class_name Career
extends RefCounted
## What the career map shows: every rank as a stop on the road (done, here,
## or locked with a teaser), the goals that stand between the doctor and the
## next stop, the roads a Senior Resident will one day choose between, and
## the never-ending days at the top.

## Each rank's stop: when it happens, what it's like, and the teaser shown
## while it's still locked.
const STOPS := [
	{"rank": Rank.INTERN, "days": "Days 1 to 8",
		"line": "Coffee, a pager and Dr. Iyer's eyebrows. You learn where everything is, mostly by walking into it.",
		"teaser": ""},
	{"rank": Rank.JUNIOR_RESIDENT, "days": "Days 9 to 13 · eight months later",
		"line": "Operations of your own, a stone that wasn't a stone, and Dr. Sethi's first go at taking the credit.",
		"teaser": "Locked. Promised: a kitchen accident, your first keyhole operation, and a senior who signs your work as his."},
	{"rank": Rank.SENIOR_RESIDENT, "days": "Days 14 to 18 · a year later",
		"line": "An intern of your own. Now you're the one with the eyebrows, na.",
		"teaser": "Locked. Promised: an intern more scared than you were, a night with the whole floor, and the meeting where mistakes get names."},
	{"rank": Rank.SURGEON, "days": "Days 19 to 23 · three months later",
		"line": "Your name on the theatre door. Also on every complaint.",
		"teaser": "Locked. Promised: your own team, your own list, a bus crash, and an old signature in the basement."},
	{"rank": Rank.HEAD_OF_DEPARTMENT, "days": "Days 24 to 27 · six months later",
		"line": "A strike, a rival, a board vote, and a parking space you never get time to use.",
		"teaser": "Locked. Promised: nurses with placards, a man from CarePlus with a measuring tape, and a vote."},
	{"rank": Rank.CHIEF, "days": "Day 27 onwards",
		"line": "You run the hospital. The hospital hasn't been told.",
		"teaser": "Locked. The top floor. The big chair. Also the blame, for everything, for ever."},
]

## The roads that split at Senior Resident. Only Surgery is built so far.
const ROADS := [
	{"id": "surgery", "name": "Surgery", "open": true},
	{"id": "emergency", "name": "Emergency", "open": false},
	{"id": "children", "name": "Children's ward", "open": false},
	{"id": "heart", "name": "Heart", "open": false},
]
const ROADS_LINE := "One day a Senior Resident picks a road. Surgery is yours for now. The others are still being built, na. Patience is also a clinical skill."
const ENDLESS_LINE := "Hard calls, monsoons, festivals, outbreaks, walk-ins. It never ends. Like a hospital."


## "done", "here" or "locked" for a rank's stop.
static func stop_state(profile: PlayerProfile, rank: int) -> String:
	var held := profile.rank_held
	if rank < held:
		return "done"
	return "here" if rank == held else "locked"


## The stops in order, each {"rank", "title", "days", "line", "state"}; a
## locked stop's line is its teaser.
static func stops(profile: PlayerProfile) -> Array:
	var found: Array = []
	for stop: Dictionary in STOPS:
		var rank := int(stop["rank"])
		var state := stop_state(profile, rank)
		found.append({"rank": rank, "title": Rank.title(rank), "days": str(stop["days"]),
			"line": str(stop["teaser"] if state == "locked" else stop["line"]), "state": state})
	return found


## What stands between the doctor and the next stop, top to bottom:
## [{"text", "done"}].
static func goals(profile: PlayerProfile) -> Array:
	var found: Array = []
	var next := Rank.next(profile.rank_held)
	if next >= 0:
		var review := DayHooks.next_review(profile.day - 1)
		if review > 0 and int(DayHooks.REVIEW_DAYS[review]) == next:
			var days := review - profile.day
			var when := "today" if days == 0 else ("tomorrow" if days == 1 else "in %d days" % days)
			found.append({"text": "Review for %s on Day %d (%s)" % [Rank.title(next), review, when], "done": false})
		var level := int(Rank.FIRST_LEVELS[next])
		var have := LevelCurve.level_for_xp(profile.total_xp)
		if have >= level:
			found.append({"text": "Level %d reached. The review only needs you to turn up and not panic." % level, "done": true})
		else:
			var short := LevelCurve.total_xp_to_reach(level) - profile.total_xp
			found.append({"text": "Level %d for %s: %d XP to go (the review tops you up if you fall short)" % [level, Rank.title(next), short],
				"done": false})
	elif profile.day >= DayHooks.LAST_STORY_DAY:
		var report := ChiefDays.days_to_report(profile.day)
		found.append({"text": "Board report today" if report == 0 else "Board report in %d days" % report, "done": false})
		var milestone := ChiefDays.next_milestone(profile.day)
		found.append({"text": "Day %d is a milestone (%d days away)" % [milestone, milestone - profile.day], "done": false})
	var best := profile.count("op_streak_best")
	if best > 0:
		found.append({"text": "Best run: %d operations won in a row. Beat it." % best, "done": false})
	var letters := Letters.arrived(profile).size()
	found.append({"text": "Letters on your wall: %d of %d" % [letters, Letters.slots().size()], "done": false})
	return found


## The line under the never-ending days, with how far in the doctor is.
static func endless_line(profile: PlayerProfile) -> String:
	if profile.day < DayHooks.LAST_STORY_DAY:
		return "Locked. After the top: days without end. Nobody said the top was the end."
	return "%s You're on Day %d." % [ENDLESS_LINE, profile.day]
