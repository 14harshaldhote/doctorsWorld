class_name OperationTask
extends TrainingTask
## An operation: the rules, the patient's condition, the team's lines and the
## score, with no visuals. Which operation it is comes from Procedures
## (Rohit's appendectomy unless the setup names another).
##
## It chains the training skills: a time-out (reading what is in front of
## you), instrument calls to Tom on the ring, tracing a cut, holding, finding
## and tapping things inside, decisions when something goes wrong, the swab
## count and the stitches. What happened before the operation comes in as
## setup: whether the player asked about allergies, whether the operation was
## put off, how well they scrubbed.
##
## The patient's condition ("stability", 0 to 100) drops with mistakes and
## while a complication goes untreated. At 20 Dr. Iyer takes over. Time
## passes only through tick(), so tests can play an operation start to end.
##
## Difficulty ("easy", "hard" or "extreme"; "" plays the operation as it was
## written) changes how fast things go wrong, how many things go wrong, how
## often the time-out board has a mistake on it, and whether hints are
## offered. Each case also rolls where things sit inside, from the seed.
##
## Positions on the skin are in centimetres: x along the body towards the
## feet, y across it towards the player, inside a window of SKIN.

## The appendectomy's steps, kept for anything that wants Rohit's operation.
const STEPS := ["incision", "retract", "find", "clamp", "cut", "close"]
const SKIN := Vector2(20.0, 14.0)
const GUIDE_SAMPLES := 40
## Seconds before a call counts as slow, and before Tom just hands it over.
const SLOW_CALL := 5.0
const HAND_OVER := 10.0
const MAX_WRONG := 3
## At or below this, Dr. Iyer takes over.
const TAKEOVER := 20.0
const HOLD_TIME := 2.0
const WASH_TIME := 3.0
## Seconds of a beat: someone talks, the team works, then the next thing.
const BEAT := 1.3
const SHORT_BEAT := 0.8
## A trace closer than this to the guide covers it.
const TRACE_NEAR := 0.7
const STITCH_MISS := 1.0
const STITCH_TARGET := 6
const MAX_STITCHES := 10
const SWAB_BASE_COUNT := 10
## Filling the belly with gas: how fast the gauge climbs, and the green band.
const FILL_RATE := 6.0
const FILL_LOW := 12.0
const FILL_HIGH := 15.0
const FILL_MAX := 20.0
## Points a hint costs on a hard case.
const HINT_COST := 5
const DIFFICULTIES := ["easy", "hard", "extreme"]
const DRAIN_SCALE := {"": 1.0, "easy": 0.7, "hard": 1.0, "extreme": 1.3}

## The operation being played: see Procedures.
var procedure := {}
## Its step ids, in order.
var steps: Array[String] = []
## What happened before: allergy_known, delayed, scrub (0 to 100),
## complication ("" to roll), lose_swab (-1 roll, 0, 1), difficulty, the
## team (lead, scrub_nurse, and anaesthetist: "" when there is none in the
## room), and
## anything a procedure's time-out asks about (tetanus_known...).
var setup := {}
var difficulty := ""
## "timeout", "beat", "call", "act", "decide", "count", "search", "done".
var phase := "timeout"
## The step or complication under way.
var step := "timeout"
var step_index := -1
## The instrument wanted in a call.
var wanted := ""
## In "act": "trace", "hold", "fill", "tap" or "stitch". target is what a
## tap wants.
var action := ""
var target := ""
## Who said the coach line: a cast id.
var speaker := "iyer"
var stability := 100.0
var vitals := Vitals.new()
## Seconds into the current call.
var call_time := 0.0
var wrong_this_call := 0
## The instrument in the doctor's hand.
var in_hand := ""
## Time-out: the board lines (with "answer" once given) and which is up.
var timeout_lines: Array[Dictionary] = []
var timeout_index := 0
## A decision's choices: [{id, text}].
var options: Array[Dictionary] = []
var holding := false
var hold_time := 0.0
## The gas gauge while filling.
var fill_level := 0.0
var trace: PackedVector2Array = PackedVector2Array()
var tracing := false
var stitches: Array[Dictionary] = []
## Steps done so far (and complications handled), for the 3D view.
var done_steps: Array[String] = []
## Complications still to come, by the step they follow.
var later := {}
## Complications (and slips, like "trap_cbd") that happened.
var happened: Array[String] = []
var active_complication := ""
var swabs_out := 0
var swabs_back := 0
var swab_missing := false
var swab_found := false
var counted := false
var takeover := false
var outcome := ""
var wrong_side := false
var reaction_coming := false
## Where things are inside this time (skin cm), and the parts to draw.
var targets := {}
var parts: Array[Dictionary] = []
## For a step that reads something (the trapped bowel): which version this is.
var variants := {}
## Taps in a step that needs several (the ports), done so far.
var sequence_index := 0
var hints_used := 0
## Score parts.
var calls := 0
var wrong_calls := 0
var slow_calls := 0
var handed_over := 0
var trace_score := -1
var trace_retries := 0
var hold_restarts := 0
var tap_misses := 0
var decisions_wrong := 0
var timeout_points := 0.0
var closed_on_bad_count := false
var recounts := 0
var stitch_misses := 0
var fill_tries := 0
var overfilled := false
## Step decisions (reading the bowel): {step: true when right first time}.
var step_decisions := {}

var _rng: SeededRandom
var _guide := PackedVector2Array()
var _lengths := PackedFloat32Array()
var _beat_left := 0.0
var _after := Callable()
var _drain := 0.0
var _complication_swabs := 0
var _queue: Array[String] = []
var _slow_said := false
var _vital_goal := {}
var _vital_now := {}
var _hinted := ""


func _init(with_seed: int = 1, with_setup: Dictionary = {}) -> void:
	_rng = SeededRandom.new(with_seed)
	setup = {"allergy_known": false, "delayed": false, "scrub": 100, "complication": "", "lose_swab": -1, "called": "Doctor",
		"procedure": "appendix", "difficulty": ""}
	setup.merge(with_setup, true)
	procedure = Procedures.get_procedure(str(setup["procedure"]))
	id = str(procedure["id"])
	difficulty = str(setup["difficulty"]) if str(setup["difficulty"]) in DIFFICULTIES else ""
	for entry: Dictionary in procedure["steps"]:
		steps.append(str(entry["id"]))
	var delayed_kind := str(procedure.get("delayed", ""))
	stability = 90.0 if bool(setup["delayed"]) and not delayed_kind.is_empty() else 100.0
	_build_guide()
	_build_timeout()
	_plan_complications(delayed_kind)
	_lay_out()
	_set_vital_goal()
	_snap_vitals()
	phase = "timeout"
	step = "timeout"
	_say_by(_lead(), "Time-out. Everyone stops. %s, read it out. {called}, check every line." % scrub_name())
	_next_timeout_line()


## The appendectomy's step titles, for anything without a task to ask.
static func title_of_step(which: String) -> String:
	for entry: Dictionary in Procedures.get_procedure("appendix")["steps"]:
		if str(entry["id"]) == which:
			return str(entry["title"])
	var known: Dictionary = Procedures.COMPLICATIONS.get(which, {})
	if known.has("title"):
		return str(known["title"]).replace("{He}", "He")
	return {"count": "The count", "timeout": "Time-out"}.get(which, which.capitalize())


## This operation's title for a step or complication.
func step_title(which: String) -> String:
	var data := _data(which)
	if data.has("title"):
		return _fill(str(data["title"]))
	return {"count": "The count", "timeout": "Time-out"}.get(which, which.capitalize())


func title() -> String:
	return str(procedure["title"])


## "Rohit Kulkarni".
func patient_name() -> String:
	return str(procedure.get("patient", "the patient"))


## "Rohit".
func patient_first() -> String:
	return str(procedure.get("first", patient_name()))


## The headline for the score card.
func outcome_line() -> String:
	return str((procedure.get("outcome_lines", {}) as Dictionary).get(outcome, "Done."))


func _lead() -> String:
	return str(setup.get("lead", procedure.get("lead", "iyer")))


## Who is scrubbed at the ring, handing instruments and counting: Tom, unless
## the doctor picked their own team.
func _scrub() -> String:
	return str(setup.get("scrub_nurse", "tom"))


func _anaesthetist() -> String:
	return str(setup.get("anaesthetist", "khan"))


## The scrub nurse's first name, "Tom".
func scrub_name() -> String:
	return str(StoryBook.cast().get(_scrub(), {}).get("name", "Tom")).split(" ")[0]


## The anaesthetist as named in notes, "Dr. Khan".
func anaesthetist_name() -> String:
	var full := str(StoryBook.cast().get(_anaesthetist(), {}).get("name", "Dr. Khan"))
	var words := full.split(" ")
	return "Dr. " + words[words.size() - 1] if full.begins_with("Dr. ") else full


## How the doctor leading the operation is named: "Dr. Iyer", "Dr. Bhatt".
func lead_name() -> String:
	var full := str(StoryBook.cast().get(_lead(), {}).get("name", "Dr. Iyer"))
	var words := full.split(" ")
	return "Dr. " + words[words.size() - 1] if full.begins_with("Dr. ") else full


## The data for a step or a complication by id.
func _data(which: String) -> Dictionary:
	for entry: Dictionary in procedure["steps"]:
		if str(entry["id"]) == which:
			return entry
	if Procedures.COMPLICATIONS.has(which):
		return Procedures.complication(procedure, which)
	return {}


func _is_complication(which: String) -> bool:
	return Procedures.COMPLICATIONS.has(which) and not steps.has(which)


## The step that closes the skin (the last stitch step).
func _closing_step() -> String:
	for index in range(steps.size() - 1, -1, -1):
		if str(_data(steps[index]).get("act", "")) == "stitch":
			return steps[index]
	return ""


func _has_act(act: String) -> bool:
	for entry: Dictionary in procedure["steps"]:
		if str(entry.get("act", "")) == act:
			return true
	return false


# --- Setting up the case -------------------------------------------------------

func _build_timeout() -> void:
	# Which line on the board is wrong this time (only on a graded case).
	var wrong_line := ""
	if not difficulty.is_empty():
		var can_be_wrong: Array = []
		for line: Dictionary in procedure["timeout"]:
			if line.has("wrong_reads"):
				can_be_wrong.append(str(line["id"]))
		var odds := {"easy": 0.0, "hard": 0.6, "extreme": 1.0}
		if not can_be_wrong.is_empty() and _rng.chance(float(odds[difficulty])):
			wrong_line = str(_rng.pick(can_be_wrong))
	elif setup.has("board_wrong"):
		wrong_line = str(setup["board_wrong"])
	for line: Dictionary in procedure["timeout"]:
		var copy := line.duplicate()
		match str(copy.get("kind", "")):
			"allergy":
				if bool(copy.get("allergic", true)):
					copy["right"] = "stop" if bool(setup.get(str(copy.get("known", "allergy_known")), false)) else "unsure"
				else:
					# No allergies: right to confirm only if somebody asked.
					copy["right"] = "confirm" if bool(setup.get(str(copy.get("asked", "allergy_asked")), false)) else "unsure"
			"known":
				copy["right"] = "stop" if bool(setup.get(str(copy["known"]), false)) else "unsure"
		if str(copy["id"]) == wrong_line or str(setup.get("board_wrong", "")) == str(copy["id"]):
			copy["reads"] = copy["wrong_reads"]
			copy["said"] = copy["wrong_said"]
			copy["right"] = "stop"
		timeout_lines.append(copy)


func _plan_complications(delayed_kind: String) -> void:
	var after := str(procedure.get("complication_after", steps[0]))
	var pool: Array = procedure["pool"]
	if bool(setup["delayed"]) and not delayed_kind.is_empty():
		later[after] = [delayed_kind]
		return
	var pick := str(setup["complication"])
	# Something nobody caught before theatre (a blood thinner still given)
	# brings its own trouble.
	var brings: Dictionary = procedure.get("unknown_brings", {})
	for key: String in brings:
		if setup.has(key) and not bool(setup[key]) and pick != "none":
			pick = str(brings[key])
	if pick == "none":
		return
	if pick not in pool:
		pick = str(_rng.pick(pool))
	later[after] = [pick]
	if difficulty == "extreme" and procedure.has("extreme_after"):
		var others := pool.filter(func(item: String) -> bool: return item != pick)
		if not others.is_empty():
			var second := str(setup.get("second_complication", _rng.pick(others)))
			var at := str(procedure["extreme_after"])
			var list: Array = later.get(at, [])
			list.append(second)
			later[at] = list


## Rolls where things sit inside, and builds the parts the table draws.
func _lay_out() -> void:
	var fixed: Dictionary = procedure.get("fixed_targets", {})
	for key: String in fixed:
		targets[key] = fixed[key]
	match id:
		"wound":
			_lay_out_wound()
		"gallbladder":
			_lay_out_gallbladder()
		"hernia":
			_lay_out_hernia()
		"hip":
			_lay_out_hip()
		"spleen":
			_lay_out_spleen()
		"obstruction":
			_lay_out_obstruction()
		"bile_leak":
			_lay_out_bile_leak()
	for entry: Dictionary in procedure.get("parts", []):
		if bool(entry.get("extreme", false)) and difficulty != "extreme":
			continue
		var part := entry.duplicate()
		var where := str(part.get("at", part["id"]))
		if where == "wound":
			part["at"] = procedure.get("wound_centre", Vector2(12, 9))
		elif targets.has(where):
			part["at"] = targets[where]
		if part.has("at") or part.has("from"):
			parts.append(part)
	for key: String in (procedure.get("variants", {}) as Dictionary):
		var kinds: Array = (procedure["variants"][key] as Dictionary).keys()
		var chosen := str(setup.get(key, ""))
		if chosen not in kinds:
			chosen = _roll_variant(kinds)
		variants[key] = chosen


## A version for a step that reads something: the gentlest on easy, a coin
## toss between the first two on hard, the worst on extreme. A delayed case
## is never the gentlest.
func _roll_variant(kinds: Array) -> String:
	if bool(setup.get("delayed", false)):
		return str(kinds[kinds.size() - 1] if difficulty == "extreme" else kinds[mini(1, kinds.size() - 1)])
	match difficulty:
		"easy":
			return str(kinds[0])
		"extreme":
			return str(kinds[kinds.size() - 1])
	return str(_rng.pick(kinds.slice(0, mini(2, kinds.size()))))


## Picks one of the slot positions for a target, away from those taken.
func _slot(key: String, taken: Array) -> Vector2:
	var choices: Array = _rng.shuffled((procedure["slots"] as Dictionary).get(key, [Vector2(12, 9)]))
	for choice: Vector2 in choices:
		var clear := true
		for other: Vector2 in taken:
			if choice.distance_to(other) < 1.3:
				clear = false
		if clear:
			taken.append(choice)
			return choice
	taken.append(choices[0])
	return choices[0]


func _lay_out_wound() -> void:
	var taken: Array = []
	targets["glass"] = _slot("glass", taken)
	if difficulty == "extreme":
		targets["glass2"] = _slot("glass", taken)
	targets["tendon"] = _slot("tendon", taken)
	targets["fat"] = _slot("fat", taken)
	targets["bleeder"] = _slot("bleeder", taken)
	var extreme: Dictionary = procedure.get("extreme", {})
	if difficulty == "extreme" and extreme.has("sequence"):
		for step_id: String in extreme["sequence"]:
			for entry: Dictionary in procedure["steps"]:
				if str(entry["id"]) == step_id:
					entry["sequence"] = extreme["sequence"][step_id]
					entry["hits"] = ["One piece. She said it shattered. Is that all of it?",
						"And a second sliver, deeper. Now it's clean."]
					entry.erase("target")


## The keyhole view: the liver across the top, the gallbladder hanging under
## it, and three tubes. Which side everything leans to changes, and on an
## extreme case the main duct is tented up close to the gallbladder, so the
## duct you want looks very short.
func _lay_out_gallbladder() -> void:
	var flip := 1.0 if str(setup.get("layout", _rng.pick(["left", "right"]))) == "left" else -1.0
	var tented := difficulty == "extreme" or bool(setup.get("tented", false))
	var centre := Vector2(12.6, 8.2)
	var mirror := func(spot: Vector2) -> Vector2: return Vector2(centre.x + (spot.x - centre.x) * flip, spot.y)
	var liver: Vector2 = mirror.call(Vector2(12.6, 5.6))
	var gallbladder: Vector2 = mirror.call(Vector2(14.6, 7.4))
	var neck: Vector2 = mirror.call(Vector2(13.4, 8.6))
	var cbd_top: Vector2 = mirror.call(Vector2(11.0, 6.8))
	var cbd_bottom: Vector2 = mirror.call(Vector2(11.4, 12.6))
	var join: Vector2 = mirror.call(Vector2(11.9, 10.2) if not tented else Vector2(12.6, 9.4))
	if tented:
		cbd_top = mirror.call(Vector2(11.6, 6.8))
	var artery_from: Vector2 = mirror.call(Vector2(10.6, 9.0))
	var artery_to: Vector2 = mirror.call(Vector2(13.8, 8.0))
	targets["liver"] = liver
	targets["gallbladder"] = gallbladder
	targets["duct"] = neck.lerp(join, 0.5)
	targets["cbd"] = cbd_top.lerp(join, 0.45) if not tented else join.lerp(cbd_bottom, 0.22)
	targets["artery"] = artery_from.lerp(artery_to, 0.42)
	targets["between"] = neck.lerp(join, 0.5).lerp(artery_from.lerp(artery_to, 0.6), 0.5)
	targets["duodenum"] = mirror.call(Vector2(9.0, 11.6))
	targets["bleeder"] = gallbladder.lerp(liver, 0.45)
	parts.append_array([
		{"id": "scope", "kind": "scope", "at": centre + Vector2(0, 0.6), "size": Vector2(0.115, 0.0), "colour": Color("#0B0E10"), "show": "open&!closing"},
		{"id": "belly_wall", "kind": "disc", "at": centre + Vector2(0, 0.6), "size": Vector2(0.118, 0.1), "colour": Color("#B94F4A"), "show": "open&!closing", "lift": 0.004},
		{"id": "liver", "kind": "blob", "at": liver, "size": Vector2(0.062, 0.4), "colour": Color("#7A2A26"), "show": "open&!closing", "tap": true},
		{"id": "gallbladder", "kind": "pear", "at": gallbladder, "to": neck, "size": Vector2(0.024, 0.0), "colour": Color("#5E8F45"),
			"show": "open&!done:remove&!closing", "tap": true, "lifted": "done:find", "lift": 0.016},
		{"id": "duodenum", "kind": "blob", "at": targets["duodenum"], "size": Vector2(0.032, 0.5), "colour": Color("#E39E95"), "show": "open&!closing", "tap": true},
		{"id": "cbd", "kind": "tube", "from": cbd_top, "to": cbd_bottom, "size": Vector2(0.0062, 0.0), "colour": Color("#B9C26A"),
			"show": "open&!closing", "tap_at": targets["cbd"], "lift": 0.014},
		{"id": "duct", "kind": "tube", "from": neck, "to": join, "size": Vector2(0.0046, 0.0), "colour": Color("#D6DB8A"),
			"show": "open&!done:divide&!closing", "tap_at": targets["duct"], "lift": 0.015},
		{"id": "artery", "kind": "tube", "from": artery_from, "to": artery_to, "size": Vector2(0.0032, 0.0), "colour": Color("#C2303A"),
			"show": "open&!done:divide&!closing", "tap_at": targets["artery"], "pulse": true, "lift": 0.016},
		{"id": "clips_duct", "kind": "clips", "at": targets["duct"], "colour": Color("#D8DEE2"), "show": "done:clip_duct&!done:remove&!closing"},
		{"id": "clips_artery", "kind": "clips", "at": targets["artery"], "colour": Color("#D8DEE2"), "show": "done:clip_artery&!done:remove&!closing"},
		{"id": "between", "kind": "mark", "at": targets["between"], "colour": Color("#FFFFFF"), "show": "step:divide", "tap": true},
		{"id": "bag", "kind": "sack", "at": targets["bag"], "size": Vector2(0.02, 0.0), "colour": Color("#F2F4F2"), "show": "step:remove", "tap": true},
		{"id": "ports", "kind": "ports", "colour": Color("#2B2F33"), "show": "done:ports", "points": ["port1", "port2", "port3"]},
		{"id": "port_marks", "kind": "marks", "colour": Color("#4B2F86"), "show": "!done:ports", "points": ["port1", "port2", "port3"]},
	])


func _lay_out_hernia() -> void:
	var below := str(setup.get("cord_side", _rng.pick(["below", "above"]))) == "below"
	var centre: Vector2 = procedure["wound_centre"]
	targets["sac"] = centre + Vector2(0.4, -0.3)
	targets["defect"] = centre + Vector2(-0.8, -0.2)
	targets["cord"] = centre + Vector2(0.2, 1.3 if below else -1.5)
	targets["loop"] = targets["sac"]
	targets["loop2"] = targets["sac"] + Vector2(1.5, 0.5)
	targets["bleeder"] = centre + Vector2(1.6, 0.4)


## The hip under X-ray: the screen comes over the wound once it is open,
## showing the thigh bone, its neck and the ball of the hip. Where the ball
## sits and the angle of the neck change with the seed. Four marks show
## where the guide wire could end; only one is centre and deep.
func _lay_out_hip() -> void:
	var screen := Vector2(12.4, 8.0)
	var tilt := _rng.range_float(-0.15, 0.15)
	# The head sits up and left of the screen's middle, clear of the panels.
	var head: Vector2 = screen + Vector2(-1.4, -1.2) + Vector2(_rng.range_float(-0.3, 0.3), _rng.range_float(-0.2, 0.2))
	var neck_base := screen + Vector2(0.4, 1.2)
	var along := (head - neck_base).normalized().rotated(tilt)
	head = neck_base + along * neck_base.distance_to(head)
	var up := Vector2(along.y, -along.x)
	if up.y > 0.0:
		up = -up
	var entry := screen + Vector2(1.2, 2.6)
	targets["aim_centre"] = head + along * 0.3
	targets["aim_high"] = head + up * 1.05 + along * 0.1
	targets["aim_joint"] = head + along * 1.75
	targets["aim_neck"] = neck_base.lerp(head, 0.45)
	targets["bleeder"] = procedure["wound_centre"] + Vector2(1.4, 0.3)
	var on_screen := "done:retract&!done:plate&!comp:bleeding&!closing"
	var bone := Color("#DAD6CA")
	var lined := "&is:film=lined"
	parts.append_array([
		{"id": "screen", "kind": "disc", "at": screen, "size": Vector2(0.105, 0.105), "colour": Color("#0B0F12"), "show": on_screen, "lift": 0.03},
		{"id": "shaft", "kind": "tube", "from": screen + Vector2(-0.2, 1.8), "to": screen + Vector2(4.4, 1.8), "size": Vector2(0.017, 0.0),
			"colour": bone, "show": on_screen, "lift": 0.032},
		{"id": "neck", "kind": "tube", "from": neck_base, "to": head - along * 0.9, "size": Vector2(0.012, 0.0),
			"colour": bone, "show": on_screen, "lift": 0.033},
		{"id": "head", "kind": "disc", "at": head, "size": Vector2(0.029, 0.029), "colour": bone, "show": on_screen + lined, "lift": 0.034},
		{"id": "head_off", "kind": "disc", "at": head + up * 0.45 - along * 0.2, "size": Vector2(0.029, 0.029), "colour": bone,
			"show": on_screen + "&!is:film=lined", "lift": 0.034},
		{"id": "break", "kind": "tube", "from": head - along * 1.0 + up * 0.7, "to": head - along * 1.0 - up * 0.7, "size": Vector2(0.0035, 0.0),
			"colour": Color("#0B0F12"), "show": on_screen + "&!is:film=lined", "lift": 0.036},
		{"id": "socket", "kind": "ring", "at": head, "size": Vector2(0.032, 0.036), "colour": Color("#8E8A80"), "show": on_screen, "lift": 0.033},
		{"id": "aim_centre", "kind": "mark", "at": targets["aim_centre"], "colour": Color("#FFFFFF"), "show": "step:wire", "tap": true, "lift": 0.047},
		{"id": "aim_high", "kind": "mark", "at": targets["aim_high"], "colour": Color("#FFFFFF"), "show": "step:wire", "tap": true, "lift": 0.047},
		{"id": "aim_joint", "kind": "mark", "at": targets["aim_joint"], "colour": Color("#FFFFFF"), "show": "step:wire", "tap": true, "lift": 0.047},
		{"id": "aim_neck", "kind": "mark", "at": targets["aim_neck"], "colour": Color("#FFFFFF"), "show": "step:wire", "tap": true, "lift": 0.047},
		{"id": "guide_wire", "kind": "tube", "from": entry, "to": targets["aim_centre"], "size": Vector2(0.0018, 0.0),
			"colour": Color("#F4F8FA"), "show": "done:wire&" + on_screen, "lift": 0.055},
		{"id": "channel", "kind": "tube", "from": entry, "to": targets["aim_centre"] - along * 0.5, "size": Vector2(0.006, 0.0),
			"colour": Color("#59606A"), "show": "done:drill&" + on_screen, "lift": 0.048},
		{"id": "plate_in", "kind": "tube", "from": procedure["wound_centre"] + Vector2(-2.0, 0.0), "to": procedure["wound_centre"] + Vector2(2.2, 0.0),
			"size": Vector2(0.007, 0.0), "colour": Color("#B9C4CA"), "show": "done:plate&!closing", "lift": 0.016},
		{"id": "screw_head", "kind": "disc", "at": procedure["wound_centre"] + Vector2(-2.0, 0.0), "size": Vector2(0.01, 0.01),
			"colour": Color("#D9B25A"), "show": "done:plate&!closing", "lift": 0.018},
	])


## The belly at night: blood everywhere until it is sucked clear, the spleen
## high on his left (the far side, by his head), the liver high on his right,
## four corners to pack, and the spleen's stalk with the tail of the pancreas
## lying against it, above or below it as the seed decides.
func _lay_out_spleen() -> void:
	var centre: Vector2 = procedure["wound_centre"]
	var spleen := centre + Vector2(-3.0, -1.6) + Vector2(_rng.range_float(-0.3, 0.3), _rng.range_float(-0.2, 0.2))
	var below := str(setup.get("pancreas_side", _rng.pick(["below", "above"]))) == "below"
	var stalk_from := spleen + Vector2(0.6, 0.3)
	var stalk_to := spleen + Vector2(1.8, 0.75)
	targets["stalk"] = stalk_from.lerp(stalk_to, 0.5)
	var pancreas_from := stalk_to + Vector2(0.2, 0.75 if below else -0.75)
	targets["pancreas"] = pancreas_from + Vector2(0.4, 0.1)
	targets["pack_spleen"] = centre + Vector2(-2.9, -1.4)
	targets["pack_liver"] = centre + Vector2(-2.9, 1.5)
	targets["pack_low_left"] = centre + Vector2(2.6, -1.0)
	targets["pack_low_right"] = centre + Vector2(3.1, 1.5)
	targets["bleeder"] = spleen + Vector2(0.5, 0.5)
	var torn := "done:pack&!done:clamp&!closing"
	parts.append_array([
		{"id": "blood", "kind": "disc", "at": centre, "size": Vector2(0.1, 0.05), "colour": Color("#5E0C0C"), "show": "open&!done:suction&!closing",
			"angle": true, "lift": 0.016},
		{"id": "liver", "kind": "blob", "at": centre + Vector2(-3.3, 1.8), "size": Vector2(0.03, 0.4), "colour": Color("#7A2A26"), "show": "open&!closing"},
		{"id": "spleen", "kind": "blob", "at": spleen, "size": Vector2(0.024, 0.5), "colour": Color("#6B2C4C"), "show": "open&!done:clamp&!closing"},
		{"id": "spleen_kept", "kind": "blob", "at": spleen, "size": Vector2(0.024, 0.5), "colour": Color("#6B2C4C"),
			"show": "done:clamp&had:chose_save&!closing"},
		{"id": "tear", "kind": "tube", "from": spleen + Vector2(-0.6, 0.2), "to": spleen + Vector2(-0.1, 0.45), "size": Vector2(0.0025, 0.0),
			"colour": Color("#2A0508"), "show": torn + "&is:spleen=tear", "lift": 0.02},
		{"id": "crack", "kind": "tube", "from": spleen + Vector2(-0.8, -0.3), "to": stalk_from, "size": Vector2(0.003, 0.0),
			"colour": Color("#2A0508"), "show": torn + "&is:spleen=deep", "lift": 0.02},
		{"id": "pieces", "kind": "dots", "at": spleen, "colour": Color("#3A0A14"), "show": torn + "&is:spleen=shattered", "lift": 0.02},
		{"id": "stalk", "kind": "tube", "from": stalk_from, "to": stalk_to, "size": Vector2(0.005, 0.0), "colour": Color("#9A2340"),
			"show": "done:suction&!closing", "tap_at": targets["stalk"], "lift": 0.016},
		{"id": "pancreas", "kind": "tube", "from": pancreas_from, "to": pancreas_from + Vector2(2.4, 0.3), "size": Vector2(0.006, 0.0),
			"colour": Color("#E6D49A"), "show": "done:suction&!closing", "tap_at": targets["pancreas"], "lift": 0.015},
		{"id": "bowel1", "kind": "ring", "at": centre + Vector2(1.6, 0.4), "colour": Color("#E8A4A0"), "size": Vector2(0.012, 0.03),
			"show": "done:suction&!closing", "lift": 0.014},
		{"id": "bowel2", "kind": "ring", "at": centre + Vector2(3.0, -0.3), "colour": Color("#E8A4A0"), "size": Vector2(0.01, 0.026),
			"show": "done:suction&!closing", "lift": 0.015},
		{"id": "pack_spleen", "kind": "mark", "at": targets["pack_spleen"], "colour": Color("#FFFFFF"), "show": "step:pack", "tap": true, "lift": 0.02},
		{"id": "pack_liver", "kind": "mark", "at": targets["pack_liver"], "colour": Color("#FFFFFF"), "show": "step:pack", "tap": true, "lift": 0.02},
		{"id": "pack_low_left", "kind": "mark", "at": targets["pack_low_left"], "colour": Color("#FFFFFF"), "show": "step:pack", "tap": true, "lift": 0.02},
		{"id": "pack_low_right", "kind": "mark", "at": targets["pack_low_right"], "colour": Color("#FFFFFF"), "show": "step:pack", "tap": true, "lift": 0.02},
		{"id": "packs", "kind": "dots", "colour": Color("#F2F2EC"), "show": "done:pack&!done:look&!closing", "lift": 0.018,
			"points": ["pack_spleen", "pack_liver", "pack_low_left", "pack_low_right"]},
		{"id": "welling", "kind": "disc", "at": targets["pack_spleen"] + Vector2(0.3, 0.2), "size": Vector2(0.026, 0.02), "colour": Color("#A51E1E"),
			"show": "done:suction&!done:pack&!closing", "lift": 0.017, "pulse": true},
	])


## A blocked bowel: fat, stretched loops on one side, flat ones beyond the
## block, the empty large bowel down the right, and at the block a nest of old
## scar round a swab left in 2004, held by a tight band. Where the block sits,
## and which way its band runs, are rolled from the seed.
func _lay_out_obstruction() -> void:
	var centre: Vector2 = procedure["wound_centre"]
	var block := centre + Vector2(_rng.range_float(-0.3, 1.0), _rng.range_float(-0.5, 0.3))
	var side := -1.0 if _rng.chance(0.5) else 1.0
	targets["transition"] = block
	targets["band"] = block + Vector2(0.0, side * 0.75)
	targets["bowel_wall"] = block + Vector2(-0.9, -side * 0.5)
	targets["loop_fat"] = centre + Vector2(-2.4, 0.9)
	targets["colon"] = centre + Vector2(2.6, 0.9)
	targets["bleeder"] = centre + Vector2(-1.3, -1.2)
	var fat := Color("#D47A70")
	var flat := Color("#EBC0B6")
	var opened := "open&!closing"
	parts.append_array([
		{"id": "loop_fat", "kind": "ring", "at": targets["loop_fat"], "size": Vector2(0.016, 0.042), "colour": fat, "show": opened,
			"tap_at": targets["loop_fat"], "lift": 0.014},
		{"id": "fat2", "kind": "ring", "at": centre + Vector2(-1.6, -0.8), "size": Vector2(0.015, 0.04), "colour": fat, "show": opened, "lift": 0.015},
		{"id": "fat3", "kind": "ring", "at": centre + Vector2(-1.1, 0.8), "size": Vector2(0.013, 0.034), "colour": fat,
			"show": "open&!done:free&!closing", "lift": 0.016},
		{"id": "fat3_eased", "kind": "ring", "at": centre + Vector2(-1.1, 0.8), "size": Vector2(0.011, 0.028), "colour": Color("#E3A096"),
			"show": "done:free&!closing", "lift": 0.016},
		{"id": "flat1", "kind": "ring", "at": block + Vector2(1.4, -0.6), "size": Vector2(0.007, 0.02), "colour": flat, "show": opened, "lift": 0.014},
		{"id": "flat2", "kind": "ring", "at": block + Vector2(1.1, 0.8), "size": Vector2(0.007, 0.018), "colour": flat, "show": opened, "lift": 0.015},
		{"id": "colon", "kind": "tube", "from": centre + Vector2(2.0, 1.7), "to": centre + Vector2(3.2, 0.1), "size": Vector2(0.009, 0.0),
			"colour": Color("#C7A28A"), "show": opened, "tap_at": targets["colon"], "lift": 0.013},
		{"id": "scar", "kind": "blob", "at": block, "size": Vector2(0.014, 0.4), "colour": Color("#E6D8C6"), "show": "open&!done:remove&!closing",
			"lift": 0.017},
		{"id": "swab_old", "kind": "sliver", "at": block + Vector2(0.15, 0.0), "size": Vector2(0.013, 0.009), "colour": Color("#F4F1E6"),
			"show": "done:run&!done:remove&!closing", "lift": 0.02},
		{"id": "band", "kind": "tube", "from": block + Vector2(-0.1, side * 0.3), "to": block + Vector2(0.1, side * 1.25),
			"size": Vector2(0.0035, 0.0), "colour": Color("#F7F2EA"), "show": "done:run&!done:free&!closing", "tap_at": targets["band"], "lift": 0.021},
		{"id": "bowel_wall", "kind": "blob", "at": targets["bowel_wall"], "size": Vector2(0.012, 0.5), "colour": Color("#E08F86"),
			"show": "done:run&!done:remove&!closing", "tap_at": targets["bowel_wall"], "lift": 0.016},
		{"id": "patch", "kind": "dots", "at": block, "colour": Color("#2E3A44"), "show": "done:remove&had:chose_repair&!closing", "lift": 0.018},
		{"id": "join", "kind": "ring", "at": block, "size": Vector2(0.006, 0.016), "colour": Color("#B35F58"),
			"show": "done:remove&had:chose_resect&!closing", "lift": 0.018},
	])


## Back in, three days after a keyhole gallbladder: the liver across the
## top, the bare bed where the gallbladder sat, the clipped stump of its
## duct and the main duct running past, all under a pool of bile. Where the
## leak is (the stump, the bed, or the main duct itself) is rolled here, so
## the leak, the fix and the main duct's tap point sit apart.
func _lay_out_bile_leak() -> void:
	var kinds: Array = (procedure["variants"]["leak"] as Dictionary).keys()
	var leak := str(setup.get("leak", ""))
	if leak not in kinds:
		leak = _roll_variant(kinds)
		setup["leak"] = leak
	var flip := 1.0 if str(setup.get("layout", _rng.pick(["left", "right"]))) == "left" else -1.0
	var centre := Vector2(12.6, 8.2)
	var mirror := func(spot: Vector2) -> Vector2: return Vector2(centre.x + (spot.x - centre.x) * flip, spot.y)
	var liver: Vector2 = mirror.call(Vector2(12.6, 5.6))
	var bed: Vector2 = mirror.call(Vector2(14.5, 7.1))
	var join: Vector2 = mirror.call(Vector2(11.9, 10.2))
	var stump_tip: Vector2 = join.lerp(mirror.call(Vector2(13.4, 8.6)), 0.55)
	var cbd_top: Vector2 = mirror.call(Vector2(11.0, 6.8))
	var cbd_bottom: Vector2 = mirror.call(Vector2(11.4, 12.6))
	var hole := cbd_top.lerp(cbd_bottom, 0.3)
	targets["liver"] = liver
	targets["duodenum"] = mirror.call(Vector2(9.0, 11.6))
	targets["bleeder"] = bed.lerp(liver, 0.4)
	match leak:
		"stump":
			targets["source"] = stump_tip
			targets["fix"] = stump_tip.lerp(join, 0.3)
			targets["cbd"] = cbd_top.lerp(cbd_bottom, 0.15)
		"bed":
			targets["source"] = bed + Vector2(0.0, 0.5)
			targets["fix"] = bed + Vector2(0.0, 0.5)
			targets["cbd"] = cbd_top.lerp(cbd_bottom, 0.5)
		_:
			targets["source"] = hole
			# The drain lies beside the duct, on the side away from the stump.
			targets["fix"] = hole + Vector2(-1.0 * flip, 0.3)
			targets["cbd"] = cbd_top.lerp(cbd_bottom, 0.85)
	var washed := "done:wash&!closing"
	parts.append_array([
		{"id": "scope", "kind": "scope", "at": centre + Vector2(0, 0.6), "size": Vector2(0.115, 0.0), "colour": Color("#0B0E10"), "show": "open&!closing"},
		{"id": "belly_wall", "kind": "disc", "at": centre + Vector2(0, 0.6), "size": Vector2(0.118, 0.1), "colour": Color("#B94F4A"), "show": "open&!closing", "lift": 0.004},
		{"id": "liver", "kind": "blob", "at": liver, "size": Vector2(0.062, 0.4), "colour": Color("#7A2A26"), "show": "open&!closing", "tap": true},
		{"id": "bed", "kind": "blob", "at": bed, "size": Vector2(0.02, 0.3), "colour": Color("#A8483F"), "show": "open&!closing", "lift": 0.016},
		{"id": "duodenum", "kind": "blob", "at": targets["duodenum"], "size": Vector2(0.032, 0.5), "colour": Color("#E39E95"), "show": "open&!closing", "tap": true},
		{"id": "cbd", "kind": "tube", "from": cbd_top, "to": cbd_bottom, "size": Vector2(0.0062, 0.0), "colour": Color("#B9C26A"),
			"show": "open&!closing", "tap_at": targets["cbd"], "lift": 0.014},
		{"id": "stump", "kind": "tube", "from": join, "to": stump_tip, "size": Vector2(0.0046, 0.0), "colour": Color("#D6DB8A"),
			"show": "open&!closing", "lift": 0.015},
		{"id": "clips_stump", "kind": "clips", "at": stump_tip.lerp(join, 0.15), "colour": Color("#D8DEE2"), "show": "open&!closing"},
		{"id": "loose_clip", "kind": "sliver", "at": stump_tip + Vector2(0.5 * flip, 0.4), "size": Vector2(0.012, 0.003),
			"colour": Color("#D8DEE2"), "show": washed + "&is:leak=stump"},
		{"id": "burn", "kind": "disc", "at": hole, "size": Vector2(0.008, 0.006), "colour": Color("#2E2A22"), "show": washed + "&is:leak=duct", "lift": 0.02},
		{"id": "bile", "kind": "disc", "at": centre + Vector2(0, 1.6), "size": Vector2(0.07, 0.05), "colour": Color("#4F6B22"),
			"show": "open&!done:wash&!closing", "lift": 0.022},
		{"id": "source", "kind": "blob", "at": targets["source"], "size": Vector2(0.006, 0.6), "colour": Color("#7FA63A"),
			"show": washed + "&!done:fix", "pulse": true, "lift": 0.022},
		{"id": "new_clips", "kind": "clips", "at": targets["fix"], "colour": Color("#F2F6F8"), "show": "done:fix&!is:leak=duct&!closing", "lift": 0.02},
		{"id": "drain", "kind": "tube", "from": targets["fix"], "to": targets["fix"] + Vector2(-1.6 * flip, 2.6), "size": Vector2(0.004, 0.0),
			"colour": Color("#F4F4EE"), "show": "done:fix&is:leak=duct&!closing", "lift": 0.02},
		{"id": "fix", "kind": "mark", "at": targets["fix"], "colour": Color("#FFFFFF"), "show": "step:fix", "tap": true},
		{"id": "ports", "kind": "ports", "colour": Color("#2B2F33"), "show": "done:ports", "points": ["port1", "port2", "port3"]},
		{"id": "port_marks", "kind": "marks", "colour": Color("#4B2F86"), "show": "!done:ports", "points": ["port1", "port2", "port3"]},
	])


# --- The incision line -------------------------------------------------------

func _build_guide() -> void:
	var shape: Array = procedure["guide"]
	var start: Vector2 = shape[0]
	var finish: Vector2 = shape[1]
	var bend: Vector2 = shape[2]
	var total := 0.0
	for index in GUIDE_SAMPLES + 1:
		var t := float(index) / GUIDE_SAMPLES
		_guide.append(start.lerp(finish, t) + bend * sin(PI * t))
	_lengths.append(0.0)
	for index in range(1, _guide.size()):
		total += _guide[index].distance_to(_guide[index - 1])
		_lengths.append(total)


## The incision line Dr. Iyer drew, in skin centimetres.
func guide() -> PackedVector2Array:
	return _guide


func guide_length() -> float:
	return _lengths[_lengths.size() - 1]


func guide_point(t: float) -> Vector2:
	var exact := clampf(t, 0.0, 1.0) * GUIDE_SAMPLES
	var index := mini(int(exact), GUIDE_SAMPLES - 1)
	return _guide[index].lerp(_guide[index + 1], exact - index)


func guide_direction(t: float) -> Vector2:
	var index := clampi(int(t * GUIDE_SAMPLES), 0, GUIDE_SAMPLES - 1)
	return (_guide[index + 1] - _guide[index]).normalized()


## [t along the guide, distance in cm] for the nearest point to a spot.
func guide_nearest(spot: Vector2) -> Array:
	var best_t := 0.0
	var best := INF
	for index in GUIDE_SAMPLES:
		var a := _guide[index]
		var b := _guide[index + 1]
		var closest := Geometry2D.get_closest_point_to_segment(spot, a, b)
		var distance := closest.distance_to(spot)
		if distance < best:
			best = distance
			best_t = (index + a.distance_to(closest) / maxf(0.0001, a.distance_to(b))) / GUIDE_SAMPLES
	return [best_t, best]


func _distance_along(t: float) -> float:
	var exact := clampf(t, 0.0, 1.0) * GUIDE_SAMPLES
	var index := mini(int(exact), GUIDE_SAMPLES - 1)
	return lerpf(_lengths[index], _lengths[index + 1], exact - index)


# --- Time ---------------------------------------------------------------------

func tick(delta: float) -> void:
	if finished:
		return
	super.tick(delta)
	if _drain > 0.0:
		_hurt(_drain * delta)
		if finished:
			return
	_update_vitals(delta)
	match phase:
		"beat":
			_beat_left -= delta
			if _beat_left <= 0.0:
				phase = ""
				var then := _after
				_after = Callable()
				if then.is_valid():
					then.call()
		"call":
			call_time += delta
			if call_time >= SLOW_CALL and not _slow_said:
				_slow_said = true
				slow_calls += 1
				_say_by(_scrub(), "Doctor? What do you need?", true)
			if call_time >= HAND_OVER:
				handed_over += 1
				_hand(wanted, "Here. You want the %s." % Instruments.name_of(wanted).to_lower())
		"act":
			if action == "hold" and holding:
				hold_time += delta
				if hold_time >= hold_needed():
					holding = false
					_act_done()
			elif action == "fill" and holding:
				fill_level = minf(FILL_MAX, fill_level + FILL_RATE * delta)
				hold_time = fill_level
				if fill_level >= FILL_MAX:
					hold_stop()


func _beat(seconds: float, then: Callable) -> void:
	phase = "beat"
	_beat_left = seconds
	_after = then


## True while the team is doing something and the doctor waits.
func busy() -> bool:
	return phase == "beat"


func _hurt(amount: float) -> void:
	if finished or amount <= 0.0:
		return
	stability = maxf(0.0, stability - amount)
	if stability <= TAKEOVER and not takeover:
		_take_over()


func _heal(amount: float) -> void:
	stability = minf(100.0, stability + amount)


# --- The time-out -------------------------------------------------------------

func _next_timeout_line() -> void:
	if timeout_index >= timeout_lines.size():
		_beat(BEAT, func() -> void:
			_say_by(_lead(), "Thank you. Everyone happy? Then we begin.")
			_beat(SHORT_BEAT, _start_step.bind(0)))
		return
	phase = "timeout"
	var line := timeout_lines[timeout_index]
	var lead := "Thank you, Doctor. " if timeout_index == 0 else ""
	_say_by(_scrub(), lead + str(line["said"]))


## The line on the board waiting for an answer, or {}.
func timeout_line() -> Dictionary:
	if phase != "timeout" or timeout_index >= timeout_lines.size():
		return {}
	return timeout_lines[timeout_index]


## The answers to a time-out line: confirm, stop, and (for things the doctor
## may not know, like allergies) unsure.
func timeout_choices() -> Array[String]:
	var line := timeout_line()
	if line.is_empty():
		return []
	if str(line.get("kind", "")) in ["allergy", "known"]:
		return ["confirm", "unsure", "stop"]
	return ["confirm", "stop"]


## Answers the time-out line on the board: "confirm", "stop" or "unsure".
func answer_timeout(choice: String) -> void:
	var line := timeout_line()
	if line.is_empty() or choice not in timeout_choices():
		return
	line["answer"] = choice
	var right := str(line["right"])
	match str(line.get("kind", "")):
		"side" when right == "stop":
			if choice == "stop":
				timeout_points += 1.0
				_say_by(_lead(), str(line["catch"]))
			else:
				wrong_side = true
				_say_by(_scrub(), str(line.get("confirmed", "%s Confirmed." % str(line["said"]).trim_prefix("Side: "))))
		"allergy" when not bool(line.get("allergic", true)):
			var asked := bool(setup.get(str(line.get("asked", "allergy_asked")), false))
			var drug := str(procedure["antibiotic"])
			if choice == "confirm":
				timeout_points += 1.0 if asked else 0.0
				_say_by(_anaesthetist(), ("No allergies, {he} told you {him}self. Starting the %s." if asked
					else "No allergies. Starting the %s.") % drug)
			elif choice == "unsure":
				timeout_points += 0.5 if asked else 1.0
				_say_by(_anaesthetist(), "You asked {him}, didn't you? Fine. I'll use one that's safe either way." if asked
					else "Nobody asked {him}? Then I'll use one that's safe either way.")
			else:
				timeout_points += 0.0 if asked else 0.5
				_say_by(_anaesthetist(), "Stop? {He} told you no allergies. Starting the %s." % drug if asked
					else "Stop? Then I'll use one that's safe either way.", asked)
		"allergy":
			var known := bool(setup.get(str(line.get("known", "allergy_known")), false))
			var drug := str(procedure["antibiotic"])
			if choice == "confirm":
				reaction_coming = true
				var first := steps[0]
				var list: Array = later.get(first, [])
				list.append("reaction")
				later[first] = list
				_say_by(_anaesthetist(), "No allergies. Starting the antibiotic, %s." % drug)
			elif choice == "stop" and known:
				timeout_points += 1.0
				_say_by(_anaesthetist(), "Penicillin? Then no %s. Swapping to one that's safe. Thank you." % drug)
			elif known:
				timeout_points += 0.5
				_say_by(_anaesthetist(), "Not sure? Then I'll use one that's safe either way.")
			else:
				timeout_points += 1.0
				_say_by(_anaesthetist(), "Nobody asked {him}? Then I'll use one that's safe either way.")
		"known":
			var knew := bool(setup.get(str(line["known"]), false))
			var who := str(line.get("speaker", "khan"))
			if choice == "confirm":
				_say_by(who, str(line["confirm"]))
				var effect := str(line.get("confirm_effect", ""))
				if not effect.is_empty() and knew:
					setup["confirmed_" + str(line["id"])] = true
			elif choice == "stop" and knew:
				timeout_points += 1.0
				_say_by(who, str(line["stop_known"]))
			elif knew:
				timeout_points += 0.5
				_say_by(who, str(line["unsure_known"]))
			else:
				timeout_points += 1.0
				_say_by(who, str(line["unsure"]))
		_:
			if choice == right:
				timeout_points += 1.0
				_say_by(_scrub(), "Good eyes. I'll fix the board." if right == "stop" else "Confirmed.")
			elif right == "stop":
				_say_by(_scrub(), "Confirmed.")
			else:
				_say_by(_scrub(), "It's right, Doctor. I checked it twice.", true)
	timeout_index += 1
	_beat(BEAT, _next_timeout_line)


func _side_line() -> Dictionary:
	for line in timeout_lines:
		if str(line.get("kind", "")) == "side":
			return line
	return {}


# --- Steps --------------------------------------------------------------------

func _start_step(index: int) -> void:
	step_index = index
	if index >= steps.size():
		_finish_operation()
		return
	step = steps[index]
	if step == _closing_step() and bool(procedure["count"]) and not counted:
		_start_count()
		return
	var data := _data(step)
	if index == 0 and wrong_side:
		wrong_side = false
		happened.append("wrong_side")
		var side := _side_line()
		_note(false, str(side.get("note", "The board had the wrong side and you confirmed it.")))
		_say_by(_lead(), str(side.get("stopped", "Wait. Wrong side. Read the notes, not the board.")), true)
		_beat(BEAT * 1.6, _begin_call.bind(_by_choice(data, "tool"), _call_line(data)))
		return
	if str(data.get("act", "")) == "decide":
		_begin_step_decision(data)
		return
	_begin_call(_by_choice(data, "tool"), _call_line(data))


## A step's call line, which can depend on what was decided before it.
func _call_line(data: Dictionary) -> String:
	return _by_choice(data, "call")


## A step's text (or tool) for key, or its "<key>_after" entry for an
## option chosen earlier ({"reclip": ...}), so a decision can change what
## the next step needs.
func _by_choice(data: Dictionary, key: String, fallback: String = "") -> String:
	var after: Dictionary = data.get(key + "_after", {})
	for option: String in after:
		if happened.has("chose_" + option):
			return str(after[option])
	return str(data.get(key, fallback))


func _begin_call(instrument: String, line: String, by: String = "") -> void:
	phase = "call"
	wanted = instrument
	call_time = 0.0
	wrong_this_call = 0
	_slow_said = false
	calls += 1
	var urgent := _is_complication(step) and str(_data(step).get("kind", "")) == "call"
	_say_by(by if not by.is_empty() else _lead(), line, urgent)


## Asks the scrub nurse for an instrument on the ring.
func call_for(instrument: String) -> void:
	if phase != "call" or finished:
		return
	if instrument == wanted:
		_hand(instrument, _hand_line(instrument))
		return
	# During some complications other instruments help but don't fix it.
	if _is_complication(step):
		var helps: Dictionary = _data(step).get("helps", {})
		if helps.has(instrument):
			if instrument == "swab":
				swabs_out += 1
				_complication_swabs += 1
			_say_by(_lead(), str(helps[instrument]), true)
			in_hand = instrument
			return
	wrong_calls += 1
	wrong_this_call += 1
	_hurt(1.5)
	if finished:
		return
	var picked_name := Instruments.name_of(instrument).to_lower()
	if wrong_this_call >= MAX_WRONG:
		handed_over += 1
		_hand(wanted, "Here. You want the %s." % Instruments.name_of(wanted).to_lower())
		return
	var lines := ["A %s? Are you sure, Doctor?" % picked_name, "That's a %s. Think about what she's doing." % picked_name]
	_say_by(_scrub(), str(lines[mini(wrong_this_call - 1, lines.size() - 1)]), true)


## True when a wrong instrument still helps (a swab on a bleed).
func helps_now(instrument: String) -> bool:
	return _is_complication(step) and (_data(step).get("helps", {}) as Dictionary).has(instrument)


func _hand_line(instrument: String) -> String:
	return str({
		"scalpel": "Scalpel.", "retractor": "Retractor.", "forceps": "Forceps.", "clamp": "Clamp.", "scissors": "Scissors.",
		"needle_holder": "Needle holder. Loaded.", "suction": "Suction.", "swab": "Swab.", "syringe": "Syringe. Loaded.",
		"port": "Port.", "camera": "Camera. Gas on.", "clip": "Clip applier. Loaded.", "hook": "Hook. Diathermy's on.",
		"mesh": "Mesh. Trimmed to size.", "wire": "Guide wire.", "drill": "Drill. Set to the wire.",
		"plate": "Screw and plate. Loaded.",
	}.get(instrument, Instruments.name_of(instrument) + "."))


func _hand(instrument: String, line: String) -> void:
	in_hand = instrument
	_say_by(_scrub(), line)
	_beat(SHORT_BEAT, _begin_act)


func _begin_act() -> void:
	phase = "act"
	hold_time = 0.0
	holding = false
	trace = PackedVector2Array()
	tracing = false
	sequence_index = 0
	var data := _data(step)
	action = str(data.get("act", ""))
	target = ""
	if data.has("sequence"):
		target = str((data["sequence"] as Array)[0])
	elif data.has("target"):
		target = str(data["target"])
	if action == "fill":
		fill_level = 0.0
	if data.has("start"):
		_say_by(_lead(), _by_choice(data, "start"), _is_complication(step) and action == "tap")


## Seconds a hold needs now.
func hold_needed() -> float:
	return float(_data(step).get("seconds", HOLD_TIME))


## The words on the hold button now.
func hold_label() -> String:
	return str(_data(step).get("hold_label", "Hold it open"))


## Starts tracing the cut at a spot on the skin.
func trace_begin(spot: Vector2) -> void:
	if phase != "act" or action != "trace":
		return
	tracing = true
	trace = PackedVector2Array([spot])
	changed.emit()


func trace_to(spot: Vector2) -> void:
	if not tracing:
		return
	if trace.is_empty() or trace[trace.size() - 1].distance_to(spot) >= 0.15:
		trace.append(spot)
		changed.emit()


## Lifts the scalpel: judges the cut, or asks for it again if it was short.
func trace_end() -> void:
	if not tracing:
		return
	tracing = false
	var covered := 0
	for point in _guide:
		if _distance_to_trace(point) <= TRACE_NEAR:
			covered += 1
	var coverage := float(covered) / _guide.size()
	if coverage < 0.6 or trace.size() < 3:
		trace_retries += 1
		_hurt(2.0)
		if not finished:
			_say_by(_lead(), "Too short. One stroke, the whole line, end to end.", true)
		trace = PackedVector2Array()
		return
	var deviation := 0.0
	for point in trace:
		deviation += float(guide_nearest(point)[1])
	deviation /= trace.size()
	trace_score = clampi(int(round(100.0 * coverage - 60.0 * maxf(0.0, deviation - 0.25))), 0, 100)
	trace_score = maxi(0, trace_score - 8 * trace_retries)
	_hurt((100.0 - trace_score) / 10.0)
	if finished:
		return
	if trace_score >= 85:
		_say_by(_lead(), "Clean edge. Nice.")
	elif trace_score >= 60:
		_say_by(_lead(), "A bit wobbly. It'll heal.")
	else:
		_say_by(_lead(), "That's ragged. Skin remembers. Smoother next time.", true)
	_act_done()


func _distance_to_trace(point: Vector2) -> float:
	var best := INF
	for index in range(trace.size() - 1):
		var closest := Geometry2D.get_closest_point_to_segment(point, trace[index], trace[index + 1])
		best = minf(best, closest.distance_to(point))
	if trace.size() == 1:
		best = trace[0].distance_to(point)
	return best


## Holding (the wound open, the suction on, the gas flowing).
func hold_start() -> void:
	if phase != "act" or action not in ["hold", "fill"]:
		return
	holding = true
	changed.emit()


func hold_stop() -> void:
	if not holding:
		return
	holding = false
	if action == "fill":
		_judge_fill()
		return
	if hold_time < hold_needed():
		hold_restarts += 1
		hold_time = 0.0
		_hurt(2.0)
		if not finished:
			_say_by(_lead(), str(_data(step).get("let_go", "Don't let go! I need it open the whole time.")), true)


## Letting go of the gas: too little means fill more, too much hurts and
## brings the pressure down later.
func _judge_fill() -> void:
	var data := _data(step)
	fill_tries += 1
	if fill_level < FILL_LOW:
		_say_by(_lead(), str(data.get("low", "Not enough. Fill it more.")), true)
		return
	if fill_level > FILL_HIGH:
		overfilled = true
		_hurt(4.0)
		if finished:
			return
		var list: Array = later.get(step, [])
		if not list.has("gas"):
			list.push_front("gas")
		later[step] = list
		_say_by(_anaesthetist(), str(data.get("over", "Too much!")), true)
		fill_level = 14.0
		_beat(SHORT_BEAT, _act_done)
		return
	_say_by(_lead(), str(data.get("good", "Good.")))
	_act_done()


## Taps something: a target inside, a port mark, a swab in the search.
func tap(spot: String) -> void:
	if finished:
		return
	if phase == "search":
		if spot == "swab":
			swab_found = true
			swabs_back = swabs_out
			counted = true
			_say_by(_scrub(), "There it is. %d out, %d back. Count's right." % [swabs_out, swabs_back])
			_beat(BEAT, _start_step.bind(steps.find(_closing_step())))
		else:
			tap_misses += 1
			_say_by(_lead(), "Not there. Look in the corners, under the edges.", true)
		return
	if phase != "act" or action != "tap":
		return
	var data := _data(step)
	if spot == target:
		if data.has("sequence"):
			var hits: Array = data.get("hits", [])
			var sequence: Array = data["sequence"]
			sequence_index += 1
			_say_by(_lead(), str(hits[mini(sequence_index - 1, hits.size() - 1)]) if not hits.is_empty() else "Good.")
			if sequence_index < sequence.size():
				target = str(sequence[sequence_index])
				return
		elif data.has("hit"):
			_say_by(_lead(), _by_choice(data, "hit"))
		_act_done()
		return
	tap_misses += 1
	var traps: Dictionary = data.get("traps", {})
	_hurt(float(traps.get(spot, 2.0)))
	var notes: Dictionary = data.get("trap_notes", {})
	if notes.has(spot) and not happened.has("trap_" + spot):
		happened.append("trap_" + spot)
	if finished:
		return
	var lines: Dictionary = data.get("trap_lines", {})
	_say_by(_lead(), str(lines.get(spot, data.get("miss", "Not there."))), true)


## A stitch across the incision at a spot on the skin.
func place_stitch(spot: Vector2) -> bool:
	if phase != "act" or action != "stitch" or stitches.size() >= MAX_STITCHES:
		return false
	var found := guide_nearest(spot)
	if float(found[1]) > STITCH_MISS:
		stitch_misses += 1
		_say_by(_lead(), "Across the cut, not beside it.", true)
		return false
	stitches.append({"t": float(found[0]), "off": float(found[1])})
	stitches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	_say_by(_lead(), "%d." % stitches.size() if stitches.size() < stitch_target() else "That'll hold. Tie it off.")
	changed.emit()
	return true


func tie_off() -> void:
	if phase != "act" or action != "stitch" or stitches.is_empty():
		return
	_act_done()


func _act_done() -> void:
	done_steps.append(step)
	in_hand = ""
	if _is_complication(step):
		_resolve_complication()
		return
	if bool(_data(step).get("swab", false)):
		swabs_out += 1
	if step == _closing_step():
		_finish_operation()
		return
	_queue.assign(later.get(step, []))
	later.erase(step)
	_beat(BEAT, _next_after_step)


func _next_after_step() -> void:
	if not _queue.is_empty():
		_start_complication(_queue.pop_front())
		return
	_start_step(step_index + 1)


# --- Reading something and deciding (the trapped bowel) -----------------------

func _begin_step_decision(data: Dictionary) -> void:
	var key := str(data.get("variant", ""))
	var kind := str(variants.get(key, ""))
	var looks: Dictionary = (procedure.get("variants", {}) as Dictionary).get(key, {}).get(kind, {})
	var decision: Dictionary = (procedure.get("decisions", {}) as Dictionary).get(step, {})
	options.assign(decision.get("options", []))
	calls += 0
	phase = "decide"
	_say_by(_lead(), "%s %s" % [_call_line(data), str(looks.get("say", ""))])


## What the doctor sees while deciding a step (the bowel's colour...), or "".
func decision_look() -> String:
	var data := _data(step)
	if str(data.get("act", "")) != "decide":
		return ""
	var key := str(data.get("variant", ""))
	var kind := str(variants.get(key, ""))
	return str((procedure.get("variants", {}) as Dictionary).get(key, {}).get(kind, {}).get("look", ""))


func _decide_step(option: String) -> void:
	var data := _data(step)
	var key := str(data.get("variant", ""))
	var kind := str(variants.get(key, ""))
	var looks: Dictionary = (procedure["variants"] as Dictionary)[key][kind]
	var decision: Dictionary = (procedure.get("decisions", {}) as Dictionary).get(step, {})
	if option == str(looks["right"]):
		if not step_decisions.has(step):
			step_decisions[step] = true
		happened.append("chose_" + option)
		_say_by(_lead(), str((decision.get("right_lines", {}) as Dictionary).get(option, "Agreed.")))
		if looks.has("after"):
			variants[key] = str(looks["after"])
		if option == "resect":
			_hurt(4.0)
		done_steps.append(step)
		options.clear()
		_beat(BEAT * 1.6, _next_after_decision)
		return
	step_decisions[step] = false
	decisions_wrong += 1
	var wrong: Array = (decision.get("wrong_lines", {}) as Dictionary).get("%s:%s" % [kind, option], [8.0, "No. Look again."])
	_hurt(float(wrong[0]))
	if not finished:
		_say_by(_lead(), str(wrong[1]), true)


func _next_after_decision() -> void:
	_queue.assign(later.get(step, []))
	later.erase(step)
	_next_after_step()


# --- Complications ------------------------------------------------------------

func _start_complication(which: String) -> void:
	step = which
	active_complication = which
	happened.append(which)
	_set_vital_goal()
	var data := _data(which)
	_drain = float(data.get("drain", 2.0)) * float(DRAIN_SCALE.get(difficulty, 1.0))
	if str(data.get("kind", "")) == "call":
		_begin_call(str(data["tool"]), _fill(str(data["call"])))
		return
	phase = "decide"
	options.clear()
	for option: Dictionary in data.get("options", []):
		options.append({"id": option["id"], "text": _fill(str(option["text"]))})
	_say_by(str(data.get("speaker", "khan")), _fill_vitals(str(data["line"])), true)


func _fill_vitals(line: String) -> String:
	return line.replace("{bp}", _bp_words()).replace("{hr}", str(vitals.hr))


func _bp_words() -> String:
	return "%d over %d" % [vitals.systolic, vitals.diastolic]


## The right answer to the decision on show.
func right_option() -> String:
	if phase == "decide" and not _is_complication(step):
		var data := _data(step)
		var key := str(data.get("variant", ""))
		return str((procedure["variants"] as Dictionary)[key][str(variants[key])]["right"])
	return str(_data(step).get("right", ""))


## Wrong answers a careless robot picks for the decision on show.
func wrong_options() -> Array:
	if _is_complication(step):
		return _data(step).get("bot_wrong", [])
	var right := right_option()
	var found := []
	for option in options:
		if str(option["id"]) != right:
			found.append(str(option["id"]))
	return found


## Picks one of the decision's options.
func decide(option: String) -> void:
	if phase != "decide" or finished:
		return
	if not _is_complication(step):
		_decide_step(option)
		return
	var data := _data(step)
	if option == right_option():
		_say_by(str(data.get("speaker", "khan")), _fill(str(data["fixed"])))
		done_steps.append(step)
		_resolve_complication()
		return
	decisions_wrong += 1
	var wrong: Array = (data.get("wrong", {}) as Dictionary).get(option, data.get("wrong_default", [12.0, "Decide!"]))
	_hurt(float(wrong[0]))
	if not finished:
		_say_by(str(data.get("speaker", "khan")), _fill(str(wrong[1])), true)


func _resolve_complication() -> void:
	var data := _data(step)
	_drain = 0.0
	active_complication = ""
	_set_vital_goal()
	_heal(6.0)
	var extra := int(data.get("swabs", 0))
	swabs_out += extra
	_complication_swabs += extra
	if str(data.get("kind", "")) == "call":
		_say_by(_lead(), _fill(str(data.get("fixed", ""))))
	in_hand = ""
	_beat(BEAT * 1.2, _next_after_step)


# --- The count ----------------------------------------------------------------

func _start_count() -> void:
	step = "count"
	phase = "count"
	match int(setup["lose_swab"]):
		1:
			swab_missing = true
		0:
			swab_missing = false
		_:
			swab_missing = _complication_swabs > 0 and _rng.chance(0.5)
	swabs_back = swabs_out - (1 if swab_missing else 0)
	options = [
		{"id": "close", "text": "Count's right. Close."},
		{"id": "recount", "text": "Count again"},
		{"id": "look", "text": "Look in the wound"},
	]
	if procedure.has("count_line") and not swab_missing:
		_say_by(_scrub(), str(procedure["count_line"]))
	else:
		_say_by(_scrub(), "Count before closing. Swabs: %d out, %d back. Instruments: all eight." % [swabs_out, swabs_back])


## Answers the count: "close", "recount" or "look".
func count(choice: String) -> void:
	if phase != "count" or finished:
		return
	var missing := swab_missing and not swab_found
	match choice:
		"close":
			if missing:
				closed_on_bad_count = true
				_say_by(_scrub(), "Doctor, the count is wrong. I'm not handing you a needle.", true)
				_beat(BEAT, func() -> void:
					_say_by(_lead(), "Nobody closes on a wrong count. Ever. Look in the wound.", true)
					phase = "search")
				return
			swabs_back = swabs_out
			counted = true
			_say_by(_scrub(), "Count's right. Needle holder coming.")
			_beat(SHORT_BEAT, _start_step.bind(steps.find(_closing_step())))
		"recount":
			recounts += 1
			if missing:
				_say_by(_scrub(), "Again... %d out, %d back. One's missing. It's somewhere." % [swabs_out, swabs_back], true)
			else:
				_say_by(_scrub(), "Same numbers. It's right, Doctor.")
		"look":
			if missing:
				phase = "search"
				_say_by(_lead(), "Good. Look carefully. Swabs soak up blood and hide.")
			else:
				recounts += 1
				_say_by(_lead(), "Nothing in there but {name}. The count was right.")


# --- Hints ----------------------------------------------------------------------

## True when the doctor can ask for a hint now (hard cases only).
func can_hint() -> bool:
	return difficulty == "hard" and not finished and phase in ["call", "act", "decide"] and _hinted != _hint_key()


## The hint for what is happening now, or "".
func hint_text() -> String:
	if phase == "call":
		var data := _data(step)
		var tool := _by_choice(data, "tool")
		var hint := _by_choice(data, "hint")
		if _is_complication(step) or hint.is_empty():
			return "You need the %s: %s." % [Instruments.name_of(tool).to_lower(), Instruments.job_of(tool).to_lower()]
		return hint
	if phase in ["act", "decide"]:
		return _fill(_by_choice(_data(step), "hint"))
	return ""


## Asks for a hint: the lead surgeon says it, and it costs points.
func use_hint() -> String:
	if not can_hint():
		return ""
	hints_used += 1
	_hinted = _hint_key()
	var text := hint_text()
	_say_by(_lead(), text)
	return text


func _hint_key() -> String:
	return "%s:%s:%d" % [phase, step, calls]


# --- The end ------------------------------------------------------------------

func _take_over() -> void:
	takeover = true
	_drain = 0.0
	in_hand = ""
	phase = "done"
	speaker = _lead()
	coach = "My hands. Step back. Now."
	coach_warns = true
	_finish_operation()


func _finish_operation() -> void:
	if finished:
		return
	phase = "done"
	outcome = _outcome()
	_write_notes()
	if not takeover:
		_say_by(_lead(), str((procedure["end_lines"] as Dictionary)[outcome]))
	_finish()


func _outcome() -> String:
	if takeover:
		return "failed"
	if score() >= 75 and stability >= 60.0:
		return "won"
	return "struggled"


## 0 to 100: how well the doctor worked with the scrub nurse.
func teamwork() -> int:
	var points := 100 - 8 * wrong_calls - 5 * slow_calls - 12 * handed_over - 5 * recounts
	if closed_on_bad_count:
		points -= 20
	if "wrong_side" in happened:
		points -= 10
	return clampi(points, 0, 100)


## 0 to 100: the cut, the hold, the taps, the decisions and the stitches.
func technique() -> int:
	var parts_scored: Array[float] = []
	if trace_score >= 0:
		parts_scored.append(trace_score)
	for entry: Dictionary in procedure["steps"]:
		if str(entry.get("act", "")) == "hold" and str(entry["id"]) in done_steps:
			parts_scored.append(maxf(0.0, 100.0 - 20.0 * hold_restarts))
			break
	if fill_tries > 0:
		parts_scored.append(100.0 if not overfilled and fill_tries == 1 else (40.0 if overfilled else 75.0))
	parts_scored.append(maxf(0.0, 100.0 - 15.0 * tap_misses))
	var decided := decisions_wrong > 0 or not step_decisions.is_empty()
	for which in happened:
		if str(Procedures.COMPLICATIONS.get(which, {}).get("kind", "")) == "decide":
			decided = true
	if decided:
		parts_scored.append(maxf(0.0, 100.0 - 35.0 * decisions_wrong))
	if _closing_step() in done_steps and not takeover:
		parts_scored.append(_stitch_score())
	var total := 0.0
	for part in parts_scored:
		total += part
	return int(round(total / parts_scored.size()))


## 0 to 100: the scrub, the time-out and the count.
func safety() -> int:
	var points := 0.5 * float(setup["scrub"]) + 50.0 * timeout_points / timeout_lines.size()
	if closed_on_bad_count:
		points -= 30.0
	for which in happened:
		if which.begins_with("trap_"):
			points -= 12.0
	return clampi(int(round(points)), 0, 100)


func score() -> int:
	var points := int(round(0.3 * stability + 0.25 * teamwork() + 0.3 * technique() + 0.15 * safety()))
	points -= HINT_COST * hints_used
	if takeover:
		points = mini(points, 39)
	return clampi(points, 0, 100)


func _stitch_score() -> int:
	if stitches.is_empty():
		return 0
	var off := 0.0
	for stitch in stitches:
		off += float(stitch["off"])
	off /= stitches.size()
	var accuracy := 1.0 - clampf((off - 0.15) / 0.6, 0.0, 1.0)
	var count_part := clampf(float(stitches.size()) / stitch_target(), 0.0, 1.0)
	var gaps: Array[float] = []
	for index in range(1, stitches.size()):
		gaps.append(_distance_along(float(stitches[index]["t"])) - _distance_along(float(stitches[index - 1]["t"])))
	var evenness := 0.5
	if gaps.size() >= 2:
		var mean := 0.0
		for gap in gaps:
			mean += gap
		mean /= gaps.size()
		var spread := 0.0
		for gap in gaps:
			spread += (gap - mean) * (gap - mean)
		spread = sqrt(spread / gaps.size()) / maxf(0.0001, mean)
		evenness = 1.0 - clampf((spread - 0.15) / 0.5, 0.0, 1.0)
	elif gaps.size() < 1 and stitch_target() <= 2:
		evenness = 1.0
	var ends := 1.0
	var reach := minf(1.2, guide_length() * 0.3)
	if _distance_along(float(stitches[0]["t"])) > reach:
		ends -= 0.5
	if guide_length() - _distance_along(float(stitches[stitches.size() - 1]["t"])) > reach:
		ends -= 0.5
	var points := 100.0 * (0.3 * accuracy + 0.3 * count_part + 0.25 * evenness + 0.15 * ends) - 5.0 * stitch_misses
	return clampi(int(round(points)), 0, 100)


## Stitches a closing needs: six for a full cut, fewer for a short one.
func stitch_target() -> int:
	if guide_length() >= 4.0:
		return STITCH_TARGET
	return clampi(int(round(guide_length() / 0.7)), 2, STITCH_TARGET)


func _write_notes() -> void:
	if takeover:
		_note(false, _fill("{Name} got too unstable and %s had to take over. %s" % [lead_name(), _takeover_reason()]))
	var allergy_line := {}
	for line in timeout_lines:
		if str(line.get("kind", "")) == "allergy":
			allergy_line = line
	if "reaction" in happened:
		_note(false, _fill("{He} reacted to the antibiotic. %s" % ("You knew about the penicillin and still confirmed \"none known\"."
			if bool(setup["allergy_known"]) else "Nobody had asked {him} about allergies, and the time-out confirmed \"none known\".")))
	elif bool(setup["allergy_known"]) and not allergy_line.is_empty():
		_note(true, "You asked about allergies before, and stopped the wrong antibiotic at the time-out.")
	for which in happened:
		var own: Dictionary = procedure.get("notes", {})
		if own.has(which):
			_note(false, _fill(str(own[which])))
	for line in timeout_lines:
		var kind := str(line.get("kind", ""))
		var answer := str(line.get("answer", ""))
		if kind == "side" and str(line["right"]) == "stop" and "wrong_side" not in happened and answer == "stop":
			_note(true, str(line.get("note_caught", "You caught the wrong side on the board at the time-out.")))
		elif kind == "known":
			var knew := bool(setup.get(str(line["known"]), false))
			if answer == "confirm":
				_note(false, str(line["note_confirm_known"] if knew else line["note_confirm"]))
			elif knew and answer == "stop":
				_note(true, str(line["note_known"]))
		elif kind == "allergy" and not bool(line.get("allergic", true)):
			if answer == "confirm" and str(line["right"]) != "confirm":
				_note(false, _fill("You confirmed \"none known\" without ever asking {him}. {He} wasn't allergic. This time."))
			elif answer == "confirm":
				_note(true, "You'd asked about allergies, so you could confirm the board.")
		elif kind.is_empty() and str(line["right"]) == "stop":
			if answer == "confirm":
				_note(false, str(line.get("wrong_note", "The board had a mistake on it and you confirmed it.")))
			elif answer == "stop":
				_note(true, "You caught the mistake on the time-out board.")
	for which in happened:
		if which.begins_with("trap_"):
			for entry: Dictionary in procedure["steps"]:
				var trap_notes: Dictionary = entry.get("trap_notes", {})
				if trap_notes.has(which.trim_prefix("trap_")):
					_note(false, str(trap_notes[which.trim_prefix("trap_")]))
					break
	if closed_on_bad_count:
		_note(false, "You tried to close with a swab missing. A swab left inside means a second operation.")
	elif swab_found:
		_note(true, "The count was off and you found the missing swab before closing.")
	if wrong_calls == 0 and handed_over == 0 and slow_calls == 0:
		_note(true, "Every instrument called right and on time. %s never had to guess." % scrub_name())
	else:
		_note(false, "%d wrong call%s and %d slow. Each one costs seconds and %s's trust." %
			[wrong_calls, "" if wrong_calls == 1 else "s", slow_calls + handed_over, scrub_name()])
	for which: String in step_decisions:
		var decision: Dictionary = (procedure.get("decisions", {}) as Dictionary).get(which, {})
		var said: Dictionary = decision.get("notes", {})
		if bool(step_decisions[which]):
			_note(true, str(said.get("right", "You read it right.")))
		else:
			_note(false, str(said.get("wrong", "You misread it.")))
	var decide_names: Array[String] = []
	for which in happened:
		var data: Dictionary = Procedures.COMPLICATIONS.get(which, {})
		if str(data.get("kind", "")) == "decide":
			decide_names.append(_fill(str(data.get("note_wrong", which))))
	var complication_wrong := decisions_wrong - step_decisions.values().count(false)
	if complication_wrong > 0 and not decide_names.is_empty():
		_note(false, "A wrong decision during the %s. Read the monitor, then act on what it says." % decide_names[0])
	elif not decide_names.is_empty():
		_note(true, "You read %s's call right and acted at once." % anaesthetist_name())
	if overfilled:
		_note(false, "You filled the belly past 15. Too much gas squeezes the big veins and drops the pressure.")
	elif fill_tries == 1:
		_note(true, "You filled to working pressure first time.")
	if trace_score >= 85:
		_note(true, "A clean, even incision along the line.")
	elif trace_score >= 0:
		_note(false, "The incision wandered off the line. A wobbly cut heals into a wider scar.")
	if float(setup["scrub"]) < 65:
		_note(false, "A rushed scrub raises the risk of infection afterwards.")
	if hints_used > 0:
		_note(false, "%d hint%s used. Each one cost %d points." % [hints_used, "" if hints_used == 1 else "s", HINT_COST])
	if difficulty == "extreme" and not takeover:
		_note(true, "An extreme case: two problems at once, and you got through it.")


func _takeover_reason() -> String:
	for which in happened:
		var data := _data(which) if _is_complication(which) else {}
		if data.has("note_failed") and which not in done_steps:
			return _fill(str(data["note_failed"]))
	return "Too many things went wrong at once."


func instruction() -> String:
	match phase:
		"timeout":
			return "Time-out: check the board. Confirm it, or stop the team"
		"call":
			return "Call for what %s needs on the ring" % lead_name()
		"act":
			match action:
				"trace", "hold", "tap":
					var data := _data(step)
					if data.has("sequence"):
						return "%s: %d of %d" % [str(data.get("instruction", "Tap the marks")), sequence_index,
							(data["sequence"] as Array).size()]
					return _by_choice(data, "instruction", "Tap it")
				"fill":
					return "%s · gas %d" % [str(_data(step).get("instruction", "Hold to fill")), int(fill_level)]
				"stitch":
					return "Tap across the cut to stitch: %d placed" % stitches.size()
		"decide":
			if not _is_complication(step):
				return str(_data(step).get("instruction", "Decide"))
			return "Read the monitor. Then decide"
		"count":
			return "Check %s's count before closing" % scrub_name()
		"search":
			return "Find the missing swab in the wound"
		"done":
			return "%s has taken over" % lead_name() if takeover else "Done"
	return ""


func progress() -> float:
	if finished:
		return 1.0
	var total := steps.size() + 1.0
	if step == "timeout":
		return 0.12 * timeout_index / timeout_lines.size()
	return clampf((maxi(0, step_index) + 1.0) / total, 0.0, 1.0)


## True when a condition about the operation holds, for the table to know
## what to show: "open", "closing", "done:x", "step:x", "comp:x", "had:x",
## "phase:x", "is:key=kind" (a rolled version), each can start with "!"
## and several join with "&".
func condition_met(condition: String) -> bool:
	if condition.is_empty():
		return true
	for part in condition.split("&"):
		var negate := part.begins_with("!")
		var test := part.trim_prefix("!")
		var value := false
		var bits := test.split(":")
		match bits[0]:
			"open":
				value = is_open()
			"closing":
				value = is_closing()
			"done":
				value = bits[1] in done_steps
			"step":
				value = step == bits[1]
			"comp":
				value = active_complication == bits[1]
			"had":
				value = bits[1] in happened
			"phase":
				value = phase == bits[1]
			"is":
				# A version rolled for a step that reads something: "is:film=lined".
				var pair := bits[1].split("=")
				value = str(variants.get(pair[0], "")) == pair[1]
		if value == negate:
			return false
	return true


## True once the operation has opened up what is inside.
func is_open() -> bool:
	var opens := str(procedure["opens"])
	if opens.is_empty():
		return true
	if opens in done_steps:
		return true
	if step == opens and phase == "act":
		return (action == "hold" and holding) or (action == "fill" and fill_level >= FILL_LOW)
	return false


## True from the count or the closing on.
func is_closing() -> bool:
	var closing := _closing_step()
	return step == closing or closing in done_steps


# --- Vitals -------------------------------------------------------------------

func _set_vital_goal() -> void:
	var goal := {"hr": 82.0, "sys": 118.0, "dia": 74.0, "spo2": 99.0, "rr": 14.0}
	if bool(procedure.get("awake", false)):
		goal["hr"] = 88.0
		goal["rr"] = 16.0
	if bool(setup.get("delayed", false)) and procedure.has("delayed"):
		goal["hr"] = 96.0
	if not active_complication.is_empty():
		var data := _data(active_complication)
		if data.has("vitals"):
			goal = (data["vitals"] as Dictionary).duplicate()
	_vital_goal = goal


func _snap_vitals() -> void:
	_vital_now = _vital_goal.duplicate()
	_show_vitals()


func _update_vitals(delta: float) -> void:
	# Low stability shows too: a faster heart and a softer pressure.
	var strain := clampf((70.0 - stability) / 50.0, 0.0, 1.0)
	var bend := {"hr": 20.0 * strain, "sys": -14.0 * strain, "dia": -8.0 * strain, "spo2": 0.0, "rr": 0.0}
	if active_complication == "faint":
		bend["hr"] = -bend["hr"]
	var weight := minf(1.0, delta * 1.2)
	for key: String in _vital_goal:
		_vital_now[key] = lerpf(float(_vital_now.get(key, 0.0)), float(_vital_goal[key]) + float(bend[key]), weight)
	_show_vitals()


func _show_vitals() -> void:
	vitals.hr = int(round(float(_vital_now["hr"])))
	vitals.systolic = int(round(float(_vital_now["sys"])))
	vitals.diastolic = int(round(float(_vital_now["dia"])))
	vitals.spo2 = int(round(float(_vital_now["spo2"])))
	vitals.rr = int(round(float(_vital_now["rr"])))


## A word for the monitor: how the patient is doing.
func condition() -> String:
	if takeover:
		return "%s HAS TAKEN OVER" % lead_name().to_upper()
	if not active_complication.is_empty():
		return str(_data(active_complication).get("condition", active_complication.to_upper()))
	if stability >= 70.0:
		return "STABLE"
	if stability >= 40.0:
		return "UNSTEADY"
	return "CRITICAL"


## Puts the patient's name and pronouns into a line.
func _fill(line: String) -> String:
	var she := str(procedure.get("pronoun", "he")) == "she"
	var words := {
		"{name}": patient_first(), "{Name}": patient_first(),
		"{he}": "she" if she else "he", "{He}": "She" if she else "He",
		"{his}": "her" if she else "his", "{His}": "Her" if she else "His",
		"{him}": "her" if she else "him", "{Him}": "Her" if she else "Him",
	}
	var made := line
	for key: String in words:
		made = made.replace(key, str(words[key]))
	return made


func _say_by(who: String, line: String, warns: bool = false) -> void:
	# With no anaesthetist in the room (an awake patient in the minor
	# theatre), the lead surgeon watches the monitor and says it instead.
	if who == "khan" and str(setup.get("anaesthetist", "khan")).is_empty():
		who = _lead()
	speaker = who
	_say(_fill(line).replace("{called}", str(setup.get("called", "Doctor"))), warns)
