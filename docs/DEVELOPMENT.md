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
  `story/cases.json` (every answer and finding) and `tools/voice_lines.json`:
  the coaching and theatre lines, listed by `tools/voice_lines.gd`, which runs
  the test suite and then every operation again well, shakily and badly while
  `Speech` notes each line it is asked to say.
- The player's name ({called}) is said as "Doctor", so one clip fits every
  player. Lines from code with numbers in them are kept as the words between
  the numbers plus clips of each number on its own, in the same voice;
  `VoiceBank` joins them up ("Heart rate" + "88" + "and slowing").
- Clips are named by what they say: a second run makes only what changed and
  deletes clips no line uses. `assets/voices/manifest.json` lists them by who
  says them and the line's words (lower case, no punctuation, `{called}` and
  `#` for numbers); exports include it through the preset's include filter.
- Names the model says wrongly are spelt as they are said in `RESPELL`.

```sh
pip install kokoro-onnx scipy          # and ffmpeg
# kokoro-v1.0.onnx and voices-v1.0.bin from
# https://github.com/thewh1teagle/kokoro-onnx/releases (model-files-v1.0)
godot --headless --path . -s res://tools/voice_lines.gd -- tools/voice_lines.json   # after new code lines
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
`test_recorded_voices.gd` checks every story line has a recording.

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
