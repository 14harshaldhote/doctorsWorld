class_name EveningSet
extends StorySet
## The places of an evening off (stage 27): the hospital canteen at night,
## the doctor's hostel room, and the party places (the hostel common room,
## the terrace at Diwali, the nurses' break room, a wedding hall and the
## seminar room). One class builds them all, from small shared pieces.
##
## Every place has the same layout, so conversations stage the same way: the
## doctor stands front right at "you", guests gather at "g1".."g7" round
## the middle facing them, and "door" is where a late arrival walks in from.
## Shots: "wide", "talk" (the group, left of the replies), "game" (the
## dance floor, the carrom board; left of the game's card, or above the
## dance strip) and, in the hostel room, "desk". A shot may set "offset"
## and "lift" (the camera's h_offset and v_offset) to leave room for a card.

const PLACES := ["canteen", "hostel_room", "hostel", "terrace", "breakroom", "wedding", "seminar"]
const YOU := Vector3(1.05, 0, 1.3)
const GUESTS := [Vector3(-0.35, 0, -0.3), Vector3(-1.3, 0, 0.25), Vector3(0.45, 0, -0.95), Vector3(-0.95, 0, -1.05),
	Vector3(-2.05, 0, -0.45), Vector3(-1.95, 0, 0.95), Vector3(-0.15, 0, 0.75)]
const DOOR := Vector3(3.7, 0, -1.6)
## Where home is built for the video call: far enough off that the room's
## camera never sees it.
const FAMILY := Vector3(40, 0, 0)
const NIGHT := Color("#101C2B")

var place := "canteen"
## The people who were put in the set, by id (besides "you").
var guests: Array[String] = []
## Where the doctor ("you") and the rival ("rival") stand for the party's
## game: {who: [spot, facing]}. Empty: they play where they are.
var play_spots := {}
var _fan: Node3D
var _lights: Array[MeshInstance3D] = []
var _clock := 0.0


func _init(for_profile: PlayerProfile = null, where: String = "canteen") -> void:
	super(for_profile)
	place = where if where in PLACES else "canteen"


func _ready() -> void:
	name = "Evening" + place.capitalize().replace(" ", "")
	marks = {"you": YOU, "door": DOOR}
	for index in GUESTS.size():
		marks["g%d" % (index + 1)] = GUESTS[index]
	shots = {
		"wide": {"from": Vector3(4.3, 2.9, 6.6), "at": Vector3(-0.7, 1.0, -0.5), "fov": 46.0},
		"talk": {"from": Vector3(3.0, 2.05, 5.3), "at": Vector3(-0.55, 1.05, -0.15), "fov": 42.0, "offset": 0.62},
		"game": {"from": Vector3(0.6, 2.5, 5.8), "at": Vector3(-0.3, 0.95, -0.2), "fov": 46.0},
	}
	match place:
		"canteen":
			_build_canteen()
		"hostel_room":
			_build_hostel_room()
		"hostel":
			_build_common_room()
		"terrace":
			_build_terrace()
		"breakroom":
			_build_breakroom()
		"wedding":
			_build_wedding()
		"seminar":
			_build_seminar()


## Moves the ceiling fan and the twinkling lights on (story time).
func tick(delta: float) -> void:
	_clock += delta
	if _fan != null:
		_fan.rotation.y += delta * 7.0
	for index in _lights.size():
		var bulb := _lights[index]
		if is_instance_valid(bulb):
			bulb.visible = fmod(_clock * 1.3 + index * 0.37, 2.6) > 0.25


## Puts the doctor (in home clothes) and the guests in their places. A guest
## not in the cast's looks is left out. Mum, Dad and Anu are never here.
func add_people(ids: Array) -> void:
	var you := add_player(YOU, atan2(-0.6 - YOU.x, -0.2 - YOU.z), "casual")
	you.set_mood(AvatarConfig.Mood.CALM)
	var spot := 0
	for id: String in ids:
		if not CastLooks.has(id) or actors.has(id) or spot >= GUESTS.size():
			continue
		var at: Vector3 = GUESTS[spot]
		var rig := add_actor(id, CastLooks.config(id), at, atan2(YOU.x - at.x, YOU.z - at.z), "casual")
		rig.set_mood(CastLooks.mood(id))
		rig.scale = Vector3.ONE * CastLooks.scale(id)
		guests.append(id)
		spot += 1


## Someone who isn't in the set yet, waiting out of sight by the door.
func add_late(id: String) -> AvatarRig:
	if actors.has(id) or not CastLooks.has(id):
		return actors.get(id)
	var rig := add_actor(id, CastLooks.config(id), DOOR, -PI / 2, "casual")
	rig.set_mood(CastLooks.mood(id))
	rig.visible = false
	return rig


## The next free guest spot, for a late arrival.
func free_spot() -> Vector3:
	return GUESTS[mini(guests.size(), GUESTS.size() - 1)]


# --- Shared pieces -----------------------------------------------------------------

func _room(wall: Color, floor_colour: Color, background: Color = NIGHT, ambient: Color = Color("#C9D3E0"),
		ambient_energy: float = 0.5, energy: float = 0.62, sun: Color = Color("#FFE9CC")) -> void:
	StageLighting.add_to(self, background, Vector3(-48, 28, 0), energy, ambient, ambient_energy, sun)
	LowPoly.put(self, LowPoly.box(Vector3(10, 0.1, 8), floor_colour), Vector3(0, -0.05, 0.6))
	LowPoly.put(self, LowPoly.box(Vector3(10, 3.3, 0.2), wall), Vector3(0, 1.65, -3.1))
	LowPoly.put(self, LowPoly.box(Vector3(10, 0.14, 0.24), wall.darkened(0.25)), Vector3(0, 0.07, -3.0))
	LowPoly.put(self, LowPoly.box(Vector3(0.2, 3.3, 8), wall.darkened(0.06)), Vector3(-4.6, 1.65, 0.6))
	LowPoly.put(self, LowPoly.box(Vector3(0.24, 0.14, 8), wall.darkened(0.3)), Vector3(-4.5, 0.07, 0.6))


func _lamp(at: Vector3, colour: Color, energy: float, reach: float) -> void:
	var lamp := OmniLight3D.new()
	lamp.light_color = colour
	lamp.light_energy = energy
	lamp.omni_range = reach
	lamp.position = at
	add_child(lamp)


func _glow_box(size: Vector3, colour: Color, at: Vector3, energy: float = 0.9, turn: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var made := LowPoly.box(size, colour)
	made.material_override = LowPoly.glow(colour, energy)
	LowPoly.put(self, made, at, turn)
	return made


func _tube_light(at: Vector3) -> void:
	_glow_box(Vector3(1.2, 0.06, 0.08), Color("#F4FBFF"), at, 1.2)
	LowPoly.put(self, LowPoly.box(Vector3(1.3, 0.04, 0.12), Color("#D9DDE0")), at + Vector3(0, 0.05, 0))


func _table(at: Vector3, size: Vector3, top: Color, legs: Color) -> Node3D:
	var table := LowPoly.joint(self, "Table", at)
	LowPoly.put(table, LowPoly.box(Vector3(size.x, 0.05, size.z), top), Vector3(0, size.y, 0))
	for x in [-size.x / 2 + 0.06, size.x / 2 - 0.06]:
		for z in [-size.z / 2 + 0.06, size.z / 2 - 0.06]:
			LowPoly.put(table, LowPoly.box(Vector3(0.05, size.y, 0.05), legs), Vector3(x, size.y / 2, z))
	LowPoly.put(table, LowPoly.shadow_blob(maxf(size.x, size.z) * 0.6, Vector2(1.0, size.z / size.x)), Vector3.ZERO)
	return table


func _chair(at: Vector3, facing: float, colour: Color) -> void:
	var chair := LowPoly.joint(self, "Chair", at, Vector3(0, facing, 0))
	LowPoly.put(chair, LowPoly.box(Vector3(0.46, 0.05, 0.46), colour), Vector3(0, 0.45, 0))
	LowPoly.put(chair, LowPoly.box(Vector3(0.46, 0.5, 0.05), colour.darkened(0.08)), Vector3(0, 0.72, -0.21))
	for x in [-0.19, 0.19]:
		for z in [-0.19, 0.19]:
			LowPoly.put(chair, LowPoly.box(Vector3(0.04, 0.45, 0.04), colour.darkened(0.2)), Vector3(x, 0.22, z))


func _cup(at: Vector3) -> void:
	LowPoly.put(self, LowPoly.cylinder(0.04, 0.032, 0.09, 8, Color("#F7F4EE")), at + Vector3(0, 0.045, 0))
	LowPoly.put(self, LowPoly.cylinder(0.036, 0.036, 0.006, 8, Color("#B98552")), at + Vector3(0, 0.086, 0))


func _sign(text: String, at: Vector3, size: int, colour: Color, turn: float = 0.0) -> Label3D:
	var label := label3d(text, size, colour)
	label.position = at
	label.rotation.y = turn
	add_child(label)
	return label


## A string of little lights hanging between two points, sagging in the middle.
func _string_lights(from: Vector3, to: Vector3, count: int, colours: Array, twinkle: bool = false) -> void:
	for index in count:
		var t := float(index) / float(maxi(1, count - 1))
		var at := from.lerp(to, t) - Vector3(0, sin(t * PI) * 0.35, 0)
		var bulb := LowPoly.sphere(0.04, colours[index % colours.size()], 5, 3)
		bulb.material_override = LowPoly.glow(colours[index % colours.size()], 1.6)
		LowPoly.put(self, bulb, at)
		if twinkle and index % 3 == 0:
			_lights.append(bulb)


## Seated figures for a crowd (silent: batchmates, wedding guests).
func _crowd(spots: Array, seed_value: int) -> void:
	var rng := SeededRandom.new(seed_value)
	for spot: Vector3 in spots:
		var figure := crowd_figure(rng)
		LowPoly.put(self, figure, Vector3(spot.x, 0, spot.z), Vector3(0, spot.y, 0))


func _window(at: Vector3, width: float, height: float, lights: int, seed_value: int) -> void:
	LowPoly.put(self, LowPoly.box(Vector3(width + 0.12, height + 0.12, 0.05), Color("#DCE3E6")), at)
	LowPoly.put(self, LowPoly.box(Vector3(width, height, 0.06), Color("#1A2C44")), at + Vector3(0, 0, 0.01))
	var rng := SeededRandom.new(seed_value)
	for index in lights:
		var x := rng.next_float() * (width - 0.12) - (width - 0.12) / 2.0
		var y := rng.next_float() * (height * 0.6) - height / 2.0 + 0.06
		var colour: Color = rng.pick([Color("#F5D58A"), Color("#F5B841"), Color("#CFE3F5")])
		_glow_box(Vector3(0.05, 0.05, 0.02), colour, at + Vector3(x, y, 0.045), 1.2)


# --- The canteen at night ------------------------------------------------------------

func _build_canteen() -> void:
	_room(Color("#E8DCC2"), Color("#C9C2B2"))
	# Mani's counter along the back, the chai urn steaming, the menu board.
	var counter := LowPoly.joint(self, "Counter", Vector3(-2.2, 0, -2.45))
	LowPoly.put(counter, LowPoly.box(Vector3(3.4, 1.0, 0.6), Color("#2F7F78")), Vector3(0, 0.5, 0))
	LowPoly.put(counter, LowPoly.box(Vector3(3.5, 0.06, 0.7), Color("#DADFD9")), Vector3(0, 1.03, 0))
	LowPoly.put(counter, LowPoly.cylinder(0.2, 0.2, 0.5, 10, Color("#C9CED2")), Vector3(-1.1, 1.31, 0))
	LowPoly.put(counter, LowPoly.cylinder(0.05, 0.05, 0.06, 6, Color("#2B2F33")), Vector3(-1.1, 1.18, 0.22))
	for index in 4:
		LowPoly.put(counter, LowPoly.box(Vector3(0.2, 0.08, 0.14), Color("#E2A35A")), Vector3(0.2 + index * 0.26, 1.1, 0.05))
	LowPoly.put(counter, LowPoly.box(Vector3(0.5, 0.3, 0.3), Color("#C9A15A")), Vector3(1.2, 1.21, -0.05))
	_sign("MANI'S CANTEEN", Vector3(-2.2, 2.75, -2.98), 64, Color("#2F7F78"))
	LowPoly.put(self, LowPoly.box(Vector3(1.5, 0.9, 0.04), Color("#2B2F33")), Vector3(0.6, 2.05, -2.98))
	_sign("TODAY\nCHAI 10\nSAMOSA 15\nCHAI 10", Vector3(0.6, 2.05, -2.95), 34, Color("#F4FBFA"))
	# The radio on a shelf, Riverside FM's dial lit.
	LowPoly.put(self, LowPoly.box(Vector3(0.8, 0.04, 0.3), Color("#8A5A3A")), Vector3(2.2, 1.6, -2.85))
	LowPoly.put(self, LowPoly.box(Vector3(0.42, 0.24, 0.16), Color("#B0482F")), Vector3(2.2, 1.74, -2.85))
	_glow_box(Vector3(0.14, 0.06, 0.02), Color("#F5B841"), Vector3(2.12, 1.76, -2.76), 1.4)
	_window(Vector3(-4.48, 1.7, -0.6), 1.6, 1.1, 9, 271)
	for x in [-2.0, 1.2]:
		_tube_light(Vector3(x, 3.1, -0.4))
	# The table by the window where whoever's on late has their chai.
	_table(Vector3(-0.85, 0, 0.0), Vector3(1.3, 0.74, 0.9), Color("#E8EEEE"), Color("#8E9599"))
	_chair(Vector3(-1.75, 0, 0.0), PI / 2, Color("#C0603E"))
	_chair(Vector3(-0.85, 0, -0.85), 0.0, Color("#C0603E"))
	_chair(Vector3(-0.85, 0, 0.85), PI, Color("#C0603E"))
	_cup(Vector3(-1.2, 0.765, 0.05))
	_cup(Vector3(-0.8, 0.765, -0.25))
	_cup(Vector3(-0.5, 0.765, 0.2))
	_table(Vector3(2.0, 0, -0.9), Vector3(1.1, 0.74, 0.8), Color("#E8EEEE"), Color("#8E9599"))
	_chair(Vector3(2.0, 0, -1.6), 0.0, Color("#3E8E5A"))
	_lamp(Vector3(-0.8, 2.4, 0.4), Color("#FFE2B0"), 0.8, 5.0)
	marks["mani"] = Vector3(-2.2, 0, -3.05 + 0.25)
	marks["seat_a"] = Vector3(-1.75, 0, 0.0)
	marks["seat_b"] = Vector3(-0.85, 0, -0.85)
	shots["talk"] = {"from": Vector3(2.6, 2.0, 4.4), "at": Vector3(-0.9, 0.95, -0.25), "fov": 42.0, "offset": 0.62}
	# The back wall: Mani at his counter, the menu, the radio on its shelf.
	shots["radio"] = {"from": Vector3(1.9, 2.25, 3.9), "at": Vector3(0.1, 1.35, -2.8), "fov": 46.0, "lift": -0.25}


## Mani behind his counter, and two colleagues sitting at the table.
func add_canteen_people(staff: Array) -> void:
	# By the end of the table, out of the camera's way.
	var you := add_player(Vector3(0.35, 0, 0.3), atan2(-0.85 - 0.35, 0.0 - 0.3), "casual")
	you.set_mood(AvatarConfig.Mood.TIRED)
	if CastLooks.has("mani"):
		var mani := add_actor("mani", CastLooks.config("mani"), marks["mani"], 0.0, CastLooks.outfit("mani"))
		mani.set_mood(AvatarConfig.Mood.HAPPY)
	var seats := [[marks["seat_a"], PI / 2], [marks["seat_b"], 0.0]]
	for index in mini(staff.size(), seats.size()):
		var id := str(staff[index])
		if not CastLooks.has(id):
			continue
		var rig := add_actor(id, CastLooks.config(id), seats[index][0], float(seats[index][1]), CastLooks.outfit(id))
		rig.sitting = true
		rig.set_mood(CastLooks.mood(id))
		guests.append(id)


# --- The hostel room ------------------------------------------------------------------

func _build_hostel_room() -> void:
	_room(Color("#C9D8C5"), Color("#A8846A"), NIGHT, Color("#B9C6D8"), 0.48, 0.5)
	# The bed along the left wall, the blanket from home, one sad pillow.
	var bed := LowPoly.joint(self, "Bed", Vector3(-3.55, 0, 0.7))
	LowPoly.put(bed, LowPoly.box(Vector3(1.0, 0.4, 2.0), Color("#6B4A33")), Vector3(0, 0.2, 0))
	LowPoly.put(bed, LowPoly.box(Vector3(0.95, 0.14, 1.95), Color("#F2EEE4")), Vector3(0, 0.47, 0))
	LowPoly.put(bed, LowPoly.box(Vector3(0.97, 0.06, 1.3), Color("#B3263A")), Vector3(0, 0.56, 0.3))
	LowPoly.put(bed, LowPoly.box(Vector3(0.6, 0.12, 0.35), Color("#F7F4EE")), Vector3(0, 0.6, -0.75))
	LowPoly.put(bed, LowPoly.shadow_blob(1.0, Vector2(0.6, 1.0)), Vector3.ZERO)
	# The desk under the window: the laptop's screen glowing, books, the kettle.
	var desk := _table(Vector3(-1.9, 0, -2.45), Vector3(1.5, 0.74, 0.7), Color("#8A5A3A"), Color("#6B4A33"))
	LowPoly.put(desk, LowPoly.box(Vector3(0.42, 0.02, 0.3), Color("#2B2F33")), Vector3(0.1, 0.775, 0.05))
	var screen := LowPoly.box(Vector3(0.42, 0.28, 0.02), Color("#BFE3F0"))
	screen.material_override = LowPoly.glow(Color("#BFE3F0"), 1.1)
	LowPoly.put(desk, screen, Vector3(0.1, 0.92, -0.1), Vector3(-0.2, 0, 0))
	for index in 3:
		LowPoly.put(desk, LowPoly.box(Vector3(0.24, 0.05, 0.32), [Color("#24427A"), Color("#B3263A"), Color("#3E8E5A")][index]),
			Vector3(-0.5, 0.79 + index * 0.05, 0.0))
	LowPoly.put(desk, LowPoly.cylinder(0.07, 0.08, 0.2, 8, Color("#C9CED2")), Vector3(0.55, 0.87, -0.05))
	LowPoly.put(desk, LowPoly.cylinder(0.09, 0.09, 0.07, 8, Color("#E2A35A")), Vector3(0.6, 0.8, 0.2))
	_chair(Vector3(-1.9, 0, -1.75), PI, Color("#3A5A7A"))
	_window(Vector3(-1.9, 1.95, -2.98), 1.5, 0.9, 12, 337)
	# Posters, a calendar crossed off, a coat on a hook.
	LowPoly.put(self, LowPoly.box(Vector3(0.6, 0.85, 0.02), Color("#24427A")), Vector3(0.6, 1.85, -2.99))
	_sign("GRAY'S\nANATOMY\nREVISION\nWALL", Vector3(0.6, 1.85, -2.97), 26, Color("#F4FBFA"))
	LowPoly.put(self, LowPoly.box(Vector3(0.5, 0.6, 0.02), Color.WHITE), Vector3(1.55, 1.75, -2.99))
	for row in 4:
		for column in 5:
			if row * 5 + column < 13:
				LowPoly.put(self, LowPoly.box(Vector3(0.05, 0.012, 0.01), Color("#B3263A")),
					Vector3(1.38 + column * 0.085, 1.88 - row * 0.1, -2.975), Vector3(0, 0, 0.7))
	LowPoly.put(self, LowPoly.box(Vector3(0.05, 0.05, 0.12), Color("#8E9599")), Vector3(2.6, 1.9, -2.94))
	LowPoly.put(self, LowPoly.box(Vector3(0.55, 1.0, 0.1), Color("#F7F4EE")), Vector3(2.6, 1.4, -2.9))
	# A pile of clothes on the second chair, and a suitcase under the bed.
	_chair(Vector3(-3.4, 0, -1.9), PI / 2, Color("#8E9599"))
	LowPoly.put(self, LowPoly.box(Vector3(0.4, 0.2, 0.36), Color("#5E9FD0")), Vector3(-3.4, 0.56, -1.9), Vector3(0, 0.3, 0.1))
	LowPoly.put(self, LowPoly.box(Vector3(0.3, 0.12, 0.3), Color("#1F8A8A")), Vector3(-3.38, 0.72, -1.85), Vector3(0, -0.4, 0))
	# The ceiling fan, turning.
	_fan = LowPoly.joint(self, "Fan", Vector3(-0.6, 3.0, 0.2))
	LowPoly.put(_fan, LowPoly.cylinder(0.09, 0.09, 0.1, 8, Color("#E8EEEE")), Vector3.ZERO)
	for blade in 3:
		var arm := LowPoly.joint(_fan, "Blade", Vector3.ZERO, Vector3(0, TAU * blade / 3.0, 0))
		LowPoly.put(arm, LowPoly.box(Vector3(0.62, 0.015, 0.12), Color("#DADFD9")), Vector3(0.36, -0.02, 0))
	LowPoly.put(self, LowPoly.cylinder(0.015, 0.015, 0.3, 4, Color("#C9CED2")), Vector3(-0.6, 3.15, 0.2))
	_lamp(Vector3(-1.9, 1.4, -1.9), Color("#BFE3F0"), 0.5, 3.0)
	_lamp(Vector3(0.0, 2.6, 0.6), Color("#FFE2B0"), 0.6, 5.5)
	marks["desk"] = Vector3(-1.9, 0, -1.75)
	marks["bed"] = Vector3(-2.75, 0, 0.6)
	shots["desk"] = {"from": Vector3(-0.6, 1.75, 0.2), "at": Vector3(-2.0, 1.0, -2.3), "fov": 44.0}
	shots["bed"] = {"from": Vector3(0.4, 2.2, 3.0), "at": Vector3(-3.0, 0.6, 0.4), "fov": 44.0}


## The doctor at the desk, laptop open, and (off to one side of the set, out
## of sight of the room) home on the other end of the call.
func add_hostel_people() -> void:
	var you := add_player(marks["desk"], PI, "casual")
	you.sitting = true
	you.set_mood(AvatarConfig.Mood.TIRED)
	_build_home_end()


## Home, as the laptop's camera sees it: the sitting room at FAMILY, Mum in
## the middle, Dad too close to the camera, Anu half out of the picture. The
## "call" shot looks at it; a call frame goes over it on screen.
func _build_home_end() -> void:
	var home := LowPoly.joint(self, "HomeEnd", FAMILY)
	LowPoly.put(home, LowPoly.box(Vector3(4.2, 2.8, 0.2), Color("#E9C79A")), Vector3(0, 1.4, -1.0))
	LowPoly.put(home, LowPoly.box(Vector3(4.2, 0.1, 3.0), Color("#9A6B4A")), Vector3(0, -0.05, 0.3))
	# The sofa with the plastic still on the arms, the family photo, the
	# calendar from the sweet shop, the tube light everybody's lit by.
	LowPoly.put(home, LowPoly.box(Vector3(2.4, 0.45, 0.7), Color("#7A3B4B")), Vector3(0, 0.22, -0.55))
	LowPoly.put(home, LowPoly.box(Vector3(2.4, 0.55, 0.18), Color("#7A3B4B")), Vector3(0, 0.6, -0.85))
	for side in [-1.0, 1.0]:
		LowPoly.put(home, LowPoly.box(Vector3(0.18, 0.62, 0.7), Color("#8C4A5A")), Vector3(1.25 * side, 0.31, -0.55))
	LowPoly.put(home, LowPoly.box(Vector3(0.7, 0.5, 0.04), Color("#6B4A33")), Vector3(-0.2, 1.95, -0.89))
	LowPoly.put(home, LowPoly.box(Vector3(0.6, 0.4, 0.02), Color("#BFD9E6")), Vector3(-0.2, 1.95, -0.865))
	LowPoly.put(home, LowPoly.box(Vector3(0.38, 0.55, 0.02), Color.WHITE), Vector3(1.1, 1.85, -0.89))
	LowPoly.put(home, LowPoly.box(Vector3(0.38, 0.2, 0.025), Color("#E05A3A")), Vector3(1.1, 2.03, -0.88))
	var tube := LowPoly.box(Vector3(1.1, 0.05, 0.07), Color("#F4FBFF"))
	tube.material_override = LowPoly.glow(Color("#F4FBFF"), 1.1)
	LowPoly.put(home, tube, Vector3(0.3, 2.55, -0.85))
	LowPoly.put(home, LowPoly.cylinder(0.16, 0.2, 0.35, 7, Color("#B9653A")), Vector3(-1.75, 0.17, -0.6))
	LowPoly.put(home, LowPoly.sphere(0.32, Color("#3E8E5A"), 7, 4), Vector3(-1.75, 0.6, -0.6))
	var family := family_looks(profile.avatar)
	var mum := add_actor("mum", family["mum"], FAMILY + Vector3(0.0, 0, -0.35), 0.0, "kurta")
	mum.set_mood(AvatarConfig.Mood.HAPPY)
	var dad := add_actor("dad", family["dad"], FAMILY + Vector3(-0.62, 0, 0.1), 0.25, "casual")
	dad.set_mood(AvatarConfig.Mood.HAPPY)
	var anu := add_actor("anu", family["anu"], FAMILY + Vector3(0.66, 0, -0.1), -0.3, "casual")
	anu.scale = Vector3.ONE * 0.86
	anu.set_mood(AvatarConfig.Mood.CALM)
	shots["call"] = {"from": FAMILY + Vector3(0.05, 1.45, 2.55), "at": FAMILY + Vector3(0.0, 1.18, -0.2), "fov": 40.0}


# --- The hostel common room ------------------------------------------------------------

func _build_common_room() -> void:
	_room(Color("#9FBF9A"), Color("#B9B2A2"), NIGHT, Color("#C8D6C4"), 0.52, 0.55)
	# Paint coming off in maps of countries nobody has heard of.
	for patch: Vector3 in [Vector3(-3.2, 2.4, -2.99), Vector3(1.9, 0.9, -2.99), Vector3(-1.1, 2.75, -2.99)]:
		LowPoly.put(self, LowPoly.box(Vector3(0.5, 0.3, 0.01), Color("#C9D3C3")), patch, Vector3(0, 0, 0.4))
	_sign("NO COOKING IN ROOMS\nTHIS MEANS YOU, ROOM 14", Vector3(1.7, 2.1, -2.97), 30, Color("#2B2F33"))
	LowPoly.put(self, LowPoly.box(Vector3(1.5, 0.55, 0.02), Color("#F7F4EE")), Vector3(1.7, 2.1, -2.99))
	# An old TV, switched off, with a cricket bat leaning on it.
	LowPoly.put(self, LowPoly.box(Vector3(0.9, 0.7, 0.5), Color("#2B2F33")), Vector3(-3.3, 1.05, -2.5))
	LowPoly.put(self, LowPoly.box(Vector3(0.75, 0.55, 0.02), Color("#3E4A52")), Vector3(-3.3, 1.07, -2.24))
	LowPoly.put(self, LowPoly.box(Vector3(1.0, 0.7, 0.5), Color("#8A5A3A")), Vector3(-3.3, 0.35, -2.5))
	LowPoly.put(self, LowPoly.box(Vector3(0.1, 0.85, 0.03), Color("#E2C48A")), Vector3(-2.65, 0.45, -2.25), Vector3(0, 0, -0.25))
	# The carrom board, on its stand, in the middle of everything.
	var board := LowPoly.joint(self, "Carrom", Vector3(-0.55, 0, 0.2))
	LowPoly.put(board, LowPoly.box(Vector3(0.95, 0.06, 0.95), Color("#6B4A33")), Vector3(0, 0.74, 0))
	LowPoly.put(board, LowPoly.box(Vector3(0.82, 0.065, 0.82), Color("#E8CF9A")), Vector3(0, 0.745, 0))
	for x in [-0.37, 0.37]:
		for z in [-0.37, 0.37]:
			LowPoly.put(board, LowPoly.cylinder(0.035, 0.035, 0.07, 8, Color("#1B1411")), Vector3(x, 0.75, z))
	LowPoly.put(board, LowPoly.torus(0.08, 0.095, Color("#B3263A"), 12, 3), Vector3(0, 0.78, 0))
	LowPoly.put(board, LowPoly.box(Vector3(0.25, 0.7, 0.25), Color("#4A3426")), Vector3(0, 0.35, 0))
	LowPoly.put(board, LowPoly.shadow_blob(0.6), Vector3.ZERO)
	for index in 7:
		var angle := TAU * index / 7.0
		LowPoly.put(board, LowPoly.cylinder(0.025, 0.025, 0.015, 8, Color("#F2EEE4") if index % 2 == 0 else Color("#2B2F33")),
			Vector3(cos(angle) * 0.07, 0.785, sin(angle) * 0.07))
	_tube_light(Vector3(-0.6, 3.1, 0.0))
	_window(Vector3(-4.48, 1.7, 0.4), 1.4, 1.0, 7, 419)
	_crowd([Vector3(-2.6, 0.9, 1.2), Vector3(-2.9, 0.4, 0.2), Vector3(1.9, -1.6, -0.6), Vector3(-1.8, 0.2, -1.9)], 717)
	for spot: Vector3 in [Vector3(-2.6, 0, 1.2), Vector3(-2.9, 0, 0.2), Vector3(1.9, 0, -0.6), Vector3(-1.8, 0, -1.9)]:
		_chair(spot, 0.0, Color("#B3263A"))
	_lamp(Vector3(-0.6, 2.4, 0.4), Color("#F4FBFF"), 0.7, 5.0)
	play_spots = {"you": [Vector3(-0.55, 0, 0.98), PI], "rival": [Vector3(-0.55, 0, -0.6), 0.0]}
	shots["game"] = {"from": Vector3(1.9, 2.5, 2.9), "at": Vector3(-0.55, 0.8, 0.2), "fov": 46.0, "offset": 0.95}


# --- The terrace at Diwali --------------------------------------------------------------

func _build_terrace() -> void:
	StageLighting.add_to(self, Color("#0E1A33"), Vector3(-40, 30, 0), 0.45, Color("#8C9AC4"), 0.55, Color("#FFC98A"))
	LowPoly.put(self, LowPoly.box(Vector3(11, 0.1, 9), Color("#8F8A82")), Vector3(0, -0.05, 0.5))
	# The parapet round the roof, diyas burning along its top.
	LowPoly.put(self, LowPoly.box(Vector3(11, 0.9, 0.2), Color("#B9B2A2")), Vector3(0, 0.45, -3.4))
	LowPoly.put(self, LowPoly.box(Vector3(0.2, 0.9, 9), Color("#ADA697")), Vector3(-5.0, 0.45, 0.5))
	for index in 14:
		var at := Vector3(-4.6 + index * 0.7, 0.92, -3.35) if index < 10 else Vector3(-4.95, 0.92, -2.6 + (index - 10) * 0.9)
		LowPoly.put(self, LowPoly.cylinder(0.06, 0.04, 0.04, 8, Color("#C0603E")), at)
		var flame := LowPoly.sphere(0.03, Color("#FFB347"), 5, 3)
		flame.material_override = LowPoly.glow(Color("#FFB347"), 2.2)
		LowPoly.put(self, flame, at + Vector3(0, 0.05, 0), Vector3.ZERO, Vector3(0.7, 1.5, 0.7))
		if index % 2 == 0:
			_lights.append(flame)
	# The city beyond, windows lit, and a water tank on its stilts.
	var rng := SeededRandom.new(1010)
	for index in 9:
		var height := rng.next_float() * 3.0 + 1.5
		var x := -6.0 + index * 1.5
		LowPoly.put(self, LowPoly.box(Vector3(1.3, height, 1.0), Color("#1B2740")), Vector3(x, height / 2.0 - 1.5, -8.0))
		for light in 4:
			_glow_box(Vector3(0.12, 0.12, 0.02), rng.pick([Color("#F5D58A"), Color("#F5B841"), Color("#F07C5A")]),
				Vector3(x - 0.4 + rng.next_float() * 0.8, rng.next_float() * height - 1.4, -7.48), 1.4)
	LowPoly.put(self, LowPoly.cylinder(0.55, 0.55, 1.0, 12, Color("#56636E")), Vector3(3.6, 1.9, -2.8))
	LowPoly.put(self, LowPoly.cylinder(0.58, 0.58, 0.06, 12, Color("#6E7C88")), Vector3(3.6, 2.43, -2.8))
	for x in [3.2, 4.0]:
		LowPoly.put(self, LowPoly.box(Vector3(0.08, 1.4, 0.08), Color("#6E7378")), Vector3(x, 0.7, -2.8))
	# Strings of lights from the tank to the stairs, a rangoli, the sweets.
	_string_lights(Vector3(-4.8, 2.6, -3.2), Vector3(3.0, 2.6, -2.2), 22, [Color("#F5B841"), Color("#F07C5A"), Color("#8FE3D2")], true)
	_string_lights(Vector3(-4.8, 2.5, 1.8), Vector3(3.0, 2.4, -2.0), 18, [Color("#F5B841"), Color("#E85D9A")], true)
	for ring in 4:
		var colours := [Color("#E85D9A"), Color("#F5B841"), Color("#3E8E5A"), Color("#5E9FD0")]
		LowPoly.put(self, LowPoly.cylinder(0.65 - ring * 0.15, 0.65 - ring * 0.15, 0.01, 16, colours[ring]),
			Vector3(-0.6, 0.005 + ring * 0.002, 0.15))
	var sweets := _table(Vector3(-3.0, 0, -1.4), Vector3(1.4, 0.74, 0.7), Color("#F2EEE4"), Color("#8E9599"))
	for index in 5:
		LowPoly.put(sweets, LowPoly.box(Vector3(0.22, 0.07, 0.18), [Color("#F5B841"), Color("#E85D9A"), Color.WHITE][index % 3]),
			Vector3(-0.5 + index * 0.25, 0.8, 0.0))
	_lamp(Vector3(-0.6, 2.2, 0.0), Color("#FFC98A"), 1.0, 7.0)
	shots["wide"] = {"from": Vector3(4.6, 3.1, 6.6), "at": Vector3(-0.8, 1.0, -0.8), "fov": 48.0}
	shots["game"] = {"from": Vector3(2.2, 2.4, 4.6), "at": Vector3(-0.6, 0.95, -0.2), "fov": 46.0, "offset": 0.95}


# --- The nurses' break room ---------------------------------------------------------------

func _build_breakroom() -> void:
	_room(Color("#D5E6E8"), Color("#BFCACB"))
	# Lockers, a kettle that's older than the interns, a noticeboard.
	for index in 6:
		LowPoly.put(self, LowPoly.box(Vector3(0.48, 1.9, 0.5), Color("#5E9FD0").darkened(0.05 * (index % 2))),
			Vector3(1.0 + index * 0.5, 0.95, -2.75))
		LowPoly.put(self, LowPoly.box(Vector3(0.06, 0.12, 0.02), Color("#C9CED2")), Vector3(1.15 + index * 0.5, 1.1, -2.49))
	LowPoly.put(self, LowPoly.box(Vector3(1.3, 0.9, 0.03), Color("#C9A15A")), Vector3(-2.6, 1.8, -2.98))
	for index in 5:
		LowPoly.put(self, LowPoly.box(Vector3(0.22, 0.28, 0.01), [Color.WHITE, Color("#F5D58A"), Color("#CFE3F5")][index % 3]),
			Vector3(-3.0 + (index % 3) * 0.36, 1.95 - (index / 3) * 0.36, -2.96))
	_sign("HAPPY BIRTHDAY\nSISTER GRACE", Vector3(-0.6, 2.7, -2.98), 60, Color("#B3263A"))
	# Balloons on strings, drifting.
	var rng := SeededRandom.new(1717)
	for index in 9:
		var at := Vector3(-3.8 + index * 0.85 + rng.next_float() * 0.2, 2.3 + rng.next_float() * 0.5, -2.6 + rng.next_float() * 0.5)
		LowPoly.put(self, LowPoly.sphere(0.17, rng.pick([Color("#E85D9A"), Color("#F5B841"), Color("#8FE3D2"), Color("#5E9FD0")]), 8, 5),
			at, Vector3.ZERO, Vector3(1.0, 1.2, 1.0))
		LowPoly.put(self, LowPoly.box(Vector3(0.006, 0.9, 0.006), Color("#DADFD9")), at - Vector3(0, 0.6, 0))
	# The table with the cake (her face on it, printed) and the paper plates.
	var table := _table(Vector3(-0.7, 0, -0.95), Vector3(1.5, 0.74, 0.8), Color("#F7F4EE"), Color("#8E9599"))
	LowPoly.put(table, LowPoly.cylinder(0.26, 0.26, 0.14, 14, Color("#F5D58A")), Vector3(0, 0.84, 0))
	LowPoly.put(table, LowPoly.cylinder(0.27, 0.27, 0.02, 14, Color("#E85D9A")), Vector3(0, 0.92, 0))
	LowPoly.put(table, LowPoly.cylinder(0.11, 0.11, 0.005, 12, Color("#7A5038")), Vector3(0, 0.935, 0))
	for index in 3:
		LowPoly.put(table, LowPoly.cylinder(0.008, 0.008, 0.08, 4, Color.WHITE), Vector3(-0.08 + index * 0.08, 0.98, 0.14))
		var flame := LowPoly.sphere(0.014, Color("#FFB347"), 4, 3)
		flame.material_override = LowPoly.glow(Color("#FFB347"), 2.4)
		LowPoly.put(table, flame, Vector3(-0.08 + index * 0.08, 1.035, 0.14))
	for index in 4:
		LowPoly.put(table, LowPoly.cylinder(0.08, 0.08, 0.01, 10, Color.WHITE), Vector3(-0.6 + index * 0.4, 0.775, 0.28))
	LowPoly.put(self, LowPoly.cylinder(0.1, 0.11, 0.25, 8, Color("#C9CED2")), Vector3(3.3, 1.18, -2.7))
	_tube_light(Vector3(-0.5, 3.1, -0.2))
	_lamp(Vector3(-0.6, 2.2, 0.4), Color("#FFE8C8"), 0.6, 5.0)
	# The toast: the doctor by the cake, everyone turned to listen.
	play_spots = {"you": [Vector3(1.3, 0, 0.1), atan2(-0.6 - 1.3, 0.0 - 0.1)]}
	shots["game"] = {"from": Vector3(2.2, 2.3, 4.6), "at": Vector3(-0.2, 1.3, -0.8), "fov": 48.0, "offset": 1.35}


# --- A wedding hall --------------------------------------------------------------------

func _build_wedding() -> void:
	_room(Color("#5A2742"), Color("#3A2A3A"), Color("#1A1024"), Color("#D6B8D0"), 0.55, 0.6, Color("#FFD9A8"))
	# Marigolds in strands down the back wall, fairy lights across the top.
	for index in 18:
		var x := -4.2 + index * 0.5
		for bead in 7:
			LowPoly.put(self, LowPoly.sphere(0.055, Color("#F5A623") if (bead + index) % 2 == 0 else Color("#F5D23A"), 6, 4),
				Vector3(x, 3.0 - bead * 0.14, -2.95))
	_string_lights(Vector3(-4.4, 3.1, -2.6), Vector3(4.0, 3.1, -2.6), 24, [Color("#FFF1CF")], true)
	_string_lights(Vector3(-4.4, 3.0, 2.4), Vector3(4.0, 3.0, -2.6), 20, [Color("#FFF1CF"), Color("#F5B841")], true)
	# The stage with the couple's chairs, and a backdrop of drapes.
	LowPoly.put(self, LowPoly.box(Vector3(3.6, 0.35, 1.4), Color("#7A1F3D")), Vector3(-2.3, 0.175, -2.25))
	LowPoly.put(self, LowPoly.box(Vector3(3.6, 0.02, 1.42), Color("#C9A15A")), Vector3(-2.3, 0.36, -2.25))
	for x in [-2.75, -1.85]:
		LowPoly.put(self, LowPoly.box(Vector3(0.6, 0.5, 0.55), Color("#F2E2B8")), Vector3(x, 0.6, -2.35))
		LowPoly.put(self, LowPoly.box(Vector3(0.6, 0.85, 0.12), Color("#C9A15A")), Vector3(x, 1.05, -2.6))
	# The dance floor: squares that light up.
	for row in 4:
		for column in 4:
			var lit := (row + column) % 2 == 0
			var tile := LowPoly.box(Vector3(0.58, 0.02, 0.58), Color("#F5B841") if lit else Color("#2E1F40"))
			if lit:
				tile.material_override = LowPoly.glow(Color("#F5B841"), 0.45)
			LowPoly.put(self, tile, Vector3(-1.5 + column * 0.6, 0.012, -0.6 + row * 0.6))
	# Round tables with white cloths and guests round them.
	for spot: Vector3 in [Vector3(2.5, 0, -1.4), Vector3(-3.6, 0, 1.4)]:
		LowPoly.put(self, LowPoly.cylinder(0.6, 0.62, 0.74, 14, Color("#F7F4EE")), spot + Vector3(0, 0.37, 0))
		LowPoly.put(self, LowPoly.cylinder(0.12, 0.1, 0.25, 8, Color("#C9A15A")), spot + Vector3(0, 0.86, 0))
	_crowd([Vector3(2.5, 0.0, -2.2), Vector3(3.3, -1.57, -1.4), Vector3(1.7, 1.57, -1.4), Vector3(-3.6, 3.14, 2.2),
		Vector3(-2.8, -1.57, 1.4), Vector3(-4.3, 1.57, 1.2)], 2020)
	_lamp(Vector3(-0.6, 2.4, 0.0), Color("#FFD9A8"), 1.0, 6.5)
	_lamp(Vector3(-2.3, 2.0, -1.6), Color("#F5A623"), 0.6, 3.5)
	# The dance-off: both out front on the floor, facing the room.
	play_spots = {"you": [Vector3(-0.25, 0, 0.8), 0.15], "rival": [Vector3(-1.15, 0, 0.8), 0.25]}
	shots["game"] = {"from": Vector3(0.1, 2.0, 5.2), "at": Vector3(-0.6, 1.0, 0.0), "fov": 46.0, "lift": -0.55}


# --- The seminar room, for a farewell ------------------------------------------------------

func _build_seminar() -> void:
	_room(Color("#DDE5E8"), Color("#9AA6AA"))
	# The screen with the slide, the banner, the flowers, the mic.
	LowPoly.put(self, LowPoly.box(Vector3(2.6, 1.5, 0.03), Color("#F7F4EE")), Vector3(-1.4, 1.85, -2.98))
	_sign("THANK YOU, DR. RAO\n34 YEARS · 1 PEN", Vector3(-1.4, 1.9, -2.95), 54, Color("#127C80"))
	LowPoly.put(self, LowPoly.box(Vector3(3.6, 0.36, 0.02), Color("#127C80")), Vector3(-1.4, 2.85, -2.97))
	_sign("WARD 4 WILL MISS YOU", Vector3(-1.4, 2.85, -2.95), 40, Color("#F4FBFA"))
	var podium := LowPoly.joint(self, "Podium", Vector3(1.2, 0, -1.9))
	LowPoly.put(podium, LowPoly.box(Vector3(0.6, 1.1, 0.45), Color("#8A5A3A")), Vector3(0, 0.55, 0))
	LowPoly.put(podium, LowPoly.cylinder(0.008, 0.008, 0.35, 4, Color("#2B2F33")), Vector3(0, 1.27, 0.1), Vector3(-0.4, 0, 0))
	LowPoly.put(podium, LowPoly.sphere(0.03, Color("#2B2F33"), 6, 4), Vector3(0, 1.42, 0.17))
	var vase := LowPoly.joint(self, "Flowers", Vector3(2.4, 0, -2.4))
	LowPoly.put(vase, LowPoly.box(Vector3(0.5, 0.74, 0.5), Color("#E8EEEE")), Vector3(0, 0.37, 0))
	LowPoly.put(vase, LowPoly.cylinder(0.1, 0.08, 0.3, 8, Color("#5E9FD0")), Vector3(0, 0.89, 0))
	var rng := SeededRandom.new(2323)
	for index in 9:
		LowPoly.put(vase, LowPoly.sphere(0.06, rng.pick([Color("#F5D23A"), Color("#E85D9A"), Color.WHITE, Color("#F07C5A")]), 6, 4),
			Vector3(rng.next_float() * 0.3 - 0.15, 1.12 + rng.next_float() * 0.18, rng.next_float() * 0.3 - 0.15))
	# Chairs in rows, half full, and the samosas, which are full.
	for row in 2:
		for column in 4:
			_chair(Vector3(-3.6 + column * 0.62, 0, 1.5 + row * 0.8), PI, Color("#24427A"))
	_crowd([Vector3(-3.6, 3.14, 1.5), Vector3(-2.36, 3.14, 1.5), Vector3(-2.98, 3.14, 2.3), Vector3(-1.74, 3.14, 2.3)], 3434)
	var food := _table(Vector3(2.9, 0, 0.4), Vector3(0.8, 0.74, 1.4), Color("#F7F4EE"), Color("#8E9599"))
	for index in 4:
		LowPoly.put(food, LowPoly.cylinder(0.12, 0.12, 0.03, 10, Color("#E2A35A")), Vector3(0, 0.78, -0.5 + index * 0.33))
	for x in [-2.0, 1.0]:
		_tube_light(Vector3(x, 3.1, -0.3))
	_lamp(Vector3(-0.6, 2.4, 0.4), Color("#FFF1DC"), 0.6, 5.5)
	# The speech: the doctor at the podium, the room turned to listen.
	play_spots = {"you": [Vector3(1.2, 0, -2.4), 0.0]}
	shots["game"] = {"from": Vector3(2.9, 2.3, 3.4), "at": Vector3(0.1, 1.2, -1.3), "fov": 46.0, "offset": 0.95}
