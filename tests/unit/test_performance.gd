extends TestCase
## Older iPhones: every scene stays inside a budget of meshes (draw calls)
## and triangles, and merging the pieces that never move changes nothing
## you can see or touch.

## Most meshes and triangles each scene may draw after merging. Before
## merging these scenes drew 460 to 730 meshes each.
const BUDGETS := {
	"title": [110, 8000],
	"lobby": [350, 24000],
	"lab": [280, 22000],
	"theatre": [260, 20000],
	"ward": [380, 26000],
	"opening": [320, 30000],
}


func _doctor(day: int, flags: Array = []) -> PlayerProfile:
	var doctor := PlayerProfile.new()
	doctor.name = "Asha Verma"
	doctor.created = true
	doctor.opening_seen = true
	doctor.day = day
	doctor.total_xp = 800
	for flag: String in flags:
		doctor.set_flag(flag)
	return doctor


func _within_budget(label: String, root: Node) -> void:
	var counted := StaticBatch.count(root)
	var budget: Array = BUDGETS[label]
	expect(int(counted["meshes"]) <= int(budget[0]), "%s draws %d meshes (budget %d)" % [label, counted["meshes"], budget[0]])
	expect(int(counted["triangles"]) <= int(budget[1]),
		"%s draws %d triangles (budget %d)" % [label, counted["triangles"], budget[1]])


func test_every_scene_stays_within_its_budget() -> void:
	_within_budget("title", add_node(HospitalFront.new()))
	_within_budget("lobby", add_node(Lobby.new(_doctor(1, ["met_iyer"]))))
	_within_budget("lab", add_node(SkillsLab.new(_doctor(2, ["met_iyer"]))))
	_within_budget("theatre", add_node(Theatre.new(_doctor(3))))
	_within_budget("ward", add_node(Ward.new(_doctor(4, ["op_rohit_done", "op_rohit_won"]))))
	var opening := add_node(Opening.new(_doctor(1))) as Opening
	_within_budget("opening", opening.current_set)


func test_merging_halves_the_meshes_and_keeps_every_triangle() -> void:
	StaticBatch.enabled = false
	var ward := add_node(Ward.new(_doctor(4, ["op_rohit_done", "op_rohit_won"]))) as Ward
	StaticBatch.enabled = true
	var before := StaticBatch.count(ward)
	var saved := StaticBatch.optimise(ward)
	var after := StaticBatch.count(ward)
	expect(saved > int(before["meshes"]) * 0.35, "merging saves %d of %d meshes" % [saved, before["meshes"]])
	expect_equal(after["meshes"], int(before["meshes"]) - saved)
	expect_equal(after["triangles"], before["triangles"], "not one triangle lost")
	expect_equal(StaticBatch.optimise(ward), 0, "merging twice changes nothing more")


func test_merged_meshes_keep_their_colours_and_places() -> void:
	var room := add_node(Node3D.new()) as Node3D
	var red := LowPoly.box(Vector3.ONE, Color("#C0392B"))
	LowPoly.put(room, red, Vector3(2, 0, 0))
	var blue := LowPoly.box(Vector3.ONE, Color("#2E86C1"))
	LowPoly.put(room, blue, Vector3(-2, 1, 0))
	blue.rotation.y = PI / 4
	var shelf := Node3D.new()
	shelf.position = Vector3(0, 3, 0)
	room.add_child(shelf)
	var green := LowPoly.box(Vector3(0.5, 0.5, 0.5), Color("#27AE60"))
	LowPoly.put(shelf, green, Vector3(0, 0, 1))
	var box := Vector3(-2.71, -0.5, -0.71)
	expect_equal(StaticBatch.optimise(room), 2, "three boxes become one mesh")
	var batches := room.find_children("Batch*", "MeshInstance3D", true, false)
	expect_equal(batches.size(), 1)
	if batches.is_empty():
		return
	var merged := batches[0] as MeshInstance3D
	expect(merged.material_override.vertex_color_use_as_albedo, "colours move into the vertices")
	var arrays := merged.mesh.surface_get_arrays(0)
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for colour: Color in [Color("#C0392B"), Color("#2E86C1"), Color("#27AE60")]:
		expect(colours.has(colour), "keeps %s" % colour.to_html(false))
	var bounds := merged.get_aabb()
	expect(bounds.position.distance_to(box) < 0.01, "the boxes stay where they were (%s)" % bounds.position)
	expect_near(bounds.end.y, 3.25, 0.001, "including the one on the shelf")


func test_what_can_change_is_never_merged() -> void:
	var room := add_node(Node3D.new()) as Node3D
	var plain: Array[MeshInstance3D] = []
	for index in 2:
		var part := LowPoly.box(Vector3.ONE * 0.2, Color("#AAAAAA"))
		LowPoly.put(room, part, Vector3(index, 0, 0))
		plain.append(part)
	var named := LowPoly.box(Vector3.ONE * 0.2, Color("#AAAAAA"))
	named.name = "Glass"
	room.add_child(named)
	var glowing := LowPoly.box(Vector3.ONE * 0.2, Color("#AAAAAA"))
	glowing.material_override = LowPoly.glow(Color("#BFE7F0"))
	room.add_child(glowing)
	var hidden := LowPoly.box(Vector3.ONE * 0.2, Color("#AAAAAA"))
	hidden.visible = false
	room.add_child(hidden)
	var marked := LowPoly.box(Vector3.ONE * 0.2, Color("#AAAAAA"))
	marked.set_meta("inside", true)
	room.add_child(marked)
	StaticBatch.optimise(room)
	for part in plain:
		expect(not is_instance_valid(part), "plain pieces are merged")
	for kept: MeshInstance3D in [named, glowing, hidden, marked]:
		expect(is_instance_valid(kept) and kept.get_parent() == room, "%s is left alone" % kept.name)


func test_characters_keep_their_joints_and_moving_parts() -> void:
	var holder := add_node(Node3D.new()) as Node3D
	var rig := AvatarRig.new()
	holder.add_child(rig)
	var height := rig.height_metres()
	var head := rig.joint("Head")
	var head_triangles := int(StaticBatch.count(head)["triangles"])
	var before := int(StaticBatch.count(rig)["meshes"])
	StaticBatch.optimise(holder)
	expect(int(StaticBatch.count(rig)["meshes"]) < before, "the character draws fewer meshes")
	expect(is_instance_valid(head) and rig.joint("Head") == head, "joints are untouched")
	expect_equal(int(StaticBatch.count(head)["triangles"]), head_triangles, "the head keeps everything on it")
	expect_near(rig.height_metres(), height, 0.001, "the character is the same height")
	for eye in rig._eyes:
		expect(is_instance_valid(eye), "eyes still blink")
	rig.set_mood(AvatarConfig.Mood.HAPPY)
	rig.moving = 1.0
	rig._process(0.1)
	expect(rig.joint("Face") != null, "the face can still change")


func test_night_and_the_operation_still_change_after_merging() -> void:
	var ward := add_node(Ward.new(_doctor(6, ["op_rohit_done", "op_rohit_won", "beds_checked", "banerjee_room"]))) as Ward
	var windows := ward.find_children("Window", "", false, false)
	expect(not windows.is_empty(), "the ward has windows")
	for window in windows:
		expect(window.get_node_or_null("Glass") != null, "each window keeps its glass for the night")
	ward._set_night(true)
	for lamp in ward._lamps:
		expect(lamp.visible, "the night lamps come on")
	var theatre := add_node(Theatre.new(_doctor(3))) as Theatre
	var table := theatre.stations["appendix"] as OperatingTable
	var inside := 0
	for child in table.get_children():
		if child.has_meta("inside"):
			inside += 1
	expect(inside > 0, "the parts inside the patient are still there to show")
	expect(is_instance_valid(table._wound) and is_instance_valid(table._appendix_up), "and the wound and appendix")
