function file = saveSetup(e)
%HOTLAP.SAVESETUP  Write a custom setup to setups\<id>.json.
J = struct('id', e.id, 'name', e.name, 'base', e.base, 'vals', e.vals);
file = fullfile(hotlap.userDir('setups'), [e.id '.json']);
fid = fopen(file, 'w', 'n', 'UTF-8'); fprintf(fid, '%s', jsonencode(J, 'PrettyPrint', true)); fclose(fid);
end
