class_name SeminarRoom
extends Node3D
## The department's seminar room, for meetings and reviews from Day 12: a
## projector screen with the slide on show, a long table with chairs, a
## window and a framed photo of the department nobody remembers posing for.
##
## Marks (see mark()): "screen" where a speaker stands, "head" at the
## table's end by the screen, "seat1" to "seat5" along the far side and the
## near end, and "door".

const WALL := Color("#F1EEE6")
const FLOOR := Color("#C9B9A0")
const TEAL := Color("#127C80")
const WOOD := Color("#9A6B45")
const SEAT := Color("#1F8A8A")
const ROOM := Rect2(-4.2, -3.2, 8.4, 7.0)
const TABLE := Vector3(0.6, 0, -0.2)
## Seats: where each chair stands and which way its sitter faces (radians).
const SEATS := {
	"head": [Vector3(-1.75, 0, -0.2), PI / 2],
	"seat1": [Vector3(-0.6, 0, -1.0), 0.0],
	"seat2": [Vector3(0.6, 0, -1.0), 0.0],
	"seat3": [Vector3(1.8, 0, -1.0), 0.0],
	"seat4": [Vector3(2.95, 0, -0.2), -PI / 2],
	"seat5": [Vector3(1.8, 0, 0.62), PI],
}

## The slide on the screen.
var slide: Label3D


func _init() -> void:
	name = "SeminarRoom"
	_build()


func _build() -> void:
	var centre := Vector3(ROOM.position.x + ROOM.size.x / 2.0, -0.05, ROOM.position.y + ROOM.size.y / 2.0)
	LowPoly.put(self, LowPoly.box(Vector3(ROOM.size.x, 0.1, ROOM.size.y), FLOOR), centre)
	for strip in 8:
		LowPoly.put(self, LowPoly.box(Vector3(ROOM.size.x, 0.008, 0.04), FLOOR.darkened(0.08)),
			Vector3(centre.x, 0.004, ROOM.position.y + 0.45 + strip * 0.85))
	var back := ROOM.position.y
	LowPoly.put(self, LowPoly.box(Vector3(ROOM.size.x, 3.2, 0.2), WALL), Vector3(centre.x, 1.6, back - 0.1))
	LowPoly.put(self, LowPoly.box(Vector3(ROOM.size.x, 0.9, 0.04), WALL.darkened(0.08)), Vector3(centre.x, 0.45, back + 0.02))
	for x: float in [ROOM.position.x, ROOM.end.x]:
		LowPoly.put(self, LowPoly.box(Vector3(0.2, 3.2, ROOM.size.y), WALL.darkened(0.05)), Vector3(x, 1.6, centre.z))
	# The projector screen on the back wall, glowing with the slide.
	var screen := LowPoly.joint(self, "Screen", Vector3(-1.5, 1.75, back + 0.04))
	LowPoly.put(screen, LowPoly.box(Vector3(2.3, 1.35, 0.03), Color("#2B2F33")), Vector3.ZERO)
	var glow := LowPoly.box(Vector3(2.2, 1.25, 0.01), Color("#F4F8FA"))
	glow.material_override = LowPoly.glow(Color("#F4F8FA"), 0.5)
	LowPoly.put(screen, glow, Vector3(0, 0, 0.02))
	slide = LabStation.label3d("", 30, UiKit.INK, 0.0034)
	slide.position = Vector3(0, 0.0, 0.035)
	slide.width = 600
	slide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen.add_child(slide)
	# A window, and the department photo.
	var window := LowPoly.joint(self, "Window", Vector3(2.4, 1.8, back + 0.02))
	LowPoly.put(window, LowPoly.box(Vector3(1.5, 1.1, 0.04), Color("#BFE7F0"), "Glass"), Vector3.ZERO)
	LowPoly.put(window, LowPoly.box(Vector3(1.6, 0.08, 0.06), WALL.darkened(0.2)), Vector3(0, -0.58, 0.02))
	LowPoly.put(window, LowPoly.box(Vector3(0.05, 1.1, 0.05), WALL.darkened(0.15)), Vector3(0, 0, 0.02))
	var photo := LowPoly.joint(self, "Photo", Vector3(ROOM.end.x - 0.12, 1.8, -1.2), Vector3(0, -PI / 2, 0))
	LowPoly.put(photo, LowPoly.box(Vector3(0.9, 0.6, 0.03), WOOD.darkened(0.3)), Vector3.ZERO)
	LowPoly.put(photo, LowPoly.box(Vector3(0.8, 0.5, 0.01), Color("#C8D8D0")), Vector3(0, 0, 0.02))
	for index in 6:
		LowPoly.put(photo, LowPoly.sphere(0.035, Color("#6B4A35"), 6, 4), Vector3(-0.3 + index * 0.12, 0.02, 0.03))
	var label := LabStation.label3d("SEMINAR ROOM · DEPARTMENT OF SURGERY", 34, TEAL, 0.0035)
	label.position = Vector3(1.2, 2.75, back + 0.03)
	add_child(label)
	# The long table and its chairs.
	var table := LowPoly.joint(self, "Table", TABLE)
	LowPoly.put(table, LowPoly.box(Vector3(3.6, 0.07, 1.1), WOOD), Vector3(0, 0.76, 0))
	for x: float in [-1.6, 1.6]:
		for z: float in [-0.42, 0.42]:
			LowPoly.put(table, LowPoly.cylinder(0.04, 0.04, 0.74, 6, WOOD.darkened(0.25)), Vector3(x, 0.37, z))
	LowPoly.put(table, LowPoly.shadow_blob(1.9, Vector2(1.0, 0.36)), Vector3.ZERO)
	for index in 4:
		LowPoly.put(table, LowPoly.box(Vector3(0.24, 0.01, 0.32), Color("#F4F4F0")), Vector3(-1.1 + index * 0.75, 0.8, -0.2 + 0.1 * (index % 2)))
	LowPoly.put(table, LowPoly.cylinder(0.05, 0.04, 0.1, 8, Color("#E8F4F8")), Vector3(0.3, 0.84, 0.2))
	for seat: String in SEATS:
		var entry: Array = SEATS[seat]
		_chair(entry[0] as Vector3, float(entry[1]))
	# A projector on a trolley at the near end.
	var projector := LowPoly.joint(self, "Projector", Vector3(-0.2, 0, 1.9))
	LabStation.table(projector, Vector3(0.5, 0.75, 0.4), Color("#8FA1A6"))
	LowPoly.put(projector, LowPoly.box(Vector3(0.3, 0.1, 0.25), Color("#2B2F33")), Vector3(0, 0.81, 0))


func _chair(at: Vector3, facing: float) -> void:
	var chair := LowPoly.joint(self, "Chair", at, Vector3(0, facing, 0))
	LowPoly.put(chair, LowPoly.box(Vector3(0.5, 0.07, 0.48), SEAT), Vector3(0, 0.44, 0))
	LowPoly.put(chair, LowPoly.box(Vector3(0.5, 0.52, 0.07), SEAT.darkened(0.1)), Vector3(0, 0.72, -0.22))
	LowPoly.put(chair, LowPoly.cylinder(0.03, 0.03, 0.42, 6, LabStation.STEEL_DARK), Vector3(0, 0.21, 0))
	LowPoly.put(chair, LowPoly.shadow_blob(0.34, Vector2(1.0, 0.9)), Vector3.ZERO)


## A mark in the ward's space, or null.
func mark(mark_name: String) -> Variant:
	if SEATS.has(mark_name):
		return position + (SEATS[mark_name][0] as Vector3)
	match mark_name:
		"screen":
			return position + Vector3(-0.2, 0, -2.3)
		"standing":
			return position + Vector3(-2.7, 0, -1.6)
		"door":
			return position + Vector3(ROOM.end.x - 0.5, 0, 2.6)
		"middle":
			return position + Vector3(0.6, 0, 1.6)
	return null


## Which way someone at a mark faces, as a point in the ward's space.
func facing(mark_name: String) -> Vector3:
	if SEATS.has(mark_name):
		var at: Vector3 = mark(mark_name)
		var angle := float(SEATS[mark_name][1])
		return at + Vector3(sin(angle), 0, cos(angle))
	return position + TABLE


func is_seat(mark_name: String) -> bool:
	return SEATS.has(mark_name)


## Where the camera stands for the meeting, and what it looks at.
func camera_pose() -> Array:
	return [position + Vector3(2.9, 2.5, 4.4), position + Vector3(0.0, 1.0, -0.8)]
