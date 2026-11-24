class_name ShiftPatient
extends RefCounted
## One person in casualty: who they are, what they have, and what you've
## done for them so far. Made by ShiftSim from a seed; nothing here draws.
##
## severity runs from 0 (fine) to 100 (crashing). It climbs by the
## condition's "worsens" points an hour until the right plan is chosen,
## then falls. The board never shows the number: it shows the triage colour
## and how long they've waited, and the nurse pages you if they turn.

## The three things you can ask, in order.
const QUESTIONS := ["pain", "when", "other"]
const QUESTION_TEXT := {
	"pain": "What's the trouble?",
	"when": "Since when?",
	"other": "Anything else? Medicines, illnesses?",
}

var id := 0
var person := {}
var age := 40
var condition_id := ""
var condition := {}
var vitals := {}
var severity := 0.0
var worsens := 0.0
var arrived_at := 0
## "waiting", "seeing" (in a cubicle), "done" (plan chosen, about to leave)
## or "gone".
var state := "waiting"
var cubicle := -1
var asked := {}
var examined := false
## test -> the minute its result is ready
var ordered := {}
## test -> result text, once it's back
var results := {}
## The order the four plans are shown in (indexes into the condition's plans).
var plan_order: Array = []
var plan := -1
## "better", "worse", "harmed", "back", "fine", "crashed" (to intensive
## care), "died", "left" or "" (still here).
var outcome := ""
## Whose fault a death was (Fates.FAULTS), once outcome is "died".
var fault := ""
## Beyond saving whatever is done (Fates.doomed()): nobody's fault.
var doomed := false
## Waiting since before the shift, and left out of the handover.
var forgotten := false
## A result the lab rang about: {test, error (a Fates lab error kind, or ""
## for a real one), answer ("", "repeat" or "treat")}, or {}.
var alert := {}
## A wrong result caught by repeating it.
var caught := false
var score := 0
var leave_at := -1
## Back after being sent home wrongly.
var returning := false
## Severity marks already paged (75: looks worse).
var paged := {}
var look_seed := 0
## "early", or "late": the illness further along and worse (PatientMaker).
var stage := "early"
## A mix or twist that changes the right plan (PatientParts.extras()), or "".
var extra := ""
## True when it isn't on the card and has to be caught.
var extra_hidden := false
## Who came in with them: {relation, first, full, sex, age}, or {} alone.
var company := {}
## Who answers the questions: "self", "parent" (a small child's) or
## "colleague" (the workmate who brought them in).
var speaker := "self"
## Their temper (PatientParts.personalities()) and the recorded voice the
## answers are said in (PatientVoices).
var personality := "calm"
var voice := ""
## How long they'll wait before walking out, as a share of the usual.
var patience := 1.0
var job := ""
## An invented illness from an outbreak, labelled as made up.
var invented := false
## Met on an earlier day: their record's id, the day, and what it was for.
var known_id := ""
var known_day := 0
var known_what := ""
## Back with the same trouble because it went wrong last time.
var complication := false
## Brought by the director after a quiet stretch (stage 26).
var trouble := false


func full_name() -> String:
	return str(person.get("full", "Patient"))


func called() -> String:
	return NameMaker.called(person, age)


func sex() -> String:
	return str(person.get("sex", "m"))


func triage() -> String:
	return str(condition.get("triage", "green"))


func waited(now: int) -> int:
	return maxi(0, now - arrived_at)


func plans() -> Array:
	return condition.get("plans", [])


## The plan shown at a position on the card.
func shown_plan(position: int) -> Dictionary:
	if position < 0 or position >= plan_order.size():
		return {}
	return plans()[int(plan_order[position])]


func is_here() -> bool:
	return state != "gone"


func decided() -> bool:
	return plan >= 0


## The board's line: "Mr. Patil, 54 · Back pain going down to the groin".
func board_line() -> String:
	var line := "%s, %d · %s" % [called(), age, str(condition.get("board", ""))]
	if forgotten and not examined and asked.is_empty():
		return Fates.forgotten_line("board") + " · " + line
	if returning:
		return "Back · " + line
	if known_day > 0:
		return "Seen on Day %d · %s" % [known_day, line]
	return line


## "his", "her".
func their() -> String:
	return "her" if sex() == "f" else "his"


## "him", "her".
func them() -> String:
	return "her" if sex() == "f" else "him"


## Who they are, under their name: "Auto driver from Satara · with his
## wife, Pallavi".
func about_line() -> String:
	var parts := PackedStringArray()
	var home := str(person.get("home", ""))
	if not job.is_empty():
		parts.append("%s from %s" % [job.substr(0, 1).to_upper() + job.substr(1), home] if not home.is_empty() else job)
	elif not home.is_empty():
		parts.append("From %s" % home)
	if not company.is_empty():
		parts.append("with %s %s, %s" % [their(), str(company.get("relation", "")), str(company.get("first", ""))])
	return " · ".join(parts)


## What the card says up front: a mix that's known ("Known: on warfarin
## for a heart valve"), and a patient met before.
func known_line() -> String:
	var parts := PackedStringArray()
	var known := str(condition.get("known", ""))
	if not known.is_empty():
		parts.append("Known: " + known.substr(0, 1).to_lower() + known.substr(1) + ".")
	if known_day > 0:
		var what := (", for " + known_what) if not known_what.is_empty() else ""
		parts.append("You saw them on Day %d%s." % [known_day, what])
		if complication:
			parts.append("It never really settled.")
	return " ".join(parts)


## Who answers for them, when it isn't them: "His mother, Sana, answers."
func answered_by() -> String:
	if speaker == "self" or company.is_empty():
		return ""
	var who := "%s %s, %s" % [their(), str(company.get("relation", "")), str(company.get("first", ""))]
	return who.substr(0, 1).to_upper() + who.substr(1) + ", answers."


## A copy that comes back later the same day (sent home wrongly): the same
## person, illness and words.
func copy_for_return() -> ShiftPatient:
	var back := ShiftPatient.new()
	for key: String in ["person", "age", "condition_id", "condition", "vitals", "look_seed", "plan_order", "stage",
			"extra", "extra_hidden", "company", "speaker", "personality", "voice", "patience", "job", "invented",
			"known_id", "known_day", "known_what", "complication"]:
		var value: Variant = get(key)
		back.set(key, value.duplicate(true) if value is Dictionary or value is Array else value)
	return back


## A lab call still waiting for the doctor's answer.
func alert_open() -> bool:
	return not alert.is_empty() and str(alert.get("answer", "")).is_empty()


## Results still to come, as test ids.
func pending_tests() -> Array:
	var found := []
	for test: String in ordered:
		if not results.has(test):
			found.append(test)
	return found


## The vitals as the monitor shows them: "Pulse 104 · BP 112/70 · ..."
func vitals_line() -> String:
	return "Pulse %d · BP %d/%d · Temp %.1f · SpO2 %d%% · Breaths %d" % [
		int(vitals.get("pulse", 80)), int(vitals.get("bp", 120)), int(vitals.get("dia", 78)),
		float(vitals.get("temp", 37.0)), int(vitals.get("spo2", 98)), int(vitals.get("breaths", 16))]
