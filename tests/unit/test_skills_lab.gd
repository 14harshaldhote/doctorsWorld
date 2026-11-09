extends TestCase
## Day 2 in the skills lab: the room, the stations, each task's screen, the
## score card, rewards and the robot play-through of all six.

const STEP := 1.0 / 30.0


func _profile(welcomed: bool = true) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.name = "Kiran Rao"
	profile.address_form = "first"
	profile.opening_seen = true
	profile.day = 2
	for flag in ["met_iyer", "day1_grace", "day1_patient", "day1_iyer"]:
		profile.set_flag(flag)
	if welcomed:
		profile.set_flag("lab_welcome")
	return profile


func _lab(profile: PlayerProfile = null) -> SkillsLab:
	var lab := SkillsLab.new(profile if profile != null else _profile())
	add_node(lab)
	lab.settle_camera()
	return lab


func _run(lab: SkillsLab, seconds: float) -> void:
	for frame in int(seconds / STEP):
		lab.update(STEP)


func test_the_lab_has_six_stations_and_three_trainers() -> void:
	var lab := _lab()
	expect_equal(lab.stations.size(), 6)
	for id: String in TrainingTask.IDS:
		var station := lab.station_for(id)
		expect(station != null, "station %s" % id)
		var spot := station.at(station.spot)
		var floor_spot := Vector2(spot.x, spot.z)
		expect(lab.walk_area.closest_walkable(floor_spot).distance_to(floor_spot) < 0.3,
			"%s: the doctor can stand in front of it" % id)
		for rect in station.blockers():
			expect(not rect.has_point(floor_spot), "%s: its furniture leaves the doctor's spot free" % id)
	for id in ["iyer", "grace", "tom"]:
		expect(lab.people.has(id), "%s is in the lab" % id)
	expect(lab.mode == "walk", "a welcomed doctor starts walking")
	expect_equal(lab.hud.hint_text(), "Tap a station to train · tap the floor to walk")
	expect_equal(lab.next_station(), "scrub", "everyone starts with the sink")


func test_day_two_opens_with_a_title_card_and_a_welcome() -> void:
	var lab := _lab(_profile(false))
	expect(lab.mode == "story", "the day starts with a moment, not a menu")
	expect(lab.overlay.fade_amount() > 0.9, "the title card covers the screen")
	_run(lab, 3.0)
	expect(lab.story.is_playing(), "Dr. Iyer and Sister Grace say hello")
	expect_equal(lab.conversation, "welcome")
	lab.talk_through()
	expect(lab.profile.has_flag("lab_welcome"), "the welcome is not repeated")
	expect(lab.mode == "walk", "then the doctor is free to walk")
	expect(lab.overlay.fade_amount() < 0.05, "the card has faded away")


func test_tapping_a_station_walks_there_and_the_trainer_explains_it() -> void:
	var lab := _lab()
	var station := lab.station_for("scrub")
	var point := lab.camera.unproject_position(station.at(station.tag_point))
	expect_equal(lab.station_at(point), "scrub", "the station's tag can be tapped")
	lab.tap(point)
	expect(lab.mode == "approach" and lab.is_walking("you"), "the doctor walks over")
	expect(lab.is_walking("grace"), "Sister Grace comes across")
	_run(lab, 8.0)
	expect(lab.story.is_playing(), "the trainer explains the station first")
	expect_equal(lab.conversation, "scrub_intro")
	lab.talk_through()
	expect(lab.in_task(), "then the task opens")
	expect(lab.view is ScrubView, "with the sink's own screen")
	expect(not lab.player.visible, "seen through the doctor's own eyes")
	var grace: AvatarRig = lab.people["grace"]["rig"]
	expect(grace.position.distance_to(station.at(station.trainer_spot)) < 0.05, "Sister Grace stands by the sink")


func test_every_station_can_be_played_well_to_at_least_two_stars() -> void:
	var lab := _lab()
	var xp := lab.profile.total_xp
	for id: String in TrainingTask.IDS:
		expect(lab.go_to_task(id), "%s opens" % id)
		if not lab.in_task():
			continue
		expect(lab.play_task(), "%s finishes" % id)
		var task := lab.view.task
		expect(task.finished and lab.view.result_open(), "%s shows its score card" % id)
		expect(task.stars() >= 2, "%s: good play earns two or three stars (got %d, %d points)" % [id, task.stars(), task.score()])
		expect(not task.notes().is_empty(), "%s explains the result" % id)
		expect(lab.profile.has_flag("trained_" + id), "%s counts as done" % id)
		expect_equal(lab.profile.best_score(id), task.score(), "%s best score saved" % id)
		expect(lab.profile.total_xp > xp, "%s earns XP" % id)
		xp = lab.profile.total_xp
		lab.view.done_pressed.emit()
		expect(not lab.in_task() and lab.player.visible, "%s: back in the lab" % id)
		_run(lab, 0.5)
	expect_equal(lab.trained_count(), 6)
	expect(lab.mode == "story", "all six done: Dr. Iyer has news")
	_run(lab, 5.0)
	expect_equal(lab.conversation, "done")
	lab.talk_through(1)
	expect(lab.profile.has_flag("training_done"), "training is over")
	expect(lab.profile.has_flag("nervous_before_theatre"), "the honest reply is remembered")
	expect(lab.hud.pager_text().contains("Theatre tomorrow"), "the pager says what's next")


func test_the_score_card_offers_another_try_and_rewards_improvement_only() -> void:
	var lab := _lab()
	lab.go_to_task("history")
	var history := lab.view as HistoryView
	history.ask("cricket")
	history.ask("onset")
	history.done_asking()
	_run(lab, 2.0)
	expect(lab.view.result_open(), "the score card comes up")
	var card := lab.view.get_node("Result")
	expect(card.find_child("Score", true, false) != null, "it shows the score")
	expect(card.find_child("TryAgain", true, false) != null and card.find_child("Done", true, false) != null,
		"it offers another try or the way back")
	var first_score := lab.profile.best_score("history")
	var xp := lab.profile.total_xp
	lab.view.retry_pressed.emit()
	expect(lab.in_task() and not lab.view.result_open(), "a fresh try opens straight away")
	expect(not lab.story.is_playing(), "no second introduction")
	lab.play_task()
	expect(lab.profile.best_score("history") > first_score, "a better score replaces the best")
	expect(lab.profile.total_xp > xp, "more stars earn a little more XP")
	var best := lab.profile.best_score("history")
	xp = lab.profile.total_xp
	lab.view.retry_pressed.emit()
	(lab.view as HistoryView).ask("job")
	(lab.view as HistoryView).done_asking()
	_run(lab, 2.0)
	expect_equal(lab.profile.best_score("history"), best, "a worse try keeps the best")
	expect_equal(lab.profile.total_xp, xp, "and earns nothing")


func test_leaving_a_task_scores_nothing() -> void:
	var lab := _lab()
	lab.go_to_task("scrub")
	(lab.view as ScrubView).press("water")
	lab.view.leave_pressed.emit()
	expect(not lab.in_task(), "back in the lab")
	expect(lab.mode == "walk" and lab.player.visible, "walking again")
	expect(not lab.profile.has_flag("trained_scrub"), "not counted")
	expect_equal(lab.profile.best_score("scrub"), -1)


func test_scrub_screen_holds_to_scrub_and_warns_out_of_order() -> void:
	var lab := _lab()
	lab.go_to_task("scrub")
	var view := lab.view as ScrubView
	var scrub := view.task as ScrubTask
	view.press("soap")
	expect(scrub.coach_warns, "soap before water is called out")
	view.press("water")
	view.press("soap")
	view.hold("palms")
	_run(lab, ScrubTask.SCRUB_TIME + 0.2)
	expect(scrub.area_done("palms"), "holding scrubs")
	var sink := lab.station_for("scrub") as ScrubSink
	expect_equal(sink.scrubbing, "palms", "the hands rub in the sink")
	view.release()
	view.press("nose")
	expect_equal(scrub.contaminations, 1, "scratching the nose after soap counts")
	expect(not scrub.area_done("palms"), "and the scrub starts again")


func test_monitor_screen_learns_then_quizzes_without_red_numbers() -> void:
	var lab := _lab()
	lab.go_to_task("monitor")
	var view := lab.view as MonitorView
	var monitor := view.task as MonitorTask
	for kind: String in Vitals.KINDS:
		view.pick(kind)
	_run(lab, 0.2)
	expect_equal(view.monitor.marks.size(), 4, "every number learned is ticked")
	view.show_patients()
	_run(lab, 0.2)
	expect_equal(monitor.phase, "quiz")
	expect(not view.monitor.show_alarms, "the quiz doesn't colour the answer red")
	expect(view.monitor.status.begins_with("PATIENT 1"), "the timer shows")
	var right := monitor.answer_now()
	var wrong := "hr" if right != "hr" else "rr"
	view.pick(wrong)
	_run(lab, 0.1)
	expect_equal(str(view.monitor.marks.get(wrong, "")), "wrong", "a wrong pick is marked")
	if right != "none":
		expect_equal(str(view.monitor.marks.get(right, "")), "answer", "and the right one is shown")


func test_history_screen_gives_verdicts_and_fills_the_case_notes() -> void:
	var lab := _lab()
	lab.go_to_task("history")
	var view := lab.view as HistoryView
	expect_equal(view.speaker_override, "Mr. Ravi Kumar", "the patient answers")
	view.ask("allergy")
	_run(lab, 0.2)
	expect(view.button_for("allergy").disabled, "a question is asked once")
	var notes := view.get_node("CaseNotes")
	var text := ""
	for found in notes.find_children("*", "Label", true, false):
		text += (found as Label).text + "\n"
	expect(text.contains("penicillin"), "the allergy goes in the notes")
	expect(lab.view._coach_text.text.contains("Penicillin"), "and is heard in his own words")


func test_instrument_tray_and_ring_pick_what_was_asked() -> void:
	var lab := _lab()
	lab.go_to_task("instruments")
	var view := lab.view as InstrumentView
	var tray := view.task as InstrumentTask
	var trolley := lab.station_for("instruments") as InstrumentTrolley
	for instrument: String in Instruments.ALL:
		var point := lab.camera.unproject_position(trolley.instrument_point(instrument))
		expect_equal(trolley.instrument_at(lab.camera, point), instrument, "%s can be tapped on the tray" % instrument)
	var wrong := Instruments.ALL[0] if tray.wanted != Instruments.ALL[0] else Instruments.ALL[1]
	view.pick(wrong)
	expect(tray.coach_warns, "a wrong pick is explained")
	view.world_tap(lab.camera.unproject_position(trolley.instrument_point(tray.wanted)))
	expect(tray.revealing and tray.handed == tray.wanted, "tapping the right one on the tray hands it over")
	expect(not view.ring.visible, "the ring waits for the mock operation")


func test_iv_screen_picks_a_vein_sets_the_angle_and_steadies() -> void:
	var lab := _lab()
	lab.go_to_task("iv")
	var view := lab.view as IvView
	var iv := view.task as IvTask
	var arm := lab.station_for("iv") as ArmPad
	for which: String in IvTask.VEINS:
		var point := lab.camera.unproject_position(arm.vein_point(which))
		expect_equal(arm.vein_at(lab.camera, point), which, "the %s vein can be tapped" % which)
	view.world_tap(lab.camera.unproject_position(arm.vein_point("forearm")))
	expect_equal(iv.vein, "forearm")
	view.set_angle(20)
	expect_near(iv.angle, 20.0)
	view.insert()
	expect_equal(iv.phase, "steady")
	var before := iv.offset
	view.drag(Vector2(UiKit.px(IvView.PIXELS_PER_MM) * 2.0, 0))
	expect_near(iv.offset.x - before.x, 2.0, 0.01, "a drag moves the tip by millimetres")


func test_stitch_pad_turns_taps_into_pad_positions() -> void:
	var lab := _lab()
	lab.go_to_task("stitch")
	var view := lab.view as StitchView
	var pad := lab.station_for("stitch") as SuturePad
	for spot: Vector2 in [Vector2(2, 4), Vector2(6, 4.5), Vector2(10, 3.5)]:
		var found: Variant = pad.pad_point(lab.camera, lab.camera.unproject_position(pad.pad_point_world(spot)))
		expect(found != null and (found as Vector2).distance_to(spot) < 0.05, "%s survives the round trip" % spot)
	expect(pad.pad_point(lab.camera, Vector2(2, 2)) == null, "a tap off the pad is ignored")
	var task := view.task as StitchTask
	view.world_tap(lab.camera.unproject_position(pad.pad_point_world(task.point_at(0.5))))
	expect_equal(task.stitches.size(), 1, "a tap on the cut places a stitch")
	_run(lab, 0.1)
	expect_equal(pad.get_node("Pad/Stitches").get_child_count(), 1, "and it shows on the pad")


func test_hud_shows_stars_for_each_station() -> void:
	var profile := _profile()
	profile.record_score("scrub", 90)
	profile.set_flag("trained_scrub")
	var lab := _lab(profile)
	var stars := lab.hud.find_children("*", "UiIcon", true, false).filter(
		func(icon: Node) -> bool: return (icon as UiIcon).kind == "star")
	expect_equal(stars.size(), 3, "three lit stars for a 90")
	expect_equal(lab.next_station(), "monitor")
