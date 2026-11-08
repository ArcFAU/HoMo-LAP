function build_standalone(outDir)
%BUILD_STANDALONE  HotLap.exe with MATLAB Compiler (runs on PCs with the free MATLAB Runtime R2024b).
%   build_standalone() writes dist\HotLap.exe with the game, the setup editor, the AI lap and the
%   data files. The Simulink lap and the Simulink model need MATLAB and are not in the executable.
%   Takes a few minutes.
root = fileparts(fileparts(mfilename('fullpath')));
if nargin < 1, outDir = fullfile(root, 'dist'); end
if ~exist(outDir, 'dir'), mkdir(outDir); end
opts = compiler.build.StandaloneApplicationOptions(fullfile(root, 'HotLap.m'), 'OutputDir', outDir, 'ExecutableName', 'HotLap', ...
    'AdditionalFiles', {fullfile(root, '+hotlap'), fullfile(root, 'data'), fullfile(root, 'SetupEditor.m')}, ...
    'TreatInputsAsNumeric', 'off', 'Verbose', 'on');
compiler.build.standaloneWindowsApplication(opts);
fprintf('wrote %s\n', fullfile(outDir, 'HotLap.exe'));
end
