function S = setups()
%HOTLAP.SETUPS  Stock car, setup fields and the five aero packages (same values as the web game).
%   S = hotlap.setups() returns
%     S.base     struct, the stock car: vehicle-params tau, 172 kg + 80 kg driver, 50 % front,
%                CoG 293 mm, 4 x AMK (21 N m, 12.421:1, 20,000 rpm) at the 80 kW system limit,
%                LTS tyre envelope mu 1.40 at 600 N with exponent -0.10, brake split 70/30,
%                roll stiffness 65 % front.
%     S.fields   cell array, one row per editable parameter:
%                {key, group, label, unit, min, max, step, display factor, decimals}
%     S.presets  struct array of the stock aero packages (id, car, name, src, vals)
%     S.arc      arcade factors (arcade and free-roam modes)

S.base = struct('ClA', 5.4, 'CdA', 1.7, 'bal', 0.50, 'mCar', 172, 'mDrv', 80, 'wf', 0.50, 'h', 0.293, ...
    'Pmax', 80, 'Tm', 21, 'G', 12.421, 'nmax', 20000, 'mu0', 1.40, 'muExp', -0.10, 'ap', 7, ...
    'brakeFront', 0.70, 'Fb', 9000, 'rollFront', 0.65, 'tv', 1, 'delMax', 25);

S.fields = {
    'ClA',        'Aero',       'Downforce ClA',              'm²',  0,    10,   0.05,  1,    2
    'CdA',        'Aero',       'Drag CdA',                   'm²',  0.6,  3,    0.05,  1,    2
    'bal',        'Aero',       'Aero balance, front',        '%',   0.3,  0.7,  0.01,  100,  0
    'mCar',       'Mass',       'Car mass',                   'kg',  140,  280,  1,     1,    0
    'mDrv',       'Mass',       'Driver mass',                'kg',  50,   110,  1,     1,    0
    'wf',         'Mass',       'Weight on the front axle',   '%',   0.4,  0.6,  0.005, 100,  1
    'h',          'Mass',       'CoG height',                 'mm',  0.2,  0.4,  0.001, 1000, 0
    'Pmax',       'Powertrain', 'System power limit',         'kW',  20,   120,  1,     1,    0
    'Tm',         'Powertrain', 'Motor torque, each of 4',    'N m', 8,    30,   0.5,   1,    1
    'G',          'Powertrain', 'Gear ratio',                 ': 1', 8,    18,   0.05,  1,    2
    'mu0',        'Tyres',      'Peak mu at 600 N',           '',    1,    2,    0.01,  1,    2
    'muExp',      'Tyres',      'Load sensitivity exponent',  '',    -0.3, 0,    0.01,  1,    2
    'ap',         'Tyres',      'Peak slip angle',            '°',   4,    12,   0.1,   1,    1
    'brakeFront', 'Brakes',     'Brake balance, front',       '%',   0.5,  0.85, 0.01,  100,  0
    'Fb',         'Brakes',     'Maximum brake force',        'N',   4000, 14000, 100,  1,    0
    'rollFront',  'Chassis',    'Roll stiffness, front',      '%',   0.3,  0.8,  0.01,  100,  0
    'tv',         'Chassis',    'Torque-vectoring authority', '%',   0,    2,    0.05,  100,  0
    'delMax',     'Chassis',    'Steering lock',              '°',   15,   35,   0.5,   1,    1
    };

P = {
    'tau-lts',  'τ 2026', 'LTS vehicle file',  5.40, 1.70, 0.50, 'FAUmaxTauV2.m, the aero behind the 75.06 s LTS lap'
    'tau-vp',   'τ 2026', 'vehicle-params',    4.90, 1.40, 0.55, 'ClA from the ADTM axle split 2.7 / 2.2 (status open), CdA 1.4 from 37 logs (proposed)'
    'ups-1011', 'υ 2027', 'CFD baseline 1011', 5.64, 1.90, 0.50, 'CFD_TOPO 1011_try3. Balance not recorded, 50 % assumed'
    'ups-v4k',  'υ 2027', 'CFD best V4_K',     6.94, 1.96, 0.45, 'CFD_TOPO 1016_V4_K, standard mesh. Balance 45 % from aero-exchange.md'
    'no-aero',  'τ 2026', 'No downforce',      0.00, 1.70, 0.50, 'Thought experiment: same car, wings and floor make no downforce'
    };
S.presets = struct('id', {}, 'car', {}, 'name', {}, 'src', {}, 'vals', {}, 'custom', {}, 'base', {});
for k = 1:size(P, 1)
    v = S.base; v.ClA = P{k, 4}; v.CdA = P{k, 5}; v.bal = P{k, 6};
    S.presets(k) = struct('id', P{k, 1}, 'car', P{k, 2}, 'name', P{k, 3}, 'src', P{k, 7}, 'vals', v, 'custom', false, 'base', P{k, 1});
end

% Arcade and free roam: the selected setup with more grip, power and top speed, and drift-friendly handling.
S.arc = struct('grip', 1.18, 'power', 1.75, 'force', 1.2, 'vtop', 1.45, 'grass', 0.85, 'brake', 1.35);
end
