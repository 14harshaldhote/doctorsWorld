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
(it's kept safe on the `swift-prototype` branch). Stages 1 to 3 of the 3D game
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

Screenshots of every screen are rebuilt automatically after each change, on
the [`screenshots` branch](../../tree/screenshots).

## For developers

Building, testing and running the game on a device are covered in
[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).
