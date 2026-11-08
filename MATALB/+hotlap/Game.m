classdef Game < handle
%HOTLAP.GAME  HoMo-LAP in a MATLAB figure: the FAUmax tau on the FSG endurance track.
%   g = hotlap.Game(entry, mode) opens the game window; g.run() plays until the window closes or
%   you quit from the pause screen. Usually started from HoMoLap (the launcher).
%     entry  setup entry from hotlap.loadSetups (stock aero package or custom setup)
%     mode   'sim' (hot lap: team data, FS Rules penalties), 'arcade' (forgiving, drift-friendly
%            handling, no penalties) or 'free' (free roam on the paddock, no lap timing)
%   Options (name, value): 'assist' (true), 'camera' (1 chase, 2 onboard, 3 high, 4 top-down),
%   'autodrive' (false: the AI drives), 'maxTime' (inf: stop after this many seconds of game time),
%   'visible' (true), 'ghost' (true).
%
%   Keys: arrows or WASD drive, Space handbrake (slides in arcade), R back on track, C camera,
%   G ghosts, Esc or P pause (Q in the pause screen quits, Enter restarts).
%
%   Same physics, rules and best-lap keys as the web game; best laps are saved in saves\bests.mat.

    properties
        entry; mode; assist = true; camMode = 1; autodrive = false; ghostOn = true; maxTime = inf
        T; C; P; car; f; carMesh
        state = 'countdown'; resumeTo = 'race'; clock = 0; running = true; result
        keys = struct('up', false, 'down', false, 'left', false, 'right', false, 'hb', false)
        lap; laps = zeros(0, 4); last; bests = struct(); bestsFile
        cones; skid = zeros(2, 0); skN = 0; looping = false; fr; cd = struct('t', 0, 'hold', 1)
        msgT = 0; hudT = 0; camYaw = 0; camSnap = true; spin = 0; gp = 1; wrongT = 0; oc = false; sub = 0
        fps = 0; frames = 0
        % graphics
        fig; ax; hax; mapAx; carT; wheels; ghostPB; ghostLTS; conePatch; coneLocal; coneBig
        grassT; grassF; freePad; freeLines; treesT; treesFr; skidLine; H = struct()
    end

    properties (Constant)
        DT = 1 / 600
        CAMS = {'Chase', 'Onboard', 'High', 'Top-down'}
        COL = struct('signal', [0.91 0.13 0.16], 'gold', [1 0.78 0.24], 'fast', [0.24 0.86 0.52], ...
            'best', [0.71 0.42 1], 'paper', [0.95 0.95 0.92], 'muted', [0.56 0.58 0.62], 'ink', [0.04 0.05 0.06])
    end

    methods
        function g = Game(entry, mode, varargin)
            if nargin < 1 || isempty(entry), E = hotlap.loadSetups(); entry = E(1); end
            if nargin < 2 || isempty(mode), mode = 'sim'; end
            o = struct('assist', true, 'camera', 1, 'autodrive', false, 'maxTime', inf, 'visible', true, 'ghost', true);
            for k = 1:2:numel(varargin), o.(varargin{k}) = varargin{k + 1}; end
            g.entry = entry; g.mode = mode; g.assist = o.assist; g.camMode = o.camera; g.autodrive = o.autodrive;
            g.maxTime = o.maxTime; g.ghostOn = o.ghost;
            g.T = hotlap.loadTrack();
            g.C = hotlap.carParams(entry.vals);
            g.P = hotlap.physicsData(g.T, g.C, mode);
            f = fullfile(hotlap.root(), 'data', 'car_mesh.mat');
            if exist(f, 'file'), g.carMesh = load(f); else, g.carMesh = []; end
            g.bestsFile = fullfile(hotlap.userDir('saves'), 'bests.mat');
            if exist(g.bestsFile, 'file'), s = load(g.bestsFile); g.bests = s.bests; end
            n = numel(g.T.cones.x0);
            g.cones = struct('x', g.T.cones.x0, 'y', g.T.cones.y0, 'vx', zeros(n, 1), 'vy', zeros(n, 1), 'a', zeros(n, 1), 'w', zeros(n, 1), ...
                'down', false(n, 1), 'on', ~g.T.cones.free | strcmp(mode, 'free'), 'dirty', true);
            g.resetLap(); g.frReset();
            g.buildFigure(o.visible);
            g.toGrid();
            if strcmp(mode, 'free'), g.state = 'race'; g.showMsg('Free roam', 'fast', 2, 'Drive anywhere · R takes you back to the start');
            else, g.state = 'countdown'; g.cd.t = 0; g.cd.hold = 0.5 + rand * 0.8; end
        end

        function R = run(g)
            % main loop: fixed 1/600 s physics, render once per frame
            t0 = tic; lastT = 0; acc = 0; f0 = 0; tf = 0; g.looping = true;
            while g.running && isvalid(g.fig)
                now = toc(t0); dt = min(now - lastT, 0.1); lastT = now;
                if ~strcmp(g.state, 'paused')
                    acc = acc + dt; n = floor(acc / g.DT); acc = acc - n * g.DT;
                    g.update(n); g.post(dt);
                end
                g.render(dt); g.hud(dt);
                drawnow;
                g.frames = g.frames + 1;
                if now - tf > 1, g.fps = (g.frames - f0) / (now - tf); f0 = g.frames; tf = now; end
                if g.clock > g.maxTime, g.running = false; end
            end
            g.looping = false;
            R = g.finish();
        end

        function R = runFixed(g, seconds, fps)
            % deterministic run for tests: advance game time at a fixed frame rate (no real-time wait)
            if nargin < 3, fps = 60; end
            n = round(seconds * fps); t0 = tic;
            for k = 1:n
                if ~strcmp(g.state, 'paused'), g.update(round(1 / fps / g.DT)); g.post(1 / fps); end
                if mod(k, max(1, round(fps / 10))) == 0, g.render(1 / fps); g.hud(1 / fps); drawnow; end
            end
            g.fps = n / toc(t0);
            R = g.summary();
        end

        function R = finish(g)
            R = g.summary();
            g.saveBests();
            if isvalid(g.fig), delete(g.fig); end
        end

        function R = summary(g)
            R.laps = array2table(g.laps, 'VariableNames', {'lap', 'time', 'valid', 'penalty'});
            R.laps.valid = logical(R.laps.valid);
            k = hotlap.bestKey(g.entry, g.mode, g.assist); fk = matlab.lang.makeValidName(k);
            if isfield(g.bests, fk), R.best = g.bests.(fk).t; else, R.best = NaN; end
            R.key = k; R.mode = g.mode; R.setup = g.entry.name; R.fps = g.fps; R.fr = g.fr;
        end
    end

    %% ---------------- simulation ----------------
    methods
        function update(g, n)
            for k = 0:n - 1
                g.clock = g.clock + g.DT;
                switch g.state
                    case 'countdown'
                        g.cd.t = g.cd.t + g.DT;
                        if g.cd.t >= 3.0 + g.cd.hold
                            g.state = 'race'; g.showMsg('Go', 'fast', 0.9, '');
                        end
                    case 'race'
                        if mod(k, 4) == 0
                            if g.autodrive, inp = hotlap.aiDriver(g.car, g.T, g.P.vPlan); else, inp = g.playerInput(); end
                            inp.arcade = ~strcmp(g.mode, 'sim'); g.H.inp = inp;
                        end
                        [g.car, g.f] = hotlap.physicsStep(g.car, g.H.inp, g.C, g.P, g.DT);
                        g.sub = g.sub + 1;
                        if strcmp(g.mode, 'free'), g.freeUpdate(g.DT); end
                        if mod(g.sub, 4) == 0
                            prev = g.car.s;
                            nr = hotlap.nearestPoint(g.T, g.car.x, g.car.y); g.car.s = nr.s; g.car.lat = nr.lat; g.H.nearI = nr.i;
                            g.car.grass = hotlap.surfaceGrass(g.T, g.car.x, g.car.y, g.mode);
                            if ~strcmp(g.mode, 'free')
                                g.lapUpdate(prev, g.car.s, 4 * g.DT);
                                out = abs(g.car.lat) > g.T.HALF + 0.72;
                                if out && ~g.oc
                                    g.oc = true;
                                    if strcmp(g.mode, 'sim'), g.addPenalty(10, 'Off course', '+10 s · all four wheels outside the cones, D 10.1.5'); end
                                elseif ~out && abs(g.car.lat) < g.T.HALF
                                    g.oc = false;
                                end
                                if g.car.outT > 1.5, g.car.outT = 0; g.backOnTrack(); g.showMsg('Back on track', 'gold', 1.4, 'You left the event area'); end
                                i = g.H.nearI; along = g.car.vx * cos(g.car.h - atan2(g.T.TTY(i), g.T.TTX(i)));
                                if along < -1.5, g.wrongT = g.wrongT + 4 * g.DT; else, g.wrongT = 0; end
                            elseif g.car.outT > 1.5
                                g.car.outT = 0; g.showMsg('Edge of the paddock', 'gold', 1.2, 'Turn around or press R');
                            end
                        end
                end
            end
        end

        function inp = playerInput(g)
            K = g.keys;
            inp = hotlap.driverInput(double(K.right) - double(K.left), double(K.up), double(K.down), K.hb, g.assist, true, false);
        end

        function post(g, dt)
            if ~strcmp(g.state, 'countdown'), g.conesUpdate(dt); g.skids(); end
            if g.msgT > 0, g.msgT = g.msgT - dt; if g.msgT <= 0, g.H.msgT.String = ''; g.H.msgS.String = ''; end, end
            if strcmp(g.state, 'race') && g.wrongT > 0.8 && g.msgT <= 0, g.showMsg('Wrong way', 'gold', 0.6, 'Turn around or press R'); end
        end

        function resetLap(g)
            g.lap = struct('active', false, 't0', 0, 'next', 1, 'valid', true, 'splits', [0 0], 'prog', 0, 'rec', zeros(0, 5), 'recT', 0, 'n', 0, 'pen', 0);
        end

        function toGrid(g)
            if strcmp(g.mode, 'free')
                g.car = hotlap.carState(g.T, 0); g.car.x = g.T.ACC.x - 1.6; g.car.y = g.T.ACC.y; g.car.h = 0;
            else
                g.car = hotlap.carState(g.T, g.T.GRID_S);
            end
            nr = hotlap.nearestPoint(g.T, g.car.x, g.car.y); g.car.s = nr.s; g.car.lat = nr.lat; g.H.nearI = nr.i;
            g.f = struct('Fdown', 0, 'Fdrag', 0, 'capF', 0, 'capR', 0, 'Fxf', 0, 'Fxr', 0, 'Fyf', 0, 'Fyr', 0, 'af', 0, 'ar', 0, 'beta', 0, 'ClAe', g.C.ClA, 'P', 0, 'ax', 0, 'ay', 0, 'Fz', 0);
            g.H.inp = hotlap.driverInput(0, 0, 0);
            n = g.resetLapKeepCount(); g.lap.n = n;
            g.resetCones(false); g.skid = zeros(2, 0); g.skN = 0; g.frReset(); g.camSnap = true; g.wrongT = 0;
        end

        function n = resetLapKeepCount(g)
            n = g.lap.n; g.resetLap();
        end

        function backOnTrack(g)
            if strcmp(g.mode, 'free')
                g.toGrid(); g.showMsg('Back to the start', 'fast', 1.2, 'Acceleration strip'); return;
            end
            g.invalidate('Reset', sprintf('Lap %d will not count', g.lap.n));
            s = g.car.s; n = g.lap.n; lp = g.lap;
            g.car = hotlap.carState(g.T, s); g.lap = lp; g.lap.n = n; g.camSnap = true;
        end

        function startLap(g, tc, s)
            g.lap.active = true; g.lap.t0 = tc; g.lap.next = 1; g.lap.valid = true; g.lap.splits = [0 0]; g.lap.pen = 0;
            g.lap.prog = s; g.lap.n = g.lap.n + 1; g.lap.rec = [g.clock - tc, g.car.x, g.car.y, g.car.h, s]; g.lap.recT = g.clock; g.gp = 1;
            g.resetCones(true); g.paintSectors();
        end

        function lapUpdate(g, prev, s, dt)
            L = g.T.LEN; d = s - prev;
            if d > L / 2, d = d - L; elseif d < -L / 2, d = d + L; end
            tEnd = g.clock; tStart = g.clock - dt;
            if g.lap.active
                if abs(d) > 12, g.invalidate('Track cut', sprintf('Lap %d will not count', g.lap.n)); end
                g.lap.prog = g.lap.prog + d;
                if g.lap.next < 3 && d > 0
                    B = g.lap.next * L / 3;
                    if prev < B && s >= B
                        ts = tStart + (tEnd - tStart) * (B - prev) / (s - prev) - g.lap.t0;
                        g.lap.splits(g.lap.next) = ts; g.onSector(g.lap.next, ts); g.lap.next = g.lap.next + 1;
                    end
                end
                if g.clock - g.lap.recT >= 1 / 30
                    g.lap.recT = g.clock; g.lap.rec(end+1, :) = [g.clock - g.lap.t0, g.car.x, g.car.y, g.car.h, g.lap.prog];
                end
            end
            if d > 0 && s < prev
                tc = tStart + (tEnd - tStart) * min(max((L - prev) / d, 0), 1);
                if g.lap.active && g.lap.next == 3, g.finishLap(tc); end
                g.startLap(tc, s);
            elseif d < 0 && s > prev && g.lap.active
                g.lap.active = false; g.showMsg('Lap aborted', 'signal', 1.6, 'Crossed the line backwards');
            end
        end

        function onSector(g, k, ts)
            st = ts - (k > 1) * g.lap.splits(max(k - 1, 1));
            g.paintSector(k, st);
            if ~g.lap.valid, return; end
            b = g.bestNow(); dl = ts - g.T.lts.splits(k);
            if isempty(b), g.showMsg(sprintf('Sector %d', k), 'gold', 1.6, sprintf('%s to the LTS lap', fmtD(dl, 2)));
            else
                d = ts - b.splits(k); c = 'gold'; if d < 0, c = 'fast'; end
                g.showMsg(sprintf('Sector %d  %s', k, fmtD(d, 2)), c, 1.6, sprintf('%s to the LTS lap', fmtD(dl, 2)));
            end
        end

        function finishLap(g, tc)
            raw = tc - g.lap.t0; t = raw + g.lap.pen;
            s = [g.lap.splits(1), g.lap.splits(2) - g.lap.splits(1), raw - g.lap.splits(2)];
            g.paintSector(3, s(3));
            g.lap.rec(end+1, :) = [raw, g.car.x, g.car.y, g.car.h, g.T.LEN];
            penTxt = ''; if g.lap.pen, penTxt = sprintf('  incl. +%d s', g.lap.pen); end
            if g.lap.valid
                b = g.bestNow(); k = matlab.lang.makeValidName(hotlap.bestKey(g.entry, g.mode, g.assist));
                if isempty(b) || t < b.t
                    g.bests.(k) = struct('key', hotlap.bestKey(g.entry, g.mode, g.assist), 't', t, 'raw', raw, 'sectors', s, 'splits', g.lap.splits, 'ghost', g.lap.rec);
                    if isempty(b), ttl = 'Lap set'; else, ttl = 'New best lap'; end
                    g.showMsg(ttl, 'best', 2.6, sprintf('%s%s   %s to LTS', fmt(t), penTxt, fmtD(t - g.T.lts.lapTime, 2)));
                    g.saveBests();
                else
                    g.showMsg(fmt(t), 'gold', 2.4, sprintf('%s to your best%s', fmtD(t - b.t, 3), penTxt));
                end
            else
                g.showMsg('Lap invalid', 'signal', 2.4, [fmt(t) ' · cut the track, not counted']);
            end
            g.laps(end+1, :) = [g.lap.n, t, g.lap.valid, g.lap.pen];
            g.last = struct('t', t, 'valid', g.lap.valid);
        end

        function invalidate(g, reason, sub)
            if ~g.lap.active || ~g.lap.valid, return; end
            g.lap.valid = false; g.showMsg(reason, 'signal', 1.8, sub);
        end

        function addPenalty(g, sec, label, sub)
            if ~g.lap.active, return; end
            g.lap.pen = g.lap.pen + sec; g.showMsg(label, 'gold', 1.2, sub);
        end

        function b = bestNow(g)
            k = matlab.lang.makeValidName(hotlap.bestKey(g.entry, g.mode, g.assist));
            if isfield(g.bests, k), b = g.bests.(k); else, b = []; end
        end

        function saveBests(g)
            bests = g.bests; %#ok<PROPLC>
            try, save(g.bestsFile, 'bests'); catch, end
        end

        function frReset(g)
            g.fr = struct('top', 0, 'dist', 0, 'armed', true, 'run', false, 't', 0, 'd', 0, 'got100', false, 'got75', false, 't100', NaN, 't75', NaN, 'b100', NaN, 'b75', NaN);
            if ~isempty(g.fr) && isfield(g.H, 'frBest'), g.fr.b100 = g.H.frBest(1); g.fr.b75 = g.H.frBest(2); end
        end

        function freeUpdate(g, dt)
            % free roam: 0-100 km/h and 75 m timed from every standing start
            F = g.fr; v = hypot(g.car.vx, g.car.vy);
            F.top = max(F.top, v); F.dist = F.dist + v * dt;
            if v < 0.3 && g.car.thr < 0.05, F.armed = true; F.run = false; g.fr = F; return; end
            if F.armed && v >= 0.3, F.armed = false; F.run = true; F.t = 0; F.d = 0; F.got100 = false; F.got75 = false; end
            if F.run
                F.t = F.t + dt; F.d = F.d + max(g.car.vx, 0) * dt;
                if ~F.got100 && v >= 100 / 3.6
                    F.got100 = true; F.t100 = F.t; F.b100 = min(F.b100, F.t); if isnan(F.b100), F.b100 = F.t; end
                    g.showMsg('0–100 km/h', 'fast', 1.6, sprintf('%.2f s', F.t));
                end
                if ~F.got75 && F.d >= 75
                    F.got75 = true; F.t75 = F.t; F.b75 = min(F.b75, F.t); if isnan(F.b75), F.b75 = F.t; end
                    g.showMsg('75 m', 'fast', 1.6, sprintf('%.3f s · %d km/h', F.t, round(v * 3.6)));
                end
                if (F.got100 && F.got75) || F.t > 30, F.run = false; end
            end
            g.H.frBest = [F.b100 F.b75];
            g.fr = F;
        end

        function resetCones(g, keepNear)
            c = g.cones;
            for i = find(c.down)'
                if keepNear && hypot(g.T.cones.x0(i) - g.car.x, g.T.cones.y0(i) - g.car.y) < 8, continue; end
                c.down(i) = false; c.x(i) = g.T.cones.x0(i); c.y(i) = g.T.cones.y0(i); c.vx(i) = 0; c.vy(i) = 0; c.w(i) = 0; c.a(i) = 0;
            end
            c.dirty = true; g.cones = c;
        end

        function conesUpdate(g, dt)
            c = g.cones; ch = cos(g.car.h); sh = sin(g.car.h); sp = hypot(g.car.vx, g.car.vy);
            dx = c.x - g.car.x; dy = c.y - g.car.y;
            near = find(c.on & dx.^2 + dy.^2 < 9);
            for i = near'
                lx = dx(i) * ch + dy(i) * sh; ly = -dx(i) * sh + dy(i) * ch; rad = 0.12 + 0.05 * g.T.cones.big(i);
                if lx > -1.45 - rad && lx < 1.42 + rad && abs(ly) < 0.72 + rad
                    wx = g.car.vx * ch - g.car.vy * sh; wy = g.car.vx * sh + g.car.vy * ch;
                    if ~c.down(i) && sp > 0.4
                        c.down(i) = true; s = sign(ly) + (ly == 0);
                        c.vx(i) = wx * 1.15 - s * sh * 1.5; c.vy(i) = wy * 1.15 + s * ch * 1.5;
                        c.w(i) = (rand - 0.5) * 18; c.a(i) = atan2(c.vy(i), c.vx(i));
                        if strcmp(g.state, 'race') && g.lap.active && strcmp(g.mode, 'sim'), g.addPenalty(2, 'Cone down', '+2 s · down or out, D 10.1.4'); end
                    elseif c.down(i) && sp > 0.5
                        c.vx(i) = wx * 1.05; c.vy(i) = wy * 1.05;
                    end
                    c.dirty = true;
                end
            end
            mv = find(c.down & (c.vx ~= 0 | c.vy ~= 0 | c.w ~= 0));
            for i = mv'
                c.x(i) = c.x(i) + c.vx(i) * dt; c.y(i) = c.y(i) + c.vy(i) * dt; c.a(i) = c.a(i) + c.w(i) * dt;
                v = hypot(c.vx(i), c.vy(i)); dv = 7 * dt;
                if v <= dv, c.vx(i) = 0; c.vy(i) = 0; else, c.vx(i) = c.vx(i) * (v - dv) / v; c.vy(i) = c.vy(i) * (v - dv) / v; end
                c.w(i) = c.w(i) * max(0, 1 - 3 * dt); if abs(c.w(i)) < 0.05, c.w(i) = 0; end
                c.dirty = true;
            end
            g.cones = c;
        end

        function skids(g)
            % skid marks from sliding or locked wheels (the four contact patches)
            if abs(g.car.vx) < 3 || g.car.grass, g.H.skPrev = []; return; end
            f = g.f; ap = g.C.ap;
            lockF = f.capF > 0 && abs(f.Fxf) > 0.88 * f.capF && g.car.brk > 0.5;
            lockR = (f.capR > 0 && abs(f.Fxr) > 0.88 * f.capR && g.car.brk > 0.5) || g.H.inp.hb;
            slipF = abs(f.af) > ap * 1.25 || lockF; slipR = abs(f.ar) > ap * 1.25 || lockR;
            if ~slipF && ~slipR, g.H.skPrev = []; return; end
            W = [g.C.a -g.C.tf/2; g.C.a g.C.tf/2; -g.C.b -g.C.tr/2; -g.C.b g.C.tr/2];
            ch = cos(g.car.h); sh = sin(g.car.h);
            p = [g.car.x + W(:, 1) * ch - W(:, 2) * sh, g.car.y + W(:, 1) * sh + W(:, 2) * ch];
            use = [slipF; slipF; slipR; slipR];
            if isfield(g.H, 'skPrev') && ~isempty(g.H.skPrev)
                q = g.H.skPrev; u = find(use);
                xs = [q(u, 1)'; p(u, 1)'; nan(1, numel(u))]; ys = [q(u, 2)'; p(u, 2)'; nan(1, numel(u))];
                g.skid = [g.skid, [xs(:)'; ys(:)']];
                if size(g.skid, 2) > 9000, g.skid = g.skid(:, end - 8999:end); end
            end
            g.H.skPrev = p;
        end
    end

    %% ---------------- input ----------------
    methods
        function onKey(g, e, down)
            switch e.Key
                case {'uparrow', 'w'}, g.keys.up = down;
                case {'downarrow', 's'}, g.keys.down = down;
                case {'leftarrow', 'a'}, g.keys.left = down;
                case {'rightarrow', 'd'}, g.keys.right = down;
                case 'space', g.keys.hb = down;
            end
            if ~down, return; end
            switch e.Key
                case {'escape', 'p'}
                    if any(strcmp(g.state, {'race', 'countdown'})), g.resumeTo = g.state; g.state = 'paused'; g.H.pause.Visible = 'on'; g.clearKeys();
                    elseif strcmp(g.state, 'paused'), g.state = g.resumeTo; g.H.pause.Visible = 'off'; end
                case 'q'
                    if strcmp(g.state, 'paused'), g.running = false; end
                case 'return'
                    if strcmp(g.state, 'paused')
                        g.H.pause.Visible = 'off'; g.laps = zeros(0, 4); g.last = []; g.lap.n = 0; g.toGrid();
                        if strcmp(g.mode, 'free'), g.state = 'race'; else, g.state = 'countdown'; g.cd.t = 0; g.cd.hold = 0.5 + rand * 0.8; end
                    end
                case 'r'
                    if strcmp(g.state, 'race'), g.backOnTrack(); end
                case 'c'
                    g.camMode = mod(g.camMode, 4) + 1; g.camSnap = true; g.showMsg(['Camera: ' g.CAMS{g.camMode}], 'fast', 0.8, '');
                case 'g'
                    g.ghostOn = ~g.ghostOn; g.showMsg(['Ghost cars: ' onoff(g.ghostOn)], 'fast', 0.8, '');
            end
        end

        function clearKeys(g)
            for k = fieldnames(g.keys)', g.keys.(k{1}) = false; end
        end
    end

    %% ---------------- graphics ----------------
    methods
        function buildFigure(g, visible)
            T = g.T; C = g.COL;
            g.fig = figure('Name', ['HoMo-LAP · ' g.entry.car ' ' g.entry.name ' · ' modeName(g.mode)], 'NumberTitle', 'off', ...
                'Color', [0.725 0.83 0.92], 'MenuBar', 'none', 'ToolBar', 'none', 'Position', [60 60 1280 720], ...
                'Visible', onoff(visible), 'Renderer', 'opengl', 'GraphicsSmoothing', 'on', ...
                'WindowKeyPressFcn', @(~, e) g.onKey(e, true), 'WindowKeyReleaseFcn', @(~, e) g.onKey(e, false), ...
                'CloseRequestFcn', @(~, ~) g.stop(), 'WindowState', 'normal');
            ax = axes(g.fig, 'Units', 'normalized', 'Position', [0 0 1 1], 'Visible', 'off', 'Projection', 'perspective', ...
                'Clipping', 'off', 'DataAspectRatio', [1 1 1], 'SortMethod', 'depth', 'HitTest', 'off');
            Wd = T.WORLD_F + [-400 -400 400 400];
            ax.XLim = [Wd(1) Wd(3)]; ax.YLim = [-Wd(4) -Wd(2)]; ax.ZLim = [-1 40];
            ax.CameraPositionMode = 'manual'; ax.CameraTargetMode = 'manual'; ax.CameraUpVectorMode = 'manual'; ax.CameraViewAngleMode = 'manual';
            ax.CameraUpVector = [0 0 1];
            hold(ax, 'on'); g.ax = ax;
            light(ax, 'Position', [-0.5 0.4 1], 'Style', 'infinite', 'Color', [1 0.97 0.9]);
            light(ax, 'Position', [0.6 -0.5 0.4], 'Style', 'infinite', 'Color', [0.35 0.38 0.42]);
            % ground: rings around the paved areas, so no surfaces overlap
            A = T.APRON; F = T.FREE; big = T.WORLD_F + [-600 -600 600 600];
            grass = [0.25 0.45 0.22];
            g.grassT = ring(ax, big, A, 0, grass);
            g.grassF = ring(ax, big, F, 0, grass);
            g.freePad = ring(ax, F, A, 0, [0.37 0.38 0.4]);
            quad(ax, A, 0, [0.36 0.37 0.39]);
            % the driven line, start line and sector marks
            o = T.HALF + 0.3; Lx = T.x + T.NX * o; Ly = T.y + T.NY * o; Rx = T.x - T.NX * o; Ry = T.y - T.NY * o; N = T.N;
            V = [[Lx; Rx], -[Ly; Ry], 0.01 * ones(2 * N, 1)]; i = (1:N)'; j = mod(i, N) + 1;
            patch(ax, 'Vertices', V, 'Faces', [i j N + j N + i], 'FaceColor', [0.3 0.31 0.33], 'EdgeColor', 'none', 'FaceLighting', 'none');
            stripe(ax, T, 0, 0.3, 2 * T.HALF + 1, [0.95 0.95 0.92]);
            for k = 1:2, stripe(ax, T, k * T.LEN / 3, 0.16, 2 * T.HALF + 1, [1 0.78 0.24]); end
            % free roam: start and finish of the acceleration strip, skidpad timing line
            Ac = T.ACC; Sk = T.SKID; ln = gobjects(0);
            for dx = [0 Ac.len], ln(end+1) = patch(ax, 'XData', Ac.x + dx + [-0.15 0.15 0.15 -0.15], 'YData', -(Ac.y + [-1 -1 1 1] * (Ac.w / 2 + 0.3)), 'ZData', 0.025 * [1 1 1 1], 'FaceColor', [0.95 0.95 0.92], 'EdgeColor', 'none', 'FaceLighting', 'none'); end %#ok<AGROW>
            hw = (Sk.d - 2 * Sk.ri) / 2 + 0.3;
            ln(end+1) = patch(ax, 'XData', Sk.x + [-0.15 0.15 0.15 -0.15], 'YData', -(Sk.y + [-1 -1 1 1] * hw), 'ZData', 0.025 * [1 1 1 1], 'FaceColor', [0.95 0.95 0.92], 'EdgeColor', 'none', 'FaceLighting', 'none');
            g.freeLines = ln;
            % scenery
            g.treesT = trees(ax, T.trees); g.treesFr = trees(ax, T.treesF);
            tents(ax, T);
            g.skidLine = line(ax, nan, nan, nan, 'Color', [0.08 0.08 0.09], 'LineWidth', 2);
            % cones
            g.buildCones();
            % cars
            g.carT = hgtransform('Parent', ax);
            Hc = hotlap.drawCarMesh(ax, g.carMesh, g.carT); g.wheels = Hc;
            g.ghostPB = ghostCar(ax, [0.81 0.91 1], 'BEST'); g.ghostLTS = ghostCar(ax, [1 0.78 0.24], 'LTS');
            free = strcmp(g.mode, 'free');
            set([g.grassF; g.freePad; g.freeLines(:); g.treesFr(:)], 'Visible', onoff(free));
            set([g.grassT; g.treesT(:)], 'Visible', onoff(~free));
            g.buildHud();
        end

        function buildCones(g)
            % one patch for all cones: a six-sided cone each, coloured per face
            n = numel(g.T.cones.x0); a = (0:5)' / 6 * 2 * pi;
            base = [cos(a) sin(a) zeros(6, 1)];
            g.coneLocal = {[base * 0.11 + [0 0 0.01]; 0 0 0.33], [base * 0.15 + [0 0 0.01]; 0 0 0.48]};
            Fc = [(1:6)' [2:6 1]' 7 * ones(6, 1)];
            Fa = zeros(6 * n, 3); Cf = zeros(6 * n, 3);
            cols = struct('b', [0.18 0.44 0.84], 'y', [0.96 0.77 0.09], 'o', [1 0.48 0.1]);
            for k = 1:n
                Fa(6 * k - 5:6 * k, :) = Fc + 7 * (k - 1);
                cc = cols.(g.T.cones.col(k)); sh = [1; 0.85; 0.7; 0.75; 0.9; 1.05];
                Cf(6 * k - 5:6 * k, :) = min(1, cc .* sh);
            end
            g.coneBig = g.T.cones.big;
            g.conePatch = patch(g.ax, 'Vertices', zeros(7 * n, 3), 'Faces', Fa, 'FaceVertexCData', Cf, 'FaceColor', 'flat', 'EdgeColor', 'none', 'FaceLighting', 'none');
            g.cones.dirty = true; g.updateCones3();
        end

        function updateCones3(g)
            c = g.cones; if ~c.dirty, return; end
            n = numel(c.x); V = nan(7 * n, 3);
            for k = 1:n
                if ~c.on(k), continue; end
                L = g.coneLocal{1 + g.coneBig(k)};
                if ~c.down(k)
                    V(7 * k - 6:7 * k, :) = L + [c.x(k), -c.y(k), 0];
                else
                    d = [cos(c.a(k)), -sin(c.a(k)), 0]; up = [0 0 1]; e2 = cross(d, up);
                    P = L(:, 1) * e2 + L(:, 2) * up + L(:, 3) * d;
                    V(7 * k - 6:7 * k, :) = P + [c.x(k), -c.y(k), 0.11 + 0.04 * g.coneBig(k)];
                end
            end
            g.conePatch.Vertices = V; g.cones.dirty = false;
        end

        function buildHud(g)
            C = g.COL; mono = 'Consolas'; disp_ = 'Arial Narrow';
            hx = axes(g.fig, 'Units', 'normalized', 'Position', [0 0 1 1], 'XLim', [0 1], 'YLim', [0 1], 'Visible', 'off', 'HitTest', 'off');
            hold(hx, 'on'); g.hax = hx;
            pnl = @(x0, y0, x1, y1) patch(hx, [x0 x1 x1 x0], [y0 y0 y1 y1], C.ink, 'FaceAlpha', 0.84, 'EdgeColor', 'none');
            txt = @(x, y, s, varargin) text(hx, x, y, s, 'Color', C.paper, 'FontName', mono, 'FontSize', 11, 'Interpreter', 'none', varargin{:});
            % timing tower
            pnl(0.01, 0.6, 0.235, 0.98); patch(hx, [0.01 0.014 0.014 0.01], [0.6 0.6 0.98 0.98], C.signal, 'EdgeColor', 'none');
            g.H.lapNo = txt(0.025, 0.955, 'Out lap', 'FontName', disp_, 'FontWeight', 'bold', 'FontSize', 12, 'Color', C.muted);
            g.H.chip = txt(0.225, 0.955, '', 'HorizontalAlignment', 'right', 'FontName', disp_, 'FontWeight', 'bold', 'FontSize', 11, 'Color', C.fast);
            g.H.cur = txt(0.025, 0.895, '0:00.000', 'FontSize', 28, 'FontWeight', 'bold');
            g.H.dPb = txt(0.025, 0.835, 'vs your best  –', 'FontSize', 10.5);
            g.H.dLts = txt(0.125, 0.835, 'vs LTS  –', 'FontSize', 10.5);
            for k = 1:3
                x0 = 0.025 + (k - 1) * 0.068;
                g.H.secP(k) = patch(hx, [x0 x0 + 0.064 x0 + 0.064 x0], [0.78 0.78 0.81 0.81], [0.13 0.15 0.17], 'EdgeColor', 'none');
                g.H.secT(k) = txt(x0 + 0.032, 0.795, sprintf('S%d', k), 'HorizontalAlignment', 'center', 'FontSize', 9.5, 'Color', C.muted);
            end
            rows = {'Last', 'Best', 'LTS lap'};
            for k = 1:3
                g.H.rowK(k) = txt(0.025, 0.755 - (k - 1) * 0.033, rows{k}, 'FontSize', 10, 'Color', C.muted);
                g.H.rowV(k) = txt(0.225, 0.755 - (k - 1) * 0.033, '–:––.–––', 'HorizontalAlignment', 'right', 'FontSize', 11);
            end
            g.H.rowV(3).Color = C.gold;
            g.H.laps = txt(0.025, 0.65, '', 'FontSize', 9.5, 'Color', [0.73 0.75 0.78], 'VerticalAlignment', 'top');
            % speedometer
            pnl(0.01, 0.02, 0.2, 0.15); patch(hx, [0.01 0.014 0.014 0.01], [0.02 0.02 0.15 0.15], C.signal, 'EdgeColor', 'none');
            g.H.spd = txt(0.1, 0.095, '0', 'HorizontalAlignment', 'right', 'FontName', disp_, 'FontWeight', 'bold', 'FontSize', 40);
            txt(0.1, 0.052, 'km/h', 'HorizontalAlignment', 'right', 'FontSize', 9, 'Color', C.muted);
            g.H.kw = txt(0.115, 0.105, '0 kW', 'FontSize', 15, 'FontWeight', 'bold', 'Color', C.gold);
            g.H.rpm = txt(0.115, 0.065, '0 rpm', 'FontSize', 9.5, 'Color', C.muted);
            patch(hx, [0.02 0.19 0.19 0.02], [0.027 0.027 0.034 0.034], [0.13 0.15 0.17], 'EdgeColor', 'none');
            g.H.bar = patch(hx, [0.02 0.02 0.02 0.02], [0.027 0.027 0.034 0.034], C.gold, 'EdgeColor', 'none');
            % aero and grip
            pnl(0.37, 0.02, 0.63, 0.19);
            g.H.aeroName = txt(0.38, 0.17, [g.entry.car ' · ' g.entry.name], 'FontName', disp_, 'FontWeight', 'bold', 'FontSize', 11);
            lbl = {'Downforce', 'Drag', 'ClA with yaw loss', 'Body slip β', 'Grip limit'};
            for k = 1:5
                txt(0.38, 0.14 - (k - 1) * 0.026, lbl{k}, 'FontSize', 9.5, 'Color', C.muted, 'Interpreter', 'none');
                g.H.aero(k) = txt(0.62, 0.14 - (k - 1) * 0.026, '–', 'HorizontalAlignment', 'right', 'FontSize', 10.5);
            end
            % keys
            pnl(0.75, 0.02, 0.99, 0.1);
            txt(0.98, 0.075, '↑ ↓ ← →  drive    Space  handbrake', 'HorizontalAlignment', 'right', 'FontSize', 9, 'Color', C.muted);
            txt(0.98, 0.045, 'R  back on track    C  camera    Esc  pause', 'HorizontalAlignment', 'right', 'FontSize', 9, 'Color', C.muted);
            % messages and start lights
            g.H.msgT = txt(0.5, 0.74, '', 'HorizontalAlignment', 'center', 'FontName', disp_, 'FontWeight', 'bold', 'FontSize', 40, 'FontAngle', 'italic');
            g.H.msgS = txt(0.5, 0.675, '', 'HorizontalAlignment', 'center', 'FontSize', 15, 'FontWeight', 'bold');
            g.H.lights = plot(hx, 0.45:0.025:0.55, 0.93 * ones(1, 5), 'o', 'MarkerSize', 22, 'MarkerFaceColor', [0.17 0.05 0.06], 'MarkerEdgeColor', [0.09 0.1 0.11], 'LineWidth', 2);
            g.H.lightsOn = scatter(hx, nan, nan, 420, C.signal, 'filled');
            % pause screen
            pz = hggroup(hx);
            patch(hx, 'Parent', pz, 'XData', [0 1 1 0], 'YData', [0 0 1 1], 'FaceColor', [0.03 0.04 0.05], 'FaceAlpha', 0.72, 'EdgeColor', 'none');
            text(hx, 0.5, 0.6, 'Paused', 'Parent', pz, 'Color', C.paper, 'FontName', disp_, 'FontWeight', 'bold', 'FontSize', 48, 'FontAngle', 'italic', 'HorizontalAlignment', 'center');
            text(hx, 0.5, 0.48, sprintf('Esc  resume      Enter  restart from the grid      Q  quit to the menu\nC  camera      G  ghost cars'), 'Parent', pz, ...
                'Color', C.paper, 'FontName', mono, 'FontSize', 13, 'HorizontalAlignment', 'center');
            pz.Visible = 'off'; g.H.pause = pz;
            % minimap
            ma = axes(g.fig, 'Units', 'normalized', 'Position', [0.78 0.78 0.21 0.2], 'Color', [0.04 0.05 0.06], 'XColor', 'none', 'YColor', 'none', 'HitTest', 'off');
            hold(ma, 'on'); axis(ma, 'equal'); g.mapAx = ma;
            plot(ma, [g.T.x; g.T.x(1)], -[g.T.y; g.T.y(1)], 'Color', [0.95 0.95 0.92 0.9], 'LineWidth', 2.2);
            p0 = hotlap.poseAt(g.T, 0); plot(ma, p0.x + [-1 1] * 7 * sin(p0.h), -(p0.y + [1 -1] * 7 * cos(p0.h)), 'Color', C.signal, 'LineWidth', 2.5);
            pad = 8; ma.XLim = [min(g.T.x) - pad, max(g.T.x) + pad]; ma.YLim = [-max(g.T.y) - pad, -min(g.T.y) + pad];
            g.H.mapLts = plot(ma, nan, nan, 'o', 'MarkerSize', 7, 'Color', C.gold, 'LineWidth', 1.5);
            g.H.mapPb = plot(ma, nan, nan, 'o', 'MarkerSize', 7, 'Color', [0.81 0.91 1], 'LineWidth', 1.5);
            g.H.mapCar = plot(ma, nan, nan, 'o', 'MarkerSize', 8, 'MarkerFaceColor', C.signal, 'MarkerEdgeColor', 'w');
            g.H.mapName = text(ma, ma.XLim(1) + 3, ma.YLim(1) + 4, sprintf('FSG endurance · %s m', num2str(round(g.T.LEN))), 'Color', C.muted, 'FontSize', 8, 'FontName', mono);
            g.H.last = struct();
            if strcmp(g.mode, 'free')
                g.H.rowK(1).String = 'Top speed'; g.H.rowK(2).String = '0–100 km/h'; g.H.rowK(3).String = '75 m'; g.H.rowV(3).Color = C.paper;
                set([g.H.secP g.H.secT g.H.dPb g.H.dLts], 'Visible', 'off');
            end
            switch g.mode, case 'arcade', g.H.chip.String = 'ARCADE'; case 'free', g.H.chip.String = 'FREE ROAM'; otherwise, if g.entry.custom, g.H.chip.String = 'CUSTOM SETUP'; g.H.chip.Color = C.gold; end, end
        end

        function stop(g)
            g.running = false;
            if ~g.looping && isvalid(g.fig), delete(g.fig); end
        end

        function render(g, dt)
            c = g.car; ch = cos(c.h); sh = sin(c.h);
            % car, wheels, body roll and pitch
            off = (g.C.a - g.C.b) / 2;
            g.carT.Matrix = makehgtform('translate', [c.x + ch * off, -(c.y + sh * off), 0], 'zrotate', -c.h) * ...
                makehgtform('xrotate', max(min(-g.f.ay * 0.0016, 0.06), -0.06), 'yrotate', max(min(-g.f.ax * 0.0012, 0.04), -0.04));
            if ~strcmp(g.state, 'paused'), g.spin = g.spin + c.vx * dt / g.C.R; end
            W = g.wheels;
            for k = 1:numel(W.wheels)
                M = makehgtform('translate', W.wheelCentre(k, :));
                if W.wheelFront(k), M = M * makehgtform('zrotate', -c.delta); end
                W.wheels(k).Matrix = M * makehgtform('yrotate', mod(g.spin, 2 * pi));
            end
            % ghosts
            [gpb, glt] = g.ghostPoses();
            placeGhost(g.ghostPB, gpb); placeGhost(g.ghostLTS, glt);
            % cones and skids
            g.updateCones3();
            if ~isempty(g.skid), set(g.skidLine, 'XData', g.skid(1, :), 'YData', -g.skid(2, :), 'ZData', 0.02 * ones(1, size(g.skid, 2))); else, set(g.skidLine, 'XData', nan, 'YData', nan, 'ZData', nan); end
            % camera
            sp = hypot(c.vx, c.vy); yawT = c.h + max(min(g.f.beta, 0.6), -0.6) * 0.6;
            if g.camSnap, g.camYaw = yawT; else, g.camYaw = g.camYaw + hotlap.wrapAngle(yawT - g.camYaw) * (1 - exp(-5 * dt)); end
            cy = cos(g.camYaw); sy = sin(g.camYaw); ax = g.ax; arcCam = ~strcmp(g.mode, 'sim');
            switch g.camMode
                case 1   % chase
                    if arcCam, d = 5.0 + sp * 0.05; hgt = 1.75 + sp * 0.012; fov = 62 + 24 * min(sp / 48, 1);
                    else, d = 5.4 + sp * 0.045; hgt = 1.9 + sp * 0.012; fov = 60 + 14 * min(sp / 34, 1); end
                    pos = [c.x - cy * d, -(c.y - sy * d), hgt];
                    if ~g.camSnap, pos = ax.CameraPosition + (pos - ax.CameraPosition) * (1 - exp(-12 * dt)); end
                    tgt = [c.x + cy * 4, -(c.y + sy * 4), 0.55]; up = [0 0 1];
                case 2   % onboard
                    pos = [c.x - ch * 0.45, -(c.y - sh * 0.45), 1.08]; tgt = [c.x + ch * 12, -(c.y + sh * 12), 0.35]; fov = 72 + 8 * min(sp / 34, 1); up = [0 0 1];
                case 3   % high
                    pos = [c.x - cy * 14, -(c.y - sy * 14), 15];
                    if ~g.camSnap, pos = ax.CameraPosition + (pos - ax.CameraPosition) * (1 - exp(-6 * dt)); end
                    tgt = [c.x + cy * 6, -(c.y + sy * 6), 0]; fov = 55; up = [0 0 1];
                otherwise   % top-down
                    pos = [c.x, -c.y, 70 + sp * 1.2]; tgt = [c.x, -c.y, 0]; fov = 40; up = [cy -sy 0];
            end
            g.camSnap = false;
            set(ax, 'CameraPosition', pos, 'CameraTarget', tgt, 'CameraUpVector', up, 'CameraViewAngle', fov);
        end

        function [gpb, glt] = ghostPoses(g)
            gpb = []; glt = [];
            if ~g.ghostOn || ~g.lap.active || strcmp(g.mode, 'free'), return; end
            tl = g.clock - g.lap.t0;
            b = g.bestNow();
            if ~isempty(b) && size(b.ghost, 1) > 2 && tl <= b.ghost(end, 1)
                G = b.ghost;
                while g.gp < size(G, 1) - 1 && G(g.gp + 1, 1) < tl, g.gp = g.gp + 1; end
                while g.gp > 1 && G(g.gp, 1) > tl, g.gp = g.gp - 1; end
                a = G(g.gp, :); c = G(g.gp + 1, :); f = min(max((tl - a(1)) / max(c(1) - a(1), 1e-9), 0), 1);
                gpb = [a(2) + (c(2) - a(2)) * f, a(3) + (c(3) - a(3)) * f, a(4) + hotlap.wrapAngle(c(4) - a(4)) * f];
            end
            L = g.T.lts;
            if tl <= L.lapTime
                p = hotlap.poseAt(g.T, interp1(L.t, L.s, tl, 'linear', 'extrap') * L.scale); glt = [p.x p.y p.h];
            end
        end

        function hud(g, dt)
            g.hudT = g.hudT - dt;
            % start lights every frame during the countdown
            if strcmp(g.state, 'countdown') || (strcmp(g.state, 'paused') && strcmp(g.resumeTo, 'countdown'))
                n = min(5, floor(g.cd.t / 0.6)); xs = 0.45:0.025:0.55;
                set(g.H.lightsOn, 'XData', xs(1:n), 'YData', 0.93 * ones(1, n)); g.H.lights.Visible = 'on';
            else
                set(g.H.lightsOn, 'XData', nan, 'YData', nan); g.H.lights.Visible = 'off';
            end
            if g.hudT > 0, return; end
            g.hudT = 0.1;
            c = g.car; f = g.f; L = g.lap; C = g.COL;
            tl = 0; if L.active, tl = g.clock - L.t0; end
            if strcmp(g.mode, 'free')
                F = g.fr; setS(g.H.lapNo, 'FREE ROAM');
                tt = 0; if F.run || F.got100 || F.got75, tt = F.t; end
                setS(g.H.cur, fmt(tt));
                setS(g.H.rowV(1), sprintf('%d km/h', round(F.top * 3.6)));
                setS(g.H.rowV(2), frTxt(F.t100, F.b100, 2)); setS(g.H.rowV(3), frTxt(F.t75, F.b75, 3));
                if F.dist < 1000, ds = sprintf('%d m', round(F.dist)); else, ds = sprintf('%.2f km', F.dist / 1000); end
                setS(g.H.laps, ['Distance  ' ds]);
            else
                if L.active, setS(g.H.lapNo, sprintf('LAP %d', L.n)); else, setS(g.H.lapNo, 'OUT LAP'); end
                pen = ''; if L.active && L.pen > 0, pen = sprintf('   +%d s', L.pen); end
                if L.active && ~L.valid, pen = [pen '   INVALID']; end
                setS(g.H.cur, [fmt(tl) pen]);
                b = g.bestNow();
                if L.active && L.valid && tl > 0.5
                    if ~isempty(b)
                        d = tl + L.pen - ghostTimeAt(b.ghost, L.prog) - (b.t - b.raw);
                        setS(g.H.dPb, ['vs best ' fmtD(d, 2)]); g.H.dPb.Color = pickC(d < 0, C.fast, C.gold);
                    else
                        setS(g.H.dPb, 'vs best  no lap yet'); g.H.dPb.Color = C.paper;
                    end
                    dl = tl + L.pen - interp1(g.T.lts.s, g.T.lts.t, min(L.prog, g.T.LEN) / g.T.lts.scale, 'linear', 'extrap');
                    setS(g.H.dLts, ['vs LTS ' fmtD(dl, 2)]); g.H.dLts.Color = pickC(dl < 0, C.fast, C.gold);
                else
                    setS(g.H.dPb, 'vs best  –'); setS(g.H.dLts, 'vs LTS  –'); g.H.dPb.Color = C.paper; g.H.dLts.Color = C.paper;
                end
                if isempty(g.last), setS(g.H.rowV(1), '–:––.–––'); else, setS(g.H.rowV(1), [fmt(g.last.t) pickS(g.last.valid, '', ' ✕')]); end
                if isempty(b), setS(g.H.rowV(2), '–:––.–––'); else, setS(g.H.rowV(2), fmt(b.t)); end
                setS(g.H.rowV(3), fmt(g.T.lts.lapTime));
                s = '';
                for k = size(g.laps, 1):-1:max(1, size(g.laps, 1) - 4)
                    l = g.laps(k, :); s = [s sprintf('Lap %-3d %s%s%s\n', l(1), fmt(l(2)), pickS(l(4) > 0, sprintf('  +%d s', l(4)), ''), pickS(l(3), '', '  invalid'))]; %#ok<AGROW>
                end
                setS(g.H.laps, s);
            end
            v = abs(c.vx); arcF = 1; if ~strcmp(g.mode, 'sim'), arcF = g.C.arc.vtop; end
            setS(g.H.spd, sprintf('%d', round(v * 3.6)));
            kw = f.P / 1000; setS(g.H.kw, sprintf('%d kW', round(kw)));
            setS(g.H.rpm, sprintf('%d rpm', round(v / g.C.R * g.C.G * 60 / (2 * pi) / arcF / 100) * 100));
            pm = g.C.Pmax / 1000; if ~strcmp(g.mode, 'sim'), pm = pm * g.C.arc.power; end
            g.H.bar.XData = 0.02 + [0 1 1 0] * 0.17 * min(max(kw / pm, 0), 1);
            setS(g.H.aero(1), sprintf('%d N', round(f.Fdown))); setS(g.H.aero(2), sprintf('%d N', round(f.Fdrag)));
            setS(g.H.aero(3), sprintf('%.2f m²', f.ClAe)); setS(g.H.aero(4), sprintf('%.1f°', abs(f.beta) * 180 / pi));
            setS(g.H.aero(5), sprintf('%.2f g', (f.capF + f.capR) / (g.C.m * 9.81)));
            % minimap
            set(g.H.mapCar, 'XData', min(max(c.x, g.mapAx.XLim(1) + 3), g.mapAx.XLim(2) - 3), 'YData', min(max(-c.y, g.mapAx.YLim(1) + 3), g.mapAx.YLim(2) - 3));
            [gpb, glt] = g.ghostPoses();
            if isempty(glt), set(g.H.mapLts, 'XData', nan, 'YData', nan); else, set(g.H.mapLts, 'XData', glt(1), 'YData', -glt(2)); end
            if isempty(gpb), set(g.H.mapPb, 'XData', nan, 'YData', nan); else, set(g.H.mapPb, 'XData', gpb(1), 'YData', -gpb(2)); end
        end

        function paintSectors(g)
            for k = 1:3, g.H.secP(k).FaceColor = [0.13 0.15 0.17]; g.H.secT(k).String = sprintf('S%d', k); g.H.secT(k).Color = g.COL.muted; end
        end

        function paintSector(g, k, st)
            C = g.COL; b = g.bestNow();
            if ~g.lap.valid, col = [0.25 0.27 0.3]; tc = C.paper;
            elseif isempty(b), col = C.best; tc = [0.08 0.03 0.13];
            elseif st < b.sectors(k), col = C.fast; tc = [0.02 0.13 0.06];
            else, col = C.gold; tc = [0.16 0.11 0];
            end
            g.H.secP(k).FaceColor = col; g.H.secT(k).String = sprintf('%.2f', st); g.H.secT(k).Color = tc;
        end

        function showMsg(g, t, col, dur, s)
            c = g.COL.(col);
            g.H.msgT.String = upper(t); g.H.msgT.Color = c; g.H.msgS.String = s; g.msgT = dur;
        end
    end

    methods (Static)
        function R = selfTest(outDir)
            %SELFTEST  Headless check: AI laps in each mode, frame rate, screenshots in outDir.
            if nargin < 1, outDir = fullfile(tempdir, 'hotlap_selftest'); end
            if ~exist(outDir, 'dir'), mkdir(outDir); end
            E = hotlap.loadSetups(); R = struct();
            for m = {'sim', 'arcade', 'free'}
                g = hotlap.Game(E(1), m{1}, 'autodrive', ~strcmp(m{1}, 'free'), 'visible', false);
                g.bestsFile = fullfile(outDir, 'selftest_bests.mat'); g.bests = struct();   % keep test laps out of saves\bests.mat
                if strcmp(m{1}, 'free'), g.keys.up = true; end
                r = g.runFixed(pickS(strcmp(m{1}, 'free'), 6, 100), 60);
                g.camSnap = true; g.render(1 / 60); g.hud(1); drawnow;
                exportgraphics(g.fig, fullfile(outDir, ['game_' m{1} '.png']), 'Resolution', 96, 'BackgroundColor', 'current');
                R.(m{1}) = r; delete(g.fig);
            end
        end
    end
end

%% ---------------- helpers ----------------
function h = ring(ax, outer, inner, z, col)
% four quads around inner within outer ([x0 y0 x1 y1] in game coordinates)
o = outer; i = inner;
X = [o(1) o(3) o(3) o(1); o(1) o(3) o(3) o(1); o(1) i(1) i(1) o(1); i(3) o(3) o(3) i(3)]';
Y = [o(2) o(2) i(2) i(2); i(4) i(4) o(4) o(4); i(2) i(2) i(4) i(4); i(2) i(2) i(4) i(4)]';
h = patch(ax, X, -Y, z * ones(size(X)), col, 'EdgeColor', 'none', 'FaceLighting', 'none');
end

function quad(ax, b, z, col)
patch(ax, [b(1) b(3) b(3) b(1)], -[b(2) b(2) b(4) b(4)], z * [1 1 1 1], col, 'EdgeColor', 'none', 'FaceLighting', 'none');
end

function stripe(ax, T, s, w, len, col)
p = hotlap.poseAt(T, s); c = cos(p.h); sn = sin(p.h);
lx = [-w w w -w] / 2; ly = [-len -len len len] / 2;
patch(ax, p.x + lx * c - ly * sn, -(p.y + lx * sn + ly * c), 0.025 * [1 1 1 1], col, 'EdgeColor', 'none', 'FaceLighting', 'none');
end

function h = trees(ax, tr)
n = size(tr, 1); a = (0:7)' / 8 * 2 * pi; V = zeros(9 * n, 3); F = zeros(8 * n, 3); Cc = zeros(8 * n, 3);
for k = 1:n
    r = tr(k, 3); x = tr(k, 1); y = -tr(k, 2); ht = r * (1.1 + tr(k, 4) * 0.6) * 2.6;
    V(9 * k - 8:9 * k, :) = [x + cos(a) * r, y + sin(a) * r, 0.9 * ones(8, 1); x, y, 0.9 + ht];
    F(8 * k - 7:8 * k, :) = [(1:8)' [2:8 1]' 9 * ones(8, 1)] + 9 * (k - 1);
    Cc(8 * k - 7:8 * k, :) = hsv2rgb([0.29 + tr(k, 4) * 0.05, 0.5, 0.3 + tr(k, 4) * 0.1]) .* (0.8 + 0.25 * cos(a + 0.6));
end
h = patch(ax, 'Vertices', V, 'Faces', F, 'FaceVertexCData', Cc, 'FaceColor', 'flat', 'EdgeColor', 'none', 'FaceLighting', 'none');
end

function tents(ax, T)
A = T.APRON; n = 14; cols = [0.91 0.13 0.16; 0.18 0.44 0.84; 0.95 0.95 0.92; 0.1 0.11 0.12; 1 0.78 0.24; 0.24 0.86 0.52; 0.91 0.13 0.16];
for i = 0:n - 1
    x = A(1) + 12 + i * (A(3) - A(1) - 24) / (n - 1); y = -(A(4) + 6.5);
    [X, Y, Z] = boxXYZ([x y 1.1], [4 4 2.2]);
    patch(ax, X, Y, Z, [0.91 0.9 0.88], 'EdgeColor', 'none', 'FaceLighting', 'flat');
    patch(ax, 'Vertices', [x - 2.1 y - 2.1 2.2; x + 2.1 y - 2.1 2.2; x + 2.1 y + 2.1 2.2; x - 2.1 y + 2.1 2.2; x y 3.5], ...
        'Faces', [1 2 5; 2 3 5; 3 4 5; 4 1 5], 'FaceColor', cols(mod(i, 7) + 1, :), 'EdgeColor', 'none', 'FaceLighting', 'flat');
end
end

function [X, Y, Z] = boxXYZ(c, s)
v = [0 0 0; 1 0 0; 1 1 0; 0 1 0; 0 0 1; 1 0 1; 1 1 1; 0 1 1] - 0.5; v = v .* s + c;
F = [1 2 3 4; 5 6 7 8; 1 2 6 5; 2 3 7 6; 3 4 8 7; 4 1 5 8]';
X = reshape(v(F, 1), 4, []); Y = reshape(v(F, 2), 4, []); Z = reshape(v(F, 3), 4, []);
end

function G = ghostCar(ax, col, label)
G = hgtransform('Parent', ax);
parts = {[-0.1 0 0.3], [1.9 0.5 0.45]; [0.85 0 0.25], [0.8 0.3 0.25]; [1.2 0 0.08], [0.4 1.36 0.04]; [-1.3 0 0.95], [0.3 1.1 0.04]; ...
    [-0.2 0.42 0.24], [0.85 0.3 0.3]; [-0.2 -0.42 0.24], [0.85 0.3 0.3]; [0.765 0.62 0.2], [0.41 0.19 0.41]; [0.765 -0.62 0.2], [0.41 0.19 0.41]; ...
    [-0.765 0.6 0.2], [0.41 0.19 0.41]; [-0.765 -0.6 0.2], [0.41 0.19 0.41]};
for k = 1:size(parts, 1)
    [X, Y, Z] = boxXYZ(parts{k, 1}, parts{k, 2});
    patch(ax, X, Y, Z, col, 'Parent', G, 'FaceAlpha', 0.35, 'EdgeColor', 'none', 'FaceLighting', 'none');
end
text(ax, 0, 0, 1.9, label, 'Parent', G, 'Color', col, 'FontWeight', 'bold', 'FontSize', 12, 'HorizontalAlignment', 'center', 'BackgroundColor', [0.04 0.05 0.06]);
G.Visible = 'off';
end

function placeGhost(G, p)
if isempty(p), G.Visible = 'off'; return; end
G.Visible = 'on'; G.Matrix = makehgtform('translate', [p(1), -p(2), 0], 'zrotate', -p(3));
end

function t = ghostTimeAt(G, p)
if p <= G(1, 5), t = G(1, 1); return; end
if p >= G(end, 5), t = G(end, 1); return; end
i = find(G(:, 5) >= p, 1); a = G(i - 1, :); b = G(i, :);
t = a(1) + (b(1) - a(1)) * min(max((p - a(5)) / max(b(5) - a(5), 1e-9), 0), 1);
end

function setS(h, s)
if ~strcmp(h.String, s), h.String = s; end
end

function s = fmt(t)
if isempty(t) || ~isfinite(t), s = '–:––.–––'; return; end
m = floor(t / 60); s = sprintf('%d:%06.3f', m, t - m * 60);
end

function s = fmtD(d, dec)
if d < 0, sg = '−'; else, sg = '+'; end
s = [sg sprintf(['%.' num2str(dec) 'f'], abs(d))];
end

function s = frTxt(t, b, dec)
if isnan(t), s = '–'; return; end
s = sprintf(['%.' num2str(dec) 'f s'], t);
if b < t, s = [s sprintf([' · best %.' num2str(dec) 'f'], b)]; end
end

function s = onoff(b), if b, s = 'on'; else, s = 'off'; end, end
function c = pickC(b, x, y), if b, c = x; else, c = y; end, end
function s = pickS(b, x, y), if b, s = x; else, s = y; end, end
function s = modeName(m)
switch m, case 'arcade', s = 'Arcade'; case 'free', s = 'Free roam'; otherwise, s = 'Hot lap'; end
end
