extends TestCase
## Stage 6 polish: the settings, the music and sounds, reduced motion, the
## colour-blind-safe monitor and the promotion celebration.

const FOLDER := "user://test_polish"
const PATH := FOLDER + "/settings.json"

var _settings_before: GameSettings = GameSettings.current
var _save_path_before: String = SettingsPanel.save_path
var _fps_before := Engine.max_fps
var _music_before: Music = Music.player


func _fresh_settings() -> GameSettings:
	GameSettings.current = GameSettings.new()
	SettingsPanel.save_path = PATH
	_remove_files()
	return GameSettings.current


func _remove_files() -> void:
	for file: String in ["settings.json", "settings.json.tmp", "save.json", "save.json.tmp"]:
		if FileAccess.file_exists(FOLDER + "/" + file):
			DirAccess.remove_absolute(FOLDER + "/" + file)


func cleanup() -> void:
	super()
	GameSettings.current = _settings_before
	GameSettings.current.apply_audio()
	SettingsPanel.save_path = _save_path_before
	Engine.max_fps = _fps_before
	tree.root.scaling_3d_scale = 1.0
	Music.player = _music_before
	UiKit.inset_override = null
	_remove_files()


# --- Settings -------------------------------------------------------------------

func test_settings_start_sensible_and_survive_a_restart() -> void:
	var settings := _fresh_settings()
	expect_between(settings.music, 0.3, 0.9, "music on but not blaring")
	expect_equal(settings.text_size, 0)
	expect(not settings.reduce_motion and not settings.colour_safe, "comfort options start off")
	settings.set_volume("Music", 0.25)
	settings.set_volume("Voices", 0.0)
	settings.text_size = 2
	settings.reduce_motion = true
	settings.colour_safe = true
	settings.graphics = "saver"
	expect_equal(settings.save_to(PATH), OK)
	var loaded := GameSettings.load_from(PATH)
	expect_equal(loaded.to_dict(), settings.to_dict(), "everything comes back")
	expect(not FileAccess.file_exists(PATH + ".tmp"), "no temporary file left behind")


func test_damaged_settings_fall_back_to_defaults() -> void:
	var repaired := GameSettings.from_dict({"music": 7, "effects": "loud", "text_size": 9, "reduce_motion": "yes",
		"graphics": "ultra"})
	expect_equal(repaired.music, 1.0, "volumes are kept between 0 and 1")
	expect_equal(repaired.effects, GameSettings.new().effects, "nonsense keeps the default")
	expect_equal(repaired.text_size, GameSettings.TEXT_SCALES.size() - 1)
	expect(not repaired.reduce_motion)
	expect_equal(repaired.graphics, "smooth")
	expect_equal(GameSettings.from_dict("not a dictionary").to_dict(), GameSettings.new().to_dict())
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()
	expect_equal(GameSettings.load_from(PATH).to_dict(), GameSettings.new().to_dict(), "a broken file gives defaults")


func test_older_devices_start_on_battery_saver() -> void:
	expect_equal(GameSettings.default_graphics("iPhone10,3"), "saver", "iPhone X")
	expect_equal(GameSettings.default_graphics("iPhone11,8"), "saver", "iPhone XR")
	expect_equal(GameSettings.default_graphics("iPhone12,1"), "smooth", "iPhone 11")
	expect_equal(GameSettings.default_graphics("iPhone16,2"), "smooth")
	expect_equal(GameSettings.default_graphics("iPad7,5"), "saver", "iPad 6th generation")
	expect_equal(GameSettings.default_graphics("iPad13,1"), "smooth")
	expect_equal(GameSettings.default_graphics("GenericDevice"), "smooth")


func test_volumes_set_the_audio_buses_and_zero_mutes() -> void:
	var settings := _fresh_settings()
	settings.set_volume("Music", 0.0)
	settings.set_volume("Effects", 0.5)
	settings.apply_audio()
	for bus: String in GameSettings.BUSES:
		expect(AudioServer.get_bus_index(bus) >= 0, "%s bus exists" % bus)
	expect(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "music at zero is silent")
	var effects := AudioServer.get_bus_index("Effects")
	expect(not AudioServer.is_bus_mute(effects))
	expect_near(AudioServer.get_bus_volume_db(effects), linear_to_db(0.5), 0.01)
	var count := AudioServer.bus_count
	settings.apply_audio()
	# Master, the three volume buses, and Spoken once a recorded line has played.
	var spoken := 1 if AudioServer.get_bus_index(Speech.RECORDED_BUS) >= 0 else 0
	expect_equal(AudioServer.bus_count, 1 + GameSettings.BUSES.size() + spoken, "buses are made once")
	expect_equal(AudioServer.bus_count, count, "applying again adds none")


func test_settings_from_the_title_screen_apply_at_once_and_save() -> void:
	_fresh_settings()
	var title := add_node(TitleScreen.new()) as TitleScreen
	expect(title.settings_button != null, "the title screen has Settings")
	title.settings_button.pressed.emit()
	var panel := title.settings
	expect(panel != null and panel.is_inside_tree(), "the settings open")
	for bus: String in GameSettings.BUSES:
		expect(panel.sliders.has(bus), "a slider for %s" % bus)
	(panel.sliders["Music"] as HSlider).value = 0
	expect_equal(GameSettings.current.music, 0.0, "the slider changes the music volume")
	expect(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "and you hear it at once")
	var button_text := title.new_button.get_theme_font_size("font_size")
	panel.pick("text_size", 2)
	expect_equal(title.new_button.get_theme_font_size("font_size"), UiKit.scaled_text(21),
		"larger text straight away, behind the settings too")
	expect(title.new_button.get_theme_font_size("font_size") > button_text)
	var later := add_node(UiKit.label("Later", 14)) as Label
	expect_equal(later.get_theme_font_size("font_size"), int(UiKit.px(14) * 1.25), "and on screens made later")
	panel.pick("graphics", 1)
	expect_equal(Engine.max_fps, 30, "battery saver runs at 30 frames a second")
	expect_near(tree.root.scaling_3d_scale, GameSettings.SAVER_3D_SCALE, 0.001)
	panel.pick("graphics", 0)
	expect_equal(Engine.max_fps, 60)
	panel.pick("reduce_motion", 1)
	panel.pick("colour_safe", 1)
	expect(GameSettings.current.reduce_motion and GameSettings.current.colour_safe)
	panel.done_button.pressed.emit()
	expect(title.settings == null, "Done closes the settings")
	var saved := GameSettings.load_from(PATH)
	expect_equal(saved.music, 0.0, "and saves them")
	expect_equal(saved.text_size, 2)
	expect(saved.reduce_motion and saved.colour_safe)


func test_settings_from_the_pause_menu_keep_the_sound_switch_in_step() -> void:
	_fresh_settings()
	var profile := PlayerProfile.new()
	profile.name = "Asha Verma"
	var hud := add_node(LobbyHud.new(profile)) as LobbyHud
	var panel := hud.open_settings()
	expect(hud.menu_open(), "the game counts as paused")
	(panel.sliders["Effects"] as HSlider).value = 0
	(panel.sliders["Voices"] as HSlider).value = 0
	panel.close()
	expect(hud.settings_panel() == null, "closing goes back to the menu")
	expect(not profile.sound_on, "no effects and no voices counts as sound off")
	expect(Sfx.play(hud, "knock") == null, "and plays nothing")


func test_an_old_save_with_sound_off_stays_quiet() -> void:
	_fresh_settings()
	var store := SaveStore.new(FOLDER + "/save.json")
	var profile := PlayerProfile.new()
	profile.name = "Asha Verma"
	profile.created = true
	profile.opening_seen = true
	profile.sound_on = false
	profile.set_flag("met_iyer")
	store.save(profile)
	var main := Main.new()
	main.store = store
	main.settings_path = PATH
	add_node(main)
	for bus: String in GameSettings.BUSES:
		expect_equal(GameSettings.current.volume(bus), 0.0, "%s off, as the old switch said" % bus)


# --- Music and sounds -----------------------------------------------------------

func test_every_track_loads_and_loops_except_the_fanfare() -> void:
	for track: String in Music.TRACKS:
		var stream := Music.stream(track) as AudioStreamOggVorbis
		expect(stream != null, "%s exists" % track)
		if stream != null:
			expect(stream.loop, "%s loops" % track)
			expect(stream.get_length() > 20.0, "%s is long enough not to grate" % track)
	var fanfare := Music.stream("fanfare") as AudioStreamOggVorbis
	expect(fanfare != null and not fanfare.loop, "the fanfare plays once")


func test_music_crossfades_between_places() -> void:
	_fresh_settings()
	var music := Music.new()
	add_node(music)
	Music.player = music
	Music.cue("hospital")
	expect_equal(music.track, "hospital")
	Music.cue("hospital")
	var playing := 0
	for child in music.get_children():
		if child is AudioStreamPlayer and (child as AudioStreamPlayer).playing:
			playing += 1
	expect_equal(playing, 1, "asking again does not restart it")
	Music.cue("night")
	expect_equal(music.track, "night", "the night shift has its own music")
	Music.fanfare()
	Music.player = null
	Music.cue("title")
	expect_equal(music.track, "night", "without a player, cues do nothing")


func test_every_world_cues_its_music() -> void:
	_fresh_settings()
	var music := Music.new()
	add_node(music)
	Music.player = music
	var title := add_node(TitleScreen.new()) as TitleScreen
	expect_equal(music.track, "title")
	_nodes.erase(title)
	title.free()
	var doctor := PlayerProfile.new()
	doctor.name = "Asha Verma"
	doctor.created = true
	doctor.opening_seen = true
	add_node(Lobby.new(doctor))
	expect_equal(music.track, "hospital")


func test_new_sounds_exist() -> void:
	for sound: String in ["tap", "chime", "buzz", "beep", "levelup"]:
		expect(sound in Sfx.NAMES, "%s is a known sound" % sound)
		expect(Sfx.stream(sound).data.size() > 1000, "%s has sound" % sound)


func test_effects_volume_zero_plays_no_effects() -> void:
	var settings := _fresh_settings()
	var holder := add_node(Node.new())
	expect(Sfx.play(holder, "tap") != null)
	settings.set_volume("Effects", 0.0)
	expect(Sfx.play(holder, "tap") == null, "effects off")
	settings.set_volume("Voices", 0.0)
	var rig := AvatarRig.new()
	holder.add_child(rig)
	rig.say_syllable("a")
	expect(rig.get_node_or_null("Voice") == null, "voices off")


# --- Comfort --------------------------------------------------------------------

func test_reduce_motion_cuts_cameras_and_skips_confetti() -> void:
	var settings := _fresh_settings()
	expect_near(UiKit.motion_weight(0.1), 0.1, 0.0001, "cameras glide normally")
	var overlay := add_node(StoryOverlay.new()) as StoryOverlay
	overlay.celebrate()
	expect(overlay.confetti() != null, "confetti for a celebration")
	for step in 200:
		overlay.tick(0.05)
	expect(overlay.confetti() == null, "the confetti clears away")
	settings.reduce_motion = true
	expect_near(UiKit.motion_weight(0.1), 1.0, 0.0001, "cameras cut with reduce motion")
	overlay.celebrate()
	expect(overlay.confetti() == null, "no confetti with reduce motion")


func test_the_colour_safe_monitor_swaps_red_and_green_and_adds_arrows() -> void:
	var settings := _fresh_settings()
	var monitor := add_node(VitalsMonitor.new()) as VitalsMonitor
	var normal_alarm := monitor.alarm_colour()
	var normal_hr := monitor._number_colour("hr")
	settings.colour_safe = true
	expect(monitor.alarm_colour() != normal_alarm, "a different alarm colour")
	expect(monitor._number_colour("hr") != normal_hr, "and a different normal colour")
	# Blue and orange: far apart in brightness and hue, unlike red and green.
	expect(absf(VitalsMonitor.SAFE_ALARM.h - VitalsMonitor.SAFE_TRACE.h) > 0.3, "alarm and normal are far apart")
	monitor.status_colour = UiKit.MINT
	expect_equal(monitor.shown_status_colour(), VitalsMonitor.SAFE_TRACE, "a stable patient shows blue, not green")
	monitor.status_colour = VitalsMonitor.ALARM
	expect_equal(monitor.shown_status_colour(), VitalsMonitor.SAFE_ALARM, "an alarm shows orange, not red")
	var sick := Vitals.new()
	sick.hr = 128
	sick.spo2 = 88
	expect_equal(sick.direction("hr"), 1, "a fast heart points up")
	expect_equal(sick.direction("spo2"), -1, "low oxygen points down")
	expect_equal(Vitals.new().direction("hr"), 0, "normal numbers get no arrow")


func test_the_monitor_beeps_with_the_heart() -> void:
	_fresh_settings()
	var monitor := add_node(VitalsMonitor.new()) as VitalsMonitor
	var steady := Vitals.new()
	steady.hr = 60
	monitor.set_vitals(steady)
	for step in 30:
		monitor.tick(0.1)
	expect_equal(monitor.beeps, 0, "quiet unless asked to beep")
	monitor.beeping = true
	for step in 30:
		monitor.tick(0.1)
	expect_between(monitor.beeps, 2, 4, "one beep a second at 60 beats a minute")


func test_promotion_plays_the_fanfare_with_confetti() -> void:
	_fresh_settings()
	var music := Music.new()
	add_node(music)
	Music.player = music
	var doctor := PlayerProfile.new()
	doctor.name = "Asha Verma"
	doctor.day = 8
	doctor.opening_seen = true
	doctor.created = true
	doctor.total_xp = 800
	var ward := add_node(Ward.new(doctor)) as Ward
	ward._promote()
	expect_equal(doctor.rank(), Rank.JUNIOR_RESIDENT)
	expect(ward.overlay.confetti() != null, "confetti for the promotion")
	expect((music.get_node("Fanfare") as AudioStreamPlayer).playing, "and the fanfare")


# --- The notch ------------------------------------------------------------------

func test_nothing_sits_under_the_notch_or_the_home_bar() -> void:
	_fresh_settings()
	expect_equal(UiKit.safe_insets(), Vector3.ZERO, "computers have no notch")
	var room := Vector3(94, 0, 42)
	UiKit.inset_override = room
	var profile := PlayerProfile.new()
	profile.name = "Asha Verma"
	var hud := add_node(LobbyHud.new(profile)) as LobbyHud
	var badge := hud.get_node("Badge") as Control
	expect_near(badge.offset_left, UiKit.px(12) + room.x, 0.01, "the badge clears the notch")
	var talk := add_node(ConversationUi.new()) as ConversationUi
	var choices := talk.get_node("Choices") as Control
	expect_near(choices.offset_right, -UiKit.px(14) - room.x, 0.01, "replies clear the notch on the right")
	expect_near(choices.offset_top, UiKit.px(14) + room.y, 0.01, "and the top")
	var line := talk.get_node("Line") as Control
	expect_near(line.offset_bottom, -UiKit.px(14) - room.z, 0.01)
	var settings := hud.open_settings()
	expect_equal(settings.offset_left, 0.0, "the settings shade still covers the whole screen")
	expect_near((settings.get_node("Card") as Control).offset_left, UiKit.px(30) + room.x, 0.01)
