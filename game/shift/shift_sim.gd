class_name ShiftSim
extends RefCounted
## Casualty during a shift: who walks in, who waits, who gets worse, which
## results come back and when. Pure rules on hospital minutes, no visuals,
## so a whole shift can be played in a test in a blink.
##
## The ward owns the clock (PlayerProfile.minutes) and calls advance_to()
## a few times a second; the sim steps one hospital minute at a time, so
## the same seed always gives the same shift however the frames fall. Work
## the doctor does (asking, examining, ordering, deciding) costs hospital
## minutes; the ward passes them on the clock and the sim catches up.
##
## Events come back from advance_to() as dictionaries for the ward to show:
##   {"kind": "arrived" | "result" | "worse" | "crashed" | "died" | "critical" |
##    "left" | "back" | "diverted" | "gone" | "visit", "patient": ShiftPatient
##    (or null), "text": String}
## A "visit" is a cured patient from an earlier day dropping in with sweets;
## it carries their record ("entry") and the experience it's worth ("xp").
##
## A "died" event carries the death's "fault" (Fates.FAULTS); a "critical"
## one is the lab ringing about a result (ShiftPatient.alert).
##
## With a Director (stage 26, set by ShiftDay.make), the shift is paced too:
## "lift", "silly" and "moment" events, and trouble after a quiet stretch.
##
## Three random streams: one decides who walks in and when, one everything
## the doctor's choices touch, and one the mistakes and deaths (Fates). So a
## day started again brings the same people at the same times, whatever was
## done differently, and the mistakes never shift the day's arrivals.

## Cubicles you see patients in, and how many can wait before the
## ambulances go elsewhere.
const CUBICLES := 4
const MAX_WAITING := 6
## Hospital minutes each piece of work takes.
const ASK_MINUTES := 2
const EXAM_MINUTES := 5
const ORDER_MINUTES := 1
const DECIDE_MINUTES := 5
## Arrivals an hour, by the hour they start from (busy evenings, quiet
## small hours), before the shift's load scales them.
const RATES := [[0, 1.6], [2, 1.0], [7, 2.0], [10, 3.0], [13, 2.6], [17, 3.2], [22, 2.2]]
## A severity that pages you, and one that crashes.
const WORSE_AT := 75.0
const CRASH_AT := 100.0
## A green patient left waiting this long may walk out.
const LEAVE_AFTER := 180
## How long a patient stays on the board once the plan's chosen (on their
## way out, out of the cubicle), before they're gone.
const STAY_AFTER := [12, 25]
## Points for a plan: right, key tests, an examination, in good time.
const POINTS_RIGHT := 60
const POINTS_TESTS := 20
const POINTS_EXAM := 10
const POINTS_TIME := 10
## No two arrivals in a row share an illness, nor any of the last few.
const RECENT := 3
## Experience for a cured patient who drops in with sweets.
const SWEETS_XP := 5
## Points for catching a wrong lab result by repeating it.
const POINTS_CAUGHT := 5

## Who walks in, when, and what they have.
var arrivals: SeededRandom
## Everything else: how long people stay, when the wrongly sent home come
## back, who gives up waiting.
var rng: SeededRandom
## Mistakes and deaths: who dies of a crash or a harmful plan, the lab's
## wrong results, the nurse's read-back, the patient nobody can save.
var fate: SeededRandom
## Deaths still to come: [minute, patient, fault, why].
var deaths_due: Array = []
## The minute the shift's patient beyond saving comes in (-1: none).
var doomed_at := -1
## Read-backs waiting for the doctor's answer, by patient id:
## {wrong, right (cubicle indexes), other (the patient in the wrong one)}.
var readbacks := {}
var minute := 0
var load := 1.0
var patients: Array[ShiftPatient] = []
var next_id := 1
var diverted := 0
## A gentle start: [minutes after the shift starts, condition id] for the
## first few arrivals, in order. Random arrivals wait until these are in.
var first_arrivals: Array = []
## Patients due back (sent home wrongly): [minute, patient].
var returns: Array = []
var recent: Array = []
## The hospital day (rarer illnesses join as the career goes on; 9999 lets
## everything walk in), the career's hospital seed (0: no outbreaks), and
## patients met on earlier days who may come back (ShiftDay.past()).
var day := 9999
var hospital := 0
var past: Array = []
var _start_minute := 0
## Records that have come back today, by id.
var _came_back := {}
## The shift's pacing (stage 26), or null for a shift without one (tests).
var director: Director


func _init(seed_value: int = 1, start_minute: int = 8 * 60, shift_load: float = 1.0) -> void:
	arrivals = SeededRandom.new(seed_value)
	rng = SeededRandom.new(absi(hash("shift|%d" % seed_value)) % 1000003 + 1)
	fate = SeededRandom.new(absi(hash("fate|%d" % seed_value)) % 1000003 + 1)
	minute = start_minute
	_start_minute = start_minute
	load = shift_load


## The day's own mistakes, once the day is set (ShiftDay.make): maybe a
## patient beyond saving later on, maybe a bed the handover forgot.
func plan_fates() -> void:
	if day >= Fates.from_day("doomed_from_day") and fate.chance(Fates.chance("doomed_shift")):
		doomed_at = _start_minute + fate.next_int_in(60, 360)
	if day >= Fates.from_day("forgotten_from_day") and fate.chance(Fates.chance("forgotten_bed")):
		_hold_over()
	if director != null:
		director.plan(day, _start_minute)


## How busy casualty is in this hour: arrivals expected per hospital hour.
func rate_at(at_minute: int) -> float:
	var hour := (at_minute / 60) % 24
	var found := 2.0
	for entry: Array in RATES:
		if hour >= int(entry[0]):
			found = float(entry[1])
	return found * load


## Steps the shift on to a hospital minute and returns what happened.
func advance_to(target: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	while minute < target:
		minute += 1
		_step_minute(events)
	return events


func _step_minute(events: Array[Dictionary]) -> void:
	var first := events.size()
	_step_world(events)
	if director != null:
		director.step(self, events, first)


func _step_world(events: Array[Dictionary]) -> void:
	for index in range(deaths_due.size() - 1, -1, -1):
		var due: Array = deaths_due[index]
		if int(due[0]) <= minute:
			deaths_due.remove_at(index)
			_die(due[1], str(due[2]), events, str(due[3]))
	if doomed_at >= 0 and minute >= doomed_at:
		doomed_at = -1
		_bring_doomed(events)
	# People who come back first (a full waiting area makes them wait
	# outside a little longer), then new arrivals.
	for index in range(returns.size() - 1, -1, -1):
		if int(returns[index][0]) <= minute:
			if waiting().size() >= MAX_WAITING:
				returns[index][0] = minute + 10
				continue
			var back: ShiftPatient = returns[index][1]
			returns.remove_at(index)
			back.state = "waiting"
			back.arrived_at = minute
			patients.append(back)
			events.append({"kind": "back", "patient": back, "text": "%s is back. Worse." % back.called()})
	if not first_arrivals.is_empty():
		if minute >= _start_minute + int(first_arrivals[0][0]):
			_arrive(events, str(first_arrivals.pop_front()[1]))
	elif arrivals.chance(rate_at(minute) / 60.0):
		# The patient is made even when casualty's full, so the day's
		# arrivals stay the same whatever the doctor does.
		var coming := _returner()
		if bool(coming.get("sweets", false)):
			events.append(_sweets_visit(coming["entry"]))
			return
		var known: Dictionary = coming.get("entry", {})
		if bool(coming.get("worse", false)):
			known = known.duplicate()
			known["worse"] = true
		var patient := make_patient(str(known.get("condition", "")) if known.has("worse") else "", known)
		if waiting().size() >= MAX_WAITING:
			diverted += 1
			events.append({"kind": "diverted", "patient": null, "text": "Casualty's full. An ambulance went to CarePlus."})
		else:
			_add(events, patient)
	for patient in patients:
		if not patient.is_here():
			continue
		_tick_patient(patient, events)


func _tick_patient(patient: ShiftPatient, events: Array[Dictionary]) -> void:
	if patient.state == "done":
		patient.severity = maxf(0.0, patient.severity - 1.0)
		if minute >= patient.leave_at:
			patient.state = "gone"
			patient.cubicle = -1
			events.append({"kind": "gone", "patient": patient, "text": ""})
		return
	patient.severity = minf(CRASH_AT, patient.severity + patient.worsens / 60.0)
	for test: String in patient.ordered:
		if not patient.results.has(test) and minute >= int(patient.ordered[test]):
			_result_back(patient, test, events)
	if patient.severity >= WORSE_AT and not patient.paged.has("worse"):
		patient.paged["worse"] = true
		events.append({"kind": "worse", "patient": patient, "text": "%s %s looks worse." % [patient.called(), where_text(patient)]})
	if patient.severity >= CRASH_AT:
		if patient.doomed or fate.chance(Fates.chance("crash_death")):
			_die(patient, "nobody" if patient.doomed else "wait", events,
				"%s crashed %s. The crash team worked for forty minutes and couldn't bring %s back." % [
					patient.called(), where_text(patient), patient.them()])
			return
		patient.state = "gone"
		patient.cubicle = -1
		patient.outcome = "crashed"
		events.append({"kind": "crashed", "patient": patient,
			"text": "%s crashed %s. The crash team took them to intensive care." % [patient.called(), where_text(patient)]})
		return
	if patient.state == "waiting" and patient.triage() == "green" and patient.waited(minute) >= LEAVE_AFTER * patient.patience \
			and rng.chance(1.0 / 60.0):
		patient.state = "gone"
		patient.outcome = "left"
		events.append({"kind": "left", "patient": patient, "text": "%s got tired of waiting and went home." % patient.called()})


func where_text(patient: ShiftPatient) -> String:
	if patient.cubicle >= 0:
		return "in cubicle %d" % (patient.cubicle + 1)
	return "in the waiting area"


## A new patient walks in (condition "" picks one).
func _arrive(events: Array[Dictionary], condition_id: String) -> ShiftPatient:
	return _add(events, make_patient(condition_id))


## Brings in a patient made elsewhere (the director's trouble).
func add_patient(events: Array[Dictionary], patient: ShiftPatient) -> ShiftPatient:
	return _add(events, patient)


func _add(events: Array[Dictionary], patient: ShiftPatient) -> ShiftPatient:
	patients.append(patient)
	var text := "New in casualty: %s." % patient.board_line()
	if patient.triage() == "red":
		text = "Red in casualty: %s." % patient.board_line()
	events.append({"kind": "arrived", "patient": patient, "text": text})
	return patient


## A new patient (condition "" picks one for the day). known: someone met on
## an earlier day (ShiftDay.past()), who keeps their name, face, temper and
## voice; with "worse" they're back with the same trouble, further along.
func make_patient(condition_id: String = "", known: Dictionary = {}) -> ShiftPatient:
	var known_age := int(known.get("age", -1))
	var known_sex := str(known.get("sex", ""))
	var outbreak := Outbreak.kind_on(hospital, day)
	var id := condition_id
	if not (Conditions.can_walk_in(id, 9999, known_age, known_sex) or (id == Outbreak.ID and not outbreak.is_empty())):
		var extra := {Outbreak.ID: Outbreak.weight()} if not outbreak.is_empty() and known.is_empty() else {}
		id = Conditions.pick(arrivals, recent, day, extra, known_age, known_sex)
	recent.append(id)
	while recent.size() > RECENT:
		recent.pop_front()
	# One draw seeds everything about who they are and what they say, so the
	# day's arrivals and their times never depend on it.
	var detail := SeededRandom.new(absi(arrivals.next()) % 1000003 + 1)
	var base := Outbreak.condition(outbreak, detail) if id == Outbreak.ID else Conditions.get_condition(id)
	var patient := ShiftPatient.new()
	patient.id = next_id
	next_id += 1
	patient.condition_id = id
	var ages: Array = base.get("age", [20, 60])
	var rolled_age := arrivals.next_int_in(int(ages[0]), int(ages[1]))
	var rolled_person := NameMaker.make(arrivals, str(base.get("sex", "")), rolled_age)
	if known.is_empty():
		patient.age = rolled_age
		patient.person = rolled_person
	else:
		patient.age = known_age
		patient.person = {}
		for key: String in ["first", "last", "full", "community", "sex", "home"]:
			patient.person[key] = str(known.get(key, ""))
		patient.known_id = str(known.get("id", ""))
		patient.known_day = int(known.get("day", 0))
		patient.known_what = str(Conditions.get_condition(str(known.get("condition", ""))).get("plain", ""))
		patient.complication = bool(known.get("worse", false))
	PatientMaker.build(patient, base, detail, known)
	var case := patient.condition
	var starts: Array = case.get("start", [20, 30])
	patient.severity = float(arrivals.next_int_in(int(starts[0]), int(starts[1])))
	if patient.complication:
		patient.severity = minf(WORSE_AT - 5.0, patient.severity + 10.0)
	patient.worsens = float(case.get("worsens", 4)) * arrivals.range_float(0.8, 1.2)
	patient.vitals = _roll_vitals(case.get("vitals", {}))
	patient.arrived_at = minute
	var look := arrivals.next()
	patient.look_seed = int(known.get("look", look)) if not known.is_empty() else look
	var order := [0, 1, 2, 3]
	patient.plan_order = arrivals.shuffled(order.slice(0, (case.get("plans", []) as Array).size()))
	return patient


## Sometimes a patient from an earlier day comes back instead of a
## stranger: {} (nobody), {"entry"} (a new problem), {"entry", "worse"}
## (the old trouble, because it went wrong) or {"entry", "sweets"} (cured,
## and grateful).
func _returner() -> Dictionary:
	if past.is_empty():
		return {}
	var rules := PatientParts.returns()
	if not arrivals.chance(float(rules.get("chance", 0.0))):
		return {}
	var choices := []
	for entry: Dictionary in past:
		if not _came_back.has(str(entry.get("id", ""))):
			choices.append(entry)
	if choices.is_empty():
		return {}
	var entry: Dictionary = arrivals.pick(choices)
	_came_back[str(entry.get("id", ""))] = true
	var outcome := str(entry.get("outcome", ""))
	var condition := str(entry.get("condition", ""))
	if outcome in ["harmed", "worse", "back"] and Conditions.can_walk_in(condition, 9999, int(entry.get("age", -1)),
			str(entry.get("sex", ""))):
		return {"entry": entry, "worse": true}
	if outcome == "better" and arrivals.chance(float(rules.get("sweets_share", 0.0))):
		return {"entry": entry, "sweets": true}
	return {"entry": entry}


## A cured patient drops in with sweets for casualty.
func _sweets_visit(entry: Dictionary) -> Dictionary:
	var sweets: Array = PatientParts.returns().get("sweets", ["a box of sweets"])
	var person := {"first": entry.get("first", ""), "last": entry.get("last", ""), "sex": entry.get("sex", "m")}
	var what := str(Conditions.get_condition(str(entry.get("condition", ""))).get("plain", ""))
	var text := "%s, from Day %d, dropped in with %s for casualty." % [NameMaker.called(person, int(entry.get("age", 40))),
		int(entry.get("day", 0)), str(arrivals.pick(sweets))]
	if not what.is_empty():
		text += " %s is long gone, apparently." % (what.substr(0, 1).to_upper() + what.substr(1))
	return {"kind": "visit", "patient": null, "text": text, "entry": entry, "xp": SWEETS_XP}


func _roll_vitals(ranges: Dictionary) -> Dictionary:
	var rolled := {}
	for key: String in ["pulse", "bp", "spo2", "breaths"]:
		var span: Array = ranges.get(key, [80, 80])
		rolled[key] = arrivals.next_int_in(int(span[0]), int(span[1]))
	var temps: Array = ranges.get("temp", [36.8, 37.0])
	rolled["temp"] = snappedf(arrivals.range_float(float(temps[0]), float(temps[1])), 0.1)
	rolled["dia"] = int(round(float(rolled["bp"]) * 0.62))
	return rolled


func waiting() -> Array[ShiftPatient]:
	var found: Array[ShiftPatient] = []
	for patient in patients:
		if patient.state == "waiting":
			found.append(patient)
	return found


## Everyone still in casualty, sickest first, then longest waiting.
func board() -> Array[ShiftPatient]:
	var found: Array[ShiftPatient] = []
	for patient in patients:
		if patient.is_here():
			found.append(patient)
	found.sort_custom(func(a: ShiftPatient, b: ShiftPatient) -> bool:
		var ta := Conditions.TRIAGE.find(a.triage())
		var tb := Conditions.TRIAGE.find(b.triage())
		if ta != tb:
			return ta < tb
		return a.arrived_at < b.arrived_at)
	return found


func in_cubicle(index: int) -> ShiftPatient:
	for patient in patients:
		if patient.is_here() and patient.cubicle == index:
			return patient
	return null


func free_cubicle() -> int:
	for index in CUBICLES:
		if in_cubicle(index) == null:
			return index
	return -1


func by_id(id: int) -> ShiftPatient:
	for patient in patients:
		if patient.id == id:
			return patient
	return null


## Brings a waiting patient into a free cubicle. False if none is free.
func take(patient: ShiftPatient) -> bool:
	if patient == null or patient.state != "waiting":
		return false
	var index := free_cubicle()
	if index < 0:
		return false
	patient.cubicle = index
	patient.state = "seeing"
	return true


## The patient's answer to one of ShiftPatient.QUESTIONS. Costs ASK_MINUTES.
func ask(patient: ShiftPatient, question: String) -> String:
	patient.asked[question] = true
	return str((patient.condition.get("answers", {}) as Dictionary).get(question, "I don't know, Doctor."))


## What examining them finds. Costs EXAM_MINUTES.
func examine(patient: ShiftPatient) -> String:
	patient.examined = true
	return str(patient.condition.get("exam", "Nothing unusual."))


## Sends a test off. Its result comes back after the test's minutes. False
## if it was ordered already. Costs ORDER_MINUTES.
func order(patient: ShiftPatient, test: String) -> bool:
	if not Conditions.TESTS.has(test) or patient.ordered.has(test) or patient.decided():
		return false
	patient.ordered[test] = minute + int(Conditions.TESTS[test]["minutes"])
	return true


## The doctor's plan, as a position on the patient's card. Returns
## {right, why, effect, score, plan (text)}. Costs DECIDE_MINUTES.
func decide(patient: ShiftPatient, position: int) -> Dictionary:
	var chosen := patient.shown_plan(position)
	if chosen.is_empty() or patient.decided():
		return {}
	var was_in := patient.cubicle
	patient.plan = int(patient.plan_order[position])
	var right := bool(chosen.get("right", false))
	if patient.alert_open():
		patient.alert["answer"] = "ignored"
	var effect := "better" if right else str(chosen.get("effect", "worse"))
	patient.score = score_for(patient, right)
	patient.state = "done"
	# The porter takes them straight away, so the cubicle is free for the
	# next one.
	patient.cubicle = -1
	patient.leave_at = minute + rng.next_int_in(STAY_AFTER[0], STAY_AFTER[1])
	match effect:
		"better":
			patient.outcome = "better"
			patient.severity = maxf(0.0, patient.severity - 20.0)
		"lucky":
			patient.outcome = "fine"
		"harm":
			patient.outcome = "harmed"
			_harm(patient, "you", str(chosen.get("why", "")))
		"back":
			patient.outcome = "back"
			_send_back(patient)
		_:
			patient.outcome = "worse"
	var result := {"right": right, "why": str(chosen.get("why", "")), "effect": effect, "score": patient.score,
		"plan": str(chosen.get("text", ""))}
	if patient.doomed:
		var go := str(Conditions.DESTINATIONS.get(str(patient.condition.get("go", "")), "upstairs"))
		_schedule_death(patient, minute + fate.next_int_in(40, 120), "nobody",
			"%s, who you sent %s, has died. %s" % [patient.called(), go, Fates.doomed_why(patient.condition_id)])
	elif right and was_in >= 0:
		_maybe_readback(patient, was_in, result)
	return result


## The nurse reads a right plan back, sometimes for the wrong cubicle (only
## when someone else is in that one). The doctor must answer it
## (answer_readback); result gets the line that asks.
func _maybe_readback(patient: ShiftPatient, was_in: int, result: Dictionary) -> void:
	if not fate.chance(Fates.chance("readback_error")):
		return
	var others := []
	for index in CUBICLES:
		var other := in_cubicle(index)
		if other != null and other != patient and not other.decided():
			others.append(index)
	if others.is_empty():
		return
	var wrong := int(fate.pick(others))
	readbacks[patient.id] = {"wrong": wrong, "right": was_in, "other": in_cubicle(wrong).id}
	result["readback"] = Fates.readback_line("ask", _readback_values(patient))


func _readback_values(patient: ShiftPatient) -> Dictionary:
	var pending: Dictionary = readbacks.get(patient.id, {})
	var other := by_id(int(pending.get("other", -1)))
	return {"wrong": int(pending.get("wrong", 0)) + 1, "right": int(pending.get("right", 0)) + 1,
		"patient": patient.called(), "other": other.called() if other != null else "Someone"}


## A read-back waiting for the doctor's answer.
func readback_open(patient: ShiftPatient) -> bool:
	return patient != null and readbacks.has(patient.id)


## The doctor's answer to a wrong read-back: correct it (true), or nod it
## through, and the drug goes to the patient in the other cubicle while this
## one waits for theirs. Returns what happened.
func answer_readback(patient: ShiftPatient, correct: bool) -> String:
	if not readback_open(patient):
		return ""
	var values := _readback_values(patient)
	var pending: Dictionary = readbacks[patient.id]
	readbacks.erase(patient.id)
	if correct:
		return Fates.readback_line("correct", values)
	var other := by_id(int(pending["other"]))
	if other != null and other.is_here():
		_harm(other, "team", "%s got a drug meant for someone else." % other.called())
	patient.severity = minf(CRASH_AT - 1.0, patient.severity + 15.0)
	return Fates.readback_line("nod", values)


## A lab result comes back: the real one, or the lab ringing about a
## critical result (real for the condition, or now and then a wrong one).
func _result_back(patient: ShiftPatient, test: String, events: Array[Dictionary]) -> void:
	var text := Conditions.result(patient.condition, test, patient.sex())
	var named := str(Conditions.TESTS[test]["name"]).to_lower()
	if str(patient.alert.get("test", "")) == test and str(patient.alert.get("answer", "")) == "repeat":
		var kind := str(patient.alert.get("error", ""))
		patient.results[test] = text
		if not kind.is_empty():
			patient.caught = true
		events.append({"kind": "result", "patient": patient, "text": Fates.lab_line(kind, "repeat", patient.called())})
		return
	if patient.alert.is_empty():
		var kinds := Fates.errors_for(test)
		if Fates.critical_test(patient.condition_id) == test:
			patient.alert = {"test": test, "error": "", "answer": ""}
			patient.results[test] = text
			events.append({"kind": "critical", "patient": patient, "text": Fates.lab_line("", "call", patient.called())})
			return
		if not kinds.is_empty() and not patient.doomed and fate.chance(Fates.chance("lab_error")):
			var kind := str(fate.pick(kinds))
			patient.alert = {"test": test, "error": kind, "answer": ""}
			patient.results[test] = Fates.lab_line(kind, "result", patient.called())
			events.append({"kind": "critical", "patient": patient, "text": Fates.lab_line(kind, "call", patient.called())})
			return
	patient.results[test] = text
	events.append({"kind": "result", "patient": patient, "text": "%s's %s is back." % [patient.called(), named]})


## Sends the result the lab rang about off again. Its true result comes back
## after the test's minutes. Costs ORDER_MINUTES.
func repeat_test(patient: ShiftPatient) -> bool:
	if patient == null or not patient.alert_open() or patient.decided():
		return false
	var test := str(patient.alert["test"])
	patient.alert["answer"] = "repeat"
	patient.results.erase(test)
	patient.ordered[test] = minute + int(Conditions.TESTS[test]["minutes"])
	return true


## Acts on the result the lab rang about straight away: right for a real
## one, harm for a wrong one. Returns what happened. Costs ORDER_MINUTES.
func treat_alert(patient: ShiftPatient) -> String:
	if patient == null or not patient.alert_open() or patient.decided():
		return ""
	patient.alert["answer"] = "treat"
	var kind := str(patient.alert.get("error", ""))
	var said := Fates.lab_line(kind, "treat", patient.called())
	if kind.is_empty():
		patient.severity = maxf(0.0, patient.severity - 10.0)
	else:
		_harm(patient, "lab", said)
	return said


## Harm done (a plan, a wrong result treated, a nodded read-back): they get
## sicker, and some die of it later in the shift.
func _harm(patient: ShiftPatient, fault: String, why: String) -> void:
	patient.severity = minf(CRASH_AT - 1.0, patient.severity + 25.0)
	if patient.doomed or _death_due(patient):
		return
	if fate.chance(Fates.chance("harm_death")):
		_schedule_death(patient, minute + fate.next_int_in(30, 90), fault,
			"%s, who you saw earlier, has died. %s" % [patient.called(), why])


func _schedule_death(patient: ShiftPatient, at_minute: int, fault: String, why: String) -> void:
	if _death_due(patient):
		return
	deaths_due.append([at_minute, patient, fault, why])


func _death_due(patient: ShiftPatient) -> bool:
	for due: Array in deaths_due:
		if due[1] == patient:
			return true
	return false


func _die(patient: ShiftPatient, fault: String, events: Array[Dictionary], text: String) -> void:
	if patient.outcome == "died":
		return
	patient.state = "gone"
	patient.cubicle = -1
	patient.outcome = "died"
	patient.fault = fault
	returns = returns.filter(func(entry: Array) -> bool: return entry[1] != patient)
	events.append({"kind": "died", "patient": patient, "fault": fault, "text": text})


## The shift's patient beyond saving comes in by ambulance: a red illness
## that can kill whatever is done, made aside so the day's arrivals stay the
## same.
func _bring_doomed(events: Array[Dictionary]) -> void:
	var options := []
	for id: String in Fates.doomed():
		if Conditions.can_walk_in(id, day):
			options.append(id)
	options.sort()
	if options.is_empty():
		return
	var patient := _make_aside(str(fate.pick(options)))
	patient.doomed = true
	patient.severity = maxf(patient.severity, float(fate.next_int_in(62, 72)))
	_add(events, patient)


## A patient who came in before the shift and was left out of the handover:
## on the board, unseen, getting worse.
func _hold_over() -> void:
	var options := []
	for id: String in Conditions.ids():
		if Conditions.get_condition(id).get("triage", "") == "yellow" and Conditions.can_walk_in(id, day):
			options.append(id)
	if options.is_empty():
		return
	var patient := _make_aside(str(fate.pick(options)))
	patient.forgotten = true
	patient.arrived_at = minute - fate.next_int_in(60, 120)
	patient.severity = float(fate.next_int_in(58, 66))
	patient.worsens = maxf(patient.worsens, 6.0) * 1.3
	patients.append(patient)


## The bed the handover forgot, while nobody has looked at it yet.
func forgotten_patient() -> ShiftPatient:
	for patient in patients:
		if patient.forgotten and patient.is_here():
			return patient
	return null


## A patient made from the fate stream, so who walks in today (and the
## illnesses they avoid repeating) stays the same.
func _make_aside(condition_id: String) -> ShiftPatient:
	return make_aside_from(fate, condition_id)


## A patient made from another stream (the fates, the director), so who
## walks in today, and the illnesses they avoid repeating, stay the same.
func make_aside_from(stream: SeededRandom, condition_id: String) -> ShiftPatient:
	var saved := arrivals
	var saved_recent := recent.duplicate()
	arrivals = SeededRandom.new(absi(stream.next()) % 1000003 + 1)
	var patient := make_patient(condition_id)
	arrivals = saved
	recent = saved_recent
	return patient


## Sent home wrongly: they come back later in the shift, worse, if there's
## shift left for it.
func _send_back(patient: ShiftPatient) -> void:
	var back := patient.copy_for_return()
	back.id = next_id
	next_id += 1
	back.severity = minf(90.0, patient.severity + 25.0)
	back.worsens = patient.worsens * 1.2
	back.returning = true
	returns.append([minute + rng.next_int_in(90, 150), back])


## Points for a decision, out of 100: the plan, the key tests done before
## deciding, an examination, and deciding before they got bad. Needless
## tests cost a little.
func score_for(patient: ShiftPatient, right: bool) -> int:
	var points := POINTS_RIGHT if right else 10
	var key: Array = patient.condition.get("key", [])
	if key.is_empty():
		points += POINTS_TESTS
	else:
		var done := 0
		for test: String in key:
			if patient.results.has(test):
				done += 1
		points += int(round(POINTS_TESTS * float(done) / key.size()))
	if patient.examined:
		points += POINTS_EXAM
	if patient.severity < 60.0:
		points += POINTS_TIME
	elif patient.severity < 80.0:
		points += POINTS_TIME / 2
	var waste := 0
	for test: String in patient.ordered:
		if not Conditions.useful(patient.condition, test):
			waste += int(Conditions.TESTS[test]["cost"])
	if patient.caught:
		points += POINTS_CAUGHT
	return clampi(points - mini(10, waste), 0, 100)


## The shift's tally for the handover card.
func summary() -> Dictionary:
	var tally := {"seen": 0, "right": 0, "wrong": 0, "crashed": 0, "died": 0, "caught": 0, "left": 0, "waiting": 0,
		"points": 0, "diverted": diverted}
	for patient in patients:
		if patient.outcome == "died":
			tally["died"] += 1
		if patient.caught:
			tally["caught"] += 1
		if patient.decided():
			tally["seen"] += 1
			tally["points"] += patient.score
			if bool((patient.plans()[patient.plan] as Dictionary).get("right", false)):
				tally["right"] += 1
			else:
				tally["wrong"] += 1
		elif patient.outcome == "crashed":
			tally["crashed"] += 1
		elif patient.outcome == "left":
			tally["left"] += 1
		elif patient.is_here():
			tally["waiting"] += 1
	return tally


## Experience for one decision: a little for turning up, more for doing it
## well. Kept small so a busy casualty never outweighs the story.
static func xp_for(score: int) -> int:
	return 5 + score / 10
