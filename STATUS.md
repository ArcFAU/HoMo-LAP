Last updated: 2026-11-08

## Done

- **Game:** one HTML page (`game\index.html`, built from `source\template.html`) with:
  - keyboard controls, plus temporary touch controls for phones
  - a 3D view (three.js r128 from a CDN) with four cameras, and a 2D fallback
  - the FSG endurance track from the LTS, with cones
  - FS Rules penalties (2 s per cone, 10 s per off-course, cut = invalid lap)
  - the LTS reference lap as a gold ghost, a personal-best ghost and sector splits
  - five aero packages (τ LTS, τ vehicle-params, υ 1011, υ V4_K, no downforce)
  - assists, on by default
  - three modes (since 2026-11-08): Hot lap, Arcade (arcade handling on the FSG track) and Free roam (paddock with skidpad and acceleration strip)
  - setup editor (since 2026-11-08): 18 physics parameters, derived numbers, up to 24 custom setups per browser; custom setups and arcade laps are not posted to the leaderboard
- **Physics:** checked against the LTS. At the limit the AI runs 75.23 s on τ LTS, vs 75.06 s for the LTS.
- **Car:**
  - FAUmax τ from `E:\UE\livery\livery.blend` with the projected livery T_TauOriginal: 206,128 triangles, 205 meshes (re-exported 2026-11-07, 23:30).
  - Back plate `SOLID003` included since 2026-11-07.
  - Served as `car.json` (meshopt) with `car_q.json` (quantized) as fallback.
- **Online:**
  - Claude artifact "HoMo-LAP" (formerly "Hot Lap"), https://claude.ai/artifact/38hveqdzZbP5zHJUSUfVmb, version `1794148607-1787` (2026-11-08: renamed to HoMo-LAP; before that `1794144097-5855` with the modes, setup editor and livery fixes; before that `1794092839-d6fc` with the shared leaderboard; capabilities `db` with rules `boards` read view / write owner and `boards/{self}` read view / write interact, `user` with scope profile).
  - Leaderboard data lives in the artifact's db, not in this folder. Read it with Claude's ArtifactData tool (collection `boards`).
  - Shared as "Anyone with the link" (set by the owner with the Share button).
  - `game\` in this folder matches that version.
- **MATLAB edition** (`MATALB\`, since 2026-11-08), built with MATLAB R2024b, Simulink, Optimization Toolbox and MATLAB Compiler:
  - the game in a MATLAB figure (all three modes)
  - a launcher and a setup editor (uifigure)
  - `simulink\HoMoLapVehicle.slx`
  - studies (setup sweep, fmincon setup optimisation)
  - tools: track build from the LTS data, car import from the Blender GLB with the livery baked into vertex colours, standalone build
  - Same physics as the web game: the AI lap is 77.40 s in MATLAB, 77.42 s in the web game and 77.47 s in Simulink.
- **Project folder:** `E:\HOT LAP` since 2026-11-07, with README, launcher, sources, model tools and the Blender export.
- **Git:** local repo on branch `main` since 2026-11-07, remote `origin` = https://github.com/ArcFAU/HoMo-LAP.git (private), pushed 2026-11-07. Commit only your own files (`git add <paths>`, not `git add -A`), because more than one session can be working in this folder.

## Open items

- **Old GitHub address:** `ArcFAU/HOT-LAP` now redirects to `ArcFAU/FS_LAP` (the game), not to `HoMo-LAP`. Any other clone of the simulator must use `https://github.com/ArcFAU/HoMo-LAP.git`.
- **High-end game "FS Lap" (placeholder name):** its own git repo in `high-end\`, `ArcFAU/FS_LAP`, pushed. Stage 0 is committed; Unreal 5.8.4 at `D:\UE\UE_5.8`, MSVC 14.50 installed, cache set to `D:\UE\DDC` (confirmed at runtime). Stage 1 passed its tests in the real game on 2026-11-08: AI lap 77.405 s, livery checked from all sides, 75 fps at Medium in an empty venue. A real gamepad and hand driving are still to be checked.

- **Not played by hand yet:**
  - Arcade, free roam and the setup editor were checked in headless Chrome (scripted driving, AI laps, screenshots).
  - The MATLAB game was checked with its headless self-test and screenshots.
  - Nobody has driven either with a keyboard yet; the arcade handling may need tuning by feel (`ARC` in template.html, `S.arc` in `MATALB\+hotlap\setups.m`).
- **Arcade car:** 0–100 km/h in 1.6 s and a 175 km/h top speed. That is deliberately not the real car; free-roam timings say "arcade car".
- **`MATALB\dist\HotLap.exe`:** built with MATLAB Compiler before the rename (not in git); `tools\build_standalone` now writes `HoMoLap.exe`. It was not started in this session, because the session's permission check blocked running it. It needs the MATLAB Runtime R2024b on PCs without MATLAB.
- **MATLAB edition data:** copies of `source\fsg_track.json`, `game\livery\*.png` and the logo, plus `car_mesh.mat` made from `blender\faumax_tau.glb`. Update them as described in `MATALB\README.md` when the originals change.

- **Leaderboard:** checked in headless Chrome against an in-memory stand-in for `db`/`user`, not yet with a real lap on the live board. Only the owner and members of his claude.ai organization can post; outside visitors only see it. The game's AI test driver doesn't post (`autodrive`); `__hotlap.postLap(raw, pen)` is a test hook that posts like a finished lap. The "naive" test driver (`sim(sec, 'naive')`) leaves the track and circles off it, so it can't produce test laps.
- **Node.js:** not installed on the laptop. The 2026-11-07 model rebuild used the node and pnpm bundled with Codex (`C:\Users\Archit\.cache\codex-runtimes\codex-primary-runtime\dependencies\node`); pnpm's cache is `E:\.pnpm-store` (36 MB, can be deleted). Installing Node.js would make `npm install` in the README work.
- **`faumax_tau.prev.glb`:** the export keeps the previous export (35 MB) and it is tracked in git, so every export adds about 35 MB to the repo. Owner to decide whether to ignore `*.prev.*`.
- **Touch controls:** temporary. Remove them later when the owner asks: `TOUCH_CONTROLS = false` or delete the marked blocks.
- **Old export folder:** `E:\UE\livery\hotlap_export` still exists. Everything from it is in `blender\`. The owner deletes it; the bridge cannot.
- **Hidden parts:** only `SOLID003` from the hidden collection `07_Hardware` is exported. If other small parts look missing, add them to the list in `blender\export_hotlap.py`.
- **Offline play:** `Play HoMo-LAP.bat` needs Python, and three.js loads from a CDN, so local play also needs internet. Vendoring the three.js files would make it fully offline.
- **Tests:** no automated test suite in this folder yet. The 2026-11-07 checks ran in headless Chrome in Claude's cloud workspace; those scripts were not copied here.
- **Livery updates:** when the livery in the .blend changes, copy the new images into `game\livery\` (at most 2048 px wide) and republish.
