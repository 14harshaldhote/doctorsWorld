class_name LabStation
extends Node3D
## One station in the skills lab: its furniture, where the player and the
## trainer stand, where the camera goes for the close-up, and how the
## station shows its task's state in 3D while the task runs.
##
## Every station is built facing +z: the player stands in front of it at
## `spot`, the trainer beside or behind it. Positions here are local to the
## station; at() turns them into lab positions.

const STEEL := Color("#C7D3D6")
const STEEL_DARK := Color("#8FA1A6")
const WHITE := Color("#F4F7F7")
const TEAL := Color("#127C80")
const DRAPE := Color("#3E8E7A")
const PLASTIC := Color("#E9CDB0")

var id := ""
## Where the player stands for this station.
var spot := Vector3(0, 0, 0.95)
## Where the trainer stands (or sits) while the task runs.
var trainer_spot := Vector3(1.05, 0, 0.45)
var trainer_sits := false
## Where a trainer who sits for the task stands to explain it first.
var trainer_intro_spot := Vector3(0.5, 0, 0.42)
## The close-up while the task runs: camera position, what it looks at, field
## of view, and a sideways shift on screen so the subject clears the panels.
var close_from := Vector3(0, 1.75, 1.3)
var close_at := Vector3(0, 0.95, 0)
var close_fov := 42.0
var close_offset := 0.0
## Where the floating name tag goes.
var tag_point := Vector3(0, 1.9, 0)
## The floor the furniture covers (x, z), which nobody walks through.
var footprints: Array[Rect2] = [Rect2(-0.7, -0.55, 1.4, 1.0)]


func _ready() -> void:
	_build()


## Each station builds its furniture here.
func _build() -> void:
	pass


## The task starts (or starts again): back to the first look.
func reset_task(_task: TrainingTask) -> void:
	pass


## Every frame while the task runs: show the task's state.
func show_task(_task: TrainingTask, _delta: float) -> void:
	pass


## A local position as a position in the lab.
func at(local: Vector3) -> Vector3:
	return transform * local


## Where the trainer waits while explaining the station.
func trainer_greeting_spot() -> Vector3:
	return trainer_intro_spot if trainer_sits else trainer_spot


## Which way the trainer faces while the task runs (towards the player).
func trainer_facing() -> float:
	var from := at(trainer_spot)
	var to := at(spot)
	return atan2(to.x - from.x, to.z - from.z)


## The footprints as floor rectangles in the lab.
func blockers() -> Array[Rect2]:
	var found: Array[Rect2] = []
	for footprint in footprints:
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		var corners: Array[Vector2] = [footprint.position, Vector2(footprint.end.x, footprint.position.y), footprint.end,
			Vector2(footprint.position.x, footprint.end.y)]
		for corner in corners:
			var world := transform * Vector3(corner.x, 0, corner.y)
			low = Vector2(minf(low.x, world.x), minf(low.y, world.z))
			high = Vector2(maxf(high.x, world.x), maxf(high.y, world.z))
		found.append(Rect2(low, high - low))
	return found


## The key of the point drawn nearest a screen point, within radius
## pixels, or "". points: key -> position in the lab.
static func nearest_on_screen(camera: Camera3D, screen_point: Vector2, points: Dictionary, radius: float) -> String:
	var best := ""
	var best_distance := radius
	for key: String in points:
		var point: Vector3 = points[key]
		if camera.is_position_behind(point):
			continue
		var distance := camera.unproject_position(point).distance_to(screen_point)
		if distance < best_distance:
			best_distance = distance
			best = key
	return best


## Where a screen point's ray meets a flat surface at a height, or null.
static func ray_to_height(camera: Camera3D, screen_point: Vector2, height: float) -> Variant:
	var origin := camera.project_ray_origin(screen_point)
	var direction := camera.project_ray_normal(screen_point)
	if absf(direction.y) < 0.0001:
		return null
	var distance := (height - origin.y) / direction.y
	if distance <= 0.0:
		return null
	return origin + direction * distance


static func label3d(text: String, size: int, colour: Color, pixel: float = 0.004) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = UiKit.heading_font()
	label.font_size = size
	label.pixel_size = pixel
	label.outline_size = 0
	label.modulate = colour
	label.shaded = false
	return label


## A plain steel-legged table, top at height, centred on the joint.
static func table(parent: Node3D, size: Vector3, top_colour: Color = WHITE) -> void:
	LowPoly.put(parent, LowPoly.box(Vector3(size.x, 0.05, size.z), top_colour), Vector3(0, size.y - 0.025, 0))
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			LowPoly.put(parent, LowPoly.cylinder(0.022, 0.022, size.y - 0.05, 6, STEEL_DARK),
				Vector3(x * (size.x / 2.0 - 0.06), (size.y - 0.05) / 2.0, z * (size.z / 2.0 - 0.06)))
	LowPoly.put(parent, LowPoly.box(Vector3(size.x - 0.14, 0.03, size.z - 0.14), STEEL), Vector3(0, 0.22, 0))
	LowPoly.put(parent, LowPoly.shadow_blob(maxf(size.x, size.z) * 0.62, Vector2(1.0, size.z / size.x)), Vector3.ZERO)


static func set_colour(part: MeshInstance3D, colour: Color) -> void:
	var current := part.material_override as StandardMaterial3D
	if current == null or not current.albedo_color.is_equal_approx(colour):
		part.material_override = LowPoly.material(colour)
