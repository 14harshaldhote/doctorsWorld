class_name DayHooks
extends RefCounted
## What keeps a career moving: how hard the cases get as the days pass, and
## what the end-of-day card says to make the next day worth starting (a
## run of operations won, how far the next review or level is, and a line
## about tomorrow).

## The days a review can promote the doctor, and the rank each one gives.
const REVIEW_DAYS := {8: Rank.JUNIOR_RESIDENT, 13: Rank.SENIOR_RESIDENT, 18: Rank.SURGEON, 23: Rank.HEAD_OF_DEPARTMENT,
	27: Rank.CHIEF}
## The last day of the written story; a Chief's days follow.
const LAST_STORY_DAY := 28
## A run of this many operations won is worth saying out loud.
const STREAK_WORTH_SAYING := 2

## A line about the day after each day: the first whose condition holds.
const TOMORROW := {
	1: [["", "Tomorrow: the skills lab. Six stations, three trainers, and a sign that says everything you break is plastic."]],
	2: [["", "Tomorrow: your first real operation. He's nineteen, and his appendix isn't waiting for his exams."]],
	3: [["op_rohit_failed", "Tomorrow: the surgical ward. Bed one is Rohit. He'll want to know what happened."],
		["", "Tomorrow: the surgical ward. Six beds, one pager, and Sister Grace's handover starts at seven sharp."]],
	4: [["beds_agreed", "Tomorrow: you promised Mr. Malhotra two beds. A minister's nephew has just arrived to collect one."],
		["", "Tomorrow: a boy has swallowed something round and shiny. A coin can wait. A battery can't."]],
	5: [["", "Tomorrow night you're on call. The lights go down at ten. The doors never lock."]],
	6: [["rider_treated", "Tomorrow: the man from last night wakes up asking for you. And Dr. Rao does his round."],
		["", "Tomorrow: Dr. Rao's round. He'll ask what you saw this week. He already knows."]],
	7: [["", "Tomorrow: your review. Dr. Rao has read every note you wrote since Monday."]],
	8: [["promoted", "Next: eight months later. A real operating theatre, a kitchen accident, and your name on the list."],
		["", "Next: eight months later. Another list, another chance, and a hand wrapped in a tea towel."]],
	9: [["", "Tomorrow: Dr. Sethi admitted a 'kidney stone' overnight. Go and press on it yourself."]],
	10: [["", "Tomorrow: your first keyhole operation. Two ducts look exactly alike. Only one is yours to cut."]],
	11: [["", "Tomorrow: the department meeting. Dr. Sethi is presenting a case. You'll recognise it."]],
	12: [["", "Tomorrow: your review. Dr. Rao, Dr. Iyer and one empty chair."]],
	13: [["", "Next: a year later. You get an intern of your own. She's terrified. So were you."]],
	14: [["", "Tomorrow: your intern's drug chart reaches the patient at eight. Read it at seven."]],
	15: [["", "Tomorrow night the whole floor is yours. Dr. Sethi is on call. From home."]],
	16: [["", "Tomorrow: the meeting where doctors say out loud what went wrong. Mr. Nanda's name is on the slide."]],
	17: [["", "Tomorrow: your review. Same table. Different chair."]],
	18: [["", "Next: three months later. Your own list, your own team, and your name on the theatre door."]],
	19: [["", "Tomorrow: the notes from her last operation come up from the basement. There's a signature on them."]],
	20: [["", "Tomorrow: news from the top floor. Somebody is leaving, and two people want the office."]],
	21: [["", "Tomorrow starts like any other morning. It stays that way until five past ten."]],
	22: [["", "Tomorrow: your interview with the board. The chair used to be a judge. Don't rehearse."]],
	23: [["", "Next: six months later. The nurses are voting, the Dean is leaving, and a stranger is measuring your ward."]],
	24: [["", "Tomorrow: one of the new day cases comes back at five in the morning. Yellow."]],
	25: [["", "Tomorrow at eight the nurses walk out. At seven, you and Grace decide who nurses whom."]],
	26: [["", "Tomorrow at three the board votes for Chief of Medicine. Dr. Kapoor has been practising his pauses."]],
	27: [["", "Next: your first morning as Chief. A new intern has been in the corridor since six, reading the fire notices."]],
}


## How likely each difficulty is on a day, out of 100. The same case gets
## harder as the career goes on: gentle for a new Junior Resident, mostly
## extreme by the time the doctor runs the hospital.
static func level_weights(day: int) -> Dictionary:
	if day <= 9:
		return {"easy": 70, "hard": 30, "extreme": 0}
	if day <= 13:
		return {"easy": 45, "hard": 45, "extreme": 10}
	if day <= 18:
		return {"easy": 20, "hard": 55, "extreme": 25}
	if day <= 23:
		return {"easy": 5, "hard": 50, "extreme": 45}
	if day <= LAST_STORY_DAY:
		return {"easy": 0, "hard": 40, "extreme": 60}
	var hard := maxi(0, 30 - (day - LAST_STORY_DAY - 1) * 2)
	return {"easy": 0, "hard": hard, "extreme": 100 - hard}


## The weights for this doctor today: a doctor on a winning run is pushed a
## little harder, and one who has just lost a patient gets a gentler case.
static func weights_for(profile: PlayerProfile) -> Dictionary:
	var weights := level_weights(profile.day)
	if profile.count("op_streak") >= 3:
		var from_easy := mini(15, int(weights["easy"]))
		weights["easy"] = int(weights["easy"]) - from_easy
		weights["hard"] = int(weights["hard"]) + from_easy
		var from_hard := mini(15 - from_easy, int(weights["hard"]))
		weights["hard"] = int(weights["hard"]) - from_hard
		weights["extreme"] = int(weights["extreme"]) + from_hard
	elif profile.count("op_lost") > 0:
		var from_extreme := mini(25, int(weights["extreme"]))
		weights["extreme"] = int(weights["extreme"]) - from_extreme
		weights["hard"] = int(weights["hard"]) + from_extreme
		var from_hard := mini(20, int(weights["hard"]))
		weights["hard"] = int(weights["hard"]) - from_hard
		weights["easy"] = int(weights["easy"]) + from_hard
	return weights


## One of a case's allowed difficulties, by the day's weights. roll is a
## number from 0 up to (not including) 1.
static func pick_level(levels: Array, weights: Dictionary, roll: float) -> String:
	if levels.is_empty():
		return ""
	var total := 0
	for level: String in levels:
		total += int(weights.get(level, 0))
	if total <= 0:
		# None of them is likely today: the hardest the case allows on a late
		# day, the gentlest on an early one.
		return str(levels[levels.size() - 1] if int(weights.get("extreme", 0)) > int(weights.get("easy", 0)) else levels[0])
	var mark := roll * float(total)
	for level: String in levels:
		mark -= float(int(weights.get(level, 0)))
		if mark < 0.0:
			return level
	return str(levels[levels.size() - 1])


## Counts an operation towards the run of wins. Losing the patient to the
## senior surgeon ends the run; struggling through keeps it but adds nothing.
static func record_operation(profile: PlayerProfile, outcome: String) -> void:
	match outcome:
		"won":
			var run := profile.add_count("op_streak", 1)
			profile.set_count("op_streak_best", maxi(run, profile.count("op_streak_best")))
			profile.set_count("op_lost", 0)
			profile.set_count("op_streak_ended", 0)
		"failed":
			profile.set_count("op_streak_ended", profile.count("op_streak"))
			profile.set_count("op_streak_ended_day", profile.day)
			profile.set_count("op_streak", 0)
			profile.set_count("op_lost", 1)
		_:
			profile.set_count("op_lost", 0)


## "4 operations won in a row", or what a broken run was, or nothing.
static func streak_line(profile: PlayerProfile) -> String:
	var run := profile.count("op_streak")
	if run >= STREAK_WORTH_SAYING:
		var best := run >= profile.count("op_streak_best") and run >= 3
		return "%d operations won in a row%s" % [run, " · your best run" if best else ""]
	var ended := profile.count("op_streak_ended") if profile.count("op_streak_ended_day") == profile.day else 0
	if ended >= STREAK_WORTH_SAYING:
		return "Your run of %d ended today. Start another tomorrow." % ended
	var best_run := profile.count("op_streak_best")
	if best_run >= 3:
		return "Your best run is %d operations won. Beat it." % best_run
	return ""


## How far the next thing worth having is: a review, a board report, or
## the next level.
static func goal_line(profile: PlayerProfile) -> String:
	var parts := PackedStringArray()
	var review := next_review(profile.day)
	if review > 0:
		var days := review - profile.day
		var rank := Rank.title(int(REVIEW_DAYS[review]))
		if days == 1:
			parts.append("Tomorrow decides: %s" % rank)
		else:
			parts.append("%d days to the review for %s" % [days, rank])
	elif profile.day >= LAST_STORY_DAY:
		var days := ChiefDays.days_to_report(profile.day)
		parts.append("Board report tomorrow" if days == 1 else "Board report in %d days" % days)
		var milestone := ChiefDays.next_milestone(profile.day)
		if milestone - profile.day <= 10:
			parts.append("Day %d is %s" % [milestone, "tomorrow" if milestone - profile.day == 1 else "in %d days" % (milestone - profile.day)])
		elif ChiefDays.tier_starts(profile.day + 1):
			parts.append("The hospital gets busier tomorrow")
	var progress := LevelCurve.progress(profile.total_xp)
	if int(progress["needed"]) > 0:
		parts.append("%d XP to level %d" % [int(progress["needed"]) - int(progress["into"]), int(progress["level"]) + 1])
	return " · ".join(parts)


## The next review day after day, or 0 when there are none left.
static func next_review(day: int) -> int:
	var found := 0
	for review: int in REVIEW_DAYS:
		if review > day and (found == 0 or review < found):
			found = review
	return found


## The line about tomorrow shown as a day ends.
static func tomorrow(profile: PlayerProfile, day: int) -> String:
	for entry: Array in TOMORROW.get(day, []):
		if WardStory.holds(profile, str(entry[0])):
			return str(entry[1])
	if day >= LAST_STORY_DAY:
		return ChiefDays.teaser(profile, day + 1)
	return ""


## Everything under the day's own line on the end-of-day card:
## {"streak": ..., "goal": ..., "tomorrow": ...}, each "" when there is nothing to say.
static func end_card(profile: PlayerProfile, day: int) -> Dictionary:
	return {"streak": streak_line(profile), "goal": goal_line(profile), "tomorrow": tomorrow(profile, day)}
