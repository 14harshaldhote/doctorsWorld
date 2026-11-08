class_name LowPoly
extends RefCounted
## Helpers that build the game's flat-shaded, low-poly look in code.
##
## Every primitive is converted to a faceted mesh (one normal per triangle),
## so light catches each face separately. Materials are shared per colour.

static var _materials := {}


## A matte material in one flat colour, shared by everything that uses it.
static func material(colour: Color, roughness: float = 0.9, double_sided: bool = false) -> StandardMaterial3D:
	var key := "%s/%s/%s" % [colour.to_html(), roughness, double_sided]
	if _materials.has(key):
		return _materials[key]
	var made := StandardMaterial3D.new()
	made.albedo_color = colour
	made.roughness = roughness
	made.metallic_specular = 0.2
	if double_sided:
		made.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[key] = made
	return made


## A glowing material for lamps and screens.
static func glow(colour: Color, energy: float = 1.5) -> StandardMaterial3D:
	var key := "glow/%s/%s" % [colour.to_html(), energy]
	if _materials.has(key):
		return _materials[key]
	var made := StandardMaterial3D.new()
	made.albedo_color = colour
	made.emission_enabled = true
	made.emission = colour
	made.emission_energy_multiplier = energy
	_materials[key] = made
	return made


## A matte material that takes its colour from each vertex, for meshes
## painted in more than one colour (like a head with hair on top).
static func painted_material() -> StandardMaterial3D:
	if _materials.has("painted"):
		return _materials["painted"]
	var made := StandardMaterial3D.new()
	made.vertex_color_use_as_albedo = true
	made.vertex_color_is_srgb = true
	made.roughness = 0.9
	made.metallic_specular = 0.2
	_materials["painted"] = made
	return made


## A faceted sphere where each face is coloured by paint, a Callable that is
## given the face's direction from the centre (a unit vector) and returns a
## Color. Used to paint a hairline straight onto the skull.
static func painted_sphere(radius: float, sides: int, rings: int, paint: Callable,
		part_name: String = "") -> MeshInstance3D:
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = radius
	sphere_mesh.height = radius * 2.0
	sphere_mesh.radial_segments = sides
	sphere_mesh.rings = rings
	var source := SurfaceTool.new()
	source.create_from(sphere_mesh, 0)
	source.deindex()
	var corners: PackedVector3Array = source.commit_to_arrays()[Mesh.ARRAY_VERTEX]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)  # -1 = flat: one normal per triangle
	for index in range(0, corners.size(), 3):
		var middle := (corners[index] + corners[index + 1] + corners[index + 2]) / 3.0
		var colour: Color = paint.call(middle.normalized())
		for corner in 3:
			tool.set_color(colour)
			tool.add_vertex(corners[index + corner])
	tool.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = tool.commit()
	node.material_override = painted_material()
	if not part_name.is_empty():
		node.name = part_name
	return node


## A soft contact shadow for the floor under a character or a piece of
## furniture: two see-through dark discs, darker in the middle.
static func shadow_blob(radius: float, stretch: Vector2 = Vector2.ONE, part_name: String = "Shadow") -> Node3D:
	var holder := Node3D.new()
	holder.name = part_name
	for ring in 2:
		var disc := CylinderMesh.new()
		disc.top_radius = radius * (1.0 if ring == 0 else 0.68)
		disc.bottom_radius = disc.top_radius
		disc.height = 0.002
		disc.radial_segments = 14
		disc.rings = 1
		var node := MeshInstance3D.new()
		node.mesh = disc
		node.material_override = _shadow_material()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.position = Vector3(0, 0.004 + ring * 0.001, 0)
		node.scale = Vector3(stretch.x, 1.0, stretch.y)
		holder.add_child(node)
	return holder


static func _shadow_material() -> StandardMaterial3D:
	if _materials.has("shadow"):
		return _materials["shadow"]
	var made := StandardMaterial3D.new()
	made.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	made.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	made.albedo_color = Color(0.08, 0.14, 0.16, 0.16)
	made.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_materials["shadow"] = made
	return made


## Turns a smooth primitive into a faceted mesh.
static func faceted(mesh: Mesh) -> ArrayMesh:
	var source := SurfaceTool.new()
	source.create_from(mesh, 0)
	source.deindex()
	var corners: PackedVector3Array = source.commit_to_arrays()[Mesh.ARRAY_VERTEX]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)  # -1 = flat: one normal per triangle
	for corner in corners:
		tool.add_vertex(corner)
	tool.generate_normals()
	return tool.commit()


static func _instance(mesh: Mesh, colour: Color, part_name: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = faceted(mesh)
	node.material_override = material(colour)
	if not part_name.is_empty():
		node.name = part_name
	return node


static func box(size: Vector3, colour: Color, part_name: String = "") -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _instance(mesh, colour, part_name)


static func cylinder(top_radius: float, bottom_radius: float, height: float, sides: int, colour: Color,
		part_name: String = "") -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return _instance(mesh, colour, part_name)


static func sphere(radius: float, colour: Color, sides: int = 8, rings: int = 5, hemisphere: bool = false,
		part_name: String = "") -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * (1.0 if hemisphere else 2.0)
	mesh.radial_segments = sides
	mesh.rings = rings
	mesh.is_hemisphere = hemisphere
	return _instance(mesh, colour, part_name)


static func torus(inner: float, outer: float, colour: Color, ring_sides: int = 8, tube_sides: int = 4,
		part_name: String = "") -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = ring_sides
	mesh.ring_segments = tube_sides
	return _instance(mesh, colour, part_name)


## A flat strip along a line of points in the XY plane, facing +Z.
## Used for mouths and eyebrows, which need curves.
static func ribbon(points: PackedVector2Array, width: float, colour: Color, closed: bool = false,
		part_name: String = "") -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := points.size()
	var segments := count if closed else count - 1
	for index in segments:
		var a := points[index]
		var b := points[(index + 1) % count]
		var along := (b - a).normalized()
		var side := Vector2(-along.y, along.x) * width * 0.5
		var corners := [a - side, b - side, b + side, a + side]
		for triangle in [[0, 1, 2], [0, 2, 3]]:
			for corner in triangle:
				tool.set_normal(Vector3.BACK)
				var point: Vector2 = corners[corner]
				tool.add_vertex(Vector3(point.x, point.y, 0.0))
	# Round the joints so curves do not show gaps.
	var joints := count if closed else count
	for index in joints:
		var centre := points[index]
		for step in 6:
			var angle_a := TAU * step / 6.0
			var angle_b := TAU * (step + 1) / 6.0
			tool.set_normal(Vector3.BACK)
			tool.add_vertex(Vector3(centre.x, centre.y, 0.0))
			tool.add_vertex(Vector3(centre.x + cos(angle_b) * width * 0.5, centre.y + sin(angle_b) * width * 0.5, 0.0))
			tool.add_vertex(Vector3(centre.x + cos(angle_a) * width * 0.5, centre.y + sin(angle_a) * width * 0.5, 0.0))
	var node := MeshInstance3D.new()
	node.mesh = tool.commit()
	node.material_override = material(colour, 0.9, true)
	if not part_name.is_empty():
		node.name = part_name
	return node


## Places a node under a parent at a position, with an optional rotation
## (in radians) and scale. Returns the node for chaining.
static func put(parent: Node3D, node: Node3D, position: Vector3, rotation: Vector3 = Vector3.ZERO,
		scale: Vector3 = Vector3.ONE) -> Node3D:
	node.position = position
	node.rotation = rotation
	node.scale = scale
	parent.add_child(node)
	return node


## An empty joint that other parts hang from.
static func joint(parent: Node3D, joint_name: String, position: Vector3, rotation: Vector3 = Vector3.ZERO) -> Node3D:
	var node := Node3D.new()
	node.name = joint_name
	return put(parent, node, position, rotation)
