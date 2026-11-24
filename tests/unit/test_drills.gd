extends TestCase
## Training spread through the career: a true story on every Day 2 score
## card, and a short drill in the skills lab between every day from the end
## of Day 3 to the start of Day 28, with free XP for turning up.

const SAVE := "user://test_drills/save.json"
const STEP := 1.0 / 30.0


func _main(day: int) -> Main:
	for file: String in ["save.json", "save.json.tmp", "settings.json", "settings.json.tmp", "save.bak1.json", "save.bak2.json", "save.bak3.json", ".install"]:
		if FileAccess.file_exists("user://test_drills/" + file):
			DirAccess.remove_absolute("user://test_drills/" + file)
	var main := Main.new()
	main.store = SaveStore.new(SAVE)
	main.settings_path = "user://test_drills/settings.json"
	add_node(main)
	main.profile.name = "Kiran Rao"
	main.profile.created = true
	main.profile.opening_seen = true
	main.profile.day = day
	main.profile.total_xp = 900
	for flag in ["met_iyer", "day1_iyer", "lab_welcome", "training_done", "op_rohit_done", "op_rohit_won"]:
		main.profile.set_flag(flag)
	for id: String in TrainingTask.IDS:
		main.profile.record_score(id, 70)
	return main


## The evening after a ward day comes before the drill: straight to bed.
func _past_evening(main: Main) -> void:
	var evening := main.screen as Evening
	expect(evening != null, "the evening comes first")
	if evening != null:
		evening.choose("bed")
		evening.play_until(func() -> bool: return main.screen != evening, 0, 0.7, 60.0)


func _card(lab: SkillsLab) -> DrillCard:
	for frame in 150:
		if lab.drill_card != null:
			break
		lab.update(STEP)
	return lab.drill_card


func test_a_drill_comes_between_every_day_from_three_to_twenty_eight() -> void:
	expect_equal(Drills.before_day(2), "", "none before the skills lab")
	expect_equal(Drills.before_day(3), "", "none before theatre day, the day after training")
	expect_equal(Drills.before_day(29), "", "none once the Chief's days begin")
	var times := {}
	var facts := {}
	for day in range(Drills.FIRST_BEFORE, Drills.LAST_BEFORE + 1):
		var station := Drills.before_day(day)
		expect(station in TrainingTask.IDS, "Day %d has a real station: %s" % [day, station])
		expect(station != Drills.before_day(day - 1), "never the same station two days running (Day %d)" % day)
		times[station] = int(times.get(station, 0)) + 1
		var fact := Drills.fact_for(day)
		expect(not fact.is_empty(), "with a true story (Day %d)" % day)
		expect(not facts.has(fact), "never the same story twice (Day %d)" % day)
		facts[fact] = true
	expect_equal(times.size(), Drills.ORDER.size(), "every drill station comes round")
	for station: String in times:
		expect(int(times[station]) >= 4, "%s comes round about every five days" % station)


func test_every_station_has_true_stories_and_day_two_shows_them() -> void:
	for id: String in TrainingTask.IDS:
		expect(TrainingFacts.count(id) >= 6, "%s has at least six stories" % id)
		var seen := {}
		for index in TrainingFacts.count(id):
			var fact := TrainingFacts.fact(id, index)
			expect(fact.length() > 40 and fact.length() < 260, "a story worth reading, not too long: %s" % fact.left(40))
			expect(not seen.has(fact), "no repeats")
			seen[fact] = true
	var profile := PlayerProfile.new()
	profile.name = "Kiran Rao"
	profile.opening_seen = true
	profile.day = 2
	profile.set_flag("lab_welcome")
	var lab := add_node(SkillsLab.new(profile)) as SkillsLab
	lab.settle_camera()
	expect(lab.go_to_task("monitor"), "the monitor station opens")
	expect_equal(lab.view.fact, TrainingFacts.fact("monitor", 0), "the first story waits on the score card")
	expect(lab.play_task(), "it's played")
	var shown := lab.view.find_child("FactText", true, false) as Label
	expect(shown != null and shown.text.contains(TrainingFacts.fact("monitor", 0)), "and the score card tells it")
	lab.view.retry_pressed.emit()
	expect_equal(lab.view.fact, TrainingFacts.fact("monitor", 1), "trying again brings the next story")


func test_finishing_a_day_opens_the_drill_with_a_story_and_free_xp() -> void:
	var main := _main(3)
	main._on_day_finished()
	var lab := main.screen as SkillsLab
	expect(lab != null and lab.drill == Drills.before_day(4), "Day 3 ends in the skills lab, for a drill")
	expect_equal(main.profile.day, 4, "the save has moved on to Day 4")
	expect(main.profile.has_flag(Drills.FLAG), "with the drill waiting")
	var card := _card(lab)
	expect(card != null, "the drill's card comes up")
	if card == null:
		return
	expect(card.fact_label.text == Drills.fact_for(4), "with today's true story")
	expect((card.find_child("Reward", true, false) as Label).text.contains("Free XP"), "and the free XP on offer")
	var before := main.profile.total_xp
	card.start_button.pressed.emit()
	expect(lab.view != null and lab.view.task.id == lab.drill, "Start opens the station's task")
	expect(lab.play_task(), "it's played")
	var earned := main.profile.total_xp - before
	expect(earned >= Drills.xp(main.profile.rank(), 0, false), "XP just for turning up (%d)" % earned)
	expect(earned <= Drills.best_xp(main.profile.rank()), "no more than the most a drill gives")
	expect(not main.profile.has_flag(Drills.FLAG), "the drill counts as done once scored")
	lab.view.retry_pressed.emit()
	lab.play_task()
	expect_equal(main.profile.total_xp - before, earned, "trying again is practice, not more XP")
	lab.view.done_pressed.emit()
	expect(main.screen is Ward and main.profile.day == 4, "then Day 4 starts")


func test_a_drill_can_be_skipped_and_quitting_never_skips_or_repeats_one() -> void:
	var main := _main(10)
	main.profile.set_flag("jump_9")
	main._on_day_finished()
	_past_evening(main)
	var lab := main.screen as SkillsLab
	expect(lab != null and lab.drill == Drills.before_day(11), "a drill before Day 11")
	_card(lab)
	# Closed the game on the card: the drill is still there next time.
	main.show_title()
	(main.screen as TitleScreen).continue_pressed.emit()
	lab = main.screen as SkillsLab
	expect(lab != null and lab.drill == Drills.before_day(11), "continue comes back to the drill")
	var before := main.profile.total_xp
	_card(lab).skip_button.pressed.emit()
	expect(main.screen is Ward and main.profile.day == 11, "Skip goes straight to Day 11")
	expect_equal(main.profile.total_xp, before, "a skipped drill gives nothing")
	main.show_title()
	(main.screen as TitleScreen).continue_pressed.emit()
	expect(main.screen is Ward, "and continue goes to the ward, not the drill again")
	var saved: PlayerProfile = SaveStore.new(SAVE).load_or_start()["profile"]
	expect(not saved.has_flag(Drills.FLAG), "the save knows the drill is over")


func test_higher_ranks_earn_more_from_a_drill() -> void:
	var last := 0
	for rank in [Rank.INTERN, Rank.JUNIOR_RESIDENT, Rank.SENIOR_RESIDENT, Rank.SURGEON, Rank.HEAD_OF_DEPARTMENT]:
		var plain := Drills.xp(rank, 0, false)
		expect(plain > last, "%s gets more for turning up (%d)" % [Rank.title(rank), plain])
		expect(Drills.xp(rank, 3, false) > plain and Drills.xp(rank, 3, true) > Drills.xp(rank, 3, false),
			"stars and a new best add more")
		last = plain


func test_closing_the_game_halfway_through_a_day_never_counts_anything_twice() -> void:
	var main := _main(8)
	main.profile.total_xp = 1500
	main.show_hospital()
	var ward := main.screen as Ward
	var picker := Ward.pick_tones(["Ready", "Honest", "Reassure", "Ask her", "Check", "Own it", "Calm", "Compromise",
		"To Aarav", "Gentle", "Careful", "Stay", "Patient first", "Answer", "Light", "Ask him", "The facts", "Grateful"])
	ward.play_until(func() -> bool: return main.profile.has_flag("promoted"), picker, AutoPlayer.new(), 1500.0)
	expect_equal(main.profile.rank(), Rank.JUNIOR_RESIDENT, "promoted at the review")
	ward.play_until(func() -> bool: return ward.mode == "walk" or ward.mode == "end", picker, AutoPlayer.new(), 300.0)
	# The game closes before the day's card: the review is saved, the day isn't over.
	main.show_title()
	main.profile = SaveStore.new(SAVE).load_or_start()["profile"]
	expect_equal(main.profile.rank(), Rank.JUNIOR_RESIDENT, "the promotion was saved")
	expect_equal(main.profile.day, 8, "on Day 8")
	main.show_hospital()
	expect_equal(main.profile.rank(), Rank.INTERN, "starting Day 8 again goes back to that morning")
	expect_equal(main.profile.total_xp, 1500, "with that morning's XP")
	ward = main.screen as Ward
	ward.play_until(func() -> bool: return main.screen != ward, picker, AutoPlayer.new(), 1500.0)
	expect_equal(main.profile.rank(), Rank.JUNIOR_RESIDENT, "promoted once, not twice")
	expect_equal(main.profile.day, 9)


func test_the_morning_is_saved_with_the_career() -> void:
	var profile := PlayerProfile.new()
	profile.day = 12
	profile.total_xp = 3000
	profile.set_flag("met_iyer")
	expect(not profile.begin_day(), "the first start of a day remembers the morning")
	profile.total_xp = 3400
	profile.set_flag("raju_history_done")
	profile.promote()
	profile.change_trust("iyer", 10)
	var loaded := PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(profile.to_dict())))
	expect(loaded.begin_day(), "a saved day started again goes back")
	expect_equal(loaded.total_xp, 3000)
	expect_equal(loaded.rank(), Rank.INTERN)
	expect(loaded.has_flag("met_iyer") and not loaded.has_flag("raju_history_done"), "with that morning's flags")
	expect_equal(loaded.trust("iyer"), PlayerProfile.new().trust("iyer"), "and trust")
	loaded.day = 13
	expect(not loaded.begin_day(), "a new day remembers a new morning")


func test_a_place_to_go_counts_from_a_tap_beside_it_or_walking_up_to_it() -> void:
	var doctor := PlayerProfile.new()
	doctor.name = "Asha Verma"
	doctor.day = 4
	doctor.opening_seen = true
	doctor.created = true
	doctor.total_xp = 800
	for flag: String in ["op_rohit_done", "op_rohit_won"]:
		doctor.set_flag(flag)
	var ward := add_node(Ward.new(doctor)) as Ward
	ward.play_until(func() -> bool: return ward.mode == "walk", Ward.pick_tones(["Ready"]))
	expect_equal(ward._go_place(), "bed1", "Rohit's bed is first")
	var bed := ward.bed("bed1").at(Vector3.ZERO)
	var beside := ward.camera.unproject_position(bed + Vector3(0.6, 0, 0.4))
	expect_equal(ward.place_at(beside), "bed1", "a tap on the floor beside the bed counts")
	var rohit := ward.rig_for("rohit")
	expect_equal(ward.place_at(ward.camera.unproject_position(rohit.face_point())), "bed1", "and a tap on Rohit")
	var far := ward.camera.unproject_position(ward.mark("desk") as Vector3)
	expect_equal(ward.place_at(far), "", "but not a tap across the room")
	# Walking there without tapping it: arriving counts.
	var spot: Vector3 = ward.mark("bed1")
	ward._send("you", spot + Vector3(0.3, 0, 0.2), Ward.WALK_SPEED)
	for frame in 300:
		if ward.mode != "walk":
			break
		ward.update(STEP)
	expect(ward.mode != "walk", "walking up to the bed starts the beat (%s)" % ward.mode)


func test_a_place_off_screen_is_pinned_to_the_edge_and_still_takes_a_tap() -> void:
	var hud := add_node(LobbyHud.new(PlayerProfile.new())) as LobbyHud
	var low := hud.size.y * 0.62
	hud.set_tag("place_trolley", "Admissions", Vector2(-400, low), true, true, true)
	expect(hud.tag_pinned("place_trolley"), "a place off the left edge is pinned, with an arrow")
	var tag := hud._tags["place_trolley"] as Control
	expect(tag.position.x >= 0 and tag.position.x + tag.size.x <= hud.size.x, "inside the screen")
	expect(hud.tag_hit("place_trolley", tag.position + tag.size / 2.0), "and a tap on it counts")
	hud.set_tag("place_trolley", "Admissions", Vector2(hud.size.x * 0.5, low), true, true, true)
	expect(not hud.tag_pinned("place_trolley"), "on screen it floats over the place as before")
	hud.set_tag("place_bed1", "Bed 1", Vector2(-400, low), true, true, false)
	expect(not (hud._tags["place_bed1"] as Control).visible, "other tags still hide off screen")


func test_history_drills_bring_new_practice_patients() -> void:
	expect("history" in Drills.ORDER, "the history station comes round between days")
	var met := {}
	for day in range(Drills.FIRST_BEFORE, Drills.LAST_BEFORE + 1):
		if Drills.before_day(day) == "history":
			met[Drills.history_case(day)] = true
	expect_equal(met.size(), Drills.HISTORY_CASES.size(), "every practice patient gets a turn")
	for case_id: String in Drills.HISTORY_CASES:
		var task := HistoryTask.new(case_id)
		expect(task.patient != "The patient" and task.patient != "Mr. Ravi Kumar", "%s is a new patient" % case_id)
		expect_equal(task.actor, "iyer", "acted by Dr. Iyer, as on Day 2")
		expect(task.questions.size() >= 8, "with plenty to ask")
		var keys := 0
		for entry: Dictionary in task.questions:
			if str(entry.get("weight", "")) == "key":
				keys += 1
				expect(entry.has("why") and entry.has("fact"), "%s: every key fact says why it matters" % case_id)
		expect_equal(keys, 4, "four facts that would hurt on the table")
		expect(task.best_points() > 0 and task.limit == 5)
	var main := _main(5)
	main.profile.set_flag("jump_9")
	main._on_day_finished()
	_past_evening(main)
	var lab := main.screen as SkillsLab
	expect(lab != null and lab.drill == "history", "a history drill before Day 6")
	var card := _card(lab)
	expect(card != null)
	if card == null:
		return
	var before := main.profile.total_xp
	card.start_button.pressed.emit()
	expect(lab.view is HistoryView, "Start opens a history")
	expect_equal((lab.view.task as HistoryTask).case_id, Drills.HISTORY_CASES[0], "with the first practice patient")
	expect(lab.play_task(), "it's played")
	expect(main.profile.total_xp > before, "and pays")
	lab.view.done_pressed.emit()
	expect(main.screen is Ward and main.profile.day == 6, "then Day 6 starts")


func test_the_trainer_reads_the_drill_card_aloud() -> void:
	var FakeSpeech := load("res://tests/unit/fake_speech.gd")
	var backend_before: SpeechBackend = Speech.backend
	var settings_before := GameSettings.current
	GameSettings.current = GameSettings.new()
	var fake: SpeechBackend = FakeSpeech.new()
	Speech.use_backend(fake)
	VoiceBank.use({})
	var profile := PlayerProfile.new()
	profile.name = "Kiran Rao"
	var card := add_node(DrillCard.new("instruments", 8, profile)) as DrillCard
	expect_equal(card.trainer, "tom", "Tom runs the instrument drill")
	expect((card.find_child("Opener", true, false) as Label).text.contains(Drills.opener("instruments")), "his opener is on the card")
	expect(card.line > 0 and Speech.speaking(card.line), "and he says it")
	expect(fake.spoken.size() == 1 and str(fake.spoken[0]["text"]).begins_with("Trolley"), "the opener first")
	for frame in 300:
		if fake.spoken.size() >= 2:
			break
		Speech.tick(STEP)
	expect(fake.spoken.size() == 2 and str(fake.spoken[1]["text"]).contains("Liston"), "then the story (Day 8's, not Day 2's)")
	card.skip_button.pressed.emit()
	expect(not Speech.speaking(), "Skip stops the voice")
	Speech.use_backend(backend_before)
	VoiceBank.reset()
	GameSettings.current = settings_before
