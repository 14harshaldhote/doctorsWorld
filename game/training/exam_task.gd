class_name ExamTask
extends TrainingTask
## Examine a patient: tap places on their body to look, press, listen or
## check, write down what is found, then say what is wrong.
##
## Each case lives in story/cases.json (a "kind": "exam" entry), so new
## patients need no code. A spot can be a key finding, a useful one, or
## nothing; a sore spot pressed before the gentle ones costs the patient's
## comfort (examine away from the pain first). Some cases are emergencies:
## the patient is bleeding, the monitor shows it, and a spot with
## "act": "pressure" stops it. Time only passes through tick().

const KEY_POINTS := 55
const DIAGNOSIS_POINTS := 30
const CARE_POINTS := 15
const WASTED_COST := 4
## How fast an emergency is expected to be controlled, in seconds.
const QUICK := 8.0
## Stability never drops below this inside the task: someone senior arrives.
const FLOOR := 25.0

var case_id := ""
var patient := ""
var about := ""
## The patient's cast id, for their name and voice.
var actor := ""
var opening := ""
## What the station shows: "belly" (lying), "wrist" (sitting) or "trauma".
var body := "belly"
var spots: Array[Dictionary] = []
var diagnoses: Array[Dictionary] = []
var him := "him"
var his := "his"

## "examine", then "decide", then "done".
var phase := "examine"
var examined: Array[String] = []
var facts: Array[String] = []
## The last finding, and the patient's words about it ("" if none).
var last_finding := ""
var last_said := ""
var chosen := ""
var hurt_first := false
## Emergencies: stability falls while bleeding, until pressure is on.
var has_vitals := false
var vitals := Vitals.new()
var stability := 100.0
var bleed := 0.0
var pressure_at := -1.0


func _init(which_case: String = "lakshmi_exam") -> void:
	id = "exam"
	case_id = which_case
	var data: Dictionary = StoryBook.chapter("cases").get(which_case, {})
	patient = str(data.get("patient", "The patient"))
	about = str(data.get("about", ""))
	actor = str(data.get("actor", ""))
	opening = str(data.get("opening", ""))
	body = str(data.get("body", "belly"))
	him = str(data.get("him", "him"))
	his = str(data.get("his", "his"))
	for entry: Variant in data.get("spots", []):
		if typeof(entry) == TYPE_DICTIONARY:
			spots.append(entry)
	for entry: Variant in data.get("diagnoses", []):
		if typeof(entry) == TYPE_DICTIONARY:
			diagnoses.append(entry)
	has_vitals = bool(data.get("vitals", false))
	bleed = float(data.get("bleed", 0.0))
	if has_vitals:
		stability = float(data.get("stability", 70.0))
		_show_vitals()
	_say(opening)


func title() -> String:
	# "Examine the rider", not "Examine The rider".
	var who := patient.substr(0, 1).to_lower() + patient.substr(1) if patient.begins_with("The ") else patient
	return "Examine " + who


func spot(spot_id: String) -> Dictionary:
	for entry in spots:
		if str(entry.get("id", "")) == spot_id:
			return entry
	return {}


func is_examined(spot_id: String) -> bool:
	return spot_id in examined


func bleeding() -> bool:
	return bleed > 0.0 and pressure_at < 0.0


func tick(delta: float) -> void:
	if finished:
		return
	super.tick(delta)
	if bleeding():
		stability = maxf(FLOOR, stability - bleed * delta)
		_show_vitals()


## Examines a spot. Returns the finding ("" if it can't be examined now).
func examine(spot_id: String) -> String:
	if finished or phase != "examine" or is_examined(spot_id):
		return ""
	var entry := spot(spot_id)
	if entry.is_empty():
		return ""
	if bool(entry.get("sore", false)) and not _gentle_done():
		hurt_first = true
	examined.append(spot_id)
	last_finding = str(entry.get("finding", ""))
	last_said = str(entry.get("says", ""))
	if entry.has("fact"):
		facts.append(str(entry["fact"]))
	if str(entry.get("act", "")) == "pressure" and pressure_at < 0.0:
		pressure_at = elapsed
		stability = minf(100.0, stability + 10.0)
		_show_vitals()
	var line := last_said if not last_said.is_empty() else last_finding
	_say(line, bool(entry.get("sore", false)) and hurt_first and examined.size() == 1)
	return last_finding


## Enough examining: show the choices for what is wrong.
func ready_to_decide() -> void:
	if finished or phase != "examine" or examined.is_empty():
		return
	phase = "decide"
	_say("Enough looking. What's wrong with %s?" % him)
	changed.emit()


## Picks what is wrong and finishes the examination.
func decide(diagnosis_id: String) -> void:
	if finished or phase != "decide":
		return
	var entry := diagnosis(diagnosis_id)
	if entry.is_empty():
		return
	chosen = diagnosis_id
	phase = "done"
	_write_notes()
	_finish()


func diagnosis(diagnosis_id: String) -> Dictionary:
	for entry in diagnoses:
		if str(entry.get("id", "")) == diagnosis_id:
			return entry
	return {}


func right_diagnosis() -> String:
	for entry in diagnoses:
		if bool(entry.get("right", false)):
			return str(entry.get("id", ""))
	return ""


func diagnosed_right() -> bool:
	return not chosen.is_empty() and chosen == right_diagnosis()


func keys_found() -> int:
	var found := 0
	for spot_id in examined:
		if str(spot(spot_id).get("weight", "")) == "key":
			found += 1
	return found


func key_count() -> int:
	var count := 0
	for entry in spots:
		if str(entry.get("weight", "")) == "key":
			count += 1
	return count


func wasted() -> int:
	var count := 0
	for spot_id in examined:
		if str(spot(spot_id).get("weight", "")) == "none":
			count += 1
	return count


## The last part of the score: kindness for a belly, speed for an emergency.
func care_points() -> int:
	if bleed > 0.0:
		if pressure_at < 0.0:
			return 0
		return CARE_POINTS if pressure_at <= QUICK else int(CARE_POINTS * clampf(1.0 - (pressure_at - QUICK) / 20.0, 0.0, 1.0))
	return 0 if hurt_first else CARE_POINTS


func score() -> int:
	var keys := key_count()
	var points := KEY_POINTS * keys_found() / maxf(1.0, keys)
	points += DIAGNOSIS_POINTS if diagnosed_right() else 0
	points += care_points()
	points -= WASTED_COST * maxi(0, wasted() - 1)
	return clampi(int(round(points)), 0, 100)


func instruction() -> String:
	match phase:
		"examine":
			if bleeding():
				return "%s is bleeding. Find it and stop it" % _pronoun_subject().capitalize()
			return "Tap where to examine · %d of %d key findings" % [keys_found(), key_count()]
		"decide":
			return "What is wrong with %s?" % him
	return "Done"


func progress() -> float:
	if finished:
		return 1.0
	return 0.8 * keys_found() / maxf(1.0, key_count())


## Gentle spots are the ones that are not sore, on the same part of the body.
func _gentle_done() -> bool:
	for spot_id in examined:
		var entry := spot(spot_id)
		if bool(entry.get("gentle", false)):
			return true
	var any_gentle := false
	for entry in spots:
		if bool(entry.get("gentle", false)):
			any_gentle = true
	return not any_gentle


func _show_vitals() -> void:
	var weak := 1.0 - clampf(stability / 100.0, 0.0, 1.0)
	vitals.hr = int(round(84 + 60 * weak))
	vitals.systolic = int(round(124 - 60 * weak))
	vitals.diastolic = int(round(78 - 34 * weak))
	vitals.spo2 = int(round(99 - 8 * weak))
	vitals.rr = int(round(15 + 12 * weak))


func _write_notes() -> void:
	var keys := key_count()
	var found := keys_found()
	_note(found == keys, "You found %d of the %d findings that matter." % [found, keys])
	for entry in spots:
		if str(entry.get("weight", "")) == "key" and not is_examined(str(entry.get("id", ""))):
			_note(false, str(entry.get("why", "You missed: %s." % entry.get("fact", entry.get("label", "")))))
	var picked := diagnosis(chosen)
	if diagnosed_right():
		_note(true, str(picked.get("why", "Right: %s." % picked.get("text", ""))))
	else:
		_note(false, str(picked.get("why", "Not %s." % picked.get("text", ""))))
	if bleed > 0.0:
		if pressure_at < 0.0:
			_note(false, "Nobody stopped the bleeding. Pressure first, questions later.")
		elif pressure_at <= QUICK:
			_note(true, "You found the bleeding and pressed on it in %d seconds." % int(ceil(pressure_at)))
		else:
			_note(false, "Pressure went on after %d seconds. Bleeding comes first, always." % int(ceil(pressure_at)))
	elif hurt_first:
		_note(false, "You pressed the sore spot first. Start away from the pain, or %s guards and you learn nothing." % _pronoun_subject())
	else:
		_note(true, "You started away from the pain, so %s could relax and let you feel." % _pronoun_subject())
	if wasted() > 1:
		_note(false, "%d checks told you nothing. Every poke costs a patient's patience." % wasted())


func _pronoun_subject() -> String:
	return "she" if him == "her" else ("they" if him == "them" else "he")
