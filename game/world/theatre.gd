class_name Theatre
extends Node3D
## Day 3: Rohit's operation, from the ward to the theatre and back.
##
## The morning starts on the surgical ward with Dr. Iyer. The doctor talks
## to Rohit and his mother at bed four and gets consent (or doesn't hurry
## it), scrubs at the sink with Tom, meets Dr. Khan in Theatre 2, and
## operates in first person. Afterwards the doctor tells Rohit's mother how
## it went, Dr. Iyer has a word, and the day ends.
##
## What the doctor learns on the ward (the allergy, how long the pain has
## gone on, whether to wait) and how well they scrub are passed into the
## operation, which can be won, struggled through or failed.
##
## Floor: x runs from the ward (left) through the scrub corridor to the
## theatre (right); z from the back wall (-4) towards the camera (+4).

signal save_requested
signal menu_choice(choice: String)
signal day_finished

const ACTIONS := []
const WALK_SPEED := 1.8
const PEOPLE_SPEED := 1.5
const XP := {"won": 120, "struggled": 80, "failed": 40}
const XP_PER_STAR := 10
const DAY_END_DELAY := 3.4
## Places on the floor.
const WARD_DOOR := Vector3(-3.9, 0, 1.4)
const BED := Vector3(-6.4, 0, -2.75)
const BED_SPOT := Vector3(-5.05, 0, -1.25)
const SINK := Vector3(-0.7, 0, -3.35)
const THEATRE_DOOR := Vector3(1.6, 0, -0.9)
const TABLE := Vector3(5.6, 0, -0.5)
## Flags from an unfinished Day 3, cleared when the day starts again.
const DAY_FLAGS := ["theatre_morning", "rohit_asked_pain", "rohit_asked_allergy", "rohit_asked_exam", "rohit_pain_day",
	"rohit_allergy_known", "rohit_delayed", "rohit_consent", "op_bleeding", "op_pressure", "op_reaction", "op_burst",
	"op_wrong_side"]

const WALL := Color("#EEF2EC")
const WARD_FLOOR := Color("#D9E2DC")
const THEATRE_WALL := Color("#CFE6E2")
const THEATRE_FLOOR := Color("#B9CFCB")
const TEAL := Color("#127C80")

var profile: PlayerProfile
var walk_area: WalkArea
var player: AvatarRig
var camera: Camera3D
var hud: LobbyHud
var talk_ui: ConversationUi
var overlay: StoryOverlay
var story: StoryPlayer
## id -> {rig, home}.
var people := {}
## "scrub" (the sink) and "appendix" (the operating table).
var stations := {}
## "story", "walk", "approach", "task" or "end".
var mode := "story"
## Where the day has got to: "morning", "consent", "scrub", "theatre",
## "operation", "after" or "end".
var stage := "morning"
var active := ""
var view: TrainingView
var conversation := ""
var talking_with := ""
## The operation, once it has been played.
var operation: OperationTask
var scrub_score := -1
## Extra setup for the operation (tests force a complication or a lost swab).
var operation_setup := {}

var _layer: CanvasLayer
var _routes := {}
var _going_to := ""
var _press_at := Vector2.ZERO
var _pressed := false
var _moved := false
var _camera_target := Vector3.ZERO
var _camera_mode := "follow"
var _camera_speaker := ""
var _intro_in := -1.0
var _clear_in := -1.0
var _next_in := -1.0
var _next := Callable()
var _end_in := -1.0
var _scrub_tries := 0


func _init(for_profile: PlayerProfile = null) -> void:
	profile = for_profile if for_profile != null else PlayerProfile.new()


func _ready() -> void:
	StageLighting.add_to(self, Color("#A9C3C8"), Vector3(-55, 28, 0))
	walk_area = WalkArea.new(Rect2(-9.6, -3.7, 10.8, 7.2), 0.28)
	_build_rooms()
	_build_stations()
	_build_people()
	player = AvatarRig.new(profile.avatar)
	player.name = "Player"
	player.voice_pitch = 1.08 - 0.04 * profile.avatar.height
	add_child(player)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 42
	add_child(camera)
	_layer = CanvasLayer.new()
	_layer.name = "HudLayer"
	add_child(_layer)
	hud = LobbyHud.new(profile)
	hud.name = "Hud"
	_layer.add_child(hud)
	hud.menu_choice.connect(_on_menu_choice)
	talk_ui = ConversationUi.new()
	talk_ui.name = "Conversation"
	talk_ui.mode = ConversationUi.Mode.TALK
	_layer.add_child(talk_ui)
	overlay = StoryOverlay.new(profile)
	overlay.name = "Overlay"
	_layer.add_child(overlay)
	overlay.fade("clear", 0.01)
	story = StoryPlayer.new(StoryRunner.new(profile), talk_ui, self)
	story.actors = _actors()
	story.finished.connect(_on_talk_finished)
	_begin_day()
	_place_camera(1.0)


# --- The rooms --------------------------------------------------------------

func _build_rooms() -> void:
	# Floors: ward and corridor, then the theatre's darker green floor.
	LowPoly.put(self, LowPoly.box(Vector3(11.4, 0.1, 8.0), WARD_FLOOR), Vector3(-4.5, -0.05, 0))
	LowPoly.put(self, LowPoly.box(Vector3(9.0, 0.1, 8.0), THEATRE_FLOOR), Vector3(5.7, -0.05, 0))
	for ix in 5:
		for iz in 4:
			if (ix + iz) % 2 == 0:
				LowPoly.put(self, LowPoly.box(Vector3(1.9, 0.01, 1.9), WARD_FLOOR.darkened(0.05)), Vector3(-9.2 + ix * 2.0 + 0.95, 0.005, -3.0 + iz * 2.0))
	# Back wall all along, side walls, and the wall between corridor and theatre.
	LowPoly.put(self, LowPoly.box(Vector3(20.6, 3.2, 0.2), WALL), Vector3(0.1, 1.6, -4.1))
	LowPoly.put(self, LowPoly.box(Vector3(9.2, 3.2, 0.22), THEATRE_WALL), Vector3(5.7, 1.6, -3.98))
	LowPoly.put(self, LowPoly.box(Vector3(20.6, 0.16, 0.24), TEAL), Vector3(0.1, 0.08, -3.98))
	for x: float in [-10.2, 10.2]:
		LowPoly.put(self, LowPoly.box(Vector3(0.2, 3.2, 8.0), WALL.darkened(0.04)), Vector3(x, 1.6, 0))
	# The theatre wall, with a doorway near the front.
	LowPoly.put(self, LowPoly.box(Vector3(0.22, 3.2, 2.5), THEATRE_WALL.darkened(0.05)), Vector3(1.4, 1.6, -2.75))
	LowPoly.put(self, LowPoly.box(Vector3(0.22, 3.2, 3.5), THEATRE_WALL.darkened(0.05)), Vector3(1.4, 1.6, 2.25))
	LowPoly.put(self, LowPoly.box(Vector3(0.24, 0.6, 1.9), THEATRE_WALL.darkened(0.1)), Vector3(1.4, 2.9, -0.55))
	var door_sign := LabStation.label3d("THEATRE 2", 60, TEAL)
	door_sign.position = Vector3(1.27, 2.45, -0.55)
	door_sign.rotation.y = -PI / 2
	add_child(door_sign)
	var light := LowPoly.box(Vector3(0.05, 0.12, 0.32), Color("#FF6B6B"))
	light.material_override = LowPoly.glow(Color("#FF6B6B"), 1.0)
	LowPoly.put(self, light, Vector3(1.27, 2.75, -0.55))
	var ward_sign := LabStation.label3d("SURGICAL WARD · BEDS 1 TO 6", 54, TEAL)
	ward_sign.position = Vector3(-6.0, 2.6, -3.98)
	add_child(ward_sign)
	var scrub_sign := LabStation.label3d("SCRUB", 54, TEAL)
	scrub_sign.position = Vector3(-0.7, 2.6, -3.98)
	add_child(scrub_sign)
	var motto := LabStation.label3d("Two minutes. Every finger. Every time.", 30, TEAL.lightened(0.2))
	motto.position = Vector3(-0.7, 2.32, -3.98)
	add_child(motto)
	_build_ward()
	_build_theatre_room()


func _build_ward() -> void:
	# Bed four (Rohit's) and the empty bed three, with curtain rails and a window.
	for at: Vector3 in [BED, BED + Vector3(-2.6, 0, 0)]:
		var bed := LowPoly.joint(self, "Bed", at)
		LowPoly.put(bed, LowPoly.box(Vector3(0.95, 0.12, 2.0), Color("#C9D6DA")), Vector3(0, 0.5, 0))
		LowPoly.put(bed, LowPoly.box(Vector3(0.9, 0.14, 1.94), Color("#F4F7F7")), Vector3(0, 0.62, 0))
		LowPoly.put(bed, LowPoly.box(Vector3(0.6, 0.1, 0.36), Color("#FFFFFF")), Vector3(0, 0.74, -0.72))
		LowPoly.put(bed, LowPoly.box(Vector3(0.92, 0.04, 1.2), Color("#9CC7D9")), Vector3(0, 0.7, 0.32))
		LowPoly.put(bed, LowPoly.box(Vector3(1.0, 0.7, 0.06), Color("#8FA1A6")), Vector3(0, 0.75, -1.0))
		for x: float in [-0.42, 0.42]:
			for z: float in [-0.9, 0.9]:
				LowPoly.put(bed, LowPoly.cylinder(0.02, 0.02, 0.44, 6, Color("#8FA1A6")), Vector3(x, 0.22, z))
		LowPoly.put(bed, LowPoly.shadow_blob(1.0, Vector2(0.55, 1.0)), Vector3.ZERO)
		walk_area.add_blocker(Rect2(at.x - 0.55, at.z - 1.1, 1.1, 2.2))
	var rail := LowPoly.joint(self, "Curtains", Vector3(BED.x, 0, BED.z))
	LowPoly.put(rail, LowPoly.box(Vector3(0.04, 2.6, 2.4), Color("#BFE3E8")), Vector3(-1.25, 1.4, 0.1))
	LowPoly.put(rail, LowPoly.box(Vector3(2.5, 0.04, 0.04), Color("#8FA1A6")), Vector3(0, 2.7, 1.3))
	# A bedside locker with flowers, and a chair for visitors.
	var locker := LowPoly.joint(self, "Locker", BED + Vector3(0.85, 0, -0.75))
	LowPoly.put(locker, LowPoly.box(Vector3(0.45, 0.7, 0.42), Color("#E2C7A4")), Vector3(0, 0.35, 0))
	LowPoly.put(locker, LowPoly.cylinder(0.05, 0.04, 0.16, 7, Color("#BFE7F0")), Vector3(0.05, 0.78, 0))
	for index in 3:
		LowPoly.put(locker, LowPoly.sphere(0.04, [Color("#F07C5A"), Color("#F5B841"), Color("#F48FB1")][index], 6, 4),
			Vector3(0.0 + index * 0.04, 0.9 + 0.02 * index, 0.01 * index))
	LowPoly.put(locker, LowPoly.box(Vector3(0.16, 0.03, 0.22), Color("#3A6FB0")), Vector3(-0.1, 0.72, 0.05))
	walk_area.add_blocker(Rect2(BED.x + 0.6, BED.z - 1.0, 0.5, 0.5))
	var chair := LowPoly.joint(self, "Chair", BED + Vector3(1.25, 0, 0.35), Vector3(0, -PI / 2, 0))
	LowPoly.put(chair, LowPoly.box(Vector3(0.46, 0.06, 0.46), Color("#5FB7A6")), Vector3(0, 0.45, 0))
	LowPoly.put(chair, LowPoly.box(Vector3(0.46, 0.5, 0.06), Color("#5FB7A6")), Vector3(0, 0.72, -0.21))
	for x: float in [-0.19, 0.19]:
		for z: float in [-0.19, 0.19]:
			LowPoly.put(chair, LowPoly.cylinder(0.018, 0.018, 0.44, 6, Color("#8FA1A6")), Vector3(x, 0.22, z))
	var window := LowPoly.joint(self, "Window", Vector3(-7.8, 1.7, -3.98))
	LowPoly.put(window, LowPoly.box(Vector3(1.6, 1.1, 0.04), Color("#BFE7F0")), Vector3.ZERO)
	LowPoly.put(window, LowPoly.box(Vector3(1.7, 0.08, 0.06), WALL.darkened(0.15)), Vector3(0, -0.58, 0.02))
	LowPoly.put(window, LowPoly.box(Vector3(0.05, 1.1, 0.05), WALL.darkened(0.1)), Vector3(0, 0, 0.02))
	# A plant by the ward door.
	var plant := LowPoly.joint(self, "Plant", Vector3(-2.9, 0, -3.5))
	LowPoly.put(plant, LowPoly.cylinder(0.2, 0.15, 0.36, 7, Color("#E2E8E8")), Vector3(0, 0.18, 0))
	LowPoly.put(plant, LowPoly.sphere(0.3, Color("#3E8E5A"), 6, 4), Vector3(0, 0.55, 0))
	LowPoly.put(plant, LowPoly.sphere(0.22, Color("#4FA56B"), 6, 4), Vector3(0.12, 0.78, 0.05))
	walk_area.add_blocker(Rect2(-3.3, -3.9, 0.8, 0.8))


func _build_theatre_room() -> void:
	# Tiles up the back wall and a big clock: theatres always have a clock.
	for row in 3:
		for column in 8:
			if (row + column) % 2 == 0:
				LowPoly.put(self, LowPoly.box(Vector3(0.9, 0.5, 0.01), THEATRE_WALL.darkened(0.06)),
					Vector3(2.4 + column * 1.0, 0.6 + row * 0.55, -3.86))
	var clock := LowPoly.joint(self, "Clock", Vector3(7.6, 2.5, -3.86))
	LowPoly.put(clock, LowPoly.cylinder(0.26, 0.26, 0.05, 14, Color.WHITE), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	LowPoly.put(clock, LowPoly.torus(0.24, 0.28, TEAL, 16, 3), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	LowPoly.put(clock, LowPoly.box(Vector3(0.025, 0.16, 0.01), UiKit.INK), Vector3(0, 0.07, 0.035))
	var board := LowPoly.joint(self, "Whiteboard", Vector3(3.4, 1.7, -3.86))
	LowPoly.put(board, LowPoly.box(Vector3(1.3, 0.8, 0.03), Color("#FBFAF5")), Vector3.ZERO)
	var lines := LabStation.label3d("THEATRE 2 · LIST\n1. Appendix · R. Kulkarni", 26, UiKit.INK, 0.0032)
	lines.position = Vector3(0, 0.05, 0.03)
	board.add_child(lines)
	# The instrument trolley Tom works from.
	var trolley := LowPoly.joint(self, "BackTable", TABLE + Vector3(1.55, 0, 1.1))
	LabStation.table(trolley, Vector3(0.9, 0.9, 0.55), Color("#3E8E7A"))
	for index in 6:
		var model := Instruments.make(Instruments.ALL[index])
		model.scale = Vector3.ONE * 1.2
		LowPoly.put(trolley, model, Vector3(-0.32 + index * 0.13, 0.91, 0.0))
	for index in 4:
		LowPoly.put(trolley, LowPoly.box(Vector3(0.07, 0.01, 0.06), Color("#F4F4F0")), Vector3(0.3, 0.91 + index * 0.012, 0.18))


func _build_stations() -> void:
	var sink := ScrubSink.new(profile.avatar)
	sink.position = SINK
	add_child(sink)
	stations["scrub"] = sink
	for rect in sink.blockers():
		walk_area.add_blocker(rect)
	var table := OperatingTable.new(profile.avatar)
	table.position = TABLE
	add_child(table)
	stations["appendix"] = table


func station_for(id: String) -> LabStation:
	return stations.get(id)


# --- People -----------------------------------------------------------------

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
	_add_person("iyer", iyer, WARD_DOOR + Vector3(-0.9, 0, -0.9), AvatarConfig.Mood.FOCUSED)
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
	_add_person("tom", tom, SINK + Vector3(1.1, 0, 0.7), AvatarConfig.Mood.HAPPY)
	var khan := AvatarConfig.new()
	khan.skin = 4
	khan.face = 4
	khan.hair_style = 10
	khan.hair_colour = 0
	khan.brows = 1
	khan.scrubs = 3
	khan.coat = false
	khan.stethoscope = true
	khan.height = 2
	_add_person("khan", khan, TABLE + Vector3(-1.45, 0, 0.25), AvatarConfig.Mood.FOCUSED)
	var rohit := AvatarConfig.new()
	rohit.skin = 6
	rohit.face = 4
	rohit.body = 0
	rohit.height = 3
	rohit.hair_style = 3
	rohit.hair_colour = 0
	rohit.brows = 2
	rohit.coat = false
	rohit.stethoscope = false
	var rohit_rig := _add_person("rohit", rohit, BED + Vector3(0.36, 0.2, 0.25), AvatarConfig.Mood.TIRED, "patient")
	rohit_rig.sitting = true
	rohit_rig.rotation.y = PI / 2
	var sunita := AvatarConfig.new()
	sunita.skin = 6
	sunita.face = 0
	sunita.body = 1
	sunita.height = 1
	sunita.hair_style = 8
	sunita.hair_colour = 1
	sunita.brows = 4
	sunita.scrubs = 4
	sunita.coat = false
	sunita.stethoscope = false
	var mother := _add_person("sunita", sunita, BED + Vector3(1.25, 0, 0.35), AvatarConfig.Mood.WORRIED, "kurta")
	mother.sitting = true
	mother.rotation.y = -PI / 2


func _add_person(id: String, look: AvatarConfig, at: Vector3, mood: int, outfit: String = "doctor") -> AvatarRig:
	var rig := AvatarRig.new(look)
	rig.name = id.capitalize()
	rig.outfit = outfit
	rig.position = at
	rig.mood = mood
	rig.voice_pitch = float(StoryBook.cast().get(id, {}).get("voice", 1.0))
	add_child(rig)
	people[id] = {"rig": rig, "home": at}
	return rig


func _actors() -> Dictionary:
	var found := {"you": player}
	for id: String in people:
		found[id] = people[id]["rig"]
	return found


func rig_for(id: String) -> AvatarRig:
	if id == "you":
		return player
	return people[id]["rig"] if people.has(id) else null


## A theatre cap and a mask, for the team in Theatre 2, over a surgical gown
## and gloves when gowned (the surgeons and the scrub nurse).
static func dress_for_theatre(rig: AvatarRig, gowned: bool = true) -> void:
	if gowned and rig.outfit != "theatre":
		rig.outfit = "theatre"
		rig.build()
	var head := rig.joint("Head")
	if head == null or head.has_node("TheatreCap"):
		return
	var cap := LowPoly.sphere(0.215, Color("#7DA7D6"), 9, 5, true, "TheatreCap")
	LowPoly.put(head, cap, Vector3(0, 0.2, 0.0), Vector3(-0.15, 0, 0), Vector3(1.0, 0.72, 1.06))
	# Half a dome over the nose, mouth and chin, its open side towards the ears.
	var mask := LowPoly.sphere(AvatarRig.HEAD_RADIUS * 1.1, Color("#9FC6E8"), 10, 4, true, "Mask")
	LowPoly.put(head, mask, Vector3(0, 0.058, 0.015), Vector3(PI / 2, 0, 0), Vector3(1.12, 1.08, 0.33))
	for side: int in [-1, 1]:
		LowPoly.put(head, LowPoly.box(Vector3(0.008, 0.008, 0.16), Color("#E8F4F8")),
			Vector3(0.188 * side, 0.12, -0.04), Vector3(0.35, 0, 0))


## Back into everyday clothes after theatre.
static func undress_from_theatre(rig: AvatarRig) -> void:
	if rig.outfit == "theatre":
		rig.outfit = "doctor"
		rig.build()
		return
	var head := rig.joint("Head")
	for part_name: String in ["TheatreCap", "Mask"]:
		if head != null and head.has_node(part_name):
			head.get_node(part_name).free()


func _place(id: String, at: Vector3, facing_point: Vector3) -> void:
	var rig := rig_for(id)
	if rig == null:
		return
	_routes.erase(id)
	rig.position = at
	rig.moving = 0.0
	rig.sitting = false
	rig.rotation.y = atan2(facing_point.x - at.x, facing_point.z - at.z)


# --- The day ----------------------------------------------------------------

func _begin_day() -> void:
	for flag: String in DAY_FLAGS:
		profile.set_flag(flag, false)
	stage = "morning"
	mode = "story"
	hud.set_talking(true)
	overlay.card("Day %d · %s" % [profile.day, profile.clock_text()], "Surgical ward · Theatre day", 2.6)
	_clear_in = 2.0
	_intro_in = 2.5
	_place("you", WARD_DOOR, WARD_DOOR + Vector3(-1, 0, -1))
	_place("iyer", WARD_DOOR + Vector3(-0.9, 0, -1.0), WARD_DOOR)
	(people["tom"]["rig"] as AvatarRig).visible = false
	(people["khan"]["rig"] as AvatarRig).visible = false
	_refresh_hud()


func _refresh_hud() -> void:
	var rows := [
		["Get Rohit's consent", profile.has_flag("rohit_consent")],
		["Scrub in", scrub_score >= 0],
		["Operate", operation != null],
		["Talk to his mother", stage == "end"],
	]
	hud.set_tasks(rows, "Theatre day")
	hud.set_pager(_pager_text())
	hud.set_clock("Day %d · %s · %s" % [profile.day, profile.clock_text(), _place_name()])
	match stage:
		"consent":
			hud.set_hint("Tap Rohit's bed to talk to him · tap the floor to walk")
		"scrub":
			hud.set_hint("Tap the scrub sink · tap the floor to walk")
		_:
			hud.set_hint("")


func _place_name() -> String:
	match stage:
		"theatre", "operation":
			return "Theatre 2"
		"scrub":
			return "Scrub room"
	return "Surgical ward"


func _pager_text() -> String:
	match stage:
		"consent":
			return "Dr. Iyer: Bed four. Consent first. Be kind, be clear."
		"scrub":
			return "Tom: Sink's free when you are. Patient's going to sleep."
	return ""


func _talk(key: String, partner: String) -> void:
	var steps := StoryBook.conversation("theatre", key)
	mode = "story"
	conversation = key
	talking_with = partner
	story.focus = partner if story.runner.start_trust(partner) >= 0 else ""
	_camera_speaker = partner
	if _camera_mode != "theatre":
		_camera_mode = "talk"
	hud.set_talking(true)
	story.play(steps)


func _on_talk_finished(_skipped: bool) -> void:
	var finished := conversation
	conversation = ""
	talking_with = ""
	match finished:
		"morning":
			stage = "consent"
			_back_to_walking()
		"consent":
			_after_consent()
		"scrub":
			open_task("scrub")
		"khan_intro":
			open_task("appendix")
		_:
			if finished.begins_with("after_"):
				_talk("debrief_" + operation.outcome, "iyer")
				return
			if finished.begins_with("debrief_"):
				_end_day()
	save_requested.emit()


func _back_to_walking() -> void:
	mode = "walk"
	active = ""
	_camera_mode = "follow"
	hud.set_talking(false)
	_refresh_hud()


func _after_consent() -> void:
	profile.set_flag("rohit_consent")
	stage = "scrub"
	var tom: AvatarRig = people["tom"]["rig"]
	tom.visible = true
	_place("tom", SINK + Vector3(1.15, 0, 0.75), SINK + Vector3(0, 0, 1.0))
	_send("iyer", THEATRE_DOOR + Vector3(0.8, 0, 0.2), PEOPLE_SPEED)
	if profile.has_flag("rohit_delayed"):
		# The afternoon: the pain is worse and the list has waited.
		profile.minutes = maxi(profile.minutes, 14 * 60 - 10)
		overlay.card(profile.clock_text(), "Rohit's pain is worse. Theatre 2 is ready.", 2.8)
		_clear_in = 2.2
	_back_to_walking()


# --- Walking ------------------------------------------------------------------

## A tap in the world: the bed, the sink, or the floor.
func tap(screen_point: Vector2) -> void:
	if view != null:
		if not view.result_open():
			view.world_tap(screen_point)
		return
	if mode != "walk" and mode != "approach":
		return
	var found := place_at(screen_point)
	if not found.is_empty():
		go_to(found)
		return
	var floor_point: Variant = LabStation.ray_to_height(camera, screen_point, 0.0)
	if floor_point == null:
		return
	mode = "walk"
	_going_to = ""
	var point := floor_point as Vector3
	_send("you", Vector3(point.x, 0, point.z), WALK_SPEED)


## The thing to walk to under a screen point ("bed" or "sink"), or "".
func place_at(screen_point: Vector2) -> String:
	var best := ""
	var best_distance := UiKit.px(44)
	for key: String in _places_open():
		var point := _tag_point(key)
		if camera.is_position_behind(point):
			continue
		var distance := camera.unproject_position(point).distance_to(screen_point)
		if distance < best_distance:
			best_distance = distance
			best = key
	return best


func _places_open() -> Array[String]:
	match stage:
		"consent":
			return ["bed"]
		"scrub":
			return ["sink"]
	return []


func _tag_point(key: String) -> Vector3:
	match key:
		"bed":
			return BED + Vector3(0.4, 1.35, 0.3)
		"sink":
			return SINK + Vector3(0, 1.55, 0.1)
	return Vector3.ZERO


## Walks to the bed (consent) or the sink (scrub in).
func go_to(key: String) -> void:
	if key not in _places_open() or story.is_playing():
		return
	mode = "approach"
	_going_to = key
	var spot := BED_SPOT if key == "bed" else (stations["scrub"] as LabStation).at((stations["scrub"] as LabStation).spot)
	_send("you", spot, WALK_SPEED)
	if key == "bed":
		_send("iyer", BED_SPOT + Vector3(0.75, 0, 0.55), PEOPLE_SPEED)
	if not _routes.has("you"):
		_arrive()


func _arrive() -> void:
	var key := _going_to
	_going_to = ""
	player.moving = 0.0
	match key:
		"bed":
			var mother: AvatarRig = people["sunita"]["rig"]
			player.rotation.y = atan2(mother.position.x - player.position.x, mother.position.z - player.position.z)
			_talk("consent", "sunita")
		"sink":
			player.rotation.y = PI
			_talk("scrub", "tom")


func _send(id: String, to: Vector3, speed: float) -> void:
	var rig := rig_for(id)
	if rig == null:
		return
	var start := Vector2(rig.position.x, rig.position.z)
	var goal := Vector2(to.x, to.z)
	var path := walk_area.find_path(start, goal)
	if path.is_empty() and start.distance_to(goal) > 0.05:
		path.append(goal)
	elif not path.is_empty() and path[path.size() - 1].distance_to(goal) > 0.05:
		path.append(goal)
	if path.is_empty():
		_routes.erase(id)
		return
	rig.sitting = false
	_routes[id] = {"path": path, "speed": speed}


func is_walking(id: String) -> bool:
	return _routes.has(id)


func _update_routes(delta: float) -> void:
	for id: String in _routes.keys():
		if not _routes.has(id):
			continue
		var rig := rig_for(id)
		var route: Dictionary = _routes[id]
		var path: PackedVector2Array = route["path"]
		var me := Vector2(rig.position.x, rig.position.z)
		var step := float(route["speed"]) * delta
		var moved := Vector2.ZERO
		while step > 0.0 and not path.is_empty():
			var to_next := path[0] - me
			if to_next.length() <= step:
				me = path[0]
				moved += to_next
				step -= to_next.length()
				path.remove_at(0)
			else:
				moved += to_next.normalized() * step
				me += to_next.normalized() * step
				step = 0.0
		rig.position = Vector3(me.x, rig.position.y, me.y)
		if moved.length() > 0.0001:
			rig.rotation.y = lerp_angle(rig.rotation.y, atan2(moved.x, moved.y), minf(1.0, delta * 10.0))
		rig.moving = 1.0
		route["path"] = path
		if path.is_empty():
			rig.moving = 0.0
			_routes.erase(id)
			if id == "you" and mode == "approach":
				_arrive()
			elif id != "you" and mode == "story" and conversation == "consent":
				rig.rotation.y = atan2(player.position.x - rig.position.x, player.position.z - rig.position.z)


# --- Tasks: the scrub and the operation ---------------------------------------

## Opens the scrub ("scrub") or the operation ("appendix") with its screen.
func open_task(id: String) -> void:
	active = id
	mode = "task"
	var station: LabStation = stations[id]
	var task: TrainingTask
	if id == "scrub":
		_scrub_tries += 1
		task = ScrubTask.new()
		view = ScrubView.new(task, self)
		view.trainer = "tom"
		view.done_text = "Into theatre"
		player.visible = false
		_place("tom", station.at(Vector3(-1.05, 0, 0.5)), station.at(station.spot))
	else:
		stage = "operation"
		operation = OperationTask.new(7 + profile.day * 3, {
			"allergy_known": profile.has_flag("rohit_allergy_known"),
			"delayed": profile.has_flag("rohit_delayed"),
			"scrub": maxi(0, scrub_score),
			"called": profile.called(),
		}.merged(operation_setup, true))
		task = operation
		view = OperationView.new(task, self, profile)
		player.visible = false
	view.name = "Training"
	_layer.add_child(view)
	_layer.move_child(view, talk_ui.get_index())
	view.leave_pressed.connect(_on_leave)
	view.retry_pressed.connect(_on_retry)
	view.done_pressed.connect(_on_done)
	view.task_finished.connect(_on_task_finished)
	station.reset_task(task)
	hud.set_talking(true)
	_camera_mode = "close"


func _on_task_finished(task: TrainingTask) -> void:
	if task.id == "scrub":
		scrub_score = maxi(scrub_score, task.score())
		profile.pass_minutes(8)
		view.show_result("Ready for theatre" if task.score() >= 65 else "Tom raises an eyebrow")
		_refresh_hud()
		return
	var op := task as OperationTask
	var xp := int(XP[op.outcome]) + XP_PER_STAR * op.stars()
	profile.total_xp += xp
	profile.record_score("appendix", op.score())
	profile.set_flag("op_rohit_done")
	profile.set_flag("op_rohit_" + op.outcome)
	for which: String in ["bleeding", "pressure", "reaction", "burst", "wrong_side"]:
		profile.set_flag("op_" + which, which in op.happened)
	var trust := {"won": 5, "struggled": 1, "failed": -3}
	profile.change_trust("iyer", int(trust[op.outcome]), story.runner.start_trust("iyer"))
	if op.decisions_wrong == 0 and ("pressure" in op.happened or "reaction" in op.happened):
		profile.change_trust("khan", 3, story.runner.start_trust("khan"))
	profile.pass_minutes(55 if op.outcome == "won" else 80)
	view.show_result("+%d XP" % xp)
	hud.refresh_profile()
	_refresh_hud()
	save_requested.emit()


func _close_task() -> void:
	if view != null:
		_layer.remove_child(view)
		view.queue_free()
		view = null
	player.visible = true
	active = ""


func _on_leave() -> void:
	# Only the scrub can be left: back to the corridor.
	if active == "scrub":
		_close_task()
		_back_to_walking()


func _on_retry() -> void:
	if active == "scrub":
		_close_task()
		open_task("scrub")


func _on_done() -> void:
	var was := active
	_close_task()
	if was == "scrub":
		_enter_theatre()
	else:
		_after_operation()


## Into Theatre 2: everyone gowned, masked and in place, and Dr. Khan.
func _enter_theatre() -> void:
	stage = "theatre"
	mode = "story"
	overlay.fade("black", 0.01)
	overlay.fade("clear", 0.8)
	var table: OperatingTable = stations["appendix"]
	_place("you", table.at(table.spot + Vector3(0, 0, 0.12)), table.at(Vector3(0.2, 0, 0)))
	_place("iyer", table.at(Vector3(0.18, 0, -0.66)), table.at(Vector3(0.2, 0, 0)))
	_place("tom", table.at(Vector3(0.95, 0, 0.62)), table.at(Vector3(0.3, 0, 0)))
	_place("khan", table.at(Vector3(-1.3, 0, 0.3)), table.at(Vector3(0, 0, 0)))
	for id: String in ["you", "iyer", "tom", "khan"]:
		var rig := rig_for(id)
		rig.visible = true
		dress_for_theatre(rig, id != "khan")
	_camera_mode = "theatre"
	_refresh_hud()
	_talk("khan_intro", "khan")


func _after_operation() -> void:
	stage = "after"
	mode = "story"
	overlay.fade("black", 0.01)
	overlay.fade("clear", 0.9)
	# Back on the ward: his mother by the empty bed, Dr. Iyer beside the doctor.
	(people["rohit"]["rig"] as AvatarRig).visible = false
	(people["tom"]["rig"] as AvatarRig).visible = false
	(people["khan"]["rig"] as AvatarRig).visible = false
	for id: String in ["you", "iyer", "tom", "khan"]:
		undress_from_theatre(rig_for(id))
	var mother_at := BED + Vector3(1.0, 0, 0.9)
	_place("sunita", mother_at, BED_SPOT)
	_place("you", BED_SPOT, mother_at)
	_place("iyer", BED_SPOT + Vector3(0.8, 0, 0.45), mother_at)
	_camera_mode = "talk"
	_refresh_hud()
	_talk("after_" + operation.outcome, "sunita")


func _end_day() -> void:
	stage = "end"
	mode = "end"
	hud.set_talking(true)
	var where := {"won": "Rohit is asleep on the ward, minus one appendix.",
		"struggled": "Rohit is in recovery, stable.",
		"failed": "Rohit is in intensive care for the night."}
	overlay.card("Day %d · %s" % [profile.day, profile.clock_text()], str(where.get(operation.outcome, "")), DAY_END_DELAY)
	_end_in = DAY_END_DELAY
	_refresh_hud()
	save_requested.emit()


## True while a task screen (the scrub or the operation) is open.
func in_task() -> bool:
	return view != null


func is_talking() -> bool:
	return story.is_playing()


# --- Story hooks --------------------------------------------------------------

func perform(_step: Dictionary) -> Variant:
	return null


func mark(_mark_name: String) -> Variant:
	return null


func on_line(speaker: String, _listener: String) -> void:
	_camera_speaker = speaker


# --- Input --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if hud.menu_open():
		return
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_press_at = button.position
			_pressed = true
			_moved = false
			if view != null and not view.result_open():
				view.world_press(button.position)
		else:
			_pressed = false
			if view != null and not view.result_open():
				view.world_release(button.position)
			if button.position.distance_to(_press_at) < 24.0:
				tap(button.position)
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _pressed and view != null and not view.result_open():
		view.world_move(motion.position)
		view.world_drag(motion.relative)


func _on_menu_choice(choice: String) -> void:
	if choice == "sound":
		save_requested.emit()
		return
	if choice != "resume":
		menu_choice.emit(choice)


# --- Every frame --------------------------------------------------------------

func _process(delta: float) -> void:
	update(delta)


## Time passes only here, so tests and the screenshot tool can play the day.
func update(delta: float) -> void:
	overlay.tick(delta)
	if _clear_in > 0.0:
		_clear_in -= delta
		if _clear_in <= 0.0:
			overlay.fade("clear", 0.8)
	if _intro_in > 0.0:
		_intro_in -= delta
		if _intro_in <= 0.0:
			_talk("morning", "iyer")
	if _end_in > 0.0:
		_end_in -= delta
		if _end_in <= 0.0:
			day_finished.emit()
			return
	story.update(delta)
	_update_routes(delta)
	if view != null:
		view.tick(delta)
		var station: LabStation = stations.get(active)
		if station != null and view != null:
			station.show_task(view.task, delta)
	_place_camera(minf(1.0, delta * 4.0))
	_update_tags()


func settle_camera() -> void:
	_place_camera(1.0)
	_update_tags()


func _place_camera(weight: float) -> void:
	var goal: Vector3
	var target: Vector3
	var offset := 0.0
	var fov := 42.0
	if _camera_mode == "close" and not active.is_empty():
		var station: LabStation = stations[active]
		goal = station.at(station.close_from)
		target = station.at(station.close_at)
		fov = station.close_fov
		offset = station.close_offset
	elif _camera_mode == "theatre":
		# The team round the table, from the corner by the door.
		goal = TABLE + Vector3(-1.6, 2.5, 3.3)
		target = TABLE + Vector3(0.2, 1.0, -0.2)
		var speaker := rig_for(_camera_speaker)
		if speaker != null:
			target = target.lerp(speaker.position + Vector3(0, 1.3, 0), 0.35)
		fov = 44.0
	elif _camera_mode == "talk" and people.has(talking_with):
		var me := player.position
		var other: AvatarRig = people[talking_with]["rig"]
		var middle := (me + other.position) / 2.0
		var across := Vector3(other.position.x - me.x, 0, other.position.z - me.z)
		across = across.normalized() if across.length() > 0.01 else Vector3(1, 0, 0)
		var side := Vector3(-across.z, 0, across.x)
		if side.z < -0.05 or (absf(side.z) <= 0.05 and side.x > 0.0):
			side = -side
		var looking := (side + Vector3(0, 0, 0.75)).normalized()
		var speaker_spot := me if _camera_speaker == "you" else other.position
		var lean := middle.lerp(speaker_spot, 0.25)
		var height := 1.0 if other.sitting else 1.22
		goal = middle + looking * 3.9 + Vector3(0, 1.9, 0)
		target = lean + Vector3(0, height, 0)
		offset = 0.62
	else:
		var focus := player.position
		focus.x = clampf(focus.x, -6.8, -1.0)
		focus.z = clampf(focus.z, -1.2, 1.2)
		goal = focus + Vector3(0, 5.6, 6.6)
		target = focus + Vector3(0, 0.3, -1.6)
	_camera_target = _camera_target.lerp(target, weight) if weight < 1.0 else target
	camera.position = camera.position.lerp(goal, weight) if weight < 1.0 else goal
	camera.h_offset = lerpf(camera.h_offset, offset, weight)
	camera.fov = lerpf(camera.fov, fov, weight)
	camera.look_at(_camera_target)


func _update_tags() -> void:
	var walking := mode == "walk" or mode == "approach"
	for key: String in ["bed", "sink"]:
		var point := _tag_point(key)
		var open := key in _places_open()
		var text := "Rohit · bed 4" if key == "bed" else "Scrub in"
		hud.set_tag("place_" + key, text, camera.unproject_position(point),
			walking and open and not camera.is_position_behind(point), true)


# --- For tests and screenshots ------------------------------------------------

## Jumps to a moment of the day for tests and screenshots: "consent" (at
## the bed), "scrub" (at the sink) or "operation" (the table, task open).
## flags are set first (rohit_allergy_known, rohit_delayed...).
func skip_to(moment: String, flags: Array = [], scrub: int = 90) -> void:
	_intro_in = -1.0
	_clear_in = -1.0
	overlay.fade("clear", 0.01)
	if story.is_playing():
		story.skip()
	for flag: String in flags:
		profile.set_flag(flag)
	profile.set_flag("theatre_morning")
	match moment:
		"consent":
			stage = "consent"
			_back_to_walking()
		"scrub":
			_after_consent()
			_place("iyer", THEATRE_DOOR + Vector3(0.8, 0, 0.2), SINK)
		"operation":
			profile.set_flag("rohit_consent")
			scrub_score = scrub
			(people["tom"]["rig"] as AvatarRig).visible = true
			_enter_theatre()
			story.skip()
	settle_camera()


## A reply picker that takes the first offered reply whose tone is in
## tones (in that order of preference), else the first reply.
static func pick_tones(tones: Array) -> Callable:
	return func(offered: Array) -> int:
		for tone: String in tones:
			for index in offered.size():
				if str((offered[index] as Dictionary).get("tone", "")) == tone:
					return index
		return 0


## Plays the conversation on show to its end, picking replies with picker
## (given the offered replies, returns an index).
func talk_through(picker: Callable = Callable(), seconds: float = 180.0) -> void:
	var step := 1.0 / 30.0
	for frame in int(seconds / step):
		if not story.is_playing() and _intro_in <= 0.0:
			return
		if talk_ui.is_choosing():
			story.choose(int(picker.call(story.runner.offered())) if picker.is_valid() else 0)
		elif story.is_playing() and not story.is_busy():
			talk_ui.tap()
		update(step)


## Runs the day until until() is true, talking with picker, walking to
## each place and playing tasks with bot. Returns true if until() was met.
func play_until(until: Callable, picker: Callable = Callable(), bot: AutoPlayer = null, seconds: float = 600.0) -> bool:
	var player_bot := bot if bot != null else AutoPlayer.new()
	var step := 1.0 / 30.0
	for frame in int(seconds / step):
		if bool(until.call()):
			return true
		if story.is_playing():
			if talk_ui.is_choosing():
				story.choose(int(picker.call(story.runner.offered())) if picker.is_valid() else 0)
			elif not story.is_busy():
				talk_ui.tap()
		elif view != null:
			if view.result_open():
				view.done_pressed.emit()
			else:
				player_bot.step(view, step)
		elif mode == "walk" and not _places_open().is_empty():
			go_to(_places_open()[0])
		update(step)
	return bool(until.call())
