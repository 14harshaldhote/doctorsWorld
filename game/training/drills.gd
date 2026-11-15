class_name Drills
extends RefCounted
## Short practice drills between days. From the end of Day 3 to the start
## of Day 28, the doctor stops in the skills lab between one day and the
## next for one station: a true story from medicine, one go at the task,
## and free XP just for turning up (more for stars and for a new best).
## The stations come round in turn, so each one is practised about every
## five days, and the XP grows with the doctor's rank. A drill can be
## skipped, and the day after it starts either way.

## The first drill comes before Day 4, the last before Day 28.
const FIRST_BEFORE := 4
const LAST_BEFORE := 28
## The stations, in the order they come round (Day 4 first).
const ORDER := ["monitor", "iv", "stitch", "instruments", "scrub"]
## Set on the save while a drill waits before the day starts.
const FLAG := "drill_due"
## XP for turning up, for each star, and for beating your best.
const TURN_UP_XP := 25
const STAR_XP := 10
const BEST_XP := 15
## Each rank adds this much again (an Intern gets the plain amount, a Head
## of Department three times it).
const RANK_STEP := 0.5
## Who says what as the drill starts, by trainer.
const OPENERS := {
	"iyer": "Dr. Iyer has ten minutes before tomorrow. She's spending them on you.",
	"grace": "Sister Grace has the lab open and the kettle on. One station, then home.",
	"tom": "Tom has the trolley laid out. He timed himself. He wants you to beat it.",
}


## The station practised before a day, or "" when no drill comes before it.
static func before_day(day: int) -> String:
	if day < FIRST_BEFORE or day > LAST_BEFORE:
		return ""
	return str(ORDER[(day - FIRST_BEFORE) % ORDER.size()])


## True when a drill waits between the end of one day and the next.
static func due_before(day: int) -> bool:
	return not before_day(day).is_empty()


## How many times the station has come round by this drill (Day 2's own
## training counts as the first visit).
static func visit(day: int) -> int:
	return 1 + (day - FIRST_BEFORE) / ORDER.size()


## The true story told before the drill on a day.
static func fact_for(day: int) -> String:
	return TrainingFacts.fact(before_day(day), visit(day))


## The XP a drill gives: for turning up, for each star and for a new best,
## more for each rank.
static func xp(rank: int, stars: int, new_best: bool) -> int:
	var plain := TURN_UP_XP + STAR_XP * clampi(stars, 0, 3) + (BEST_XP if new_best else 0)
	return int(roundf(plain * (1.0 + RANK_STEP * maxi(0, rank))))


## The most a drill can give at a rank (three stars and a new best).
static func best_xp(rank: int) -> int:
	return xp(rank, 3, true)


## A seed for the drill's task, the same until the day is played again.
static func seed_for(profile: PlayerProfile, day: int) -> int:
	return absi(hash("%s|drill|%d|%s" % [profile.name, day, before_day(day)])) % 1000003 + 1


static func opener(station: String) -> String:
	return str(OPENERS.get(str(TrainingTask.TRAINERS.get(station, "iyer")), OPENERS["iyer"]))
