function T = loadTrack(file)
%HOTLAP.LOADTRACK  FSG endurance track, cones, paddock and LTS reference lap.
%   T = hotlap.loadTrack() reads data\fsg_track.json (made by tools\build_track.m or
%   the Python scripts in source\track) and computes the same arrays as the web game:
%   centreline, tangents, normals, curvature, cones (blue left, yellow right, every 5 m and
%   closer in bends), the paved event area, the free-roam paddock with an FS skidpad and
%   acceleration strip, and the LTS reference lap.
%   Coordinates: metres, x right, y down (screen convention of the web game); heading h is
%   measured from +x toward +y. hotlap.Game shows y flipped so the 3D view has z up.
if nargin < 1, file = fullfile(hotlap.root(), 'data', 'fsg_track.json'); end
J = jsondecode(fileread(file));
T.x = J.x(:); T.y = J.y(:); N = numel(T.x); T.N = N;
j = [2:N 1]';
T.SEG = hypot(T.x(j) - T.x, T.y(j) - T.y);
T.S = [0; cumsum(T.SEG)];            % N+1 values, S(N+1) = lap length
T.LEN = T.S(end);
p = [N 1:N-1]';
dx = T.x(j) - T.x(p); dy = T.y(j) - T.y(p); l = hypot(dx, dy);
T.TTX = dx ./ l; T.TTY = dy ./ l;
T.NX = -T.TTY; T.NY = T.TTX;         % normal points to the driver's right
p3 = mod((0:N-1)' - 3, N) + 1; q3 = mod((0:N-1)' + 3, N) + 1;
a1 = atan2(T.y - T.y(p3), T.x - T.x(p3)); a2 = atan2(T.y(q3) - T.y, T.x(q3) - T.x);
l1 = hypot(T.x - T.x(p3), T.y - T.y(p3)); l2 = hypot(T.x(q3) - T.x, T.y(q3) - T.y);
T.K = hotlap.wrapAngle(a2 - a1) ./ (0.5 * (l1 + l2));   % signed curvature, positive = right-hander
T.HALF = 2.0;                        % 4 m wide for keyboard driving
mn = [min(T.x) min(T.y)]; mx = [max(T.x) max(T.y)];
T.APRON = [mn - 14, mx + 14];        % [x0 y0 x1 y1] paved event area
T.WORLD_T = [mn - 45, mx + 45];
T.FREE = [T.APRON(1) - 250, T.APRON(2) - 200, T.APRON(3) + 200, T.APRON(4) + 120];
T.WORLD_F = T.FREE + [-30 -30 30 30];
T.SKID = struct('x', T.APRON(1) - 55, 'y', (T.APRON(2) + T.APRON(4)) / 2, 'd', 18.25, 'ri', 15.25 / 2, 'ro', 21.25 / 2);
T.ACC = struct('x', T.APRON(1) + 25, 'y', T.APRON(2) - 50, 'len', 75, 'w', 5);
T.GRID_S = T.LEN - 30;

% LTS reference lap (results/viewerSamples/singleTrack_endurance.json)
L = J.lts;
T.lts.s = L.s(:); T.lts.t = L.t(:); T.lts.v = L.v(:);
T.lts.length = L.length; T.lts.lapTime = L.lapTime; T.lts.splits = [L.splits(:)' L.lapTime];
T.lts.scale = T.LEN / L.length;

% cones: blue left (-1), yellow right (+1), about every 5 m and closer in bends (D 7.1, D 5.1.1)
cx = []; cy = []; col = ''; big = []; free = [];
for side = [-1 1]
    acc = 0;
    for i = 1:N
        ak = abs(T.K(i));
        if ak > 0.07, sp = 2.4; elseif ak > 0.03, sp = 3.4; else, sp = 5; end
        acc = acc + T.SEG(i);
        if acc < sp, continue; end
        acc = 0;
        off = side * (T.HALF + 0.15); x = T.x(i) + T.NX(i) * off; y = T.y(i) + T.NY(i) * off;
        nr = hotlap.nearestPoint(T, x, y);
        if nr.d < T.HALF + 0.05, continue; end   % another section runs right here
        cx(end+1) = x; cy(end+1) = y; col(end+1) = 'b' + (side > 0) * ('y' - 'b'); big(end+1) = 0; free(end+1) = 0; %#ok<AGROW>
    end
end
for s = [-3 0 3]
    for side = [-1 1]
        pz = hotlap.poseAt(T, s); nr = hotlap.nearestPoint(T, pz.x, pz.y); off = side * (T.HALF + 0.45);
        cx(end+1) = pz.x + T.NX(nr.i) * off; cy(end+1) = pz.y + T.NY(nr.i) * off; col(end+1) = 'o'; big(end+1) = 1; free(end+1) = 0; %#ok<AGROW>
    end
end
% free roam only: skidpad (two circles 18.25 m apart, inner 15.25 m, outer 21.25 m) and the 75 m acceleration strip
K = T.SKID;
for side = [-1 1]
    ccx = K.x; ccy = K.y + side * K.d / 2;
    for k = 0:15, a = k / 16 * 2 * pi; cx(end+1) = ccx + cos(a) * K.ri; cy(end+1) = ccy + sin(a) * K.ri; col(end+1) = 'b'; big(end+1) = 0; free(end+1) = 1; end %#ok<AGROW>
    for k = 0:12
        a = k / 13 * 2 * pi; x = ccx + cos(a) * K.ro; y = ccy + sin(a) * K.ro;
        if hypot(x - ccx, y - (K.y - side * K.d / 2)) < K.ro + 0.5, continue; end   % keep the crossing open
        cx(end+1) = x; cy(end+1) = y; col(end+1) = 'y'; big(end+1) = 0; free(end+1) = 1; %#ok<AGROW>
    end
end
for side = [-1 1], cx(end+1) = K.x + K.ro + 2; cy(end+1) = K.y + side * 1.6; col(end+1) = 'o'; big(end+1) = 1; free(end+1) = 1; end %#ok<AGROW>
A = T.ACC; nA = A.len / 5;
for k = 0:nA
    for side = [-1 1]
        cx(end+1) = A.x + k * 5; cy(end+1) = A.y + side * A.w / 2; col(end+1) = 'b' + (side > 0) * ('y' - 'b'); %#ok<AGROW>
        big(end+1) = (k == 0 || k == nA); free(end+1) = 1; %#ok<AGROW>
    end
end
T.cones = struct('x0', cx(:), 'y0', cy(:), 'col', col(:), 'big', logical(big(:)), 'free', logical(free(:)));

% scenery: trees around the event area, and around the free-roam paddock
rs = RandStream('mt19937ar', 'Seed', 5);
T.trees = scatterTrees(rs, T.WORLD_T, T.APRON + [-5 -5 5 5], 260);
T.treesF = scatterTrees(rs, T.WORLD_F + [-30 -30 30 30], T.FREE + [-4 -4 4 4], 520);
end

function tr = scatterTrees(rs, box, hole, n)
tr = zeros(0, 4);   % x y radius shade
for k = 1:20 * n
    if size(tr, 1) >= n, break; end
    x = box(1) + (box(3) - box(1)) * rand(rs); y = box(2) + (box(4) - box(2)) * rand(rs);
    if x > hole(1) && x < hole(3) && y > hole(2) && y < hole(4), continue; end
    tr(end+1, :) = [x y 2.2 + rand(rs) * 2.6 rand(rs)]; %#ok<AGROW>
end
end
