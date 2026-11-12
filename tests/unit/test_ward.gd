extends TestCase
## Days 4 to 8 on the surgical ward: the patients, the bed politics, the
## night on call and the review.

const CAREFUL := ["Ready", "Honest", "Reassure", "Ask her", "Check", "Own it", "Calm", "Compromise", "To Aarav", "Gentle",
	"Careful", "Stay", "Patient first", "Answer", "Light", "Ask him", "The facts", "Grateful"]


func _ward(day: int = 4, flags: Array = []) -> Ward:
	var doctor := PlayerProfile.new()
	doctor.name = "Asha Verma"
	doctor.day = day
	doctor.opening_seen = true
	doctor.created = true
	doctor.total_xp = 800
	for flag: String in ["op_rohit_done", "op_rohit_won"] + flags:
		doctor.set_flag(flag)
	return add_node(Ward.new(doctor)) as Ward


func test_day_four_starts_with_handover_at_the_nurses_station() -> void:
	var ward := _ward()
	expect(ward.overlay.fade_amount() > 0.9, "a title card opens the day")
	for frame in 100:
		ward.update(1.0 / 30.0)
	expect_equal(ward.conversation, "handover")
	expect_equal(ward.talking_with, "grace")
	ward.play_until(func() -> bool: return ward.mode == "walk", Ward.pick_tones(CAREFUL))
	expect_equal(ward._go_place(), "bed1", "Rohit's bed is first")
	expect(ward.hud.hint_text().contains("Bed 1"), "the hint points to bed 1")
	var tag := ward.camera.unproject_position(ward._tag_point("bed1"))
	expect_equal(ward.place_at(tag), "bed1", "the bed can be tapped")


func test_day_four_admits_lakshmi_and_settles_the_beds() -> void:
	var ward := _ward()
	var finished := [false]
	ward.day_finished.connect(func() -> void: finished[0] = true)
	var xp := ward.profile.total_xp
	expect(ward.play_until(func() -> bool: return finished[0], Ward.pick_tones(CAREFUL)), "the day ends")
	var profile := ward.profile
	for flag in ["lakshmi_history_done", "lakshmi_history_medicines", "lakshmi_exam_done", "lakshmi_exam_right",
			"lakshmi_asked", "beds_checked", "rohit_honest", "ward_day4"]:
		expect(profile.has_flag(flag), flag)
	expect(not profile.has_flag("beds_agreed"), "no beds given away")
	expect_equal(ward.results.size(), 2, "a history and an examination")
	for result in ward.results:
		expect(int(result["score"]) >= 85, "%s played well: %d" % [result["id"], result["score"]])
	expect(profile.total_xp >= xp + Ward.SHIFT_XP + 2 * Ward.TASK_XP, "experience for the work and the shift")
	expect(ward.bed("bed2").patient == ward.rig_for("lakshmi"), "Lakshmi is in bed 2")
	expect(profile.best_score("exam") >= 85, "the examination is recorded as a skill")
	print("    day 4 xp: %d -> %d, minutes %s" % [xp, profile.total_xp, profile.clock_text()])


func _play_day(ward: Ward, tones: Array, bot: AutoPlayer = null) -> bool:
	var finished := [false]
	ward.day_finished.connect(func() -> void: finished[0] = true)
	return ward.play_until(func() -> bool: return finished[0], Ward.pick_tones(tones), bot)


func test_freeing_beds_sends_lakshmi_home_and_she_comes_back() -> void:
	var ward := _ward()
	expect(_play_day(ward, ["Agree"] + CAREFUL))
	expect(ward.profile.has_flag("beds_agreed"))
	expect(ward.profile.trust("malhotra", 50) > 50, "Mr. Malhotra is pleased")
	expect(ward.profile.trust("iyer", 50) < 50, "Dr. Iyer is not")
	var next := _ward(5, ward.profile.flags.keys())
	next.profile.relationships = ward.profile.relationships.duplicate()
	expect(next.bed("bed1").patient != next.rig_for("rohit"), "Rohit was sent home")
	expect(not next.present("rohit"))
	next.play_until(func() -> bool: return next.conversation == "day5_morning")
	var said := []
	next.play_until(func() -> bool:
		if not next.story.runner.history.is_empty():
			said.append(str(next.story.runner.history[-1][1]))
		return next.mode == "walk", Ward.pick_tones(CAREFUL))
	expect(" ".join(said).contains("came back at three"), "Lakshmi came back in the night")


func test_the_side_room_goes_to_whoever_the_doctor_chooses() -> void:
	for choice: String in ["Send home", "Compromise", "Side room"]:
		var ward := _ward(5, ["beds_checked"])
		ward.skip_to("kunal")
		ward.play_until(func() -> bool: return ward.beat().get("id", "") == "aarav", Ward.pick_tones([choice] + CAREFUL))
		var profile := ward.profile
		expect(profile.has_flag("kunal_exam_right"), "a sprain, not a fracture")
		var side := ward.bed("side").patient
		match choice:
			"Send home":
				expect(profile.has_flag("kunal_home"))
				expect(not ward.present("kunal"), "Kunal went home")
				expect(side == ward.rig_for("banerjee"), "Mrs. Banerjee has the side room")
			"Compromise":
				expect(profile.has_flag("banerjee_room"))
				expect(side == ward.rig_for("banerjee"), "Mrs. Banerjee has the side room")
				expect(ward.bed("bed5").patient == ward.rig_for("kunal"), "Kunal has her bed")
			"Side room":
				expect(profile.has_flag("kunal_room"))
				expect(side == ward.rig_for("kunal"), "Kunal has the side room")
				expect(ward.bed("bed5").patient == ward.rig_for("banerjee"), "Mrs. Banerjee stays on the ward")
		ward.visible = false
		ward.set_process(false)


func test_aaravs_battery_is_found_by_reading_the_film_properly() -> void:
	var ward := _ward(5, ["beds_checked"])
	expect(_play_day(ward, CAREFUL))
	expect(ward.profile.has_flag("aarav_scan_right"), "a careful read finds the battery")
	expect(ward.profile.has_flag("aarav_battery_found"))
	var careless := _ward(5, ["beds_checked"])
	var bad := AutoPlayer.new()
	bad.quality = "bad"
	careless.skip_to("aarav")
	careless.play_until(func() -> bool: return careless.mode == "end", Ward.pick_tones(CAREFUL), bad)
	expect(not careless.profile.has_flag("aarav_battery_found"), "a rushed read calls it a coin")
	expect(careless.results.size() > 0 and int(careless.results[-1]["score"]) < 40, "and scores badly")


func test_the_night_on_call_and_the_rider() -> void:
	var ward := _ward(6, ["beds_checked", "banerjee_room"])
	expect(ward.night, "Day 6 is a night")
	expect(ward.profile.minutes >= Ward.NIGHT_START, "it starts in the evening")
	expect(ward.bed("side").patient == ward.rig_for("banerjee"), "Mrs. Banerjee is in the side room")
	ward.skip_to("rider")
	expect(ward.profile.minutes >= Ward.NIGHT_LATE, "the rider comes in after two")
	ward.go_to("trolley")
	ward.play_until(func() -> bool: return ward.view != null, Ward.pick_tones(CAREFUL))
	var exam := ward.view.task as ExamTask
	expect(exam != null and exam.has_vitals, "an emergency, with the monitor")
	expect((ward.view as ExamView).monitor != null, "the monitor is on screen")
	expect(exam.bleeding(), "he is bleeding")
	var before := exam.stability
	ward.update(1.0)
	expect(exam.stability < before, "and getting weaker")
	ward.play_until(func() -> bool: return ward.mode == "end", Ward.pick_tones(CAREFUL))
	var profile := ward.profile
	expect(profile.has_flag("rider_exam_right"), "a torn artery")
	expect(exam.pressure_at >= 0.0 and exam.pressure_at <= ExamTask.QUICK, "pressure went on quickly")
	for flag in ["rider_treated", "rider_named", "pooja_answered"]:
		expect(profile.has_flag(flag), flag)
	expect(ward.bed("bed4").patient == ward.rig_for("salim"), "Salim is in bed 4 after theatre")


func test_following_policy_at_night_puts_salim_in_intensive_care() -> void:
	var ward := _ward(6, ["beds_checked"])
	expect(_play_day(ward, ["Policy"] + CAREFUL))
	expect(ward.profile.has_flag("rider_waited"))
	expect(not ward.profile.has_flag("rider_treated"))
	expect(ward.profile.trust("sethi", 45) < 45, "Dr. Sethi is angry")
	var next := _ward(7, ward.profile.flags.keys())
	expect(not next.present("salim"), "Salim is in intensive care, not on the ward")
	var rows := []
	for entry in next.beats:
		if next._beat_open(entry):
			rows.append(str(entry.get("id", "")))
	expect(not rows.has("salim"), "so there is no visit to him")


func test_mr_fernandes_decides_for_himself_and_the_beds_are_saved() -> void:
	var ward := _ward(7, ["beds_checked", "banerjee_room", "rider_treated", "rider_named"])
	expect(_play_day(ward, CAREFUL))
	var profile := ward.profile
	for flag in ["joseph_exam_right", "joseph_asked", "beds_saved"]:
		expect(profile.has_flag(flag), flag)
	expect(profile.trust("joseph", 50) > 55, "Mr. Fernandes trusts the doctor who asked him")
	expect(profile.trust("rao", 45) > 45, "Dr. Rao noticed")


func test_the_review_promotes_the_doctor_to_junior_resident() -> void:
	var ward := _ward(8, ["beds_checked", "banerjee_room", "rider_treated", "rider_named", "joseph_asked", "beds_saved"])
	expect_equal(ward.profile.rank(), Rank.INTERN)
	expect(_play_day(ward, CAREFUL))
	expect_equal(ward.profile.rank(), Rank.JUNIOR_RESIDENT, "promoted")
	expect(ward.profile.level() >= 4, "with the experience to match")
	expect(ward.profile.has_flag("promoted"))


func test_quiet_days_after_the_review_have_teaching_films() -> void:
	var ward := _ward(14, ["promoted", "jump_9"])
	expect(_play_day(ward, CAREFUL))
	expect(ward.profile.has_flag("teaching_scan_right"), "the coin is read as a coin")


func test_examination_buttons_sit_on_the_patient_and_taps_pick_them() -> void:
	var ward := _ward()
	ward.skip_to("lakshmi")
	ward.go_to("trolley")
	ward.play_until(func() -> bool: return ward.view is ExamView, Ward.pick_tones(CAREFUL))
	var view := ward.view as ExamView
	expect(view != null, "the examination opens after the history")
	view.tick(0.1)
	ward.settle_camera()
	view.tick(0.1)
	var screen := ward.get_viewport().get_visible_rect().size
	for entry in (view.task as ExamTask).spots:
		var spot_id := str(entry["id"])
		var button := view.spot_button(spot_id)
		expect(button != null and button.get_parent().visible, "%s is shown" % spot_id)
		var point: Variant = view.spot_point(spot_id)
		expect(point != null, "%s is on her body" % spot_id)
		var at := ward.camera.unproject_position(point as Vector3)
		expect(Rect2(Vector2.ZERO, screen).has_point(at), "%s is on screen at %s" % [spot_id, at])
	var temp := ward.camera.unproject_position(view.spot_point("temp") as Vector3)
	expect_equal(view.spot_at(temp), "temp", "a tap on her forehead picks the temperature")
	view.world_tap(temp)
	expect((view.task as ExamTask).is_examined("temp"))
	expect(view.spot_button("temp").disabled, "and its button turns done")
