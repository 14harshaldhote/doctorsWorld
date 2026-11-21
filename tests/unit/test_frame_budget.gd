extends TestCase
## Resource rules (stage 22): the game asks for as few frames as the screen
## needs (30 on still screens, 5 while another app is in front) and the
## hospital's clock waits while it's away.


func cleanup() -> void:
	super.cleanup()
	FrameBudget.reset()


func test_the_rate_follows_the_setting_the_screen_and_the_focus() -> void:
	FrameBudget.reset()
	expect_equal(FrameBudget.target(), 60, "smooth by default")
	FrameBudget.set_base(30)
	expect_equal(FrameBudget.target(), 30, "battery saver")
	FrameBudget.set_base(60)
	FrameBudget.calm(true)
	expect_equal(FrameBudget.target(), FrameBudget.MENU_FPS, "a still screen needs fewer")
	FrameBudget.calm(true)
	FrameBudget.calm(false)
	expect_equal(FrameBudget.target(), FrameBudget.MENU_FPS, "still one open")
	FrameBudget.calm(false)
	FrameBudget.calm(false)
	expect_equal(FrameBudget.calm_screens(), 0, "never below none")
	expect_equal(FrameBudget.target(), 60)
	FrameBudget.set_away(true)
	expect_equal(FrameBudget.target(), FrameBudget.AWAY_FPS, "almost nothing while away")
	expect_equal(Engine.max_fps, FrameBudget.AWAY_FPS, "and the engine is told")
	FrameBudget.set_away(false)
	expect_equal(Engine.max_fps, 60, "back to full when it's in front again")


func test_still_screens_ask_for_fewer_frames_while_they_show() -> void:
	FrameBudget.reset()
	var title := add_node(TitleScreen.new()) as TitleScreen
	expect_equal(FrameBudget.target(), FrameBudget.MENU_FPS, "the title")
	title.open_settings()
	expect_equal(FrameBudget.calm_screens(), 2, "settings over it")
	title.get_parent().remove_child(title)
	title.free()
	expect_equal(FrameBudget.calm_screens(), 0, "gone, and full speed again")
	var settings := GameSettings.new()
	settings.graphics = "saver"
	settings.apply_display(tree.root)
	expect_equal(FrameBudget.base, 30, "Battery saver sets the base")
	settings.graphics = "smooth"
	settings.apply_display(tree.root)
	expect_equal(FrameBudget.base, 60)


func test_the_hospital_clock_waits_while_the_game_is_away() -> void:
	FrameBudget.reset()
	var doctor := PlayerProfile.new()
	doctor.name = "Asha Verma"
	doctor.day = 4
	doctor.opening_seen = true
	doctor.created = true
	doctor.set_count("hospital_seed", 4242)
	for flag: String in ["op_rohit_done", "op_rohit_won"]:
		doctor.set_flag(flag)
	var ward := add_node(Ward.new(doctor)) as Ward
	ward.play_until(func() -> bool: return ward.mode == "walk", Ward.pick_tones(["Ready", "Honest", "Calm", "Patient first"]))
	var at := ward.profile.minutes
	FrameBudget.set_away(true)
	for frame in 600:
		ward.update(1.0 / 30.0)
	expect_equal(ward.profile.minutes, at, "twenty seconds away: not a minute passes")
	FrameBudget.set_away(false)
	for frame in 600:
		ward.update(1.0 / 30.0)
	expect(ward.profile.minutes > at, "and it runs again once back")
