extends TestCase
## Casualty inside the game (stage 22): through the ward's door, patients
## on the benches and in the cubicles, the patient card, the clock that runs
## while the doctor is free, late story beats and handing over.

const CAREFUL := ["Ready", "Honest", "Reassure", "Ask her", "Check", "Own it", "Calm", "Compromise", "To Aarav", "Gentle",
	"Careful", "Stay", "Patient first", "Answer", "Light", "Ask him", "The facts", "Grateful"]
const STEP := 1.0 / 30.0


func _ward(day: int = 4) -> Ward:
	var doctor := PlayerProfile.new()
	doctor.name = "Asha Verma"
	doctor.day = day
	doctor.opening_seen = true
	doctor.created = true
	doctor.total_xp = 800
	doctor.set_count("hospital_seed", 4242)
	for flag: String in ["op_rohit_done", "op_rohit_won"]:
		doctor.set_flag(flag)
	return add_node(Ward.new(doctor)) as Ward


## Plays to the first walk of the day (Rohit's bed on Day 4).
func _to_first_walk(ward: Ward) -> void:
	ward.play_until(func() -> bool: return ward.mode == "walk", Ward.pick_tones(CAREFUL))


func _frames(ward: Ward, seconds: float) -> void:
	for frame in int(seconds / STEP):
		ward.update(STEP)


## Walks until the doctor has arrived where the walk was heading.
func _walk_until(ward: Ward, done: Callable, seconds: float = 30.0) -> bool:
	for frame in int(seconds / STEP):
		if bool(done.call()):
			return true
		ward.update(STEP)
	return bool(done.call())


func _to_casualty(ward: Ward) -> void:
	_to_first_walk(ward)
	ward._walk_to_door()
	_walk_until(ward, func() -> bool: return ward.place == "casualty")


func test_casualty_opens_on_the_first_ward_day_and_not_before() -> void:
	expect(not ShiftDay.open(3), "not before the ward")
	expect(ShiftDay.open(4) and ShiftDay.open(400), "from Day 4, for ever")
	expect_near(ShiftDay.load_for(4), 0.5, 0.001, "a quiet first day")
	expect(ShiftDay.load_for(9) > ShiftDay.load_for(5), "busier as the days go on")
	expect_near(ShiftDay.load_for(20), 1.0, 0.001, "a normal day by Day 14")
	expect(ShiftDay.load_for(200) <= ShiftDay.MOST, "never more than the most")
	var ward := _ward()
	expect(ward.shift != null, "Day 4 has a casualty")
	expect_equal(ward.shift.minute, PlayerProfile.DAY_START, "starting with the day")
	expect_equal(str(ward.beats[-1]["id"]), "sign_off", "the day ends with handing over")


func test_each_career_has_its_own_hospital_and_a_restart_keeps_it() -> void:
	var doctor := PlayerProfile.new()
	doctor.day = 5
	doctor.begin_day()
	var first := ShiftDay.hospital_seed(doctor)
	expect(first > 0, "a seed is made")
	expect_equal(ShiftDay.hospital_seed(doctor), first, "and kept")
	expect_equal(int((doctor.morning["counters"] as Dictionary)["hospital_seed"]), first, "in the morning too")
	doctor.begin_day()
	expect_equal(ShiftDay.hospital_seed(doctor), first, "a day started again keeps the same hospital")
	expect(ShiftDay.seed_for(doctor, 5) != ShiftDay.seed_for(doctor, 6), "each day is different")
	var other := PlayerProfile.new()
	other.set_count("hospital_seed", first + 1)
	expect(ShiftDay.seed_for(other, 5) != ShiftDay.seed_for(doctor, 5), "another career, another hospital")


func test_the_clock_runs_only_while_the_doctor_is_free() -> void:
	var ward := _ward()
	for frame in 100:
		ward.update(STEP)
	expect_equal(ward.conversation, "handover")
	var talking_at := ward.profile.minutes
	_frames(ward, 20.0)
	expect_equal(ward.profile.minutes, talking_at, "no time passes in a conversation")
	_to_first_walk(ward)
	var walking_at := ward.profile.minutes
	_frames(ward, 20.0)
	expect_between(ward.profile.minutes - walking_at, 9, 11, "about half a hospital minute a second while free")
	ward.hud.open_settings()
	var menu_at := ward.profile.minutes
	_frames(ward, 20.0)
	expect_equal(ward.profile.minutes, menu_at, "none behind a menu")


func test_the_door_takes_the_doctor_to_casualty_and_back() -> void:
	var ward := _ward()
	_to_first_walk(ward)
	expect(ward._door_tapped(ward.camera.unproject_position(Ward.DOOR)), "the door can be tapped")
	ward._walk_to_door()
	expect(_walk_until(ward, func() -> bool: return ward.place == "casualty"), "through the door")
	expect(ward.casualty.visible, "casualty shows")
	expect(not ward.theatre_set.visible and not ward.seminar.visible, "nothing else does")
	expect(ward.player.global_position.y < Ward.CASUALTY_AT.y + 0.5, "the doctor is down there")
	expect(ward.hud.hint_text().contains("Ward 4"), "the hint says how to get back")
	expect(ward.toasts_waiting().size() > 0 or ward.profile.has_flag("casualty_intro"), "a word on what casualty is")
	expect(ward.hud.pager_text().contains("Bed one"), "the story's page still shows")
	ward._tap_casualty(ward.camera.unproject_position(ward.casualty.door_spot()))
	expect(_walk_until(ward, func() -> bool: return ward.place == "ward"), "back through the door")
	expect(not ward.casualty.visible, "casualty hidden again")
	expect(ward.player.global_position.y > -0.5, "on the ward floor")
	expect_equal(ward._go_place(), "bed1", "the story waits where it was")
	expect(ward.hud.hint_text().contains("Bed 1"), "and the hint points there again")


func test_patients_wait_on_the_benches_and_bodies_are_built_one_a_frame() -> void:
	var ward := _ward(9)
	_to_first_walk(ward)
	ward.profile.minutes += 120
	ward._catch_up()
	var waiting := ward.shift.waiting().size()
	expect(waiting >= 2, "a couple of hours bring a few people: %d" % waiting)
	ward._walk_to_door()
	_walk_until(ward, func() -> bool: return ward.place == "casualty")
	var built := ward.casualty.rigs_built()
	ward.update(STEP)
	expect(ward.casualty.rigs_built() - built <= 1, "one body a frame at most")
	_frames(ward, 1.0)
	for patient in ward.shift.waiting():
		var rig := ward.casualty.rig_of(patient)
		expect(rig != null, "%s has a body" % patient.full_name())
		expect(rig != null and rig.sitting, "sitting on a bench")
	var seats := {}
	for seat in CasualtyRoom.SEATS.size():
		var patient := ward.casualty.patient_in_seat(seat)
		if patient != null:
			expect(not seats.has(patient.id), "one seat each")
			seats[patient.id] = true
	expect_equal(seats.size(), ward.shift.waiting().size(), "everyone waiting has a seat")
	expect(ward.hud.hint_text().contains("Tap someone"), "the hint says what to do")


func test_seeing_a_patient_from_the_bench_to_the_plan() -> void:
	var ward := _ward(9)
	_to_first_walk(ward)
	ward.profile.minutes += 90
	ward._catch_up()
	ward._walk_to_door()
	_walk_until(ward, func() -> bool: return ward.place == "casualty")
	_frames(ward, 1.0)
	var patient: ShiftPatient = ward.shift.board()[0]
	if patient.state != "waiting":
		patient = ward.shift.waiting()[0]
	_frames(ward, 0.5)
	expect(ward.see_patient(patient), "taken to a cubicle")
	expect_equal(patient.state, "seeing")
	expect(_walk_until(ward, func() -> bool: return ward.panel != null), "the doctor walks over and the card opens")
	expect_equal(ward.mode, "patient")
	expect(ward.casualty.rig_of(patient).lying, "the patient is lying on the trolley")
	var panel := ward.panel
	expect(panel.find_child("Name", true, false) != null, "the card names them")
	var clock := ward.profile.minutes
	_frames(ward, 10.0)
	expect_equal(ward.profile.minutes, clock, "reading the card costs no time")
	panel.button("Ask_pain").pressed.emit()
	expect_equal(ward.profile.minutes, clock + ShiftSim.ASK_MINUTES, "a question costs two minutes")
	expect(panel.find_child("Answer_pain", true, false) != null, "and the answer shows")
	panel.button("Examine").pressed.emit()
	expect_equal(ward.profile.minutes, clock + ShiftSim.ASK_MINUTES + ShiftSim.EXAM_MINUTES)
	expect(panel.find_child("Finding", true, false) != null, "the finding shows")
	for test: String in patient.condition.get("key", []):
		panel.button("Test_" + test).pressed.emit()
	expect_equal(patient.ordered.size(), (patient.condition.get("key", []) as Array).size(), "the key tests are sent")
	var position := ShiftBot.position_of(patient, true)
	panel.button("Plan%d" % (position + 1)).pressed.emit()
	expect(panel.confirm_button.visible, "a plan picked waits for confirming")
	var xp := ward.profile.total_xp
	panel.confirm_button.pressed.emit()
	expect(panel.showing_result(), "the result shows")
	_frames(ward, 2.0)
	expect(ward.casualty.rig_of(patient) != null and ward.casualty.rig_of(patient).lying,
		"they stay on the trolley while the doctor reads the result")
	expect(panel.done_button.visible and not panel.close_button.visible, "with Done")
	expect_equal(patient.outcome, "better")
	expect(ward.profile.total_xp > xp, "experience for it")
	expect_equal(ward.profile.count("casualty_seen"), 1)
	expect_equal(ward.profile.count("casualty_right"), 1)
	expect_equal(ward.casualty_xp, ward.profile.total_xp - xp)
	panel.done_button.pressed.emit()
	expect(ward.panel == null and ward.mode == "walk", "back to walking")
	_frames(ward, 20.0)
	expect(ward.casualty.rig_of(patient) == null, "the patient has gone out of the door")
	expect(ward.shift.free_cubicle() >= 0, "the cubicle is free")


func test_stepping_away_leaves_the_patient_in_their_cubicle() -> void:
	var ward := _ward(10)
	_to_first_walk(ward)
	ward.profile.minutes += 90
	ward._catch_up()
	_to_casualty_now(ward)
	var patient: ShiftPatient = ward.shift.waiting()[0]
	ward.see_patient(patient)
	_walk_until(ward, func() -> bool: return ward.panel != null)
	ward.panel.button("StepAway").pressed.emit()
	expect(ward.panel == null and ward.mode == "walk", "the card closes")
	expect_equal(patient.state, "seeing", "they stay in the cubicle")
	expect(ward.see_patient(patient), "and can be seen again")
	expect(_walk_until(ward, func() -> bool: return ward.panel != null), "the card opens again")


func _to_casualty_now(ward: Ward) -> void:
	ward._walk_to_door()
	_walk_until(ward, func() -> bool: return ward.place == "casualty")
	_frames(ward, 1.0)


func test_full_cubicles_say_so() -> void:
	var ward := _ward(12)
	_to_first_walk(ward)
	_to_casualty_now(ward)
	for index in ShiftSim.CUBICLES + 1:
		var patient := ward.shift.make_patient("gastro")
		ward.shift.patients.append(patient)
	for index in ShiftSim.CUBICLES:
		expect(ward.shift.take(ward.shift.waiting()[0]))
	ward._toasts.clear()
	expect(not ward.see_patient(ward.shift.waiting()[0]), "no cubicle free")
	expect(ward.toasts_waiting()[0].contains("cubicles are busy"), "and the doctor is told")


func test_a_patient_crashing_while_seen_closes_the_card() -> void:
	var ward := _ward(12)
	_to_first_walk(ward)
	_to_casualty_now(ward)
	var patient := ward.shift.make_patient("heart_attack")
	ward.shift.patients.append(patient)
	ward.see_patient(patient)
	_walk_until(ward, func() -> bool: return ward.panel != null)
	patient.severity = ShiftSim.CRASH_AT - 0.1
	ward.panel.button("Test_ct").pressed.emit()
	expect(patient.outcome in ["crashed", "died"], "they crash (%s)" % patient.outcome)
	expect(ward.panel == null and ward.mode == "walk", "the card closes")
	if patient.outcome == "crashed":
		expect(ward.toasts_waiting().any(func(text: String) -> bool: return text.contains("crashed")), "and the pager says why")
	else:
		_frames(ward, 0.2)
		expect(ward.family_card() != null, "and the family is waiting")
		expect_equal(ward.profile.wall.size(), 1, "and the name is on the wall")


func test_casualty_news_reaches_the_doctor_on_the_ward_only_when_it_matters() -> void:
	var ward := _ward(12)
	_to_first_walk(ward)
	ward._toasts.clear()
	var calm := ward.shift.make_patient("gastro")
	ward._on_shift_event({"kind": "arrived", "patient": calm, "text": "New in casualty: someone."})
	expect(ward.toasts_waiting().is_empty(), "a tummy bug doesn't page the ward")
	var red := ward.shift.make_patient("heart_attack")
	ward._on_shift_event({"kind": "arrived", "patient": red, "text": "Red in casualty: someone."})
	ward._on_shift_event({"kind": "worse", "patient": red, "text": "Someone looks worse."})
	ward._on_shift_event({"kind": "crashed", "patient": red, "text": "Someone crashed."})
	ward._on_shift_event({"kind": "worse", "patient": red, "text": "Another looks worse."})
	expect_equal(ward.toasts_waiting().size(), Ward.TOAST_QUEUE, "a few at a time")
	expect(not ward.toasts_waiting().has("Red in casualty: someone."), "the least important goes first")
	expect(ward.toasts_waiting().has("Someone crashed."), "a crash is always told")
	_frames(ward, Ward.TOAST_GAP * 4)
	expect(ward.toasts_waiting().is_empty(), "and they're shown in turn")


func test_a_story_beat_left_waiting_is_late_and_costs_a_little() -> void:
	var ward := _ward()
	_to_first_walk(ward)
	ward.profile.minutes += Ward.LATE_AFTER + 15
	ward._toasts.clear()
	ward.go_to(ward._go_place())
	expect(_walk_until(ward, func() -> bool: return ward.conversation == "rohit_round"), "Rohit's round starts")
	expect_equal(ward.late_beats, 1, "late once")
	expect(ward.toasts_waiting().any(func(text: String) -> bool: return text.contains("waiting")), "and told so")
	var finished := [false]
	ward.day_finished.connect(func() -> void: finished[0] = true)
	var xp := ward.profile.total_xp
	expect(ward.play_until(func() -> bool: return finished[0], Ward.pick_tones(CAREFUL)), "the day still ends")
	expect_equal(ward.shift_xp, Ward.SHIFT_XP - Ward.LATE_XP, "the shift pays a little less")
	expect(ward.profile.total_xp >= xp + ward.shift_xp, "but it pays")


func test_handing_over_ends_the_day_whenever_the_doctor_likes() -> void:
	var ward := _ward()
	var finished := [false]
	ward.day_finished.connect(func() -> void: finished[0] = true)
	ward.play_until(func() -> bool: return str(ward.beat().get("id", "")) == "sign_off" and ward.mode == "walk",
		Ward.pick_tones(CAREFUL))
	expect_equal(str(ward.beat()["id"]), "sign_off", "the story is done")
	expect(ward.hud.pager_text().contains("Hand over"), "Grace says to hand over")
	expect(ward.hud.hint_text().contains("casualty"), "and casualty is still there")
	_frames(ward, 30.0)
	expect(not finished[0], "the day waits for the doctor")
	expect(ward.play_until(func() -> bool: return finished[0], Ward.pick_tones(CAREFUL)), "hand over ends it")
	expect(ward.profile.has_flag("ward_day4"), "the day counts")


func test_the_free_clock_stops_at_the_end_of_the_shift() -> void:
	var ward := _ward(9)
	_to_first_walk(ward)
	ward.profile.minutes = ShiftDay.DAY_END - 1
	_frames(ward, 30.0)
	expect_equal(ward.profile.minutes, ShiftDay.DAY_END, "the clock stops at 20:00")
	expect(ward.toasts_waiting().any(func(text: String) -> bool: return text.contains("shift's over"))
		or ward._shift_over_said, "and says so")


## The card's shape: pinned to the right edge, top to bottom, never more
## than about half the screen, its words in a scroll so a long card can't
## push it off screen, and every button big enough for a thumb. (How it
## really lays out is checked in the screenshots, which run real frames.)
func test_the_patient_card_fits_every_screen() -> void:
	var text_before := GameSettings.current.text_size
	for case: Array in [[Vector2i(1688, 780), 1], [Vector2i(1334, 750), 2], [Vector2i(1366, 1024), 2], [Vector2i(1280, 800), 0]]:
		var size: Vector2i = case[0]
		GameSettings.current.text_size = int(case[1])
		tree.root.size = size
		var ward := _ward(12)
		_to_first_walk(ward)
		_to_casualty_now(ward)
		var patient := ward.shift.make_patient("appendicitis")
		ward.shift.patients.append(patient)
		ward.see_patient(patient)
		_walk_until(ward, func() -> bool: return ward.panel != null)
		ward.panel.button("Ask_pain").pressed.emit()
		var sheet := ward.panel.sheet
		var screen := ward.get_viewport().get_visible_rect().size
		expect(is_equal_approx(sheet.anchor_left, 1.0) and is_equal_approx(sheet.anchor_right, 1.0), "%s: on the right" % size)
		expect(is_zero_approx(sheet.anchor_top) and is_equal_approx(sheet.anchor_bottom, 1.0), "%s: top to bottom" % size)
		expect(-sheet.offset_left <= screen.x * 0.62 + UiKit.px(12) + 1.0, "%s: the patient stays in view beside it" % size)
		expect(sheet.offset_top >= 0.0 and sheet.offset_bottom <= 0.0, "%s: inside the screen" % size)
		var scroll := ward.panel.find_child("Scroll", true, false) as ScrollContainer
		expect(scroll != null and scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED,
			"%s: the card's words scroll" % size)
		expect(scroll.get_combined_minimum_size().y < 1.0, "%s: so they never make the card taller" % size)
		for child in ward.panel.find_children("*", "Button", true, false):
			var button := child as Button
			if button.visible:
				expect(button.custom_minimum_size.y >= UiKit.px(38), "%s: %s is big enough to tap" % [size, button.name])
		ward.queue_free()
	GameSettings.current.text_size = text_before
	tree.root.size = Vector2i(1688, 780)


func test_casualty_costs_little_per_frame() -> void:
	var ward := _ward(30)
	_to_first_walk(ward)
	ward.profile.minutes += 180
	ward._catch_up()
	_to_casualty_now(ward)
	_frames(ward, 3.0)
	var started := Time.get_ticks_usec()
	var frames := 300
	for frame in frames:
		ward._tick_shift(STEP)
	var per_frame := (Time.get_ticks_usec() - started) / 1000.0 / frames
	expect(per_frame < 1.0, "casualty's own work is %.3f ms a frame" % per_frame)


func test_people_wait_facing_the_camera_and_newcomers_walk_in_through_the_door() -> void:
	var ward := _ward(12)
	_to_first_walk(ward)
	_only_these(ward)
	for index in 2:
		ward.shift.patients.append(ward.shift.make_patient("gastro"))
	_to_casualty_now(ward)
	for patient in ward.shift.waiting():
		var rig := ward.casualty.rig_of(patient)
		expect(rig.sitting, "already waiting: sitting down, not walking in")
		expect_near(rig.rotation.y, 0.0, 0.01, "facing out of the room, so their faces show")
	var newcomer := ward.shift.make_patient("wrist_fracture")
	ward.shift.patients.append(newcomer)
	ward.update(STEP)
	var rig := ward.casualty.rig_of(newcomer)
	expect(rig != null and not rig.sitting, "someone new is on their feet")
	expect(rig != null and rig.position.x > 5.5, "coming in at the door")
	expect(ward.casualty.seat_of(newcomer) < 0, "not sat down yet")
	expect(_walk_until(ward, func() -> bool: return ward.casualty.seat_of(newcomer) >= 0, 20.0), "over to a seat")
	expect(rig.sitting, "and sitting")
	var seats := {}
	for patient in ward.shift.waiting():
		var seat := ward.casualty.seat_of(patient)
		expect(seat >= 0 and not seats.has(seat), "a seat each")
		seats[seat] = true


func test_the_camera_takes_in_the_benches_and_the_cubicles() -> void:
	var ward := _ward(12)
	_to_first_walk(ward)
	_to_casualty_now(ward)
	var screen := ward.camera.get_viewport().get_visible_rect()
	for spot: Vector3 in [CasualtyRoom.DOOR + Vector3(-0.5, 0, 0), Vector3(-5.0, 0, -0.6), Vector3(0, 0, 0.8)]:
		ward.player.position = ward.casualty.world(spot)
		ward.settle_camera()
		var x := clampf(spot.x, -3.6, 3.6)
		var bench := ward.camera.unproject_position(ward.casualty.world(Vector3(x, 1.3, CasualtyRoom.SEATS[0].z)))
		var feet := ward.camera.unproject_position(ward.casualty.world(Vector3(x, 0.45, CasualtyRoom.SEATS[0].z + 0.3)))
		var trolley := ward.camera.unproject_position(ward.casualty.world(Vector3(x, 1.75, CasualtyRoom.TROLLEY_AT.z)))
		expect(screen.has_point(bench) and screen.has_point(feet), "the people on the benches are in view (from %s)" % spot)
		expect(screen.has_point(trolley), "and so are the cubicles behind (from %s)" % spot)
		expect(bench.y < screen.size.y * 0.8, "clear of the buttons at the bottom")
		expect(trolley.y > screen.size.y * 0.15, "and of the top of the screen")


func test_the_board_is_short_and_the_tags_never_pile_up() -> void:
	var ward := _ward(12)
	_to_first_walk(ward)
	_only_these(ward)
	for condition: String in ["gastro", "heart_attack", "wrist_fracture", "asthma", "gastro", "renal_colic"]:
		ward.shift.patients.append(ward.shift.make_patient(condition))
	_to_casualty_now(ward)
	expect_equal(ward.shift.waiting().size(), 6, "a full waiting area")
	var rows: int = ward.hud._tasks.get_child_count() - 1
	expect_equal(rows, Ward.BOARD_ROWS, "the board shows the first few, sickest first")
	var kicker := ward.hud._tasks.get_child(0) as Label
	expect(kicker.text.to_lower().contains("6 waiting"), "and counts the rest: %s" % kicker.text)
	var shown: Array[Rect2] = []
	var names := []
	for id: String in ward.hud._tags:
		var tag := ward.hud._tags[id] as Control
		if id.begins_with("cas_") and tag.visible:
			shown.append(Rect2(tag.position, tag.size))
			names.append(id)
	expect(shown.size() >= 3, "several tags show: %s" % str(names))
	for a in shown.size():
		for b in range(a + 1, shown.size()):
			expect(not shown[a].intersects(shown[b]), "%s and %s don't overlap" % [names[a], names[b]])
	var red := ward.shift.board()[0]
	expect_equal(red.triage(), "red", "the heart attack is first on the board")
	expect(ward.hud._tags["cas_s%d" % ward.casualty.seat_of(red)].visible, "and the sickest gets their tag")


func test_tapping_a_tag_sees_that_patient() -> void:
	var ward := _ward(12)
	_to_first_walk(ward)
	_only_these(ward)
	for condition: String in ["gastro", "wrist_fracture", "asthma"]:
		ward.shift.patients.append(ward.shift.make_patient(condition))
	_to_casualty_now(ward)
	var chosen: ShiftPatient = null
	var tag: Control = null
	for patient in ward.shift.waiting():
		var found := ward.hud._tags.get("cas_s%d" % ward.casualty.seat_of(patient)) as Control
		if found != null and found.visible:
			chosen = patient
			tag = found
	expect(chosen != null, "someone has a tag")
	if chosen == null:
		return
	ward._tap_casualty(tag.position + tag.size / 2.0)
	expect_equal(chosen.state, "seeing", "the one on the tag goes to a cubicle")


func test_heading_for_casualty_the_camera_looks_towards_its_door() -> void:
	var ward := _ward(12)
	_to_first_walk(ward)
	ward.player.position = Ward.DOOR + Vector3(-4.5, 0, 0.4)
	ward._walk_to_door()
	_frames(ward, 0.5)
	ward.settle_camera()
	var screen := ward.camera.get_viewport().get_visible_rect()
	expect(screen.has_point(ward.camera.unproject_position(Ward.DOOR + Vector3(0, 1.6, 0))), "the door is in view")


## Nobody in casualty but the patients the test adds, and nobody new turns up.
func _only_these(ward: Ward) -> void:
	ward.shift.patients.clear()
	ward.shift.load = 0.0

