function d = deriveSetup(v, T)
%HOTLAP.DERIVESETUP  Numbers that follow from a setup (same as the web game's setup editor).
%   d = hotlap.deriveSetup(vals, T) returns total mass, power to weight, drive force, top speed
%   (motor rpm or drag limited), downforce and drag at 100 km/h, L/D, grip at 60 and 100 km/h, and
%   d.est, a point-mass quasi-steady lap time on the FSG curvature (for comparing setups only).
if nargin < 2, T = hotlap.loadTrack(); end
C = hotlap.carParams(v); G0 = 9.81; kq = 0.5 * C.rho;
W = C.m * G0;
lo = 1; hi = 120;   % drag-limited top speed: P eta = (CdA q + rr (W + ClA q)) v
for k = 1:60
    s = (lo + hi) / 2; q = kq * s * s;
    if (v.CdA * q + C.rr * (W + v.ClA * q)) * s < C.Pmax * C.eta, lo = s; else, hi = s; end
end
q100 = kq * (100 / 3.6)^2;
mu = @(Fz) v.mu0 * (max(Fz, 40) / C.Fz0) .^ v.muExp;
latG = @(kmh) mu((W + v.ClA * kq * (kmh / 3.6)^2) / 4) * (W + v.ClA * kq * (kmh / 3.6)^2) / W;
d = struct('m', C.m, 'wf', v.wf, 'vTop', min(C.vMotor, lo), 'vMot', C.vMotor, 'vDrag', lo, 'Fd', C.FdMax, ...
    'pw', v.Pmax / (C.m / 1000), 'down100', v.ClA * q100, 'drag100', v.CdA * q100, 'ld', v.ClA / max(v.CdA, eps), ...
    'g60', latG(60), 'g100', latG(100), 'est', estLap(v, T, C));
end

function t = estLap(v, T, C)
% point-mass, quasi-steady lap time on the track's curvature
N = T.N; G0 = 9.81; m = C.m; kq = 0.5 * C.rho / m; Pw = C.Pmax * C.eta; Fd = C.FdMax; vMot = C.vMotor;
mu = @(Fz) v.mu0 * (max(Fz, 40) / C.Fz0) .^ v.muExp;
gripA = @(s) mu((m * G0 + v.ClA * kq * m * s .* s) / 4) .* (m * G0 + v.ClA * kq * m * s .* s) / m;
vc = zeros(N, 1);
for i = 1:N
    ak = max(abs(T.K(mod((i - 3:i + 1)', N) + 1)));
    lo = 1; hi = vMot;
    for k = 1:30, s = (lo + hi) / 2; if s * s * ak <= gripA(s), lo = s; else, hi = s; end, end
    vc(i) = lo;
end
vf = vc;
for pass = 1:2
    for i = 1:N   % accelerate: power, drive force and the grip left over by cornering
        j = mod(i, N) + 1; s = vf(i); gg = gripA(s); lat = s * s * abs(T.K(i)); lon = sqrt(max(gg * gg - lat * lat, 0));
        a = min(min(Fd, Pw / max(s, 1)) / m, lon) - (v.CdA * kq * s * s + C.rr * G0);
        vf(j) = min(vc(j), sqrt(max(s * s + 2 * a * T.SEG(i), 0.25)));
    end
    for i = N:-1:1   % brake
        j = mod(i, N) + 1; s = vf(j); gg = gripA(s); lat = s * s * abs(T.K(j)); lon = sqrt(max(gg * gg - lat * lat, 0));
        a = lon + v.CdA * kq * s * s;
        vf(i) = min(vf(i), sqrt(s * s + 2 * a * T.SEG(i)));
    end
end
t = sum(T.SEG ./ max(0.5 * (vf + vf([2:N 1])), 0.5));
end
