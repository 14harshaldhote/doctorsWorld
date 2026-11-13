extends TestCase
## The Surgeon's story, Days 19 to 23: your own team and list, Mrs. Kurup's
## blocked bowel and what was left in it, Dr. Rao's old mistake, the bus
## crash on the flyover, and the review for Head of Department.


# --- Triage ---------------------------------------------------------------------

func _triage(level: String, with_seed: int = 5) -> TriageTask:
	return TriageTask.new("bus_triage", with_seed, level)


## Plays a triage through its screen with the robot, to the end.
func _play_triage(task: TriageTask, quality: String = "good") -> TriageView:
	var view := add_node(TriageView.new(task)) as TriageView
	var bot := AutoPlayer.new()
	bot.quality = quality
	bot.pace = 0.1
	var waited := 0.0
	while not task.finished and waited < 120.0:
		bot.step(view, 0.1)
		view.tick(0.1)
		waited += 0.1
	return view


func test_the_start_rules_tag_each_kind_of_casualty() -> void:
	expect_equal(TriageTask.start_tag({"walk": true}), "green")
	expect_equal(TriageTask.start_tag({"breathing": false, "airway": true}), "red")
	expect_equal(TriageTask.start_tag({"breathing": false, "airway": false}), "black")
	expect_equal(TriageTask.start_tag({"rate": 31}), "red")
	expect_equal(TriageTask.start_tag({"rate": 30, "refill": 2}), "yellow", "thirty is not over thirty, two is not over two")
	expect_equal(TriageTask.start_tag({"rate": 20, "refill": 3}), "red")
	expect_equal(TriageTask.start_tag({"rate": 20, "refill": 1, "obeys": false}), "red")
	expect_equal(TriageTask.start_tag({"rate": 20, "refill": 1, "obeys": true}), "yellow")


func test_the_checks_stop_where_the_rules_decide() -> void:
	expect_equal(TriageTask.needed_checks({"walk": true}), ["walk"] as Array[String])
	expect_equal(TriageTask.needed_checks({"breathing": false}), ["walk", "breathing", "airway"] as Array[String])
	expect_equal(TriageTask.needed_checks({"rate": 34}), ["walk", "breathing", "rate"] as Array[String])
	expect_equal(TriageTask.needed_checks({"rate": 20, "refill": 4}), ["walk", "breathing", "rate", "pulse"] as Array[String])
	expect_equal(TriageTask.needed_checks({"rate": 20, "refill": 1}).size(), 5)


func test_each_level_has_its_number_and_every_colour_but_black_is_there() -> void:
	for level: String in TriageTask.COUNTS:
		for with_seed in [1, 2, 3, 40, 999]:
			var triage := _triage(level, with_seed)
			expect_equal(triage.casualties.size(), int(TriageTask.COUNTS[level]), "%s seed %d" % [level, with_seed])
			var truths := {}
			for entry in triage.casualties:
				truths[entry["truth"]] = true
			for colour: String in ["red", "yellow", "green"]:
				expect(truths.has(colour), "%s seed %d has a %s" % [level, with_seed, colour])


func test_the_same_seed_gives_the_same_crash_and_seeds_differ() -> void:
	var first := _triage("hard", 12)
	var again := _triage("hard", 12)
	for index in first.casualties.size():
		expect_equal(first.casualties[index]["id"], again.casualties[index]["id"])
		expect_equal(first.casualties[index]["rate"], again.casualties[index]["rate"])
	var seen := {}
	for with_seed in range(1, 30):
		var triage := _triage("hard", with_seed)
		var key := ""
		for entry in triage.casualties:
			key += "%s%s," % [entry["id"], entry["truth"]]
		seen[key] = true
	expect(seen.size() > 10, "crashes vary from seed to seed (%d kinds)" % seen.size())


func test_hard_and_extreme_put_numbers_near_the_lines() -> void:
	# The conductor straddles thirty breaths: on hard some seeds make him red, some yellow.
	var colours := {}
	for with_seed in range(1, 80):
		var triage := _triage("extreme", with_seed)
		for entry in triage.casualties:
			if str(entry["id"]) == "conductor":
				colours[entry["truth"]] = true
				expect(int(entry["rate"]) >= 29 and int(entry["rate"]) <= 32, "extreme conductor rate %d" % int(entry["rate"]))
	expect(colours.has("red") and colours.has("yellow"), "the conductor is sometimes red, sometimes yellow")


func test_a_careful_doctor_tags_everyone_right_with_no_wasted_checks() -> void:
	for level: String in TriageTask.COUNTS:
		var triage := _triage(level, 21)
		_play_triage(triage)
		expect(triage.finished, level + " finished")
		expect(triage.all_right(), level + " all right")
		expect_equal(triage.wasted, 0, level + " no wasted checks")
		expect_equal(triage.score(), 100, level + " full marks")


func test_tagging_on_looks_alone_sends_someone_red_to_wait() -> void:
	var low := 100
	for with_seed in [3, 8, 13]:
		var triage := _triage("hard", with_seed)
		_play_triage(triage, "bad")
		expect(triage.finished, "bad finished")
		expect(not triage.all_right(), "looks lie")
		low = mini(low, triage.score())
	expect(low < 60, "guessing scores low (%d)" % low)


func test_a_shaky_doctor_wastes_checks_and_loses_points() -> void:
	var triage := _triage("hard", 9)
	_play_triage(triage, "shaky")
	expect(triage.wasted > 0, "extra checks counted")
	expect(triage.score() < 100, "and cost points")


func test_a_right_tag_without_the_deciding_check_is_a_guess() -> void:
	var triage := _triage("easy", 4)
	var entry: Dictionary = {}
	for casualty in triage.casualties:
		if str(casualty["truth"]) == "red" and bool(casualty.get("breathing", true)):
			entry = casualty
			break
	expect(not entry.is_empty(), "a breathing red casualty")
	triage.select(str(entry["id"]))
	triage.check("walk")
	triage.tag("red")
	expect_equal(triage.verdict(str(entry["id"])), "guessed")


func test_tagging_red_as_yellow_is_under_triage_and_noted() -> void:
	var triage := _triage("easy", 6)
	for entry in triage.casualties:
		triage.select(str(entry["id"]))
		for check in TriageTask.needed_checks(entry):
			triage.check(check)
		var given := str(entry["truth"])
		if given == "red":
			given = "yellow"
		triage.tag(given)
	triage.finish_triage()
	expect(not triage.under_triaged().is_empty(), "someone red waited")
	var noted := false
	for note in triage.notes():
		if "tagged yellow" in str(note["text"]):
			noted = true
	expect(noted, "the score card says who was under-triaged")


func test_the_airway_is_only_opened_on_someone_not_breathing() -> void:
	var triage := _triage("easy", 2)
	for entry in triage.casualties:
		var casualty_id := str(entry["id"])
		expect(not triage.can_check(casualty_id, "airway"), "not before checking breathing")
		triage.select(casualty_id)
		triage.check("breathing")
		expect_equal(triage.can_check(casualty_id, "airway"), not bool(entry["breathing"]), casualty_id)
		triage.back()


func test_hints_cost_on_hard_and_are_gone_on_extreme() -> void:
	var easy := _triage("easy", 1)
	easy.select(str(easy.casualties[0]["id"]))
	expect(not easy.hint().is_empty(), "easy hint")
	expect_equal(easy.hint_cost(), 0)
	var hard := _triage("hard", 1)
	hard.select(str(hard.casualties[0]["id"]))
	expect("walk" in hard.hint(), "the first hint is about walking")
	expect_equal(hard.hint_cost(), TriageTask.HINT_COST)
	var extreme := _triage("extreme", 1)
	expect(not extreme.hints_allowed(), "no hints on extreme")
	expect(extreme.hint().is_empty(), "and none given")
	var view := add_node(TriageView.new(extreme)) as TriageView
	expect(not (view.find_child("Hint", true, false) as Button).visible, "the hint button is hidden on extreme")


func test_the_rules_card_shows_only_on_easy() -> void:
	var easy := add_node(TriageView.new(_triage("easy", 1))) as TriageView
	expect(easy.find_child("Rules", true, false) != null, "rules card on easy")
	var hard := add_node(TriageView.new(_triage("hard", 1))) as TriageView
	expect(hard.find_child("Rules", true, false) == null, "no card on hard")


# --- Mrs. Kurup's blocked bowel -------------------------------------------------

func _theatre(setup: Dictionary) -> Theatre:
	var doctor := PlayerProfile.new()
	doctor.name = "Asha Verma"
	doctor.day = 19
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


func test_the_blocked_bowel_plays_well_and_badly_at_every_level() -> void:
	for level: String in OperationTask.DIFFICULTIES:
		var good := _play_op({"procedure": "obstruction", "difficulty": level, "lungs_known": true, "chest_safe": true,
			"allergy_asked": true, "scrub_nurse": "neha", "anaesthetist": "bose"}, "good")
		expect(good.finished, "%s: finished" % level)
		expect_equal(good.outcome, "won", "%s played well" % level)
		var bad := _play_op({"procedure": "obstruction", "difficulty": level}, "bad")
		expect(bad.outcome != "won", "%s played badly doesn't go well" % level)


func test_the_old_swab_is_seeded_and_reads_differently_by_level() -> void:
	var kinds := {}
	for with_seed in range(1, 25):
		var one := OperationTask.new(with_seed, {"procedure": "obstruction", "difficulty": "hard"})
		var two := OperationTask.new(with_seed, {"procedure": "obstruction", "difficulty": "hard"})
		expect_equal(one.variants, two.variants, "the same insides for the same seed")
		expect_equal(one.targets, two.targets, "the same layout for the same seed")
		kinds[str(one.variants["swab"])] = true
	expect(kinds.size() > 1, "hard cases differ from seed to seed")
	expect_equal(OperationTask.new(3, {"procedure": "obstruction", "difficulty": "easy"}).variants["swab"], "loose")
	expect_equal(OperationTask.new(3, {"procedure": "obstruction", "difficulty": "extreme"}).variants["swab"], "eroded")


func test_every_bowel_target_is_clear_of_its_traps() -> void:
	for with_seed in [1, 7, 40, 300, 512]:
		var op := OperationTask.new(with_seed, {"procedure": "obstruction", "difficulty": "hard"})
		for entry: Dictionary in op.procedure["steps"]:
			if not entry.has("target"):
				continue
			var right: Vector2 = op.targets[str(entry["target"])]
			for trap: String in (entry.get("traps", {}) as Dictionary):
				expect(right.distance_to(op.targets[trap]) > 0.9, "seed %d: %s is clear of %s" % [with_seed, entry["target"], trap])


func test_your_own_team_is_named_in_theatre() -> void:
	var picked := OperationTask.new(5, {"procedure": "obstruction", "scrub_nurse": "neha", "anaesthetist": "bose"})
	expect_equal(picked.scrub_name(), "Neha")
	expect_equal(picked.anaesthetist_name(), "Dr. Bose")
	var usual := OperationTask.new(5, {"procedure": "obstruction"})
	expect_equal(usual.scrub_name(), "Tom")
	expect_equal(usual.anaesthetist_name(), "Dr. Khan")
	expect_equal(usual.lead_name(), "Dr. Iyer")


func test_nobody_minding_her_chest_brings_on_the_wheeze() -> void:
	for with_seed in [1, 2, 3, 4, 5, 6]:
		var unsafe := OperationTask.new(with_seed, {"procedure": "obstruction", "chest_safe": false})
		var planned: Array = []
		for list: Array in unsafe.later.values():
			planned.append_array(list)
		expect("pressure" in planned, "seed %d: her asthma catches up with her" % with_seed)
	var told := {}
	for entry in OperationTask.new(1, {"procedure": "obstruction", "lungs_known": true}).timeout_lines:
		if str(entry["id"]) == "chest":
			told = entry
	expect_equal(told["right"], "stop", "knowing about her asthma, you tell the anaesthetist")


func test_waiting_two_hours_means_the_swab_has_done_more_damage() -> void:
	for with_seed in range(1, 15):
		var waited := OperationTask.new(with_seed, {"procedure": "obstruction", "difficulty": "hard", "delayed": true})
		expect(waited.variants["swab"] != "loose", "seed %d: never the gentle case after a wait" % with_seed)


func test_a_tired_nurse_loses_a_swab_and_a_careful_surgeon_finds_it() -> void:
	var op := _play_op({"procedure": "obstruction", "difficulty": "easy", "lose_swab": 1, "chest_safe": true,
		"lungs_known": true, "allergy_asked": true}, "good")
	expect(op.swab_missing, "the count came up one short")
	expect(op.swab_found, "and the swab was found before closing")
	var rested := _play_op({"procedure": "obstruction", "difficulty": "easy", "lose_swab": 0, "chest_safe": true,
		"lungs_known": true, "allergy_asked": true, "scrub_nurse": "neha"}, "good")
	expect(not rested.swab_missing, "a rested nurse keeps the count")


# --- The story, Days 19 to 23 ---------------------------------------------------

const CAREFUL := ["Fresh hands", "Start now", "Patient first", "Plain", "Truth now", "Together", "Truth", "Listen", "Promise",
	"Explain", "Fair fight", "Call in", "Own it", "Credit Priya", "Ready", "Count rule", "Talk"]
const CARELESS := ["Loyal", "Wait for Khan", "Brief", "Quick", "Tomorrow", "Colleague", "Adhesions", "Stick to it", "Honest",
	"Light", "Dig", "Clear beds", "Defend", "Photo", "Nervous", "Blame", "Board", "Nights"]
const BEFORE := ["op_rohit_done", "op_rohit_won", "promoted", "beds_saved", "rider_treated", "jump_9", "op_raju_won",
	"credit_proof", "sethi_apology", "jump_14", "op_gomes_won", "nanda_called", "op_imran_won", "mm_credit_zoya",
	"vote_night_doctor"]


func _ward(day: int, flags: Array = []) -> Ward:
	var doctor := PlayerProfile.new()
	doctor.name = "Asha Verma"
	doctor.day = day
	doctor.opening_seen = true
	doctor.created = true
	doctor.total_xp = LevelCurve.total_xp_to_reach(Rank.FIRST_LEVELS[Rank.SURGEON]) + 400
	doctor.rank_held = Rank.SURGEON
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


func test_three_months_later_you_pick_your_team_and_free_her_bowel() -> void:
	var ward := _ward(19)
	expect(ward.profile.has_flag("jump_19"), "three months later")
	var places := []
	expect(_play_day(ward, CAREFUL, "good", places), "the day ends")
	for flag: String in ["team_neha", "team_bose", "kurup_history_lungs", "kurup_consent_plain", "op_kurup_won", "kurup_told_now"]:
		expect(ward.profile.has_flag(flag), flag)
	var op := ward.operation
	expect(op != null and op.id == "obstruction", "the blocked bowel")
	expect_equal(op.setup["scrub_nurse"], "neha")
	expect_equal(op.setup["anaesthetist"], "bose")
	expect(bool(op.setup["chest_safe"]), "you told Dr. Bose about her asthma")
	expect(not bool(op.setup["delayed"]), "straight to theatre")
	expect(not bool(op.setup["lose_swab"]), "a rested nurse")
	expect(places.has("theatre"))
	expect_equal(WardStory.end_line(ward.profile, 19), "Mrs. Kurup is asleep. Venu knows. The pot is on Dr. Iyer's desk.")


func test_a_tired_nurse_and_a_two_hour_wait_have_their_costs() -> void:
	var ward := _ward(19)
	expect(_play_day(ward, CARELESS, "shaky"), "the day ends")
	var op := ward.operation
	expect_equal(op.setup["scrub_nurse"], "tom")
	expect_equal(op.setup["anaesthetist"], "khan")
	expect(bool(op.setup["delayed"]), "waiting for Dr. Khan")
	expect(bool(op.setup["lose_swab"]), "Tom was up all night")
	expect(op.variants["swab"] != "loose", "two more hours made it worse")
	expect(ward.profile.has_flag("kurup_told_later"))


func test_day_twenty_you_stand_beside_dr_rao_when_he_tells_her() -> void:
	var ward := _ward(20, ["jump_19", "op_kurup_won", "kurup_told_now"])
	expect(_play_day(ward, CAREFUL), "the day ends")
	for flag: String in ["candour_together", "kurup_promise"]:
		expect(ward.profile.has_flag(flag), flag)
	expect(not ward.profile.has_flag("candour_hidden"))
	expect_equal(WardStory.end_line(ward.profile, 20), "Dr. Rao said sorry to her face. You stood beside him.")


func test_writing_adhesions_is_remembered() -> void:
	var ward := _ward(20, ["jump_19", "op_kurup_struggled", "kurup_told_later"])
	var before := ward.profile.trust("iyer", 50)
	expect(_play_day(ward, CARELESS), "the day ends")
	for flag: String in ["candour_hidden", "candour_lied"]:
		expect(ward.profile.has_flag(flag), flag)
	expect(ward.profile.trust("iyer", 50) < before, "Dr. Iyer trusts you less")
	expect_equal(WardStory.end_line(ward.profile, 20), "Her notes say 'adhesions'. The pot says otherwise.")


func test_day_twenty_one_dr_rao_retires_and_the_count_rule_goes_up() -> void:
	var ward := _ward(21, ["jump_19", "op_kurup_won", "candour_together", "kurup_promise"])
	var places := []
	expect(_play_day(ward, CAREFUL, "good", places), "the day ends")
	expect(places.has("seminar"))
	for flag: String in ["count_rule", "sethi_fair"]:
		expect(ward.profile.has_flag(flag), flag)
	expect_equal(WardStory.end_line(ward.profile, 21), "Dr. Rao is retiring. The count rule goes up on Monday.")


func test_day_twenty_two_the_flyover_crash_is_sorted_at_the_ambulance_bay() -> void:
	var ward := _ward(22, ["jump_19", "candour_together", "count_rule", "sethi_fair"])
	ward.play_until(func() -> bool: return ward.view is TriageView, Ward.pick_tones(CAREFUL))
	var view := ward.view as TriageView
	expect(view != null, "the triage opens")
	expect_equal(ward.talking_with, "priya", "the camera stays on Priya")
	expect(view.kicker_override.ends_with("Ambulance bay"))
	expect(_play_day(ward, CAREFUL), "the day ends")
	for flag: String in ["bus_triage_done", "bus_triage_right", "crash_called", "crash_credit_priya"]:
		expect(ward.profile.has_flag(flag), flag)
	expect(not ward.profile.has_flag("bus_triage_under"))


func test_tagging_on_looks_at_the_crash_is_not_all_right() -> void:
	var ward := _ward(22, ["jump_19"])
	expect(_play_day(ward, CARELESS, "bad"), "the day ends")
	expect(ward.profile.has_flag("bus_triage_done"))
	expect(not ward.profile.has_flag("bus_triage_right"), "looks lie")
	expect(ward.profile.has_flag("crash_photo"))


func test_the_interview_makes_a_head_of_department() -> void:
	var ward := _ward(23, ["jump_19", "op_kurup_won", "candour_together", "kurup_promise", "count_rule", "sethi_fair"])
	expect_equal(ward.profile.rank(), Rank.SURGEON)
	var places := []
	expect(_play_day(ward, CAREFUL, "good", places), "the day ends")
	expect(places.has("seminar"))
	expect_equal(ward.profile.rank(), Rank.HEAD_OF_DEPARTMENT, "promoted")
	expect(ward.profile.level() >= Rank.FIRST_LEVELS[Rank.HEAD_OF_DEPARTMENT], "with the experience to match")
	expect(ward.profile.has_flag("hod_talk"))
	expect_equal(WardStory.end_line(ward.profile, 23), "Head of Department, from the first of the month.")


func test_the_board_has_read_the_pathology_report() -> void:
	var ward := _ward(23, ["jump_19", "candour_hidden", "candour_lied"])
	expect(_play_day(ward, CARELESS), "the day ends")
	expect(ward.profile.has_flag("hod_blamed"))
	expect(ward.profile.trust("rao", 45) < 45, "Dr. Rao heard you blame him")
	expect_equal(ward.profile.rank(), Rank.HEAD_OF_DEPARTMENT, "by one vote")
