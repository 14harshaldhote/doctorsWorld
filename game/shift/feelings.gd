class_name Feelings
extends RefCounted
## The director's rules and the feelings it hands out (story/feelings.json):
## the emotional moments, the silly beats inside serious scenes, and the
## breathers after hard stretches. Read once and kept. Director decides
## when; the ward shows them (MomentCard for a moment, a toast and a voice
## for the rest).
##
## A spoken line is {"say", "text"}: a cast member's id, or "patient" (the
## patient's own recorded voice), "relative" (someone with them) or "kid"
## (a child's voice, "boy" or "girl").

## Days before the same moment can come back.
const MOMENT_REST := 10
## How much likelier a breather that remembers something the doctor did is.
const MEMORY_WEIGHT := 3
## Who a relative's line can be recorded in, unless the line says.
const RELATIVE_VOICES := {"sex": ["f", "m"], "age": [25, 75]}
## The voices children speak in, by sex.
const KIDS := {"m": "boy", "f": "girl"}


static func data() -> Dictionary:
	return StoryBook.chapter("feelings")


## One of the director's numbers (story/feelings.json "director").
static func rule(key: String, fallback: Variant = null) -> Variant:
	return (data().get("director", {}) as Dictionary).get(key, fallback)


static func moments() -> Dictionary:
	return data().get("moments", {})


static func moment(id: String) -> Dictionary:
	return moments().get(id, {})


static func moment_title(id: String) -> String:
	return str(moment(id).get("title", ""))


static func sillies() -> Dictionary:
	return data().get("silly", {})


static func silly_text(id: String) -> String:
	return str((sillies().get(id, {}) as Dictionary).get("text", ""))


static func lifts() -> Dictionary:
	return data().get("lifts", {})


static func lift_text(id: String) -> String:
	return str((lifts().get(id, {}) as Dictionary).get("text", ""))


## True when a condition on the story flags holds: "flag", "!flag", "a|b"
## (either), "a&b" (both); "" always holds.
static func holds(flags: Dictionary, condition: String) -> bool:
	if condition.is_empty():
		return true
	if "|" in condition:
		for part in condition.split("|"):
			if holds(flags, part):
				return true
		return false
	for part in condition.split("&"):
		var wanted := not part.begins_with("!")
		if bool(flags.get(part.trim_prefix("!"), false)) != wanted:
			return false
	return true


## A breather for today: one not used yet, whose day has come and whose
## memory holds (those that remember something are likelier), or "".
static func pick_lift(rng: SeededRandom, flags: Dictionary, day: int, used: Dictionary) -> String:
	var options := []
	var ids := lifts().keys()
	ids.sort()
	for id: String in ids:
		var entry: Dictionary = lifts()[id]
		if used.has(id) or day < int(entry.get("from_day", 0)):
			continue
		if not holds(flags, str(entry.get("if", ""))):
			continue
		if entry.has("unless") and holds(flags, str(entry["unless"])):
			continue
		for _copy in (MEMORY_WEIGHT if entry.has("if") else 1):
			options.append(id)
	return str(rng.pick(options)) if not options.is_empty() else ""


## Something silly for a serious scene today, or "".
static func pick_silly(rng: SeededRandom, day: int, used: Dictionary) -> String:
	var options := []
	var ids := sillies().keys()
	ids.sort()
	for id: String in ids:
		var entry: Dictionary = sillies()[id]
		if not used.has(id) and day >= int(entry.get("from_day", 0)):
			options.append(id)
	return str(rng.pick(options)) if not options.is_empty() else ""


# --- Moments ------------------------------------------------------------------------

## The days the career last had each moment, from its counters.
static func seen_moments(profile: PlayerProfile) -> Dictionary:
	var found := {}
	for id: String in moments():
		var day := profile.count("moment_" + id)
		if day > 0:
			found[id] = day
	return found


## True when a moment fits a patient in casualty now: still here, not
## beyond saving, the right sex and age, and for most moments not yet sent
## on their way (the son in a hurry only comes for someone going up to the
## ward on a right plan).
static func fits(id: String, patient: ShiftPatient) -> bool:
	var entry := moment(id)
	if entry.is_empty() or str(entry.get("kind", "")) != "patient" or patient == null:
		return false
	if not patient.is_here() or patient.doomed or patient.forgotten:
		return false
	var fit: Dictionary = entry.get("fit", {})
	if fit.has("sex") and patient.sex() != str(fit["sex"]):
		return false
	var ages: Array = fit.get("age", [0, 200])
	if patient.age < int(ages[0]) or patient.age > int(ages[1]):
		return false
	if bool(fit.get("alone", false)) and not patient.company.is_empty():
		return false
	if bool(fit.get("admitted", false)):
		return patient.decided() and patient.outcome == "better" and str(patient.condition.get("go", "")) == "admit"
	return not patient.decided() and patient.triage() != "red"


## The day's moment: {"id", "patient"} for one that fits someone here (or a
## colleague's), not had in the last MOMENT_REST days, or {}.
static func pick_moment(rng: SeededRandom, sim: ShiftSim, seen: Dictionary) -> Dictionary:
	var options := []
	var ids := moments().keys()
	ids.sort()
	for id: String in ids:
		if seen.has(id) and sim.day - int(seen[id]) < MOMENT_REST:
			continue
		var entry := moment(id)
		if sim.day < int(entry.get("from_day", 0)):
			continue
		if str(entry.get("kind", "")) == "staff":
			options.append({"id": id, "patient": null})
			continue
		# Someone in a cubicle first: the doctor is with them.
		var seeing := []
		var anyone := []
		for patient in sim.patients:
			if fits(id, patient):
				anyone.append(patient)
				if patient.cubicle >= 0:
					seeing.append(patient)
		var pool := seeing if not seeing.is_empty() else anyone
		if not pool.is_empty():
			options.append({"id": id, "patient": rng.pick(pool)})
	return rng.pick(options) if not options.is_empty() else {}


## Where in casualty a patient is, for a moment's heading.
static func where_text(patient: ShiftPatient) -> String:
	if patient == null:
		return ""
	if patient.cubicle >= 0:
		return "Cubicle %d" % (patient.cubicle + 1)
	if patient.decided():
		return "On the way up"
	return "The waiting area"


## A moment's words with the patient filled in.
static func fill(text: String, patient: ShiftPatient) -> String:
	if patient == null:
		return text
	var male := patient.sex() != "f"
	return text.replace("{patient}", patient.called()).replace("{where}", where_text(patient)) \
		.replace("{his}", "his" if male else "her").replace("{His}", "His" if male else "Her") \
		.replace("{him}", "him" if male else "her") \
		.replace("{he}", "he" if male else "she").replace("{He}", "He" if male else "She") \
		.replace("{son}", "son" if male else "daughter")


## The recorded voice a line is said in: the cast member's own, the
## patient's, a relative's (whoever came with them, if they did) or a
## child's. Always one the line was recorded in.
static func voice_for(line: Dictionary, patient: ShiftPatient, rng: SeededRandom, voices: Dictionary = {}) -> String:
	var who := str(line.get("say", ""))
	match who:
		"patient":
			if patient == null:
				return ""
			if patient.speaker == "self" and not patient.voice.is_empty():
				return patient.voice
			return PatientVoices.pick(rng, patient.sex(), patient.age, [])
		"kid":
			return str(KIDS.get(patient.sex() if patient != null else "m", "boy"))
		"relative":
			var allowed: Dictionary = voices if not voices.is_empty() else RELATIVE_VOICES
			var ages: Array = allowed.get("age", [25, 75])
			var sexes: Array = allowed.get("sex", ["f", "m"])
			if patient != null and not patient.company.is_empty() and str(patient.company.get("sex", "")) in sexes:
				var age := clampi(int(patient.company.get("age", 40)), int(ages[0]), int(ages[1]))
				return PatientVoices.pick(rng, str(patient.company["sex"]), age, [])
			var options := PatientVoices.overlapping(sexes, int(ages[0]), int(ages[1]))
			return str(rng.pick(options)) if not options.is_empty() else ""
	return who


## Every line a made-up person says in the feelings, in every voice that
## could say it: [{"who", "text", "mood"}] (PatientVoices.catalogue adds
## these, for the recordings).
static func patient_lines() -> Array:
	var found := []
	var add := func(line: Dictionary, sexes: Array, ages: Array) -> void:
		var who := str(line.get("say", ""))
		if who not in ["patient", "relative"]:
			return
		for voice: String in PatientVoices.overlapping(sexes, int(ages[0]), int(ages[1])):
			found.append({"who": voice, "text": str(line.get("text", "")), "mood": str(line.get("mood", "calm"))})
	for id: String in moments():
		var entry := moment(id)
		var fit: Dictionary = entry.get("fit", {})
		var sexes: Array = [str(fit["sex"])] if fit.has("sex") else ["f", "m"]
		var ages: Array = fit.get("age", [16, 99])
		var lines: Array = [entry.get("line", {})]
		for choice: Dictionary in entry.get("choices", []):
			lines.append(choice.get("line", {}))
		for line: Dictionary in lines:
			if str(line.get("say", "")) == "relative":
				var voices: Dictionary = entry.get("voices", RELATIVE_VOICES)
				add.call(line, voices.get("sex", ["f", "m"]), voices.get("age", [25, 75]))
			else:
				add.call(line, sexes, ages)
	for id: String in sillies():
		add.call((sillies()[id] as Dictionary).get("line", {}), RELATIVE_VOICES["sex"], RELATIVE_VOICES["age"])
	return found


## Every line the cast and the children say in the feelings: [{who, text}].
static func cast_lines() -> Array:
	var found := []
	var add := func(line: Dictionary) -> void:
		var who := str(line.get("say", ""))
		var text := str(line.get("text", ""))
		if who.is_empty() or text.is_empty() or who in ["patient", "relative"]:
			return
		if who == "kid":
			for kid: String in KIDS.values():
				found.append({"who": kid, "text": text})
		else:
			found.append({"who": who, "text": text})
	for id: String in moments():
		var entry := moment(id)
		add.call(entry.get("line", {}))
		for choice: Dictionary in entry.get("choices", []):
			add.call(choice.get("line", {}))
	for group: Dictionary in [sillies(), lifts()]:
		for id: String in group:
			add.call((group[id] as Dictionary).get("line", {}))
	return found


# --- After a moment ------------------------------------------------------------------

## What a choice in a moment changes: trust, a flag, a count, the day the
## career last had this moment, and the message that comes days later (a
## kept phone item).
static func choose(profile: PlayerProfile, id: String, choice_id: String, patient: ShiftPatient) -> void:
	var entry := moment(id)
	profile.set_count("moment_" + id, profile.day)
	profile.add_count("moments", 1)
	for choice: Dictionary in entry.get("choices", []):
		if str(choice.get("id", "")) != choice_id:
			continue
		for who: String in (choice.get("trust", {}) as Dictionary):
			profile.change_trust(who, int(choice["trust"][who]))
		if choice.has("flag"):
			profile.set_flag(str(choice["flag"]))
		if choice.has("count"):
			profile.add_count(str(choice["count"]), 1)
		var payoff: Dictionary = choice.get("payoff", {})
		if not payoff.is_empty():
			PhoneBook.keep(profile, payoff_item(profile, id, payoff, patient))
		return


## The message a moment brings days later, as a kept phone item.
static func payoff_item(profile: PlayerProfile, id: String, payoff: Dictionary, patient: ShiftPatient) -> Dictionary:
	var rng := SeededRandom.new(absi(("payoff|%s|%d|%d" % [id, profile.day, patient.id if patient != null else 0]).hash()) % 1000003 + 1)
	var days: Array = payoff.get("days", [2, 3])
	var day := profile.day + rng.next_int_in(int(days[0]), int(days[1]))
	var at := rng.next_int_in(19 * 60, 21 * 60 + 30)
	var from := str(payoff.get("from", ""))
	var item_id := "m%d_%s" % [profile.day, id]
	var item := {"id": item_id, "chat": from, "from": from, "name": "", "text": fill(str(payoff.get("text", "")), patient),
		"day": day, "at": at}
	match from:
		"relative":
			var relation := str(payoff.get("relation", "daughter"))
			var sex := "f" if relation in ["daughter", "mother", "wife", "sister"] else "m"
			var age := 40
			var last := ""
			var community := ""
			if patient != null:
				age = patient.age + 28 if relation in ["mother", "father"] else maxi(22, patient.age - 30)
				last = str(patient.person.get("last", ""))
				community = str(patient.person.get("community", ""))
			var made := NameMaker.make(rng, sex, clampi(age, 20, 80), community, last)
			item["chat"] = item_id
			item["from"] = item_id
			item["name"] = str(made.get("full", "A relative"))
		"social":
			item["chat"] = "elsy"
			item["from"] = "elsy"
	return item
