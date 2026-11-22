class_name ShiftDay
extends RefCounted
## The day's casualty: whether it's open, how busy it is, its seed, when the
## shift ends and how a day's work there is counted. Casualty opens on the
## first ward day and never closes again.
##
## Every career has its own hospital: a number made once (the counter
## "hospital_seed") decides who walks in on every day of it. The same day
## started again brings the same people at the same times.

const FIRST_DAY := 4
## How busy casualty is (ShiftSim's load): half on the first ward day,
## rising a little each day to a normal day by Day 14, then busier with
## each of the Chief's tiers, up to MOST.
const FIRST_LOAD := 0.5
const DAILY_RISE := 0.05
const TIER_RISE := 0.1
const MOST := 1.4
## The free clock stops here (hospital minutes): 20:00 for a day shift,
## 08:00 the next morning for a night.
const DAY_END := 20 * 60
const NIGHT_END := 32 * 60
## The gentle start on the first ward day: a sprained wrist, then a tummy bug.
const FIRST_ARRIVALS := [[20, "wrist_fracture"], [70, "gastro"]]
## How far back a patient can still come back from, in days.
const RECALL_DAYS := 20
## Outcomes a patient record can have (ShiftPatient.outcome after a plan).
const OUTCOMES := ["better", "worse", "harmed", "back", "fine"]


static func open(day: int) -> bool:
	return day >= FIRST_DAY


static func load_for(day: int) -> float:
	if not open(day):
		return 0.0
	var amount := FIRST_LOAD + DAILY_RISE * (day - FIRST_DAY)
	amount = minf(amount, 1.0)
	return minf(MOST, amount + TIER_RISE * ChiefDays.tier(day))


## The career's own seed, made the first time it's needed. Kept in the
## morning snapshot too, so a day started again keeps the same hospital.
static func hospital_seed(profile: PlayerProfile) -> int:
	var seed_value := profile.count("hospital_seed")
	if seed_value <= 0:
		seed_value = absi(hash("%d|%d|%s" % [Time.get_ticks_usec(), Time.get_unix_time_from_system(), profile.name])) \
			% 999983 + 1
		profile.set_count("hospital_seed", seed_value)
		if int(profile.morning.get("day", -1)) == profile.day:
			var counters: Dictionary = profile.morning.get("counters", {})
			counters["hospital_seed"] = seed_value
			profile.morning["counters"] = counters
	return seed_value


static func seed_for(profile: PlayerProfile, day: int) -> int:
	return absi(hash("casualty|%d|%d" % [hospital_seed(profile), day])) % 1000003 + 1


## The day's shift, starting at a hospital minute, or null when casualty
## isn't open yet.
static func make(profile: PlayerProfile, day: int, start_minute: int) -> ShiftSim:
	if not open(day):
		return null
	var sim := ShiftSim.new(seed_for(profile, day), start_minute, load_for(day))
	sim.day = day
	sim.hospital = hospital_seed(profile)
	sim.past = past(profile, day)
	if day == FIRST_DAY:
		sim.first_arrivals = FIRST_ARRIVALS.duplicate(true)
	return sim


static func end_minute(night: bool) -> int:
	return NIGHT_END if night else DAY_END


## Counts a decision in the career and returns its XP. Kept small next to
## the story. The patient (when given) is remembered with the career, so
## they can come back on a later day.
static func record(profile: PlayerProfile, result: Dictionary, patient: ShiftPatient = null) -> int:
	var xp := ShiftSim.xp_for(int(result.get("score", 0)))
	profile.total_xp += xp
	profile.add_count("casualty_seen", 1)
	if bool(result.get("right", false)):
		profile.add_count("casualty_right", 1)
	if patient != null:
		remember(profile, patient)
	return xp


## Keeps a patient seen today in the career's records (the newest KEEP), for
## coming back later. Someone seen twice today keeps one record.
static func remember(profile: PlayerProfile, patient: ShiftPatient) -> void:
	var full := str(patient.person.get("full", ""))
	# An invented outbreak's patients don't come back: the fever is gone in days.
	if full.is_empty() or patient.condition_id == Outbreak.ID or patient.outcome not in OUTCOMES:
		return
	var kept := []
	for entry: Dictionary in profile.patients:
		if not (str(entry.get("full", "")) == full and int(entry.get("day", 0)) == profile.day):
			kept.append(entry)
	kept.append({
		"id": "d%d_%d" % [profile.day, patient.id], "day": profile.day,
		"first": str(patient.person.get("first", "")), "last": str(patient.person.get("last", "")), "full": full,
		"community": str(patient.person.get("community", "")), "sex": patient.sex(),
		"home": str(patient.person.get("home", "")), "age": patient.age,
		# The look as PatientLook reads it: small enough to keep exactly in a save.
		"look": absi(patient.look_seed) % PatientLook.SEEDS,
		"voice": patient.voice if patient.speaker == "self" else "", "personality": patient.personality if patient.speaker == "self" else "",
		"job": patient.job, "condition": patient.condition_id, "outcome": patient.outcome, "back": 0,
	})
	var keep := int(PatientParts.returns().get("keep", 40))
	while kept.size() > keep:
		kept.pop_front()
	profile.patients = kept


## Notes that a patient from an earlier day came back today, so they don't
## come back again until they're seen anew.
static func note_return(profile: PlayerProfile, id: String) -> void:
	for entry: Dictionary in profile.patients:
		if str(entry.get("id", "")) == id:
			entry["back"] = profile.day


## Patients from earlier days who may come back today: seen in the last
## RECALL_DAYS days and not back already. Copies, so the day's casualty never
## changes the career's records.
static func past(profile: PlayerProfile, day: int) -> Array:
	var found := []
	for entry: Dictionary in profile.patients:
		var seen := int(entry.get("day", 0))
		if seen < day and seen >= day - RECALL_DAYS and int(entry.get("back", 0)) == 0 \
				and str(entry.get("condition", "")) != Outbreak.ID:
			found.append(entry.duplicate(true))
	return found


## The career's patient records from a save, kept only if every field is
## the right kind and sensible (an edited save can't smuggle in anything
## else), newest KEEP at most.
static func clean_patients(raw: Variant) -> Array:
	var kept := []
	if typeof(raw) != TYPE_ARRAY:
		return kept
	var keep := int(PatientParts.returns().get("keep", 40))
	for item: Variant in raw:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var entry := _clean_entry(item)
		if not entry.is_empty():
			kept.append(entry)
	while kept.size() > keep:
		kept.pop_front()
	return kept


static func _clean_entry(item: Dictionary) -> Dictionary:
	var entry := {}
	for key: String in ["id", "first", "last", "full", "community", "sex", "home", "voice", "personality", "job",
			"condition", "outcome"]:
		var value: Variant = item.get(key, "")
		if typeof(value) != TYPE_STRING or (value as String).length() > 60:
			return {}
		entry[key] = value
	for key: String in ["day", "age", "look", "back"]:
		var value: Variant = item.get(key, 0)
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
			return {}
		entry[key] = int(value)
	if str(entry["sex"]) not in ["m", "f"] or not NameMaker.COMMUNITIES.has(str(entry["community"])):
		return {}
	if str(entry["outcome"]) not in OUTCOMES or Conditions.get_condition(str(entry["condition"])).is_empty():
		return {}
	entry["look"] = absi(int(entry["look"])) % PatientLook.SEEDS
	if int(entry["age"]) < 0 or int(entry["age"]) > 110 or int(entry["day"]) < 1 or str(entry["id"]).is_empty() \
			or str(entry["full"]).is_empty():
		return {}
	if not str(entry["voice"]).is_empty() and not PatientVoices.has(str(entry["voice"])):
		entry["voice"] = ""
	if not PatientParts.personalities().has(str(entry["personality"])):
		entry["personality"] = ""
	return entry


## The end-of-day line for casualty, or "" if nobody was seen.
static func summary_line(sim: ShiftSim, xp: int) -> String:
	if sim == null:
		return ""
	var tally := sim.summary()
	if int(tally["seen"]) == 0:
		return ""
	var line := "Casualty: %d seen, %d right" % [int(tally["seen"]), int(tally["right"])]
	if int(tally["crashed"]) > 0:
		line += ", %d to intensive care" % int(tally["crashed"])
	return line + ", +%d XP" % xp
