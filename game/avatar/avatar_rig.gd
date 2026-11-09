class_name AvatarRig
extends Node3D
## A low-poly character built entirely in code from an AvatarConfig.
##
## The body is a set of jointed parts (hips, torso, arms, legs, head) that are
## posed procedurally every frame: idle breathing, walking, sitting, blinking
## and talking. Faces show seven moods. Rebuilding is cheap, so the avatar
## creator simply rebuilds the whole character after every change.
##
## People move while they talk: arm gestures (explaining, shrugging,
## pointing, cheering...), head movements (nods, shakes, tilts), turning the
## head towards whoever they are looking at, and a mouth that opens with each
## spoken syllable. Characters can hold props (a pager, a letter) and wear a
## few outfits besides the doctor's coat (a graduation gown, home clothes).
##
## Units are metres. The feet stand on y = 0 and the character faces +Z.

const HEIGHT_SCALES := [0.92, 0.96, 1.0, 1.04, 1.08]
const BODY_WIDTHS := [0.88, 1.0, 1.16]
const HIP_HEIGHT := 0.705
## The head is drawn large for a friendly, chunky look.
const HEAD_SCALE := 1.18
const HEAD_RADIUS := 0.17
const HEAD_CENTRE := Vector3(0.0, 0.16, 0.01)

const EYE_DARK := Color("#1E1A1A")
const MOUTH := Color("#5A2A20")
const COAT := Color("#E8EEEE")
const COAT_SHADE := Color("#D9E2E4")
const SHOE := Color("#2B2B2B")
const METAL := Color("#A9B8BB")
const TUBE := Color("#33454A")
const FRAME := Color("#1F2A2E")
const BADGE_TEAL := Color("#127C80")

## Head shape: x, y, z scale of the head sphere.
const FACE_SCALES := [
	Vector3(1.0, 0.98, 0.97), Vector3(0.93, 1.06, 0.95), Vector3(1.03, 1.0, 0.97),
	Vector3(0.99, 1.02, 0.95), Vector3(0.9, 1.1, 0.95), Vector3(1.1, 0.96, 0.98),
]
## Eye shape: width, height, half spacing, highlight size.
const EYE_SHAPES := [
	Vector4(1.0, 1.0, 0.06, 1.0), Vector4(1.15, 0.75, 0.06, 1.0), Vector4(1.0, 1.0, 0.07, 1.0),
	Vector4(1.0, 1.0, 0.051, 1.0), Vector4(1.3, 1.3, 0.062, 1.2), Vector4(0.78, 0.78, 0.058, 0.8),
	Vector4(1.05, 0.6, 0.06, 0.8), Vector4(1.12, 1.12, 0.06, 1.6),
]
## Brow style: length, thickness, arch height.
const BROW_STYLES := [
	Vector3(0.062, 0.012, 0.0), Vector3(0.064, 0.011, 0.009), Vector3(0.064, 0.02, 0.002),
	Vector3(0.058, 0.007, 0.004), Vector3(0.056, 0.011, 0.004), Vector3(0.07, 0.017, 0.0),
]
## Nose style: width, length, depth.
const NOSE_STYLES := [
	Vector3(0.022, 0.026, 0.028), Vector3(0.022, 0.055, 0.04), Vector3(0.034, 0.045, 0.034),
	Vector3(0.022, 0.07, 0.046), Vector3(0.016, 0.034, 0.026),
]
## Mood: left brow angle, brow lift, mouth points (shocked is a ring).
const MOODS := [
	{"brow": 0.0, "lift": 0.0, "mouth": [Vector2(-0.03, 0), Vector2(0.03, 0)]},
	{"brow": 0.05, "lift": 0.006, "mouth": [Vector2(-0.036, 0.008), Vector2(-0.018, -0.004), Vector2(0, -0.008), Vector2(0.018, -0.004), Vector2(0.036, 0.008)]},
	{"brow": 0.32, "lift": 0.004, "mouth": [Vector2(-0.03, -0.007), Vector2(-0.015, 0.0), Vector2(0, 0.002), Vector2(0.015, 0.0), Vector2(0.03, -0.007)]},
	{"brow": -0.16, "lift": -0.004, "mouth": [Vector2(-0.024, 0), Vector2(0.024, 0)]},
	{"brow": -0.06, "lift": -0.006, "mouth": [Vector2(-0.024, -0.002), Vector2(0, 0.001), Vector2(0.024, -0.002)]},
	{"brow": -0.36, "lift": -0.002, "mouth": [Vector2(-0.03, -0.009), Vector2(-0.015, -0.001), Vector2(0, 0.001), Vector2(0.015, -0.001), Vector2(0.03, -0.009)]},
	{"brow": 0.12, "lift": 0.018, "mouth": []},
]

## Arm gestures. Each arm is [shoulder forward, shoulder twist, arm out to
## the side, elbow bend, forearm swing, forearm tilt], written for the right
## arm; the left arm mirrors them. Negative "forward" and "bend" raise the
## arm and forearm in front of the body. "beat" moves the hands in time with
## speech; the other keys add their own motion.
const GESTURES := {
	"explain": {"R": [-0.45, 0.0, 0.2, -1.25, 0.25, 0.0], "beat": 0.16},
	"open_hands": {"R": [-0.38, 0.0, 0.32, -1.15, 0.4, 0.0], "L": [-0.38, 0.0, 0.32, -1.15, 0.4, 0.0], "beat": 0.1},
	"point": {"R": [-1.4, 0.0, 0.06, -0.1, 0.0, 0.0]},
	"shrug": {"R": [-0.12, 0.0, 0.42, -1.5, 0.55, 0.0], "L": [-0.12, 0.0, 0.42, -1.5, 0.55, 0.0], "shrug": 1.0,
		"tilt": 0.14},
	"chest": {"R": [-0.38, 0.0, -0.32, -2.0, -0.55, 0.0]},
	"wave": {"R": [-0.2, 0.0, 2.35, -0.3, 0.0, 0.0], "swing": 0.42},
	"cheer": {"R": [-0.25, 0.0, 2.65, -0.25, 0.0, 0.0], "L": [-0.25, 0.0, 2.65, -0.25, 0.0, 0.0], "bounce": 1.0},
	"clap": {"R": [-0.95, 0.0, -0.16, -1.05, -0.35, 0.0], "L": [-0.95, 0.0, -0.16, -1.05, -0.35, 0.0], "clap": 1.0},
	"think": {"R": [-0.3, 0.0, -0.3, -2.3, -0.35, 0.0], "L": [-0.32, 0.0, -0.2, -1.55, -1.0, 0.0], "tilt": 0.12},
	"offer": {"R": [-1.0, 0.0, 0.04, -0.42, 0.0, 0.0]},
	"fold_arms": {"R": [-0.32, 0.0, -0.08, -1.7, -1.15, 0.0], "L": [-0.36, 0.0, -0.08, -1.62, -1.2, 0.0]},
	"raise": {"R": [-0.3, 0.0, 2.1, -0.35, 0.0, 0.0]},
	"wag": {"R": [-0.5, 0.0, 0.1, -1.75, 0.0, 0.0], "swing": 0.28},
	"hold": {"R": [-0.38, 0.0, 0.02, -1.22, 0.0, 0.0]},
}
## Head movements: nods and shakes play once, the others hold for the line.
const HEAD_GESTURES := ["nod", "shake", "tilt", "down", "up"]
const ARM_REST := [0.0, 0.0, -0.09, -0.2, 0.0, 0.0]

## Emitted after the character has been rebuilt.
signal rebuilt

var config := AvatarConfig.new()
var mood: int = AvatarConfig.Mood.CALM
## How much the character is walking, from 0 (still) to 1 (full stride).
var moving := 0.0
var sitting := false
var talking := false
## Seconds between blinks; 0 turns blinking off (for still screenshots).
var blink_every := 3.4
## "doctor" (scrubs, and the coat if the look has one), "casual" (home
## clothes), "kurta" or "gown" (graduation). Set before the rig is built.
var outfit := "doctor"
var gown_colour := Color("#1D1D24")
var trim_colour := Color("#7A2440")
var mortarboard := true
## The current arm gesture (a key of GESTURES) or "".
var gesture := ""
## The current head movement (one of HEAD_GESTURES) or "".
var head_gesture := ""
## True while listening to someone: small nods now and then.
var listening := false
## How high this character's voice is (1 is the middle).
var voice_pitch := 1.0
var voice_volume_db := 0.0

var _gesture_clock := 0.0
var _head_clock := 0.0
var _arm_now := {"L": ARM_REST.duplicate(), "R": ARM_REST.duplicate()}
var _arm_weight := {"L": 0.0, "R": 0.0}
var _shrug := 0.0
var _look_target: Variant = null
var _look := Vector2.ZERO
var _mouth_open := 0.0
var _since_syllable := 10.0
var _props := {}
var _voice: AudioStreamPlayer3D

var _joints := {}
var _eyes: Array[Node3D] = []
var _mouth: Node3D
var _walk_phase := 0.0
var _clock := 0.0
var _shown_moving := 0.0


func _init(start_config: AvatarConfig = null) -> void:
	if start_config != null:
		config = start_config.copy()


func _ready() -> void:
	if not has_node("Model"):
		build()


## Rebuilds the whole character from a look.
func set_config(new_config: AvatarConfig) -> void:
	config = new_config.copy()
	build()


func set_mood(new_mood: int) -> void:
	mood = clampi(new_mood, 0, MOODS.size() - 1)
	if has_node("Model"):
		_build_face(joint("Head"))


## Starts an arm gesture ("" to drop it) and optionally a head movement.
func set_gesture(new_gesture: String, new_head: String = "") -> void:
	if new_gesture != gesture:
		gesture = new_gesture if GESTURES.has(new_gesture) else ""
		_gesture_clock = 0.0
	set_head_gesture(new_head)


func set_head_gesture(new_head: String) -> void:
	head_gesture = new_head if new_head in HEAD_GESTURES else ""
	_head_clock = 0.0


## Turns the head towards a point in the world, or straight ahead with null.
func look_at_point(point: Variant) -> void:
	_look_target = point


## Turns the head towards another character's face.
func look_at_rig(other: AvatarRig) -> void:
	if other == null:
		_look_target = null
		return
	_look_target = other.face_point()


## The middle of the face in world space, for others to look at.
func face_point() -> Vector3:
	var head_height := (1.08 if sitting else 1.5) * scale.y * (HEIGHT_SCALES[config.height] as float)
	return global_position + Vector3(0, head_height, 0)


## Opens the mouth for one spoken syllable and plays the voice murmur.
func say_syllable(letter: String = "a") -> void:
	_mouth_open = 1.0
	_since_syllable = 0.0
	if not Voice.enabled or not is_inside_tree():
		return
	if _voice == null:
		_voice = AudioStreamPlayer3D.new()
		_voice.name = "Voice"
		_voice.unit_size = 4.0
		_voice.max_db = 3.0
		add_child(_voice)
		_voice.position = Vector3(0, 1.5, 0)
	_voice.stream = Voice.syllable(letter)
	_voice.volume_db = voice_volume_db
	_voice.pitch_scale = voice_pitch * (0.94 + 0.12 * fposmod(_clock * 7.31, 1.0))
	_voice.play()


## Puts a prop ("pager", "letter", "certificate", "coffee") in a hand.
func hold(item: String, side: String = "R") -> void:
	drop(side)
	var elbow := joint("Elbow" + side)
	if elbow == null:
		return
	var prop := Props.make(item)
	prop.name = "Held" + side
	elbow.add_child(prop)
	prop.position = Vector3(0, -0.345, 0.02)
	_props[side] = item


func drop(side: String = "R") -> void:
	_props.erase(side)
	var elbow := joint("Elbow" + side)
	if elbow == null:
		return
	var old := elbow.get_node_or_null("Held" + side)
	if old != null:
		elbow.remove_child(old)
		old.free()


## The prop in a hand, or "".
func held(side: String = "R") -> String:
	return str(_props.get(side, ""))


## Jumps straight to the end of any gesture or head turn, for screenshots.
func settle() -> void:
	set_pose(_walk_phase, _shown_moving)
	_update_upper(0.0, true)


## A joint or part by name, for posing and tests (for example "Head").
func joint(joint_name: String) -> Node3D:
	return _joints.get(joint_name)


## Total height in metres, from the floor to the top of the head or hair.
func height_metres() -> float:
	var top := 0.0
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		var box := _transform_to_self(mesh_node) * mesh_node.get_aabb()
		top = maxf(top, box.end.y)
	return top


# The node's transform relative to this rig, which works before the rig is
# in the scene tree (global transforms do not).
func _transform_to_self(node: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != self:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result


func build() -> void:
	for child in get_children():
		if child.name == "Model":
			remove_child(child)
			child.free()
	_joints.clear()
	_eyes.clear()
	var width: float = BODY_WIDTHS[config.body]
	var height_scale: float = HEIGHT_SCALES[config.height]
	var skin := config.skin_colour()
	var scrubs := config.scrubs_colour()
	var trousers := scrubs.darkened(0.12)
	var doctor := outfit == "doctor"
	match outfit:
		"casual":
			trousers = Color("#3A4558")
		"kurta":
			scrubs = scrubs.lightened(0.25)
			trousers = Color("#EDE3D0")
		"gown":
			scrubs = gown_colour
			trousers = Color("#2B2B30")

	var model := Node3D.new()
	model.name = "Model"
	model.scale = Vector3.ONE * height_scale
	add_child(model)
	_joints["Model"] = model

	var hips := _add_joint(model, "Hips", Vector3(0, HIP_HEIGHT, 0))
	var torso := _add_joint(hips, "Torso", Vector3.ZERO)

	# Legs: thigh, knee, shin, shoe.
	for side: int in [-1, 1]:
		var suffix := "L" if side < 0 else "R"
		var hip := _add_joint(hips, "Hip" + suffix, Vector3(0.09 * width * side, 0.0, 0.0))
		LowPoly.put(hip, LowPoly.cylinder(0.078 * width, 0.062, 0.34, 6, trousers), Vector3(0, -0.17, 0))
		var knee := _add_joint(hip, "Knee" + suffix, Vector3(0, -0.34, 0))
		LowPoly.put(knee, LowPoly.cylinder(0.06, 0.052, 0.31, 6, trousers), Vector3(0, -0.155, 0))
		LowPoly.put(knee, LowPoly.box(Vector3(0.11, 0.06, 0.21), SHOE), Vector3(0, -0.335, 0.035))

	# Torso in scrubs, with a V of skin at the neck.
	LowPoly.put(torso, LowPoly.cylinder(0.19, 0.16, 0.5, 7, scrubs, "Chest"), Vector3(0, 0.25, 0), Vector3.ZERO,
		Vector3(width, 1.0, 0.64))
	LowPoly.put(torso, LowPoly.cylinder(0.045, 0.0, 0.08, 3, skin, "NeckV"), Vector3(0, 0.46, 0.098),
		Vector3(0.12, PI, 0))
	var coat := config.coat and doctor
	if coat:
		_build_coat(torso, width, scrubs)
	_build_outfit(hips, torso, width, scrubs)

	# Arms: sleeves are white with a coat, short scrub sleeves without.
	for side: int in [-1, 1]:
		var suffix := "L" if side < 0 else "R"
		var shoulder := _add_joint(torso, "Shoulder" + suffix, Vector3(0.215 * width * side, 0.46, 0.0),
			Vector3(0, 0, -0.09 * side))
		var long_sleeves := coat or outfit in ["gown", "kurta"]
		var sleeve := COAT if coat else scrubs
		var forearm := sleeve if long_sleeves else skin
		var cuff := 0.068 if outfit == "gown" else 0.05
		LowPoly.put(shoulder, LowPoly.cylinder(0.058, cuff, 0.3, 6, sleeve), Vector3(0, -0.15, 0))
		var elbow := _add_joint(shoulder, "Elbow" + suffix, Vector3(0, -0.3, 0))
		LowPoly.put(elbow, LowPoly.cylinder(cuff, cuff * 1.15 if outfit == "gown" else 0.044, 0.25, 6, forearm),
			Vector3(0, -0.125, 0))
		if long_sleeves:
			LowPoly.put(elbow, LowPoly.cylinder(0.042, 0.042, 0.03, 6, skin), Vector3(0, -0.26, 0))
		LowPoly.put(elbow, LowPoly.box(Vector3(0.07, 0.085, 0.036), skin, "Hand" + suffix), Vector3(0, -0.31, 0))
		if side < 0 and config.watch and outfit != "gown":
			var watch := Node3D.new()
			watch.name = "Watch"
			LowPoly.put(elbow, watch, Vector3(0, -0.235, 0))
			LowPoly.put(watch, LowPoly.box(Vector3(0.108, 0.034, 0.108), Color("#2B2F33")), Vector3.ZERO)
			LowPoly.put(watch, LowPoly.box(Vector3(0.03, 0.036, 0.03), Color("#E6E1D6")), Vector3(0, 0, 0.045))
			_joints["Watch"] = watch

	# Neck and head.
	LowPoly.put(torso, LowPoly.cylinder(0.052, 0.058, 0.11, 6, skin), Vector3(0, 0.53, 0))
	var head := _add_joint(torso, "Head", Vector3(0, 0.565, 0))
	head.scale = Vector3.ONE * HEAD_SCALE
	_build_head(head)
	if config.stethoscope and doctor:
		_build_stethoscope(torso)
	if outfit == "gown" and mortarboard:
		_build_mortarboard(head)
	var shadow := LowPoly.shadow_blob(0.26 * width, Vector2(1.0, 0.8))
	model.add_child(shadow)
	_joints["Shadow"] = shadow
	var props := _props.duplicate()
	_props.clear()
	for side: String in props:
		hold(props[side], side)
	set_pose(0.0, 0.0)
	_update_upper(0.0, true)
	rebuilt.emit()


## Home clothes and graduation gowns: the parts the doctor's outfit lacks.
func _build_outfit(hips: Node3D, torso: Node3D, width: float, main: Color) -> void:
	match outfit:
		"casual":
			# A shirt collar.
			for side: int in [-1, 1]:
				LowPoly.put(torso, LowPoly.box(Vector3(0.08, 0.035, 0.05), main.lightened(0.15)),
					Vector3(0.045 * side, 0.475, 0.085), Vector3(0.3, 0, 0.45 * side))
		"kurta":
			var tunic := LowPoly.cylinder(0.19, 0.25, 0.44, 7, main, "Tunic")
			LowPoly.put(hips, tunic, Vector3(0, -0.2, 0), Vector3.ZERO, Vector3(width, 1.0, 0.72))
			# A scarf over one shoulder.
			var scarf := main.darkened(0.35) if main.get_luminance() > 0.5 else Color("#F5B841")
			LowPoly.put(torso, LowPoly.box(Vector3(0.09, 0.62, 0.02), scarf, "Scarf"), Vector3(0.0, 0.25, 0.13),
				Vector3(0, 0, 0.62), Vector3(width, 1.0, 1.0))
			LowPoly.put(torso, LowPoly.box(Vector3(0.09, 0.42, 0.02), scarf), Vector3(-0.15 * width, 0.25, -0.12),
				Vector3(0, 0, -0.2))
		"gown":
			var robe := LowPoly.cylinder(0.2, 0.27, 0.6, 8, gown_colour, "Gown")
			LowPoly.put(hips, robe, Vector3(0, -0.26, 0), Vector3.ZERO, Vector3(width, 1.0, 0.78))
			var front := 0.19 * 0.64 + 0.004
			for side: int in [-1, 1]:
				var stole := LowPoly.box(Vector3(0.055, 0.5, 0.012), trim_colour, "Stole")
				LowPoly.put(torso, stole, Vector3(0.055 * side * width, 0.24, front), Vector3(0, 0, 0.08 * side))
				LowPoly.put(torso, LowPoly.box(Vector3(0.056, 0.012, 0.014), Color("#C9A15A")),
					Vector3(0.055 * side * width + 0.01 * side, 0.0, front + 0.002))


func _build_mortarboard(head: Node3D) -> void:
	var cap := Node3D.new()
	cap.name = "Mortarboard"
	head.add_child(cap)
	_joints["Mortarboard"] = cap
	var shape: Vector3 = FACE_SCALES[config.face]
	var top := HEAD_CENTRE.y + HEAD_RADIUS * shape.y * 0.82
	var lift := 0.06 if config.hair_style in [4, 7, 11] else 0.0
	LowPoly.put(cap, LowPoly.cylinder(HEAD_RADIUS * 1.02 * shape.x, HEAD_RADIUS * 1.06 * shape.x, 0.08, 8, gown_colour),
		Vector3(0, top + lift, -0.005), Vector3(-0.12, 0, 0))
	LowPoly.put(cap, LowPoly.box(Vector3(0.36, 0.02, 0.36), gown_colour.lightened(0.04), "Board"),
		Vector3(0, top + 0.05 + lift, -0.01), Vector3(-0.12, PI / 4, 0))
	LowPoly.put(cap, LowPoly.cylinder(0.006, 0.006, 0.13, 4, Color("#C9A15A"), "Tassel"),
		Vector3(0.16, top - 0.01 + lift, 0.06))


func _build_coat(torso: Node3D, width: float, scrubs: Color) -> void:
	var coat := Node3D.new()
	coat.name = "Coat"
	torso.add_child(coat)
	_joints["Coat"] = coat
	LowPoly.put(coat, LowPoly.cylinder(0.205, 0.218, 0.62, 7, COAT), Vector3(0, 0.2, 0), Vector3.ZERO,
		Vector3(width, 1.0, 0.68))
	var front := 0.218 * 0.68 + 0.004
	# The open front shows the scrubs underneath.
	LowPoly.put(coat, LowPoly.box(Vector3(0.085 * width, 0.4, 0.012), scrubs), Vector3(0, 0.29, front - 0.004))
	for side: int in [-1, 1]:
		LowPoly.put(coat, LowPoly.box(Vector3(0.05, 0.2, 0.012), COAT_SHADE), Vector3(0.05 * side * width, 0.4, front),
			Vector3(0, 0, 0.35 * side))
	var badge := LowPoly.box(Vector3(0.065, 0.04, 0.01), Color.WHITE, "Badge")
	LowPoly.put(coat, badge, Vector3(0.1 * width, 0.36, front + 0.002))
	LowPoly.put(badge, LowPoly.box(Vector3(0.065, 0.01, 0.012), BADGE_TEAL), Vector3(0, 0.015, 0.001))


func _build_stethoscope(torso: Node3D) -> void:
	var tool := Node3D.new()
	tool.name = "Stethoscope"
	torso.add_child(tool)
	_joints["Stethoscope"] = tool
	LowPoly.put(tool, LowPoly.torus(0.1, 0.116, TUBE, 10, 4), Vector3(0, 0.49, 0.025), Vector3(0.5, 0, 0))
	LowPoly.put(tool, LowPoly.box(Vector3(0.012, 0.12, 0.012), TUBE), Vector3(0.03, 0.38, 0.15), Vector3(0, 0, 0.1))
	LowPoly.put(tool, LowPoly.cylinder(0.024, 0.024, 0.014, 8, METAL), Vector3(0.036, 0.31, 0.152), Vector3(PI / 2, 0, 0))


func _build_head(head: Node3D) -> void:
	var skin := config.skin_colour()
	var shape: Vector3 = FACE_SCALES[config.face]
	var skull := LowPoly.painted_sphere(HEAD_RADIUS, 8, 6, _skull_paint, "Skull")
	LowPoly.put(head, skull, HEAD_CENTRE, Vector3.ZERO, shape)
	if config.face == 2 or config.face == 5:
		# Square and wide faces get a firmer jaw.
		LowPoly.put(head, LowPoly.box(Vector3(0.2 * shape.x, 0.08, 0.2), skin), Vector3(0, 0.05, 0.0))
	for side: int in [-1, 1]:
		LowPoly.put(head, LowPoly.box(Vector3(0.03, 0.06, 0.045), skin.darkened(0.06)),
			Vector3((HEAD_RADIUS * shape.x - 0.005) * side, 0.14, 0.0))
	_build_face(head)
	_build_hair(head)
	_build_facial_hair(head)
	_build_glasses(head)


## Colours one face of the skull: hair above the hairline, skin below it.
## Hair is painted on so no skin ever shows through gaps under the hair.
func _skull_paint(direction: Vector3) -> Color:
	var skin := config.skin_colour()
	if config.covers_hair():
		return skin
	var hair := config.hair_colour_value()
	var style: String = AvatarConfig.HAIR_STYLES[config.hair_style]
	if style == "Buzz cut":
		hair = hair.lerp(skin, 0.3)
	# The hairline sits high at the front, above the ears at the sides and low
	# at the back of the neck.
	var line := 0.12 + direction.z * (0.42 if direction.z > 0.0 else 0.75)
	return hair if direction.y > line else skin


## The depth of the head's front surface at a point on the face.
func _face_depth(x: float, y: float) -> float:
	var shape: Vector3 = FACE_SCALES[config.face]
	var nx := x / (HEAD_RADIUS * shape.x)
	var ny := (y - HEAD_CENTRE.y) / (HEAD_RADIUS * shape.y)
	return HEAD_CENTRE.z + HEAD_RADIUS * shape.z * sqrt(maxf(0.0, 1.0 - nx * nx - ny * ny)) - 0.008


func _build_face(head: Node3D) -> void:
	var old := head.get_node_or_null("Face")
	if old != null:
		head.remove_child(old)
		old.free()
	_eyes.clear()
	var face := Node3D.new()
	face.name = "Face"
	head.add_child(face)
	_joints["Face"] = face
	var skin := config.skin_colour()
	var eye: Vector4 = EYE_SHAPES[config.eyes]
	var brow: Vector3 = BROW_STYLES[config.brows]
	var nose: Vector3 = NOSE_STYLES[config.nose]
	var feel: Dictionary = MOODS[mood]
	var brow_colour := config.facial_hair_colour().darkened(0.25)
	if brow_colour.get_luminance() > 0.45:
		brow_colour = brow_colour.darkened(0.45)

	for side: int in [-1, 1]:
		var x := eye.z * side
		var eye_y := 0.15
		var holder := Node3D.new()
		holder.name = "Eye" + ("L" if side < 0 else "R")
		LowPoly.put(face, holder, Vector3(x, eye_y, _face_depth(x, eye_y)))
		LowPoly.put(holder, LowPoly.sphere(0.022, EYE_DARK, 8, 4), Vector3.ZERO, Vector3.ZERO,
			Vector3(eye.x, eye.y, 0.6))
		LowPoly.put(holder, LowPoly.sphere(0.0065 * eye.w, Color.WHITE, 6, 3), Vector3(0.008, 0.008 * eye.y, 0.012))
		_eyes.append(holder)
		if mood == AvatarConfig.Mood.TIRED:
			LowPoly.put(holder, LowPoly.box(Vector3(0.056 * eye.x, 0.022, 0.03), skin.darkened(0.05)),
				Vector3(0, 0.014 * eye.y, 0.006))
		var brow_y: float = 0.2 + float(feel["lift"])
		var points := PackedVector2Array([Vector2(-brow.x / 2, 0), Vector2(0, brow.z), Vector2(brow.x / 2, 0)])
		var brow_node := LowPoly.ribbon(points, brow.y, brow_colour, false, "Brow" + ("L" if side < 0 else "R"))
		LowPoly.put(face, brow_node, Vector3(x, brow_y, _face_depth(x, brow_y) + 0.004),
			Vector3(0, 0.12 * side, -feel["brow"] * side))

	var tip := _face_depth(0, 0.115)
	LowPoly.put(face, LowPoly.cylinder(0.0, nose.x, nose.y, 4, skin.darkened(0.1), "Nose"),
		Vector3(0, 0.118, tip + nose.z * 0.3), Vector3(-0.35, PI / 4, 0), Vector3(1, 1, nose.z / nose.x))

	var mouth_y := 0.072
	var mouth_z := maxf(_face_depth(0, mouth_y) + 0.003, _beard_front(mouth_y) + 0.005)
	var mouth_points := PackedVector2Array(feel["mouth"])
	var closed := false
	if mouth_points.is_empty():
		closed = true
		for step in 10:
			var angle := TAU * step / 10.0
			mouth_points.append(Vector2(cos(angle) * 0.013, sin(angle) * 0.017))
	_mouth = LowPoly.ribbon(mouth_points, 0.009, MOUTH, closed, "Mouth")
	LowPoly.put(face, _mouth, Vector3(0, mouth_y, mouth_z))


func _build_hair(head: Node3D) -> void:
	var hair := Node3D.new()
	hair.name = "Hair"
	head.add_child(hair)
	_joints["Hair"] = hair
	var colour := config.hair_colour_value()
	var shape: Vector3 = FACE_SCALES[config.face]
	var centre := HEAD_CENTRE
	var cap_scale := shape * 1.07
	var style: String = AvatarConfig.HAIR_STYLES[config.hair_style]
	match style:
		"Short":
			_cap(hair, colour, cap_scale, -0.4)
		"Buzz cut":
			pass  # painted straight onto the skull
		"Side part":
			_cap(hair, colour, cap_scale, -0.36)
			LowPoly.put(hair, LowPoly.box(Vector3(0.17, 0.05, 0.08), colour), centre + Vector3(0.03, 0.135, 0.11),
				Vector3(0.3, 0, -0.32))
		"Curly":
			_cap(hair, colour, cap_scale, -0.42)
			for index in 9:
				var angle := -PI * 0.95 + PI * 0.95 * 2.0 * index / 8.0
				var spot := Vector3(sin(angle) * 0.14, 0.12 + cos(angle * 0.5) * 0.03, cos(angle) * 0.05 - 0.02)
				LowPoly.put(hair, LowPoly.sphere(0.055, colour, 6, 4), centre + spot)
		"Afro":
			LowPoly.put(hair, LowPoly.sphere(0.235, colour, 9, 6), centre + Vector3(0, 0.075, -0.06), Vector3.ZERO,
				Vector3(1.0, 0.9, 0.85))
		"Long":
			_cap(hair, colour, cap_scale, -0.36)
			LowPoly.put(hair, LowPoly.box(Vector3(0.32, 0.4, 0.07), colour), centre + Vector3(0, -0.14, -0.12))
			for side: int in [-1, 1]:
				LowPoly.put(hair, LowPoly.box(Vector3(0.05, 0.3, 0.09), colour),
					centre + Vector3(0.155 * side * shape.x, -0.1, -0.02))
		"Ponytail":
			_cap(hair, colour, cap_scale, -0.42)
			LowPoly.put(hair, LowPoly.sphere(0.045, colour, 6, 4), centre + Vector3(0, 0.06, -0.185))
			LowPoly.put(hair, LowPoly.cylinder(0.045, 0.02, 0.26, 6, colour), centre + Vector3(0, -0.07, -0.21),
				Vector3(-0.25, 0, 0))
		"Bun":
			_cap(hair, colour, cap_scale, -0.42)
			LowPoly.put(hair, LowPoly.sphere(0.075, colour, 7, 5), centre + Vector3(0, 0.17, -0.07))
		"Braid":
			_cap(hair, colour, cap_scale, -0.42)
			for index in 5:
				LowPoly.put(hair, LowPoly.sphere(0.042 - index * 0.004, colour, 6, 4),
					centre + Vector3(0, 0.0 - index * 0.07, -0.19 - index * 0.012))
		"Bob":
			_cap(hair, colour, cap_scale, -0.36)
			LowPoly.put(hair, LowPoly.box(Vector3(0.36 * shape.x, 0.22, 0.13), colour), centre + Vector3(0, -0.04, -0.09))
			for side: int in [-1, 1]:
				LowPoly.put(hair, LowPoly.box(Vector3(0.06, 0.22, 0.17), colour),
					centre + Vector3(0.165 * side * shape.x, -0.03, -0.01))
		"Headscarf":
			LowPoly.put(hair, LowPoly.sphere(HEAD_RADIUS, colour, 8, 5, true), centre, Vector3(-0.32, 0, 0),
				shape * 1.12)
			LowPoly.put(hair, LowPoly.sphere(HEAD_RADIUS, colour, 8, 5, true), centre + Vector3(0, -0.01, -0.01),
				Vector3(-PI / 2, 0, 0), shape * 1.12)
			LowPoly.put(hair, LowPoly.cylinder(0.13, 0.25, 0.24, 8, colour), Vector3(0, -0.02, -0.01), Vector3.ZERO,
				Vector3(1.0, 1.0, 0.8))
		"Turban":
			LowPoly.put(hair, LowPoly.sphere(0.2, colour, 8, 5), centre + Vector3(0, 0.1, -0.02), Vector3(0.22, 0, 0),
				Vector3(1.05 * shape.x, 0.72, 1.02))
			LowPoly.put(hair, LowPoly.torus(0.15, 0.2, colour.darkened(0.1), 9, 4), centre + Vector3(0, 0.08, 0.0),
				Vector3(0.28, 0, 0), Vector3(shape.x, 1, 1))
			LowPoly.put(hair, LowPoly.torus(0.13, 0.18, colour.lightened(0.06), 9, 4), centre + Vector3(0, 0.14, -0.02),
				Vector3(0.12, 0, 0.18), Vector3(shape.x, 1, 1))


## A hair cap: a dome over the top of the head, tilted back to show the brow.
func _cap(hair: Node3D, colour: Color, cap_scale: Vector3, tilt: float) -> void:
	LowPoly.put(hair, LowPoly.sphere(HEAD_RADIUS, colour, 8, 4, true, "Cap"), HEAD_CENTRE + Vector3(0, 0.005, -0.006),
		Vector3(tilt, 0, 0), cap_scale)


## Short and full beards: centre height (below the head centre), size.
const BEARDS := {
	4: [0.06, Vector3(1.03, 0.72, 1.05)],
	5: [0.072, Vector3(1.05, 0.78, 1.06)],
}


## How far forward a beard reaches at a height on the face's centre line, so
## the mouth and moustache can sit on top of it. -1 when there is no beard.
func _beard_front(y: float) -> float:
	if not BEARDS.has(config.facial_hair):
		return -1.0
	var shape: Vector3 = FACE_SCALES[config.face]
	var drop: float = BEARDS[config.facial_hair][0]
	var size: Vector3 = BEARDS[config.facial_hair][1]
	var below := (HEAD_CENTRE.y - drop) - y
	var reach := HEAD_RADIUS * size.y * shape.y
	if below < 0.0 or below > reach:
		return -1.0
	return HEAD_CENTRE.z + 0.004 + HEAD_RADIUS * size.z * shape.z * sqrt(1.0 - pow(below / reach, 2.0))


func _build_facial_hair(head: Node3D) -> void:
	if config.facial_hair == 0:
		return
	var beard := Node3D.new()
	beard.name = "FacialHair"
	head.add_child(beard)
	_joints["FacialHair"] = beard
	var colour := config.facial_hair_colour()
	var shape: Vector3 = FACE_SCALES[config.face]
	var moustache_y := 0.097
	var moustache_z := maxf(_face_depth(0, moustache_y) + 0.01, _beard_front(moustache_y - 0.004) + 0.004)
	var moustache := LowPoly.box(Vector3(0.085, 0.02, 0.03), colour)
	match config.facial_hair:
		1:
			var stubble := config.skin_colour().lerp(colour, 0.35)
			LowPoly.put(beard, LowPoly.sphere(HEAD_RADIUS, stubble, 8, 4, true), HEAD_CENTRE + Vector3(0, -0.055, 0.0),
				Vector3(PI, 0, 0), Vector3(shape.x * 1.015, 0.62, shape.z * 1.02))
		2:
			LowPoly.put(beard, moustache, Vector3(0, moustache_y, moustache_z))
		3:
			LowPoly.put(beard, moustache, Vector3(0, moustache_y, moustache_z))
			LowPoly.put(beard, LowPoly.box(Vector3(0.05, 0.06, 0.04), colour), Vector3(0, 0.025, _face_depth(0, 0.03)))
		4, 5:
			var drop: float = BEARDS[config.facial_hair][0]
			var size: Vector3 = BEARDS[config.facial_hair][1]
			LowPoly.put(beard, LowPoly.sphere(HEAD_RADIUS, colour, 8, 4, true),
				HEAD_CENTRE + Vector3(0, -drop, 0.004), Vector3(PI, 0, 0), size * shape)
			LowPoly.put(beard, moustache, Vector3(0, moustache_y, moustache_z))


func _build_glasses(head: Node3D) -> void:
	if config.glasses == 0:
		return
	var glasses := Node3D.new()
	glasses.name = "Glasses"
	head.add_child(glasses)
	_joints["Glasses"] = glasses
	var eye: Vector4 = EYE_SHAPES[config.eyes]
	var style: String = AvatarConfig.GLASSES[config.glasses]
	var depth := _face_depth(eye.z, 0.15) + 0.014
	for side: int in [-1, 1]:
		var centre := Vector3(eye.z * side, 0.15, depth)
		match style:
			"Round":
				LowPoly.put(glasses, LowPoly.torus(0.026, 0.032, FRAME, 8, 4), centre, Vector3(PI / 2, 0, 0))
			"Square":
				_square_lens(glasses, centre, 0.028, Vector3(1.0, 1.0, 0.9))
			"Wide":
				_square_lens(glasses, centre, 0.024, Vector3(1.45, 1.0, 0.85))
			"Half-rim":
				LowPoly.put(glasses, LowPoly.box(Vector3(0.062, 0.009, 0.009), FRAME), centre + Vector3(0, 0.016, 0))
			"Big round":
				LowPoly.put(glasses, LowPoly.torus(0.034, 0.041, FRAME, 10, 4), centre, Vector3(PI / 2, 0, 0))
		# Arms run back along the side of the head to the ears.
		var temple_x: float = HEAD_RADIUS * FACE_SCALES[config.face].x * 0.9
		var lens_edge := eye.z + 0.03
		LowPoly.put(glasses, LowPoly.box(Vector3(temple_x - lens_edge, 0.008, 0.008), FRAME),
			Vector3((lens_edge + temple_x) / 2.0 * side, 0.155, depth - 0.012))
		LowPoly.put(glasses, LowPoly.box(Vector3(0.008, 0.008, 0.13), FRAME),
			Vector3(temple_x * side, 0.158, depth - 0.075))
	LowPoly.put(glasses, LowPoly.box(Vector3(eye.z * 2 - 0.06, 0.007, 0.007), FRAME), Vector3(0, 0.155, depth))


## A square lens frame: a four-sided ring turned to face forward.
func _square_lens(glasses: Node3D, centre: Vector3, size: float, stretch: Vector3) -> void:
	var holder := Node3D.new()
	LowPoly.put(glasses, holder, centre, Vector3(PI / 2, 0, 0), stretch)
	LowPoly.put(holder, LowPoly.torus(size, size + 0.006, FRAME, 4, 4), Vector3.ZERO, Vector3(0, PI / 4, 0))


func _add_joint(parent: Node3D, joint_name: String, position: Vector3, rotation: Vector3 = Vector3.ZERO) -> Node3D:
	var node := LowPoly.joint(parent, joint_name, position, rotation)
	_joints[joint_name] = node
	return node


## Poses the body for a point in the walk cycle. walk is 0 (still) to 1.
## Deterministic, so screenshots and tests can ask for an exact pose.
func set_pose(phase: float, walk: float, breath: float = 0.0) -> void:
	var hips := joint("Hips")
	if hips == null:
		return
	var swing := sin(phase)
	joint("Shadow").visible = not sitting
	if sitting:
		for suffix in ["L", "R"]:
			joint("Hip" + suffix).rotation.x = -1.5
			joint("Knee" + suffix).rotation.x = 1.5
		hips.position.y = 0.48
	else:
		joint("HipL").rotation.x = -swing * 0.5 * walk
		joint("HipR").rotation.x = swing * 0.5 * walk
		joint("KneeL").rotation.x = maxf(0.0, swing) * 0.75 * walk
		joint("KneeR").rotation.x = maxf(0.0, -swing) * 0.75 * walk
		hips.position.y = HIP_HEIGHT + absf(cos(phase)) * 0.028 * walk
	joint("ShoulderL").rotation.x = swing * 0.42 * walk
	joint("ShoulderR").rotation.x = -swing * 0.42 * walk
	joint("ElbowL").rotation.x = -0.2 - 0.25 * walk
	joint("ElbowR").rotation.x = -0.2 - 0.25 * walk
	if sitting:
		joint("ElbowL").rotation.x = -0.9
		joint("ElbowR").rotation.x = -0.9
	var torso := joint("Torso")
	torso.scale = Vector3(1.0, 1.0 + breath * 0.012, 1.0 + breath * 0.008)
	torso.rotation.x = 0.05 * walk
	joint("Head").rotation.x = -0.04 * walk + breath * 0.012


## The gesture an arm should take now: the active gesture's pose for that arm,
## the holding pose when the hand has a prop, or null to hang loose.
func _arm_goal(side: String) -> Variant:
	var move: Dictionary = GESTURES.get(gesture, {})
	if move.has(side):
		return move[side]
	if move.has("R") and side == "L" and held("L").is_empty():
		return null
	if not held(side).is_empty():
		return GESTURES["hold"]["R"]
	return null


## Layers gestures, head movement and gaze over the walk/idle pose.
func _update_upper(delta: float, snap: bool = false) -> void:
	var hips := joint("Hips")
	if hips == null:
		return
	var rate := 1.0 if snap else 1.0 - exp(-delta * 8.0)
	var move: Dictionary = GESTURES.get(gesture, {})
	var t := _gesture_clock
	var speaking := talking and _since_syllable < 0.45
	for side: String in ["L", "R"]:
		var sign := -1.0 if side == "L" else 1.0
		var goal: Variant = _arm_goal(side)
		var now: Array = _arm_now[side]
		if goal != null:
			for index in 6:
				now[index] = lerpf(now[index], float(goal[index]), rate)
		_arm_weight[side] = lerpf(_arm_weight[side], 1.0 if goal != null else 0.0, rate)
		var weight: float = _arm_weight[side]
		var arm: Array = now.duplicate()
		if goal != null and move.has(side):
			if speaking and move.has("beat"):
				arm[3] += sin(t * 6.5 + (0.0 if side == "R" else 1.7)) * float(move["beat"])
				arm[0] += sin(t * 3.3) * float(move["beat"]) * 0.3
			if move.has("swing"):
				arm[5] += sin(t * 9.0) * float(move["swing"])
			if move.has("clap"):
				arm[2] -= (sin(t * 11.0) * 0.5 + 0.5) * 0.14
			if move.has("bounce"):
				arm[2] += sin(t * 7.0) * 0.12
		var shoulder := joint("Shoulder" + side)
		var elbow := joint("Elbow" + side)
		shoulder.rotation = Vector3(
			lerpf(shoulder.rotation.x, arm[0], weight),
			lerpf(0.0, arm[1] * sign, weight),
			lerpf(ARM_REST[2] * sign, arm[2] * sign, weight))
		elbow.rotation = Vector3(
			lerpf(elbow.rotation.x, arm[3], weight),
			lerpf(0.0, arm[4] * sign, weight),
			lerpf(0.0, arm[5] * sign, weight))
	# Shrugs lift the shoulders; cheering bounces on the toes.
	_shrug = lerpf(_shrug, float(move.get("shrug", 0.0)), rate)
	for side: String in ["L", "R"]:
		joint("Shoulder" + side).position.y = 0.46 + 0.035 * _shrug
	if move.has("bounce") and not sitting:
		hips.position.y += absf(sin(t * 7.0)) * 0.035
	# Gaze: the head turns towards the target and the chest follows a little.
	var goal_look := Vector2.ZERO
	if _look_target != null and is_inside_tree():
		var local: Vector3 = global_transform.affine_inverse() * (_look_target as Vector3)
		var eye_height := (1.08 if sitting else 1.5) * (HEIGHT_SCALES[config.height] as float)
		var flat := Vector2(local.x, local.z)
		if flat.length() > 0.05:
			goal_look.x = clampf(atan2(local.x, local.z), -1.15, 1.15)
			goal_look.y = clampf(-atan2(local.y - eye_height, flat.length()), -0.45, 0.45)
	_look = goal_look if snap else _look.lerp(goal_look, 1.0 - exp(-delta * 6.0))
	var head := joint("Head")
	var nod := 0.0
	var shake := 0.0
	var tilt := float(move.get("tilt", 0.0))
	match head_gesture:
		"nod":
			nod = sin(_head_clock * TAU * 2.2) * 0.17 * clampf(1.0 - _head_clock / 0.95, 0.0, 1.0)
		"shake":
			shake = sin(_head_clock * TAU * 2.4) * 0.3 * clampf(1.0 - _head_clock / 1.1, 0.0, 1.0)
		"tilt":
			tilt += 0.16
		"down":
			nod = 0.3
		"up":
			nod = -0.3
	if listening and head_gesture.is_empty():
		nod += maxf(0.0, sin(_clock * 2.2)) * maxf(0.0, sin(_clock * 0.71)) * 0.09
	if speaking:
		nod += sin(_clock * 8.5) * 0.03
	head.rotation.x += nod + _look.y
	head.rotation.y = _look.x * 0.75 + shake
	head.rotation.z = tilt
	joint("Torso").rotation.y = _look.x * 0.25


func _process(delta: float) -> void:
	_clock += delta
	_gesture_clock += delta
	_head_clock += delta
	_since_syllable += delta
	_shown_moving = move_toward(_shown_moving, moving, delta * 4.0)
	_walk_phase = fmod(_walk_phase + delta * TAU * (0.6 + 1.0 * _shown_moving), TAU)
	set_pose(_walk_phase, _shown_moving, sin(_clock * 1.9) * (1.0 - _shown_moving))
	_update_upper(delta)
	if blink_every > 0.0:
		var blink := fmod(_clock, blink_every) < 0.12
		for eye in _eyes:
			if is_instance_valid(eye):
				eye.scale.y = 0.15 if blink else 1.0
	_mouth_open = move_toward(_mouth_open, 0.0, delta * 7.0)
	if _mouth != null and is_instance_valid(_mouth):
		var open := _mouth_open
		if talking and _since_syllable > 0.6:
			# Talking without a voice (a quiet aside): a steady murmur.
			open = absf(sin(_clock * 14.0))
		_mouth.scale.y = 1.0 + open * 1.5
