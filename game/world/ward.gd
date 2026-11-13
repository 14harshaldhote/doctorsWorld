class_name Ward
extends Node3D
## Days 4 to 8: a week on the surgical ward. Then, eight months later,
## Days 9 to 13 as a Junior Resident (their beats are in WardStory), with
## operations in the theatre and meetings in the seminar room, and quiet
## days after the last story day.
##
## Each day is a list of beats (DAYS): a conversation, somewhere to walk
## to, work with a patient (take a history, examine them, read an X-ray)
## and a conversation after. Who lies in which bed follows the story so far:
## what the doctor agreed with the administrator about beds, who got the
## side room, whether the rider was treated. Day 6 is a night on call. Day 8
## ends with the review and the promotion to Junior Resident.
##
## Floor: x runs from the X-ray viewer's wall (left) past six beds to the
## side room and the door (right); z from the back wall (-4) towards the
## camera (+4). The theatre and the seminar room are built far below the
## ward (THEATRE_AT, SEMINAR_AT) and shown only while the story is in them.
## Time passes only through update().

signal save_requested
signal menu_choice(choice: String)
signal day_finished

const ACTIONS := ["arrive", "leave", "put", "card", "page"]
const WALK_SPEED := 1.8
const PEOPLE_SPEED := 1.5
const FIRST_DAY := 4
const NIGHT_DAY := 6
const REVIEW_DAY := 8
## The review conversation on each review day.
const REVIEWS := {8: "review", 13: "review_senior", 18: "review_surgeon", 23: "review_hod", 27: "board_vote"}
## Experience for an operation, by outcome, plus this much per star.
const OP_XP := {"won": 120, "struggled": 80, "failed": 40}
const OP_XP_PER_STAR := 10
## The theatre's table and the seminar room, out of sight below the ward.
const THEATRE_AT := Vector3(0, -40, 0)
const SEMINAR_AT := Vector3(0, -80, 0)
## Experience for a day's work, on top of each task's.
const SHIFT_XP := 120
## Each task gives this much experience plus half its score.
const TASK_XP := 20
## The review gives at least this much, and always enough for the promotion.
const REVIEW_XP := 150
const DAY_END_DELAY := 3.4
const NIGHT_START := 20 * 60
## 02:10 the next morning, still on the night's clock.
const NIGHT_LATE := 26 * 60 + 10

## Beds: id -> [where, turn about y, label]. The trolley stands in the
## admissions bay with its head towards the door.
const BEDS := {
	"bed1": [Vector3(-7.0, 0, -2.85), 0.0, "Bed 1"],
	"bed2": [Vector3(-4.8, 0, -2.85), 0.0, "Bed 2"],
	"bed3": [Vector3(-2.6, 0, -2.85), 0.0, "Bed 3"],
	"bed4": [Vector3(-0.4, 0, -2.85), 0.0, "Bed 4"],
	"bed5": [Vector3(1.8, 0, -2.85), 0.0, "Bed 5"],
	"bed6": [Vector3(4.0, 0, -2.85), 0.0, "Bed 6"],
	"side": [Vector3(7.95, 0, -2.75), 0.0, "Side room"],
	"trolley": [Vector3(-5.2, 0, 1.75), -PI / 2, "Admissions"],
}
const DESK := Vector3(1.6, 0, 1.45)
const LIGHTBOX := Vector3(-8.8, 0, -0.35)
## Inside the end walls (at x -9.1 and 9.5), where a talk camera can stand.
const ROOM_MIN_X := -8.8
const ROOM_MAX_X := 9.2
const DOOR := Vector3(8.7, 0, 1.0)
const FAMILY := Vector3(6.9, 0, 2.7)

## The days. A beat can have:
##   "id"     its name (also the HUD row's key)
##   "row"    the line in the HUD's task list ("" or none: no row)
##   "if"     a story flag it needs ("!flag" for not set)
##   "go"     where to walk first: a bed id, "desk" or "lightbox"
##   "talk"   the conversation on arrival, and "with" who it is with
##   "tasks"  [[task id, case id], ...] played in turn
##   "after"  the conversation after the tasks
##   "coach"  who coaches the tasks (default Dr. Iyer)
##   "page"   the pager's message while walking there
##   "card"   [title, line]: a moment passing (the night's 02:10)
const DAYS := {
	4: [
		{"id": "handover", "talk": "handover", "with": "grace"},
		{"id": "rohit", "row": "See Rohit in bed 1", "go": "bed1", "talk": "rohit_round", "with": "rohit",
			"page": "Dr. Iyer: Bed one first. Your patient, your round."},
		{"id": "lakshmi", "row": "Admit the new patient", "go": "trolley", "talk": "lakshmi_arrive", "with": "lakshmi",
			"tasks": [["history", "lakshmi_history"], ["exam", "lakshmi_exam"]], "after": "lakshmi_after",
			"page": "Priya: New admission in the bay. Pain under the ribs."},
		{"id": "arjun", "row": "Lakshmi's son is calling", "go": "bed2", "talk": "arjun_call", "with": "lakshmi",
			"page": "Priya: Bed two's son on video. From Dubai. He's loud."},
		{"id": "beds", "row": "Mr. Malhotra wants a word", "go": "desk", "talk": "malhotra_beds", "with": "malhotra",
			"page": "Grace: The administrator is at my desk. Asking for you."},
	],
	5: [
		{"id": "morning", "talk": "day5_morning", "with": "iyer"},
		{"id": "kunal", "row": "A VIP in admissions", "go": "trolley", "talk": "kunal_arrive", "with": "kunal",
			"tasks": [["exam", "kunal_exam"]], "after": "kunal_room",
			"page": "Priya: Admissions. He says his uncle is a minister."},
		{"id": "aarav", "row": "Read Aarav's X-ray", "go": "lightbox", "talk": "aarav_arrive", "with": "leela",
			"tasks": [["scan", "aarav_scan"]], "after": "aarav_after",
			"page": "Dr. Iyer: Lightbox. Leela Thomas is back, with Aarav."},
	],
	6: [
		{"id": "night", "talk": "night_start", "with": "sethi"},
		{"id": "banerjee", "row": "Night round: Mrs. Banerjee", "go": "banerjee", "talk": "banerjee_night", "with": "banerjee",
			"page": "Priya: Mrs. Banerjee can't sleep. She's asking for the doctor."},
		{"id": "late", "card": ["02:10", "The ward is asleep. Then the doors bang open."]},
		{"id": "rider", "row": "Emergency in admissions", "go": "trolley", "talk": "rider_arrive", "with": "rider",
			"tasks": [["exam", "rider_exam"]], "after": "rider_after", "coach": "priya", "music": "emergency",
			"page": "Priya: ADMISSIONS. NOW. He's bleeding."},
	],
	7: [
		{"id": "morning", "talk": "day7_morning", "with": "iyer"},
		{"id": "salim", "row": "See Salim in bed 4", "if": "rider_treated", "go": "bed4", "talk": "salim_morning",
			"with": "salim", "page": "Priya: Bed four is awake. He keeps asking for the night doctor."},
		{"id": "joseph", "row": "Mr. Fernandes in bed 6", "go": "bed6", "talk": "joseph_arrive", "with": "joseph",
			"tasks": [["exam", "joseph_exam"]], "after": "joseph_family",
			"page": "Dr. Iyer: Bed six. Bring patience. His children are here."},
		{"id": "rao", "row": "Dr. Rao's round", "go": "desk", "talk": "rao_round", "with": "rao",
			"page": "Grace: Dr. Rao and Mr. Malhotra. At my desk. Both of them. Hurry."},
	],
	8: [
		{"id": "letters", "talk": "letters", "with": "grace"},
		{"id": "review", "row": "Your review with Dr. Rao", "go": "desk", "talk": "review", "with": "rao",
			"page": "Dr. Iyer: We're ready for you. Don't run."},
	],
}
## Every quiet day after the review.
const QUIET := [
	{"id": "morning", "talk": "quiet_morning", "with": "iyer"},
	{"id": "films", "row": "Teaching films", "go": "lightbox", "tasks": [["scan", "teaching_scan"]],
		"after": "quiet_after", "page": "Dr. Iyer: Lightbox when you're ready. Teaching films."},
]
## The story's choices on each day, cleared when an unfinished day starts again.
const DAY_FLAGS := {
	4: ["lakshmi_privacy", "lakshmi_told", "lakshmi_asked", "beds_agreed", "beds_refused", "beds_checked",
		"rohit_honest"],
	5: ["kunal_room", "banerjee_room", "kunal_home", "aarav_battery_found"],
	6: ["banerjee_sat", "rider_treated", "rider_waited", "rider_called_sethi", "rider_named", "pooja_answered"],
	7: ["joseph_asked", "joseph_surgery", "joseph_home", "beds_saved", "rao_neutral", "rao_malhotra"],
	8: [],
}
## The cases worked each day, whose task flags are cleared with them.
const DAY_CASES := {
	4: ["lakshmi_history", "lakshmi_exam"],
	5: ["kunal_exam", "aarav_scan"],
	6: ["rider_exam"],
	7: ["joseph_exam"],
}

const WALL := Color("#EEF2EC")
const FLOOR := Color("#D9E2DC")
const TEAL := Color("#127C80")
const NIGHT_SKY := Color("#16222E")

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
## The beds (by id) and the X-ray viewer ("scan").
var stations := {}
## "story", "walk", "approach", "task" or "end".
var mode := "story"
var night := false
## Today's beats, the one under way and the ids of those done.
var beats: Array[Dictionary] = []
var beat_index := -1
var done_beats: Array[String] = []
## The bed of the patient being seen, for the task screens.
var active_bed := ""
var active := ""
var view: TrainingView
var conversation := ""
var talking_with := ""
## Tasks still to play in this beat, as [task id, case id].
var task_queue: Array = []
## Every task finished today, as {id, case, score}.
var results: Array[Dictionary] = []
var shift_xp := 0
## Where the story is: "ward", "theatre" or "seminar".
var place := "ward"
var theatre_set: TheatreSet
var table: OperatingTable
var seminar: SeminarRoom
## The operation under way (or last played today).
var operation: OperationTask

var _layer: CanvasLayer
var _environment: Environment
var _lamps: Array[Node3D] = []
var _routes := {}
var _leaving := {}
var _press_at := Vector2.ZERO
var _pressed := false
var _camera_target := Vector3.ZERO
var _camera_mode := "follow"
var _camera_speaker := ""
var _intro_in := -1.0
var _clear_in := -1.0
var _beat_in := -1.0
var _end_in := -1.0
var _day_card_in := -1.0
var _queued_procedure := ""


func _init(for_profile: PlayerProfile = null) -> void:
	profile = for_profile if for_profile != null else PlayerProfile.new()


func _ready() -> void:
	_environment = StageLighting.add_to(self, Color("#A9C3C8"), Vector3(-55, 28, 0))
	walk_area = WalkArea.new(Rect2(-8.55, -3.75, 17.6, 7.3), 0.28)
	_build_room()
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
	StaticBatch.optimise(self)
	_place_camera(1.0)


# --- The room -------------------------------------------------------------------

func _build_room() -> void:
	LowPoly.put(self, LowPoly.box(Vector3(18.6, 0.1, 8.2), FLOOR), Vector3(0.3, -0.05, 0))
	for ix in 9:
		for iz in 4:
			if (ix + iz) % 2 == 0:
				LowPoly.put(self, LowPoly.box(Vector3(1.9, 0.01, 1.9), FLOOR.darkened(0.05)),
					Vector3(-8.0 + ix * 2.0, 0.005, -3.0 + iz * 2.0))
	# The back wall, the end walls and a teal skirting.
	LowPoly.put(self, LowPoly.box(Vector3(18.8, 3.2, 0.2), WALL), Vector3(0.3, 1.6, -4.1))
	LowPoly.put(self, LowPoly.box(Vector3(18.8, 0.16, 0.24), TEAL), Vector3(0.3, 0.08, -3.98))
	for x: float in [-9.1, 9.5]:
		LowPoly.put(self, LowPoly.box(Vector3(0.2, 3.2, 8.2), WALL.darkened(0.04)), Vector3(x, 1.6, 0))
	var sign := LabStation.label3d("WARD 4 · SURGERY", 60, TEAL)
	sign.position = Vector3(-2.0, 2.75, -3.98)
	add_child(sign)
	# Windows between the beds.
	for x: float in [-5.9, -1.5, 2.9]:
		var window := LowPoly.joint(self, "Window", Vector3(x, 1.85, -3.98))
		LowPoly.put(window, LowPoly.box(Vector3(0.9, 1.0, 0.04), Color("#BFE7F0"), "Glass"), Vector3.ZERO)
		LowPoly.put(window, LowPoly.box(Vector3(1.0, 0.07, 0.06), WALL.darkened(0.15)), Vector3(0, -0.53, 0.02))
		LowPoly.put(window, LowPoly.box(Vector3(0.05, 1.0, 0.05), WALL.darkened(0.1)), Vector3(0, 0, 0.02))
	# A clock over the nurses' station.
	var clock := LowPoly.joint(self, "Clock", Vector3(-3.7, 2.55, -3.96))
	LowPoly.put(clock, LowPoly.cylinder(0.2, 0.2, 0.05, 14, Color.WHITE), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	LowPoly.put(clock, LowPoly.torus(0.19, 0.22, TEAL, 16, 3), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	LowPoly.put(clock, LowPoly.box(Vector3(0.02, 0.13, 0.01), UiKit.INK), Vector3(0, 0.05, 0.035))
	_build_side_room()
	_build_desk()
	_build_family_corner()
	_build_door()


func _build_side_room() -> void:
	# Glass on the ward side, a wall in front with a doorway, a sign.
	var glass := LowPoly.box(Vector3(0.06, 2.4, 3.1), Color("#CFEAF0"), "SideGlass")
	LowPoly.put(self, glass, Vector3(5.85, 1.2, -2.55))
	LowPoly.put(self, LowPoly.box(Vector3(0.1, 0.08, 3.1), Color("#8FA1A6")), Vector3(5.85, 2.42, -2.55))
	LowPoly.put(self, LowPoly.box(Vector3(0.1, 0.8, 3.1), WALL.darkened(0.06)), Vector3(5.85, 0.4, -2.55))
	LowPoly.put(self, LowPoly.box(Vector3(0.45, 2.6, 0.12), WALL.darkened(0.06)), Vector3(6.08, 1.3, -1.0))
	LowPoly.put(self, LowPoly.box(Vector3(2.15, 2.6, 0.12), WALL.darkened(0.06)), Vector3(8.43, 1.3, -1.0))
	var label := LabStation.label3d("SIDE ROOM", 34, TEAL, 0.004)
	label.position = Vector3(8.4, 2.2, -0.93)
	add_child(label)
	walk_area.add_blocker(Rect2(5.75, -4.0, 0.2, 3.05))
	walk_area.add_blocker(Rect2(5.75, -1.1, 0.6, 0.2))
	walk_area.add_blocker(Rect2(7.35, -1.1, 2.2, 0.2))


func _build_desk() -> void:
	# The nurses' station: a long counter with a raised front, a computer,
	# files and a phone.
	var desk := LowPoly.joint(self, "Desk", DESK)
	LowPoly.put(desk, LowPoly.box(Vector3(2.8, 0.95, 0.62), Color("#E2EEEC")), Vector3(0, 0.475, 0))
	LowPoly.put(desk, LowPoly.box(Vector3(2.9, 0.06, 0.7), Color("#8FB9B3")), Vector3(0, 0.98, 0))
	LowPoly.put(desk, LowPoly.box(Vector3(2.8, 0.18, 0.06), TEAL), Vector3(0, 0.75, 0.33))
	LowPoly.put(desk, LowPoly.box(Vector3(0.5, 0.32, 0.04), Color("#2B2F33")), Vector3(-0.7, 1.2, -0.12))
	var screen := LowPoly.box(Vector3(0.44, 0.26, 0.01), Color("#BFE7F0"))
	screen.material_override = LowPoly.glow(Color("#BFE7F0"), 0.6)
	LowPoly.put(desk, screen, Vector3(-0.7, 1.2, -0.095))
	for index in 4:
		LowPoly.put(desk, LowPoly.box(Vector3(0.24, 0.3, 0.04), [Color("#F5B841"), Color("#5E9FD0"), Color("#F07C5A"),
			Color("#3E8E5A")][index]), Vector3(0.45 + index * 0.06, 1.16, -0.1), Vector3(0, 0, 0.06 * index))
	LowPoly.put(desk, LowPoly.box(Vector3(0.14, 0.05, 0.2), Color("#2B2F33")), Vector3(1.05, 1.04, 0.05))
	var label := LabStation.label3d("NURSES' STATION", 30, TEAL, 0.0035)
	label.position = Vector3(0, 0.76, 0.37)
	desk.add_child(label)
	walk_area.add_blocker(Rect2(DESK.x - 1.45, DESK.z - 0.35, 2.9, 0.7))


func _build_family_corner() -> void:
	var corner := LowPoly.joint(self, "Family", FAMILY)
	for index in 3:
		var chair := LowPoly.joint(corner, "Seat", Vector3(-0.6 + index * 0.6, 0, 0.35), Vector3(0, PI, 0))
		LowPoly.put(chair, LowPoly.box(Vector3(0.48, 0.06, 0.46), Color("#F5B841")), Vector3(0, 0.45, 0))
		LowPoly.put(chair, LowPoly.box(Vector3(0.48, 0.48, 0.06), Color("#F5B841")), Vector3(0, 0.72, -0.21))
		LowPoly.put(chair, LowPoly.cylinder(0.03, 0.03, 0.44, 6, LabStation.STEEL_DARK), Vector3(0, 0.22, 0))
	var cooler := LowPoly.joint(corner, "Cooler", Vector3(1.35, 0, 0.1))
	LowPoly.put(cooler, LowPoly.box(Vector3(0.34, 0.95, 0.34), Color("#F4F7F7")), Vector3(0, 0.475, 0))
	LowPoly.put(cooler, LowPoly.cylinder(0.13, 0.13, 0.36, 8, Color("#9FD6EA")), Vector3(0, 1.13, 0))
	var plant := LowPoly.joint(corner, "Plant", Vector3(-1.3, 0, 0.1))
	LowPoly.put(plant, LowPoly.cylinder(0.2, 0.15, 0.36, 7, Color("#E2E8E8")), Vector3(0, 0.18, 0))
	LowPoly.put(plant, LowPoly.sphere(0.3, Color("#3E8E5A"), 6, 4), Vector3(0, 0.55, 0))
	LowPoly.put(plant, LowPoly.sphere(0.22, Color("#4FA56B"), 6, 4), Vector3(0.12, 0.78, 0.05))
	walk_area.add_blocker(Rect2(FAMILY.x - 1.6, FAMILY.z + 0.05, 3.2, 0.6))


func _build_door() -> void:
	var door := LowPoly.joint(self, "Door", Vector3(9.38, 0, DOOR.z))
	LowPoly.put(door, LowPoly.box(Vector3(0.08, 2.3, 1.5), Color("#9CC7D9")), Vector3(0, 1.15, 0))
	LowPoly.put(door, LowPoly.box(Vector3(0.1, 0.12, 1.7), TEAL), Vector3(0, 2.36, 0))
	var label := LabStation.label3d("EXIT", 34, TEAL, 0.004)
	label.position = Vector3(9.3, 2.62, DOOR.z)
	label.rotation.y = -PI / 2
	add_child(label)


func _build_stations() -> void:
	for bed_id: String in BEDS:
		var entry: Array = BEDS[bed_id]
		var bed := WardBed.new(bed_id, str(entry[2]), bed_id == "trolley")
		bed.position = entry[0]
		bed.rotation.y = float(entry[1])
		add_child(bed)
		stations[bed_id] = bed
		for rect in bed.blockers():
			walk_area.add_blocker(rect)
	var box := Lightbox.new()
	box.position = LIGHTBOX
	box.rotation.y = PI / 2
	add_child(box)
	stations["scan"] = box
	theatre_set = TheatreSet.new()
	theatre_set.position = THEATRE_AT
	theatre_set.visible = false
	add_child(theatre_set)
	table = OperatingTable.new(profile.avatar)
	table.position = THEATRE_AT
	table.visible = false
	add_child(table)
	stations["table"] = table
	seminar = SeminarRoom.new()
	seminar.position = SEMINAR_AT
	seminar.visible = false
	add_child(seminar)
	# Night: warm lamps at the desk and along the beds.
	for at: Vector3 in [DESK + Vector3(0, 1.9, 0), Vector3(-4.0, 2.3, -2.0), Vector3(3.0, 2.3, -2.0),
			Vector3(-5.6, 2.2, 1.6)]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color("#FFD9A0")
		lamp.light_energy = 1.4
		lamp.omni_range = 4.5
		lamp.position = at
		lamp.visible = false
		add_child(lamp)
		_lamps.append(lamp)


func station_for(id: String) -> LabStation:
	if id in ["exam", "history"]:
		return stations.get(active_bed)
	if id in Procedures.ids():
		return table
	return stations.get(id)


func bed(bed_id: String) -> WardBed:
	return stations.get(bed_id) as WardBed


# --- People -------------------------------------------------------------------

func _build_people() -> void:
	_person("iyer", {"skin": 3, "face": 1, "height": 3, "hair_style": 7, "hair_colour": 5, "brows": 0, "glasses": 4,
		"scrubs": 1, "watch": true}, AvatarConfig.Mood.FOCUSED)
	_person("grace", {"skin": 7, "face": 0, "hair_style": 6, "hair_colour": 0, "scrubs": 4, "coat": false,
		"stethoscope": false, "watch": true, "brows": 2}, AvatarConfig.Mood.HAPPY)
	_person("priya", {"skin": 6, "face": 3, "hair_style": 8, "hair_colour": 0, "eyes": 7, "scrubs": 2, "coat": false,
		"stethoscope": false, "watch": true}, AvatarConfig.Mood.CALM)
	_person("sethi", {"skin": 4, "face": 2, "height": 4, "hair_style": 2, "hair_colour": 1, "facial_hair": 4,
		"scrubs": 6, "brows": 2}, AvatarConfig.Mood.TIRED)
	_person("rao", {"skin": 5, "face": 5, "height": 2, "body": 2, "hair_style": 1, "hair_colour": 6, "glasses": 2,
		"facial_hair": 2, "scrubs": 1, "brows": 5}, AvatarConfig.Mood.CALM)
	_person("malhotra", {"skin": 2, "face": 4, "height": 3, "hair_style": 2, "hair_colour": 5, "glasses": 3,
		"scrubs": 6, "coat": false, "stethoscope": false, "watch": true, "brows": 3}, AvatarConfig.Mood.FOCUSED, "casual")
	_person("rohit", {"skin": 6, "face": 4, "body": 0, "height": 3, "hair_style": 3, "hair_colour": 0, "brows": 2,
		"coat": false, "stethoscope": false}, AvatarConfig.Mood.TIRED, "patient")
	_person("sunita", {"skin": 6, "face": 0, "body": 1, "height": 1, "hair_style": 8, "hair_colour": 1, "brows": 4,
		"scrubs": 4, "coat": false, "stethoscope": false}, AvatarConfig.Mood.WORRIED, "kurta")
	_person("lakshmi", {"skin": 7, "face": 5, "body": 2, "height": 1, "hair_style": 7, "hair_colour": 5, "brows": 4,
		"glasses": 1, "coat": false, "stethoscope": false}, AvatarConfig.Mood.WORRIED, "patient")
	_person("kunal", {"skin": 3, "face": 2, "body": 1, "height": 3, "hair_style": 2, "hair_colour": 3, "facial_hair": 1,
		"scrubs": 7, "coat": false, "stethoscope": false, "watch": true}, AvatarConfig.Mood.ANGRY, "casual")
	_person("banerjee", {"skin": 2, "face": 0, "body": 0, "height": 0, "hair_style": 7, "hair_colour": 6, "brows": 3,
		"glasses": 5, "coat": false, "stethoscope": false}, AvatarConfig.Mood.TIRED, "patient")
	_person("salim", {"skin": 6, "face": 4, "body": 0, "height": 2, "hair_style": 0, "hair_colour": 0, "facial_hair": 4,
		"brows": 2, "coat": false, "stethoscope": false}, AvatarConfig.Mood.TIRED, "patient")
	_person("joseph", {"skin": 4, "face": 4, "body": 0, "height": 2, "hair_style": 1, "hair_colour": 6, "glasses": 4,
		"facial_hair": 2, "brows": 3, "coat": false, "stethoscope": false}, AvatarConfig.Mood.CALM, "patient")
	_person("maria", {"skin": 4, "face": 1, "body": 1, "height": 2, "hair_style": 9, "hair_colour": 1, "brows": 1,
		"scrubs": 5, "coat": false, "stethoscope": false}, AvatarConfig.Mood.WORRIED, "kurta")
	_person("peter", {"skin": 4, "face": 2, "body": 2, "height": 3, "hair_style": 0, "hair_colour": 2, "facial_hair": 1,
		"scrubs": 1, "coat": false, "stethoscope": false}, AvatarConfig.Mood.ANGRY, "casual")
	_person("leela", {"skin": 4, "face": 3, "hair_style": 5, "hair_colour": 1, "eyes": 2, "scrubs": 2, "coat": false,
		"stethoscope": false}, AvatarConfig.Mood.WORRIED, "kurta")
	var child := _person("aarav", {"skin": 4, "face": 0, "eyes": 4, "hair_style": 3, "hair_colour": 0, "scrubs": 7,
		"coat": false, "stethoscope": false}, AvatarConfig.Mood.HAPPY, "casual")
	child.scale = Vector3.ONE * 0.64
	_person("tom", {"skin": 3, "face": 2, "hair_style": 2, "hair_colour": 0, "facial_hair": 1, "scrubs": 1, "coat": false,
		"stethoscope": false, "height": 3}, AvatarConfig.Mood.HAPPY)
	_person("khan", {"skin": 4, "face": 4, "hair_style": 10, "hair_colour": 0, "brows": 1, "scrubs": 3, "coat": false,
		"height": 2}, AvatarConfig.Mood.FOCUSED)
	# Eight months later: the Junior Resident's patients.
	_person("deepa", {"skin": 5, "face": 3, "body": 1, "height": 2, "hair_style": 8, "hair_colour": 0, "brows": 2,
		"scrubs": 2, "coat": false, "stethoscope": false}, AvatarConfig.Mood.WORRIED, "kurta")
	_person("bansal", {"skin": 3, "face": 5, "body": 2, "height": 2, "hair_style": 1, "hair_colour": 6, "glasses": 3,
		"facial_hair": 2, "brows": 4, "coat": false, "stethoscope": false}, AvatarConfig.Mood.TIRED, "patient")
	_person("farida", {"skin": 4, "face": 1, "body": 1, "height": 1, "hair_style": 9, "hair_colour": 1, "brows": 1,
		"glasses": 1, "coat": false, "stethoscope": false}, AvatarConfig.Mood.CALM, "patient")
	_person("raju", {"skin": 7, "face": 2, "body": 1, "height": 3, "hair_style": 0, "hair_colour": 0, "facial_hair": 4,
		"brows": 3, "coat": false, "stethoscope": false}, AvatarConfig.Mood.WORRIED, "patient")
	_person("mehra", {"skin": 2, "face": 0, "body": 2, "height": 1, "hair_style": 7, "hair_colour": 6, "brows": 4,
		"glasses": 5, "scrubs": 5, "coat": false, "stethoscope": false, "watch": true}, AvatarConfig.Mood.ANGRY, "kurta")
	# A year later: the Senior Resident's intern, patients and colleagues.
	_person("zoya", {"skin": 3, "face": 3, "height": 1, "hair_style": 6, "hair_colour": 1, "eyes": 7, "brows": 1,
		"scrubs": 2, "watch": true}, AvatarConfig.Mood.WORRIED)
	_person("bhatt", {"skin": 5, "face": 2, "body": 2, "height": 4, "hair_style": 1, "hair_colour": 0, "facial_hair": 4,
		"brows": 2, "scrubs": 3}, AvatarConfig.Mood.HAPPY)
	_person("gomes", {"skin": 4, "face": 5, "body": 0, "height": 0, "hair_style": 7, "hair_colour": 6, "brows": 4,
		"glasses": 5, "coat": false, "stethoscope": false}, AvatarConfig.Mood.CALM, "patient")
	_person("francis", {"skin": 4, "face": 2, "body": 2, "height": 3, "hair_style": 2, "hair_colour": 5, "facial_hair": 2,
		"brows": 3, "scrubs": 1, "coat": false, "stethoscope": false, "watch": true}, AvatarConfig.Mood.WORRIED, "casual")
	_person("nanda", {"skin": 3, "face": 5, "body": 2, "height": 2, "hair_style": 0, "hair_colour": 5, "facial_hair": 2,
		"glasses": 2, "brows": 3, "coat": false, "stethoscope": false}, AvatarConfig.Mood.TIRED, "patient")
	_person("imran", {"skin": 6, "face": 4, "body": 0, "height": 3, "hair_style": 3, "hair_colour": 0, "facial_hair": 1,
		"brows": 2, "coat": false, "stethoscope": false}, AvatarConfig.Mood.WORRIED, "patient")
	_person("rubina", {"skin": 6, "face": 1, "height": 1, "hair_style": 10, "hair_colour": 0, "eyes": 1, "brows": 1,
		"scrubs": 4, "coat": false, "stethoscope": false}, AvatarConfig.Mood.WORRIED, "kurta")
	# Three months a surgeon: the first patient on your own list, your own
	# theatre team, and the chair of the board.
	_person("kurup", {"skin": 6, "face": 5, "body": 2, "height": 1, "hair_style": 7, "hair_colour": 6, "brows": 4,
		"glasses": 1, "coat": false, "stethoscope": false}, AvatarConfig.Mood.TIRED, "patient")
	_person("venu", {"skin": 6, "face": 4, "body": 1, "height": 2, "hair_style": 1, "hair_colour": 6, "facial_hair": 2,
		"glasses": 3, "brows": 3, "scrubs": 5, "coat": false, "stethoscope": false}, AvatarConfig.Mood.WORRIED, "casual")
	_person("neha", {"skin": 3, "face": 1, "height": 2, "hair_style": 10, "hair_colour": 0, "eyes": 3, "brows": 1,
		"scrubs": 2, "coat": false, "stethoscope": false}, AvatarConfig.Mood.FOCUSED)
	_person("bose", {"skin": 4, "face": 2, "body": 1, "height": 3, "hair_style": 2, "hair_colour": 1, "facial_hair": 3,
		"glasses": 2, "brows": 2, "scrubs": 3, "coat": false}, AvatarConfig.Mood.HAPPY)
	_person("rajan", {"skin": 5, "face": 0, "body": 1, "height": 2, "hair_style": 7, "hair_colour": 6, "brows": 3,
		"glasses": 4, "scrubs": 6, "coat": false, "stethoscope": false, "watch": true}, AvatarConfig.Mood.CALM, "kurta")
	# Six months a head of department: the day case that came back, the
	# rival for Chief of Medicine, the Dean, and a new intern of your own.
	_person("sinha", {"skin": 4, "face": 1, "body": 1, "height": 2, "hair_style": 9, "hair_colour": 5, "brows": 3,
		"glasses": 1, "coat": false, "stethoscope": false}, AvatarConfig.Mood.TIRED, "patient")
	_person("kapoor", {"skin": 3, "face": 2, "body": 1, "height": 4, "hair_style": 2, "hair_colour": 0, "facial_hair": 3,
		"brows": 2, "scrubs": 1, "coat": false, "stethoscope": false, "watch": true}, AvatarConfig.Mood.HAPPY, "casual")
	_person("dean", {"skin": 4, "face": 5, "body": 2, "height": 2, "hair_style": 1, "hair_colour": 6, "facial_hair": 4,
		"glasses": 1, "brows": 4, "scrubs": 5, "coat": false, "stethoscope": false}, AvatarConfig.Mood.CALM, "kurta")
	_person("saxena", {"skin": 5, "face": 3, "height": 1, "hair_style": 6, "hair_colour": 0, "eyes": 5, "brows": 1,
		"scrubs": 1}, AvatarConfig.Mood.WORRIED)
	# Patients who sleep through the week, so the ward is full.
	_person("bg1", {"skin": 8, "face": 5, "body": 2, "hair_style": 1, "hair_colour": 5, "facial_hair": 5,
		"coat": false, "stethoscope": false}, AvatarConfig.Mood.TIRED, "patient")
	_person("bg2", {"skin": 1, "face": 1, "hair_style": 9, "hair_colour": 2, "coat": false, "stethoscope": false},
		AvatarConfig.Mood.CALM, "patient")
	_person("bg3", {"skin": 5, "face": 3, "body": 1, "hair_style": 0, "hair_colour": 0, "facial_hair": 2,
		"coat": false, "stethoscope": false}, AvatarConfig.Mood.TIRED, "patient")
	for id: String in people:
		_hide(id)


func _person(id: String, look: Dictionary, mood: int, outfit: String = "doctor") -> AvatarRig:
	var config := AvatarConfig.new()
	for key: String in look:
		config.set(key, look[key])
	var rig := AvatarRig.new(config)
	rig.name = id.capitalize().replace(" ", "")
	rig.outfit = outfit
	rig.mood = mood
	rig.voice_pitch = float(StoryBook.cast().get(id, {}).get("voice", 1.0))
	add_child(rig)
	people[id] = {"rig": rig, "home": Vector3.ZERO}
	return rig


func _actors() -> Dictionary:
	var found := {"you": player}
	for id: String in people:
		found[id] = people[id]["rig"]
	# The rider is Salim before anyone knows his name.
	found["rider"] = people["salim"]["rig"]
	return found


func rig_for(id: String) -> AvatarRig:
	if id == "you":
		return player
	if id == "rider":
		id = "salim"
	return people[id]["rig"] if people.has(id) else null


## Who is visible on the ward now.
func present(id: String) -> bool:
	var rig := rig_for(id)
	return rig != null and rig.visible


func _hide(id: String) -> void:
	var rig := rig_for(id)
	if rig == null:
		return
	_free_bed(rig)
	_routes.erase(id)
	rig.visible = false
	rig.sitting = false
	rig.lying = false
	rig.rotation = Vector3(0, rig.rotation.y, 0)


func _free_bed(rig: AvatarRig) -> void:
	for bed_id: String in BEDS:
		var station := bed(bed_id)
		if station.patient == rig:
			station.clear()


## Puts someone somewhere at once. where is "off", a bed with a pose
## ("bed2:lie", "bed2:sit"), a place by a bed ("bed2:chair", "bed2:other",
## "bed2:foot", "bed2:head", "bed2:side"), or a mark ("desk", "lightbox"...).
func put(id: String, where: String) -> void:
	var rig := rig_for(id)
	if rig == null:
		return
	if where == "off":
		_hide(id)
		return
	_free_bed(rig)
	_routes.erase(id)
	rig.visible = true
	rig.moving = 0.0
	rig.rotation = Vector3(0, rig.rotation.y, 0)
	rig.lying = false
	rig.sitting = false
	var parts := where.split(":")
	var place_name := parts[0]
	var how := parts[1] if parts.size() > 1 else ""
	if BEDS.has(place_name):
		var station := bed(place_name)
		match how:
			"lie":
				station.lay_down(rig)
				return
			"sit":
				station.sit_up(rig)
				return
			"chair":
				rig.position = station.chair_point()
				rig.sitting = true
				rig.rotation.y = station.rotation.y + PI / 2
				return
		rig.position = station.mark(how)
		_face(rig, station.pillow_point())
		return
	rig.position = mark(where)
	var facing: Variant = _mark_facing(where)
	if facing != null:
		_face(rig, facing as Vector3)
	if where.begins_with("family"):
		rig.sitting = true
		rig.rotation.y = PI
	if place_name == "seminar" and seminar.is_seat(how):
		rig.sitting = true


func _face(rig: AvatarRig, point: Vector3) -> void:
	rig.rotation.y = atan2(point.x - rig.position.x, point.z - rig.position.z)


## Named places on the floor, for put() and for stories ("walk" to a mark).
## "theatre:lead" and "seminar:seat2" are places in those rooms.
func mark(mark_name: String) -> Variant:
	var parts := mark_name.split(":")
	if BEDS.has(parts[0]):
		return bed(parts[0]).mark(parts[1] if parts.size() > 1 else "side")
	if parts[0] == "theatre" and parts.size() > 1:
		return _theatre_mark(parts[1])
	if parts[0] == "seminar" and parts.size() > 1:
		return seminar.mark(parts[1])
	match mark_name:
		"desk":
			return DESK + Vector3(0, 0, 0.85)
		"desk:behind":
			return DESK + Vector3(0.3, 0, -0.75)
		"desk:left":
			return DESK + Vector3(-1.75, 0, 0.35)
		"desk:right":
			return DESK + Vector3(1.75, 0, 0.45)
		"desk:far":
			return DESK + Vector3(-1.1, 0, 1.25)
		"lightbox":
			return (stations["scan"] as LabStation).at(Vector3(0, 0, 0.85))
		"lightbox:left":
			return (stations["scan"] as LabStation).at(Vector3(-0.85, 0, 1.0))
		"lightbox:right":
			return (stations["scan"] as LabStation).at(Vector3(0.85, 0, 1.2))
		"lightbox:far":
			return (stations["scan"] as LabStation).at(Vector3(0.2, 0, 1.75))
		"door":
			return DOOR
		"family:1":
			return FAMILY + Vector3(-0.6, 0, 0.35)
		"family:2":
			return FAMILY + Vector3(0.0, 0, 0.35)
		"family:3":
			return FAMILY + Vector3(0.6, 0, 0.35)
	return null


func _mark_facing(mark_name: String) -> Variant:
	if mark_name.begins_with("theatre:"):
		return table.at(Vector3(0.2, 0, 0)) if not mark_name.ends_with("door") else table.at(Vector3(0, 0, 3))
	if mark_name.begins_with("seminar:"):
		return seminar.facing(mark_name.substr(8))
	match mark_name:
		"desk", "desk:far":
			return DESK
		"desk:behind":
			return DESK + Vector3(0, 0, 2.0)
		"desk:left", "desk:right":
			return DESK + Vector3(0, 0, 0.85)
		"lightbox", "lightbox:left", "lightbox:right", "lightbox:far":
			return (stations["scan"] as LabStation).at(Vector3(0, 1.5, 0))
		"door":
			return Vector3(0, 0, 0)
	return null


## Where the theatre team stands round the table: "you" (the operating
## doctor), "lead" (across the table), "scrub" (Tom, by his trolley),
## "anaesthetist" (at the head) and "door".
func _theatre_mark(which: String) -> Variant:
	match which:
		"you":
			return table.at(table.spot + Vector3(0, 0, 0.12))
		"lead":
			return table.at(Vector3(0.18, 0, -0.66))
		"scrub":
			return table.at(Vector3(0.95, 0, 0.62))
		"anaesthetist":
			return table.at(Vector3(-1.3, 0, 0.3))
		"door":
			return table.at(Vector3(-3.6, 0, 1.6))
	return null


## Applies a list of [who, where, condition?] placements (see WardStory).
## where can also be "hold:item[:L]" or "drop" for what someone carries.
func _apply_puts(list: Array) -> void:
	for entry: Array in list:
		if entry.size() > 2 and not WardStory.holds(profile, str(entry[2])):
			continue
		var who := str(entry[0])
		var where := str(entry[1])
		var rig := rig_for(who)
		if rig == null:
			continue
		if where.begins_with("hold:"):
			var held := where.split(":")
			rig.hold(held[1], held[2] if held.size() > 2 else "R")
		elif where == "drop":
			rig.drop()
		else:
			put(who, where)


## Where each patient is at the start of a day, following the story.
func _stage_day() -> void:
	for id: String in people:
		_hide(id)
	for bed_id: String in BEDS:
		bed(bed_id).clear()
	var banerjee_side := profile.has_flag("banerjee_room") or profile.has_flag("kunal_home")
	match profile.day:
		4:
			put("rohit", "bed1:lie")
			put("sunita", "bed1:chair")
			put("bg1", "bed3:lie")
			put("bg2", "bed4:lie")
			put("banerjee", "bed5:lie")
			put("bg3", "bed6:lie")
			put("grace", "desk:behind")
			put("iyer", "desk:left")
			put("you", "desk")
		5:
			if profile.has_flag("beds_agreed"):
				put("bg1", "bed1:lie")
				put("lakshmi", "bed2:lie")
			else:
				put("rohit", "bed1:sit")
				put("lakshmi", "bed2:lie")
				put("bg1", "bed3:lie")
			put("bg2", "bed4:lie")
			put("banerjee", "bed5:lie")
			put("bg3", "bed6:lie")
			put("grace", "desk:behind")
			put("iyer", "desk:left")
			put("you", "desk")
		6:
			put("bg1", "bed1:lie")
			put("lakshmi", "bed2:lie")
			put("bg3", "bed6:lie")
			if profile.has_flag("kunal_room"):
				put("kunal", "side:sit")
				put("banerjee", "bed5:lie")
			else:
				put("banerjee", "side:lie")
				if profile.has_flag("banerjee_room"):
					put("kunal", "bed5:sit")
			put("priya", "desk:behind")
			put("sethi", "desk:left")
			put("you", "desk")
		7:
			put("bg1", "bed1:lie")
			put("lakshmi", "bed2:sit")
			if profile.has_flag("rider_treated"):
				put("salim", "bed4:lie")
			put("banerjee", "side:lie" if banerjee_side else "bed5:lie")
			put("joseph", "bed6:lie")
			put("maria", "bed6:chair")
			put("peter", "bed6:other")
			put("grace", "desk:behind")
			put("iyer", "desk:left")
			put("you", "desk")
		_:
			if WardStory.STAGING.has(profile.day):
				_apply_puts(WardStory.STAGING[profile.day])
			elif profile.day > WardStory.FIRST_DAY:
				_apply_puts(WardStory.QUIET_STAGING)
			else:
				put("bg1", "bed1:lie")
				put("bg2", "bed3:lie")
				put("joseph", "bed6:lie")
				put("banerjee", "side:sit" if banerjee_side else "bed5:sit")
				if profile.has_flag("rider_treated"):
					put("salim", "bed4:sit")
				put("grace", "desk:behind")
				put("iyer", "desk:left")
				put("you", "desk")
	var you := rig_for("you")
	_face(you, DESK)


## Who moves where as a beat starts.
func _stage_beat(entry: Dictionary) -> void:
	_go_to_place(str(entry.get("where", "ward")))
	if entry.has("slide"):
		seminar.slide.text = str(entry["slide"])
	_apply_puts(entry.get("put", []))
	match "%d:%s" % [profile.day, entry.get("id", "")]:
		"4:rohit":
			_send("iyer", bed("bed1").mark("other"), PEOPLE_SPEED)
		"4:lakshmi":
			put("lakshmi", "trolley:lie")
			put("priya", "trolley:other")
			_send("iyer", bed("trolley").mark("foot"), PEOPLE_SPEED)
		"4:arjun":
			put("lakshmi", "bed2:sit")
			put("priya", "off")
			put("iyer", "desk:left")
			(rig_for("lakshmi") as AvatarRig).hold("phone")
		"4:beds":
			put("malhotra", "desk:right")
			(rig_for("lakshmi") as AvatarRig).drop()
			put("lakshmi", "bed2:lie")
		"5:kunal":
			put("kunal", "trolley:sit")
			put("priya", "trolley:other")
			(rig_for("kunal") as AvatarRig).hold("phone", "L")
		"5:aarav":
			put("leela", "lightbox:right")
			put("aarav", "lightbox:far")
			put("iyer", "lightbox:left")
		"6:late":
			put("rider", "trolley:lie")
			put("priya", "trolley:other")
			put("sethi", "off")
		"7:joseph":
			_send("iyer", bed("bed6").at(Vector3(1.45, 0, -0.4)), PEOPLE_SPEED)
		"7:rao":
			put("rao", "desk:right")
			put("malhotra", "desk:far")
			put("iyer", "desk:left")
		"8:review":
			put("rao", "desk:right")
			put("sethi", "desk:far")
			put("iyer", "desk:left")
		_:
			if entry.get("id", "") == "films":
				put("iyer", "lightbox:left")


# --- The day ----------------------------------------------------------------------

func _begin_day() -> void:
	for flag: String in DAY_FLAGS.get(profile.day, WardStory.DAY_FLAGS.get(profile.day, [])):
		profile.set_flag(flag, false)
	for case_id: String in DAY_CASES.get(profile.day, WardStory.DAY_CASES.get(profile.day, [])):
		for flag: String in profile.flags.keys():
			if flag.begins_with(case_id + "_"):
				profile.set_flag(flag, false)
	night = profile.day == NIGHT_DAY or profile.day in WardStory.NIGHTS
	if night:
		profile.minutes = maxi(profile.minutes, NIGHT_START)
	_set_night(night)
	beats = _beats_for(profile.day)
	beat_index = -1
	done_beats.clear()
	results.clear()
	shift_xp = 0
	mode = "story"
	place = ""
	_go_to_place("ward")
	operation = null
	_stage_day()
	hud.set_talking(true)
	if WardStory.TIME_JUMPS.has(profile.day):
		# Months pass between ranks: say so before the day starts.
		var jump: Array = WardStory.TIME_JUMPS[profile.day]
		profile.set_flag("jump_%d" % profile.day)
		overlay.fade("black", 0.01)
		overlay.card(str(jump[0]), str(jump[1]), 3.2)
		_day_card_in = 3.4
		_clear_in = 5.2
		_intro_in = 5.8
	else:
		_show_day_card()
		_clear_in = 2.0
		_intro_in = 2.5
	_refresh_hud()


func _show_day_card() -> void:
	overlay.card("Day %d · %s" % [profile.day, profile.clock_text()], _day_line(), 2.6)


func _beats_for(day: int) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var source: Array = DAYS.get(day, WardStory.DAYS.get(day, QUIET))
	for beat: Dictionary in source:
		found.append(beat)
	return found


func _day_line() -> String:
	match profile.day:
		4:
			return "Surgical ward · Your first week"
		5:
			return "Surgical ward · Beds are short"
		6:
			return "On call tonight · Dr. Sethi is senior"
		7:
			return "Surgical ward · Dr. Rao's round"
		8:
			return "Review day"
	return str(WardStory.DAY_LINES.get(profile.day, "Surgical ward · A quiet day"))


func beat() -> Dictionary:
	return beats[beat_index] if beat_index >= 0 and beat_index < beats.size() else {}


func _beat_open(entry: Dictionary) -> bool:
	if not entry.has("if"):
		return true
	return WardStory.holds(profile, str(entry["if"]))


## Starts the next beat whose condition holds, or ends the day.
func _next_beat() -> void:
	beat_index += 1
	while beat_index < beats.size() and not _beat_open(beats[beat_index]):
		beat_index += 1
	if beat_index >= beats.size():
		_end_day()
		return
	var current := beat()
	task_queue = (current.get("tasks", []) as Array).duplicate(true)
	if place != "theatre":
		Music.cue(_place_music())
	_stage_beat(current)
	if current.has("at"):
		profile.minutes = maxi(profile.minutes, int(current["at"]))
	if current.has("card"):
		var lines: Array = current["card"]
		mode = "story"
		hud.set_talking(true)
		_pass_card_time(current)
		overlay.fade("black", 0.6)
		overlay.card(str(lines[0]), str(lines[1]), 2.6)
		_clear_in = 2.2
		_beat_in = 2.8
		_refresh_hud()
		return
	if current.has("go"):
		_back_to_walking()
		if not hud.pager_text().is_empty():
			Sfx.play(self, "pager", -6.0)
		return
	_talk(str(current.get("talk", "")), str(current.get("with", "")))


## A card beat moves the clock on (the night's 02:10).
func _pass_card_time(entry: Dictionary) -> void:
	if entry.get("id", "") == "late":
		profile.minutes = maxi(profile.minutes, NIGHT_LATE)


func _finish_beat() -> void:
	var current := beat()
	done_beats.append(str(current.get("id", "")))
	profile.pass_minutes(int(current.get("minutes", 25)))
	save_requested.emit()
	_next_beat()


func _refresh_hud() -> void:
	var rows := []
	for index in beats.size():
		var entry := beats[index]
		if str(entry.get("row", "")).is_empty() or not _beat_open(entry):
			continue
		if index > beat_index:
			break
		rows.append([str(entry["row"]), str(entry.get("id", "")) in done_beats])
	hud.set_tasks(rows, "On call" if night else ("Review day" if REVIEWS.has(profile.day) else "Ward round"))
	var current := beat()
	var walking := mode == "walk" or mode == "approach"
	hud.set_pager(str(current.get("page", "")) if walking else "")
	hud.set_clock("Day %d · %s · %s" % [profile.day, profile.clock_text(), _place_title()])
	if walking and current.has("go"):
		hud.set_hint("Tap %s · tap the floor to walk" % _place_phrase(_go_place()))
	else:
		hud.set_hint("")


## Where the doctor is, for the clock line.
func _place_title() -> String:
	match place:
		"theatre":
			return str(operation.procedure.get("theatre", "Theatre 2")) if operation != null else "Theatre 2"
		"seminar":
			return "Seminar room"
	return "On call" if night else "Ward 4"


## Where the current beat sends the doctor: a bed id, "desk" or "lightbox".
func _go_place() -> String:
	var place := str(beat().get("go", ""))
	if place == "banerjee":
		var rig := rig_for("banerjee")
		for bed_id: String in BEDS:
			if bed(bed_id).patient == rig:
				return bed_id
		return "bed5"
	return place


## How the hint names a place: "Bed 2", "the admissions bay"...
func _place_phrase(place: String) -> String:
	match place:
		"trolley":
			return "the admissions bay"
		"side":
			return "the side room"
		"desk":
			return "the nurses' station"
		"lightbox":
			return "the X-ray viewer"
	return str(BEDS.get(place, ["", "", place])[2])


## The floating tag over a place: "Bed 1 · Rohit Kulkarni", "Nurses' station".
func _tag_text(place: String) -> String:
	match place:
		"trolley":
			return "Admissions"
		"desk":
			return "Nurses' station"
		"lightbox":
			return "X-ray viewer"
	var label := str(BEDS.get(place, ["", "", place])[2])
	var patient := bed(place).patient if BEDS.has(place) else null
	for id: String in people:
		if patient != null and people[id]["rig"] == patient:
			return label + " · " + str(StoryBook.cast().get(id, {}).get("name", ""))
	return label


func _talk(key: String, partner: String) -> void:
	var steps := StoryBook.conversation("ward", key)
	for chapter: String in WardStory.CHAPTERS:
		if steps.is_empty():
			steps = StoryBook.conversation(chapter, key)
	mode = "story"
	conversation = key
	talking_with = partner
	story.focus = partner if story.runner.start_trust(partner) >= 0 else ""
	_camera_speaker = partner
	_camera_mode = "talk"
	hud.set_talking(true)
	_refresh_hud()
	story.play(steps)


func _on_talk_finished(_skipped: bool) -> void:
	var finished := conversation
	conversation = ""
	talking_with = ""
	var current := beat()
	_after_talk(finished)
	if finished == str(current.get("talk", "")):
		_apply_puts(current.get("put_talked", []))
		_run_tasks()
	elif finished == str(current.get("brief", "")) and place == "theatre":
		open_operation(_queued_procedure)
	elif finished == str(current.get("after", "")):
		_apply_puts(current.get("put_end", []))
		_finish_beat()
	save_requested.emit()


## What a finished conversation changes on the ward.
func _after_talk(key: String) -> void:
	match key:
		"lakshmi_after":
			put("lakshmi", "bed2:lie")
			put("priya", "off")
		"kunal_room":
			(rig_for("kunal") as AvatarRig).drop("L")
			if profile.has_flag("kunal_room"):
				put("kunal", "side:sit")
			else:
				put("banerjee", "side:lie")
				if profile.has_flag("banerjee_room"):
					put("kunal", "bed5:sit")
				else:
					put("kunal", "off")
			put("malhotra", "off")
			put("priya", "off")
		"aarav_after":
			put("leela", "off")
			put("aarav", "off")
			put("iyer", "desk:left")
		"rider_after":
			put("rider", "bed4:lie" if profile.has_flag("rider_treated") else "off")
			put("priya", "desk:behind")
		"joseph_family":
			put("maria", "bed6:chair")
			put("peter", "bed6:other")
		"review", "review_senior", "review_surgeon", "review_hod", "board_vote":
			_promote()


## Plays the beat's tasks in turn, then its last conversation.
func _run_tasks() -> void:
	if not task_queue.is_empty():
		var next: Array = task_queue.pop_front()
		if str(next[0]) == "operate":
			_enter_theatre(str(next[1]))
		else:
			open_task(str(next[0]), str(next[1]))
		return
	var current := beat()
	if current.has("after"):
		_talk(str(current["after"]), str(current.get("with", "iyer")))
	else:
		_apply_puts(current.get("put_end", []))
		_finish_beat()


func _back_to_walking() -> void:
	mode = "walk"
	active = ""
	_camera_mode = "follow"
	hud.set_talking(false)
	_refresh_hud()


## The review's promotion: up a rank, with experience topped up to the new
## rank's first level if the work so far fell short of it.
func _promote() -> void:
	var before := profile.total_xp
	var next := Rank.next(profile.rank_held)
	var needed := LevelCurve.total_xp_to_reach(Rank.FIRST_LEVELS[next]) if next >= 0 else 0
	profile.total_xp += maxi(REVIEW_XP, needed - profile.total_xp)
	profile.promote()
	profile.set_flag("promoted")
	Music.fanfare()
	overlay.celebrate()
	hud.refresh_profile()
	hud.toast("+%d XP · %s" % [profile.total_xp - before, Rank.title(profile.rank())])


func _end_day() -> void:
	mode = "end"
	hud.set_talking(true)
	shift_xp = SHIFT_XP
	profile.total_xp += SHIFT_XP
	profile.set_flag("ward_day%d" % profile.day)
	if not night:
		profile.minutes = maxi(profile.minutes, 18 * 60 + 30)
	var title := "Day %d · %s" % [profile.day, "07:00" if night else profile.clock_text()]
	if REVIEWS.has(profile.day):
		title = "%s · %s" % [profile.full_title(), Rank.title(profile.rank())]
	overlay.card(title, _end_line() + "   +%d XP" % SHIFT_XP, DAY_END_DELAY)
	_end_in = DAY_END_DELAY
	hud.refresh_profile()
	_refresh_hud()
	save_requested.emit()


func _end_line() -> String:
	match profile.day:
		4:
			if profile.has_flag("beds_agreed"):
				return "Two beds freed by noon. Mr. Malhotra is delighted."
			return "Rohit ate toast. Lakshmi's gallbladder is on tomorrow's list."
		5:
			if profile.has_flag("aarav_battery_found"):
				return "The battery is out. Aarav wants to keep it."
			return "The battery is out, just in time. Aarav is fine."
		6:
			if profile.has_flag("rider_treated"):
				return "Salim Sheikh is in recovery. Someone called Pooja is on her way."
			return "Salim Sheikh is in intensive care. He'll live, just."
		7:
			if profile.has_flag("beds_saved"):
				return "Ward 4 keeps its beds. For now."
			return "Mr. Fernandes has a tube and a plan. Ward 4's beds are on the board's agenda."
		8:
			return "Junior Resident, from Monday."
	var story_line := WardStory.end_line(profile, profile.day)
	return story_line if not story_line.is_empty() else "A quiet day. Quiet days are rare."


# --- Walking ----------------------------------------------------------------------

## A tap in the world: the place the beat sends the doctor, or the floor.
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
	var point := floor_point as Vector3
	_send("you", Vector3(point.x, 0, point.z), WALK_SPEED)


## The place to walk to under a screen point, or "".
func place_at(screen_point: Vector2) -> String:
	var place := _go_place()
	if place.is_empty():
		return ""
	var point := _tag_point(place)
	if camera.is_position_behind(point):
		return ""
	return place if camera.unproject_position(point).distance_to(screen_point) < UiKit.px(48) else ""


func _tag_point(place: String) -> Vector3:
	if BEDS.has(place):
		return bed(place).at(bed(place).tag_point)
	match place:
		"desk":
			return DESK + Vector3(0, 1.75, 0)
		"lightbox":
			return (stations["scan"] as LabStation).at(Vector3(0, 2.2, 0.1))
	return Vector3.ZERO


## Walks to the place the current beat needs.
func go_to(place: String) -> void:
	if place != _go_place() or story.is_playing() or mode not in ["walk", "approach"]:
		return
	mode = "approach"
	var spot: Vector3 = mark(place) if place != "desk" else DESK + Vector3(-0.35, 0, 0.85)
	_send("you", spot, WALK_SPEED)
	if not _routes.has("you"):
		_arrive()


func _arrive() -> void:
	var place := _go_place()
	player.moving = 0.0
	if BEDS.has(place):
		_face(player, bed(place).pillow_point())
	else:
		var facing: Variant = _mark_facing(place)
		if facing != null:
			_face(player, facing as Vector3)
	active_bed = place if BEDS.has(place) else active_bed
	var current := beat()
	var partner := rig_for(str(current.get("with", "")))
	if place == "lightbox" and current.has("talk") and partner != null and partner.visible:
		# A talk by the films, not a look at them: turn to each other.
		_face(player, partner.position)
		_face(partner, player.position)
	if current.has("talk"):
		_talk(str(current["talk"]), str(current.get("with", "")))
	else:
		_run_tasks()


func _send(who: String, to: Vector3, speed: float) -> void:
	var id := "salim" if who == "rider" else who
	var rig := rig_for(id)
	if rig == null:
		return
	rig.sitting = false
	rig.lying = false
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
	_routes[id] = {"path": path, "speed": speed}


func is_walking(id: String) -> bool:
	return _routes.has("salim" if id == "rider" else id)


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
		rig.position = Vector3(me.x, 0, me.y)
		if moved.length() > 0.0001:
			rig.rotation.y = lerp_angle(rig.rotation.y, atan2(moved.x, moved.y), minf(1.0, delta * 10.0))
		rig.moving = 1.0
		route["path"] = path
		if path.is_empty():
			rig.moving = 0.0
			_routes.erase(id)
			if _leaving.has(id):
				_leaving.erase(id)
				_hide(id)
			elif id == "you" and mode == "approach":
				_arrive()
			elif id != "you":
				_face(rig, player.position)


# --- Tasks ------------------------------------------------------------------------

## Opens a task with a patient: "history", "exam" or "scan", for a case.
func open_task(task_id: String, which_case: String) -> void:
	active = task_id
	mode = "task"
	var task: TrainingTask
	if task_id == "chart":
		# What the doctor found out before the chart was written decides some lines.
		var forced := {}
		var rules: Dictionary = beat().get("chart_force", {})
		for line_id: String in rules:
			forced[line_id] = WardStory.holds(profile, str(rules[line_id]))
		task = ChartTask.new(which_case, _case_seed("chart"), _case_level(beat()), forced)
	elif task_id == "triage":
		task = TriageTask.new(which_case, _case_seed("triage"), _case_level(beat()))
	elif task_id == "rota":
		task = RotaTask.new(which_case, _case_seed("rota"), _case_level(beat()))
	else:
		task = TrainingTask.make(task_id, 7 + profile.day * 3, which_case)
	if task_id == "scan":
		view = ScanView.new(task, self)
	elif task_id == "chart":
		# At the nurses' station, side by side with the intern who wrote it.
		view = ChartView.new(task, self)
		talking_with = (task as ChartTask).actor
		_camera_speaker = talking_with
	elif task_id == "triage":
		# Out at the ambulance bay, with the nurse running the line.
		view = TriageView.new(task, self)
		talking_with = (task as TriageTask).actor
		_camera_speaker = talking_with
		Music.cue("emergency")
	elif task_id == "rota":
		# At the nurses' station, with the head nurse before she walks out.
		view = RotaView.new(task, self)
		talking_with = (task as RotaTask).actor
		_camera_speaker = talking_with
	else:
		var station := bed(active_bed)
		if task_id == "history":
			# Patients sit up to talk, and lie down to be examined.
			put((task as HistoryTask).actor, active_bed + ":sit")
			station.frame_for("talk")
			view = HistoryView.new(task, self)
			view.trainer = (task as HistoryTask).actor
		else:
			var exam := task as ExamTask
			if exam.body == "trauma":
				Music.cue("emergency")
			if exam.body != "wrist":
				put(exam.actor, active_bed + ":lie")
				station.uncover(true)
			else:
				# Sitting on the edge, the sore forearm held out to the doctor.
				var arm_rig: AvatarRig = rig_for(exam.actor)
				if arm_rig != null:
					arm_rig.set_gesture("hold")
					arm_rig.settle()
			station.frame_for(exam.body)
			view = ExamView.new(task, self)
	var coach := str(beat().get("coach", ""))
	if not coach.is_empty() and task_id != "history":
		view.trainer = coach
	view.name = "Training"
	view.can_retry = false
	view.done_text = "Back to the ward"
	var spot := str(BEDS.get(active_bed, ["", "", "Ward"])[2])
	if task_id == "scan":
		spot = "X-ray viewer"
	elif task_id in ["chart", "rota"]:
		spot = "Nurses' station"
	elif task_id == "triage":
		spot = "Ambulance bay"
	var shift := "Major incident" if task_id == "triage" else ("On call" if night else "Ward round")
	if task_id == "rota":
		shift = "Strike day"
	view.kicker_override = "%s · %s" % [shift, spot]
	_layer.add_child(view)
	_layer.move_child(view, talk_ui.get_index())
	view.done_pressed.connect(_on_done)
	view.task_finished.connect(_on_task_finished)
	var station_now := station_for(task_id)
	if station_now != null:
		station_now.reset_task(task)
	player.visible = task_id in ["chart", "triage", "rota"]
	hud.set_talking(true)
	_camera_mode = "talk" if task_id in ["chart", "triage", "rota"] else "close"


func _on_task_finished(task: TrainingTask) -> void:
	if task is OperationTask:
		_on_operation_finished(task as OperationTask)
		return
	var case_id := ""
	var right := false
	var seen: Array[String] = []
	var patient := ""
	if task is HistoryTask:
		var history := task as HistoryTask
		case_id = history.case_id
		seen = history.asked
		patient = history.actor
		right = history.notes().size() > 0 and bool(history.notes()[0]["ok"])
	elif task is ExamTask:
		var exam := task as ExamTask
		case_id = exam.case_id
		seen = exam.examined
		patient = exam.actor
		right = exam.diagnosed_right()
	elif task is ScanTask:
		var scan := task as ScanTask
		case_id = scan.case_id
		right = scan.answered_right()
	elif task is ChartTask:
		var chart := task as ChartTask
		case_id = chart.case_id
		seen = chart.found()
		right = chart.all_right()
		# What reaches the patient: the theatre team only knows what was fixed.
		for line_id in chart.missed():
			profile.set_flag(case_id + "_missed_" + line_id)
	elif task is TriageTask:
		var triage := task as TriageTask
		case_id = triage.case_id
		right = triage.all_right()
		# Who was sent to wait when they couldn't, for the story after.
		for casualty_id in triage.under_triaged():
			seen.append("under_" + casualty_id)
		profile.set_flag(case_id + "_under", not triage.under_triaged().is_empty())
	elif task is RotaTask:
		var rota := task as RotaTask
		case_id = rota.case_id
		right = rota.all_right()
		# Which rules gave way, and whether anyone was left with nobody.
		for rule in rota.broken_rules():
			seen.append(rule)
		profile.set_flag(case_id + "_gap", not rota.uncovered().is_empty())
	profile.set_flag(case_id + "_done")
	profile.set_flag(case_id + "_right", right)
	for item: String in seen:
		profile.set_flag(case_id + "_" + item)
	if not patient.is_empty() and story.runner.start_trust(patient) >= 0:
		profile.change_trust(patient, 3 if right else -2, story.runner.start_trust(patient))
	var xp := TASK_XP + task.score() / 2
	profile.total_xp += xp
	var best := profile.record_score(task.id, task.score())
	results.append({"id": task.id, "case": case_id, "score": task.score(), "right": right})
	profile.pass_minutes(15)
	view.show_result("+%d XP%s" % [xp, " · new best" if best else ""])
	hud.refresh_profile()
	_refresh_hud()
	save_requested.emit()


## The music for the ward as it is now: calm by day, quiet at night, or
## the beat's own ("music": "emergency" for a crash call).
func _place_music() -> String:
	if place != "theatre" and place != "seminar":
		var beat_track := str(beat().get("music", ""))
		if not beat_track.is_empty():
			return beat_track
	return "night" if night else "hospital"


func _close_task() -> void:
	if place == "ward":
		Music.cue(_place_music())
	if BEDS.has(active_bed):
		bed(active_bed).uncover(false)
		var held_out := bed(active_bed).patient
		if held_out != null and held_out.gesture == "hold":
			held_out.set_gesture("")
	if view != null:
		_layer.remove_child(view)
		view.queue_free()
		view = null
	player.visible = true
	active = ""


func _on_done() -> void:
	var was := active
	_close_task()
	_camera_mode = "talk"
	if was in Procedures.ids():
		_leave_theatre()
	_run_tasks()


## True while a task screen is open.
func in_task() -> bool:
	return view != null


func is_talking() -> bool:
	return story.is_playing()


# --- Theatre and meetings ---------------------------------------------------------

## Moves the story to "ward", "theatre" or "seminar": only that room shows,
## with its own light and music, after a quick fade.
func _go_to_place(where: String) -> void:
	if where == place:
		return
	var was := place
	place = where
	theatre_set.visible = where == "theatre"
	table.visible = where == "theatre"
	seminar.visible = where == "seminar"
	_light(night and where == "ward")
	if not was.is_empty():
		overlay.fade("black", 0.01)
		overlay.fade("clear", 0.8)
		Music.cue("theatre" if where == "theatre" else _place_music())
		_camera_mode = "talk" if where != "ward" else "follow"
		settle_camera.call_deferred()


## The doctor and the team walk into theatre for the beat's operation:
## gowned, masked, in place round the table, and the brief before it starts.
func _enter_theatre(procedure: String) -> void:
	var entry := beat()
	_queued_procedure = procedure
	var data := Procedures.get_procedure(procedure)
	mode = "story"
	hud.set_talking(true)
	var patient := str(entry.get("patient", ""))
	if not patient.is_empty():
		put(patient, "off")
	var team := _team(entry)
	var spots := ["lead", "scrub", "anaesthetist"]
	for index in spots.size():
		var who := str(team[index]) if index < team.size() else ""
		if who.is_empty():
			continue
		put(who, "theatre:" + spots[index])
		Theatre.dress_for_theatre(rig_for(who), spots[index] != "anaesthetist")
	put("you", "theatre:you")
	Theatre.dress_for_theatre(player)
	_go_to_place("theatre")
	theatre_set.show_operation(str(data.get("theatre", "Theatre 2")), "%s · %s" % [data.get("title", ""), data.get("patient", "")])
	_refresh_hud()
	if entry.has("brief"):
		_talk(str(entry["brief"]), str(team[2]) if team.size() > 2 and not str(team[2]).is_empty() else str(team[0]))
	else:
		open_operation(procedure)


## Opens the operation on the table with its screen. What the team knows
## (what the doctor found out on the ward) and how hard the case is come
## from the beat; the case itself is laid out at random.
func open_operation(procedure: String) -> void:
	var entry := beat()
	active = procedure
	mode = "task"
	var setup := {"procedure": procedure, "called": profile.called(), "difficulty": _case_level(entry)}
	var known: Dictionary = entry.get("op_flags", {})
	for key: String in known:
		setup[key] = WardStory.holds(profile, str(known[key]))
	var team := _team(entry)
	setup["lead"] = str(team[0]) if not team.is_empty() else "iyer"
	setup["scrub_nurse"] = str(team[1]) if team.size() > 1 else "tom"
	setup["anaesthetist"] = str(team[2]) if team.size() > 2 else "khan"
	operation = OperationTask.new(_case_seed(procedure), setup)
	view = OperationView.new(operation, self, profile)
	view.name = "Training"
	view.done_text = "Back to the ward"
	_layer.add_child(view)
	_layer.move_child(view, talk_ui.get_index())
	view.done_pressed.connect(_on_done)
	view.task_finished.connect(_on_task_finished)
	table.reset_task(operation)
	player.visible = false
	hud.set_talking(true)
	_camera_mode = "close"
	Music.cue("theatre")
	_refresh_hud()


## The beat's theatre team (lead, scrub nurse, anaesthetist), with the
## doctor's own picks swapped in: "team_swap": [[1, "neha", "team_neha"]].
func _team(entry: Dictionary) -> Array:
	var team: Array = (entry.get("team", ["iyer", "tom", "khan"]) as Array).duplicate()
	for swap: Array in entry.get("team_swap", []):
		if int(swap[0]) < team.size() and WardStory.holds(profile, str(swap[2])):
			team[int(swap[0])] = str(swap[1])
	return team


## A number that is the same for this career, day and case, so a case is
## laid out the same way until the day is played again.
func _case_seed(procedure: String) -> int:
	return absi(hash("%s|%d|%s|%d" % [profile.name, profile.day, procedure, profile.total_xp])) % 1000003 + 1


## The case's difficulty: one of the beat's "levels", picked by the seed.
func _case_level(entry: Dictionary) -> String:
	var levels: Array = entry.get("levels", [])
	if levels.is_empty():
		return ""
	var dice := SeededRandom.new(_case_seed("level" + str(entry.get("id", ""))))
	return str(dice.pick(levels))


func _on_operation_finished(op: OperationTask) -> void:
	var patient := str(beat().get("patient", op.patient_first().to_lower()))
	var xp := int(OP_XP[op.outcome]) + OP_XP_PER_STAR * op.stars()
	profile.total_xp += xp
	var best := profile.record_score(op.id, op.score())
	profile.set_flag("op_%s_done" % patient)
	for outcome: String in OP_XP:
		profile.set_flag("op_%s_%s" % [patient, outcome], outcome == op.outcome)
	for which: String in op.happened:
		profile.set_flag("op_%s_%s" % [patient, which])
	var lead := str(op.setup.get("lead", "iyer"))
	var trust := {"won": 4, "struggled": 1, "failed": -3}
	profile.change_trust(lead, int(trust[op.outcome]), story.runner.start_trust(lead))
	if op.decisions_wrong == 0 and str(op.setup.get("anaesthetist", "khan")) == "khan" \
			and ("pressure" in op.happened or "reaction" in op.happened):
		profile.change_trust("khan", 3, story.runner.start_trust("khan"))
	if story.runner.start_trust(patient) >= 0:
		profile.change_trust(patient, {"won": 5, "struggled": 1, "failed": -2}[op.outcome], story.runner.start_trust(patient))
	results.append({"id": op.id, "case": patient, "score": op.score(), "right": op.outcome == "won"})
	profile.pass_minutes(55 if op.outcome == "won" else 80)
	view.show_result("+%d XP%s" % [xp, " · new best" if best else ""])
	hud.refresh_profile()
	_refresh_hud()
	save_requested.emit()


## Out of theatre, back on the ward: everyone in their own clothes, and
## the patient where the beat puts them after the operation.
func _leave_theatre() -> void:
	var entry := beat()
	for who: String in ["you", "iyer", "tom", "khan", "sethi", "rao", "bhatt", "neha", "bose"]:
		var rig := rig_for(who)
		if rig != null:
			Theatre.undress_from_theatre(rig)
	for who: String in ["tom", "khan", "neha", "bose"]:
		put(who, "off")
	_go_to_place("ward")
	_apply_puts(entry.get("put_back", []))
	var partner := rig_for(str(entry.get("with", "")))
	if partner != null and partner.visible:
		_face(player, partner.position)


# --- Night ------------------------------------------------------------------------

func _set_night(on: bool) -> void:
	Music.cue(_place_music())
	_light(on)


## The light: the ward by day or at night. The theatre and the seminar room
## always have their own lights on.
func _light(on: bool) -> void:
	_environment.background_color = NIGHT_SKY if on else Color("#A9C3C8")
	_environment.ambient_light_color = Color("#8FA6C8") if on else Color("#DDE8F0")
	_environment.ambient_light_energy = 0.26 if on else 0.42
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.light_energy = 0.32 if on else 0.8
		sun.light_color = Color("#B8C8F0") if on else Color("#FFF4E3")
	for lamp in _lamps:
		lamp.visible = on
	for window in find_children("Window", "", false, false):
		var glass := window.get_node_or_null("Glass") as MeshInstance3D
		if glass != null:
			LabStation.set_colour(glass, Color("#24344A") if on else Color("#BFE7F0"))


# --- Story hooks ------------------------------------------------------------------

func perform(step: Dictionary) -> Variant:
	var who := str(step.get("who", ""))
	match str(step["do"]):
		"arrive":
			# In at the door, then across the ward to a mark.
			put(who, "door")
			var to: Variant = mark(str(step.get("at", "desk:right")))
			_send(who, to as Vector3 if to != null else DOOR, PEOPLE_SPEED)
			return func() -> bool: return not is_walking(who)
		"leave":
			(rig_for(who) as AvatarRig).sitting = false
			_send(who, DOOR, PEOPLE_SPEED)
			_leaving["salim" if who == "rider" else who] = true
			return func() -> bool: return not is_walking(who)
		"put":
			put(who, str(step.get("at", "off")))
			return 0.0
		"card":
			overlay.card(str(step.get("title", "")), str(step.get("text", "")), 2.4)
			return 2.4
		"page":
			hud.set_pager(story.runner.fill(str(step.get("text", ""))))
			Sfx.play(self, "pager", -6.0)
			return 0.6
	return null


func on_line(speaker: String, _listener: String) -> void:
	_camera_speaker = speaker


# --- Input ------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if hud.menu_open():
		return
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_press_at = button.position
			_pressed = true
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
	if choice != "resume":
		menu_choice.emit(choice)


# --- Every frame ------------------------------------------------------------------

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
			_next_beat()
	if _day_card_in > 0.0:
		_day_card_in -= delta
		if _day_card_in <= 0.0:
			_show_day_card()
	if _beat_in > 0.0:
		_beat_in -= delta
		if _beat_in <= 0.0:
			var current := beat()
			if current.has("talk") and not current.has("go"):
				_talk(str(current["talk"]), str(current.get("with", "")))
			elif current.has("go"):
				# A moment passing, then the walk to wherever it happens.
				_back_to_walking()
				if not hud.pager_text().is_empty():
					Sfx.play(self, "pager", -6.0)
			else:
				_finish_beat()
	if _end_in > 0.0:
		_end_in -= delta
		if _end_in <= 0.0:
			day_finished.emit()
			return
	story.update(delta)
	_update_routes(delta)
	if view != null:
		view.tick(delta)
		var station := station_for(active)
		if station != null and view != null:
			station.show_task(view.task, delta)
	_place_camera(UiKit.motion_weight(minf(1.0, delta * 4.0)))
	_update_tags()


func settle_camera() -> void:
	if not is_inside_tree():
		return
	_place_camera(1.0)
	_update_tags()


func _place_camera(weight: float) -> void:
	var goal: Vector3
	var target: Vector3
	var offset := 0.0
	var fov := 42.0
	var partner := rig_for(talking_with)
	if _camera_mode == "close" and not active.is_empty() and station_for(active) != null:
		var station := station_for(active)
		goal = station.at(station.close_from)
		target = station.at(station.close_at)
		fov = station.close_fov
		offset = station.close_offset
	elif place != "ward":
		# The theatre team round the table, or the meeting round its table,
		# leaning a little towards whoever speaks.
		var pose := _room_pose()
		goal = pose[0]
		target = pose[1]
		var speaker := rig_for(_camera_speaker)
		if speaker != null and speaker.visible and speaker.position.y < -10.0:
			target = target.lerp(speaker.position + Vector3(0, 1.1 if speaker.sitting else 1.3, 0), 0.3)
		fov = 44.0
	elif _camera_mode == "talk" and partner != null and partner.visible and _bed_of(partner) != null:
		# A patient in bed: from the end of the bed, everyone round it.
		var home := _bed_of(partner)
		goal = home.at(Vector3(0.35, 2.5, 3.0))
		target = home.at(Vector3(0.0, 0.8, -0.3))
		fov = 44.0
		offset = 0.5
	elif _camera_mode == "talk" and partner != null and partner.visible \
			and _rest_point(partner).distance_to(LIGHTBOX) < 2.2 and player.position.distance_to(LIGHTBOX) < 2.2:
		# At the X-ray viewer, by the end wall: from out in the aisle, between
		# the beds and the trolley, looking back at everyone round the films.
		var box := stations["scan"] as LabStation
		goal = box.at(Vector3(-0.6, 2.1, 4.3))
		target = box.at(Vector3(-0.1, 1.15, 1.0))
		offset = 0.62
	elif _camera_mode == "talk" and partner != null and partner.visible:
		var me := player.position
		var other := _rest_point(partner)
		var middle := (me + other) / 2.0
		var across := Vector3(other.x - me.x, 0, other.z - me.z)
		across = across.normalized() if across.length() > 0.01 else Vector3(1, 0, 0)
		var side := Vector3(-across.z, 0, across.x)
		if side.z < -0.05 or (absf(side.z) <= 0.05 and side.x > 0.0):
			side = -side
		var looking := (side + Vector3(0, 0, 0.75)).normalized()
		var spot := middle + looking * 3.9
		if spot.x < ROOM_MIN_X or spot.x > ROOM_MAX_X:
			# By an end wall (the X-ray viewer): look from the room's side, not
			# from behind the wall.
			looking = (-side + Vector3(0, 0, 0.75)).normalized()
		var speaker := rig_for(_camera_speaker)
		var speaker_spot := speaker.position if speaker != null and speaker.visible else other
		var lean := middle.lerp(Vector3(speaker_spot.x, 0, speaker_spot.z), 0.25)
		var height := 0.95 if partner.sitting or partner.lying else 1.22
		goal = middle + looking * 3.9 + Vector3(0, 1.9, 0)
		target = lean + Vector3(0, height, 0)
		offset = 0.62
	else:
		var focus := player.position
		var place := _go_place() if mode == "walk" or mode == "approach" else ""
		if not place.is_empty():
			# Lean towards where the doctor is going, so it's on screen.
			var there := _tag_point(place)
			focus = focus.lerp(Vector3(there.x, 0, there.z), 0.55)
		focus.x = clampf(focus.x, -6.2, 6.4)
		focus.z = clampf(focus.z, -1.2, 1.4)
		goal = focus + Vector3(0, 5.6, 6.6)
		target = focus + Vector3(0, 0.3, -1.6)
	_camera_target = _camera_target.lerp(target, weight) if weight < 1.0 else target
	camera.position = camera.position.lerp(goal, weight) if weight < 1.0 else goal
	camera.h_offset = lerpf(camera.h_offset, offset, weight)
	camera.fov = lerpf(camera.fov, fov, weight)
	camera.look_at(_camera_target)


func _room_pose() -> Array:
	if place == "seminar":
		return seminar.camera_pose()
	return [table.at(Vector3(-1.6, 2.5, 3.3)), table.at(Vector3(0.2, 1.0, -0.2))]


## The bed someone is lying or sitting on, or null.
func _bed_of(rig: AvatarRig) -> WardBed:
	for bed_id: String in BEDS:
		if bed(bed_id).patient == rig:
			return bed(bed_id)
	return null


## Where someone is on the floor: a lying patient's middle, not their feet.
func _rest_point(rig: AvatarRig) -> Vector3:
	if rig.lying:
		for bed_id: String in BEDS:
			if bed(bed_id).patient == rig:
				return bed(bed_id).at(Vector3(0, 0, -0.15))
	return Vector3(rig.position.x, 0, rig.position.z)


func _update_tags() -> void:
	var walking := mode == "walk" or mode == "approach"
	var place := _go_place() if walking else ""
	for key: String in ["bed1", "bed2", "bed3", "bed4", "bed5", "bed6", "side", "trolley", "desk", "lightbox"]:
		var point := _tag_point(key)
		var shown := walking and key == place and not camera.is_position_behind(point)
		hud.set_tag("place_" + key, _tag_text(key), camera.unproject_position(point), shown, true)


# --- For tests and screenshots ------------------------------------------------------

## Jumps to the start of a beat (by id) on today's list, with flags set
## first. The conversations before it are skipped.
func skip_to(beat_id: String, flags: Array = []) -> void:
	_intro_in = -1.0
	_clear_in = -1.0
	overlay.fade("clear", 0.01)
	overlay.tick(10.0)
	if story.is_playing():
		story.skip()
	for flag: String in flags:
		profile.set_flag(flag)
	_day_card_in = -1.0
	_stage_day()
	for index in beats.size():
		if str(beats[index].get("id", "")) == beat_id:
			beat_index = index - 1
			break
		if _beat_open(beats[index]):
			done_beats.append(str(beats[index].get("id", "")))
			_stage_beat(beats[index])
			_pass_card_time(beats[index])
			_after_talk(str(beats[index].get("after", beats[index].get("talk", ""))))
			_apply_puts(beats[index].get("put_back", []))
			_apply_puts(beats[index].get("put_end", []))
	_next_beat()
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


## Runs the day until until() is true, talking with picker, walking to
## each place and playing tasks with bot. Returns true if until() was met.
func play_until(until: Callable, picker: Callable = Callable(), bot: AutoPlayer = null, seconds: float = 900.0) -> bool:
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
		elif mode == "walk" and not _go_place().is_empty():
			go_to(_go_place())
		update(step)
	return bool(until.call())
