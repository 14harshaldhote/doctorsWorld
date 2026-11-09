extends TestCase
## The two skills learnt on the ward: examining a patient and reading an
## X-ray. The rules and scores, the cases in story/cases.json, and the
## screens over the ward.

const JOINTS := ["Head", "Torso", "ElbowR", "ElbowL", "HipR", "HipL", "Hips", "KneeR", "KneeL"]


func test_every_examination_and_xray_case_is_complete() -> void:
	var cases := StoryBook.chapter("cases")
	var cast := StoryBook.cast()
	var exams := 0
	var scans := 0
	for case_id: String in cases:
		var data: Dictionary = cases[case_id]
		match str(data.get("kind", "history")):
			"exam":
				exams += 1
				for key in ["patient", "about", "actor", "body", "opening", "spots", "diagnoses"]:
					expect(data.has(key), "%s has %s" % [case_id, key])
				expect(cast.has(str(data.get("actor", ""))), "%s is someone in the cast" % case_id)
				expect(str(data.get("body", "")) in ["belly", "wrist", "trauma"], "%s frames a known body part" % case_id)
				var ids := {}
				var keys := 0
				for entry: Dictionary in data.get("spots", []):
					var spot_id := str(entry.get("id", ""))
					expect(not spot_id.is_empty() and not ids.has(spot_id), "%s: spot ids are unique" % case_id)
					ids[spot_id] = true
					var at: Array = entry.get("at", [])
					expect(at.size() == 4 and str(at[0]) in JOINTS, "%s.%s is on a joint of the body" % [case_id, spot_id])
					expect(not str(entry.get("label", "")).is_empty() and not str(entry.get("finding", "")).is_empty(),
						"%s.%s has a label and a finding" % [case_id, spot_id])
					var weight := str(entry.get("weight", ""))
					expect(weight in ["key", "useful", "none"], "%s.%s weight is known" % [case_id, spot_id])
					if weight == "key":
						keys += 1
						expect(not str(entry.get("why", "")).is_empty(), "%s.%s explains why it matters" % [case_id, spot_id])
				expect(keys >= 2, "%s has findings that matter" % case_id)
				_expect_one_right(case_id, data.get("diagnoses", []))
			"scan":
				scans += 1
				for key in ["patient", "about", "truth", "opening", "lines", "answers"]:
					expect(data.has(key), "%s has %s" % [case_id, key])
				expect(str(data.get("truth", "")) in ["battery", "coin", "none"], "%s shows something known" % case_id)
				for line in ["zoom", "side", "missed_zoom", "missed_side"]:
					expect(not str((data.get("lines", {}) as Dictionary).get(line, "")).is_empty(), "%s has the %s line" % [case_id, line])
				_expect_one_right(case_id, data.get("answers", []))
	expect(exams >= 4, "four patients to examine")
	expect(scans >= 2, "and X-rays to read")


func _expect_one_right(case_id: String, choices: Array) -> void:
	var right := 0
	for entry: Dictionary in choices:
		expect(not str(entry.get("text", "")).is_empty() and not str(entry.get("why", "")).is_empty(),
			"%s.%s has text and a reason" % [case_id, entry.get("id", "")])
		if bool(entry.get("right", false)):
			right += 1
	expect_equal(right, 1, "%s has exactly one right answer" % case_id)


# --- Examining -------------------------------------------------------------------

func test_a_careful_examination_scores_well() -> void:
	var exam := ExamTask.new("lakshmi_exam")
	expect_equal(exam.patient, "Lakshmi Pillai")
	expect_equal(exam.him, "her")
	expect_equal(exam.phase, "examine")
	expect(not exam.coach.is_empty(), "she speaks first")
	for spot_id in ["llq", "rlq", "eyes", "temp", "pulse", "ruq"]:
		expect(not exam.examine(spot_id).is_empty(), spot_id)
	expect(not exam.hurt_first, "the sore place came after the gentle ones")
	expect_equal(exam.keys_found(), exam.key_count())
	expect(exam.facts.size() >= 5, "the findings are written down")
	expect_equal(exam.examine("ruq"), "", "a place is examined once")
	exam.ready_to_decide()
	expect_equal(exam.phase, "decide")
	exam.decide("gallbladder")
	expect(exam.finished)
	expect(exam.diagnosed_right())
	expect_equal(exam.score(), 100)
	expect(bool(exam.notes()[0]["ok"]), "every finding found")


func test_pressing_the_sore_place_first_hurts_and_costs_care() -> void:
	var exam := ExamTask.new("lakshmi_exam")
	exam.examine("ruq")
	expect(exam.hurt_first, "she guarded")
	expect(exam.coach_warns, "the coach warns")
	expect_equal(exam.care_points(), 0)
	for spot_id in ["eyes", "temp"]:
		exam.examine(spot_id)
	exam.ready_to_decide()
	exam.decide("gallbladder")
	expect_equal(exam.score(), ExamTask.KEY_POINTS + ExamTask.DIAGNOSIS_POINTS, "no points for care")
	var texts := []
	for note in exam.notes():
		texts.append(str(note["text"]))
	expect(" ".join(texts).contains("sore spot first"), "the score card says why")


func test_wrong_answers_and_wasted_checks_cost_points() -> void:
	var exam := ExamTask.new("joseph_exam")
	for spot_id in ["press", "eyes", "look"]:
		exam.examine(spot_id)
	expect_equal(exam.wasted(), 1)
	exam.ready_to_decide()
	exam.decide("constipation")
	expect(not exam.diagnosed_right())
	expect(exam.score() < 40, "a missed blockage scores badly: %d" % exam.score())
	var texts := []
	for note in exam.notes():
		texts.append(str(note["text"]))
	expect(" ".join(texts).contains("tinkling") or " ".join(texts).contains("Tinkling"), "the missed finding is explained")


func test_deciding_needs_at_least_one_finding() -> void:
	var exam := ExamTask.new("kunal_exam")
	exam.ready_to_decide()
	expect_equal(exam.phase, "examine", "examine something first")
	exam.decide("sprain")
	expect(not exam.finished)


func test_a_bleeding_patient_weakens_until_pressure_goes_on() -> void:
	var exam := ExamTask.new("rider_exam")
	expect(exam.has_vitals)
	expect(exam.bleeding())
	var start := exam.stability
	var heart := exam.vitals.hr
	exam.tick(5.0)
	expect(exam.stability < start, "stability falls")
	expect(exam.vitals.hr > heart, "his heart races")
	exam.tick(1000.0)
	expect_equal(exam.stability, ExamTask.FLOOR, "a senior arrives before the worst")
	var fresh := ExamTask.new("rider_exam")
	fresh.tick(3.0)
	fresh.examine("thigh")
	expect(not fresh.bleeding(), "pressure stops it")
	var held := fresh.stability
	fresh.tick(10.0)
	expect_equal(fresh.stability, held, "and he holds steady")
	for spot_id in ["airway", "breathing", "pulse"]:
		fresh.examine(spot_id)
	fresh.ready_to_decide()
	fresh.decide("artery")
	expect_equal(fresh.care_points(), ExamTask.CARE_POINTS, "pressure inside %d seconds" % int(ExamTask.QUICK))
	expect_equal(fresh.score(), 100)


func test_slow_pressure_costs_care() -> void:
	var exam := ExamTask.new("rider_exam")
	for spot_id in ["airway", "breathing", "pulse"]:
		exam.examine(spot_id)
		exam.tick(6.0)
	exam.examine("thigh")
	expect(exam.pressure_at > ExamTask.QUICK)
	expect(exam.care_points() < ExamTask.CARE_POINTS, "late pressure earns less")


# --- Reading an X-ray ------------------------------------------------------------

func test_reading_a_film_properly_finds_the_battery() -> void:
	var scan := ScanTask.new("aarav_scan")
	expect_equal(scan.truth, "battery")
	expect(scan.instruction().contains("Tap"), "first, look closer")
	scan.toggle_zoom()
	expect(scan.looked_zoom and scan.zoomed)
	expect(scan.coach.contains("halo"), "Dr. Iyer points out the halo")
	scan.show_view("side")
	expect(scan.looked_side)
	expect(not scan.zoomed, "turning to the side zooms out")
	scan.tick(5.0)
	scan.answer("battery")
	expect(scan.finished and scan.answered_right())
	expect_equal(scan.score(), 100)


func test_rushing_a_film_misses_the_battery() -> void:
	var scan := ScanTask.new("aarav_scan")
	scan.answer("coin")
	expect(scan.finished and not scan.answered_right())
	expect_equal(scan.score(), 0)
	var texts := []
	for note in scan.notes():
		texts.append(str(note["text"]))
	expect(" ".join(texts).contains("halo"), "the score card explains what was missed")


func test_a_coin_is_a_coin() -> void:
	var scan := ScanTask.new("teaching_scan")
	scan.toggle_zoom()
	scan.show_view("side")
	scan.tick(1.0)
	scan.answer("coin")
	expect(scan.answered_right())
	expect_equal(scan.score(), 100 - ScanTask.PATIENCE_POINTS, "right, but quick")


func test_the_film_draws_what_is_there() -> void:
	var film := add_node(XrayFilm.new()) as XrayFilm
	film.size = Vector2(400, 400)
	film.truth = "battery"
	expect_equal(film.object_centre(), Vector2(200, 136))
	film.set_state("front", true)
	expect_equal(film.object_centre(), Vector2(200, 200), "zoomed, the object fills the middle")
	expect(film.object_radius() > 100.0)
	var taps := [0]
	film.object_tapped.connect(func() -> void: taps[0] += 1)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(200, 200)
	film._gui_input(press)
	press.position = Vector2(5, 395)
	film._gui_input(press)
	expect_equal(taps[0], 1, "only a tap on the object counts")
