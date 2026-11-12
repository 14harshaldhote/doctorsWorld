class_name WardBed
extends LabStation
## A bed on the surgical ward (or the trolley in the admissions bay): the
## bed, a curtain rail, a locker and a visitor's chair, and the patient in
## it. The patient is a person from the ward, laid down on their back or
## sat on the edge by lay_down() and sit_up().
##
## For an examination the station frames the part of the body being
## examined, and spot_point() turns a case's spot ("at": [joint, x, y, z],
## a point in that joint's own space) into a place on the patient's body,
## so the buttons follow them as they breathe.

const FRAME := Color("#C9D6DA")
const SHEET := Color("#F4F7F7")
const BLANKET := Color("#9CC7D9")
const MATTRESS_TOP := 0.69
## Where a lying patient's feet are, and how high their back sits.
const LIE_AT := Vector3(0, MATTRESS_TOP + 0.12, 0.95)
const SIT_AT := Vector3(0.36, 0.2, 0.15)

var label := ""
var trolley := false
var patient: AvatarRig
var _blanket_flat: Node3D
var _blanket_up: Node3D
var _blanket_legs: Node3D


func _init(bed_id: String = "bed1", bed_label: String = "Bed 1", is_trolley: bool = false) -> void:
	id = bed_id
	name = bed_id.to_pascal_case()
	label = bed_label
	trolley = is_trolley
	spot = Vector3(0.9, 0, 0.2)
	trainer_spot = Vector3(-0.85, 0, -0.15)
	tag_point = Vector3(0.0, 1.2, 0.9)
	if trolley:
		footprints = [Rect2(-0.4, -1.0, 0.8, 2.0)]
	else:
		footprints = [Rect2(-0.55, -1.1, 1.1, 2.2), Rect2(0.58, -0.98, 0.5, 0.46)]
	frame_for("belly")


func _build() -> void:
	var width := 0.95 if not trolley else 0.7
	LowPoly.put(self, LowPoly.box(Vector3(width, 0.12, 2.0), FRAME if not trolley else STEEL), Vector3(0, 0.5, 0))
	LowPoly.put(self, LowPoly.box(Vector3(width - 0.05, 0.14, 1.94), SHEET), Vector3(0, 0.62, 0))
	LowPoly.put(self, LowPoly.box(Vector3(0.6, 0.1, 0.36), Color.WHITE), Vector3(0, 0.74, -0.72))
	_blanket_flat = LowPoly.put(self, LowPoly.box(Vector3(width - 0.03, 0.04, 1.2), BLANKET), Vector3(0, 0.7, 0.32))
	_blanket_up = LowPoly.put(self, LowPoly.box(Vector3(width - 0.01, 0.24, 1.0), BLANKET), Vector3(0, 0.86, 0.52))
	_blanket_up.visible = false
	# Folded down to the knees, for examining a lying patient's belly.
	_blanket_legs = LowPoly.put(self, LowPoly.box(Vector3(width - 0.01, 0.2, 0.62), BLANKET), Vector3(0, 0.84, 0.72))
	_blanket_legs.visible = false
	if not trolley:
		LowPoly.put(self, LowPoly.box(Vector3(1.0, 0.7, 0.06), STEEL_DARK), Vector3(0, 0.75, -1.0))
	for x: float in [-width * 0.44, width * 0.44]:
		for z: float in [-0.9, 0.9]:
			LowPoly.put(self, LowPoly.cylinder(0.02, 0.02, 0.44, 6, STEEL_DARK), Vector3(x, 0.22, z))
			if trolley:
				LowPoly.put(self, LowPoly.cylinder(0.05, 0.05, 0.03, 8, Color("#2B2B2B")), Vector3(x, 0.05, z),
					Vector3(0, 0, PI / 2))
	LowPoly.put(self, LowPoly.shadow_blob(1.0, Vector2(0.55, 1.0)), Vector3.ZERO)
	if trolley:
		# Side rails and a drip pole.
		for side: float in [-1.0, 1.0]:
			LowPoly.put(self, LowPoly.box(Vector3(0.02, 0.12, 1.4), STEEL), Vector3(side * 0.36, 0.78, 0.1))
		LowPoly.put(self, LowPoly.cylinder(0.012, 0.012, 1.3, 6, STEEL), Vector3(-0.32, 1.25, -0.9))
		LowPoly.put(self, LowPoly.box(Vector3(0.1, 0.18, 0.04), Color("#E8F4F8")), Vector3(-0.27, 1.8, -0.9))
		return
	# A curtain rail with the curtain pulled back, a locker and a chair.
	LowPoly.put(self, LowPoly.box(Vector3(0.04, 2.5, 0.5), Color("#BFE3E8")), Vector3(-1.15, 1.35, -0.85))
	LowPoly.put(self, LowPoly.box(Vector3(0.04, 0.04, 2.4), STEEL_DARK), Vector3(-1.15, 2.62, 0.0))
	var locker := LowPoly.joint(self, "Locker", Vector3(0.82, 0, -0.75))
	LowPoly.put(locker, LowPoly.box(Vector3(0.45, 0.7, 0.42), Color("#E2C7A4")), Vector3(0, 0.35, 0))
	LowPoly.put(locker, LowPoly.cylinder(0.05, 0.05, 0.12, 7, Color("#BFE7F0")), Vector3(0.08, 0.76, 0.02))
	var chair := LowPoly.joint(self, "Chair", Vector3(-0.95, 0, 0.75), Vector3(0, PI / 2, 0))
	LowPoly.put(chair, LowPoly.box(Vector3(0.46, 0.06, 0.46), Color("#5FB7A6")), Vector3(0, 0.45, 0))
	LowPoly.put(chair, LowPoly.box(Vector3(0.46, 0.5, 0.06), Color("#5FB7A6")), Vector3(0, 0.72, -0.21))
	for x: float in [-0.19, 0.19]:
		for z: float in [-0.19, 0.19]:
			LowPoly.put(chair, LowPoly.cylinder(0.018, 0.018, 0.44, 6, STEEL_DARK), Vector3(x, 0.22, z))
	var number := label3d(label.to_upper(), 34, TEAL, 0.004)
	number.position = Vector3(0, 1.12, -1.04)
	add_child(number)


## Where a visitor sits beside the bed (on the far side from the doctor).
func chair_point() -> Vector3:
	return at(Vector3(-0.95, 0, 0.75))


## Places around the bed: "side" (the doctor's spot), "other" (across the
## bed), "chair" (the visitor's chair), "foot" (standing at the foot) and
## "head" (by the pillow, on the doctor's side).
func mark(which: String) -> Vector3:
	match which:
		"other":
			return at(trainer_spot)
		"chair":
			return chair_point()
		"foot":
			return at(Vector3(0.25, 0, 1.45))
		"head":
			return at(Vector3(0.85, 0, -0.6))
		"top":
			return at(Vector3(0.15, 0, -1.5))
	return at(spot)


## Where the patient's head is, for people to look at.
func pillow_point() -> Vector3:
	return at(Vector3(0, 0.95, -0.6))

## Lays a person on their back in this bed, head on the pillow.
func lay_down(rig: AvatarRig) -> void:
	patient = rig
	rig.sitting = false
	rig.lying = true
	rig.moving = 0.0
	rig.position = at(LIE_AT)
	rig.rotation = Vector3(-PI / 2, rotation.y, 0)
	_blanket_flat.visible = false
	_blanket_up.visible = true
	_blanket_legs.visible = false


## Folds the blanket down to the knees (true) or back up (false).
func uncover(on: bool) -> void:
	if patient == null or not patient.lying:
		return
	_blanket_up.visible = not on
	_blanket_legs.visible = on


## Sits a person on the edge of this bed, facing the doctor's side.
func sit_up(rig: AvatarRig) -> void:
	patient = rig
	rig.lying = false
	rig.sitting = true
	rig.moving = 0.0
	rig.position = at(SIT_AT)
	rig.rotation = Vector3(0, rotation.y + PI / 2, 0)
	_blanket_flat.visible = true
	_blanket_up.visible = false
	_blanket_legs.visible = false


## The bed is empty again (the person is placed elsewhere by the ward).
func clear() -> void:
	if patient != null:
		patient.lying = false
		patient.sitting = false
		patient.rotation = Vector3(0, patient.rotation.y, 0)
	patient = null
	_blanket_flat.visible = true
	_blanket_up.visible = false
	_blanket_legs.visible = false


## Frames the close-up for an examination of the belly, a wrist or a whole
## injured body ("trauma"), or a bedside talk ("talk").
func frame_for(body: String) -> void:
	match body:
		"talk":
			# A patient sitting on the edge of the bed, face to face.
			close_from = Vector3(2.3, 1.45, 0.25)
			close_at = Vector3(0.36, 1.0, 0.15)
			close_fov = 48.0
			close_offset = 0.0
		"wrist":
			# Sitting on the edge, the right forearm held out to the doctor,
			# seen from beside that arm so it runs across the screen.
			close_from = Vector3(0.8, 2.05, -1.5)
			close_at = Vector3(0.55, 1.0, -0.1)
			close_fov = 36.0
			close_offset = -0.12
		"trauma":
			close_from = Vector3(0.95, 2.3, 0.3)
			# Looking a little higher and wider keeps the head clear of the
			# monitor in the corner.
			close_at = Vector3(0.2, 0.86, -0.05)
			close_fov = 55.0
			close_offset = -0.25
		_:
			close_from = Vector3(0.75, 2.15, 0.05)
			close_at = Vector3(0.2, 0.7, -0.2)
			close_fov = 46.0
			# The patient sits right of centre, clear of the notes card.
			close_offset = -0.3


## A case spot's place on the patient: "at" is [joint, x, y, z], a point in
## that joint's own space. null when there is no patient or no such joint.
func spot_point(entry: Dictionary) -> Variant:
	if patient == null:
		return null
	var where: Variant = entry.get("at", [])
	if typeof(where) != TYPE_ARRAY or (where as Array).size() < 4:
		return null
	var parts := where as Array
	var joint := patient.joint(str(parts[0]))
	if joint == null or not joint.is_inside_tree():
		return null
	return joint.global_transform * Vector3(float(parts[1]), float(parts[2]), float(parts[3]))
