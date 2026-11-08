function import_car(glbFile, outFile, targetTris, maxEdge)
%IMPORT_CAR  FAUmax tau model for the MATLAB edition: GLB export -> data\car_mesh.mat.
%   import_car() reads ..\blender\faumax_tau.glb (the background Blender export, see the main
%   README), bakes the projected livery into vertex colours and writes data\car_mesh.mat.
%   The mesh is reduced to about 70,000 triangles, then the livery panels are refined where the
%   livery changes (stripe edges, E49, tau, down to 1.5 cm edges), so it survives as vertex colours.
%   data\car_mesh.mat holds
%     body    struct Faces (int32), Vertices (single, m), Colors (uint8 RGB)
%     tires   struct array, one per wheel: Faces, Vertices (around the wheel centre), Colors, centre, front
%   Coordinates are Blender's (x forward, y left, z up) with the origin moved midway between the
%   axles (x = 2.467 m), which is how hotlap.Game places the model.
%   import_car(glbFile, outFile, targetTris, minEdge) to choose files, the base triangle budget
%   and the smallest livery edge (m). Reads only; nothing is written next to the GLB.
here = fileparts(mfilename('fullpath')); root = fileparts(here);
if nargin < 1 || isempty(glbFile), glbFile = fullfile(fileparts(root), 'blender', 'faumax_tau.glb'); end
if nargin < 2 || isempty(outFile), outFile = fullfile(root, 'data', 'car_mesh.mat'); end
if nargin < 3 || isempty(targetTris), targetTris = 70000; end
if nargin < 4 || isempty(maxEdge), maxEdge = 0.015; end
MODEL_X0 = (1.702 + 3.232) / 2;    % axles at x = 1.702 m (rear) and 3.232 m (front)
LIV = struct('c', [2.725 0 0.55], 's', [1.525 0.8 0.55], 'sharp', 8);   % LIVERY_Projector empty

fprintf('reading %s\n', glbFile);
fid = fopen(glbFile, 'r'); B = fread(fid, inf, '*uint8'); fclose(fid);
assert(isequal(char(B(1:4))', 'glTF'), 'not a GLB file');
L0 = double(typecast(B(13:16), 'uint32'));
J = jsondecode(char(B(21:20 + L0))');
o = 20 + L0; L1 = double(typecast(B(o + 1:o + 4), 'uint32'));
BIN = B(o + 9:o + 8 + L1);
nodes = asCell(J.nodes); meshes = asCell(J.meshes); accs = asCell(J.accessors); bvs = asCell(J.bufferViews); mats = asCell(J.materials);

% livery images (same files as the web game)
lv = struct();
for k = {'Left', 'Right', 'Top', 'Front', 'Rear'}
    [im, ~, al] = imread(fullfile(root, 'data', 'livery', ['LIVERY_' k{1} '.png']));
    if isempty(al), al = 255 * ones(size(im, 1), size(im, 2), 'uint8'); end
    lv.(k{1}) = struct('rgb', double(im) / 255, 'a', double(al) / 255);
end

% walk the default scene
parts = {};
scene = J.scenes(J.scene + 1); if iscell(scene), scene = scene{1}; end
stack = num2cell(scene.nodes(:)');
stack = cellfun(@(n) struct('i', n, 'M', eye(4), 'tire', -1), stack, 'UniformOutput', false);
tireNames = {};
while ~isempty(stack)
    it = stack{end}; stack(end) = [];
    nd = nodes{it.i + 1};
    M = it.M * localMatrix(nd);
    nm = ''; if isfield(nd, 'name'), nm = nd.name; end
    tire = it.tire;
    if tire < 0 && ~isempty(regexp(nm, '^S_S000_TIRE', 'once')), tireNames{end+1} = nm; tire = numel(tireNames); end %#ok<AGROW>
    if isfield(nd, 'mesh')
        ms = meshes{nd.mesh + 1}; prims = asCell(ms.primitives);
        for p = 1:numel(prims)
            pr = prims{p};
            V = readAcc(accs, bvs, BIN, pr.attributes.POSITION);
            Nn = readAcc(accs, bvs, BIN, pr.attributes.NORMAL);
            if isfield(pr, 'indices'), F = reshape(readAcc(accs, bvs, BIN, pr.indices), 3, [])' + 1; else, F = reshape(1:size(V, 1), 3, [])'; end
            Vh = [V ones(size(V, 1), 1)] * M'; V = Vh(:, 1:3);
            Nn = Nn * inv(M(1:3, 1:3)); Nn = Nn ./ max(vecnorm(Nn, 2, 2), 1e-9); %#ok<MINV>
            % glTF (y up) -> Blender (z up): x = gx, y = -gz, z = gy
            V = [V(:, 1) -V(:, 3) V(:, 2)]; Nn = [Nn(:, 1) -Nn(:, 3) Nn(:, 2)];
            mi = -1; if isfield(pr, 'material'), mi = pr.material; end
            parts{end+1} = struct('V', V, 'N', Nn, 'F', double(F), 'mat', mi, 'tire', tire, 'name', nm); %#ok<AGROW>
        end
    end
    if isfield(nd, 'children')
        for ch = nd.children(:)', stack{end+1} = struct('i', ch, 'M', M, 'tire', tire); end %#ok<AGROW>
    end
end
total = sum(cellfun(@(p) size(p.F, 1), parts));
isLivPart = cellfun(@(p) p.mat >= 0 && isfield(mats{p.mat + 1}, 'name') && contains(mats{p.mat + 1}.name, '[LIVERY]'), parts);
plain = sum(cellfun(@(p) size(p.F, 1), parts(~isLivPart)));
fprintf('%d parts, %d triangles (%d on livery materials), %d tyre nodes\n', numel(parts), total, total - plain, numel(tireNames));

% colours per vertex: materials as in the web game, livery projected on [LIVERY] materials
ratio = min(1, targetTris / total);
body = struct('F', zeros(0, 3), 'V', zeros(0, 3), 'C', zeros(0, 3));
tires = repmat(struct('F', zeros(0, 3), 'V', zeros(0, 3), 'C', zeros(0, 3)), 1, max(numel(tireNames), 1));
for k = 1:numel(parts)
    p = parts{k};
    name = ''; base = [0.118 0.129 0.145]; isLiv = false;
    if p.mat >= 0
        m = mats{p.mat + 1}; if isfield(m, 'name'), name = m.name; end
        bc = [1 1 1];
        if isfield(m, 'pbrMetallicRoughness') && isfield(m.pbrMetallicRoughness, 'baseColorFactor'), bc = m.pbrMetallicRoughness.baseColorFactor(1:3)'; end
        if contains(name, '[LIVERY]')
            isLiv = true;
            if ~isempty(regexpi(name, 'alumin', 'once')), base = hex([184 188 194]); elseif contains(name, 'Material.001'), base = hex([11 11 12]); else, base = hex([30 33 37]); end
        elseif ~isempty(regexpi(name, 'tyre|tire|rubber', 'once')), base = hex([18 18 18]);
        elseif isempty(name) || ~isempty(regexpi(name, 'carbon|fibre|fiber', 'once')), base = hex([30 33 37]);
        else, base = min(1, bc .^ (1 / 2.2));   % linear -> sRGB
        end
    end
    F = p.F; V = p.V; Nv = p.N;
    if ratio < 1 && size(F, 1) > 150
        [F2, V2] = reducepatch(F, V, ratio);
        if ~isempty(F2), Nv = Nv(nearestIdx(V2, V), :); F = F2; V = V2; end
    end
    if isLiv
        [F, V, col] = refineLivery(F, V, Nv, base, lv, LIV, maxEdge);
    else
        col = repmat(base, size(V, 1), 1);
    end
    if p.tire > 0
        t = p.tire; o = size(tires(t).V, 1);
        tires(t).F = [tires(t).F; F + o]; tires(t).V = [tires(t).V; V]; tires(t).C = [tires(t).C; col];
    else
        o = size(body.V, 1); body.F = [body.F; F + o]; body.V = [body.V; V]; body.C = [body.C; col];
    end
end
shift = [MODEL_X0 0 0];
car.body = struct('Faces', int32(body.F), 'Vertices', single(body.V - shift), 'Colors', uint8(round(body.C * 255)));
car.tires = struct('Faces', {}, 'Vertices', {}, 'Colors', {}, 'centre', {}, 'front', {}, 'name', {});
for t = 1:numel(tireNames)
    c = (min(tires(t).V) + max(tires(t).V)) / 2;
    car.tires(t) = struct('Faces', int32(tires(t).F), 'Vertices', single(tires(t).V - c), 'Colors', uint8(round(tires(t).C * 255)), ...
        'centre', c - shift, 'front', c(1) - MODEL_X0 > 0, 'name', tireNames{t});
end
car.source = glbFile; car.made = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm'));
car.triangles = size(car.body.Faces, 1) + sum(arrayfun(@(t) size(t.Faces, 1), car.tires));
save(outFile, '-struct', 'car', '-v7');
fprintf('wrote %s: %d triangles (body %d), %d tyres\n', outFile, car.triangles, size(car.body.Faces, 1), numel(car.tires));
end

function c = hex(rgb), c = rgb / 255; end

function [F, V, col] = refineLivery(F, V, N, base, lv, LIV, minE)
% adaptive refinement: split triangles where the projected livery changes inside them
% (stripe edges, E49, tau), down to edges of minE; flat-coloured areas stay coarse
col = livery(V, N, repmat(base, size(V, 1), 1), lv, LIV);
for it = 1:8
    e = [vecnorm(V(F(:, 1), :) - V(F(:, 2), :), 2, 2), vecnorm(V(F(:, 2), :) - V(F(:, 3), :), 2, 2), vecnorm(V(F(:, 3), :) - V(F(:, 1), :), 2, 2)];
    c1 = col(F(:, 1), :); c2 = col(F(:, 2), :); c3 = col(F(:, 3), :);
    nc = N(F(:, 1), :) + N(F(:, 2), :) + N(F(:, 3), :); nc = nc ./ max(vecnorm(nc, 2, 2), 1e-9);
    cc = livery((V(F(:, 1), :) + V(F(:, 2), :) + V(F(:, 3), :)) / 3, nc, repmat(base, size(F, 1), 1), lv, LIV);
    err = max(abs(cc - (c1 + c2 + c3) / 3), [], 2) + 0.5 * max(max(abs(c1 - c2), abs(c2 - c3)), [], 2);
    sel = max(e, [], 2) > minE & err > 0.16;   % above the carbon-weave contrast in the images
    if ~any(sel), break; end
    n0 = size(V, 1);
    [F, V, N] = splitFaces(F, V, N, sel);
    col = [col; livery(V(n0 + 1:end, :), N(n0 + 1:end, :), repmat(base, size(V, 1) - n0, 1), lv, LIV)]; %#ok<AGROW>
end
end

function [F, V, N] = splitFaces(F, V, N, sel)
% split the selected triangles into four, sharing the edge midpoints
    Fs = F(sel, :); ns = size(Fs, 1);
    E = sort([Fs(:, [1 2]); Fs(:, [2 3]); Fs(:, [3 1])], 2);
    [Eu, ~, ic] = unique(E, 'rows');
    mid = size(V, 1) + (1:size(Eu, 1))';
    V = [V; (V(Eu(:, 1), :) + V(Eu(:, 2), :)) / 2];
    Nm = N(Eu(:, 1), :) + N(Eu(:, 2), :); N = [N; Nm ./ max(vecnorm(Nm, 2, 2), 1e-9)];
    m12 = mid(ic(1:ns)); m23 = mid(ic(ns + 1:2 * ns)); m31 = mid(ic(2 * ns + 1:end));
    F = [F(~sel, :); Fs(:, 1) m12 m31; m12 Fs(:, 2) m23; m31 m23 Fs(:, 3); m12 m23 m31];
end

function C = asCell(x)
if iscell(x), C = x(:)'; else, C = num2cell(x(:)'); end
end

function M = localMatrix(nd)
if isfield(nd, 'matrix'), M = reshape(nd.matrix, 4, 4); return; end
Tm = eye(4); R = eye(4); S = eye(4);
if isfield(nd, 'translation'), Tm(1:3, 4) = nd.translation(:); end
if isfield(nd, 'rotation')
    q = nd.rotation(:); x = q(1); y = q(2); z = q(3); w = q(4);
    R(1:3, 1:3) = [1 - 2*(y*y + z*z), 2*(x*y - z*w), 2*(x*z + y*w); 2*(x*y + z*w), 1 - 2*(x*x + z*z), 2*(y*z - x*w); 2*(x*z - y*w), 2*(y*z + x*w), 1 - 2*(x*x + y*y)];
end
if isfield(nd, 'scale'), S(1:3, 1:3) = diag(nd.scale(:)); end
M = Tm * R * S;
end

function D = readAcc(accs, bvs, BIN, idx)
a = accs{idx + 1}; bv = bvs{a.bufferView + 1};
off = 0; if isfield(bv, 'byteOffset'), off = bv.byteOffset; end
if isfield(a, 'byteOffset'), off = off + a.byteOffset; end
switch a.componentType
    case 5126, cls = 'single'; nb = 4;
    case 5125, cls = 'uint32'; nb = 4;
    case 5123, cls = 'uint16'; nb = 2;
    case 5121, cls = 'uint8';  nb = 1;
    otherwise, error('component type %d', a.componentType);
end
nc = struct('SCALAR', 1, 'VEC2', 2, 'VEC3', 3, 'VEC4', 4).(a.type);
stride = nc * nb; if isfield(bv, 'byteStride') && ~isempty(bv.byteStride), stride = bv.byteStride; end
if stride == nc * nb
    raw = BIN(off + 1:off + a.count * stride);
else
    idxB = off + (0:a.count - 1)' * stride + (1:nc * nb); raw = BIN(reshape(idxB', [], 1));
end
D = double(reshape(typecast(raw(:), cls), nc, [])');
end

function col = livery(V, N, col, lv, LIV)
% same projection as the web game's shader: five planar images blended by surface normal
q = 0.5 * (V - LIV.c) ./ LIV.s + 0.5;
S = LIV.sharp;
w = @(x) max(x, 0) .^ S;
[cL, aL] = samp(lv.Left,  1 - q(:, 1), q(:, 3)); wL = w(N(:, 2));
[cR, aR] = samp(lv.Right, q(:, 1),     q(:, 3)); wR = w(-N(:, 2));
[cT, aT] = samp(lv.Top,   q(:, 1),     q(:, 2)); wT = w(N(:, 3));
[cF, aF] = samp(lv.Front, q(:, 2),     q(:, 3)); wF = w(N(:, 1));
[cB, aB] = samp(lv.Rear,  1 - q(:, 2), q(:, 3)); wB = w(-N(:, 1));
wD = w(-N(:, 3));
aL = aL .* wL; aR = aR .* wR; aT = aT .* wT; aF = aF .* wF; aB = aB .* wB;
aSum = aL + aR + aT + aF + aB; wSum = wL + wR + wT + wF + wB + wD;
la = zeros(size(aSum)); ok = wSum > 1e-6; la(ok) = min(max(aSum(ok) ./ wSum(ok), 0), 1);
lc = (cL .* aL + cR .* aR + cT .* aT + cF .* aF + cB .* aB) ./ max(aSum, 1e-6);
col = col .* (1 - la) + lc .* la;
end

function [c, a] = samp(img, u, v)
% texture lookup with three.js conventions (flipY: v = 0 is the bottom row); outside [0, 1] is transparent
[H, W, ~] = size(img.rgb);
in = u >= 0 & u <= 1 & v >= 0 & v <= 1;
col = round(min(max(u, 0), 1) * (W - 1)) + 1; row = round((1 - min(max(v, 0), 1)) * (H - 1)) + 1;
id = sub2ind([H W], row, col);
c = [img.rgb(id) img.rgb(id + H * W) img.rgb(id + 2 * H * W)];
a = img.a(id) .* in;
end

function idx = nearestIdx(Q, V)
% index of the nearest row of V for every row of Q (brute force in blocks)
idx = zeros(size(Q, 1), 1); bs = 2000;
for s = 1:bs:size(Q, 1)
    e = min(s + bs - 1, size(Q, 1)); q = Q(s:e, :);
    d = (q(:, 1) - V(:, 1)').^2 + (q(:, 2) - V(:, 2)').^2 + (q(:, 3) - V(:, 3)').^2;
    [~, idx(s:e)] = min(d, [], 2);
end
end
