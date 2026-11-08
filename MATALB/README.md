# Hot Lap — MATLAB edition

Hot Lap built with MathWorks products: the same FAUmax τ, FSG endurance track, team data, modes and car setups as the browser game, in MATLAB and Simulink.

- **Play:** in MATLAB R2024b, `cd 'E:\HOT LAP\MATALB'`, then `HotLap`.
- **Source of truth:** the data comes from the main project (`E:\HOT LAP`). This folder holds copies, plus the tools that rebuild them from the same sources.

| Product | Used for |
|---|---|
| MATLAB | game, launcher, setup editor, headless AI laps, track and car tools |
| Simulink | `simulink\HotLapVehicle.slx`, the car and AI driver as a model |
| Optimization Toolbox | `studies\optimize_setup.m` (fmincon) |
| MATLAB Compiler | `tools\build_standalone.m` → `dist\HotLap.exe` (optional) |

## Playing

`HotLap` opens the launcher:

1. **Choose a mode:**
   - **Hot lap:** team data and FS Rules 2027 penalties: 2 s per cone, 10 s off course, a cut invalidates the lap.
   - **Arcade:** forgiving, drift-friendly handling with more grip and power. Space starts a slide. No penalties; laps are kept separately.
   - **Free roam:** arcade handling on a large paddock with an FS skidpad and a 75 m acceleration strip. 0–100 km/h and 75 m are timed from every standing start.
2. **Choose a car setup:** one of the five stock aero packages or one of your own (**Edit setup**).
3. Press **Start**. The game opens in its own window.

| Key | Action |
|---|---|
| Arrow keys or WASD | Drive |
| Space | Handbrake (in Arcade and Free roam it starts a slide) |
| R | Back on track (Free roam: back to the start) |
| C | Camera: chase, onboard, high, top-down |
| G | Ghost cars on/off |
| Esc or P | Pause; then Q quits to the launcher and Enter restarts |

The game shows:
- lap and sector times, with deltas to your best lap and to the LTS lap
- the LTS reference lap as a gold ghost and your best lap as a blue ghost
- aero forces and the grip limit
- a minimap

Best laps are saved in `saves\bests.mat`, using the same keys as the web game.

**Other launcher buttons:**
- **AI lap:** the demo driver drives the selected setup without graphics.
- **Simulink lap:** runs the same car in the Simulink model.
- **Open Simulink model:** opens `HotLapVehicle.slx`.

## Car setups

**Edit setup** changes every parameter the physics uses:

| Group | Parameters |
|---|---|
| Aero | ClA, CdA, front aero balance |
| Mass | car mass, driver mass, front weight share, CoG height |
| Powertrain | system power limit, motor torque, gear ratio |
| Tyres | peak μ at 600 N, load sensitivity, peak slip angle |
| Brakes | front brake balance, maximum brake force |
| Chassis | front roll stiffness share, torque-vectoring authority, steering lock |

The editor also shows the numbers that follow:
- total mass, power to weight, drive force
- top speed, and whether motor rpm or drag limits it
- downforce and drag at 100 km/h, L/D
- grip at 60 and 100 km/h
- a point-mass lap estimate compared with the stock car

How setups are stored:
- Stock packages are never changed. Saving one makes a custom setup.
- Custom setups are stored as `setups\<id>.json`, with the same fields as a setup in the web game.
- A deleted setup is kept as `.json.deleted`.
- Wheelbase, track width and the car model stay as built.

## Folder layout

```
MATALB\
├─ HotLap.m              launcher (uifigure): modes, setups, AI lap, Simulink lap
├─ SetupEditor.m         setup editor
├─ +hotlap\              the game and its model, shared by everything else
│  ├─ Game.m             the game window: 3D scene, HUD, keys, laps, penalties, ghosts, modes
│  ├─ physicsStep.m      single-track car model, hot-lap and arcade handling (also used by Simulink)
│  ├─ aiDriver.m         demo driver (path follower + speed plan)
│  ├─ simulateLap.m      AI laps without graphics, with the game's lap and penalty rules
│  ├─ setups.m           stock car, setup fields, aero packages, arcade factors
│  ├─ carParams.m        physics parameters from a setup
│  ├─ deriveSetup.m      derived numbers and the point-mass lap estimate
│  ├─ loadTrack.m        track, cones, paddock, skidpad, acceleration strip, LTS lap
│  └─ ...                nearestPoint, poseAt, planSpeeds, bestKey, loadSetups, saveSetup, ...
├─ simulink\
│  ├─ build_hotlap_model.m   builds HotLapVehicle.slx (the script is the source of the model)
│  ├─ HotLapVehicle.slx      driver, vehicle dynamics and lap timing blocks
│  ├─ hotlapModelParams.m    parameter struct HL for the model
│  └─ run_simulink_lap.m     runs the model with any setup, compares with MATLAB and the LTS
├─ studies\
│  ├─ setup_sweep.m      lap time against one parameter (AI lap and estimate)
│  └─ optimize_setup.m   downforce and gear ratio for the shortest lap (fmincon)
├─ tools\
│  ├─ build_track.m      data\fsg_track.json from the LTS data (MATLAB version of source\track)
│  ├─ import_car.m       data\car_mesh.mat from blender\faumax_tau.glb, livery baked in
│  ├─ preview_car.m      renders the car from four sides (livery check)
│  └─ build_standalone.m HotLap.exe with MATLAB Compiler
├─ data\                 fsg_track.json, car_mesh.mat, livery\LIVERY_*.png, logo.png
├─ setups\               your custom setups (JSON)
└─ saves\                best laps (bests.mat)
```

## Same model as the web game

The physics, AI driver, track, cones, rules and setup values are line-by-line ports of `source\template.html`. Checks on 2026-11-08, stock τ with the LTS aero package:

| Run | Lap |
|---|---|
| Web game, AI driver | 77.42 s |
| MATLAB, `hotlap.simulateLap` | 77.405 s, 77.400 s |
| MATLAB game, AI driver | 77.422 s |
| Simulink, `HotLapVehicle.slx` | 77.473 s (driver at 150 Hz with a one-step delay) |
| Arcade, web / MATLAB | 76.48 s / 76.45 s |
| LTS reference | 75.058 s |

- **Track:** `tools\build_track.m` writes the same `fsg_track.json` as the Python scripts, to 0.000 m.
- **Cones:** both versions place 620 cones (88 of them in free roam only).

**Differences from the web game:**
- **No shared leaderboard:** it lives in the claude.ai artifact.
- **No sound and no touch controls.**
- **The livery is baked into vertex colours:** the mesh is refined where the livery changes, so the stripe shows. Fine print does not survive.

## Updating

- **Track:** `tools\build_track` reads `D:\VD\laptimesimulation` (read-only) and writes `data\fsg_track.json`. Alternatively, copy `source\fsg_track.json` from the main project.
- **Car model:**
  1. Export from Blender as described in the main README. This is a background Blender run that never saves `livery.blend`.
  2. Run `tools\import_car`, then check the result with `tools\preview_car`.
- **Livery:** copy `game\livery\LIVERY_*.png` into `data\livery\`, then run `tools\import_car` again.
- **Simulink model:** run `simulink\build_hotlap_model` again after changing its blocks. The previous model is kept as `.slx.bak`.

## Checks

```matlab
R = hotlap.Game.selfTest('C:\temp\hotlap');            % AI laps in all three modes, screenshots
R = run_simulink_lap();                               % Simulink vs MATLAB vs LTS, speed plot
S = hotlap.setups(); hotlap.simulateLap(S.presets(1).vals).laps
```

`selfTest` keeps its laps out of `saves\bests.mat`.
