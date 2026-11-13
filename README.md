# Doctors World

*Congratulations, you're a doctor now. Nobody checked whether you were ready.*

You spent years learning the names of bones. You graduated. Your family cried,
mostly about the fees. Now a letter says you start Monday at Riverside City
Hospital, a place where the lifts are slow, the coffee is worse, and everyone
already has an opinion about you.

Doctors World is a small, chunky, fully 3D story game for iPhone and iPad. You
make your doctor, walk the corridors, talk to people who talk back, and try to
climb from terrified intern to Chief of Medicine without killing anyone. Or at
least without killing anyone important.

> Every patient, illness and hospital in the game is made up. This is a game,
> not medical advice. If you're actually unwell, put the phone down.

## What you'll be doing

**Making yourself.** Skin, face, eyes, brows, nose, twelve hair styles, beards,
glasses, scrubs, a white coat you haven't earned yet. Spin yourself round and
admire the doctor your mother always wanted.

**Graduating, then immediately regretting it.** The story opens at your MBBS
graduation, follows you to the job letter, and drops you at the hospital door
on day one, still holding the letter like it might protect you.

**Walking around.** Tap the floor and you walk there. Tap a person and you go
and talk to them. The hospital is a real place you move through, not a menu
pretending to be one. Some rooms you see through your own eyes.

**Talking to people.** Nurses, senior doctors, rivals, patients, and patients'
families, who have done their own research. What you say changes what they
think of you, and they remember.

**Learning on the job.** Training tasks teach you the moves you'll later need
for real, like reading a monitor, picking the right instrument, or noticing
the thing the patient didn't mention.

**Operating.** Eventually someone lets you into theatre. An AI surgical team
works around you, a nurse hands you instruments (please ask for the right one),
and the patient's heart rate tells you how it's going.

**Meeting the patients.** Every patient has a story: a teenager who lied about
how it happened, a mother who won't leave the corridor, an old man who has
outlived three of his doctors and intends to outlive you.

**Hospital politics.** Who gets the good cases, who gets blamed for the bad
ones, and why the head of department suddenly wants to be your friend.

## Climbing the ladder

Experience comes from good decisions and successful operations. Experience
gets you promoted. Promotion gets you harder patients and more blame, which is
how you know you're winning.

| Rank | What it means |
| --- | --- |
| Intern | You can walk, talk and panic. |
| Junior Resident | People start asking for your opinion and then ignoring it. |
| Senior Resident | Night shifts. Fewer staff. Same number of emergencies. |
| Surgeon | Your own operations. Your own complications. |
| Head of Department | Meetings. So many meetings. |
| Chief of Medicine | Everything is your fault now. Congratulations. |

## What works right now

The game is being built in stages, and the old 2D version has been retired
(it's kept safe on the `swift-prototype` branch). Stages 1 to 8 of the 3D game
are in:

- The title screen: the hospital at dusk, an ambulance, a doctor wandering about.
- Name your doctor and choose whether people call you by your first or last name.
- The avatar creator, with every option above and a doctor you can spin round.
- The opening, about a minute and a half, starring you. Convocation day: the
  dean reads out your name, the hall claps, your sister screams, your mother
  insists the hall is dusty. A few weeks later a letter arrives. Your mum asks
  whether you'll even eat properly there, and you get to answer (she remembers).
  Then Monday morning, an ambulance, and a very large building. Hold anywhere
  to skip it, if you're the kind of person who skips weddings too.
- Day 1 in the hospital lobby. Dr. Meera Iyer meets you at the door with a
  coffee (hers) and a pager (yours), and notices you're late. Then you walk
  around, meet Sister Grace (who notices everything), and say hello to the
  waiting patients, who have been waiting since before you were born.
- Conversations with replies. Pick how you answer and people trust you more,
  or less, and a little meter shows you exactly how badly that went.
- People move when they talk: hands, shrugs, nods, turning to look at whoever
  is speaking, and lips that keep time. Nurses gossip by the vending machine
  whether you're listening or not, though you only catch it if you wander
  close.
- Everyone talks out loud. Every line you can read, someone actually says,
  in their own natural voice, recorded for this game, and the words appear as
  they're said instead of racing ahead. Dr. Iyer sounds like Dr.
  Iyer all game, and children sound like children. Your own doctor stays
  quiet: your lines and replies are yours to read, in whatever voice is in
  your head. The music
  ducks out of the way while anyone speaks. Too slow? Too fast? There's a
  setting. Too honest? No setting for that.
- Day 2, the skills lab. Six stations, three trainers, and a sign promising
  that everything you break is plastic. Scrub in without touching your face
  (you will want to). Read a patient monitor before Dr. Iyer reads you.
  Interview Mr. Kumar, who is Dr. Iyer in a terrible mood, and find what
  could kill him in five questions. Learn the instruments, then call for them
  while Tom waits with his eyebrows. Put in an IV line with hands that won't
  stay still. Stitch a cut neatly, because patients judge you by the scar.
- Every task is scored out of 100 with up to three stars, and the score card
  tells you exactly what you did wrong and why it would have mattered.
  Try again as often as you like; only your best counts, and only
  improvements earn more XP. Finish all six and Dr. Iyer has news about
  tomorrow.
- Day 3, your first operation. Rohit, nineteen, has appendicitis and finals on
  Thursday. His mother has diagnosed gas. You get his consent anyway, and how
  you handle her decides whether she trusts you or the internet. Ask the right
  questions (he's been hiding the pain for a day, he's allergic to something)
  and they come back to save you later. Wait too long and his appendix makes
  its own decisions.
- Theatre 2: scrub in, then the time-out, where the board says the wrong side
  and someone has to say so. Call for instruments from Tom, who hands you
  exactly what you asked for, even when it's wrong. Trace the incision, hold
  the wound open, find the appendix, clamp it, cut it. Something will go
  wrong (bleeding, a crashing blood pressure, an allergic reaction) and Dr.
  Khan will tell you so in a voice you will hear in your sleep. Count the
  swabs before you close, because "probably all of them" is not a number.
- Do well and Rohit is fine. Do badly and Dr. Iyer says "My hands" and takes
  over, and then you get to explain that to his mother. Afterwards Dr. Iyer
  tells you what she really thought, and the next morning the pager tells you
  how he's doing.
- Days 4 to 8, the surgical ward. Six beds, a trolley in admissions, a side
  room everyone wants, and an X-ray viewer that hums. Sister Grace runs the
  handover; Dr. Iyer runs you. A pager card tells you who's next.
- Five patients, each with a story. Mrs. Lakshmi Pillai has pain under her
  ribs and a secret her son doesn't know, and he's on a video call asking.
  Kunal, an influencer with a sore wrist, is filming you and would like the
  side room. Little Aarav swallowed something round and shiny: read the
  X-ray and decide whether it's a coin that can wait or a battery that
  can't. Mr. Joseph Fernandes, 81, has a blocked bowel and a family who
  disagree about what he wants, and nobody has asked him.
- Examining patients, a new skill: tap where to look, listen or press, be
  gentle where it hurts, and decide what's wrong. Reading X-rays: the front
  view, the side view, a closer look, and then a decision a child depends on.
- The night on call. The lights go down, Mrs. Banerjee can't sleep, and at
  two in the morning an unknown motorbike rider comes in bleeding while the
  monitor counts. Press on the right place first. Then his phone rings.
- Bed politics. Mr. Vikram Malhotra, the administrator, needs two beds by
  tonight and would like a doctor to agree with him. Whether you check each
  patient, refuse, or hand the beds over comes back to you when Dr. Anand
  Rao, the head of surgery, asks what you saw this week.
- The review. Dr. Rao reads the week back to you, the letters arrive, and if
  you've earned it you finish Day 8 as a Junior Resident. Experience now
  shows your level; rank comes from being promoted. The next morning is an
  ordinary day, which is somehow worse.
- Music. A minute or more of each, so it doesn't loop in your head like a
  pager: a warm tune for the title, an easy one for the ward, a tense one for
  theatre (no drums: the heart monitor keeps the beat, and you'd rather it
  kept going), a lonely piano for the night shift, an urgent one for when the
  doors bang open, a sad one for when things go wrong, and a fanfare when
  you're promoted, which is the only time anyone in a hospital gets one. Buttons click, the monitor beeps with the patient's heart (lower
  when their oxygen drops, so you'll hear it before you see it), and good
  scores chime.
- Settings, from the title screen or the pause menu: separate volumes for
  music, sound effects and voices; reading lines aloud (off, slower, normal or
  faster); bigger text, which grows everywhere at once;
  Reduce motion, for people who'd rather the camera didn't swoop; a
  colour-blind-safe monitor in blue and orange with arrows, because "the red
  number" is not a diagnosis; and Battery saver, which older iPhones pick by
  themselves.
- Things move like they mean it: screens fade in, buttons push in when you
  tap them, score cards pop up and the stars land one at a time, and your
  promotion comes with confetti.
- Room for the notch and the home bar on newer iPhones, and older iPhones
  have about half as much to draw, so the hospital runs smoothly on phones as
  tired as the staff. The sound plays even with the silent switch on, because
  the game has its own volume settings and you'd only turn them all off anyway.
- Eight months later. You're a Junior Resident now, which means the pager no
  longer makes you jump, mostly, and the cases come with real operating
  theatres attached. The team walks you in, gowns up, and Dr. Khan briefs you
  with whatever you did or didn't ask on the ward.
- Deepa cut her hand on a broken glass while cooking, and the glass is still
  in there somewhere. Find it before you find a tendon. Did you ask about her
  last tetanus jab? The time-out board will.
- Mr. Bansal was admitted overnight by Dr. Sethi as a kidney stone. Examine
  him properly and you find a pulsing lump that is very much not a stone.
  Skip it and he collapses at noon, and everyone wants to know who saw him
  last.
- Your first keyhole operation: Mrs. Ansari's gallbladder. Put the ports in,
  fill her belly with gas (between 12 and 15, not "a bit more"), find the
  green pear under the liver and keep well away from the duct that looks
  exactly like the one you want.
- The department meeting, in a seminar room with a projector and a photo
  nobody remembers posing for. Dr. Sethi presents "his" case. It was yours.
  Speak up, ask him an awkward question, or let it go and watch it come back.
- Raju, a builder with a stuck hernia, arrives at the same moment as a board
  member's mother with heartburn and opinions. One of them is an emergency.
  See the wrong one first and you'll see exactly what fifty minutes does to a
  loop of bowel.
- Every operation is random, and every case can be easy, hard (ask for a
  hint, pay for it in points) or extreme (the board is wrong, two things go
  wrong at once, and nobody is giving you hints).
- The review, with Dr. Rao, Dr. Iyer and an empty chair. Yours. They
  remember the hand, the lump, the credit and the VIP, and if you've earned
  it you walk out a Senior Resident.
- A year later. Senior Resident: an intern of your own, Dr. Zoya Qureshi,
  who is keen, terrified, and writes drug charts at three in the morning.
  Teach her, watch her, or throw her in. She remembers which.
- Mrs. Gomes, eighty-one, broke her hip and would like someone who doesn't
  whisper. Her son drove five hours from Pune to sign things on her behalf.
  She is perfectly capable of signing them herself, if anyone asks her.
- Check Zoya's drug chart before it reaches a patient: a dose a thousand times
  too big, an antibiotic she's allergic to, a blood thinner nobody stopped.
  Tap the line, say what's wrong, and sign. Accuse a correct line and she'll
  explain, politely, why you're wrong. Miss the blood thinner and you'll meet
  it again in theatre, where it's much redder.
- Fix her hip with Dr. Bhatt from orthopaedics. Read the X-ray, line
  the break up, and put a guide wire through the middle of the bone, not the
  joint, then a screw and a plate. Measure twice. The bone doesn't care how
  confident you sounded.
- Your first night in charge of the whole floor. Mr. Nanda's pulse is
  climbing after his bowel operation. Whether Zoya calls you at eleven or
  sits on it until one depends on what you taught her on Monday.
- Two in the morning, a scaffolder falls two floors. Find the bleeding you
  can't see, then open his belly with Dr. Sethi and decide: save the spleen,
  or take it out. Mind the pancreas. It's right there and it holds grudges.
- The M&M meeting, where doctors talk about what went wrong. Zoya presents.
  Someone gets the credit. Then a budget vote: a surgical robot, or a second
  doctor at night. You were alone on Tuesday night. Dr. Rao lets you decide.
- The review, again. Same table, different chair. Earn it and you walk out
  a Surgeon.

Screenshots of every screen are rebuilt automatically after each change, on
the [`screenshots` branch](../../tree/screenshots).

## For developers

Building, testing and running the game on a device are covered in
[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).
