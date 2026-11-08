function HL = homolapModelParams(vals, mode)
%HOMOLAPMODELPARAMS  Parameter struct HL for simulink\HoMoLapVehicle.slx.
%   HL = homolapModelParams(vals, mode): car parameters (hotlap.carParams), track and speed plan
%   (hotlap.physicsData), the track arrays the blocks need, and the start state on the grid.
%   mode 'sim' (default) or 'arcade'.
if nargin < 1 || isempty(vals), S = hotlap.setups(); vals = S.presets(1).vals; end
if nargin < 2, mode = 'sim'; end
T = hotlap.loadTrack(); C = hotlap.carParams(vals); P = hotlap.physicsData(T, C, mode);
HL.C = C; HL.P = P;
HL.T = struct('N', T.N, 'x', T.x, 'y', T.y, 'SEG', T.SEG, 'S', T.S, 'LEN', T.LEN, 'TTX', T.TTX, 'TTY', T.TTY, ...
    'NX', T.NX, 'NY', T.NY, 'K', T.K, 'APRON', T.APRON);
HL.c0 = hotlap.carState(T, T.GRID_S);
HL.arcade = ~strcmp(mode, 'sim');
HL.dt = 1 / 600;
HL.lts = struct('s', T.lts.s * T.lts.scale, 't', T.lts.t, 'v', T.lts.v, 'lapTime', T.lts.lapTime);
end
