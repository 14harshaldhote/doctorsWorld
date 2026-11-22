class_name PatientParts
extends RefCounted
## The parts a casualty patient is made from (story/patients.json): the
## patients' recorded voices, their tempers, jobs, who comes in with them,
## the mixes and twists that change the right plan, the invented outbreaks
## and the patients who come back. Read once and kept.
##
## The illnesses themselves live in story/conditions.json (Conditions).


static func data() -> Dictionary:
	return StoryBook.chapter("patients")


static func voices() -> Dictionary:
	return _dict("voices")


static func personalities() -> Dictionary:
	return _dict("personalities")


static func extras() -> Dictionary:
	return _dict("extras")


static func outbreak() -> Dictionary:
	return _dict("outbreak")


static func returns() -> Dictionary:
	return _dict("returns")


static func company() -> Dictionary:
	return _dict("company")


static func same_name() -> Array:
	return _array("same_name")


## Every job, as [words, sex ("" either), youngest, oldest]: the everyday
## ones, then the ones only some illnesses ask for.
static func jobs(with_extra: bool = false) -> Array:
	var found := _array("jobs").duplicate()
	if with_extra:
		found.append_array(_array("extra_jobs"))
	return found


static func _dict(key: String) -> Dictionary:
	var found: Variant = data().get(key)
	return found if typeof(found) == TYPE_DICTIONARY else {}


static func _array(key: String) -> Array:
	var found: Variant = data().get(key)
	return found if typeof(found) == TYPE_ARRAY else []
