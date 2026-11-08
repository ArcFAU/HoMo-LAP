function R = run_simulink_lap(vals, varargin)
%RUN_SIMULINK_LAP  Run HoMoLapVehicle.slx with a setup and compare with the MATLAB physics and the LTS.
%   R = run_simulink_lap() runs two laps with the stock tau (LTS aero package).
%   R = run_simulink_lap(vals, 'mode', 'arcade', 'time', 165, 'quiet', false)
%   Returns R.lapSimulink (second lap, the first flying lap), R.lapMatlab (hotlap.simulateLap with
%   the same setup), R.lts and the logged signals R.simOut. Unless quiet, plots the speed along the
%   lap against the LTS reference lap.
o = struct('mode', 'sim', 'time', 165, 'quiet', false);
for k = 1:2:numel(varargin), o.(varargin{k}) = varargin{k + 1}; end
if nargin < 1 || isempty(vals), S = hotlap.setups(); vals = S.presets(1).vals; end
here = fileparts(mfilename('fullpath')); mdl = 'HoMoLapVehicle';
if ~exist(fullfile(here, [mdl '.slx']), 'file'), build_homolap_model(); end
load_system(fullfile(here, [mdl '.slx']));
HL = homolapModelParams(vals, o.mode);
assignin(get_param(mdl, 'ModelWorkspace'), 'HL', HL);
simOut = sim(mdl, 'StopTime', num2str(o.time));
lp = squeeze(simOut.laps.Data)'; n = lp(:, 1); last = lp(:, 2);   % logged as 2 x 1 x samples
idx = find(diff([0; n]) > 0);
R.lapsSimulink = last(idx);
R.lapSimulink = NaN; if ~isempty(idx), R.lapSimulink = R.lapsSimulink(end); end
M = hotlap.simulateLap(vals, 'mode', o.mode, 'time', o.time);
R.lapsMatlab = M.laps.time; R.lapMatlab = M.best;
R.lts = HL.lts.lapTime; R.simOut = simOut;
if ~o.quiet
    st = squeeze(simOut.state.Data)'; s = st(:, 7); v = hypot(st(:, 4), st(:, 5)) * 3.6;
    % the last full lap in the log
    w = find(diff(s) < -HL.T.LEN / 2);
    figure('Name', 'HoMo-LAP · Simulink lap', 'Color', 'w');
    if numel(w) >= 2, k = w(end - 1) + 1:w(end); plot(s(k), v(k), 'LineWidth', 1.4); hold on; end
    plot(HL.lts.s, HL.lts.v * 3.6, 'Color', [0.85 0.6 0.1], 'LineWidth', 1.2);
    grid on; xlabel('Lap distance (m)'); ylabel('Speed (km/h)');
    legend(sprintf('Simulink, AI driver (%.3f s)', R.lapSimulink), sprintf('LTS reference (%.3f s)', R.lts), 'Location', 'southoutside');
    title(sprintf('FSG endurance · Simulink %.3f s · MATLAB game physics %.3f s', R.lapSimulink, R.lapMatlab));
    fprintf('Simulink lap %.3f s, MATLAB physics %.3f s, LTS %.3f s\n', R.lapSimulink, R.lapMatlab, R.lts);
end
end
