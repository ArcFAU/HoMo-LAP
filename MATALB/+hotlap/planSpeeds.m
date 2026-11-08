function [vPlan, vPlanA] = planSpeeds(T, C)
%HOTLAP.PLANSPEEDS  Speed plans along the centreline for the AI driver and the brake assist.
%   vPlan (mu factor 0.86, braking 0.7) drives the AI; vPlanA (0.9, 0.72) is the brake assist limit.
vPlan = plan(T, C, 0.86, 0.7);
vPlanA = plan(T, C, 0.9, 0.72);
end

function v = plan(T, C, muf, abf)
N = T.N; G0 = 9.81;
kq = 0.5 * C.rho * C.ClA / C.m; mu = 1.3 * muf * C.mu0 / 1.40;
v = zeros(N, 1);
for i = 1:N
    ak = max(abs(T.K(mod((i - 4:i + 2)', N) + 1)));
    den = ak - mu * kq;
    if den <= 1e-4, v(i) = 60; else, v(i) = min(60, sqrt(mu * G0 / den)); end
end
for pass = 1:3
    for i = N:-1:1
        nx = v(mod(i, N) + 1); ab = abf * mu * (G0 + kq * nx * nx); vv = sqrt(nx * nx + 2 * ab * T.SEG(i));
        if vv < v(i), v(i) = vv; end
    end
end
end
