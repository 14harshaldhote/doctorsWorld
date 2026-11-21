class_name CasualtyRoom
extends Node3D
## Casualty, through the ward's door: four cubicles with trolleys along the
## back wall, curtains between them, benches for the people waiting, the
## triage desk with its nurse, and the door back to Ward 4. Built far below
## the ward (Ward.CASUALTY_AT) and shown only while the doctor is here.
##
## The people come and go with the shift (ShiftSim): sync() gives each
## patient a body (at most one built a frame, so nothing stutters when
## someone walks in), sits the waiting on the benches, walks whoever is
## taken to their cubicle and lays them down, and walks the finished out.
## Floor: x from the left wall (-7.2) to the door wall (7.2), z from the
## back wall (-4) towards the camera. The room sits straight below the
## ward (only its height differs), so a point's x and z are the same in the
## room and in the world, which is what the walking (Crowd) works in; world()
## adds the height for anything placed outside the room.

const WALL := Color("#EAF0EE")
const FLOOR := Color("#D3DDE0")
const TEAL := Color("#127C80")
const CURTAIN := Color("#9FD3D6")
const BENCH := Color("#F5B841")
const ROOM := Rect2(-7.2, -4.0, 14.4, 8.0)
## Each cubicle's middle (x); the trolleys stand in them, heads to the wall.
const CUBICLE_X := [-5.4, -1.8, 1.8, 5.4]
const TROLLEY_AT := Vector3(-0.3, 0, -2.45)
## Where people sit to wait, in the order they fill: two benches facing
## out of the room (towards the camera), so their faces show, with a gap
## between them to walk through to the cubicles.
const SEATS := [
	Vector3(0.9, 0, 2.3), Vector3(1.65, 0, 2.3), Vector3(2.4, 0, 2.3),
	Vector3(4.4, 0, 2.3), Vector3(5.15, 0, 2.3), Vector3(5.9, 0, 2.3),
]
const BENCH_X := [1.65, 5.15]
## The triage desk, its front (and the nurse's face) towards the camera.
const DESK := Vector3(-4.6, 0, 2.3)
## Where the doctor stands to go back through the door, and where they come in.
const DOOR := Vector3(6.55, 0, 0.6)
const WALK_SPEED := 1.3

var walk_area: WalkArea
var trolleys: Array[WardBed] = []
var nurse: AvatarRig
## Patient id -> {"rig", "patient", "seat", "route", "state"}: the bodies on
## show. state is how the body was last placed ("seat", "walk_seat" (on
## the way in from the door), "walk_in" (to a cubicle), "lying", "walk_out").
var bodies := {}
var _rigs_built := 0
## False until every body has been built since the doctor came in: people
## already waiting just sit there; anyone who turns up after walks in
## through the door.
var _settled := false
## The patient whose result is on the card: they stay on the trolley until
## the doctor is done reading it (-1 for nobody).
var held := -1


func _ready() -> void:
	# Its trolleys build themselves on entering the tree; then the room's
	# still parts are merged into fewer draw calls (the ward's own merge
	# skips the room, which is hidden by then).
	StaticBatch.optimise(self)


func _init() -> void:
	name = "CasualtyRoom"
	walk_area = WalkArea.new(Rect2(ROOM.position.x + 0.3, ROOM.position.y + 0.25, ROOM.size.x - 0.6, ROOM.size.y - 0.6), 0.28)
	_build()


func _build() -> void:
	var centre := Vector3(ROOM.position.x + ROOM.size.x / 2.0, -0.05, ROOM.position.y + ROOM.size.y / 2.0)
	LowPoly.put(self, LowPoly.box(Vector3(ROOM.size.x + 0.4, 0.1, ROOM.size.y + 0.2), FLOOR), centre)
	# A teal line on the floor in front of the cubicles: wait behind it.
	LowPoly.put(self, LowPoly.box(Vector3(ROOM.size.x - 0.4, 0.012, 0.08), TEAL), Vector3(0, 0.006, -0.95))
	LowPoly.put(self, LowPoly.box(Vector3(ROOM.size.x + 0.4, 3.2, 0.2), WALL), Vector3(centre.x, 1.6, ROOM.position.y - 0.1))
	LowPoly.put(self, LowPoly.box(Vector3(ROOM.size.x + 0.4, 0.16, 0.24), TEAL), Vector3(centre.x, 0.08, ROOM.position.y + 0.02))
	for x: float in [ROOM.position.x - 0.1, ROOM.end.x + 0.1]:
		LowPoly.put(self, LowPoly.box(Vector3(0.2, 3.2, ROOM.size.y + 0.2), WALL.darkened(0.04)), Vector3(x, 1.6, centre.z))
	var sign := LabStation.label3d("CASUALTY", 64, Color("#C0392B"))
	sign.position = Vector3(0, 2.8, ROOM.position.y + 0.02)
	add_child(sign)
	_build_cubicles()
	_build_benches()
	_build_desk()
	_build_door()


func _build_cubicles() -> void:
	for index in CUBICLE_X.size():
		var x: float = CUBICLE_X[index]
		var trolley := WardBed.new("cubicle%d" % (index + 1), "Cubicle %d" % (index + 1), true)
		trolley.position = Vector3(x, 0, 0) + TROLLEY_AT
		add_child(trolley)
		trolleys.append(trolley)
		for rect in trolley.blockers():
			walk_area.add_blocker(rect)
		var number := LabStation.label3d(str(index + 1), 54, TEAL, 0.005)
		number.position = Vector3(x, 2.35, ROOM.position.y + 0.03)
		add_child(number)
		# A monitor on the wall beside the trolley's head.
		var screen := LowPoly.box(Vector3(0.42, 0.3, 0.04), Color("#2B2F33"))
		LowPoly.put(self, screen, Vector3(x + 0.55, 1.55, ROOM.position.y + 0.04))
		var glow := LowPoly.box(Vector3(0.36, 0.24, 0.01), Color("#7FE0C8"))
		glow.material_override = LowPoly.glow(Color("#7FE0C8"), 0.5)
		LowPoly.put(self, glow, Vector3(x + 0.55, 1.55, ROOM.position.y + 0.065))
	# Curtains between the cubicles, half drawn, on rails.
	for edge: float in [-3.6, 0.0, 3.6]:
		LowPoly.put(self, LowPoly.box(Vector3(0.04, 2.2, 2.2), CURTAIN), Vector3(edge, 1.2, -2.9))
		LowPoly.put(self, LowPoly.box(Vector3(0.05, 0.05, 3.0), LabStation.STEEL_DARK), Vector3(edge, 2.35, -2.5))
		walk_area.add_blocker(Rect2(edge - 0.1, -4.0, 0.2, 2.25))


func _build_benches() -> void:
	var z: float = SEATS[0].z
	for middle: float in BENCH_X:
		var bench := LowPoly.joint(self, "Bench", Vector3(middle, 0, z))
		LowPoly.put(bench, LowPoly.box(Vector3(2.3, 0.07, 0.5), BENCH), Vector3(0, 0.45, 0))
		LowPoly.put(bench, LowPoly.box(Vector3(2.3, 0.5, 0.06), BENCH), Vector3(0, 0.72, -0.22))
		for x: float in [-1.0, 1.0]:
			LowPoly.put(bench, LowPoly.box(Vector3(0.06, 0.44, 0.4), LabStation.STEEL_DARK), Vector3(x, 0.22, 0))
		# Further back than front, so someone getting up steps out forwards,
		# not through the backrest.
		walk_area.add_blocker(Rect2(middle - 1.2, z - 0.32, 2.4, 0.5))


func _build_desk() -> void:
	var desk := LowPoly.joint(self, "TriageDesk", DESK)
	LowPoly.put(desk, LowPoly.box(Vector3(2.2, 0.95, 0.6), Color("#E2EEEC")), Vector3(0, 0.475, 0))
	LowPoly.put(desk, LowPoly.box(Vector3(2.3, 0.06, 0.68), Color("#8FB9B3")), Vector3(0, 0.98, 0))
	LowPoly.put(desk, LowPoly.box(Vector3(2.2, 0.18, 0.06), Color("#C0392B")), Vector3(0, 0.75, 0.32))
	LowPoly.put(desk, LowPoly.box(Vector3(0.46, 0.3, 0.04), Color("#2B2F33")), Vector3(0.5, 1.18, -0.1))
	var label := LabStation.label3d("TRIAGE", 30, Color.WHITE, 0.0035)
	label.position = Vector3(0, 0.75, 0.36)
	desk.add_child(label)
	walk_area.add_blocker(Rect2(DESK.x - 1.15, DESK.z - 0.35, 2.3, 0.7))
	var look := AvatarConfig.random(SeededRandom.new(23))
	look.coat = false
	look.stethoscope = false
	look.scrubs = 2
	look.facial_hair = 0
	look.hair_style = 7
	look.hair_colour = 0
	look.skin = 6
	nurse = AvatarRig.new(look)
	nurse.name = "TriageNurse"
	nurse.position = DESK + Vector3(0.2, 0, -0.75)
	nurse.rotation.y = 0.0
	nurse.mood = AvatarConfig.Mood.FOCUSED
	add_child(nurse)


func _build_door() -> void:
	var door := LowPoly.joint(self, "Door", Vector3(ROOM.end.x - 0.02, 0, DOOR.z))
	LowPoly.put(door, LowPoly.box(Vector3(0.08, 2.3, 1.5), Color("#9CC7D9")), Vector3(0, 1.15, 0))
	LowPoly.put(door, LowPoly.box(Vector3(0.1, 0.12, 1.7), TEAL), Vector3(0, 2.36, 0))
	var label := LabStation.label3d("WARD 4", 34, TEAL, 0.004)
	label.position = Vector3(ROOM.end.x - 0.1, 2.62, DOOR.z)
	label.rotation.y = -PI / 2
	add_child(label)


# --- Places ------------------------------------------------------------------------

func floor_y() -> float:
	return position.y


## A point in the room, in the world.
func world(local: Vector3) -> Vector3:
	return position + local


## Where the doctor stands to see the patient in a cubicle (in the world).
func doctor_spot(cubicle: int) -> Vector3:
	return world(trolleys[clampi(cubicle, 0, trolleys.size() - 1)].mark("side"))


## The patient's head on a cubicle's trolley, for the doctor to face.
func pillow_point(cubicle: int) -> Vector3:
	return world(trolleys[clampi(cubicle, 0, trolleys.size() - 1)].pillow_point())


func door_spot() -> Vector3:
	return world(DOOR)


## Over a cubicle's trolley, for its tag.
func cubicle_tag_point(cubicle: int) -> Vector3:
	return world(trolleys[cubicle].at(Vector3(0, 1.75, 0.2)))


func seat_point(seat: int) -> Vector3:
	return world(SEATS[seat])


func door_tag_point() -> Vector3:
	return world(DOOR + Vector3(0.45, 2.1, 0))


# --- The people ------------------------------------------------------------------

## The bodies on show, for keeping walkers out of each other.
func rigs() -> Array:
	var found := [nurse]
	for id: int in bodies:
		found.append(bodies[id]["rig"])
	return found


func rig_of(patient: ShiftPatient) -> AvatarRig:
	if patient == null or not bodies.has(patient.id):
		return null
	return bodies[patient.id]["rig"]


## How many bodies have been built in all (for tests of the one-a-frame rule).
func rigs_built() -> int:
	return _rigs_built


## Brings the bodies in line with the shift. `everyone` is whoever else is
## on this floor (the doctor), for walking round them. At most one body is
## built each call.
func sync(sim: ShiftSim, delta: float, everyone: Array = []) -> void:
	if sim == null:
		return
	var walkers := everyone.duplicate()
	walkers.append_array(rigs())
	# Bodies for people who have gone.
	for id: int in bodies.keys():
		var entry: Dictionary = bodies[id]
		var patient: ShiftPatient = entry["patient"]
		if not patient.is_here() and entry["state"] != "walk_out":
			if patient.outcome == "left":
				_walk_out(entry, walkers)
			else:
				_remove(id)
	var built := false
	var missing := false
	for patient in sim.patients:
		if not patient.is_here():
			continue
		if not bodies.has(patient.id):
			if patient.state == "done":
				continue
			if built:
				missing = true
				continue
			_add_body(patient)
			built = true
			if _settled and patient.state == "waiting":
				_walk_to_seat(bodies[patient.id], walkers)
		var entry: Dictionary = bodies[patient.id]
		match patient.state:
			"waiting":
				if entry["state"] not in ["seat", "walk_seat"]:
					_seat(entry)
			"seeing":
				if entry["state"] in ["seat", "walk_seat"]:
					_walk_in(entry, walkers)
			"done":
				if entry["state"] in ["seat", "walk_seat", "walk_in", "lying"] and patient.id != held:
					_walk_out(entry, walkers)
	if not missing:
		_settled = true
	for id: int in bodies.keys():
		_step(id, delta, walkers)


## The doctor has just come in: whoever is already waiting is sitting down,
## not walking in.
func fresh_view() -> void:
	_settled = false
	for id: int in bodies:
		var entry: Dictionary = bodies[id]
		if entry["state"] == "walk_seat":
			_seat(entry)


func _add_body(patient: ShiftPatient) -> void:
	var look := PatientLook.make(patient.person, patient.age, patient.look_seed, patient.triage())
	var rig := AvatarRig.new(look["config"])
	rig.name = "Patient%d" % patient.id
	rig.outfit = str(look["outfit"])
	rig.mood = int(look["mood"])
	rig.voice_pitch = 1.0
	add_child(rig)
	_rigs_built += 1
	var entry := {"rig": rig, "patient": patient, "seat": -1, "route": {}, "state": ""}
	bodies[patient.id] = entry
	if patient.state == "seeing":
		entry["state"] = "seat"
		_lie(entry)


## Sits a waiting patient on the first free seat (or stands them by the
## benches if every seat is taken, which the shift's own limit prevents).
func _seat(entry: Dictionary) -> void:
	var rig: AvatarRig = entry["rig"]
	var seat := int(entry["seat"])
	if seat < 0:
		seat = _free_seat()
		entry["seat"] = seat
	entry["state"] = "seat"
	entry["route"] = {}
	rig.lying = false
	rig.moving = 0.0
	rig.rotation = Vector3.ZERO
	if seat >= 0:
		rig.position = SEATS[seat]
		rig.sitting = true
	else:
		rig.position = Vector3(3.4, 0, 3.0)
		rig.sitting = false


## Someone who has just turned up: in through the door and over to the
## first free seat.
func _walk_to_seat(entry: Dictionary, walkers: Array) -> void:
	var rig: AvatarRig = entry["rig"]
	var seat := _free_seat()
	if seat < 0:
		_seat(entry)
		return
	entry["seat"] = seat
	rig.sitting = false
	rig.lying = false
	rig.position = DOOR + Vector3(0.3, 0, 0)
	rig.rotation = Vector3(0, -PI / 2, 0)
	var path := Crowd.plan(rig, world(SEATS[seat] + Vector3(0, 0, 0.55)), walkers, walk_area, floor_y())
	if path.is_empty():
		_seat(entry)
		return
	entry["state"] = "walk_seat"
	entry["route"] = {"path": path, "speed": WALK_SPEED}


func _free_seat() -> int:
	var taken := {}
	for id: int in bodies:
		var entry: Dictionary = bodies[id]
		if entry["state"] in ["seat", "walk_seat"] and int(entry["seat"]) >= 0:
			taken[int(entry["seat"])] = true
	for seat in SEATS.size():
		if not taken.has(seat):
			return seat
	return -1


## Gets up from the bench and walks to their cubicle.
func _walk_in(entry: Dictionary, walkers: Array) -> void:
	var patient: ShiftPatient = entry["patient"]
	var rig: AvatarRig = entry["rig"]
	entry["seat"] = -1
	rig.sitting = false
	var trolley := trolleys[clampi(patient.cubicle, 0, trolleys.size() - 1)]
	var to := trolley.mark("foot")
	var path := Crowd.plan(rig, to, walkers, walk_area, floor_y())
	if path.is_empty():
		_lie(entry)
		return
	entry["state"] = "walk_in"
	entry["route"] = {"path": path, "speed": WALK_SPEED}


## Lies down on their cubicle's trolley.
func _lie(entry: Dictionary) -> void:
	var patient: ShiftPatient = entry["patient"]
	var rig: AvatarRig = entry["rig"]
	entry["state"] = "lying"
	entry["route"] = {}
	entry["seat"] = -1
	if patient.cubicle >= 0:
		trolleys[patient.cubicle].lay_down(rig)


## Lies them down now if they are still on their way (the doctor got there
## first).
func settle(patient: ShiftPatient) -> void:
	if patient == null or not bodies.has(patient.id):
		return
	var entry: Dictionary = bodies[patient.id]
	if patient.state == "seeing" and entry["state"] != "lying":
		_lie(entry)


func _walk_out(entry: Dictionary, walkers: Array) -> void:
	var rig: AvatarRig = entry["rig"]
	for trolley in trolleys:
		if trolley.patient == rig:
			trolley.clear()
	entry["seat"] = -1
	rig.sitting = false
	rig.lying = false
	rig.rotation = Vector3(0, rig.rotation.y, 0)
	entry["state"] = "walk_out"
	var path := Crowd.plan(rig, world(DOOR + Vector3(0.3, 0, 0)), walkers, walk_area, floor_y())
	entry["route"] = {"path": path, "speed": WALK_SPEED}


func _step(id: int, delta: float, walkers: Array) -> void:
	var entry: Dictionary = bodies[id]
	var route: Dictionary = entry["route"]
	if route.is_empty():
		return
	var rig: AvatarRig = entry["rig"]
	var done := Crowd.advance(rig, route, delta, walkers, walk_area, floor_y())
	if not done:
		return
	rig.moving = 0.0
	entry["route"] = {}
	match entry["state"]:
		"walk_seat":
			_seat(entry)
		"walk_in":
			_lie(entry)
		"walk_out":
			_remove(id)


func _remove(id: int) -> void:
	var entry: Dictionary = bodies[id]
	var rig: AvatarRig = entry["rig"]
	for trolley in trolleys:
		if trolley.patient == rig:
			trolley.clear()
	bodies.erase(id)
	rig.queue_free()


## Everyone gone, for a new day.
func clear_all() -> void:
	for id: int in bodies.keys():
		_remove(id)


## The patient whose body is under a screen point, or null.
func patient_at(camera: Camera3D, screen_point: Vector2) -> ShiftPatient:
	var best: ShiftPatient = null
	var best_distance := UiKit.px(44)
	for id: int in bodies:
		var entry: Dictionary = bodies[id]
		if entry["state"] == "walk_out":
			continue
		var rig: AvatarRig = entry["rig"]
		var feet := rig.global_position
		var head := rig.face_point() + Vector3(0, 0.12, 0)
		if camera.is_position_behind(head) or camera.is_position_behind(feet):
			continue
		var a := camera.unproject_position(feet)
		var b := camera.unproject_position(head)
		var distance := Geometry2D.get_closest_point_to_segment(screen_point, a, b).distance_to(screen_point)
		if distance < best_distance:
			best_distance = distance
			best = entry["patient"]
	return best


## The seat someone is sitting on, or -1.
func seat_of(patient: ShiftPatient) -> int:
	if patient == null or not bodies.has(patient.id):
		return -1
	var entry: Dictionary = bodies[patient.id]
	return int(entry["seat"]) if entry["state"] == "seat" else -1


## The patient sitting on a seat, or null.
func patient_in_seat(seat: int) -> ShiftPatient:
	for id: int in bodies:
		var entry: Dictionary = bodies[id]
		if entry["state"] == "seat" and int(entry["seat"]) == seat:
			return entry["patient"]
	return null


## Where a body's tag floats: over their head on the bench, over the
## trolley in a cubicle.
func tag_point(patient: ShiftPatient) -> Vector3:
	if patient.cubicle >= 0:
		return cubicle_tag_point(patient.cubicle)
	var rig := rig_of(patient)
	if rig != null:
		return rig.global_position + Vector3(0, 1.75 if not rig.sitting else 1.45, 0)
	return world(Vector3(3.6, 1.6, 3.0))


## The camera over casualty: high enough to take in the benches and the
## cubicles at once, sliding sideways with the doctor (goal, target).
func camera_pose(focus: Vector3) -> Array:
	var local := focus - position
	var at := world(Vector3(clampf(local.x, -3.6, 3.6), 0, clampf(local.z, -0.4, 0.4)))
	return [at + Vector3(0, 7.0, 7.6), at + Vector3(0, 0.5, -0.4)]
