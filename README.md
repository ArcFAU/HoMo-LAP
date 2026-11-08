# HoMo-LAP — FAUmax τ on the FSG endurance track

HoMo-LAP was called Hot Lap until 2026-11-08. The name Hot Lap now belongs to the planned high-end game in `high-end\`.

Browser racing game built on the team's data: the τ vehicle parameters, the LTS FSG endurance track and reference lap, the CFD aero packages and the FS Rules cone and off-course penalties.

- **Modes:** Hot lap (team data, FS Rules penalties, leaderboard), Arcade (forgiving, drift-friendly handling on the FSG track) and Free roam (a large paddock with an FS skidpad and acceleration strip).
- **Car setup:** *Edit setup* in the menu changes every physics parameter (aero, masses, CoG, power, gearing, tyres, brakes, roll balance, torque vectoring, steering lock) and saves your own setups.
- **MATLAB edition:** the same game, physics and setups in MATLAB and Simulink, in `MATALB\` (see `MATALB\README.md`).

- **Play online:** https://claude.ai/artifact/38hveqdzZbP5zHJUSUfVmb (private until you share it with the Share button on that page)
- **Play from this folder:** double-click `Play HoMo-LAP.bat`. It needs Python and an internet connection, because three.js loads from a CDN. Opening `index.html` directly does not work: the browser blocks loading the car model from `file://`.

Controls:

| Key | Action |
|---|---|
| Arrow keys or WASD | Drive |
| Space | Handbrake (in Arcade and Free roam it starts a slide) |
| R | Back on track (Free roam: back to the start) |
| C | Change camera |
| G | Ghost on/off |
| M | Mute |
| Esc or P | Pause |

Phones get on-screen touch controls.

**Modes:**
- **Hot lap:** the car as the team's data describes it. Assists, FS Rules penalties and the leaderboard apply.
- **Arcade:** the selected setup with 18 % more grip, 1.75× power and 1.45× top speed. The car counter-steers by itself, the handbrake starts a slide, and the body slip is held below 38°. No penalties; a cut still invalidates the lap. Laps are kept separately and not posted.
- **Free roam:** arcade handling on a paved paddock about 700 m × 450 m, with an FS skidpad (D 4) and a 75 m acceleration strip (D 5). No lap timing. 0–100 km/h and 75 m are timed from every standing start.

**Car setups:** *Edit setup* opens the setup editor.
- **Editing:** sliders and number fields for 18 parameters, with derived numbers: total mass, power to weight, top speed and what limits it, downforce and drag at 100 km/h, grip at 60 and 100 km/h, and a point-mass lap estimate compared with the stock car.
- **Stock packages** are never changed: saving one makes your own setup. A browser stores up to 24 setups.
- **Best laps:** a custom setup keeps its own best laps, and changing its values starts a new best.
- **Leaderboard:** custom setups are not posted. The leaderboard compares the team's stock packages.

**Leaderboard (online only):** the menu shows a shared leaderboard under the aero packages, one per package and assist setting. Each player's best valid lap is posted automatically, ranked by time including penalties, with FS points from the FS Rules 2027 endurance formula (D 9.2). Only the owner and members of his claude.ai organization can post; everyone else with the link can view it. Played from this folder, the leaderboard is hidden.

## Folder layout

```
HOT LAP\
├─ Play HoMo-LAP.bat      local launcher (source\serve.py, port 8765)
├─ MATALB\                 MATLAB/Simulink edition (own README): game, setup editor, Simulink model, studies
├─ high-end\               Hot Lap, the planned high-end game in Unreal Engine 5 (own README); nothing built yet
├─ game\                   exactly what is published online
│  ├─ index.html           the whole game (built from source\template.html)
│  ├─ car.json             car model, meshopt-compressed GLB as base64
│  ├─ car_q.json           fallback model (quantized only), used if meshopt fails
│  └─ livery\              LIVERY_Left/Right/Top/Front/Rear.png (projected livery)
├─ source\
│  ├─ template.html        game source (HTML + JS); edit this, not game\index.html
│  ├─ build_game.py        template + fsg_track.json + logo → game\index.html
│  ├─ fsg_track.json       track centreline + LTS reference lap (ghost, splits)
│  ├─ logo_small.png       menu logo
│  ├─ track\               scripts that made fsg_track.json from the LTS data
│  └─ model\               scripts that shrink the Blender export for the web
└─ blender\
   ├─ export_hotlap.py     background export from E:\UE\livery\livery.blend
   ├─ faumax_tau.glb       full export (35.7 MB, decimated to ≤3000 tris per part)
   ├─ export_info.json     export log (objects, triangle count, livery images)
   └─ LIVERY_*.png         full-resolution livery projections from the .blend
```

## Project notes

E:\HOT LAP is the project folder. Anyone working here (Claude, Codex or a person) first reads `AGENTS.md`. These notes record the project:

| File | What it holds |
|---|---|
| `CHAT_HISTORY.md` | Append-only log of every task: requests and replies verbatim, plus a work record |
| `STATUS.md` | Current state and open items |
| `DECISIONS.md` | Why things are built the way they are |
| `CHANGELOG.md` | Changes players see |

## Changing the game

1. Edit `source\template.html`.
2. Run `python source\build_game.py`. This writes `game\index.html` and stamps the build time into the menu ("Build …").
3. Test it with `Play HoMo-LAP.bat`.

**Removing the touch controls:** set `const TOUCH_CONTROLS = false;`. To delete them completely, remove the blocks marked `TOUCH CONTROLS (temporary)` in the CSS, the HTML and the JS, plus the lines tagged `// TOUCH CONTROLS (temporary)`.

**Updating the online version:** the online page is a Claude artifact. Ask Claude to republish the files in `game\` to the HoMo-LAP artifact.

## Updating the car model

1. **Export from Blender.** This runs in the background and never modifies or saves livery.blend:
   ```
   "<path to blender.exe>" -b "E:\UE\livery\livery.blend" --python "E:\HOT LAP\blender\export_hotlap.py"
   ```
   - The script exports only parts visible in the view layer.
   - The back plate (`SOLID003`) sits in the hidden collection `07_Hardware`, so the script adds it explicitly. Add other hidden parts to the same list in the script.
   - Parts over 3000 triangles get a Decimate modifier, and only in the background copy.
2. **Shrink for the web.** Needs Node.js. In `source\model`:
   ```
   npm install
   node slim.mjs ..\..\blender\faumax_tau.glb car.glb 0.25 0.005
   node slim_q.mjs ..\..\blender\faumax_tau.glb car_q.glb 0.25 0.005
   python pack_json.py
   ```
   - The two numbers are the simplify ratio and the error limit.
   - `pack_json.py` writes `game\car.json` and `game\car_q.json`.
   - The artifact host refuses `.glb` files, so the model travels as base64 JSON.
3. If the livery images changed, copy the new ones into `game\livery\`. Keep each at most 2048 px wide.

How the game uses the model:
- Materials with `[LIVERY]` in their name get the projected livery. The projection box is set in `LIV` in template.html.
- `S_S000_TIRE*` nodes become the steering and spinning wheels.
- Names containing tyre, tire or rubber get the rubber material. Names containing carbon or fibre (or empty names) get the carbon material.

## Rebuilding the track

In `source\track` (needs numpy, scipy and Pillow; reads the LTS data from `D:\VD\laptimesimulation`):

1. `python fsg_track2.py`
   - Reads `data\tracks\A_FSGend_3.mat` (distance and curvature) and integrates it into x/y.
   - Closes the loop with a minimal curvature correction and writes `fsg.npz`.
2. `python fsg_final.py`
   - Pushes the end section 2.4 m away from the start straight where they pinch together.
   - Resamples to 1 m.
   - Adds the LTS reference lap from `results\viewerSamples\singleTrack_endurance.json` (75.058 s, used for the gold ghost and sector splits).
   - Writes `source\fsg_track.json`.
3. Run `build_game.py` again.

## Physics and data in the game

- **Model:**
  - Single-track (bicycle) model with load transfer and a friction ellipse.
  - Tyres: μ 1.40 at 600 N, load-sensitivity exponent −0.10 (LTS envelope).
  - Drive: four AMK motors, 80 kW system limit, top speed 34.06 m/s.
  - Control: torque-vectoring yaw controller, brake split 70/30.
  - Timing: fixed 1/600 s step.
- **Aero packages:**

  | Package | ClA | CdA | Front balance |
  |---|---|---|---|
  | τ LTS | 5.4 | 1.7 | 0.50 |
  | τ vehicle-params | 4.9 | 1.4 | 0.55 |
  | υ 1011 | 5.64 | 1.90 | 0.50 |
  | υ V4_K | 6.94 | 1.96 | 0.45 |
  | No downforce | 0 | 1.7 | 0.50 |

- **Penalties (FS Rules D 10.1.7):** 2 s per cone down or out, 10 s per off-course. A track cut invalidates the lap.
- **Track:** 4 m wide; blue and yellow cones every 5 m, closer together in bends.
- **Assists** (on by default; best laps are saved separately with and without them): braking to the LTS speed plan, steering help, traction control, stronger torque vectoring.

At the limit, the AI driver runs 75.2 s on the τ LTS package, against the LTS's 75.06 s.
