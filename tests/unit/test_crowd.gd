extends TestCase
## Nobody walks through anybody, or through a wall, a bed or a desk: people
## go around furniture and each other, wait or step aside when someone is in
## the way, and are never put down on top of someone. Whole days are played
## frame by frame and any frame with two bodies in one place fails.

const SAVE := "user://test_crowd/save.json"
const STEP := 1.0 / 30.0

var _found := {}


func _rig(at: Vector2) -> AvatarRig:
	var rig := AvatarRig.new(AvatarConfig.new())
	add_node(rig)
	rig.global_position = Vector3(at.x, 0, at.y)
	return rig


func _room() -> WalkArea:
	var area := WalkArea.new(Rect2(-5, -5, 10, 10))
	area.add_blocker(Rect2(-0.5, -3, 1, 4))  # a bed in the middle
	return area


func test_a_path_goes_around_a_person_standing_in_the_way() -> void:
	var area := WalkArea.new(Rect2(-5, -5, 10, 10))
	var straight := area.find_path(Vector2(-3, 0), Vector2(3, 0))
	expect_equal(straight.size(), 1, "an empty room is one straight walk")
	var around := area.find_path(Vector2(-3, 0), Vector2(3, 0), PackedVector2Array([Vector2(0, 0)]))
	expect(around.size() > 1, "someone in the middle is walked around")
	var last := Vector2(-3, 0)
	for point in around:
		for step in 10:
			var on := last.lerp(point, step / 10.0)
			expect(on.distance_to(Vector2.ZERO) >= Crowd.GAP * 0.9, "never through them (%s)" % on)
		last = point
	var blocked := area.find_path(Vector2(-3, 0), Vector2(0.2, 0), PackedVector2Array([Vector2(0, 0)]))
	expect(not blocked.is_empty(), "walking up to someone still finds a way")


func test_a_path_goes_around_furniture() -> void:
	var area := _room()
	var path := area.find_path(Vector2(-3, -1), Vector2(3, -1))
	expect(path.size() > 1, "the bed is walked around")
	var last := Vector2(-3, -1)
	for point in path:
		expect(area.line_clear(last, point), "each leg is clear of the bed")
		last = point


func test_steering_steps_aside_and_waits_when_there_is_no_room() -> void:
	var me := _rig(Vector2(0, 0))
	var ahead := _rig(Vector2(0, -0.55))
	var wanted := Vector2(0, -0.1)
	var people: Array[AvatarRig] = [ahead]
	var step := Crowd.steer(me, wanted, people)
	expect(step != Vector2.ZERO, "someone ahead: a way past is found")
	expect((Vector2(0, 0) + step).distance_to(Vector2(0, -0.55)) >= Crowd.GAP, "that keeps the gap")
	expect(step.x > 0.0, "people pass on the same side")
	var boxed: Array[AvatarRig] = [ahead, _rig(Vector2(0.45, -0.3)), _rig(Vector2(-0.45, -0.3)),
			_rig(Vector2(0.55, 0.05)), _rig(Vector2(-0.55, 0.05))]
	expect_equal(Crowd.steer(me, wanted, boxed), Vector2.ZERO, "boxed in: wait")
	var away := Crowd.steer(me, Vector2(0, 0.1), people)
	expect(away != Vector2.ZERO, "walking away from someone is always fine")


func test_a_spot_someone_already_has_moves_to_one_beside_it() -> void:
	var area := _room()
	var taken := _rig(Vector2(2, 2))
	var people: Array[AvatarRig] = [taken]
	var spot := Crowd.free_spot(Vector2(2, 2), people, area)
	expect(spot.distance_to(Vector2(2, 2)) >= Crowd.GAP, "not on top of them")
	expect(spot.distance_to(Vector2(2, 2)) < 1.2, "but close by")
	var on_bed := Crowd.free_spot(Vector2(0, -1), [], area)
	expect(area.is_walkable(on_bed), "a spot on the bed moves off it")
	expect_equal(Crowd.free_spot(Vector2(-3, 3), people, area), Vector2(-3, 3), "a free spot stays")


func test_someone_put_down_on_top_of_someone_is_moved_clear() -> void:
	var area := _room()
	var one := _rig(Vector2(2, 2))
	var two := _rig(Vector2(2.1, 2))
	expect_equal(Crowd.problems([one, two], area).size(), 1, "two people in one spot is a problem")
	expect(Crowd.make_room(two, [one, two], area), "so one of them moves")
	expect(Crowd.problems([one, two], area).is_empty(), "and then there is none")
	var in_bed := _rig(Vector2(0, 0))
	expect_equal(str(Crowd.problems([in_bed], area)[0]["kind"]), "furniture", "standing in a bed is a problem")
	in_bed.lying = true
	expect(Crowd.problems([in_bed], area).is_empty(), "lying in it is not")


func test_a_walk_ends_beside_someone_standing_at_its_end() -> void:
	var area := _room()
	var walker := _rig(Vector2(-3, 3))
	var standing := _rig(Vector2(3, 3))
	var everyone := [walker, standing]
	var route := {"path": Crowd.plan(walker, Vector3(3, 0, 3), everyone, area), "speed": 2.0}
	var done := false
	for frame in 300:
		done = Crowd.advance(walker, route, STEP, everyone, area)
		expect(Crowd.problems(everyone, area).is_empty(), "never inside them (frame %d)" % frame)
		if done:
			break
	expect(done, "the walk ends")
	expect(Crowd.flat(walker).distance_to(Vector2(3, 3)) < 1.0, "next to them")


func test_two_people_walking_at_each_other_pass() -> void:
	var area := WalkArea.new(Rect2(-5, -2, 10, 4))
	var one := _rig(Vector2(-3, 0))
	var two := _rig(Vector2(3, 0))
	var everyone := [one, two]
	var first := {"path": Crowd.plan(one, Vector3(3, 0, 0), [one], area), "speed": 1.6}
	var second := {"path": Crowd.plan(two, Vector3(-3, 0, 0), [two], area), "speed": 1.6}
	var done := [false, false]
	for frame in 400:
		if not done[0]:
			done[0] = Crowd.advance(one, first, STEP, everyone, area)
		if not done[1]:
			done[1] = Crowd.advance(two, second, STEP, everyone, area)
		expect(Crowd.problems(everyone, area).is_empty(), "never through each other (frame %d)" % frame)
		if done[0] and done[1]:
			break
	expect(done[0] and done[1], "both get where they were going")
	expect(Crowd.flat(one).x > 1.5 and Crowd.flat(two).x < -1.5, "past each other")


# --- Whole days, every frame ----------------------------------------------

func _main() -> Main:
	for file: String in ["save.json", "save.json.tmp", "settings.json", "settings.json.tmp"]:
		if FileAccess.file_exists("user://test_crowd/" + file):
			DirAccess.remove_absolute("user://test_crowd/" + file)
	var main := Main.new()
	main.store = SaveStore.new(SAVE)
	main.settings_path = "user://test_crowd/settings.json"
	add_node(main)
	return main


func _rigs(root: Node, found: Array = []) -> Array:
	for child in root.get_children():
		if child is AvatarRig:
			found.append(child)
		elif child is Node3D:
			_rigs(child, found)
	return found


## Notes every overlap on this frame of a screen.
func _check(screen: Node) -> void:
	var overlay: StoryOverlay = screen.get("overlay")
	if overlay != null and overlay.fade_amount() > 0.9:
		return
	var area: WalkArea = screen.get("walk_area")
	var where := str(screen.get("place")) if screen is Ward else ""
	var fixed := []
	if screen is Lobby:
		var lobby := screen as Lobby
		# Sister Grace works behind the desk; the doctor walks in at the door.
		fixed.append(lobby.people["grace"]["rig"])
		if lobby.conversation == "arrival":
			fixed.append(lobby.player)
	for problem in Crowd.problems(_rigs(screen), area if where in ["", "ward"] else null, 0.0, 0.08, fixed):
		var key := "%s day %d: %s %s x %s" % [screen.get_script().get_global_name(),
				int((screen.get("profile") as PlayerProfile).day), problem["kind"], problem["who"], problem["with"]]
		_found[key] = int(_found.get(key, 0)) + 1


func _expect_clear(what: String) -> void:
	var keys := _found.keys()
	keys.sort()
	for key: String in keys:
		expect(false, "%s: %s (%d frames)" % [what, key, _found[key]])
	expect(keys.is_empty(), "%s: nobody inside anybody or anything" % what)
	_found.clear()


func _talk(story_ui: ConversationUi, story: StoryPlayer) -> void:
	if story_ui.is_choosing():
		story.choose(0)
	elif story.is_playing() and not story.is_busy():
		story_ui.tap()


func test_the_first_day_every_frame() -> void:
	var main := _main()
	(main.screen as TitleScreen).new_career_pressed.emit()
	var naming := main.screen as NameScreen
	naming.name_field.text = "Kiran Rao"
	naming._on_name_changed(naming.name_field.text)
	naming._on_next()
	(main.screen as AvatarCreator)._on_done()
	var opening := main.screen as Opening
	opening.skip()
	var lobby := main.screen as Lobby
	expect(lobby != null, "the lobby")
	for id: String in ["", "grace", "nair", "iyer"]:
		if not lobby.story.is_playing() and not id.is_empty():
			lobby.walk_to_person(id)
		for frame in 6000:
			if not lobby.story.is_playing() and (id.is_empty() or lobby._path.is_empty()) and frame > 30:
				break
			_talk(lobby.talk_ui, lobby.story)
			lobby._physics_process(STEP)
			lobby._process(STEP)
			_check(lobby)
	for frame in 600:
		if main.screen != lobby:
			break
		lobby._process(STEP)
		_check(lobby)
	_expect_clear("the lobby")
	var lab := main.screen as SkillsLab
	expect(lab != null, "then the skills lab")
	if lab == null:
		return
	for frame in 3000:
		if not lab.story.is_playing() and lab._gather.is_empty() and lab._intro_in <= 0.0:
			break
		_talk(lab.talk_ui, lab.story)
		lab.update(STEP)
		_check(lab)
	for id: String in TrainingTask.IDS:
		lab.start_station(id)
		for frame in 1800:
			if lab.view != null:
				break
			_talk(lab.talk_ui, lab.story)
			lab.update(STEP)
			_check(lab)
			# After the four theatre needs Dr. Iyer has news first; then the extras.
			if lab.view == null and not lab.story.is_playing() and lab.mode == "walk" and frame % 30 == 29:
				lab.start_station(id)
		lab.play_task(func() -> bool:
			_check(lab)
			return lab.view == null or lab.view.result_open())
		lab.view.done_pressed.emit()
	_expect_clear("the skills lab")
	for frame in 3000:
		if lab.can_go_home() and not lab.story.is_playing() and lab.mode == "walk":
			break
		_talk(lab.talk_ui, lab.story)
		lab.update(STEP)
	lab.go_home()
	for frame in 900:
		if main.screen != lab:
			break
		if lab.mode == "end":
			lab.overlay.skip_end_card()
		lab.update(STEP)
	var theatre := main.screen as Theatre
	expect(theatre != null, "then the theatre")
	if theatre == null:
		return
	theatre.play_until(func() -> bool:
		_check(theatre)
		if theatre.mode == "end":
			theatre.overlay.skip_end_card()
		return main.screen != theatre,
		Theatre.pick_tones(["Ask Rohit", "Allergies", "Explain", "Be straight", "Hold firm"]), AutoPlayer.new(), 900.0)
	_expect_clear("the theatre")
	expect_equal(main.profile.day, 4, "the opening days are done")


func _ward_days(first_day: int, last_day: int, last_reply: bool) -> void:
	var main := _main()
	main.profile.name = "Kiran Rao"
	main.profile.created = true
	main.profile.opening_seen = true
	main.profile.day = first_day
	main.profile.total_xp = 800
	for flag in ["met_iyer", "day1_iyer", "lab_welcome", "training_done", "op_rohit_done", "op_rohit_won"]:
		main.profile.set_flag(flag)
	main.show_hospital()
	var picker := func(offered: Array) -> int: return offered.size() - 1 if last_reply else 0
	var guard := 0
	while main.profile.day <= last_day and guard < 40:
		guard += 1
		var lab := main.screen as SkillsLab
		if lab != null and not lab.drill.is_empty():
			for frame in 150:
				if lab.drill_card != null:
					break
				lab.update(STEP)
				_check(lab)
			lab.drill_card.start_button.pressed.emit()
			lab.play_task(func() -> bool:
				_check(lab)
				return lab.view == null or lab.view.result_open())
			lab.view.done_pressed.emit()
		var ward := main.screen as Ward
		expect(ward != null, "day %d is on the ward" % main.profile.day)
		if ward == null:
			break
		var day := main.profile.day
		ward.play_until(func() -> bool:
			if main.screen == ward:
				_check(ward)
				if ward.mode == "end":
					ward.overlay.skip_end_card()
			return main.screen != ward, picker, AutoPlayer.new(), 2400.0)
		expect(main.profile.day > day, "day %d finishes" % day)
		if main.profile.day == day:
			break
	_expect_clear("days %d to %d" % [first_day, last_day])


func test_ward_days_every_frame_with_the_first_replies() -> void:
	_ward_days(4, 8, false)


func test_ward_days_every_frame_with_the_last_replies() -> void:
	_ward_days(9, 14, true)
