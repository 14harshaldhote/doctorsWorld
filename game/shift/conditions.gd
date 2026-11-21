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
## How often each condition walks in, out of the total.
const WEIGHTS := {
	"gastro": 10, "renal_colic": 8, "wrist_fracture": 7, "chest_wall": 7, "dengue": 7, "pneumonia": 6,
	"appendicitis": 6, "malaria": 5, "asthma": 5, "heart_attack": 5, "dka": 3, "viper_bite": 3, "brain_bleed": 3,
	"ectopic": 3,
}
## Where a patient goes after the right plan, as the board says it.
const DESTINATIONS := {
	"theatre": "to theatre", "admit": "admitted to the ward", "home": "home", "icu": "to intensive care",
	"cath": "to the cath lab", "refer": "to neurosurgery",
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


## A condition id, picked by WEIGHTS, never one of `avoid`.
static func pick(rng: SeededRandom, avoid: Array = []) -> String:
	var total := 0
	for id: String in WEIGHTS:
		if id not in avoid:
			total += int(WEIGHTS[id])
	var roll := rng.next_int(maxi(1, total))
	for id: String in WEIGHTS:
		if id in avoid:
			continue
		roll -= int(WEIGHTS[id])
		if roll < 0:
			return id
	return "gastro"
