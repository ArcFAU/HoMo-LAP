# Changelog

User-visible changes, newest first. Detailed reasoning is in `CHAT_HISTORY.md`, decisions in `DECISIONS.md`.

## 2026-11-08

### Changed
- **Hot Lap is now HoMo-LAP**: the web version, the online page (same link) and the MATLAB edition (`HoMoLap` in MATLAB, `HoMoLapVehicle.slx` in Simulink). Saved best laps and the leaderboard carry over. The name Hot Lap now belongs to the planned high-end game.

### Fixed
- **Livery now sticks to the car.** The livery projection used the car position from the previous frame, so the livery trailed the moving car (about 0.15 m at 30 km/h, 0.5 m at full speed, 0.8 m in arcade) and twisted in bends. It now follows the car exactly.
- **Livery looks like livery.blend:** the carbon under the transparent parts of the livery was shiny and reflected the sky, so the chequered areas looked grey and white and seemed to move as the car turned. It is now dark, slightly glossy carbon, and the chequer reads as dark blocks on carbon. The livery images no longer shimmer at their edges.
- **`Play Hot Lap.bat` always loads the newest version:** the browser no longer keeps an old cached page after an update. The menu shows the build time.

### Added
- **Arcade mode:** forgiving, drift-friendly handling on the FSG track, with more grip, power (1.75×) and top speed (about 175 km/h). The car counter-steers by itself and the handbrake (Space) starts a slide. No penalties; laps are timed and kept separately, with their own ghost. The chase camera widens with speed.
- **Free roam:** arcade handling on a large paved paddock around the event area, with an FS skidpad and a 75 m acceleration strip marked with cones. No lap timing; the timing tower shows top speed, 0–100 km/h, 75 m from standstill and distance. R takes you back to the start of the strip.
- **Car setup editor** (*Edit setup* in the menu): 18 parameters (aero, masses, weight distribution, CoG height, power limit, motor torque, gear ratio, tyre μ and load sensitivity, peak slip angle, brake balance and force, roll stiffness balance, torque-vectoring authority, steering lock) with derived numbers and a lap estimate. Your setups appear under the stock packages and keep their own best laps; they are not posted to the leaderboard.
- **MATLAB edition** in `MATALB\`: the game in MATLAB with all three modes, a launcher and setup editor, a Simulink model of the car and AI driver, setup studies (sweep and fmincon optimisation), and MATLAB tools for the track and the car model.
- **Shared leaderboard (online version):** in the menu under the aero packages, one board per aero package and assist setting. Each player's best valid lap is posted automatically, ranked by time including penalties, with FS points from the FS Rules 2027 endurance formula (D 9.2: fastest = 250, 1.5× or slower = 25). Players can set a driver name. During a race the game shows the new place ("P2 on the leaderboard"). Hidden when playing locally.

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

## 2026-11-08

- FS Lap's visible Unreal driving slice now launches with the generated track, car, chase camera and HUD.
