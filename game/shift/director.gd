class_name Director
extends RefCounted
## The shift's pacing (stage 26), the way good TV paces an episode. It keeps
## a feel for how hard the shift has been (tension): a red arrival, someone
## turning, a crash or a death push it up, and it settles minute by minute,
## more slowly while people are waiting. From that:
##
##   a breather   after a hard stretch: a cup of chai, a bad joke, the radio
##                (a "lift"), no trouble for a while, and the patient nobody
##                could save held back until it's over
##   trouble      after a long quiet stretch: an ambulance the day's own
##                arrivals didn't bring (made from this stream, so they stay
##                the same)
##   silliness    in the middle of something serious, at most one per serious
##                scene, and not often: a goat, a relative after the Wi-Fi
##   a moment     an emotional one a few times a week, never on a schedule,
##                with someone who's here, when the shift is calm enough
##
## Rules and numbers in story/feelings.json (Feelings). Pure rules on
## hospital minutes, like ShiftSim, which steps it once a minute and adds
## what it decides to the events:
##   {"kind": "lift", "lift": id, "text"}
##   {"kind": "silly", "silly": id, "patient": the serious one, "text"}
##   {"kind": "moment", "moment": id, "patient": who it's with (or null), "text"}
## and trouble as an ordinary "arrived" event.

## How hard the shift feels, 0 to 100.
var tension := 0.0
## Minutes in a row the shift has been calm with next to nobody waiting.
var quiet := 0
## Breathers, trouble, silliness and the moment, so far today.
var lifts := 0
var troubles := 0
var sillies := 0
var moments := 0
## Until this minute, no trouble (a breather).
var breather_until := -1
## The minute the day's moment is due (-1: none today).
var moment_at := -1
## The day's window for its moment: from, until (it stops looking for
## someone it fits after that).
var moment_from := -1
var moment_until := -1
## Moments seen on earlier days: id -> the day (kept by the ward in the
## profile), so the same one doesn't come back for a while.
var seen := {}
## The career's story flags (the ward passes the profile's own), for lifts
## that remember what the doctor did ("if").
var flags := {}
## [minute, event] still to come.
var pending: Array = []
## Lifts and silliness used today, by id.
var used := {}
var rng: SeededRandom

var _last_trouble := -100000
var _last_silly := -100000
var _hard := false
## Patients a serious scene was already counted for (one silly each at most).
var _scenes := {}
## Patients already looked at for the moment that needs an admission.
var _looked := {}


func _init(seed_value: int = 1) -> void:
	rng = SeededRandom.new(absi(hash("director|%d" % seed_value)) % 1000003 + 1)


## The day's moment, if today has one: a few days a week, at a time the
## stream picks in the shift's window.
func plan(day: int, start_minute: int) -> void:
	if day < int(Feelings.rule("moment_from_day", 5)) or not rng.chance(float(Feelings.rule("moment_chance", 0.4))):
		return
	var window: Array = Feelings.rule("moment_window", [80, 560])
	moment_at = start_minute + rng.next_int_in(int(window[0]), int(window[1]) - 60)
	moment_from = start_minute + int(window[0])
	moment_until = start_minute + int(window[1])


## One hospital minute: what happened in it (events from index first on)
## moves the tension, then the director decides.
func step(sim: ShiftSim, events: Array[Dictionary], first: int) -> void:
	for index in range(first, events.size()):
		_note(sim, events[index])
	var waiting := sim.waiting().size()
	tension = maxf(0.0, tension - float(Feelings.rule("decay", 0.35)) / (1.0 + float(Feelings.rule("busy_hold", 0.12)) * waiting))
	var hard := float(Feelings.rule("hard", 55))
	if tension >= hard:
		_hard = true
	elif _hard and tension < hard * 0.5:
		_breather(sim)
	if tension < float(Feelings.rule("calm", 14)) and waiting <= 1:
		quiet += 1
	else:
		quiet = 0
	_maybe_trouble(sim, events)
	_maybe_moment(sim, events)
	for index in range(pending.size() - 1, -1, -1):
		if int(pending[index][0]) <= sim.minute:
			var due: Dictionary = pending[index][1]
			pending.remove_at(index)
			var patient: ShiftPatient = due.get("patient")
			if str(due["kind"]) == "silly" and patient != null and not patient.is_here() and patient.outcome != "died":
				continue
			events.append(due)


func _note(sim: ShiftSim, event: Dictionary) -> void:
	var push: Dictionary = Feelings.rule("tension", {})
	var kind := str(event.get("kind", ""))
	var patient: ShiftPatient = event.get("patient")
	var serious := false
	match kind:
		"arrived":
			var triage := patient.triage() if patient != null else "green"
			tension += float(push.get("arrived_" + triage, 0.0))
			serious = triage == "red"
		"worse", "critical", "back", "diverted":
			tension += float(push.get(kind, 0.0))
		"crashed", "died":
			tension += float(push.get(kind, 0.0))
			serious = true
	tension = minf(100.0, tension)
	if serious and patient != null and not _scenes.has(patient.id):
		_scenes[patient.id] = true
		_maybe_silly(sim, patient)


## After a hard stretch: something kind or funny soon, no trouble for a
## while, and the patient nobody could save held back till it's over.
func _breather(sim: ShiftSim) -> void:
	_hard = false
	breather_until = sim.minute + int(Feelings.rule("breather_minutes", 90))
	if sim.doomed_at >= 0 and sim.doomed_at < breather_until:
		sim.doomed_at = breather_until + rng.next_int_in(10, 40)
	if lifts >= int(Feelings.rule("lift_max", 2)):
		return
	var id := Feelings.pick_lift(rng, flags, sim.day, used)
	if id.is_empty():
		return
	lifts += 1
	used[id] = true
	var delay: Array = Feelings.rule("lift_delay", [6, 14])
	pending.append([sim.minute + rng.next_int_in(int(delay[0]), int(delay[1])),
		{"kind": "lift", "lift": id, "patient": null, "text": Feelings.lift_text(id)}])


func _maybe_silly(sim: ShiftSim, patient: ShiftPatient) -> void:
	if sillies >= int(Feelings.rule("silly_max", 2)) or sim.minute - _last_silly < int(Feelings.rule("silly_gap", 110)):
		return
	if not rng.chance(float(Feelings.rule("silly_chance", 0.45))):
		return
	var id := Feelings.pick_silly(rng, sim.day, used)
	if id.is_empty():
		return
	sillies += 1
	_last_silly = sim.minute
	used[id] = true
	var delay: Array = Feelings.rule("silly_delay", [2, 6])
	pending.append([sim.minute + rng.next_int_in(int(delay[0]), int(delay[1])),
		{"kind": "silly", "silly": id, "patient": patient, "text": Feelings.silly_text(id)}])


## A long quiet stretch brings an ambulance the day's arrivals didn't.
func _maybe_trouble(sim: ShiftSim, events: Array[Dictionary]) -> void:
	if sim.day < int(Feelings.rule("trouble_from_day", 6)) or quiet < int(Feelings.rule("quiet_minutes", 85)):
		return
	if sim.minute < breather_until or troubles >= int(Feelings.rule("trouble_max", 2)) \
			or sim.minute - _last_trouble < int(Feelings.rule("trouble_gap", 150)):
		return
	var options := []
	for id: String in Conditions.ids():
		var triage := str(Conditions.get_condition(id).get("triage", ""))
		if triage in ["yellow", "red"] and Conditions.can_walk_in(id, sim.day) and not id in sim.recent:
			options.append(id)
	if options.is_empty():
		return
	options.sort()
	troubles += 1
	quiet = 0
	_last_trouble = sim.minute
	var patient := sim.make_aside_from(rng, str(rng.pick(options)))
	patient.trouble = true
	sim.add_patient(events, patient)


## The day's moment, once it's due and the shift is calm enough, with
## someone it fits (it waits a little while nobody does). An old man going
## up to the ward with a son in a hurry can bring it on early.
func _maybe_moment(sim: ShiftSim, events: Array[Dictionary]) -> void:
	if moment_at < 0 or moments > 0:
		return
	if sim.minute > moment_until:
		moment_at = -1
		return
	var calm := tension < float(Feelings.rule("moment_calm", 35))
	if calm and sim.minute >= moment_from:
		for patient in sim.patients:
			if patient.is_here() and patient.decided() and not _looked.has(patient.id):
				_looked[patient.id] = true
				if Feelings.fits("papers", patient) and not _recent("papers", sim.day):
					_fire(sim, events, "papers", patient)
					return
	if sim.minute < moment_at:
		return
	if not calm:
		return
	var found := Feelings.pick_moment(rng, sim, seen)
	if found.is_empty():
		moment_at = sim.minute + 20
		return
	_fire(sim, events, str(found["id"]), found.get("patient"))


func _fire(_sim: ShiftSim, events: Array[Dictionary], id: String, patient: ShiftPatient) -> void:
	moments += 1
	moment_at = -1
	events.append({"kind": "moment", "moment": id, "patient": patient, "text": Feelings.moment_title(id)})


func _recent(id: String, day: int) -> bool:
	return seen.has(id) and day - int(seen[id]) < Feelings.MOMENT_REST
