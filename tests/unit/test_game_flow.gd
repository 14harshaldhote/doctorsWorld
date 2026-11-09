extends TestCase
## The screens in order: title, name, look, the opening story, the
## hospital, and back again.

const SAVE := "user://test_flow/save.json"


func _main() -> Main:
	_clear()
	var main := Main.new()
	main.store = SaveStore.new(SAVE)
	add_node(main)
	return main


func _clear() -> void:
	for file: String in ["save.json", "save.json.tmp"]:
		var path := "user://test_flow/" + file
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func test_a_fresh_install_shows_the_title_without_continue() -> void:
	var main := _main()
	var title := main.screen as TitleScreen
	expect(title != null, "title screen first")
	expect(title.continue_button == null, "nothing to continue yet")


func test_new_career_runs_name_then_look_then_the_opening_then_hospital() -> void:
	var main := _main()
	(main.screen as TitleScreen).new_career_pressed.emit()
	var naming := main.screen as NameScreen
	expect(naming != null, "name screen after New career")
	naming.name_field.text = "  Kiran   Rao "
	naming._on_name_changed(naming.name_field.text)
	naming._on_form_picked("first")
	naming._on_next()
	var creator := main.screen as AvatarCreator
	expect(creator != null, "avatar creator after the name")
	expect_equal(main.profile.name, "Kiran Rao", "name tidied")
	creator._pick("hair_style", 4)
	creator._pick("glasses", 2)
	creator._on_done()
	var opening := main.screen as Opening
	expect(opening != null, "the opening story after the look")
	opening.update(0.5)
	opening.skip()
	var lobby := main.screen as Lobby
	expect(lobby != null, "hospital after the opening")
	expect(main.profile.opening_seen, "the opening is not shown twice")
	expect(lobby.arrival and lobby.story.is_playing(), "Dr. Iyer meets the new doctor at the door")
	var saved := SaveStore.new(SAVE).load_or_start()
	expect_equal(saved["outcome"], SaveStore.Outcome.LOADED, "a save was written")
	var profile: PlayerProfile = saved["profile"]
	expect_equal(profile.name, "Kiran Rao")
	expect_equal(profile.address_form, "first")
	expect_equal(profile.avatar.hair_style, 4)
	expect_equal(profile.avatar.glasses, 2)
	expect(profile.created, "the career has started")
	expect(profile.opening_seen, "the save remembers the opening was seen")
	_clear()


func test_an_empty_name_cannot_go_on() -> void:
	var main := _main()
	(main.screen as TitleScreen).new_career_pressed.emit()
	var naming := main.screen as NameScreen
	naming.name_field.text = "   "
	naming._on_name_changed(naming.name_field.text)
	expect(naming.next_button.disabled, "Next is off with no name")
	naming._on_next()
	expect(main.screen == naming, "still on the name screen")


func test_continue_and_the_pause_menu() -> void:
	var main := _main()
	main.profile.name = "Kiran Rao"
	main.profile.created = true
	main.profile.opening_seen = true
	main.profile.set_flag("met_iyer")
	main._save()
	main.show_title()
	var title := main.screen as TitleScreen
	expect(title.continue_button != null, "continue offered once saved")
	title.continue_pressed.emit()
	expect(main.screen is Lobby, "continue goes to the hospital")
	expect(not (main.screen as Lobby).story.is_playing(), "no second welcome from Dr. Iyer")
	(main.screen as Lobby).menu_choice.emit("look")
	expect(main.screen is AvatarCreator, "change my look opens the creator")
	(main.screen as AvatarCreator).back_pressed.emit()
	expect(main.screen is Lobby, "back from editing returns to the hospital")
	(main.screen as Lobby).menu_choice.emit("title")
	expect(main.screen is TitleScreen, "title screen from the menu")
	_clear()


func test_a_career_that_missed_the_opening_sees_it_on_continue() -> void:
	var main := _main()
	main.profile.name = "Kiran Rao"
	main.profile.created = true
	main._save()
	main.show_title()
	(main.screen as TitleScreen).continue_pressed.emit()
	expect(main.screen is Opening, "the opening plays before the hospital")
	(main.screen as Opening).skip()
	expect(main.screen is Lobby, "then the hospital")
	_clear()


func test_the_end_of_day_one_leads_to_the_skills_lab_on_day_two() -> void:
	var main := _main()
	main.profile.name = "Kiran Rao"
	main.profile.created = true
	main.profile.opening_seen = true
	for flag in ["met_iyer", "day1_grace", "day1_patient"]:
		main.profile.set_flag(flag)
	main.show_hospital()
	var lobby := main.screen as Lobby
	expect(lobby != null, "Day 1 is in the lobby")
	lobby._start_talk("iyer")
	for frame in 4000:
		if not lobby.story.is_playing():
			break
		if lobby.talk_ui.is_choosing():
			lobby.story.choose(0)
		elif not lobby.story.is_busy():
			lobby.talk_ui.tap()
		lobby._process(1.0 / 30.0)
	expect(main.screen == lobby, "a moment to take in the goodbye")
	for frame in 120:
		if main.screen != lobby:
			break
		lobby._process(1.0 / 30.0)
	var lab := main.screen as SkillsLab
	expect(lab != null, "then Day 2 starts in the skills lab")
	expect_equal(main.profile.day, 2)
	expect_equal(main.profile.clock_text(), "07:00", "at seven sharp")
	expect(lab != null and lab.mode == "story", "with a welcome")
	var saved: PlayerProfile = SaveStore.new(SAVE).load_or_start()["profile"]
	expect_equal(saved.day, 2, "the new day is saved")
	main.show_title()
	(main.screen as TitleScreen).continue_pressed.emit()
	expect(main.screen is SkillsLab, "continue returns to the lab")
	_clear()


func test_a_save_that_finished_day_one_before_the_lab_moves_on() -> void:
	var main := _main()
	main.profile.name = "Kiran Rao"
	main.profile.created = true
	main.profile.opening_seen = true
	for flag in ["met_iyer", "day1_grace", "day1_patient", "day1_iyer"]:
		main.profile.set_flag(flag)
	main.show_hospital()
	expect(main.screen is SkillsLab, "straight to Day 2")
	expect_equal(main.profile.day, 2)
	_clear()


func test_going_home_after_training_leads_to_theatre_day_and_then_back_to_the_lab() -> void:
	var main := _main()
	main.profile.name = "Kiran Rao"
	main.profile.created = true
	main.profile.opening_seen = true
	main.profile.day = 2
	for flag in ["met_iyer", "day1_iyer", "lab_welcome", "training_done"]:
		main.profile.set_flag(flag)
	main.show_hospital()
	var lab := main.screen as SkillsLab
	expect(lab != null, "Day 2 is the lab")
	expect(lab.can_go_home(), "after training the doctor may go home")
	lab.go_home()
	for frame in 900:
		if main.screen != lab:
			break
		lab.update(1.0 / 30.0)
	var theatre := main.screen as Theatre
	expect(theatre != null, "the next morning is theatre day")
	expect_equal(main.profile.day, 3)
	main.show_title()
	(main.screen as TitleScreen).continue_pressed.emit()
	expect(main.screen is Theatre, "continue returns to theatre day")
	theatre = main.screen as Theatre
	var good := AutoPlayer.new()
	theatre.play_until(func() -> bool: return main.screen != theatre,
		Theatre.pick_tones(["Ask Rohit", "Allergies", "Explain", "Be straight", "Hold firm"]), good, 900.0)
	var after := main.screen as SkillsLab
	expect(after != null, "after the operation the doctor practises in the lab")
	expect_equal(main.profile.day, 4)
	expect(main.profile.has_flag("op_rohit_done"), "the operation is remembered")
	expect(after != null and after.hud.pager_text().contains("Rohit"), "the pager says how Rohit is doing")
	_clear()
