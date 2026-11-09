class_name SuturePad
extends LabStation
## Stitching: a rubber practice pad with a cut across it, on a table with
## a needle holder and thread. Each stitch placed shows across the cut.
##
## The pad is the task's 12 x 8 cm, drawn at three times life size so the
## stitches are big enough to tap on a phone.

## Metres per centimetre of pad.
const SCALE := 0.03
const PAD_TOP := 0.86
const SUTURE := Color("#22337A")

var _pad: Node3D
var _stitches: Node3D
var _shown := -1
var _wound: MeshInstance3D


func _init() -> void:
	id = "stitch"
	name = "SuturePad"
	spot = Vector3(0, 0, 0.82)
	trainer_spot = Vector3(0.9, 0, -0.62)
	close_from = Vector3(0.0, 1.48, 0.5)
	close_at = Vector3(0.0, 0.86, -0.03)
	close_fov = 42.0
	close_offset = 0.0
	tag_point = Vector3(0, 1.3, 0.1)
	footprints = [Rect2(-0.62, -0.42, 1.24, 0.74)]


func _build() -> void:
	var desk := LowPoly.joint(self, "Table", Vector3(0, 0, -0.05))
	table(desk, Vector3(1.1, 0.8, 0.66))
	LowPoly.put(self, LowPoly.box(Vector3(0.5, 0.012, 0.38), Color("#3E8E7A")), Vector3(0, 0.806, 0))
	_pad = LowPoly.joint(self, "Pad", Vector3(0, PAD_TOP, 0))
	var size := StitchTask.PAD_SIZE * SCALE
	LowPoly.put(_pad, LowPoly.box(Vector3(size.x, 0.05, size.y), Color("#F0C9B4")), Vector3(0, -0.025, 0))
	LowPoly.put(_pad, LowPoly.box(Vector3(size.x + 0.01, 0.012, size.y + 0.01), Color("#C98F7A")), Vector3(0, -0.048, 0))
	var task := StitchTask.new()
	var line := PackedVector2Array()
	for point in task.curve():
		var local := pad_to_local(point)
		line.append(Vector2(local.x, -local.z))
	_wound = LowPoly.ribbon(line, 0.009, Color("#9E2B2B"))
	LowPoly.put(_pad, _wound, Vector3(0, 0.001, 0), Vector3(-PI / 2, 0, 0))
	var inner := LowPoly.ribbon(line, 0.0035, Color("#5E1414"))
	LowPoly.put(_pad, inner, Vector3(0, 0.0015, 0), Vector3(-PI / 2, 0, 0))
	_stitches = LowPoly.joint(_pad, "Stitches", Vector3(0, 0.002, 0))
	# A needle holder and a spool of thread beside the pad.
	var holder := Instruments.make("needle_holder")
	holder.scale = Vector3.ONE * 1.4
	LowPoly.put(self, holder, Vector3(0.33, 0.812, 0.04), Vector3(0, 0.4, 0), Vector3.ONE * 1.4)
	LowPoly.put(self, LowPoly.cylinder(0.02, 0.02, 0.025, 8, SUTURE), Vector3(-0.32, 0.825, 0.08))
	LowPoly.put(self, LowPoly.cylinder(0.024, 0.024, 0.004, 8, WHITE), Vector3(-0.32, 0.84, 0.08))


## A pad position in centimetres (x across, y towards the player) as a
## position relative to the pad's centre, in metres.
static func pad_to_local(point: Vector2) -> Vector3:
	var half := StitchTask.PAD_SIZE / 2.0
	return Vector3((point.x - half.x) * SCALE, 0, (point.y - half.y) * SCALE)


## Where a pad point is drawn, in the lab.
func pad_point_world(point: Vector2) -> Vector3:
	return at(Vector3(0, PAD_TOP, 0) + pad_to_local(point))


## The pad position under a screen point, in centimetres, or null when the
## tap is off the pad.
func pad_point(camera: Camera3D, screen_point: Vector2) -> Variant:
	var hit: Variant = ray_to_height(camera, screen_point, PAD_TOP + global_position.y)
	if hit == null:
		return null
	var local: Vector3 = transform.affine_inverse() * (hit as Vector3)
	var half := StitchTask.PAD_SIZE / 2.0
	var point := Vector2(local.x / SCALE + half.x, local.z / SCALE + half.y)
	if point.x < -0.5 or point.y < -0.5 or point.x > StitchTask.PAD_SIZE.x + 0.5 or point.y > StitchTask.PAD_SIZE.y + 0.5:
		return null
	return point


func reset_task(_task: TrainingTask) -> void:
	for child in _stitches.get_children():
		_stitches.remove_child(child)
		child.queue_free()
	_shown = 0


func show_task(task: TrainingTask, _delta: float) -> void:
	var stitch := task as StitchTask
	if stitch == null or stitch.stitches.size() == _shown:
		return
	for child in _stitches.get_children():
		_stitches.remove_child(child)
		child.queue_free()
	for entry in stitch.stitches:
		var t := float(entry["t"])
		var middle := pad_to_local(stitch.point_at(t))
		var along := stitch.direction_at(t)
		var mark := LowPoly.joint(_stitches, "Stitch", middle, Vector3(0, -atan2(along.y, along.x), 0))
		# The thread runs across the cut, with a knot on one side.
		LowPoly.put(mark, LowPoly.box(Vector3(0.004, 0.003, 0.034), SUTURE), Vector3.ZERO)
		LowPoly.put(mark, LowPoly.sphere(0.004, SUTURE, 5, 3), Vector3(0, 0.002, -0.017))
		LowPoly.put(mark, LowPoly.box(Vector3(0.012, 0.002, 0.003), SUTURE), Vector3(0.004, 0.003, -0.019), Vector3(0, 0.6, 0))
	_shown = stitch.stitches.size()
