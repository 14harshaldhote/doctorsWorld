class_name PatientVoices
extends RefCounted
## The ten recorded voices of the people casualty makes up: a young, a
## middle-aged and an old voice for men and for women, with a warmer and a
## sharper one where there's room, so a patient sounds like their temper
## (sweet, harsh, soft, worn out) and their age. The parent of a small
## child, or the workmate who brought someone in, speaks for them in their
## own voice.
##
## Every line a made-up patient can say is recorded ahead in each voice that
## could say it (tools/make_voices.py, from catalogue()), and the game puts a
## spoken answer together from those clips (VoiceBank). Names are never in
## a spoken line, so nothing is left to the phone's reading voice.

## The pace and feeling a line is recorded with, by the illness's triage.
const MOODS := {"red": "worried", "yellow": "worried", "green": "calm"}
## How old a parent or a workmate can be, around the patient.
const PARENT_AGES := [20, 46]
const COLLEAGUE_AGES := [22, 55]


static func ids() -> Array:
	var found := PatientParts.voices().keys()
	found.sort()
	return found


static func has(who: String) -> bool:
	return PatientParts.voices().has(who)


## True when a voice suits someone of this sex and age.
static func fits(who: String, sex: String, age: int) -> bool:
	var voice: Dictionary = PatientParts.voices().get(who, {})
	if voice.is_empty():
		return false
	var ages: Array = voice.get("ages", [0, 0])
	return str(voice.get("sex", "")) == sex and age >= int(ages[0]) and age <= int(ages[1])


## The voices that suit someone, those sharing one of the tones first.
static func suited(sex: String, age: int, tones: Array) -> Array:
	var liked := []
	for who: String in ids():
		if fits(who, sex, age) and _shares(PatientParts.voices()[who].get("tones", []), tones):
			liked.append(who)
	return liked


## A voice for someone of this sex and age with one of these tones (any
## voice that fits if none shares a tone).
static func pick(rng: SeededRandom, sex: String, age: int, tones: Array) -> String:
	var liked := suited(sex, age, tones)
	if liked.is_empty():
		for who: String in ids():
			if fits(who, sex, age):
				liked.append(who)
	if liked.is_empty():
		return "pf_mid_warm" if sex == "f" else "pm_mid_warm"
	return str(rng.pick(liked))


## How the phone's own voice reads a patient voice when a clip is missing,
## shaped like a cast.json entry for Speech.
static func cast_entry(who: String) -> Dictionary:
	var voice: Dictionary = PatientParts.voices().get(who, {})
	return {"gender": "female" if str(voice.get("sex", "m")) == "f" else "male", "voice": float(voice.get("voice", 1.0))}


## Who can be heard answering for an illness: the sexes and the ages of the
## speaker (the patient, a child's parent, or the workmate who brought them).
static func speakers_for(condition: Dictionary) -> Dictionary:
	match str(condition.get("told_by", "")):
		"parent":
			return {"sexes": ["f", "m"], "ages": PARENT_AGES}
		"colleague":
			return {"sexes": ["f", "m"], "ages": COLLEAGUE_AGES}
	var sex := str(condition.get("sex", ""))
	return {"sexes": [sex] if sex in ["m", "f"] else ["f", "m"], "ages": condition.get("age", [20, 60])}


## Voices whose sex is one of sexes and whose ages overlap low..high.
static func overlapping(sexes: Array, low: int, high: int, tones: Array = []) -> Array:
	var found := []
	for who: String in ids():
		var voice: Dictionary = PatientParts.voices()[who]
		var ages: Array = voice.get("ages", [0, 0])
		if str(voice.get("sex", "")) not in sexes or int(ages[1]) < low or int(ages[0]) > high:
			continue
		if not tones.is_empty() and not _shares(voice.get("tones", []), tones):
			continue
		found.append(who)
	return found


## Every line a made-up patient can say, in every voice that can say it:
## [{"who", "text", "mood"}]. The voice tool records these.
static func catalogue() -> Array:
	var seen := {}
	var lines := []
	var add := func(who: String, text: String, mood: String) -> void:
		var key := who + "|" + text
		if text.strip_edges().is_empty() or seen.has(key):
			return
		seen[key] = true
		lines.append({"who": who, "text": text, "mood": mood})
	for id: String in Conditions.ids():
		var condition := Conditions.get_condition(id)
		var speaking := speakers_for(condition)
		var ages: Array = speaking["ages"]
		var voices := overlapping(speaking["sexes"], int(ages[0]), int(ages[1]))
		var mood := str(MOODS.get(str(condition.get("triage", "green")), "calm"))
		var said: Array = (condition.get("answers", {}) as Dictionary).values()
		said.append_array((condition.get("late", {}).get("answers", {}) as Dictionary).values())
		for text: Variant in said:
			for who: String in voices:
				add.call(who, str(text), mood)
	for id: String in PatientParts.extras():
		var extra: Dictionary = PatientParts.extras()[id]
		var sayings := [str(extra.get("say", ""))]
		if extra.has("hidden"):
			sayings.append(str(extra["hidden"].get("say", "")))
		var sex := str(extra.get("sex", ""))
		for condition_id: String in extra.get("fits", {}):
			var condition := Conditions.get_condition(condition_id)
			if condition.is_empty():
				continue
			var ages := PatientMaker.overlap(extra.get("ages", [0, 99]), condition.get("age", [0, 99]))
			if ages.is_empty():
				continue
			var sexes: Array = speakers_for(condition)["sexes"]
			if sex in ["m", "f"]:
				sexes = [sex] if sex in sexes else []
			for who: String in overlapping(sexes, int(ages[0]), int(ages[1])):
				for text: String in sayings:
					add.call(who, text, "worried")
	for id: String in PatientParts.personalities():
		var temper: Dictionary = PatientParts.personalities()[id]
		var ages: Array = temper.get("ages", [0, 99])
		var low := int(ages[0])
		var high := int(ages[1])
		if "self" not in temper.get("speakers", []):
			# Only a parent or a workmate has this temper.
			low = maxi(low, PARENT_AGES[0])
			high = mini(high, COLLEAGUE_AGES[1])
		var mood := str(temper.get("mood", "calm"))
		for who: String in overlapping(["f", "m"], low, high, temper.get("tones", [])):
			for text: Variant in temper.get("openers", []) + temper.get("afters", []):
				add.call(who, str(text), mood)
	var outbreak := PatientParts.outbreak()
	var outbreak_ages: Array = outbreak.get("age", [16, 45])
	var outbreak_voices := overlapping(["f", "m"], int(outbreak_ages[0]), int(outbreak_ages[1]))
	var outbreak_lines: Array = outbreak.get("when", []) + outbreak.get("other", [])
	for kind: Dictionary in (outbreak.get("kinds", {}) as Dictionary).values():
		outbreak_lines.append_array(kind.get("pain", []))
	for text: Variant in outbreak_lines:
		for who: String in outbreak_voices:
			add.call(who, str(text), "worried")
	for text: Variant in PatientParts.returns().get("hello", []) + PatientParts.returns().get("again", []):
		for who: String in ids():
			add.call(who, str(text), "calm")
	return lines


static func _shares(a: Array, b: Array) -> bool:
	for item: Variant in a:
		if item in b:
			return true
	return false
