# Decisions

Why Hot Lap is built the way it is. Add a dated entry when a decision changes how the game works or how contributors work. Don't rewrite old entries; mark them superseded instead.

## 2026-11-07 — One self-contained HTML page, published as a Claude artifact

The whole game is one page with the track data and logo built in, plus the car model and livery images next to it. It is published as a private Claude artifact that the owner shares himself.

**Why:** it runs on the laptop and on phones without installing anything, and one link is enough to share it.

## 2026-11-07 — Don't disturb the laptop's live session; export the car in a background Blender

The owner said another Claude session was live on the laptop. The car is therefore exported by a separate background Blender (`-b … --python export_hotlap.py`). It changes only its own in-memory copy: decimation, linking hidden parts. `livery.blend` is never modified or saved.

**Why:** the owner's open work must stay untouched.

## 2026-11-07 — Track from the LTS curvature, not a drawn track

The track is the LTS's `A_FSGend_3.mat` (distance and curvature), integrated into x/y.
- The small closure gap is removed with a minimal-norm curvature correction. A uniform heading fix distorted the track.
- The end section is pushed 2.4 m away from the start straight where the two pinch together.

**Why:** the game should drive the same track the LTS reference lap was computed on, so the gold ghost is comparable.

## 2026-11-07 — Single-track physics on the LTS tyre envelope

- A single-track model with load transfer and a friction ellipse.
- LTS tyre envelope: μ 1.40 at 600 N, exponent −0.10.
- 80 kW system limit, top speed 34.06 m/s.
- Torque-vectoring yaw control and a 70/30 brake split.

**Why:** it is close enough to the LTS (AI 75.23 s vs 75.06 s) while staying fast enough to run at 600 steps/s in a browser.

## 2026-11-07 — Penalties from FS Rules 2027 D 10.1.7

2 s per cone down or out and 10 s per off-course. A large progress jump counts as a cut and invalidates the lap.

**Why:** team members know these rules, and they make the game feel like an endurance or autocross run.

## 2026-11-07 — Assists on by default, best laps kept separately

The owner found cornering too hard. The assists are on by default: brake, steering, traction and stronger torque vectoring. Best laps are stored per aero package and per assist mode.

**Why:** easy to pick up, but laps with assists don't overwrite raw laps.

## 2026-11-07 — Models served as base64 JSON, meshopt first with a quantized fallback

The artifact host refuses `.glb` and `.bin` files. Both models are wrapped as base64 in JSON and parsed in the page:
- `car.json` is the meshopt-compressed model (6.3 MB).
- `car_q.json` is quantized only (11.6 MB), used if the meshopt decoder can't load.

**Why:** this is the only way to host the model with the artifact. The fallback keeps the car visible if the decoder CDN fails.

## 2026-11-07 — Livery projected in a shader from five planar images

`[LIVERY]` materials get `LIVERY_Left`, `LIVERY_Right`, `LIVERY_Top`, `LIVERY_Front` and `LIVERY_Rear`, projected along the car's axes and blended by surface normal. This matches how the livery is set up in the .blend; the exported `LIVERY_UV` tiles were empty.

**Why:** it reproduces the .blend's livery without baking it.

## 2026-11-07 — Hidden parts added explicitly to the export

The export takes visible parts only. The back plate `SOLID003` sits in the hidden collection `07_Hardware`, so the export script links it in, in the background copy only. The rest of `07_Hardware` stays out.

**Why:** the owner reported the back plate missing. Exporting the whole hidden collection would add hardware he hasn't asked for.

## 2026-11-07 — Touch controls are temporary and kept in marked blocks

The owner wants phone support "just for now", so the touch controls live in clearly marked blocks behind `TOUCH_CONTROLS`.

**Why:** they can be removed cleanly later.

## 2026-11-08 — Shared leaderboard in the artifact's db, scored by time and FS points

The online page keeps one document per player, `boards/<player id>`, in the artifact's `db`. Everyone reads all of them, each player writes only their own (`boards/{self}`: `interact`), and only the owner can change or delete others (`boards`: `read: view`, `write: owner`). A document holds the player's best valid corrected lap per board (aero package + assist mode) and an optional typed driver name. Every write reads the stored document first and merges into it. Points use FS Rules 2027 D 9.2.2 / Table 9 for Endurance, with Tmin = fastest corrected time on that board.

**Why:** the owner asked for a shared leaderboard and for both scorings ("use both if possible"). By platform rule, visitors from outside the owner's organization hold `view` and cannot write, so only the owner and organization members can post; the owner chose this over a per-device log. Names are typed by the player rather than copying claude.ai profile names into the store, because profile names may not be shown to every viewer and go stale. Merging on write means a slow snapshot can't wipe a player's other laps.

## 2026-11-07 — Git with LF line endings; commit only your own files

The folder is a git repo, pushed to the private GitHub repo `ArcFAU/HOT-LAP`. `.gitattributes` keeps LF line endings in the working copy (`.bat` keeps CRLF). Commit with explicit paths, not `git add -A`.

**Why:** Windows git otherwise checks files out with CRLF, so a checkout changed `game\index.html` away from the bytes that the build writes and the artifact serves. More than one session can be working in the folder at once, and `git add -A` once committed another session's unfinished files.

## 2026-11-07 — E:\HOT LAP is the project folder

The owner decided to work in `E:\HOT LAP` from now on. It holds the game, sources, tools, the Blender export and the project notes. It follows the same conventions as HoMo CFD and CFD_TOPO (`AGENTS.md`, `CHAT_HISTORY.md` and the other notes).

**Why:** one place for everything, with a history any session (cloud or VS Code) can pick up.

## 2026-11-08 — Arcade and free roam are a handling layer on the same model

Arcade handling is a branch inside the same single-track physics, not a second car model:
- more grip, power and top speed (`ARC`: grip 1.18, power 1.75, drive force 1.2, top speed 1.45, brakes 1.35)
- automatic counter-steer
- a handbrake slide that the throttle can hold
- a stability limit on body slip (14°, or 38° while drifting) and on yaw rate

Free roam uses the same handling on a paved paddock around the event area, with an FS skidpad and acceleration strip made of cones that exist only in that mode. Arcade laps get their own best-lap keys (`arc|…`) and are never posted.

**Why:** the owner asked for a "Need for Speed / Forza Horizon" style second mode and chose arcade handling on FSG plus a free-roam area (not boost or drift scoring). Sharing the model keeps the aero, setup and data readouts meaningful in every mode, and keeps the hot-lap physics untouched (the AI lap is unchanged at 77.42 s).

## 2026-11-08 — Setup editor; custom setups stay off the leaderboard

Every value the physics uses can be edited. The fixed geometry (wheelbase, track, model) stays as built.
- **Storage:** custom setups are stored with the player's data (`setups`, up to 24) as `{ id, name, base, vals }`, the same fields as the MATLAB edition's `setups\*.json`.
- **Best laps:** the best-lap key includes a hash of the values, so a changed setup starts a new best.
- **Stock packages** are read-only; editing one saves a copy.
- **Leaderboard:** custom setups and arcade laps are not posted. The board compares the team's stock packages in Hot lap mode.

**Why:** the owner wanted a built-in setup configuration "so it does not only rely on the data from laptime sim and aero package". Posting custom setups would make board entries incomparable, because anyone could set μ 2.0 and 120 kW.

## 2026-11-08 — MATLAB edition in MATALB\, sharing one physics source with Simulink

The owner asked for "a copy of the entire project but with MathWorks products" in `E:\HOT LAP\MATALB` (the folder name is the owner's) and chose a full MATLAB/Simulink port. What it contains:
- **Ports of the web game:** `+hotlap\physicsStep.m`, `aiDriver.m` and `loadTrack.m` port the web game line by line.
- **One source for the game and the model:** the game and the Simulink model call these same functions. The MATLAB Function blocks compile them with the bundled LCC compiler.
- **Generated model:** the model is built by `build_hotlap_model.m`, so the script is its source.
- **Livery in vertex colours:** the livery is baked into the mesh, because MATLAB patches have no image textures. The mesh is refined only where the livery changes, which keeps it at about 175,000 triangles.
- **Not in the MATLAB edition:** the leaderboard (it lives in the claude.ai artifact), sound and touch controls.

**Why:** one physics source keeps the MATLAB game, the headless AI lap and Simulink in step with each other and with the web game. The AI laps agree to 0.07 s.

## 2026-11-08 — Local launcher sends no-cache; builds carry a time stamp

`Play Hot Lap.bat` runs `source\serve.py` instead of `python -m http.server`. It is the same simple server, but it sends `Cache-Control: no-cache`, so the browser revalidates every file. `build_game.py` puts the build time in the menu.

**Why:** the owner reported that the livery fix had not worked. The plain server sends no cache header, so Chrome could keep showing an older `index.html` after a rebuild. The stamp shows at a glance which build a browser is running.

## 2026-11-08 — Renamed to HoMo-LAP; "Hot Lap" is the high-end game

Everything built so far is now called **HoMo-LAP**: the web version, the online artifact and the MATLAB/Simulink edition. It is developed as the team's lap simulator, and the arcade and free-roam modes stay in it. **Hot Lap** is the name of the planned Unreal Engine game (`high-end\`). The game will use HoMo-LAP's physics core with an arcade layer on top.

Renamed:
- page and window titles, the menu heading
- the MATLAB launcher (`HoMoLap.m`) and the Simulink model (`HoMoLapVehicle.slx`, built by `build_homolap_model.m` with `homolapModelParams.m`)
- the standalone exe name, the local launcher (`Play HoMo-LAP.bat`)
- the docs

Kept, so data and links survive:
- the folder `E:\HOT LAP`
- the artifact link
- the saved-laps key `hotlap.hvm.fsg.v1`, the leaderboard collection `boards` and its lap keys
- the MATLAB package `+hotlap` (called from the Simulink blocks)
- `blender\export_hotlap.py`, `window.__hotlap` (test hook)

The GitHub repo is renamed by the owner on GitHub. The mode called "Hot lap" keeps its name: it is the FS term for a timed flying lap.

**Why:** the owner's split: a simulator in the HoMo family (HoMo-LTS, HoMo-CFD) for fidelity, and a separate high-end game for looks and fun.

## 2026-11-08 — Hot Lap is its own repository, `ArcFAU/HotLap`, in `high-end\`

The owner asked for a new repo for the high-end game. `high-end\` is a separate git repository with Git LFS. HoMo-LAP's `.gitignore` excludes the folder, and its earlier history keeps the first version of the plan.

**Why:** Unreal assets are large binaries and shouldn't bloat HoMo-LAP's repo. The name is `HotLap`, not `Hot-Lap`: GitHub ignores capitals, so `Hot-Lap` would be the old name `HOT-LAP`, and reusing an old name ends GitHub's redirect from it to `HoMo-LAP`.

