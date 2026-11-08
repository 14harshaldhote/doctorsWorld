# Pulse Ward

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
| 2. Game core | Seeded shifts, patients, vitals, triage, scoring, XP, saves | Next |
| 3. First playable shift | SpriteKit floor, drag to triage, HUD, results | |
| 4. Diagnosis and procedures | Symptom cards, tests, suture and injection mini-games | |
| 5. Progression screens | Ranks, skill tree, reputation, CPR and IV | |
| 6. Polish | Animation, haptics, sound, tutorial, iPad tuning | |

## Project layout

```
App/                    SwiftUI app: screens and, from stage 3, the SpriteKit floor
UITests/                XCUITest smoke tests
Packages/GameCore/      Every game rule, in plain Swift with no UI imports
project.yml             XcodeGen spec (the .xcodeproj is generated, not committed)
.github/workflows/      CI: core tests on Linux, app build and UI test on macOS
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
open PulseWard.xcodeproj
```

1. In Xcode, select the **PulseWard** target, open **Signing & Capabilities**,
   and choose your Apple ID as the team (a free Apple ID works).
2. If Xcode says the bundle identifier is taken, change
   `com.harshaldhote.pulseward` to something unique.
3. Plug in your device, pick it as the run destination and press Run.

With a free Apple ID the installed app expires after 7 days; run it from Xcode
again to renew. The Apple Developer Program removes that limit and enables
TestFlight.

## Tests

```sh
swift test --package-path Packages/GameCore          # game core, any Mac or Linux
xcodebuild test -project PulseWard.xcodeproj -scheme PulseWard \
  -destination 'platform=iOS Simulator,name=iPhone 16'   # UI smoke test
```

## Tech

Swift 6 with strict concurrency, SwiftUI, SpriteKit, Swift Testing, XcodeGen,
SwiftLint. No third-party runtime dependencies and no paid services.
