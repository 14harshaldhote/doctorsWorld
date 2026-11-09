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

const DAY_START := 7 * 60


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


func level() -> int:
	return LevelCurve.level_for_xp(total_xp)


func rank() -> int:
	return Rank.for_level(level())


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
	var best: Variant = data.get("skills")
	if typeof(best) == TYPE_DICTIONARY:
		for skill: Variant in best:
			var points: Variant = best[skill]
			if typeof(skill) == TYPE_STRING and typeof(points) in [TYPE_INT, TYPE_FLOAT]:
				profile.skills[skill] = clampi(int(points), 0, 100)
	return profile
