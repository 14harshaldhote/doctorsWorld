class_name ScrubSink
extends LabStation
## Scrub in: a theatre sink with a tap, soap, sterile towels, a gown and a
## box of gloves, and the doctor's own hands over the basin in close-up.
## The hands get wet, foam up, rub while an area is scrubbed, dry off, go
## into gown sleeves and finally into gloves.

const GOWN := Color("#6E9FD1")
const GLOVE := Color("#E7D3A2")
const FOAM := Color("#FBFDFD")
const WATER := Color("#BFE7F0")

var look: AvatarConfig
## The area being scrubbed now ("" when not scrubbing): set by the screen.
var scrubbing := ""
var hands: Node3D
var _hand := {}
var _skin: Array[MeshInstance3D] = []
var _sleeves: Array[MeshInstance3D] = []
var _foam: Array[Node3D] = []
var _drips: Array[Node3D] = []
var _water: Node3D
var _towel: Node3D
var _clock := 0.0
var _rub := 0.0


func _init(for_look: AvatarConfig = null) -> void:
	id = "scrub"
	name = "ScrubSink"
	look = for_look if for_look != null else AvatarConfig.new()
	trainer_spot = Vector3(-1.05, 0, 0.5)
	close_from = Vector3(0.0, 1.66, 0.7)
	close_at = Vector3(0.02, 1.02, -0.16)
	close_offset = 0.0
	tag_point = Vector3(0, 1.45, 0.1)
	footprints = [Rect2(-0.8, -0.6, 1.95, 0.9)]


func _build() -> void:
	# Cabinet, steel trough and a tiled splashback.
	LowPoly.put(self, LowPoly.box(Vector3(1.3, 0.86, 0.6), WHITE), Vector3(0, 0.43, -0.25))
	LowPoly.put(self, LowPoly.box(Vector3(1.32, 0.06, 0.62), TEAL), Vector3(0, 0.03, -0.25))
	LowPoly.put(self, LowPoly.box(Vector3(1.3, 0.22, 0.62), STEEL), Vector3(0, 0.97, -0.25))
	LowPoly.put(self, LowPoly.box(Vector3(1.16, 0.04, 0.46), STEEL_DARK), Vector3(0, 1.0, -0.23))
	LowPoly.put(self, LowPoly.box(Vector3(1.4, 1.0, 0.06), Color("#DDEFEE")), Vector3(0, 1.5, -0.55))
	for row in 4:
		for column in 6:
			if (row + column) % 2 == 0:
				LowPoly.put(self, LowPoly.box(Vector3(0.22, 0.22, 0.01), Color("#C7E6E3")),
					Vector3(-0.575 + column * 0.23, 1.12 + row * 0.23, -0.515))
	# A gooseneck tap worked by the elbow.
	LowPoly.put(self, LowPoly.cylinder(0.02, 0.02, 0.36, 6, STEEL_DARK), Vector3(0, 1.26, -0.44))
	LowPoly.put(self, LowPoly.cylinder(0.016, 0.016, 0.3, 6, STEEL_DARK), Vector3(0, 1.43, -0.3), Vector3(PI / 2, 0, 0))
	LowPoly.put(self, LowPoly.cylinder(0.018, 0.012, 0.07, 6, STEEL_DARK), Vector3(0, 1.4, -0.16))
	LowPoly.put(self, LowPoly.box(Vector3(0.24, 0.025, 0.03), STEEL), Vector3(0.12, 1.26, -0.44), Vector3(0, 0, -0.3))
	_water = LowPoly.joint(self, "Water", Vector3(0, 1.2, -0.16))
	var stream := LowPoly.cylinder(0.011, 0.016, 0.36, 6, WATER)
	stream.material_override = LowPoly.glow(WATER, 0.6)
	LowPoly.put(_water, stream, Vector3.ZERO)
	_water.visible = false
	# Soap and a brush tray on the splashback.
	var soap := LowPoly.joint(self, "Soap", Vector3(-0.48, 1.32, -0.48))
	LowPoly.put(soap, LowPoly.box(Vector3(0.12, 0.2, 0.08), WHITE), Vector3.ZERO)
	LowPoly.put(soap, LowPoly.box(Vector3(0.08, 0.06, 0.02), Color("#F07C5A")), Vector3(0, 0.03, 0.045))
	LowPoly.put(soap, LowPoly.box(Vector3(0.03, 0.04, 0.06), STEEL_DARK), Vector3(0, -0.12, 0.02))
	var poster := label3d("HANDS UP.\nWATER DOWN.", 44, TEAL, 0.0035)
	poster.position = Vector3(0.38, 1.82, -0.51)
	add_child(poster)
	# A side trolley: sterile towels, a folded gown, a box of gloves.
	var side := LowPoly.joint(self, "Side", Vector3(0.92, 0, -0.18))
	table(side, Vector3(0.5, 0.88, 0.5))
	for index in 3:
		LowPoly.put(side, LowPoly.box(Vector3(0.18, 0.025, 0.16), Color("#3E8E7A").lightened(index * 0.06)),
			Vector3(-0.1, 0.9 + index * 0.026, -0.1))
	LowPoly.put(side, LowPoly.box(Vector3(0.22, 0.07, 0.18), GOWN), Vector3(0.08, 0.93, 0.08))
	LowPoly.put(side, LowPoly.box(Vector3(0.16, 0.08, 0.1), WHITE), Vector3(-0.1, 0.94, 0.13))
	LowPoly.put(side, LowPoly.box(Vector3(0.1, 0.03, 0.005), Color("#4FA0D8")), Vector3(-0.1, 0.95, 0.183))
	_towel = LowPoly.joint(self, "Towel", Vector3(0, 1.06, 0.06))
	LowPoly.put(_towel, LowPoly.box(Vector3(0.3, 0.012, 0.2), Color("#3E8E7A")), Vector3.ZERO, Vector3(0.3, 0, 0))
	_towel.visible = false
	_build_hands()
	LowPoly.put(self, LowPoly.shadow_blob(0.8, Vector2(1.0, 0.45)), Vector3(0, 0, -0.25))


## The doctor's forearms and hands, held fingertips up over the basin.
func _build_hands() -> void:
	hands = LowPoly.joint(self, "Hands", Vector3(0, 1.08, 0.02))
	var skin := look.skin_colour()
	var scrubs := look.scrubs_colour()
	for side: String in ["L", "R"]:
		var mirror := -1.0 if side == "L" else 1.0
		var wrist := LowPoly.joint(hands, "Hand" + side, Vector3(0.075 * mirror, 0, 0), Vector3(-0.55, -0.35 * mirror, 0.22 * mirror))
		_hand[side] = wrist
		var palm := LowPoly.box(Vector3(0.078, 0.085, 0.026), skin)
		LowPoly.put(wrist, palm, Vector3(0, 0.05, 0))
		_skin.append(palm)
		for finger in 4:
			var height := [0.05, 0.058, 0.055, 0.044][finger] as float
			var part := LowPoly.box(Vector3(0.015, height, 0.017), skin)
			LowPoly.put(wrist, part, Vector3((-0.027 + finger * 0.018) * mirror, 0.093 + height / 2.0, 0))
			_skin.append(part)
		var thumb := LowPoly.box(Vector3(0.018, 0.05, 0.019), skin)
		LowPoly.put(wrist, thumb, Vector3(-0.05 * mirror, 0.045, 0.01), Vector3(0, 0, 0.6 * mirror))
		_skin.append(thumb)
		var arm := LowPoly.cylinder(0.031, 0.036, 0.26, 7, skin)
		LowPoly.put(wrist, arm, Vector3(0, -0.12, 0))
		_skin.append(arm)
		var sleeve := LowPoly.cylinder(0.045, 0.048, 0.12, 7, scrubs)
		LowPoly.put(wrist, sleeve, Vector3(0, -0.22, 0))
		_sleeves.append(sleeve)
	# Foam, hidden until the soap.
	var rng := SeededRandom.new(5)
	for index in 14:
		var bubble := LowPoly.sphere(0.012 + rng.next_float() * 0.012, FOAM, 6, 4)
		var side := -1.0 if index % 2 == 0 else 1.0
		var at := Vector3(side * (0.05 + rng.next_float() * 0.06), -0.04 + rng.next_float() * 0.15,
			0.012 + rng.next_float() * 0.02)
		LowPoly.put(hands, bubble, at)
		bubble.visible = false
		_foam.append(bubble)
	for index in 4:
		var drip := LowPoly.sphere(0.006, WATER, 5, 3)
		drip.material_override = LowPoly.glow(WATER, 0.5)
		LowPoly.put(hands, drip, Vector3(-0.09 + index * 0.06, -0.18, 0.02))
		drip.visible = false
		_drips.append(drip)


func reset_task(_task: TrainingTask) -> void:
	scrubbing = ""
	_rub = 0.0
	_clock = 0.0


func show_task(task: TrainingTask, delta: float) -> void:
	var scrub := task as ScrubTask
	if scrub == null:
		return
	_clock += delta
	var stage := scrub.stage
	_water.visible = stage >= 1 and stage < 4
	_towel.visible = stage == 5
	var soaped := stage == 2
	var amount := float(scrub.areas_done()) / ScrubTask.AREAS.size()
	for index in _foam.size():
		var bubble := _foam[index]
		bubble.visible = soaped and index < 6 + int(amount * 8)
		bubble.scale = Vector3.ONE * (0.8 + 0.3 * amount + 0.1 * sin(_clock * 6.0 + index))
	var wet := stage >= 1 and stage < 5
	for index in _drips.size():
		var drip := _drips[index]
		drip.visible = wet
		drip.position.y = -0.18 - fposmod(_clock * 0.5 + index * 0.27, 0.6) * 0.3
	var sleeve_colour := GOWN if stage >= 6 else look.scrubs_colour()
	for sleeve in _sleeves:
		set_colour(sleeve, sleeve_colour)
		sleeve.scale = Vector3(1, 2.2, 1) if stage >= 6 else Vector3.ONE
		sleeve.position.y = -0.16 if stage >= 6 else -0.22
	var hand_colour := GLOVE if stage >= 7 else look.skin_colour()
	for part in _skin:
		set_colour(part, hand_colour)
	# Rub the hands together while an area is held.
	var target := 1.0 if not scrubbing.is_empty() and soaped else 0.0
	_rub = move_toward(_rub, target, delta * 6.0)
	var swing := sin(_clock * 15.0) * 0.022 * _rub
	(_hand["L"] as Node3D).position = Vector3(-0.075 + 0.03 * _rub + swing, 0.01 * sin(_clock * 15.0) * _rub, 0)
	(_hand["R"] as Node3D).position = Vector3(0.075 - 0.03 * _rub - swing, 0, 0)
