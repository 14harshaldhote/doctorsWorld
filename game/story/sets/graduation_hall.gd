class_name GraduationHall
extends StorySet
## Convocation day: a hall with a stage, curtains and a banner, the dean at
## the centre, graduates waiting in gowns, and the audience. Your family
## stands up in the back rows when your name is called.
##
## The stage runs across the back (z from -5.7 to -1.5, top at y = 0.9) and
## the audience faces it from the front (+z).

const STAGE_TOP := 0.9
const WOOD := Color("#6A4A33")
const CURTAIN := Color("#5A2742")
const WALL := Color("#2F2545")
const GOLD := Color("#C9A15A")

var _crowd: Array[Node3D] = []
var _clapping := 0.0
var _clock := 0.0


func _ready() -> void:
	StageLighting.add_to(self, WALL, Vector3(-38, 18, 0), 0.75, Color("#C7B8DA"), 0.5, Color("#FFE7C4"))
	# Light from the stage falls on the audience's faces.
	var house := DirectionalLight3D.new()
	house.name = "HouseLight"
	house.rotation_degrees = Vector3(-30, 200, 0)
	house.light_color = Color("#FFE2C0")
	house.light_energy = 0.55
	add_child(house)
	marks = {
		"stage_left": Vector3(-4.0, STAGE_TOP, -3.3),
		"dean_front": Vector3(-0.45, STAGE_TOP, -3.3),
		"audience": Vector3(-0.45, STAGE_TOP, 6.0),
	}
	_build_hall()
	_build_stage()
	_build_audience()
	_build_people()
	shots = {
		"wide": {"from": Vector3(0, 2.7, 10.5), "at": Vector3(0, 1.75, -3.2), "to_from": Vector3(0, 2.35, 7.8),
			"time": 11.0, "fov": 42.0},
		"stage": {"from": Vector3(-1.2, 2.3, 4.4), "at": Vector3(-1.4, 2.25, -3.3), "to_from": Vector3(-0.7, 2.25, 3.6),
			"time": 7.0, "fov": 40.0},
		"family": {"from": Vector3(-2.75, 1.85, 2.5), "at": Vector3(-3.25, 1.3, 5.9), "fov": 44.0},
		"hero": {"from": Vector3(0.9, 2.2, -0.6), "at": Vector3(-0.45, 2.15, -3.3), "to_from": Vector3(0.7, 2.25, -1.1),
			"time": 4.0, "fov": 38.0},
	}


func _build_hall() -> void:
	LowPoly.put(self, LowPoly.box(Vector3(20, 0.1, 26), Color("#4C3A2C")), Vector3(0, -0.05, 2))
	LowPoly.put(self, LowPoly.box(Vector3(2.2, 0.012, 14), Color("#7A2E3E")), Vector3(0, 0.006, 5.0))
	LowPoly.put(self, LowPoly.box(Vector3(20, 8, 0.3), WALL), Vector3(0, 4, -6.1))
	for side: int in [-1, 1]:
		LowPoly.put(self, LowPoly.box(Vector3(0.3, 8, 26), WALL.darkened(0.12)), Vector3(9.5 * side, 4, 2))
		# Tall windows down the side walls, glowing softly.
		for index in 4:
			var pane := LowPoly.box(Vector3(0.06, 2.6, 1.1), Color("#9C8BC4"))
			pane.material_override = LowPoly.glow(Color("#9C8BC4"), 0.35)
			LowPoly.put(self, pane, Vector3(9.33 * side, 3.6, -0.5 + index * 3.0))


func _build_stage() -> void:
	var stage := LowPoly.joint(self, "Stage", Vector3(0, 0, -3.6))
	LowPoly.put(stage, LowPoly.box(Vector3(13, STAGE_TOP, 4.2), WOOD), Vector3(0, STAGE_TOP / 2.0, 0))
	LowPoly.put(stage, LowPoly.box(Vector3(13.02, 0.12, 0.06), Color("#7E5B40")), Vector3(0, STAGE_TOP - 0.06, 2.11))
	LowPoly.put(stage, LowPoly.box(Vector3(13.04, 0.08, 0.08), GOLD.darkened(0.2)), Vector3(0, 0.04, 2.11))
	# Steps up on the left.
	for step in 3:
		LowPoly.put(stage, LowPoly.box(Vector3(1.2, 0.3 * (step + 1), 0.34), Color("#7E5B40")),
			Vector3(-4.6, 0.15 * (step + 1), 2.6 - step * 0.34))
	# Curtains: folds in two shades, and a valance across the top.
	for side: int in [-1, 1]:
		for fold in 6:
			var shade := CURTAIN if fold % 2 == 0 else CURTAIN.darkened(0.18)
			LowPoly.put(stage, LowPoly.box(Vector3(0.24, 6.2, 0.3), shade), Vector3((6.3 - fold * 0.22) * side, 3.1, 0.9 - fold * 0.05))
	for fold in 26:
		var shade := Color("#6E3152") if fold % 2 == 0 else Color("#5E2846")
		LowPoly.put(stage, LowPoly.box(Vector3(0.52, 1.0, 0.25), shade), Vector3(-6.5 + fold * 0.52, 5.95, 1.6))
	# The banner.
	LowPoly.put(stage, LowPoly.box(Vector3(5.4, 0.8, 0.06), GOLD), Vector3(0, 4.55, -2.0))
	var banner := label3d("CONVOCATION", 120, Color("#2A1A00"))
	banner.position = Vector3(0, 4.57, -1.96)
	stage.add_child(banner)
	var college := label3d("City Medical College", 54, Color("#E9DCC0"))
	college.position = Vector3(0, 3.95, -2.0)
	stage.add_child(college)
	# A lectern with a microphone, and a table of rolled certificates.
	var lectern := LowPoly.joint(stage, "Lectern", Vector3(2.6, STAGE_TOP, 0.4))
	LowPoly.put(lectern, LowPoly.cylinder(0.32, 0.4, 1.1, 6, Color("#7E5B40")), Vector3(0, 0.55, 0))
	LowPoly.put(lectern, LowPoly.box(Vector3(0.75, 0.06, 0.5), Color("#8A6447")), Vector3(0, 1.12, 0), Vector3(0.25, 0, 0))
	LowPoly.put(lectern, LowPoly.cylinder(0.008, 0.008, 0.3, 4, Color("#2B2B2B")), Vector3(-0.1, 1.28, 0.15), Vector3(-0.3, 0, 0))
	LowPoly.put(lectern, LowPoly.sphere(0.03, Color("#2B2B2B"), 6, 4), Vector3(-0.1, 1.42, 0.2))
	LowPoly.put(lectern, LowPoly.cylinder(0.16, 0.14, 0.12, 12, Color("#127C80")), Vector3(0, 0.75, 0.33),
		Vector3(PI / 2, 0, 0))
	var table := LowPoly.joint(stage, "Table", Vector3(1.0, STAGE_TOP, -0.6))
	LowPoly.put(table, LowPoly.box(Vector3(1.4, 0.72, 0.6), Color("#7A2E3E")), Vector3(0, 0.36, 0))
	for index in 6:
		LowPoly.put(table, LowPoly.cylinder(0.024, 0.024, 0.3, 8, Color("#F3EBD6")),
			Vector3(-0.45 + index * 0.18, 0.75, (index % 2) * 0.1 - 0.05), Vector3(0, 0.3, PI / 2))
	# A spotlight on the dean.
	var beam := light_beam(0.25, 1.25, 5.6, Color("#FFF4D6"), 0.07)
	LowPoly.put(stage, beam, Vector3(0.0, STAGE_TOP + 2.8, 0.25))
	var spot := OmniLight3D.new()
	spot.light_color = Color("#FFE2B0")
	spot.light_energy = 1.4
	spot.omni_range = 5.5
	spot.position = Vector3(-0.2, STAGE_TOP + 3.2, 1.2)
	stage.add_child(spot)
	LowPoly.put(stage, LowPoly.cylinder(1.1, 1.1, 0.01, 20, Color("#8A6A4E")), Vector3(0, STAGE_TOP + 0.006, 0.25))


func _build_audience() -> void:
	var rng := SeededRandom.new(2026)
	for row in 5:
		var z := 1.0 + row * 1.2
		for seat in 14:
			var x := -6.3 + seat * 0.9 + (0.9 if seat >= 7 else 0.0)
			if absf(x) < 0.8:
				continue
			var chair := LowPoly.joint(self, "Seat", Vector3(x, 0, z))
			LowPoly.put(chair, LowPoly.box(Vector3(0.7, 0.08, 0.6), Color("#3A3047")), Vector3(0, 0.45, 0))
			LowPoly.put(chair, LowPoly.box(Vector3(0.7, 0.6, 0.07), Color("#2E2639")), Vector3(0, 0.78, 0.28))
			# The family's row and the rows just in front of them stay clear
			# so the camera can see them.
			var family_gap := x > -4.8 and x < -1.7 and row >= 3
			if family_gap or rng.chance(0.12):
				continue
			var figure := crowd_figure(rng)
			figure.rotation.y = PI
			chair.add_child(figure)
			_crowd.append(figure)


func _build_people() -> void:
	var dean_look := AvatarConfig.new()
	dean_look.skin = 4
	dean_look.face = 5
	dean_look.hair_style = 1
	dean_look.hair_colour = 6
	dean_look.facial_hair = 4
	dean_look.glasses = 1
	dean_look.height = 2
	dean_look.body = 2
	var dean_rig := add_actor("dean", dean_look, Vector3(0.35, STAGE_TOP, -3.35), -PI / 2 + 0.35, "gown")
	dean_rig.gown_colour = Color("#6E2338")
	dean_rig.trim_colour = GOLD
	dean_rig.mortarboard = false
	dean_rig.build()
	dean_rig.set_mood(AvatarConfig.Mood.HAPPY)
	var you := add_player(marks["stage_left"], PI / 2, "gown")
	you.set_mood(AvatarConfig.Mood.WORRIED)
	# Classmates waiting their turn.
	var rng := SeededRandom.new(77)
	for index in 2:
		var look := AvatarConfig.random(rng)
		var mate := AvatarRig.new(look)
		mate.name = "Classmate%d" % (index + 1)
		mate.outfit = "gown"
		mate.position = Vector3(-4.85 - index * 0.75, STAGE_TOP, -3.55 - index * 0.2)
		mate.rotation.y = PI / 2
		add_child(mate)
	# Your family in the back rows, standing and facing the stage.
	var family := family_looks(profile.avatar)
	var mum := add_actor("mum", family["mum"], Vector3(-3.3, 0, 5.75), PI, "kurta")
	var dad := add_actor("dad", family["dad"], Vector3(-2.45, 0, 5.8), PI, "casual")
	var anu := add_actor("anu", family["anu"], Vector3(-4.15, 0, 5.7), PI, "casual")
	anu.scale = Vector3.ONE * 0.86
	for rig: AvatarRig in [mum, dad, anu]:
		rig.set_mood(AvatarConfig.Mood.HAPPY)


func cue(cue_name: String) -> float:
	if cue_name == "applause":
		Sfx.play(self, "applause", -4.0)
		_clapping = 3.0
		for id: String in ["mum", "dad"]:
			(actors[id] as AvatarRig).set_gesture("clap")
		(actors["anu"] as AvatarRig).set_gesture("cheer")
		return 1.2
	return 0.0


func _process(delta: float) -> void:
	_clock += delta
	if _clapping > 0.0:
		_clapping -= delta
		# The audience bobs as it claps.
		for index in _crowd.size():
			var figure := _crowd[index]
			figure.position.y = absf(sin(_clock * 9.0 + index * 1.7)) * 0.025 * minf(1.0, _clapping)
		if _clapping <= 0.0:
			for id: String in ["mum", "dad"]:
				var rig: AvatarRig = actors[id]
				if rig.gesture == "clap":
					rig.set_gesture("")
