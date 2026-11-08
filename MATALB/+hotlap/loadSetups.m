function E = loadSetups()
%HOTLAP.LOADSETUPS  Stock aero packages followed by the custom setups saved in setups\*.json.
%   A custom setup file holds { id, name, base, vals } (the same fields as a setup in the web game).
S = hotlap.setups();
E = S.presets;
d = dir(fullfile(hotlap.userDir('setups'), '*.json'));
for k = 1:numel(d)
    try
        J = jsondecode(fileread(fullfile(d(k).folder, d(k).name)));
        E(end+1) = hotlap.customSetup(J.id, J.name, J.base, J.vals); %#ok<AGROW>
    catch err
        warning('hotlap:setup', 'Skipped %s: %s', d(k).name, err.message);
    end
end
end
