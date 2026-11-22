class_name PatientMaker
extends RefCounted
## Builds a casualty patient's case from parts, all from one seed, in well
## under a millisecond:
##
##   * the illness and how far along it is: early, or arriving late and
##     worse (a burst appendix instead of an angry one);
##   * a mix or a twist that changes the right plan: something shown on the
##     card (on warfarin, pregnant, years of steroids, weak kidneys) or
##     something hidden that the doctor has to catch by asking, examining or
##     testing (a penicillin allergy, a pregnancy nobody mentions, the drink
##     they deny);
##   * who they are: a job, a temper, who came in with them (a relative
##     shares their surname) and the voice they speak in;
##   * what they say, in their own temper.
##
## The medicine never changes at run time: every answer, finding, result
## and plan comes from the checked library (story/conditions.json and
## story/patients.json). A mix only swaps in its own checked plan for that
## illness, and the usual plan becomes the trap.

## How often a patient who could have a mix or twist has one.
const EXTRA_CHANCE := 0.4
## How often a mix that can hide (a pregnancy, the drinking) is hidden.
const HIDDEN_CHANCE := 0.5
## How often someone with a temper has a last word after "Anything else?".
const AFTER_CHANCE := 0.6
## Ages by band, for who comes in with them.
const BANDS := [[12, "child"], [18, "teen"], [30, "young"], [60, "adult"]]
const WOMEN := ["mother", "sister", "wife", "daughter", "daughter-in-law"]
const MEN := ["father", "brother", "elder brother", "husband", "son", "grandson"]


## Turns a base illness into this patient's case. Fills in the patient's
## stage, extra, company, speaker, temper, voice and job, and sets
## patient.condition to the case. known: a patient met on an earlier day
## (their temper, voice and job are kept; "worse" brings their old illness
## back late).
static func build(patient: ShiftPatient, base: Dictionary, rng: SeededRandom, known: Dictionary = {}) -> void:
	var case := base.duplicate(true)
	case.erase("late")
	patient.stage = "early"
	var late: Dictionary = base.get("late", {})
	if not late.is_empty() and (bool(known.get("worse", false)) or rng.chance(float(late.get("chance", 0.3)))):
		patient.stage = "late"
		_merge_late(case, late)
	patient.extra = ""
	patient.extra_hidden = false
	var choices := extras_for(patient.condition_id, patient.sex(), patient.age)
	if not choices.is_empty() and rng.chance(EXTRA_CHANCE):
		patient.extra = str(rng.pick(choices))
		var extra: Dictionary = PatientParts.extras()[patient.extra]
		patient.extra_hidden = str(extra.get("known", "")).is_empty() or (extra.has("hidden") and rng.chance(HIDDEN_CHANCE))
		_apply_extra(case, patient.extra, patient.condition_id, patient.extra_hidden, rng)
	patient.company = _company(patient, base, rng)
	var told := str(base.get("told_by", ""))
	patient.speaker = told if told in ["parent", "colleague"] and not patient.company.is_empty() else "self"
	var speaker_sex := patient.sex()
	var speaker_age := patient.age
	if patient.speaker != "self":
		speaker_sex = str(patient.company.get("sex", "f"))
		speaker_age = int(patient.company.get("age", 30))
	var kept_temper := str(known.get("personality", ""))
	var kept_voice := str(known.get("voice", ""))
	if patient.speaker == "self" and _temper_fits(kept_temper, "self", speaker_sex, speaker_age) \
			and PatientVoices.fits(kept_voice, speaker_sex, speaker_age):
		patient.personality = kept_temper
		patient.voice = kept_voice
	else:
		patient.personality = _temper(rng, patient.speaker, speaker_sex, speaker_age)
		var tones: Array = PatientParts.personalities().get(patient.personality, {}).get("tones", [])
		patient.voice = PatientVoices.pick(rng, speaker_sex, speaker_age, tones)
	patient.patience = float(PatientParts.personalities().get(patient.personality, {}).get("patience", 1.0))
	var kept_job := str(known.get("job", ""))
	patient.job = kept_job if not kept_job.is_empty() or patient.age < 12 else _job(rng, base, patient.sex(), patient.age)
	_compose(case, patient, rng, known)
	patient.invented = bool(case.get("invented", false))
	patient.condition = case


## The mixes and twists that change the plan for this illness and fit this
## person, by id.
static func extras_for(condition_id: String, sex: String, age: int) -> Array:
	var found := []
	var all := PatientParts.extras()
	for id: String in all:
		var extra: Dictionary = all[id]
		if not (extra.get("fits", {}) as Dictionary).has(condition_id):
			continue
		var wanted := str(extra.get("sex", ""))
		var ages: Array = extra.get("ages", [0, 120])
		if (wanted in ["m", "f"] and wanted != sex) or age < int(ages[0]) or age > int(ages[1]):
			continue
		found.append(id)
	found.sort()
	return found


## Where two age ranges meet: [low, high], or [] if they don't.
static func overlap(a: Array, b: Array) -> Array:
	var low := maxi(int(a[0]), int(b[0]))
	var high := mini(int(a[1]), int(b[1]))
	return [low, high] if low <= high else []


static func _merge_late(case: Dictionary, late: Dictionary) -> void:
	for key: String in ["board", "exam"]:
		if late.has(key):
			case[key] = late[key]
	for key: String in ["start", "worsens"]:
		if late.has(key):
			case[key] = late[key]
	for key: String in ["answers", "results", "vitals"]:
		var merged: Dictionary = case.get(key, {})
		var more: Dictionary = late.get(key, {})
		for part: String in more:
			merged[part] = more[part]
		case[key] = merged


## Swaps in a mix or twist: what they say about it, what the examination
## and the tests show, the key tests, and the plans (its own right plan
## first, the usual plan as the trap, two of the usual wrong ones).
static func _apply_extra(case: Dictionary, id: String, condition_id: String, hidden: bool, rng: SeededRandom) -> void:
	var extra: Dictionary = PatientParts.extras()[id]
	var fit: Dictionary = extra["fits"][condition_id]
	var say := str(extra.get("say", ""))
	if hidden and extra.has("hidden"):
		say = str(extra["hidden"].get("say", say))
	var answers: Dictionary = case["answers"]
	answers["other"] = join([str(answers.get("other", "")), say])
	if extra.has("exam"):
		case["exam"] = join([str(case.get("exam", "")), str(extra["exam"])])
	var results: Dictionary = case.get("results", {})
	var own: Dictionary = fit.get("results", {})
	for test: String in extra.get("results", {}):
		results[test] = own.get(test, extra["results"][test])
	for test: String in own:
		results[test] = own[test]
	case["results"] = results
	var key: Array = (case.get("key", []) as Array).duplicate()
	var more: Array = (extra.get("key", []) as Array).duplicate()
	if hidden and extra.has("hidden"):
		more.append_array(extra["hidden"].get("key", []))
	for test: String in more:
		if test not in key:
			key.append(test)
	case["key"] = key
	var usual: Dictionary = {}
	var wrong := []
	for plan: Dictionary in case.get("plans", []):
		if bool(plan.get("right", false)):
			usual = plan
		else:
			wrong.append(plan)
	if wrong.size() > 2:
		wrong.remove_at(rng.next_int(wrong.size()))
	var plans := [
		{"text": str(fit.get("right", "")), "right": true, "why": str(fit.get("why", ""))},
		{"text": str(fit.get("trap", usual.get("text", ""))), "effect": str(fit.get("trap_effect", "worse")),
			"why": str(fit.get("trap_why", ""))},
	]
	plans.append_array(wrong)
	case["plans"] = plans
	if fit.has("go"):
		case["go"] = fit["go"]
	case["extra"] = id
	case["known"] = "" if hidden else str(extra.get("known", ""))


## Who came in with them: {relation, first, full, sex, age}, or {} alone.
static func _company(patient: ShiftPatient, base: Dictionary, rng: SeededRandom) -> Dictionary:
	var told := str(base.get("told_by", ""))
	var relation := str(base.get("with", ""))
	var groups := PatientParts.company()
	if relation.is_empty():
		if told == "parent":
			relation = _weighted(rng, groups.get("child", [["mother", 1]]))
		elif told == "colleague":
			relation = "colleague"
		else:
			relation = _weighted(rng, groups.get(band(patient.age), [["", 1]]))
	if relation.is_empty():
		return {}
	if relation == "spouse":
		relation = "wife" if patient.sex() == "m" else "husband"
	var sex := "f" if relation in WOMEN else ("m" if relation in MEN else "")
	if relation == "roommate":
		sex = patient.sex()
	elif sex.is_empty():
		sex = "m" if rng.chance(0.5) else "f"
	var age := _relation_age(relation, patient.age, rng)
	var surname := str(patient.person.get("last", "")) if relation in PatientParts.same_name() else ""
	var community := str(patient.person.get("community", ""))
	if relation in ["friend", "colleague", "roommate"] and rng.chance(0.5):
		community = ""
	var made := NameMaker.make(rng, sex, age, community, surname)
	for attempt in 2:
		if str(made.get("first", "")) != str(patient.person.get("first", "")):
			break
		made = NameMaker.make(rng, sex, age, community, surname)
	return {"relation": relation, "first": str(made.get("first", "")), "full": str(made.get("full", "")), "sex": sex,
		"age": age}


## The band an age falls in: child, teen, young, adult or old.
static func band(age: int) -> String:
	for entry: Array in BANDS:
		if age < int(entry[0]):
			return str(entry[1])
	return "old"


static func _relation_age(relation: String, age: int, rng: SeededRandom) -> int:
	match relation:
		"mother", "father":
			return clampi(age + rng.next_int_in(20, 32), PatientVoices.PARENT_AGES[0], 90)
		"elder brother":
			return age + rng.next_int_in(3, 8)
		"brother", "sister", "cousin":
			return maxi(12, age + rng.next_int_in(-5, 5))
		"wife":
			return maxi(18, age - rng.next_int_in(0, 5))
		"husband":
			return age + rng.next_int_in(0, 5)
		"son", "daughter":
			return maxi(18, age - rng.next_int_in(24, 34))
		"daughter-in-law":
			return maxi(20, age - rng.next_int_in(26, 34))
		"grandson":
			return clampi(age - rng.next_int_in(46, 56), 12, 30)
		"colleague":
			return clampi(age + rng.next_int_in(-4, 4), PatientVoices.COLLEAGUE_AGES[0], PatientVoices.COLLEAGUE_AGES[1])
	return maxi(16, age + rng.next_int_in(-4, 4))


static func _weighted(rng: SeededRandom, options: Array) -> String:
	var total := 0
	for option: Array in options:
		total += int(option[1])
	if total <= 0:
		return ""
	var roll := rng.next_int(total)
	for option: Array in options:
		roll -= int(option[1])
		if roll < 0:
			return str(option[0])
	return ""


## True when a temper suits this speaker and some voice can play it.
static func _temper_fits(id: String, speaker: String, sex: String, age: int) -> bool:
	var temper: Dictionary = PatientParts.personalities().get(id, {})
	if temper.is_empty() or speaker not in temper.get("speakers", []):
		return false
	var ages: Array = temper.get("ages", [0, 120])
	if age < int(ages[0]) or age > int(ages[1]):
		return false
	return not PatientVoices.suited(sex, age, temper.get("tones", [])).is_empty()


static func _temper(rng: SeededRandom, speaker: String, sex: String, age: int) -> String:
	var all := PatientParts.personalities()
	var ids := all.keys()
	ids.sort()
	var options := []
	for id: String in ids:
		if _temper_fits(id, speaker, sex, age):
			options.append([id, int(all[id].get("weight", 1))])
	var picked := _weighted(rng, options)
	return picked if not picked.is_empty() else "calm"


## A job for their age and sex, from the illness's own list when it has one.
static func _job(rng: SeededRandom, base: Dictionary, sex: String, age: int) -> String:
	var wanted: Array = base.get("jobs", [])
	var fitting := _jobs_fitting(PatientParts.jobs(true), wanted, sex, age)
	if fitting.is_empty():
		fitting = _jobs_fitting(PatientParts.jobs(false), [], sex, age)
	return str(rng.pick(fitting)) if not fitting.is_empty() else ""


static func _jobs_fitting(table: Array, wanted: Array, sex: String, age: int) -> Array:
	var found := []
	for entry: Array in table:
		if not wanted.is_empty() and str(entry[0]) not in wanted:
			continue
		var only := str(entry[1])
		if (only in ["m", "f"] and only != sex) or age < int(entry[2]) or age > int(entry[3]):
			continue
		found.append(str(entry[0]))
	return found


## What they say, in their temper: an opening line before the first answer
## (and a hello if they've been here before), a last word after "Anything
## else?".
static func _compose(case: Dictionary, patient: ShiftPatient, rng: SeededRandom, known: Dictionary) -> void:
	var temper: Dictionary = PatientParts.personalities().get(patient.personality, {})
	var openers: Array = temper.get("openers", [])
	var afters: Array = temper.get("afters", [])
	var opener := str(rng.pick(openers)) if not openers.is_empty() else ""
	var after := str(rng.pick(afters)) if not afters.is_empty() and rng.chance(AFTER_CHANCE) else ""
	var hello := ""
	if not known.is_empty():
		var lines: Array = PatientParts.returns().get("again" if bool(known.get("worse", false)) else "hello", [])
		hello = str(rng.pick(lines)) if not lines.is_empty() else ""
	var answers: Dictionary = case.get("answers", {})
	answers["pain"] = join([hello, opener, str(answers.get("pain", ""))])
	answers["other"] = join([str(answers.get("other", "")), after])
	case["answers"] = answers


## Pieces of speech joined into one line, leaving out the empty ones.
static func join(pieces: Array) -> String:
	var kept := PackedStringArray()
	for piece: Variant in pieces:
		var text := str(piece).strip_edges()
		if not text.is_empty():
			kept.append(text)
	return " ".join(kept)
