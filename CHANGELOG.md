# Changelog

User-visible changes, newest first. Detailed reasoning is in `CHAT_HISTORY.md`, decisions in `DECISIONS.md`.

## 2026-11-07

### Changed
- **Livery is now T_TauOriginal** (was D_VoltageSlash), matching livery.blend. The car model was re-exported, so the livery now also covers the nosecone, monocoque, wings and undertray panels whose livery material had been lost in the export.

### Added
- **Project folder `E:\HOT LAP`:**
  - `Play Hot Lap.bat` to play locally
  - a README
  - the project notes (`AGENTS.md`, `CHAT_HISTORY.md`, `STATUS.md`, `DECISIONS.md`, this file)
- **Back plate:** the car now has its back plate (`SOLID003`), so the rear is no longer open.
- **The real FAUmax τ:**
  - the car from livery.blend with its projected livery
  - steering and spinning wheels
  - carbon, rubber and environment reflections
- **3D view:** Chase, Onboard, High and Top-down cameras (`C` or the CAM button), cones, trees and skid marks. Falls back to 2D without WebGL.
- **Assists (on by default):** brake, steering, traction and stronger torque vectoring. Best laps are kept separately with and without them.
- **Touch controls for phones (temporary).**
- **Team data:**
  - the FSG endurance track from the LTS
  - the LTS reference lap as a gold ghost, a personal-best ghost and sector splits
  - five aero packages
  - FS Rules penalties (2 s per cone, 10 s per off-course, cut = invalid lap)
- **First version:** a keyboard-controlled hot-lap game in the browser.

### Fixed
- The car could get stuck at the edge of the map. It now returns to the track after 1.5 s.
- Ghost labels overlapped.
- Greek package names showed in uppercase (Υ, Β).
