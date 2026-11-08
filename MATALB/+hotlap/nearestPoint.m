function nr = nearestPoint(T, x, y)
%HOTLAP.NEARESTPOINT  Closest point on the track centreline.
%   nr = hotlap.nearestPoint(T, x, y) returns nr.d (distance, m), nr.i (segment start index),
%   nr.s (distance along the lap, m) and nr.lat (lateral offset, positive = driver's right).
%   Code-generation compatible (used in the Simulink model).
N = T.N;
[~, bi] = min((x - T.x).^2 + (y - T.y).^2);
bd = inf; bs = 0; blat = 0; bia = 1;
for k = 0:1
    if k == 0, a = bi - 1; if a < 1, a = N; end, else, a = bi; end
    b = a + 1; if b > N, b = 1; end
    vx = T.x(b) - T.x(a); vy = T.y(b) - T.y(a);
    t = ((x - T.x(a)) * vx + (y - T.y(a)) * vy) / (vx * vx + vy * vy);
    t = min(max(t, 0), 1);
    qx = T.x(a) + vx * t; qy = T.y(a) + vy * t; d = hypot(x - qx, y - qy);
    if d < bd
        bd = d; bia = a; bs = mod(T.S(a) + T.SEG(a) * t, T.LEN);
        blat = (x - qx) * T.NX(a) + (y - qy) * T.NY(a);
    end
end
nr = struct('d', bd, 'i', bia, 's', bs, 'lat', blat);
end
