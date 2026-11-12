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
| 2. Intro story | Story engine (replies, trust, moods), talking animation and voices, graduation, job letter and first-morning cutscenes, Dr. Iyer's welcome, lobby conversations and banter | Done |
| 3. Training | Day 2 skills lab: six scored, explained practice tasks (scrub in, monitor, history, instruments, IV line, stitching), trainers, best scores, Day 1 to Day 2 | Done |
| 4. First operation | Day 3: Rohit's consent with his mother, scrubbing in, the time-out, instrument calls with Tom, incision, a complication called by Dr. Khan, the swab count, stitching, the talk with his family and Dr. Iyer's debrief; won, struggled or failed (Dr. Iyer takes over) | Done |
| 5. Hospital life | Days 4 to 8 on the surgical ward: five patient stories (Lakshmi, Kunal, Aarav, an unknown rider, Mr. Fernandes), examining patients and reading X-rays as new skills, the bed-shortage politics with Mr. Malhotra, an on-call night, Dr. Rao's review and promotion to Junior Resident; an automated run from a new game to promotion | Done |
| 6. Polish | Settings (music, effects and voice volume, text size, reduce motion, colour-blind-safe monitor, battery saver), music for each place and a promotion fanfare, interface sounds and monitor beeps, screen fades and animated cards, confetti, room for the iPhone notch and home bar, and merged meshes so older iPhones draw about half as much | Done |
| 7. Junior Resident | "Eight months later": Days 9 to 13 as a Junior Resident. The team walks into a real operating theatre and the department's seminar room. Three new operations: a cut hand in the minor theatre, a keyhole gallbladder (fill the belly with gas, read the camera) and a stuck hernia whose bowel you must judge. Each case is random within its difficulty (easy; hard, with hints that cost points; extreme, with stacked problems and no hints) and shaped by what you asked on the ward. Also a missed aneurysm, Dr. Sethi taking the credit at the department meeting, a VIP's mother against an emergency, and the review that makes a Senior Resident | Done |
| Later | Senior Resident (nights in charge, an intern, the budget vote), Surgeon (your own team, mass casualties, Dr. Rao's old mistake), Head of Department (the strike, the board) and the ending | |

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

You need a Mac with Xcode 26 or newer, because Godot 4.7's iOS library is
built with the iOS 26 SDK. There is no simulator build (Godot's simulator
library is Intel only), so run it on a real iPhone or iPad.

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
5. The first time, turn on **Developer Mode** on the device (Settings >
   Privacy & Security), and trust your developer profile under Settings >
   General > VPN & Device Management.

With a free Apple ID the installed app expires after 7 days; run it from Xcode
again to renew. The Apple Developer Program removes that limit and enables
TestFlight.

## Project layout

```
project.godot           Project settings (landscape, 1688x780 canvas, Compatibility renderer)
export_presets.cfg      iOS export (Xcode project only, so CI needs no signing)
game/main.gd            Screen flow: title, name, look, opening, Day 1 lobby, Day 2 skills lab,
                        Day 3 theatre, the ward from Day 4; loading and saving
game/core/              Rules with no visuals: profile (best training scores, the rank
                        held), avatar look, XP curve, ranks, saves, seeded random numbers,
                        walkable floor and paths, patient vitals, GameSettings
game/avatar/            LowPoly mesh helpers, AvatarRig (the jointed, animated
                        character with gestures, gaze and lip movement), Props
                        (things people hold), AvatarSheet (a line-up of looks),
                        StaticBatch (merges meshes that never change)
game/audio/             Voice murmurs and sound effects, synthesised in code,
                        Music (crossfading tracks, the fanfare, ducking) and
                        Speech (lines read aloud with the device's voices)
game/ui/                UiKit (colours, fonts, buttons, text size, safe area,
                        animations), title, name and avatar creator screens,
                        settings, lobby HUD, conversation screen, story overlay
                        (fades, title cards, the letter, confetti), icons, the
                        patient monitor and the instrument ring (reused in
                        operations)
game/ui/training/       One screen per training task, on a shared TrainingView
                        (instructions, coaching, score card), including ExamView
                        (spots on the patient) and ScanView with XrayFilm
game/ui/surgery/        OperationView: the operation screen (monitor, team meter,
                        instrument ring, time-out board, decisions, score card)
game/training/          The training tasks' rules and scoring (no visuals), the
                        instruments, ExamTask (examining a patient) and ScanTask
                        (reading an X-ray), and AutoPlayer (plays any task well, or
                        badly, for tests and screenshots)
game/training/stations/ The six stations in 3D: sink, monitor bed, history chair,
                        instrument trolley, practice arm, suture pad
game/surgery/           Procedures (every operation as data), OperationTask (plays
                        any of them: time-out, calls, traced, held and filled
                        actions, decisions, complications, the count, difficulty,
                        hints, scoring) and OperatingTable (the table, the wound,
                        the keyhole view and the first-person hands in 3D)
game/story/             StoryBook (loads story files), StoryRunner (steps,
                        replies, trust), StoryPlayer (puts a story on stage),
                        Opening and its sets (graduation hall, home, morning)
game/world/             StageLighting, the hospital front, the Day 1 lobby, the Day 2
                        skills lab, the Day 3 ward and Theatre 2, and Ward (Days 4 to
                        8 and after) with WardBed and Lightbox; WardStory (Days 9
                        to 13 as data), TheatreSet (the operating room the ward's
                        team walks into) and SeminarRoom (meetings and reviews)
story/                  The words: cast, opening, Day 1 conversations, banter, training
                        conversations, patient cases (cases.json), the theatre day
                        (theatre.json), the ward days (ward.json), the Junior
                        Resident's days (junior.json)
assets/fonts/           Fredoka and Nunito (SIL Open Font License)
assets/music/           The music, made by tools/make_music.py
tests/                  The test runner and unit tests
tools/                  Screenshot tool used by CI, and the music generator
```

## Writing story

Conversations and cutscenes are JSON files in `story/`, one per chapter. A
conversation is a list of steps:

```json
{"say": "iyer", "text": "{called}? You're late.", "mood": "focused", "gesture": "fold_arms"}
{"choose": [{"tone": "Be honest", "text": "...", "trust": {"iyer": 5}, "flag": "honest_with_iyer"}]}
{"do": "walk", "who": "you", "to": "entrance"}
{"if": "asked_nair_wait", "then": [...], "else": [...]}
```

A reply with `"if": "flag"` is only offered while the flag is set (`"!flag"`
for unset), and `"again": true` brings the same choice back after it, which
makes question lists ("Ask Rohit", "Allergies"...) that end with a reply that
moves on. Every choice needs at least one reply without `if` or `again`.

`{name}`, `{first}`, `{last}`, `{called}` and `{title}` fill in the player's
name. The full list of keys is at the top of `game/story/story_runner.gd`, and
`tests/unit/test_story.gd` checks every file against the cast, the gestures
and the actions each scene knows, so a typo fails the build. The export preset
includes `story/*.json`, and CI checks the exported game carries them.

Patient cases live in `story/cases.json`. A history case (the default
`kind`) has the patient, who plays them, how many questions you get, and each
question with its answer, the fact it adds to the notes, its weight (`key`,
`useful` or `none`) and, for key questions, why it matters. An `exam` case has
spots on the patient's body (`"at": [joint, x, y, z]`, a point in that joint's
own space, so the buttons follow them as they breathe), each with a finding,
a weight, and `gentle`, `sore` or `"act": "pressure"` where it matters, plus
the diagnoses to choose from. A `scan` case names the object really on the
film and the answers.

## The ward

`game/world/ward.gd` runs Days 4 to 8, and an ordinary day after that. Each
day in `Ward.DAYS` is a list of beats: a conversation (`talk`), a place to
walk to (`go`: a bed, the trolley, the desk or the X-ray viewer), tasks with a
case (`tasks`), the conversation after them (`after`), a pager line (`page`)
and a time card (`card`). A beat with `if` only runs when the flag is set, so
the rider leads to Mr. Salim's morning only if he was treated on the ward.
Where people stand for each beat is set in `_stage_day` and `_stage_beat`.

Ward conversations can use the actions `arrive` (walk in from the door to a
place), `leave`, `put` (place someone at once), `card` (a time card) and
`page` (a pager line). A place is a bed id with a mark, such as
`trolley:head`, `bed2:sit` or `bed6:other`, or the desk and the family
corner.

Rank is no longer worked out from XP. XP sets the level, and the rank only
rises when someone promotes you (`PlayerProfile.promote()`), which Dr. Rao
does at the reviews on Day 8 and Day 13 (`Ward.REVIEWS`).

From Day 9 the days come from `game/world/ward_story.gd`, so new chapters
are data, not code. `WardStory.DAYS` uses the same beats plus:

- `where: "seminar"` for a beat in the seminar room, with a `slide`;
- `at` to move the clock on, and `card` before a conversation;
- `put`, `put_talked`, `put_back` and `put_end` to place people as the beat
  starts, after the first conversation, back from theatre and at the end
  (`["mehra", "side:sit", "!mehra_home"]`: a condition is optional);
- a task `["operate", "hernia"]`, which walks the `team` (lead, scrub nurse,
  anaesthetist) into theatre for a `brief`, then plays the operation.
  `op_flags` hands the team what the doctor found on the ward
  (`{"ate_known": "raju_history_meal"}`), and `levels` lists the
  difficulties the case can be: one is picked from a seed made of the
  career, the day and the case, so it stays the same until the day is
  played again.

After an operation the ward sets `op_<patient>_done`, `op_<patient>_won`
(or `struggled`, `failed`) and one flag per thing that happened
(`op_raju_chose_warm`, `op_farida_gas`), so later conversations remember it.
Conditions in WardStory may join flags with `&` and `|`. `TIME_JUMPS` puts a
card such as "Eight months later" before a day, and `STAGING`, `DAY_LINES`,
`END_LINES`, `DAY_FLAGS` and `DAY_CASES` hold the rest of each day. Story
conversations for these days are in a chapter listed in `WardStory.CHAPTERS`.

## Operations

`game/surgery/procedures.gd` holds the appendix, the wound, the gallbladder
and the hernia as data. Each has steps (what Tom hands over, what the doctor
does), a time-out board, a pool of complications and, for some, insides that
vary (`variants`: the hernia's bowel is pink, dusky or dead). A step id must
never match a complication id; a test checks it.

Difficulty changes the same operation. On **easy** the board is right, the
insides are the gentlest, a hint shows by itself under each step and
problems hurt the patient slowly. On **hard**
the board may be wrong, the insides are a coin toss, and the doctor can ask
the lead surgeon for a hint at 5 points each. On **extreme** the board is
wrong, the insides are the worst, a second problem lands on top of the first,
the patient worsens faster and there are no hints. A case is laid out from a
seed, so the same seed gives the same case.

## Settings and accessibility

`GameSettings` holds the settings for the device (not the career) in
`user://settings.json`, written the same safe way as the save. Main loads them
at start-up; the Settings panel (from the title screen and the pause menu)
changes them live and saves on Done.

- **Volumes:** the Music, Effects and Voices audio buses, made at run time.
  Zero mutes a bus, and sound effects and voices are not even started.
- **Read lines aloud:** off, or slower, normal or faster speech
  (`read_aloud`, `speech_speed`), and the player's doctor's voice, lighter,
  deeper or silent (`your_voice`, also chosen in the character creator). See
  Spoken lines below.
- **Text size:** `UiKit.set_text_size()` records each label's design size, and
  `UiKit.refresh_text()` resizes every label on screen when the setting
  changes. Body text grows by up to a quarter; headings of 28 and over stay as
  they are so screens still fit. Panels grow around the text, score cards
  scroll when they would be taller than the screen.
- **Reduce motion:** cameras cut instead of gliding (`UiKit.motion_weight()`),
  no button dips, pops or confetti, a quicker fade between screens, and the
  title camera stays still.
- **Colour-blind-safe monitor:** blue and orange instead of green and red,
  with up and down arrows beside numbers out of range and a tick or cross on
  the answer cells, so colour is never the only clue.
- **Graphics:** Battery saver runs at 30 frames a second at three quarters of
  the 3D resolution without anti-aliasing. iPhones before the iPhone 11 and
  iPads before the 8th generation start on it.

Edges of the screen: `UiKit.keep_off_edges()` moves a control in by the
device's safe area (the notch, rounded corners and the home bar), the same on
both sides so turning the phone round changes nothing. Screens call
`UiKit.keep_children_off_edges()` once built; backgrounds that fill the screen
are left alone. The screenshot tool pretends to be a notched iPhone
(`UiKit.inset_override`) so the shots match the device.

## Music and sound

The six music tracks (title, hospital, theatre, night, emergency, sad) and
the fanfare are composed and synthesised by `tools/make_music.py` (Python
with numpy, and ffmpeg for the Ogg Vorbis files), so there are no third-party
recordings. Each loop is a minute or more, in stereo, with a reverb; anything
that rings past the end of a loop wraps round to its start, so the loops join
without a seam. Loudness is set the way a phone speaker hears it (above about
250 Hz), a little under the old tracks, so speech stays clear. Run it again
after changing a tune (about two minutes):

```sh
python3 tools/make_music.py            # all tracks
python3 tools/make_music.py sad night  # some
```

Scenes ask for a track with `Music.cue()`; Main owns the one Music node, which
crossfades between tracks, dips the music under the promotion fanfare, and
dips it under spoken lines (`Music.duck_for_speech()`, a gain effect on the
Music bus). A ward beat can name its own music (`"music": "emergency"` for a
crash call), which plays until the beat ends, and a conversation can change
the music for as long as it lasts with `{"do": "music", "track": "sad"}`.
Sound effects (`Sfx`) and the fallback murmur are made in code at run time.

## Spoken lines

Every line is read aloud with the device's own text-to-speech (Godot's
`DisplayServer.tts_*`, which on iOS is `AVSpeechSynthesizer`; it needs
`audio/general/text_to_speech` in the project settings). It's free, offline,
and nothing leaves the device.

- `Speech` picks the voices: English ones only, clearer (enhanced or premium)
  before standard, Indian English before other accents, never the joke voices.
  They are split into higher and lower voices by name. Each cast member has a
  `gender` (and `child`, `pace`) in `story/cast.json`; they share out the
  voices of their kind in cast order, the first being the player's, and their
  `voice` level sets the pitch on top, so people sharing a voice still sound
  apart. `Speech.prepare()` turns the shown text into what is said ("Dr." is
  "Doctor", "120/80" is "120 over 80", shouted capitals are words) and keeps a
  map back to the shown letters.
- `SpokenLine` paces one typed line to its voice: the engine reports each
  word it reaches and the text shows up to the end of that word, so it never
  runs ahead. If the engine gives no word marks the text creeps on at about
  speaking pace; if the voice never starts, the line is typed as before.
- `ConversationUi` and `TrainingView` (coach lines, patients answering in
  exams and histories) use it; `StoryPlayer` also has the player say their
  chosen reply before the next line. Lobby banter stays a murmur.
- Where the device has no English voice (and in headless tests), lines fall
  back to the murmur. Tests use a fake engine (`tests/unit/fake_speech.gd`)
  that sends the same events as the real one. The screenshot tool turns
  speech off (`Speech.enabled`) so shots don't wait on voices.
- Better voices: on an iPhone, Settings > Accessibility > Spoken Content >
  Voices > English, where the enhanced voices can be downloaded; the game
  prefers them by itself.

## Performance

Everything is built from small meshes, and each costs a draw call.
`StaticBatch.optimise()` runs at the end of each scene's setup and merges the
meshes that can never change into one mesh per group and material look,
coloured per vertex, so the scene looks the same (renders with and without
it differ in a fraction of a percent of pixels, along a few edges). It leaves alone anything a
script keeps in a variable, anything named or carrying metadata, hidden,
see-through or glowing meshes, and characters' joints, so doors, lamps,
blankets, faces and moving parts keep working. Scenes now draw 90 to 340
meshes instead of 170 to 640. `tests/unit/test_performance.gd` keeps each
scene inside a budget of meshes and triangles.

## Training tasks

Each task in the skills lab is three pieces that stay apart, so the rules can
be tested without drawing anything:

- the rules (`game/training/*_task.gd`): what you can do, scoring out of 100,
  stars, the coach's lines and the notes on the score card;
- the 3D station (`game/training/stations/`): furniture, where people stand,
  the close-up camera, and how the task's state looks;
- the screen (`game/ui/training/`): buttons and panels that call the rules.

Time only moves through `tick()`, so `AutoPlayer` and the tests can play every
station start to finish in a fraction of a second. `Ward.play_until()` and
`Theatre.play_until()` do the same for whole days, and
`test_a_whole_career_from_new_game_to_junior_resident` plays from the title
screen to the promotion in a few seconds.

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
