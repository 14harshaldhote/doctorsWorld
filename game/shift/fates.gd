class_name Fates
extends RefCounted
## What casualty's mistakes cost (story/mistakes.json): how likely a crash
## or a harmful plan is to kill, the patients nobody could save, the lab's
## wrong results and critical calls, the nurse's read-back, the bed the
## handover forgot, and the family, the morgue and the wall after a death.
## Read once and kept. ShiftSim rolls the dice; this only holds the rules.
##
## A death has a fault, which the wall shows:
##   "you"     a plan that did harm
##   "wait"    crashed before a doctor got to them
##   "lab"     a wrong result, treated without a repeat
##   "team"    a drug that went to the wrong cubicle on a nodded read-back
##   "nobody"  beyond saving, whatever was done

const FAULTS := ["you", "wait", "lab", "team", "nobody"]
## The most names the wall keeps (the oldest come down first).
const WALL_KEEP := 200
## What the family can be told, in the order the buttons show.
const TELLINGS := ["plain", "jargon", "nurse"]


static func data() -> Dictionary:
	return StoryBook.chapter("mistakes")


static func chance(key: String) -> float:
	return float((data().get("chances", {}) as Dictionary).get(key, 0.0))


## A day the shift can bring this from ("doomed_from_day", ...).
static func from_day(key: String) -> int:
	return int((data().get("chances", {}) as Dictionary).get(key, 9999))


## The wall's short reason for a fault: "Your call", "Nobody's fault".
static func fault_text(fault: String) -> String:
	return str((data().get("faults", {}) as Dictionary).get(fault, ""))


## Conditions that can come in beyond saving, and why they died.
static func doomed() -> Dictionary:
	return data().get("doomed", {})


static func doomed_why(condition_id: String) -> String:
	return str(doomed().get(condition_id, "Nobody could have stopped this."))


## The test whose real result makes the lab ring for this condition, or "".
static func critical_test(condition_id: String) -> String:
	return str((data().get("critical", {}) as Dictionary).get(condition_id, ""))


static func lab_errors() -> Dictionary:
	return data().get("lab_errors", {})


## The kinds of wrong result a test can come back with, sorted.
static func errors_for(test: String) -> Array:
	var found := []
	var all := lab_errors()
	for kind: String in all:
		if test in ((all[kind] as Dictionary).get("tests", []) as Array):
			found.append(kind)
	found.sort()
	return found


## One line about a lab result: "result", "call", "treat" or "repeat", for a
## wrong one (kind) or a real critical one (kind "").
static func lab_line(kind: String, part: String, patient_called: String) -> String:
	var source: Dictionary = (lab_errors().get(kind, {}) as Dictionary) if not kind.is_empty() else data().get("real_critical", {})
	return str(source.get(part, "")).replace("{patient}", patient_called)


static func readback_line(part: String, values: Dictionary) -> String:
	return _fill(str((data().get("readback", {}) as Dictionary).get(part, "")), values)


static func forgotten_line(part: String) -> String:
	return str((data().get("forgotten", {}) as Dictionary).get(part, ""))


static func family() -> Dictionary:
	return data().get("family", {})


## The family's lines of one kind ("open", "plain", "jargon", "nurse").
static func family_lines(kind: String) -> Array:
	return (family().get(kind, []) as Array).duplicate()


## Every line a family member can say, for the recordings.
static func family_spoken() -> Array:
	var found := []
	for kind: String in ["open"] + TELLINGS:
		for line: Variant in family_lines(kind):
			found.append(str(line))
	return found


static func telling_text(telling: String) -> String:
	return str((family().get("choices", {}) as Dictionary).get(telling, ""))


static func after_text(telling: String) -> String:
	return str((family().get("after", {}) as Dictionary).get(telling, ""))


static func family_fault_text(fault: String) -> String:
	return str((family().get("fault", {}) as Dictionary).get(fault, ""))


static func morgue_text(patient_called: String) -> String:
	return str(family().get("morgue", "")).replace("{patient}", patient_called)


static func _fill(text: String, values: Dictionary) -> String:
	for key: String in values:
		text = text.replace("{%s}" % key, str(values[key]))
	return text


# --- The wall -----------------------------------------------------------------

## The wall's record of a death: who, how old, which day, what of, and whose
## fault.
static func wall_entry(patient: ShiftPatient, day: int) -> Dictionary:
	var what := str(patient.condition.get("name", "")) if not patient.invented else "an invented fever"
	return {"full": patient.full_name(), "age": patient.age, "day": day, "what": what, "fault": patient.fault}


## Adds a death to the wall (newest last, at most WALL_KEEP).
static func add_to_wall(wall: Array, entry: Dictionary) -> void:
	wall.append(entry)
	while wall.size() > WALL_KEEP:
		wall.pop_front()


## The wall from a save, kept only if every field is the right kind and
## sensible (an edited save can't smuggle in anything else).
static func clean_wall(raw: Variant) -> Array:
	var kept := []
	if typeof(raw) != TYPE_ARRAY:
		return kept
	for item: Variant in raw:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var entry := {}
		var good := true
		for key: String in ["full", "what", "fault"]:
			var value: Variant = (item as Dictionary).get(key, "")
			if typeof(value) != TYPE_STRING or (value as String).length() > 60:
				good = false
				break
			entry[key] = value
		for key: String in ["age", "day"]:
			var value: Variant = (item as Dictionary).get(key, 0)
			if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
				good = false
				break
			entry[key] = clampi(int(value), 0, 100000)
		if good and str(entry["fault"]) in FAULTS and not str(entry["full"]).is_empty():
			kept.append(entry)
	while kept.size() > WALL_KEEP:
		kept.pop_front()
	return kept
