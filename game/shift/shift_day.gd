class_name ShiftDay
extends RefCounted
## The day's casualty: whether it's open, how busy it is, its seed, when the
## shift ends and how a day's work there is counted. Casualty opens on the
## first ward day and never closes again.
##
## Every career has its own hospital: a number made once (the counter
## "hospital_seed") decides who walks in on every day of it. The same day
## started again brings the same people at the same times.

const FIRST_DAY := 4
## How busy casualty is (ShiftSim's load): half on the first ward day,
## rising a little each day to a normal day by Day 14, then busier with
## each of the Chief's tiers, up to MOST.
const FIRST_LOAD := 0.5
const DAILY_RISE := 0.05
const TIER_RISE := 0.1
const MOST := 1.4
## The free clock stops here (hospital minutes): 20:00 for a day shift,
## 08:00 the next morning for a night.
const DAY_END := 20 * 60
const NIGHT_END := 32 * 60
## The gentle start on the first ward day: a sprained wrist, then a tummy bug.
const FIRST_ARRIVALS := [[20, "wrist_fracture"], [70, "gastro"]]


static func open(day: int) -> bool:
	return day >= FIRST_DAY


static func load_for(day: int) -> float:
	if not open(day):
		return 0.0
	var amount := FIRST_LOAD + DAILY_RISE * (day - FIRST_DAY)
	amount = minf(amount, 1.0)
	return minf(MOST, amount + TIER_RISE * ChiefDays.tier(day))


## The career's own seed, made the first time it's needed. Kept in the
## morning snapshot too, so a day started again keeps the same hospital.
static func hospital_seed(profile: PlayerProfile) -> int:
	var seed_value := profile.count("hospital_seed")
	if seed_value <= 0:
		seed_value = absi(hash("%d|%d|%s" % [Time.get_ticks_usec(), Time.get_unix_time_from_system(), profile.name])) \
			% 999983 + 1
		profile.set_count("hospital_seed", seed_value)
		if int(profile.morning.get("day", -1)) == profile.day:
			var counters: Dictionary = profile.morning.get("counters", {})
			counters["hospital_seed"] = seed_value
			profile.morning["counters"] = counters
	return seed_value


static func seed_for(profile: PlayerProfile, day: int) -> int:
	return absi(hash("casualty|%d|%d" % [hospital_seed(profile), day])) % 1000003 + 1


## The day's shift, starting at a hospital minute, or null when casualty
## isn't open yet.
static func make(profile: PlayerProfile, day: int, start_minute: int) -> ShiftSim:
	if not open(day):
		return null
	var sim := ShiftSim.new(seed_for(profile, day), start_minute, load_for(day))
	if day == FIRST_DAY:
		sim.first_arrivals = FIRST_ARRIVALS.duplicate(true)
	return sim


static func end_minute(night: bool) -> int:
	return NIGHT_END if night else DAY_END


## Counts a decision in the career: {"xp"}. Kept small next to the story.
static func record(profile: PlayerProfile, result: Dictionary) -> int:
	var xp := ShiftSim.xp_for(int(result.get("score", 0)))
	profile.total_xp += xp
	profile.add_count("casualty_seen", 1)
	if bool(result.get("right", false)):
		profile.add_count("casualty_right", 1)
	return xp


## The end-of-day line for casualty, or "" if nobody was seen.
static func summary_line(sim: ShiftSim, xp: int) -> String:
	if sim == null:
		return ""
	var tally := sim.summary()
	if int(tally["seen"]) == 0:
		return ""
	var line := "Casualty: %d seen, %d right" % [int(tally["seen"]), int(tally["right"])]
	if int(tally["crashed"]) > 0:
		line += ", %d to intensive care" % int(tally["crashed"])
	return line + ", +%d XP" % xp
