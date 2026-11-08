class_name StageLighting
extends RefCounted
## The shared light set-up: soft sky ambience, one warm key light and a cool
## fill. Every 3D scene uses it so the look stays consistent.
##
## There are no real-time shadows: the game uses the Compatibility renderer
## (it runs on every iPhone and iPad, and CI screenshots match the device), and
## characters and furniture get soft contact shadows from LowPoly.shadow_blob.


static func add_to(parent: Node3D, background: Color = Color("#CFE3E6"), sun_angle: Vector3 = Vector3(-52, 32, 0),
		energy: float = 0.8, ambient: Color = Color("#DDE8F0"), ambient_energy: float = 0.42,
		sun_colour: Color = Color("#FFF4E3")) -> Environment:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = background
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = ambient
	environment.ambient_light_energy = ambient_energy
	# No sky reflections: at low angles they wash floors out to white.
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.95
	environment.tonemap_white = 2.2
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = environment
	parent.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = sun_angle
	sun.light_color = sun_colour
	sun.light_energy = energy
	parent.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.rotation_degrees = Vector3(-20, sun_angle.y + 160, 0)
	fill.light_color = Color("#BFD8F2")
	fill.light_energy = 0.22
	parent.add_child(fill)
	return environment


## Evening light for the title screen: a sky fading from deep blue to a warm
## horizon, a low orange sun and cool shadows.
static func add_dusk(parent: Node3D) -> Environment:
	var environment := add_to(parent, Color("#1B4058"), Vector3(-14, -58, 0), 0.75, Color("#7FA3C4"), 0.5,
		Color("#FFB27A"))
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#16354C")
	sky_material.sky_horizon_color = Color("#D9895F")
	sky_material.sky_curve = 0.18
	sky_material.ground_horizon_color = Color("#D9895F")
	sky_material.ground_bottom_color = Color("#24525F")
	sky_material.sun_angle_max = 0.0
	sky_material.sun_curve = 0.01
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	return environment
