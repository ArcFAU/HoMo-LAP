# Hot Lap — the high-end game (plan)

Goal: **Hot Lap**, a game built in **Unreal Engine 5** with the look and feel of a modern racing game. It sits on top of **HoMo-LAP**, the team's lap simulator (the web and MATLAB versions in this folder, called Hot Lap until 2026-11-08). The game uses HoMo-LAP's car, track, data and physics core, with arcade handling on top, so its handling stays believable.

What stays the same:
- **Car:** the FAUmax τ from `livery.blend`, with the T_TauOriginal livery.
- **Track:** the FSG endurance track from the LTS.
- **Rules:** FS Rules penalties and ghosts.
- **Content:** the three modes and the setup system.
- **Physics:** the same single-track model, checked against the LTS (AI lap 77.4 s in the web game, MATLAB and Simulink).

The physics plugin is called `HoMoLapPhysics` because it is HoMo-LAP's model: HoMo-LAP can use the same C++ core if it later gets a native version.

Status: plan only (2026-11-08). Nothing is built yet. The decisions at the end are open.

## 1. What we need

### Hardware

| | This laptop | Needed to build it | Comfortable |
|---|---|---|---|
| GPU | GTX 1650 Max-Q, 4 GB | works for the editor at medium settings; no hardware ray tracing | RTX 3060 / 4060 or better, 8–12 GB |
| CPU | i5-9300H, 4 cores | works; first shader compile takes about an hour | 8+ cores |
| RAM | 32 GB | enough | 64 GB |
| Free disk | D 77 GB, E 27 GB, C 28 GB, F 36 GB | about 120 GB on one fast drive: engine about 50 GB, project, derived-data cache and assets 50–70 GB | 1 TB NVMe |

**Disk space is the real blocker on this laptop.** An external 1 TB NVMe SSD on USB-C is the cheapest fix.

**The GPU is a ceiling.** It can run Lumen (software) and Nanite at about 1080p and 60 fps in a modest scene with upscaling. Ray-traced reflections need an RTX card. Plan to show the result on a stronger PC.

### Software

| What | Why | Cost |
|---|---|---|
| Unreal Engine 5.x (Epic Games Launcher) | game engine. 5.7 was installed before at `D:\UE_5.7`; the folder is gone, only the registry entry is left | free for internal, non-commercial use |
| Visual Studio 2022 with "Game development with C++" | the physics plugin is C++ | free (Community) |
| Blender 5.1 (installed) | car export and livery bake, in the background as today | free |
| Git LFS, or Perforce / Unreal Revision Control | Unreal assets are binary and large; plain git won't cope, and GitHub's free LFS quota is small for an Unreal project | free tiers exist |
| Optional: Vehicle Dynamics Blockset + Simulink 3D Animation | lets Simulink drive Unreal scenes (route B, section 4). Licensed here, not installed | in the licence |

### Skills

| Role | Work | Who |
|---|---|---|
| Unreal developer (C++ and Blueprints) | vehicle pawn, game modes, HUD, timing | team / Claude for code |
| 3D artist | car materials, livery bake, venue, lighting | team |
| Vehicle dynamics | physics port, validation against the LTS, later the dual-track model | team (data exists) |
| Sound | motor and inverter recordings, tyres, wind | team on a test day |

Claude can write and check the code, tools and data pipeline. Art direction and the final look need someone sitting in the editor.

### Data we already have

| Data | Where (read-only) | Used for |
|---|---|---|
| Car model and livery projection | `E:\UE\livery\livery.blend`, `livery_art\` | car mesh, UV livery sheets 1001–1004 (4096 px) |
| Track centreline and LTS lap | `source\fsg_track.json` (from `D:\VD\laptimesimulation`) | track spline, cones, LTS ghost |
| Vehicle parameters, aero packages | `source\template.html`, `MATALB\+hotlap\setups.m` | physics, setups |
| Dual-track LTS result | `D:\VD\laptimesimulation\results\viewerSamples\dualTrack_endurance.json` | reference for the four-wheel model |
| HDRI skies | `E:\UE\qwantani_moon_noon_puresky_4k.exr`, `leadenhall_market_4k.exr` | lighting, reflections |
| Physics reference code | `MATALB\+hotlap\physicsStep.m` (code-generation clean), web `physics()` | C++ port |

### Data we still need

- **Real venue:** photos of the FSG / Hockenheim dynamic area, from the paddock, the tents, the grandstand, the barriers and the surface. Optionally open elevation and aerial data of the site.
- **Sound recordings of the τ:** motor and inverter at several speeds and loads, regen braking, tyres, cockpit.
- **Tyre data:** a full tyre model (TTC data) if we want more than the LTS envelope later.
- **Suspension data:** kinematics and springs and dampers for the four-wheel model (vehicle-params).

## 2. The pipeline

```
SOURCES (read-only)                    TOOLS (high-end\tools, run on demand)        UNREAL PROJECT (high-end\HotLapUE)

livery.blend ──Blender -b──────────▶ export_ue.py ─────────────────────────────▶ /Game/Car
                                       · body, 4 wheel assemblies with pivots        · Nanite body, wheel meshes
                                       · FBX or glTF, metres, x forward              · carbon / clear-coat / alu / rubber
                                     bake_livery_uv.py ────────────────────────▶   · livery UDIM 1001–1004 (virtual texture)
                                       · T_TauOriginal projection → UV sheets

fsg_track.json (LTS) ──────────────▶ track_to_ue.py ───────────────────────────▶ /Game/Track
                                       · centreline, edges, cones (same rules)        · spline road, painted lines
                                       · paddock, skidpad, acceleration strip         · cones as instances with physics

setups (web / MATLAB schema) ──────▶ copied as JSON ───────────────────────────▶ /Game/Data (DataTable)

physicsStep.m / physics() ─────────▶ hand port to C++ ─────────────────────────▶ Plugins/HoMoLapPhysics
                                       · same equations, 600 Hz sub-steps              · AI lap must match 77.4 s
                                                                                      · later: dual-track model

HDRI, Fab assets, photos ──────────▶ artist in the editor ─────────────────────▶ /Game/Environment (venue, sky, sun)
sound recordings ──────────────────▶ cut and loop ─────────────────────────────▶ MetaSounds (rpm, load, slip driven)

                                                                                 ──▶ Windows build (HotLap.exe, 2–5 GB)
```

The rules carry over from this project:
- **Read-only sources:** `livery.blend` is opened only by a background Blender and never saved. `D:\VD` and the livery folder stay read-only.
- **The tools are the source:** every Unreal asset that comes from team data is regenerated by a script, so a new export, track or setup flows through without hand work.
- **The physics stays one model:** the C++ port is checked against the same AI lap as the web game, MATLAB and Simulink.

## 3. Stages

Times assume one developer part-time plus an artist; they're rough.

| Stage | Content | Done when | Time |
|---|---|---|---|
| 0. Setup | disk space, Unreal 5.x, Visual Studio, project `HotLapUE` (C++), version control with LFS | empty project opens, builds, and is in version control | ~1 week |
| 1. Driving slice | car exported with pivots; livery baked to UV sheets; track spline and cones from `fsg_track.json`; C++ physics port; keyboard and gamepad (analog); chase camera | AI lap within 0.1 s of 77.4 s; livery checked from the sides, rear and front; 60 fps on the laptop at medium settings | 2–3 weeks |
| 2. Game | timing, sectors, FS penalties, LTS and best-lap ghosts, the three modes, setup editor (UMG), HUD in the web game's style, venue v1, sky and sun from the HDRI, tyre smoke, skid marks, audio v1 | a full hot lap and arcade lap play end to end | 3–4 weeks |
| 3. High end | four-wheel model with suspension movement; cockpit camera with steering wheel and driver; wheel support with force feedback; replays and TV cameras; post-processing (motion blur, bloom, exposure, colour grade); recorded motor sound; detailed venue; performance pass | stated look and feel targets met; packaged build runs on a second PC | 4–8 weeks |
| 4. Optional | Simulink drives the car in Unreal (route B); telemetry out to MATLAB over UDP; online leaderboard backend; multiplayer ghosts | as decided | open |

## 4. Two ways to connect MATLAB / Simulink

- **Route A (recommended): Unreal owns the physics.** A C++ port of `physicsStep` runs in Unreal. Telemetry can stream to MATLAB over UDP for plots. Unreal has no extra dependencies, and it runs on any PC.
- **Route B: Simulink owns the physics.** Vehicle Dynamics Blockset and Simulink 3D Animation send the car's pose to an Unreal scene.
  - It needs both products installed (licensed here).
  - Custom scenes must be built with the Unreal version that MathWorks' support package expects. For R2024b this is reportedly 5.1, which needs checking before relying on it.
  - It's good for engineering demos but a poor fit for a game.

## 5. Risks

| Risk | Effect | What we do |
|---|---|---|
| Disk and GPU on this laptop | slow editor, no ray tracing | external SSD; scalability settings; final look shown on a stronger PC |
| The livery loses detail | the web and MATLAB versions project or bake it; Unreal needs proper UV textures | bake the projection into the existing 4096 px UV sheets in Blender; check from all sides |
| Physics port drifts from the LTS | handling and lap times no longer comparable | automated test: headless AI lap must match 77.4 s ± 0.1 s |
| Asset size in version control | repo becomes unusable | LFS or Perforce from day one; generated assets rebuilt by scripts, not stored twice |
| Scope creep (open world, traffic, many cars) | never finishes | one car, one venue, three modes; everything else after stage 3 |
| Sharing | a 2–5 GB Windows build replaces "send a link" | keep the web game for quick sharing; the high-end build is for demos and team use |

## 6. Decisions for the owner

1. **Engine version:** the latest Unreal 5.x (recommended), or the version MathWorks needs if route B matters.
2. **Disk:** buy an external SSD, or free about 120 GB on one drive.
3. **Version control:** Git LFS on a host with enough quota, or Perforce or Unreal Revision Control.
4. **Physics:** route A (C++ port of our model, recommended) or route B (Simulink).
5. **Venue:** a generic paddock first (recommended), or a model of the real FSG site from photos and open data.
6. **People:** who does the art and the sound recordings.

## Folder layout

```
high-end\
├─ README.md     this plan
├─ tools\        export and bake scripts (stage 1)
├─ data\         generated exports for Unreal (not hand-edited)
└─ HotLapUE\     the Unreal project (stage 0; under LFS or Perforce)
```
