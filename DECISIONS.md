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

## 2026-11-07 — E:\HOT LAP is the project folder

The owner decided to work in `E:\HOT LAP` from now on. It holds the game, sources, tools, the Blender export and the project notes. It follows the same conventions as HoMo CFD and CFD_TOPO (`AGENTS.md`, `CHAT_HISTORY.md` and the other notes).

**Why:** one place for everything, with a history any session (cloud or VS Code) can pick up.
