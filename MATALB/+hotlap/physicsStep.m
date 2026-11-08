function [c, f] = physicsStep(c, inp, C, P, dt)
%HOTLAP.PHYSICSSTEP  One step of the single-track car model (same model as the web game).
%   [c, f] = hotlap.physicsStep(c, inp, C, P, dt)
%     c    car state (hotlap.carState): position x, y (m), heading h, body velocities vx, vy (m/s),
%          yaw rate r, filtered steer/throttle/brake, filtered accelerations, drift timer ...
%     inp  driver input: steer (-1..1, + = right), thr, brk (0..1), hb, assist, human, arcade (logical)
%     C    car parameters (hotlap.carParams)
%     P    track data for the assists and the world edge: N, K, vPlanA, world [x0 y0 x1 y1], s (lap position)
%     dt   time step, s (the game uses 1/600 s)
%   Single-track model with load transfer and a friction ellipse, LTS tyre envelope, four motors at
%   the system power limit, torque vectoring, brake split with wheel-slip control. In arcade mode:
%   more grip, power and top speed, automatic counter-steer, handbrake drifts and a stability limit.
%   Code-generation compatible: the Simulink model calls this function.
G0 = 9.81; DEG = pi / 180; A = C.arc;
arc = inp.arcade;
thrT = min(max(inp.thr, 0), 1); brkT = min(max(inp.brk, 0), 1);
% brake assist: never enter a bend faster than the planned corner speed
c.assistBrake = false;
if inp.assist && ~arc && c.vx > 3
    vt = P.vPlanA(mod(floor(c.s + 2 + c.vx * 0.25), P.N) + 1);
    if c.vx > vt + 0.2, brkT = max(brkT, min(max((c.vx - vt) / 0.8, 0), 1)); thrT = 0; c.assistBrake = true; end
end
c.thr = c.thr + min(max(thrT - c.thr, -9 * dt), pick(arc, 10, 6) * dt);
c.brk = c.brk + min(max(brkT - c.brk, -12 * dt), pick(arc, 16, 12) * dt);
st = min(max(inp.steer, -1), 1);
if abs(st) < abs(c.st) || st * c.st < 0, rate = pick(arc, 9, 7); else, rate = pick(arc, 6, 4.2); end
c.st = c.st + min(max(st - c.st, -rate * dt), rate * dt);

v = hypot(c.vx, c.vy); vxs = max(abs(c.vx), 1.5);
sf = 1; if c.grass, sf = pick(arc, A.grass, 0.62); end
if arc, sf = sf * A.grip; end
beta = atan2(c.vy, vxs);
ClAe = C.ClA * (1 - C.yawLoss * min(abs(beta) / DEG, 8));
q = 0.5 * C.rho * c.vx * c.vx;
Fdown = q * ClAe; Fdrag = q * C.CdA; W = C.m * G0;
Fzf = W * C.b / C.L + Fdown * C.bal - C.m * c.axp * C.h / C.L;
Fzr = W * C.a / C.L + Fdown * (1 - C.bal) + C.m * c.axp * C.h / C.L;
Fzf = max(Fzf, 60); Fzr = max(Fzr, 60);
dF = C.m * c.ayp * C.h;
capF = axleCap(C, Fzf, C.rollFront * dF / C.tf) * sf; capR = axleCap(C, Fzr, (1 - C.rollFront) * dF / C.tr) * sf;

% arcade drift state: the handbrake, or power with the rear already sliding, starts a slide the car holds for a moment
if arc
    c.driftT = max(0, c.driftT - dt);
    if inp.hb && c.vx > 7, c.driftT = 0.9;
    elseif c.driftT > 0 && c.thr > 0.5 && abs(beta) > 6 * DEG, c.driftT = max(c.driftT, 0.35);
    end
else
    c.driftT = 0;
end
drift = c.driftT > 0;

% steering: the key maps to a share of the lock the car can use at this speed
aLim = (capF + capR) / C.m;
if arc, dLim = min(C.delMax, atan(C.L * aLim / max(v * v, 4)) + 1.15 * C.ap);
else,   dLim = min(C.delMax, C.L * aLim / max(v * v, 4) + 0.9 * C.ap);
end
dCmd = c.st * dLim;
if arc
    if abs(c.vx) > 3   % automatic counter-steer into a slide (less while drifting, so the slide lasts)
        bx = sign(beta) * max(0, abs(beta) - 3 * DEG);
        dCmd = min(max(dCmd + min(max(pick(drift, 0.45, 0.8) * bx, -0.35), 0.35), -C.delMax), C.delMax);
    end
elseif inp.assist && inp.human && abs(c.vx) > 2.5
    % steering assist: into the bend gives the lock the bend needs plus a margin, otherwise a gentler lock
    iA = floor(c.s + 1 + 0.12 * v);
    kA = 0; for jj = -2:2, kA = kA + P.K(mod(iA + jj, P.N) + 1) / 5; end
    if c.st * kA > 0 && abs(kA) > 0.004
        dff = atan(C.L * abs(kA)) + 0.6 * C.ap * min(1, abs(kA) * 8);
        want = 1.05 * dff - atan(1.2 * c.lat / (v + 2)) * sign(kA) + 0.2 * dLim;
        dCmd = sign(c.st) * abs(c.st) * min(max(want, 0.25 * dLim), dLim);
    else
        dCmd = c.st * dLim * 0.55;
    end
end
c.delta = dCmd; c.dLim = dLim;

% longitudinal: 4 motors, torque split by axle load with traction control, brakes with wheel-slip control
Fxf = 0; Fxr = 0; Pw = 0;
Pmax = C.Pmax * pick(arc, A.power, 1); FdMax = C.FdMax * pick(arc, A.force, 1); vTop = C.vMotor * pick(arc, A.vtop, 1);
if c.thr > 0.001 && ~(c.brk > 0.05 && c.vx > 0.3)
    Fd = min(FdMax, Pmax * C.eta / max(c.vx, 1));
    if c.vx > vTop - 0.6, Fd = Fd * min(max((vTop - c.vx) / 0.6, 0), 1); end
    Fd = Fd * c.thr;
    shr = Fzf / (Fzf + Fzr);
    tcF = 0.9; tcR = 0.9;
    if arc
        tcF = 0.95; tcR = pick(drift, 1.0, 0.95);
    elseif inp.assist   % traction assist: keep enough grip for the corner the tyres are already in
        uF = min(1, abs(c.FyfP) / max(capF, 1)); uR = min(1, abs(c.FyrP) / max(capR, 1));
        tcF = 0.9 * sqrt(max(0.04, 1 - 1.05 * uF * uF)); tcR = 0.9 * sqrt(max(0.04, 1 - 1.05 * uR * uR));
    end
    Fxf = min(Fd * shr, tcF * capF); Fxr = min(Fd * (1 - shr), tcR * capR);
    Pw = (Fxf + Fxr) * max(c.vx, 0) / C.eta;
elseif c.brk > 0.001
    if c.vx > 0.3
        % brake split 70/30 (LTS), wheel-slip control keeps 90 % front / 60 % rear of the axle grip (arcade: 95 / 80 %)
        Fb = c.brk * C.Fb * pick(arc, A.brake, 1);
        Fxf = -min(C.brakeFront * Fb, pick(arc, 0.95, 0.9) * capF); Fxr = -min((1 - C.brakeFront) * Fb, pick(arc, 0.8, 0.6) * capR);
    elseif c.vx > -3.5
        Fxf = -c.brk * 450; Fxr = -c.brk * 450;
    end
end
af = c.delta - atan2(c.vy + C.a * c.r, vxs);
ar = -atan2(c.vy - C.b * c.r, vxs);
% rear slip guard: when the rear slides, the motors back off the rear longitudinal force (arcade: not while drifting)
if arc
    if ~drift && abs(ar) > C.ap && ~inp.hb, Fxr = Fxr * 0.4; end
elseif abs(ar) > pick(inp.assist, 0.85, 1.15) * C.ap && ~inp.hb
    Fxr = Fxr * pick(inp.assist, 0.3, 0.5);
end
if inp.assist && c.assistBrake, Fxr = Fxr * 0.6; end     % assisted braking leans on the front axle
if inp.hb && abs(c.vx) > 0.3, Fxr = -sign(c.vx) * pick(arc, 0.35, 0.85) * capR; end
Dyf = sqrt(max(capF * capF - Fxf * Fxf, 0));
Dyr = sqrt(max(capR * capR - Fxr * Fxr, 0));
if arc && inp.hb, Dyr = Dyr * 0.5;                        % arcade handbrake: the rear lets go
elseif arc && drift && c.thr > 0.3, Dyr = Dyr * 0.85;     % power holds the slide
end
Fyf = Dyf * sin(C.C * atan(C.B * af)); Fyr = Dyr * sin(C.C * atan(C.B * ar));

cd = cos(c.delta); sd = sin(c.delta);
Fres = C.rr * (W + Fdown) + Fdrag + c.grass * 0.05 * W;
FX = Fxf * cd - Fyf * sd + Fxr; FY = Fxf * sd + Fyf * cd + Fyr;
MZ = C.a * (Fyf * cd + Fxf * sd) - C.b * Fyr;
% torque vectoring: four motors steer the yaw rate toward the driver's request
if abs(c.vx) > 4 && ~inp.hb
    rMax = 0.95 * aLim / abs(c.vx);
    rDes = min(max(c.vx * tan(c.delta) / C.L, -rMax), rMax);
    if arc, kTv = 12; mTv = pick(drift, 500, 2200); elseif inp.assist, kTv = 10; mTv = 1400; else, kTv = 6; mTv = 900; end
    mTv = mTv * C.tv;
    MZ = MZ + min(max(C.Iz * kTv * (rDes - c.r), -mTv), mTv);
end
if arc && abs(c.vx) > 3
    % arcade stability: body slip below 14 deg (38 deg while drifting), yaw rate below what the grip can hold
    bMax = pick(drift, 38, 14) * DEG; bx = beta - min(max(beta, -bMax), bMax);
    MZ = MZ + min(max(C.Iz * 70 * bx, -7000), 7000);
    rCap = pick(drift, 1.6, 1.2) * aLim / abs(c.vx); rx = c.r - min(max(c.r, -rCap), rCap);
    MZ = MZ - min(max(C.Iz * 14 * rx, -6000), 6000);
end
% resistance never reverses the car
stopF = abs(c.vx) * C.m / dt;
FX = FX - sign(c.vx) * min(Fres, stopF);
axb = FX / C.m; ayb = FY / C.m;
c.vx = c.vx + (axb + c.vy * c.r) * dt;
c.vy = c.vy + (ayb - c.vx * c.r) * dt;
c.r = c.r + MZ / C.Iz * dt;
% blend to kinematic steering at walking pace
ax = abs(c.vx);
if ax < 3 || c.vx < 0
    if c.vx < 0, kb = 1; else, kb = min(max((3 - ax) / 2.5, 0), 1); end
    rk = c.vx * tan(c.delta) / C.L;
    c.r = c.r + (rk - c.r) * kb; c.vy = c.vy + (rk * C.b - c.vy) * kb;
end
if ax < 0.05 && c.thr < 0.01 && c.brk < 0.01, c.vx = 0; c.vy = c.vy * 0.9; c.r = c.r * 0.9; end
c.axp = c.axp + (axb - c.axp) * min(1, dt * 25);
c.ayp = c.ayp + (ayb - c.ayp) * min(1, dt * 25);

ch = cos(c.h); sh = sin(c.h);
c.x = c.x + (c.vx * ch - c.vy * sh) * dt; c.y = c.y + (c.vx * sh + c.vy * ch) * dt; c.h = c.h + c.r * dt;
w = P.world;
if c.x < w(1) || c.x > w(3) || c.y < w(2) || c.y > w(4)
    c.x = min(max(c.x, w(1)), w(3)); c.y = min(max(c.y, w(2)), w(4)); c.vx = c.vx * 0.3; c.vy = c.vy * 0.3; c.outT = c.outT + dt; c.hitWall = true;
else
    c.outT = 0; c.hitWall = false;
end
c.FyfP = Fyf; c.FyrP = Fyr;
f = struct('Fdown', Fdown, 'Fdrag', Fdrag, 'capF', capF, 'capR', capR, 'Fxf', Fxf, 'Fxr', Fxr, 'Fyf', Fyf, 'Fyr', Fyr, ...
    'af', af, 'ar', ar, 'beta', beta, 'ClAe', ClAe, 'P', Pw, 'ax', axb, 'ay', ayb, 'Fz', Fzf + Fzr);
end

function y = pick(cond, a, b)
if cond, y = a; else, y = b; end
end

function cap = axleCap(C, Fz, dF)
o = Fz / 2 + abs(dF); i = Fz / 2 - abs(dF);
if i < 0, o = o + i; i = 0; end
cap = muAt(C, o) * o;
if i > 0, cap = cap + muAt(C, i) * i; end
end

function mu = muAt(C, Fz)
mu = C.mu0 * (max(Fz, 40) / C.Fz0) ^ C.muExp;
end
