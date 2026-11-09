class_name SkillsLab
extends Node3D
## Day 2: the skills lab. Six practice stations around one room, run by
## Dr. Iyer, Sister Grace and Tom the scrub nurse.
##
## Tap a station: the doctor walks over, the trainer comes across and
## explains it, then the task opens in close-up with its own screen. When
## the task ends, the score card says what went well and what to fix, the
## best score is saved, and the first try earns XP (better stars later earn
## a little more). When all six are done, Dr. Iyer has news about tomorrow.
##
## Floor coordinates as in the lobby: x left to right, z from the back wall
## (-5) towards the camera (+5).

signal save_requested
signal menu_choice(choice: String)

const ROOM := Rect2(-7, -5, 14, 10)
const WALK_SPEED := 1.8
const PEOPLE_SPEED := 1.5
const TAP_RADIUS := 80.0
const FIRST_XP := 30
const XP_PER_STAR := 10
const MINUTES_PER_TRY := 10
const ACTIONS := []
## Where each station stands and which way it faces (turn about y).
const LAYOUT := {
	"scrub": [Vector3(-4.6, 0, -4.2), 0.0],
	"monitor": [Vector3(-1.7, 0, -4.0), 0.0],
	"instruments": [Vector3(1.6, 0, -4.0), 0.0],
	"stitch": [Vector3(4.6, 0, -4.2), 0.0],
	"history": [Vector3(-5.8, 0, 0.6), PI / 2],
	"iv": [Vector3(5.8, 0, 0.6), -PI / 2],
}
const HOMES := {"iyer": Vector3(-0.8, 0, -1.3), "grace": Vector3(0.9, 0, -1.1)}
const START := Vector3(0, 0, 3.2)

const WALL := Color("#EEF2EC")
const WALL_TOP := Color("#DCE8E6")
const FLOOR := Color("#D7E3E0")
const FLOOR_TILE := Color("#C9D9D6")
const TEAL := Color("#127C80")

var profile: PlayerProfile
var walk_area: WalkArea
var player: AvatarRig
var camera: Camera3D
var hud: LobbyHud
var talk_ui: ConversationUi
var overlay: StoryOverlay
var story: StoryPlayer
var stations := {}
## People in the lab: id -> {rig, home}.
var people := {}
## "walk", "approach" (walking to a station), "story" or "task".
var mode := "walk"
## The station being used or walked to.
var active := ""
## The task screen while a task runs.
var view: TrainingView
## The conversation running now (a key of story/training.json).
var conversation := ""
var talking_with := ""

var _layer: CanvasLayer
var _routes := {}
var _press_at := Vector2.ZERO
var _pressed := false
var _facing := PI
var _camera_target := Vector3.ZERO
var _camera_mode := "follow"
var _camera_speaker := ""
var _attempts := {}
var _intro_in := -1.0
var _clear_in := -1.0
var _gather := ""
var _gather_wait := 0.0
var _marker: Node3D
var _marker_time := 0.0


func _init(for_profile: PlayerProfile = null) -> void:
	profile = for_profile if for_profile != null else PlayerProfile.new()


func _ready() -> void:
	StageLighting.add_to(self, Color("#A9C3C8"), Vector3(-55, 32, 0))
	walk_area = WalkArea.new(Rect2(-6.75, -4.75, 13.5, 9.5), 0.28)
	_build_room()
	_build_stations()
	_build_people()
	player = AvatarRig.new(profile.avatar)
	player.name = "Player"
	player.voice_pitch = 1.08 - 0.04 * profile.avatar.height
	player.position = START
	player.rotation.y = _facing
	add_child(player)
	_marker = _build_marker()
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
	hud.set_hint("Tap a station to train · tap the floor to walk")
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
	_refresh_board()
	_update_clock()
	if not profile.has_flag("lab_welcome"):
		_begin_day()
	_place_camera(1.0)


# --- The room --------------------------------------------------------------

func _build_room() -> void:
	LowPoly.put(self, LowPoly.box(Vector3(ROOM.size.x, 0.1, ROOM.size.y), FLOOR), Vector3(0, -0.05, 0))
	for ix in 7:
		for iz in 5:
			if (ix + iz) % 2 == 0:
				LowPoly.put(self, LowPoly.box(Vector3(1.96, 0.01, 1.96), FLOOR_TILE), Vector3(-6 + ix * 2, 0.005, -4 + iz * 2))
	# A teal ring on the floor joins the stations.
	for side: int in [-1, 1]:
		LowPoly.put(self, LowPoly.box(Vector3(9.4, 0.012, 0.12), TEAL.lightened(0.25)), Vector3(0, 0.012, 2.1 * side - 0.9))
		LowPoly.put(self, LowPoly.box(Vector3(0.12, 0.012, 4.32), TEAL.lightened(0.25)), Vector3(4.7 * side, 0.012, -0.9))
	var back := LowPoly.joint(self, "BackWall", Vector3(0, 0, ROOM.position.y))
	LowPoly.put(back, LowPoly.box(Vector3(ROOM.size.x + 0.4, 3.4, 0.2), WALL), Vector3(0, 1.7, -0.1))
	LowPoly.put(back, LowPoly.box(Vector3(ROOM.size.x + 0.4, 0.5, 0.22), WALL_TOP), Vector3(0, 3.15, -0.1))
	LowPoly.put(back, LowPoly.box(Vector3(ROOM.size.x + 0.4, 0.16, 0.24), TEAL), Vector3(0, 0.08, -0.1))
	for side: int in [-1, 1]:
		var wall := LowPoly.joint(self, "SideWall" + ("L" if side < 0 else "R"), Vector3(7.1 * side, 0, 0))
		LowPoly.put(wall, LowPoly.box(Vector3(0.2, 3.4, ROOM.size.y), WALL.darkened(0.04)), Vector3(0, 1.7, 0))
		LowPoly.put(wall, LowPoly.box(Vector3(0.24, 0.16, ROOM.size.y), TEAL), Vector3(-0.02 * side, 0.08, 0))
	var title := LabStation.label3d("SKILLS LAB", 110, TEAL)
	title.position = Vector3(0, 2.75, -4.88)
	add_child(title)
	var motto := LabStation.label3d("Everything you break in here is plastic.", 44, TEAL.lightened(0.2))
	motto.position = Vector3(0, 2.38, -4.88)
	add_child(motto)
	# A big wall clock and a skeleton-free anatomy chart, because this is a nice lab.
	var clock := LowPoly.joint(self, "WallClock", Vector3(-3.1, 2.55, -4.88))
	LowPoly.put(clock, LowPoly.cylinder(0.26, 0.26, 0.05, 14, Color.WHITE), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	LowPoly.put(clock, LowPoly.torus(0.24, 0.28, TEAL, 16, 3), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	LowPoly.put(clock, LowPoly.box(Vector3(0.025, 0.16, 0.01), UiKit.INK), Vector3(0, 0.07, 0.035))
	LowPoly.put(clock, LowPoly.box(Vector3(0.12, 0.025, 0.01), UiKit.INK), Vector3(0.05, 0, 0.035), Vector3(0, 0, 0.0))
	var chart := LowPoly.joint(self, "Chart", Vector3(3.1, 2.4, -4.88))
	LowPoly.put(chart, LowPoly.box(Vector3(0.9, 0.7, 0.03), Color("#FBFAF5")), Vector3.ZERO)
	LowPoly.put(chart, LowPoly.sphere(0.08, Color("#F4B6A0"), 8, 5), Vector3(0, 0.18, 0.03))
	LowPoly.put(chart, LowPoly.box(Vector3(0.18, 0.3, 0.02), Color("#F4B6A0")), Vector3(0, -0.06, 0.03))
	LowPoly.put(chart, LowPoly.box(Vector3(0.06, 0.08, 0.02), Color("#E57373")), Vector3(-0.02, -0.02, 0.045))
	for corner: Vector3 in [Vector3(-6.55, 0, -4.5), Vector3(6.55, 0, -4.5)]:
		_plant(corner, 1.0)
		walk_area.add_blocker(Rect2(corner.x - 0.4, corner.z - 0.4, 0.8, 0.8))
	# Shelves of spare plastic organs on the left wall, at the front.
	var shelf := LowPoly.joint(self, "Shelf", Vector3(-6.75, 0, 3.0), Vector3(0, PI / 2, 0))
	LowPoly.put(shelf, LowPoly.box(Vector3(1.6, 1.8, 0.4), Color("#C9A27A")), Vector3(0, 0.9, 0))
	for row in 3:
		LowPoly.put(shelf, LowPoly.box(Vector3(1.5, 0.04, 0.38), Color("#E2C7A4")), Vector3(0, 0.45 + row * 0.5, 0.02))
		for item in 3:
			var colour: Color = [Color("#F4B6A0"), Color("#8FE3D2"), Color("#F8D27A")][(row + item) % 3]
			LowPoly.put(shelf, LowPoly.box(Vector3(0.28, 0.2, 0.2), colour), Vector3(-0.5 + item * 0.5, 0.58 + row * 0.5, 0.05))
	walk_area.add_blocker(Rect2(-7.0, 2.1, 0.55, 1.8))
	# The door the doctor came in by.
	var door := LowPoly.joint(self, "Door", Vector3(6.95, 0, 3.4), Vector3(0, -PI / 2, 0))
	LowPoly.put(door, LowPoly.box(Vector3(1.2, 2.3, 0.08), Color("#5FB7A6")), Vector3(0, 1.15, 0))
	LowPoly.put(door, LowPoly.box(Vector3(0.36, 0.46, 0.02), Color("#BFE7F0")), Vector3(0, 1.62, 0.05))


func _plant(at: Vector3, plant_size: float) -> void:
	var plant := LowPoly.joint(self, "Plant", at)
	LowPoly.put(plant, LowPoly.cylinder(0.2 * plant_size, 0.15 * plant_size, 0.36 * plant_size, 7, Color("#E2E8E8")),
		Vector3(0, 0.18 * plant_size, 0))
	LowPoly.put(plant, LowPoly.sphere(0.3 * plant_size, Color("#3E8E5A"), 6, 4), Vector3(0, 0.55 * plant_size, 0))
	LowPoly.put(plant, LowPoly.sphere(0.22 * plant_size, Color("#4FA56B"), 6, 4), Vector3(0.12 * plant_size, 0.78 * plant_size, 0.05))
	LowPoly.put(plant, LowPoly.shadow_blob(0.32 * plant_size), Vector3.ZERO)


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


func _build_stations() -> void:
	for id: String in TrainingTask.IDS:
		var station := _make_station(id)
		var layout: Array = LAYOUT[id]
		station.position = layout[0]
		station.rotation.y = layout[1]
		add_child(station)
		stations[id] = station
		for rect in station.blockers():
			walk_area.add_blocker(rect)


func _make_station(id: String) -> LabStation:
	match id:
		"scrub":
			return ScrubSink.new(profile.avatar)
		"monitor":
			return MonitorBed.new()
		"history":
			return ExamChair.new()
		"instruments":
			return InstrumentTrolley.new()
		"iv":
			return ArmPad.new()
	return SuturePad.new()


func station_for(id: String) -> LabStation:
	return stations.get(id)


# --- People ----------------------------------------------------------------

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
	_add_person("iyer", iyer, HOMES["iyer"], 0.0, AvatarConfig.Mood.FOCUSED)
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
	_add_person("grace", grace, HOMES["grace"], 0.0, AvatarConfig.Mood.HAPPY)
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
	var trolley: LabStation = stations["instruments"]
	_add_person("tom", tom, trolley.at(trolley.trainer_spot), trolley.trainer_facing(), AvatarConfig.Mood.HAPPY)


func _add_person(id: String, look: AvatarConfig, at: Vector3, facing: float, mood: int) -> AvatarRig:
	var rig := AvatarRig.new(look)
	rig.name = id.capitalize()
	rig.position = at
	rig.rotation.y = facing
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


## The character with a cast id ("you" for the player), for the task screens.
func rig_for(id: String) -> AvatarRig:
	if id == "you":
		return player
	return people[id]["rig"] if people.has(id) else null


# --- The day ---------------------------------------------------------------

func _begin_day() -> void:
	overlay.card("Day %d · %s" % [profile.day, profile.clock_text()], "Skills lab", 2.6)
	_clear_in = 2.0
	_intro_in = 2.5
	mode = "story"
	hud.set_talking(true)
	var iyer: AvatarRig = people["iyer"]["rig"]
	var grace: AvatarRig = people["grace"]["rig"]
	iyer.position = START + Vector3(-0.75, 0, -1.4)
	grace.position = START + Vector3(0.8, 0, -1.3)
	for rig: AvatarRig in [iyer, grace]:
		rig.rotation.y = atan2(START.x - rig.position.x, START.z - rig.position.z)
	_facing = PI
	player.rotation.y = _facing


func _update_clock() -> void:
	hud.set_clock("Day %d · %s · Skills lab" % [profile.day, profile.clock_text()])


func is_trained(id: String) -> bool:
	return profile.has_flag("trained_" + id)


func trained_count() -> int:
	var count := 0
	for id: String in TrainingTask.IDS:
		if is_trained(id):
			count += 1
	return count


## The first station not tried yet, or "" once all six are done.
func next_station() -> String:
	for id: String in TrainingTask.IDS:
		if not is_trained(id):
			return id
	return ""


func _refresh_board() -> void:
	var rows := []
	for id: String in TrainingTask.IDS:
		var best := profile.best_score(id)
		rows.append([TrainingTask.title_of(id), is_trained(id), TrainingTask.stars_for(best) if best >= 0 else -1])
	hud.set_tasks(rows, "Skills lab · %d of %d" % [trained_count(), TrainingTask.IDS.size()])
	hud.set_pager(_pager_text())


func _pager_text() -> String:
	if profile.has_flag("training_done"):
		return "Dr. Iyer: Theatre tomorrow, 7:00. Rohit, nineteen, appendix. Practise if you like."
	var next := next_station()
	if next.is_empty():
		return "Dr. Iyer: All six? Come here."
	if trained_count() == 0:
		return "Sister Grace: Six stations. Start with the sink. Everyone starts with the sink."
	return "%s: Next, %s." % [_short_name(str(TrainingTask.TRAINERS[next])), TrainingTask.title_of(next).to_lower()]


func _short_name(id: String) -> String:
	match id:
		"iyer":
			return "Dr. Iyer"
		"grace":
			return "Sister Grace"
		"tom":
			return "Tom"
	return story.runner.display_name(id)


# --- Stations --------------------------------------------------------------

## Walks to a station; the trainer comes over and the task begins.
func start_station(id: String) -> void:
	if not stations.has(id) or not (mode == "walk" or mode == "approach") or story.is_playing():
		return
	active = id
	mode = "approach"
	var station: LabStation = stations[id]
	_send("you", station.at(station.spot), WALK_SPEED)
	var trainer := str(TrainingTask.TRAINERS[id])
	_send(trainer, station.at(station.trainer_greeting_spot()), PEOPLE_SPEED)
	var target := station.at(station.spot)
	_marker.position = Vector3(target.x, 0.02, target.z)
	_marker.visible = true
	_marker_time = 1.2
	if not _routes.has("you"):
		_arrive()


func _arrive() -> void:
	var station: LabStation = stations[active]
	var centre := station.at(Vector3(0, 0, 0))
	_facing = atan2(centre.x - player.position.x, centre.z - player.position.z)
	player.rotation.y = _facing
	player.moving = 0.0
	var trainer := str(TrainingTask.TRAINERS[active])
	if is_trained(active):
		open_task(active)
		return
	var steps := StoryBook.conversation("training", active + "_intro")
	if steps.is_empty():
		open_task(active)
		return
	_talk(active + "_intro", trainer, steps)


func _talk(key: String, partner: String, steps: Array) -> void:
	mode = "story"
	conversation = key
	talking_with = partner
	story.focus = partner if story.runner.start_trust(partner) >= 0 else ""
	_camera_speaker = partner
	_camera_mode = "talk"
	hud.set_talking(true)
	story.play(steps)


func _on_talk_finished(_skipped: bool) -> void:
	var finished := conversation
	conversation = ""
	talking_with = ""
	_camera_mode = "follow"
	match finished:
		"welcome":
			profile.set_flag("lab_welcome")
			for id: String in ["iyer", "grace"]:
				_send(id, HOMES[id], PEOPLE_SPEED)
			_back_to_walking()
		"done":
			_back_to_walking()
		_:
			if finished.ends_with("_intro") and not active.is_empty():
				open_task(active)
				return
			_back_to_walking()
	save_requested.emit()


func _back_to_walking() -> void:
	mode = "walk"
	active = ""
	hud.set_talking(false)
	_refresh_board()
	_update_clock()


## Opens a station's task in close-up with its screen.
func open_task(id: String) -> void:
	active = id
	mode = "task"
	var station: LabStation = stations[id]
	_attempts[id] = int(_attempts.get(id, 0)) + 1
	var task := TrainingTask.make(id, 1 + int(_attempts[id]) + profile.day * 10)
	view = _view_for(task)
	view.name = "Training"
	_layer.add_child(view)
	_layer.move_child(view, talk_ui.get_index())
	view.leave_pressed.connect(_on_leave)
	view.retry_pressed.connect(_on_retry)
	view.done_pressed.connect(_on_done)
	view.task_finished.connect(_on_task_finished)
	station.reset_task(task)
	hud.set_talking(true)
	player.visible = false
	var trainer := str(TrainingTask.TRAINERS[id])
	_routes.erase(trainer)
	_routes.erase("you")
	player.position = station.at(station.spot)
	var rig: AvatarRig = people[trainer]["rig"]
	rig.position = station.at(station.trainer_spot)
	rig.rotation.y = station.trainer_facing()
	rig.moving = 0.0
	rig.sitting = station.trainer_sits
	rig.look_at_point(station.at(station.close_from))
	_camera_mode = "close"


func _view_for(task: TrainingTask) -> TrainingView:
	match task.id:
		"scrub":
			return ScrubView.new(task, self)
		"monitor":
			return MonitorView.new(task, self)
		"history":
			return HistoryView.new(task, self)
		"instruments":
			return InstrumentView.new(task, self)
		"iv":
			return IvView.new(task, self)
	return StitchView.new(task, self)


func _on_task_finished(task: TrainingTask) -> void:
	var id := task.id
	var before := profile.best_score(id)
	var old_stars := TrainingTask.stars_for(before) if before >= 0 else 0
	var first := not is_trained(id)
	var better := profile.record_score(id, task.score())
	var xp := 0
	if first:
		xp = FIRST_XP + XP_PER_STAR * task.stars()
		profile.set_flag("trained_" + id)
	elif task.stars() > old_stars:
		xp = XP_PER_STAR * (task.stars() - old_stars)
	profile.total_xp += xp
	profile.pass_minutes(MINUTES_PER_TRY)
	var parts := PackedStringArray()
	if xp > 0:
		parts.append("+%d XP" % xp)
	if better and not first:
		parts.append("new best")
	elif not first:
		parts.append("best %d" % profile.best_score(id))
	view.show_result(" · ".join(parts))
	hud.refresh_profile()
	_update_clock()
	save_requested.emit()


func _close_task() -> void:
	if view != null:
		_layer.remove_child(view)
		view.queue_free()
		view = null
	player.visible = true
	if not active.is_empty():
		var trainer := str(TrainingTask.TRAINERS[active])
		var rig: AvatarRig = people[trainer]["rig"]
		rig.sitting = false
		rig.look_at_point(null)
		var station: LabStation = stations[active]
		if station.trainer_sits:
			# Up from the patient's chair, a step into the room.
			rig.position = station.at(station.trainer_intro_spot)
	_camera_mode = "follow"


func _on_leave() -> void:
	_close_task()
	_back_to_walking()


func _on_retry() -> void:
	var id := active
	_close_task()
	open_task(id)


func _on_done() -> void:
	_close_task()
	_back_to_walking()
	if next_station().is_empty() and not profile.has_flag("training_done"):
		_gather_for("done")


## Brings Dr. Iyer and Sister Grace over to the doctor, then plays a
## conversation.
func _gather_for(key: String) -> void:
	_gather = key
	_gather_wait = 4.0
	mode = "story"
	hud.set_talking(true)
	var me := player.position
	var toward := Vector3(-me.x, 0, -me.z).normalized() if Vector2(me.x, me.z).length() > 0.5 else Vector3(0, 0, -1)
	var side := Vector3(-toward.z, 0, toward.x)
	_send("iyer", me + toward * 1.2 - side * 0.55, PEOPLE_SPEED)
	_send("grace", me + toward * 1.2 + side * 0.65, PEOPLE_SPEED)


## True while a station's task screen is open.
func in_task() -> bool:
	return view != null


func is_talking() -> bool:
	return story.is_playing()


# --- Story hooks -----------------------------------------------------------

func perform(_step: Dictionary) -> Variant:
	return null


func mark(_mark_name: String) -> Variant:
	return null


func on_line(speaker: String, _listener: String) -> void:
	_camera_speaker = speaker


# --- Input and movement ----------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if hud.menu_open():
		return
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_press_at = button.position
			_pressed = true
		else:
			_pressed = false
			if button.position.distance_to(_press_at) < 24.0:
				tap(button.position)
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _pressed and view != null and not view.result_open():
		view.world_drag(motion.relative)


## A tap on the screen: picks something in the task, a station, or the floor.
func tap(screen_point: Vector2) -> void:
	if view != null:
		if not view.result_open():
			view.world_tap(screen_point)
		return
	if mode != "walk" and mode != "approach":
		return
	var found := station_at(screen_point)
	if not found.is_empty():
		start_station(found)
		return
	var floor_point: Variant = LabStation.ray_to_height(camera, screen_point, 0.0)
	if floor_point == null:
		return
	mode = "walk"
	active = ""
	var point := floor_point as Vector3
	_send("you", Vector3(point.x, 0, point.z), WALK_SPEED)
	_marker.position = Vector3(point.x, 0.02, point.z)
	_marker.visible = true
	_marker_time = 1.2


## The station drawn nearest a screen point (its furniture or its tag), or "".
func station_at(screen_point: Vector2) -> String:
	var best := ""
	var best_distance := UiKit.px(TAP_RADIUS / 2.0)
	for id: String in stations:
		var station: LabStation = stations[id]
		for point: Vector3 in [station.at(station.tag_point), station.at(Vector3(0, 0.85, 0))]:
			if camera.is_position_behind(point):
				continue
			var distance := camera.unproject_position(point).distance_to(screen_point)
			if distance < best_distance:
				best_distance = distance
				best = id
	return best


## Sends someone walking around the furniture to a spot.
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
		# Arriving somewhere can end other walks (a task opening places the trainer).
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
		rig.position = Vector3(me.x, 0, me.y)
		if moved.length() > 0.0001:
			var heading := atan2(moved.x, moved.y)
			if id == "you":
				_facing = heading
			rig.rotation.y = lerp_angle(rig.rotation.y, heading, minf(1.0, delta * 10.0))
		rig.moving = 1.0
		route["path"] = path
		if path.is_empty():
			rig.moving = 0.0
			_routes.erase(id)
			_on_route_end(id)


func _on_route_end(id: String) -> void:
	if id == "you" and mode == "approach" and not active.is_empty():
		_arrive()
		return
	if people.has(id) and mode != "task":
		var rig: AvatarRig = people[id]["rig"]
		if not active.is_empty() and str(TrainingTask.TRAINERS[active]) == id:
			rig.rotation.y = atan2(player.position.x - rig.position.x, player.position.z - rig.position.z) \
				if mode == "story" else (stations[active] as LabStation).trainer_facing()
		elif _gather.is_empty() and conversation.is_empty():
			# Settle facing into the room.
			rig.rotation.y = atan2(-rig.position.x, 1.5 - rig.position.z)
		else:
			rig.rotation.y = atan2(player.position.x - rig.position.x, player.position.z - rig.position.z)


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


func _walk_with_keys(delta: float) -> void:
	var keys := _key_direction()
	if keys == Vector2.ZERO or hud.menu_open():
		return
	_routes.erase("you")
	mode = "walk"
	active = ""
	var step := keys.normalized() * WALK_SPEED * delta
	var me := Vector2(player.position.x, player.position.z)
	for attempt: Vector2 in [step, Vector2(step.x, 0), Vector2(0, step.y)]:
		if attempt != Vector2.ZERO and walk_area.is_walkable(me + attempt):
			player.position += Vector3(attempt.x, 0, attempt.y)
			_facing = atan2(attempt.x, attempt.y)
			player.rotation.y = _facing
			player.moving = 1.0
			return


# --- Every frame -----------------------------------------------------------

func _process(delta: float) -> void:
	update(delta)


## Time passes only here, so tests and the screenshot tool can play the lab.
func update(delta: float) -> void:
	overlay.tick(delta)
	if _clear_in > 0.0:
		_clear_in -= delta
		if _clear_in <= 0.0:
			overlay.fade("clear", 0.8)
	if _intro_in > 0.0:
		_intro_in -= delta
		if _intro_in <= 0.0:
			_talk("welcome", "iyer", StoryBook.conversation("training", "welcome"))
	if mode == "walk" or mode == "approach":
		player.moving = 0.0 if not _routes.has("you") else player.moving
		_walk_with_keys(delta)
	story.update(delta)
	_update_routes(delta)
	if not _gather.is_empty():
		_gather_wait -= delta
		if (not is_walking("iyer") and not is_walking("grace")) or _gather_wait <= 0.0:
			var key := _gather
			_gather = ""
			for id: String in ["iyer", "grace"]:
				_routes.erase(id)
				var rig: AvatarRig = people[id]["rig"]
				rig.moving = 0.0
				rig.rotation.y = atan2(player.position.x - rig.position.x, player.position.z - rig.position.z)
			_facing = atan2(people["iyer"]["rig"].position.x - player.position.x,
				people["iyer"]["rig"].position.z - player.position.z)
			player.rotation.y = _facing
			_talk(key, "iyer", StoryBook.conversation("training", key))
	if view != null:
		view.tick(delta)
		(stations[active] as LabStation).show_task(view.task, delta)
	if _marker_time > 0.0:
		_marker_time -= delta
		_marker.scale = Vector3.ONE * (1.0 + (1.2 - _marker_time) * 0.4)
		if _marker_time <= 0.0:
			_marker.visible = false
	_place_camera(minf(1.0, delta * 4.0))
	_update_tags()


func settle_camera() -> void:
	_place_camera(1.0)


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
		focus.x = clampf(focus.x, -2.6, 2.6)
		focus.z = clampf(focus.z, -0.6, 1.4)
		goal = focus + Vector3(0, 6.2, 7.0)
		target = focus + Vector3(0, 0.2, -1.6)
	_camera_target = _camera_target.lerp(target, weight) if weight < 1.0 else target
	camera.position = camera.position.lerp(goal, weight) if weight < 1.0 else goal
	camera.h_offset = lerpf(camera.h_offset, offset, weight)
	camera.fov = lerpf(camera.fov, fov, weight)
	camera.look_at(_camera_target)


func _update_tags() -> void:
	var walking := mode == "walk" or mode == "approach"
	var next := next_station()
	for id: String in stations:
		var station: LabStation = stations[id]
		var point := station.at(station.tag_point)
		var text := TrainingTask.title_of(id)
		var best := profile.best_score(id)
		if best >= 0:
			text += " · %d" % best
		hud.set_tag("station_" + id, text, camera.unproject_position(point),
			walking and not camera.is_position_behind(point), id == next)


func _on_menu_choice(choice: String) -> void:
	if choice == "sound":
		save_requested.emit()
		return
	if choice != "resume":
		menu_choice.emit(choice)


# --- For tests and screenshots ---------------------------------------------

## Plays the conversation on show to its end, taking reply pick.
func talk_through(pick: int = 0, seconds: float = 120.0) -> void:
	var step := 1.0 / 30.0
	for frame in int(seconds / step):
		if not story.is_playing() and _gather.is_empty() and _intro_in <= 0.0:
			return
		if talk_ui.is_choosing():
			story.choose(pick)
		elif story.is_playing() and not story.is_busy():
			talk_ui.tap()
		update(step)


## Walks to a station and through its introduction until the task is open.
func go_to_task(id: String, seconds: float = 60.0) -> bool:
	start_station(id)
	var step := 1.0 / 30.0
	for frame in int(seconds / step):
		if view != null:
			settle_camera()
			return true
		if talk_ui.is_choosing():
			story.choose(0)
		elif story.is_playing() and not story.is_busy():
			talk_ui.tap()
		update(step)
	return view != null


## Plays the open task with an AutoPlayer until stop() says so (or it ends
## and the score card is up). Returns true if stop() was met.
func play_task(stop: Callable = Callable(), seconds: float = 120.0) -> bool:
	var bot := AutoPlayer.new()
	var step := 1.0 / 30.0
	for frame in int(seconds / step):
		if view == null:
			return false
		if stop.is_valid() and bool(stop.call()):
			return true
		if not stop.is_valid() and view.result_open():
			return true
		bot.step(view, step)
		update(step)
	return false
