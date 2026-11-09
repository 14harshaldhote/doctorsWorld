extends TestCase
## The avatar look, the player profile and safe saving.

var _folder := ""


func _temp_folder() -> String:
	if _folder.is_empty():
		_folder = "user://test-saves-%d-%d" % [Time.get_ticks_usec(), randi()]
		DirAccess.make_dir_recursive_absolute(_folder)
	return _folder


func _remove_folder() -> void:
	if _folder.is_empty():
		return
	for file in DirAccess.get_files_at(_folder):
		DirAccess.remove_absolute(_folder.path_join(file))
	DirAccess.remove_absolute(_folder)


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_every_field_has_the_planned_number_of_choices() -> void:
	expect_equal(AvatarConfig.choice_count("skin"), 10)
	expect_equal(AvatarConfig.choice_count("body"), 3)
	expect_equal(AvatarConfig.choice_count("face"), 6)
	expect_equal(AvatarConfig.choice_count("eyes"), 8)
	expect_equal(AvatarConfig.choice_count("brows"), 6)
	expect_equal(AvatarConfig.choice_count("nose"), 5)
	expect_equal(AvatarConfig.choice_count("hair_style"), 12)
	expect_equal(AvatarConfig.choice_count("hair_colour"), 10)
	expect_equal(AvatarConfig.choice_count("facial_hair"), 6)
	expect_equal(AvatarConfig.choice_count("glasses"), 6)
	expect_equal(AvatarConfig.choice_count("scrubs"), 8)
	expect_equal(AvatarConfig.HAIR_COLOUR_NAMES.size(), AvatarConfig.HAIR_COLOURS.size())
	expect_equal(AvatarConfig.SCRUB_NAMES.size(), AvatarConfig.SCRUBS.size())


func test_look_round_trips_through_a_dictionary() -> void:
	var look := AvatarConfig.random(SeededRandom.new(77))
	var back := AvatarConfig.from_dict(look.to_dict())
	expect(look.equals(back), "a saved look should load back the same")


func test_damaged_look_falls_back_to_defaults_field_by_field() -> void:
	var defaults := AvatarConfig.new()
	var repaired := AvatarConfig.from_dict({"skin": 99, "hair_style": -1, "eyes": "blue", "scrubs": 3, "coat": "yes", "glasses": 2.5})
	expect_equal(repaired.skin, defaults.skin)
	expect_equal(repaired.hair_style, defaults.hair_style)
	expect_equal(repaired.eyes, defaults.eyes)
	expect_equal(repaired.glasses, defaults.glasses)
	expect_equal(repaired.coat, defaults.coat)
	expect_equal(repaired.scrubs, 3, "valid fields are kept")
	expect(AvatarConfig.from_dict(null).equals(defaults))


func test_random_looks_are_repeatable_and_varied() -> void:
	expect(AvatarConfig.random(SeededRandom.new(4)).equals(AvatarConfig.random(SeededRandom.new(4))))
	var styles := {}
	var rng := SeededRandom.new(9)
	for i in 120:
		styles[AvatarConfig.random(rng).hair_style] = true
	expect_equal(styles.size(), 12, "every hair style should come up")


func test_names_are_cleaned_and_addressed_properly() -> void:
	var profile := PlayerProfile.new()
	profile.name = "   Asha    Verma  "
	expect_equal(profile.name, "Asha Verma")
	expect_equal(profile.full_title(), "Dr. Asha Verma")
	expect_equal(profile.called(), "Dr. Verma")
	profile.address_form = "first"
	expect_equal(profile.called(), "Dr. Asha")
	profile.name = "Ngozi"
	expect_equal(profile.called(), "Dr. Ngozi", "one name works either way")
	profile.name = "Aleksandra Konstantinopolska-Wiśniewska"
	expect(profile.name.length() <= PlayerProfile.MAX_NAME_LENGTH, "long names are cut")
	profile.name = "     "
	expect_equal(profile.full_title(), "Doctor")
	expect_equal(profile.called(), "Doctor")


func test_profile_level_and_rank_come_from_xp() -> void:
	var profile := PlayerProfile.new()
	expect_equal(profile.level(), 1)
	expect_equal(profile.rank(), Rank.INTERN)
	profile.total_xp = 2000
	expect_equal(profile.rank(), Rank.JUNIOR_RESIDENT)


func test_save_text_is_stable_and_versioned() -> void:
	var profile := PlayerProfile.new()
	profile.name = "Kofi Mensah"
	profile.avatar = AvatarConfig.random(SeededRandom.new(1))
	var text := SaveStore.encode(profile)
	expect_equal(text, SaveStore.encode(PlayerProfile.from_dict(profile.to_dict())), "byte-for-byte stable")
	expect(text.contains("\"version\": 2"))
	var decoded := SaveStore.decode(text)
	expect(decoded.has("profile"))
	expect_equal((decoded["profile"] as PlayerProfile).to_dict(), profile.to_dict())


func test_decode_refuses_damaged_and_newer_saves() -> void:
	expect_equal(SaveStore.decode("{not json")["error"], "corrupt")
	expect_equal(SaveStore.decode("[1, 2]")["error"], "corrupt")
	expect_equal(SaveStore.decode("{\"profile\": {}}")["error"], "corrupt")
	expect_equal(SaveStore.decode("{\"version\": 0, \"profile\": {}}")["error"], "corrupt")
	expect_equal(SaveStore.decode("{\"version\": 3, \"profile\": {}}")["error"], "newer_version")


func test_story_progress_is_saved_and_repaired() -> void:
	var profile := PlayerProfile.new()
	expect_equal(profile.trust("iyer", 50), 50, "strangers start at their default")
	expect_equal(profile.change_trust("iyer", 8, 50), 58)
	expect_equal(profile.change_trust("iyer", 90, 50), 100, "trust tops out at 100")
	expect_equal(profile.change_trust("grace", -80, 45), 0, "and bottoms out at 0")
	profile.set_flag("honest_with_iyer")
	profile.opening_seen = true
	profile.sound_on = false
	profile.pass_minutes(25)
	expect_equal(profile.clock_text(), "07:25")
	var back := PlayerProfile.from_dict(profile.to_dict())
	expect_equal(back.trust("iyer"), 100)
	expect_equal(back.trust("grace"), 0)
	expect(back.has_flag("honest_with_iyer"))
	expect(not back.has_flag("corrected_iyer"))
	expect(back.opening_seen)
	expect(not back.sound_on)
	expect_equal(back.minutes, PlayerProfile.DAY_START + 25)
	var damaged := PlayerProfile.from_dict({"relationships": {"iyer": 400, "x": "lots"}, "flags": {"a": true, "b": "yes"},
		"minutes": -5, "opening_seen": "yes"})
	expect_equal(damaged.trust("iyer"), 100, "out-of-range trust is clamped")
	expect(not damaged.relationships.has("x"), "nonsense trust is dropped")
	expect(damaged.has_flag("a") and not damaged.has_flag("b"))
	expect_equal(damaged.minutes, PlayerProfile.DAY_START)
	expect(not damaged.opening_seen)


func test_version_1_saves_still_load() -> void:
	var decoded := SaveStore.decode("{\"version\": 1, \"profile\": {\"name\": \"Mei Lin\", \"created\": true}}")
	var profile: PlayerProfile = decoded["profile"]
	expect_equal(profile.name, "Mei Lin")
	expect(not profile.opening_seen, "players from stage 1 see the new opening")
	expect(profile.sound_on)


func test_fresh_start_then_save_then_load() -> void:
	var store := SaveStore.new(_temp_folder().path_join("save.json"))
	var first := store.load_or_start()
	expect_equal(first["outcome"], SaveStore.Outcome.FRESH)
	expect(first["can_save"])
	var profile: PlayerProfile = first["profile"]
	profile.name = "Mei Lin"
	profile.created = true
	expect_equal(store.save(profile), OK)
	expect(not FileAccess.file_exists(store.path + ".tmp"), "the temporary file is renamed away")
	var second := store.load_or_start()
	expect_equal(second["outcome"], SaveStore.Outcome.LOADED)
	expect_equal((second["profile"] as PlayerProfile).name, "Mei Lin")
	_remove_folder()


func test_unreadable_saves_are_set_aside_with_free_names() -> void:
	var folder := _temp_folder()
	var store := SaveStore.new(folder.path_join("save.json"))
	_write(store.path, "this is not a save")
	var first := store.load_or_start()
	expect_equal(first["outcome"], SaveStore.Outcome.SET_ASIDE)
	expect_equal(first["reason"], "corrupt")
	expect_equal(String(first["backup"]).get_file(), "save.unreadable.json")
	expect(not FileAccess.file_exists(store.path), "the broken file is moved, not copied")
	_write(store.path, "{\"version\": 9, \"profile\": {}}")
	var second := store.load_or_start()
	expect_equal(second["reason"], "newer_version")
	expect_equal(String(second["backup"]).get_file(), "save.unreadable-2.json")
	expect(FileAccess.file_exists(folder.path_join("save.unreadable.json")), "the first backup is untouched")
	_remove_folder()
