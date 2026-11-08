extends TestCase
## Day 1 in the hospital lobby: walking, talking and today's tasks.


func _lobby() -> Lobby:
	var lobby := Lobby.new(PlayerProfile.new())
	add_node(lobby)
	return lobby


func _run(lobby: Lobby, seconds: float) -> void:
	var step := 1.0 / 60.0
	for frame in int(seconds / step):
		lobby._physics_process(step)
		lobby._process(step)


func _talk_through(lobby: Lobby) -> void:
	for line in 10:
		if not lobby.hud.dialogue_open():
			return
		lobby._on_dialogue_next()


func test_lobby_has_the_cast_and_three_tasks() -> void:
	var lobby := _lobby()
	for id in ["iyer", "grace", "patient", "patient2"]:
		expect(lobby.people.has(id), "missing %s" % id)
	expect_equal(lobby.tasks.size(), 3)
	expect(lobby.tasks.all(func(task: Array) -> bool: return not task[2]), "nothing done yet")
	expect(lobby.walk_area.is_walkable(Vector2(lobby.player.position.x, lobby.player.position.z)),
		"the player starts on open floor")


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


func test_tapping_dr_iyer_walks_over_and_starts_talking() -> void:
	var lobby := _lobby()
	var iyer: AvatarRig = lobby.people["iyer"]["rig"]
	var screen_point := lobby.camera.unproject_position(iyer.global_position + Vector3(0, 0.8, 0))
	expect_equal(lobby.person_at(screen_point), "iyer", "tap lands on Dr. Iyer")
	lobby.tap(screen_point)
	_run(lobby, 8.0)
	expect(lobby.hud.dialogue_open(), "conversation open")
	expect_equal(lobby._talking_to, "iyer")
	var distance := Vector2(lobby.player.position.x, lobby.player.position.z).distance_to(
		Vector2(iyer.position.x, iyer.position.z))
	expect_between(distance, 0.5, 1.5, "standing next to her")


func test_finishing_conversations_completes_tasks_and_gives_xp() -> void:
	var lobby := _lobby()
	var saves := [0]
	lobby.save_requested.connect(func() -> void: saves[0] += 1)
	for id in ["iyer", "grace", "patient2"]:
		lobby._start_talk(id)
		_talk_through(lobby)
	expect(lobby.tasks.all(func(task: Array) -> bool: return task[2]), "all three tasks done")
	expect_equal(lobby.profile.total_xp, Lobby.XP_PER_TASK * 3)
	expect_equal(saves[0], 3, "progress is saved after each task")
	lobby._start_talk("iyer")
	_talk_through(lobby)
	expect_equal(lobby.profile.total_xp, Lobby.XP_PER_TASK * 3, "no double XP for talking twice")


func test_conversations_use_the_players_name() -> void:
	var profile := PlayerProfile.new()
	profile.name = "Kiran Rao"
	profile.address_form = "first"
	var lobby := Lobby.new(profile)
	add_node(lobby)
	var lines: Array = lobby.people["iyer"]["lines"]
	expect(" ".join(lines).contains("Dr. Kiran"), "Dr. Iyer calls you by the name you chose")
