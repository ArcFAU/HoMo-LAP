function fig = HoMoLap()
%HOMOLAP  HoMo-LAP, MATLAB edition: launcher for the game, the setup editor and the Simulink model.
%   Run HoMoLap from this folder (or add it to the path). Choose a mode and a car setup, then Start.
%     Hot lap    team data (vehicle-params tau, LTS tyre envelope, CFD aero), FS Rules 2027 penalties
%     Arcade     forgiving, drift-friendly handling with more grip and power; no penalties
%     Free roam  arcade handling on a large paddock with an FS skidpad and a 75 m acceleration strip
%   Edit setup changes any physics parameter and saves your own setups (setups\*.json).
%   AI lap runs the demo driver with the selected setup (no graphics) and compares with the LTS lap.
%   Simulink lap runs the same car and driver in simulink\HoMoLapVehicle.slx.
%   Best laps are kept in saves\bests.mat, with the same keys as the web game.
here = fileparts(mfilename('fullpath')); addpath(here, fullfile(here, 'simulink'), fullfile(here, 'tools'), fullfile(here, 'studies'));
S = hotlap.setups(); T = hotlap.loadTrack();
E = hotlap.loadSetups();
modes = {'sim', 'Hot lap', 'Team data and FS Rules penalties (2 s per cone, 10 s off course, cut = invalid).';
         'arcade', 'Arcade', 'Forgiving, drift-friendly handling with more grip and power. Space starts a slide. No penalties; laps kept separately.';
         'free', 'Free roam', 'Arcade handling on a large paddock with an FS skidpad and acceleration strip. 0–100 km/h and 75 m are timed from every standing start.'};
ink = [0.04 0.05 0.06]; paper = [0.95 0.95 0.92]; red = [0.91 0.13 0.16]; muted = [0.56 0.58 0.62];

fig = uifigure('Name', 'HoMo-LAP · MATLAB edition', 'Position', [100 80 980 720], 'Color', ink);
gl = uigridlayout(fig, [1 2], 'ColumnWidth', {520, '1x'}, 'BackgroundColor', ink, 'Padding', [24 18 24 18], 'ColumnSpacing', 26);
L = uigridlayout(gl, [10 1], 'RowHeight', {44, 70, 46, 18, 96, 18, '1x', 30, 46, 30}, 'BackgroundColor', ink, 'Padding', 0, 'RowSpacing', 6);
hdr = uigridlayout(L, [1 2], 'ColumnWidth', {140, '1x'}, 'BackgroundColor', ink, 'Padding', 0);
uiimage(hdr, 'ImageSource', fullfile(hotlap.root(), 'data', 'logo.png'));
uilabel(hdr, 'Text', 'FS LAP SIMULATOR · FS RULES 2027 · MATLAB EDITION', 'FontColor', red, 'FontName', 'Consolas', 'FontSize', 11);
uilabel(L, 'Text', 'HoMo-LAP', 'FontSize', 56, 'FontWeight', 'bold', 'FontAngle', 'italic', 'FontColor', paper);
uilabel(L, 'Text', 'Drive the FAUmax τ on the FSG endurance layout from the lap-time simulation, with the team''s vehicle data. The LTS reference lap drives alongside you as a gold ghost.', ...
    'FontColor', [0.79 0.8 0.82], 'WordWrap', 'on');
uilabel(L, 'Text', 'MODE', 'FontColor', muted, 'FontWeight', 'bold', 'FontSize', 11);
mg = uibuttongroup(L, 'BackgroundColor', [0.13 0.15 0.17], 'BorderType', 'none', 'SelectionChangedFcn', @(~, ~) refresh());
rb = gobjects(3, 1);
for k = 1:3
    rb(k) = uiradiobutton(mg, 'Text', modes{k, 2}, 'Position', [10 96 - 30 * k 110 22], 'FontColor', paper, 'FontWeight', 'bold');
    uilabel(mg, 'Text', modes{k, 3}, 'Position', [120 96 - 30 * k - 4 380 30], 'FontColor', muted, 'FontSize', 10.5, 'WordWrap', 'on');
end
sr = uigridlayout(L, [1 2], 'ColumnWidth', {'1x', 110}, 'BackgroundColor', ink, 'Padding', 0);
uilabel(sr, 'Text', 'CAR SETUP', 'FontColor', muted, 'FontWeight', 'bold', 'FontSize', 11);
uibutton(sr, 'Text', 'Edit setup', 'ButtonPushedFcn', @(~, ~) editSetup());
lb = uilistbox(L, 'BackgroundColor', [0.13 0.15 0.17], 'FontColor', paper, 'FontName', 'Consolas', 'ValueChangedFcn', @(~, ~) refresh());
src = uilabel(L, 'Text', '', 'FontColor', muted, 'FontSize', 10.5, 'WordWrap', 'on');
act = uigridlayout(L, [1 4], 'ColumnWidth', {150, 120, 110, '1x'}, 'BackgroundColor', ink, 'Padding', 0);
uibutton(act, 'Text', 'START', 'FontSize', 20, 'FontWeight', 'bold', 'FontAngle', 'italic', 'BackgroundColor', red, 'FontColor', 'w', 'ButtonPushedFcn', @(~, ~) start());
cbA = uicheckbox(act, 'Text', 'Assists', 'Value', true, 'FontColor', paper, 'ValueChangedFcn', @(~, ~) refresh());
cam = uidropdown(act, 'Items', {'Chase', 'Onboard', 'High', 'Top-down'}, 'ItemsData', 1:4, 'Value', 1);
uilabel(act, 'Text', '');
tools = uigridlayout(L, [1 3], 'BackgroundColor', ink, 'Padding', 0);
uibutton(tools, 'Text', 'AI lap (no graphics)', 'ButtonPushedFcn', @(~, ~) aiLap());
uibutton(tools, 'Text', 'Simulink lap', 'ButtonPushedFcn', @(~, ~) simLap());
uibutton(tools, 'Text', 'Open Simulink model', 'ButtonPushedFcn', @(~, ~) openModel());

R = uigridlayout(gl, [4 1], 'RowHeight', {18, '1x', 18, 200}, 'BackgroundColor', ink, 'Padding', 0);
uilabel(R, 'Text', 'YOUR BEST LAPS (THIS COMPUTER)', 'FontColor', muted, 'FontWeight', 'bold', 'FontSize', 11);
tb = uitable(R, 'ColumnName', {'Mode', 'Setup', 'Assists', 'Best'}, 'RowName', {}, 'ColumnWidth', {70, '1x', 60, 80}, ...
    'BackgroundColor', [0.93 0.93 0.92; 1 1 1], 'ForegroundColor', [0.1 0.11 0.12], 'FontName', 'Consolas');
uilabel(R, 'Text', 'LOG', 'FontColor', muted, 'FontWeight', 'bold', 'FontSize', 11);
logA = uitextarea(R, 'Editable', 'off', 'BackgroundColor', [0.13 0.15 0.17], 'FontColor', [0.79 0.8 0.82], 'FontName', 'Consolas', ...
    'Value', {'Keys in the game: arrows or WASD drive, Space handbrake, R back on track,', 'C camera, G ghosts, Esc pause (then Q quits, Enter restarts).', ...
    sprintf('LTS reference lap: %.3f s on %s (%s).', T.lts.lapTime, 'A_FSGend_3', 'singleTrack_endurance.json')});
fillList(E(1).id); refresh();
if isdeployed, waitfor(fig); end   % HoMoLap.exe: keep running until the launcher closes

    function m = mode(), m = modes{find(rb == mg.SelectedObject, 1), 1}; end
    function e = entry(), e = E(strcmp({E.id}, lb.Value)); end

    function fillList(sel)
        E = hotlap.loadSetups();
        lb.Items = arrayfun(@(e) sprintf('%-8s %-20s ClA %.2f  CdA %.2f  %2d %%', e.car, e.name, e.vals.ClA, e.vals.CdA, round(e.vals.bal * 100)), E, 'UniformOutput', false);
        lb.ItemsData = {E.id};
        if any(strcmp({E.id}, sel)), lb.Value = sel; else, lb.Value = E(1).id; end
    end

    function refresh()
        e = entry(); src.Text = e.src; cbA.Enable = strcmp(mode(), 'sim');
        bf = fullfile(hotlap.userDir('saves'), 'bests.mat'); rows = cell(0, 4);
        if exist(bf, 'file')
            B = load(bf); B = B.bests;
            for fn = fieldnames(B)'
                b = B.(fn{1}); k = b.key; md = 'Hot lap';
                if startsWith(k, 'arc|'), md = 'Arcade'; k = k(5:end); end
                ast = 'on'; if endsWith(k, '|raw'), ast = 'off'; k = k(1:end - 4); end
                id = strtok(k, '#'); ee = E(strcmp({E.id}, id)); nm = id; if ~isempty(ee), nm = [ee.car ' ' ee.name]; end
                rows(end+1, :) = {md, nm, ast, fmt(b.t)}; %#ok<AGROW>
            end
        end
        tb.Data = rows;
    end

    function log(s), logA.Value = [logA.Value; {s}]; scroll(logA, 'bottom'); end

    function start()
        e = entry(); m = mode();
        log(sprintf('Started %s with %s %s.', modes{strcmp(modes(:, 1), m), 2}, e.car, e.name));
        try
            g = hotlap.Game(e, m, 'assist', cbA.Value, 'camera', cam.Value);
            r = g.run();
            v = r.laps(r.laps.valid, :);
            if strcmp(m, 'free'), log(sprintf('Free roam: top speed %d km/h, best 0–100 km/h %.2f s, 75 m %.3f s.', round(r.fr.top * 3.6), r.fr.b100, r.fr.b75));
            elseif isempty(r.laps), log('No lap completed.');
            else, log(sprintf('%d laps, %d valid. Best for this setup: %s.', height(r.laps), height(v), fmt(r.best)));
            end
        catch err
            log(['Game error: ' err.message]);
        end
        refresh();
    end

    function editSetup()
        SetupEditor(entry(), @saved);
    end

    function saved(e)
        if isempty(e), fillList(E(1).id); log('Setup deleted (the file is kept as .json.deleted).');
        else, fillList(e.id); log(sprintf('Saved setup "%s" to setups\\%s.json.', e.name, e.id)); end
        refresh();
    end

    function aiLap()
        e = entry(); m = mode(); if strcmp(m, 'free'), m = 'arcade'; end
        log(sprintf('AI lap, %s, %s %s ...', m, e.car, e.name)); drawnow;
        r = hotlap.simulateLap(e.vals, 'mode', m, 'track', T);
        if isempty(r.laps), log('The AI did not finish a lap.'); return; end
        for k = 1:height(r.laps)
            l = r.laps(k, :); log(sprintf('  lap %d  %s  %s  cones %d, off course %d', l.lap, fmt(l.time), pick(l.valid, 'valid', 'invalid'), l.cones, l.offCourse));
        end
        log(sprintf('  LTS reference %s (the LTS drives the ideal line; the AI follows the centreline).', fmt(r.lts)));
    end

    function simLap()
        if isdeployed, log('The Simulink lap needs MATLAB; it is not part of HoMoLap.exe.'); return; end
        e = entry(); log(sprintf('Simulink lap with %s %s ...', e.car, e.name)); drawnow;
        try
            r = run_simulink_lap(e.vals, 'quiet', true);
            log(sprintf('  Simulink: lap %s, MATLAB physics %s, LTS %s.', fmt(r.lapSimulink), fmt(r.lapMatlab), fmt(r.lts)));
        catch err
            log(['  Simulink error: ' err.message]);
        end
    end

    function openModel()
        if isdeployed, log('The Simulink model needs MATLAB; it is not part of HoMoLap.exe.'); return; end
        f = fullfile(hotlap.root(), 'simulink', 'HoMoLapVehicle.slx');
        if ~exist(f, 'file'), log('Building simulink\HoMoLapVehicle.slx ...'); drawnow; build_homolap_model(); end
        open_system(f);
    end
end

function s = fmt(t)
if isempty(t) || ~isfinite(t), s = '–:––.–––'; return; end
m = floor(t / 60); s = sprintf('%d:%06.3f', m, t - m * 60);
end
function s = pick(b, x, y), if b, s = x; else, s = y; end, end
