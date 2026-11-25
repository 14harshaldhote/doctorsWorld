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
| 8. Senior Resident | "A year later": Days 14 to 18 as a Senior Resident with an intern of your own (Dr. Zoya Qureshi). A new puzzle, checking her drug chart (`ChartTask`, `ChartView`), whose wrong lines can come from what you missed on the ward and carry into theatre. Two new operations: hip fixation with Dr. Bhatt (read the X-ray, aim a guide wire, measure, drill, plate) and an emergency laparotomy for a torn spleen (find the bleeding corner, save or remove the spleen, clamp clear of the pancreas). Also a son who wants to sign for his capable mother, a night in charge where your teaching decides when Zoya calls you, the M&M meeting, the budget vote and the review that makes a Surgeon | Done |
| 9. Surgeon | "Three months later": Days 19 to 23 as a Surgeon with a list and a team of your own. You pick the scrub nurse and the anaesthetist (`team_swap`), and each pick changes the operation: a tired nurse loses a swab in the count, a quick anaesthetist who wasn't told about her asthma meets a wheeze, waiting for the careful one makes the bowel worse. A new operation, an open belly for a blocked bowel (find where fat loops turn flat, read what an old swab has done, cut the scar band). Dr. Rao's 2004 swab and the choice to tell her, hide it or let him tell it. A new puzzle, triage at a bus crash (`TriageTask`, `TriageView`, START rules, borderline numbers on hard and extreme). Dr. Rao retires and the interview makes a Head of Department | Done |
| 10. Head of Department and the ending | "Six months later": Days 24 to 28 as Head of Department. A strike vote, Dr. Sameer Kapoor of CarePlus touring the ward, and Mrs. Sinha back from Dr. Sethi's day-case pilot with a bile leak: her history (the penicillin allergy) and a new keyhole operation (wash out, find the fresh trickle, read the leak: a slipped clip, a duct in the liver bed or a burn on the main duct, each with its own fix). Dr. Sethi's request to keep it quiet until the vote. A new puzzle, strike-day nurse cover (`RotaTask`, `RotaView`). The agency offer, the picket line, the board vote that makes you Chief of Medicine (`Ward.REVIEWS` 27), then the last day: your Head of Surgery, your own intern's first morning and Dr. Iyer and Grace telling you where everyone ended up | Done |
| 11. Chief's days, for ever | Day 29 onwards, generated by `ChiefDays` (story in `story/chief.json`, written by `tools/chief_story.py`). Days 29 to 35 are the casebook: one patient a day, mostly people met before (Mrs. Banerjee, Mr. Malhotra's son Dev, Tom, Salim from the crash, Mrs. Mehra, a CarePlus day case, Sister Grace), each a history plus one of the story's operations with the patient swapped in (`Procedures.for_patient`). Every day has a hard call that moves the hospital's standing (`Standing`: staff, money, public trust), which feeds the morning's news, theatre pressure and a board report every fifth day. From Day 36 the days never end: a fresh staffing rota or highway crash from bigger seeded pools, a teaching case in the simulator, a recurring call (never the same two days running, with three variants each). Every ten days is a new tier: harder theatre (`OperationTask` `intensity`), no easy puzzles, more rota-and-crash days, a stricter board and a little ground lost each morning. Milestone days at 50, 75, 100 and every 50th. Every day of the career, Day 1 included, ends on a card (`StoryOverlay.end_card`, `DayHooks`) with the winning run, the next goal and a line about tomorrow; tap to go on. Cases lean harder as the career goes on and after a run of wins, gentler after a lost patient (`DayHooks.weights_for`) | Done |
| 12. No two weeks the same | More variety for the endless days, all in `ChiefDays`. Fourteen recurring hard calls (`ROUNDS_CALLS`, three openings each by `rounds_a/b/c`); none comes back within `CALL_GAP` days, worked out once per doctor and cached (`call_for` and `sim_for` are loops, not recursion, so Day 5000 is as cheap as Day 50). From Day 43 each week (`week`, `event_for`) is ordinary or an event from `EVENTS`: the rains (crashes every other day, more busy days), festival week (a new crash, `festival_triage`) or an outbreak (a new rota full of the stomach bug, `outbreak_rota`, every day). The first four weeks bring all three events and one ordinary week; after that each four is a seeded shuffle, never the same twice running. An event changes the puzzle's case, its talks and page, the day card's heading, the teaser the evening before, the morning news (`event_*` flags) and the day's last line, and costs a point a morning from its own meter. Eight walk-in patients (`CASEBOOK` entries with `walkin: true`) come on Day 37 and every fourth day after, in an order seeded by the doctor's name; each is a history and an operation at the day's difficulties, and joins the simulator's cases after their day. The board's wrong-age note now names the casebook patient. Story in `tools/chief_story.py`; the new cases and histories are in `story/cases.json` | Done |
| 13. Reminders, privacy and thanks | Reminders on the phone to bring the player back (`Reminders`, `ReminderBackend`, `ReminderAsk`): a page about the day waiting (the story day, the casebook patient, a walk-in, a hard week starting, a milestone, the board report or the day's hard call), then a run to save or a slipping number, then two gentle nudges, then silence. One a day at the hour the player usually plays (kept between 10:00 and 20:00), none after a week away, and every launch and save replaces the plan. Off until the player says yes: the game asks after Day 1 and once more after the first review (`Reminders.should_ask`), the phone then asks for permission, and Settings has an on/off row. The iOS side is `addons/dw_reminders` (see Reminders below). Settings > About opens the privacy policy and the acknowledgements (`AboutTexts`, `ReaderPanel`): thanks, every part of Godot with its copyright holders, and every licence text. The policy is also in [docs/PRIVACY.md](PRIVACY.md) for the App Store | Done |
| 14. Training through the career, and fewer ways to get stuck | A drill between every day from the end of Day 3 to the start of Day 28 (`Drills`, `DrillCard`, `SkillsLab` with a `drill` station): the save moves to the next morning as soon as a day ends, with `Drills.FLAG` set, and `Main.show_hospital` opens the skills lab for one station (monitor, IV line, stitching, instruments, scrubbing in, in turn) before the day. A card shows a true story (`TrainingFacts`, six per station) and the XP on offer; the first score pays `Drills.xp` (for turning up, each star and a new best, times 1 + half the rank) and clears the flag; Skip goes straight on. Every Day 2 score card ends with a story too (`TrainingView.fact`). Fixes from a playthrough audit: a day started again after the game closed halfway goes back to that morning (`PlayerProfile.begin_day`, the `morning` snapshot in the save), so a review can no longer promote twice and XP can't be earned twice; the ward's and theatre's place to go counts from a tap on its bed or person or the floor beside it, or from walking up to it, and its tag is pinned to the screen's edge with an arrow when the place is off screen or under a panel (`LobbyHud.set_tag(..., pin)`, `tag_hit`) | Done |
| 15. Turning up pays, new patients, a card that talks | XP for opening the game on a new real-world day (`DailyReward`: 10 XP, plus 5 for each day in a row up to a week, times 1 + half the rank; `PlayerProfile.last_played` and the counter `day_streak`), on a `WelcomeCard` over the day's screen, which waits for it. The XP goes into the morning snapshot too, so a day that starts over keeps it. The history station joins the drills (`Drills.ORDER` has six stations) with a practice patient each time it comes round (`Drills.HISTORY_CASES`, four new cases in `story/cases.json`, all acted by Dr. Iyer). The trainer reads the drill card aloud: the opener, then the true story (`DrillCard._read_aloud`); the facts and openers moved to `story/facts.json` so `tools/make_voices.py` records them (`fact_lines()`) | Done |
| 16. Nobody walks through anybody, voices that sound like people | One walking system for everyone (`Crowd`): every walk plans its way round furniture and round anyone standing still (`WalkArea.find_path` with people), steps aside or waits for anyone in the way on every frame, ends beside someone instead of inside them, and gets up off a bed or out of furniture before it sets off. The stitch trainer's spot moved out of the lab wall. `test_crowd.gd` plays the first days and two ward weeks frame by frame and fails on any overlap. Story lines are acted: each sentence is made on its own with its own pace and pitch and put back together with small pauses, gently shaped by the line's mood (`MOODS` in `tools/make_voices.py`). The first two weeks of dialogue were rewritten to sound spoken | Done |
| 17. The career map, a rival and letters | The Career button (it replaced the Casebook corner button) opens `CareerMap` over the paused game: every rank as a stop (`Career.STOPS`: done, here with the goals for the next stop, or locked with a teaser), the roads a Senior Resident will choose between (only Surgery open), the never-ending days, and the race with Dr. Varun Khanna (`Rival`). Letters from patients (`Letters`, `story/letters.json`) arrive as their day ends, the first letter in a slot whose condition holds; the Letters page is a wall of every slot, sealed, empty or arrived, and reading one marks it read. The end-of-day card adds a line about the race and one about the post. The ward, theatre, skills lab and lobby now stop their clocks while any menu is open | Done |
| 18. Crises | Eight hospital crises played as puzzles (`CrisisTask`, `CrisisView`, built by `Crises` in game/training/crises.gd): a power cut in theatre, two patients with the same name, an angry family after a death, the family's blood donors, an insurance form, a snakebite, dengue triage with two units of platelets, and an inspection in thirty minutes. Each is rolled from a seed at easy, hard or extreme. They come on Days 10, 14, 15, 16, 17, 20, 24 and 26 (the beat before each day's last), then every third Chief's day from Day 36 in a seeded order. The coach's lines are in `story/crisis_lines.json`, the talks before and after in `story/crises.json` | Done |
| 19. Daily hooks | On the career map's Today page: the 60-second case (`DailyCase`, six quick emergencies in `QuickCases`, one a day, the same for everyone, played with `CrisisTask` against one minute), the weekly mystery (`WeeklyMystery`, `story/mysteries.json`, one clue a weekday and one guess a week), and 20 badges on the Badges page (`Badges`) | Done |
| 20. Tighter start | Six more quick cases (asthma, fits and eclampsia, head injury, poisoning, sepsis, heat), eight more mysteries, four more badges; Day 2 needs four stations (`SkillsLab.NEEDED`), not six; filler trimmed from the longest speeches; quick cases as story beats on Days 21, 23 and 27; a two-card cold open; the Today page from meeting Dr. Iyer on Day 1; Varun's first message on Day 1's card | Done |
| 21. Lines that sound like people, and a share card | junior, senior, surgeon, hod and the Chief's days (`tools/chief_story.py`, which writes `story/chief.json`: edit the script, never the JSON) rewritten in a spoken voice, about 1,300 lines; the young characters (Zoya, Ira Saxena, Dev, Arif, Ananya) talk Gen Z and the seniors get more sarcastic; the 60-second case can be shared (`Share`: a wa.me link plus the clipboard, swappable `Share.opener` / `Share.copier` for tests; `DailyCase.share_text` from the counters `daily_case_marks`, `daily_case_seconds`, `daily_case_slow`; case numbers from `DailyCase.FIRST_DATE`); screenshots 167-169. 1.11.1: no emoji anywhere in the game (the share card's marks are words, `DailyCase.MARK_WORDS`), checked by `test_nothing_in_the_game_uses_emoji` | Done |
| 22. Casualty and the clock | `game/shift/`: `ShiftSim` (arrivals by the hour, four cubicles, six seats, worse/crash/leave, tests coming back), `ShiftDay` (load by day and tier, the career's `hospital_seed`), `ShiftPatient`, `Conditions` (`story/conditions.json`), `NameMaker`, `PatientLook`, `ShiftBot`; `CasualtyRoom` behind the ward's door, `PatientPanel` (the card); the free clock (`Ward.CLOCK_RATE`), late beats, the `sign_off` beat; sealed saves (`SaveStore` v3: HMAC over the body, `.install` secret, three backups, `save.tampered.json`), `ClockGuard` on the daily XP, case and mystery, check codes on shared results (`DailyCase.check_code`, `check_shared`), `FrameBudget`; the macOS preset and CI job; screenshots 170-174 | Done |
| 23. The doctor's phone | `PhonePanel` over the game (Phone button, a swipe up from the bottom, P on a Mac; the clock keeps running, 30 fps while it's up): Chats with two-reply answers, Calls (`ring`, answer, decline, rang out; lines spoken in the caller's voice, the doctor's replies only shown), Lab results (the story's reports and casualty's live ones), the Pager (today's pages), the Feed and Photos (`PhotoCard`, pictures drawn in code). `PhoneBook` reads `story/phone.json` (contacts, 144 messages, calls, posts, photos, reports, each on a day and time with a story condition) and keeps what was read, answered and picked up in `profile.phone`, checked on load (`PhoneBook.clean`). `PhoneWriter` writes the game's own: Varun's reels, the family's evenings (gentler after a death), the batch group on the race, the hospital page and the paper after Day 28, and a thank-you from someone casualty sent home. New messages show as a banner and a number on the Phone button; the end-of-day card says who is about to text. Screenshots 175-182 | Done |
| 24. Patients that never run out | `story/conditions.json` grows to 57 illnesses common in India (each with a `weight`, the `from_day` it opens on, a family's `plain` words, optional `jobs`, `with`, `told_by` a parent or colleague, and a `late` stage); `story/patients.json` holds the parts (`PatientParts`): ten patient voices (`PatientVoices`), twelve tempers, jobs, who comes with them, the mixes and twists (`extras`), the invented outbreak (`Outbreak`) and coming back (`returns`); `PatientMaker` builds each case from one seed; returning patients from `profile.patients` (`ShiftDay.remember`, `past`, `clean_patients`); answers read aloud from clips joined sentence by sentence (`VoiceBank.sentences`); four more communities in `NameMaker`; the card shows who they are, what's known and who answers; toasts sit beside the card; screenshots 183-187 | Done |
| 25. Mistakes and deaths | `story/mistakes.json` read by `Fates` (game/shift/fates.gd): the chances, whose fault a death is (`Fates.FAULTS`), the conditions that can come in beyond saving, the lab's critical calls and wrong results, the read-back, the forgotten bed, the family's lines and Iyer's M&M messages. `ShiftSim` rolls them from its own `fate` stream (`plan_fates`, `_harm`, `_die`, `_result_back`, `repeat_test`, `treat_alert`, `answer_readback`, `_hold_over`); the card gets the lab's call and the read-back (`PatientPanel`); a death opens the relatives' room (`FamilyCard`) for a patient the doctor saw, and every death goes on the wall (`profile.wall`, `WallPanel`, the "The wall" tag by the desk). Day 5 loses Mrs. Saroja Raman whatever is done (`saroja_round`, `saroja_son`, `saroja_wall`). The phone gets Maps (`HospitalMap`). Screenshots 188-193 | Done |
| 26. The director and feelings | A pacing director (`Director`, `story/feelings.json`) that keeps a tension number for the shift and gives it breathers, emotional and silly moments, lifts that remember the doctor's choices, colleagues' asks (`Lives`), three sarcastic songs and the phone's radio, and the goat. See The director and feelings below. Screenshots 194-199 | Done |
| 27. Life outside the wards | An evening after every ward day from Day 4 (`Evening`, `story/life.json`, `Life`): chai in the canteen, the hostel room, a video call home, eating, studying, scrolling, bed; sleep and hunger reach the next day's theatre (`OperationTask.tremor`); Mum texts after days without a call and then walks onto Ward 4; five parties with a game each (`game/ui/games/`: carrom, antakshari, dance-off, speech) and the pager going off; Varun in person, voiced. See Evenings and parties below. Screenshots 200-215 | Done |
| 28. Speed | Characters nobody can see skip their posing (`AvatarRig._on_screen`, joints looked up once per build) and breathe and blink on their own beat; the voice list is read on a background thread at boot (`VoiceBank.warm`); the phone's messages are rebuilt only when something they are made from changes (`PhoneBook._state_key`); Space or Return moves a talk on (`ui_accept`) and 1 to 9 pick a reply (the `reply_1` to `reply_9` actions; the game reads no raw keys); the casualty toast refits when a Mac window is resized; `tools/profile.gd` and `tools/soak.gd`. See Performance below | Done |

The earlier SwiftUI and SpriteKit prototype is kept on the git branch
`swift-prototype`.

## Run it on your computer

1. Install Godot 4.7.2 (standard build, not .NET) from
   [godotengine.org/download](https://godotengine.org/download).
2. Open Godot, choose **Import**, and pick `project.godot` in this folder.
3. Press **Play** (F5, or Cmd+B on a Mac).

Controls on a computer: click the floor to walk and click a person to talk
(in the lobby and the skills lab WASD and the arrow keys walk too). In a
conversation, Space or Return does what a click does and 1 to 9 pick a reply.
P brings the phone up and puts it away; Esc puts it away, or pauses. On a
phone or tablet: tap, and swipe up from the bottom of the screen for the
phone.

## Run it on a Mac

Every push to `main` builds a Mac app in CI (the **DoctorsWorld-mac**
artifact on the run's page): one app for Intel and Apple silicon, ad-hoc
signed, because there is no paid Apple Developer account to sign it
properly. To open it:

1. Download the artifact, unzip it (twice: GitHub zips the zip), and drag
   **Doctors World.app** into Applications.
2. Double-click it. macOS says it can't check the developer; click **Done**.
3. Open **System Settings > Privacy & Security**, scroll down to the line
   about Doctors World and click **Open Anyway**, then confirm.

After that it opens like any other app. To build it yourself instead: in
Godot, **Project > Export**, pick the **macOS** preset and click
**Export Project** (Godot's 4.7.2 export templates must be installed).
The Mac App Store would need the paid account; the game doesn't use it.
The save lives in `~/Library/Application Support/Godot/app_userdata/Doctors World/`.

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
again to renew. The paid Apple Developer Program would remove that limit and
enable TestFlight; the game doesn't use it for now.

### Testers' phones, without a paid account

A free Apple ID installs on other people's phones the same way: plug the
tester's iPhone into the Mac, pick it as the run destination in Xcode and
press Run. The first time, the phone needs Developer Mode on and the profile
trusted (step 5 above), and the tester must unlock it while Xcode installs.
Apple limits a free ID to a few devices and a few apps a week, and each
install stops opening after 7 days, so plan to plug the phones in again
weekly. Settings on the phone are kept between installs; the save file is
too, unless the app is deleted. Nothing is uploaded anywhere: there is no
server, so a tester's save stays on their phone.

For a long test on an older iPhone, turn on Settings > Graphics > Battery
saver (phones before the iPhone 11 start on it) and watch for warmth and
battery drain during a full ward day; the engine can't read the phone's
heat, so that check is done by hand.

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
                        Resident's days (junior.json), the Senior
                        Resident's (senior.json) and the Surgeon's
                        (surgeon.json), and the Head of Department's
                        days and the ending (hod.json)
assets/fonts/           Fredoka and Nunito (SIL Open Font License)
assets/music/           The music, made by tools/make_music.py
assets/voices/          Recorded voices, made by tools/make_voices.py (Kokoro, Apache 2.0)
tests/                  The test runner and unit tests
tools/                  Screenshot tool used by CI, the music and voice makers
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
does at the reviews on Day 8, Day 13 and Day 18, and the board does at the
interview on Day 23 and the vote on Day 27 (`Ward.REVIEWS`).

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
  played again;
- a task `["chart", "gomes_chart"]` for a drug chart, with `chart_force`
  deciding lines from flags (`{"warfarin": "!gomes_history_medicines"}`:
  the warfarin line is wrong if nobody asked about her tablets);
- `team_swap` to put the doctor's own picks into the team
  (`[[1, "neha", "team_neha"]]`: Neha scrubs if `team_neha` is set). The
  operation names whoever is there (`scrub_name()`, `anaesthetist_name()`);
- a task `["triage", "bus_triage"]` for sorting casualties at a crash;
- a task `["rota", "strike_rota"]` for strike-day nurse cover, with a
  `coach` (who stands with you at the desk);
- `card` together with `go`: the time card plays, then the doctor walks to
  the place and the beat's conversation starts there (the last evening at
  the X-ray viewer). A talk at the X-ray viewer turns both people to each
  other and uses its own camera, since the viewer stands by the end wall.

`WardStory.NIGHTS` lists days that are night shifts, and a cast entry's
`later_roles` changes the role shown from a day on (Dr. Sethi becomes a
consultant on Day 14). A drug chart sets `<case>_done`, `<case>_right` and
`<case>_missed_<line>` for each wrong line left on it.

After an operation the ward sets `op_<patient>_done`, `op_<patient>_won`
(or `struggled`, `failed`) and one flag per thing that happened
(`op_raju_chose_warm`, `op_farida_gas`), so later conversations remember it.
Conditions in WardStory may join flags with `&` and `|`. `TIME_JUMPS` puts a
card such as "Eight months later" before a day, and `STAGING`, `DAY_LINES`,
`END_LINES`, `DAY_FLAGS` and `DAY_CASES` hold the rest of each day. Story
conversations for these days are in a chapter listed in `WardStory.CHAPTERS`.

## Operations

`game/surgery/procedures.gd` holds the appendix, the wound, the gallbladder,
the hernia, the hip, the spleen, the blocked bowel and the bile leak as data. Each has steps (what Tom hands over, what the doctor
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
seed, so the same seed gives the same case. `unknown_brings` ties a
complication to something the team wasn't told (`{"warfarin_known":
"bleeding"}`), and `view_centre` moves the close-up camera so the work sits
between the screen's panels.

A step can change with an earlier decision: `tool_after`, `call_after`,
`hit_after`, `hint_after`, `instruction_after` and `start_after` map a
decision's option to what that step uses instead (`"tool_after": {"drain":
"forceps"}`: if the doctor chose to drain the bile leak, the next step is done
with forceps, not the clip applier). `OperationTask._by_choice()` reads them.
The bile leak picks its variant (`stump`, `bed` or `duct`) while the case is
laid out, so the place to tap and what the camera shows agree with it.

## Drug charts

`ChartTask` (in `game/training/`) reads a `"kind": "chart"` case from
`story/cases.json`: the patient card, and lines that each have a right and
a wrong version (`"subtle": true` for the harder ones). The seed and the
difficulty pick which lines are wrong: two plain ones on easy, plus one
subtle on hard and two on extreme. Flag a line with a reason and the intern
agrees, half agrees (right line, wrong reason) or explains why it was right.
Hints come from Dr. Iyer (5 points each on hard, none on extreme).

## Triage

`TriageTask` reads a `"kind": "triage"` case: a place, the nurse who runs
the line (`actor`), what she says as each tag is given, and casualty
templates. Each template says whether they walk, breathe, breathe once the
airway is opened, and the ranges for breaths a minute (`rate`) and nail bed
refill (`refill`) on each difficulty, so hard and extreme can put a number
right on the line (30 breaths is yellow, 31 is red). The seed picks six,
eight or ten of them, always with a red, a yellow and a green. The START
rules decide the true tag (`start_tag`) and which checks it takes to know
(`needed_checks`): a check past that wastes time, and a right tag without
its deciding check counts as a guess. Tagging someone red as yellow or green
is under-triage, and the ward sets `<case>_under` and `<case>_under_<id>`.
Easy shows the rules on a card; hints cost 5 points on hard; extreme has
none.

## Strike-day cover

`RotaTask` reads a `"kind": "rota"` case: who is left to work (`staff`:
each with a `capacity` that can differ by difficulty, whether they can run a
drip, and `student` or `from` for people who only appear on hard or
extreme) and patient templates (`load` from 1 to 3, and `iv`, `infectious`,
`fragile` or `confused`, each with an `about` line Grace says when you pick
them). The seed picks six, eight or ten patients whose total load fills the
staff to a set tightness, and `RotaTask.solve()` checks there is always a
way to cover them. The rules (`RotaTask.RULES`): nobody carries more than
their limit, drips only with a nurse who can run them, an infected patient
never shares a nurse with a fragile one, a confused patient's nurse carries
4 or less, and a student never takes a patient weighing 3. Signing scores the
rota: 12 points off for each rule broken, 15 for each patient left without a
nurse. The ward sets `<case>_right`, `<case>_<rule>` for each broken rule and
`<case>_gap` for anyone uncovered, and the midday report reads them back.
Easy shows the rules and marks a patient coral when they break one (with a
warning from Grace); a hint (5 points on hard, none on extreme) names a
placement that still leads to a full cover, or says which one to move.

## Settings and accessibility

`GameSettings` holds the settings for the device (not the career) in
`user://settings.json`, written the same safe way as the save. Main loads them
at start-up; the Settings panel (from the title screen and the pause menu)
changes them live and saves on Done.

- **Volumes:** the Music, Effects and Voices audio buses, made at run time.
  Zero mutes a bus, and sound effects and voices are not even started.
- **Read lines aloud:** off, or slower, normal or faster speech
  (`read_aloud`, `speech_speed`). The player's doctor is never voiced, so
  there is no voice choice for them. See Spoken lines below.
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
- **Reminders:** off or on (`reminders`), shown only where the device can
  show them. See Reminders below.
- **About:** the privacy policy and the acknowledgements, read in a
  `ReaderPanel` over the settings. Their words are in `AboutTexts`; the
  policy is copied word for word into `docs/PRIVACY.md` (a test checks), so
  change both together.

## Drills between days

`Drills.before_day(day)` names the station practised before a day (Days 4
to 28, `ORDER` in turn), or "" for none. `Main._close_day` advances the save
and sets `Drills.FLAG` when a drill is due; `Main.show_hospital` sees the
flag and opens `SkillsLab.new(profile, station)`, which skips the Day 2
story, stands the doctor at the station with its trainer and shows a
`DrillCard`. The task's seed comes from `Drills.seed_for`, so a drill is the
same until it is played. The first score pays `Drills.xp(rank, stars,
new_best)` once and clears the flag; retries are practice. `drill_finished`
(Done, Skip, or leaving after a score) takes Main on to the day.

True stories live in `story/facts.json` ("facts", six per station, read by
`TrainingFacts`; "openers", one line per trainer, read by `Drills.opener`).
Day 2 shows fact n on the nth go at a station; the drill before a day shows
fact `Drills.visit(day)`, so no story repeats between Day 2 and Day 28.
Keep them true and short (under about 250 characters): they are on screen
next to the score, and the trainer reads them aloud on the drill card, so
run `tools/make_voices.py` after changing one.

The history drill picks `Drills.history_case(day)` from `HISTORY_CASES`,
practice patients in `story/cases.json` with the same shape as
`training_history` (four key questions with a `why`, three useful, two
that waste a question). `SkillsLab.open_task` passes the case to
`TrainingTask.make` only in drill mode, so Day 2 keeps Mr. Kumar.

## People moving

Every walk goes through `Crowd`: `Crowd.plan()` finds a way round the
furniture and round anyone standing still (people's spots go into
`WalkArea.find_path` as solid for that search), and `Crowd.advance()` moves
the walker one frame, turning aside (right first, so two people pass on the
same side) or waiting for anyone within `GAP` (0.5 m between centres). A walk
blocked for `REPLAN_AFTER` finds another way once; blocked for `GIVE_UP`, or
nearly there, it ends where it is. Someone who has stopped where a walk ends
moves its end beside them. `Crowd.make_room()` moves anyone put down on top
of someone. The ward's theatre and seminar room sit on other floors, so the
ward's walk area only applies to people on its own floor. `Crowd.problems()`
lists every overlap on a frame; `test_crowd.gd` uses it on whole days.

## The career map

`CareerMap` (game/ui/career_map.gd) is opened by `LobbyHud.open_career()`
from the Career corner button in every scene with a HUD; `menu_open()` is
true while it is up, so the scene stops its clock (`update` returns early)
and ignores taps. Closing it emits `menu_choice("save")`, so a letter read is
saved straight away. The HUD's amber badge counts unread letters
(`refresh_letters`).

- `Career.stops(profile)`: one stop per rank, `done`, `here` or `locked`; a
  locked stop shows its `teaser`. `Career.goals(profile)` lists the next
  review (from `DayHooks.REVIEW_DAYS`) and level for the stop the doctor is
  on, or a Chief's board report and next milestone, plus the best run and
  how many letters are on the wall. `Career.ROADS` are the roads at Senior
  Resident; only Surgery is open.
- `Rival` is Dr. Varun Khanna, a batchmate at CarePlus on the same rung of
  the ladder. The race compares XP earned in a "month": Days 4-8, 9-13,
  14-18, 19-23, 24-27, then every ten days from 28 (`STRETCHES`,
  `CHIEF_STRETCH`). `Rival.begin_day` (called by `Ward._begin_day`) starts a
  month's count from the doctor's XP that morning (`rival_base`) and settles
  the month before into `rival_won`, `rival_lost` or `rival_tied`. A
  promotion's top-up is added to `rival_base` in `Ward._promote`, so reviews
  never decide a month. Varun earns `PACE` a day plus a day's line from
  `DAYS` (picked by a hash of the day, so it is the same for everyone), and
  `LOSS_PUSH` for each patient the player loses (`DayHooks.record_operation`).
  A career that reaches the race partway through a month races from that day
  (`rival_since`). The counters are part of the day's morning snapshot, so a
  day played again counts nothing twice.
- `Letters` reads `story/letters.json`: `slots`, each with an `after` day and
  a list of `letters`, each with a `when` condition (`WardStory.holds`
  syntax; empty means always), `from`, `title` and `body` (`{called}` is the
  doctor's name). The first letter whose condition holds is the one that
  comes, once the doctor is past the slot's day; no match means nobody wrote.
  `Letters.post_line` is the end card's line for the letters arriving as a
  day ends. Reading sets `letter_read_<slot>` in the flags and in the
  morning snapshot. Square brackets in a letter are shown as written.

To add a letter, add a slot (in day order) or another letter to a slot,
with a condition on a flag the story really sets; `test_career.gd` checks
both.

## Crises

`Crises` (game/training/crises.gd) builds each crisis from a `SeededRandom`:
the title, the spot, the card of facts, and the steps. `CrisisTask` plays
them; `CrisisView` shows the facts on a card under the header and the step
on the right. A step is one of three kinds:

- `one`: pick one option (`options`, `answer`).
- `each`: give every item one of the `choices`; a choice with a `limit` runs
  out (dengue's two units of platelets). Marked by the share right.
- `some`: pick the items that fit. With `need`, enough safe ones (each
  unsafe pick costs half a needed one); with `budget`, `costs` and `values`,
  the best plan that fits (`CrisisTask.best_plan`, a search over every set):
  a job only counts with the job it `needs`, and a `critical` job left out
  costs `CRITICAL_MISSED`. Otherwise the right set, wrong picks cancelling
  right ones.

`urgent` steps get a clock on hard (30 s) and extreme (18 s); whatever is
picked when it runs out is the answer. Hints are free on easy, cost
`HINT_COST` on hard and don't exist on extreme. Each step names the coach's
line keys (`right`, `wrong`, `hint`) in `story/crisis_lines.json`, under the
crisis, with `brief_<level>`, `end_all`, `end_some` and `end_none` (and
`over_budget` for the inspection); every line is spoken by the crisis's
`ACTORS` entry and recorded like any story line, so no `{called}` in them.

On the ward a crisis is a beat (`Crises.beat`): `Ward._beats_for` puts it
before the day's last beat on the story days (`STORY_DAYS`) and
`ChiefDays.beats` before the last beat every `CHIEF_EVERY` days from
`CHIEF_FROM`, in rounds of all eight (`Crises._order`, seeded by the
doctor's name, never the same one twice running). A beat with `gowned`
dresses those people for theatre and undresses them after (`_leave_theatre`).
Flags are `crisis_<id>_done`, `crisis_<id>_right` and
`crisis_<id>_missed_<step>`; `DayHooks.record_crisis` counts `crises` and
`crises_right`, and on a Chief's day the town's trust moves with the result.

To add a crisis: a builder in `Crises.build`, an entry in `IDS`, `BEATS` and
`ACTORS`, its lines and talks, and a place in the schedule. `test_crises.gd`
plays every crisis at every level over forty seeds, right and wrong, and
checks every line key it can reach is written.

## The daily case, the weekly mystery and badges

All three live on the career map (`CareerMap`): the Today page and the
Badges page. The Career button carries a mint dot (`LobbyHud.today_dot`)
while `CareerMap.today_waiting` (from `Ward.FIRST_DAY`, the day's case or
the week's guess is still to do).

- `QuickCases` (game/training/quick_cases.gd) builds twelve quick emergencies
  (sugar, allergy, stroke, chest pain, a baby with diarrhoea, burns, asthma,
  fits, head injury, poisoning, sepsis, heat), each
  three `one` steps whose answers come from rolled facts. `Crises.build`
  hands any id starting `quick_` to it; the lines are the `quick` group in
  `story/crisis_lines.json`, spoken by Dr. Iyer.
- `DailyCase` picks the day's case (rounds of six, each a seeded shuffle,
  never the same case two days running), the seed and the level (easy
  Monday to Wednesday, hard Thursday and Friday, extreme at the weekend),
  and sets `CrisisTask.time_total` to 60: when it runs out every step left
  is locked. `record` keeps the counters `daily_case_date` (as 20261119),
  `daily_case_streak`, `daily_case_best`, `daily_case_score`, `daily_cases`
  and `daily_cases_perfect`, pays XP and copies them into the morning
  snapshot. Leaving early hands the case in as it stands.
- `WeeklyMystery` reads `story/mysteries.json`: a week is Monday to Sunday
  (`week_of`), clue N opens on weekday N, `for_week` steps through the list
  by three so all come once before any repeats. One guess a week
  (`mystery_week`), worth `TOP_XP` less `CLUE_COST` per open clue after the
  first. Not voiced.
- `Badges.ALL` is [id, name, line once earned, how to earn, rule]; a badge
  is the flag `badge_<id>` and is kept for good. `Badges.check` runs as a
  day ends, after the case, after the guess and when the page opens.

Stage 20: `Crises.STORY_DAYS` also puts three quick cases on the meeting
days (21 heat, 23 asthma, 27 sepsis) as ordinary crisis beats, with no
minute on the clock; the ward passes `{"story": true}` so the patient is the
one the talk around it names. The Today page opens with the flag
`met_iyer` (`CareerMap.today_open`). Badges keep their flags in the morning
snapshot (`Badges.keep_flag`), and `all_quick` needs the flag
`ever_right_<case>` for all twelve (set by a perfect daily case).

`test_daily.gd` plays every quick case at every level over forty seeds,
checks the medicine, the dates on real weeks, the streak, the one guess,
the badges, and the Today page end to end.

## A new day

`DailyReward.claim(profile)` runs at the top of `Main.show_hospital`: the
first open on a new local date pays `xp_for(streak, rank)`, moves the streak
on (or back to one after a gap) and returns what to show; `Main.welcome_back`
puts a `WelcomeCard` over the screen and disables the screen's processing
until the card closes. The career's first session only notes the date. Tests
set `DailyReward.today_override`.

## Reminders

`Reminders.plan()` works out up to four reminders (`DAYS_AHEAD` 1, 2, 4
and 7 days after the last session) and `Reminders.payload()` turns them into
a few lines of text. `ReminderBackend` hands that text to the phone by
setting the `DW_REMINDERS` environment variable. Main writes a new plan at
start-up, on every save and when the game goes to the background, and
remembers the hour each session starts (`GameSettings.play_hours`).

The phone's side is `addons/dw_reminders/reminders_ios.cpp`. The editor
plugin in the same folder adds it to the exported Xcode project's generated
C++ file (`add_apple_embedded_platform_cpp_code`) and links
UserNotifications, so there is nothing to build by hand and it works with
any Godot version. Every two seconds it reads `DW_REMINDERS`; a new value
clears every pending reminder and schedules the new ones with
UNUserNotificationCenter, and an `ask` line shows the phone's permission
prompt first. It writes `granted`, `denied` or `undetermined` back to
`DW_REMINDERS_STATUS`, which the game reads for its question and its
Settings row. The plugin must stay switched on in `project.godot`
(`[editor_plugins]`); CI checks that the code reaches the Xcode project and
the app. On a computer there's nothing to send to, and tests use a fake
(`tests/unit/fake_reminders.gd`).

To try it on a device: finish Day 1, say **Page me**, allow notifications,
then change the phone's clock forward a day (or wait).

Edges of the screen: `UiKit.keep_off_edges()` moves a control in by the
device's safe area (the notch, rounded corners and the home bar), the same on
both sides so turning the phone round changes nothing. Screens call
`UiKit.keep_children_off_edges()` once built; backgrounds that fill the screen
are left alone. The screenshot tool pretends to be a notched iPhone
(`UiKit.inset_override`) so the shots match the device.

## Music and sound

The six music tracks (title, hospital, theatre, night, emergency, sad), the
fanfare and the music of the three songs (`song_night`, `song_dal`,
`song_roast`, timed by `story/songs.json`) are composed and synthesised by
`tools/make_music.py` (Python
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

Every line is read aloud. Almost all of them play from recordings made ahead
of time with natural voices; the few without one are read by the device's own
text-to-speech. Both are free, offline, and nothing leaves the device.

### Recorded voices

`tools/make_voices.py` makes them with Kokoro, a free, open voice model
(Apache 2.0) that runs on an ordinary computer. Each character has their own
voice, a blend of Kokoro's voices with an Indian voice at its heart (see
`VOICES` in the script), so nobody else's game sounds like this one. A line's
mood sets its pace, Arjun and Pooja come through a phone, the children are
pitched up, everyone else gets a faint room, and all of them are levelled to
the same loudness. The player's doctor (`you`) gets no clips: they are
never voiced.

- What is said comes from `story/*.json` (every line and reply),
  `story/cases.json` (every answer and finding), `tools/task_lines.json` and
  `tools/voice_lines.json`. `tools/task_lines.gd` plays each skills lab
  station down every branch (every step too early, every order, every
  angle, every answer) and lists every line its coach can say;
  `tools/voice_lines.gd` runs the test suite and then every operation and
  ward day again well, shakily and badly while `Speech` notes each line it
  is asked to say (the theatre and ward coaching).
- Every line is acted the same way as the story (below), so coaching never
  sounds flatter than the scene around it.
- The player's name ({called}) is said as "Doctor", so one clip fits every
  player. Nobody else says the player's name ({name}, {first}): a recording
  can't. A line from code with numbers in it is recorded whole as it was
  heard; for numbers it never said, the words between the numbers plus clips
  of each number on its own are kept too, and `VoiceBank` joins them up
  ("Heart rate" + "88" + "and slowing"). Training lines are written so their
  numbers come from a short list (rounded angles, counts), so each is one
  whole recording.
- Clips are named by what they say: a second run makes only what changed and
  deletes clips no line uses. `assets/voices/manifest.json` lists them by who
  says them and the line's words (lower case, no punctuation, `{called}` and
  `#` for numbers); exports include it through the preset's include filter.
- Names the model says wrongly are spelt as they are said in `RESPELL`.
- Casualty's made-up patients speak in ten voices of their own (`pm_*` and
  `pf_*` in `VOICES`): every line in `tools/patient_lines.json` (written by
  `tools/patient_lines.gd` from `PatientVoices.catalogue()`) is acted in
  each voice that could say it, and the game joins an answer from them.

```sh
pip install kokoro-onnx scipy          # and ffmpeg
# kokoro-v1.0.onnx and voices-v1.0.bin from
# https://github.com/thewh1teagle/kokoro-onnx/releases (model-files-v1.0)
godot --headless --path . -s res://tools/task_lines.gd    # after changing a skills lab station's lines
godot --headless --path . -s res://tools/voice_lines.gd -- tools/voice_lines.json   # after new code lines
godot --headless --path . -s res://tools/patient_lines.gd   # after changing conditions.json or patients.json
python3 tools/make_voices.py --model DIR                # everything, one worker a core
python3 tools/make_voices.py --model DIR --only iyer   # one character again
python3 tools/make_voices.py --model DIR --sample iyer "A line to try."
godot --headless --path . --import
```

At run time `Speech.say()` asks `VoiceBank.find()` first and plays the parts
through a `RecordedVoice` on the "Spoken" bus, which sends to Voices. The speed
setting plays the clip faster or slower and a pitch shift on that bus keeps
the voice's pitch. Words are reached on a clock from each clip's word times,
so the text and the lips keep pace with it, as with the device's voices.
`test_recorded_voices.gd` checks every story line has a recording, and
`test_task_voices.gd` that every training line has one whole recording, that
`tools/task_lines.json` matches the code, and that the first two days, played
through every screen, ask for nothing unrecorded.

Story lines are acted rather than read (`performed()`): Kokoro reads every
sentence alike, so each sentence (a word or two goes with its neighbour) is
made on its own with a slightly different pace and pitch, then they're
joined with short pauses that depend on how each ends (`PAUSES`). The mood
nudges pace, pitch, loudness and pauses (`MOODS`), kept gentle on purpose:
soft, ordinary speech, never shouting. Pitch moves with ffmpeg's rubberband
filter, keeping the voice's character. `--sample WHO TEXT --mood tired`
tries a line. Changing `MOODS`, `PAUSES` or `DIRECTION_VERSION` remakes the
story clips; lines from code and cases keep their plain reading. Kokoro
can't really act, so real feeling still needs recorded people.

### The device's voices

Lines with no recording use the device's text-to-speech (Godot's
`DisplayServer.tts_*`, which on iOS is `AVSpeechSynthesizer`; it needs
`audio/general/text_to_speech` in the project settings).

- `Speech` picks the voices: English ones only, clearer (enhanced or premium)
  before standard, Indian English before other accents, never the joke voices.
  They are split into higher and lower voices by name. Each cast member has a
  `gender` (and `child`, `pace`) in `story/cast.json`; they share out the
  voices of their kind in cast order, and their
  `voice` level sets the pitch on top, so people sharing a voice still sound
  apart. `Speech.prepare()` turns the shown text into what is said ("Dr." is
  "Doctor", "120/80" is "120 over 80", shouted capitals are words) and keeps a
  map back to the shown letters.
- `SpokenLine` paces one typed line to its voice: the engine reports each
  word it reaches and the text shows up to the end of that word, so it never
  runs ahead. If the engine gives no word marks the text creeps on at about
  speaking pace; if the voice never starts, the line is typed as before.
- `ConversationUi` and `TrainingView` (coach lines, patients answering in
  exams and histories) use it.
- The player's doctor is never voiced: `Speech.say()` returns 0 for `you`,
  a chosen reply is only shown, and the player's own lines move their lips
  without the murmur (`StoryPlayer._on_syllable`).
- Lobby banter stays a murmur, and only up close: `Lobby.banter_volume()`
  sets it from the player's distance to the speaker, soft within
  `BANTER_NEAR`, fading out by `BANTER_FAR`, silent beyond (mouths still
  move), and softer again while the player is in a conversation.
- Where a line has no recording and the device has no English voice (and in
  headless tests), lines fall back to the murmur. Tests use a fake engine (`tests/unit/fake_speech.gd`)
  that sends the same events as the real one. The screenshot tool turns
  speech off (`Speech.enabled`) so shots don't wait on voices.
- Better voices: on an iPhone, Settings > Accessibility > Spoken Content >
  Voices > English, where the enhanced voices can be downloaded; the game
  prefers them by itself.

## Casualty and the clock

From Day 4, `Ward._start_shift()` makes the day's `ShiftSim` (`ShiftDay.make`).
It runs on the main thread, catching up with `profile.minutes` whenever they
move (`Ward._catch_up`), which costs about 0.4 ms per hospital hour; there is
no background thread to go wrong. The clock moves at `Ward.CLOCK_RATE`
hospital minutes a second only while the doctor is free (walking, no
conversation, task or menu, and the game in front), and each action on the
card spends minutes of its own (`ShiftSim.ASK_MINUTES` and so on). A story
beat reached more than `Ward.LATE_AFTER` minutes after it paged is late and
costs `Ward.LATE_XP`. `CasualtyRoom.sync()` builds at most one body a frame;
people already waiting sit down, newcomers walk in from the door. The HUD's
crowded tags (`LobbyHud.start_crowd`, `set_tag(..., crowded)`) make way for
each other, sickest first, and keep off the doctor.

## Patients that never run out

Every casualty patient is made on the spot from parts, and the medicine is
never made up at run time: every answer, finding, result and plan comes from
the checked library. `ShiftSim.make_patient()` takes one draw from the
arrivals stream to seed a `SeededRandom` for everything about who the
patient is, so the day's arrivals and their times never depend on it, and
`PatientMaker.build()` does the rest in about a tenth of a millisecond:

- The illness (`Conditions.pick`, by `weight`, only those whose `from_day`
  has come and that fit a returning patient's age and sex) and its stage:
  some arrive `late`, further along and worse (a burst appendix, cerebral
  malaria, DKA that waited two days), with their own answers, findings,
  results, start and pace.
- A mix or twist (`extras` in `story/patients.json`, 40 percent of those
  that fit): warfarin, a pregnancy, years of steroids, weak kidneys, the
  drinking, a penicillin allergy. A known one is on the card in amber; a
  hidden one has to be caught by asking, examining or testing. Each fit
  brings its own checked right plan and the usual right plan becomes the
  trap, with two of the usual wrong ones.
- Who they are: a job for their age and sex (the illness's own list when
  it has one), who came in with them (a relative shares their surname), a
  temper (`personalities`: how they open, a last word after "Anything
  else?", patience) and a voice that fits the speaker's age and sex and
  shares a tone with the temper. A small child's illness is told by a
  parent, heat stroke by the colleague who brought them in.
- Names (`NameMaker`) come from 17 communities, each with its own first
  names (some only for the young or the old), surnames and home towns, and
  never a name from the cast.

`PatientVoices.catalogue()` lists every line a patient can say in every
voice that could say it; `tools/patient_lines.gd` writes it to
`tools/patient_lines.json` and `make_voices.py` records it. An answer is a
hello, an opening line and the illness's answer joined together, and
`VoiceBank.find()` plays it from those clips: it splits the line at the ends
of sentences and covers it from the start with the longest run that has a
clip. `test_patients.gd` makes 1,500 patients and checks every word of
every answer is in the catalogue for that voice, and that every catalogue
line has a clip.

Patients come back. A decision records the patient in `profile.patients`
(`ShiftDay.remember`: name, community, home, age, look, voice, temper, job,
illness, outcome; the newest 40). On a later day (within
`ShiftDay.RECALL_DAYS`) an arrival is sometimes one of them instead
(`returns.chance`): with something new, back with the same trouble further
along if it went wrong (`complication`), or, if cured, dropping in with
sweets for a little XP (a "visit" event). Each comes back at most once until
seen anew (`note_return`). The records are in the morning snapshot and are
checked field by field on load (`clean_patients`).

Every `outbreak.every` days from `outbreak.first_day` an invented fever goes
round for `outbreak.lasts` days (`Outbreak.kind_on`, in an order set by the
career's hospital seed). It is labelled invented everywhere: its name, the
line under the patient's name, a coral label on the card, every
explanation, and the district health office's post on the phone's feed.
What the doctor does about it is real: isolate, support, sample and report
the cluster. Outbreak patients are never remembered.

## Mistakes and deaths

`story/mistakes.json` holds the rules and every line; `Fates` reads it once
and keeps it, and `ShiftSim` rolls the dice from its own `fate` stream, so
who walks in on a day (the `arrivals` stream) never depends on a mistake.
Patients made for a mistake (the doomed one, the forgotten bed) are made by
`ShiftSim._make_aside`, which borrows a seed from `fate` and leaves the
arrivals stream and `recent` as they were.

Every death has a fault, which the wall shows and the family scene says:
`you` (a plan that did harm), `wait` (crashed before a doctor got there),
`lab` (a wrong result, treated), `team` (a drug nodded through to the wrong
cubicle) and `nobody` (beyond saving whatever was done). How it happens:

- A crash kills with `chances.crash_death`, otherwise the patient goes up
  to intensive care as before.
- A harmful plan, a wrong result treated or a nodded read-back makes the
  patient 25 points sicker (`ShiftSim._harm`), and with
  `chances.harm_death` they die 30 to 90 minutes later.
- From `doomed_from_day`, `doomed_shift` of shifts bring someone in beyond
  saving (one of `doomed`'s conditions, very sick). The right plan still
  ends in a death 40 to 120 minutes later, at fault `nobody`.
- A test whose real result is critical for the illness (`critical`) makes
  the lab ring. Otherwise, with `lab_error`, a blood test or a gas comes
  back wrong (`lab_errors`: a burst sample, someone else's tube, a typo) and
  the lab rings about that. The card offers Repeat (the true result comes
  back after the test's minutes; a caught error is worth
  `ShiftSim.POINTS_CAUGHT`) or Treat (right for a real result, harm for a
  wrong one). Deciding without answering counts as ignoring it.
- After a right plan, with `readback_error`, Sister Priya reads it back for
  another occupied cubicle. Correct her and nothing happens; nod and the
  other patient is harmed (fault `team`) and this one waits.
- From `forgotten_from_day`, `forgotten_bed` of shifts start with a yellow
  patient the night's handover left out: already waiting an hour or two,
  shown as "No notes" on the board until seen.

At about half a day in casualty, a careful doctor loses about one patient
in twenty shifts (nobody's fault), an average one about one in four or five
and a careless one about one in three; `test_how_often_patients_die` checks
those bounds with the seeded bot.

A death is noted by `ShiftDay.note_death`: the name goes on `profile.wall`
(`Fates.wall_entry`; at most `Fates.WALL_KEEP`, in the morning snapshot, so a
restarted day takes its deaths back down; checked field by field on load by
`Fates.clean_wall`), the patient's record becomes "died" and never walks back
in, and the day counts `deaths` and `deaths_<fault>`. If the doctor saw the
patient, `Ward` opens a `FamilyCard` (at most two waiting) once the doctor is
free: the relative is whoever came in with them or a relation picked by age
(`FamilyCard.family_of`), speaking in a recorded patient voice
(`PatientVoices.catalogue` records the family lines for every voice). How the
doctor tells them is counted (`told_plain`, `told_jargon`, `told_nurse`) and
moves Sister Priya's trust. A death of someone nobody saw is only a toast.
The wall is the "The wall" tag by Ward 4's desk (`Ward.WALL_SPOT`), which
opens `WallPanel`. For a death at fault `you`, `lab` or `team`, Dr. Iyer
sends an M&M message that evening (`PhoneWriter.mortality`, lines in `mm`).

Day 5 has the first death on purpose: Mrs. Saroja Raman, 78, in bed 6, with
her son Venkat (`saroja_round`, `saroja_son`, `saroja_wall` in
`story/ward.json`). She dies whatever is done; how the son is told sets
`saroja_told_plain`, `_jargon` or `_priya`, and `Ward.STORY_DEATH` puts her
on the wall.

The phone's Maps app (`PhonePanel.PLACES`, drawn by `HospitalMap`) shows
the hospital's places and lights where the doctor is (`LobbyHud.live_place`,
set by each place) and where the story wants them next.

## The director and feelings

`story/feelings.json` holds the director's numbers (`director`), the
emotional moments (`moments`), the silly ones (`silly`) and the breathers
(`lifts`); `Feelings` reads it. `Director` (in `ShiftSim.director`, made by
`ShiftDay.make`) is stepped once a hospital minute after the world and adds
its own events to the minute's list. It keeps `tension` (0 to 100): each
event pushes it by `director.tension` (a red arrival, someone worse, a crash,
a death) and it settles by `decay` a minute, more slowly while people wait
(`busy_hold`). From that:

- A **breather**: once the shift has been `hard` and drops below half of it,
  no trouble for `breather_minutes`, the patient nobody can save
  (`ShiftSim.doomed_at`) held back until after it, and a `lift` event
  (`lift_max` a day) some minutes later. A lift may remember the doctor's
  choices with `if`/`unless` on the story flags (`Feelings.holds`: `a`, `!a`,
  `a|b`, `a&b`); those that remember are `Feelings.MEMORY_WEIGHT` times as
  likely. A lift with a `song` plays it, with its line as the radio's request.
- **Trouble**: from `trouble_from_day`, after `quiet_minutes` calm with at
  most one waiting, a yellow or red arrival (`trouble_max` a day,
  `trouble_gap` apart), made by `ShiftSim.make_aside_from(director.rng, ...)`
  so the day's own arrivals never change (`ShiftPatient.trouble` is true).
- **Silliness**: a serious scene (a red arrival, a crash, a death) rolls
  `silly_chance` once per patient, at most `silly_max` a day and `silly_gap`
  apart, and the `silly` event follows a few minutes later. The ward shows it
  only to a doctor in casualty: a toast, a line in someone's voice, a sound,
  or the goat (`Goat`, which walks itself across the walkway and frees
  itself).
- A **moment**: `Director.plan` gives `moment_chance` of days from
  `moment_from_day` a minute in `moment_window`. When it comes and the shift
  is calm (`moment_calm`), `Feelings.pick_moment` picks one not had in the
  last `Feelings.MOMENT_REST` days that fits someone here (`fit`: sex, ages,
  `alone`, `admitted`) or a colleague's (`kind: staff`), preferring someone
  in a cubicle; nobody fits and it looks again 20 minutes later. "papers"
  comes early, for an old man going up to the ward.

`WardFeelings` (made by `Ward`) shows it all. A moment opens a `MomentCard`
once the doctor is free (a patient's only in casualty, dropped if they go);
the clock stops while it's open. `Feelings.choose` counts it
(`moment_<id>` is the day, so it rests; `moments`), moves trust, sets the
choice's `flag`, and keeps a phone message for later (`payoff`: from a cast
contact, the social worker, or a relative named by `NameMaker` whose chat is
the message itself) with `PhoneBook.keep`. Lines say `patient`, `relative`
(a voice chosen by `voices` or `Feelings.RELATIVE_VOICES`, whoever came with
them if they fit) or `kid` (`boy` or `girl`); `{patient}`, `{where}`, `{his}`, `{His}`, `{him}` and `{he}`
are filled by `Feelings.fill`. The patient and relative lines are
recorded in every patient voice that could say them (`Feelings.patient_lines`,
through `PatientVoices.catalogue`).

**Colleagues' lives.** `story/arcs.json` gives each colleague needs (`people`)
that drift every three days from the career's hospital seed, and arcs: who,
the conversation (`talk`, in `story/lives.json`), the stretches of the story
it can happen in (`chapters`), how it weighs the needs, how many days later
the message comes (`after`) and what it says for each answer (`payoff` with
`if`). `Lives.today` picks the arc whose colleague wants it most over
`threshold`, from `first_day`, `gap_days` after the last, with time for its
message before the story jumps ahead. Nothing about needs is stored; the
counters `lv_<arc>` (the day they asked) and `lv_last` are, in the morning
snapshot. On a day with one, `WardFeelings` waits for the doctor standing on
Ward 4 with nothing on after `talk_from` (and not in a hard stretch); the
colleague walks up (mode `side`, through the door if they weren't there),
the conversation plays, and they go back. The message is written by
`Lives.items`, through `PhoneWriter.items`.

**Songs.** `story/songs.json` has the station, the songs (`title`, `by`,
`track`, `bpm`, `intro`, `bars_per_line`, `outro`, and `lines` with who sings
each) and the radio's `requests`. A line starts every `bars_per_line` bars
after `intro` (`Songs.line_start`); the music (`assets/music/song_*.ogg`,
made by `tools/make_music.py` from the same numbers) lasts `Songs.length`.
`SongPlayer` plays one: the request first in RJ Bunty's voice, then the music
with each line said in its singer's recorded voice on its bar. Only one plays
anywhere (`SongPlayer.active`); the background music steps back
(`Music.hold_for_song`) and stops ducking for lines while it plays.
`LyricsBanner` shows the words along the bottom with a Stop button and takes
no other taps. The night nurses sing after 23:30 on a night shift on the ward
and the canteen's jingle plays at lunch one day in `WardFeelings.DAL_EVERY`
(and the first time); a conversation, a task or a card stops a song. The
phone's Radio app plays any of them and the day's request
(`Songs.request_for`), and stops when the phone goes away or rings.

The screenshot tool sets `WardFeelings.hold`, so nothing comes round by
itself in the other shots.

## Evenings and parties

`story/life.json` holds the rules (`first_day`, `start`, `wake`,
`good_sleep`, `worst_sleep`, `hungry_sleep`, `home_every`), the evening's
activities with their costs on the clock, the canteen (`staff` per stretch of
the story, `chai` talks and `tips` per colleague, `mani`), the hostel
(`eats`, `walks`, `studies`, `scrolls`), `sleep_lines`, `mum_texts`, the
calls home (`calls`, each a talk in `story/evenings.json`, some with an
`if`), and the parties. `Life` reads it; everything it keeps is a profile
counter (names at the top of `game/core/life.gd`), so it is in the morning
snapshot and nothing runs per frame.

**When.** Every finished day on Ward 4 from `first_day` that isn't a night
shift has an evening (`Life.has_evening`). `Main._close_day` calls
`Life.day_closed`, which marks it due (`life_due`) with the minute the doctor
left; `Main.show_hospital` plays it first while `Life.evening_due` holds, so
a save from before evenings existed, or a day restarted from the title, is
never owed one. Closing the game mid-evening starts it again: nothing is kept
until `Life.go_to_bed`.

**The evening.** `Evening` (game/world/evening.gd) builds an `EveningSet`
(the canteen, the hostel room, and the party places, all from shared
pieces with the same `you`, `g1`..`g7` and `door` spots and `wide`, `talk`,
`game` shots; a shot may set `offset` and `lift` for the camera's h/v
offsets, and `play_spots` says where the doctor and the rival stand for a
game). `EveningPanel` lists what there's time for and "Go to bed".
`choose(id)` does one: chai with one of tonight's two colleagues
(`Life.staff_tonight`, `Life.had_chai`: a talk, a little trust, and their
tip for the next day's kind, `Life.kind_of`, shown again in the morning),
the radio (the "roast" song through `SongPlayer`), the walk to the hostel,
the call home (`Life.call_for`: a lost patient, a promotion, Mum's visit or
the first call first, then the ordinary ones in turn; `CallFrame` dresses
the screen as a video call with the family built off-camera at
`EveningSet.FAMILY`), food, study or scrolling. `go_to_bed()` ends it with a
lights-out card. Tests drive it with `update(delta)` and
`play_until(condition, reply, skill, seconds)`.

**Sleep.** `Life.sleep_hours(bed, ate)` counts to the alarm (`wake`), less
`hungry_sleep` on an empty stomach. The next morning `Life.morning` gives a
toast with the hours and the tip, and `Life.tremor` (0 at `good_sleep` hours
or more, 1 at `worst_sleep` or less) is handed to `OperationTask.tremor`,
which wobbles the scalpel and the needle by up to `TREMOR_REACH`;
`OperationView` says so in its kicker from `OperationTask.SHAKY`.

**Home.** `Life.days_without_home` counts from the first evening, so a career
from before evenings isn't owed calls. From two days, each morning keeps a
nag counter and `Life.items` gives Mum's message for the phone (each text
once a stretch: she escalates, never repeats). Past `home_every` days
`Life.mum_due` holds and `WardFeelings` sends Mum up to Ward 4 like a
colleague's ask (`start_mum`, talk `lf_mum_visit`, with a line from Sister
Grace when she's on the ward); `Life.mum_came` counts it.

**Parties.** Each party in `parties` has a `day` (fixed), an `arc` (Dr.
Khan's reception: the first free evening after her `khan_wedding` ask), or
comes round in `repeat` (from Day 31, every 7 days). It names its place
(`where`), the talk, its `guests`, the game (`carrom`, `antakshari`,
`dance` or `speech`) and `against` whom, `bed`, `xp`, and for a pager night
the flag for leaving (`left`, with `left_bed`). The talk's steps can say
`{"do": "game"}`, `{"do": "page"}` (the pager card over the scene, from
`pages`, with the `left_cards` card after if the doctor goes) and
`{"do": "arrive", ...}` (someone walks in late: Varun at Dr. Rao's
farewell). `Life.went` gives trust with every guest who has a meter and the
XP; `Life.skipped` takes a little. The game's result sets
`Life.result_flag(id, result)` for the talk's `if`.

**The games** (game/ui/games/) extend `MiniGame`: a card on the right with
the title, one line on how to play, a score line, the play area (which
scrolls only if it can't fit) and "Sit out" (a loss). Time passes only
through `tick()`, and `auto_step(skill)` plays a move for the tests and the
screenshot tool. `CarromGame` runs fixed-step physics on a 2x2 board, three
strikes each, ties to the doctor. `AntakshariGame` offers three songs (one
right, one already sung or wrong, one with the wrong letter) against
`seconds`; the other side forgets the words `miss` of the time, and ties go
to them. `DanceGame` plays `assets/music/party.ogg` (made by
`tools/make_music.py party` at the game's BPM) and judges taps against the
heard audio time, falling back to the frame clock if the two drift apart by
more than `DRIFT`. `SpeechGame` plays a speech from `speeches`, a line at a
time from three; the points give `great`, `ok` or `flop` against its
thresholds.

## The phone

`story/phone.json` holds the phone's people (`contacts`: a name, a colour, a
`group` of members, a `page` or `handle` for the feed) and everything that
arrives: `chats` (`id`, `chat`, `from`, `day`, `at` as "HH:MM", up to "32:00"
for a night, `text`, `photo` with `caption`, `reply` with two options,
`deleted`, `when`), answers (`answer_to` a message, `pick` one of its
replies, `delay` in minutes after the doctor answers), `calls` (`lines` and
`after` per reply, each `{"say", "text"}` with a cast id so the caller speaks
in their own voice; `busy` for a call nobody can pick up; `missed`, the
message left when nobody does), `feed`, `photos` and `lab`. A `when` is a
story condition (`flag`, `!flag`, `&`, `|`) plus `rank>=N`, `r:<id>=<pick>`
(that message was answered with that reply) and `c:<id>=a` or `=d` (that
call was answered, or wasn't). `test_phone.gd` checks every flag named is
one the game sets, every photo is one `PhotoCard.KINDS` draws and every
speaker is in the cast.

Something arrives when its day has passed or its time has come today, so a
day that ends early hands the rest over the next morning. A call rings on
its day once the doctor has been free for `LobbyHud.CALL_AFTER_FREE`
seconds, never in a conversation, task or menu, and counts as missed after
`LobbyHud.RING_FOR` or when its day goes. Text can use `{name}`, `{first}`,
`{last}`, `{called}` and `{title}`.

`profile.phone` keeps read marks (`seen`, a stamp per chat or app; `*` is a
floor set the first time a career meets the phone, so an old save starts
with only today unread), `replies`, `calls`, the day notes (`days`, written
by `PhoneBook.note_day` as a day ends) and `kept` (thank-you messages, which
depend on a live casualty). It is outside the morning snapshot, so a
restarted day keeps what was read and said. `PhoneBook.clean` checks every
field on load: shapes, ids, numbers and caps. `PhoneWriter` makes its
messages from `hash("what|name|day")`, so a career always sees the same ones,
for the last `PhoneBook.WINDOW` days only. `PhoneBook.items()` works
everything out at most once a frame (about 1.5 ms on a desktop for a Day 20
career) and the HUD looks again once a second.

## Honest saves

`SaveStore` writes version 3 saves sealed with an HMAC-SHA256 of the body,
keyed with `SaveStore.PEPPER` and a per-install secret in `user://.install`.
A broken seal, an unsealed save after the install has sealed one, or a save
copied from another install is moved to `save.tampered.json`, and the newest
good backup (`save.bak1.json` to `save.bak3.json`) loads instead, with a line
on the title screen (`Main.notice_for`). `SaveStore.make_plausible` caps
experience at a generous bound for the day. `ClockGuard` keeps the latest
date seen; while the phone's date is earlier, `DailyReward.claim`,
`DailyCase.record` and `WeeklyMystery.guess` pay nothing. Shared results end
with `DailyCase.check_code`, and `DailyCase.check_shared` checks a pasted
one. This stops editing saves and dates; someone who takes the app itself
apart can get round any of it, as with every offline game.
`test_the_game_has_no_back_doors` keeps networking, outside code and debug
keys out of `game/`.

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

The game's own code (stage 28) costs under 1.5 ms a frame in its busiest
scenes: Ward 4 with sixty people about, casualty, the phone over the ward.
What made the difference:

- **Characters out of sight wait.** `AvatarRig._process` keeps its clocks
  running but only poses a character the camera can see (its chest within
  `REACH` of the view, `_on_screen`; one frustum is shared by everyone for a
  frame). The time it missed is owed and paid on the first frame it is seen,
  so it comes back into view mid-stride where it should be. With no camera
  (tests, tools) everyone is posed. The joints posed every frame are looked
  up once per build (`_find_joints`), and eyes are touched only when a blink
  starts or ends. Each character's clock starts somewhere new, so a ward
  doesn't breathe or blink as one.
- **The voice list loads at boot, on another thread.** `VoiceBank.warm()`
  (called first thing in `Main._ready`) reads the 1.8 MB manifest in the
  background; the first line anyone speaks used to stall the game while it
  was parsed. `reset()` and the first lookup wait for it.
- **The phone keeps its messages.** `PhoneBook.items` is rebuilt only when
  something it is made from changes (`_state_key`: flags, counts, the phone's
  own state, trust, experience, the name, the wall). The clock is not one of
  them, since `has_arrived` reads it; the HUD's once-a-second check no longer
  rebuilds a hundred messages.

Measure with `tools/profile.gd` (the busiest moments, one line each: the
game code per frame as mean, 95th percentile and worst, physics, draw calls,
objects, nodes and memory; draw calls only with a window):

    godot --headless --path . -s res://tools/profile.gd
    xvfb-run -a godot --path . --resolution 1334x750 -s res://tools/profile.gd -- ward,casualty

`tools/soak.gd` plays a new career from the title for 30 minutes (or the
minutes given), choices picked and tasks done by the bot, a few seconds of
every day through the real frame loop with the phone opened on some, and the
evenings in turn (parties, chai, the hostel, a call home). After each day it
notes objects, nodes, nodes left out of the tree and memory, and fails if
they climb past the baseline (`DRIFT`, `MEMORY_DRIFT_MB`):

    godot --headless --path . -s res://tools/soak.gd -- 30

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
  It also exports the Mac app (universal, ad-hoc signed), checks both
  architectures and the signature, starts it headless for a few seconds to
  make sure it boots cleanly, and uploads it as the `DoctorsWorld-mac`
  artifact.
