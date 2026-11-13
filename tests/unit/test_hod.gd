extends TestCase
## The Head of Department's story, Days 24 to 28: the nurses' strike and the
## cover rota, Dr. Sethi's bile leak, the board's vote for Chief of Medicine,
## and the last day.


# --- Strike-day cover -----------------------------------------------------------

func _rota(level: String, with_seed: int = 5) -> RotaTask:
	return RotaTask.new("strike_rota", with_seed, level)


## Plans a rota through its screen with the robot, to the end.
func _play_rota(task: RotaTask, quality: String = "good") -> RotaView:
	var view := add_node(RotaView.new(task)) as RotaView
	var bot := AutoPlayer.new()
	bot.quality = quality
	bot.pace = 0.1
	var waited := 0.0
	while not task.finished and waited < 120.0:
		bot.step(view, 0.1)
		view.tick(0.1)
		waited += 0.1
	return view


func _person(fields: Dictionary) -> Dictionary:
	var entry := {"id": "p", "load": 1, "iv": false, "infectious": false, "fragile": false, "confused": false}
	entry.merge(fields, true)
	return entry


func _nurse(fields: Dictionary) -> Dictionary:
	var entry := {"id": "n", "capacity": 6, "iv": true, "student": false}
	entry.merge(fields, true)
	return entry


func test_each_rule_is_caught_when_it_breaks() -> void:
	var nurse: Array[Dictionary] = [_nurse({"id": "a", "capacity": 4, "iv": false})]
	var cases := {
		"load": [_person({"id": "x", "load": 3}), _person({"id": "y", "load": 2})],
		"iv": [_person({"id": "x", "iv": true})],
		"infection": [_person({"id": "x", "infectious": true}), _person({"id": "y", "fragile": true})],
		"confused": [_person({"id": "x", "confused": true, "load": 2}), _person({"id": "y", "load": 3})],
	}
	for rule: String in cases:
		var people: Array[Dictionary] = []
		people.assign(cases[rule])
		var placed := {}
		for entry in people:
			placed[str(entry["id"])] = "a"
		var rules: Array = RotaTask.breaks(people, nurse, placed).map(func(b: Dictionary) -> String: return str(b["rule"]))
		expect(rule in rules, "%s is caught (%s)" % [rule, rules])
	var student: Array[Dictionary] = [_nurse({"id": "s", "student": true})]
	var heavy: Array[Dictionary] = [_person({"id": "x", "load": 3})]
	expect_equal(RotaTask.breaks(heavy, student, {"x": "s"})[0]["rule"], "student")
	var light: Array[Dictionary] = [_person({"id": "x", "load": 2, "confused": true}), _person({"id": "y", "load": 2})]
	expect(RotaTask.breaks(light, nurse, {"x": "a", "y": "a"}).is_empty(), "four exactly is fine for the confused")


func test_every_level_and_seed_rolls_a_rota_that_can_be_done() -> void:
	for level: String in RotaTask.COUNTS:
		for with_seed in [1, 2, 3, 7, 40, 999]:
			var rota := _rota(level, with_seed)
			var label := "%s seed %d" % [level, with_seed]
			expect_equal(rota.patients.size(), int(RotaTask.COUNTS[level]), label)
			expect(not rota.solution.is_empty(), label + " has an answer")
			expect(RotaTask.breaks(rota.patients, rota.staff, rota.solution).is_empty(), label + " answer keeps every rule")
			expect_equal(rota.solution.size(), rota.patients.size(), label + " answer covers everyone")


func test_harder_days_bring_more_hands_and_tighter_limits() -> void:
	expect_equal(_rota("easy").staff.size(), 3)
	var hard := _rota("hard")
	expect_equal(hard.staff.size(), 4)
	expect(hard.staff.any(func(m: Dictionary) -> bool: return bool(m["student"])), "a student on hard")
	var extreme := _rota("extreme")
	expect_equal(extreme.staff.size(), 5)
	expect_equal(int(extreme.member("joel")["capacity"]), 4, "the agency nurse carries less on extreme")
	expect_equal(int(_rota("easy").member("joel")["capacity"]), 5)
	for level: String in RotaTask.COUNTS:
		var rota := _rota(level, 11)
		var load := 0
		var limit := 0
		for entry in rota.patients:
			load += int(entry["load"])
		for entry in rota.staff:
			limit += int(entry["capacity"])
		expect_between(float(load) / limit, float(RotaTask.TIGHTNESS[level]) - 0.12, float(RotaTask.TIGHTNESS[level]) + 0.12,
			"%s is about as full as it should be" % level)


func test_the_same_seed_gives_the_same_ward_and_seeds_differ() -> void:
	var first := _rota("hard", 12)
	var again := _rota("hard", 12)
	expect_equal(first.patients.map(func(p: Dictionary) -> String: return str(p["id"])),
		again.patients.map(func(p: Dictionary) -> String: return str(p["id"])))
	var differ := false
	for with_seed in [13, 14, 15, 16]:
		var other := _rota("hard", with_seed)
		if other.patients.map(func(p: Dictionary) -> String: return str(p["id"])) \
				!= first.patients.map(func(p: Dictionary) -> String: return str(p["id"])):
			differ = true
	expect(differ, "different seeds, different patients")


func test_a_careful_planner_keeps_every_rule_at_every_level() -> void:
	for level: String in RotaTask.COUNTS:
		var rota := _rota(level, 21)
		_play_rota(rota)
		expect(rota.finished, level + " signed")
		expect(rota.all_right(), level + " all right")
		expect_equal(rota.score(), 100, level + " full marks")


func test_dealing_patients_out_like_cards_breaks_the_rules() -> void:
	var low := 100
	for with_seed in [3, 8, 13]:
		var rota := _rota("hard", with_seed)
		_play_rota(rota, "bad")
		expect(rota.finished, "bad signed")
		expect(not rota.all_right(), "rules broken")
		low = mini(low, rota.score())
	expect(low < 80, "dealing scores low (%d)" % low)


func test_picking_a_patient_grace_says_who_they_are() -> void:
	var rota := _rota("easy", 3)
	var entry: Dictionary = rota.patients[0]
	rota.select(str(entry["id"]))
	expect(rota.coach.begins_with(str(entry["short"]) + ": "), rota.coach)
	expect(rota.coach.contains(str(entry["about"])), "with what's wrong with them")
	rota.select(str(entry["id"]))
	expect(rota.selected.is_empty(), "tapping again puts them down")


func test_one_patient_in_the_wrong_place_costs_points_and_is_explained() -> void:
	var rota := _rota("hard", 9)
	_play_rota(rota, "shaky")
	expect(not rota.all_right(), "something broke")
	expect(rota.score() < 100, "and cost points")
	var bad := rota.notes().filter(func(n: Dictionary) -> bool: return not bool(n["ok"]))
	expect(not bad.is_empty(), "the score card says what")
	expect(bad.any(func(n: Dictionary) -> bool: return str(n["text"]).contains(":")), "with the reason")


func test_easy_warns_at_once_and_hard_only_when_signed() -> void:
	var easy := _rota("easy", 4)
	var drip := easy.patients.filter(func(p: Dictionary) -> bool: return bool(p["iv"]))
	expect(not drip.is_empty(), "someone on a drip")
	easy.select(str(drip[0]["id"]))
	easy.assign("joel")
	expect(easy.coach_warns, "Grace warns straight away on easy")
	expect(easy.coach.contains("IV"), "about IV: " + easy.coach)
	var hard := _rota("hard", 4)
	var hard_drip := hard.patients.filter(func(p: Dictionary) -> bool: return bool(p["iv"]))
	hard.select(str(hard_drip[0]["id"]))
	hard.assign("joel")
	expect(not hard.coach_warns, "no warning on hard")
	expect_equal(hard.broken_rules(), ["iv"] as Array[String])


func test_leaving_someone_with_nobody_is_the_worst_mistake() -> void:
	var rota := _rota("easy", 2)
	for entry in rota.patients.slice(1):
		rota.select(str(entry["id"]))
		rota.assign(str(rota.solution[str(entry["id"])]))
	rota.sign_rota()
	expect(rota.finished, "signed")
	expect_equal(rota.uncovered().size(), 1)
	expect_equal(rota.score(), 100 - RotaTask.UNCOVERED_COST)
	expect(rota.coach.contains("name"), "Grace won't walk out on an empty bed: " + rota.coach)


func test_hints_cost_on_hard_and_are_gone_on_extreme() -> void:
	var easy := _rota("easy", 1)
	expect(not easy.hint().is_empty(), "easy hint")
	expect_equal(easy.hint_cost(), 0)
	var hard := _rota("hard", 1)
	var first := hard.hint()
	expect(first.contains(" with "), "the hint names who: " + first)
	expect_equal(hard.hint_cost(), RotaTask.HINT_COST)
	var extreme := _rota("extreme", 1)
	expect(not extreme.hints_allowed(), "no hints on extreme")
	expect(extreme.hint().is_empty(), "and none given")
	var view := add_node(RotaView.new(extreme)) as RotaView
	expect(not (view.find_child("Hint", true, false) as Button).visible, "the hint button is hidden on extreme")


func test_a_hint_finds_the_patient_that_has_to_move() -> void:
	var rota := _rota("hard", 6)
	# Every drip with the nurse who can't give IV: nothing else can fix that.
	for entry in rota.patients:
		if bool(entry["iv"]):
			rota.select(str(entry["id"]))
			rota.assign("joel")
			break
	var said := rota.hint()
	expect(said.begins_with("Move"), "the hint says what to move: " + said)


func test_following_every_hint_signs_a_rota_that_holds() -> void:
	var rota := _rota("hard", 17)
	var guard := 0
	while not rota.uncovered().is_empty() and guard < 20:
		guard += 1
		rota.hint()
		var waiting := rota.uncovered()
		var next := ""
		for entry in rota.patients:
			if rota.coach.begins_with(str(entry["short"]) + " with"):
				next = str(entry["id"])
		expect(next in waiting, "the hint names someone waiting")
		var who := ""
		for member in rota.staff:
			if rota.coach.contains(" with %s." % str(member["short"])):
				who = str(member["id"])
		rota.select(next)
		rota.assign(who)
	rota.sign_rota()
	expect(rota.all_right(), "hints lead to a rota that holds")
	expect_equal(rota.score(), 100 - rota.hints_used * RotaTask.HINT_COST)


func test_the_rules_card_shows_only_on_easy_and_the_screen_shows_loads() -> void:
	var easy_task := _rota("easy", 1)
	var easy := add_node(RotaView.new(easy_task)) as RotaView
	expect(easy.find_child("Rules", true, false) != null, "rules card on easy")
	var hard := add_node(RotaView.new(_rota("hard", 1))) as RotaView
	expect(hard.find_child("Rules", true, false) == null, "no card on hard")
	var first := str(easy_task.patients[0]["id"])
	easy.pick(first)
	easy.give_to("priya")
	expect(easy.staff_button("priya").text.contains("%d/6" % int(easy_task.patients[0]["load"])), easy.staff_button("priya").text)
	expect(easy.staff_button("joel").text.contains("no drips"), "the agency nurse shows he can't run a drip")
	expect(easy.patient_button(first).text.contains("→ Priya"), "the patient shows who has them")


# --- Mrs. Sinha's bile leak -----------------------------------------------------

func _theatre(setup: Dictionary) -> Theatre:
	var doctor := PlayerProfile.new()
	doctor.name = "Asha Verma"
	doctor.day = 25
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


func test_the_bile_leak_plays_well_and_badly_at_every_level() -> void:
	for level: String in OperationTask.DIFFICULTIES:
		var good := _play_op({"procedure": "bile_leak", "difficulty": level, "allergy_known": true}, "good")
		expect(good.finished, "%s: finished" % level)
		expect_equal(good.outcome, "won", "%s played well" % level)
		var bad := _play_op({"procedure": "bile_leak", "difficulty": level}, "bad")
		expect(bad.outcome != "won", "%s played badly doesn't go well" % level)


func test_where_it_leaks_is_seeded_and_harder_by_level() -> void:
	var kinds := {}
	for with_seed in range(1, 25):
		var one := OperationTask.new(with_seed, {"procedure": "bile_leak", "difficulty": "hard"})
		var two := OperationTask.new(with_seed, {"procedure": "bile_leak", "difficulty": "hard"})
		expect_equal(one.variants, two.variants, "the same leak for the same seed")
		expect_equal(one.targets, two.targets, "the same layout for the same seed")
		kinds[str(one.variants["leak"])] = true
	expect(kinds.size() > 1, "hard cases differ from seed to seed")
	expect_equal(OperationTask.new(3, {"procedure": "bile_leak", "difficulty": "easy"}).variants["leak"], "stump")
	expect_equal(OperationTask.new(3, {"procedure": "bile_leak", "difficulty": "extreme"}).variants["leak"], "duct")


func test_every_leak_target_is_clear_of_its_traps() -> void:
	for leak: String in ["stump", "bed", "duct"]:
		for with_seed in [1, 7, 40, 300, 512]:
			var op := OperationTask.new(with_seed, {"procedure": "bile_leak", "difficulty": "hard", "leak": leak})
			expect_equal(op.variants["leak"], leak)
			for entry: Dictionary in op.procedure["steps"]:
				if not entry.has("target"):
					continue
				var right: Vector2 = op.targets[str(entry["target"])]
				for trap: String in (entry.get("traps", {}) as Dictionary):
					expect(right.distance_to(op.targets[trap]) > 0.9,
						"%s seed %d: %s is clear of %s" % [leak, with_seed, entry["target"], trap])


func test_a_hole_in_the_main_duct_gets_a_drain_not_a_clip() -> void:
	var op := _play_op({"procedure": "bile_leak", "difficulty": "extreme", "allergy_known": true}, "good")
	expect("chose_drain" in op.happened, "drained, not clipped")
	expect_equal(op.outcome, "won")
	var clipped := _play_op({"procedure": "bile_leak", "difficulty": "easy", "allergy_known": true}, "good")
	expect("chose_reclip" in clipped.happened, "a slipped clip is clipped again")


func test_her_penicillin_allergy_is_on_the_board_only_if_you_asked() -> void:
	var told := {}
	for entry in OperationTask.new(1, {"procedure": "bile_leak", "allergy_known": true}).timeout_lines:
		if str(entry["id"]) == "allergy":
			told = entry
	expect_equal(told["right"], "stop", "knowing about the penicillin, you stop the co-amoxiclav")
	var unknown := {}
	for entry in OperationTask.new(1, {"procedure": "bile_leak"}).timeout_lines:
		if str(entry["id"]) == "allergy":
			unknown = entry
	expect_equal(unknown["right"], "unsure")


# --- The story, Days 24 to 28 ---------------------------------------------------

const CAREFUL := ["Support", "Ask", "Explain", "Together", "Promise", "Refuse", "Tea", "Truth", "Credit Grace", "Own it",
	"Patients", "Sethi", "Families", "Everything"]
const CARELESS := ["Stop", "Polite", "Brief", "Complication", "Listen", "Sign", "Thank", "Defend", "Budgets", "Advertise",
	"Count", "Nothing"]
const BEFORE := ["op_rohit_done", "op_rohit_won", "promoted", "beds_saved", "rider_treated", "jump_9", "op_raju_won",
	"credit_proof", "jump_14", "op_gomes_won", "nanda_called", "mm_credit_zoya", "vote_night_doctor", "jump_19",
	"op_kurup_won", "kurup_told_now", "candour_together", "count_rule", "sethi_fair", "hod_talk"]


func _ward(day: int, flags: Array = []) -> Ward:
	var doctor := PlayerProfile.new()
	doctor.name = "Asha Verma"
	doctor.day = day
	doctor.opening_seen = true
	doctor.created = true
	doctor.total_xp = LevelCurve.total_xp_to_reach(Rank.FIRST_LEVELS[Rank.HEAD_OF_DEPARTMENT]) + 400
	doctor.rank_held = Rank.HEAD_OF_DEPARTMENT
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


func test_six_months_later_the_nurses_vote_to_strike_and_a_rival_tours_the_ward() -> void:
	var ward := _ward(24)
	expect(ward.profile.has_flag("jump_24"), "six months later")
	expect(_play_day(ward, CAREFUL), "the day ends")
	for flag: String in ["strike_backed", "kapoor_asked"]:
		expect(ward.profile.has_flag(flag), flag)
	expect_equal(WardStory.end_line(ward.profile, 24), "Your letter is on the board's desk. The strike is on for Thursday.")


func test_telling_the_nurses_to_stop_is_remembered() -> void:
	var ward := _ward(24)
	var before := ward.profile.trust("grace", 50)
	expect(_play_day(ward, CARELESS), "the day ends")
	expect(ward.profile.has_flag("strike_opposed"))
	expect(ward.profile.trust("grace", 50) < before, "Grace trusts you less")


func test_day_twenty_five_the_day_case_comes_back_and_the_surgeon_tells_her() -> void:
	var ward := _ward(25, ["jump_24", "strike_backed"])
	var places := []
	expect(_play_day(ward, CAREFUL, "good", places), "the day ends")
	expect(places.has("theatre"))
	for flag: String in ["sinha_history_allergy", "op_sinha_won", "sinha_together", "pilot_paused"]:
		expect(ward.profile.has_flag(flag), flag)
	var op := ward.operation
	expect(op != null and op.id == "bile_leak", "the bile leak")
	expect(bool(op.setup["allergy_known"]), "theatre knew about the penicillin")
	expect_equal(op.scrub_name(), "Neha")
	expect_equal(WardStory.end_line(ward.profile, 25), "Mrs. Sinha heard it from the surgeon, with you beside him.")


func test_writing_known_complication_costs_dr_iyer_s_trust() -> void:
	var ward := _ward(25, ["jump_24", "strike_opposed"])
	var before := ward.profile.trust("iyer", 50)
	expect(_play_day(ward, CARELESS, "shaky"), "the day ends")
	expect(ward.profile.has_flag("sinha_covered"))
	expect(ward.profile.trust("iyer", 50) < before, "Dr. Iyer heard it")
	expect_equal(WardStory.end_line(ward.profile, 25), "Her notes say 'known complication'. Her son is driving from Lucknow.")


func test_strike_day_you_plan_cover_with_grace_and_send_the_agency_back() -> void:
	var ward := _ward(26, ["jump_24", "strike_backed", "sinha_together", "pilot_paused"])
	ward.play_until(func() -> bool: return ward.view is RotaView, Ward.pick_tones(CAREFUL))
	var view := ward.view as RotaView
	expect(view != null, "the rota opens")
	expect_equal(ward.talking_with, "grace", "the camera stays on Grace")
	expect(view.kicker_override.begins_with("Strike day"), view.kicker_override)
	expect(_play_day(ward, CAREFUL), "the day ends")
	for flag: String in ["strike_rota_done", "strike_rota_right", "strike_no_agency", "picket_tea"]:
		expect(ward.profile.has_flag(flag), flag)
	expect(not ward.profile.has_flag("strike_rota_gap"))
	expect_equal(WardStory.end_line(ward.profile, 26), "The strike is over: two more nurses on nights. Nobody came to harm.")


func test_a_careless_rota_and_agency_nurses_break_the_strike() -> void:
	var ward := _ward(26, ["jump_24", "strike_opposed"])
	expect(_play_day(ward, CARELESS, "bad"), "the day ends")
	expect(ward.profile.has_flag("strike_rota_done"))
	expect(not ward.profile.has_flag("strike_rota_right"), "rules broken")
	expect(ward.profile.has_flag("strike_agency"))
	expect_equal(WardStory.end_line(ward.profile, 26), "The strike is over. Twelve agency nurses broke it. Kapoor's.")


func test_the_board_votes_you_chief_of_medicine() -> void:
	var ward := _ward(27, ["jump_24", "strike_backed", "sinha_together", "pilot_paused", "strike_rota_right",
		"strike_no_agency", "picket_tea"])
	expect_equal(ward.profile.rank(), Rank.HEAD_OF_DEPARTMENT)
	var places := []
	expect(_play_day(ward, CAREFUL, "good", places), "the day ends")
	expect(places.has("seminar"))
	expect_equal(ward.profile.rank(), Rank.CHIEF, "promoted")
	expect(ward.profile.level() >= Rank.FIRST_LEVELS[Rank.CHIEF], "with the experience to match")
	expect_equal(WardStory.end_line(ward.profile, 27), "Chief of Medicine, from Monday.")


func test_the_board_has_seen_the_videos() -> void:
	var ward := _ward(27, ["jump_24", "strike_opposed", "sinha_covered", "strike_agency"])
	var before := ward.profile.trust("rajan", 40)
	expect(_play_day(ward, CARELESS), "the day ends")
	expect(ward.profile.trust("rajan", 40) < before, "Mrs. Rajan heard you defend it")
	expect_equal(ward.profile.rank(), Rank.CHIEF, "by one vote")


func test_waiting_until_after_the_vote_she_asks_you_herself() -> void:
	var ward := _ward(27, ["jump_24", "sinha_waited", "strike_talks", "strike_no_agency"])
	expect(_play_day(ward, CAREFUL), "the day ends")
	expect(ward.profile.has_flag("sinha_told_late"), "told before the vote, late")


func test_the_last_day_you_pick_a_head_of_surgery_and_meet_your_intern() -> void:
	var ward := _ward(28, ["jump_24", "sinha_together", "strike_no_agency", "promoted"])
	ward.profile.rank_held = Rank.CHIEF
	var places := []
	expect(_play_day(ward, CAREFUL, "good", places), "the day ends")
	for flag: String in ["hos_sethi", "lesson_ask"]:
		expect(ward.profile.has_flag(flag), flag)
	expect(places.has("ward"))
	expect(ward.profile.trust("iyer", 45) > 45, "the last talk at the lightbox, with Dr. Iyer")
	expect(ward.profile.minutes >= 18 * 60 + 20, "at the end of the day")
	expect_equal(WardStory.end_line(ward.profile, 28), "Chief of Medicine. The pager still goes off. You still answer it.")


func test_the_last_talk_at_the_x_ray_viewer_is_seen_from_inside_the_ward() -> void:
	var ward := _ward(28, ["jump_24", "sinha_together", "strike_no_agency", "promoted", "hos_sethi", "lesson_ask"])
	ward.profile.rank_held = Rank.CHIEF
	ward.skip_to("ending")
	expect(ward.play_until(func() -> bool: return ward.conversation == "ending" and ward.talk_ui.is_choosing(),
		Ward.pick_tones(CAREFUL)), "the ending talk")
	ward.settle_camera()
	expect(ward.camera.position.x > Ward.ROOM_MIN_X - 0.01, "not behind the end wall (%.2f)" % ward.camera.position.x)
	expect(ward.camera.position.z > -4.0, "not behind the back wall")


func test_only_a_surgeon_who_told_her_can_be_head_of_surgery() -> void:
	var ward := _ward(28, ["jump_24", "sinha_covered"])
	ward.profile.rank_held = Rank.CHIEF
	expect(_play_day(ward, ["Sethi", "Iyer"]), "the day ends")
	expect(not ward.profile.has_flag("hos_sethi"), "Sethi isn't offered")
	expect(ward.profile.has_flag("hos_iyer"))


func test_after_the_last_day_the_quiet_days_go_on() -> void:
	var ward := _ward(29, ["jump_24", "hos_iyer"])
	ward.profile.rank_held = Rank.CHIEF
	expect(not WardStory.DAYS.has(29), "no story left to tell")
	expect(_play_day(ward, CAREFUL), "the day ends")
	expect(ward.profile.has_flag("teaching_scan_done"), "teaching films, like any quiet day")
