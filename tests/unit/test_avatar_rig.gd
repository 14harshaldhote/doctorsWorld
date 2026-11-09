extends TestCase
## The low-poly character built from an avatar look.


func _rig(look: AvatarConfig = null) -> AvatarRig:
	var rig := AvatarRig.new(look)
	rig.set_process(false)
	add_node(rig)
	return rig


func test_default_doctor_has_every_main_part() -> void:
	var rig := _rig()
	for part in ["Model", "Hips", "Torso", "Head", "Face", "Hair", "ShoulderL", "ShoulderR", "KneeL", "KneeR",
			"Coat", "Stethoscope", "Shadow"]:
		expect(rig.joint(part) != null, "missing %s" % part)
	expect(rig.joint("Glasses") == null, "no glasses unless chosen")
	expect(rig.joint("FacialHair") == null, "no beard unless chosen")
	expect(rig.joint("Watch") == null, "no watch unless chosen")


func test_optional_parts_follow_the_look() -> void:
	var look := AvatarConfig.new()
	look.coat = false
	look.stethoscope = false
	look.watch = true
	look.glasses = 3
	look.facial_hair = 5
	var rig := _rig(look)
	expect(rig.joint("Coat") == null, "coat switched off")
	expect(rig.joint("Stethoscope") == null, "stethoscope switched off")
	expect(rig.joint("Watch") != null, "watch switched on")
	expect(rig.joint("Glasses") != null, "glasses chosen")
	expect(rig.joint("FacialHair") != null, "beard chosen")


func test_every_hair_style_and_mood_builds() -> void:
	var rig := _rig()
	for style in AvatarConfig.HAIR_STYLES.size():
		var look := AvatarConfig.new()
		look.hair_style = style
		rig.set_config(look)
		expect(rig.joint("Hair") != null, "hair node for %s" % AvatarConfig.HAIR_STYLES[style])
		expect_between(rig.height_metres(), 1.5, 2.1, "%s height" % AvatarConfig.HAIR_STYLES[style])
	for mood in AvatarConfig.EXPRESSIONS.size():
		rig.set_mood(mood)
		expect(rig.joint("Face").get_node_or_null("Mouth") != null, "mouth for %s" % AvatarConfig.EXPRESSIONS[mood])
	expect_equal(rig.joint("Head").get_children().filter(func(child: Node) -> bool: return child.name == "Face").size(), 1,
		"changing mood replaces the face rather than stacking faces")


func test_taller_choices_make_taller_characters() -> void:
	var rig := _rig()
	var previous := 0.0
	for height in AvatarConfig.HEIGHTS.size():
		var look := AvatarConfig.new()
		look.height = height
		look.hair_style = 1  # buzz cut, so hair volume does not change the height
		rig.set_config(look)
		var now := rig.height_metres()
		expect(now > previous, "height %d (%.3f m) should beat %.3f m" % [height, now, previous])
		previous = now


func test_walking_swings_the_legs_in_opposite_directions() -> void:
	var rig := _rig()
	rig.set_pose(PI / 2, 1.0)
	var left := rig.joint("HipL").rotation.x
	var right := rig.joint("HipR").rotation.x
	expect(absf(left) > 0.3, "left leg swings")
	expect(left * right < 0.0, "legs swing opposite ways")
	rig.set_pose(PI / 2, 0.0)
	expect_near(rig.joint("HipL").rotation.x, 0.0, 0.0001, "standing still")


func test_sitting_bends_hips_and_knees_and_hides_the_floor_shadow() -> void:
	var rig := _rig()
	rig.sitting = true
	rig.set_pose(0.0, 0.0)
	expect(rig.joint("HipL").rotation.x < -1.0, "thighs forward")
	expect(rig.joint("KneeL").rotation.x > 1.0, "knees bent")
	expect(rig.joint("Hips").position.y < AvatarRig.HIP_HEIGHT, "lower when seated")
	expect(not rig.joint("Shadow").visible, "the chair has its own shadow")


func test_meshes_are_faceted() -> void:
	var rig := _rig()
	var skull := rig.joint("Head").get_node("Skull") as MeshInstance3D
	var arrays := skull.mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	expect(normals.size() >= 3 and normals.size() % 3 == 0, "unindexed triangles")
	var flat := 0
	for index in range(0, normals.size(), 3):
		if normals[index].is_equal_approx(normals[index + 1]) and normals[index].is_equal_approx(normals[index + 2]):
			flat += 1
	expect_equal(flat, normals.size() / 3, "every triangle has one normal")


func test_hair_is_painted_on_the_skull_but_not_under_a_headscarf() -> void:
	var look := AvatarConfig.new()
	look.hair_style = 1
	look.hair_colour = 0
	var rig := _rig(look)
	var colours: PackedColorArray = (rig.joint("Head").get_node("Skull") as MeshInstance3D).mesh.surface_get_arrays(0)[
		Mesh.ARRAY_COLOR]
	var skin := look.skin_colour()
	var hair_faces := 0
	for colour in colours:
		if not colour.is_equal_approx(skin):
			hair_faces += 1
	expect(hair_faces > 0, "buzz cut shows on the skull")
	expect(hair_faces < colours.size(), "the face stays skin")
	look.hair_style = 10
	rig.set_config(look)
	colours = (rig.joint("Head").get_node("Skull") as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	for colour in colours:
		if not colour.is_equal_approx(skin):
			failures.append("headscarf skull should be all skin")
			break


func test_fifty_random_looks_build_cleanly() -> void:
	var rng := SeededRandom.new(99)
	var rig := _rig()
	for round in 50:
		var look := AvatarConfig.random(rng)
		rig.set_config(look)
		expect(rig.joint("Head") != null, "look %d built" % round)
		expect_between(rig.height_metres(), 1.45, 2.15, "look %d height" % round)
		if look.facial_hair >= 4:
			var mouth := rig.joint("Face").get_node("Mouth") as Node3D
			var beard_front := rig._beard_front(mouth.position.y)
			expect(mouth.position.z > beard_front, "look %d: mouth sits in front of the beard" % round)


func test_gestures_move_the_arms_and_settle_back() -> void:
	var rig := _rig()
	rig.settle()
	var rest: Vector3 = rig.joint("ShoulderR").rotation
	for gesture: String in AvatarRig.GESTURES:
		rig.set_gesture(gesture)
		rig.settle()
		var moved := rig.joint("ShoulderR").rotation.distance_to(rest) + rig.joint("ShoulderL").rotation.distance_to(rest)
		expect(moved > 0.05, "%s moves an arm" % gesture)
	rig.set_gesture("")
	rig.settle()
	expect(rig.joint("ShoulderR").rotation.distance_to(rest) < 0.05, "arms go back to rest")


func test_unknown_gestures_are_ignored() -> void:
	var rig := _rig()
	rig.set_gesture("moonwalk", "spin")
	expect_equal(rig.gesture, "")
	expect_equal(rig.head_gesture, "")


func test_looking_at_someone_turns_the_head_towards_them() -> void:
	var rig := _rig()
	rig.rotation.y = 0.0
	rig.look_at_point(rig.global_position + Vector3(2, 1.5, 1))
	rig.settle()
	expect(rig.joint("Head").rotation.y > 0.3, "head turns towards a point on the left of the body")
	expect(rig.joint("Torso").rotation.y > 0.05, "the chest follows a little")
	rig.look_at_point(rig.global_position + Vector3(-2, 1.5, 1))
	rig.settle()
	expect(rig.joint("Head").rotation.y < -0.3, "and the other way")
	rig.look_at_point(rig.global_position + Vector3(0, 1.5, -3))
	rig.settle()
	expect(absf(rig.joint("Head").rotation.y) <= 1.15 * 0.75 + 0.01, "no owl turns for someone behind")


func test_speaking_opens_the_mouth_and_it_closes_again() -> void:
	var rig := _rig()
	var mouth: Node3D = rig._mouth
	rig.say_syllable("o")
	rig._process(0.01)
	expect(mouth.scale.y > 1.5, "mouth opens on a syllable")
	for frame in 30:
		rig._process(1.0 / 30.0)
	expect_near(mouth.scale.y, 1.0, 0.01, "and closes when the line is over")


func test_outfits_for_the_story() -> void:
	var rig := _rig()
	rig.outfit = "gown"
	rig.build()
	expect(rig.find_child("Gown", true, false) != null, "graduation gown")
	expect(rig.joint("Mortarboard") != null, "with the cap")
	expect(rig.joint("Coat") == null, "no lab coat under the gown")
	rig.mortarboard = false
	rig.build()
	expect(rig.joint("Mortarboard") == null, "the cap can stay off")
	rig.outfit = "kurta"
	rig.build()
	expect(rig.find_child("Tunic", true, false) != null, "kurta")
	rig.outfit = "doctor"
	rig.build()
	expect(rig.joint("Coat") != null, "back in the lab coat")


func test_props_go_in_the_hands_and_survive_a_rebuild() -> void:
	var rig := _rig()
	for item: String in Props.ITEMS:
		rig.hold(item)
		expect_equal(rig.held(), item)
		expect(rig.joint("ElbowR").get_node_or_null("HeldR") != null, "%s is in the hand" % item)
	rig.hold("coffee", "L")
	rig.build()
	expect_equal(rig.held("L"), "coffee", "still holding the coffee after a rebuild")
	expect(rig.joint("ElbowL").get_node_or_null("HeldL") != null, "the cup is back in the new hand")
	rig.drop("L")
	rig.drop("R")
	expect_equal(rig.held("L"), "")
	expect(rig.joint("ElbowR").get_node_or_null("HeldR") == null, "hands empty")
