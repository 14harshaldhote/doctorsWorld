class_name StorySet
extends Node3D
## One place in a story scene (the graduation hall, home, the street outside
## the hospital). A set builds its room, its people (actors, by cast id),
## named spots (marks) and camera shots, and plays its own effects (cues).

## The characters on this set, by cast id. "you" is the player.
var actors := {}
## Named spots in the set, for walking and facing.
var marks := {}
## Camera shots by name: {from, at, fov, to_from, to_at, time}. A shot with
## to_from/to_at moves the camera slowly over time seconds.
var shots := {}
var profile: PlayerProfile


func _init(for_profile: PlayerProfile = null) -> void:
	profile = for_profile if for_profile != null else PlayerProfile.new()


## Moves anything the set animates by itself on by delta seconds (story time).
func tick(_delta: float) -> void:
	pass


## Plays an effect (applause, a door knock, an ambulance). Returns how many
## seconds the story should wait.
func cue(_cue_name: String) -> float:
	return 0.0


## Adds a character from the cast with a look and an outfit.
func add_actor(id: String, look: AvatarConfig, at: Vector3, facing: float, outfit: String = "doctor") -> AvatarRig:
	var rig := AvatarRig.new(look)
	rig.name = id.capitalize().replace(" ", "")
	rig.outfit = outfit
	rig.position = at
	rig.rotation.y = facing
	var entry: Dictionary = StoryBook.cast().get(id, {})
	rig.voice_pitch = float(entry.get("voice", 1.0))
	add_child(rig)
	actors[id] = rig
	return rig


## The player's own doctor in an outfit.
func add_player(at: Vector3, facing: float, outfit: String) -> AvatarRig:
	var rig := add_actor("you", profile.avatar, at, facing, outfit)
	rig.voice_pitch = 1.08 - 0.04 * profile.avatar.height
	return rig


## Mum, Dad and Anu look like the player: same skin, family features.
static func family_looks(you: AvatarConfig) -> Dictionary:
	var mum := AvatarConfig.new()
	mum.skin = you.skin
	mum.eyes = you.eyes
	mum.nose = you.nose
	mum.face = 0
	mum.brows = 1
	mum.height = 1
	mum.hair_style = 7
	mum.hair_colour = 1
	mum.scrubs = 7
	var dad := AvatarConfig.new()
	dad.skin = clampi(you.skin + 1, 0, AvatarConfig.SKIN_TONES.size() - 1)
	dad.face = 5
	dad.brows = 2
	dad.nose = you.nose
	dad.height = 3
	dad.body = 2
	dad.hair_style = 0
	dad.hair_colour = 5
	dad.facial_hair = 2
	dad.glasses = 4
	dad.scrubs = 3
	var anu := AvatarConfig.new()
	anu.skin = you.skin
	anu.eyes = 4
	anu.face = 0
	anu.height = 0
	anu.body = 0
	anu.hair_style = 6
	anu.hair_colour = 0
	anu.scrubs = 5
	return {"mum": mum, "dad": dad, "anu": anu}


## A quick seated figure for crowds: a body, a head and hair, nothing more.
static func crowd_figure(rng: SeededRandom) -> Node3D:
	var figure := Node3D.new()
	var clothes: Color = rng.pick([Color("#F07C5A"), Color("#3E8E5A"), Color("#24427A"), Color("#C9A15A"),
		Color("#6A4C9C"), Color("#E8EEEE"), Color("#8C2F4B"), Color("#2B2F33"), Color("#5E9FD0")])
	var skin: Color = AvatarConfig.SKIN_TONES[rng.next_int_in(2, 9)]
	var hair: Color = AvatarConfig.HAIR_COLOURS[rng.pick([0, 0, 0, 1, 1, 2, 5, 6])]
	LowPoly.put(figure, LowPoly.cylinder(0.17, 0.21, 0.5, 6, clothes), Vector3(0, 0.72, 0), Vector3.ZERO,
		Vector3(1.0, 1.0, 0.7))
	LowPoly.put(figure, LowPoly.cylinder(0.05, 0.05, 0.08, 5, skin), Vector3(0, 1.0, 0))
	LowPoly.put(figure, LowPoly.sphere(0.13, skin, 7, 4), Vector3(0, 1.13, 0))
	LowPoly.put(figure, LowPoly.sphere(0.14, hair, 7, 3, true), Vector3(0, 1.15, -0.015), Vector3(-0.4, 0, 0))
	return figure


static func label3d(text: String, size: int, colour: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = UiKit.heading_font()
	label.font_size = size
	label.pixel_size = 0.004
	label.outline_size = 0
	label.modulate = colour
	label.shaded = false
	return label


## A soft beam of light: a see-through cone that glows a little.
static func light_beam(top_radius: float, bottom_radius: float, height: float, colour: Color, alpha: float) -> MeshInstance3D:
	var cone := LowPoly.cylinder(top_radius, bottom_radius, height, 10, colour)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(colour, alpha)
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow.no_depth_test = false
	cone.material_override = glow
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return cone
