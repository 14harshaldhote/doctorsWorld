extends TestCase
## The six training tasks' rules: good play scores well, mistakes cost
## points, and every score comes with an explanation.


func _run(task: TrainingTask, seconds: float, step: float = 1.0 / 30.0) -> void:
	for frame in int(seconds / step):
		task.tick(step)


func _note_text(task: TrainingTask) -> String:
	var lines := PackedStringArray()
	for note in task.notes():
		lines.append(str(note["text"]))
	return "\n".join(lines)


func test_every_task_can_be_made_and_has_a_title_and_trainer() -> void:
	for task_id: String in TrainingTask.IDS:
		var task := TrainingTask.make(task_id)
		expect(task != null, "%s is made" % task_id)
		expect_equal(task.id, task_id)
		expect(not task.title().is_empty(), "%s has a title" % task_id)
		expect(StoryBook.cast().has(str(TrainingTask.TRAINERS[task_id])), "%s has a trainer from the cast" % task_id)
		expect(not task.instruction().is_empty(), "%s says what to do" % task_id)
		expect(not task.finished)


func test_stars_follow_the_score() -> void:
	expect_equal(TrainingTask.stars_for(100), 3)
	expect_equal(TrainingTask.stars_for(85), 3)
	expect_equal(TrainingTask.stars_for(70), 2)
	expect_equal(TrainingTask.stars_for(45), 1)
	expect_equal(TrainingTask.stars_for(10), 0)


# --- Scrub in ------------------------------------------------------------------

func _scrub_perfectly(task: ScrubTask) -> void:
	for frame in 400:
		if task.finished:
			return
		var next := task.next_expected()
		if task.is_area(next):
			task.scrub(next, 0.1)
		else:
			task.do_step(next)


func test_a_perfect_scrub_scores_full_marks() -> void:
	var task := ScrubTask.new()
	_scrub_perfectly(task)
	expect(task.finished, "gloved and done")
	expect_equal(task.score(), 100)
	expect_equal(task.stars(), 3)
	expect(_note_text(task).contains("right order"), "the card says why it went well")


func test_scrub_steps_out_of_order_do_not_happen_and_cost_points() -> void:
	var task := ScrubTask.new()
	task.do_step("gloves")
	expect_equal(task.stage, 0, "no gloves on wet hands... or dry ones")
	expect(task.coach_warns and task.coach.contains("Gown first"), "the coach explains: %s" % task.coach)
	task.do_step("soap")
	expect(task.coach.contains("Water first"))
	_scrub_perfectly(task)
	expect_equal(task.mistakes, 2)
	expect_equal(task.score(), 100 - 2 * ScrubTask.POINTS_PER_MISTAKE)
	expect(_note_text(task).contains("Gown first"), "mistakes are explained on the card")


func test_touching_your_face_after_soap_means_soaping_again() -> void:
	var task := ScrubTask.new()
	task.do_step("nose")
	expect_equal(task.contaminations, 0, "before washing, it doesn't matter")
	task.do_step("water")
	task.do_step("soap")
	task.scrub("palms", 2.0)
	expect(task.area_done("palms"))
	task.do_step("mask")
	expect_equal(task.contaminations, 1)
	expect_equal(task.stage, 1, "back to the soap")
	expect(not task.area_done("palms"), "the scrubbing has to be done again")
	_scrub_perfectly(task)
	expect_equal(task.score(), 100 - ScrubTask.POINTS_PER_CONTAMINATION)


func test_scrubbing_takes_time_and_skipped_areas_are_named() -> void:
	var task := ScrubTask.new()
	task.do_step("water")
	task.do_step("soap")
	task.scrub("palms", 0.5)
	expect(not task.area_done("palms"), "half a second is not a scrub")
	task.scrub("palms", 1.0)
	expect(task.area_done("palms"))
	task.scrub("backs", 2.0)
	task.do_step("rinse")
	expect_equal(task.skipped.size(), 4, "four areas skipped")
	expect(task.coach.contains("thumbs"), "the coach names them")
	task.do_step("towel")
	task.do_step("gown")
	task.do_step("gloves")
	expect_equal(task.score(), 100 - 4 * ScrubTask.POINTS_PER_SKIPPED_AREA)
	expect(_note_text(task).contains("Germs hide there"))


# --- Read the monitor ---------------------------------------------------------

func test_vitals_know_what_is_normal() -> void:
	var vitals := Vitals.new()
	expect(vitals.problems().is_empty(), "the default patient is fine")
	vitals.spo2 = 88
	expect_equal(vitals.problems(), ["spo2"] as Array[String])
	expect_equal(vitals.problem_words("spo2"), "too low")
	expect_equal(vitals.value_text("spo2"), "88%")
	var rng := SeededRandom.new(3)
	for kind: String in Vitals.KINDS:
		for direction: String in ["high", "low"]:
			if kind == "spo2" and direction == "high":
				continue
			var sick := Vitals.with_problem(rng, kind, direction)
			expect_equal(sick.problems(), [kind] as Array[String], "%s %s is the only problem" % [kind, direction])
	for index in 20:
		expect(Vitals.healthy(rng).problems().is_empty(), "healthy numbers are healthy")


func _read_monitors(task: MonitorTask, right: bool, think: float = 1.0) -> void:
	for kind: String in Vitals.KINDS:
		task.learn(kind)
	task.start_quiz()
	for frame in 4000:
		if task.finished:
			return
		if not task.revealing and task.time_left <= MonitorTask.ROUND_TIME - think:
			var answer := task.answer_now()
			if not right:
				answer = "none" if answer != "none" else "hr"
			task.answer(answer)
		task.tick(1.0 / 30.0)


func test_reading_every_monitor_right_and_fast_scores_well() -> void:
	var task := MonitorTask.new(5)
	task.start_quiz()
	expect_equal(task.phase, "learn", "the numbers are explained before the quiz")
	_read_monitors(task, true)
	expect(task.finished)
	expect_equal(task.correct, MonitorTask.ROUNDS)
	expect(task.score() >= 90, "score %d" % task.score())
	expect(_note_text(task).contains("6 of 6"))


func test_wrong_answers_are_explained_with_the_normal_range() -> void:
	var task := MonitorTask.new(5)
	_read_monitors(task, false)
	expect_equal(task.correct, 0)
	expect(task.score() <= 10, "score %d" % task.score())
	expect(_note_text(task).contains("normal is"), "the card teaches the ranges")


func test_running_out_of_time_counts_as_a_miss() -> void:
	var task := MonitorTask.new(2)
	for kind: String in Vitals.KINDS:
		task.learn(kind)
	task.start_quiz()
	_run(task, MonitorTask.ROUND_TIME + 0.2)
	expect(task.revealing, "the answer is shown")
	expect(task.coach.begins_with("Too slow"), task.coach)
	expect_equal(task.round_index, 0)
	_run(task, MonitorTask.REVEAL_TIME + 0.1)
	expect_equal(task.round_index, 1, "on to the next patient")


# --- Take a history -----------------------------------------------------------

func test_the_history_case_loads_from_the_story_files() -> void:
	var task := HistoryTask.new()
	expect_equal(task.patient, "Mr. Ravi Kumar")
	expect_equal(task.limit, 5)
	expect(task.questions.size() >= 8, "plenty of questions to choose from")
	expect_equal(task.best_points(), 4 * HistoryTask.KEY_POINTS + HistoryTask.USEFUL_POINTS)


func test_asking_what_matters_finds_the_dangerous_facts() -> void:
	var task := HistoryTask.new()
	for question_id: String in ["allergy", "medicines", "onset", "meal", "where"]:
		expect(not task.ask(question_id).is_empty(), "%s gets an answer" % question_id)
	expect(task.finished, "five questions and done")
	expect_equal(task.score(), 100)
	expect(task.facts.has("Allergic to penicillin"), "facts go on the case card")
	expect(task.ask("smoke").is_empty(), "no more questions")


func test_small_talk_misses_the_allergy_and_says_why_it_matters() -> void:
	var task := HistoryTask.new()
	for question_id: String in ["cricket", "job", "where", "surgery", "onset"]:
		task.ask(question_id)
	expect(task.finished)
	expect_equal(task.stars(), 0)
	var text := _note_text(task)
	expect(text.contains("penicillin"), "the missed allergy is explained")
	expect(text.contains("blood thinner"), "and the medicine")
	expect(text.contains("small talk"))


func test_a_question_can_only_be_asked_once() -> void:
	var task := HistoryTask.new()
	task.ask("allergy")
	expect(task.ask("allergy").is_empty())
	expect_equal(task.remaining(), 4)
	task.finish_early()
	expect(task.finished, "you can stop early")


# --- Instruments --------------------------------------------------------------

func test_every_instrument_has_a_name_a_job_calls_and_a_model() -> void:
	for instrument: String in Instruments.ALL:
		expect(not Instruments.name_of(instrument).is_empty())
		expect(not Instruments.job_of(instrument).is_empty())
		expect((Instruments.CALLS[instrument] as Array).size() >= 2, "%s has calls" % instrument)
		var model := Instruments.make(instrument)
		expect(model.get_child_count() > 0, "%s has a model" % instrument)
		model.free()


func _play_instruments(task: InstrumentTask, right: bool, think: float = 1.0) -> void:
	var waited := 0.0
	for frame in 4000:
		if task.finished:
			return
		if not task.revealing:
			waited += 1.0 / 30.0
			if waited >= think:
				waited = 0.0
				var pick := task.wanted
				if not right:
					pick = Instruments.ALL[(Instruments.ALL.find(task.wanted) + 1) % Instruments.ALL.size()]
				task.pick(pick)
		task.tick(1.0 / 30.0)


func test_knowing_every_instrument_scores_full_marks() -> void:
	var task := InstrumentTask.new(4)
	expect_equal(task.part, "match")
	_play_instruments(task, true, 0.5)
	expect(task.finished)
	expect(task.score() >= 95, "score %d" % task.score())
	expect_equal(task.first_try, InstrumentTask.MATCH_ROUNDS + InstrumentTask.CALL_ROUNDS)


func test_wrong_instruments_are_explained_and_the_clock_runs_out() -> void:
	var task := InstrumentTask.new(4)
	var wanted := task.wanted
	var other: String = Instruments.ALL[(Instruments.ALL.find(wanted) + 1) % Instruments.ALL.size()]
	task.pick(other)
	expect(task.coach_warns and task.coach.contains(Instruments.name_of(other).to_lower()), task.coach)
	_play_instruments(task, false, 0.3)
	expect(task.finished, "the calls time out and the task ends")
	expect(task.score() < 40, "score %d" % task.score())
	expect(_note_text(task).contains("mixed up") or _note_text(task).contains("froze"))


# --- IV line ------------------------------------------------------------------

func _hold_steady(task: IvTask, skill: float) -> void:
	for frame in 200:
		if task.finished:
			return
		task.nudge(-task.offset * skill)
		task.tick(1.0 / 30.0)


func test_a_good_vein_a_good_angle_and_steady_hands() -> void:
	var task := IvTask.new(3)
	task.pick_vein("forearm")
	task.set_angle(20)
	task.insert()
	expect_equal(task.phase, "steady")
	_hold_steady(task, 1.0)
	expect(task.finished)
	expect(task.score() >= 95, "score %d" % task.score())
	expect(task.coach.contains("Flashback"), task.coach)


func test_a_bad_vein_and_a_steep_angle_and_shaky_hands() -> void:
	var task := IvTask.new(3)
	task.pick_vein("wrist")
	expect(task.coach_warns, "the coach warns about the wrist")
	task.set_angle(50)
	task.insert()
	expect(task.coach.contains("steep"), task.coach)
	_hold_steady(task, 0.0)
	expect(task.finished)
	expect(task.score() < 40, "score %d" % task.score())
	var text := _note_text(task)
	expect(text.contains("15 to 30"), "the card gives the right angle")
	expect(text.contains("forearm"), "and the right vein")


func test_the_wrist_vein_sits_by_the_wrist() -> void:
	for attempt in 5:
		var task := IvTask.new(attempt)
		expect(float(task.slots["wrist"]) < float(task.slots["forearm"]))
		expect(float(task.slots["wrist"]) < float(task.slots["thin"]))


# --- Stitching ----------------------------------------------------------------

func test_even_stitches_end_to_end_score_full_marks() -> void:
	var task := StitchTask.new()
	var count := 8
	for index in count:
		var t := 0.04 + 0.92 * index / (count - 1)
		expect(task.place(task.point_at(t)), "stitch %d placed" % index)
	task.tie_off()
	expect(task.finished)
	expect(task.score() >= 95, "score %d" % task.score())
	expect(_note_text(task).contains("Even spacing"))


func test_missing_the_cut_and_bunching_stitches_cost_points() -> void:
	var task := StitchTask.new()
	expect(not task.place(Vector2(6, 7.5)), "far from the cut is a miss")
	expect_equal(task.misses, 1)
	for t: float in [0.3, 0.33, 0.36, 0.6]:
		task.place(task.point_at(t) + Vector2(0, 0.5))
	task.tie_off()
	expect(task.score() < 40, "score %d" % task.score())
	var text := _note_text(task)
	expect(text.contains("off the line"), "accuracy is explained")
	expect(text.contains("Uneven"), "spacing is explained")
	expect(text.contains("end to end"), "coverage is explained")
