class_name OperatingTable
extends LabStation
## The operating table with the patient under blue drapes, the anaesthetic
## screen at their head, a window of skin, big lights overhead, Dr. Khan's
## machine and monitor, and the doctor's own gloved hands in first person.
##
## Rohit's appendectomy has its own hand-made parts (below). Every other
## operation is drawn from the parts its OperationTask lays out: discs,
## tubes, blobs, slivers and rings in skin centimetres, each shown while a
## condition about the operation holds (see OperationTask.condition_met).
##
## The skin shows the operation as it goes: the dotted line, the cut, the
## wound held open with the bowel and the appendix inside, the appendix
## lifted out, clamped and cut, blood or pus during a complication, a lost
## swab, and the stitches at the end. Tap targets (the appendix, its base,
## where to cut, a bleeder, a swab, the bowel) have points here.
##
## Rohit lies along x with his head at -x, so his right side is +z, towards
## the doctor. Skin positions are centimetres as in OperationTask, drawn at
## SCALE metres per centimetre (twice life size, to tap on a phone).

const TABLE_TOP := 0.86
const SCALE := 0.02
## The skin window's corner (head end, far side) in the station's space.
const SKIN_ORIGIN := Vector3(-0.07, 0, -0.17)
const SKIN_Y := TABLE_TOP + 0.2
const SKIN := OperationTask.SKIN
const BLUE := Color("#3F7FB5")
const BLUE_DARK := Color("#2F6696")
const SKIN_TONE := Color("#D9A27E")
const IODINE := Color("#C8874F")
const WOUND := Color("#8E2626")
const WOUND_DEEP := Color("#5A1414")
const BOWEL := Color("#E8A4A0")
const APPENDIX := Color("#D9676A")
const BLOOD := Color("#A51E1E")
const PUS := Color("#E8DCA0")
const SUTURE := Color("#22337A")
const GLOVE := Color("#E7D3A2")
## The hands are drawn smaller than life so they never hide the wound.
const HAND_SCALE := 0.6
## Where the hands rest when they are not working, in skin centimetres.
const LEFT_REST := Vector2(9.6, 12.8)
const RIGHT_REST := Vector2(17.4, 12.4)
## The middle of where the work happens (the incision and what is inside).
const WORK_CENTRE := Vector2(13.3, 9.6)
## Where things are inside the wound, in skin centimetres.
const TARGETS := {
	"appendix": Vector2(13.9, 9.1),
	"bowel": Vector2(11.7, 10.5),
	"base": Vector2(12.2, 10.0),
	"cut": Vector2(14.0, 8.8),
	"bleeder": Vector2(12.7, 10.9),
	"swab": Vector2(13.8, 9.9),
}
## Heights above the skin for tap targets (things inside sit lower).
## The wound is drawn as dark discs on the skin, so what is inside sits
## just above them.
const TARGET_DEPTH := {"appendix": 0.011, "bowel": 0.01, "base": 0.02, "cut": 0.03, "bleeder": 0.012, "swab": 0.014}

var look: AvatarConfig
var _guide_line: Node3D
var _cut: Node3D
var _wound: Node3D
var _retractors: Node3D
var _appendix_in: Node3D
var _appendix_up: Node3D
var _clamp: Node3D
var _tie: Node3D
var _blood: Node3D
var _spurt: Node3D
var _pus: Node3D
var _swab: Node3D
var _stitches: Node3D
var _trace_marks: Node3D
var _hands: Node3D
var _hand := {}
var _held: Node3D
var _held_name := ""
var _monitor_light: MeshInstance3D
var _clock := 0.0
var _shown_stitches := -1
var _shown_trace := -1
var _guide_shown := ""
## The operation on the table now, and its own parts (not the appendix).
var _op: OperationTask
var _generic: Node3D
var _generic_parts := {}
var _appendix_nodes: Array[Node3D] = []


## Points the close-up camera at a spot on the skin (the middle of the work).
func _frame_work(centre: Vector2) -> void:
	var work := skin_local(centre)
	close_from = work + Vector3(0.0, 0.29, 0.21)
	close_at = work + Vector3(-0.022, 0.0, -0.016)


func _init(for_look: AvatarConfig = null) -> void:
	id = "appendix"
	name = "OperatingTable"
	look = for_look if for_look != null else AvatarConfig.new()
	spot = Vector3(0.22, 0, 0.62)
	trainer_spot = Vector3(0.18, 0, -0.62)
	# Looking down into the wound from the doctor's side, framed a little
	# left of and above the work so it sits between the screen's panels.
	var work := skin_local(WORK_CENTRE)
	close_from = work + Vector3(0.0, 0.29, 0.21)
	close_at = work + Vector3(-0.022, 0.0, -0.016)
	close_fov = 44.0
	close_offset = 0.0
	tag_point = Vector3(0, 1.6, 0)
	footprints = [Rect2(-1.05, -0.36, 2.1, 0.72)]


func _build() -> void:
	_build_table()
	_build_patient()
	_build_machines()
	_build_lights()
	_build_wound()
	_build_hands()


func _build_table() -> void:
	LowPoly.put(self, LowPoly.box(Vector3(2.0, 0.08, 0.56), STEEL_DARK), Vector3(0, TABLE_TOP - 0.06, 0))
	LowPoly.put(self, LowPoly.box(Vector3(1.96, 0.05, 0.52), Color("#2E3A40")), Vector3(0, TABLE_TOP - 0.005, 0))
	LowPoly.put(self, LowPoly.cylinder(0.12, 0.14, TABLE_TOP - 0.15, 8, STEEL_DARK), Vector3(0, (TABLE_TOP - 0.15) / 2.0 + 0.05, 0))
	LowPoly.put(self, LowPoly.box(Vector3(0.9, 0.08, 0.5), STEEL_DARK.darkened(0.2)), Vector3(0, 0.04, 0))
	LowPoly.put(self, LowPoly.shadow_blob(1.2, Vector2(1.0, 0.4)), Vector3.ZERO)


## Rohit under the drapes: a draped body, his head and cap at the far end
## behind the screen, and the window of skin.
func _build_patient() -> void:
	var body := LowPoly.joint(self, "Patient", Vector3.ZERO)
	# Legs, then the belly and chest, all under blue drapes that hang over the sides.
	LowPoly.put(body, LowPoly.box(Vector3(1.0, 0.12, 0.5), BLUE), Vector3(0.52, TABLE_TOP + 0.08, 0))
	LowPoly.put(body, LowPoly.box(Vector3(0.7, 0.18, 0.56), BLUE), Vector3(-0.2, TABLE_TOP + 0.1, 0))
	for side: int in [-1, 1]:
		LowPoly.put(body, LowPoly.box(Vector3(1.9, 0.42, 0.02), BLUE_DARK), Vector3(0.0, TABLE_TOP - 0.1, 0.29 * side))
	# The drape around the window, with the iodine-stained skin inside.
	var window := Vector3(SKIN.x * SCALE, 0, SKIN.y * SCALE)
	var centre := SKIN_ORIGIN + window / 2.0
	LowPoly.put(body, LowPoly.box(Vector3(window.x + 0.02, 0.01, window.z + 0.02), IODINE), Vector3(centre.x, SKIN_Y - 0.004, centre.z))
	# Where the iodine is thinner, skin shows through in soft patches.
	for patch in [[Vector2(6.0, 4.5), 0.05], [Vector2(4.2, 10.4), 0.035], [Vector2(17.6, 3.6), 0.03]]:
		LowPoly.put(body, LowPoly.cylinder(float(patch[1]), float(patch[1]), 0.004, 9, SKIN_TONE.lerp(IODINE, 0.6)),
			skin_local(patch[0] as Vector2, -0.001), Vector3.ZERO, Vector3(1.3, 1.0, 0.8))
	for edge in [[Vector3(window.x + 0.14, 0.03, 0.07), Vector3(centre.x, SKIN_Y, SKIN_ORIGIN.z - 0.035)],
			[Vector3(window.x + 0.14, 0.03, 0.07), Vector3(centre.x, SKIN_Y, SKIN_ORIGIN.z + window.z + 0.035)],
			[Vector3(0.07, 0.03, window.z), Vector3(SKIN_ORIGIN.x - 0.035, SKIN_Y, centre.z)],
			[Vector3(0.07, 0.03, window.z), Vector3(SKIN_ORIGIN.x + window.x + 0.035, SKIN_Y, centre.z)]]:
		LowPoly.put(body, LowPoly.box(edge[0], BLUE.lightened(0.06)), edge[1])
	# The anaesthetic screen across his chest, and his head beyond it.
	var screen := LowPoly.joint(self, "Screen", Vector3(-0.5, TABLE_TOP, 0))
	LowPoly.put(screen, LowPoly.box(Vector3(0.02, 0.62, 0.9), BLUE.lightened(0.1)), Vector3(0, 0.5, 0))
	LowPoly.put(screen, LowPoly.cylinder(0.012, 0.012, 0.95, 6, STEEL), Vector3(0, 0.82, 0), Vector3(PI / 2, 0, 0))
	LowPoly.put(body, LowPoly.box(Vector3(0.26, 0.06, 0.34), WHITE), Vector3(-0.8, TABLE_TOP + 0.04, 0))
	LowPoly.put(body, LowPoly.sphere(0.1, SKIN_TONE, 8, 6), Vector3(-0.78, TABLE_TOP + 0.15, 0))
	LowPoly.put(body, LowPoly.sphere(0.104, Color("#7DA7D6"), 8, 5, true), Vector3(-0.8, TABLE_TOP + 0.16, 0), Vector3(0, 0, PI / 2 + 0.3))
	# A breathing tube to the machine.
	LowPoly.put(body, LowPoly.cylinder(0.012, 0.012, 0.5, 6, Color("#BFD8E6")), Vector3(-0.98, TABLE_TOP + 0.2, -0.05),
		Vector3(0, 0, PI / 2 - 0.4))


## Dr. Khan's anaesthetic machine and the monitor on its arm.
func _build_machines() -> void:
	var machine := LowPoly.joint(self, "Machine", Vector3(-1.35, 0, -0.55))
	LowPoly.put(machine, LowPoly.box(Vector3(0.6, 1.2, 0.5), Color("#DDE4E4")), Vector3(0, 0.62, 0))
	LowPoly.put(machine, LowPoly.box(Vector3(0.62, 0.05, 0.52), TEAL), Vector3(0, 0.03, 0))
	LowPoly.put(machine, LowPoly.box(Vector3(0.4, 0.2, 0.02), Color("#2E3A40")), Vector3(0, 0.95, 0.26))
	for index in 3:
		LowPoly.put(machine, LowPoly.cylinder(0.03, 0.03, 0.03, 8, [Color("#4FA0D8"), Color("#F5B841"), Color("#8FE3A6")][index]),
			Vector3(-0.15 + index * 0.15, 0.7, 0.26), Vector3(PI / 2, 0, 0))
	var arm := LowPoly.joint(self, "MonitorArm", Vector3(-1.2, 0, -0.62))
	LowPoly.put(arm, LowPoly.cylinder(0.025, 0.025, 1.6, 6, STEEL_DARK), Vector3(0, 0.8, 0))
	var monitor := LowPoly.joint(arm, "Monitor", Vector3(0.1, 1.62, 0.05), Vector3(0, 0.7, 0))
	LowPoly.put(monitor, LowPoly.box(Vector3(0.5, 0.34, 0.06), Color("#1E2A2E")), Vector3.ZERO)
	LowPoly.put(monitor, LowPoly.box(Vector3(0.44, 0.28, 0.01), Color("#06171A")), Vector3(0, 0, 0.032))
	var trace := LowPoly.box(Vector3(0.36, 0.01, 0.005), Color("#8FE3A6"))
	trace.material_override = LowPoly.glow(Color("#8FE3A6"), 1.2)
	LowPoly.put(monitor, trace, Vector3(0, 0.06, 0.04))
	_monitor_light = LowPoly.sphere(0.018, Color("#FF6B6B"), 6, 4)
	_monitor_light.material_override = LowPoly.glow(Color("#FF6B6B"), 1.5)
	LowPoly.put(monitor, _monitor_light, Vector3(0.17, 0.11, 0.04))
	# A drip stand.
	var drip := LowPoly.joint(self, "Drip", Vector3(-1.05, 0, 0.45))
	LowPoly.put(drip, LowPoly.cylinder(0.015, 0.015, 1.9, 6, STEEL), Vector3(0, 0.95, 0))
	LowPoly.put(drip, LowPoly.box(Vector3(0.12, 0.2, 0.04), Color("#E8F4F8")), Vector3(0.06, 1.75, 0))


func _build_lights() -> void:
	for spot_at: Vector3 in [Vector3(0.05, 2.25, 0.05), Vector3(0.6, 2.35, -0.35)]:
		var lamp := LowPoly.joint(self, "Lamp", spot_at)
		LowPoly.put(lamp, LowPoly.cylinder(0.3, 0.36, 0.12, 12, Color("#E9EEF0")), Vector3.ZERO)
		var glass := LowPoly.cylinder(0.27, 0.27, 0.01, 12, Color("#FFF8E0"))
		glass.material_override = LowPoly.glow(Color("#FFF8E0"), 1.4)
		LowPoly.put(lamp, glass, Vector3(0, -0.065, 0))
		LowPoly.put(lamp, LowPoly.cylinder(0.02, 0.02, 0.6, 6, STEEL_DARK), Vector3(0, 0.36, 0))


## The parts that show the operation's progress, all hidden to start.
func _build_wound() -> void:
	var task := OperationTask.new()
	_guide_line = LowPoly.joint(self, "Guide", Vector3.ZERO)
	var guide := task.guide()
	# A surgical marker's dotted line.
	for index in range(0, guide.size(), 3):
		var dot := LowPoly.cylinder(0.0028, 0.0028, 0.002, 6, Color("#4B2F86"))
		LowPoly.put(_guide_line, dot, skin_local(guide[index], 0.002))
	_cut = LowPoly.joint(self, "Cut", Vector3.ZERO)
	_ribbon_on_skin(_cut, guide, 0.006, WOUND, 0.004)
	_trace_marks = LowPoly.joint(self, "Trace", Vector3.ZERO)
	# The open wound: a dark oval with the bowel and the appendix inside.
	_wound = LowPoly.joint(self, "Wound", skin_local(Vector2(13.0, 9.5), 0.0))
	var along := guide[guide.size() - 1] - guide[0]
	_wound.rotation.y = -atan2(along.y, along.x)
	LowPoly.put(_wound, LowPoly.cylinder(0.064, 0.064, 0.008, 14, WOUND), Vector3(0, 0.002, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.58))
	LowPoly.put(_wound, LowPoly.cylinder(0.054, 0.054, 0.006, 14, WOUND_DEEP), Vector3(0, 0.004, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.52))
	_retractors = LowPoly.joint(_wound, "Retractors", Vector3.ZERO)
	for side: int in [-1, 1]:
		LowPoly.put(_retractors, LowPoly.box(Vector3(0.09, 0.012, 0.014), STEEL), Vector3(0, 0.012, 0.042 * side))
		LowPoly.put(_retractors, LowPoly.box(Vector3(0.02, 0.012, 0.09), STEEL_DARK), Vector3(0.0, 0.018, 0.09 * side))
	# Bowel loops and, where the big bowel ends, the appendix.
	_appendix_in = LowPoly.joint(self, "AppendixIn", Vector3.ZERO)
	_place_on_skin(_appendix_in, TARGETS["appendix"], TARGET_DEPTH["appendix"])
	for index in 3:
		LowPoly.put(_appendix_in, LowPoly.sphere(0.008, APPENDIX, 6, 4), Vector3(-0.014 + index * 0.012, 0.0, 0.004 * sin(index * 1.4)))
	var bowel := LowPoly.joint(self, "Bowel", Vector3.ZERO)
	_place_on_skin(bowel, TARGETS["bowel"], TARGET_DEPTH["bowel"])
	LowPoly.put(bowel, LowPoly.torus(0.006, 0.016, BOWEL, 10, 5), Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.6, 1.0))
	LowPoly.put(bowel, LowPoly.torus(0.005, 0.014, BOWEL.darkened(0.08), 10, 5), Vector3(0.022, 0.0, -0.012), Vector3.ZERO,
		Vector3(1.0, 0.6, 1.0))
	var colon := LowPoly.joint(self, "Colon", Vector3.ZERO)
	_place_on_skin(colon, Vector2(12.6, 8.6), 0.008)
	LowPoly.put(colon, LowPoly.sphere(0.02, BOWEL.lightened(0.05), 8, 5), Vector3.ZERO, Vector3.ZERO, Vector3(1.2, 0.5, 1.0))
	for part: Node3D in [bowel, colon, _appendix_in]:
		part.visible = false
		part.set_meta("inside", true)
	# The appendix lifted out of the wound and lying across the skin.
	_appendix_up = LowPoly.joint(self, "AppendixUp", Vector3.ZERO)
	var base := skin_local(TARGETS["base"], 0.02)
	var tip := skin_local(TARGETS["cut"] + (TARGETS["cut"] - TARGETS["base"]) * 0.7, 0.03)
	for index in 7:
		var t := index / 6.0
		var point := base.lerp(tip, t) + Vector3(0, 0.006 * sin(t * PI), 0)
		LowPoly.put(_appendix_up, LowPoly.sphere(0.011 - 0.002 * t, APPENDIX, 7, 4), point)
	# Dr. Iyer's forceps hold its tip up, handles towards the doctor's side.
	var forceps := Instruments.make("forceps")
	_appendix_up.add_child(forceps)
	forceps.scale = Vector3.ONE * 0.8
	forceps.rotation = Vector3(-0.45, 0.55, 0)
	forceps.position = tip + Vector3(0, 0.004, 0) - forceps.basis * Vector3(0, 0, -0.07)
	_appendix_up.visible = false
	_clamp = Instruments.make("clamp")
	add_child(_clamp)
	_clamp.scale = Vector3.ONE * 1.1
	_clamp.position = skin_local(TARGETS["base"], 0.034) + Vector3(0, 0, 0.04)
	_clamp.rotation = Vector3(0.3, 0.9, 0)
	_clamp.visible = false
	_tie = LowPoly.joint(self, "Tie", skin_local(TARGETS["base"].lerp(TARGETS["cut"], 0.22), 0.024))
	LowPoly.put(_tie, LowPoly.torus(0.008, 0.012, SUTURE, 8, 3), Vector3.ZERO, Vector3(0, 0, PI / 2))
	_tie.visible = false
	# Complications.
	_blood = LowPoly.joint(self, "Blood", skin_local(TARGETS["bleeder"], 0.0))
	LowPoly.put(_blood, LowPoly.cylinder(0.04, 0.04, 0.006, 12, BLOOD), Vector3(0, 0.006, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.7))
	_spurt = LowPoly.sphere(0.008, Color("#D22B2B"), 6, 4)
	_spurt.material_override = LowPoly.glow(Color("#D22B2B"), 0.6)
	LowPoly.put(_blood, _spurt, Vector3(0, 0.02, 0))
	_blood.visible = false
	_pus = LowPoly.joint(self, "Pus", skin_local(Vector2(13.2, 9.6), 0.0))
	LowPoly.put(_pus, LowPoly.cylinder(0.045, 0.045, 0.006, 12, PUS), Vector3(0, 0.007, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.55))
	_pus.visible = false
	_swab = LowPoly.joint(self, "Swab", skin_local(TARGETS["swab"], 0.006))
	LowPoly.put(_swab, LowPoly.box(Vector3(0.026, 0.008, 0.02), Color("#F4F4F0")), Vector3(0, 0.006, 0), Vector3(0, 0.4, 0.2))
	LowPoly.put(_swab, LowPoly.box(Vector3(0.026, 0.004, 0.004), Color("#4FA0D8")), Vector3(0, 0.0105, 0.004), Vector3(0, 0.4, 0.2))
	_swab.visible = false
	_stitches = LowPoly.joint(self, "Stitches", Vector3.ZERO)
	_appendix_nodes = [_guide_line, _cut, _wound, _appendix_in, bowel, colon, _appendix_up, _clamp, _tie, _blood, _pus, _swab]


## The doctor's gloved hands and forearms in gown sleeves, reaching in from
## the camera's side of the table.
func _build_hands() -> void:
	_hands = LowPoly.joint(self, "Hands", Vector3.ZERO)
	for side: String in ["L", "R"]:
		var hand := LowPoly.joint(_hands, "Hand" + side, Vector3.ZERO)
		hand.scale = Vector3.ONE * HAND_SCALE
		_hand[side] = hand
		LowPoly.put(hand, LowPoly.box(Vector3(0.07, 0.026, 0.085), GLOVE), Vector3(0, 0, -0.01))
		for finger in 4:
			LowPoly.put(hand, LowPoly.box(Vector3(0.014, 0.016, 0.05), GLOVE), Vector3(-0.024 + finger * 0.016, -0.004, -0.072))
		LowPoly.put(hand, LowPoly.box(Vector3(0.018, 0.018, 0.045), GLOVE), Vector3(0.042 * (1 if side == "L" else -1), 0, -0.035),
			Vector3(0, 0.5 * (1 if side == "L" else -1), 0))
		var arm := LowPoly.cylinder(0.034, 0.042, 0.3, 7, Color("#6E9FD1"))
		LowPoly.put(hand, arm, Vector3(0, 0.02, 0.18), Vector3(PI / 2 - 0.25, 0, 0))
		hand.rotation = Vector3(-0.35, 0.25 if side == "R" else -0.25, 0)
	_set_hand("L", LEFT_REST, 0.03)
	_set_hand("R", RIGHT_REST, 0.03)


## Puts a hand so its fingertips (or the tip of what it holds) touch a skin
## position, lift metres above it.
func _set_hand(side: String, spot: Vector2, lift: float) -> void:
	var hand: Node3D = _hand[side]
	hand.position = skin_local(spot, lift) - hand.basis * _tip_in_hand(side)


## Where the working tip is in a hand's own space: the end of what it holds,
## else the fingertips.
func _tip_in_hand(side: String) -> Vector3:
	if side == "R" and _held != null:
		return _held.transform * Vector3(0, 0, -float(Instruments.TIPS.get(_held_name, 0.07)))
	return Vector3(0, -0.006, -0.097)


# --- Skin positions ---------------------------------------------------------

## A skin position (cm) as a position in this station's space.
static func skin_local(spot: Vector2, lift: float = 0.0) -> Vector3:
	return SKIN_ORIGIN + Vector3(spot.x * SCALE, SKIN_Y + lift, spot.y * SCALE)


## A skin position as a position in the theatre.
func skin_world(spot: Vector2, lift: float = 0.0) -> Vector3:
	return at(skin_local(spot, lift))


## The skin position under a screen point, or null when off the window.
func skin_point(camera: Camera3D, screen_point: Vector2) -> Variant:
	var hit: Variant = ray_to_height(camera, screen_point, SKIN_Y + global_position.y)
	if hit == null:
		return null
	var local: Vector3 = transform.affine_inverse() * (hit as Vector3)
	var spot := Vector2((local.x - SKIN_ORIGIN.x) / SCALE, (local.z - SKIN_ORIGIN.z) / SCALE)
	if spot.x < -1.0 or spot.y < -1.0 or spot.x > SKIN.x + 1.0 or spot.y > SKIN.y + 1.0:
		return null
	return spot


## Where a tap target is drawn, in the theatre.
func target_point(which: String) -> Vector3:
	if _generic_on():
		var spot_now: Vector2 = _op.targets.get(which, _op.procedure.get("wound_centre", Vector2(13, 9.5)))
		return skin_world(spot_now, _generic_lift(which))
	var spot: Vector2 = TARGETS.get(which, Vector2(13, 9.5))
	return skin_world(spot, float(TARGET_DEPTH.get(which, 0.0)))


func _generic_on() -> bool:
	return _op != null and _op.id != "appendix"


## How far above the skin a generic target sits (its part's height).
func _generic_lift(which: String) -> float:
	for part: Dictionary in _op.parts:
		if str(part["id"]) == which:
			return float(part.get("lift", 0.012)) + (0.01 if part.has("lifted") and _op.condition_met(str(part["lifted"])) else 0.0)
	return 0.012


## The tap target nearest a screen point (only those that show now), or "".
func target_at(camera: Camera3D, screen_point: Vector2, task: OperationTask) -> String:
	var points := {}
	for which: String in targets_shown(task):
		points[which] = target_point(which)
	return nearest_on_screen(camera, screen_point, points, UiKit.px(30))


## The tap targets that can be seen at this point in the operation.
func targets_shown(task: OperationTask) -> Array[String]:
	var found: Array[String] = []
	if task == null:
		return found
	if task.id != "appendix":
		return _generic_targets(task)
	var opened := "retract" in task.done_steps
	var lifted := "find" in task.done_steps
	if opened and not lifted:
		found.append_array(["appendix", "bowel"])
	if lifted and not "clamp" in task.done_steps:
		found.append_array(["base", "cut", "bowel"])
	elif "clamp" in task.done_steps and not "cut" in task.done_steps:
		found.append_array(["cut", "base", "bowel"])
	if task.active_complication == "bleeding":
		found.append("bleeder")
	if task.phase == "search":
		found.append_array(["swab", "bowel"])
	return found


func _generic_targets(task: OperationTask) -> Array[String]:
	var found: Array[String] = []
	for part: Dictionary in task.parts:
		if (bool(part.get("tap", false)) or part.has("tap_at")) and task.condition_met(str(part.get("show", ""))):
			found.append(str(part["id"]))
	if task.phase == "act" and task.action == "tap" and not task.target.is_empty() and task.target not in found:
		found.append(task.target)
	if task.active_complication == "bleeding" and "bleeder" not in found:
		found.append("bleeder")
	if task.phase == "search":
		found.append("swab")
	return found


# --- Showing the task -------------------------------------------------------

func reset_task(task: TrainingTask) -> void:
	_op = task as OperationTask
	_frame_work(_op.procedure.get("view_centre", _op.procedure.get("wound_centre", WORK_CENTRE)) if _generic_on() else WORK_CENTRE)
	_build_generic()
	_clock = 0.0
	_shown_stitches = -1
	_shown_trace = -1
	for child in _stitches.get_children():
		_stitches.remove_child(child)
		child.queue_free()
	for child in _trace_marks.get_children():
		_trace_marks.remove_child(child)
		child.queue_free()


func show_task(task: TrainingTask, delta: float) -> void:
	var op := task as OperationTask
	if op == null:
		return
	if op.id != "appendix":
		_clock += delta
		_show_generic(op, delta)
		return
	_clock += delta
	var done := op.done_steps
	var cut := "incision" in done
	var opened := "retract" in done or (op.step == "retract" and op.phase == "act" and op.holding)
	var lifted := "find" in done
	var out := "cut" in done
	var closing := op.step == "close" or "close" in done
	_guide_line.visible = not cut
	_cut.visible = cut and (not opened or closing)
	_wound.visible = opened and not closing
	_retractors.visible = opened and not closing
	for child in get_children():
		if child.has_meta("inside"):
			(child as Node3D).visible = opened and not closing and (child != _appendix_in or not lifted)
	_appendix_up.visible = lifted and not out and not closing
	_clamp.visible = "clamp" in done and not out
	_tie.visible = "clamp" in done and not out and not closing
	_blood.visible = op.active_complication == "bleeding" or ("bleeding" in op.happened and not closing and opened)
	if _blood.visible:
		var bleeding := op.active_complication == "bleeding"
		_blood.scale = Vector3.ONE * (1.0 + (0.25 * sin(_clock * 7.0) if bleeding else -0.4))
		_spurt.visible = bleeding
		_spurt.position.y = 0.02 + 0.015 * absf(sin(_clock * 7.0))
	_pus.visible = op.active_complication == "burst" or (op.step == "burst" and op.phase != "done")
	if _pus.visible:
		var left := 1.0 - clampf(op.hold_time / OperationTask.WASH_TIME, 0.0, 1.0) if op.step == "burst" else 1.0
		_pus.scale = Vector3(left, 1.0, left) + Vector3(0.05, 0, 0.05)
	_swab.visible = op.swab_missing and not op.swab_found and (op.phase in ["count", "search"])
	_show_trace(op)
	_show_stitches(op)
	_show_hands(op, delta)
	if _monitor_light != null:
		var alarm := not op.active_complication.is_empty() or op.stability < 50.0
		_monitor_light.visible = alarm and fmod(_clock, 0.6) < 0.35


func _show_trace(op: OperationTask) -> void:
	var count := op.trace.size() if op.tracing else 0
	if count == _shown_trace:
		return
	_shown_trace = count
	for child in _trace_marks.get_children():
		_trace_marks.remove_child(child)
		child.queue_free()
	if count >= 2:
		_ribbon_on_skin(_trace_marks, op.trace, 0.005, Color("#B23A3A"), 0.005)


func _show_stitches(op: OperationTask) -> void:
	if op.stitches.size() == _shown_stitches:
		return
	_shown_stitches = op.stitches.size()
	for child in _stitches.get_children():
		_stitches.remove_child(child)
		child.queue_free()
	for entry in op.stitches:
		var t := float(entry["t"])
		var along := op.guide_direction(t)
		var mark := LowPoly.joint(_stitches, "Stitch", skin_local(op.guide_point(t), 0.004), Vector3(0, -atan2(along.y, along.x), 0))
		LowPoly.put(mark, LowPoly.box(Vector3(0.004, 0.003, 0.026), SUTURE), Vector3.ZERO)
		LowPoly.put(mark, LowPoly.sphere(0.004, SUTURE, 5, 3), Vector3(0, 0.002, -0.013))


## The right hand goes where the work is, holding what Tom handed over, the
## tip of the instrument on the spot. The left hand steadies nearby.
func _show_hands(op: OperationTask, delta: float) -> void:
	if op.in_hand != _held_name:
		_held_name = op.in_hand
		if _held != null:
			_held.queue_free()
			_held = null
		if not _held_name.is_empty():
			_held = Instruments.make(_held_name)
			_held.scale = Vector3.ONE * 1.3
			(_hand["R"] as Node3D).add_child(_held)
			_held.position = Vector3(-0.01, -0.012, -0.11)
			_held.rotation = Vector3(0.2, 0, 0)
	var goal := RIGHT_REST
	var lift := 0.03
	var steady := LEFT_REST
	if op.phase == "act" or op.phase == "beat" or op.phase == "search":
		match op.step:
			"incision":
				goal = op.trace[op.trace.size() - 1] if op.tracing and not op.trace.is_empty() else op.guide_point(0.0)
				lift = 0.002
				steady = op.guide_point(0.5) + Vector2(-3.2, 1.4)
			"retract", "burst":
				goal = Vector2(14.6, 11.2)
				lift = 0.01
				steady = Vector2(11.2, 11.6)
			"find", "clamp", "cut", "bleeding":
				goal = TARGETS.get(op.target, WORK_CENTRE)
				lift = 0.01
				steady = Vector2(10.6, 11.8)
	if op.id != "appendix" and op.phase in ["act", "beat", "search"] and op.step != "incision":
		var centre: Vector2 = op.procedure.get("wound_centre", WORK_CENTRE)
		match op.action:
			"tap":
				goal = op.targets.get(op.target, centre)
				lift = 0.012
				steady = centre + Vector2(-2.6, 2.0)
			"hold", "fill":
				goal = centre + Vector2(1.4, 1.6)
				lift = 0.01
				steady = centre + Vector2(-1.8, 2.0)
			"close":
				var next := clampf(0.08 + 0.84 * op.stitches.size() / 5.0, 0.0, 1.0)
				goal = op.guide_point(next) + Vector2(0.3, 0.1)
				lift = 0.004
				steady = op.guide_point(next) + Vector2(-2.6, 0.8)
	_move_hand("R", goal, lift, delta)
	_move_hand("L", steady, 0.02, delta)


func _move_hand(side: String, spot: Vector2, lift: float, delta: float) -> void:
	var hand: Node3D = _hand[side]
	var goal := skin_local(spot, lift) - hand.basis * _tip_in_hand(side)
	hand.position = hand.position.lerp(goal, minf(1.0, delta * 8.0)) if delta > 0.0 else goal


func _ribbon_on_skin(parent: Node3D, points: PackedVector2Array, width: float, colour: Color, lift: float) -> void:
	var line := PackedVector2Array()
	for point in points:
		var local := skin_local(point, 0.0)
		line.append(Vector2(local.x, -local.z))
	var strip := LowPoly.ribbon(line, width, colour)
	LowPoly.put(parent, strip, Vector3(0, SKIN_Y + lift, 0), Vector3(-PI / 2, 0, 0))


func _place_on_skin(node: Node3D, spot: Vector2, lift: float) -> void:
	node.position = skin_local(spot, lift)


# --- Any other operation ----------------------------------------------------

const BOWEL_COLOURS := {"pink": Color("#E8A4A0"), "dusky": Color("#8E5A86"), "dead": Color("#3D4A2E")}


## Swaps the appendix's parts for the operation's own, or back again.
func _build_generic() -> void:
	if _generic != null:
		remove_child(_generic)
		_generic.queue_free()
		_generic = null
	_generic_parts.clear()
	var generic := _generic_on()
	for node in _appendix_nodes:
		node.visible = false
	if not generic:
		_rebuild_line(OperationTask.new())
		return
	_rebuild_line(_op)
	_generic = LowPoly.joint(self, "Parts", Vector3.ZERO)
	var shown: Array[Dictionary] = _op.parts.duplicate()
	var centre: Vector2 = _op.procedure.get("wound_centre", WORK_CENTRE)
	if _op.targets.has("bleeder"):
		shown.append({"id": "bleed", "kind": "bleed", "at": _op.targets["bleeder"], "show": "comp:bleeding"})
	shown.append({"id": "bile", "kind": "disc", "at": centre + Vector2(0.8, -0.4), "size": Vector2(0.04, 0.028),
		"colour": Color("#7C8A2C"), "show": "comp:bile", "lift": 0.013})
	shown.append({"id": "swab", "kind": "swab", "at": centre + Vector2(1.2, 0.5), "show": "phase:search"})
	_op.targets["swab"] = centre + Vector2(1.2, 0.5)
	for part in shown:
		var node := _make_part(part)
		if node != null:
			_generic.add_child(node)
			_generic_parts[str(part["id"])] = {"node": node, "part": part}


## The dotted line and the cut for this operation's guide.
func _rebuild_line(op: OperationTask) -> void:
	for node: Node3D in [_guide_line, _cut]:
		for child in node.get_children():
			node.remove_child(child)
			child.queue_free()
	var guide := op.guide()
	for index in range(0, guide.size(), 3):
		var dot := LowPoly.cylinder(0.0028, 0.0028, 0.002, 6, Color("#4B2F86"))
		LowPoly.put(_guide_line, dot, skin_local(guide[index], 0.002))
	_ribbon_on_skin(_cut, guide, 0.006, WOUND, 0.004)


func _part_colour(part: Dictionary) -> Color:
	var colour: Variant = part.get("colour", Color.WHITE)
	if colour is String and str(colour) == "bowel":
		return BOWEL_COLOURS.get(str(_op.variants.get("bowel", "pink")), BOWEL_COLOURS["pink"])
	return colour as Color


func _make_part(part: Dictionary) -> Node3D:
	var kind := str(part.get("kind", "blob"))
	var colour := _part_colour(part)
	var size: Vector2 = part.get("size", Vector2(0.01, 0.0))
	var lift := float(part.get("lift", 0.012))
	var root := Node3D.new()
	root.name = str(part["id"]).to_pascal_case()
	var at_value: Variant = part.get("at", Vector2.ZERO)
	var at: Vector2 = at_value if at_value is Vector2 else Vector2.ZERO
	var angle := 0.0
	if bool(part.get("angle", false)):
		var along := _op.guide()[_op.guide().size() - 1] - _op.guide()[0]
		angle = -atan2(along.y, along.x)
	match kind:
		"disc":
			root.position = skin_local(at, lift)
			root.rotation.y = angle
			LowPoly.put(root, LowPoly.cylinder(size.x, size.x, 0.004, 16, colour), Vector3.ZERO, Vector3.ZERO,
				Vector3(1.0, 1.0, size.y / maxf(0.0001, size.x)))
		"scope":
			# The camera's round picture: black all round it, like a screen.
			root.position = skin_local(at, 0.006)
			LowPoly.put(root, LowPoly.torus(size.x, size.x + 0.26, colour, 32, 4), Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.05, 0.86))
		"dots":
			var points: Array[Vector2] = []
			if str(part.get("at", "")) == "edges" or part.has("points"):
				for key: String in part.get("points", ["edge_a", "edge_b"]):
					points.append(_op.targets.get(key, at))
			else:
				for index in 7:
					points.append(at + Vector2(cos(index * 2.4) * (0.6 + 0.3 * (index % 3)), sin(index * 2.4) * 0.5))
			for point in points:
				LowPoly.put(root, LowPoly.cylinder(0.004, 0.004, 0.003, 6, colour), skin_local(point, lift))
		"tube":
			var from: Vector2 = part.get("from", at - Vector2(cos(-angle), sin(-angle)) * size.y / SCALE / 2.0)
			var to: Vector2 = part.get("to", at + Vector2(cos(-angle), sin(-angle)) * size.y / SCALE / 2.0)
			var length := from.distance_to(to)
			var count := maxi(3, int(length / maxf(0.08, size.x / SCALE * 1.1)))
			for index in count + 1:
				var t := float(index) / count
				LowPoly.put(root, LowPoly.sphere(size.x, colour, 6, 4), skin_local(from.lerp(to, t), lift))
		"blob", "sack":
			root.position = skin_local(at, lift)
			var flat := size.y if size.y > 0.0 else 0.6
			LowPoly.put(root, LowPoly.sphere(size.x, colour, 9, 6), Vector3.ZERO, Vector3.ZERO, Vector3(1.0, flat, 0.8))
			if kind == "sack":
				LowPoly.put(root, LowPoly.torus(size.x * 0.7, size.x * 0.95, colour.darkened(0.2), 12, 3), Vector3(0, size.x * 0.4, 0))
		"pear":
			var neck: Vector2 = part.get("to", at)
			root.position = skin_local(at, lift)
			LowPoly.put(root, LowPoly.sphere(size.x, colour, 9, 6), Vector3.ZERO, Vector3.ZERO, Vector3(1.2, 0.6, 0.9))
			for index in 3:
				var t := (index + 1) / 3.5
				var point := skin_local(at.lerp(neck, t), lift) - root.position
				LowPoly.put(root, LowPoly.sphere(size.x * (0.75 - 0.15 * index), colour.darkened(0.05 * index), 7, 5), point,
					Vector3.ZERO, Vector3(1.0, 0.6, 1.0))
		"sliver":
			root.position = skin_local(at, lift)
			root.rotation.y = 0.7 + at.x
			var piece := LowPoly.box(Vector3(size.x, 0.002, size.y), colour)
			if bool(part.get("glow", false)):
				piece.material_override = LowPoly.glow(colour, 1.6)
			LowPoly.put(root, piece, Vector3.ZERO)
		"ring":
			root.position = skin_local(at, lift)
			LowPoly.put(root, LowPoly.torus(size.x, size.y, colour, 12, 5), Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.6, 1.0))
		"clips":
			root.position = skin_local(at, lift + 0.004)
			for side: int in [-1, 1]:
				LowPoly.put(root, LowPoly.box(Vector3(0.012, 0.003, 0.003), colour), Vector3(0, 0, 0.006 * side), Vector3(0, 0.6, 0))
		"mark":
			root.position = skin_local(at, lift + 0.004)
			var mark := LowPoly.torus(0.004, 0.006, colour, 10, 3)
			mark.material_override = LowPoly.glow(colour, 0.8)
			LowPoly.put(root, mark, Vector3.ZERO)
		"ports":
			for key: String in part.get("points", []):
				LowPoly.put(root, LowPoly.cylinder(0.009, 0.009, 0.012, 8, colour), skin_local(_op.targets.get(key, at), 0.006))
				LowPoly.put(root, LowPoly.cylinder(0.005, 0.005, 0.014, 8, Color("#4FA0D8")), skin_local(_op.targets.get(key, at), 0.008))
		"marks":
			for key: String in part.get("points", []):
				LowPoly.put(root, LowPoly.torus(0.009, 0.013, colour, 12, 3), skin_local(_op.targets.get(key, at), 0.002))
				LowPoly.put(root, LowPoly.cylinder(0.003, 0.003, 0.002, 6, colour), skin_local(_op.targets.get(key, at), 0.002))
		"bleed":
			root.position = skin_local(at, 0.0)
			LowPoly.put(root, LowPoly.cylinder(0.04, 0.04, 0.006, 12, BLOOD), Vector3(0, 0.012, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.7))
			var spurt := LowPoly.sphere(0.008, Color("#D22B2B"), 6, 4)
			spurt.name = "Spurt"
			spurt.material_override = LowPoly.glow(Color("#D22B2B"), 0.6)
			LowPoly.put(root, spurt, Vector3(0, 0.024, 0))
		"swab":
			root.position = skin_local(at, 0.012)
			LowPoly.put(root, LowPoly.box(Vector3(0.026, 0.008, 0.02), Color("#F4F4F0")), Vector3.ZERO, Vector3(0, 0.4, 0.2))
			LowPoly.put(root, LowPoly.box(Vector3(0.026, 0.004, 0.004), Color("#4FA0D8")), Vector3(0, 0.0045, 0.004), Vector3(0, 0.4, 0.2))
		_:
			return null
	root.visible = false
	return root


func _show_generic(op: OperationTask, delta: float) -> void:
	var has_trace := false
	var trace_step := ""
	for entry: Dictionary in op.procedure["steps"]:
		if str(entry.get("act", "")) == "trace":
			has_trace = true
			trace_step = str(entry["id"])
	var keyhole := bool(op.procedure.get("keyhole", false))
	var closing := op.is_closing()
	var opened := op.is_open()
	_guide_line.visible = has_trace and trace_step not in op.done_steps
	if keyhole:
		_cut.visible = closing
	elif has_trace:
		_cut.visible = trace_step in op.done_steps and (not opened or closing)
	else:
		_cut.visible = not opened or closing
	for id: String in _generic_parts:
		var entry: Dictionary = _generic_parts[id]
		var node: Node3D = entry["node"]
		var part: Dictionary = entry["part"]
		node.visible = op.condition_met(str(part.get("show", "")))
		if not node.visible:
			continue
		if part.has("lifted"):
			node.position.y = skin_local(Vector2.ZERO, float(part.get("lift", 0.012))).y + (0.01 if op.condition_met(str(part["lifted"])) else 0.0)
		if bool(part.get("pulse", false)):
			node.scale = Vector3.ONE * (1.0 + 0.12 * absf(sin(_clock * 6.0)))
		if str(part.get("kind", "")) == "bleed":
			node.scale = Vector3.ONE * (1.0 + 0.25 * sin(_clock * 7.0))
			var spurt := node.get_node_or_null("Spurt") as Node3D
			if spurt != null:
				spurt.position.y = 0.024 + 0.015 * absf(sin(_clock * 7.0))
		if str(part.get("colour", "")) == "bowel":
			for child in node.get_children():
				LabStation.set_colour(child as MeshInstance3D, _part_colour(part))
	_show_trace(op)
	_show_stitches(op)
	_show_hands(op, delta)
	if _monitor_light != null:
		var alarm := not op.active_complication.is_empty() or op.stability < 50.0
		_monitor_light.visible = alarm and fmod(_clock, 0.6) < 0.35
