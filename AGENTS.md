# Contributor instructions

Hot Lap is a browser racing game. It puts High Voltage Motorsports' FAUmax τ (the real Blender model and livery) on the FSG endurance track, using the team's LTS, vehicle-params and CFD numbers.

**E:\HOT LAP is the project folder (owner, 2026-11-07: "we work in that folder now on").** It is the source of truth. Copies elsewhere are derived from it and may be out of date:
- the online artifact
- the old export folder `E:\UE\livery\hotlap_export`
- any cloud workspace

Before changing anything, read:
- `README.md`: layout, how to build, play and update
- `STATUS.md`: current state and open items
- `DECISIONS.md`: why things are the way they are
- the latest entries in `CHAT_HISTORY.md`

## Safeguards

- **Never modify or save `E:\UE\livery\livery.blend`, and don't drive the open Blender session.**
  - Another Claude session may be working on the laptop (owner, 2026-11-07).
  - Car exports run in a background Blender (`blender -b … --python blender\export_hotlap.py`), which only changes its own in-memory copy.
- **Read-only data sources:**
  - `D:\VD` (laptimesimulation / HoMo-LTS, vehicle-params)
  - the CFD projects (`D:\HoMo-CFD`, `D:\CFD_TOPO`)
  - the livery folder `E:\UE\livery`
  - Nothing for Hot Lap is written there.
- **Don't edit `game\index.html` directly.** Edit `source\template.html` and run `python source\build_game.py`.
- **Keep the touch controls in their marked blocks.** They are temporary and will be removed later (owner: "Just for now. Later we might need to remove it."). `const TOUCH_CONTROLS = false;` turns them off.
- **Don't delete files without the owner's approval.** Keep originals (`.bak` or renamed).
- **Online version:**
  - It is the Claude artifact "Hot Lap" (https://claude.ai/artifact/38hveqdzZbP5zHJUSUfVmb), private to the owner until he shares it.
  - Republish only the files in `game\`.
  - The host does not serve `.glb` or `.bin` files, so models go up as base64 JSON (`source\model\pack_json.py`).
- **No secrets in this folder.**

## Required conversation log

Append to `CHAT_HISTORY.md` for every work task, before the task is complete:
1. The user's requests and clarifications, verbatim.
2. The contributor's user-visible responses, verbatim, including the final one. If intermediate messages are not reproduced, say so.
3. A short work record: changed files, decisions, checks and results.

Append new dated entries, newest at the bottom, and never rewrite earlier ones. No hidden reasoning, credentials or secrets. If you can't write the file, tell the user and give them the exact text to append.

Record user-visible changes in `CHANGELOG.md` and decisions in `DECISIONS.md`. Update `STATUS.md` when the state or the open items change.

## Checks

There is no automated test suite in this folder yet. After a change:

1. `python source\build_game.py`
2. Start `Play Hot Lap.bat` and play a lap. Check the browser console (F12) for errors.
3. After a model change, look at the car from the rear and the sides in the 3D view. The `C` key cycles the cameras.

Report what was checked in `CHAT_HISTORY.md`.
