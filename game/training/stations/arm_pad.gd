class_name ArmPad
extends LabStation
## IV line: a plastic practice arm on a table, with three veins to choose
## from and a cannula. The needle tilts to the angle being set, goes in on
## the chosen vein, wanders while the player steadies it, and its chamber
## flashes red while the tip sits in the vein.

const ARM_HEIGHT := 0.862
const ARM_RADIUS := 0.048
const WRIST_X := -0.3
const ELBOW_X := 0.18
const VEIN := Color("#4C6DB2")
## How far the needle visibly moves per millimetre the tip wanders (exaggerated).
const DRIFT_SCALE := 0.004

var _veins := {}
var _needle: Node3D
var _chamber: MeshInstance3D
var _rest := Vector3(0.36, 0.812, 0.2)


func _init() -> void:
	id = "iv"
	name = "ArmPad"
	spot = Vector3(0, 0, 0.82)
	trainer_spot = Vector3(0.62, 0, -0.62)
	close_from = Vector3(-0.02, 1.4, 0.6)
	close_at = Vector3(-0.04, 0.87, -0.04)
	close_fov = 42.0
	close_offset = 0.0
	tag_point = Vector3(0, 1.3, 0)
	footprints = [Rect2(-0.66, -0.42, 1.32, 0.74)]


func _build() -> void:
	var desk := LowPoly.joint(self, "Table", Vector3(0, 0, -0.05))
	table(desk, Vector3(1.24, 0.8, 0.66))
	LowPoly.put(self, LowPoly.box(Vector3(0.9, 0.012, 0.3), Color("#3E8E7A")), Vector3(-0.05, 0.806, 0))
	var arm := LowPoly.joint(self, "Arm", Vector3(0, ARM_HEIGHT, 0))
	# Rotated onto its side, the cylinder's top end is the wrist.
	var forearm := LowPoly.cylinder(ARM_RADIUS * 0.85, ARM_RADIUS * 1.1, ELBOW_X - WRIST_X, 9, PLASTIC)
	LowPoly.put(arm, forearm, Vector3((WRIST_X + ELBOW_X) / 2.0, 0, 0), Vector3(0, 0, PI / 2))
	LowPoly.put(arm, LowPoly.cylinder(ARM_RADIUS * 1.2, ARM_RADIUS * 1.12, 0.3, 9, PLASTIC), Vector3(ELBOW_X + 0.15, 0.004, 0),
		Vector3(0, 0, PI / 2))
	LowPoly.put(arm, LowPoly.cylinder(ARM_RADIUS * 1.22, ARM_RADIUS * 1.22, 0.02, 9, PLASTIC.darkened(0.15)),
		Vector3(ELBOW_X + 0.3, 0.004, 0), Vector3(0, 0, PI / 2))
	# The hand, palm down, at the wrist end.
	var hand := LowPoly.joint(arm, "Hand", Vector3(WRIST_X - 0.06, -0.012, 0))
	LowPoly.put(hand, LowPoly.box(Vector3(0.1, 0.03, 0.085), PLASTIC), Vector3.ZERO)
	for finger in 4:
		LowPoly.put(hand, LowPoly.box(Vector3(0.07, 0.022, 0.017), PLASTIC), Vector3(-0.08, -0.004, -0.03 + finger * 0.02))
	LowPoly.put(hand, LowPoly.box(Vector3(0.05, 0.022, 0.02), PLASTIC), Vector3(-0.02, -0.004, 0.055), Vector3(0, -0.5, 0))
	# A blue tourniquet above the elbow.
	LowPoly.put(arm, LowPoly.torus(ARM_RADIUS * 1.15, ARM_RADIUS * 1.4, Color("#4FA0D8"), 12, 3), Vector3(ELBOW_X + 0.08, 0.004, 0),
		Vector3(0, 0, PI / 2))
	for which: String in IvTask.VEINS:
		var vein := LowPoly.joint(self, "Vein" + which.capitalize(), Vector3.ZERO)
		var strip := LowPoly.ribbon(_vein_shape(which), _vein_width(which), VEIN)
		LowPoly.put(vein, strip, Vector3.ZERO, Vector3(-PI / 2, 0, 0))
		_veins[which] = vein
	_place_veins({"wrist": 0.12, "forearm": 0.45, "thin": 0.8})
	_build_needle()


func _vein_shape(which: String) -> PackedVector2Array:
	var points := PackedVector2Array()
	match which:
		"forearm":
			for index in 7:
				var x := -0.07 + index * 0.0233
				points.append(Vector2(x, 0.003 * sin(index * 0.6)))
		"thin":
			for index in 13:
				var x := -0.06 + index * 0.01
				points.append(Vector2(x, 0.009 * sin(index * 1.3)))
		_:
			for index in 6:
				var x := -0.03 + index * 0.012
				points.append(Vector2(x, 0.008 * sin(index * 0.9 + 0.5)))
	return points


func _vein_width(which: String) -> float:
	return {"forearm": 0.013, "thin": 0.0045, "wrist": 0.009}.get(which, 0.008)


func _place_veins(slots: Dictionary) -> void:
	for which: String in _veins:
		var slot := float(slots.get(which, 0.5))
		(_veins[which] as Node3D).position = Vector3(slot_x(slot), ARM_HEIGHT + ARM_RADIUS * lerpf(0.85, 1.1, slot) + 0.001, 0)


## Where along the arm a slot is: 0 at the wrist, 1 at the elbow.
static func slot_x(slot: float) -> float:
	return lerpf(WRIST_X, ELBOW_X, slot)


func _build_needle() -> void:
	_needle = LowPoly.joint(self, "Needle", _rest)
	var steel := LowPoly.cylinder(0.0016, 0.0016, 0.04, 5, STEEL)
	LowPoly.put(_needle, steel, Vector3(-0.02, 0, 0), Vector3(0, 0, PI / 2))
	var body := LowPoly.cylinder(0.0065, 0.0065, 0.05, 7, Color("#EEF4F4"))
	LowPoly.put(_needle, body, Vector3(-0.065, 0, 0), Vector3(0, 0, PI / 2))
	_chamber = LowPoly.cylinder(0.0072, 0.0072, 0.016, 7, Color("#F7F7F2"))
	LowPoly.put(_needle, _chamber, Vector3(-0.098, 0, 0), Vector3(0, 0, PI / 2))
	LowPoly.put(_needle, LowPoly.box(Vector3(0.022, 0.003, 0.05), Color("#F48FB1")), Vector3(-0.046, -0.003, 0))
	LowPoly.put(_needle, LowPoly.cylinder(0.005, 0.005, 0.012, 7, Color("#F48FB1")), Vector3(-0.112, 0, 0), Vector3(0, 0, PI / 2))


## The point on the arm that stands for a vein, in the lab.
func vein_point(which: String) -> Vector3:
	var vein: Node3D = _veins.get(which)
	return at(vein.position) if vein != null else at(Vector3.ZERO)


## The vein drawn nearest a screen point, or "".
func vein_at(camera: Camera3D, screen_point: Vector2) -> String:
	var points := {}
	for which: String in _veins:
		points[which] = vein_point(which)
	return nearest_on_screen(camera, screen_point, points, UiKit.px(42))


func reset_task(task: TrainingTask) -> void:
	var iv := task as IvTask
	if iv != null:
		_place_veins(iv.slots)
	_needle.position = _rest
	_needle.rotation = Vector3.ZERO
	set_colour(_chamber, Color("#F7F7F2"))


func show_task(task: TrainingTask, delta: float) -> void:
	var iv := task as IvTask
	if iv == null:
		return
	var goal := _rest
	var tilt := 0.0
	if iv.phase != "vein":
		var vein_at_point: Vector3 = (_veins[iv.vein] as Node3D).position
		tilt = deg_to_rad(iv.angle)
		match iv.phase:
			"angle":
				goal = vein_at_point + Vector3(-0.03, 0.014, 0)
			_:
				goal = vein_at_point + Vector3(0, -0.003, 0) \
					+ Vector3(iv.offset.x, 0, iv.offset.y) * DRIFT_SCALE
	_needle.position = _needle.position.lerp(goal, minf(1.0, delta * 10.0))
	_needle.rotation = Vector3(0, 0, -tilt)
	var flashback := iv.phase in ["steady", "done"] and iv.is_inside()
	set_colour(_chamber, Color("#C0392B") if flashback else Color("#F7F7F2"))
