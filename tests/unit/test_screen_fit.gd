extends TestCase
## Every screen shape sees the whole shot: a Mac window, an iPad or an
## iPhone SE is narrower for its height than the iPhones the scenes are
## framed on, so the camera opens up there instead of cutting the sides
## off, and what the player must reach next keeps its tag in sight.

const SIZES := [Vector2i(1688, 780), Vector2i(1334, 750), Vector2i(1440, 900), Vector2i(1280, 800), Vector2i(1024, 768),
	Vector2i(2048, 1536)]


func cleanup() -> void:
	super()
	tree.root.size = Vector2i(1688, 780)


func test_the_view_opens_up_on_narrower_screens() -> void:
	expect_near(FitCamera.fitted(42.0, Vector2(1688, 780)), 42.0, 0.001, "an iPhone sees the shot as framed")
	expect_near(FitCamera.fitted(42.0, Vector2(2532, 1170)), 42.0, 0.001, "and so does a wider one")
	var last := 42.0
	for size: Vector2 in [Vector2(1334, 750), Vector2(1440, 900), Vector2(1024, 768)]:
		var fov := FitCamera.fitted(42.0, size)
		expect(fov > last, "%s: narrower, wider view (%.1f)" % [size, fov])
		last = fov
	expect(FitCamera.fitted(55.0, Vector2(600, 800)) <= FitCamera.WIDEST, "never a fish-eye")
	# As much across as the iPhone: the width seen at the same distance.
	var across := tan(deg_to_rad(FitCamera.fitted(42.0, Vector2(1024, 768)) / 2.0)) * 1024.0 / 768.0
	expect_near(across, tan(deg_to_rad(21.0)) * FitCamera.WIDE_ASPECT, 0.001)


func test_the_camera_refits_when_the_window_changes() -> void:
	tree.root.size = Vector2i(1440, 900)
	var camera := FitCamera.new()
	camera.designed_fov = 44.0
	add_node(camera)
	expect_near(camera.fov, FitCamera.fitted(44.0, Vector2(1440, 900)), 0.001, "a Mac window")
	tree.root.size = Vector2i(1688, 780)
	expect_near(camera.fov, 44.0, 0.001, "resized to a phone's shape, the shot as framed")
	camera.designed_fov = 30.0
	expect_near(camera.fov, 30.0, 0.001, "a new shot takes its own field of view")


func test_every_scene_uses_the_fitting_camera() -> void:
	tree.root.size = Vector2i(1024, 768)
	var profile := PlayerProfile.new()
	profile.name = "Kiran Rao"
	profile.opening_seen = true
	profile.set_flag("met_iyer")
	for scene: Node in [Lobby.new(profile), SkillsLab.new(profile)]:
		add_node(scene)
		var camera: Camera3D = scene.get("camera")
		expect(camera is FitCamera, "%s: the fitting camera" % scene.name)
		expect(camera.fov > 50.0, "%s: wider on an iPad (%.1f)" % [scene.name, camera.fov])


func test_day_one_keeps_the_person_to_meet_in_sight() -> void:
	# On a Mac window Sister Grace stands up by the clock and the pager, so
	# her tag would hide under them: it waits at the edge and takes a click.
	for size: Vector2i in SIZES:
		tree.root.size = size
		var profile := PlayerProfile.new()
		profile.name = "Kiran Rao"
		profile.opening_seen = true
		profile.set_flag("met_iyer")
		var lobby := Lobby.new(profile)
		add_node(lobby)
		for frame in 3:
			lobby._process(1.0 / 60.0)
		var tag: Control = lobby.hud._tags.get("grace")
		expect(tag != null and tag.visible, "%s: Sister Grace's tag shows" % size)
		if tag == null:
			continue
		var screen := lobby.get_viewport().get_visible_rect()
		expect(screen.encloses(Rect2(tag.position, tag.size)), "%s: on the screen" % size)
		expect_equal(lobby.person_at(tag.position + tag.size / 2.0), "grace", "%s: a click on it finds her" % size)
		lobby.get_parent().remove_child(lobby)
		lobby.free()
