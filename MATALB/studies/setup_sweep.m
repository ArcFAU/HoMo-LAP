function R = setup_sweep(field, values, base)
%SETUP_SWEEP  Lap time against one setup parameter: AI lap (full physics) and point-mass estimate.
%   R = setup_sweep() sweeps downforce ClA from 0 to 9 m² on the stock tau (LTS aero package).
%   R = setup_sweep(field, values, base) sweeps any field of the setup (see hotlap.setups, e.g.
%   'mCar', 'Pmax', 'mu0', 'bal', 'h') over values, starting from the setup struct base.
%   Returns a table and plots both lap times. The AI follows the centreline, so its times sit
%   above the LTS lap; compare setups with each other, not with the LTS.
%   Example:  setup_sweep('mCar', 150:10:230)
S = hotlap.setups();
if nargin < 1 || isempty(field), field = 'ClA'; end
if nargin < 2 || isempty(values), values = 0:1:9; end
if nargin < 3 || isempty(base), base = S.presets(1).vals; end
T = hotlap.loadTrack();
ai = nan(numel(values), 1); est = nan(numel(values), 1); valid = false(numel(values), 1);
for k = 1:numel(values)
    v = base; v.(field) = values(k);
    r = hotlap.simulateLap(v, 'track', T, 'time', 100);   % out lap + one flying lap
    if ~isempty(r.laps), ai(k) = r.laps.time(end); valid(k) = r.laps.valid(end); end
    est(k) = hotlap.deriveSetup(v, T).est;
    fprintf('%s = %g: AI %.3f s%s, estimate %.3f s\n', field, values(k), ai(k), repmat(' (invalid)', 1, ~valid(k)), est(k));
end
R = table(values(:), ai, valid, est, 'VariableNames', {field, 'aiLap', 'valid', 'pointMass'});
f = S.fields(strcmp(S.fields(:, 1), field), :);
figure('Name', ['Hot Lap · sweep ' field], 'Color', 'w');
yyaxis left; plot(values * f{8}, ai, 'o-', 'LineWidth', 1.4); ylabel('AI lap (s)');
yyaxis right; plot(values * f{8}, est, 's--', 'LineWidth', 1.2); ylabel('Point-mass estimate (s)');
grid on; xlabel(sprintf('%s (%s)', f{3}, f{4})); title(sprintf('FSG endurance: lap time against %s', lower(f{3})));
end
