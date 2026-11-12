extends TestCase
## The Junior Resident's story, Days 9 to 13: the time jump, the three new
## operations (a cut hand, a keyhole gallbladder, a stuck hernia), the
## department meeting, the VIP and the review that makes a Senior Resident.

const NEW_OPERATIONS := ["wound", "gallbladder", "hernia"]
const CAREFUL := ["Ready", "Calm", "Honest", "Careful", "Plain", "Explain", "Question", "Patient first", "Help",
	"Grateful", "Thorough"]


func _ward(day: int, flags: Array = []) -> Ward:
	var doctor := PlayerProfile.new()
	doctor.name = "Asha Verma"
	doctor.day = day
	doctor.opening_seen = true
	doctor.created = true
	doctor.total_xp = LevelCurve.total_xp_to_reach(Rank.FIRST_LEVELS[Rank.JUNIOR_RESIDENT]) + 400
	doctor.rank_held = Rank.JUNIOR_RESIDENT
	for flag: String in ["op_rohit_done", "op_rohit_won", "promoted", "beds_saved", "rider_treated"] + flags:
		doctor.set_flag(flag)
	return add_node(Ward.new(doctor)) as Ward


## Plays the ward's day to its end, noting every place the doctor works in.
func _play_day(ward: Ward, tones: Array, quality: String = "good", places: Array = []) -> bool:
	var finished := [false]
	ward.day_finished.connect(func() -> void: finished[0] = true)
	var bot := AutoPlayer.new()
	bot.quality = quality
	var until := func() -> bool:
		if not places.has(ward.place):
			places.append(ward.place)
		return finished[0]
	return ward.play_until(until, Ward.pick_tones(tones), bot)


## The time-out lines the board has wrong.
func _board_mistakes(op: OperationTask) -> Array:
	var wrong := []
	for line: Dictionary in op.timeout_lines:
		if line.has("wrong_reads") and str(line["reads"]) == str(line["wrong_reads"]):
			wrong.append(str(line["id"]))
	return wrong


## Answers every time-out line the right way, except those in answers.
func _time_out(op: OperationTask, answers: Dictionary = {}) -> void:
	for line in 12:
		var on_show := op.timeout_line()
		if on_show.is_empty():
			return
		op.answer_timeout(str(answers.get(str(on_show["id"]), on_show["right"])))
		var waited := 0.0
		while op.busy() and waited < 10.0:
			op.tick(0.1)
			waited += 0.1


# --- The operations on their own ---------------------------------------------

func test_no_step_shares_a_name_with_a_complication() -> void:
	for id: String in Procedures.ids():
		for entry: Dictionary in Procedures.get_procedure(id)["steps"]:
			expect(not Procedures.COMPLICATIONS.has(str(entry["id"])),
				"%s: step '%s' is also a complication" % [id, entry["id"]])


func test_every_new_operation_is_the_same_for_a_seed_and_easy_is_kind() -> void:
	for id: String in NEW_OPERATIONS:
		for level: String in OperationTask.DIFFICULTIES:
			var one := OperationTask.new(77, {"procedure": id, "difficulty": level})
			var two := OperationTask.new(77, {"procedure": id, "difficulty": level})
			expect_equal(one.difficulty, level)
			expect(not one.steps.is_empty(), "%s has steps" % id)
			expect_equal(_board_mistakes(one), _board_mistakes(two), "%s %s: the same board for the same seed" % [id, level])
			expect_equal(one.variants, two.variants, "%s %s: the same insides for the same seed" % [id, level])
			expect_equal(one.later, two.later, "%s %s: the same surprises for the same seed" % [id, level])
			if level == "easy":
				expect(_board_mistakes(one).is_empty(), "%s: no mistakes on the board on easy" % id)
			if level == "extreme":
				expect(not _board_mistakes(one).is_empty(), "%s: the board is wrong on extreme" % id)


func test_hard_cases_vary_from_seed_to_seed() -> void:
	var boards := {}
	for seed_value in range(1, 40):
		var op := OperationTask.new(seed_value, {"procedure": "gallbladder", "difficulty": "hard"})
		boards[str(_board_mistakes(op))] = true
	expect(boards.size() >= 2, "different seeds give different boards: %s" % [boards.keys()])


func test_a_late_hernia_is_never_pink_and_extreme_is_dead() -> void:
	expect_equal(OperationTask.new(5, {"procedure": "hernia", "difficulty": "easy"}).variants["bowel"], "pink")
	for seed_value in range(1, 12):
		var late := OperationTask.new(seed_value, {"procedure": "hernia", "difficulty": "hard", "delayed": true})
		expect_equal(late.variants["bowel"], "dusky", "fifty minutes late, the bowel is bruised")
	expect_equal(OperationTask.new(3, {"procedure": "hernia", "difficulty": "extreme", "delayed": true}).variants["bowel"],
		"dead")


func test_asking_about_allergies_lets_the_doctor_confirm_none() -> void:
	var asked := OperationTask.new(9, {"procedure": "gallbladder", "difficulty": "easy", "allergy_asked": true,
		"aspirin_known": true})
	_time_out(asked, {"allergy": "confirm"})
	expect(not asked.reaction_coming, "no allergy, no reaction")
	expect_near(asked.timeout_points, float(asked.timeout_lines.size()), 0.01, "every line right")
	var guessed := OperationTask.new(9, {"procedure": "gallbladder", "difficulty": "easy", "aspirin_known": true})
	_time_out(guessed, {"allergy": "confirm"})
	expect(not guessed.reaction_coming, "she has no allergy either way")
	expect_near(guessed.timeout_points, float(guessed.timeout_lines.size()) - 1.0, 0.01,
		"confirming what nobody asked earns nothing")
	var careful := OperationTask.new(9, {"procedure": "gallbladder", "difficulty": "easy", "aspirin_known": true})
	_time_out(careful, {"allergy": "unsure"})
	expect_near(careful.timeout_points, float(careful.timeout_lines.size()), 0.01, "'not sure' is right if nobody asked")


func test_what_the_history_found_changes_the_time_out() -> void:
	var told := OperationTask.new(4, {"procedure": "wound", "difficulty": "easy", "tetanus_known": true})
	var not_told := OperationTask.new(4, {"procedure": "wound", "difficulty": "easy"})
	for pair: Array in [[told, "stop"], [not_told, "unsure"]]:
		var op: OperationTask = pair[0]
		for line: Dictionary in op.timeout_lines:
			if str(line["id"]) == "tetanus":
				expect_equal(line["right"], pair[1], "the tetanus line")
	var ate := OperationTask.new(4, {"procedure": "hernia", "difficulty": "easy", "ate_known": true})
	var meal_line := {}
	for line: Dictionary in ate.timeout_lines:
		if str(line.get("known", "")) == "ate_known":
			meal_line = line
	expect_equal(meal_line.get("right", ""), "stop", "knowing he ate changes the hernia's time-out")


func test_overfilling_the_belly_brings_the_pressure_down_without_errors() -> void:
	var op := OperationTask.new(2, {"procedure": "gallbladder", "difficulty": "easy", "allergy_asked": true})
	expect_equal(op.procedure["opens"], "fill")
	op.step = "fill"
	op.phase = "act"
	op.fill_level = 19.0
	op._judge_fill()
	expect(op.overfilled, "too much gas is noticed")
	expect(op.later.get("fill", []).has("gas"), "the pressure drops after the fill")
	op._start_complication("gas")
	expect_equal(op.phase, "decide")
	expect_equal(op.right_option(), "release", "let the gas out")
	expect(op.coach.contains("pressure"), "Dr. Khan says why: %s" % op.coach)


# --- Days 9 to 13 on the ward ---------------------------------------------------

func test_eight_months_later_opens_day_nine() -> void:
	var ward := _ward(9)
	expect(ward.overlay.fade_amount() > 0.9, "a dark screen")
	expect_equal(ward.overlay._card_title.text, "Eight months later")
	expect(ward.profile.has_flag("jump_9"), "the jump is seen once")
	for frame in 120:
		ward.update(1.0 / 30.0)
	expect(ward.overlay._card_title.text.begins_with("Day 9"), "then the day's own card")


func test_day_nine_stitches_deepas_hand_in_the_minor_theatre() -> void:
	var ward := _ward(9)
	var places := []
	expect(_play_day(ward, CAREFUL, "good", places), "the day ends")
	var profile := ward.profile
	expect(places.has("theatre"), "the team goes into theatre")
	expect_equal(ward.place, "ward", "and comes back to the ward")
	for flag: String in ["deepa_history_tetanus", "op_deepa_done", "op_deepa_won", "deepa_booster"]:
		expect(profile.has_flag(flag), flag)
	expect_equal(ward.theatre_set.door_sign.text, "MINOR THEATRE", "a cut hand goes to the minor theatre")
	expect(not ward.rig_for("deepa").visible, "Deepa goes home")
	expect(ward._end_line().contains("stitched"), ward._end_line())


func test_day_ten_missing_the_aneurysm_has_consequences() -> void:
	var careful := _ward(10)
	expect(_play_day(careful, CAREFUL), "a careful day ends")
	expect(careful.profile.has_flag("bansal_exam_right"), "the careful doctor feels the pulsing lump")
	expect(careful._end_line().contains("Because you looked"), careful._end_line())
	var sloppy := _ward(10)
	expect(_play_day(sloppy, ["Brisk", "Promise"], "bad"), "a sloppy day still ends")
	expect(not sloppy.profile.has_flag("bansal_exam_right"), "the sloppy doctor misses it")
	expect(sloppy._end_line().contains("collapsed"), sloppy._end_line())
	expect(sloppy.profile.has_flag("farida_scared"), "promising Farida it's nothing scared her more")


func test_day_eleven_is_the_first_keyhole_operation() -> void:
	var ward := _ward(11, ["farida_history_done", "farida_history_medicines", "farida_history_allergy", "farida_reassured"])
	var places := []
	expect(_play_day(ward, CAREFUL, "good", places), "the day ends")
	expect(places.has("theatre"))
	var op := ward.operation
	expect(op != null and op.id == "gallbladder", "the gallbladder")
	expect(bool(op.setup["aspirin_known"]) and bool(op.setup["allergy_asked"]), "what she told you reaches the team")
	expect_equal(op.setup["lead"], "iyer")
	expect(ward.profile.has_flag("op_farida_won"), "played well, it goes well")
	expect(ward.profile.has_flag("farida_consented_honest"))
	expect(ward.bed("bed2").patient == ward.rig_for("farida"), "Farida is back in bed 2")


func test_the_meeting_is_in_the_seminar_room_and_sethi_takes_the_credit() -> void:
	var ward := _ward(12, ["bansal_exam_right", "bansal_sethi_told"])
	ward.play_until(func() -> bool: return ward.conversation == "meeting", Ward.pick_tones(CAREFUL))
	expect_equal(ward.place, "seminar")
	expect(ward.seminar.visible and not ward.theatre_set.visible)
	expect(ward.seminar.slide.text.contains("Dr. K. Sethi"), "his name on the slide")
	expect(ward.rig_for("sethi").visible and ward.rig_for("rao").visible, "Dr. Sethi presents to Dr. Rao")
	expect_equal(ward.profile.clock_text(), "08:00")


func test_seeing_the_vip_first_costs_raju_time() -> void:
	var ward := _ward(12, ["bansal_exam_right"])
	var places := []
	expect(_play_day(ward, ["VIP first", "Question", "Thorough", "Help"] + CAREFUL, "good", places), "the day ends")
	var profile := ward.profile
	expect(profile.has_flag("mehra_first") and not profile.has_flag("raju_first"), "the VIP went first")
	expect(bool(ward.operation.setup["delayed"]), "Raju waited")
	expect(places.has("seminar") and places.has("theatre"))
	expect(profile.has_flag("op_raju_chose_warm") or profile.has_flag("op_raju_chose_resect"),
		"his bowel paid for it, and the doctor saw it wasn't healthy")
	expect(not ward._end_line().contains("forgiven"), ward._end_line())


func test_seeing_raju_first_and_arguing_with_the_vip_brings_a_letter() -> void:
	var ward := _ward(12, ["bansal_exam_right"])
	expect(_play_day(ward, ["Patient first", "Speak up", "Defend"] + CAREFUL), "the day ends")
	var profile := ward.profile
	expect(profile.has_flag("raju_first") and not bool(ward.operation.setup["delayed"]), "Raju went straight in")
	expect(profile.has_flag("credit_called_out"), "the doctor spoke up at the meeting")
	expect(profile.has_flag("mehra_complaint"), "Mrs. Mehra didn't like being argued with")
	expect(ward._end_line().contains("letter"), ward._end_line())


func test_the_review_makes_a_senior_resident() -> void:
	var ward := _ward(13, ["bansal_exam_right", "op_deepa_won", "op_farida_won", "op_raju_won", "raju_first",
		"credit_proof", "mehra_charmed", "mehra_home"])
	expect_equal(ward.profile.rank(), Rank.JUNIOR_RESIDENT)
	var places := []
	expect(_play_day(ward, CAREFUL, "good", places), "the day ends")
	expect(places.has("seminar"), "the review is in the seminar room")
	expect_equal(ward.profile.rank(), Rank.SENIOR_RESIDENT, "promoted")
	expect(ward.profile.level() >= 7)
	expect_equal(ward._end_line(), "Senior Resident, from Monday.")


func test_the_end_lines_follow_what_happened() -> void:
	var profile := PlayerProfile.new()
	expect_equal(WardStory.end_line(profile, 12), "Raju is on the ward. Mrs. Mehra has forgiven you. Mostly.")
	profile.set_flag("op_raju_chose_resect")
	expect(WardStory.end_line(profile, 12).contains("dead when he came in"))
	profile.set_flag("mehra_first")
	expect(WardStory.end_line(profile, 12).contains("might have kept"))
	profile.set_flag("op_raju_failed")
	expect(WardStory.end_line(profile, 12).contains("intensive care"))
	expect(WardStory.holds(profile, "mehra_first&!raju_first"))
	expect(not WardStory.holds(profile, "raju_first|mehra_home"))


func test_with_no_anaesthetist_the_lead_reads_the_monitor() -> void:
	var minor := OperationTask.new(6, {"procedure": "wound", "difficulty": "easy", "lead": "iyer", "anaesthetist": ""})
	minor._start_complication("faint")
	expect_equal(minor.speaker, "iyer", "Dr. Khan isn't in the minor theatre")
	var main := OperationTask.new(6, {"procedure": "gallbladder", "difficulty": "easy", "lead": "iyer", "anaesthetist": "khan"})
	main._start_complication("gas")
	expect_equal(main.speaker, "khan", "in Theatre 2 she is")


func test_the_hold_and_tie_buttons_keep_their_full_height() -> void:
	var ward := _ward(11, ["farida_history_done", "farida_history_medicines", "farida_history_allergy"])
	ward.play_until(func() -> bool: return ward.view is OperationView, Ward.pick_tones(CAREFUL))
	var view := ward.view as OperationView
	expect(view != null, "the operation opens")
	if view == null:
		return
	for button: Button in [view._hold, view._tie]:
		expect(button.custom_minimum_size.y >= UiKit.px(52), "%s is a full-size button" % button.name)
		expect(button.custom_minimum_size.x > 0.0, "%s keeps its width" % button.name)


func test_gas_hisses_while_the_belly_fills() -> void:
	expect("hiss" in Sfx.NAMES)
	expect(Sfx.stream("hiss").data.size() > 1000, "a real sound")
