class_name WardStory
extends RefCounted
## The ward's story after the first week, as data the Ward plays: Days 9 to
## 13, eight months later, as a Junior Resident (stage 7), ending with the
## review that makes the doctor a Senior Resident; then Days 14 to 18, a year
## on, as a Senior Resident with an intern of their own (stage 8), ending
## with the review that makes a Surgeon; then Days 19 to 23, three months
## on, as a Surgeon with a list and a team of their own (stage 9), ending with
## the interview that makes a Head of Department.
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
##   "team_swap" [[index, who, condition], ...]: the doctor's own picks
##   "patient"   the operation's patient (for flags: op_<patient>_won...)
##   "op_flags"  {setup key: condition}, what the team knows going in
##   "levels"    the difficulties this case can be, one picked at random
##   "slide"     the seminar room's slide
##   "chart_force" {line id: condition} for a drug chart: true makes that
##               line wrong this time, false keeps it right
## A task ["operate", procedure] walks the team into theatre.
## Conditions: "flag", "!flag", joined with "&".

## The first day after the time jump: from here on the ward is the
## Junior Resident's (and the quiet days after the story use QUIET_STAGING).
const FIRST_DAY := 9
## A card before the day's own card: the time between ranks.
const TIME_JUMPS := {
	9: ["Eight months later", "Junior Resident now. The pager no longer makes you jump. Mostly."],
	14: ["A year later", "Senior Resident. An intern of your own, and nights in charge of the whole floor."],
	19: ["Three months later", "Surgeon. Your own list, your own team, and nobody's hands over yours."],
}
## The story chapters the Ward reads conversations from, after "ward".
const CHAPTERS := ["junior", "senior", "surgeon"]
## Story days that are night shifts (the first week's night is Ward.NIGHT_DAY).
const NIGHTS := [16]

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
	# --- A year later: the Senior Resident ---------------------------------------
	14: [
		{"id": "handover", "talk": "handover14", "with": "zoya"},
		{"id": "gomes", "row": "A broken hip in admissions", "go": "trolley", "talk": "gomes_arrive", "with": "gomes",
			"page": "Priya: Admissions. Eighty-one, fell at home. She wants someone who doesn't whisper.",
			"put": [["gomes", "trolley:lie"], ["priya", "trolley:other"], ["zoya", "trolley:foot"]],
			"tasks": [["history", "gomes_history"]], "after": "gomes_after",
			"put_end": [["gomes", "bed2:lie"], ["priya", "off"], ["zoya", "desk:left"]]},
		{"id": "francis", "row": "Her son, from Pune", "go": "desk", "at": 17 * 60 + 30, "talk": "francis_talk", "with": "francis",
			"page": "Grace: Mrs. Gomes's son drove five hours from Pune. He wants the consent forms. Now.",
			"put": [["francis", "desk:right"], ["grace", "desk:behind"]],
			"put_end": [["francis", "bed2:chair"]]},
	],
	15: [
		{"id": "chart", "row": "Check Zoya's drug chart", "talk": "morning15", "with": "zoya",
			"tasks": [["chart", "gomes_chart"]], "coach": "zoya", "after": "chart_after",
			"chart_force": {"warfarin": "!gomes_history_medicines"}, "levels": ["easy", "hard", "extreme"]},
		{"id": "gomes_op", "row": "Operate: Mrs. Gomes's hip", "go": "bed2", "talk": "gomes_consent", "with": "gomes",
			"page": "Dr. Bhatt: Theatre 3's ready for Mrs. Gomes. Bring her consent, and yourself.",
			"put": [["francis", "bed2:chair"]],
			"tasks": [["operate", "hip"]],
			"brief": "hip_brief", "team": ["bhatt", "tom", "khan"], "patient": "gomes",
			"op_flags": {"warfarin_known": "!gomes_chart_missed_warfarin", "allergy_known": "gomes_history_allergy|gomes_chart_done"},
			"levels": ["easy", "hard", "extreme"],
			"put_back": [["gomes", "bed2:lie"], ["you", "bed2:side"], ["bhatt", "bed2:foot"]],
			"after": "gomes_after_op",
			"put_end": [["bhatt", "off"]]},
		{"id": "budget", "row": "Mr. Malhotra's budget", "go": "desk", "talk": "budget_preview", "with": "malhotra",
			"page": "Mr. Malhotra: Five minutes, Doctor. About Thursday's vote. I brought a brochure.",
			"put": [["malhotra", "desk:right"]],
			"put_end": [["malhotra", "off"]]},
	],
	16: [
		{"id": "night", "talk": "night16", "with": "sethi"},
		{"id": "nanda", "row": "Bed five: Mr. Nanda", "if": "zoya_ask|night_round_together", "go": "bed5", "at": 23 * 60,
			"talk": "nanda_round", "with": "nanda", "page": "Zoya: Bed five's pulse is 112. You said any time. So... it's any time.",
			"put": [["zoya", "bed5:foot"]],
			"tasks": [["exam", "nanda_exam"]], "after": "nanda_call", "put_end": [["nanda", "off", "nanda_called"]]},
		{"id": "nanda_late", "row": "Bed five: Mr. Nanda", "if": "!zoya_ask&!night_round_together", "go": "bed5", "at": 24 * 60 + 40,
			"talk": "nanda_round", "with": "nanda",
			"page": "Priya: Bed five. Your intern's been watching his pulse climb since ten. She didn't want to bother you.",
			"put": [["zoya", "bed5:foot"]],
			"tasks": [["exam", "nanda_exam"]], "after": "nanda_call", "put_end": [["nanda", "off", "nanda_called"]]},
		{"id": "late", "card": ["02:10", "Mr. Nanda's monitor beeps softly. Then the doors bang open."]},
		{"id": "imran", "row": "Emergency: a fall from scaffolding", "go": "trolley", "talk": "imran_arrive", "with": "imran",
			"page": "Priya: ADMISSIONS. Fell two floors. His friends carried him in.", "music": "emergency",
			"put": [["imran", "trolley:lie"], ["priya", "trolley:other"], ["zoya", "trolley:foot"]],
			"tasks": [["exam", "imran_exam"]], "coach": "priya", "after": "imran_plan"},
		{"id": "imran_op", "row": "Operate: Imran's spleen", "talk": "imran_ready", "with": "priya", "music": "emergency",
			"tasks": [["operate", "spleen"]],
			"brief": "spleen_brief", "team": ["sethi", "tom", "khan"], "patient": "imran",
			"op_flags": {"allergy_asked": "imran_allergy_asked", "delayed": "imran_ct"},
			"levels": ["easy", "hard", "extreme"],
			"put_back": [["imran", "bed4:lie"], ["you", "bed4:side"], ["sethi", "bed4:foot"], ["priya", "off"]],
			"after": "imran_after"},
		{"id": "dawn", "row": "Dawn: Mr. Nanda", "go": "bed5", "at": 30 * 60, "talk": "nanda_dawn", "with": "zoya",
			"page": "Priya: It's six. Come and see bed five before the day team arrives.",
			"put": [["nanda", "bed5:lie", "!nanda_icu"], ["nanda", "off", "nanda_icu"], ["zoya", "bed5:foot"], ["sethi", "bed5:other"]]},
	],
	17: [
		{"id": "imran", "row": "Imran and his wife", "go": "bed4", "talk": "imran_visit", "with": "rubina",
			"page": "Priya: Bed four is awake. His wife's been here since five. She has questions.",
			"put": [["rubina", "bed4:chair"]]},
		{"id": "mm", "row": "M&M meeting: Mr. Nanda", "where": "seminar", "at": 16 * 60,
			"card": ["Seminar room · 16:00", "Morbidity and mortality. Where doctors talk about what went wrong."],
			"talk": "mm", "with": "rao", "slide": "M&M · MR. H. NANDA, 58\nA leak after a bowel join\nPresented by Dr. Z. Qureshi",
			"put": [["rao", "seminar:head"], ["zoya", "seminar:screen"], ["sethi", "seminar:seat1"], ["iyer", "seminar:seat2"],
				["grace", "seminar:seat3"], ["you", "seminar:seat5"]]},
		{"id": "vote", "row": "The budget vote", "where": "seminar", "at": 17 * 60,
			"card": ["Seminar room · 17:00", "The budget committee. One robot, or one more doctor at night."],
			"talk": "vote", "with": "malhotra", "slide": "BUDGET 2027 · SURGERY\nA: Surgical robot\nB: A second night doctor",
			"put": [["malhotra", "seminar:screen"], ["zoya", "off"], ["grace", "off"], ["bhatt", "seminar:seat3"],
				["rao", "seminar:head"], ["sethi", "seminar:seat1"], ["iyer", "seminar:seat2"], ["you", "seminar:seat5"]]},
	],
	18: [
		{"id": "letters", "talk": "letters18", "with": "grace"},
		{"id": "review", "row": "Your review with Dr. Rao", "where": "seminar",
			"card": ["Seminar room · 15:00", "The same table. A different chair this time: the one by the window."], "at": 15 * 60,
			"talk": "review_surgeon", "with": "rao", "slide": "ANNUAL REVIEW\nSenior Residents",
			"put": [["rao", "seminar:head"], ["iyer", "seminar:seat1"], ["bhatt", "seminar:seat2"], ["you", "seminar:seat5"],
				["malhotra", "seminar:seat4"]]},
	],
	# --- Three months later: the Surgeon -----------------------------------------
	19: [
		{"id": "handover", "talk": "handover19", "with": "grace", "put_end": [["tom", "off"]]},
		{"id": "kurup", "row": "Your first patient: Mrs. Kurup", "go": "trolley", "talk": "kurup_arrive", "with": "kurup",
			"page": "Priya: Admissions. Sixty-four, vomiting since Saturday, belly like a drum.",
			"put": [["kurup", "trolley:lie"], ["priya", "trolley:other"], ["venu", "trolley:foot"]],
			"tasks": [["history", "kurup_history"]], "after": "kurup_after",
			"put_end": [["kurup", "bed2:lie"], ["venu", "bed2:chair"], ["priya", "off"]]},
		{"id": "kurup_op", "row": "Operate: Mrs. Kurup", "go": "bed2", "talk": "kurup_ready", "with": "kurup",
			"page": "Priya: Theatre 2 is ready for Mrs. Kurup. Your name's on the door. In capitals.",
			"tasks": [["operate", "obstruction"]],
			"brief": "obstruction_brief", "team": ["iyer", "tom", "khan"], "patient": "kurup",
			"team_swap": [[1, "neha", "team_neha"], [2, "bose", "team_bose"]],
			# A tired nurse loses count; a quick anaesthetist doesn't ask about
			# her chest; waiting for the careful one costs her bowel two hours.
			"op_flags": {"lungs_known": "kurup_history_lungs", "allergy_asked": "kurup_history_allergy",
				"chest_safe": "!team_bose|kurup_history_lungs", "delayed": "!team_bose", "lose_swab": "!team_neha"},
			"levels": ["easy", "hard", "extreme"],
			"put_back": [["kurup", "bed2:lie"], ["venu", "bed2:chair"], ["you", "bed2:side"], ["iyer", "bed2:foot"]],
			"after": "kurup_after_op",
			"put_end": [["iyer", "desk:right"]]},
	],
	20: [
		{"id": "notes", "talk": "morning20", "with": "iyer"},
		{"id": "rao", "row": "Dr. Rao and the 2004 notes", "go": "desk", "talk": "rao_swab", "with": "rao",
			"page": "Dr. Rao: Could you come to the desk? Before you see Mrs. Kurup. Please.",
			"put": [["rao", "desk:right"], ["iyer", "off"]],
			"put_end": [["rao", "bed2:other", "candour_together"], ["rao", "off", "!candour_together"]]},
		{"id": "kurup", "row": "Bed two: Mrs. Kurup", "go": "bed2", "talk": "kurup_truth", "with": "kurup",
			"page": "Priya: Mrs. Kurup's awake and asking questions. Lots of them.",
			"put_end": [["rao", "off"]]},
	],
	21: [
		{"id": "news", "talk": "morning21", "with": "grace"},
		{"id": "kurup", "row": "Bed two: good news", "go": "bed2", "talk": "kurup_wind", "with": "kurup",
			"page": "Priya: Bed two. Mrs. Kurup has news. She's very proud of it.",
			"put": [["priya", "bed2:other"]], "put_end": [["priya", "off"]]},
		{"id": "rao", "row": "Dr. Rao's meeting", "where": "seminar", "at": 16 * 60,
			"card": ["Seminar room · 16:00", "Dr. Rao asked for everyone. He has never asked for everyone."],
			"talk": "rao_retires", "with": "rao", "slide": "SURGERY\nA word from the Head of Department",
			"put": [["rao", "seminar:head"], ["malhotra", "seminar:screen"], ["sethi", "seminar:seat1"], ["iyer", "seminar:seat2"],
				["grace", "seminar:seat3"], ["you", "seminar:seat5"]]},
	],
	22: [
		{"id": "crash", "talk": "crash22", "with": "priya", "music": "emergency"},
		{"id": "triage", "row": "The ambulance bay: sort the casualties", "go": "trolley", "at": 10 * 60 + 5,
			"talk": "triage_arrive", "with": "priya", "music": "emergency",
			"page": "Priya: AMBULANCE BAY. NOW. The first ones are off.",
			"put": [["priya", "trolley:other"], ["grace", "off"], ["bg3", "trolley:lie"]],
			"tasks": [["triage", "bus_triage"]], "coach": "priya", "after": "triage_after",
			"levels": ["easy", "hard", "extreme"],
			"put_end": [["priya", "off"], ["bg3", "bed6:lie"]]},
		{"id": "evening", "row": "Evening, after the crash", "go": "desk", "at": 18 * 60, "talk": "crash_evening", "with": "iyer",
			"page": "Dr. Iyer: Desk, when you can. Everyone's alive who can be. Come and sit down.",
			"put": [["iyer", "desk:right"], ["sethi", "desk:left"], ["malhotra", "desk:behind"]],
			"put_end": [["malhotra", "off"], ["sethi", "off"]]},
	],
	23: [
		{"id": "letter", "talk": "morning23", "with": "grace"},
		{"id": "interview", "row": "Interview: Head of Department", "where": "seminar",
			"card": ["Seminar room · 11:00", "Three chairs on one side of the table. One on the other. Yours."], "at": 11 * 60,
			"talk": "review_hod", "with": "rajan", "slide": "INTERVIEW\nHead of Department, Surgery",
			"put": [["rajan", "seminar:head"], ["rao", "seminar:seat1"], ["malhotra", "seminar:seat2"], ["you", "seminar:seat5"]]},
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
	14: [["bg1", "bed1:lie"], ["bg2", "bed3:lie"], ["nanda", "bed5:sit"], ["bg3", "bed6:lie"],
		["grace", "desk:behind"], ["iyer", "desk:right"], ["zoya", "desk:left"], ["you", "desk"]],
	15: [["bg1", "bed1:lie"], ["gomes", "bed2:lie"], ["bg2", "bed3:lie"], ["nanda", "bed5:lie"], ["bg3", "bed6:lie"],
		["grace", "desk:behind"], ["iyer", "desk:right"], ["zoya", "desk:left"], ["you", "desk"]],
	16: [["bg1", "bed1:lie"], ["gomes", "bed2:lie"], ["bg2", "bed3:lie"], ["nanda", "bed5:lie"], ["bg3", "bed6:lie"],
		["priya", "desk:behind"], ["sethi", "desk:right"], ["zoya", "desk:left"], ["you", "desk"]],
	17: [["bg1", "bed1:lie"], ["gomes", "bed2:sit"], ["imran", "bed4:lie"], ["bg3", "bed6:lie"],
		["nanda", "bed5:lie", "!nanda_icu"], ["priya", "desk:behind"], ["zoya", "desk:left"], ["you", "desk"]],
	18: [["bg1", "bed1:lie"], ["gomes", "bed2:sit"], ["imran", "bed4:sit"], ["bg3", "bed6:lie"],
		["nanda", "bed5:sit", "!nanda_icu"], ["grace", "desk:behind"], ["iyer", "desk:right"], ["zoya", "desk:left"], ["you", "desk"]],
	19: [["bg1", "bed1:lie"], ["bg2", "bed3:lie"], ["bg3", "bed6:lie"],
		["grace", "desk:behind"], ["iyer", "desk:right"], ["tom", "desk:left"], ["you", "desk"]],
	20: [["bg1", "bed1:lie"], ["kurup", "bed2:lie"], ["venu", "bed2:chair"], ["bg2", "bed3:lie"], ["bg3", "bed6:lie"],
		["grace", "desk:behind"], ["iyer", "desk:right"], ["you", "desk"]],
	21: [["bg1", "bed1:lie"], ["kurup", "bed2:sit"], ["venu", "bed2:chair"], ["bg2", "bed3:lie"], ["bg3", "bed6:lie"],
		["grace", "desk:behind"], ["you", "desk"]],
	22: [["bg1", "bed1:lie"], ["kurup", "bed2:sit"], ["bg2", "bed3:lie"], ["bg3", "bed6:lie"],
		["grace", "desk:behind"], ["priya", "desk:left"], ["you", "desk"]],
	23: [["bg1", "bed1:lie"], ["kurup", "bed2:sit"], ["venu", "bed2:chair"], ["bg2", "bed3:lie"], ["bg3", "bed6:lie"],
		["grace", "desk:behind"], ["iyer", "desk:right"], ["you", "desk"]],
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
	14: "Surgical ward · Senior Resident",
	15: "Theatre day · Borrowed by the bone team",
	16: "Night shift · You're in charge",
	17: "Meeting day · Two of them",
	18: "Review day",
	19: "Theatre day · Your list, your team",
	20: "Surgical ward · An old set of notes",
	21: "Surgical ward · News from the top floor",
	22: "Major incident · The flyover",
	23: "Interview day",
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
	14: [["gomes_own_consent", "Mrs. Gomes will sign her own form tomorrow. Francis is sleeping in the chair."],
		["gomes_son_signed", "Francis signed the form. His mother hasn't been told."],
		["", "Mrs. Gomes is on the ward, first on tomorrow's list."]],
	15: [["op_gomes_failed", "Mrs. Gomes's hip is fixed. Dr. Bhatt finished it. She'll stand tomorrow, slowly."],
		["op_gomes_bleeding&gomes_chart_missed_warfarin", "Mrs. Gomes needed two units of blood. Her warfarin was never stopped."],
		["", "Mrs. Gomes's hip is fixed. She's asked for tea and a hearing aid battery."]],
	16: [["nanda_called", "Seven a.m. Two emergencies, two patients alive. Handover, then sleep."],
		["nanda_zoya_called", "Seven a.m. Mr. Nanda is in intensive care. Zoya made the call you didn't."],
		["", "Seven a.m. Mr. Nanda is on a ventilator in intensive care. The M&M is tomorrow."]],
	17: [["vote_night_doctor", "From April, nobody is alone at night. Mr. Malhotra will need a new brochure."],
		["", "The robot arrives in April. The nights stay as they are."]],
	18: [["", "Surgeon, from Monday."]],
	19: [["op_kurup_failed", "Mrs. Kurup's bowel is free. Dr. Iyer finished it. Your first list, and a hard lesson."],
		["kurup_told_now", "Mrs. Kurup is asleep. Venu knows. The pot is on Dr. Iyer's desk."],
		["", "Mrs. Kurup is asleep. The pot is on Dr. Iyer's desk, with the 2004 notes beside it."]],
	20: [["candour_together", "Dr. Rao said sorry to her face. You stood beside him."],
		["candour_rao", "Dr. Rao said sorry to her face, before the tea round."],
		["candour_late", "She knows. You nearly didn't tell her."],
		["", "Her notes say 'adhesions'. The pot says otherwise."]],
	21: [["count_rule", "Dr. Rao is retiring. The count rule goes up on Monday."],
		["", "Dr. Rao is retiring. Interviews on Friday: you, or Dr. Sethi."]],
	22: [["bus_triage_under", "Twenty-three in, nine operations. One waited who shouldn't have."],
		["", "Twenty-three in, nine operations. Nobody waited who couldn't."]],
	23: [["", "Head of Department, from the first of the month."]],
}

## The story's choices on each day, cleared when an unfinished day starts again.
const DAY_FLAGS := {
	9: ["deepa_booster", "deepa_rushed", "jump_9"],
	10: ["bansal_sethi_told", "bansal_sethi_skipped", "farida_scared", "farida_reassured"],
	11: ["farida_consented_honest", "farida_consented_quick"],
	12: ["credit_called_out", "credit_let_go", "credit_proof", "mehra_first", "raju_first", "mehra_home",
		"mehra_charmed", "mehra_complaint"],
	13: ["sethi_apology"],
	14: ["jump_14", "zoya_watch", "zoya_lead", "zoya_ask", "gomes_faced", "gomes_rushed", "gomes_own_consent", "gomes_son_signed",
		"gomes_aid_found_late", "francis_explained"],
	15: ["chart_kind", "chart_firm", "chart_reported", "gomes_reconsented", "lean_night", "lean_robot"],
	16: ["night_round_together", "nanda_called", "nanda_waited", "nanda_pain", "nanda_zoya_called", "nanda_icu",
		"imran_ct", "imran_allergy_asked", "ward_zoya", "ward_priya", "sethi_thanked"],
	17: ["imran_truth", "imran_vague", "mm_credit_zoya", "mm_took_credit", "mm_culture", "mm_own", "mm_blame_zoya",
		"vote_night_doctor", "vote_robot"],
	18: ["zoya_thanked"],
	19: ["jump_19", "team_neha", "team_bose", "kurup_consent_plain", "kurup_consent_quick", "kurup_told_now", "kurup_told_later"],
	20: ["candour_together", "candour_rao", "candour_hidden", "candour_late", "candour_lied", "kurup_promise"],
	21: ["count_rule", "sethi_fair", "sethi_dig"],
	22: ["crash_beds", "crash_called", "crash_no_photo", "crash_credit_priya", "crash_photo"],
	23: ["hod_owned", "hod_blamed", "hod_nurses", "hod_talk", "hod_board"],
}
## The cases worked each day, whose task flags are cleared with them.
const DAY_CASES := {
	9: ["deepa_history"],
	10: ["bansal_exam", "farida_history"],
	12: ["raju_history"],
	14: ["gomes_history"],
	15: ["gomes_chart"],
	16: ["nanda_exam", "imran_exam"],
	19: ["kurup_history"],
	22: ["bus_triage"],
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


## The days a time jump starts on, earliest first.
static func jump_days() -> Array[int]:
	var found: Array[int] = []
	for day: int in TIME_JUMPS:
		found.append(day)
	found.sort()
	return found


static func end_line(profile: PlayerProfile, day: int) -> String:
	for entry: Array in END_LINES.get(day, []):
		if holds(profile, str(entry[0])):
			return str(entry[1])
	return ""
