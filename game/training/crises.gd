class_name Crises
extends RefCounted
## The hospital crises (see CrisisTask): what happens, the facts on the card,
## the questions and the rules that decide the right answers, rolled from a
## seed so no two are the same. Also when each one comes: on eight days of
## the written story, then every third day once the Chief's days are
## generated, in an order seeded by the doctor's name.
##
## The rules are simplified from real Indian guidance (blood donor selection,
## fasting before an operation, snakebite treatment, dengue, insurance
## waiting periods, medico-legal cases) so the game teaches nothing wrong.

const LINES_PATH := "res://story/crisis_lines.json"
const IDS := ["power_cut", "ramesh", "crowd", "donors", "insurance", "snakebite", "dengue", "inspection"]
## The written story's crises: one a day, never on a review day.
const STORY_DAYS := {10: "ramesh", 14: "insurance", 15: "dengue", 16: "snakebite", 17: "donors", 20: "power_cut",
	24: "crowd", 26: "inspection", 21: "quick_heat", 23: "quick_asthma", 27: "quick_sepsis"}
const STORY_LEVELS := {10: ["easy", "hard"], 14: ["easy", "hard"], 15: ["easy", "hard"], 16: ["easy", "hard"],
	17: ["easy", "hard"], 20: ["hard", "extreme"], 24: ["hard", "extreme"], 26: ["hard", "extreme"],
	21: ["hard"], 23: ["hard", "extreme"], 27: ["hard", "extreme"]}
## From this Chief's day, one crisis every CHIEF_EVERY days.
const CHIEF_FROM := 36
const CHIEF_EVERY := 3
## The beat for each crisis: the task list's row, where it happens, the
## pager, and who stands where.
const BEATS := {
	"power_cut": {"row": "Theatre 2: the lights go out", "where": "theatre", "at": 15 * 60,
		"put": [["tom", "theatre:scrub"], ["khan", "theatre:anaesthetist"], ["you", "theatre:you"]],
		"gowned": ["you", "tom", "khan"]},
	"ramesh": {"row": "Two Ramesh Kumars, one gallbladder", "go": "desk", "at": 14 * 60 + 30,
		"page": "Grace: Desk, Doctor. Theatre wants Ramesh Kumar. We have two.", "put": [["grace", "desk:left"]]},
	"crowd": {"row": "The family at the door", "go": "desk", "at": 16 * 60,
		"page": "Grace: Doctor, the corridor. Now, please. Quietly.",
		"put": [["grace", "desk:left"], ["relative_a", "family:1"], ["relative_b", "family:2"], ["relative_c", "family:3"]]},
	"donors": {"row": "Blood: the family's donors", "go": "desk", "at": 13 * 60,
		"page": "Priya: Desk. The blood bank's out of the patient's group. The whole family's here to donate. Whole family.",
		"put": [["priya", "desk:left"]]},
	"insurance": {"row": "The insurance form", "go": "desk", "at": 15 * 60,
		"page": "Mr. Malhotra: Desk. The insurance company has questions. I have more.", "put": [["malhotra", "desk:right"]]},
	"snakebite": {"row": "Admissions: a snakebite", "go": "trolley", "music": "emergency",
		"page": "Priya: ADMISSIONS. Snakebite, two hours from the village. Come now.", "put": [["priya", "trolley:other"]]},
	"dengue": {"row": "Dengue: five beds, two units", "go": "desk", "at": 16 * 60,
		"page": "Dr. Iyer: Desk. It's dengue season, and every family wants platelets.", "put": [["iyer", "desk:left"]]},
	"inspection": {"row": "Inspection in thirty minutes", "go": "desk", "at": 15 * 60,
		"page": "Grace: The inspectors are in the car park. Thirty minutes, Doctor. Desk.", "put": [["grace", "desk:left"]]},
	# The quick casualty cases that give the meeting days something to play.
	"quick_heat": {"row": "Admissions: the constable from the signal", "go": "trolley", "at": 14 * 60, "music": "emergency",
		"page": "Priya: ADMISSIONS. The traffic constable from outside. Collapsed in the sun.",
		"put": [["priya", "trolley:other"], ["iyer", "trolley:foot"]]},
	"quick_asthma": {"row": "Admissions: a wheeze before the interview", "go": "trolley", "at": 9 * 60 + 30,
		"page": "Priya: Admissions, sorry, before your interview. He can't finish a sentence.",
		"put": [["priya", "trolley:other"], ["iyer", "trolley:foot"]]},
	"quick_sepsis": {"row": "Bed six: the shivering grandmother", "go": "trolley", "at": 13 * 60,
		"page": "Priya: Bed six is shivering and confused, Doctor. Before the board, please.",
		"put": [["priya", "trolley:other"], ["iyer", "trolley:foot"]]},
}
const ACTORS := {"power_cut": "tom", "ramesh": "grace", "crowd": "grace", "donors": "priya", "insurance": "malhotra",
	"snakebite": "priya", "dengue": "iyer", "inspection": "grace", "quick_heat": "iyer", "quick_asthma": "iyer",
	"quick_sepsis": "iyer"}

static var _lines: Dictionary = {}


# --- When ----------------------------------------------------------------------------

## The crisis on a day, or "".
static func for_day(profile: PlayerProfile, day: int) -> String:
	if STORY_DAYS.has(day):
		return str(STORY_DAYS[day])
	if day < CHIEF_FROM or (day - CHIEF_FROM) % CHIEF_EVERY != 0:
		return ""
	var turn := (day - CHIEF_FROM) / CHIEF_EVERY
	var order := _order(profile, turn / IDS.size())
	return str(order[turn % IDS.size()])


## Each round of eight in a seeded order, never the same crisis twice running
## across the join.
static func _order(profile: PlayerProfile, block: int) -> Array:
	var order := SeededRandom.new(absi(hash("%s|crises|%d" % [profile.name, block])) % 1000003 + 1).shuffled(IDS)
	if block > 0:
		var before := _order(profile, block - 1)
		if order[0] == before[before.size() - 1]:
			var held: Variant = order[0]
			order[0] = order[1]
			order[1] = held
	return order


static func levels_for(day: int) -> Array:
	if STORY_LEVELS.has(day):
		return (STORY_LEVELS[day] as Array).duplicate()
	return ChiefDays.puzzle_levels(day)


## The ward beat for a day's crisis ({} for none).
static func beat(profile: PlayerProfile, day: int) -> Dictionary:
	var crisis := for_day(profile, day)
	if crisis.is_empty():
		return {}
	var made: Dictionary = (BEATS[crisis] as Dictionary).duplicate(true)
	made.merge({"id": "crisis", "crisis": crisis, "talk": "crisis_%s_arrive" % crisis, "with": ACTORS[crisis],
		"coach": ACTORS[crisis], "tasks": [["crisis", crisis]], "after": "crisis_%s_after" % crisis,
		"levels": levels_for(day)})
	var ends: Array = []
	for entry: Array in made.get("put", []):
		if str(entry[0]) != "you":
			ends.append([entry[0], "off"])
	made["put_end"] = ends
	return made


# --- Lines -----------------------------------------------------------------------------

static func lines() -> Dictionary:
	if _lines.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LINES_PATH))
		if parsed is Dictionary:
			_lines = parsed
	return _lines


## What the coach says for a crisis's line key ("" if it isn't written).
static func line(crisis: String, key: String) -> String:
	# The daily quick cases share one set of lines.
	var group := "quick" if crisis.begins_with("quick_") else crisis
	var entry: Variant = (lines().get(group, {}) as Dictionary).get(key, {})
	return str((entry as Dictionary).get("text", "")) if entry is Dictionary else ""


# --- Building a crisis ----------------------------------------------------------------

static func build(crisis: String, dice: SeededRandom, level: String, context: Dictionary = {}) -> Dictionary:
	if crisis.begins_with("quick_"):
		return QuickCases.build(crisis, dice, level, context)
	var made: Dictionary
	match crisis:
		"power_cut":
			made = _power_cut(dice, level)
		"ramesh":
			made = _ramesh(dice, level)
		"crowd":
			made = _crowd(dice, level)
		"donors":
			made = _donors(dice, level)
		"insurance":
			made = _insurance(dice, level)
		"snakebite":
			made = _snakebite(dice, level)
		"dengue":
			made = _dengue(dice, level)
		"inspection":
			made = _inspection(dice, level)
		_:
			push_error("Unknown crisis: %s" % crisis)
			return {}
	made["actor"] = ACTORS[crisis]
	if context.has("actor"):
		made["actor"] = context["actor"]
	return made


static func _opt(id: String, text: String) -> Dictionary:
	return {"id": id, "text": text}


## A "one" step: the options shuffled so where an answer sits gives nothing away.
static func _one(dice: SeededRandom, id: String, prompt: String, options: Array, answer: String, extra: Dictionary = {}) -> Dictionary:
	var step := {"id": id, "kind": "one", "prompt": prompt, "options": dice.shuffled(options), "answer": answer,
		"right": id + "_right", "wrong": id + "_wrong", "hint": id + "_hint"}
	step.merge(extra, true)
	return step


# --- The lights go out in theatre ---------------------------------------------------------

static func _power_cut(dice: SeededRandom, level: String) -> Dictionary:
	var general: bool = dice.chance(0.5)
	var keyhole: bool = level != "easy" and dice.chance(0.4)
	var bleeding: bool = dice.chance(0.5)
	var kit_ok: bool = level == "easy" or dice.chance(0.5)
	var ups_ok: bool = level == "easy" or dice.chance(0.5)
	var patient: String = dice.pick(["Mr. Gopal Shinde, 58", "Mrs. Lata Pawar, 46", "Mr. Irfan Sheikh, 39", "Mrs. Meena Kale, 62"])
	var operation := "Keyhole gallbladder" if keyhole else str(dice.pick(["Open hernia repair", "Open appendix"]))
	var facts: Array[String] = ["%s · %s" % [patient, operation],
		"Under general anaesthesia: the ventilator breathes for the patient" if general
			else "Spinal anaesthetic: awake, chatty, numb from the waist down",
		"Camera, gas and three instruments inside the belly" if keyhole
			else ("You've just nicked a small artery. It's pumping." if bleeding
				else "Closing up. The swab count was right ten minutes ago."),
		"Emergency kit: checked Monday, headlamp charged (Tom's handwriting)" if kit_ok
			else "Emergency kit: the headlamp went home for the Diwali lights. It has not come back.",
		"UPS: beeping. The red sockets get about ten minutes" if ups_ok
			else "UPS: failed its test last month. Repair request 'under process' since then."]
	var steps: Array = []
	steps.append(_one(dice, "s1", "The lights die. Ventilator, monitor and screen go with them. First, right now:", [
		_opt("bag", "Squeeze the bag by hand: breathe for the patient"),
		_opt("talk", "Talk to the patient: keep them calm and still"),
		_opt("torch", "Go and find a torch"),
		_opt("shout", "Shout for the electrician"),
		_opt("feel", "Carry on by feel")], "bag" if general else "talk",
		{"urgent": true, "right": "s1_right_general" if general else "s1_right_spinal",
			"wrong": "s1_wrong_general" if general else "s1_wrong_spinal",
			"why": "Under general anaesthesia the ventilator does the breathing. When it stops, someone squeezes the bag by hand, at once." if general
				else "With a spinal the patient is awake and breathing unaided. The danger in the first ten seconds is panic and movement on an open wound: talk to the patient.",
			"good": "Breathing first, everything else after." if general else "An awake patient who stays still is the best thing in a dark theatre."}))
	steps.append(_one(dice, "s2", "You need light on the wound:", [
		_opt("headlamp", "The headlamp from the emergency kit"),
		_opt("phones", "Phone torches, held over the wound by the runner"),
		_opt("door", "Prop the door open for the corridor light"),
		_opt("wait", "Wait for the generator")], "headlamp" if kit_ok else "phones",
		{"urgent": true, "right": "s2_right", "wrong": "s2_wrong_kit" if kit_ok else "s2_wrong_flat",
			"why": "Read the card: the kit was checked on Monday and its headlamp is charged. Use it." if kit_ok
				else "Read the card: the headlamp went home for Diwali. Three phone torches held steady beat waiting in the dark.",
			"good": "Light from what you actually have, not what should be there."}))
	if keyhole:
		steps.append(_one(dice, "s3", "Three instruments inside the belly, and the screen is black:", [
			_opt("still", "Hold every instrument still, exactly where it is"),
			_opt("out", "Pull all the instruments out"),
			_opt("open", "Cut open now"),
			_opt("gas", "Let the gas out")], "still",
			{"urgent": true, "right": "s3_right_keyhole", "wrong": "s3_wrong_keyhole",
				"why": "An instrument moved blind can tear what you can't see. Still hands until the camera's back; open only if something is bleeding.",
				"good": "Nothing moves inside a belly you can't see."}))
	elif bleeding:
		steps.append(_one(dice, "s3", "The artery is still pumping:", [
			_opt("press", "Press on it with a swab, and keep pressing"),
			_opt("clamp", "Clamp where you think it is"),
			_opt("burn", "Seal it with the diathermy"),
			_opt("close", "Pack it and close fast")], "press",
			{"urgent": true, "right": "s3_right_bleeding", "wrong": "s3_wrong_bleeding",
				"why": "Clamping blind catches nerves and bowel, and the diathermy needs power. Firm pressure stops almost any small bleed while you wait for light.",
				"good": "Pressure, patience, light. In that order."}))
	else:
		steps.append(_one(dice, "s3", "You were closing. The swab count:", [
			_opt("recount", "Stop closing. Count again once you can see"),
			_opt("trust", "Close. The count was right before"),
			_opt("xray", "Close, and X-ray tomorrow"),
			_opt("feel", "Feel around inside for swabs")], "recount",
			{"urgent": true, "right": "s3_right_closing", "wrong": "s3_wrong_closing",
				"why": "Things fall in the dark. A count from before the lights went is a count of a different operation.",
				"good": "A new count after the dark. Swabs don't announce themselves."}))
	if ups_ok:
		steps.append(_one(dice, "s4", "The UPS beeps: ten minutes of power in the red sockets. What goes in them?", [
			_opt("monitor", "The monitor and the anaesthetic machine"),
			_opt("suction", "The suction"),
			_opt("diathermy", "The diathermy"),
			_opt("light", "The big theatre light")], "monitor",
			{"right": "s4_right", "wrong": "s4_wrong_ups",
				"why": "Ten minutes is for keeping the patient alive and watched, not for finishing the operation: monitor and anaesthetic machine first.",
				"good": "The patient's numbers before the surgeon's comfort."}))
	else:
		steps.append(_one(dice, "s4", "No UPS, no monitor. How do you watch the patient?", [
			_opt("manual", "Pulse by hand and a manual BP cuff every three minutes, called out loud"),
			_opt("colour", "Watch the colour of the blood"),
			_opt("app", "A pulse app on somebody's phone"),
			_opt("wait", "Wait for the power")], "manual",
			{"right": "s4_right", "wrong": "s4_wrong_dead",
				"why": "Without a monitor you become the monitor: a hand on the pulse, the old cuff, numbers said out loud so everyone hears.",
				"good": "Old tools, said out loud, every three minutes."}))
	if level == "extreme":
		steps.append(_one(dice, "s5", "The lights come back. Before anyone relaxes:", [
			_opt("check", "Check the ventilator restarted on the right settings before letting go of the bag" if general
				else "Check the blood pressure: a spinal can drop it while everyone looks at the lights"),
			_opt("carry", "Let go and carry on: the power's back"),
			_opt("celebrate", "Thank the generator out loud"),
			_opt("count", "Ask who dropped what in the dark")], "check",
			{"right": "s5_right", "wrong": "s5_wrong",
				"why": "Machines restart on their own settings, not the patient's. Check before you trust." if general
					else "A spinal can drop the blood pressure. The minutes in the dark weren't watched properly: check now.",
				"good": "Trust the power after you've checked what it switched back on."}))
	return {"title": "The lights go out", "spot": "Theatre 2", "card": "THEATRE 2 · POWER CUT", "facts": facts, "steps": steps,
		"dark": true}


# --- Two Ramesh Kumars ---------------------------------------------------------------------

static func _date(dice: SeededRandom, year_from: int, year_to: int) -> Array:
	return [dice.next_int_in(1, 28), dice.next_int_in(1, 12), dice.next_int_in(year_from, year_to)]


static func _date_text(date: Array) -> String:
	return "%02d/%02d/%d" % [int(date[0]), int(date[1]), int(date[2])]


const MONTHS := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October",
	"November", "December"]


static func _said_date(date: Array) -> String:
	return "%d %s %d" % [int(date[0]), MONTHS[int(date[1]) - 1], int(date[2])]


static func _ramesh(dice: SeededRandom, level: String) -> Dictionary:
	var scenarios := ["clean"]
	if level != "easy":
		scenarios.append("misprint")
	if level == "extreme":
		scenarios.append("swapped")
	var scenario: String = dice.pick(scenarios)
	var dob_a := _date(dice, 1964, 1972)
	var dob_b := _date(dice, 1964, 1972)
	while _date_text(dob_b) == _date_text(dob_a):
		dob_b = _date(dice, 1964, 1972)
	var uhid_a := dice.next_int_in(300000, 399999)
	var uhid_b := dice.next_int_in(300000, 399999)
	var going: int = dice.next_int(2)
	var beds := ["Bed 3", "Bed 5"]
	var dobs := [dob_a, dob_b]
	var uhids := [str(uhid_a), str(uhid_b)]
	var fathers := ["Suresh", "Mahesh"]
	var slip := "Theatre slip: RAMESH KUMAR · DOB %s · UHID %s · keyhole gallbladder, 09:00" % [_date_text(dobs[going]), uhids[going]]
	# What each band says: the man's own details, except where it went wrong.
	var bands := [[_date_text(dob_a), uhids[0]], [_date_text(dob_b), uhids[1]]]
	var says := [_said_date(dob_a), _said_date(dob_b)]
	if scenario == "misprint":
		var digits: String = uhids[going]
		bands[going][1] = digits.substr(0, 3) + digits[4] + digits[3] + digits.substr(5)
		if bands[going][1] == digits:
			bands[going][1] = digits.substr(0, 5) + str((int(digits[5]) + 1) % 10)
	elif scenario == "swapped":
		var held: Array = bands[0]
		bands[0] = bands[1]
		bands[1] = held
	var facts: Array[String] = [slip]
	for index in 2:
		facts.append("%s band: RAMESH KUMAR · DOB %s · UHID %s" % [beds[index], bands[index][0], bands[index][1]])
	var answer := "stop" if scenario != "clean" else ("bed3" if going == 0 else "bed5")
	var steps: Array = []
	var checks := [
		{"id": "open", "text": "Ask him to say his full name and date of birth"},
		{"id": "band", "text": "Match the band's UHID and date of birth to the slip"},
		{"id": "closed", "text": "Ask him: 'You're Ramesh Kumar, na?'"},
		{"id": "board", "text": "Read the name board over the bed"},
		{"id": "bed", "text": "Go by the bed number on the slip"},
		{"id": "face", "text": "Ask Sister Grace if she recognises him"}]
	steps.append({"id": "s1", "kind": "some", "prompt": "Before anyone goes to theatre, which checks actually count?",
		"items": dice.shuffled(checks), "answer": ["open", "band"], "right": "s1_right", "wrong": "s1_wrong", "hint": "s1_hint",
		"reasons": {"open": "Ask him to tell you his name and date of birth: an open question, his own words.",
			"band": "Match two identifiers on the band (UHID and date of birth) to the slip.",
			"closed": "Every patient says yes to 'You're Ramesh, na?'. Especially a hungry one.",
			"board": "Name boards are written in pencil by whoever was last on shift.",
			"bed": "Bed numbers change every time someone needs the one by the window.",
			"face": "Grace knows everyone. Grace also knows that faces aren't identifiers."},
		"why": "Two identifiers count: his name and date of birth in his own words, and the band's UHID and date of birth against the slip.",
		"good": "Two identifiers, from his own mouth and his band. Nothing else counts."})
	steps.append(_one(dice, "s2", "You ask each man his name and date of birth. Who goes to theatre?", [
		_opt("bed3", "Bed 3"), _opt("bed5", "Bed 5"), _opt("stop", "Neither yet: stop and sort out the bands")], answer,
		{"facts": ["Bed 3 says: 'Ramesh Kumar, born %s.'" % says[0], "Bed 5 says: 'Ramesh Kumar, born %s.'" % says[1]],
			"right": "s2_right_" + scenario, "wrong": "s2_wrong",
			"why": {"clean": "Only one man's spoken birthday, band and slip all agree. He goes; the other has breakfast.",
				"misprint": "His birthday matches the slip, but his band's UHID has two digits swapped. A wrong band goes to theatre with him: fix it first.",
				"swapped": "Each man's spoken birthday matches the other man's band. The bands are swapped. Nobody goes until they're re-banded."}[scenario],
			"good": "You matched what he said, what his band says, and what the slip says. All three."}))
	# What he's had since midnight, against the fasting rules.
	var drinks := [["black tea at 06:30", "go", "Black tea is a clear fluid: two hours. 06:30 to 09:00 is enough."],
		["a glass of water at 07:30", "later", "Water is two hours: 07:30 means not before 09:30. Move him down the list, not off it."],
		["milky chai and two Parle-G at 07:00", "later", "Milk and biscuits are food: six hours. Not before 13:00, so move him later today."],
		["a full wedding dinner at 01:00", "go", "Food is six hours: 01:00 to 07:00. By 09:00 he's fine, however much biryani it was."]]
	var drink: Array = dice.pick(drinks)
	steps.append(_one(dice, "s3", "The right Ramesh had %s. His slot is 09:00:" % drink[0], [
		_opt("go", "He goes at 09:00"), _opt("later", "Move him later in today's list"), _opt("cancel", "Cancel him today")],
		str(drink[1]), {"right": "s3_right", "wrong": "s3_wrong",
			"why": "%s Water and black tea: two hours. Milk, chai, biscuits, food: six." % drink[2],
			"good": str(drink[2])}))
	return {"title": "Two Ramesh Kumars", "spot": "Nurses' station", "card": "THEATRE SLIP AND BANDS", "facts": facts, "steps": steps}


# --- The family at the door ----------------------------------------------------------------

static func _crowd(dice: SeededRandom, level: String) -> Dictionary:
	var accident: bool = dice.chance(0.5)
	var patient := "Sagar More, 24: bike accident, head injury, died this morning" if accident \
		else "Mr. Dinesh Patil, 67: heart attack, two days in ICU, died an hour ago"
	var kin: String = dice.pick(["his mother, sitting on the floor by the door", "his elder brother, very quiet"] if accident
		else ["his wife, sitting on the floor by the door", "his eldest son, holding the forms"])
	var loud: String = dice.pick(["a local corporator who never met him", "a cousin filming everything on his phone",
		"an uncle who smells of the afternoon"])
	var grievance: String = dice.pick(["told", "bill", "waited"])
	var clue: String = {"told": "The family keeps saying: 'Yesterday they said he was better.'",
		"bill": "Someone is holding the final bill up for the corridor to see: ₹1,84,000.",
		"waited": "'Two hours on a stretcher downstairs!' says everyone, to everyone."}[grievance]
	var danger: bool = level != "easy" and dice.chance(0.5 if level == "hard" else 0.75)
	var facts: Array[String] = [patient, "Next of kin: " + kin, "Loudest: " + loud, clue]
	var steps: Array = []
	steps.append(_one(dice, "s1", "Twenty people in the corridor. Who do you talk to?", [
		_opt("kin", "Next of kin: " + kin.split(",")[0]), _opt("loud", "The loudest: " + loud.split(" who")[0]),
		_opt("all", "Everyone, right here, at once"), _opt("none", "Nobody, until the police come")], "kin",
		{"right": "s1_right", "wrong": "s1_wrong",
			"why": "The person who has the right to know is the next of kin, not the loudest man. Loud men are for later, or never.",
			"good": "The next of kin first. The volume can wait."}))
	steps.append(_one(dice, "s2", "Where?", [
		_opt("room", "The relatives' room, with Grace, chairs for everyone who sits"),
		_opt("corridor", "Here in the corridor, where everyone can hear"),
		_opt("icu", "Inside the ICU"), _opt("phone", "By phone, from the doctors' room")], "room",
		{"right": "s2_right", "wrong": "s2_wrong",
			"why": "Bad news is given sitting down, in a private room, with a nurse who stays. Never in a corridor, never by phone when they're outside your door.",
			"good": "Sitting down, a private room, a nurse beside you."}))
	var openers := {
		"told": "I'm sorry. You should have been told he was getting worse. Let me tell you everything, from the start.",
		"bill": "I'm sorry. Nobody will stop you taking him home. The bill can wait till next week.",
		"waited": "I'm sorry. You waited far too long downstairs. I'll find out why, and tell you myself."}
	var bad: Array = dice.pick([["jargon", "He had a cardiac arrest secondary to ventricular fibrillation."],
		["defend", "We did everything possible."], ["blame", "The night doctor should have called me."]])
	var options := [_opt("told", openers["told"]), _opt("bill", openers["bill"]), _opt("waited", openers["waited"]),
		_opt(str(bad[0]), str(bad[1]))]
	steps.append(_one(dice, "s3", "Your first words:", options, grievance,
		{"right": "s3_right", "wrong": "s3_wrong",
			"why": "Read the card: what they're angry about is right there. Say sorry for that first, in plain words. %s" % {
				"told": "They were told he was better.", "bill": "The bill is in the air.", "waited": "They waited two hours."}[grievance],
			"explain": {"jargon": "Medical words in a moment like this sound like a wall.",
				"defend": "'We did everything' is what people say when they didn't.",
				"blame": "Blaming a colleague in front of the family helps nobody and is usually wrong."},
			"good": "You answered the thing they were actually angry about."}))
	if danger:
		var thing: String = dice.pick(["the fire extinguisher off the wall", "a broken chair leg", "a steel water jug"])
		steps.append(_one(dice, "s4", "Someone at the back has picked up %s:" % thing, [
			_opt("leave", "Step out calmly with Grace, and call security and the police (112)"),
			_opt("talk", "Keep talking, they're listening"), _opt("grab", "Take it off him"),
			_opt("lock", "Lock them in the room")], "leave",
			{"facts": ["At the back: someone has picked up %s." % thing], "right": "s4_right", "wrong": "s4_wrong",
				"why": "When something becomes a weapon, the talking is over. Leave calmly, together, and let security and the police do their job.",
				"good": "Calm, out, together, and the police called. Nobody's a hero today."}))
	if accident:
		steps.append(_one(dice, "s5", "The uncle says: 'No police, no post-mortem. Just give us the body.'", [
			_opt("mlc", "It's a road accident: a medico-legal case. The police must be told, and the post-mortem is the law. Explain it gently."),
			_opt("skip", "Agree. They've suffered enough"), _opt("neta", "Ask the corporator to sort it out"),
			_opt("refuse", "Refuse to discuss it")], "mlc",
			{"right": "s5_right_accident", "wrong": "s5_wrong_accident",
				"why": "A death after an accident is a medico-legal case: the police are told, and a post-mortem may be the law. Kindness is explaining that, not skipping it.",
				"good": "The law, explained kindly. That's the whole job here."}))
	else:
		steps.append(_one(dice, "s5", "The corporator says: 'Do a post-mortem! Find out who's guilty!'", [
			_opt("cert", "No post-mortem is needed: the cause is known. You'll write the death certificate and explain it."),
			_opt("pm", "Order a post-mortem to calm things down"), _opt("police", "Call the police to decide"),
			_opt("refuse", "Refuse to discuss it")], "cert",
			{"right": "s5_right_natural", "wrong": "s5_wrong_natural",
				"why": "A natural death in hospital with a known cause needs a death certificate, not a post-mortem. A post-mortem to calm a corporator is not a reason.",
				"good": "A known cause gets a certificate, written carefully and explained."}))
	return {"title": "The family at the door", "spot": "Relatives' room", "card": "THE CORRIDOR", "facts": facts, "steps": steps}


# --- The family's blood ----------------------------------------------------------------------

## Who can give red cells to whom.
static func compatible(donor: String, patient: String) -> bool:
	var d_abo := donor.trim_suffix("+").trim_suffix("-")
	var p_abo := patient.trim_suffix("+").trim_suffix("-")
	var abo_ok := d_abo == "O" or d_abo == p_abo or p_abo == "AB"
	var rh_ok := patient.ends_with("+") or donor.ends_with("-")
	return abo_ok and rh_ok


static func _donors(dice: SeededRandom, level: String) -> Dictionary:
	var groups := ["O+", "A+", "B+", "AB+"] if level == "easy" else ["O+", "A+", "B+", "AB+", "O-", "B-", "A-"]
	var group: String = dice.pick(groups)
	var patient: String = dice.pick(["Mrs. Kavya Rane, 31: bleeding after her delivery", "Mr. Prakash Jadhav, 45: a bleeding ulcer",
		"Mrs. Shobha Gaikar, 58: a leaking aneurysm"])
	var need := 3 if level == "extreme" else 2
	var count := 5 if level == "easy" else (6 if level == "hard" else 7)
	var safe := need + (1 if level == "easy" else dice.next_int(2))
	var people := dice.shuffled([["Rakesh", "husband", "M"], ["Vinod", "brother", "M"], ["Pallavi", "sister-in-law", "F"],
		["Santosh", "cousin", "M"], ["Mrs. Deshmukh", "neighbour", "F"], ["Arvind", "friend from work", "M"],
		["Bhau", "uncle", "M"], ["Sunanda", "sister", "F"], ["Ganesh", "nephew", "M"]])
	var good_groups := groups.filter(func(g: String) -> bool: return compatible(g, group))
	var bad_groups := ["O+", "A+", "B+", "AB+", "O-", "A-", "B-", "AB-"].filter(func(g: String) -> bool: return not compatible(g, group))
	var defects := ["group", "drank", "tattoo", "antibiotics", "age"]
	if level != "easy":
		defects += ["hb", "weight", "malaria", "hepatitis", "recent"]
	if level == "extreme":
		defects += ["woman_recent", "insulin"]
		if group.ends_with("-"):
			defects += ["rh", "rh"]
	var items: Array = []
	var answer: Array = []
	var reasons := {}
	for index in count:
		var who: Array = people[index]
		var female := str(who[2]) == "F"
		var id := "d%d" % (index + 1)
		var donor := {"age": dice.next_int_in(21, 55), "kg": dice.next_int_in(52, 84), "group": str(dice.pick(good_groups)),
			"hb": dice.range_float(13.0, 15.6), "last": "never donated", "extra": str(dice.pick(["", "", "BP tablets, well controlled",
				"diabetic, on tablets", "had a cold last week, fine now"]))}
		var defect := ""
		if index >= safe:
			defect = str(dice.pick(defects))
			if defect == "woman_recent" and not female:
				defect = "recent"
			if defect == "group" and bad_groups.is_empty():
				defect = "drank"
		match defect:
			"group":
				donor["group"] = str(dice.pick(bad_groups))
				reasons[id] = "%s is %s: that can't go into a %s patient." % [who[0], donor["group"], group]
			"rh":
				donor["group"] = str(dice.pick(["O+", group.trim_suffix("-") + "+"]))
				reasons[id] = "%s is %s. A Rh-negative patient needs Rh-negative blood." % [who[0], donor["group"]]
			"drank":
				donor["extra"] = "drank at a wedding last night"
				reasons[id] = "%s drank last night: no donating within 24 hours of alcohol." % who[0]
			"tattoo":
				donor["extra"] = "new tattoo, %d months ago" % dice.next_int_in(3, 9)
				reasons[id] = "%s's tattoo is under a year old: wait twelve months after a tattoo." % who[0]
			"antibiotics":
				donor["extra"] = "on antibiotics for a tooth, day %d of 5" % dice.next_int_in(2, 4)
				reasons[id] = "%s is still on antibiotics: finish the course first." % who[0]
			"age":
				donor["age"] = dice.pick([17, 66, 68])
				reasons[id] = "%s is %d: donors are 18 to 65." % [who[0], donor["age"]]
			"hb":
				donor["hb"] = dice.range_float(11.6, 12.4)
				reasons[id] = "%s's haemoglobin is %.1f: under 12.5 is too low to give." % [who[0], donor["hb"]]
			"weight":
				donor["kg"] = dice.next_int_in(40, 44)
				reasons[id] = "%s weighs %d kg: under 45 kg can't give a full unit." % [who[0], donor["kg"]]
			"malaria":
				donor["extra"] = "malaria %d weeks ago, treated" % dice.next_int_in(4, 10)
				reasons[id] = "%s had malaria under three months ago." % who[0]
			"hepatitis":
				donor["extra"] = "had hepatitis B, years ago"
				reasons[id] = "%s had hepatitis B: never a donor." % who[0]
			"recent":
				donor["last"] = "donated %d weeks ago" % dice.next_int_in(5, 10)
				reasons[id] = "%s donated under three months ago." % who[0]
			"woman_recent":
				donor["last"] = "donated 3 months ago"
				reasons[id] = "%s donated three months ago: women wait four months between donations." % who[0]
			"insulin":
				donor["extra"] = "diabetic, on insulin"
				reasons[id] = "%s is on insulin: deferred. (Tablets would have been fine.)" % who[0]
		if defect.is_empty():
			answer.append(id)
			if female and str(donor["last"]) == "never donated" and level == "extreme" and dice.chance(0.5):
				donor["last"] = "donated 5 months ago"
		var detail := "%s · %d kg · Hb %.1f · %s" % [donor["group"], donor["kg"], donor["hb"], donor["last"]]
		if not str(donor["extra"]).is_empty():
			detail += " · " + str(donor["extra"])
		items.append({"id": id, "text": "%s (%s), %d, %s" % [who[0], who[1], donor["age"], who[2]], "detail": detail})
	var facts: Array[String] = [patient, "Her group: %s" % group if patient.begins_with("Mrs.") else "His group: %s" % group,
		"The blood bank has no %s. The family's blood is cross-matched for the patient directly." % group,
		"Units needed: %d" % need, "Donors: 18 to 65 · 45 kg or more · Hb 12.5 or more"]
	var steps: Array = []
	steps.append({"id": "s1", "kind": "some", "need": need, "prompt": "Who can safely give blood to this patient?", "items": items,
		"answer": answer, "reasons": reasons, "right": "s1_right", "wrong": "s1_wrong", "hint": "s1_hint", "weight": 2.0,
		"why": "Check each donor against the group, the limits on the card, and the rules: no alcohol in 24 hours, no tattoo in a year, no antibiotics, no hepatitis B, three months since malaria or the last donation (four for women).",
		"good": "Every unit you picked is compatible and safe."})
	steps.append(_one(dice, "s2", "The first unit reaches the bedside:", [
		_opt("check", "Two of you check the unit's group, number and expiry against the patient's band, at the bed"),
		_opt("label", "The bag has the right name on it. Hang it."),
		_opt("warm", "Warm it in a bowl of hot water first"),
		_opt("fast", "Squeeze it in fast, they're bleeding")], "check",
		{"right": "s2_right", "wrong": "s2_wrong",
			"why": "Most transfusion disasters are the wrong bag in the right patient. Two people check it at the bed, against the band, every time.",
			"good": "Two people, at the bed, against the band."}))
	return {"title": "The family's blood", "spot": "Blood bank", "card": "BLOOD BANK · DONOR LIST", "facts": facts, "steps": steps}


# --- The insurance form -----------------------------------------------------------------------

static func _insurance(dice: SeededRandom, level: String) -> Dictionary:
	var person: Array = dice.pick([["Suresh", "Yadav", "Yadev"], ["Mahendra", "Shinde", "Shindhe"], ["Anil", "Kulkarni", "Kulkarani"],
		["Ramesh", "Pawar", "Powar"]])
	var dob := [dice.next_int_in(1, 12), dice.next_int_in(13, 28), dice.next_int_in(1968, 1990)]
	var policy := "%04d-%04d-%02d" % [dice.next_int_in(1000, 9999), dice.next_int_in(1000, 9999), dice.next_int_in(10, 99)]
	var appendix: bool = dice.chance(0.6)
	var diagnosis := "Acute appendicitis" if appendix else "Right inguinal hernia, two years"
	var procedure := "Laparoscopic appendicectomy" if appendix else "Open hernia repair with mesh"
	var estimate := dice.next_int_in(41, 79) * 1000
	var since: Array = dice.pick([["3 weeks ago", 0], ["8 months ago", 8], ["3 years ago", 36]])
	var name := "%s %s" % [person[0], person[1]]
	var true_fields := {"name": name, "dob": "%02d/%02d/%d" % [dob[1], dob[0], dob[2]], "policy": policy,
		"diagnosis": diagnosis, "procedure": procedure, "admitted": "today", "estimate": "₹%s" % _rupees(estimate)}
	var wrong_fields := {"name": "%s %s" % [person[0], person[2]], "dob": "%02d/%02d/%d" % [dob[0], dob[1], dob[2]],
		"policy": policy.substr(0, 5) + policy[6] + policy[5] + policy.substr(7),
		"diagnosis": "Pain in abdomen", "procedure": "Open appendicectomy" if appendix else "Laparoscopic hernia repair",
		"admitted": "yesterday", "estimate": "₹%s" % _rupees(_swap_digits(estimate))}
	if wrong_fields["policy"] == policy:
		wrong_fields["policy"] = policy.substr(0, 10) + str((int(policy[10]) + 3) % 10) + policy.substr(11)
	var plain := ["name", "dob", "policy", "estimate", "admitted"]
	var subtle := ["diagnosis", "procedure"]
	var counts: Array = {"easy": [2, 0], "hard": [2, 1], "extreme": [2, 2]}[level]
	var wrong: Array = dice.shuffled(plain).slice(0, int(counts[0])) + dice.shuffled(subtle).slice(0, int(counts[1]))
	var labels := {"name": "Name", "dob": "Date of birth", "policy": "Policy number", "diagnosis": "Diagnosis",
		"procedure": "Operation", "admitted": "Admitted", "estimate": "Estimate"}
	var reasons := {"name": "The name must match the Aadhaar card letter for letter. Insurers reject 'nearly'.",
		"dob": "Day and month were swapped: the Aadhaar card says otherwise.",
		"policy": "Two digits of the policy number were swapped.",
		"diagnosis": "'Pain in abdomen' is a symptom, not a diagnosis. The note says what it is. Vague forms get rejected.",
		"procedure": "The operation on the form isn't the one on the doctor's note.",
		"admitted": "He was admitted today, not yesterday. Dates are the first thing they check.",
		"estimate": "The estimate's digits are swapped: the costing sheet says otherwise."}
	var items: Array = []
	for field: String in ["name", "dob", "policy", "diagnosis", "procedure", "admitted", "estimate"]:
		var value: String = wrong_fields[field] if field in wrong else true_fields[field]
		items.append({"id": field, "text": "%s: %s" % [labels[field], value]})
	var facts: Array[String] = ["Aadhaar: %s · DOB %s" % [name.to_upper(), true_fields["dob"]],
		"Policy card: %s · %s · since %s · cover ₹3,00,000" % [name.to_upper(), policy, since[0]],
		"Doctor's note: %s · %s · admitted today" % [diagnosis, procedure], "Costing sheet: ₹%s" % _rupees(estimate)]
	var steps: Array = []
	steps.append({"id": "s1", "kind": "some", "prompt": "Mark every line on the form that doesn't match the documents:",
		"items": items, "answer": wrong, "reasons": reasons, "right": "s1_right", "wrong": "s1_wrong", "hint": "s1_hint",
		"weight": 1.5, "why": "Check every field against the documents on the card, letter for letter.",
		"good": "Every mismatch found, and nothing right doubted."})
	var months := int(since[1])
	var covered := months >= 1 and (appendix or months >= 24)
	steps.append(_one(dice, "s2", "Policy since %s, for %s. Is it covered?" % [since[0], diagnosis.to_lower()], [
		_opt("covered", "Yes: send the claim"),
		_opt("not", "No: tell the family today, and why"),
		_opt("accident", "Write it up as an accident so it's covered")], "covered" if covered else "not",
		{"right": "s2_right", "wrong": "s2_wrong",
			"why": ("Illness in a policy's first 30 days isn't covered, emergencies included; only accidents are." if months < 1
				else ("A hernia has a two-year waiting period on most policies. Eight months isn't two years." if not appendix and months < 24
					else "Past the first 30 days, an emergency like appendicitis is covered." if appendix
						else "Three years is past the hernia's two-year wait: covered.")) + " Calling it an accident is fraud.",
			"explain": {"accident": "Calling it an accident is fraud, with your signature on it."},
			"good": "The waiting period, worked out, and the family told the truth early."}))
	if appendix:
		steps.append(_one(dice, "s3", "No approval yet, and his appendix is getting worse:", [
			_opt("operate", "Operate now. Emergency approval can follow, or he pays later; nobody waits for paperwork"),
			_opt("wait", "Wait for the approval"), _opt("transfer", "Send him to the government hospital"),
			_opt("deposit", "Ask for ₹50,000 before theatre")], "operate",
			{"right": "s3_right", "wrong": "s3_wrong",
				"why": "An emergency is treated first. Approval, or the bill, follows. An appendix doesn't read policy documents.",
				"good": "Patient first, paperwork second."}))
	else:
		steps.append(_one(dice, "s3", "The family asks you to write the hernia up as an 'emergency':", [
			_opt("honest", "No. Write what it is, and help them with the cost: a payment plan, or a government scheme"),
			_opt("yes", "Write 'emergency'. Who checks?"), _opt("delay", "Tell them to come back in two years"),
			_opt("refuse", "Refuse to operate")], "honest",
			{"right": "s3_right_hernia", "wrong": "s3_wrong_hernia",
				"why": "The insurer checks. Write what it is, then help with the cost honestly.",
				"good": "The truth on the form, and real help with the bill."}))
	return {"title": "The insurance form", "spot": "Insurance desk", "card": "THE DOCUMENTS", "facts": facts, "steps": steps}


static func _rupees(amount: int) -> String:
	var text := str(amount)
	if text.length() <= 3:
		return text
	var last := text.substr(text.length() - 3)
	var rest := text.substr(0, text.length() - 3)
	var parts: Array[String] = []
	while rest.length() > 2:
		parts.push_front(rest.substr(rest.length() - 2))
		rest = rest.substr(0, rest.length() - 2)
	if not rest.is_empty():
		parts.push_front(rest)
	return ",".join(parts) + "," + last


static func _swap_digits(amount: int) -> int:
	var text := str(amount)
	var swapped := text[1] + text[0] + text.substr(2)
	if swapped == text:
		swapped = str(amount + 9000)
	return int(swapped)


# --- A snakebite at three in the morning ------------------------------------------------------

static func _snakebite(dice: SeededRandom, level: String) -> Dictionary:
	var kinds := ["krait", "russell", "dry"]
	if level != "easy":
		kinds += ["cobra", "sawscaled"]
	var snake: String = dice.pick(kinds)
	var child: bool = level == "extreme" and dice.chance(0.5)
	var patient: String = "Bablu Dhangar, 9, from Wadi village" if child \
		else str(dice.pick(["Mr. Balu Gavde, 38, a farmer", "Mrs. Laxmibai Kokate, 52, a farmer", "Mr. Sambhaji Pote, 44, a watchman"]))
	var signs: Array = {
		"krait": ["Bitten asleep on the floor, around midnight. Barely felt it.", "No swelling at all.",
			"Eyelids drooping, voice thick, says his stomach hurts.", "20-minute clotting test: clotted."],
		"cobra": ["Bitten in the field at dusk. Saw a hood.", "Painful swelling around the bite.",
			"Eyelids drooping, struggling to swallow.", "20-minute clotting test: clotted."],
		"russell": ["Bitten on the foot in the sugarcane.", "Swelling up to the knee, very painful.", "Gums oozing blood.",
			"20-minute clotting test: still liquid after 20 minutes."],
		"sawscaled": ["Bitten lifting firewood. A small brown snake.", "Swelling around the bite.", "Blood in the urine.",
			"20-minute clotting test: not clotted."],
		"dry": ["Bitten six hours ago. Two fang marks, mild pain.", "No swelling beyond the bite. No drooping, no bleeding.",
			"20-minute clotting test: clotted. Again at six hours: clotted."]}[snake]
	var aid: String = dice.pick(["tourniquet", "cut", "splint"])
	var aid_text: String = {"tourniquet": "First aid: a rope tied tight above the bite, by the whole village.",
		"cut": "First aid: the local healer cut the bite and sucked it. Twice.",
		"splint": "First aid: the PHC nurse splinted the leg and kept him still."}[aid]
	var facts: Array[String] = [patient]
	facts.append_array(signs)
	facts.append(aid_text)
	var syndrome: String = {"krait": "neuro", "cobra": "neuro", "russell": "haemo", "sawscaled": "haemo", "dry": "none"}[snake]
	var steps: Array = []
	steps.append(_one(dice, "s1", "What is the venom doing?", [
		_opt("neuro", "Nerves: it's paralysing"), _opt("haemo", "Blood: it's stopping clotting"),
		_opt("none", "Nothing yet: no signs of venom"), _opt("allergy", "An allergic reaction")], syndrome,
		{"right": "s1_right", "wrong": "s1_wrong",
			"why": {"neuro": "Drooping eyelids, a thick voice, trouble swallowing: the nerves. A clotting test that clots says the blood is fine.",
				"haemo": "Bleeding gums or blood in the urine, and blood that won't clot in 20 minutes: the venom is in the blood.",
				"none": "Fang marks, but no swelling spreading, no drooping, no bleeding, and the blood clots, twice: a dry bite so far."}[syndrome],
			"good": "You read the signs and the clotting test together."}))
	steps.append(_one(dice, "s2", "Antivenom (ASV)?", [
		_opt("ten", "10 vials of ASV now, slowly, with adrenaline ready"),
		_opt("one", "1 vial, and see"),
		_opt("none", "No ASV: watch for 24 hours, clotting test every six hours"),
		_opt("half", "5 vials" + (": he's a child" if child else ": to be careful"))], "none" if syndrome == "none" else "ten",
		{"right": "s2_right_none" if syndrome == "none" else "s2_right", "wrong": "s2_wrong",
			"why": ("No signs of venom means no ASV yet: it can cause reactions of its own. Watch, and repeat the clotting test." if syndrome == "none"
				else "Signs of venom mean 10 vials, given slowly with adrenaline ready for a reaction.") +
				(" Snakes don't give children a smaller dose. Neither does the ASV." if child and syndrome != "none" else ""),
			"good": "The right dose for the signs. Snakes don't do half measures, so neither do you."}))
	steps.append(_one(dice, "s3", {"tourniquet": "The rope above the bite:", "cut": "The healer's cut:", "splint": "The splint:"}[aid],
		{"tourniquet": [_opt("loosen", "Loosen it slowly once the ASV is running and adrenaline is ready"),
			_opt("cut", "Cut it off right now"), _opt("leave", "Leave it on till morning"), _opt("tighter", "Tie it tighter")],
		"cut": [_opt("clean", "Clean and dress it, give tetanus, and no more cutting; watch it for oozing"),
			_opt("suck", "Suck it again"), _opt("stitch", "Stitch it shut"), _opt("ice", "Pack it in ice")],
		"splint": [_opt("keep", "Keep the splint and keep him still: it's exactly right"),
			_opt("off", "Take the splint off to have a look"), _opt("walk", "Let him walk to the bathroom"),
			_opt("rub", "Rub the leg to get the venom moving out")]}[aid],
		{"tourniquet": "loosen", "cut": "clean", "splint": "keep"}[aid],
		{"right": "s3_right", "wrong": "s3_wrong",
			"why": {"tourniquet": "A tight rope is bad first aid, but cutting it off at once can flood the body with venom. Loosen it once the ASV is in.",
				"cut": "Cutting and sucking only adds an infection. Clean it, cover it, tetanus, and a wound that oozes tells you about the blood.",
				"splint": "A splint and stillness slow the venom down. The PHC nurse did it right; don't undo it."}[aid],
			"good": "First aid sorted out without making it worse."}))
	if level != "easy":
		var follow: Array = {
			"haemo": ["Six hours after the ASV, the clotting test still doesn't clot:",
				[_opt("repeat", "Repeat the ASV dose, and test again in six hours"), _opt("vitk", "Give vitamin K and wait"),
				_opt("stop", "Nothing more: the ASV is done"), _opt("ffp", "Plasma only, no more ASV")], "repeat",
				"Blood that still won't clot six hours after ASV needs another dose. Test again six hours after that."],
			"neuro": ["An hour after the ASV, his breathing is getting weaker:",
				[_opt("airway", "Support his breathing: bag and mask, and the anaesthetist to put a tube in"),
				_opt("more", "Another 10 vials every hour until he's better"), _opt("wait", "He's still talking, so wait"),
				_opt("sit", "Sit him up and give oxygen by mask")], "airway",
				"Paralysed breathing muscles need breathing support now; more ASV won't work fast enough. Talking isn't breathing well."],
			"none": ["At 24 hours: still no signs, and the clotting tests are normal:",
				[_opt("home", "Home, with clear instructions to come back if anything changes"), _opt("asv", "ASV anyway, just in case"),
				_opt("week", "Keep him a week"), _opt("antibiotic", "Antibiotics for the bite")], "home",
				"Twenty-four quiet hours and normal clotting tests: a dry bite. Home, with a careful talk about what to come back for."]}[syndrome]
		steps.append(_one(dice, "s4", str(follow[0]), follow[1], str(follow[2]),
			{"right": "s4_right", "wrong": "s4_wrong", "why": str(follow[3]), "good": str(follow[3])}))
	return {"title": "A snakebite at night", "spot": "Admissions", "card": "ADMISSIONS · SNAKEBITE", "facts": facts, "steps": steps}


# --- Dengue season -------------------------------------------------------------------------------

## A dengue patient of a kind: [text, detail, right choice, reason].
static func _dengue_patient(dice: SeededRandom, kind: String, name: String) -> Array:
	match kind:
		"low":
			var count := dice.next_int_in(6, 9)
			return ["%s, day %d of fever" % [name, dice.next_int_in(4, 6)],
				"Platelets %d,000 · no bleeding · BP %d/%d · eating a little" % [count, dice.next_int_in(108, 122), dice.next_int_in(72, 80)],
				"plt", "%s's count is %d,000: under 10,000, platelets even without bleeding." % [name, count]]
		"bleed":
			var count := dice.next_int_in(14, 22)
			return ["%s, day 5 of fever" % name,
				"Platelets %d,000 · black stools since morning · BP %d/%d" % [count, dice.next_int_in(104, 118), dice.next_int_in(70, 78)],
				"plt", "%s is bleeding inside (black stools) with a low count: platelets." % name]
		"shock":
			var top := dice.next_int_in(86, 98)
			var gap := dice.next_int_in(12, 18)
			var count := dice.next_int_in(38, 62)
			return ["%s, day 5 of fever" % name,
				"BP %d/%d · pulse %d · cold hands, restless · platelets %d,000" % [top, top - gap, dice.next_int_in(118, 134), count],
				"hdu", "%s's pulse pressure is %d (under 20), cold and restless: shock. Fluids fast in HDU, not platelets; the count isn't the problem." % [name, gap]]
		"warning":
			var hct := dice.next_int_in(44, 48)
			var drop := dice.next_int_in(48, 62)
			var sign: String = dice.pick(["vomiting everything since last night", "belly pain under the right ribs",
				"haematocrit up from 38 to %d" % hct])
			return ["%s, day 4 of fever" % name,
				"Platelets %d,000 and falling · %s · BP %d/%d" % [drop, sign, dice.next_int_in(110, 124), dice.next_int_in(74, 82)],
				"ward", "%s has a warning sign (%s) with a steady BP: admit for IV fluids and close watch." % [name, sign.split(" since")[0]]]
		_:
			var count := dice.next_int_in(68, 140)
			return ["%s, day %d of fever" % [name, dice.next_int_in(2, 3)],
				"Platelets %d,000 · eating, drinking, walking · no warning signs · family demanding platelets" % count,
				"home", "%s has no warning signs and %d,000 platelets: home, paracetamol, fluids. Platelets would only use up someone else's." % [name, count]]


static func _dengue(dice: SeededRandom, level: String) -> Dictionary:
	var kinds: Array = {"easy": ["low", "shock", "warning", "home", "home"],
		"hard": ["low", "bleed", "shock", "warning", "warning", "home"],
		"extreme": ["low", "bleed", "shock", "shock", "warning", "warning", "home"]}[level]
	var names := dice.shuffled(["Rahul", "Mrs. Sonawane", "Imran", "Pooja", "Mr. Kale", "Baby Aarohi's father", "Tanvi", "Mr. Dsouza"])
	var items: Array = []
	var answer := {}
	var reasons := {}
	var index := 0
	for kind: String in dice.shuffled(kinds):
		index += 1
		var id := "p%d" % index
		var made := _dengue_patient(dice, kind, str(names[index - 1]))
		items.append({"id": id, "text": made[0], "detail": made[1]})
		answer[id] = made[2]
		reasons[id] = made[3]
	var facts: Array[String] = ["Two units of platelets in the blood bank. That's all, till tomorrow.",
		"Platelets: under 10,000, or bleeding with a low count", "Shock (pulse pressure under 20, cold, restless): HDU, fluids fast",
		"Warning signs (vomiting, belly pain, rising haematocrit): ward, IV fluids", "No warning signs: home, paracetamol, fluids"]
	var steps: Array = []
	steps.append({"id": "s1", "kind": "each", "prompt": "Five families, all asking for platelets. Decide for each patient:" if level == "easy"
			else "Every family is asking for platelets. Decide for each patient:", "items": items,
		"choices": [{"id": "plt", "text": "Platelets", "limit": 2}, {"id": "hdu", "text": "HDU"}, {"id": "ward", "text": "Ward"},
			{"id": "home", "text": "Home"}],
		"answer": answer, "reasons": reasons, "right": "s1_right", "wrong": "s1_wrong", "hint": "s1_hint", "weight": 2.0,
		"why": "Platelets for the very low count or the bleeding, HDU for shock, the ward for warning signs, home for the rest.",
		"good": "Two units, to the two who needed them, and everyone else where they belong."})
	steps.append(_one(dice, "s2", "A mother asks for a painkiller from the chemist (ibuprofen), and papaya leaf juice:", [
		_opt("para", "Paracetamol only: no ibuprofen or aspirin, they make bleeding worse. The juice won't replace fluids."),
		_opt("ibu", "Ibuprofen is fine for the fever"), _opt("juice", "Papaya juice instead of the drip"),
		_opt("nothing", "No medicine at all")], "para",
		{"right": "s2_right", "wrong": "s2_wrong",
			"why": "In dengue only paracetamol: ibuprofen and aspirin thin the blood when the platelets are already low. Papaya juice is harmless and useless; fluids are not.",
			"good": "Paracetamol, fluids, and honesty about the papaya."}))
	return {"title": "Dengue season", "spot": "Fever ward", "card": "FEVER WARD · DENGUE", "facts": facts, "steps": steps}


# --- Inspection in thirty minutes --------------------------------------------------------------

const JOBS := [
	["key", "Find the crash cart key (Dr. Sethi's coat, probably)", 4, 0, false, ""],
	["crash", "Replace the expired adrenaline in the crash cart", 6, 30, true, "key"],
	["register", "Fill the gaps in the controlled drugs register, honestly", 8, 20, true, ""],
	["oxygen", "Check the oxygen cylinders and label the empty ones", 4, 20, true, ""],
	["tag", "Tag the broken BP machine 'Out of order' and log the repair", 2, 10, false, ""],
	["sharps", "Empty the overflowing sharps bin", 3, 15, false, ""],
	["fridge", "Fill in the drug fridge temperature chart, and check it works", 5, 15, false, ""],
	["fire", "Show the two new nurses the fire exits", 5, 15, false, ""],
	["handrub", "Refill the hand rub at every bed", 6, 10, false, ""],
	["hide", "Hide the broken BP machine in the sluice room", 3, -15, false, ""],
	["beds", "Make every bed with hospital corners", 12, 10, false, ""],
	["poster", "Put up the new 'Patients' rights' poster", 2, 5, false, ""],
	["paint", "Paint over the damp patch by the window", 15, 0, false, ""],
	["files", "Sort the discharge files alphabetically", 9, 5, false, ""],
]


static func _inspection(dice: SeededRandom, level: String) -> Dictionary:
	var count := 8 if level == "easy" else (10 if level == "hard" else 12)
	var budget := 25 if level == "extreme" else 30
	var must := ["key", "crash", "register", "oxygen", "tag"]
	if level != "easy":
		must.append("hide")
	if level == "extreme":
		must.append("paint")
	var rest: Array = []
	for job: Array in JOBS:
		if str(job[0]) not in must:
			rest.append(str(job[0]))
	var chosen: Array = must + dice.shuffled(rest).slice(0, count - must.size())
	var items: Array = []
	var costs := {}
	var values := {}
	var needs := {}
	var critical := {}
	var reasons := {}
	for job: Array in JOBS:
		var id := str(job[0])
		if id not in chosen:
			continue
		costs[id] = int(job[2])
		values[id] = int(job[3])
		critical[id] = bool(job[4])
		if not str(job[5]).is_empty():
			needs[id] = str(job[5])
		items.append({"id": id, "text": str(job[1]), "detail": "%d min%s" % [int(job[2]), " · must do" if bool(job[4]) and level == "easy" else ""]})
	reasons = {"crash": "The crash cart's adrenaline: expired drugs in a crash cart fail inspections and patients. (It needs the key first.)",
		"register": "The controlled drugs register is checked first by every inspector, and should be by every ward.",
		"oxygen": "Empty oxygen cylinders with no label are how someone dies during an inspection.",
		"hide": "Inspectors always open the sluice room. A hidden machine is a lie; a tagged one is a repair request.",
		"paint": "Fifteen minutes of wet paint impresses nobody and hides nothing.",
		"key": "The adrenaline is locked in the crash cart: without the key, replacing it is a wish, not a job."}
	var facts: Array[String] = ["Inspectors in the car park. %d minutes." % budget,
		"Grace has found: expired adrenaline in the crash cart (locked), gaps in the drugs register, a broken BP machine, two cylinders that sound empty.",
		"You and Grace can do %d minutes of jobs between you." % budget]
	var steps: Array = []
	steps.append({"id": "s1", "kind": "some", "budget": budget, "prompt": "What gets done before they walk in?", "items": dice.shuffled(items),
		"costs": costs, "values": values, "needs": needs, "critical": critical, "reasons": reasons,
		"right": "s1_right", "wrong": "s1_wrong", "hint": "s1_hint", "weight": 2.0,
		"why": "Safety first (crash cart, oxygen, the drugs register), honesty always, decoration only with minutes left over.",
		"good": "Everything that keeps patients safe, honestly, inside the time."})
	steps.append(_one(dice, "s2", "The inspector asks for the expired drugs log. Three vials expired this month:", [
		_opt("honest", "Show it, with what was done about each one"),
		_opt("none", "Say nothing expired this month"), _opt("pharmacy", "Say the log is at the pharmacy"),
		_opt("blame", "Blame the night shift")], "honest",
		{"right": "s2_right", "wrong": "s2_wrong",
			"why": "Expired vials happen everywhere. A log that shows what you did about them is a good ward; a lie is a closed one.",
			"good": "Honest, with the paperwork to prove what you did."}))
	return {"title": "Inspection in thirty minutes", "spot": "Ward 4", "card": "WARD 4 · BEFORE THE INSPECTION", "facts": facts,
		"steps": steps}
