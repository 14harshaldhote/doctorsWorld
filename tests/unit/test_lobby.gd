extends TestCase
## Day 1 in the hospital lobby: meeting Dr. Iyer at the door, walking,
## talking, today's tasks and the people chatting nearby.


func _profile(met_iyer: bool = true) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.name = "Kiran Rao"
	profile.address_form = "first"
	profile.opening_seen = true
	if met_iyer:
		profile.set_flag("met_iyer")
	return profile


func _lobby(profile: PlayerProfile = null, with_arrival: bool = false) -> Lobby:
	var lobby := Lobby.new(profile if profile != null else _profile(), with_arrival)
	add_node(lobby)
	return lobby


func _run(lobby: Lobby, seconds: float) -> void:
	var step := 1.0 / 60.0
	for frame in int(seconds / step):
		lobby._physics_process(step)
		lobby._process(step)


## Plays the conversation on show to its end, picking reply number pick.
## Returns every line shown, in order.
func _talk_through(lobby: Lobby, pick: int = 0) -> Array[String]:
	var lines: Array[String] = []
	for frame in 4000:
		if not lobby.story.is_playing():
			break
		if lobby.talk_ui.is_choosing():
			lobby.story.choose(pick)
		elif not lobby.story.is_busy():
			var text := lobby.talk_ui.line_text()
			if not text.is_empty() and (lines.is_empty() or lines[lines.size() - 1] != text):
				lines.append(text)
			lobby.talk_ui.tap()
		lobby._process(1.0 / 30.0)
	expect(not lobby.story.is_playing(), "the conversation ended")
	return lines


func test_lobby_has_the_cast_and_three_tasks() -> void:
	var lobby := _lobby()
	for id in ["iyer", "grace", "nair", "leela", "aarav", "tom", "priya"]:
		expect(lobby.people.has(id), "missing %s" % id)
	expect_equal(lobby.tasks.size(), Lobby.TASKS.size())
	expect(lobby.tasks.all(func(task: Array) -> bool: return not task[2]), "nothing done yet")
	expect(lobby.walk_area.is_walkable(Vector2(lobby.player.position.x, lobby.player.position.z)),
		"the player starts on open floor")
	expect(not lobby.story.is_playing(), "no conversation running once Dr. Iyer has been met")


func test_walking_to_a_point_gets_there_without_crossing_furniture() -> void:
	var lobby := _lobby()
	lobby.walk_to(Vector2(-5.0, 3.6))
	expect(not lobby._path.is_empty(), "a path was found")
	var previous := Vector2(lobby.player.position.x, lobby.player.position.z)
	for point in lobby._path:
		expect(lobby.walk_area.line_clear(previous, point), "leg %s → %s is clear" % [previous, point])
		previous = point
	_run(lobby, 8.0)
	var now := Vector2(lobby.player.position.x, lobby.player.position.z)
	expect(now.distance_to(Vector2(-5.0, 3.6)) < 0.1, "arrived (now at %s)" % now)


func test_walking_into_the_desk_stops_at_its_edge() -> void:
	var lobby := _lobby()
	lobby.walk_to(Vector2(0, -3.4))
	_run(lobby, 8.0)
	var now := Vector2(lobby.player.position.x, lobby.player.position.z)
	expect(lobby.walk_area.is_walkable(now), "still on open floor at %s" % now)
	expect(now.y > -2.9, "in front of the desk")


func test_tapping_sister_grace_walks_over_and_starts_talking() -> void:
	var lobby := _lobby()
	lobby.player.position = Vector3(0, 0, 0)
	lobby._place_camera(1.0)
	var grace: AvatarRig = lobby.people["grace"]["rig"]
	var screen_point := lobby.camera.unproject_position(grace.global_position + Vector3(0, 1.2, 0))
	expect_equal(lobby.person_at(screen_point), "grace", "the tap lands on Sister Grace")
	lobby.tap(screen_point)
	_run(lobby, 8.0)
	expect(lobby.story.is_playing(), "a conversation started")
	expect_equal(lobby.talking_with, "grace")
	expect_equal(lobby.conversation, "grace")
	expect(lobby.hud.is_talking(), "the walking HUD steps aside")
	var distance := Vector2(lobby.player.position.x, lobby.player.position.z).distance_to(
		Vector2(grace.position.x, grace.position.z))
	expect_between(distance, 0.5, 1.9, "standing near her")


func test_taps_do_nothing_while_someone_is_talking() -> void:
	var lobby := _lobby()
	lobby._start_talk("grace")
	var before := lobby.player.position
	lobby.tap(Vector2(100, 600))
	_run(lobby, 1.0)
	expect(lobby.player.position.distance_to(before) < 0.001, "the player stays put mid-conversation")


func test_the_day_opens_with_dr_iyer_at_the_door() -> void:
	var profile := _profile(false)
	var lobby := _lobby(profile, true)
	expect(lobby.story.is_playing(), "the arrival plays straight away")
	expect_equal(lobby.conversation, "arrival")
	expect_equal(lobby.player.held("R"), "letter", "the player walks in holding the letter")
	var saves := [0]
	lobby.save_requested.connect(func() -> void: saves[0] += 1)
	var lines := _talk_through(lobby, 2)
	expect(" ".join(lines).contains("Kiran"), "Dr. Iyer uses the player's name")
	expect(profile.has_flag("met_iyer"), "meeting her is remembered")
	expect(profile.has_flag("honest_with_iyer"), "the honest reply is remembered")
	expect_equal(profile.trust("iyer"), 55, "being honest earns her trust")
	expect_equal(lobby.player.held("R"), "", "hands free for the day")
	expect(not lobby.hud.is_talking(), "the walking HUD is back")
	expect(lobby.hud.pager_text().contains("Grace"), "the pager points to Sister Grace")
	expect_equal(saves[0], 1, "progress is saved once the day starts")
	_run(lobby, 10.0)
	var iyer: AvatarRig = lobby.people["iyer"]["rig"]
	expect(iyer.position.distance_to(Lobby.IYER_POST) < 0.05, "Dr. Iyer walks back to her post")


func test_correcting_dr_iyer_costs_trust() -> void:
	var profile := _profile(false)
	var lobby := _lobby(profile, true)
	_talk_through(lobby, 1)
	expect(profile.has_flag("corrected_iyer"), "she remembers being corrected")
	expect_equal(profile.trust("iyer"), 47)


func test_finishing_conversations_completes_tasks_and_gives_xp() -> void:
	var lobby := _lobby()
	var saves := [0]
	lobby.save_requested.connect(func() -> void: saves[0] += 1)
	expect_equal(lobby.conversation_for("iyer"), "iyer_waiting", "Dr. Iyer sends you away until you're done")
	for id in ["grace", "nair", "iyer"]:
		lobby._start_talk(id)
		_talk_through(lobby)
	expect(lobby.tasks.all(func(task: Array) -> bool: return task[2]), "all three tasks done")
	expect_equal(lobby.profile.total_xp, Lobby.XP_PER_TASK * 3)
	expect_equal(saves[0], 3, "progress is saved after each conversation")
	for task: Array in Lobby.TASKS:
		expect(lobby.profile.has_flag("day1_" + str(task[0])), "task %s is saved" % task[0])
	expect_equal(lobby.conversation_for("iyer"), "iyer_again")
	expect_equal(lobby.conversation_for("grace"), "grace_again")
	expect_equal(lobby.conversation_for("nair"), "nair_again")
	lobby._start_talk("iyer")
	_talk_through(lobby)
	lobby._start_talk("leela")
	_talk_through(lobby)
	expect_equal(lobby.profile.total_xp, Lobby.XP_PER_TASK * 3, "no double XP for talking twice")


func test_replies_change_trust_and_the_card_shows_it() -> void:
	var lobby := _lobby()
	lobby._start_talk("grace")
	for frame in 600:
		if lobby.talk_ui.is_choosing():
			break
		if not lobby.talk_ui.is_typing():
			lobby.talk_ui.tap()
		lobby._process(1.0 / 30.0)
	expect(lobby.talk_ui.is_choosing(), "Sister Grace waits for a reply")
	expect_equal(lobby.talk_ui.choice_buttons().size(), 3, "three replies")
	var before := lobby.profile.trust("grace", 45)
	lobby.story.choose(0)
	expect_equal(lobby.profile.trust("grace", 45), before + 5, "the warm reply earns trust")
	expect_equal(lobby.story.card_for("grace")["trust"], before + 5, "the card shows the new trust")


func test_progress_carries_over_from_the_save() -> void:
	var profile := _profile()
	profile.set_flag("day1_grace")
	var lobby := _lobby(profile)
	expect(lobby.task_done("grace"), "Sister Grace already met")
	expect(not lobby.task_done("patient"))
	expect(lobby.hud.pager_text().contains("waiting area"), "the pager moves on to the next task")


func test_a_patient_answers_with_your_name() -> void:
	var lobby := _lobby()
	lobby._start_talk("nair")
	var lines := _talk_through(lobby, 1)
	expect(lobby.profile.has_flag("asked_nair_wait"), "asking about the wait is remembered")
	expect(lobby.task_done("patient"), "greeting a patient counts")
	expect(lines.size() >= 3, "a real exchange, not a single line")


func test_nurses_and_patients_chat_among_themselves() -> void:
	var lobby := _lobby()
	var heard := {}
	for frame in 60 * 40:
		lobby._process(1.0 / 60.0)
		for index in 2:
			var line := lobby.banter_line(index)
			if not line.is_empty():
				heard[line[1]] = line[0]
	expect(heard.size() >= 4, "several lines of chatter (heard %d)" % heard.size())
	expect(heard.values().has("tom") and heard.values().has("priya"), "the nurses take turns")
	var tom: AvatarRig = lobby.people["tom"]["rig"]
	var priya: AvatarRig = lobby.people["priya"]["rig"]
	expect(tom.talking or priya.talking or lobby.banter_line(0).is_empty(), "the speaker's mouth moves")


func test_chatter_pauses_while_you_talk_to_someone_in_it() -> void:
	var lobby := _lobby()
	_run(lobby, 3.0)
	lobby._start_talk("nair")
	_run(lobby, 2.0)
	for frame in 120:
		lobby._process(1.0 / 60.0)
		var line := lobby.banter_line(1)
		expect(line.is_empty(), "the waiting patients stop chatting while you talk to them")
		if not line.is_empty():
			break


func test_background_chatter_is_soft_and_only_heard_up_close() -> void:
	expect(is_nan(Lobby.banter_volume(Lobby.BANTER_FAR + 0.5)), "too far away: not heard at all")
	var near := Lobby.banter_volume(1.0)
	expect_between(near, -30.0, -18.0, "up close: heard, but softly")
	expect(Lobby.banter_volume(3.5) < near - 6.0, "much fainter a few steps away")
	expect(Lobby.banter_volume(1.0, true) < near, "softer still while you talk to someone")
	var lobby := _lobby()
	var tom: AvatarRig = lobby.people["tom"]["rig"]
	var priya: AvatarRig = lobby.people["priya"]["rig"]
	var middle := (tom.position + priya.position) / 2.0
	# Across the room from the nurses: their chatter is silent, though their
	# mouths still move.
	lobby.player.position = Vector3(-signf(middle.x) * 7.0, 0, -signf(middle.z) * 5.0)
	for rig: AvatarRig in [tom, priya]:
		expect(lobby._player_distance(rig) > Lobby.BANTER_FAR, "the player starts far away")
	var talked := false
	for frame in 60 * 12:
		lobby._process(1.0 / 60.0)
		talked = talked or tom.talking or priya.talking
	expect(talked, "the nurses chat")
	expect(tom.get_node_or_null("Voice") == null and priya.get_node_or_null("Voice") == null,
		"but from across the room you don't hear them")
	# Right beside them: now it can be heard, softly.
	lobby.player.position = middle + Vector3(0.6, 0, 0.6)
	var heard: AudioStreamPlayer3D = null
	for frame in 60 * 20:
		lobby._process(1.0 / 60.0)
		for rig: AvatarRig in [tom, priya]:
			var voice := rig.get_node_or_null("Voice") as AudioStreamPlayer3D
			if voice != null:
				heard = voice
		if heard != null:
			break
	expect(heard != null, "standing beside them you hear them")
	if heard != null:
		expect_between(heard.volume_db, Lobby.BANTER_LOUDEST - 1.0, Lobby.BANTER_LOUDEST + 0.1, "softly")
	expect(tom.voice_volume_db == 0.0 and priya.voice_volume_db == 0.0,
		"their own lines in a conversation keep the normal level")
