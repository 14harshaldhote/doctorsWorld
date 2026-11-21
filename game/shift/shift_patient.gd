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
## "better", "worse", "harmed", "back", "fine", "crashed", "left" or "" (still here).
var outcome := ""
var score := 0
var leave_at := -1
## Back after being sent home wrongly.
var returning := false
## Severity marks already paged (75: looks worse).
var paged := {}
var look_seed := 0


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
	return ("Back · " + line) if returning else line


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
