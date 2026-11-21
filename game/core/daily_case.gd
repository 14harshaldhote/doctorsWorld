class_name DailyCase
extends RefCounted
## The 60-second case: one quick emergency a real-world day, the same for
## every doctor that day (seeded by the date), played once against one
## minute on the clock. Weekdays get harder towards the weekend: easy
## Monday to Wednesday, hard Thursday and Friday, extreme at the weekend.
## Playing on days in a row builds a streak; a perfect case pays extra.
##
## The record lives in the profile's counters: the date last played (as
## 20261119), the streak, the best streak, cases played, perfect cases and
## the last score.

const SECONDS := 60.0
const BASE_XP := 30
## On top of the score's share, per day of the streak (up to a week).
const STREAK_XP := 5
const PERFECT_XP := 25
const LEVELS_BY_WEEKDAY := ["extreme", "easy", "easy", "easy", "hard", "hard", "extreme"]
## The first 60-second case, case #1. The share card numbers the rest from
## it, so friends playing the same day share a number.
const FIRST_DATE := "2026-11-19"
## Each step's word on the share card: wrong, half right, right. Plain
## words, no emoji.
const MARK_WORDS := ["wrong", "half right", "right"]
## The share card's last word, by how it went. Picked by the date, so the
## same result on the same day says the same thing.
const BRAG := {
	"perfect": [
		"Dr. Iyer said acceptable. Out loud. I'm framing it.",
		"Zero mistakes. Main character energy, honestly.",
		"Flawless. The patient didn't even need me. Rude.",
		"Perfect. The nurse looked mildly impressed. Mildly.",
	],
	"some": [
		"The patient lived. My ego, less so.",
		"Not perfect. The patient doesn't need to know.",
		"Kind of mid, but the patient's fine. That's the bar, right?",
		"Some right, some... learning opportunities.",
	],
	"none": [
		"Dr. Iyer took over. We don't talk about it.",
		"The patient is fine. No thanks to me.",
		"Down bad. The nurse knew more than me.",
		"I panicked. The patient was very understanding.",
	],
	"slow": [
		"Ran out of time. Casualty doesn't do extensions.",
		"The minute ended before I did.",
		"Sixty seconds. I needed sixty-one. Classic.",
	],
}


## The date as a number: "2026-11-19" is 20261119.
static func date_number(date: String) -> int:
	return int(date.replace("-", ""))


## Which quick case comes on a date. Every doctor gets the same one. The
## days go in rounds of six, each a seeded shuffle of all six cases, so a
## case comes once a round and never two days running (where two rounds
## meet, the new round's first two swap if they would repeat).
static func case_for(date: String) -> String:
	var day := int(Time.get_unix_time_from_datetime_string(date + "T12:00:00")) / 86400
	var size := QuickCases.IDS.size()
	var round_index := floori(day / float(size))
	var order := _round(round_index)
	if order[0] == _round(round_index - 1)[size - 1]:
		var first: String = order[0]
		order[0] = order[1]
		order[1] = first
	return str(order[posmod(day, size)])


static func _round(round_index: int) -> Array:
	return SeededRandom.new(absi(hash("daily|%d" % round_index)) % 1000003 + 1).shuffled(QuickCases.IDS)


## Which 60-second case this is, counting from the first one: case #1 was
## FIRST_DATE.
static func case_number(date: String) -> int:
	var first := int(Time.get_unix_time_from_datetime_string(FIRST_DATE + "T12:00:00")) / 86400
	var day := int(Time.get_unix_time_from_datetime_string(date + "T12:00:00")) / 86400
	return maxi(1, day - first + 1)


static func seed_for(date: String) -> int:
	return absi(hash("daily-seed|" + date)) % 1000003 + 1


static func level_for(date: String) -> String:
	var weekday := int(Time.get_datetime_dict_from_datetime_string(date + "T12:00:00", true).get("weekday", 1))
	return str(LEVELS_BY_WEEKDAY[clampi(weekday, 0, 6)])


## The day's case, ready to play, with its minute on the clock.
static func make(date: String = "") -> CrisisTask:
	var when := date if not date.is_empty() else DailyReward.today()
	var task := CrisisTask.new(case_for(when), seed_for(when), level_for(when))
	task.time_total = SECONDS
	return task


static func played_today(profile: PlayerProfile, date: String = "") -> bool:
	var when := date if not date.is_empty() else DailyReward.today()
	return profile.count("daily_case_date") == date_number(when)


## The streak as it stands today: still alive if the last case was today or
## yesterday, otherwise gone.
static func streak(profile: PlayerProfile, date: String = "") -> int:
	var when := date if not date.is_empty() else DailyReward.today()
	var last := profile.count("daily_case_date")
	if last == date_number(when) or last == date_number(DailyReward.yesterday(when)):
		return profile.count("daily_case_streak")
	return 0


## Records a finished case and pays for it: {"xp", "streak", "perfect"}.
## A second case on the same day records nothing.
static func record(profile: PlayerProfile, task: CrisisTask, date: String = "") -> Dictionary:
	var when := date if not date.is_empty() else DailyReward.today()
	if played_today(profile, when):
		return {}
	var run := streak(profile, when) + 1
	var perfect := task.all_right()
	profile.set_count("daily_case_date", date_number(when))
	profile.set_count("daily_case_streak", run)
	profile.set_count("daily_case_best", maxi(run, profile.count("daily_case_best")))
	profile.set_count("daily_case_score", task.score())
	profile.set_count("daily_case_marks", marks_code(task))
	profile.set_count("daily_case_seconds", seconds_used(task))
	profile.set_count("daily_case_slow", task.timeouts)
	profile.add_count("daily_cases", 1)
	if perfect:
		profile.add_count("daily_cases_perfect", 1)
		# Kept for good: the badge for every kind of case.
		Badges.keep_flag(profile, "ever_right_" + task.case_id)
	var xp := BASE_XP + task.score() / 2 + STREAK_XP * mini(run - 1, 6) + (PERFECT_XP if perfect else 0)
	profile.total_xp += xp
	if int(profile.morning.get("day", -1)) == profile.day:
		# Like the daily XP: it survives the day being started again.
		profile.morning["total_xp"] = int(profile.morning.get("total_xp", profile.total_xp - xp)) + xp
		var counters: Dictionary = profile.morning.get("counters", {})
		for key: String in ["daily_case_date", "daily_case_streak", "daily_case_best", "daily_case_score", "daily_cases",
				"daily_cases_perfect", "daily_case_marks", "daily_case_seconds", "daily_case_slow"]:
			counters[key] = profile.count(key)
		profile.morning["counters"] = counters
	return {"xp": xp, "streak": run, "perfect": perfect}


## Each step's mark as a digit, in order (3 right, 2 half right, 1 wrong or
## never reached), read as one number: 331 is right, right, wrong.
static func marks_code(task: CrisisTask) -> int:
	var code := 0
	for index in task.steps.size():
		var mark := task.marks[index] if index < task.marks.size() else 0.0
		code = code * 10 + (3 if mark >= 0.999 else (2 if mark > 0.0 else 1))
	return code


## Whole seconds of the minute used, 1 to 60.
static func seconds_used(task: CrisisTask) -> int:
	if task.time_total < 0.0:
		return int(SECONDS)
	return clampi(ceili(SECONDS - task.time_total), 1, int(SECONDS))


## Today's result as a message for friends, or "" if today's case isn't
## played yet. It says how it went, never what the case was, so nobody's
## case is spoilt:
##   Doctors World · 60-second case #3
##   Hard · 2 of 3 right in 38s
##   Right, right, wrong
##   5 days running
##   The patient lived. My ego, less so.
##   Same case for every doctor today. Your move.
static func share_text(profile: PlayerProfile, date: String = "") -> String:
	var when := date if not date.is_empty() else DailyReward.today()
	if not played_today(profile, when):
		return ""
	var digits := str(profile.count("daily_case_marks"))
	var words: Array[String] = []
	var right := 0
	for digit in digits:
		var mark := clampi(int(digit), 1, 3)
		words.append(str(MARK_WORDS[mark - 1]))
		if mark == 3:
			right += 1
	var lines: Array[String] = []
	lines.append("Doctors World · 60-second case #%d" % case_number(when))
	lines.append("%s · %d of %d right in %ds" % [level_for(when).capitalize(), right, digits.length(),
		profile.count("daily_case_seconds", int(SECONDS))])
	var row := ", ".join(words)
	lines.append(row.substr(0, 1).to_upper() + row.substr(1))
	var run := streak(profile, when)
	if run >= 2:
		lines.append("%d days running" % run)
	var how := "some"
	if right == digits.length():
		how = "perfect"
	elif profile.count("daily_case_slow") > 0:
		how = "slow"
	elif right == 0:
		how = "none"
	var said: Array = BRAG[how]
	lines.append(str(said[absi(hash("brag|" + when)) % said.size()]))
	lines.append("Same case for every doctor today. Your move.")
	return "\n".join(lines)
