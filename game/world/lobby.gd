class_name Lobby
extends Node3D
## Day 1: the reception of Riverside City Hospital. The player walks around
## (tap the floor, or WASD and arrow keys), meets Dr. Meera Iyer and Sister
## Grace, and says hello to a waiting patient.
##
## Floor coordinates: x runs left to right, z runs from the back wall (-6)
## towards the camera (+6). The room is open on the camera side.

signal save_requested
signal menu_choice(choice: String)

const ROOM := Rect2(-8, -6, 16, 12)
const WALK_SPEED := 1.8
const CAMERA_OFFSET := Vector3(0, 3.7, 5.0)
const TALK_DISTANCE := 1.0
const TAP_RADIUS := 70.0
const XP_PER_TASK := 40

const WALL := Color("#EEF2EC")
const WALL_TOP := Color("#DCE8E6")
const FLOOR := Color("#D3E0E1")
const FLOOR_TILE := Color("#C5D6D8")
const TEAL := Color("#127C80")
const SEAT := Color("#1F8A8A")
const WOOD := Color("#C9A27A")

var profile: PlayerProfile
var walk_area: WalkArea
var player: AvatarRig
var camera: Camera3D
var hud: LobbyHud
## People you can talk to: id -> {rig, name, role, lines, task}.
var people := {}
## Today's tasks in order: [id, text, done].
var tasks := [
	["iyer", "Find Dr. Iyer", false],
	["grace", "Meet Sister Grace", false],
	["patient", "Greet a waiting patient", false],
]

var _path := PackedVector2Array()
var _talk_target := ""
var _talking_to := ""
var _line_index := 0
var _marker: Node3D
var _marker_time := 0.0
var _press_at := Vector2.ZERO
var _facing := PI
var _camera_target := Vector3.ZERO


func _init(for_profile: PlayerProfile = null) -> void:
	profile = for_profile if for_profile != null else PlayerProfile.new()


func _ready() -> void:
	StageLighting.add_to(self, Color("#A9C3C8"), Vector3(-55, 28, 0))
	walk_area = WalkArea.new(Rect2(-7.7, -5.75, 15.4, 11.6), 0.28)
	_build_room()
	_build_reception()
	_build_waiting_area()
	_build_doors_and_corners()
	_build_people()
	player = AvatarRig.new(profile.avatar)
	player.name = "Player"
	player.position = Vector3(0, 0, 4.6)
	player.rotation.y = _facing
	add_child(player)
	_marker = _build_marker()
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 42
	add_child(camera)
	_place_camera(1.0)
	var layer := CanvasLayer.new()
	layer.name = "HudLayer"
	add_child(layer)
	hud = LobbyHud.new(profile)
	hud.name = "Hud"
	layer.add_child(hud)
	hud.dialogue_next.connect(_on_dialogue_next)
	hud.menu_choice.connect(func(choice: String) -> void: menu_choice.emit(choice))
	hud.set_clock("Day %d · 07:00 · First day" % profile.day)
	hud.set_pager("Dr. Iyer: Reception. Now. Don't make me page twice.")
	_refresh_tasks()


# --- Building the room ---------------------------------------------------

func _build_room() -> void:
	LowPoly.put(self, LowPoly.box(Vector3(ROOM.size.x, 0.1, ROOM.size.y), FLOOR), Vector3(0, -0.05, 0))
	# A checker of slightly darker tiles so walking reads as movement.
	for ix in 8:
		for iz in 6:
			if (ix + iz) % 2 == 0:
				LowPoly.put(self, LowPoly.box(Vector3(1.96, 0.01, 1.96), FLOOR_TILE), Vector3(-7 + ix * 2, 0.005, -5 + iz * 2))
	LowPoly.put(self, LowPoly.box(Vector3(2.6, 0.02, 1.4), TEAL.darkened(0.15)), Vector3(0, 0.012, 5.2))
	# A guide line from the entrance to reception.
	LowPoly.put(self, LowPoly.box(Vector3(0.16, 0.012, 6.2), Color("#F5B841")), Vector3(0, 0.012, 1.3))
	# Back and side walls with a teal skirting and a lighter top band.
	var back := LowPoly.joint(self, "BackWall", Vector3(0, 0, ROOM.position.y))
	LowPoly.put(back, LowPoly.box(Vector3(ROOM.size.x + 0.4, 3.4, 0.2), WALL), Vector3(0, 1.7, -0.1))
	LowPoly.put(back, LowPoly.box(Vector3(ROOM.size.x + 0.4, 0.5, 0.22), WALL_TOP), Vector3(0, 3.15, -0.1))
	LowPoly.put(back, LowPoly.box(Vector3(ROOM.size.x + 0.4, 0.16, 0.24), TEAL), Vector3(0, 0.08, -0.1))
	for side: int in [-1, 1]:
		var wall := LowPoly.joint(self, "SideWall" + ("L" if side < 0 else "R"), Vector3(8.1 * side, 0, 0))
		LowPoly.put(wall, LowPoly.box(Vector3(0.2, 3.4, ROOM.size.y), WALL.darkened(0.04)), Vector3(0, 1.7, 0))
		LowPoly.put(wall, LowPoly.box(Vector3(0.24, 0.16, ROOM.size.y), TEAL), Vector3(-0.02 * side, 0.08, 0))
	# The hospital's name on the back wall.
	var sign := _label3d("Riverside City Hospital", 88, TEAL)
	sign.position = Vector3(0.45, 2.62, -5.78)
	add_child(sign)
	var cross := LowPoly.joint(self, "Emblem", Vector3(-3.15, 2.62, -5.8))
	LowPoly.put(cross, LowPoly.cylinder(0.3, 0.3, 0.05, 12, TEAL), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	LowPoly.put(cross, LowPoly.box(Vector3(0.1, 0.36, 0.04), Color.WHITE), Vector3(0, 0, 0.03))
	LowPoly.put(cross, LowPoly.box(Vector3(0.36, 0.1, 0.04), Color.WHITE), Vector3(0, 0, 0.03))


func _build_reception() -> void:
	var desk := LowPoly.joint(self, "Reception", Vector3(0, 0, -3.4))
	LowPoly.put(desk, LowPoly.box(Vector3(4.2, 1.02, 0.9), Color("#F4F7F7")), Vector3(0, 0.51, 0))
	LowPoly.put(desk, LowPoly.box(Vector3(4.22, 0.42, 0.06), TEAL), Vector3(0, 0.62, 0.46))
	LowPoly.put(desk, LowPoly.box(Vector3(4.4, 0.07, 1.1), WOOD), Vector3(0, 1.06, 0.05))
	LowPoly.put(desk, LowPoly.box(Vector3(0.55, 0.36, 0.05), Color("#26343A")), Vector3(-1.1, 1.3, -0.15),
		Vector3(0, 0.25, 0))
	LowPoly.put(desk, LowPoly.box(Vector3(0.5, 0.31, 0.02), Color("#5FB7A6")), Vector3(-1.1, 1.3, -0.12),
		Vector3(0, 0.25, 0))
	LowPoly.put(desk, LowPoly.box(Vector3(0.24, 0.1, 0.32), Color("#F07C5A")), Vector3(1.3, 1.14, 0.1))
	_plant(desk, Vector3(1.85, 1.1, -0.1), 0.5)
	var label := _label3d("RECEPTION", 54, Color.WHITE)
	label.position = Vector3(0, 0.62, 0.5)
	desk.add_child(label)
	LowPoly.put(desk, LowPoly.shadow_blob(2.6, Vector2(1.0, 0.36)), Vector3(0, 0, 0.1))
	walk_area.add_blocker(Rect2(-2.35, -5.8, 4.7, 2.95))


func _build_waiting_area() -> void:
	var area := LowPoly.joint(self, "Waiting", Vector3(-5.1, 0, 0))
	for row in 2:
		var z := -0.2 + row * 1.7
		for seat in 5:
			_chair(area, Vector3(-1.6 + seat * 0.8, 0, z))
		walk_area.add_blocker(Rect2(-5.1 - 2.05, z - 0.42, 4.1, 0.78))
	_plant(self, Vector3(-7.3, 0, 3.6), 1.0)
	walk_area.add_blocker(Rect2(-7.7, 3.2, 0.8, 0.8))
	var board := LowPoly.joint(self, "Notices", Vector3(-5.2, 1.7, -5.86))
	LowPoly.put(board, LowPoly.box(Vector3(1.8, 1.1, 0.05), WOOD), Vector3.ZERO)
	for index in 5:
		var colour: Color = [Color("#F8D27A"), Color.WHITE, Color("#8FE3D2"), Color("#F4B6A0"), Color.WHITE][index]
		LowPoly.put(board, LowPoly.box(Vector3(0.32, 0.36, 0.02), colour), Vector3(-0.62 + index * 0.31, 0.12 - (index % 2) * 0.3, 0.035),
			Vector3(0, 0, (index - 2) * 0.05))


func _chair(parent: Node3D, at: Vector3) -> void:
	var chair := LowPoly.joint(parent, "Chair", at)
	LowPoly.put(chair, LowPoly.box(Vector3(0.62, 0.08, 0.52), SEAT), Vector3(0, 0.44, 0))
	LowPoly.put(chair, LowPoly.box(Vector3(0.62, 0.52, 0.07), SEAT.darkened(0.1)), Vector3(0, 0.72, -0.24))
	for x in [-0.27, 0.27]:
		LowPoly.put(chair, LowPoly.box(Vector3(0.05, 0.42, 0.42), Color("#8FA3A8")), Vector3(x, 0.2, 0))
	LowPoly.put(chair, LowPoly.shadow_blob(0.38, Vector2(1.0, 0.85)), Vector3.ZERO)


func _build_doors_and_corners() -> void:
	_door(Vector3(-5.2, 0, -5.88), "WARD A")
	_door(Vector3(5.2, 0, -5.88), "OR 1 · OR 2")
	_plant(self, Vector3(-7.25, 0, -5.3), 1.1)
	_plant(self, Vector3(7.25, 0, -5.3), 1.1)
	_plant(self, Vector3(-2.9, 0, -5.35), 0.9)
	_plant(self, Vector3(2.9, 0, -5.35), 0.9)
	for spot: Vector2 in [Vector2(-7.25, -5.3), Vector2(7.25, -5.3), Vector2(-2.9, -5.35), Vector2(2.9, -5.35)]:
		walk_area.add_blocker(Rect2(spot.x - 0.4, spot.y - 0.45, 0.8, 0.9))
	# A vending machine and a water cooler on the right wall.
	var vend := LowPoly.joint(self, "Vending", Vector3(7.5, 0, -1.2), Vector3(0, -PI / 2, 0))
	LowPoly.put(vend, LowPoly.box(Vector3(0.95, 1.95, 0.7), Color("#F07C5A")), Vector3(0, 0.975, 0))
	var glass := LowPoly.box(Vector3(0.6, 1.2, 0.04), Color("#BFE7F0"))
	glass.material_override = LowPoly.glow(Color("#BFE7F0"), 0.5)
	LowPoly.put(vend, glass, Vector3(-0.1, 1.2, 0.36))
	LowPoly.put(vend, LowPoly.shadow_blob(0.75, Vector2(1.0, 0.7)), Vector3.ZERO)
	walk_area.add_blocker(Rect2(6.95, -1.75, 0.9, 1.1))
	var cooler := LowPoly.joint(self, "Cooler", Vector3(7.5, 0, 0.6))
	LowPoly.put(cooler, LowPoly.box(Vector3(0.4, 1.0, 0.4), Color("#E8EEEE")), Vector3(0, 0.5, 0))
	LowPoly.put(cooler, LowPoly.cylinder(0.16, 0.16, 0.4, 8, Color("#8FD0E8")), Vector3(0, 1.2, 0))
	walk_area.add_blocker(Rect2(7.2, 0.3, 0.6, 0.6))
	# Benches by the entrance on the right.
	for z in [2.6, 4.0]:
		var bench := LowPoly.joint(self, "Bench", Vector3(6.6, 0, z), Vector3(0, -PI / 2, 0))
		LowPoly.put(bench, LowPoly.box(Vector3(1.6, 0.1, 0.5), WOOD), Vector3(0, 0.44, 0))
		for x in [-0.65, 0.65]:
			LowPoly.put(bench, LowPoly.box(Vector3(0.08, 0.42, 0.4), Color("#8FA3A8")), Vector3(x, 0.2, 0))
		LowPoly.put(bench, LowPoly.shadow_blob(0.9, Vector2(1.0, 0.4)), Vector3.ZERO)
		walk_area.add_blocker(Rect2(6.3, z - 0.85, 0.65, 1.7))


func _door(at: Vector3, title: String) -> void:
	var door := LowPoly.joint(self, "Door", at)
	LowPoly.put(door, LowPoly.box(Vector3(2.0, 2.4, 0.08), Color("#DCE6E8")), Vector3(0, 1.2, 0))
	for side: int in [-1, 1]:
		LowPoly.put(door, LowPoly.box(Vector3(0.86, 2.2, 0.06), Color("#5FB7A6")), Vector3(0.45 * side, 1.12, 0.05))
		LowPoly.put(door, LowPoly.box(Vector3(0.3, 0.4, 0.02), Color("#BFE7F0")), Vector3(0.45 * side, 1.6, 0.085))
	LowPoly.put(door, LowPoly.box(Vector3(1.4, 0.34, 0.05), TEAL), Vector3(0, 2.62, 0.04))
	var label := _label3d(title, 48, Color.WHITE)
	label.position = Vector3(0, 2.62, 0.08)
	door.add_child(label)


func _plant(parent: Node3D, at: Vector3, size: float) -> void:
	var plant := LowPoly.joint(parent, "Plant", at)
	LowPoly.put(plant, LowPoly.cylinder(0.2 * size, 0.15 * size, 0.36 * size, 7, Color("#E2E8E8")), Vector3(0, 0.18 * size, 0))
	LowPoly.put(plant, LowPoly.sphere(0.3 * size, Color("#3E8E5A"), 6, 4), Vector3(0, 0.55 * size, 0))
	LowPoly.put(plant, LowPoly.sphere(0.22 * size, Color("#4FA56B"), 6, 4), Vector3(0.12 * size, 0.78 * size, 0.05))
	if at.y < 0.01:
		LowPoly.put(plant, LowPoly.shadow_blob(0.32 * size), Vector3.ZERO)


func _label3d(text: String, size: int, colour: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = UiKit.heading_font()
	label.font_size = size
	label.pixel_size = 0.004
	label.outline_size = 0
	label.modulate = colour
	label.shaded = false
	return label


func _build_marker() -> Node3D:
	var marker := Node3D.new()
	marker.name = "TapMarker"
	var ring := LowPoly.torus(0.16, 0.22, Color("#F5B841"), 14, 3)
	ring.material_override = LowPoly.glow(Color("#F5B841"), 0.8)
	ring.scale = Vector3(1, 0.15, 1)
	marker.add_child(ring)
	marker.visible = false
	add_child(marker)
	return marker


# --- People --------------------------------------------------------------

func _build_people() -> void:
	var iyer := AvatarConfig.new()
	iyer.skin = 3
	iyer.face = 1
	iyer.height = 3
	iyer.hair_style = 7
	iyer.hair_colour = 5
	iyer.brows = 0
	iyer.glasses = 4
	iyer.scrubs = 1
	iyer.watch = true
	_add_person("iyer", iyer, Vector3(2.7, 0, -1.9), -0.6, "Dr. Meera Iyer", "Senior surgeon", [
		"You're late. Good, it means you're nervous.",
		"Nervous doctors check things twice. Keep that, %s." % profile.called(),
		"Go and see Sister Grace at the desk. She runs this hospital. I just operate in it.",
	], AvatarConfig.Mood.FOCUSED)
	var grace := AvatarConfig.new()
	grace.skin = 7
	grace.face = 0
	grace.hair_style = 6
	grace.hair_colour = 0
	grace.scrubs = 4
	grace.coat = false
	grace.stethoscope = false
	grace.watch = true
	grace.brows = 2
	_add_person("grace", grace, Vector3(-0.7, 0, -4.4), 0.0, "Sister Grace Mathew", "Head nurse", [
		"So you're the new intern. Welcome to Riverside, %s." % profile.called(),
		"Rule one: wash your hands. Rule two: see rule one.",
		"The wards open to you tomorrow. Tonight, sleep. You won't get much after this.",
	], AvatarConfig.Mood.HAPPY)
	var rng := SeededRandom.new(4242)
	var waiting := [
		["patient", Vector3(-5.9, 0, -0.2), "Mr. Prakash Nair", "Waiting since 6 a.m.", [
			"Are you a real doctor? You look about twelve.",
			"Never mind. Everyone looks twelve to me now.",
		]],
		["patient2", Vector3(-4.3, 0, 1.5), "Leela Thomas", "Waiting with her son", [
			"He swallowed a coin. He says it was an accident. It was not.",
		]],
	]
	for entry: Array in waiting:
		var look := AvatarConfig.random(rng)
		look.coat = false
		look.stethoscope = false
		look.scrubs = rng.pick([2, 3, 5, 7])
		var rig := _add_person(entry[0], look, entry[1], 0.0, entry[2], entry[3], entry[4], AvatarConfig.Mood.TIRED)
		rig.sitting = true


func _add_person(id: String, look: AvatarConfig, at: Vector3, facing: float, display_name: String, role: String,
		lines: Array, mood: int) -> AvatarRig:
	var rig := AvatarRig.new(look)
	rig.name = id.capitalize().replace(" ", "")
	rig.position = at
	rig.rotation.y = facing
	rig.mood = mood
	add_child(rig)
	people[id] = {"rig": rig, "name": display_name, "role": role, "lines": lines, "facing": facing}
	if not rig.sitting:
		walk_area.add_blocker(Rect2(at.x - 0.25, at.z - 0.25, 0.5, 0.5))
	return rig


# --- Tasks ---------------------------------------------------------------

func _refresh_tasks() -> void:
	var list := []
	for task: Array in tasks:
		list.append([task[1], task[2]])
	hud.set_tasks(list)


func _complete_task(id: String) -> void:
	for task: Array in tasks:
		if task[0] == id and not task[2]:
			task[2] = true
			profile.total_xp += XP_PER_TASK
			hud.refresh_profile()
			hud.toast("+%d XP · %s" % [XP_PER_TASK, task[1]])
			save_requested.emit()
	_refresh_tasks()
	var done := tasks.all(func(task: Array) -> bool: return task[2])
	if done:
		hud.set_pager("Dr. Iyer: Good. That's Day 1. Go home. Sleep. Come back sharper.")
	elif id == "iyer":
		hud.set_pager("Sister Grace: I'm at the desk. Bring your ID badge.")


# --- Input and movement --------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if hud.dialogue_open() or hud.menu_open():
		return
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.pressed:
		_press_at = button.position
	elif button.position.distance_to(_press_at) < 24.0:
		tap(button.position)


## Handles a tap on the screen: talk to a person, or walk to the floor.
func tap(screen_point: Vector2) -> void:
	var person := person_at(screen_point)
	if not person.is_empty():
		walk_to_person(person)
		return
	var floor_point: Variant = _floor_point(screen_point)
	if floor_point == null:
		return
	_talk_target = ""
	walk_to(floor_point)


## The id of the person drawn at a screen point, or "".
func person_at(screen_point: Vector2) -> String:
	var best := ""
	var best_distance := TAP_RADIUS
	for id: String in people:
		var rig: AvatarRig = people[id]["rig"]
		var feet := rig.global_position
		var head := feet + Vector3(0, 1.1 if rig.sitting else 1.6, 0)
		if camera.is_position_behind(head):
			continue
		var a := camera.unproject_position(feet)
		var b := camera.unproject_position(head)
		var distance := Geometry2D.get_closest_point_to_segment(screen_point, a, b).distance_to(screen_point)
		if distance < best_distance:
			best_distance = distance
			best = id
	return best


func _floor_point(screen_point: Vector2) -> Variant:
	var origin := camera.project_ray_origin(screen_point)
	var direction := camera.project_ray_normal(screen_point)
	if direction.y > -0.01:
		return null
	var hit := origin + direction * (-origin.y / direction.y)
	return Vector2(hit.x, hit.z)


func walk_to(target: Vector2) -> void:
	var start := Vector2(player.position.x, player.position.z)
	_path = walk_area.find_path(start, target)
	if not _path.is_empty():
		var end := _path[_path.size() - 1]
		_marker.position = Vector3(end.x, 0.02, end.y)
		_marker.visible = true
		_marker_time = 1.2


func walk_to_person(id: String) -> void:
	var rig: AvatarRig = people[id]["rig"]
	var spot := Vector2(rig.position.x, rig.position.z)
	var me := Vector2(player.position.x, player.position.z)
	var away := (me - spot).normalized() if me.distance_to(spot) > 0.01 else Vector2(0, 1)
	_talk_target = id
	if me.distance_to(spot) <= TALK_DISTANCE + 0.3:
		_path = PackedVector2Array()
		_start_talk(id)
		return
	walk_to(walk_area.closest_walkable(spot + away * TALK_DISTANCE))


func _physics_process(delta: float) -> void:
	if player == null:
		return
	var keys := _key_direction()
	var moved := Vector2.ZERO
	if keys != Vector2.ZERO and not hud.dialogue_open() and not hud.menu_open():
		_path = PackedVector2Array()
		_talk_target = ""
		moved = _step(keys.normalized() * WALK_SPEED * delta)
	elif not _path.is_empty():
		var me := Vector2(player.position.x, player.position.z)
		var next := _path[0]
		var to_next := next - me
		var step := WALK_SPEED * delta
		if to_next.length() <= step:
			player.position = Vector3(next.x, 0, next.y)
			moved = to_next
			_path.remove_at(0)
			if _path.is_empty() and not _talk_target.is_empty():
				_start_talk(_talk_target)
		else:
			moved = to_next.normalized() * step
			player.position += Vector3(moved.x, 0, moved.y)
	if moved.length() > 0.0001:
		_facing = atan2(moved.x, moved.y)
	player.moving = 1.0 if moved.length() > 0.0001 else 0.0
	player.rotation.y = lerp_angle(player.rotation.y, _facing, minf(1.0, delta * 10.0))


## Moves by a step if the floor allows it, sliding along walls otherwise.
func _step(step: Vector2) -> Vector2:
	var me := Vector2(player.position.x, player.position.z)
	for attempt: Vector2 in [step, Vector2(step.x, 0), Vector2(0, step.y)]:
		if attempt != Vector2.ZERO and walk_area.is_walkable(me + attempt):
			player.position += Vector3(attempt.x, 0, attempt.y)
			return attempt
	return Vector2.ZERO


func _key_direction() -> Vector2:
	var direction := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		direction.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		direction.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		direction.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		direction.y += 1
	return direction


func _process(delta: float) -> void:
	_place_camera(minf(1.0, delta * 4.0))
	if _marker_time > 0.0:
		_marker_time -= delta
		_marker.scale = Vector3.ONE * (1.0 + (1.2 - _marker_time) * 0.4)
		if _marker_time <= 0.0:
			_marker.visible = false
	_update_tags()


func _place_camera(weight: float) -> void:
	var focus := player.position if player != null else Vector3.ZERO
	var goal: Vector3
	var target: Vector3
	if not _talking_to.is_empty():
		# In a conversation the camera swings round to frame both faces.
		var other: AvatarRig = people[_talking_to]["rig"]
		var middle := (focus + other.position) / 2.0
		var across := Vector3(other.position.x - focus.x, 0, other.position.z - focus.z).normalized()
		var side := Vector3(-across.z, 0, across.x)
		if side.z < 0.0:
			side = -side
		goal = middle + side * 3.5 + Vector3(0, 1.8, 0)
		target = middle + Vector3(0, 1.15, 0)
	else:
		focus.x = clampf(focus.x, -5.0, 5.0)
		focus.z = clampf(focus.z, -3.4, 3.6)
		goal = focus + CAMERA_OFFSET
		target = focus + Vector3(0, 0.9, 0)
	_camera_target = _camera_target.lerp(target, weight) if weight < 1.0 else target
	camera.position = camera.position.lerp(goal, weight)
	camera.look_at(_camera_target)


func _update_tags() -> void:
	var next_task := ""
	for task: Array in tasks:
		if not task[2]:
			next_task = task[0]
			break
	for id: String in people:
		var person: Dictionary = people[id]
		var rig: AvatarRig = person["rig"]
		var head := rig.global_position + Vector3(0, 1.45 if rig.sitting else 2.05, 0)
		var shown := not camera.is_position_behind(head)
		var text: String = person["name"] if id in ["iyer", "grace"] else "%s · waiting" % person["name"]
		var highlight := next_task == id or (next_task == "patient" and id.begins_with("patient"))
		hud.set_tag(id, text, camera.unproject_position(head), shown, highlight)


# --- Conversations -------------------------------------------------------

func _start_talk(id: String) -> void:
	_talk_target = ""
	_talking_to = id
	_line_index = 0
	var person: Dictionary = people[id]
	var rig: AvatarRig = person["rig"]
	var to_them := Vector2(rig.position.x - player.position.x, rig.position.z - player.position.z)
	_facing = atan2(to_them.x, to_them.y)
	if not rig.sitting:
		rig.rotation.y = atan2(-to_them.x, -to_them.y)
	_show_line()


func _show_line() -> void:
	var person: Dictionary = people[_talking_to]
	var lines: Array = person["lines"]
	var rig: AvatarRig = person["rig"]
	rig.talking = true
	hud.show_line(person["name"], person["role"], lines[_line_index], _line_index == lines.size() - 1)


func _on_dialogue_next() -> void:
	if _talking_to.is_empty():
		hud.hide_dialogue()
		return
	var person: Dictionary = people[_talking_to]
	var lines: Array = person["lines"]
	_line_index += 1
	if _line_index < lines.size():
		_show_line()
		return
	var rig: AvatarRig = person["rig"]
	rig.talking = false
	if not rig.sitting:
		rig.rotation.y = person["facing"]
	hud.hide_dialogue()
	var finished := _talking_to
	_talking_to = ""
	_complete_task("patient" if finished.begins_with("patient") else finished)


## Sets up a calm, posed moment for the screenshot tool.
func stage_for_screenshot(talking: bool) -> void:
	for person: Dictionary in people.values():
		(person["rig"] as AvatarRig).blink_every = 0.0
	player.blink_every = 0.0
	if talking:
		player.position = Vector3(2.15, 0, -1.05)
		_start_talk("iyer")
	else:
		player.position = Vector3(0.6, 0, 1.4)
		_facing = PI * 0.9
	player.rotation.y = _facing
	_place_camera(1.0)
