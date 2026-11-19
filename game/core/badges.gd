class_name Badges
extends RefCounted
## Badges: small proofs that the doctor did something, each with a line
## that doesn't let it go to their head. A badge is earned the first time
## its rule holds and kept for good (flag "badge_<id>"), even if the count
## behind it later drops (a streak that breaks). Badges.check() is called
## as a day ends and after the daily case or the weekly mystery.

## [id, name, the line once earned, how to earn it, rule]. A rule is
## ["count", counter, at least], ["flag", flag], ["day", day], ["rank", rank],
## ["letters", how many], ["all_crises"] or ["sharp", most clues].
const ALL := [
	["promoted", "Promoted", "Dr. Rao signed it. Nobody knows why. Don't ask.", "Pass your first review.", ["flag", "promoted"]],
	["first_crisis", "Baptism by chaos", "One crisis down. The hospital has several thousand more.", "Get through your first crisis.", ["count", "crises", 1]],
	["cool_head", "Cool head", "Five crises without a single slip. Sister Grace is suspicious.", "Get five crises completely right.", ["count", "crises_right", 5]],
	["seen_it_all", "Seen it all", "Lights out, two Rameshes, a snake, an inspector. Nothing surprises you. Yet.", "Get every kind of crisis right at least once.", ["all_crises"]],
	["minute_one", "Sixty seconds", "Your first 60-second case. Most of your patients take longer to find their Aadhaar card.", "Play a 60-second case.", ["count", "daily_cases", 1]],
	["minute_three", "Habit forming", "Three days of 60-second cases in a row. Your chai is getting cold for medicine.", "Play the 60-second case three days running.", ["count", "daily_case_best", 3]],
	["minute_seven", "A full week", "Seven days running. Your family has filed a missing person report.", "Play the 60-second case seven days running.", ["count", "daily_case_best", 7]],
	["minute_perfect", "Not a second wasted", "A perfect 60-second case. Frame it. Nobody will look at it.", "Get a 60-second case completely right.", ["count", "daily_cases_perfect", 1]],
	["mystery_one", "Case closed", "You solved the weekly mystery. Somewhere, a TV detective feels threatened.", "Solve a weekly mystery.", ["count", "mysteries_solved", 1]],
	["mystery_sharp", "Monday diagnosis", "Solved on two clues or fewer. Either brilliant or lucky. We'll go with brilliant.", "Solve a weekly mystery on two clues or fewer.", ["sharp", 2]],
	["mystery_five", "The regular", "Five mysteries solved. The patients would like you to stop enjoying their illnesses so much.", "Solve five weekly mysteries.", ["count", "mysteries_solved", 5]],
	["steady_five", "Steady hands", "Five operations in a row without a loss. The anaesthetist has stopped praying out loud.", "Win five operations in a row.", ["count", "op_streak_best", 5]],
	["steady_ten", "Golden hands", "Ten in a row. The theatre staff now touch your gloves for luck. Please stop them.", "Win ten operations in a row.", ["count", "op_streak_best", 10]],
	["beat_varun", "Take that, Varun", "You beat Dr. Varun Khanna for a month. His podcast did not mention it.", "Win a month of the race.", ["count", "rival_won", 1]],
	["beat_varun_three", "Hoarding material", "Three months ahead of Varun. Somebody should put your face on the highway instead.", "Win three months of the race.", ["count", "rival_won", 3]],
	["letters_ten", "Fan mail", "Ten letters on the wall. Two of them aren't even complaints.", "Get ten letters from patients.", ["letters", 10]],
	["streak_seven", "Shows up", "Seven days running in the hospital. The canteen knows your order.", "Open the game seven days running.", ["count", "day_streak", 7]],
	["chief", "The big chair", "Chief of Medicine. You now have an office, a nameplate and everyone's problems.", "Become Chief of Medicine.", ["rank", 5]],
	["day_fifty", "Fifty days", "Fifty days in. The hospital hasn't fallen down, and you're taking the credit.", "Reach Day 50.", ["day", 50]],
	["day_hundred", "A hundred days", "A hundred days. The interns think you were born here.", "Reach Day 100.", ["day", 100]],
]


static func ids() -> Array:
	return ALL.map(func(entry: Array) -> String: return str(entry[0]))


static func entry(badge_id: String) -> Array:
	for badge: Array in ALL:
		if str(badge[0]) == badge_id:
			return badge
	return []


static func has(profile: PlayerProfile, badge_id: String) -> bool:
	return profile.has_flag("badge_" + badge_id)


static func earned(profile: PlayerProfile) -> Array:
	return ids().filter(func(badge_id: String) -> bool: return has(profile, badge_id))


## Whether a badge's rule holds now.
static func holds(profile: PlayerProfile, badge: Array) -> bool:
	var rule: Array = badge[4]
	match str(rule[0]):
		"count":
			return profile.count(str(rule[1])) >= int(rule[2])
		"flag":
			return profile.has_flag(str(rule[1]))
		"day":
			return profile.day >= int(rule[1])
		"rank":
			return profile.rank_held >= int(rule[1])
		"letters":
			return Letters.arrived(profile).size() >= int(rule[1])
		"sharp":
			return profile.count("mysteries_solved") > 0 and profile.count("mystery_best", 99) <= int(rule[1])
		"all_crises":
			for crisis: String in Crises.IDS:
				# The story's own flag counts too, for careers from before badges.
				if not profile.has_flag("ever_right_crisis_" + crisis) and not profile.has_flag("crisis_%s_right" % crisis):
					return false
			return true
	return false


## Gives every badge whose rule now holds; returns the new ones' ids.
static func check(profile: PlayerProfile) -> Array:
	var new: Array = []
	for badge: Array in ALL:
		var badge_id := str(badge[0])
		if not has(profile, badge_id) and holds(profile, badge):
			profile.set_flag("badge_" + badge_id)
			new.append(badge_id)
	return new


## A toast for new badges: "Badge: Cool head" or "3 new badges".
static func toast_text(new: Array) -> String:
	if new.is_empty():
		return ""
	if new.size() == 1:
		return "Badge: %s" % str(entry(str(new[0]))[1])
	return "%d new badges" % new.size()
