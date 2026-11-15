extends TestCase
## Settings > About: the privacy policy (the same, word for word, as the
## copy on GitHub for the App Store) and the acknowledgements, with every
## part of Godot and every licence the game comes with.

const FOLDER := "user://test_about"

var _settings_before: GameSettings = GameSettings.current
var _save_path_before: String = SettingsPanel.save_path


func cleanup() -> void:
	super()
	GameSettings.current = _settings_before
	SettingsPanel.save_path = _save_path_before
	for file: String in ["settings.json", "settings.json.tmp"]:
		if FileAccess.file_exists(FOLDER + "/" + file):
			DirAccess.remove_absolute(FOLDER + "/" + file)


func _panel() -> SettingsPanel:
	GameSettings.current = GameSettings.new()
	SettingsPanel.save_path = FOLDER + "/settings.json"
	return add_node(SettingsPanel.new()) as SettingsPanel


func test_the_privacy_policy_promises_what_the_game_does() -> void:
	var words := AboutTexts.privacy()
	for promise: String in ["collects nothing about you", "no ads", "no analytics", "no tracking",
			"never sends anything over the internet", "Deleting the game deletes all of it", "never uses the microphone",
			"Reminders are off until you say yes", "Nothing goes to a server", "children included", AboutTexts.CONTACT]:
		expect(words.contains(promise), "the policy says: %s" % promise)
	var everything := ""
	for path: String in ["res://game", "res://addons"]:
		everything += _all_code(path)
	for never: String in ["HTTPRequest", "HTTPClient", "StreamPeerTCP", "WebSocketPeer", "PacketPeerUDP"]:
		expect(not everything.contains(never), "and the game really has no %s" % never)


func test_the_copy_on_github_says_the_same_word_for_word() -> void:
	var copy := FileAccess.get_file_as_string("res://docs/PRIVACY.md")
	expect(not copy.is_empty(), "docs/PRIVACY.md exists, for the App Store")
	expect(copy.contains(AboutTexts.PRIVACY_UPDATED), "with the same date")
	for section: Array in AboutTexts.PRIVACY:
		expect(copy.contains("## " + str(section[0])), "the heading %s" % section[0])
		for paragraph: String in section[1]:
			expect(copy.contains(paragraph), "the paragraph starting \"%s\"" % paragraph.left(40))


func test_the_acknowledgements_credit_everything_the_game_is_made_with() -> void:
	var thanks := AboutTexts.thanks_page(0)
	for credit: String in ["Godot Engine", "Juan Linietsky", "Kokoro", "hexgrad", "kokoro-onnx", "Fredoka", "Nunito",
			"SIL Open Font License", "night shift", "not medical advice", "Permission is hereby granted"]:
		expect(thanks.contains(credit), "the thanks page mentions %s" % credit)
	var parts := AboutTexts.godot_parts()
	for component: Dictionary in Engine.get_copyright_info():
		expect(parts.contains(AboutTexts.escape(str(component["name"]))), "Godot's part %s is listed" % component["name"])
	var licences := AboutTexts.licence_texts()
	for licence: String in AboutTexts.NAMED_LICENCES:
		expect(Engine.get_license_info().has(licence), "Godot carries the %s text" % licence)
		expect(licences.contains(AboutTexts.escape(str(Engine.get_license_info()[licence]).strip_edges().left(200))),
			"and the licence page prints it: %s" % licence)


func test_about_opens_from_the_settings_and_reads_properly() -> void:
	var panel := _panel()
	var privacy := panel.open_reader("Privacy")
	expect(privacy.is_inside_tree() and privacy.get_parent() == panel, "the privacy policy opens over the settings")
	expect(privacy.page_text().contains("collects nothing about you"), "and shows the policy")
	expect(not privacy.page_text().contains("[b]"), "formatted, not raw codes")
	privacy.done_button.pressed.emit()
	expect(panel.reader == null, "Done closes it, back to the settings")
	var thanks := panel.open_reader("Acknowledgements")
	expect_equal(thanks.page_chips.size(), AboutTexts.THANKS_PAGES.size(), "a chip for each page")
	expect(thanks.page_text().contains("Kokoro"), "thanks first")
	thanks.show_page(1)
	expect(thanks.page_text().contains("FreeType"), "then Godot's parts")
	thanks.show_page(2)
	var licences := thanks.page_text()
	expect(licences.contains("Apache License") and licences.contains("Open Font License (OFL)"), "then the licence texts")
	expect(licences.contains("[yyyy]"), "square brackets in a licence print as written")
	thanks.close()


func test_bigger_text_makes_the_reading_bigger() -> void:
	var panel := _panel()
	var normal := panel.open_reader("Privacy").text.get_theme_font_size("normal_font_size")
	panel.reader.close()
	GameSettings.current.text_size = 2
	var bigger := panel.open_reader("Privacy").text.get_theme_font_size("normal_font_size")
	expect(bigger > normal, "Larger text reads larger (%d, %d)" % [normal, bigger])


static func _all_code(folder: String) -> String:
	var found := ""
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(".gd") or file.ends_with(".cpp"):
			found += FileAccess.get_file_as_string(folder.path_join(file))
	for sub: String in DirAccess.get_directories_at(folder):
		found += _all_code(folder.path_join(sub))
	return found
