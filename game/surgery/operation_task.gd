class_name OperationTask
extends TrainingTask
## Rohit's appendectomy, the first real operation: the rules, the patient's
## condition, the team's lines and the score, with no visuals.
##
## It chains the training skills: a time-out (reading what is in front of
## you), instrument calls to Tom on the ring, tracing the cut, holding the
## wound open, finding things inside, reading the monitor when Dr. Khan
## calls a problem, the swab count and the stitches. What happened before
## the operation comes in as setup: whether the player asked about
## allergies, whether the operation was put off, how well they scrubbed.
##
## Rohit's condition ("stability", 0 to 100) drops with mistakes and while a
## complication goes untreated. At 20 Dr. Iyer takes over. Time passes only
## through tick(), so tests can play an operation start to finish.
##
## Positions on the skin are in centimetres: x along the body towards the
## feet, y across it towards the player, inside a window of SKIN.

## The steps of the operation, in order.
const STEPS := ["incision", "retract", "find", "clamp", "cut", "close"]
## The instrument each step needs.
const TOOLS := {
	"incision": "scalpel",
	"retract": "retractor",
	"find": "forceps",
	"clamp": "clamp",
	"cut": "scissors",
	"close": "needle_holder",
}
const STEP_TITLES := {
	"incision": "Open the skin",
	"retract": "Hold it open",
	"find": "Find the appendix",
	"clamp": "Clamp the base",
	"cut": "Cut it free",
	"close": "Close the skin",
	"bleeding": "Stop the bleeding",
	"burst": "Wash it out",
	"pressure": "Pressure falling",
	"reaction": "Allergic reaction",
	"count": "The count",
	"timeout": "Time-out",
}
## What Dr. Iyer says when a step needs its instrument.
const CALL_LINES := {
	"incision": "Small cut, low on the right, along the line I drew. Your hands. Ask Tom for what you need.",
	"retract": "Good. Now I need to see inside. Hold the edges apart for me.",
	"find": "Find the appendix. Follow the big bowel down to where it ends. Gently.",
	"clamp": "There it is. Close off its base, where it joins the bowel.",
	"cut": "Tied. Now cut it free, just above the clamp.",
	"close": "It's out. Now close the skin. Neat stitches, end to end.",
	"bleeding": "Bleeder! It's pumping. Stop it, quickly!",
	"burst": "It's burst. Pus everywhere. We need to clear this out before anything else.",
}
## What Tom says as he hands each instrument over.
const HAND_LINES := {
	"scalpel": "Scalpel.",
	"retractor": "Retractor.",
	"forceps": "Forceps.",
	"clamp": "Clamp.",
	"scissors": "Scissors.",
	"needle_holder": "Needle holder. Loaded.",
	"suction": "Suction.",
	"swab": "Swab.",
}
## The time-out board. "right" is the correct answer: "confirm" or "stop"
## ("allergy" depends on what the player found out before).
const TIMEOUT := [
	{"id": "patient", "label": "Patient", "reads": "Rohit Kulkarni, 19", "said": "Patient: Rohit Kulkarni, nineteen.", "right": "confirm"},
	{"id": "procedure", "label": "Operation", "reads": "Appendix removal", "said": "Operation: removal of the appendix.", "right": "confirm"},
	{"id": "side", "label": "Side", "reads": "LEFT lower belly", "said": "Side: left lower belly.", "right": "stop"},
	{"id": "allergy", "label": "Allergies", "reads": "None known", "said": "Allergies: none known.", "right": "allergy"},
]
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
## Swabs Dr. Iyer uses in a plain operation.
const BASE_SWABS := 3
const SWAB_BASE_COUNT := 10

## What happened before: allergy_known, delayed, scrub (0 to 100),
## complication ("" to roll, or bleeding/pressure), lose_swab (-1 roll, 0, 1).
var setup := {}
## "timeout", "beat", "call", "act", "decide", "count", "search", "done".
var phase := "timeout"
## The step or complication under way (a key of STEP_TITLES).
var step := "timeout"
var step_index := -1
## The instrument wanted in a call.
var wanted := ""
## In "act": "trace", "hold", "tap" or "stitch". target is what a tap wants.
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
var trace: PackedVector2Array = PackedVector2Array()
var tracing := false
var stitches: Array[Dictionary] = []
## Steps done so far (and complications handled), for the 3D view.
var done_steps: Array[String] = []
## Complications still to come, by the step they follow.
var later := {}
## Complications that happened.
var happened: Array[String] = []
var active_complication := ""
var swabs_out := 0
var swabs_back := 0
var swab_missing := false
var swab_found := false
var takeover := false
var outcome := ""
var wrong_side := false
var reaction_coming := false
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


func _init(with_seed: int = 1, with_setup: Dictionary = {}) -> void:
	id = "appendix"
	_rng = SeededRandom.new(with_seed)
	setup = {"allergy_known": false, "delayed": false, "scrub": 100, "complication": "", "lose_swab": -1, "called": "Doctor"}
	setup.merge(with_setup, true)
	stability = 90.0 if bool(setup["delayed"]) else 100.0
	_build_guide()
	for line: Dictionary in TIMEOUT:
		var copy := line.duplicate()
		if str(copy["right"]) == "allergy":
			copy["right"] = "stop" if bool(setup["allergy_known"]) else "unsure"
		timeout_lines.append(copy)
	if bool(setup["delayed"]):
		later["find"] = ["burst"]
	else:
		var pick := str(setup["complication"])
		if pick not in ["bleeding", "pressure"]:
			pick = str(_rng.pick(["bleeding", "pressure"]))
		later["find"] = [pick]
	_set_vital_goal()
	_snap_vitals()
	phase = "timeout"
	step = "timeout"
	_say_by("iyer", "Time-out. Everyone stops. Tom, read it out. {called}, check every line.")
	_next_timeout_line()


static func title_of_step(which: String) -> String:
	return str(STEP_TITLES.get(which, which.capitalize()))


func title() -> String:
	return "Appendectomy"


# --- The incision line -------------------------------------------------------

func _build_guide() -> void:
	# A short oblique cut over the appendix, low on the right side of the belly.
	var start := Vector2(14.6, 7.3)
	var finish := Vector2(11.4, 11.7)
	var bend := Vector2(0.35, 0.25)
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
				_say_by("tom", "Doctor? What do you need?", true)
			if call_time >= HAND_OVER:
				handed_over += 1
				_hand(wanted, "Here. You want the %s." % Instruments.name_of(wanted).to_lower())
		"act":
			if action == "hold" and holding:
				hold_time += delta
				var needed := WASH_TIME if step == "burst" else HOLD_TIME
				if hold_time >= needed:
					holding = false
					_act_done()


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
			_say_by("iyer", "Thank you. Everyone happy? Then we begin.")
			_beat(SHORT_BEAT, _start_step.bind(0)))
		return
	phase = "timeout"
	var line := timeout_lines[timeout_index]
	var lead := "Thank you, Doctor. " if timeout_index == 0 else ""
	_say_by("tom", lead + str(line["said"]))


## The line on the board waiting for an answer, or {}.
func timeout_line() -> Dictionary:
	if phase != "timeout" or timeout_index >= timeout_lines.size():
		return {}
	return timeout_lines[timeout_index]


## The answers to a time-out line: confirm, stop, and (for allergies) unsure.
func timeout_choices() -> Array[String]:
	var line := timeout_line()
	if line.is_empty():
		return []
	if str(line["id"]) == "allergy":
		return ["confirm", "unsure", "stop"]
	return ["confirm", "stop"]


## Answers the time-out line on the board: "confirm", "stop" or "unsure".
func answer_timeout(choice: String) -> void:
	var line := timeout_line()
	if line.is_empty() or choice not in timeout_choices():
		return
	line["answer"] = choice
	var right := str(line["right"])
	match str(line["id"]):
		"side":
			if choice == "stop":
				timeout_points += 1.0
				_say_by("iyer", "Good catch. His notes say right. Tom, fix the board. That's what a time-out is for.")
			else:
				wrong_side = true
				_say_by("tom", "Left side. Confirmed.")
		"allergy":
			var known := bool(setup["allergy_known"])
			if choice == "confirm":
				reaction_coming = true
				later["incision"] = ["reaction"]
				_say_by("khan", "No allergies. Starting the antibiotic, co-amoxiclav.")
			elif choice == "stop" and known:
				timeout_points += 1.0
				_say_by("khan", "Penicillin? Then no co-amoxiclav. Swapping to one that's safe. Thank you.")
			elif known:
				timeout_points += 0.5
				_say_by("khan", "Not sure? Then I'll use one that's safe either way.")
			else:
				timeout_points += 1.0
				_say_by("khan", "Nobody asked him? Then I'll use one that's safe either way.")
		_:
			if choice == right:
				timeout_points += 1.0
				_say_by("tom", "Confirmed.")
			else:
				_say_by("tom", "It's right, Doctor. I checked it twice.", true)
	timeout_index += 1
	_beat(BEAT, _next_timeout_line)


# --- Steps --------------------------------------------------------------------

func _start_step(index: int) -> void:
	step_index = index
	if index >= STEPS.size():
		_finish_operation()
		return
	step = str(STEPS[index])
	if step == "close" and swabs_back == 0:
		_start_count()
		return
	if step == "incision" and wrong_side:
		wrong_side = false
		happened.append("wrong_side")
		_note(false, "The board said LEFT and you confirmed it. Dr. Iyer stopped you at the incision. The time-out is there to catch exactly that.")
		_say_by("iyer", "Wait. Left? It's his RIGHT side. Read the notes, not the board.", true)
		_beat(BEAT * 1.6, _begin_call.bind(TOOLS[step], str(CALL_LINES[step])))
		return
	_begin_call(str(TOOLS[step]), str(CALL_LINES[step]))


func _begin_call(instrument: String, line: String, by: String = "iyer") -> void:
	phase = "call"
	wanted = instrument
	call_time = 0.0
	wrong_this_call = 0
	_slow_said = false
	calls += 1
	_say_by(by, line, step in ["bleeding", "burst"])


## Asks Tom for an instrument on the ring.
func call_for(instrument: String) -> void:
	if phase != "call" or finished:
		return
	if instrument == wanted:
		_hand(instrument, str(HAND_LINES.get(instrument, Instruments.name_of(instrument) + ".")))
		return
	# While bleeding, suction and a swab help but don't stop it.
	if step == "bleeding" and instrument in ["suction", "swab"]:
		if instrument == "swab":
			swabs_out += 1
			_complication_swabs += 1
			_say_by("iyer", "Pressing on it. It's still pumping. Stop it at the source!", true)
		else:
			_say_by("iyer", "I can see it now. Stop it at the source!", true)
		in_hand = instrument
		return
	if step == "burst" and instrument == "swab":
		swabs_out += 1
		_complication_swabs += 1
		in_hand = instrument
		_say_by("iyer", "A swab won't do it. There's too much. We need to clear it all.", true)
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
	_say_by("tom", str(lines[mini(wrong_this_call - 1, lines.size() - 1)]), true)


func _hand(instrument: String, line: String) -> void:
	in_hand = instrument
	_say_by("tom", line)
	_beat(SHORT_BEAT, _begin_act)


func _begin_act() -> void:
	phase = "act"
	hold_time = 0.0
	holding = false
	trace = PackedVector2Array()
	tracing = false
	match step:
		"incision":
			action = "trace"
			target = ""
		"retract":
			action = "hold"
			target = ""
			_say_by("iyer", "Hold it there. Steady...")
		"find":
			action = "tap"
			target = "appendix"
		"clamp":
			action = "tap"
			target = "base"
		"cut":
			action = "tap"
			target = "cut"
		"bleeding":
			action = "tap"
			target = "bleeder"
			_say_by("iyer", "There, the bleeding vessel. Clamp it!", true)
		"burst":
			action = "hold"
			target = ""
			_say_by("iyer", "Keep the suction on it. Don't stop until it's clear.")
		"close":
			action = "stitch"
			target = ""


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
			_say_by("iyer", "Too short. One stroke, the whole line, end to end.", true)
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
		_say_by("iyer", "Clean edge. Nice.")
	elif trace_score >= 60:
		_say_by("iyer", "A bit wobbly. It'll heal.")
	else:
		_say_by("iyer", "That's ragged. Skin remembers. Smoother next time.", true)
	_act_done()


func _distance_to_trace(point: Vector2) -> float:
	var best := INF
	for index in range(trace.size() - 1):
		var closest := Geometry2D.get_closest_point_to_segment(point, trace[index], trace[index + 1])
		best = minf(best, closest.distance_to(point))
	if trace.size() == 1:
		best = trace[0].distance_to(point)
	return best


## Holding the wound open (or the suction on).
func hold_start() -> void:
	if phase != "act" or action != "hold":
		return
	holding = true
	changed.emit()


func hold_stop() -> void:
	if not holding:
		return
	holding = false
	var needed := WASH_TIME if step == "burst" else HOLD_TIME
	if hold_time < needed:
		hold_restarts += 1
		hold_time = 0.0
		_hurt(2.0)
		if not finished:
			_say_by("iyer", "Don't let go! I need it open the whole time." if step != "burst"
				else "Keep the suction on! It's filling up again.", true)


## Taps something in the wound: appendix, base, cut, bleeder, swab, or
## "bowel" (the wrong thing).
func tap(spot: String) -> void:
	if finished:
		return
	if phase == "search":
		if spot == "swab":
			swab_found = true
			swabs_back = swabs_out
			_say_by("tom", "There it is. %d out, %d back. Count's right." % [swabs_out, swabs_back])
			_beat(BEAT, _start_step.bind(STEPS.find("close")))
		else:
			tap_misses += 1
			_say_by("iyer", "Not there. Look in the corners, under the edges.", true)
		return
	if phase != "act" or action != "tap":
		return
	if spot == target:
		match target:
			"appendix":
				_say_by("iyer", "There it is. Lift it up for me.")
			"base":
				_say_by("iyer", "Clamped. I'm tying it off.")
			"cut":
				_say_by("iyer", "And it's out. Into the dish.")
			"bleeder":
				_say_by("iyer", "Got it. Bleeding's stopped.")
		_act_done()
		return
	tap_misses += 1
	_hurt(4.0 if spot == "bowel" else 2.0)
	if finished:
		return
	match target:
		"appendix":
			_say_by("iyer", "That's small bowel. Gently! Follow the big one down to its end.", true)
		"base":
			_say_by("iyer", "The clamp goes at its base, where it joins the bowel.", true)
		"cut":
			_say_by("iyer", "Just above the clamp. Not the bowel!", true)
		"bleeder":
			_say_by("iyer", "Not there. Where it's spurting!", true)


## A stitch across the incision at a spot on the skin.
func place_stitch(spot: Vector2) -> bool:
	if phase != "act" or action != "stitch" or stitches.size() >= MAX_STITCHES:
		return false
	var found := guide_nearest(spot)
	if float(found[1]) > STITCH_MISS:
		stitch_misses += 1
		_say_by("iyer", "Across the cut, not beside it.", true)
		return false
	stitches.append({"t": float(found[0]), "off": float(found[1])})
	stitches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	_say_by("iyer", "%d." % stitches.size() if stitches.size() < STITCH_TARGET else "That'll hold. Tie it off.")
	changed.emit()
	return true


func tie_off() -> void:
	if phase != "act" or action != "stitch" or stitches.is_empty():
		return
	_act_done()


func _act_done() -> void:
	done_steps.append(step)
	in_hand = ""
	if step in ["bleeding", "burst", "pressure", "reaction"]:
		_resolve_complication()
		return
	if step in ["incision", "retract", "find"]:
		swabs_out += 1
	if step == "close":
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


# --- Complications ------------------------------------------------------------

func _start_complication(which: String) -> void:
	step = which
	active_complication = which
	happened.append(which)
	_set_vital_goal()
	match which:
		"bleeding":
			_drain = 4.0
			_begin_call("clamp", str(CALL_LINES["bleeding"]))
		"burst":
			_drain = 1.5
			_begin_call("suction", str(CALL_LINES["burst"]))
		"pressure":
			_drain = 3.0
			phase = "decide"
			options = [
				{"id": "fluids", "text": "Fluids, fast"},
				{"id": "deeper", "text": "Deepen the anaesthetic"},
				{"id": "carry_on", "text": "Carry on, it'll settle"},
			]
			_say_by("khan", "Pressure's falling. %s. Heart rate climbing. What do you want to do?" % _bp_words(), true)
		"reaction":
			_drain = 4.0
			phase = "decide"
			options = [
				{"id": "adrenaline", "text": "Stop the antibiotic, give adrenaline"},
				{"id": "fluids", "text": "Run fluids and watch"},
				{"id": "carry_on", "text": "Keep going, we're nearly there"},
			]
			_say_by("khan", "Rash across his chest. Pressure's dropping and his oxygen's falling. It's the antibiotic!", true)


func _bp_words() -> String:
	return "%d over %d" % [vitals.systolic, vitals.diastolic]


## The right answer to the decision on show.
func right_option() -> String:
	match step:
		"pressure":
			return "fluids"
		"reaction":
			return "adrenaline"
	return ""


## Picks one of the decision's options.
func decide(option: String) -> void:
	if phase != "decide" or finished:
		return
	if option == right_option():
		if step == "pressure":
			_say_by("khan", "Fluids running. Legs up... Pressure's coming back. Good call.")
		else:
			_say_by("khan", "Antibiotic off. Adrenaline in... The rash is fading. Oxygen's coming up.")
		done_steps.append(step)
		_resolve_complication()
		return
	decisions_wrong += 1
	var penalty := 15.0
	var line := "His airway is swelling. We are not nearly anywhere!"
	match [step, option]:
		["pressure", "deeper"]:
			penalty = 20.0
			line = "Deeper drops it further! He needs fluid in the tank. Think!"
		["pressure", _]:
			penalty = 12.0
			line = "It isn't settling. It's falling. Decide!"
		["reaction", "fluids"]:
			penalty = 8.0
			line = "Fluids alone won't stop a reaction. It's getting worse!"
	_hurt(penalty)
	if not finished:
		_say_by("khan", line, true)


func _resolve_complication() -> void:
	_drain = 0.0
	active_complication = ""
	_set_vital_goal()
	_heal(6.0)
	if step == "burst":
		swabs_out += 2
		_complication_swabs += 2
		_say_by("iyer", "Clear. Two swabs to mop the corners. Now, the appendix.")
	elif step == "bleeding":
		_say_by("iyer", "Bleeding's stopped. Breathe. Back to work.")
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
	_say_by("tom", "Count before closing. Swabs: %d out, %d back. Instruments: all eight." % [swabs_out, swabs_back])


## Answers the count: "close", "recount" or "look".
func count(choice: String) -> void:
	if phase != "count" or finished:
		return
	var missing := swab_missing and not swab_found
	match choice:
		"close":
			if missing:
				closed_on_bad_count = true
				_say_by("tom", "Doctor, the count is wrong. I'm not handing you a needle.", true)
				_beat(BEAT, func() -> void:
					_say_by("iyer", "Nobody closes on a wrong count. Ever. Look in the wound.", true)
					phase = "search")
				return
			swabs_back = swabs_out
			_say_by("tom", "Count's right. Needle holder coming.")
			_beat(SHORT_BEAT, _start_step.bind(STEPS.find("close")))
		"recount":
			recounts += 1
			if missing:
				_say_by("tom", "Again... %d out, %d back. One's missing. It's somewhere." % [swabs_out, swabs_back], true)
			else:
				_say_by("tom", "Same numbers. It's right, Doctor.")
		"look":
			if missing:
				phase = "search"
				_say_by("iyer", "Good. Look carefully. Swabs soak up blood and hide.")
			else:
				recounts += 1
				_say_by("iyer", "Nothing in there but Rohit. The count was right.")


# --- The end ------------------------------------------------------------------

func _take_over() -> void:
	takeover = true
	_drain = 0.0
	in_hand = ""
	phase = "done"
	speaker = "iyer"
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
		var lines := {
			"won": "Last stitch. Well done, everyone. Rohit, you can have your appendix in a jar.",
			"struggled": "Done. That was harder than it needed to be. But it's done.",
			"failed": "It's done.",
		}
		_say_by("iyer", str(lines[outcome]))
	_finish()


func _outcome() -> String:
	if takeover:
		return "failed"
	if score() >= 75 and stability >= 60.0:
		return "won"
	return "struggled"


## 0 to 100: how well the doctor worked with Tom.
func teamwork() -> int:
	var points := 100 - 8 * wrong_calls - 5 * slow_calls - 12 * handed_over - 5 * recounts
	if closed_on_bad_count:
		points -= 20
	if "wrong_side" in happened:
		points -= 10
	return clampi(points, 0, 100)


## 0 to 100: the cut, the hold, the taps, the decisions and the stitches.
func technique() -> int:
	var parts: Array[float] = []
	if trace_score >= 0:
		parts.append(trace_score)
	if "retract" in done_steps:
		parts.append(maxf(0.0, 100.0 - 20.0 * hold_restarts))
	parts.append(maxf(0.0, 100.0 - 15.0 * tap_misses))
	if decisions_wrong > 0 or "pressure" in happened or "reaction" in happened:
		parts.append(maxf(0.0, 100.0 - 35.0 * decisions_wrong))
	if "close" in done_steps and not takeover:
		parts.append(_stitch_score())
	var total := 0.0
	for part in parts:
		total += part
	return int(round(total / parts.size()))


## 0 to 100: the scrub, the time-out and the count.
func safety() -> int:
	var points := 0.5 * float(setup["scrub"]) + 50.0 * timeout_points / timeout_lines.size()
	if closed_on_bad_count:
		points -= 30.0
	return clampi(int(round(points)), 0, 100)


func score() -> int:
	var points := int(round(0.3 * stability + 0.25 * teamwork() + 0.3 * technique() + 0.15 * safety()))
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
	var count_part := clampf(float(stitches.size()) / STITCH_TARGET, 0.0, 1.0)
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
	var ends := 1.0
	if _distance_along(float(stitches[0]["t"])) > 1.2:
		ends -= 0.5
	if guide_length() - _distance_along(float(stitches[stitches.size() - 1]["t"])) > 1.2:
		ends -= 0.5
	var points := 100.0 * (0.3 * accuracy + 0.3 * count_part + 0.25 * evenness + 0.15 * ends) - 5.0 * stitch_misses
	return clampi(int(round(points)), 0, 100)


func _write_notes() -> void:
	if takeover:
		_note(false, "Rohit got too unstable and Dr. Iyer had to take over. %s" % _takeover_reason())
	if "reaction" in happened:
		_note(false, "He reacted to the antibiotic. %s" % ("You knew about the penicillin and still confirmed \"none known\"."
			if bool(setup["allergy_known"]) else "Nobody had asked him about allergies, and the time-out confirmed \"none known\"."))
	elif bool(setup["allergy_known"]):
		_note(true, "You asked about allergies before, and stopped the wrong antibiotic at the time-out.")
	if "burst" in happened:
		_note(false, "The appendix burst while he waited. Putting the operation off made it longer and riskier.")
	if "wrong_side" not in happened and str(timeout_lines[2].get("answer", "")) == "stop":
		_note(true, "You caught the wrong side on the board at the time-out.")
	if closed_on_bad_count:
		_note(false, "You tried to close with a swab missing. A swab left inside means a second operation.")
	elif swab_found:
		_note(true, "The count was off and you found the missing swab before closing.")
	if wrong_calls == 0 and handed_over == 0 and slow_calls == 0:
		_note(true, "Every instrument called right and on time. Tom never had to guess.")
	else:
		_note(false, "%d wrong call%s and %d slow. Each one costs seconds and Tom's trust." %
			[wrong_calls, "" if wrong_calls == 1 else "s", slow_calls + handed_over])
	if decisions_wrong > 0:
		_note(false, "A wrong decision during the %s. Read the monitor, then act on what it says." %
			("pressure drop" if "pressure" in happened else "reaction"))
	elif "pressure" in happened or "reaction" in happened:
		_note(true, "You read Dr. Khan's call right and acted at once.")
	if trace_score >= 85:
		_note(true, "A clean, even incision along the line.")
	elif trace_score >= 0:
		_note(false, "The incision wandered off the line. A wobbly cut heals into a wider scar.")
	if float(setup["scrub"]) < 65:
		_note(false, "A rushed scrub raises the risk of infection afterwards.")


func _takeover_reason() -> String:
	if "bleeding" in happened and "bleeding" not in done_steps:
		return "The bleeding went on too long."
	if "reaction" in happened and "reaction" not in done_steps:
		return "The allergic reaction wasn't treated in time."
	if "pressure" in happened and "pressure" not in done_steps:
		return "His blood pressure wasn't brought back up."
	return "Too many things went wrong at once."


func instruction() -> String:
	match phase:
		"timeout":
			return "Time-out: check the board. Confirm it, or stop the team"
		"call":
			return "Call for what Dr. Iyer needs on the ring"
		"act":
			match action:
				"trace":
					return "Trace the dotted line in one stroke, end to end"
				"hold":
					return "Hold the suction on until it's clear" if step == "burst" else "Press and hold to keep the wound open"
				"tap":
					return str({
						"appendix": "Tap the appendix: the small tube where the big bowel ends",
						"base": "Tap the base of the appendix, where it joins the bowel",
						"cut": "Tap just above the clamp to cut",
						"bleeder": "Tap the bleeding vessel to clamp it",
					}.get(target, "Tap it"))
				"stitch":
					return "Tap across the cut to stitch: %d placed" % stitches.size()
		"decide":
			return "Read the monitor. Then decide"
		"count":
			return "Check Tom's count before closing"
		"search":
			return "Find the missing swab in the wound"
		"done":
			return "Dr. Iyer has taken over" if takeover else "Done"
	return ""


func progress() -> float:
	if finished:
		return 1.0
	var total := STEPS.size() + 1.0
	if step == "timeout":
		return 0.12 * timeout_index / timeout_lines.size()
	return clampf((maxi(0, step_index) + 1.0) / total, 0.0, 1.0)


# --- Vitals -------------------------------------------------------------------

func _set_vital_goal() -> void:
	var goal := {"hr": 82.0, "sys": 118.0, "dia": 74.0, "spo2": 99.0, "rr": 14.0}
	if bool(setup.get("delayed", false)):
		goal["hr"] = 96.0
	match active_complication:
		"bleeding":
			goal = {"hr": 126.0, "sys": 84.0, "dia": 48.0, "spo2": 97.0, "rr": 14.0}
		"pressure":
			goal = {"hr": 114.0, "sys": 80.0, "dia": 44.0, "spo2": 97.0, "rr": 14.0}
		"reaction":
			goal = {"hr": 132.0, "sys": 76.0, "dia": 40.0, "spo2": 88.0, "rr": 14.0}
		"burst":
			goal = {"hr": 108.0, "sys": 104.0, "dia": 64.0, "spo2": 97.0, "rr": 14.0}
	_vital_goal = goal


func _snap_vitals() -> void:
	_vital_now = _vital_goal.duplicate()
	_show_vitals()


func _update_vitals(delta: float) -> void:
	# Low stability shows too: a faster heart and a softer pressure.
	var strain := clampf((70.0 - stability) / 50.0, 0.0, 1.0)
	var bend := {"hr": 20.0 * strain, "sys": -14.0 * strain, "dia": -8.0 * strain, "spo2": 0.0, "rr": 0.0}
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


## A word for the monitor: how Rohit is doing.
func condition() -> String:
	if takeover:
		return "DR. IYER HAS TAKEN OVER"
	match active_complication:
		"bleeding":
			return "BLEEDING"
		"pressure":
			return "PRESSURE FALLING"
		"reaction":
			return "ALLERGIC REACTION"
		"burst":
			return "BURST APPENDIX"
	if stability >= 70.0:
		return "STABLE"
	if stability >= 40.0:
		return "UNSTEADY"
	return "CRITICAL"


func _say_by(who: String, line: String, warns: bool = false) -> void:
	speaker = who
	_say(line.replace("{called}", str(setup.get("called", "Doctor"))), warns)
