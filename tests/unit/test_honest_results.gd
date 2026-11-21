extends TestCase
## Honest results (stage 22): a shared 60-second case carries a check code,
## a friend's game can tell a real result from an edited one, and the game
## has no back doors (no networking, no code loaded from outside, no debug
## shortcuts).

const THURSDAY := "2026-11-19"


func _doctor() -> PlayerProfile:
	var doctor := PlayerProfile.new()
	doctor.name = "Asha Verma"
	doctor.day = 12
	doctor.opening_seen = true
	doctor.created = true
	doctor.rank_held = Rank.JUNIOR_RESIDENT
	doctor.total_xp = 3000
	doctor.set_flag("met_iyer")
	return doctor


func _played(right_first: bool) -> PlayerProfile:
	DailyReward.today_override = THURSDAY
	var doctor := _doctor()
	var task := DailyCase.make()
	var guard := 0
	while not task.finished and guard < 20:
		var step := task.current()
		var right := right_first and guard == 0
		task.choose(str(CrisisTask.right_answer(step) if right else AutoPlayer.crisis_wrong_answer(step)))
		task.confirm()
		guard += 1
	DailyCase.record(doctor, task)
	return doctor


func cleanup() -> void:
	DailyReward.today_override = ""
	Share.paster = Callable()
	super.cleanup()


func test_a_shared_result_checks_out() -> void:
	var text := DailyCase.share_text(_played(true))
	var lines := text.split("\n")
	expect(lines[lines.size() - 2].begins_with("Check code: "), "a check code above the last line")
	var verdict := DailyCase.check_shared(text)
	expect(bool(verdict.get("ok", false)), "the real thing checks out: %s" % str(verdict))
	expect_equal(int(verdict.get("number", 0)), DailyCase.case_number(THURSDAY))
	expect_equal(int(verdict.get("right", -1)), 1)
	var pasted := "[21/11/26, 10:42 pm] Rohan: " + text.replace("\n", "\r\n")
	expect(bool(DailyCase.check_shared(pasted).get("ok", false)), "even with WhatsApp's name and time stuck on the front")


func test_an_edited_result_does_not_add_up() -> void:
	var text := DailyCase.share_text(_played(true))
	var lines := text.split("\n")
	var steps := lines[2].split(", ").size()
	var more := text.replace("1 of %d right" % steps, "%d of %d right" % [steps, steps])
	expect(more != text, "the count was changed")
	expect_equal(str(DailyCase.check_shared(more).get("why", "")), "edited", "more right than really")
	var seconds := lines[1].get_slice(" right in ", 1)
	var faster := text.replace(" right in " + seconds, " right in " + ("59s" if seconds != "59s" else "58s"))
	expect_equal(str(DailyCase.check_shared(faster).get("why", "")), "edited", "another time")
	var words := PackedStringArray()
	for index in steps:
		words.append("right")
	var row := ", ".join(words)
	lines[2] = row.substr(0, 1).to_upper() + row.substr(1)
	lines[1] = lines[1].replace("1 of", "%d of" % steps)
	expect_equal(str(DailyCase.check_shared("\n".join(lines)).get("why", "")), "edited", "every mark changed to right")


func test_something_that_isnt_a_result_says_so() -> void:
	expect_equal(str(DailyCase.check_shared("").get("why", "")), "no_result")
	expect_equal(str(DailyCase.check_shared("Good morning! Chai at 5?").get("why", "")), "no_result")
	var text := DailyCase.share_text(_played(false))
	var lines := Array(text.split("\n")).filter(func(line: String) -> bool: return not line.begins_with("Check code"))
	expect_equal(str(DailyCase.check_shared("\n".join(lines)).get("why", "")), "no_result", "no code, nothing to check")


func test_the_today_page_checks_a_friends_result() -> void:
	var friend := DailyCase.share_text(_played(true))
	var doctor := _played(false)
	var map := add_node(CareerMap.new(doctor, "today")) as CareerMap
	var button := map.find_child("CheckFriend", true, false) as Button
	expect(button != null, "a button to check a friend's result")
	var line := map.find_child("CheckLine", true, false) as Label
	Share.paster = func() -> String: return friend
	button.pressed.emit()
	expect(line.text.begins_with("That one's real"), line.text)
	Share.paster = func() -> String: return friend.replace("in ", "in 1")
	button.pressed.emit()
	expect(line.text.begins_with("That doesn't add up"), line.text)
	Share.paster = func() -> String: return "hello"
	button.pressed.emit()
	expect(line.text.begins_with("Nothing to check"), line.text)


## The game's own code: what it may and may not do.
func _scripts(folder: String, into: Array[String]) -> void:
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			into.append(folder.path_join(file))
	for sub in DirAccess.get_directories_at(folder):
		_scripts(folder.path_join(sub), into)


func test_the_game_has_no_back_doors() -> void:
	var scripts: Array[String] = []
	_scripts("res://game", scripts)
	expect(scripts.size() > 50, "the game's scripts are found: %d" % scripts.size())
	var banned := ["HTTPRequest", "HTTPClient", "StreamPeer", "PacketPeer", "WebSocket", "TCPServer", "UDPServer", "ENet",
		"MultiplayerPeer", "WebRTC", "OS.execute", "OS.create_process", "JavaScriptBridge", "str_to_var", "bytes_to_var",
		"Expression.new", "InputEventKey", "is_key_pressed", "OS.is_debug_build"]
	for path in scripts:
		var text := FileAccess.get_file_as_string(path)
		for word: String in banned:
			expect(not text.contains(word), "%s uses %s" % [path, word])
		if text.contains("OS.shell_open"):
			expect(path.ends_with("core/share.gd"), "%s opens links (only sharing may, and only WhatsApp)" % path)
		var at := text.find("load(\"user://")
		expect(at < 0, "%s loads code or assets from the save folder" % path)
	var share := FileAccess.get_file_as_string("res://game/core/share.gd")
	expect(share.count("OS.shell_open") == 1 and share.contains("https://wa.me/"), "the one link is WhatsApp's")
