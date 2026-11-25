extends TestCase
## Stage 28: the speed pass. Characters nobody can see skip their posing,
## the phone keeps its messages until something changes, the voices are read
## in the background at boot, and a Mac keyboard can move a talk on.


func _walker(at: Vector3) -> AvatarRig:
	var rig := AvatarRig.new()
	rig.position = at
	rig.moving = 1.0
	return rig


func test_characters_out_of_sight_wait_and_then_catch_up() -> void:
	var room := add_node(Node3D.new()) as Node3D
	var camera := Camera3D.new()
	room.add_child(camera)
	camera.make_current()
	var seen := _walker(Vector3(0, 0, -6))
	var behind := _walker(Vector3(0, 0, 6))
	var hidden := _walker(Vector3(1, 0, -6))
	for rig in [seen, behind, hidden]:
		room.add_child(rig)
	hidden.visible = false
	AvatarRig._frustum_frame = -1
	var hip_before: float = behind.joint("HipL").rotation.x
	for rig: AvatarRig in [seen, behind, hidden]:
		rig._process(0.2)
	expect(absf(seen.joint("HipL").rotation.x) > 0.01, "the one in front of the camera walks")
	expect_near(behind.joint("HipL").rotation.x, hip_before, 0.0001, "the one behind it is left as it was")
	expect_near(hidden.joint("HipL").rotation.x, hip_before, 0.0001, "and so is a hidden one")
	expect(behind._owed > 0.19, "the time it missed is kept")
	# The camera turns round: the one behind is mid-stride straight away.
	camera.rotation.y = PI
	AvatarRig._frustum_frame = -1
	behind._process(0.02)
	expect(absf(behind.joint("HipL").rotation.x) > 0.01, "once seen it walks")
	expect_near(behind._owed, 0.0, 0.0001, "with nothing owed")
	expect_near(behind._walk_phase, seen._walk_phase, 0.3, "its stride kept time while it waited")


func test_with_no_camera_everyone_moves() -> void:
	var room := add_node(Node3D.new()) as Node3D
	var rig := _walker(Vector3(0, 0, 50))
	room.add_child(rig)
	rig._process(0.2)
	expect(absf(rig.joint("HipL").rotation.x) > 0.01, "tests and tools see every pose")


func test_nobody_breathes_or_blinks_in_step_with_the_next() -> void:
	var clocks: Array[float] = []
	for index in 6:
		var rig := AvatarRig.new()
		clocks.append(rig._clock)
		rig.free()
	for index in range(1, clocks.size()):
		expect(absf(clocks[index] - clocks[index - 1]) > 0.3, "%d starts %.2f s apart from the last" % [index,
			absf(clocks[index] - clocks[index - 1])])


func test_the_phone_keeps_its_messages_until_something_changes() -> void:
	PhoneBook.forget()
	var doctor := PlayerProfile.new()
	doctor.name = "Meera Joshi"
	doctor.day = 12
	doctor.minutes = 10 * 60
	doctor.set_flag("met_iyer")
	var first := PhoneBook.items(doctor)
	expect(not first.is_empty(), "there are messages")
	doctor.minutes += 90
	expect(is_same(PhoneBook.items(doctor), first), "the clock alone changes nothing to rebuild")
	doctor.set_flag("ward_day10")
	var second := PhoneBook.items(doctor)
	expect(not is_same(second, first), "a new story fact rebuilds them")
	doctor.set_count("hospital_seed", 77)
	var third := PhoneBook.items(doctor)
	expect(not is_same(third, second), "so does a count")
	doctor.name = "Meera Rao"
	expect(not is_same(PhoneBook.items(doctor), third), "and a new name")
	PhoneBook.forget()


func test_the_voices_are_read_in_the_background() -> void:
	VoiceBank.reset()
	VoiceBank.warm()
	expect(VoiceBank._warming >= 0 or VoiceBank.has_lines(), "the read starts at once")
	expect(VoiceBank.has_lines(), "and the lines are there when first asked for")
	expect_equal(VoiceBank._warming, -1, "the task is done with")
	VoiceBank.reset()
	VoiceBank.warm()
	VoiceBank.reset()
	expect_equal(VoiceBank._warming, -1, "forgetting waits for a read under way")
	expect(VoiceBank.has_lines(), "and reading again works")
	VoiceBank.reset()


func _key(code: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.keycode = code
	key.pressed = true
	return key


func test_a_keyboard_moves_a_talk_on_and_picks_replies() -> void:
	var screen := add_node(Control.new()) as Control
	var hud := LobbyHud.new(PlayerProfile.new())
	screen.add_child(hud)
	var talk := ConversationUi.new()
	screen.add_child(talk)
	var moved := [0]
	var picked := [-1]
	talk.advanced.connect(func() -> void: moved[0] += 1)
	talk.chosen.connect(func(index: int) -> void: picked[0] = index)
	talk.show_line("Dr. Iyer", "Coffee first. Then rounds.")
	talk.get_viewport().push_input(_key(KEY_SPACE))
	expect(not talk.is_typing() and moved[0] == 0, "Space finishes the line being typed")
	talk.get_viewport().push_input(_key(KEY_ENTER))
	expect_equal(moved[0], 1, "Return moves on")
	talk.show_choices([{"tone": "Calm", "text": "On my way."}, {"tone": "Honest", "text": "After coffee."}])
	talk.get_viewport().push_input(_key(KEY_SPACE))
	expect_equal(moved[0], 1, "Space cannot skip a choice")
	talk.get_viewport().push_input(_key(KEY_2))
	expect_equal(picked[0], 1, "2 picks the second reply")
	talk.show_line("Dr. Iyer", "Good.")
	talk.finish_typing()
	hud._menu.visible = true
	talk.get_viewport().push_input(_key(KEY_SPACE))
	expect_equal(moved[0], 1, "nothing moves on behind the pause menu")
	hud._menu.visible = false
	talk.close()
	talk.get_viewport().push_input(_key(KEY_SPACE))
	expect_equal(moved[0], 1, "or once the talk is over")
