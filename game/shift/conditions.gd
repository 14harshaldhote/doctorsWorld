class_name Conditions
extends RefCounted
## The illnesses that walk into casualty (story/conditions.json) and the
## tests that can be ordered for them.
##
## A condition says how the patient looks (vitals ranges), what they say
## when asked, what an examination finds, which tests come back abnormal and
## what they show, and four plans: one right, three wrong, each wrong one with
## what it does (worse, harm, back, lucky) and why. A test the condition
## doesn't list comes back normal. Medicine is never made up at run time:
## everything a patient shows comes from this file.

## Tests: name, hospital minutes until the result, what a needless one
## costs the score, and the normal result.
const TESTS := {
	"sugar": {"name": "Finger-prick sugar", "minutes": 2, "cost": 0, "normal": "Sugar 112 mg/dL, normal."},
	"ecg": {"name": "ECG", "minutes": 5, "cost": 0, "normal": "Normal rhythm. No changes."},
	"urine": {"name": "Urine dip and pregnancy test", "minutes": 5, "cost": 0, "normal": "Clear."},
	"gas": {"name": "Blood gas", "minutes": 10, "cost": 1, "normal": "Normal blood gas."},
	"clot": {"name": "20-minute clotting test", "minutes": 20, "cost": 0, "normal": "Clotted within 20 minutes. Normal."},
	"rapid": {"name": "Malaria and dengue tests", "minutes": 15, "cost": 1, "normal": "Malaria and dengue tests negative."},
	"bloods": {"name": "Blood count and chemistry", "minutes": 20, "cost": 1, "normal": "Blood count and chemistry normal."},
	"xray": {"name": "X-ray", "minutes": 30, "cost": 2, "normal": "Normal X-ray."},
	"usg": {"name": "Ultrasound", "minutes": 30, "cost": 2, "normal": "Normal ultrasound."},
	"ct": {"name": "CT scan", "minutes": 60, "cost": 4, "normal": "Normal CT."},
}
## The order tests are offered in: quick and cheap first.
const ORDER := ["sugar", "ecg", "urine", "gas", "clot", "rapid", "bloods", "xray", "usg", "ct"]
## Where a patient goes after the right plan, as the board says it.
const DESTINATIONS := {
	"theatre": "to theatre", "admit": "admitted to the ward", "home": "home", "icu": "to intensive care",
	"cath": "to the cath lab", "refer": "to neurosurgery", "tb_clinic": "to the TB clinic",
	"labour": "to the labour room", "burns": "to the burns unit", "isolation": "to the isolation ward",
}
const TRIAGE := ["red", "yellow", "green"]


static func all() -> Dictionary:
	return StoryBook.chapter("conditions")


static func ids() -> Array:
	var found := all().keys()
	found.sort()
	return found


static func get_condition(id: String) -> Dictionary:
	var found: Variant = all().get(id)
	return found if typeof(found) == TYPE_DICTIONARY else {}


## What a test shows for this condition: its own result, or the normal one.
## A woman's urine dip says the pregnancy test was negative too.
static func result(condition: Dictionary, test: String, sex: String) -> String:
	var own: Dictionary = condition.get("results", {})
	if own.has(test):
		return str(own[test])
	var normal := str(TESTS[test]["normal"])
	if test == "urine" and sex == "f":
		return "Clear. Pregnancy test negative."
	return normal


## A test that shows something, or one the condition counts as key.
static func useful(condition: Dictionary, test: String) -> bool:
	return (condition.get("results", {}) as Dictionary).has(test) or test in (condition.get("key", []) as Array)


## How often a condition walks in, next to the others (its "weight").
static func weight(id: String) -> int:
	return int(get_condition(id).get("weight", 0))


## True when a condition can walk in on this day, for someone this age and
## sex (age -1 and sex "" mean anyone).
static func can_walk_in(id: String, day: int, age: int = -1, sex: String = "") -> bool:
	var condition := get_condition(id)
	if condition.is_empty() or weight(id) <= 0 or day < int(condition.get("from_day", 0)):
		return false
	var ages: Array = condition.get("age", [0, 120])
	if age >= 0 and (age < int(ages[0]) or age > int(ages[1])):
		return false
	var only := str(condition.get("sex", ""))
	return sex.is_empty() or only.is_empty() or only == sex


## A condition id picked by weight, never one of `avoid`: only ones that can
## walk in on the day (rarer and harder ones join as the career goes on),
## for someone this age and sex when given. extra adds ids with weights of
## their own (an invented outbreak).
static func pick(rng: SeededRandom, avoid: Array = [], day: int = 9999, extra: Dictionary = {}, age: int = -1,
		sex: String = "") -> String:
	var options := []
	for id: String in ids():
		if id not in avoid and can_walk_in(id, day, age, sex):
			options.append([id, weight(id)])
	var added := extra.keys()
	added.sort()
	for id: String in added:
		if id not in avoid and int(extra[id]) > 0:
			options.append([id, int(extra[id])])
	var total := 0
	for option: Array in options:
		total += int(option[1])
	if total <= 0:
		return "gastro"
	var roll := rng.next_int(total)
	for option: Array in options:
		roll -= int(option[1])
		if roll < 0:
			return str(option[0])
	return "gastro"
