extends TestCase
## Casualty (stage 22): the people who walk in, their illnesses, and the
## shift that runs on hospital minutes. Everything here is pure rules, so
## whole shifts are played in a blink, over many seeds.

const SEEDS := 30
## 08:00 and 20:00, in minutes since midnight.
const EIGHT := 8 * 60
const EIGHT_PM := 20 * 60


func _arrived(events: Array[Dictionary]) -> Array:
	var found := []
	for event in events:
		if event["kind"] == "arrived":
			var patient: ShiftPatient = event["patient"]
			found.append("%d %s %s %d" % [patient.arrived_at, patient.condition_id, patient.full_name(), patient.age])
	return found


func _kinds(events: Array[Dictionary]) -> Array:
	return events.map(func(event: Dictionary) -> String: return str(event["kind"]))


## A sim with one patient of a condition already in a cubicle.
func _one(condition_id: String, seed_value: int = 7) -> Array:
	var sim := ShiftSim.new(seed_value, EIGHT, 0.0)
	var patient := sim.make_patient(condition_id)
	sim.patients.append(patient)
	sim.take(patient)
	return [sim, patient]


# --- Names ---------------------------------------------------------------------

func test_strangers_never_get_a_cast_name_or_a_real_one() -> void:
	var rng := SeededRandom.new(11)
	var cast_words := {}
	for id: String in StoryBook.cast():
		var entry: Variant = StoryBook.cast()[id]
		if typeof(entry) == TYPE_DICTIONARY:
			for word in str(entry.get("name", "")).replace(".", " ").split(" ", false):
				if word.length() > 2 and word not in ["Dr", "Mr", "Mrs", "Ms", "Sister", "The", "Your"]:
					cast_words[word.to_lower().replace("'", "")] = true
	expect(cast_words.size() > 40, "the cast's names are known: %d" % cast_words.size())
	for index in 3000:
		var person := NameMaker.make(rng, "", rng.next_int_in(1, 90))
		for word: String in [person["first"], person["last"]]:
			var low := word.to_lower().replace("'", "")
			expect(not cast_words.has(low), "%s is a cast name" % word)
			expect(low not in ["asha", "verma", "varun", "khanna", "harshal", "dhote"], "%s is not allowed" % word)
		expect(str(person["full"]) == "%s %s" % [person["first"], person["last"]], "full name joins the two")


func test_names_fit_the_person() -> void:
	var rng := SeededRandom.new(5)
	for index in 2000:
		var age := rng.next_int_in(1, 95)
		var sex := "m" if index % 2 == 0 else "f"
		var person := NameMaker.make(rng, sex, age)
		expect_equal(person["sex"], sex, "the sex asked for")
		var data: Dictionary = NameMaker.COMMUNITIES[person["community"]]
		var entries: Array = data[sex]
		var entry := ""
		for candidate: String in entries:
			if NameMaker.plain(candidate) == person["first"]:
				entry = candidate
		expect(not entry.is_empty(), "%s is a %s %s name" % [person["first"], person["community"], sex])
		expect(NameMaker.fits_age(entry, age), "%s suits a %d-year-old" % [entry, age])
		expect(person["last"] in data["last"], "%s is a %s surname" % [person["last"], person["community"]])
		expect(person["home"] in data["home"], "the home town is from the same community")


func test_names_are_many_and_the_same_seed_gives_the_same_person() -> void:
	var seen := {}
	var rng := SeededRandom.new(99)
	for index in 1000:
		seen[NameMaker.make(rng, "", 40)["full"]] = true
	expect(seen.size() > 600, "a thousand strangers have many names: %d" % seen.size())
	var first := NameMaker.make(SeededRandom.new(42), "f", 30)
	var again := NameMaker.make(SeededRandom.new(42), "f", 30)
	expect_equal(first, again, "the same seed, the same person")
	var relative := NameMaker.make(SeededRandom.new(3), "m", 60, str(first["community"]), str(first["last"]))
	expect_equal(relative["last"], first["last"], "a relative shares the surname")
	expect_equal(relative["community"], first["community"], "and the community")
	expect(NameMaker.COMMUNITIES.size() == NameMaker.WEIGHTS.size(), "every community has a weight")


func test_how_staff_address_people() -> void:
	var man := {"first": "Ganesh", "last": "Patil", "sex": "m"}
	var woman := {"first": "Rekha", "last": "Shah", "sex": "f"}
	expect_equal(NameMaker.called(man, 54), "Mr. Patil")
	expect_equal(NameMaker.called(woman, 52), "Mrs. Shah")
	expect_equal(NameMaker.called(woman, 23), "Ms. Shah")
	expect_equal(NameMaker.called(man, 12), "Ganesh", "a child by their first name")


# --- Illnesses -------------------------------------------------------------------

func test_every_illness_is_complete_and_has_one_right_plan() -> void:
	var ids := Conditions.ids()
	expect(ids.size() >= 14, "at least fourteen illnesses: %d" % ids.size())
	for id: String in ids:
		var condition := Conditions.get_condition(id)
		for key: String in ["name", "board", "triage", "start", "worsens", "vitals", "answers", "exam", "key", "go", "plans"]:
			expect(condition.has(key), "%s has %s" % [id, key])
		expect(str(condition["triage"]) in Conditions.TRIAGE, "%s's triage" % id)
		expect(str(condition["go"]) in Conditions.DESTINATIONS, "%s goes somewhere real" % id)
		var ages: Array = condition.get("age", [20, 60])
		expect(int(ages[0]) >= 1 and int(ages[0]) <= int(ages[1]), "%s's ages" % id)
		var starts: Array = condition["start"]
		expect(int(starts[0]) <= int(starts[1]) and int(starts[1]) < ShiftSim.WORSE_AT, "%s starts below the page" % id)
		for question: String in ShiftPatient.QUESTIONS:
			expect(not str((condition["answers"] as Dictionary).get(question, "")).is_empty(), "%s answers %s" % [id, question])
		for vital: String in ["pulse", "bp", "spo2", "breaths", "temp"]:
			var span: Array = (condition["vitals"] as Dictionary).get(vital, [])
			expect(span.size() == 2 and float(span[0]) <= float(span[1]), "%s's %s range" % [id, vital])
		for test: String in condition["key"]:
			expect(Conditions.TESTS.has(test), "%s's key test %s exists" % [id, test])
		for test: String in (condition.get("results", {}) as Dictionary):
			expect(Conditions.TESTS.has(test), "%s's result for %s is a real test" % [id, test])
		var plans: Array = condition["plans"]
		expect_equal(plans.size(), 4, "%s has four plans" % id)
		var right := 0
		for plan: Dictionary in plans:
			expect(not str(plan.get("text", "")).is_empty(), "%s plan has words" % id)
			expect(not str(plan.get("why", "")).is_empty(), "%s plan says why" % id)
			if bool(plan.get("right", false)):
				right += 1
			else:
				expect(str(plan.get("effect", "")) in ["worse", "harm", "back", "lucky"], "%s wrong plan's effect" % id)
		expect_equal(right, 1, "%s has exactly one right plan" % id)
		expect(Conditions.WEIGHTS.has(id), "%s walks in sometimes" % id)
	for id: String in Conditions.WEIGHTS:
		expect(id in ids, "weighted %s exists" % id)


func test_illnesses_are_no_dialogue_and_keep_real_names_out() -> void:
	var text := JSON.stringify(Conditions.all())
	expect(not text.contains("\"say\""), "no spoken lines, so no voices are expected for it")
	expect(not text.to_lower().contains("harshal"), "no real names")


func test_a_test_the_illness_doesnt_list_comes_back_normal() -> void:
	var colic := Conditions.get_condition("renal_colic")
	expect(Conditions.result(colic, "usg", "m") != Conditions.TESTS["usg"]["normal"], "the scan shows the stone")
	expect_equal(Conditions.result(colic, "ct", "m"), Conditions.TESTS["ct"]["normal"])
	expect_equal(Conditions.result(Conditions.get_condition("gastro"), "urine", "f"), "Clear. Pregnancy test negative.")
	expect(Conditions.useful(colic, "usg"), "a key test is useful")
	expect(not Conditions.useful(colic, "ct"), "a CT for colic here is not")


func test_illnesses_are_picked_by_weight_and_never_from_the_avoid_list() -> void:
	var rng := SeededRandom.new(8)
	var counts := {}
	for index in 6000:
		var id := Conditions.pick(rng, ["gastro"])
		expect(id != "gastro", "avoided")
		counts[id] = int(counts.get(id, 0)) + 1
	expect(int(counts.get("renal_colic", 0)) > int(counts.get("dka", 0)), "common things are common")
	expect(counts.size() == Conditions.WEIGHTS.size() - 1, "everything else turns up")


# --- The shift -------------------------------------------------------------------

func test_the_same_day_brings_the_same_people_whatever_you_do() -> void:
	for seed_value in [3, 17, 2026]:
		var idle := ShiftSim.new(seed_value, EIGHT, 1.0)
		var idle_events := idle.advance_to(EIGHT + 6 * 60)
		var busy := ShiftSim.new(seed_value, EIGHT, 1.0)
		var busy_events := ShiftBot.play(busy, EIGHT + 6 * 60)
		var idle_arrived := _arrived(idle_events)
		var busy_arrived := _arrived(busy_events)
		# The idle doctor's casualty fills and ambulances go elsewhere, so
		# compare up to the first one turned away.
		var cut := idle_arrived.size()
		for event in idle_events:
			if event["kind"] == "diverted":
				cut = 0
				for earlier in idle_events:
					if earlier == event:
						break
					if earlier["kind"] == "arrived":
						cut += 1
				break
		expect(cut >= 4, "seed %d: a few arrivals to compare (%d)" % [seed_value, cut])
		expect_equal(busy_arrived.slice(0, cut), idle_arrived.slice(0, cut), "seed %d: same people, same times" % seed_value)
		var again := ShiftSim.new(seed_value, EIGHT, 1.0)
		expect_equal(_arrived(ShiftBot.play(again, EIGHT + 6 * 60)), busy_arrived, "seed %d: a replay is identical" % seed_value)


func test_casualty_is_as_busy_as_the_hour() -> void:
	var total := 0
	var expected := 0.0
	for seed_value in SEEDS:
		var sim := ShiftSim.new(seed_value + 1, EIGHT, 1.0)
		var events := ShiftBot.play(sim, EIGHT + 12 * 60)
		total += _arrived(events).size() + _kinds(events).count("diverted")
	for minute in range(EIGHT, EIGHT + 12 * 60):
		expected += ShiftSim.new(1, EIGHT, 1.0).rate_at(minute) / 60.0
	expected *= SEEDS
	expect_between(total, expected * 0.85, expected * 1.15, "arrivals near the hourly rates (%d vs %.0f)" % [total, expected])
	var quiet := ShiftSim.new(1, EIGHT, 0.5)
	var busy := ShiftSim.new(1, EIGHT, 1.4)
	expect_near(busy.rate_at(EIGHT) / quiet.rate_at(EIGHT), 2.8, 0.001, "load scales the rate")
	expect(quiet.rate_at(3 * 60) < quiet.rate_at(18 * 60), "small hours are quieter than the evening")


func test_a_gentle_start_brings_the_chosen_first_patients() -> void:
	var sim := ShiftSim.new(4, EIGHT, 1.0)
	sim.first_arrivals = [[3, "wrist_fracture"], [20, "gastro"]]
	var events := sim.advance_to(EIGHT + 2)
	expect(_arrived(events).is_empty(), "nobody in the first couple of minutes")
	events = sim.advance_to(EIGHT + 3)
	expect_equal(_arrived(events).size(), 1, "the first one at three minutes")
	expect_equal(sim.patients[0].condition_id, "wrist_fracture")
	events = sim.advance_to(EIGHT + 19)
	expect(_arrived(events).is_empty(), "then nobody until the second")
	events = sim.advance_to(EIGHT + 20)
	expect_equal(sim.patients[-1].condition_id, "gastro", "the second at twenty minutes")


func test_an_untreated_patient_gets_worse_pages_you_then_crashes() -> void:
	var made := _one("heart_attack")
	var sim: ShiftSim = made[0]
	var patient: ShiftPatient = made[1]
	var events := sim.advance_to(EIGHT + 8 * 60)
	var kinds := _kinds(events)
	expect_equal(kinds.count("worse"), 1, "one page when they turn")
	expect_equal(kinds.count("crashed"), 1, "and they crash")
	expect(kinds.find("worse") < kinds.find("crashed"), "the page comes first")
	expect_equal(patient.outcome, "crashed")
	expect(not patient.is_here(), "the crash team took them")
	expect_equal(sim.free_cubicle(), 0, "the cubicle is free again")
	expect_equal(sim.summary()["crashed"], 1)


func test_results_come_back_after_their_time() -> void:
	var made := _one("renal_colic")
	var sim: ShiftSim = made[0]
	var patient: ShiftPatient = made[1]
	expect(sim.order(patient, "usg"), "ordered")
	expect(not sim.order(patient, "usg"), "not twice")
	expect(not sim.order(patient, "mri"), "not a test that doesn't exist")
	expect_equal(patient.pending_tests(), ["usg"])
	var events := sim.advance_to(EIGHT + 29)
	expect(not patient.results.has("usg"), "not back at 29 minutes")
	events = sim.advance_to(EIGHT + 30)
	expect(patient.results.has("usg"), "back at 30")
	expect_equal(_kinds(events), ["result"], "and the nurse says so")
	expect(str(events[0]["text"]).contains("ultrasound"), "the page names the test")
	expect(patient.pending_tests().is_empty(), "nothing pending")


func test_a_careful_right_plan_scores_well_and_they_get_better() -> void:
	var made := _one("renal_colic")
	var sim: ShiftSim = made[0]
	var patient: ShiftPatient = made[1]
	while patient.state == "seeing":
		var spent := ShiftBot.step(sim, true)
		sim.advance_to(sim.minute + spent)
	expect_equal(patient.outcome, "better")
	expect(patient.score >= 90, "careful and right: %d" % patient.score)
	expect_equal(patient.cubicle, -1, "the cubicle is free straight away")
	expect_equal(sim.free_cubicle(), 0)
	expect(patient.is_here(), "still on the board on their way out")
	sim.advance_to(sim.minute + ShiftSim.STAY_AFTER[1] + 1)
	expect(not patient.is_here(), "then gone")
	expect_between(ShiftSim.xp_for(patient.score), 14, 15, "experience for it")
	var rushed := _one("renal_colic", 8)
	var quick: ShiftPatient = rushed[1]
	var result: Dictionary = (rushed[0] as ShiftSim).decide(quick, ShiftBot.position_of(quick, true))
	expect(bool(result["right"]), "right")
	expect(quick.score < patient.score, "right without looking scores less: %d" % quick.score)
	expect((rushed[0] as ShiftSim).decide(quick, 0).is_empty(), "a patient is decided once")


func test_a_wrong_plan_says_why_and_does_what_it_says() -> void:
	var effects := {}
	for id: String in Conditions.ids():
		for position in 4:
			var made := _one(id, 30 + position)
			var sim: ShiftSim = made[0]
			var patient: ShiftPatient = made[1]
			var plan := patient.shown_plan(position)
			if bool(plan.get("right", false)):
				continue
			var before := patient.severity
			var result := sim.decide(patient, position)
			expect(not bool(result["right"]), "%s wrong" % id)
			expect(not str(result["why"]).is_empty(), "%s says why" % id)
			expect(int(result["score"]) <= 40, "%s wrong scores low: %d" % [id, result["score"]])
			var effect := str(result["effect"])
			effects[effect] = true
			match effect:
				"harm":
					expect(patient.severity > before, "%s harm makes them worse" % id)
					expect_equal(patient.outcome, "harmed")
				"back":
					expect_equal(sim.returns.size(), 1, "%s sent home comes back" % id)
					var events := sim.advance_to(sim.minute + 151)
					expect(_kinds(events).has("back"), "%s is back within the shift" % id)
					var back: ShiftPatient = sim.patients[-1]
					expect(back.returning and back.board_line().begins_with("Back · "), "the board says they're back")
					expect_equal(back.full_name(), patient.full_name(), "the same person")
					expect(back.severity > patient.severity, "and worse")
				"lucky":
					expect_equal(patient.outcome, "fine", "%s got away with it" % id)
				_:
					expect_equal(patient.outcome, "worse")
	for effect: String in ["worse", "harm", "back", "lucky"]:
		expect(effects.has(effect), "some wrong plan does %s" % effect)


func test_cubicles_fill_and_a_full_casualty_turns_ambulances_away() -> void:
	var sim := ShiftSim.new(12, EIGHT, 0.0)
	for index in ShiftSim.CUBICLES + ShiftSim.MAX_WAITING:
		sim.patients.append(sim.make_patient("gastro" if index % 2 == 0 else "wrist_fracture"))
	for index in ShiftSim.CUBICLES:
		expect(sim.take(sim.waiting()[0]), "cubicle %d" % (index + 1))
	expect(not sim.take(sim.waiting()[0]), "no fifth cubicle")
	expect_equal(sim.waiting().size(), ShiftSim.MAX_WAITING)
	sim.load = 50.0
	var events := sim.advance_to(EIGHT + 30)
	expect(_kinds(events).has("diverted"), "ambulances go elsewhere")
	expect_equal(sim.waiting().size(), ShiftSim.MAX_WAITING, "nobody new squeezes in")
	expect(sim.summary()["diverted"] > 0)


func test_the_board_puts_the_sickest_first() -> void:
	var sim := ShiftSim.new(2, EIGHT, 0.0)
	for id: String in ["gastro", "appendicitis", "heart_attack", "wrist_fracture", "asthma"]:
		sim.patients.append(sim.make_patient(id))
		sim.advance_to(sim.minute + 1)
	var order := sim.board().map(func(patient: ShiftPatient) -> String: return patient.condition_id)
	expect_equal(order, ["heart_attack", "asthma", "appendicitis", "gastro", "wrist_fracture"])
	expect(sim.board()[0].board_line().ends_with(str(Conditions.get_condition("heart_attack")["board"])), "the board line")


func test_a_green_patient_left_too_long_may_go_home() -> void:
	var left := 0
	for seed_value in SEEDS:
		var sim := ShiftSim.new(seed_value + 100, EIGHT, 0.0)
		var patient := sim.make_patient("wrist_fracture")
		sim.patients.append(patient)
		sim.advance_to(EIGHT + ShiftSim.LEAVE_AFTER - 1)
		expect(patient.is_here(), "nobody leaves before three hours")
		sim.advance_to(EIGHT + 8 * 60)
		if patient.outcome == "left":
			left += 1
	expect(left > SEEDS / 2, "most give up in the end: %d of %d" % [left, SEEDS])


func test_long_busy_shifts_stay_sane_and_quick() -> void:
	var started := Time.get_ticks_usec()
	var minutes := 0
	for seed_value in SEEDS:
		var sim := ShiftSim.new(seed_value + 500, 7 * 60, 1.4)
		sim.first_arrivals = [[3, "wrist_fracture"]]
		ShiftBot.play(sim, 7 * 60 + 14 * 60, seed_value % 3 != 0)
		minutes += 14 * 60
		var ids := {}
		var cubicles := {}
		for patient in sim.patients:
			expect(not ids.has(patient.id), "ids are unique")
			ids[patient.id] = true
			expect(patient.state in ["waiting", "seeing", "done", "gone"], "a real state: %s" % patient.state)
			expect_between(patient.severity, 0.0, ShiftSim.CRASH_AT, "severity in range")
			expect_between(patient.score, 0, 100, "score in range")
			if patient.cubicle >= 0:
				expect(patient.state == "seeing", "only someone being seen sits in a cubicle")
				expect(not cubicles.has(patient.cubicle), "one patient a cubicle")
				cubicles[patient.cubicle] = true
		expect(sim.waiting().size() <= ShiftSim.MAX_WAITING, "the waiting area never overflows")
		var tally := sim.summary()
		expect(int(tally["seen"]) >= 15, "seed %d: a busy shift sees plenty: %d" % [seed_value, tally["seen"]])
	var per_hour_ms := (Time.get_ticks_usec() - started) / 1000.0 / (minutes / 60.0)
	expect(per_hour_ms < 5.0, "an hospital hour costs %.2f ms to simulate" % per_hour_ms)


func test_a_careful_doctor_keeps_people_alive_on_a_normal_day() -> void:
	var crashed := 0
	var seen := 0
	for seed_value in SEEDS:
		var sim := ShiftSim.new(seed_value + 900, 7 * 60, 1.0)
		ShiftBot.play(sim, 7 * 60 + 12 * 60)
		var tally := sim.summary()
		crashed += int(tally["crashed"])
		seen += int(tally["seen"])
	expect(crashed <= SEEDS / 3, "a careful doctor rarely loses one to a crash: %d in %d shifts" % [crashed, SEEDS])
	expect(seen >= SEEDS * 15, "and sees plenty: %d" % seen)
