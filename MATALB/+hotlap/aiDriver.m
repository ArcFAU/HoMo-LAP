function inp = aiDriver(c, T, vPlan)
%HOTLAP.AIDRIVER  The demo driver: path follower with curvature feed-forward plus heading and
%   cross-track correction (Stanley type), speed from the plan. Same as aiInput() in the web game.
%   Code-generation compatible.
v = max(c.vx, 0); N = T.N;
sA = c.s + 0.8 + v * 0.06; iA = floor(sA);
kff = 0; for j = -1:1, kff = kff + T.K(mod(iA + j, N) + 1) / 3; end
pA = hotlap.poseAt(T, sA);
headV = c.h + atan2(c.vy, max(abs(c.vx), 1));
eH = hotlap.wrapAngle(pA.h - headV);
del = atan(1.53 * kff) + 1.0 * eH - atan(3.2 * c.lat / (v + 1.5));
vt = vPlan(mod(floor(c.s + 2 + v * 0.08), N) + 1);
inp = hotlap.driverInput(min(max(del / c.dLim, -1), 1), min(max((vt - c.vx) / 1.5, 0), 1), min(max((c.vx - vt - 0.3) / 3, 0), 1));
end
