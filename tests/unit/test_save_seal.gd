extends TestCase
## Sealed saves (stage 22): an edited save is caught and set aside, the last
## good backup takes its place, old unsealed saves are taken once, and no
## loaded career has numbers it couldn't have earned.

var _folders: Array[String] = []


func _folder() -> String:
	var folder := "user://test-seal-%d-%d" % [Time.get_ticks_usec(), randi()]
	DirAccess.make_dir_recursive_absolute(folder)
	_folders.append(folder)
	return folder


func cleanup() -> void:
	super.cleanup()
	for folder in _folders:
		var dir := DirAccess.open(folder)
		if dir == null:
			continue
		dir.include_hidden = true
		for file in dir.get_files():
			DirAccess.remove_absolute(folder.path_join(file))
		DirAccess.remove_absolute(folder)
	_folders.clear()


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _doctor(xp: int, day: int = 6) -> PlayerProfile:
	var doctor := PlayerProfile.new()
	doctor.name = "Mei Lin"
	doctor.created = true
	doctor.day = day
	doctor.total_xp = xp
	return doctor


## The save's text with its experience changed, the seal left as it was.
func _edited(path: String, xp: int) -> String:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	(data["profile"] as Dictionary)["total_xp"] = xp
	return JSON.stringify(data, "\t", true)


func test_a_save_is_sealed_and_loads_back() -> void:
	var store := SaveStore.new(_folder().path_join("save.json"))
	expect_equal(store.save(_doctor(1234)), OK)
	var text := FileAccess.get_file_as_string(store.path)
	expect(text.contains("\"version\": 3") and text.contains("\"seal\""), "version 3, with a seal")
	var loaded := SaveStore.new(store.path).load_or_start()
	expect_equal(loaded["outcome"], SaveStore.Outcome.LOADED)
	expect_equal((loaded["profile"] as PlayerProfile).total_xp, 1234)
	expect_equal(Main.notice_for(loaded), "", "nothing to say")


func test_an_edited_save_is_set_aside_and_the_last_honest_one_comes_back() -> void:
	var folder := _folder()
	var store := SaveStore.new(folder.path_join("save.json"))
	store.save(_doctor(500))
	store.save(_doctor(700))
	_write(store.path, _edited(store.path, 90000))
	var loaded := SaveStore.new(store.path).load_or_start()
	expect_equal(loaded["reason"], "tampered", "the edit is caught")
	expect_equal(loaded["outcome"], SaveStore.Outcome.RESTORED)
	expect_equal((loaded["profile"] as PlayerProfile).total_xp, 500, "the backup before it")
	expect_equal(String(loaded["backup"]).get_file(), "save.tampered.json", "the edited one is kept, aside")
	expect(FileAccess.file_exists(folder.path_join("save.tampered.json")))
	expect(Main.notice_for(loaded).contains("edited outside the game"), "and the player is told")


func test_an_edit_with_no_backup_starts_a_new_career() -> void:
	var store := SaveStore.new(_folder().path_join("save.json"))
	store.save(_doctor(500))
	_write(store.path, _edited(store.path, 90000))
	var loaded := SaveStore.new(store.path).load_or_start()
	expect_equal(loaded["outcome"], SaveStore.Outcome.SET_ASIDE)
	expect(not (loaded["profile"] as PlayerProfile).created, "a new career")
	expect(Main.notice_for(loaded).contains("new career"))


func test_taking_the_seal_off_does_not_help() -> void:
	var store := SaveStore.new(_folder().path_join("save.json"))
	store.save(_doctor(500))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store.path))
	data.erase("seal")
	data["version"] = 2
	(data["profile"] as Dictionary)["total_xp"] = 30000
	_write(store.path, JSON.stringify(data))
	var loaded := SaveStore.new(store.path).load_or_start()
	expect_equal(loaded["reason"], "tampered", "an unsealed save after a sealed one")


func test_an_old_unsealed_save_is_taken_once() -> void:
	var store := SaveStore.new(_folder().path_join("save.json"))
	_write(store.path, JSON.stringify({"version": 2, "profile": _doctor(2500).to_dict()}))
	var first := store.load_or_start()
	expect_equal(first["outcome"], SaveStore.Outcome.LOADED, "a save from before seals still loads")
	expect_equal((first["profile"] as PlayerProfile).total_xp, 2500)
	store.save(first["profile"])
	expect(FileAccess.get_file_as_string(store.path).contains("\"seal\""), "and is sealed from then on")
	expect_equal(SaveStore.new(store.path).load_or_start()["outcome"], SaveStore.Outcome.LOADED)


func test_a_save_from_another_install_is_not_taken() -> void:
	var store := SaveStore.new(_folder().path_join("save.json"))
	store.save(_doctor(1500))
	var other := SaveStore.new(_folder().path_join("save.json"))
	_write(other.path, FileAccess.get_file_as_string(store.path))
	var loaded := other.load_or_start()
	expect_equal(loaded["reason"], "tampered", "someone else's maxed-out save, dropped in")


func test_the_last_three_saves_are_kept() -> void:
	var folder := _folder()
	var store := SaveStore.new(folder.path_join("save.json"))
	for xp: int in [100, 200, 300, 400, 500]:
		store.save(_doctor(xp))
	var backups := store.backup_paths()
	expect_equal(backups.size(), SaveStore.BACKUPS)
	var expected := [400, 300, 200]
	for index in backups.size():
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(backups[index]))
		expect_equal(int((data["profile"] as Dictionary)["total_xp"]), expected[index], "backup %d" % (index + 1))
	expect(not FileAccess.file_exists(folder.path_join("save.bak4.json")), "no more than three")
	expect(not FileAccess.file_exists(store.path + ".tmp"), "nothing left over")


func test_a_damaged_save_falls_back_to_a_backup() -> void:
	var store := SaveStore.new(_folder().path_join("save.json"))
	store.save(_doctor(800))
	store.save(_doctor(900))
	_write(store.path, "{\"version\": 3, \"profile\": {\"name\": ")
	var loaded := SaveStore.new(store.path).load_or_start()
	expect_equal(loaded["reason"], "corrupt")
	expect_equal(loaded["outcome"], SaveStore.Outcome.RESTORED)
	expect_equal((loaded["profile"] as PlayerProfile).total_xp, 800)
	expect(Main.notice_for(loaded).contains("damaged"))


func test_a_crash_between_renames_loses_nothing() -> void:
	var store := SaveStore.new(_folder().path_join("save.json"))
	store.save(_doctor(800))
	store.save(_doctor(900))
	# As if the game died after the old save became a backup but before the
	# new one was renamed into place.
	DirAccess.rename_absolute(store.path, store.path + ".tmp")
	var loaded := SaveStore.new(store.path).load_or_start()
	expect_equal(loaded["outcome"], SaveStore.Outcome.LOADED, "the finished write is found")
	expect_equal((loaded["profile"] as PlayerProfile).total_xp, 900, "the newest save, not the backup")
	expect(FileAccess.file_exists(store.path), "and put where it belongs")
	DirAccess.remove_absolute(store.path)
	expect_equal(SaveStore.new(store.path).load_or_start()["outcome"], SaveStore.Outcome.FRESH,
		"a save deleted on purpose stays deleted")


func test_numbers_no_career_could_reach_are_brought_back() -> void:
	var store := SaveStore.new(_folder().path_join("save.json"))
	_write(store.path, JSON.stringify({"version": 2, "profile": _doctor(999999, 5).to_dict()}))
	var profile: PlayerProfile = store.load_or_start()["profile"]
	expect_equal(profile.total_xp, SaveStore.XP_ALLOWANCE + SaveStore.XP_PER_DAY_ALLOWANCE * 5)
	var honest := _doctor(LevelCurve.total_xp_to_reach(Rank.FIRST_LEVELS[Rank.CHIEF]) + 3000, 27)
	expect_equal(SaveStore.make_plausible(honest), "", "a real Chief's experience is left alone")


func test_the_title_says_what_happened_to_the_save() -> void:
	var title := add_node(TitleScreen.new(_doctor(500), "Your save was damaged, so you're back at your last good one.")) \
		as TitleScreen
	var line := title.find_child("SaveNotice", true, false) as Label
	expect(line != null and line.text.contains("damaged"), "a line under the buttons")
	var plain := add_node(TitleScreen.new(_doctor(500))) as TitleScreen
	expect(plain.find_child("SaveNotice", true, false) == null, "and none when all is well")


func test_an_edit_costs_almost_nothing_to_check() -> void:
	var store := SaveStore.new(_folder().path_join("save.json"))
	var doctor := _doctor(5000, 20)
	for index in 200:
		doctor.set_flag("flag_%d" % index)
		doctor.set_count("count_%d" % index, index)
	var started := Time.get_ticks_usec()
	store.save(doctor)
	var loaded := SaveStore.new(store.path).load_or_start()
	var spent := (Time.get_ticks_usec() - started) / 1000.0
	expect_equal(loaded["outcome"], SaveStore.Outcome.LOADED)
	expect(spent < 150.0, "saving and loading a big career takes %.1f ms" % spent)
