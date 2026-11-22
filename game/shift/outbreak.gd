class_name Outbreak
extends RefCounted
## Invented outbreaks: every so often a new fever goes round town for a few
## days, made on the phone from parts (story/patients.json "outbreak"): a
## pattern of symptoms, an examination and a blood picture of its own, so
## the doctor has to spot it across several patients.
##
## The illness is invented and always says so, on the patient card and in
## every explanation, so nobody takes it for real medicine. What the doctor
## has to do about it is real: isolate, support, sample and report a
## cluster to the public health team.
##
## Each career meets the kinds in its own order (the hospital's seed); the
## same day always has the same outbreak.

const ID := "outbreak"


## The kind of invented fever going round on a day, or "" when none is.
static func kind_on(hospital_seed: int, day: int) -> String:
	if hospital_seed <= 0:
		return ""
	var info := PatientParts.outbreak()
	var first := int(info.get("first_day", 10))
	var every := int(info.get("every", 12))
	var lasts := int(info.get("lasts", 4))
	if day < first or every <= 0:
		return ""
	var since := day - first
	if since % every >= lasts:
		return ""
	var kinds: Array = (info.get("kinds", {}) as Dictionary).keys()
	kinds.sort()
	if kinds.is_empty():
		return ""
	var order := SeededRandom.new(absi(hash("outbreak|%d" % hospital_seed)) % 1000003 + 1).shuffled(kinds)
	return str(order[(since / every) % order.size()])


## True on the first day of an outbreak (when the news breaks).
static func starts_on(hospital_seed: int, day: int) -> bool:
	var info := PatientParts.outbreak()
	return not kind_on(hospital_seed, day).is_empty() and (day - int(info.get("first_day", 10))) % int(info.get("every", 12)) == 0


## How often the invented fever walks in, next to the real illnesses.
static func weight() -> int:
	return int(PatientParts.outbreak().get("weight", 0))


## The invented illness as a condition, with this patient's own words
## picked by rng. Empty for a kind that doesn't exist.
static func condition(kind: String, rng: SeededRandom) -> Dictionary:
	var info := PatientParts.outbreak()
	var data: Dictionary = (info.get("kinds", {}) as Dictionary).get(kind, {})
	if data.is_empty():
		return {}
	return {
		"name": "Invented: %s" % str(data.get("name", "")),
		"board": str(data.get("board", "Fever")),
		"sex": "",
		"age": (info.get("age", [16, 45]) as Array).duplicate(),
		"triage": str(info.get("triage", "yellow")),
		"start": (info.get("start", [20, 30]) as Array).duplicate(),
		"worsens": float(info.get("worsens", 3)),
		"vitals": (info.get("vitals", {}) as Dictionary).duplicate(true),
		"answers": {
			"pain": str(rng.pick(data.get("pain", ["Fever."]))),
			"when": str(rng.pick(info.get("when", ["Two days."]))),
			"other": str(rng.pick(info.get("other", ["Nothing else."]))),
		},
		"exam": str(data.get("exam", "")),
		"results": {"bloods": str(data.get("bloods", ""))},
		"key": [],
		"go": str(info.get("go", "isolation")),
		"plans": (info.get("plans", []) as Array).duplicate(true),
		"plain": "",
		"invented": true,
		"kind": kind,
		"label": str(info.get("label", "Invented illness")),
	}


## The phone feed's news when an outbreak starts, or "".
static func news(hospital_seed: int, day: int) -> String:
	var kind := kind_on(hospital_seed, day)
	if kind.is_empty():
		return ""
	var info := PatientParts.outbreak()
	var board := str((info.get("kinds", {}) as Dictionary).get(kind, {}).get("board", "fever")).to_lower()
	return str(info.get("news", "")).format({"board_low": board})
