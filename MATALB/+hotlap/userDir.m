function d = userDir(sub)
%HOTLAP.USERDIR  Folder for best laps (saves) and custom setups (setups).
%   In MATLAB this is the MATLAB edition's folder; in the compiled HoMoLap.exe it is
%   %LOCALAPPDATA%\HoMoLap, because the application folder is read-only there.
if isdeployed, d = fullfile(getenv('LOCALAPPDATA'), 'HoMoLap'); else, d = hotlap.root(); end
if nargin, d = fullfile(d, sub); end
if ~exist(d, 'dir'), mkdir(d); end
end
