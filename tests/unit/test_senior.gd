extends TestCase
## The Senior Resident's story, Days 14 to 18: a year later, the new intern's
## drug chart, Mrs. Gomes's broken hip, a night on call alone, the M&M and
## the budget vote, and the review that makes a Surgeon.


# --- The drug chart ------------------------------------------------------------

func _chart(level: String, with_seed: int = 5) -> ChartTask:
	return ChartTask.new("gomes_chart", with_seed, level)


## Plays a chart through its screen with the robot, to the end.
func _play_chart(task: ChartTask, quality: String = "good") -> ChartView:
	var view := add_node(ChartView.new(task)) as ChartView
	var bot := AutoPlayer.new()
	bot.quality = quality
	bot.pace = 0.1
	var waited := 0.0
	while not task.finished and waited < 60.0:
		bot.step(view, 0.1)
		view.tick(0.1)
		waited += 0.1
	return view


func test_each_level_hides_its_number_of_mistakes() -> void:
	for level: String in ChartTask.MISTAKES:
		for with_seed in [1, 2, 3, 40, 999]:
			var chart := _chart(level, with_seed)
			var counts: Array = ChartTask.MISTAKES[level]
			var subtle := 0
			for line_id in chart.mistakes():
				if bool(chart.line(line_id)["subtle"]):
					subtle += 1
			expect_equal(chart.mistakes().size(), int(counts[0]) + int(counts[1]), "%s seed %d" % [level, with_seed])
			expect_equal(subtle, int(counts[1]), "%s seed %d: subtle mistakes" % [level, with_seed])


func test_the_same_seed_gives_the_same_chart_and_seeds_differ() -> void:
	expect_equal(_chart("hard", 12).mistakes(), _chart("hard", 12).mistakes())
	var seen := {}
	for with_seed in range(1, 30):
		seen[str(_chart("hard", with_seed).mistakes())] = true
	expect(seen.size() > 4, "charts vary from seed to seed (%d kinds)" % seen.size())


func test_a_wrong_line_reads_wrong_and_a_right_line_reads_right() -> void:
	var chart := _chart("extreme", 7)
	for entry in chart.lines:
		var text := " ".join(ChartTask.line_text(entry))
		if str(entry["id"]) == "digoxin":
			expect(("62.5 mg" in text) == bool(entry["wrong"]), "digoxin reads: " + text)
		if str(entry["id"]) == "antibiotic":
			expect(("Co-amoxiclav" in text) == bool(entry["wrong"]), "antibiotic reads: " + text)
		expect(not str(entry.get("defend", "")).is_empty(), "%s can be defended" % entry["id"])


func test_the_right_reason_catches_a_mistake_and_a_wrong_one_half_counts() -> void:
	var chart := _chart("hard", 3)
	var wrong := chart.mistakes()
	var first := chart.line(wrong[0])
	chart.select(wrong[0])
	expect_equal(chart.selected, wrong[0])
	chart.flag(str(first["reason"]))
	expect_equal(chart.verdicts[wrong[0]], "found")
	expect(chart.selected.is_empty(), "the pick clears")
	expect(not chart.coach_warns, "the intern agrees")
	var second := chart.line(wrong[1])
	var accepted: Array = [str(second["reason"])] + (second.get("also", []) as Array)
	for reason: String in ChartTask.REASONS:
		if reason not in accepted:
			chart.flag(reason, wrong[1])
			break
	expect_equal(chart.verdicts[wrong[1]], "half")
	expect(chart.coach_warns, "the intern says: not for that reason")
	chart.flag(str(second["reason"]), wrong[1])
	expect_equal(chart.verdicts[wrong[1]], "half", "a line is judged once")


func test_flagging_a_right_line_is_a_false_alarm_the_intern_defends() -> void:
	var chart := _chart("easy", 9)
	var right_line := ""
	for entry in chart.lines:
		if not bool(entry["wrong"]):
			right_line = str(entry["id"])
			break
	chart.flag("dose", right_line)
	expect_equal(chart.verdicts[right_line], "false")
	expect_equal(chart.coach, str(chart.line(right_line)["defend"]))
	expect_equal(chart.false_alarms(), 1)
	for line_id in chart.mistakes():
		chart.flag(str(chart.line(line_id)["reason"]), line_id)
	chart.sign()
	expect(chart.finished, "signed")
	expect(not chart.all_right(), "a false alarm spoils a clean chart")
	expect_equal(chart.score(), 100 - ChartTask.FALSE_ALARM)


func test_easy_hints_are_free_hard_cost_and_extreme_has_none() -> void:
	var easy := _chart("easy")
	easy.hint()
	expect_equal(easy.speaker, "iyer", "Dr. Iyer gives the hint")
	expect_equal(easy.coach, str(easy.line(easy.missed()[0])["hint"]))
	expect_equal(easy.hint_cost(), 0)
	var hard := _chart("hard")
	hard.hint()
	for line_id in hard.mistakes():
		hard.flag(str(hard.line(line_id)["reason"]), line_id)
	expect_equal(hard.speaker, "zoya", "the intern answers the flag")
	hard.sign()
	expect_equal(hard.score(), 100 - ChartTask.HINT_COST)
	var extreme := _chart("extreme")
	expect(not extreme.hints_allowed(), "no hints on extreme")
	expect_equal(extreme.hint(), "")
	expect_equal(extreme.hints_used, 0)


func test_missed_mistakes_are_explained_when_the_chart_is_signed() -> void:
	var chart := _chart("hard", 21)
	chart.sign()
	expect_equal(chart.score(), 0)
	var texts := []
	for note in chart.notes():
		texts.append(str(note["text"]))
	for line_id in chart.mistakes():
		expect(str(chart.line(line_id)["why"]) in texts, "explains the missed %s" % line_id)
	expect_equal(chart.coach, str(StoryBook.chapter("cases")["gomes_chart"]["signed"]["none"]))


func test_the_robot_checks_the_chart_through_its_screen() -> void:
	for level: String in ChartTask.MISTAKES:
		var good := ChartTask.new("gomes_chart", 31, level)
		var view := _play_chart(good)
		expect(good.finished, "%s: signed" % level)
		expect(good.all_right(), "%s: every mistake caught, nothing right doubted" % level)
		expect_equal(good.score(), 100)
		expect(view.line_button(good.mistakes()[0]).disabled, "a judged line can't be tapped again")
	var shaky := ChartTask.new("gomes_chart", 31, "hard")
	_play_chart(shaky, "shaky")
	expect_equal(shaky.missed().size(), 1)
	expect_equal(shaky.false_alarms(), 1)
	var bad := ChartTask.new("gomes_chart", 31, "extreme")
	_play_chart(bad, "bad")
	expect(bad.found().is_empty(), "the wrong reasons catch nothing")
	expect(bad.score() < 40, "a bad check scores badly (%d)" % bad.score())


func test_the_chart_screen_swaps_to_reasons_and_shows_who_spoke() -> void:
	var chart := _chart("easy", 4)
	var view := add_node(ChartView.new(chart)) as ChartView
	view.tick(0.1)
	expect_equal(view.voice_id(), "zoya")
	view.pick(chart.mistakes()[0])
	view.tick(0.1)
	expect(view.reason_button("dose").is_visible_in_tree(), "the reasons show for a picked line")
	expect(not view.line_button(chart.mistakes()[1]).is_visible_in_tree(), "the lines step aside")
	view.cancel()
	view.tick(0.1)
	expect(view.line_button(chart.mistakes()[1]).is_visible_in_tree(), "the lines come back")
	view.ask_hint()
	view.tick(0.1)
	expect_equal(view.voice_id(), "iyer")
	expect_equal(view.speaker_override, "Dr. Meera Iyer")


# --- The two new operations ------------------------------------------------------

const NEW_OPERATIONS := ["hip", "spleen"]


func _theatre(setup: Dictionary) -> Theatre:
	var doctor := PlayerProfile.new()
	doctor.name = "Asha Verma"
	doctor.day = 15
	doctor.opening_seen = true
	var theatre := add_node(Theatre.new(doctor)) as Theatre
	theatre.operation_setup = setup
	theatre.skip_to("operation", [], 90)
	return theatre


func _play_op(setup: Dictionary, quality: String, seconds: float = 300.0) -> OperationTask:
	var theatre := _theatre(setup)
	var bot := AutoPlayer.new()
	bot.quality = quality
	var step := 1.0 / 20.0
	for frame in int(seconds / step):
		if theatre.view == null or theatre.view.result_open():
			break
		bot.step(theatre.view, step)
		theatre.update(step)
	return theatre.operation


func test_the_new_operations_play_well_and_badly_at_every_level() -> void:
	for id: String in NEW_OPERATIONS:
		for level: String in OperationTask.DIFFICULTIES:
			var good := _play_op({"procedure": id, "difficulty": level, "lead": "bhatt" if id == "hip" else "sethi"}, "good")
			expect(good.finished, "%s %s: finished" % [id, level])
			expect_equal(good.outcome, "won", "%s %s played well" % [id, level])
			var bad := _play_op({"procedure": id, "difficulty": level}, "bad")
			expect(bad.outcome != "won", "%s %s played badly doesn't go well" % [id, level])


func test_the_new_operations_are_the_same_for_a_seed_and_hard_cases_vary() -> void:
	for id: String in NEW_OPERATIONS:
		var kinds := {}
		for with_seed in range(1, 25):
			var one := OperationTask.new(with_seed, {"procedure": id, "difficulty": "hard"})
			var two := OperationTask.new(with_seed, {"procedure": id, "difficulty": "hard"})
			expect_equal(one.variants, two.variants, "%s: the same insides for the same seed" % id)
			expect_equal(one.targets, two.targets, "%s: the same layout for the same seed" % id)
			kinds[str(one.variants) + str(one.later)] = true
		expect(kinds.size() > 1, "%s: hard cases differ from seed to seed" % id)
		var easy := OperationTask.new(3, {"procedure": id, "difficulty": "easy"})
		var extreme := OperationTask.new(3, {"procedure": id, "difficulty": "extreme"})
		for key: String in easy.variants:
			var kinds_list: Array = (easy.procedure["variants"][key] as Dictionary).keys()
			expect_equal(easy.variants[key], kinds_list[0], "%s %s: easy is the gentlest" % [id, key])
			expect_equal(extreme.variants[key], kinds_list[kinds_list.size() - 1], "%s %s: extreme is the worst" % [id, key])


func test_every_tap_target_is_clear_of_its_traps() -> void:
	for id: String in NEW_OPERATIONS:
		for with_seed in [1, 7, 40, 300]:
			var op := OperationTask.new(with_seed, {"procedure": id, "difficulty": "hard"})
			for entry: Dictionary in op.procedure["steps"]:
				if not entry.has("target"):
					continue
				var right: Vector2 = op.targets[str(entry["target"])]
				for trap: String in (entry.get("traps", {}) as Dictionary):
					expect(right.distance_to(op.targets[trap]) > 0.9, "%s seed %d: %s is clear of %s" % [id, with_seed, entry["target"], trap])


func test_the_lead_surgeon_is_named_in_the_operation() -> void:
	var hip := OperationTask.new(5, {"procedure": "hip", "lead": "bhatt"})
	expect_equal(hip.lead_name(), "Dr. Bhatt")
	var spleen := OperationTask.new(5, {"procedure": "spleen", "lead": "sethi"})
	expect_equal(spleen.lead_name(), "Dr. Sethi")
	expect_equal(OperationTask.new(5, {}).lead_name(), "Dr. Iyer")


func test_warfarin_nobody_stopped_makes_her_bleed() -> void:
	for with_seed in [1, 2, 3, 4, 5]:
		var unknown := OperationTask.new(with_seed, {"procedure": "hip", "warfarin_known": false})
		var planned: Array = []
		for list: Array in unknown.later.values():
			planned.append_array(list)
		expect("bleeding" in planned, "seed %d: she bleeds when the warfarin went on" % with_seed)
	var line := {}
	for entry in OperationTask.new(1, {"procedure": "hip", "warfarin_known": true}).timeout_lines:
		if str(entry["id"]) == "thinners":
			line = entry
	expect_equal(line["right"], "stop", "knowing it was stopped, you tell the team")


func test_the_chart_can_be_told_which_lines_went_wrong() -> void:
	for with_seed in range(1, 12):
		var copied := ChartTask.new("gomes_chart", with_seed, "easy", {"warfarin": true})
		expect("warfarin" in copied.mistakes(), "seed %d: the warfarin was copied from home" % with_seed)
		expect_equal(copied.mistakes().size(), 2)
		var stopped := ChartTask.new("gomes_chart", with_seed, "hard", {"warfarin": false})
		expect(not ("warfarin" in stopped.mistakes()), "seed %d: the warfarin was stopped in time" % with_seed)
		expect_equal(stopped.mistakes().size(), 3)


# --- The story, Days 14 to 18 ---------------------------------------------------

const CAREFUL := ["Open door", "Patient first", "Honest", "Explain", "Plain", "Check", "Own it", "Report", "Night doctor",
	"Together", "Call senior", "Ask", "Theatre", "Zoya holds", "Thank", "Truth", "Credit", "Speak up", "Grateful", "Her call"]
const CARELESS := ["Throw in", "Quick", "Reassure", "Easy", "Brief", "Firm", "Move on", "Robot", "Split", "Pain",
	"Focus", "Scan first", "Scrub in", "Defend", "Vague", "Not mine", "Take it", "Blame", "Light", "Ambitious"]
const BEFORE := ["op_rohit_done", "op_rohit_won", "promoted", "beds_saved", "rider_treated", "jump_9", "op_raju_won",
	"credit_proof", "sethi_apology"]


func _ward(day: int, flags: Array = []) -> Ward:
	var doctor := PlayerProfile.new()
	doctor.name = "Asha Verma"
	doctor.day = day
	doctor.opening_seen = true
	doctor.created = true
	doctor.total_xp = LevelCurve.total_xp_to_reach(Rank.FIRST_LEVELS[Rank.SENIOR_RESIDENT]) + 400
	doctor.rank_held = Rank.SENIOR_RESIDENT
	for flag: String in BEFORE + flags:
		doctor.set_flag(flag)
	return add_node(Ward.new(doctor)) as Ward


func _play_day(ward: Ward, tones: Array, quality: String = "good", places: Array = []) -> bool:
	var finished := [false]
	ward.day_finished.connect(func() -> void: finished[0] = true)
	var bot := AutoPlayer.new()
	bot.quality = quality
	var until := func() -> bool:
		if not places.has(ward.place):
			places.append(ward.place)
		return finished[0]
	return ward.play_until(until, Ward.pick_tones(tones), bot, 1500.0)


func test_a_year_later_opens_day_fourteen_with_an_intern() -> void:
	var ward := _ward(14)
	expect(ward.profile.has_flag("jump_14"), "a year later")
	expect(ward.rig_for("zoya").visible, "Zoya is at the desk")
	expect(_play_day(ward, CAREFUL), "the day ends")
	expect(ward.profile.has_flag("zoya_ask"))
	expect(ward.profile.has_flag("gomes_history_hearing"), "her hearing aid is found")
	expect(ward.profile.has_flag("gomes_own_consent"), "so she signs for herself")
	expect(not ward.profile.has_flag("gomes_son_signed"))
	expect(ward.bed("bed2").patient == ward.rig_for("gomes"), "Mrs. Gomes is in bed 2")


func test_without_her_hearing_aid_her_son_signs_for_her() -> void:
	var ward := _ward(14)
	expect(_play_day(ward, CARELESS, "shaky"), "the day ends")
	expect(ward.profile.has_flag("gomes_son_signed"))
	expect(not ward.profile.has_flag("gomes_own_consent"))
	expect_equal(WardStory.end_line(ward.profile, 14), "Francis signed the form. His mother hasn't been told.")


func test_day_fifteen_checks_the_chart_then_fixes_the_hip_with_the_bone_team() -> void:
	var ward := _ward(15, ["jump_14", "gomes_history_done", "gomes_history_medicines", "gomes_history_allergy",
		"gomes_history_hearing", "gomes_own_consent", "zoya_ask"])
	var places := []
	expect(_play_day(ward, CAREFUL, "good", places), "the day ends")
	expect(ward.profile.has_flag("gomes_chart_done"), "the chart is checked")
	expect(ward.profile.has_flag("gomes_chart_right"), "every mistake caught")
	expect(not ward.profile.has_flag("gomes_chart_missed_warfarin"))
	expect(places.has("theatre"))
	var op := ward.operation
	expect(op != null and op.id == "hip", "the hip")
	expect_equal(op.setup["lead"], "bhatt")
	expect(bool(op.setup["warfarin_known"]) and bool(op.setup["allergy_known"]), "the team knows")
	expect(ward.profile.has_flag("op_gomes_won"), "played well, it goes well")
	expect(ward.profile.has_flag("chart_reported"))


func test_not_asking_about_her_tablets_puts_her_warfarin_on_the_chart() -> void:
	var ward := _ward(15, ["jump_14", "gomes_history_done", "gomes_son_signed"])
	expect(_play_day(ward, CARELESS, "bad"), "the day ends")
	expect(ward.profile.has_flag("gomes_chart_missed_warfarin"), "a careless check misses the copied warfarin")
	expect(not bool(ward.operation.setup["warfarin_known"]), "so theatre doesn't know")
	var coming: Array = ward.operation.happened.duplicate()
	for list: Array in ward.operation.later.values():
		coming.append_array(list)
	expect(coming.has("bleeding"), "and she bleeds")


func test_night_sixteen_calling_early_saves_mr_nanda() -> void:
	var ward := _ward(16, ["jump_14", "zoya_ask", "op_gomes_won"])
	expect(ward.night, "a night shift")
	var places := []
	expect(_play_day(ward, CAREFUL, "good", places), "the night ends")
	for flag: String in ["nanda_exam_right", "nanda_called", "imran_exam_right", "imran_allergy_asked", "ward_zoya"]:
		expect(ward.profile.has_flag(flag), flag)
	expect(not ward.profile.has_flag("nanda_icu"))
	var op := ward.operation
	expect(op != null and op.id == "spleen", "the spleen")
	expect_equal(op.setup["lead"], "sethi")
	expect(not bool(op.setup["delayed"]), "straight to theatre")
	expect(ward.profile.has_flag("op_imran_won"))
	expect(places.has("theatre"))


func test_night_sixteen_waiting_and_scanning_cost_time() -> void:
	var ward := _ward(16, ["jump_14", "op_gomes_won"])
	expect(_play_day(ward, CARELESS, "shaky"), "the night ends")
	expect(ward.profile.has_flag("nanda_pain"))
	expect(ward.profile.has_flag("nanda_icu"), "Mr. Nanda ends up in intensive care")
	expect(ward.profile.has_flag("imran_ct"))
	expect(bool(ward.operation.setup["delayed"]), "the scan cost Imran time")
	expect(not ward.profile.has_flag("nanda_zoya_called"), "with Zoya in theatre, nobody watched him")


func test_day_seventeen_the_mm_and_the_vote() -> void:
	var ward := _ward(17, ["jump_14", "nanda_called", "op_imran_won", "op_imran_chose_save", "lean_night"])
	var places := []
	expect(_play_day(ward, CAREFUL, "good", places), "the day ends")
	expect(places.has("seminar"))
	for flag: String in ["imran_truth", "mm_credit_zoya", "vote_night_doctor"]:
		expect(ward.profile.has_flag(flag), flag)


func test_blaming_the_intern_at_the_mm_is_remembered() -> void:
	var ward := _ward(17, ["jump_14", "nanda_pain", "nanda_icu"])
	expect(_play_day(ward, CARELESS), "the day ends")
	expect(ward.profile.has_flag("mm_blame_zoya"))
	expect(ward.profile.has_flag("vote_robot"))
	expect(ward.profile.trust("zoya", 50) < 50, "Zoya trusts you less")


func test_the_review_makes_a_surgeon() -> void:
	var ward := _ward(18, ["jump_14", "nanda_called", "mm_credit_zoya", "vote_night_doctor", "op_gomes_won"])
	expect_equal(ward.profile.rank(), Rank.SENIOR_RESIDENT)
	expect(_play_day(ward, CAREFUL), "the day ends")
	expect_equal(ward.profile.rank(), Rank.SURGEON, "promoted")
	expect(ward.profile.level() >= Rank.FIRST_LEVELS[Rank.SURGEON], "with the experience to match")
	expect_equal(WardStory.end_line(ward.profile, 18), "Surgeon, from Monday.")


func test_the_drug_chart_opens_at_the_nurses_station_with_zoya() -> void:
	var ward := _ward(15, ["jump_14", "gomes_history_medicines"])
	ward.play_until(func() -> bool: return ward.view is ChartView, Ward.pick_tones(CAREFUL))
	var view := ward.view as ChartView
	expect(view != null, "the chart opens")
	expect_equal(ward.talking_with, "zoya", "the camera stays on Zoya")
	expect(ward.player.visible, "the doctor stays at the desk")
	expect(view.kicker_override.ends_with("Nurses' station"))
	expect(not ("warfarin" in (view.task as ChartTask).mistakes()), "the warfarin was stopped, because you asked")
