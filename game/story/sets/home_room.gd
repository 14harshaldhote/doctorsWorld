class_name HomeRoom
extends StorySet
## Home, a few weeks after graduation: a warm living room with morning light
## through the window, chai on the table, Mum at the table, Anu by the sofa.
## Dad comes in from the front door with the letter.

const WALL := Color("#F1E3C8")
const FLOOR := Color("#B07A4A")
const WOOD := Color("#8A5A3A")


func _ready() -> void:
	StageLighting.add_to(self, WALL, Vector3(-42, 35, 0), 0.8, Color("#F2E2CC"), 0.5, Color("#FFE6C4"))
	marks = {
		"door": Vector3(3.0, 0, -2.4),
		"table_side": Vector3(1.55, 0, 0.05),
	}
	_build_room()
	_build_furniture()
	_build_people()
	shots = {
		"room": {"from": Vector3(3.5, 2.05, 5.1), "at": Vector3(-0.2, 1.0, -0.6), "to_from": Vector3(3.0, 1.95, 4.5),
			"time": 8.0, "fov": 44.0},
		"letter": {"from": Vector3(1.85, 1.62, 2.45), "at": Vector3(0.72, 1.42, 0.75), "fov": 36.0},
		"family_table": {"from": Vector3(1.2, 1.75, 4.1), "at": Vector3(-0.75, 1.05, -0.2), "fov": 42.0, "offset": 1.0},
	}


func _build_room() -> void:
	LowPoly.put(self, LowPoly.box(Vector3(9, 0.1, 8), FLOOR), Vector3(0, -0.05, 0.5))
	for index in 9:
		LowPoly.put(self, LowPoly.box(Vector3(0.012, 0.004, 8), FLOOR.darkened(0.12)), Vector3(-4 + index, 0.002, 0.5))
	LowPoly.put(self, LowPoly.box(Vector3(2.8, 0.012, 2.0), Color("#C0603E")), Vector3(-0.1, 0.007, -0.15))
	LowPoly.put(self, LowPoly.box(Vector3(2.5, 0.014, 1.7), Color("#D98A5F")), Vector3(-0.1, 0.009, -0.15))
	LowPoly.put(self, LowPoly.box(Vector3(9, 3.3, 0.2), WALL), Vector3(0, 1.65, -3.1))
	LowPoly.put(self, LowPoly.box(Vector3(9, 0.14, 0.24), Color("#C68C58")), Vector3(0, 0.07, -3.08))
	LowPoly.put(self, LowPoly.box(Vector3(0.2, 3.3, 8), WALL.darkened(0.06)), Vector3(-4.1, 1.65, 0.5))
	LowPoly.put(self, LowPoly.box(Vector3(0.24, 0.14, 8), Color("#C68C58")), Vector3(-4.08, 0.07, 0.5))
	# The window, glowing with morning light, and the light it throws.
	var glass := LowPoly.box(Vector3(1.7, 1.2, 0.04), Color("#CFEAF5"))
	glass.material_override = LowPoly.glow(Color("#CFEAF5"), 0.7)
	LowPoly.put(self, glass, Vector3(0.3, 1.8, -2.99))
	for x in [-0.55, 0.3, 1.15]:
		LowPoly.put(self, LowPoly.box(Vector3(0.07, 1.3, 0.06), Color.WHITE), Vector3(x, 1.8, -2.96))
	for y in [1.2, 1.8, 2.4]:
		LowPoly.put(self, LowPoly.box(Vector3(1.8, 0.07, 0.06), Color.WHITE), Vector3(0.3, y, -2.96))
	var shaft := light_beam(0.85, 1.2, 2.6, Color("#FFF1CF"), 0.1)
	LowPoly.put(self, shaft, Vector3(0.3, 1.0, -2.0), Vector3(-0.75, 0, 0), Vector3(1.0, 1.0, 0.35))
	var sun := OmniLight3D.new()
	sun.light_color = Color("#FFE2B0")
	sun.light_energy = 0.9
	sun.omni_range = 4.5
	sun.position = Vector3(0.3, 1.9, -2.2)
	add_child(sun)
	# The front door.
	var door := LowPoly.joint(self, "Door", Vector3(3.0, 0, -2.99))
	LowPoly.put(door, LowPoly.box(Vector3(1.15, 2.2, 0.06), Color("#E2D0AE")), Vector3(0, 1.1, 0))
	LowPoly.put(door, LowPoly.box(Vector3(0.95, 2.05, 0.06), WOOD), Vector3(0, 1.03, 0.03))
	LowPoly.put(door, LowPoly.sphere(0.04, Color("#C9A15A"), 6, 4), Vector3(0.35, 1.0, 0.08))
	# A wall clock, a calendar and a framed photo.
	LowPoly.put(self, LowPoly.cylinder(0.24, 0.24, 0.04, 14, Color.WHITE), Vector3(-1.9, 2.4, -2.98), Vector3(PI / 2, 0, 0))
	LowPoly.put(self, LowPoly.box(Vector3(0.02, 0.17, 0.02), Color("#2B2B2B")), Vector3(-1.9, 2.46, -2.94))
	LowPoly.put(self, LowPoly.box(Vector3(0.13, 0.02, 0.02), Color("#2B2B2B")), Vector3(-1.85, 2.4, -2.94))
	var calendar := LowPoly.joint(self, "Calendar", Vector3(-3.99, 1.9, -1.0), Vector3(0, PI / 2, 0))
	LowPoly.put(calendar, LowPoly.box(Vector3(0.5, 0.65, 0.02), Color.WHITE), Vector3.ZERO)
	LowPoly.put(calendar, LowPoly.box(Vector3(0.5, 0.14, 0.025), Color("#B3263A")), Vector3(0, 0.26, 0.002))
	var photo := LowPoly.joint(self, "Photo", Vector3(-3.99, 1.75, 1.2), Vector3(0, PI / 2, 0))
	LowPoly.put(photo, LowPoly.box(Vector3(0.7, 0.5, 0.03), Color("#5B4636")), Vector3.ZERO)
	LowPoly.put(photo, LowPoly.box(Vector3(0.6, 0.4, 0.035), Color("#2F2545")), Vector3.ZERO)
	LowPoly.put(photo, LowPoly.box(Vector3(0.12, 0.2, 0.04), Color("#1D1D24")), Vector3(0, -0.06, 0.002))
	LowPoly.put(photo, LowPoly.box(Vector3(0.16, 0.03, 0.045), Color("#1D1D24")), Vector3(0, 0.1, 0.002))


func _build_furniture() -> void:
	var table := LowPoly.joint(self, "Table", Vector3(0, 0, -0.2))
	LowPoly.put(table, LowPoly.box(Vector3(1.8, 0.06, 1.0), WOOD), Vector3(0, 0.76, 0))
	for x in [-0.82, 0.82]:
		for z in [-0.42, 0.42]:
			LowPoly.put(table, LowPoly.box(Vector3(0.07, 0.74, 0.07), WOOD.darkened(0.15)), Vector3(x, 0.37, z))
	for spot: Vector3 in [Vector3(-0.45, 0.83, 0.15), Vector3(0.5, 0.83, -0.2)]:
		LowPoly.put(table, LowPoly.cylinder(0.075, 0.075, 0.012, 10, Color.WHITE), spot - Vector3(0, 0.035, 0))
		LowPoly.put(table, LowPoly.cylinder(0.042, 0.034, 0.08, 8, Color("#F7F4EE")), spot)
		LowPoly.put(table, LowPoly.cylinder(0.036, 0.036, 0.005, 8, Color("#B98552")), spot + Vector3(0, 0.035, 0))
	LowPoly.put(table, LowPoly.cylinder(0.15, 0.13, 0.025, 12, Color.WHITE), Vector3(0.05, 0.8, 0.2))
	for index in 4:
		LowPoly.put(table, LowPoly.cylinder(0.045, 0.045, 0.012, 8, Color("#E2B45A")),
			Vector3(0.0 + index * 0.035, 0.82 + index * 0.012, 0.18 + (index % 2) * 0.03))
	LowPoly.put(table, LowPoly.box(Vector3(0.42, 0.012, 0.3), Color("#F2F0EA")), Vector3(-0.1, 0.795, -0.25), Vector3(0, 0.3, 0))
	LowPoly.put(table, LowPoly.shadow_blob(1.1, Vector2(1.0, 0.6)), Vector3.ZERO)
	_chair(Vector3(-1.25, 0, -0.2), PI / 2)
	_chair(Vector3(0.0, 0, -1.05), 0.0)
	# The sofa by the left wall.
	var sofa := LowPoly.joint(self, "Sofa", Vector3(-3.35, 0, -1.4), Vector3(0, PI / 2, 0))
	var green := Color("#3E8E5A")
	LowPoly.put(sofa, LowPoly.box(Vector3(2.0, 0.42, 0.85), green), Vector3(0, 0.21, 0))
	LowPoly.put(sofa, LowPoly.box(Vector3(2.0, 0.55, 0.22), green.darkened(0.12)), Vector3(0, 0.6, -0.34))
	for side: int in [-1, 1]:
		LowPoly.put(sofa, LowPoly.box(Vector3(0.2, 0.62, 0.85), green.darkened(0.08)), Vector3(0.95 * side, 0.31, 0))
	LowPoly.put(sofa, LowPoly.box(Vector3(0.42, 0.36, 0.14), Color("#F5B841")), Vector3(-0.5, 0.6, -0.18), Vector3(-0.2, 0, 0.1))
	LowPoly.put(sofa, LowPoly.shadow_blob(1.1, Vector2(1.0, 0.45)), Vector3.ZERO)
	# A cabinet with a plant on the right.
	var cabinet := LowPoly.joint(self, "Cabinet", Vector3(3.5, 0, 0.6), Vector3(0, -PI / 2, 0))
	LowPoly.put(cabinet, LowPoly.box(Vector3(1.4, 0.8, 0.45), WOOD), Vector3(0, 0.4, 0))
	LowPoly.put(cabinet, LowPoly.box(Vector3(0.6, 0.6, 0.02), WOOD.lightened(0.12)), Vector3(-0.33, 0.4, 0.23))
	LowPoly.put(cabinet, LowPoly.box(Vector3(0.6, 0.6, 0.02), WOOD.lightened(0.12)), Vector3(0.33, 0.4, 0.23))
	LowPoly.put(cabinet, LowPoly.cylinder(0.14, 0.11, 0.24, 7, Color("#C0603E")), Vector3(0.4, 0.92, 0))
	LowPoly.put(cabinet, LowPoly.sphere(0.22, Color("#3E8E5A"), 6, 4), Vector3(0.4, 1.18, 0))
	LowPoly.put(cabinet, LowPoly.box(Vector3(0.36, 0.3, 0.06), Color("#5B4636")), Vector3(-0.3, 0.95, 0), Vector3(-0.15, 0, 0))


func _chair(at: Vector3, facing: float) -> void:
	var chair := LowPoly.joint(self, "Chair", at, Vector3(0, facing, 0))
	LowPoly.put(chair, LowPoly.box(Vector3(0.5, 0.06, 0.5), WOOD.lightened(0.08)), Vector3(0, 0.45, 0))
	LowPoly.put(chair, LowPoly.box(Vector3(0.5, 0.55, 0.06), WOOD), Vector3(0, 0.75, -0.23))
	for x in [-0.21, 0.21]:
		for z in [-0.21, 0.21]:
			LowPoly.put(chair, LowPoly.box(Vector3(0.05, 0.45, 0.05), WOOD.darkened(0.15)), Vector3(x, 0.22, z))


func _build_people() -> void:
	var family := family_looks(profile.avatar)
	var you := add_player(Vector3(0.75, 0, 0.8), PI - 0.75, "casual")
	you.set_mood(AvatarConfig.Mood.CALM)
	var mum := add_actor("mum", family["mum"], Vector3(-1.2, 0, -0.2), PI / 2, "kurta")
	mum.sitting = true
	mum.set_mood(AvatarConfig.Mood.HAPPY)
	var anu := add_actor("anu", family["anu"], Vector3(-2.15, 0, 0.7), PI / 2 + 0.3, "casual")
	anu.scale = Vector3.ONE * 0.86
	var dad := add_actor("dad", family["dad"], marks["door"], 0.0, "casual")
	dad.hold("letter")
	dad.set_mood(AvatarConfig.Mood.HAPPY)


func cue(cue_name: String) -> float:
	if cue_name == "knock":
		Sfx.play(self, "knock")
		for id: String in ["you", "mum", "anu"]:
			(actors[id] as AvatarRig).look_at_point(marks["door"] + Vector3(0, 1.5, 0))
		return 1.1
	return 0.0
