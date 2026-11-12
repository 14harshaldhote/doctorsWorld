class_name TheatreSet
extends Node3D
## The operating theatre the ward's surgeons walk into from Day 9: tiled
## walls, a clock, the list on a whiteboard, Tom's instrument trolley and a
## door with its sign. The operating table itself is the ward's station
## (a direct child of the ward, so its picking maths stays in the ward's
## space); this set is built around it, with the table at its origin.
##
## The same room is Theatre 2 or the minor theatre: only the signs change.

const WALL := Color("#CFE6E2")
const FLOOR := Color("#B9CFCB")
const TEAL := Color("#127C80")
## The room's floor, around the table at the origin: x from the head end
## (-) to the foot (+), z from the back wall (-) to the open front (+).
const ROOM := Rect2(-4.4, -3.4, 9.0, 7.4)

## The sign over the door ("THEATRE 2") and the list on the whiteboard.
var door_sign: Label3D
var board_text: Label3D


func _init() -> void:
	name = "TheatreSet"
	_build()


func _build() -> void:
	var floor_centre := Vector3(ROOM.position.x + ROOM.size.x / 2.0, -0.05, ROOM.position.y + ROOM.size.y / 2.0)
	LowPoly.put(self, LowPoly.box(Vector3(ROOM.size.x, 0.1, ROOM.size.y), FLOOR), floor_centre)
	for ix in 4:
		for iz in 3:
			if (ix + iz) % 2 == 0:
				LowPoly.put(self, LowPoly.box(Vector3(1.9, 0.01, 1.9), FLOOR.darkened(0.04)),
					Vector3(-3.4 + ix * 2.0, 0.005, -2.4 + iz * 2.0))
	# Back wall with tiles, two side walls, a teal skirting.
	var back := ROOM.position.y
	LowPoly.put(self, LowPoly.box(Vector3(ROOM.size.x, 3.2, 0.2), WALL), Vector3(floor_centre.x, 1.6, back - 0.1))
	LowPoly.put(self, LowPoly.box(Vector3(ROOM.size.x, 0.16, 0.24), TEAL), Vector3(floor_centre.x, 0.08, back + 0.02))
	for x: float in [ROOM.position.x, ROOM.end.x]:
		LowPoly.put(self, LowPoly.box(Vector3(0.2, 3.2, ROOM.size.y), WALL.darkened(0.05)),
			Vector3(x, 1.6, floor_centre.z))
	for row in 3:
		for column in 8:
			if (row + column) % 2 == 0:
				LowPoly.put(self, LowPoly.box(Vector3(0.9, 0.5, 0.01), WALL.darkened(0.06)),
					Vector3(-3.4 + column * 1.0, 0.6 + row * 0.55, back + 0.02))
	# A big clock: theatres always have a clock.
	var clock := LowPoly.joint(self, "Clock", Vector3(2.2, 2.5, back + 0.03))
	LowPoly.put(clock, LowPoly.cylinder(0.26, 0.26, 0.05, 14, Color.WHITE), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	LowPoly.put(clock, LowPoly.torus(0.24, 0.28, TEAL, 16, 3), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	LowPoly.put(clock, LowPoly.box(Vector3(0.025, 0.16, 0.01), UiKit.INK), Vector3(0, 0.07, 0.035))
	LowPoly.put(clock, LowPoly.box(Vector3(0.11, 0.022, 0.01), UiKit.INK), Vector3(0.05, 0.0, 0.035))
	# The day's list on a whiteboard.
	var board := LowPoly.joint(self, "Whiteboard", Vector3(-1.6, 1.7, back + 0.03))
	LowPoly.put(board, LowPoly.box(Vector3(1.5, 0.85, 0.03), Color("#FBFAF5")), Vector3.ZERO)
	LowPoly.put(board, LowPoly.box(Vector3(1.56, 0.04, 0.06), Color("#8FA1A6")), Vector3(0, -0.45, 0.02))
	board_text = LabStation.label3d("", 26, UiKit.INK, 0.0032)
	board_text.position = Vector3(0, 0.04, 0.03)
	board.add_child(board_text)
	# The doorway on the left wall, with the sign and a red "in use" light.
	var door := LowPoly.joint(self, "Door", Vector3(ROOM.position.x + 0.11, 0, 1.6))
	LowPoly.put(door, LowPoly.box(Vector3(0.04, 2.3, 1.4), Color("#9CC7D9")), Vector3(0, 1.15, 0))
	LowPoly.put(door, LowPoly.box(Vector3(0.05, 0.6, 0.3), Color("#E8F4F8")), Vector3(0.01, 1.5, 0.3))
	door_sign = LabStation.label3d("THEATRE 2", 56, TEAL)
	door_sign.position = Vector3(ROOM.position.x + 0.16, 2.6, 1.6)
	door_sign.rotation.y = PI / 2
	add_child(door_sign)
	var in_use := LowPoly.box(Vector3(0.05, 0.12, 0.32), Color("#FF6B6B"))
	in_use.material_override = LowPoly.glow(Color("#FF6B6B"), 1.0)
	LowPoly.put(self, in_use, Vector3(ROOM.position.x + 0.16, 2.9, 1.6))
	# Tom's instrument trolley, at the foot of the table on the doctor's side.
	var trolley := LowPoly.joint(self, "BackTable", Vector3(1.55, 0, 1.1))
	LabStation.table(trolley, Vector3(0.9, 0.9, 0.55), Color("#3E8E7A"))
	for index in 6:
		var model := Instruments.make(Instruments.ALL[index])
		model.scale = Vector3.ONE * 1.2
		LowPoly.put(trolley, model, Vector3(-0.32 + index * 0.13, 0.91, 0.0))
	for index in 4:
		LowPoly.put(trolley, LowPoly.box(Vector3(0.07, 0.01, 0.06), Color("#F4F4F0")), Vector3(0.3, 0.91 + index * 0.012, 0.18))
	# A swab bucket and a cabinet of supplies against the back wall.
	var bucket := LowPoly.joint(self, "Bucket", Vector3(2.4, 0, -0.9))
	LowPoly.put(bucket, LowPoly.cylinder(0.2, 0.16, 0.42, 10, Color("#E2E8E8")), Vector3(0, 0.21, 0))
	LowPoly.put(bucket, LowPoly.torus(0.18, 0.21, TEAL, 12, 3), Vector3(0, 0.42, 0))
	var cabinet := LowPoly.joint(self, "Cabinet", Vector3(3.6, 0, back + 0.35))
	LowPoly.put(cabinet, LowPoly.box(Vector3(1.0, 1.8, 0.5), Color("#E2EEEC")), Vector3(0, 0.9, 0))
	LowPoly.put(cabinet, LowPoly.box(Vector3(0.9, 1.6, 0.02), Color("#BFE7F0")), Vector3(0, 0.95, 0.26))
	for shelf in 3:
		for item in 4:
			LowPoly.put(cabinet, LowPoly.box(Vector3(0.16, 0.18, 0.2), [Color("#F5B841"), Color("#5E9FD0"),
				Color("#F4F4F0"), Color("#8FE3A6")][(shelf + item) % 4]), Vector3(-0.3 + item * 0.2, 0.5 + shelf * 0.5, 0.05))


## The signs for an operation: the room's name over the door and the list.
func show_operation(room: String, list_line: String) -> void:
	door_sign.text = room.to_upper()
	board_text.text = "%s · LIST\n1. %s" % [room.to_upper(), list_line]
