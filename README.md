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
(it's kept safe on the `swift-prototype` branch). Stages 1 to 5 of the 3D game
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
  is speaking, lips that keep time, and a murmur of a voice. Nurses gossip by
  the vending machine whether you're listening or not.
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

Screenshots of every screen are rebuilt automatically after each change, on
the [`screenshots` branch](../../tree/screenshots).

## For developers

Building, testing and running the game on a device are covered in
[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).
