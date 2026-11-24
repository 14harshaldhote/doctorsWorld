extends TestCase
## Patients that never run out (stage 24): the library of real illnesses,
## the mixes and twists that change the right plan, who each patient is
## (job, temper, company, voice, name), the patients who come back on later
## days, the invented outbreak that always says it's invented, and the card
## and voices that show it all.

const STEP := 1.0 / 30.0
const CAREFUL := ["Ready", "Honest", "Reassure", "Ask her", "Check", "Own it", "Calm", "Compromise", "To Aarav", "Gentle",
	"Careful", "Stay", "Patient first", "Answer", "Light", "Ask him", "The facts", "Grateful"]
const SEED := 4242

var _settings_before: GameSettings = GameSettings.current
var _backend_before: SpeechBackend = Speech.backend
## What Speech was noting before (tools/voice_lines.gd notes every line the
## tests say, so a test that listens adds to it instead of wiping it).
var _listening_before: bool = Speech.listening
var _heard_before: Dictionary = Speech.heard


func cleanup() -> void:
	var heard_here := Speech.heard
	Speech.heard = _heard_before
	if _listening_before and not is_same(heard_here, _heard_before):
		Speech.heard.merge(heard_here)
	Speech.listening = _listening_before
	Speech.stop()
	Speech.use_backend(_backend_before)
	super()
	GameSettings.current = _settings_before


func _doctor(day: int = 12) -> PlayerProfile:
	var doctor := PlayerProfile.new()
	doctor.name = "Asha Verma"
	doctor.day = day
	doctor.opening_seen = true
	doctor.created = true
	doctor.total_xp = 800
	doctor.set_count("hospital_seed", SEED)
	for flag: String in ["op_rohit_done", "op_rohit_won"]:
		doctor.set_flag(flag)
	return doctor


func _ward(day: int = 12) -> Ward:
	return add_node(Ward.new(_doctor(day))) as Ward


func _frames(ward: Ward, seconds: float) -> void:
	for frame in int(seconds / STEP):
		ward.update(STEP)


func _walk_until(ward: Ward, done: Callable, seconds: float = 30.0) -> bool:
	for frame in int(seconds / STEP):
		if bool(done.call()):
			return true
		ward.update(STEP)
	return bool(done.call())


func _to_casualty(ward: Ward) -> void:
	ward.play_until(func() -> bool: return ward.mode == "walk", Ward.pick_tones(CAREFUL))
	ward._walk_to_door()
	_walk_until(ward, func() -> bool: return ward.place == "casualty")
	_frames(ward, 1.0)


## Opens the card for a patient made for the test.
func _see(ward: Ward, patient: ShiftPatient) -> PatientPanel:
	ward.shift.patients.append(patient)
	ward.see_patient(patient)
	_walk_until(ward, func() -> bool: return ward.panel != null)
	return ward.panel


## A patient made until they match (a mix, a child, a late stage...).
func _made(sim: ShiftSim, condition_id: String, wanted: Callable, tries: int = 400) -> ShiftPatient:
	for attempt in tries:
		var patient := sim.make_patient(condition_id)
		if bool(wanted.call(patient)):
			return patient
	return null


## Who answers: their sex and age (the patient, a parent or a workmate).
func _speaker(patient: ShiftPatient) -> Array:
	if patient.speaker == "self":
		return [patient.sex(), patient.age]
	return [str(patient.company.get("sex", "")), int(patient.company.get("age", 0))]


## True when a line can be put together from recorded lines of this voice
## (what VoiceBank does with the clips), checked against the catalogue.
func _covered(lines: Dictionary, who: String, text: String) -> bool:
	var pieces := PackedStringArray()
	for sentence in VoiceBank.sentences(text):
		var plain := VoiceBank.normalize(sentence)
		if not plain.is_empty():
			pieces.append(plain)
	if lines.has(who + "|" + " ".join(pieces)):
		return true
	var start := 0
	while start < pieces.size():
		var found := false
		for stop in range(pieces.size(), start, -1):
			if lines.has(who + "|" + " ".join(pieces.slice(start, stop))):
				start = stop
				found = true
				break
		if not found:
			return false
	return true


func _catalogue_keys() -> Dictionary:
	var keys := {}
	for line: Dictionary in PatientVoices.catalogue():
		keys[str(line["who"]) + "|" + VoiceBank.normalize(str(line["text"]))] = true
	return keys


# --- The library ---------------------------------------------------------------

func test_the_library_is_big_and_every_illness_is_complete() -> void:
	var ids := Conditions.ids()
	expect(ids.size() >= 55, "about forty new illnesses on top of the first fourteen (%d)" % ids.size())
	var jobs := {}
	for entry: Array in PatientParts.jobs(true):
		jobs[str(entry[0])] = true
	var relations := {}
	for group: String in PatientParts.company():
		for option: Array in PatientParts.company()[group]:
			relations[str(option[0])] = true
	var opening := {}
	for id: String in ids:
		var condition := Conditions.get_condition(id)
		var ages: Array = condition.get("age", [20, 60])
		var told := str(condition.get("told_by", ""))
		expect(told in ["", "parent", "colleague"], "%s: who tells it" % id)
		if told.is_empty():
			expect(int(ages[0]) >= 12, "%s: someone who answers for themselves is 12 or over" % id)
		if told == "parent":
			expect(int(ages[1]) < 12, "%s: a parent answers for a small child" % id)
		expect(Conditions.weight(id) > 0, "%s walks in" % id)
		var from_day := int(condition.get("from_day", 0))
		expect(from_day >= ShiftDay.FIRST_DAY and from_day <= 14, "%s opens by Day 14 (%d)" % [id, from_day])
		opening[from_day] = true
		expect(condition.has("plain"), "%s has a family's plain words for it" % id)
		for job: Variant in condition.get("jobs", []):
			expect(jobs.has(str(job)), "%s's job %s is in the job list" % [id, job])
		var with := str(condition.get("with", ""))
		expect(with.is_empty() or relations.has(with) or with in PatientMaker.WOMEN + PatientMaker.MEN + ["cousin"],
			"%s comes in with someone real (%s)" % [id, with])
		var late: Dictionary = condition.get("late", {})
		if late.is_empty():
			continue
		expect(float(late.get("chance", 0.0)) > 0.0 and float(late.get("chance", 0.0)) < 1.0, "%s: late sometimes" % id)
		for question: String in (late.get("answers", {}) as Dictionary):
			expect(question in ShiftPatient.QUESTIONS, "%s: late answer to a real question" % id)
		for test: String in (late.get("results", {}) as Dictionary):
			expect(Conditions.TESTS.has(test), "%s: late result for a real test" % id)
		var starts: Array = late.get("start", [0, 0])
		var early: Array = condition["start"]
		expect(int(starts[0]) > int(early[0]) and int(starts[1]) < ShiftSim.WORSE_AT, "%s: late starts worse, below the page" % id)
	expect(opening.size() >= 3, "new illnesses join over the first fortnight")


func test_the_parts_are_clean_words_with_no_real_names() -> void:
	var text := JSON.stringify(PatientParts.data()) + JSON.stringify(Conditions.all())
	expect(not text.to_lower().contains("harshal"), "no real names")
	for index in text.length():
		var code := text.unicode_at(index)
		if code >= 0x2190:
			expect(false, "plain characters only, no emoji or symbols: %s" % text.substr(maxi(0, index - 20), 40))
			break
	var names := JSON.stringify(NameMaker.COMMUNITIES)
	expect(not names.contains("\"Asha\""), "nobody else is called Asha")
	expect(not JSON.stringify(PatientParts.data()).contains("\"say\": \"\""), "nothing silent")


func test_every_mix_has_its_own_right_plan_and_the_usual_one_is_the_trap() -> void:
	var rng := SeededRandom.new(9)
	for id: String in PatientParts.extras():
		var extra: Dictionary = PatientParts.extras()[id]
		expect(not (extra.get("fits", {}) as Dictionary).is_empty(), "%s fits some illnesses" % id)
		for condition_id: String in extra.get("fits", {}):
			var base := Conditions.get_condition(condition_id)
			expect(not base.is_empty(), "%s fits a real illness (%s)" % [id, condition_id])
			if base.is_empty():
				continue
			expect(not PatientMaker.overlap(extra.get("ages", [0, 120]), base.get("age", [0, 120])).is_empty(),
				"%s: the ages of %s meet" % [id, condition_id])
			var usual := ""
			for plan: Dictionary in base["plans"]:
				if bool(plan.get("right", false)):
					usual = str(plan["text"])
			var ways := [false]
			if str(extra.get("known", "")).is_empty() or extra.has("hidden"):
				ways.append(true)
			for hidden: bool in ways:
				var case := base.duplicate(true)
				PatientMaker._apply_extra(case, id, condition_id, hidden, rng)
				var where := "%s + %s%s" % [condition_id, id, " (hidden)" if hidden else ""]
				var plans: Array = case["plans"]
				expect_equal(plans.size(), 4, "%s: four plans" % where)
				var right := 0
				for plan: Dictionary in plans:
					expect(not str(plan.get("text", "")).is_empty() and not str(plan.get("why", "")).is_empty(),
						"%s: every plan has words and a why" % where)
					if bool(plan.get("right", false)):
						right += 1
						expect(str(plan["text"]) != usual, "%s: the mix changes the right plan" % where)
					else:
						expect(str(plan.get("effect", "")) in ["worse", "harm", "back", "lucky"], "%s: a real effect" % where)
				expect_equal(right, 1, "%s: one right plan" % where)
				expect(str(case.get("go", "")) in Conditions.DESTINATIONS, "%s: goes somewhere real" % where)
				for test: String in case.get("key", []):
					expect(Conditions.TESTS.has(test), "%s: key test %s exists" % [where, test])
				for test: String in (case.get("results", {}) as Dictionary):
					expect(Conditions.TESTS.has(test), "%s: result for a real test" % where)
				var known := str(case.get("known", ""))
				expect(known.is_empty() == (hidden or str(extra.get("known", "")).is_empty()),
					"%s: on the card only when it isn't hidden" % where)
				expect(str((case["answers"] as Dictionary)["other"]).length() > str((base["answers"] as Dictionary)["other"]).length(),
					"%s: they say something about it when asked" % where)


# --- Who they are ----------------------------------------------------------------

func test_patients_are_whole_people_from_one_seed() -> void:
	var sim := ShiftSim.new(77, 8 * 60, 1.0)
	sim.day = 30
	var catalogue := _catalogue_keys()
	var seen_tempers := {}
	var seen_voices := {}
	var children := 0
	var late := 0
	var mixes := 0
	for index in 1500:
		var patient := sim.make_patient()
		var where := "%s (%s)" % [patient.condition_id, patient.full_name()]
		var speaking := _speaker(patient)
		expect(PatientVoices.fits(patient.voice, str(speaking[0]), int(speaking[1])), "%s: the voice fits who answers" % where)
		var temper: Dictionary = PatientParts.personalities().get(patient.personality, {})
		expect(not temper.is_empty() and patient.speaker in temper.get("speakers", []), "%s: a temper for who answers" % where)
		var shares := false
		for tone: Variant in temper.get("tones", []):
			shares = shares or tone in PatientParts.voices()[patient.voice].get("tones", [])
		expect(shares, "%s: the voice suits the temper (%s, %s)" % [where, patient.personality, patient.voice])
		seen_tempers[patient.personality] = true
		seen_voices[patient.voice] = true
		if patient.age < 12:
			children += 1
			expect_equal(patient.speaker, "parent", "%s: a small child's parent answers" % where)
			expect(str(patient.company.get("relation", "")) in ["mother", "father"], "%s: with a parent" % where)
			expect(patient.job.is_empty(), "%s: no job at that age" % where)
		elif not patient.job.is_empty():
			var fits := false
			for entry: Array in PatientParts.jobs(true):
				if str(entry[0]) == patient.job:
					fits = fits or (patient.age >= int(entry[2]) and patient.age <= int(entry[3])
						and (str(entry[1]).is_empty() or str(entry[1]) == patient.sex()))
			expect(fits, "%s: %s suits a %d year old" % [where, patient.job, patient.age])
		if not patient.company.is_empty() and str(patient.company["relation"]) in PatientParts.same_name():
			expect(str(patient.company["full"]).ends_with(" " + str(patient.person["last"])), "%s: family share a surname" % where)
		late += int(patient.stage == "late")
		mixes += int(not patient.extra.is_empty())
		var right := 0
		for plan: Dictionary in patient.plans():
			right += int(bool(plan.get("right", false)))
		expect_equal(right, 1, "%s: one right plan" % where)
		expect_equal(patient.plan_order.size(), patient.plans().size(), "%s: every plan on the card" % where)
		for question: String in ShiftPatient.QUESTIONS:
			var answer := str((patient.condition["answers"] as Dictionary).get(question, ""))
			expect(not answer.is_empty(), "%s answers %s" % [where, question])
			expect(_covered(catalogue, patient.voice, answer), "%s: every word of the %s answer is recorded for %s: %s" % [
				where, question, patient.voice, answer])
		if failures.size() > 12:
			break
	expect(children > 10, "small children come in, with a parent (%d)" % children)
	expect(late > 20 and mixes > 40, "some arrive late (%d) and some with a mix (%d)" % [late, mixes])
	expect(seen_tempers.size() == PatientParts.personalities().size(), "every temper turns up (%d)" % seen_tempers.size())
	expect(seen_voices.size() == PatientVoices.ids().size(), "every voice is used (%d)" % seen_voices.size())


func test_the_same_seed_makes_the_same_people() -> void:
	var first := ShiftSim.new(5150, 8 * 60, 1.0)
	var second := ShiftSim.new(5150, 8 * 60, 1.0)
	for sim: ShiftSim in [first, second]:
		sim.day = 20
	for index in 200:
		var a := first.make_patient()
		var b := second.make_patient()
		expect_equal([a.full_name(), a.age, a.condition_id, a.stage, a.extra, a.extra_hidden, a.voice, a.personality, a.job,
			a.company, a.condition["answers"], a.plan_order, a.look_seed],
			[b.full_name(), b.age, b.condition_id, b.stage, b.extra, b.extra_hidden, b.voice, b.personality, b.job,
			b.company, b.condition["answers"], b.plan_order, b.look_seed], "patient %d is the same" % index)


func test_making_a_patient_is_cheap() -> void:
	var sim := ShiftSim.new(31, 8 * 60, 1.0)
	sim.day = 40
	sim.make_patient()
	var started := Time.get_ticks_usec()
	var count := 1000
	for index in count:
		sim.make_patient()
	var each := (Time.get_ticks_usec() - started) / 1000.0 / count
	expect(each < 1.0, "a patient takes %.3f ms to make" % each)


func test_rarer_illnesses_join_as_the_career_goes_on() -> void:
	var early := {}
	var later := {}
	var rng := SeededRandom.new(3)
	for index in 4000:
		early[Conditions.pick(rng, [], ShiftDay.FIRST_DAY)] = true
		later[Conditions.pick(rng, [], 30)] = true
	for id: String in early:
		expect(int(Conditions.get_condition(id).get("from_day", 0)) <= ShiftDay.FIRST_DAY, "%s waits for its day" % id)
	expect_equal(later.size(), Conditions.ids().size(), "by Day 30 everything walks in")
	var rng_child := SeededRandom.new(4)
	for index in 300:
		var id := Conditions.pick(rng_child, [], 30, {}, 70, "f")
		var ages: Array = Conditions.get_condition(id)["age"]
		expect(70 >= int(ages[0]) and 70 <= int(ages[1]) and str(Conditions.get_condition(id).get("sex", "")) != "m",
			"a returning 70 year old woman gets something she can have (%s)" % id)


func test_a_late_arrival_is_further_along() -> void:
	var sim := ShiftSim.new(12, 8 * 60, 1.0)
	var base := Conditions.get_condition("appendicitis")
	var late: Dictionary = base["late"]
	var patient := _made(sim, "appendicitis", func(made: ShiftPatient) -> bool: return made.stage == "late")
	expect(patient != null, "appendicitis sometimes arrives late")
	if patient == null:
		return
	expect(str(patient.condition["answers"]["pain"]).ends_with(str(late["answers"]["pain"])), "they say how it's spread")
	expect_equal(str(patient.condition["exam"]), str(late["exam"]))
	expect_equal(str(patient.condition["results"]["usg"]), str(late["results"]["usg"]), "the scan shows it burst")
	expect(patient.severity >= float(late["start"][0]), "and they start sicker")
	expect(not patient.condition.has("late"), "the case keeps no copy of the stages")
	var early := _made(sim, "appendicitis", func(made: ShiftPatient) -> bool: return made.stage == "early")
	expect(early != null and str(early.condition["results"]["usg"]) == str(base["results"]["usg"]), "most come early")


func test_a_small_child_is_answered_by_a_parent_on_the_card() -> void:
	var ward := _ward(12)
	_to_casualty(ward)
	var child := ward.shift.make_patient("croup")
	expect_equal(child.speaker, "parent")
	var panel := _see(ward, child)
	var by := panel.find_child("AnsweredBy", true, false) as Label
	expect(by != null and by.text.contains(str(child.company["first"])) and by.text.ends_with("answers."),
		"the card says who answers: %s" % (by.text if by != null else "nothing"))
	expect(by.text.begins_with("His ") or by.text.begins_with("Her "), "as the child's parent")
	var about := panel.find_child("About", true, false) as Label
	expect(about != null and about.text.contains("with %s %s" % [child.their(), child.company["relation"]]),
		"who came in with them shows under the name")


# --- The card ------------------------------------------------------------------

func test_a_mix_on_the_card_is_in_amber_and_a_hidden_one_is_not() -> void:
	var ward := _ward(12)
	_to_casualty(ward)
	var shown := _made(ward.shift, "head_injury", func(made: ShiftPatient) -> bool:
		return made.extra == "warfarin" and not made.extra_hidden)
	expect(shown != null, "a head injury on warfarin")
	if shown == null:
		return
	var panel := _see(ward, shown)
	var known := panel.find_child("Known", true, false) as Label
	expect(known != null and known.text.begins_with("Known: on warfarin"), "the card says so up front")
	expect(known.get_theme_color("font_color").is_equal_approx(UiKit.AMBER), "in amber")
	panel.button("StepAway").pressed.emit()
	var quiet := _made(ward.shift, "hypoglycaemia", func(made: ShiftPatient) -> bool:
		return made.extra == "alcohol" and made.extra_hidden)
	expect(quiet != null, "a low sugar who denies the drinking")
	if quiet == null:
		return
	expect(quiet.known_line().is_empty(), "a hidden mix isn't on the card")
	expect(str(quiet.condition["answers"]["other"]).contains("Only at weddings"), "they deny it when asked")
	expect(str(quiet.condition["exam"]).contains("Smells of alcohol"), "the examination gives it away")


func test_the_card_fits_with_everything_on_it() -> void:
	var text_before := GameSettings.current.text_size
	for case: Array in [[Vector2i(1688, 780), 2], [Vector2i(1334, 750), 2], [Vector2i(2048, 1536), 2]]:
		var size: Vector2i = case[0]
		GameSettings.current.text_size = int(case[1])
		tree.root.size = size
		var ward := _ward(10)
		_to_casualty(ward)
		var patient := ward.shift.make_patient(Outbreak.ID)
		expect(patient.invented, "%s: day 10 has an invented fever" % size)
		patient.known_id = "d3_1"
		patient.known_day = 3
		patient.known_what = "the chest pain that wasn't the heart"
		patient.complication = true
		patient.job = "construction site supervisor"
		patient.company = {"relation": "daughter-in-law", "first": "Swagatika", "full": "Swagatika Mohanty", "sex": "f",
			"age": 30}
		var panel := _see(ward, patient)
		_frames(ward, 0.5)
		var made_up := panel.find_child("Invented", true, false) as Label
		expect(made_up != null and made_up.text.to_lower().contains("invented"), "%s: the card says it's invented" % size)
		var said := panel.find_child("Said", true, false) as Label
		expect(said.text.begins_with("Invented illness: ") and said.get_theme_color("font_color").is_equal_approx(UiKit.CORAL),
			"%s: so does the line under the name, in coral" % size)
		expect(panel.find_child("About", true, false) != null and panel.find_child("Known", true, false) != null,
			"%s: who they are and when you saw them" % size)
		# The header stays put above the scrolling questions: measured with
		# its fonts at the card's width, it leaves most of the card for them.
		var sheet := panel.sheet
		var screen := ward.get_viewport().get_visible_rect().size
		var inner := -sheet.offset_left - UiKit.px(12) - UiKit.px(18) * 2.0
		var tall := screen.y - UiKit.px(12) * 2.0 - UiKit.px(14) * 2.0
		var header := 0.0
		for child in (panel.find_child("Name", true, false) as Control).get_parent().get_children():
			var label := child as Label
			if label == null:
				continue
			var font := label.get_theme_font("font")
			header += font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, inner,
				label.get_theme_font_size("font_size")).y + UiKit.px(4)
		expect(header <= tall * 0.5, "%s: the header leaves most of the card to scroll (%.0f of %.0f)" % [size, header, tall])
		expect(-sheet.offset_left <= screen.x * 0.62 + UiKit.px(12) + 1.0, "%s: the patient stays in view" % size)
		ward.queue_free()
	GameSettings.current.text_size = text_before
	tree.root.size = Vector2i(1688, 780)


func test_answers_are_spoken_in_the_patients_voice_and_stop_with_the_card() -> void:
	GameSettings.current = GameSettings.new()
	var fake: SpeechBackend = load("res://tests/unit/fake_speech.gd").new()
	Speech.use_backend(fake)
	Speech.listening = true
	Speech.heard = {}
	var ward := _ward(12)
	_to_casualty(ward)
	var patient := ward.shift.make_patient("renal_colic")
	var panel := _see(ward, patient)
	panel.button("Ask_pain").pressed.emit()
	var answer := str(patient.condition["answers"]["pain"])
	expect(Speech.heard.has(patient.voice + "\t" + answer), "the answer is read in their voice (%s)" % patient.voice)
	expect(ward.answer_line() != 0, "and is being said")
	panel.button("StepAway").pressed.emit()
	expect_equal(ward.answer_line(), 0, "stepping away stops it")
	expect(not Speech.speaking(), "nothing carries on talking")


func test_patient_voices_read_by_the_phone_sound_like_their_sex() -> void:
	var fake: SpeechBackend = load("res://tests/unit/fake_speech.gd").new()
	Speech.use_backend(fake)
	var higher: Array = Speech.pools()["higher"].map(func(voice: Dictionary) -> String: return str(voice["id"]))
	var lower: Array = Speech.pools()["lower"].map(func(voice: Dictionary) -> String: return str(voice["id"]))
	for who: String in PatientVoices.ids():
		var picked := Speech.voice_for(who)
		var female := str(PatientParts.voices()[who]["sex"]) == "f"
		expect(str(picked.get("id", "")) in (higher if female else lower), "%s reads in a %s voice" % [who,
			"higher" if female else "lower"])


func test_every_patient_line_has_a_recording() -> void:
	VoiceBank.reset()
	var missing := []
	var total := 0
	for line: Dictionary in PatientVoices.catalogue():
		total += 1
		if VoiceBank.find(str(line["who"]), str(line["text"])).is_empty() and missing.size() < 5:
			missing.append("%s: %s" % [line["who"], line["text"]])
	expect(total > 1000, "every line in every voice that can say it (%d)" % total)
	expect(missing.is_empty(), "every patient line is recorded; missing e.g. %s" % [missing])
	var sim := ShiftSim.new(808, 8 * 60, 1.0)
	sim.day = 30
	for index in 200:
		var patient := sim.make_patient()
		for question: String in ShiftPatient.QUESTIONS:
			var answer := str(patient.condition["answers"][question])
			expect(not VoiceBank.find(patient.voice, answer).is_empty(), "%s's %s answer plays from clips" % [
				patient.condition_id, question])
		if failures.size() > 5:
			break


func test_a_line_is_put_together_from_recorded_sentences() -> void:
	VoiceBank.use({"lines": [
		{"who": "pm_young", "key": "remember me doctor you saw me the other day",
			"parts": [{"stream": AudioStreamWAV.new(), "length": 1.0, "words": [0.5, 1.0]}]},
		{"who": "pm_young", "key": "it hurts here", "parts": [{"stream": AudioStreamWAV.new(), "length": 0.5, "words": [0.5]}]},
	]})
	expect_equal(VoiceBank.sentences("Two days. Since the fest! Really?"), PackedStringArray(["Two days.", "Since the fest!", "Really?"]))
	expect_equal(VoiceBank.sentences("Temp 38.5 today."), PackedStringArray(["Temp 38.5 today."]), "a decimal is not an end")
	expect_equal(VoiceBank.find("pm_young", "Remember me, Doctor? You saw me the other day. It hurts here.").size(), 2,
		"a hello and an answer, one after the other")
	expect(VoiceBank.find("pm_young", "It hurts here. And here.").is_empty(), "nothing half said")
	expect(VoiceBank.find("pf_young", "It hurts here.").is_empty(), "only in the voice that recorded it")
	VoiceBank.reset()


# --- Outbreaks -----------------------------------------------------------------

func test_an_outbreak_comes_every_so_often_and_says_its_invented() -> void:
	var info := PatientParts.outbreak()
	var first := int(info["first_day"])
	var every := int(info["every"])
	var lasts := int(info["lasts"])
	for day in range(1, 80):
		expect(Outbreak.kind_on(0, day).is_empty(), "no hospital, no outbreak")
	for day in range(1, first):
		expect(Outbreak.kind_on(SEED, day).is_empty(), "none before Day %d" % first)
	var kind := Outbreak.kind_on(SEED, first)
	expect(not kind.is_empty() and Outbreak.starts_on(SEED, first), "one starts on Day %d" % first)
	for day in range(first, first + lasts):
		expect_equal(Outbreak.kind_on(SEED, day), kind, "the same fever for %d days" % lasts)
	expect(not Outbreak.starts_on(SEED, first + 1), "starting only once")
	expect(Outbreak.kind_on(SEED, first + lasts).is_empty(), "then it's gone")
	expect(Outbreak.starts_on(SEED, first + every) and Outbreak.kind_on(SEED, first + every) != kind, "and a new one comes")
	var kinds := {}
	for round in (info["kinds"] as Dictionary).size():
		kinds[Outbreak.kind_on(SEED, first + every * round)] = true
	expect_equal(kinds.size(), (info["kinds"] as Dictionary).size(), "every kind in turn")
	for name: String in info["kinds"]:
		var made := Outbreak.condition(name, SeededRandom.new(1))
		expect(str(made["name"]).begins_with("Invented: ") and bool(made["invented"]), "%s is labelled invented" % name)
		expect(str(made["label"]).to_lower().contains("invented"), "%s: the card label says so" % name)
		var right := 0
		for plan: Dictionary in made["plans"]:
			expect(str(plan["why"]).to_lower().contains("invented"), "%s: every explanation says it's invented" % name)
			right += int(bool(plan.get("right", false)))
		expect_equal(right, 1)
		expect(str(made["go"]) in Conditions.DESTINATIONS, "%s: isolation is a real place" % name)
	expect(Outbreak.news(SEED, first).to_lower().contains("invented"), "the news says it's invented too")
	expect(Outbreak.condition("nothing", SeededRandom.new(1)).is_empty())


func test_outbreak_patients_walk_in_only_while_it_lasts() -> void:
	var counts := {}
	for day: int in [9, 10, 11, 14]:
		var sim := ShiftSim.new(day * 13, 8 * 60, 1.0)
		sim.day = day
		sim.hospital = SEED
		var invented := 0
		for index in 300:
			var patient := sim.make_patient()
			invented += int(patient.invented)
			if patient.invented:
				expect_equal(patient.condition_id, Outbreak.ID)
		counts[day] = invented
	expect(int(counts[9]) == 0 and int(counts[14]) == 0, "not before or after (%s)" % counts)
	expect(int(counts[10]) > 10 and int(counts[11]) > 10, "a good few during (%s)" % counts)


# --- Coming back ---------------------------------------------------------------

func _entry(day: int, outcome: String, condition: String = "renal_colic") -> Dictionary:
	return {"id": "d%d_3" % day, "day": day, "first": "Sachin", "last": "Patil", "full": "Sachin Patil", "community": "marathi",
		"sex": "m", "home": "Satara", "age": 44, "look": 991, "voice": "pm_mid_warm", "personality": "chatty",
		"job": "auto driver", "condition": condition, "outcome": outcome, "back": 0}


func test_a_patient_from_an_earlier_day_is_the_same_person() -> void:
	var sim := ShiftSim.new(64, 8 * 60, 1.0)
	sim.day = 20
	var entry := _entry(12, "better")
	var patient := sim.make_patient("", entry)
	expect_equal(patient.full_name(), "Sachin Patil")
	expect_equal([patient.age, patient.sex(), patient.look_seed, str(patient.person["home"])], [44, "m", 991, "Satara"],
		"the same face, age and home")
	expect_equal(patient.job, "auto driver", "the same job")
	if patient.speaker == "self" and PatientVoices.fits("pm_mid_warm", "m", 44):
		expect_equal(patient.voice, "pm_mid_warm", "the same voice")
	expect(patient.board_line().begins_with("Seen on Day 12"), "the board remembers them")
	expect(patient.known_line().contains("You saw them on Day 12, for the kidney stone"), "so does the card")
	var hello: Array = PatientParts.returns()["hello"]
	var said := str(patient.condition["answers"]["pain"])
	var greets := false
	for line: Variant in hello:
		greets = greets or said.begins_with(str(line))
	expect(greets, "they say hello again")
	var worse := entry.duplicate()
	worse["worse"] = true
	var back := sim.make_patient("renal_colic", worse)
	expect(back.complication and back.condition_id == "renal_colic", "back with the same trouble")
	expect(back.known_line().contains("It never really settled."), "the card says it never settled")
	expect(str(back.condition["answers"]["pain"]).begins_with(str(PatientParts.returns()["again"][0])), "and so do they")


func test_patients_come_back_some_days_and_some_bring_sweets() -> void:
	var visits := 0
	var known := 0
	var worse := 0
	for seed_value in 30:
		var sim := ShiftSim.new(seed_value + 100, 8 * 60, 1.0)
		sim.day = 30
		for index in 12:
			var outcome: String = ["better", "harmed", "back", "better"][index % 4]
			var entry := _entry(20 + index % 9, outcome, ["renal_colic", "gastro", "dengue", "malaria"][index % 4])
			entry["id"] = "d%d_%d" % [20 + index % 9, index]
			entry["full"] = "Person %d" % index
			sim.past.append(entry)
		var came := {}
		var events := ShiftBot.play(sim, 20 * 60)
		for event: Dictionary in events:
			var patient: ShiftPatient = event.get("patient")
			if str(event["kind"]) == "visit":
				visits += 1
				expect_equal(int(event["xp"]), ShiftSim.SWEETS_XP)
				expect(str(event["text"]).contains("dropped in with"), "sweets for casualty: %s" % event["text"])
				var id := str(event["entry"]["id"])
				expect(not came.has(id), "once a day")
				came[id] = true
			elif str(event["kind"]) == "arrived" and patient != null and not patient.known_id.is_empty():
				known += 1
				worse += int(patient.complication)
				expect(not came.has(patient.known_id), "once a day")
				came[patient.known_id] = true
	expect(visits > 3, "cured patients drop in with sweets (%d)" % visits)
	expect(known > 10 and worse > 3, "and old patients come back (%d, %d worse)" % [known, worse])


func test_records_are_kept_cleaned_and_go_back_with_the_morning() -> void:
	var doctor := _doctor(15)
	doctor.begin_day()
	var sim := ShiftDay.make(doctor, 15, 9 * 60)
	var patient := sim.make_patient("gastro")
	patient.plan = 0
	patient.outcome = "better"
	var xp := ShiftDay.record(doctor, {"score": 80, "right": true}, patient)
	expect(xp > 0 and doctor.patients.size() == 1, "seen and remembered")
	var entry: Dictionary = doctor.patients[0]
	expect_equal([str(entry["full"]), int(entry["day"]), str(entry["condition"]), str(entry["outcome"])],
		[patient.full_name(), 15, "gastro", "better"])
	ShiftDay.record(doctor, {"score": 10, "right": false}, patient)
	expect_equal(doctor.patients.size(), 1, "seen twice today, one record")
	var fever := sim.make_patient("dengue")
	fever.condition_id = Outbreak.ID
	fever.plan = 0
	fever.outcome = "better"
	ShiftDay.record(doctor, {"score": 50}, fever)
	expect_equal(doctor.patients.size(), 1, "an invented fever isn't remembered")
	var copy := PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(doctor.to_dict())))
	expect_equal(copy.patients, doctor.patients, "records survive a save")
	doctor.begin_day()
	expect(doctor.patients.is_empty(), "a day started again forgets today's patients")
	for index in 60:
		var many := _entry(2 + index % 10, "better")
		many["id"] = "n%d" % index
		doctor.patients.append(many)
	doctor.patients = ShiftDay.clean_patients(doctor.patients)
	expect_equal(doctor.patients.size(), int(PatientParts.returns()["keep"]), "only the newest are kept")
	var bad := [
		"not a record", {"id": "x"}, _entry(3, "crashed"), _entry(3, "better", "made_up_illness"),
		_entry(0, "better"),
	]
	var wrong_community := _entry(3, "better")
	wrong_community["community"] = "martian"
	var long_name := _entry(3, "better")
	long_name["full"] = "A".repeat(200)
	var number_name := _entry(3, "better")
	number_name["first"] = 12
	bad.append_array([wrong_community, long_name, number_name])
	expect(ShiftDay.clean_patients(bad).is_empty(), "nothing odd gets in from an edited save")
	expect(ShiftDay.clean_patients("nope").is_empty() and ShiftDay.clean_patients(null).is_empty())
	var odd_voice := _entry(3, "better")
	odd_voice["voice"] = "iyer"
	odd_voice["personality"] = "villain"
	var cleaned: Dictionary = ShiftDay.clean_patients([odd_voice])[0]
	expect(str(cleaned["voice"]).is_empty() and str(cleaned["personality"]).is_empty(), "a cast voice or odd temper is dropped")


func test_who_can_come_back_today() -> void:
	var doctor := _doctor(30)
	doctor.patients = [_entry(5, "better"), _entry(12, "better"), _entry(29, "harmed"), _entry(30, "better")]
	(doctor.patients[0] as Dictionary)["id"] = "old"
	(doctor.patients[1] as Dictionary)["id"] = "fine"
	(doctor.patients[2] as Dictionary)["id"] = "yesterday"
	(doctor.patients[3] as Dictionary)["id"] = "today"
	var ids := ShiftDay.past(doctor, 30).map(func(entry: Dictionary) -> String: return str(entry["id"]))
	expect_equal(ids, ["fine", "yesterday"], "from the last %d days, not today" % ShiftDay.RECALL_DAYS)
	ShiftDay.note_return(doctor, "fine")
	ids = ShiftDay.past(doctor, 31).map(func(entry: Dictionary) -> String: return str(entry["id"]))
	expect_equal(ids, ["yesterday", "today"], "someone who came back waits to be seen anew")
	var past := ShiftDay.past(doctor, 31)
	(past[0] as Dictionary)["full"] = "Changed"
	expect(str((doctor.patients[2] as Dictionary)["full"]) != "Changed", "the day's casualty gets copies")


func test_a_visit_with_sweets_is_worth_a_little_and_marked() -> void:
	var ward := _ward(30)
	ward.play_until(func() -> bool: return ward.mode == "walk", Ward.pick_tones(CAREFUL))
	var entry := _entry(25, "better")
	ward.profile.patients = [entry.duplicate()]
	var xp := ward.profile.total_xp
	var before := ward.casualty_xp
	ward._toasts.clear()
	ward._on_shift_event({"kind": "visit", "patient": null, "text": "Mr. Patil, from Day 25, dropped in with a box of pedas.",
		"entry": entry, "xp": ShiftSim.SWEETS_XP})
	expect_equal(ward.profile.total_xp, xp + ShiftSim.SWEETS_XP, "a little experience")
	expect_equal(ward.casualty_xp, before + ShiftSim.SWEETS_XP, "counted in casualty's day")
	expect(ward.toasts_waiting()[-1].contains("pedas"), "the doctor hears about it, anywhere")
	expect_equal(int((ward.profile.patients[0] as Dictionary)["back"]), 30, "and they won't come back again for now")


# --- Names and the phone -------------------------------------------------------

func test_names_come_from_every_region_and_never_from_the_cast() -> void:
	var rng := SeededRandom.new(21)
	var groups := {}
	for index in 6000:
		var age := rng.next_int_in(1, 90)
		var person := NameMaker.make(rng, "", age)
		groups[str(person["community"])] = true
		expect(NameMaker.allowed(str(person["first"])) and NameMaker.allowed(str(person["last"])), "%s is nobody in the cast" % person["full"])
		if failures.size() > 3:
			break
	for group: String in ["bihari", "rajasthani", "odia", "sindhi"]:
		expect(groups.has(group) and NameMaker.WEIGHTS.has(group), "%s families walk in" % group)
	expect_equal(groups.size(), NameMaker.COMMUNITIES.size(), "every community turns up")
	for group: String in NameMaker.COMMUNITIES:
		var data: Dictionary = NameMaker.COMMUNITIES[group]
		for key: String in ["m", "f", "last", "home"]:
			var usable := 0
			for name: Variant in data[key]:
				usable += int(key == "home" or NameMaker.allowed(NameMaker.plain(str(name))))
			expect(usable >= 5, "%s has enough %s names (%d)" % [group, key, usable])
		for sex: String in ["m", "f"]:
			for age: int in [8, 40, 80]:
				var fits := 0
				for name: Variant in data[sex]:
					fits += int(NameMaker.fits_age(str(name), age) and NameMaker.allowed(NameMaker.plain(str(name))))
				expect(fits >= 3, "%s has names for a %d year old (%s)" % [group, age, sex])


func test_the_phone_thanks_in_plain_words_and_reports_the_outbreak() -> void:
	var doctor := _doctor(14)
	var found := {}
	for day in range(10, 60):
		var sim := ShiftSim.new(day, 8 * 60, 1.0)
		sim.day = day
		for index in 6:
			var patient := sim.make_patient()
			patient.plan = 0
			patient.outcome = "better"
			sim.patients.append(patient)
		var message := PhoneWriter.thanks(doctor, day, sim)
		if message.is_empty():
			continue
		var text := str(message["text"])
		expect(not text.contains("{"), "every gap filled: %s" % text)
		var who: ShiftPatient = null
		for patient: ShiftPatient in sim.patients:
			if str(message["id"]) == "k%d_%d" % [day, patient.id]:
				who = patient
		expect(who != null and not str(who.condition.get("plain", "")).is_empty(), "a thank-you for something worth thanking for")
		if who != null and not who.company.is_empty():
			expect_equal(str(message["name"]), str(who.company["full"]), "whoever came in with them writes")
			found["company"] = true
		found["any"] = true
	expect(found.has("any") and found.has("company"), "thank-yous arrive, some from the family who came in")
	var feed := PhoneWriter.items(_doctor(10)).filter(func(item: Dictionary) -> bool: return str(item["id"]) == "gen_outbreak_10")
	expect_equal(feed.size(), 1, "the outbreak makes the news on its first day")
	expect(str(feed[0]["text"]).contains("invented"), "saying it's invented")
	var none := PhoneWriter.items(_doctor(11)).filter(func(item: Dictionary) -> bool: return str(item["id"]).begins_with("gen_outbreak"))
	expect_equal(none.size(), 1, "and stays in the feed for the next day (the window), not posted twice")


func test_news_while_the_card_is_up_shows_beside_it() -> void:
	for size: Vector2i in [Vector2i(1688, 780), Vector2i(1334, 750), Vector2i(2048, 1536)]:
		tree.root.size = size
		var ward := _ward(15)
		_to_casualty(ward)
		var panel := _see(ward, ward.shift.make_patient("gastro"))
		ward.hud.toast("Red in casualty: Mrs. Kohli, 58 · Crushing chest pain, sweating, and her left arm feels heavy and odd.")
		_frames(ward, 0.2)
		var toast := ward.hud.toast_rect()
		var sheet := panel.sheet.get_global_rect()
		var screen := ward.get_viewport().get_visible_rect()
		expect(toast.end.x <= sheet.position.x + 1.0, "%s: the toast stays left of the card (%s, %s)" % [size, toast, sheet])
		expect(toast.position.x >= -1.0, "%s: and on the screen" % size)
		panel.button("StepAway").pressed.emit()
		ward.hud.toast("Your shift's over. Hand over at the nurses' station.")
		_frames(ward, 0.2)
		var centred := ward.hud.toast_rect()
		expect(absf(centred.get_center().x - screen.size.x * 0.5) < 2.0, "%s: back in the middle once it closes" % size)
		ward.queue_free()
	tree.root.size = Vector2i(1688, 780)
