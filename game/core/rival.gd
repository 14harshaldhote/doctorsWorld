class_name Rival
extends RefCounted
## Dr. Varun Khanna: the batchmate who took the CarePlus job, climbing his
## own ladder across town. The race is the XP each of them earns in a
## stretch of the career (a "month": each chapter of the story, then every
## ten Chief's days), so a time jump or a big promotion never decides it,
## only how the days are played. He earns a steady pace, has his own good
## and bad days, and gets a push whenever the player loses a patient.

const NAME := "Dr. Varun Khanna"
const SHORT := "Varun"
## The race starts with the ward; before that he is only a name on the map.
const FIRST_DAY := 4
## The first day of each stretch of the story; from the Chief's first
## morning a new stretch every ten days.
const STRETCHES := [4, 9, 14, 19, 24, 28]
const CHIEF_STRETCH := 10
## His XP a day in each stretch: between a careful and a careless player's
## (measured by playing the career through both ways).
const PACE := {4: 260, 9: 335, 14: 330, 19: 310, 24: 360, 28: 300}
## The push he gets for each patient the player loses this stretch.
const LOSS_PUSH := 60
## A difference this small is a tie.
const TIE := 20

## His day, by day (picked by the day's number): XP and what he did.
const DAYS := [
	[140, "Varun did a keyhole gallbladder and posted it with a sunset filter."],
	[90, "Varun's consultant called him 'promising' in front of the department. He has framed the minutes."],
	[-60, "Varun was found asleep in the CarePlus MRI. Inside it. Switched off, thankfully."],
	[60, "Varun gave a talk called 'Leadership in Surgery'. He has led nothing."],
	[-90, "Varun's patient asked for a different doctor. Politely. In writing. With a copy to his mother."],
	[30, "Varun started a podcast. Two episodes, eleven listeners, nine of them relatives."],
	[0, "Varun spent the day on a 'wellness retreat' paid for by CarePlus. Very well. Very rested."],
	[110, "Varun caught a missed fracture on nights. Annoyingly, a genuinely good catch."],
	[-40, "Varun argued with a scrub nurse. The scrub nurse won. Scrub nurses always win."],
	[70, "CarePlus put Varun's face on a hoarding at the highway signal. Twelve feet tall. Smiling."],
	[-70, "Varun lost a swab count and stayed three hours looking for it. It was in his pocket."],
	[50, "Varun has learnt your name. He says it in meetings now, na. Not kindly."],
	[120, "Varun did two operations back to back and called his mother between them. Both went well."],
	[-30, "A nursing student corrected Varun's scrub technique in the comments of his own reel."],
	[20, "Varun ate lunch standing up and told everyone about it."],
	[-50, "Varun's consultant took credit for his case. Welcome to medicine, Varun."],
]

const AHEAD := [
	"You're %d XP ahead of Varun this month. He's 'not even counting'. He is counting.",
	"You lead Varun by %d XP. His mother has stopped forwarding you his reels.",
	"%d XP ahead of Varun. Somewhere at CarePlus, a gym selfie is being taken about this.",
]
const BEHIND := [
	"Varun is %d XP ahead of you this month. He has already told the WhatsApp group.",
	"You're %d XP behind Varun. Arre, he's posting about it. Of course he is.",
	"Varun leads by %d XP. His hoarding at the signal looks even smugger today.",
]
const LEVEL := "Neck and neck with Varun this month. Both your mothers are praying. Separately."


## The first day of the stretch a day belongs to.
static func stretch_start(day: int) -> int:
	if day >= STRETCHES[STRETCHES.size() - 1]:
		var chief_first: int = STRETCHES[STRETCHES.size() - 1]
		return chief_first + ((day - chief_first) / CHIEF_STRETCH) * CHIEF_STRETCH
	var found := 0
	for start: int in STRETCHES:
		if day >= start:
			found = start
	return found


## The stretch's last day.
static func stretch_end(day: int) -> int:
	var start := stretch_start(day)
	if start >= STRETCHES[STRETCHES.size() - 1]:
		return start + CHIEF_STRETCH - 1
	var index := STRETCHES.find(start)
	return int(STRETCHES[index + 1]) - 1


static func pace(day: int) -> int:
	var start := stretch_start(day)
	return int(PACE.get(mini(start, STRETCHES[STRETCHES.size() - 1]), 300))


## His day: [XP, what he did].
static func day_entry(day: int) -> Array:
	return DAYS[absi(("varun_%d" % day).hash()) % DAYS.size()]


static func racing(profile: PlayerProfile) -> bool:
	return profile.day >= FIRST_DAY


## As a ward day begins: a new stretch starts counting from the player's
## XP now (after any time jump has been paid).
static func begin_day(profile: PlayerProfile) -> void:
	if not racing(profile):
		return
	var start := stretch_start(profile.day)
	var was := profile.count("rival_from")
	if was != start:
		if was >= FIRST_DAY and was < start:
			# The month before is settled: who earned more in it.
			var ahead := profile.total_xp - profile.count("rival_base") - his(profile, stretch_end(was))
			var key := "rival_won" if ahead >= TIE else ("rival_lost" if ahead <= -TIE else "rival_tied")
			profile.add_count(key, 1)
		profile.set_count("rival_from", start)
		# A career that reaches the race partway through a month (a save from
		# before there was a race) only races him from today.
		profile.set_count("rival_since", profile.day)
		profile.set_count("rival_base", profile.total_xp)
		profile.set_count("rival_losses", 0)


## A patient lost: Varun gets a push. (Counted with the day's other
## counters, so a day played again doesn't count it twice.)
static func patient_lost(profile: PlayerProfile) -> void:
	if racing(profile):
		profile.add_count("rival_losses", 1)


## What the player has earned this stretch.
static func yours(profile: PlayerProfile) -> int:
	if profile.count("rival_from") != stretch_start(profile.day):
		return 0
	return maxi(0, profile.total_xp - profile.count("rival_base"))


## What Varun has earned this stretch by the end of a day.
static func his(profile: PlayerProfile, through_day: int) -> int:
	var start := stretch_start(through_day)
	if profile.count("rival_from") == start:
		start = maxi(start, profile.count("rival_since"))
	var total := 0
	for day in range(start, through_day + 1):
		total += pace(day) + int(day_entry(day)[0])
	return maxi(0, total + profile.count("rival_losses") * LOSS_PUSH)


## How far ahead the player is at the end of a day (behind when negative).
static func lead(profile: PlayerProfile, through_day: int) -> int:
	return yours(profile) - his(profile, through_day)


## The end-of-day card's line about the race, or "".
static func line(profile: PlayerProfile, day: int) -> String:
	if not racing(profile) or profile.count("rival_from") != stretch_start(day):
		return ""
	var ahead := lead(profile, day)
	var pick := absi(("race_%d" % day).hash())
	var said := LEVEL
	if absi(ahead) >= TIE:
		var text: String = (AHEAD if ahead > 0 else BEHIND)[pick % AHEAD.size()]
		said = text % absi(ahead)
	if day == stretch_end(day):
		said += " The month ends tonight."
	return said


## "Months: you 2, Varun 1" (and the ties), or "" before a month is settled.
static func record(profile: PlayerProfile) -> String:
	var won := profile.count("rival_won")
	var lost := profile.count("rival_lost")
	var tied := profile.count("rival_tied")
	if won + lost + tied == 0:
		return ""
	var said := "Months won: you %d, %s %d" % [won, SHORT, lost]
	if tied > 0:
		said += ", %d level" % tied
	return said


## His title, the same rung as the player's (they graduated together),
## except that the Chief's job went to the player.
static func title(profile: PlayerProfile) -> String:
	if profile.rank_held >= Rank.CHIEF:
		return "Head of Surgery, CarePlus"
	return "%s, CarePlus" % Rank.title(profile.rank_held)
