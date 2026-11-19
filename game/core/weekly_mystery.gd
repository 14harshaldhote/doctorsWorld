class_name WeeklyMystery
extends RefCounted
## The weekly mystery: one patient whose diagnosis nobody has made, the
## same for every doctor in a real-world week (Monday to Sunday). A new
## clue opens each weekday, five by Friday. The doctor gets one guess all
## week: guess early on fewer clues for more XP, or wait and be sure.
##
## The mysteries are in story/mysteries.json; the record is in the
## profile's counters (the week last guessed, whether it was right, on how
## many clues, and the totals).

const PATH := "res://story/mysteries.json"
const CLUES := 5
## XP for a right guess on one clue, less each clue after.
const TOP_XP := 160
const CLUE_COST := 30
const WEEKDAYS := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]

static var _all: Array = []


static func all() -> Array:
	if _all.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_all = (parsed as Dictionary).get("mysteries", [])
	return _all


## Days since 1 January 1970 for a date.
static func _day_index(date: String) -> int:
	return int(Time.get_unix_time_from_datetime_string(date + "T12:00:00")) / 86400


## The week number (weeks start on Monday) and the day in it (0 = Monday).
static func week_of(date: String) -> int:
	# 1 January 1970 was a Thursday: the first Monday is day 4.
	return floori((_day_index(date) - 4) / 7.0)


static func weekday(date: String) -> int:
	return posmod(_day_index(date) - 4, 7)


## This week's mystery. Every one comes once before any comes again.
static func for_week(week: int) -> Dictionary:
	var list := all()
	if list.is_empty():
		return {}
	return list[posmod(week * 3, list.size())]


static func current(date: String = "") -> Dictionary:
	return for_week(week_of(_when(date)))


static func _when(date: String) -> String:
	return date if not date.is_empty() else DailyReward.today()


## How many clues are open on a date: one on Monday, five from Friday.
static func clues_open(date: String = "") -> int:
	return mini(CLUES, weekday(_when(date)) + 1)


## The day a clue (0 to 4) opens, for the locked ones.
static func opens_on(clue: int) -> String:
	return str(WEEKDAYS[clampi(clue, 0, CLUES - 1)])


static func guessed(profile: PlayerProfile, date: String = "") -> bool:
	return profile.count("mystery_week", -999999) == week_of(_when(date))


static func xp_for(clues: int) -> int:
	return TOP_XP - CLUE_COST * (clampi(clues, 1, CLUES) - 1)


## The one guess of the week: {"right", "xp", "clues", "answer", "explain"}.
## A second guess in the same week changes nothing and returns {}.
static func guess(profile: PlayerProfile, option_id: String, date: String = "") -> Dictionary:
	var when := _when(date)
	if guessed(profile, when):
		return {}
	var mystery := current(when)
	var clues := clues_open(when)
	var right := option_id == str(mystery.get("answer", ""))
	var xp := xp_for(clues) if right else 0
	profile.set_count("mystery_week", week_of(when))
	profile.set_count("mystery_right", 1 if right else 0)
	profile.set_count("mystery_clues", clues)
	profile.set_count("mystery_pick", maxi(0, _option_index(mystery, option_id)))
	profile.add_count("mysteries_tried", 1)
	if right:
		profile.add_count("mysteries_solved", 1)
		var best := profile.count("mystery_best", CLUES + 1)
		profile.set_count("mystery_best", mini(best, clues))
	profile.total_xp += xp
	if int(profile.morning.get("day", -1)) == profile.day:
		profile.morning["total_xp"] = int(profile.morning.get("total_xp", profile.total_xp - xp)) + xp
		var counters: Dictionary = profile.morning.get("counters", {})
		for key: String in ["mystery_week", "mystery_right", "mystery_clues", "mystery_pick", "mysteries_tried",
				"mysteries_solved", "mystery_best"]:
			if profile.counters.has(key):
				counters[key] = profile.count(key)
		profile.morning["counters"] = counters
	return {"right": right, "xp": xp, "clues": clues, "answer": _option_text(mystery, str(mystery.get("answer", ""))),
		"explain": str(mystery.get("explain", ""))}


static func _option_index(mystery: Dictionary, option_id: String) -> int:
	var options: Array = mystery.get("options", [])
	for index in options.size():
		if str(options[index]["id"]) == option_id:
			return index
	return -1


static func _option_text(mystery: Dictionary, option_id: String) -> String:
	for option: Dictionary in mystery.get("options", []):
		if str(option["id"]) == option_id:
			return str(option["text"])
	return option_id
