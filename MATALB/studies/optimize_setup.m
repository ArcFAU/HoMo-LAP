function R = optimize_setup(base)
%OPTIMIZE_SETUP  Best downforce level and gear ratio for the FSG endurance lap (Optimization Toolbox).
%   R = optimize_setup() starts from the stock tau (LTS aero package) and finds ClA and the gear
%   ratio G that minimise the point-mass lap estimate (hotlap.deriveSetup), with drag tied to
%   downforce by a straight-line fit through the team's CFD and LTS packages (more downforce costs
%   drag). It then checks the result with a full AI lap (hotlap.simulateLap).
%   Needs the Optimization Toolbox (fmincon).
%   The drag fit and the bounds are simple assumptions; treat the result as a direction, not a design.
S = hotlap.setups(); T = hotlap.loadTrack();
if nargin < 1 || isempty(base), base = S.presets(1).vals; end
V = [S.presets.vals]; V = V([V.ClA] > 0);
pc = polyfit([V.ClA], [V.CdA], 1);            % CdA = pc(1) ClA + pc(2)
fprintf('drag fit over %d packages: CdA = %.3f ClA + %.3f\n', numel(V), pc(1), pc(2));
mk = @(z) setfield(setfield(setfield(base, 'ClA', z(1)), 'CdA', polyval(pc, z(1))), 'G', z(2));
obj = @(z) hotlap.deriveSetup(mk(z), T).est;
z0 = [base.ClA base.G]; lb = [2 9]; ub = [9 16];
opts = optimoptions('fmincon', 'Display', 'iter', 'FiniteDifferenceStepSize', [0.05 0.05], 'OptimalityTolerance', 1e-4);
[z, fval] = fmincon(obj, z0, [], [], [], [], lb, ub, [], opts);
best = mk(z);
r0 = hotlap.simulateLap(base, 'track', T, 'time', 100); r1 = hotlap.simulateLap(best, 'track', T, 'time', 100);
R = struct('ClA', z(1), 'CdA', best.CdA, 'G', z(2), 'estimate', fval, 'estimateStart', obj(z0), ...
    'aiStart', r0.laps.time(end), 'aiBest', r1.laps.time(end), 'vals', best, 'dragFit', pc);
fprintf(['\nstart: ClA %.2f, CdA %.2f, G %.2f -> estimate %.3f s, AI %.3f s\n' ...
         'best:  ClA %.2f, CdA %.2f, G %.2f -> estimate %.3f s, AI %.3f s\n'], ...
    base.ClA, base.CdA, base.G, R.estimateStart, R.aiStart, R.ClA, R.CdA, R.G, R.estimate, R.aiBest);
fprintf('Save it as a setup with: hotlap.saveSetup(hotlap.customSetup(''c-opt'', ''Optimised aero + gearing'', ''tau-lts'', R.vals))\n');
end
