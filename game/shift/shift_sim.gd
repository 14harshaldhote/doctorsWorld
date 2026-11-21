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
##   {"kind": "arrived" | "result" | "worse" | "crashed" | "left" | "back" |
##    "diverted" | "gone", "patient": ShiftPatient (or null), "text": String}
##
## Two random streams: one decides who walks in and when, the other
## everything the doctor's choices touch. So a day started again brings the
## same people at the same times, whatever was done differently.

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

## Who walks in, when, and what they have.
var arrivals: SeededRandom
## Everything else: how long people stay, when the wrongly sent home come
## back, who gives up waiting.
var rng: SeededRandom
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
var _start_minute := 0


func _init(seed_value: int = 1, start_minute: int = 8 * 60, shift_load: float = 1.0) -> void:
	arrivals = SeededRandom.new(seed_value)
	rng = SeededRandom.new(absi(hash("shift|%d" % seed_value)) % 1000003 + 1)
	minute = start_minute
	_start_minute = start_minute
	load = shift_load


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
		var patient := make_patient("")
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
			patient.results[test] = Conditions.result(patient.condition, test, patient.sex())
			events.append({"kind": "result", "patient": patient,
				"text": "%s's %s is back." % [patient.called(), str(Conditions.TESTS[test]["name"]).to_lower()]})
	if patient.severity >= WORSE_AT and not patient.paged.has("worse"):
		patient.paged["worse"] = true
		events.append({"kind": "worse", "patient": patient, "text": "%s %s looks worse." % [patient.called(), where_text(patient)]})
	if patient.severity >= CRASH_AT:
		patient.state = "gone"
		patient.cubicle = -1
		patient.outcome = "crashed"
		events.append({"kind": "crashed", "patient": patient,
			"text": "%s crashed %s. The crash team took them to intensive care." % [patient.called(), where_text(patient)]})
		return
	if patient.state == "waiting" and patient.triage() == "green" and patient.waited(minute) >= LEAVE_AFTER \
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


func _add(events: Array[Dictionary], patient: ShiftPatient) -> ShiftPatient:
	patients.append(patient)
	var text := "New in casualty: %s." % patient.board_line()
	if patient.triage() == "red":
		text = "Red in casualty: %s." % patient.board_line()
	events.append({"kind": "arrived", "patient": patient, "text": text})
	return patient


func make_patient(condition_id: String = "") -> ShiftPatient:
	var id := condition_id if not Conditions.get_condition(condition_id).is_empty() else Conditions.pick(arrivals, recent)
	recent.append(id)
	while recent.size() > RECENT:
		recent.pop_front()
	var condition := Conditions.get_condition(id)
	var patient := ShiftPatient.new()
	patient.id = next_id
	next_id += 1
	patient.condition_id = id
	patient.condition = condition
	var ages: Array = condition.get("age", [20, 60])
	patient.age = arrivals.next_int_in(int(ages[0]), int(ages[1]))
	var sex := str(condition.get("sex", ""))
	patient.person = NameMaker.make(arrivals, sex, patient.age)
	var starts: Array = condition.get("start", [20, 30])
	patient.severity = float(arrivals.next_int_in(int(starts[0]), int(starts[1])))
	patient.worsens = float(condition.get("worsens", 4)) * arrivals.range_float(0.8, 1.2)
	patient.vitals = _roll_vitals(condition.get("vitals", {}))
	patient.arrived_at = minute
	patient.look_seed = arrivals.next()
	var order := [0, 1, 2, 3]
	patient.plan_order = arrivals.shuffled(order.slice(0, (condition.get("plans", []) as Array).size()))
	return patient


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
	patient.plan = int(patient.plan_order[position])
	var right := bool(chosen.get("right", false))
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
			patient.severity = minf(CRASH_AT - 1.0, patient.severity + 25.0)
		"back":
			patient.outcome = "back"
			_send_back(patient)
		_:
			patient.outcome = "worse"
	return {"right": right, "why": str(chosen.get("why", "")), "effect": effect, "score": patient.score,
		"plan": str(chosen.get("text", ""))}


## Sent home wrongly: they come back later in the shift, worse, if there's
## shift left for it.
func _send_back(patient: ShiftPatient) -> void:
	var back := ShiftPatient.new()
	back.id = next_id
	next_id += 1
	back.person = patient.person
	back.age = patient.age
	back.condition_id = patient.condition_id
	back.condition = patient.condition
	back.vitals = patient.vitals.duplicate()
	back.severity = minf(90.0, patient.severity + 25.0)
	back.worsens = patient.worsens * 1.2
	back.returning = true
	back.look_seed = patient.look_seed
	back.plan_order = patient.plan_order.duplicate()
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
	return clampi(points - mini(10, waste), 0, 100)


## The shift's tally for the handover card.
func summary() -> Dictionary:
	var tally := {"seen": 0, "right": 0, "wrong": 0, "crashed": 0, "left": 0, "waiting": 0, "points": 0,
		"diverted": diverted}
	for patient in patients:
		if patient.decided():
			tally["seen"] += 1
			tally["points"] += patient.score
			if patient.outcome in ["better"]:
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
