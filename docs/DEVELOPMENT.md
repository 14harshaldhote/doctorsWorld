# Doctors World: development guide

Doctors World is an original low-poly 3D story game for iPhone and iPad, built
with [Godot 4.7](https://godotengine.org) in GDScript. Everything you see is
made in code: characters, furniture and buildings are faceted meshes built from
simple shapes, so there are no model or texture files to manage.

The story and full feature plan live in the plan document ("Doctors World v2
plan"). This file covers how to build, run and test the game.

## Stages

| Stage | What it adds | State |
| --- | --- | --- |
| 1. Avatar and lobby | Godot project, avatar creator, title and name screens, walkable lobby, CI | Done |
| 2. Intro story | Graduation, job letter and first-morning cutscenes | Next |
| 3. Training | Logical training tasks that later return in operations | |
| 4. Wards and patients | Patient stories, examinations, conversations with families | |
| 5. Operations | Theatre with an AI team and a nurse handing instruments | |
| 6. Career and politics | Promotions, reputation, rivals and hospital politics | |

The earlier SwiftUI and SpriteKit prototype is kept on the git branch
`swift-prototype`.

## Run it on your computer

1. Install Godot 4.7.2 (standard build, not .NET) from
   [godotengine.org/download](https://godotengine.org/download).
2. Open Godot, choose **Import**, and pick `project.godot` in this folder.
3. Press **Play** (F5, or Cmd+B on a Mac).

Controls on a computer: click the floor to walk, click a person to talk, or
use WASD / arrow keys. On a phone or tablet: tap.

## Run it on your iPhone or iPad

You need a Mac with Xcode 16 or newer.

1. In Godot, open **Editor > Manage Export Templates** and download the
   templates for 4.7.2.
2. Open **Project > Export**, pick the **iOS** preset, and set
   **App Store Team ID** to your Apple team ID (Xcode shows it under
   Settings > Accounts; a free Apple ID works). Change the bundle identifier
   `com.harshaldhote.doctorsworld` if Xcode says it is taken.
3. Click **Export Project**. The preset writes an Xcode project into
   `build/ios/`.
4. Open `build/ios/DoctorsWorld.xcodeproj`, choose your team under
   **Signing & Capabilities**, plug in the device and press Run.

With a free Apple ID the installed app expires after 7 days; run it from Xcode
again to renew. The Apple Developer Program removes that limit and enables
TestFlight.

## Project layout

```
project.godot           Project settings (landscape, 1688x780 canvas, Compatibility renderer)
export_presets.cfg      iOS export (Xcode project only, so CI needs no signing)
game/main.gd            Screen flow: title, name, look, hospital; loading and saving
game/core/              Rules with no visuals: profile, avatar look, XP curve, ranks,
                        saves, seeded random numbers, walkable floor and paths
game/avatar/            LowPoly mesh helpers, AvatarRig (the jointed, animated
                        character), AvatarSheet (a line-up of looks)
game/ui/                UiKit (colours, fonts, buttons), title, name and avatar
                        creator screens, lobby HUD, icons drawn in code
game/world/             StageLighting, the hospital at dusk, the Day 1 lobby
assets/fonts/           Fredoka and Nunito (SIL Open Font License)
tests/                  The test runner and unit tests
tools/                  Screenshot tool used by CI
```

## Tests

```sh
godot --headless --path . --import
godot --headless --path . -s res://tests/run_tests.gd
```

Each `test_*` method in `tests/unit/` runs on a fresh instance. A test fails if
an expectation fails, if any engine or script error is logged while it runs, or
if its file does not load. Pass `-- --only=lobby` to run only matching files.

## Screenshots

```sh
xvfb-run -a godot --path . --resolution 1688x780 -s res://tools/screenshots.gd -- shots iphone
xvfb-run -a godot --path . --resolution 2048x1536 -s res://tools/screenshots.gd -- shots ipad
```

On a Mac or a desktop with a screen, drop `xvfb-run -a`.

## Rendering choice

The game uses Godot's **Compatibility** renderer on every platform. It runs on
every supported iPhone and iPad, it is light on battery, and it is the renderer
CI can draw with, so the screenshots match what the device shows. Real-time
shadows are off; characters and furniture have soft contact shadows instead
(`LowPoly.shadow_blob`). Faces are flat-shaded on purpose.

## CI

`.github/workflows/ci.yml` runs on every push and pull request:

- **Linux:** downloads Godot, runs the tests, renders iPhone and iPad
  screenshots, and on `main` publishes them to the `screenshots` branch.
- **macOS:** exports the iOS Xcode project with Godot's templates and builds
  the iPhone and iPad app with code signing turned off. (Godot's simulator
  library is Intel only, so CI builds the real device app instead.)
