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
