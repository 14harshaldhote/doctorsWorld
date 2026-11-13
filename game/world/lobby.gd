class_name Lobby
extends Node3D
## Day 1: the reception of Riverside City Hospital.
##
## The day opens with Dr. Meera Iyer meeting the new doctor at the door with
## a coffee and a pager. Then the player walks around (tap the floor, or WASD
## and arrow keys), meets Sister Grace, says hello to a waiting patient and
## reports back. Nurses and patients chat among themselves nearby.
##
## Conversations come from story/day1.json and play through StoryPlayer, so
## people gesture, nod and murmur while they talk, and replies change trust.
##
## Floor coordinates: x runs left to right, z runs from the back wall (-6)
## towards the camera (+6). The room is open on the camera side.

signal save_requested
signal menu_choice(choice: String)
## Day 1 is over: emitted a moment after Dr. Iyer sends the doctor home.
signal day_finished

const ROOM := Rect2(-8, -6, 16, 12)
const WALK_SPEED := 1.8
const CAMERA_OFFSET := Vector3(0, 3.7, 5.0)
const TALK_DISTANCE := 1.0
const TAP_RADIUS := 70.0
const XP_PER_TASK := 40
const ACTIONS := ["shot", "pager", "start_day"]
## Today's tasks: id, text. Each is remembered as the story flag "day1_<id>".
const TASKS := [
	["grace", "Meet Sister Grace"],
	["patient", "Greet a waiting patient"],
	["iyer", "Report back to Dr. Iyer"],
]
const IYER_POST := Vector3(2.7, 0, -1.9)
## Seconds between Dr. Iyer's goodbye and the end of the day.
const DAY_END_DELAY := 2.5
## Background chatter between other people is only heard up close: at its
## loudest (still soft) within BANTER_NEAR metres of the player, fading out
## by BANTER_FAR, and silent beyond (their mouths still move). While the
## player is in a conversation of their own it is softer again.
const BANTER_NEAR := 1.8
const BANTER_FAR := 4.5
const BANTER_LOUDEST := -20.0
const BANTER_FAINTEST := -36.0
const BANTER_IN_CONVERSATION := -8.0

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
var talk_ui: ConversationUi
var story: StoryPlayer
## True when the day starts with Dr. Iyer meeting the player at the door.
var arrival := false
## People you can talk to: id -> {rig, facing, home}.
var people := {}
## Today's tasks in order: [id, text, done].
var tasks := []
## The conversation running now (a key of story/day1.json) and with whom.
var talking_with := ""
var conversation := ""

var _path := PackedVector2Array()
var _talk_target := ""
var _marker: Node3D
var _marker_time := 0.0
var _press_at := Vector2.ZERO
var _facing := PI
var _camera_target := Vector3.ZERO
var _camera_mode := "follow"
var _camera_speaker := ""
var _banter: Array = []
var _banter_clock := 0.0
var _walking_home: Array[String] = []
var _day_end_in := -1.0


func _init(for_profile: PlayerProfile = null, with_arrival: bool = false) -> void:
	profile = for_profile if for_profile != null else PlayerProfile.new()
	arrival = with_arrival


func _ready() -> void:
	StageLighting.add_to(self, Color("#A9C3C8"), Vector3(-55, 28, 0))
	Music.cue("hospital")
	walk_area = WalkArea.new(Rect2(-7.7, -5.75, 15.4, 11.6), 0.28)
	_build_room()
	_build_reception()
	_build_waiting_area()
	_build_doors_and_corners()
	_build_people()
	player = AvatarRig.new(profile.avatar)
	player.name = "Player"
	player.voice_pitch = 1.08 - 0.04 * profile.avatar.height
	player.position = Vector3(0, 0, 4.6)
	player.rotation.y = _facing
	add_child(player)
	_marker = _build_marker()
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 42
	add_child(camera)
	var layer := CanvasLayer.new()
	layer.name = "HudLayer"
	add_child(layer)
	hud = LobbyHud.new(profile)
	hud.name = "Hud"
	layer.add_child(hud)
	hud.menu_choice.connect(_on_menu_choice)
	talk_ui = ConversationUi.new()
	talk_ui.name = "Conversation"
	talk_ui.mode = ConversationUi.Mode.TALK
	layer.add_child(talk_ui)
	story = StoryPlayer.new(StoryRunner.new(profile), talk_ui, self)
	story.actors = _actors()
	story.finished.connect(_on_talk_finished)
	_load_tasks()
	_update_clock()
	if arrival:
		_begin_arrival()
	else:
		hud.set_pager(_pager_for_progress())
		_refresh_tasks()
	_place_camera(1.0)
	_build_banter()
	StaticBatch.optimise(self)


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
	var iyer_rig := _add_person("iyer", iyer, IYER_POST, -0.6, AvatarConfig.Mood.FOCUSED)
	iyer_rig.hold("coffee", "L")
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
	_add_person("grace", grace, Vector3(-0.7, 0, -4.4), 0.0, AvatarConfig.Mood.HAPPY)
	var nair := AvatarConfig.new()
	nair.skin = 6
	nair.face = 5
	nair.hair_style = 0
	nair.hair_colour = 5
	nair.facial_hair = 2
	nair.body = 2
	nair.height = 1
	nair.scrubs = 7
	nair.coat = false
	nair.stethoscope = false
	_add_person("nair", nair, Vector3(-5.9, 0, -0.2), 0.0, AvatarConfig.Mood.TIRED, "casual").sitting = true
	var leela := AvatarConfig.new()
	leela.skin = 4
	leela.face = 3
	leela.hair_style = 5
	leela.hair_colour = 1
	leela.eyes = 2
	leela.scrubs = 2
	leela.coat = false
	leela.stethoscope = false
	_add_person("leela", leela, Vector3(-5.1, 0, -0.2), 0.0, AvatarConfig.Mood.WORRIED, "kurta").sitting = true
	var aarav := AvatarConfig.new()
	aarav.skin = 4
	aarav.face = 0
	aarav.eyes = 4
	aarav.hair_style = 3
	aarav.hair_colour = 0
	aarav.scrubs = 7
	aarav.coat = false
	aarav.stethoscope = false
	var child := _add_person("aarav", aarav, Vector3(-4.3, 0, -0.2), 0.0, AvatarConfig.Mood.HAPPY, "casual")
	child.sitting = true
	child.scale = Vector3.ONE * 0.64
	var tom := AvatarConfig.new()
	tom.skin = 3
	tom.face = 2
	tom.hair_style = 2
	tom.hair_colour = 0
	tom.facial_hair = 1
	tom.scrubs = 1
	tom.coat = false
	tom.stethoscope = false
	tom.height = 3
	var priya := AvatarConfig.new()
	priya.skin = 6
	priya.face = 3
	priya.hair_style = 8
	priya.hair_colour = 0
	priya.eyes = 7
	priya.scrubs = 2
	priya.coat = false
	priya.stethoscope = false
	priya.watch = true
	var tom_spot := Vector3(6.7, 0, 1.15)
	var priya_spot := Vector3(5.95, 0, 0.7)
	_add_person("tom", tom, tom_spot, atan2(priya_spot.x - tom_spot.x, priya_spot.z - tom_spot.z), AvatarConfig.Mood.HAPPY)
	_add_person("priya", priya, priya_spot, atan2(tom_spot.x - priya_spot.x, tom_spot.z - priya_spot.z),
		AvatarConfig.Mood.CALM)


func _add_person(id: String, look: AvatarConfig, at: Vector3, facing: float, mood: int,
		outfit: String = "doctor") -> AvatarRig:
	var rig := AvatarRig.new(look)
	rig.name = id.capitalize().replace(" ", "")
	rig.outfit = outfit
	rig.position = at
	rig.rotation.y = facing
	rig.mood = mood
	rig.voice_pitch = float(StoryBook.cast().get(id, {}).get("voice", 1.0))
	add_child(rig)
	people[id] = {"rig": rig, "facing": facing, "home": at}
	if outfit == "doctor" or id in ["tom", "priya"]:
		walk_area.add_blocker(Rect2(at.x - 0.25, at.z - 0.25, 0.5, 0.5))
	return rig


func _actors() -> Dictionary:
	var found := {"you": player}
	for id: String in people:
		found[id] = people[id]["rig"]
	return found


func person_name(id: String) -> String:
	return story.runner.display_name(id)


# --- Tasks ---------------------------------------------------------------

func _load_tasks() -> void:
	tasks = []
	for task: Array in TASKS:
		tasks.append([task[0], task[1], profile.has_flag("day1_" + str(task[0]))])


func _refresh_tasks() -> void:
	var list := []
	for task: Array in tasks:
		list.append([task[1], task[2]])
	hud.set_tasks(list)


func task_done(id: String) -> bool:
	for task: Array in tasks:
		if task[0] == id:
			return task[2]
	return false


func _complete_task(id: String) -> void:
	for task: Array in tasks:
		if task[0] == id and not task[2]:
			task[2] = true
			profile.set_flag("day1_" + id)
			profile.total_xp += XP_PER_TASK
			hud.refresh_profile()
			hud.toast("+%d XP · %s" % [XP_PER_TASK, task[1]])
	_refresh_tasks()
	hud.set_pager(_pager_for_progress())


func _pager_for_progress() -> String:
	if task_done("iyer"):
		return "Dr. Iyer: Good. That's Day 1. Go home. Sleep. Come back sharper."
	if task_done("grace") and task_done("patient"):
		return "Dr. Iyer: Done? Come and find me by the theatre doors."
	if task_done("grace"):
		return "Sister Grace: Say hello to the waiting area. Nicely."
	return "Dr. Iyer: Sister Grace is at the desk. Go."


func _update_clock() -> void:
	hud.set_clock("Day %d · %s · First day" % [profile.day, profile.clock_text()])


# --- The arrival: Dr. Iyer at the door -----------------------------------

func _begin_arrival() -> void:
	player.position = Vector3(0.1, 0, 7.4)
	player.rotation.y = PI
	_facing = PI
	player.hold("letter")
	var iyer: AvatarRig = people["iyer"]["rig"]
	iyer.position = Vector3(1.9, 0, 1.6)
	iyer.rotation.y = PI * 0.85
	iyer.hold("pager")
	hud.set_tasks([])
	hud.set_pager("")
	talking_with = "iyer"
	conversation = "arrival"
	story.focus = "iyer"
	hud.set_talking(true)
	story.play(StoryBook.conversation("day1", "arrival"))


## Called from the story when Dr. Iyer has handed over the pager.
func _start_day() -> void:
	profile.set_flag("met_iyer")
	player.drop("L")
	player.drop("R")
	_refresh_tasks()
	hud.set_pager(_pager_for_progress())
	Sfx.play(self, "pager", -8.0)


# --- What the story asks for ---------------------------------------------

func perform(step: Dictionary) -> Variant:
	match str(step["do"]):
		"shot":
			_camera_mode = str(step.get("name", "follow"))
			return 0.0
		"pager":
			hud.set_pager(story.runner.fill(str(step.get("text", ""))))
			Sfx.play(self, "pager", -8.0)
			return 0.4
		"start_day":
			_start_day()
			return 0.0
	return null


func mark(mark_name: String) -> Variant:
	match mark_name:
		"entrance":
			return Vector3(0.1, 0, 4.75)
		"meet":
			return Vector3(0.5, 0, 3.8)
		"iyer_post":
			return IYER_POST
	return null


func on_line(speaker: String, _listener: String) -> void:
	_camera_speaker = speaker
	_camera_mode = "talk"


# --- Conversations -------------------------------------------------------

## The conversation to play when the player talks to someone now.
func conversation_for(id: String) -> String:
	match id:
		"iyer":
			if task_done("iyer"):
				return "iyer_again"
			if task_done("grace") and task_done("patient"):
				return "iyer_report"
			return "iyer_waiting"
		"grace":
			return "grace_again" if task_done("grace") else "grace"
		"nair", "leela":
			return id + "_again" if profile.has_flag("talked_" + id) else id
		"aarav":
			return conversation_for("leela")
	return id


func _start_talk(id: String) -> void:
	_talk_target = ""
	_path = PackedVector2Array()
	var key := conversation_for(id)
	var steps := StoryBook.conversation("day1", key)
	if steps.is_empty():
		return
	var partner := "leela" if id == "aarav" else id
	talking_with = partner
	conversation = key
	var rig: AvatarRig = people[partner]["rig"]
	var to_them := Vector2(rig.position.x - player.position.x, rig.position.z - player.position.z)
	_facing = atan2(to_them.x, to_them.y)
	player.rotation.y = _facing
	player.moving = 0.0
	if not rig.sitting:
		rig.rotation.y = atan2(-to_them.x, -to_them.y)
	story.focus = partner if story.runner.start_trust(partner) >= 0 else ""
	_camera_speaker = partner
	_camera_mode = "talk"
	hud.set_talking(true)
	story.play(steps)


func _on_talk_finished(_skipped: bool) -> void:
	var finished := conversation
	var partner := talking_with
	talking_with = ""
	conversation = ""
	_camera_mode = "follow"
	hud.set_talking(false)
	if people.has(partner):
		var rig: AvatarRig = people[partner]["rig"]
		if not rig.sitting and partner not in ["iyer"]:
			rig.rotation.y = people[partner]["facing"]
	match finished:
		"arrival":
			# Dr. Iyer goes back to her spot by the theatre doors.
			_walk_home("iyer")
		"grace":
			_complete_task("grace")
		"nair", "leela":
			profile.set_flag("talked_" + finished)
			_complete_task("patient")
		"iyer_report":
			_complete_task("iyer")
			_day_end_in = DAY_END_DELAY
	_update_clock()
	save_requested.emit()


func _walk_home(id: String) -> void:
	story.walk(id, people[id]["home"], 1.3)
	_walking_home.append(id)


func is_talking() -> bool:
	return story.is_playing()


# --- Input and movement --------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if story.is_playing() or hud.menu_open():
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
	if story.is_playing():
		return
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
		var head := rig.face_point() + Vector3(0, 0.12, 0)
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
	if rig.sitting:
		# Seated people are greeted from the front.
		away = (Vector2(0, 1) + away * 0.4).normalized()
	_talk_target = id
	if me.distance_to(spot) <= TALK_DISTANCE + 0.3:
		_path = PackedVector2Array()
		_start_talk(id)
		return
	walk_to(walk_area.closest_walkable(spot + away * TALK_DISTANCE))
	if _path.is_empty():
		_start_talk(id)


func _physics_process(delta: float) -> void:
	if player == null or story.is_playing():
		return
	var keys := _key_direction()
	var moved := Vector2.ZERO
	if keys != Vector2.ZERO and not hud.menu_open():
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
				return
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
	story.update(delta)
	_update_banter(delta)
	if _day_end_in > 0.0:
		_day_end_in -= delta
		if _day_end_in <= 0.0:
			# The game moves on to the next day, and this scene goes away.
			day_finished.emit()
			return
	for id: String in _walking_home.duplicate():
		if not story.is_walking(id):
			_walking_home.erase(id)
			(people[id]["rig"] as AvatarRig).rotation.y = people[id]["facing"]
	_place_camera(UiKit.motion_weight(minf(1.0, delta * 4.0)))
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
	var offset := 0.0
	if _camera_mode == "arrival":
		goal = Vector3(-0.6, 2.2, 9.6)
		target = Vector3(0.6, 1.3, 3.2)
	elif _camera_mode == "talk" and people.has(talking_with):
		# A two-shot from the side, leaning towards whoever is speaking, with
		# both people kept left of the reply panel.
		var other: AvatarRig = people[talking_with]["rig"]
		var middle := (focus + other.position) / 2.0
		var across := Vector3(other.position.x - focus.x, 0, other.position.z - focus.z)
		across = across.normalized() if across.length() > 0.01 else Vector3(1, 0, 0)
		var side := Vector3(-across.z, 0, across.x)
		if side.z < -0.05 or (absf(side.z) <= 0.05 and side.x > 0.0):
			side = -side
		if talking_with == "grace":
			# The desk monitor stands on Sister Grace's left.
			side = Vector3(1, 0, 0) if side.x < 0.0 else side
		# From the side and a little in front, so desks don't get in the way.
		var view := (side + Vector3(0, 0, 0.75)).normalized()
		var speaker_spot := focus if _camera_speaker == "you" else other.position
		var lean := middle.lerp(speaker_spot, 0.25)
		var height := 1.0 if other.sitting else 1.22
		goal = middle + view * 3.7 + Vector3(0, 1.85, 0)
		target = lean + Vector3(0, height, 0)
		offset = 0.62
	else:
		focus.x = clampf(focus.x, -5.0, 5.0)
		focus.z = clampf(focus.z, -3.4, 3.6)
		goal = focus + CAMERA_OFFSET
		target = focus + Vector3(0, 0.9, 0)
	_camera_target = _camera_target.lerp(target, weight) if weight < 1.0 else target
	camera.position = camera.position.lerp(goal, weight)
	camera.h_offset = lerpf(camera.h_offset, offset, weight)
	camera.look_at(_camera_target)


func _update_tags() -> void:
	var next_task := ""
	for task: Array in tasks:
		if not task[2]:
			next_task = task[0]
			break
	var started := profile.has_flag("met_iyer")
	for id: String in people:
		var rig: AvatarRig = people[id]["rig"]
		var head := rig.face_point() + Vector3(0, 0.58 * rig.scale.y, 0)
		var shown := not camera.is_position_behind(head) and started
		var text := person_name(id)
		if id in ["nair", "leela"]:
			text += " · waiting"
		var highlight := next_task == id or (next_task == "patient" and id in ["nair", "leela"])
		hud.set_tag(id, text, camera.unproject_position(head), shown, highlight)


func _on_menu_choice(choice: String) -> void:
	if choice != "resume":
		menu_choice.emit(choice)


# --- People chatting among themselves ------------------------------------

func _build_banter() -> void:
	var sets: Array = StoryBook.chapter("banter").get("lobby", [])
	for entry: Dictionary in sets:
		var pair: Array = entry.get("between", [])
		if pair.size() == 2 and people.has(pair[0]) and people.has(pair[1]):
			_banter.append({"pair": pair, "lines": entry.get("lines", []), "index": 0, "time": 0.0,
				"wait": 1.5 + _banter.size() * 2.2, "syllable": 0.0, "vowels": ""})


func _update_banter(delta: float) -> void:
	_banter_clock += delta
	for chat: Dictionary in _banter:
		var pair: Array = chat["pair"]
		var a: AvatarRig = people[pair[0]]["rig"]
		var b: AvatarRig = people[pair[1]]["rig"]
		var busy := story.is_playing() and (talking_with in pair or conversation == "arrival")
		var lines: Array = chat["lines"]
		if busy or lines.is_empty():
			_quiet_banter(chat, a, b)
			continue
		if float(chat["wait"]) > 0.0:
			chat["wait"] = float(chat["wait"]) - delta
			continue
		var line: Array = lines[int(chat["index"]) % lines.size()]
		var speaker: AvatarRig = people[line[0]]["rig"]
		var listener := b if speaker == a else a
		if float(chat["time"]) == 0.0:
			speaker.set_gesture(str(line[2]) if line.size() > 2 else "explain")
			speaker.talking = true
			speaker.look_at_rig(listener)
			listener.look_at_rig(speaker)
			listener.listening = true
			listener.talking = false
			listener.set_gesture("")
			chat["vowels"] = _vowels(str(line[1]))
		chat["time"] = float(chat["time"]) + delta
		# Murmur a syllable every so often while the bubble shows.
		chat["syllable"] = float(chat["syllable"]) - delta
		var vowels: String = chat["vowels"]
		if float(chat["syllable"]) <= 0.0 and float(chat["time"]) < 2.2 and not vowels.is_empty():
			chat["syllable"] = 0.17
			var level := banter_volume(_player_distance(speaker), story.is_playing())
			speaker.voice_volume_db = level
			speaker.say_syllable(vowels[int(float(chat["time"]) / 0.17) % vowels.length()], not is_nan(level))
			# Their own lines in a conversation keep the normal level.
			speaker.voice_volume_db = 0.0
		var head := speaker.face_point() + Vector3(0, 0.62 * speaker.scale.y, 0)
		hud.set_bubble(pair[0] + pair[1], str(line[1]), camera.unproject_position(head),
			not camera.is_position_behind(head))
		if float(chat["time"]) >= 3.2:
			speaker.talking = false
			speaker.set_gesture("")
			chat["time"] = 0.0
			chat["index"] = int(chat["index"]) + 1
			var finished_round: bool = int(chat["index"]) % lines.size() == 0
			chat["wait"] = 7.0 if finished_round else 0.5
			hud.set_bubble(pair[0] + pair[1], "", Vector2.ZERO, false)


## How loud a background murmur is (dB) for a speaker this far from the
## player, or NAN when it is too far away to be heard at all.
static func banter_volume(distance: float, in_conversation: bool = false) -> float:
	if distance > BANTER_FAR:
		return NAN
	var weight := clampf((distance - BANTER_NEAR) / (BANTER_FAR - BANTER_NEAR), 0.0, 1.0)
	var level := lerpf(BANTER_LOUDEST, BANTER_FAINTEST, weight)
	return level + (BANTER_IN_CONVERSATION if in_conversation else 0.0)


func _player_distance(rig: AvatarRig) -> float:
	if player == null or not is_instance_valid(player):
		return INF
	var gap := rig.global_position - player.global_position
	return Vector2(gap.x, gap.z).length()


func _quiet_banter(chat: Dictionary, a: AvatarRig, b: AvatarRig) -> void:
	if float(chat["time"]) > 0.0:
		chat["time"] = 0.0
		for rig: AvatarRig in [a, b]:
			rig.talking = false
			rig.listening = false
			if rig != story._speaker:
				rig.set_gesture("")
	var pair: Array = chat["pair"]
	hud.set_bubble(pair[0] + pair[1], "", Vector2.ZERO, false)


static func _vowels(text: String) -> String:
	var found := ""
	for letter in text.to_lower():
		if letter in "aeiou":
			found += letter
	return found


## The pair chatting now and the line on show, for tests: [speaker, text] or [].
func banter_line(index: int = 0) -> Array:
	if index >= _banter.size():
		return []
	var chat: Dictionary = _banter[index]
	if float(chat["time"]) <= 0.0:
		return []
	var lines: Array = chat["lines"]
	var line: Array = lines[int(chat["index"]) % lines.size()]
	return [line[0], line[1]]


## Sets up a calm, posed moment for the screenshot tool: "walk", "talk"
## (Sister Grace offering replies) or "arrival" (Dr. Iyer at the door).
func stage_for_screenshot(moment: String) -> void:
	match moment:
		"talk":
			player.position = Vector3(-0.55, 0, -2.45)
			_start_talk("grace")
			_advance_to_choice()
		"arrival":
			for frame in 900:
				story.update(1.0 / 30.0)
				if talk_ui.is_choosing():
					break
				if not story.is_busy() and not talk_ui.is_typing():
					talk_ui.tap()
		_:
			player.position = Vector3(0.6, 0, 1.4)
			_facing = PI * 0.9
			player.rotation.y = _facing
			for frame in 150:
				_update_banter(1.0 / 30.0)
	_place_camera(1.0)


func _advance_to_choice() -> void:
	for frame in 600:
		story.update(1.0 / 30.0)
		if talk_ui.is_choosing() or not story.is_playing():
			return
		if not talk_ui.is_typing():
			talk_ui.tap()
