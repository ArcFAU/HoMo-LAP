Last updated: 2026-11-07

## Done

- **Game:** one HTML page (`game\index.html`, built from `source\template.html`) with:
  - keyboard controls, plus temporary touch controls for phones
  - a 3D view (three.js r128 from a CDN) with four cameras, and a 2D fallback
  - the FSG endurance track from the LTS, with cones
  - FS Rules penalties (2 s per cone, 10 s per off-course, cut = invalid lap)
  - the LTS reference lap as a gold ghost, a personal-best ghost and sector splits
  - five aero packages (τ LTS, τ vehicle-params, υ 1011, υ V4_K, no downforce)
  - assists, on by default
- **Physics:** checked against the LTS. At the limit the AI runs 75.23 s on τ LTS, vs 75.06 s for the LTS.
- **Car:**
  - FAUmax τ from `E:\UE\livery\livery.blend` with the projected livery T_TauOriginal: 206,128 triangles, 205 meshes (re-exported 2026-11-07, 23:30).
  - Back plate `SOLID003` included since 2026-11-07.
  - Served as `car.json` (meshopt) with `car_q.json` (quantized) as fallback.
- **Online:**
  - Claude artifact "Hot Lap", https://claude.ai/artifact/38hveqdzZbP5zHJUSUfVmb, version `1794091836-958f` (2026-11-07, livery T_TauOriginal).
  - Shared as "Anyone with the link" (set by the owner with the Share button).
  - `game\` in this folder matches that version.
- **Project folder:** `E:\HOT LAP` since 2026-11-07, with README, launcher, sources, model tools and the Blender export.
- **Git:** local repo on branch `main` since 2026-11-07, remote `origin` = https://github.com/ArcFAU/HOT-LAP.git (private), pushed 2026-11-07. Commit only your own files (`git add <paths>`, not `git add -A`), because more than one session can be working in this folder.

## Open items

- **Logo provenance chunk:** `source\logo_small.png` carries a 7.5 KB `caBX` (C2PA) chunk from the file store; the pixels are unchanged. `build_game.py` would embed it and change `index.html`, so the published `index.html` was kept as is. Strip the chunk before the next template change.
- **Node.js:** not installed on the laptop. The 2026-11-07 model rebuild used the node and pnpm bundled with Codex (`C:\Users\Archit\.cache\codex-runtimes\codex-primary-runtime\dependencies\node`); pnpm's cache is `E:\.pnpm-store` (36 MB, can be deleted). Installing Node.js would make `npm install` in the README work.
- **`faumax_tau.prev.glb`:** the export keeps the previous export (35 MB) and it is tracked in git, so every export adds about 35 MB to the repo. Owner to decide whether to ignore `*.prev.*`.
- **Touch controls:** temporary. Remove them later when the owner asks: `TOUCH_CONTROLS = false` or delete the marked blocks.
- **Old export folder:** `E:\UE\livery\hotlap_export` still exists. Everything from it is in `blender\`. The owner deletes it; the bridge cannot.
- **Hidden parts:** only `SOLID003` from the hidden collection `07_Hardware` is exported. If other small parts look missing, add them to the list in `blender\export_hotlap.py`.
- **Offline play:** `Play Hot Lap.bat` needs Python, and three.js loads from a CDN, so local play also needs internet. Vendoring the three.js files would make it fully offline.
- **Tests:** no automated test suite in this folder yet. The 2026-11-07 checks ran in headless Chrome in Claude's cloud workspace; those scripts were not copied here.
- **Livery updates:** when the livery in the .blend changes, copy the new images into `game\livery\` (at most 2048 px wide) and republish.
