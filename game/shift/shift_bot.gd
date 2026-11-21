class_name ShiftBot
extends RefCounted
## A doctor that plays casualty by itself, for tests and the autoplay that
## records screenshots. It works like a careful junior: sickest first, asks
## everything, examines, sends the key tests, waits for them, then decides.
##
## step() does one piece of work and returns the hospital minutes it took
## (1 when it only waited); the caller passes those minutes on the sim.

## right: choose the right plan (false: a wrong one, to test what follows).
static func step(sim: ShiftSim, right: bool = true) -> int:
	var seeing: Array[ShiftPatient] = []
	for patient in sim.patients:
		if patient.state == "seeing":
			seeing.append(patient)
	seeing.sort_custom(func(a: ShiftPatient, b: ShiftPatient) -> bool: return a.severity > b.severity)
	for patient in seeing:
		for question: String in ShiftPatient.QUESTIONS:
			if not patient.asked.has(question):
				sim.ask(patient, question)
				return ShiftSim.ASK_MINUTES
		if not patient.examined:
			sim.examine(patient)
			return ShiftSim.EXAM_MINUTES
		for test: String in patient.condition.get("key", []):
			if not patient.ordered.has(test):
				sim.order(patient, test)
				return ShiftSim.ORDER_MINUTES
		if patient.pending_tests().is_empty():
			sim.decide(patient, position_of(patient, right))
			return ShiftSim.DECIDE_MINUTES
	for patient in sim.board():
		if patient.state == "waiting" and sim.take(patient):
			return 1
	return 1


## Where the right (or a wrong) plan sits on the patient's card.
static func position_of(patient: ShiftPatient, right: bool) -> int:
	for position in patient.plan_order.size():
		if bool(patient.shown_plan(position).get("right", false)) == right:
			return position
	return 0


## Plays the shift on to a hospital minute.
static func play(sim: ShiftSim, until: int, right: bool = true) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	while sim.minute < until:
		var spent := step(sim, right)
		events.append_array(sim.advance_to(mini(until, sim.minute + maxi(1, spent))))
	return events
