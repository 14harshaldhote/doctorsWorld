class_name WardStory
extends RefCounted
## The ward's story after the first week, as data the Ward plays: Days 9 to
## 13, eight months later, as a Junior Resident (stage 7), ending with the
## review that makes the doctor a Senior Resident.
##
## Beats use the Ward's keys (see Ward.DAYS) plus:
##   "where"     "seminar" for a beat in the seminar room (no walking)
##   "card"      with "talk": a moment passing, then the conversation
##   "at"        moves the clock on to this many minutes past midnight
##   "put"       [[who, where, condition?], ...] as the beat starts
##   "put_talked" the same, after the arrival conversation
##   "put_back"  the same, back on the ward after an operation
##   "put_end"   the same, after the last conversation
##   "brief"     a conversation in theatre before the operation
##   "team"      who is in theatre: [lead, scrub nurse, anaesthetist or ""]
##   "patient"   the operation's patient (for flags: op_<patient>_won...)
##   "op_flags"  {setup key: condition}, what the team knows going in
##   "levels"    the difficulties this case can be, one picked at random
##   "slide"     the seminar room's slide
## A task ["operate", procedure] walks the team into theatre.
## Conditions: "flag", "!flag", joined with "&".

## The first day after the time jump: from here on the ward is the
## Junior Resident's (and the quiet days after the story use QUIET_STAGING).
const FIRST_DAY := 9
## A card before the day's own card: the time between ranks.
const TIME_JUMPS := {
	9: ["Eight months later", "Junior Resident now. The pager no longer makes you jump. Mostly."],
}
## The story chapters the Ward reads conversations from, after "ward".
const CHAPTERS := ["junior"]

const DAYS := {
	9: [
		{"id": "handover", "talk": "handover9", "with": "grace"},
		{"id": "deepa", "row": "A cut hand in admissions", "go": "trolley", "talk": "deepa_arrive", "with": "deepa",
			"page": "Priya: Admissions. Kitchen accident. Her hand's wrapped in a tea towel.",
			"put": [["deepa", "trolley:sit"], ["priya", "trolley:other"]],
			"tasks": [["history", "deepa_history"], ["operate", "wound"]],
			"brief": "deepa_brief", "team": ["iyer", "tom", ""], "patient": "deepa",
			"op_flags": {"tetanus_known": "deepa_history_tetanus"}, "levels": ["easy", "hard"],
			"put_back": [["deepa", "trolley:sit"], ["iyer", "trolley:foot"], ["priya", "off"]],
			"after": "deepa_after",
			"put_end": [["deepa", "off"], ["iyer", "desk:left"]]},
	],
	10: [
		{"id": "morning", "talk": "morning10", "with": "iyer"},
		{"id": "bansal", "row": "Mr. Bansal in bed 3", "go": "bed3", "talk": "bansal_arrive", "with": "bansal",
			"page": "Dr. Iyer: Bed three. Dr. Sethi admitted him overnight. Look for yourself.",
			"put": [["bansal", "bed3:lie"]],
			"tasks": [["exam", "bansal_exam"]], "after": "bansal_after",
			"put_end": [["bansal", "off"], ["sethi", "off"]]},
		{"id": "farida", "row": "Pre-op check: Mrs. Ansari", "go": "bed2", "talk": "farida_arrive", "with": "farida",
			"page": "Grace: Bed two. Tomorrow's keyhole gallbladder. Ask her everything.",
			"tasks": [["history", "farida_history"]], "after": "farida_after"},
	],
	11: [
		{"id": "morning", "talk": "morning11", "with": "iyer"},
		{"id": "farida", "row": "Operate: Mrs. Ansari's gallbladder", "go": "bed2", "talk": "farida_consent", "with": "farida",
			"page": "Dr. Khan: Theatre 2 is ready. Bring Mrs. Ansari's consent.",
			"tasks": [["operate", "gallbladder"]],
			"brief": "farida_brief", "team": ["iyer", "tom", "khan"], "patient": "farida",
			"op_flags": {"aspirin_known": "farida_history_medicines", "allergy_asked": "farida_history_allergy"}, "levels": ["easy", "hard", "extreme"],
			"put_back": [["farida", "bed2:lie"], ["you", "bed2:side"], ["iyer", "bed2:foot"]],
			"after": "farida_after_op"},
	],
	12: [
		{"id": "meeting", "row": "Department meeting", "where": "seminar", "at": 8 * 60,
			"card": ["Seminar room · 08:00", "The monthly department meeting. Dr. Sethi is presenting."],
			"talk": "meeting", "with": "rao",
			"slide": "A LEAKING ANEURYSM, CAUGHT IN TIME\nMr. R. Bansal, 67\nPresented by Dr. K. Sethi",
			"put": [["rao", "seminar:head"], ["sethi", "seminar:screen"], ["iyer", "seminar:seat1"],
				["you", "seminar:seat2"], ["grace", "seminar:seat3"], ["malhotra", "seminar:seat4"]]},
		{"id": "raju", "row": "Emergency: a stuck hernia", "go": "trolley", "talk": "raju_arrive", "with": "raju",
			"music": "emergency", "page": "Priya: Admissions, now. Groin lump since last night. And a VIP at the desk.",
			"put": [["raju", "trolley:lie"], ["priya", "trolley:other"], ["you", "door"], ["iyer", "desk:left"],
				["grace", "desk:behind"], ["mehra", "desk:right"], ["malhotra", "desk:far"]]},
		{"id": "mehra", "row": "Mrs. Mehra in the side room", "if": "mehra_first", "go": "side", "talk": "mehra_seen",
			"with": "mehra", "page": "Mr. Malhotra: The side room. Mrs. Mehra is waiting. Please.",
			"put": [["mehra", "side:sit"], ["malhotra", "side:foot"]],
			"put_end": [["mehra", "side:lie"], ["malhotra", "off"]]},
		{"id": "raju_op", "row": "Operate: Raju's hernia", "go": "trolley", "talk": "raju_back", "with": "raju",
			"page": "Dr. Khan: Theatre 2 in ten minutes. Find out when he last ate.",
			"tasks": [["history", "raju_history"], ["operate", "hernia"]],
			"brief": "raju_brief", "team": ["iyer", "tom", "khan"], "patient": "raju",
			"op_flags": {"ate_known": "raju_history_meal", "allergy_asked": "raju_history_allergy", "delayed": "mehra_first"}, "levels": ["easy", "hard", "extreme"],
			"put_back": [["raju", "bed4:lie"], ["you", "bed4:side"], ["iyer", "bed4:foot"], ["priya", "off"]],
			"after": "raju_after"},
		{"id": "mehra_late", "row": "Mrs. Mehra in the side room", "if": "!mehra_first", "go": "side", "talk": "mehra_waited",
			"with": "mehra", "page": "Grace: Mrs. Mehra has been in the side room for two hours. Brace yourself.",
			"put": [["mehra", "side:sit"], ["malhotra", "side:foot"]],
			"put_end": [["malhotra", "off"]]},
	],
	13: [
		{"id": "letters", "talk": "letters13", "with": "grace"},
		{"id": "review", "row": "Your review with Dr. Rao", "where": "seminar",
			"card": ["Seminar room · 15:00", "Dr. Rao, Dr. Iyer and an empty chair. Yours."], "at": 15 * 60,
			"talk": "review_senior", "with": "rao", "slide": "ANNUAL REVIEW\nJunior Residents",
			"put": [["rao", "seminar:head"], ["iyer", "seminar:seat1"], ["you", "seminar:seat5"],
				["malhotra", "seminar:seat4"]]},
	],
}

## Where everyone is as each day starts.
const STAGING := {
	9: [["bg1", "bed1:lie"], ["bg2", "bed3:lie"], ["bg3", "bed5:lie"], ["banerjee", "side:sit", "banerjee_room|kunal_home"],
		["grace", "desk:behind"], ["iyer", "desk:left"], ["you", "desk"]],
	10: [["bg1", "bed1:lie"], ["farida", "bed2:sit"], ["bg3", "bed5:lie"], ["bg2", "bed6:lie"],
		["grace", "desk:behind"], ["iyer", "desk:left"], ["sethi", "desk:right"], ["you", "desk"]],
	11: [["bg1", "bed1:lie"], ["farida", "bed2:lie"], ["bg3", "bed5:lie"], ["bg2", "bed6:lie"],
		["grace", "desk:behind"], ["iyer", "desk:left"], ["you", "desk"]],
	12: [["bg1", "bed1:lie"], ["farida", "bed2:sit"], ["bg3", "bed5:lie"], ["bg2", "bed6:lie"],
		["grace", "desk:behind"], ["you", "desk"]],
	13: [["bg1", "bed1:lie"], ["raju", "bed4:sit"], ["bg3", "bed5:lie"], ["bg2", "bed6:lie"],
		["mehra", "side:sit", "!mehra_home"], ["grace", "desk:behind"], ["iyer", "desk:left"], ["you", "desk"]],
}

## Where everyone is on a quiet day after the story.
const QUIET_STAGING := [["bg1", "bed1:lie"], ["bg2", "bed3:lie"], ["bg3", "bed5:sit"], ["grace", "desk:behind"],
	["iyer", "desk:left"], ["you", "desk"]]

## The line under each day's card.
const DAY_LINES := {
	9: "Surgical ward · Junior Resident",
	10: "Surgical ward · Dr. Sethi was on call",
	11: "Theatre day · Your first keyhole operation",
	12: "Meeting day · Then whatever comes through the door",
	13: "Review day",
}

## The day's last line: the first whose condition holds.
const END_LINES := {
	9: [["op_deepa_failed", "Deepa's hand is closed. Dr. Iyer finished it. She'll heal."],
		["", "Deepa's hand is stitched. She'll be back at the stove in ten days."]],
	10: [["bansal_exam_right", "Mr. Bansal is in vascular theatre. Because you looked."],
		["", "Mr. Bansal collapsed at noon. Dr. Iyer got him to theatre in time. Just."]],
	11: [["op_farida_failed", "Farida is in recovery. It was Dr. Iyer's operation in the end."],
		["", "Farida is asleep on the ward, four small plasters and no gallbladder."]],
	12: [["op_raju_failed", "Raju is in intensive care. Long day. Longer night."],
		["op_raju_chose_resect&mehra_first", "Raju is on the ward, shorter by a loop of bowel he might have kept."],
		["op_raju_chose_resect", "Raju is on the ward, shorter by a loop of bowel that was dead when he came in."],
		["mehra_first", "Raju is on the ward. Fifty minutes late, and lucky."],
		["mehra_complaint", "Raju is on the ward. Mrs. Mehra is writing a letter."],
		["", "Raju is on the ward. Mrs. Mehra has forgiven you. Mostly."]],
	13: [["", "Senior Resident, from Monday."]],
}

## The story's choices on each day, cleared when an unfinished day starts again.
const DAY_FLAGS := {
	9: ["deepa_booster", "deepa_rushed", "jump_9"],
	10: ["bansal_sethi_told", "bansal_sethi_skipped", "farida_scared", "farida_reassured"],
	11: ["farida_consented_honest", "farida_consented_quick"],
	12: ["credit_called_out", "credit_let_go", "credit_proof", "mehra_first", "raju_first", "mehra_home",
		"mehra_charmed", "mehra_complaint"],
	13: ["sethi_apology"],
}
## The cases worked each day, whose task flags are cleared with them.
const DAY_CASES := {
	9: ["deepa_history"],
	10: ["bansal_exam", "farida_history"],
	12: ["raju_history"],
}


## True when a condition holds for profile: "", "flag", "!flag", "a&b", "a|b".
static func holds(profile: PlayerProfile, test: String) -> bool:
	if test.is_empty():
		return true
	if "|" in test:
		for part in test.split("|"):
			if holds(profile, part):
				return true
		return false
	for part in test.split("&"):
		var negated := part.begins_with("!")
		var flag := part.substr(1) if negated else part
		if profile.has_flag(flag) == negated:
			return false
	return true


static func end_line(profile: PlayerProfile, day: int) -> String:
	for entry: Array in END_LINES.get(day, []):
		if holds(profile, str(entry[0])):
			return str(entry[1])
	return ""
