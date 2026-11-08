function R = simulateLap(vals, varargin)
%HOTLAP.SIMULATELAP  Let the AI driver run laps with a setup, without graphics.
%   R = hotlap.simulateLap(vals) drives 2 laps from the grid with the setup vals (see hotlap.setups)
%   and returns lap times. Options (name, value):
%     'mode'    'sim' (default) or 'arcade'
%     'time'    seconds to simulate (default 165, about two laps)
%     'track'   track struct from hotlap.loadTrack (loaded if omitted)
%     'trace'   true to return a 50 Hz trace (t, x, y, v, ax, ay, s)
%   R.laps is a table with lap number, time, valid flag, cones hit, off-course count and penalty.
%   Same rules as the game: 2 s per cone down, 10 s per off-course, a cut (> 12 m jump) invalidates.
%   Example:  S = hotlap.setups(); R = hotlap.simulateLap(S.presets(1).vals); R.laps
o = struct('mode', 'sim', 'time', 165, 'track', [], 'trace', false);
for k = 1:2:numel(varargin), o.(varargin{k}) = varargin{k + 1}; end
T = o.track; if isempty(T), T = hotlap.loadTrack(); end
C = hotlap.carParams(vals);
P = hotlap.physicsData(T, C, o.mode);
arcade = ~strcmp(o.mode, 'sim');
DT = 1 / 600; n = round(o.time / DT);
c = hotlap.carState(T, T.GRID_S);
cones = [T.cones.x0 T.cones.y0]; coneDown = false(size(cones, 1), 1); coneOn = ~T.cones.free;
lap = struct('active', false, 't0', 0, 'next', 1, 'valid', true, 'splits', [0 0], 'pen', 0, 'cones', 0, 'oc', 0, 'n', 0);
laps = zeros(0, 7); oc = false; clock = 0;
tr = zeros(0, 7); trT = 0;
inp = hotlap.driverInput(0, 0, 0);
for k = 0:n - 1
    clock = clock + DT;
    if mod(k, 4) == 0, inp = hotlap.aiDriver(c, T, P.vPlan); inp.arcade = arcade; end
    [c, f] = hotlap.physicsStep(c, inp, C, P, DT);
    if mod(k, 4) == 3
        prev = c.s;
        nr = hotlap.nearestPoint(T, c.x, c.y); c.s = nr.s; c.lat = nr.lat;
        c.grass = hotlap.surfaceGrass(T, c.x, c.y, o.mode);
        % laps, sectors and cut detection
        d = c.s - prev; if d > T.LEN / 2, d = d - T.LEN; elseif d < -T.LEN / 2, d = d + T.LEN; end
        tEnd = clock; tStart = clock - 4 * DT;
        if lap.active
            if abs(d) > 12, lap.valid = false; end
            if lap.next < 3 && d > 0
                B = lap.next * T.LEN / 3;
                if prev < B && c.s >= B
                    lap.splits(lap.next) = tStart + (tEnd - tStart) * (B - prev) / (c.s - prev) - lap.t0; lap.next = lap.next + 1;
                end
            end
        end
        if d > 0 && c.s < prev
            tc = tStart + (tEnd - tStart) * min(max((T.LEN - prev) / d, 0), 1);
            if lap.active && lap.next == 3
                raw = tc - lap.t0;
                laps(end+1, :) = [lap.n, raw + lap.pen, lap.valid, lap.cones, lap.oc, lap.pen, raw]; %#ok<AGROW>
            end
            lap.active = true; lap.t0 = tc; lap.next = 1; lap.valid = true; lap.splits = [0 0]; lap.pen = 0; lap.cones = 0; lap.oc = 0; lap.n = lap.n + 1;
        end
        % off course: all four wheels outside the cones (D 10.1.5)
        out = abs(c.lat) > T.HALF + 0.72;
        if out && ~oc, oc = true; if lap.active && ~arcade, lap.pen = lap.pen + 10; lap.oc = lap.oc + 1; end
        elseif ~out && abs(c.lat) < T.HALF, oc = false;
        end
        % cones down or out (D 10.1.4), car footprint 2.9 m x 1.45 m
        dxy = cones - [c.x c.y]; near = find(coneOn & ~coneDown & sum(dxy.^2, 2) < 9);
        if ~isempty(near)
            ch = cos(c.h); sh = sin(c.h);
            lx = dxy(near, 1) * ch + dxy(near, 2) * sh; ly = -dxy(near, 1) * sh + dxy(near, 2) * ch;
            hit = near(lx > -1.57 & lx < 1.54 & abs(ly) < 0.84);
            if ~isempty(hit)
                coneDown(hit) = true;
                if lap.active && ~arcade, lap.pen = lap.pen + 2 * numel(hit); lap.cones = lap.cones + numel(hit); end
            end
        end
    end
    if o.trace && clock - trT >= 0.02
        trT = clock; tr(end+1, :) = [clock c.x c.y hypot(c.vx, c.vy) f.ax f.ay c.s]; %#ok<AGROW>
    end
end
R.laps = array2table(laps, 'VariableNames', {'lap', 'time', 'valid', 'cones', 'offCourse', 'penalty', 'raw'});
R.laps.valid = logical(R.laps.valid);
v = R.laps(R.laps.valid, :);
if isempty(v), R.best = NaN; else, R.best = min(v.time); end
R.lts = T.lts.lapTime;
if o.trace, R.trace = array2table(tr, 'VariableNames', {'t', 'x', 'y', 'v', 'ax', 'ay', 's'}); end
end
