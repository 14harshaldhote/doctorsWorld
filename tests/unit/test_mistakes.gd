extends TestCase
## Mistakes and deaths (stage 25): crashes and harmful plans that kill, the
## patient nobody can save, the lab's wrong results and critical calls, the
## nurse's read-back, the bed the handover forgot, the family, the wall,
## M&M, and how often it all happens.

const CAREFUL := ["Ready", "Honest", "Reassure", "Ask her", "Check", "Own it", "Calm", "Compromise", "To Aarav", "Gentle",
	"Careful", "Stay", "Patient first", "Answer", "Light", "Ask him", "The facts", "Grateful", "Plainly"]
const STEP := 1.0 / 30.0

var _rules_before: Variant = StoryBook._cache.get("mistakes")


func cleanup() -> void:
	if _rules_before == null:
		StoryBook._cache.erase("mistakes")
	else:
		StoryBook._cache["mistakes"] = _rules_before
	super()


## The rules with some chances changed, for one test.
func _with_chances(changed: Dictionary) -> void:
	var rules: Dictionary = Fates.data().duplicate(true)
	for key: String in changed:
		rules["chances"][key] = changed[key]
	StoryBook._cache["mistakes"] = rules


func _sim(day: int = 12) -> ShiftSim:
	var sim := ShiftSim.new(77, 8 * 60, 1.0)
	sim.day = day
	return sim


func _seen(sim: ShiftSim, condition_id: String) -> ShiftPatient:
	var patient := sim.make_patient(condition_id)
	sim.patients.append(patient)
	sim.take(patient)
	return patient


func _deaths(events: Array[Dictionary]) -> Array[Dictionary]:
	return events.filter(func(event: Dictionary) -> bool: return event["kind"] == "died")


func test_the_rules_are_complete_and_sensible() -> void:
	for key: String in ["crash_death", "harm_death", "doomed_shift", "lab_error", "readback_error", "forgotten_bed"]:
		var value := Fates.chance(key)
		expect(value > 0.0 and value < 0.6, "%s is a chance, not a certainty (%.2f)" % [key, value])
	for fault: String in Fates.FAULTS:
		expect(not Fates.fault_text(fault).is_empty(), "the wall can say %s" % fault)
		expect(not Fates.family_fault_text(fault).is_empty(), "the family scene can say %s" % fault)
	for id: String in Fates.doomed():
		expect(not Conditions.get_condition(id).is_empty() and Conditions.get_condition(id)["triage"] == "red",
			"%s is a real red illness" % id)
	for id: String in (Fates.data()["critical"] as Dictionary):
		var test := Fates.critical_test(id)
		expect((Conditions.get_condition(id).get("results", {}) as Dictionary).has(test),
			"%s's critical %s is a real result" % [id, test])
	for kind: String in Fates.lab_errors():
		for part: String in ["result", "call", "treat", "repeat"]:
			expect(not Fates.lab_line(kind, part, "Mr. Rao").is_empty(), "%s has a %s line" % [kind, part])
	for telling: String in Fates.TELLINGS:
		expect(not Fates.family_lines(telling).is_empty() and not Fates.telling_text(telling).is_empty(),
			"the family can be told %s" % telling)
	for line: String in Fates.family_spoken():
		for field: String in ["{", "}"]:
			expect(field not in line, "a family line has no blanks to fill: %s" % line)


func test_a_crash_can_kill_and_the_crash_team_sometimes_wins() -> void:
	var died := 0
	var icu := 0
	for with_seed in range(1, 41):
		var sim := ShiftSim.new(with_seed, 8 * 60, 1.0)
		sim.day = 12
		var patient := sim.make_patient("asthma")
		sim.patients.append(patient)
		patient.severity = ShiftSim.CRASH_AT - 0.01
		var events := sim.advance_to(sim.minute + 1)
		if patient.outcome == "died":
			died += 1
			expect_equal(patient.fault, "wait", "nobody got to them in time")
			expect_equal(_deaths(events).size(), 1, "and the shift says so once")
		elif patient.outcome == "crashed":
			icu += 1
	expect(died > 5 and icu > 5, "some die, some go to intensive care (%d died, %d to ICU)" % [died, icu])


func test_a_harmful_plan_can_kill_later_in_the_shift() -> void:
	_with_chances({"harm_death": 1.0, "readback_error": 0.0})
	var sim := _sim()
	var patient := _seen(sim, "appendicitis")
	var result := sim.decide(patient, _position(patient, "harm"))
	expect_equal(result["effect"], "harm", "the laxative")
	expect_equal(sim.deaths_due.size(), 1, "a death is coming")
	var events := sim.advance_to(sim.minute + 100)
	var deaths := _deaths(events)
	expect_equal(deaths.size(), 1, "and comes within the shift")
	expect_equal(patient.outcome, "died")
	expect_equal(patient.fault, "you", "the plan's fault")
	expect(str(deaths[0]["text"]).contains(str(result["why"])), "the news says why")
	expect_equal(sim.summary()["died"], 1, "the handover counts it")
	expect_equal(sim.summary()["wrong"], 1, "as a wrong call")


func test_the_patient_beyond_saving_dies_even_with_the_right_plan() -> void:
	_with_chances({"doomed_shift": 1.0, "readback_error": 0.0})
	var profile := PlayerProfile.new()
	profile.day = 14
	profile.set_count("hospital_seed", 99)
	var sim := ShiftDay.make(profile, 14, 8 * 60)
	expect(sim.doomed_at >= 8 * 60 + 60, "someone beyond saving is coming today")
	var events := sim.advance_to(sim.doomed_at)
	var doomed: ShiftPatient = null
	for patient in sim.patients:
		if patient.doomed:
			doomed = patient
	expect(doomed != null and doomed.triage() == "red", "by ambulance, red")
	if doomed == null:
		return
	expect(events.any(func(event: Dictionary) -> bool: return event["kind"] == "arrived" and event["patient"] == doomed),
		"and casualty hears about it")
	# Make room, so the doctor sees them at once.
	for other in sim.patients:
		if other != doomed and other.cubicle >= 0:
			other.state = "gone"
			other.cubicle = -1
	doomed.state = "waiting"
	doomed.cubicle = -1
	expect(sim.take(doomed), "seen straight away")
	var result := sim.decide(doomed, ShiftBot.position_of(doomed, true))
	expect(bool(result.get("right", false)), "the right plan")
	var later := sim.advance_to(sim.minute + 200)
	expect_equal(doomed.outcome, "died", "they die anyway")
	expect_equal(doomed.fault, "nobody", "and it's nobody's fault")
	expect(_deaths(later).size() >= 1, "the shift says so")


func test_the_same_day_brings_the_same_people_whatever_the_mistakes() -> void:
	# Who walks in never depends on the mistakes' dice.
	var first := _arrivals(1.0)
	var second := _arrivals(0.0)
	expect_equal(first, second, "the same people at the same times")


func _arrivals(lab_error: float) -> Array:
	_with_chances({"lab_error": lab_error, "doomed_shift": 0.0, "forgotten_bed": 0.0})
	var profile := PlayerProfile.new()
	profile.day = 12
	profile.set_count("hospital_seed", 31)
	var sim := ShiftDay.make(profile, 12, 8 * 60)
	ShiftBot.play(sim, 13 * 60)
	return sim.patients.filter(func(patient: ShiftPatient) -> bool: return not patient.returning).map(
		func(patient: ShiftPatient) -> String: return "%s@%d" % [patient.full_name(), patient.arrived_at])


func test_a_wrong_lab_result_can_be_caught_by_repeating_it() -> void:
	_with_chances({"lab_error": 1.0})
	var sim := _sim()
	var patient := _seen(sim, "appendicitis")
	sim.order(patient, "bloods")
	var events := sim.advance_to(sim.minute + 25)
	expect(patient.alert_open(), "the lab rang")
	expect(events.any(func(event: Dictionary) -> bool: return event["kind"] == "critical"), "as a call")
	var kind := str(patient.alert["error"])
	expect(kind in Fates.errors_for("bloods"), "with a wrong result (%s)" % kind)
	expect_equal(patient.results["bloods"], Fates.lab_line(kind, "result", patient.called()), "the card shows the wrong one")
	expect(sim.repeat_test(patient), "repeat it")
	expect(not patient.results.has("bloods"), "the wrong one is gone")
	var back := sim.advance_to(sim.minute + 25)
	expect_equal(patient.results["bloods"], Conditions.result(patient.condition, "bloods", patient.sex()),
		"the repeat is the true result")
	expect(patient.caught, "caught")
	expect(back.any(func(event: Dictionary) -> bool: return str(event["text"]) == Fates.lab_line(kind, "repeat", patient.called())),
		"and the lab says what went wrong")
	var right := sim.decide(patient, ShiftBot.position_of(patient, true))
	expect(int(right["score"]) > 0 and sim.summary()["caught"] == 1, "it counts")


func test_treating_a_wrong_lab_result_does_harm() -> void:
	_with_chances({"lab_error": 1.0, "harm_death": 1.0})
	var sim := _sim()
	var patient := _seen(sim, "appendicitis")
	sim.order(patient, "bloods")
	sim.advance_to(sim.minute + 25)
	var before := patient.severity
	var said := sim.treat_alert(patient)
	expect(not said.is_empty() and patient.severity > before + 20.0, "they get sicker (%s)" % said)
	expect_equal(sim.deaths_due.size(), 1, "and this time it kills")
	sim.advance_to(sim.minute + 100)
	expect_equal(patient.fault, "lab", "the wall says it was the lab's result")


func test_a_real_critical_result_is_rung_through_and_treating_it_helps() -> void:
	_with_chances({"lab_error": 0.0})
	var sim := _sim()
	var patient := _seen(sim, "hyperkalaemia")
	sim.order(patient, "bloods")
	var events := sim.advance_to(sim.minute + 25)
	expect(patient.alert_open() and str(patient.alert["error"]).is_empty(), "the lab rings about a real one")
	expect(events.any(func(event: Dictionary) -> bool: return event["kind"] == "critical"), "as a call from the lab")
	var before := patient.severity
	sim.treat_alert(patient)
	expect(patient.severity < before, "treating it helps")
	expect(sim.deaths_due.is_empty(), "and harms nobody")


func test_a_wrong_read_back_must_be_answered() -> void:
	_with_chances({"readback_error": 1.0, "harm_death": 0.0})
	var sim := _sim()
	var other := _seen(sim, "gastro")
	var patient := _seen(sim, "appendicitis")
	var result := sim.decide(patient, ShiftBot.position_of(patient, true))
	expect(result.has("readback"), "Priya reads it back for the wrong cubicle")
	expect(str(result["readback"]).contains("cubicle %d" % (other.cubicle + 1)), str(result.get("readback", "")))
	expect(sim.readback_open(patient), "it waits for an answer")
	var before := other.severity
	var heard := sim.answer_readback(patient, false)
	expect(other.severity > before + 20.0, "nodded through: the drug went to the wrong patient")
	expect(heard.contains(other.called()), heard)
	expect(not sim.readback_open(patient), "answered")
	# Corrected, nobody is harmed.
	var sim2 := _sim()
	var other2 := _seen(sim2, "gastro")
	var patient2 := _seen(sim2, "appendicitis")
	sim2.decide(patient2, ShiftBot.position_of(patient2, true))
	var calm := other2.severity
	expect(not sim2.answer_readback(patient2, true).is_empty() and other2.severity == calm, "corrected, all fine")


func test_the_handover_can_forget_a_bed() -> void:
	_with_chances({"forgotten_bed": 1.0, "doomed_shift": 0.0})
	var profile := PlayerProfile.new()
	profile.day = 12
	profile.set_count("hospital_seed", 5)
	var sim := ShiftDay.make(profile, 12, 8 * 60)
	var forgotten := sim.forgotten_patient()
	expect(forgotten != null, "someone was left out")
	if forgotten == null:
		return
	expect(forgotten.arrived_at < 8 * 60 and forgotten.waited(sim.minute) >= 60, "waiting since before the shift")
	expect(forgotten.board_line().begins_with(Fates.forgotten_line("board")), forgotten.board_line())
	expect(forgotten in sim.board(), "on the board for anyone who looks")
	sim.take(forgotten)
	sim.ask(forgotten, "pain")
	expect(not forgotten.board_line().begins_with(Fates.forgotten_line("board")), "seen now")
	# Two days on the same seed without the forgotten bed bring the same arrivals.
	_with_chances({"forgotten_bed": 0.0, "doomed_shift": 0.0})
	var plain := ShiftDay.make(profile, 12, 8 * 60)
	expect(plain.forgotten_patient() == null, "nobody forgotten this time")


func test_deaths_go_on_the_wall_and_never_walk_back_in() -> void:
	var profile := PlayerProfile.new()
	profile.day = 12
	var sim := _sim()
	var patient := _seen(sim, "heart_attack")
	sim.decide(patient, ShiftBot.position_of(patient, false))
	ShiftDay.record(profile, {"score": 10}, patient)
	patient.outcome = "died"
	patient.fault = "you"
	ShiftDay.note_death(profile, patient)
	expect_equal(profile.wall.size(), 1, "on the wall")
	expect_equal(profile.wall[0]["full"], patient.full_name())
	expect_equal(profile.wall[0]["fault"], "you")
	expect_equal(profile.count("deaths_you"), 1, "counted by fault")
	expect(ShiftDay.past(profile, 13).is_empty(), "they never come back")
	var saved := PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(profile.to_dict())))
	expect_equal(saved.wall, profile.wall, "the wall is saved")
	var junk := Fates.clean_wall([{"full": "X", "age": 3, "day": 1, "what": "y", "fault": "aliens"}, "no", {"full": 4},
		{"full": "Real Person", "age": 40, "day": 9, "what": "Asthma", "fault": "wait"}])
	expect_equal(junk.size(), 1, "an edited save can't put just anything on the wall")


func test_a_day_started_again_takes_its_deaths_back_down() -> void:
	var profile := PlayerProfile.new()
	profile.day = 12
	profile.begin_day()
	Fates.add_to_wall(profile.wall, {"full": "Ravi Kumar", "age": 50, "day": 12, "what": "Asthma", "fault": "wait"})
	expect(profile.begin_day(), "the day starts over")
	expect(profile.wall.is_empty(), "and today's names come down with it")


func test_how_often_patients_die() -> void:
	# Half a day in casualty, many careers: a careful doctor loses only those
	# nobody could save; one right two times in three loses about one patient
	# in three shifts, mostly to their own calls.
	var totals := {}
	for skill: float in [1.0, 0.7]:
		var deaths := {}
		var shifts := 0
		for hospital in range(1, 31):
			for day in [10, 14, 20]:
				var profile := PlayerProfile.new()
				profile.day = day
				profile.set_count("hospital_seed", hospital * 7 + 3)
				var sim := ShiftDay.make(profile, day, 8 * 60)
				var rng := SeededRandom.new(hospital * 100 + day)
				while sim.minute < 14 * 60:
					var spent := ShiftBot.step(sim, rng.chance(skill))
					sim.advance_to(mini(14 * 60, sim.minute + maxi(1, spent)))
				for patient in sim.patients:
					if patient.outcome == "died":
						deaths[patient.fault] = int(deaths.get(patient.fault, 0)) + 1
				for due: Array in sim.deaths_due:
					deaths[str(due[2])] = int(deaths.get(str(due[2]), 0)) + 1
				shifts += 1
		totals[skill] = [deaths, shifts]
	var careful: Dictionary = totals[1.0][0]
	expect(careful.keys().all(func(fault: String) -> bool: return fault == "nobody"), "careful: only nobody's fault %s" % careful)
	var mixed: Dictionary = totals[0.7][0]
	var rate := float(mixed.values().reduce(func(sum: int, value: int) -> int: return sum + value, 0)) / float(totals[0.7][1])
	expect(rate > 0.15 and rate < 0.6, "about one death in three shifts (%.2f: %s)" % [rate, mixed])
	expect(int(mixed.get("you", 0)) > int(mixed.get("nobody", 0)), "mostly from choices that could have gone differently")


func test_iyer_calls_an_mm_after_a_death_that_was_a_mistake() -> void:
	var profile := PlayerProfile.new()
	profile.name = "Asha Verma"
	profile.day = 12
	profile.minutes = 19 * 60
	var sim := _sim()
	var patient := _seen(sim, "dengue")
	patient.outcome = "died"
	patient.fault = "you"
	var note := PhoneWriter.mortality(profile, 12, sim)
	expect_equal(note.get("chat"), "iyer", "Dr. Iyer writes")
	expect(str(note.get("text", "")).contains("M&M") and str(note["text"]).contains(patient.called()), str(note.get("text")))
	patient.fault = "nobody"
	expect(PhoneWriter.mortality(profile, 12, sim).is_empty(), "nobody's fault: no meeting, only the wall")
	PhoneBook.note_day(profile, 12, sim)
	expect(bool(PhoneBook.state(profile)["days"]["12"]["lost"]), "home writes gently tonight")


# --- In the game ------------------------------------------------------------------

func _ward(day: int) -> Ward:
	var doctor := PlayerProfile.new()
	doctor.name = "Asha Verma"
	doctor.day = day
	doctor.opening_seen = true
	doctor.created = true
	doctor.total_xp = 800
	doctor.set_count("hospital_seed", 4242)
	for flag: String in ["op_rohit_done", "op_rohit_won"]:
		doctor.set_flag(flag)
	return add_node(Ward.new(doctor)) as Ward


func _frames(ward: Ward, seconds: float) -> void:
	for frame in int(seconds / STEP):
		ward.update(STEP)


func test_a_death_brings_the_family_and_the_name_goes_on_the_wall() -> void:
	var ward := _ward(12)
	ward.play_until(func() -> bool: return ward.mode == "walk", Ward.pick_tones(CAREFUL))
	var patient := ward.shift.make_patient("asthma")
	ward.shift.patients.append(patient)
	patient.asked["pain"] = true
	patient.fault = "you"
	ward._on_shift_event({"kind": "died", "patient": patient, "fault": "you", "text": "%s has died." % patient.called()})
	expect_equal(ward.profile.wall.size(), 1, "the name is on the wall at once")
	_frames(ward, 0.2)
	var card := ward.family_card()
	expect(card != null and ward.mode == "family", "the family is waiting")
	if card == null:
		return
	for telling: String in Fates.TELLINGS:
		expect(card.button("Tell_" + telling) != null, "the doctor can tell them %s" % telling)
	expect(not card.done_button.visible, "and must")
	card.button("Tell_plain").pressed.emit()
	expect(card.done_button.visible, "then it can close")
	expect(card.find_child("Fault", true, false) != null, "with whose fault it was")
	card.done_button.pressed.emit()
	expect(ward.family_card() == null and ward.mode == "walk", "back to work")
	expect_equal(ward.profile.count("told_plain"), 1, "the telling is counted")
	# Someone nobody saw is only a page.
	var unseen := ward.shift.make_patient("gastro")
	ward._toasts.clear()
	ward._on_shift_event({"kind": "died", "patient": unseen, "fault": "wait", "text": "Someone crashed."})
	_frames(ward, 0.2)
	expect(ward.family_card() == null, "no family scene for a stranger")
	expect_equal(ward.profile.wall.size(), 2, "but the wall keeps the name")
	ward.open_wall()
	expect(ward.wall != null and ward.wall.list.get_child_count() == 2, "the wall lists both")
	ward.wall.done_button.pressed.emit()
	expect(ward.wall == null and ward.mode == "walk", "and closes")


func test_the_card_offers_a_repeat_and_a_read_back() -> void:
	_with_chances({"lab_error": 1.0, "readback_error": 1.0, "harm_death": 0.0})
	var sim := _sim()
	var other := _seen(sim, "gastro")
	var patient := _seen(sim, "appendicitis")
	sim.order(patient, "bloods")
	sim.advance_to(sim.minute + 25)
	var panel := PatientPanel.new(patient, sim.minute)
	add_node(panel)
	expect(panel.button("Repeat") != null and panel.button("TreatResult") != null, "the lab call's two answers")
	sim.repeat_test(patient)
	panel.refresh(sim.minute)
	expect(panel.button("Repeat") == null, "answered")
	sim.advance_to(sim.minute + 25)
	var result := sim.decide(patient, ShiftBot.position_of(patient, true))
	panel.show_result(result, 10)
	expect(panel.button("Correct") != null and panel.button("Nod") != null, "the read-back's two answers")
	expect(not panel.done_button.visible, "the card waits for one")
	panel.readback_answered(sim.answer_readback(patient, true))
	expect(panel.done_button.visible and panel.find_child("ReadbackHeard", true, false) != null, "then closes")
	expect(other.severity < 60.0, "the other patient got nothing meant for someone else")


func test_day_five_loses_mrs_raman_whatever_is_done() -> void:
	var ward := _ward(5)
	ward.play_until(func() -> bool: return ward.mode == "end" or ward.done_beats.has("saroja_wall"),
		Ward.pick_tones(CAREFUL), null, 600.0)
	expect(ward.done_beats.has("saroja_end") and ward.done_beats.has("saroja_wall"), "her beats are played %s" % [ward.done_beats])
	expect(ward.profile.has_flag("saroja_died"), "she dies")
	expect(ward.profile.has_flag("saroja_told_plain"), "her son is told plainly")
	expect(ward.profile.wall.any(func(entry: Dictionary) -> bool: return entry["full"] == "Saroja Raman" and entry["fault"] == "nobody"),
		"the first name on the wall, nobody's fault")
	expect(not ward.present("saroja"), "and bed six is empty")


func test_the_phone_has_a_map_of_the_hospital() -> void:
	var profile := PlayerProfile.new()
	profile.day = 12
	var phone := PhonePanel.new(profile)
	phone.live_place = func() -> Dictionary: return {"here": "casualty", "next": "Bed 6: Mrs. Raman"}
	add_node(phone)
	phone._show("maps")
	var plan := phone.find_child("Plan", true, false) as HospitalMap
	expect(plan != null and plan.here == "casualty", "the plan lights up where you are")
	for place: Array in PhonePanel.PLACES:
		expect(phone.find_child("Place_" + str(place[0]), true, false) != null, "%s is listed" % place[1])


func _position(patient: ShiftPatient, effect: String) -> int:
	for position in patient.plan_order.size():
		if str(patient.shown_plan(position).get("effect", "")) == effect:
			return position
	return 0
