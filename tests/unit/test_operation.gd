extends TestCase
## Rohit's appendectomy: the rules on their own, and whole operations
## played well, shakily and badly in Theatre 2.


func _theatre(flags: Array = [], setup: Dictionary = {}, scrub: int = 90) -> Theatre:
	var doctor := PlayerProfile.new()
	doctor.name = "Asha Verma"
	doctor.day = 3
	doctor.opening_seen = true
	var theatre := add_node(Theatre.new(doctor)) as Theatre
	theatre.operation_setup = setup
	theatre.skip_to("operation", flags, scrub)
	return theatre


func _play(theatre: Theatre, quality: String, seconds: float = 240.0) -> OperationTask:
	var bot := AutoPlayer.new()
	bot.quality = quality
	var step := 1.0 / 30.0
	for frame in int(seconds / step):
		if theatre.view == null or theatre.view.result_open():
			break
		bot.step(theatre.view, step)
		theatre.update(step)
	return theatre.operation


## Ticks a task until it stops being busy (a line, a hand-over).
func _settle(op: OperationTask, limit: float = 10.0) -> void:
	var waited := 0.0
	while op.busy() and waited < limit:
		op.tick(0.1)
		waited += 0.1


func test_played_well_rohit_is_fine() -> void:
	for flags: Array in [[], ["rohit_allergy_known"]]:
		for complication: String in ["bleeding", "pressure"]:
			var op := _play(_theatre(flags, {"complication": complication}), "good")
			expect(op.finished, "the operation ends")
			expect_equal(op.outcome, "won", "%s %s" % [flags, complication])
			expect(op.stars() >= 2, "a good operation earns stars")
			expect(complication in op.happened, "the %s happened" % complication)
			expect(not op.takeover)
			cleanup()


func test_played_shakily_it_is_a_struggle() -> void:
	for complication: String in ["bleeding", "pressure"]:
		var op := _play(_theatre([], {"complication": complication}), "shaky")
		expect_equal(op.outcome, "struggled", complication)
		expect(not op.takeover, "Dr. Iyer lets the doctor finish")
		expect("reaction" in op.happened, "confirming 'no allergies' brings the reaction")
		expect("wrong_side" in op.happened, "confirming the wrong side is caught at the incision")
		expect(op.teamwork() < 70, "wrong calls cost teamwork")
		cleanup()


func test_played_badly_dr_iyer_takes_over() -> void:
	for flags: Array in [[], ["rohit_delayed"]]:
		var theatre := _theatre(flags)
		var op := _play(theatre, "bad")
		expect(op.finished)
		expect(op.takeover, "Dr. Iyer takes over")
		expect_equal(op.outcome, "failed")
		expect(op.score() < 40, "a failed operation scores low")
		expect(op.stability <= OperationTask.TAKEOVER)
		expect_equal(op.coach, "My hands. Step back. Now.")
		cleanup()


func test_the_time_out_catches_the_wrong_side_and_the_allergy() -> void:
	var op := OperationTask.new(1, {"allergy_known": true, "complication": "pressure"})
	expect_equal(op.phase, "timeout")
	expect_equal(op.timeout_line()["id"], "patient")
	op.answer_timeout("confirm")
	_settle(op)
	op.answer_timeout("confirm")
	_settle(op)
	expect_equal(op.timeout_line()["reads"], "LEFT lower belly", "the board has the wrong side")
	op.answer_timeout("stop")
	_settle(op)
	expect_equal(op.timeout_choices(), ["confirm", "unsure", "stop"] as Array[String], "allergies can be 'not sure'")
	op.answer_timeout("stop")
	expect(op.coach.contains("Penicillin"), "Dr. Khan swaps the antibiotic")
	_settle(op)
	expect_equal(op.phase, "call", "then the operation starts")
	expect_equal(op.wanted, "scalpel")
	expect_near(op.timeout_points, 4.0)
	expect(not op.later.has("incision"), "no reaction coming")
	var careless := OperationTask.new(1, {"allergy_known": false})
	for answer in 4:
		careless.answer_timeout("confirm")
		_settle(careless)
	expect(careless.later.get("incision", []).has("reaction"), "confirming 'none known' brings a reaction")
	expect(careless.wrong_side or "wrong_side" in careless.happened, "the wrong side slips through")


func test_tom_hands_it_over_after_three_wrong_calls_or_a_long_wait() -> void:
	var op := OperationTask.new(1, {"complication": "pressure"})
	for answer: String in ["confirm", "confirm", "stop", "unsure"]:
		op.answer_timeout(answer)
		_settle(op)
	expect_equal(op.phase, "call")
	var before := op.stability
	op.call_for("forceps")
	expect(op.coach_warns and op.speaker == "tom", "Tom questions a wrong call")
	op.call_for("clamp")
	op.call_for("swab")
	expect_equal(op.handed_over, 1, "after three wrong calls Tom hands it over")
	expect_equal(op.in_hand, "scalpel")
	expect(op.stability < before, "wrong calls cost a little")
	_settle(op)
	expect_equal([op.phase, op.action], ["act", "trace"])
	var slow := OperationTask.new(1, {"complication": "pressure"})
	for answer: String in ["confirm", "confirm", "stop", "unsure"]:
		slow.answer_timeout(answer)
		_settle(slow)
	for tick in 120:
		slow.tick(0.1)
	expect_equal(slow.slow_calls, 1, "waiting counts as a slow call")
	expect_equal(slow.handed_over, 1, "then Tom hands it over anyway")


func test_bleeding_drains_until_clamped_and_a_lost_swab_must_be_found() -> void:
	var theatre := _theatre(["rohit_allergy_known"], {"complication": "bleeding", "lose_swab": 1})
	var op := theatre.operation
	var bot := AutoPlayer.new()
	var step := 1.0 / 30.0
	var drained := false
	for frame in 3000:
		if op.active_complication == "bleeding":
			var before := op.stability
			theatre.update(0.5)
			drained = drained or op.stability < before
			if op.phase == "call":
				# A swab presses on it but doesn't stop it.
				theatre.view.call(&"call_for", "swab")
		if op.phase == "count":
			break
		bot.step(theatre.view, step)
		theatre.update(step)
	expect(drained, "Rohit gets less stable while he bleeds")
	expect_equal(op.phase, "count")
	expect(op.swab_missing, "a swab used in the bleeding goes missing")
	expect_equal(op.swabs_back, op.swabs_out - 1)
	op.count("close")
	expect(op.closed_on_bad_count, "closing on a wrong count is noted")
	_settle(op)
	expect_equal(op.phase, "search", "Dr. Iyer makes the doctor look")
	var table := theatre.station_for("appendix") as OperatingTable
	expect(table.targets_shown(op).has("swab"), "the swab can be tapped")
	(theatre.view as OperationView).world_tap(theatre.camera.unproject_position(table.target_point("swab")))
	expect(op.swab_found, "tapping the swab finds it")
	expect_equal(op.swabs_back, op.swabs_out)
	_settle(op)
	expect_equal(op.wanted, "needle_holder", "then the closing")
	expect(op.safety() < 70, "the bad count costs safety")


func test_waiting_lets_the_appendix_burst() -> void:
	var op := _play(_theatre(["rohit_delayed"]), "good")
	expect("burst" in op.happened, "a delayed operation finds it burst")
	expect_equal(op.outcome, "won", "a good team still wins")
	expect(op.notes().any(func(note: Dictionary) -> bool: return str(note["text"]).contains("burst")),
		"the score card explains the burst")


func test_the_screen_follows_the_operation() -> void:
	var theatre := _theatre()
	var view := theatre.view as OperationView
	var op := theatre.operation
	theatre.update(0.1)
	expect(view.choice_button("confirm") != null and view.choice_button("stop") != null, "the time-out board has its answers")
	expect(not view.ring.visible, "no ring during the time-out")
	expect(not view._leave.visible, "nobody leaves an operation")
	for answer: String in ["confirm", "confirm", "stop", "unsure"]:
		view.choice_button(answer).pressed.emit()
		for frame in 150:
			theatre.update(1.0 / 30.0)
			if op.phase in ["timeout", "call"]:
				break
	expect_equal(op.phase, "call")
	expect(view.ring.visible, "the ring shows for a call")
	view.ring.button_for("scalpel").pressed.emit()
	for frame in 40:
		theatre.update(1.0 / 30.0)
	expect_equal(op.action, "trace")
	# Trace the line on screen, like a finger.
	var table := theatre.station_for("appendix") as OperatingTable
	var cam := theatre.camera
	view.world_press(cam.unproject_position(table.skin_world(op.guide_point(0.0))))
	for index in 21:
		view.world_move(cam.unproject_position(table.skin_world(op.guide_point(index / 20.0))))
	view.world_release(Vector2.ZERO)
	expect(op.trace_score >= 85, "an accurate trace on screen scores well (got %d)" % op.trace_score)
	expect(view.monitor.status == "STABLE", "the monitor shows how he is")
