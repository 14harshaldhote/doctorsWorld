# Doctors World: development guide

An original hospital game for iPhone and iPad. You start as a first-day intern
in a small city hospital and rise to Chief of Medicine by handling short, tense
shifts well: triage arrivals, read drifting vitals, diagnose overlapping
symptoms and perform procedures with your own fingers. Good decisions earn
experience, experience unlocks skills, and skills change how you play.

> Conditions in the game are simplified and fictional. This is not medical advice.

## Status

| Stage | What it adds | State |
| --- | --- | --- |
| 1. Foundation | Xcode project, game core package, title screen, CI | Done |
| 2. Game core | Seeded shifts, patients, vitals, triage, scoring, XP, saves | Done |
| 3. First playable shift | SpriteKit floor, drag to triage, HUD, bedside panel, results, saving | Done |
| 4. Diagnosis and procedures | Symptom cards, follow-up questions, suture and injection mini-games | Next |
| 5. Progression screens | Ranks, skill tree, reputation, CPR and IV | |
| 6. Polish | Animation, haptics, sound, tutorial, iPad tuning | |

## Project layout

```
App/Model/              AppModel (screens, career, saving) and ShiftController
App/Floor/              SpriteKit ward: WardScene, BedNode, PatientToken
App/Screens/            SwiftUI: title, shift HUD, bedside panel, casebook, results
UITests/                Launch, full-shift and screenshot UI tests
Packages/GameCore/      Every game rule, in plain Swift with no UI imports
  Content/              Conditions, symptoms, tests, casebook
  Shift/                The shift engine: arrivals, decline, actions, scoring
  Play/                 Real-time runner, bedside model, player-facing text
  Progression/          XP curve, ranks, skills, player profile
  Save/                 Versioned JSON saves
  Simulation/           Auto-player for tests, balance checks and demo mode
project.yml             XcodeGen spec (the .xcodeproj is generated, not committed)
.github/workflows/      CI: core tests on Linux, app build and UI tests on macOS
```

The core rule of the codebase: **the game core decides, the screens only draw.**
A tap becomes an action, the core applies it and advances a fixed-step clock,
and the UI renders the new state. The same seed and the same actions always
replay the same shift, so every bug can be reproduced in a unit test.

## Run it on your iPhone or iPad

You need a Mac with Xcode 16 or newer.

```sh
brew install xcodegen
xcodegen generate
open DoctorsWorld.xcodeproj
```

1. In Xcode, select the **DoctorsWorld** target, open **Signing & Capabilities**,
   and choose your Apple ID as the team (a free Apple ID works).
2. If Xcode says the bundle identifier is taken, change
   `com.harshaldhote.doctorsworld` to something unique.
3. Plug in your device, pick it as the run destination and press Run.

With a free Apple ID the installed app expires after 7 days; run it from Xcode
again to renew. The Apple Developer Program removes that limit and enables
TestFlight.

## Demo mode and test switches

Launch arguments (set them in the Xcode scheme under Run > Arguments) change a
shift without touching the rules:

| Argument | Effect |
| --- | --- |
| `-autoplay YES` | The computer plays the shift (expert style) |
| `-freshProfile YES` | Start a new career in memory; the real save is not touched |
| `-seed 42` | Replay the same shift every time |
| `-shiftSeconds 60` | Shift length in game seconds (5 to 1800) |
| `-arrivalSeconds 6` | Busier shifts: a patient every 6 to 9 seconds |
| `-timeScale 2` | Play faster or slower (0.25 to 8) |

The UI tests use these to play a whole shift in under a minute.

## Tests

```sh
swift test --package-path Packages/GameCore          # game core, any Mac or Linux
xcodebuild test -project DoctorsWorld.xcodeproj -scheme DoctorsWorld \
  -destination 'platform=iOS Simulator,name=iPhone 16'   # UI tests: launch, full shift, screenshots
```

## Tech

Swift 6 with strict concurrency, SwiftUI, SpriteKit, Swift Testing, XcodeGen,
SwiftLint. No third-party runtime dependencies and no paid services.
