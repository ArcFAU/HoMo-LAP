function fig = SetupEditor(entry, onSave)
%SETUPEDITOR  Edit a car setup: every parameter the physics uses, with the numbers that follow.
%   SetupEditor() edits a copy of the stock tau LTS package.
%   SetupEditor(entry, onSave) edits entry (from hotlap.loadSetups). Stock packages are never
%   changed: saving them makes a custom setup. Custom setups are saved as setups\<id>.json (the
%   same fields as a setup in the web game). onSave(entry) is called after every save or delete
%   (entry is empty after a delete).
%   Wheelbase, track width and the car model stay as built.
S = hotlap.setups(); T = hotlap.loadTrack(); E = hotlap.loadSetups();
if nargin < 1 || isempty(entry), entry = E(1); end
if nargin < 2, onSave = @(e) []; end
draft = entry.vals; loaded = entry.vals;
ref = hotlap.deriveSetup(S.presets(1).vals, T).est;

fig = uifigure('Name', 'HoMo-LAP · Car setup', 'Position', [120 80 1060 760], 'Color', [0.04 0.05 0.06]);
gl = uigridlayout(fig, [5 1], 'RowHeight', {60, '1x', 140, 30, 44}, 'BackgroundColor', [0.04 0.05 0.06], 'Padding', [18 14 18 14]);
top = uigridlayout(gl, [2 3], 'ColumnWidth', {320, 320, '1x'}, 'RowHeight', {18, 28}, 'BackgroundColor', [0.04 0.05 0.06], 'Padding', 0);
lab(top, 'SETUP NAME'); lab(top, 'LOAD VALUES FROM'); lab(top, '');
if entry.custom, nm = entry.name; else, nm = [entry.name ' (custom)']; end
nameF = uieditfield(top, 'text', 'Value', nm, 'BackgroundColor', [0.13 0.15 0.17], 'FontColor', [0.95 0.95 0.92]);
items = [{'—'}, arrayfun(@(e) [e.car ' · ' e.name], E, 'UniformOutput', false)];
baseD = uidropdown(top, 'Items', items, 'ItemsData', [{''}, {E.id}], 'Value', '', 'ValueChangedFcn', @loadFrom);
title_ = uilabel(top, 'Text', 'Car setup', 'FontSize', 26, 'FontWeight', 'bold', 'FontAngle', 'italic', 'FontColor', [0.95 0.95 0.92], 'HorizontalAlignment', 'right');
title_.Layout.Row = [1 2]; title_.Layout.Column = 3;

groups = unique(S.fields(:, 2), 'stable');
grid = uigridlayout(gl, [2 3], 'BackgroundColor', [0.04 0.05 0.06], 'Padding', 0, 'RowSpacing', 12, 'ColumnSpacing', 22, 'Scrollable', 'on');
ctl = struct();
for gi = 1:numel(groups)
    rows = find(strcmp(S.fields(:, 2), groups{gi}));
    p = uigridlayout(grid, [1 + 2 * numel(rows), 3], 'ColumnWidth', {'1x', 72, 34}, 'RowHeight', [{20}, repmat({16, 24}, 1, numel(rows))], ...
        'BackgroundColor', [0.04 0.05 0.06], 'Padding', 0, 'RowSpacing', 2);
    h = uilabel(p, 'Text', upper(groups{gi}), 'FontWeight', 'bold', 'FontColor', [0.91 0.13 0.16]); h.Layout.Column = [1 3];
    for r = rows'
        f = S.fields(r, :); k = f{1};
        l = uilabel(p, 'Text', f{3}, 'FontColor', [0.79 0.8 0.82]); l.Layout.Column = [1 3];
        sl = uislider(p, 'Limits', [f{5} f{6}] * f{8}, 'MajorTicks', [], 'MinorTicks', [], 'Value', draft.(k) * f{8});
        nf = uieditfield(p, 'numeric', 'Limits', [f{5} f{6}] * f{8}, 'Value', draft.(k) * f{8}, 'ValueDisplayFormat', ['%.' num2str(f{9}) 'f'], ...
            'BackgroundColor', [0.13 0.15 0.17], 'FontColor', [0.95 0.95 0.92], 'FontName', 'Consolas');
        uilabel(p, 'Text', f{4}, 'FontColor', [0.56 0.58 0.62], 'FontName', 'Consolas');
        sl.ValueChangingFcn = @(~, e) setVal(k, e.Value, 'slider');
        sl.ValueChangedFcn = @(s, ~) setVal(k, s.Value, 'slider');
        nf.ValueChangedFcn = @(s, ~) setVal(k, s.Value, 'field');
        ctl.(k) = struct('slider', sl, 'field', nf, 'label', l, 'f', {f});
    end
end
der = uitable(gl, 'ColumnName', {}, 'RowName', {}, 'ColumnWidth', {'2x', '1x', '2x', '1x'}, 'FontName', 'Consolas', ...
    'BackgroundColor', [0.93 0.93 0.92; 1 1 1], 'ForegroundColor', [0.1 0.11 0.12]);
note = uilabel(gl, 'Text', ['Gold labels differ from the stock car. The lap estimate is a point-mass calculation on the FSG curvature, for comparing setups only; ' ...
    'run the AI lap or the Simulink model for a full lap.'], 'FontColor', [0.56 0.58 0.62], 'WordWrap', 'on');
bar = uigridlayout(gl, [1 6], 'ColumnWidth', {150, 170, 190, 130, '1x', 100}, 'BackgroundColor', [0.04 0.05 0.06], 'Padding', 0);
bSave = uibutton(bar, 'Text', 'Save', 'BackgroundColor', [0.91 0.13 0.16], 'FontColor', 'w', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) save_(false));
bNew = uibutton(bar, 'Text', 'Save as new setup', 'ButtonPushedFcn', @(~, ~) save_(true));
uibutton(bar, 'Text', 'Reset to the loaded values', 'ButtonPushedFcn', @(~, ~) reset_());
bDel = uibutton(bar, 'Text', 'Delete setup', 'ButtonPushedFcn', @(~, ~) delete_());
uilabel(bar, 'Text', '');
uibutton(bar, 'Text', 'Close', 'ButtonPushedFcn', @(~, ~) delete(fig));
if ~entry.custom
    bSave.Visible = 'off'; bDel.Visible = 'off'; bNew.Text = 'Save as my setup';
    bNew.BackgroundColor = [0.91 0.13 0.16]; bNew.FontColor = 'w'; bNew.FontWeight = 'bold';
end
refresh();

    function setVal(k, x, from)
        f = ctl.(k).f; x = min(max(x / f{8}, f{5}), f{6}); draft.(k) = x;
        if ~strcmp(from, 'slider'), ctl.(k).slider.Value = x * f{8}; end
        if ~strcmp(from, 'field'), ctl.(k).field.Value = x * f{8}; end
        refresh();
    end

    function refresh()
        for r = 1:size(S.fields, 1)
            k = S.fields{r, 1};
            if abs(draft.(k) - S.base.(k)) > 1e-9, c = [1 0.78 0.24]; else, c = [0.79 0.8 0.82]; end
            ctl.(k).label.FontColor = c;
        end
        d = hotlap.deriveSetup(draft, T); dt = d.est - ref;
        if d.vMot < d.vDrag, lim = 'motor rpm'; else, lim = 'drag'; end
        if dt < 0, sg = '−'; else, sg = '+'; end
        der.Data = {
            'Total mass', sprintf('%d kg', round(d.m)), 'Front axle, static', sprintf('%.1f %%', d.wf * 100)
            'Power to weight', sprintf('%.0f kW/t', d.pw), 'Drive force, max', sprintf('%d N', round(d.Fd))
            ['Top speed, ' lim], sprintf('%.1f km/h', d.vTop * 3.6), 'L/D', sprintf('%.2f', d.ld)
            'Downforce at 100 km/h', sprintf('%d N', round(d.down100)), 'Drag at 100 km/h', sprintf('%d N', round(d.drag100))
            'Grip at 60 km/h', sprintf('%.2f g', d.g60), 'Grip at 100 km/h', sprintf('%.2f g', d.g100)
            'Lap estimate vs stock', sprintf('%s%.2f s', sg, abs(dt)), '', ''};
    end

    function loadFrom(src, ~)
        if isempty(src.Value), return; end
        e = E(strcmp({E.id}, src.Value)); draft = e.vals; loaded = e.vals; sync();
    end

    function reset_(), draft = loaded; sync(); end

    function sync()
        for r = 1:size(S.fields, 1)
            k = S.fields{r, 1}; f = ctl.(k).f;
            ctl.(k).slider.Value = draft.(k) * f{8}; ctl.(k).field.Value = draft.(k) * f{8};
        end
        refresh();
    end

    function save_(asNew)
        name = strtrim(nameF.Value);
        if asNew || ~entry.custom
            if entry.custom, base = entry.base; else, base = entry.id; end
            e = hotlap.customSetup(['c-' lower(dec2base(round(posixtime(datetime('now')) * 1000), 36))], name, base, draft);
        else
            e = hotlap.customSetup(entry.id, name, entry.base, draft);
        end
        hotlap.saveSetup(e);
        onSave(e); delete(fig);
    end

    function delete_()
        if ~entry.custom, return; end
        if ~strcmp(uiconfirm(fig, sprintf('Delete the setup "%s"?', entry.name), 'Delete setup', 'Options', {'Delete', 'Cancel'}, 'DefaultOption', 2), 'Delete'), return; end
        f = fullfile(hotlap.userDir('setups'), [entry.id '.json']);
        if exist(f, 'file'), movefile(f, [f '.deleted']); end   % kept, not erased
        onSave([]); delete(fig);
    end
end

function lab(p, s)
uilabel(p, 'Text', s, 'FontColor', [0.56 0.58 0.62], 'FontWeight', 'bold', 'FontSize', 11);
end
