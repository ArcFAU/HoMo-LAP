function e = customSetup(id, name, base, vals)
%HOTLAP.CUSTOMSETUP  Setup entry for a custom setup; values are limited to the editor's ranges.
S = hotlap.setups(); v = S.base;
for k = 1:size(S.fields, 1)
    f = S.fields(k, :);
    if isfield(vals, f{1}) && isnumeric(vals.(f{1})) && isfinite(vals.(f{1})), v.(f{1}) = min(max(double(vals.(f{1})), f{5}), f{6}); end
end
b = S.presets(strcmp({S.presets.id}, base));
if isempty(b), src = 'Own setup'; base = ''; else, src = ['Based on ' b.car ' ' b.name]; end
src = sprintf('%s · %d kg · %d kW · mu %.2f', src, round(v.mCar + v.mDrv), round(v.Pmax), v.mu0);
name = strtrim(regexprep(char(name), '\s+', ' ')); if isempty(name), name = 'My setup'; end
e = struct('id', char(id), 'car', 'Custom', 'name', name(1:min(end, 32)), 'src', src, 'vals', v, 'custom', true, 'base', char(base));
end
