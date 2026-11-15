class_name PlayerProfile
extends RefCounted
## The player's career: their name, how people address them, their look,
## and the experience they have earned.

const MAX_NAME_LENGTH := 24
const DEFAULT_NAME := "Asha Verma"

var name := DEFAULT_NAME:
	set(value):
		name = clean_name(value)
## "first" for Dr. Asha, "last" for Dr. Verma.
var address_form := "last"
var avatar := AvatarConfig.new()
var total_xp := 0
var day := 1
## True once the player has finished the creator, so Continue makes sense.
var created := false
## Minutes since midnight on the current day (07:00 when a day starts).
var minutes := DAY_START
## True once the opening story (graduation, letter, first morning) has played.
var opening_seen := false
var sound_on := true
## How much each character trusts the player, 0 to 100, by character id.
var relationships := {}
## Story facts the game remembers: what the player said and did.
var flags := {}
## Best training score per skill, 0 to 100, by training task id.
var skills := {}
## The rank the hospital has given the player (a Rank value). Experience
## makes a promotion possible; the review on the ward makes it happen.
var rank_held := Rank.INTERN
## Whole numbers the career keeps count of, by name: operations won in a
## row ("op_streak"), the best run ("op_streak_best"), and, for a Chief, the
## hospital's standing (see Standing).
var counters := {}
## How the career stood when today began: {"day", "total_xp", "minutes",
## "relationships", "flags", "skills", "rank", "counters"}. A day that is
## started again from its first beat (the game was closed halfway) goes
## back to it, so nothing is earned, promoted or decided twice.
var morning := {}
## The local date the game was last opened ("2026-11-16"), for the XP on a
## new day (DailyReward); the days in a row are the counter "day_streak".
var last_played := ""

const DAY_START := 7 * 60
## What a day keeps in the morning snapshot.
const MORNING_KEYS := ["total_xp", "minutes", "relationships", "flags", "skills", "rank", "counters"]


## Trims spaces, collapses runs of spaces and cuts overly long names.
## Letters from every language are kept.
static func clean_name(raw: String) -> String:
	var parts := raw.strip_edges().split(" ", false)
	var joined := " ".join(parts)
	return joined.substr(0, MAX_NAME_LENGTH).strip_edges()


func first_name() -> String:
	var parts := name.split(" ", false)
	return parts[0] if parts.size() > 0 else "Doctor"


func last_name() -> String:
	var parts := name.split(" ", false)
	return parts[parts.size() - 1] if parts.size() > 0 else "Doctor"


## "Dr. Asha Verma", or "Dr. Doctor" never: an empty name reads "Doctor".
func full_title() -> String:
	return "Dr. " + name if not name.is_empty() else "Doctor"


## What patients and staff call the player: "Dr. Verma" or "Dr. Asha".
func called() -> String:
	if name.is_empty():
		return "Doctor"
	return "Dr. " + (first_name() if address_form == "first" else last_name())


## How much a character trusts the player. start is used until they meet.
func trust(id: String, start: int = 50) -> int:
	return int(relationships.get(id, start))


## Changes a character's trust, kept between 0 and 100. Returns the new value.
func change_trust(id: String, delta: int, start: int = 50) -> int:
	var value := clampi(trust(id, start) + delta, 0, 100)
	relationships[id] = value
	return value


func has_flag(flag: String) -> bool:
	return bool(flags.get(flag, false))


func set_flag(flag: String, value: bool = true) -> void:
	if value:
		flags[flag] = true
	else:
		flags.erase(flag)


## The time of day as "07:05".
func clock_text() -> String:
	return "%02d:%02d" % [(minutes / 60) % 24, minutes % 60]


func pass_minutes(amount: int) -> void:
	minutes += maxi(0, amount)


func best_score(skill: String) -> int:
	return int(skills.get(skill, -1))


## Records a training score. Returns true when it beats the best so far.
func record_score(skill: String, points: int) -> bool:
	var clean := clampi(points, 0, 100)
	if clean <= best_score(skill):
		return false
	skills[skill] = clean
	return true


## A number the career keeps count of, or start if it has never been set.
func count(id: String, start: int = 0) -> int:
	return int(counters.get(id, start))


func set_count(id: String, value: int) -> void:
	counters[id] = value


## Adds to a count, kept between low and high. Returns the new value.
func add_count(id: String, delta: int, start: int = 0, low: int = 0, high: int = 1000000) -> int:
	var value := clampi(count(id, start) + delta, low, high)
	counters[id] = value
	return value


func level() -> int:
	return LevelCurve.level_for_xp(total_xp)


## The rank the player holds now.
func rank() -> int:
	return rank_held


## The rank the player's experience is enough for.
func rank_earned() -> int:
	return Rank.for_level(level())


## Moves up to the next rank. Returns the new rank.
func promote() -> int:
	var next := Rank.next(rank_held)
	if next >= 0:
		rank_held = next
	return rank_held


func to_dict() -> Dictionary:
	return {
		"name": name,
		"address_form": address_form,
		"avatar": avatar.to_dict(),
		"total_xp": total_xp,
		"day": day,
		"created": created,
		"minutes": minutes,
		"opening_seen": opening_seen,
		"sound_on": sound_on,
		"relationships": relationships.duplicate(),
		"flags": flags.duplicate(),
		"skills": skills.duplicate(),
		"rank": rank_held,
		"counters": counters.duplicate(),
		"morning": morning.duplicate(true),
		"last_played": last_played,
	}


static func from_dict(data: Variant) -> PlayerProfile:
	var profile := PlayerProfile.new()
	if typeof(data) != TYPE_DICTIONARY:
		return profile
	if typeof(data.get("name")) == TYPE_STRING:
		profile.name = data["name"]
	if data.get("address_form") in ["first", "last"]:
		profile.address_form = data["address_form"]
	profile.avatar = AvatarConfig.from_dict(data.get("avatar"))
	var xp: Variant = data.get("total_xp")
	if typeof(xp) in [TYPE_INT, TYPE_FLOAT] and float(xp) >= 0.0:
		profile.total_xp = int(xp)
	var saved_day: Variant = data.get("day")
	if typeof(saved_day) in [TYPE_INT, TYPE_FLOAT] and float(saved_day) >= 1.0:
		profile.day = int(saved_day)
	if typeof(data.get("created")) == TYPE_BOOL:
		profile.created = data["created"]
	var saved_minutes: Variant = data.get("minutes")
	if typeof(saved_minutes) in [TYPE_INT, TYPE_FLOAT] and float(saved_minutes) >= 0.0:
		profile.minutes = mini(int(saved_minutes), 48 * 60)
	for toggle: String in ["opening_seen", "sound_on"]:
		if typeof(data.get(toggle)) == TYPE_BOOL:
			profile.set(toggle, data[toggle])
	var meters: Variant = data.get("relationships")
	if typeof(meters) == TYPE_DICTIONARY:
		for id: Variant in meters:
			var value: Variant = meters[id]
			if typeof(id) == TYPE_STRING and typeof(value) in [TYPE_INT, TYPE_FLOAT]:
				profile.relationships[id] = clampi(int(value), 0, 100)
	var facts: Variant = data.get("flags")
	if typeof(facts) == TYPE_DICTIONARY:
		for flag: Variant in facts:
			if typeof(flag) == TYPE_STRING and typeof(facts[flag]) == TYPE_BOOL and facts[flag]:
				profile.flags[flag] = true
	var held: Variant = data.get("rank")
	if typeof(held) in [TYPE_INT, TYPE_FLOAT]:
		profile.rank_held = clampi(int(held), Rank.INTERN, Rank.CHIEF)
	var counts: Variant = data.get("counters")
	if typeof(counts) == TYPE_DICTIONARY:
		for id: Variant in counts:
			var value: Variant = counts[id]
			if typeof(id) == TYPE_STRING and typeof(value) in [TYPE_INT, TYPE_FLOAT]:
				profile.counters[id] = clampi(int(value), -1000000, 1000000)
	var best: Variant = data.get("skills")
	if typeof(best) == TYPE_DICTIONARY:
		for skill: Variant in best:
			var points: Variant = best[skill]
			if typeof(skill) == TYPE_STRING and typeof(points) in [TYPE_INT, TYPE_FLOAT]:
				profile.skills[skill] = clampi(int(points), 0, 100)
	var snapshot: Variant = data.get("morning")
	if typeof(snapshot) == TYPE_DICTIONARY and typeof(snapshot.get("day")) in [TYPE_INT, TYPE_FLOAT]:
		profile.morning = snapshot
	var played: Variant = data.get("last_played")
	if typeof(played) == TYPE_STRING and played.length() == 10:
		profile.last_played = played
	return profile


## Called as a day begins from its first beat. The first time, remembers how
## the career stands; if this day was begun before and is starting over (the
## game was closed halfway through), puts everything back to that morning.
## Returns true when it put things back.
func begin_day() -> bool:
	if int(morning.get("day", -1)) == day:
		var copy := to_dict()
		for key: String in MORNING_KEYS:
			if morning.has(key):
				copy[key] = morning[key]
		var back := PlayerProfile.from_dict(copy)
		total_xp = back.total_xp
		minutes = back.minutes
		relationships = back.relationships
		flags = back.flags
		skills = back.skills
		rank_held = back.rank_held
		counters = back.counters
		return true
	morning = {"day": day}
	var now := to_dict()
	for key: String in MORNING_KEYS:
		morning[key] = now[key]
	return false
