class_name StaticBatch
extends RefCounted
## Fewer draw calls for older phones. Everything in the game is built from
## many small meshes, and each one costs the phone a draw call every frame.
## optimise() merges meshes that can never move or change on their own into
## one mesh per group, coloured per vertex, which looks exactly the same.
##
## What is left alone, so nothing that changes can break:
## - anything a script keeps in a variable (a blanket that is shown and
##   hidden, a needle that moves, a dictionary of instruments),
## - anything with its own name (code finds those by name), or with metadata,
## - hidden meshes, see-through or glowing ones, and meshes with children.
## Such nodes, characters and named parts become their own groups: the
## meshes under each are merged with each other, never across them, so a
## moving joint carries its merged mesh with it.

## Merged meshes are named with this prefix.
const PREFIX := "Batch"

## Switched off only to compare the look with and without merging.
static var enabled := true

static var _materials := {}


## Merges what it safely can under root. Returns how many draw calls it saved.
static func optimise(root: Node3D) -> int:
	if not enabled:
		return 0
	var kept := _referenced_nodes(root)
	var groups := {}
	_collect(root, root, Transform3D.IDENTITY, kept, groups)
	var saved := 0
	for key: String in groups:
		var group: Dictionary = groups[key]
		var parts: Array = group["parts"]
		if parts.size() < 2:
			continue
		var merged := _merge(parts)
		if merged == null:
			continue
		var holder: Node3D = group["root"]
		var batch := MeshInstance3D.new()
		batch.name = "%s%d" % [PREFIX, holder.get_child_count()]
		batch.mesh = merged
		batch.material_override = group["material"]
		batch.cast_shadow = group["shadow"]
		holder.add_child(batch)
		for part: Array in parts:
			var mesh_node := part[0] as MeshInstance3D
			mesh_node.get_parent().remove_child(mesh_node)
			mesh_node.free()
		saved += parts.size() - 1
	return saved


## Every node that a script under root keeps in a variable (directly, or in
## an array or dictionary).
static func _referenced_nodes(root: Node) -> Dictionary:
	var found := {}
	var scripted: Array[Node] = [root]
	for child in root.find_children("*", "", true, false):
		if child.get_script() != null:
			scripted.append(child)
	for node in scripted:
		for property in node.get_property_list():
			if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
				continue
			_note(node.get(str(property["name"])), found, 0)
	return found


static func _note(value: Variant, found: Dictionary, depth: int) -> void:
	match typeof(value):
		TYPE_OBJECT:
			if value is Node and is_instance_valid(value):
				found[value] = true
		TYPE_ARRAY:
			if depth < 3:
				for item: Variant in value:
					_note(item, found, depth + 1)
		TYPE_DICTIONARY:
			if depth < 3:
				for item: Variant in (value as Dictionary).keys() + (value as Dictionary).values():
					_note(item, found, depth + 1)


static func _auto_named(node: Node) -> bool:
	return str(node.name).begins_with("@")


## True for nodes whose meshes get merged among themselves only.
static func _is_group(node: Node, root: Node, kept: Dictionary) -> bool:
	return node == root or kept.has(node) or node is AvatarRig or not _auto_named(node)


static func _collect(node: Node, group_root: Node3D, to_group: Transform3D, kept: Dictionary, groups: Dictionary) -> void:
	for child in node.get_children():
		var spatial := child as Node3D
		if spatial == null or not spatial.visible:
			continue
		if child is MeshInstance3D and _mergeable(child as MeshInstance3D, kept):
			var mesh_node := child as MeshInstance3D
			var material := _merged_material(mesh_node)
			var key := "%d/%s/%d" % [group_root.get_instance_id(), material.resource_name, mesh_node.cast_shadow]
			if not groups.has(key):
				groups[key] = {"root": group_root, "material": material, "shadow": mesh_node.cast_shadow, "parts": []}
			(groups[key]["parts"] as Array).append([mesh_node, to_group * mesh_node.transform])
			continue
		if child is MeshInstance3D or child.get_meta_list().size() > 0:
			# Left alone, but its children can still be merged among themselves.
			_collect(child, spatial, Transform3D.IDENTITY, kept, groups)
			continue
		if _is_group(child, group_root, kept):
			_collect(child, spatial, Transform3D.IDENTITY, kept, groups)
		else:
			_collect(child, group_root, to_group * spatial.transform, kept, groups)


static func _mergeable(mesh_node: MeshInstance3D, kept: Dictionary) -> bool:
	if kept.has(mesh_node) or not _auto_named(mesh_node) or mesh_node.get_child_count() > 0:
		return false
	if mesh_node.get_meta_list().size() > 0 or mesh_node.mesh == null or mesh_node.mesh.get_surface_count() != 1:
		return false
	if mesh_node.skeleton != NodePath("") and mesh_node.has_node(mesh_node.skeleton) and mesh_node.skeleton != NodePath(".."):
		return false
	var mesh := mesh_node.mesh
	if mesh is ArrayMesh:
		if (mesh as ArrayMesh).surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES:
			return false
	elif not mesh is PrimitiveMesh or mesh is PointMesh:
		return false
	var material := mesh_node.material_override as StandardMaterial3D
	if material == null:
		return false
	if material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or material.emission_enabled:
		return false
	if material.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL or material.albedo_texture != null:
		return false
	return true


## One shared vertex-coloured material per look (roughness, shine, sides).
static func _merged_material(mesh_node: MeshInstance3D) -> StandardMaterial3D:
	var source := mesh_node.material_override as StandardMaterial3D
	var key := "r%.2f s%.2f m%.2f c%d" % [source.roughness, source.metallic_specular, source.metallic, source.cull_mode]
	if _materials.has(key):
		return _materials[key]
	var made := StandardMaterial3D.new()
	made.resource_name = key
	made.vertex_color_use_as_albedo = true
	made.vertex_color_is_srgb = true
	made.roughness = source.roughness
	made.metallic_specular = source.metallic_specular
	made.metallic = source.metallic
	made.cull_mode = source.cull_mode
	_materials[key] = made
	return made


static func _merge(parts: Array) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	for part: Array in parts:
		var mesh_node := part[0] as MeshInstance3D
		var place: Transform3D = part[1]
		var arrays := mesh_node.mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var faces: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var painted: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var order: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var material := mesh_node.material_override as StandardMaterial3D
		var tint := Color.WHITE if material.vertex_color_use_as_albedo else material.albedo_color
		var turn := place.basis.inverse().transposed()
		var count := order.size() if order.size() > 0 else points.size()
		for step in count:
			var index := order[step] if order.size() > 0 else step
			vertices.append(place * points[index])
			normals.append((turn * faces[index]).normalized() if faces.size() > index else Vector3.UP)
			colours.append(painted[index] * tint if painted.size() > index else tint)
	if vertices.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	var merged := ArrayMesh.new()
	merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return merged


## The meshes drawn under root and their triangles, for performance budgets.
static func count(root: Node) -> Dictionary:
	var meshes := 0
	var triangles := 0
	for found in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := found as MeshInstance3D
		if mesh_node.mesh == null or not mesh_node.is_visible_in_tree():
			continue
		meshes += 1
		for surface in mesh_node.mesh.get_surface_count():
			var arrays := mesh_node.mesh.surface_get_arrays(surface)
			var order: Variant = arrays[Mesh.ARRAY_INDEX]
			var size := (order as PackedInt32Array).size() if order != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			triangles += size / 3
	return {"meshes": meshes, "triangles": triangles}
