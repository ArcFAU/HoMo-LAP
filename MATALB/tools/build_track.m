function build_track(outFile, vdRoot)
%BUILD_TRACK  data\fsg_track.json from the LTS data (MATLAB version of source\track\*.py).
%   build_track() reads D:\VD\laptimesimulation (read-only):
%     data\tracks\A_FSGend_3.mat                       distance and curvature of the FSG endurance track
%     results\viewerSamples\singleTrack_endurance.json the LTS reference lap (75.058 s)
%   and writes data\fsg_track.json in this folder:
%     1. curvature resampled to 0.5 m, smoothed over 3 m, integrated into x/y
%     2. the closure gap removed with a minimal-norm curvature correction (heading and position)
%     3. the end section pushed 2.4 m away from the start straight where the two pinch together
%     4. resampled to 1 m, shifted to screen coordinates (y down) with a 40 m margin
%     5. the LTS lap on a 2 m grid, with sector times at a third and two thirds of the distance
%   build_track(outFile, vdRoot) to choose the output file and the location of the VD repository.
here = fileparts(mfilename('fullpath')); root = fileparts(here);
if nargin < 1 || isempty(outFile), outFile = fullfile(root, 'data', 'fsg_track.json'); end
if nargin < 2 || isempty(vdRoot), vdRoot = 'D:\VD'; end
S = load(fullfile(vdRoot, 'laptimesimulation', 'data', 'tracks', 'A_FSGend_3.mat'));
A = S.A; s = A(:, 1) - A(1, 1); k = A(:, 2);
Ltot = 1103.4082136873235; ds = 0.5; N = round(Ltot / ds); ds = Ltot / N;
su = (0:N - 1)' * ds; ku = interp1(s, k, su, 'linear', 'extrap');
n = bitor(round(3.0 / ds), 1);                     % 3 m circular moving average, as np.convolve 'same'
kp = [ku(end - n + 1:end); ku; ku(1:n)]; ks = conv(kp, ones(n, 1) / n, 'same'); ks = ks(n + 1:end - n);
kk = ks;
for it = 1:8
    [x, y, th] = integ(kk, ds);
    target = 2 * pi * round(th(end) / (2 * pi));
    r = [th(end) - target; x(end) - x(1); y(end) - y(1)];
    xs = x(1:end - 1); ys = y(1:end - 1);
    J = [ones(1, N) * ds; -(y(end) - ys') * ds; (x(end) - xs') * ds];
    lam = (J * J') \ (-r);
    kk = kk + J' * lam;
end
[x, y] = integ(kk, ds); x = x(1:end - 1); y = y(1:end - 1);
fprintf('closure: max |dk| %.2e 1/m\n', max(abs(kk - ks)));
% push the end section away from the start straight around the pinch (Hann window, peak at 1040 m)
s = (0:N - 1)' * ds; startSel = find(s > 0 & s < 110); win = find(s > 990 & s < 1090);
w = zeros(N, 1); w(win) = 0.5 * (1 - cos(2 * pi * (s(win) - 990) / 100));
nx = zeros(N, 1); ny = zeros(N, 1);
for i = win'
    [~, j] = min(hypot(x(startSel) - x(i), y(startSel) - y(i))); j = startSel(j);
    dd = hypot(x(i) - x(j), y(i) - y(j)); nx(i) = (x(i) - x(j)) / dd; ny(i) = (y(i) - y(j)) / dd;
end
x = x + 2.4 * w .* nx; y = y + 2.4 * w .* ny;
% resample to 1 m
seg = hypot(diff([x; x(1)]), diff([y; y(1)])); cum = [0; cumsum(seg)]; L = cum(end);
M = round(L); sq = linspace(0, L, M + 1)'; sq = sq(1:end - 1);
xx = interp1(cum, [x; x(1)], sq); yy = interp1(cum, [y; y(1)], sq);
gx = xx - min(xx) + 40; gy = -yy - min(-yy) + 40;
% LTS reference lap
lap = jsondecode(fileread(fullfile(vdRoot, 'laptimesimulation', 'results', 'viewerSamples', 'singleTrack_endurance.json')));
ls_ = lap.lap.distance_m(:); lt = lap.lap.time_s(:); lv = lap.lap.speed_mps(:);
Llts = lap.track.length_m; Tl = lap.summary.lapTime_s;
grid = (0:2:Llts - 1e-9)'; tg = interp1(ls_, lt, grid); vg = interp1(ls_, lv, grid);
sec = interp1(ls_, lt, Llts * [1 / 3 2 / 3]);
out.x = round(gx, 2); out.y = round(gy, 2);
out.lts = struct('s', round(grid, 1), 't', round(tg, 3), 'v', round(vg, 2), 'length', round(Llts, 2), 'lapTime', round(Tl, 3), ...
    'splits', round(sec(:), 3), 'model', lap.model, 'vehicle', lap.vehicleName, 'created', lap.created, 'vmax', lap.summary.maximumSpeed_mps);
fid = fopen(outFile, 'w', 'n', 'UTF-8'); fprintf(fid, '%s', jsonencode(out)); fclose(fid);
fprintf('wrote %s: %d points, %.1f m, LTS lap %.3f s, splits %.3f / %.3f s\n', outFile, M, L, Tl, sec(1), sec(2));
end

function [x, y, th] = integ(kk, ds)
th = [0; cumsum(kk * ds)];                 % N+1 headings
thm = th(1:end - 1) + kk * ds / 2;
x = [0; cumsum(cos(thm) * ds)]; y = [0; cumsum(sin(thm) * ds)];
end
