class_name HospitalFront
extends Node3D
## Riverside City Hospital from the street at dusk, behind the title screen.
## The building sits on the right so the menu has room on the left.

const WALL := Color("#E6EEF0")
const WALL_SIDE := Color("#AFC2C7")
const TEAL := Color("#127C80")
const WINDOW_LIT := Color("#F8D27A")
const WINDOW_DARK := Color("#5E7F88")

var _camera: Camera3D
var _clock := 0.0
var _walker: AvatarRig


func _ready() -> void:
	StageLighting.add_dusk(self)
	_build_ground()
	_build_building()
	_build_ambulance(Vector3(5.6, 0, 3.2))
	for spot in [Vector3(-1.4, 0, -1.2), Vector3(-0.4, 0, -2.2), Vector3(10.6, 0, -0.6), Vector3(-3.0, 0, 1.0)]:
		_tree(spot, 1.0 + fmod(spot.x * 7.3, 0.5))
	_build_people()
	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.fov = 40
	add_child(_camera)
	_place_camera(0.0)


func _build_ground() -> void:
	LowPoly.put(self, LowPoly.box(Vector3(60, 0.2, 40), Color("#2F6B5E")), Vector3(0, -0.1, 0))
	LowPoly.put(self, LowPoly.box(Vector3(60, 0.02, 3.4), Color("#34464D")), Vector3(0, 0.01, 5.2))
	for index in 12:
		LowPoly.put(self, LowPoly.box(Vector3(1.4, 0.025, 0.14), Color("#C9D2C8")), Vector3(-14 + index * 3.0, 0.02, 5.2))
	LowPoly.put(self, LowPoly.box(Vector3(14, 0.03, 2.4), Color("#9AA9A6")), Vector3(4.5, 0.015, 2.4))
	LowPoly.put(self, LowPoly.box(Vector3(2.6, 0.04, 2.6), Color("#B7C2BF")), Vector3(4.5, 0.02, 0.9))


func _build_building() -> void:
	var building := LowPoly.joint(self, "Hospital", Vector3(4.5, 0, -2.0))
	LowPoly.put(building, LowPoly.box(Vector3(9.0, 5.6, 4.0), WALL), Vector3(0, 2.8, 0))
	LowPoly.put(building, LowPoly.box(Vector3(9.3, 0.3, 4.3), Color("#F2F6F7")), Vector3(0, 5.75, 0))
	LowPoly.put(building, LowPoly.box(Vector3(3.6, 1.0, 3.0), WALL_SIDE), Vector3(-5.6, 0.5, 0.3))
	# Windows: a grid, most lit for the night shift.
	var lit := [1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 0]
	for row in 3:
		for column in 6:
			var on: bool = lit[row * 6 + column] == 1
			var colour := WINDOW_LIT if on else WINDOW_DARK
			var pane := LowPoly.box(Vector3(0.9, 0.75, 0.06), colour)
			if on:
				pane.material_override = LowPoly.glow(WINDOW_LIT, 0.9)
			LowPoly.put(building, pane, Vector3(-3.4 + column * 1.36, 4.5 - row * 1.25, 2.02))
	# Sign board with a cross and the hospital's name.
	LowPoly.put(building, LowPoly.box(Vector3(4.6, 0.9, 0.14), TEAL), Vector3(0, 6.45, 1.6))
	var cross := LowPoly.joint(building, "Cross", Vector3(-1.75, 6.45, 1.69))
	LowPoly.put(cross, LowPoly.cylinder(0.36, 0.36, 0.05, 12, Color.WHITE), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	LowPoly.put(cross, LowPoly.box(Vector3(0.12, 0.42, 0.04), TEAL), Vector3(0, 0, 0.03))
	LowPoly.put(cross, LowPoly.box(Vector3(0.42, 0.12, 0.04), TEAL), Vector3(0, 0, 0.03))
	var sign := Label3D.new()
	sign.text = "RIVERSIDE CITY"
	sign.font = UiKit.heading_font()
	sign.font_size = 96
	sign.pixel_size = 0.0042
	sign.outline_size = 0
	sign.modulate = Color.WHITE
	sign.position = Vector3(0.35, 6.45, 1.7)
	building.add_child(sign)
	# Entrance: a canopy and glowing doors.
	LowPoly.put(building, LowPoly.box(Vector3(2.6, 0.16, 1.4), TEAL), Vector3(0, 1.95, 2.6))
	for side: int in [-1, 1]:
		LowPoly.put(building, LowPoly.box(Vector3(0.1, 1.9, 0.1), Color("#DCE6E8")), Vector3(1.15 * side, 0.95, 3.2))
	var doors := LowPoly.box(Vector3(1.6, 1.8, 0.06), Color("#8FE3D2"))
	doors.material_override = LowPoly.glow(Color("#8FE3D2"), 0.6)
	LowPoly.put(building, doors, Vector3(0, 0.9, 2.03))
	LowPoly.put(building, LowPoly.box(Vector3(0.05, 1.8, 0.08), Color("#5FB7A6")), Vector3(0, 0.9, 2.06))
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("#FFD9A0")
	lamp.light_energy = 1.2
	lamp.omni_range = 4.5
	lamp.position = Vector3(0, 1.7, 3.0)
	building.add_child(lamp)


func _build_ambulance(at: Vector3) -> void:
	var van := LowPoly.joint(self, "Ambulance", at, Vector3(0, -0.35, 0))
	LowPoly.put(van, LowPoly.box(Vector3(2.4, 1.2, 1.2), Color("#F4F7F7")), Vector3(0, 0.95, 0))
	LowPoly.put(van, LowPoly.box(Vector3(0.8, 0.85, 1.16), Color("#E3EAEB")), Vector3(1.55, 0.78, 0))
	LowPoly.put(van, LowPoly.box(Vector3(0.5, 0.4, 1.18), Color("#37505A")), Vector3(1.62, 1.0, 0))
	LowPoly.put(van, LowPoly.box(Vector3(2.42, 0.18, 1.22), TEAL), Vector3(0, 0.9, 0))
	var light_bar := LowPoly.box(Vector3(0.5, 0.14, 0.7), Color("#F07C5A"))
	light_bar.material_override = LowPoly.glow(Color("#F07C5A"), 1.4)
	LowPoly.put(van, light_bar, Vector3(0.6, 1.62, 0))
	for x in [-0.75, 1.45]:
		for z in [-0.6, 0.6]:
			LowPoly.put(van, LowPoly.cylinder(0.26, 0.26, 0.2, 8, Color("#1E2A2E")), Vector3(x, 0.26, z),
				Vector3(PI / 2, 0, 0))
	LowPoly.put(van, LowPoly.shadow_blob(1.5, Vector2(1.0, 0.55)), Vector3.ZERO)


func _tree(at: Vector3, height: float) -> void:
	var tree := LowPoly.joint(self, "Tree", at)
	LowPoly.put(tree, LowPoly.cylinder(0.08, 0.1, 0.5, 5, Color("#5B4636")), Vector3(0, 0.25, 0))
	LowPoly.put(tree, LowPoly.cylinder(0.0, 0.55, 1.4 * height, 6, Color("#2E7D62")), Vector3(0, 0.5 + 0.7 * height, 0))
	LowPoly.put(tree, LowPoly.cylinder(0.0, 0.42, 1.0 * height, 6, Color("#3A8F70")), Vector3(0, 1.2 + 0.5 * height, 0))
	LowPoly.put(tree, LowPoly.shadow_blob(0.6), Vector3.ZERO)


func _build_people() -> void:
	var rng := SeededRandom.new(11)
	var look := AvatarConfig.random(rng)
	look.coat = true
	_walker = AvatarRig.new(look)
	_walker.name = "Walker"
	_walker.moving = 1.0
	add_child(_walker)
	var nurse_look := AvatarConfig.random(rng)
	nurse_look.coat = false
	nurse_look.scrubs = 4
	var nurse := AvatarRig.new(nurse_look)
	nurse.name = "Nurse"
	nurse.position = Vector3(5.6, 0, 1.15)
	nurse.rotation.y = 0.6
	add_child(nurse)


func _place_camera(sway: float) -> void:
	_camera.look_at_from_position(Vector3(-2.6 + sway, 2.2, 15.5), Vector3(1.2 + sway * 0.4, 3.0, 0.0))


func _process(delta: float) -> void:
	_clock += delta
	_place_camera(sin(_clock * 0.25) * 0.35)
	if _walker != null:
		# A doctor strolls along the path to the entrance and back.
		var t := fmod(_clock * 0.12, 2.0)
		var going := t < 1.0
		var x := lerpf(1.0, 3.9, t if going else 2.0 - t)
		_walker.position = Vector3(x, 0, 2.4)
		_walker.rotation.y = PI / 2 if going else -PI / 2
