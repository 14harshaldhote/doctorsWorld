extends SceneTree
## Renders the store-style screenshots of every screen and story moment.
##
##   godot --path . --resolution 1688x780 -s res://tools/screenshots.gd -- shots iphone
##
## The first argument is the output folder, the second a prefix for the file
## names (for example the device), and an optional third limits the run to
## shots whose name contains it (or any of a comma-separated list).

const FRAMES_TO_SETTLE := 10

var _out := "shots"
var _prefix := "shot"
var _only := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_prefix = args[1]
	if args.size() > 2:
		_only = args[2]
	# The safe area of an iPhone with a notch (or an iPad's home bar), in
	# landscape, so the shots match the devices.
	UiKit.inset_override = Vector3(UiKit.px(47), 0, UiKit.px(21)) if _prefix.begins_with("iphone") \
		else Vector3(0, 0, UiKit.px(20))
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var doctor := sample_profile()
	await _shot("01-title", TitleScreen.new(doctor))
	await _shot("02-name", NameScreen.new(doctor))
	for tab_name in AvatarCreator.TABS:
		var creator := AvatarCreator.new(doctor)
		await _shot("03-creator-%s" % tab_name.to_lower(), creator, func() -> void:
			creator.show_tab(tab_name)
			if tab_name == "Face":
				creator.rig.set_mood(AvatarConfig.Mood.HAPPY)
			creator.settle_camera())
	await _shot("04-avatar-range", AvatarSheet.new())
	var lobby := Lobby.new(sample_profile_at_work())
	await _shot("05-lobby", lobby, func() -> void: lobby.stage_for_screenshot("walk"))
	var talking := Lobby.new(sample_profile_at_work())
	await _shot("06-lobby-talk", talking, func() -> void: talking.stage_for_screenshot("talk"))
	await _opening_shot("07-opening-graduation", func(o: Opening) -> bool:
		return o.set_name == "graduation" and o.ui.line_text().begins_with("Congratulations") and not o.ui.is_typing())
	await _opening_shot("08-opening-family", func(o: Opening) -> bool:
		return o.set_name == "graduation" and o.ui.line_text().begins_with("Twenty-two") and not o.ui.is_typing())
	await _opening_shot("09-opening-letter", func(o: Opening) -> bool:
		return o.overlay.letter_open() and o.overlay._letter.modulate.a >= 1.0, -1)
	await _opening_shot("10-opening-choice", func(o: Opening) -> bool:
		return o.set_name == "home" and o.ui.is_choosing(), -1)
	await _opening_shot("11-opening-morning", func(o: Opening) -> bool:
		return o.set_name == "morning" and o.ui.line_text().begins_with("Okay") and not o.ui.is_typing())
	var arriving := Lobby.new(sample_profile(), true)
	await _shot("12-lobby-arrival", arriving, func() -> void: arriving.stage_for_screenshot("arrival"))
	await _lab_shots()
	await _theatre_shots()
	await _ward_shots()
	quit(0)


## Day 2 in the skills lab: the room, a trainer explaining, each task in
## the middle of being played, and a score card.
func _lab_shots() -> void:
	var lab := SkillsLab.new(sample_profile_in_lab())
	await _shot("13-lab", lab, func() -> void:
		lab.player.position = Vector3(-0.4, 0, 1.6)
		lab.player.rotation.y = PI * 0.92
		lab.update(0.1)
		lab.settle_camera())
	var intro := SkillsLab.new(sample_profile_in_lab())
	await _shot("14-lab-intro", intro, func() -> void:
		intro.start_station("history")
		for frame in 900:
			intro.update(1.0 / 30.0)
			if intro.story.is_playing() and intro.talk_ui.line_text().begins_with("I'll be") and not intro.talk_ui.is_typing():
				break
			if intro.story.is_playing() and not intro.story.is_busy() and not intro.talk_ui.is_typing():
				intro.talk_ui.tap()
		intro.settle_camera())
	await _task_shot("15-scrub", "scrub", func(task: TrainingTask) -> bool:
		return (task as ScrubTask).areas_done() >= 3 and float((task as ScrubTask).scrubbed["nails"]) > 0.7)
	await _task_shot("16-monitor", "monitor", func(task: TrainingTask) -> bool:
		var monitor := task as MonitorTask
		return monitor.round_index >= 1 and monitor.revealing and monitor.answer_now() != "none")
	await _task_shot("17-history", "history", func(task: TrainingTask) -> bool:
		return (task as HistoryTask).asked.size() >= 3)
	await _task_shot("18-instruments", "instruments", func(task: TrainingTask) -> bool:
		var tray := task as InstrumentTask
		return tray.part == "call" and tray.round_index == 1 and tray.revealing)
	await _task_shot("19-iv-angle", "iv", func(task: TrainingTask) -> bool:
		return (task as IvTask).phase == "angle" and absf((task as IvTask).angle - 22.0) < 0.5)
	await _task_shot("20-iv-steady", "iv", func(task: TrainingTask) -> bool:
		return (task as IvTask).steady_time > 1.4)
	await _task_shot("21-stitch", "stitch", func(task: TrainingTask) -> bool:
		return (task as StitchTask).stitches.size() >= 7)
	await _task_shot("22-result", "stitch", func(_task: TrainingTask) -> bool: return false)


## Day 3, Rohit's operation: the ward, consent with his mother, the team in
## Theatre 2, each part of the operation, the score card and the talk after.
func _theatre_shots() -> void:
	var careful := Theatre.pick_tones(["Ask Rohit", "Allergies", "Ask about the exam", "Explain", "Be straight",
		"Hold firm", "Honest", "Polite", "Plain"])
	await _day_shot("23-ward", func(t: Theatre) -> bool:
		return t.mode == "walk" and t.stage == "consent", careful)
	await _day_shot("24-consent", func(t: Theatre) -> bool:
		return t.conversation == "consent" and t.talk_ui.is_choosing() and t.story.runner.offered().size() >= 4, careful)
	await _day_shot("25-team", func(t: Theatre) -> bool:
		return t.conversation == "khan_intro" and t.talk_ui.line_text().begins_with("So you're") \
			and not t.talk_ui.is_typing(), careful)
	await _op_shot("26-timeout", func(op: OperationTask) -> bool:
		return op.phase == "timeout" and op.timeout_index == 2 and not op.busy())
	await _op_shot("27-incision", func(op: OperationTask) -> bool:
		return op.step == "incision" and op.tracing and op.trace.size() >= 18)
	await _op_shot("28-call", func(op: OperationTask) -> bool:
		return op.step == "clamp" and op.phase == "call" and not op.busy())
	await _op_shot("29-complication", func(op: OperationTask) -> bool:
		return op.active_complication == "bleeding" and op.phase == "act" and not op.busy())
	await _op_shot("30-count", func(op: OperationTask) -> bool:
		return op.phase == "count" and not op.busy())
	await _op_shot("31-closing", func(op: OperationTask) -> bool:
		return op.step == "close" and op.stitches.size() >= 4)
	await _op_shot("32-op-result", func(_op: OperationTask) -> bool: return false)
	await _day_shot("33-after", func(t: Theatre) -> bool:
		return t.conversation == "after_won" and t.talk_ui.line_text().begins_with("Thank God") \
			and not t.talk_ui.is_typing(), careful, "good")


## Days 4 to 8 on the surgical ward: the round, examining, the X-ray, the
## bed politics, the night on call, the family meeting and the review.
func _ward_shots() -> void:
	var careful := Ward.pick_tones(["Ready", "Honest", "Reassure", "Ask her", "Check", "Own it", "Calm", "Compromise",
		"To Aarav", "Gentle", "Careful", "Stay", "Patient first", "Answer", "Light", "Ask him", "The facts", "Grateful"])
	var past := ["beds_checked", "banerjee_room", "rider_treated", "rider_named", "pooja_answered", "joseph_asked",
		"lakshmi_exam_right", "aarav_battery_found", "rohit_honest", "banerjee_sat"]
	await _ward_shot("34-ward", 4, [], "", func(w: Ward) -> bool:
		return w.mode == "walk" and w.beat().get("id", "") == "rohit", careful)
	await _ward_shot("35-round", 4, [], "rohit", func(w: Ward) -> bool:
		return w.conversation == "rohit_round" and w.talk_ui.is_choosing(), careful)
	await _ward_shot("36-history", 4, [], "lakshmi", func(w: Ward) -> bool:
		return w.view is HistoryView and (w.view.task as HistoryTask).asked.size() >= 2, careful)
	await _ward_shot("37-exam", 4, [], "lakshmi", func(w: Ward) -> bool:
		return w.view is ExamView and (w.view.task as ExamTask).examined.size() >= 4, careful)
	await _ward_shot("38-exam-decide", 4, [], "lakshmi", func(w: Ward) -> bool:
		return w.view is ExamView and (w.view.task as ExamTask).phase == "decide", careful)
	await _ward_shot("39-video-call", 4, ["lakshmi_history_medicines", "lakshmi_exam_right"], "arjun", func(w: Ward) -> bool:
		return w.conversation == "arjun_call" and w.talk_ui.is_choosing(), careful)
	await _ward_shot("40-beds", 4, ["lakshmi_exam_right"], "beds", func(w: Ward) -> bool:
		return w.conversation == "malhotra_beds" and w.talk_ui.is_choosing(), careful)
	await _ward_shot("41-wrist", 5, ["beds_checked"], "kunal", func(w: Ward) -> bool:
		return w.view is ExamView and (w.view.task as ExamTask).examined.size() >= 3, careful)
	await _ward_shot("42-side-room", 5, ["beds_checked"], "kunal", func(w: Ward) -> bool:
		return w.conversation == "kunal_room" and w.talk_ui.is_choosing(), careful)
	await _ward_shot("43-xray", 5, ["beds_checked"], "aarav", func(w: Ward) -> bool:
		return w.view is ScanView and (w.view.task as ScanTask).zoomed, careful)
	await _ward_shot("44-xray-side", 5, ["beds_checked"], "aarav", func(w: Ward) -> bool:
		return w.view is ScanView and (w.view.task as ScanTask).view == "side", careful)
	await _ward_shot("45-night", 6, ["beds_checked", "banerjee_room"], "banerjee", func(w: Ward) -> bool:
		return w.mode == "walk", careful)
	await _ward_shot("46-trauma", 6, ["beds_checked", "banerjee_room"], "rider", func(w: Ward) -> bool:
		return w.view is ExamView and (w.view.task as ExamTask).examined.size() >= 2, careful)
	await _ward_shot("47-pooja", 6, ["beds_checked", "banerjee_room"], "rider", func(w: Ward) -> bool:
		return w.conversation == "rider_after" and w.talk_ui.line_text().contains("birthday") and not w.talk_ui.is_typing(),
		careful)
	await _ward_shot("48-family", 7, past, "joseph", func(w: Ward) -> bool:
		return w.conversation == "joseph_family" and w.talk_ui.is_choosing(), careful)
	await _ward_shot("49-rao", 7, past, "rao", func(w: Ward) -> bool:
		return w.conversation == "rao_round" and w.talk_ui.is_choosing(), careful)
	await _ward_shot("50-review", 8, past + ["beds_saved"], "review", func(w: Ward) -> bool:
		return w.conversation == "review" and w.talk_ui.line_text().contains("Junior Resident") and not w.talk_ui.is_typing(),
		careful)
	await _ward_shot("51-promoted", 8, past + ["beds_saved"], "review", func(w: Ward) -> bool:
		return w.mode == "end" and w.overlay.fade_amount() > 0.9, careful)

	# Stage 6: the settings, the largest text and the colour-blind-safe monitor.
	var settings_title := TitleScreen.new(sample_profile())
	await _shot("52-settings", settings_title, func() -> void: settings_title.open_settings())
	var paused := Lobby.new(sample_profile_at_work())
	await _shot("53-settings-paused", paused, func() -> void:
		paused.stage_for_screenshot("walk")
		paused.hud.open_settings())
	var text_before := GameSettings.current.text_size
	GameSettings.current.text_size = 2
	var big_text := Lobby.new(sample_profile_at_work())
	await _shot("54-larger-text", big_text, func() -> void: big_text.stage_for_screenshot("talk"))
	GameSettings.current.text_size = text_before
	GameSettings.current.colour_safe = true
	await _ward_shot("55-colour-safe", 6, ["beds_checked", "banerjee_room"], "rider", func(w: Ward) -> bool:
		return w.view is ExamView and (w.view.task as ExamTask).examined.size() >= 2, careful)
	GameSettings.current.colour_safe = false

	# Stage 7: the Junior Resident's week, eight months later.
	var junior := Ward.pick_tones(["Ready", "Calm", "Honest", "Careful", "Plain", "Explain", "Question", "Patient first",
		"Help", "Grateful", "Thorough"])
	var year := ["bansal_exam_right", "bansal_sethi_told", "farida_history_medicines", "farida_history_allergy",
		"farida_reassured", "op_deepa_won", "op_farida_won"]
	await _ward_shot("56-time-jump", 9, [], "", func(w: Ward) -> bool:
		return w._day_card_in > 0.0 and w._day_card_in < 2.0, junior)
	await _ward_shot("57-cut-hand", 9, [], "deepa", func(w: Ward) -> bool:
		return w.conversation == "deepa_arrive" and w.talk_ui.is_choosing(), junior)
	await _ward_shot("58-minor-theatre", 9, [], "deepa", func(w: Ward) -> bool:
		return w.conversation == "deepa_brief" and w.story.runner.history.size() >= 3 and not w.talk_ui.is_typing(), junior)
	await _ward_shot("59-wound-repair", 9, [], "deepa", func(w: Ward) -> bool:
		return w.operation != null and w.operation.step == "explore" and w.operation.phase == "act", junior)
	await _ward_shot("60-aneurysm", 10, [], "bansal", func(w: Ward) -> bool:
		return w.view is ExamView and (w.view.task as ExamTask).examined.size() >= 3, junior)
	await _ward_shot("61-keyhole-team", 11, year, "farida", func(w: Ward) -> bool:
		return w.conversation == "farida_brief" and w.story.runner.history.size() >= 2 and not w.talk_ui.is_typing(), junior)
	await _ward_shot("62-keyhole", 11, year, "farida", func(w: Ward) -> bool:
		return w.operation != null and w.operation.step == "find" and w.operation.phase == "act", junior)
	await _ward_shot("63-meeting", 12, year, "meeting", func(w: Ward) -> bool:
		return w.conversation == "meeting" and w.talk_ui.is_choosing(), junior)
	await _ward_shot("64-vip", 12, year, "raju", func(w: Ward) -> bool:
		return w.conversation == "raju_arrive" and w.talk_ui.is_choosing(), junior)
	await _ward_shot("65-bowel", 12, year + ["credit_proof", "raju_first"], "raju_op", func(w: Ward) -> bool:
		return w.operation != null and w.operation.step == "check" and w.operation.phase == "decide", junior)
	var reviewed := year + ["credit_proof", "raju_first", "op_raju_won", "mehra_charmed", "mehra_home"]
	await _ward_shot("66-senior-review", 13, reviewed, "review", func(w: Ward) -> bool:
		return w.conversation == "review_senior" and w.talk_ui.line_text().contains("Senior Resident") and not w.talk_ui.is_typing(),
		junior)
	await _ward_shot("67-senior-promoted", 13, reviewed, "review", func(w: Ward) -> bool:
		return w.mode == "end" and w.overlay.fade_amount() > 0.9, junior)


## A ward day from a beat (or from the start) played up to a moment.
func _ward_shot(shot_name: String, day: int, flags: Array, from_beat: String, moment: Callable, picker: Callable) -> void:
	var ward := Ward.new(sample_profile_on_ward(day, flags))
	await _shot(shot_name, ward, func() -> void:
		if not from_beat.is_empty():
			ward.skip_to(from_beat)
		if not ward.play_until(moment.bind(ward), picker, AutoPlayer.new()):
			push_error("The ward never reached %s" % shot_name)
		var step := 1.0 / 30.0
		for frame in 90:
			if ward.view != null:
				ward.view._type_coach(step)
		if ward.mode == "end":
			ward.overlay.tick(1.0)
		ward.settle_camera()
		ward.set_process(false))


## The doctor on the ward: the operation done, some of the week played.
static func sample_profile_on_ward(day: int, flags: Array = []) -> PlayerProfile:
	var doctor := sample_profile_on_theatre_day()
	for flag: String in ["op_rohit_done", "op_rohit_won"] + flags:
		doctor.set_flag(flag)
	doctor.record_score("appendix", 91)
	doctor.day = day
	doctor.minutes = PlayerProfile.DAY_START
	doctor.total_xp = 760 + 260 * (day - 4)
	if day >= WardStory.FIRST_DAY:
		# Eight months on: a Junior Resident with the first week behind them.
		for flag: String in ["promoted", "rohit_honest", "rider_treated", "beds_saved", "jump_%d" % WardStory.FIRST_DAY]:
			doctor.set_flag(flag)
		doctor.rank_held = Rank.JUNIOR_RESIDENT
		doctor.total_xp = 2400 + 250 * (day - WardStory.FIRST_DAY)
	return doctor


## The theatre day played from the start (replies picked by picker, tasks
## by a robot of the given quality) up to a moment.
func _day_shot(shot_name: String, moment: Callable, picker: Callable, quality: String = "good") -> void:
	var theatre := Theatre.new(sample_profile_on_theatre_day())
	theatre.operation_setup = {"complication": "bleeding"}
	await _shot(shot_name, theatre, func() -> void:
		var bot := AutoPlayer.new()
		bot.quality = quality
		if not theatre.play_until(moment.bind(theatre), picker, bot):
			push_error("The theatre day never reached %s" % shot_name)
		_hold_theatre(theatre))


## The operation played well from the time-out up to a moment (or to its
## score card when the moment never comes), bleeding as the complication.
func _op_shot(shot_name: String, moment: Callable) -> void:
	var theatre := Theatre.new(sample_profile_on_theatre_day())
	theatre.operation_setup = {"complication": "bleeding", "lose_swab": 1}
	await _shot(shot_name, theatre, func() -> void:
		theatre.skip_to("operation", ["rohit_allergy_known"], 92)
		var bot := AutoPlayer.new()
		var step := 1.0 / 30.0
		for frame in 7200:
			if theatre.view == null or theatre.view.result_open():
				break
			if bool(moment.call(theatre.operation)):
				break
			bot.step(theatre.view, step)
			theatre.update(step)
		_hold_theatre(theatre))


## Lets the coach finish typing, the wound and hands catch up and the camera
## settle, without moving the story or the operation on.
func _hold_theatre(theatre: Theatre) -> void:
	var step := 1.0 / 30.0
	for frame in 90:
		if theatre.view != null:
			theatre.view._type_coach(step)
			var station := theatre.station_for(theatre.active)
			if station != null:
				station.show_task(theatre.view.task, step)
	theatre.settle_camera()
	theatre.set_process(false)


## The doctor on Day 3: training finished, the theatre day ahead.
static func sample_profile_on_theatre_day() -> PlayerProfile:
	var doctor := sample_profile_in_lab()
	for id: String in ["history", "instruments", "iv", "stitch"]:
		doctor.set_flag("trained_" + id)
	doctor.set_flag("training_done")
	doctor.record_score("history", 81)
	doctor.record_score("instruments", 88)
	doctor.record_score("iv", 70)
	doctor.record_score("stitch", 84)
	doctor.day = 3
	doctor.minutes = PlayerProfile.DAY_START
	doctor.total_xp = 610
	return doctor


## A task played well by the robot up to a moment (or to its score card when
## the moment never comes), then held still for the picture.
func _task_shot(shot_name: String, id: String, moment: Callable) -> void:
	var lab := SkillsLab.new(sample_profile_in_lab())
	await _shot(shot_name, lab, func() -> void:
		if not lab.go_to_task(id):
			push_error("The %s station never opened" % id)
			return
		lab.play_task(func() -> bool: return bool(moment.call(lab.view.task)) or lab.view.result_open())
		# Let the camera, the coach's typing and the result card settle.
		for frame in 90:
			if not lab.view.result_open() and lab.view.task.finished:
				lab.update(1.0 / 30.0)
				continue
			lab.view._type_coach(1.0 / 30.0)
		lab.settle_camera()
		lab.set_process(false))


## The doctor on Day 2, welcomed, with the sink and the monitor done.
static func sample_profile_in_lab() -> PlayerProfile:
	var doctor := sample_profile_at_work()
	for flag in ["day1_grace", "day1_patient", "day1_iyer", "lab_welcome", "trained_scrub", "trained_monitor"]:
		doctor.set_flag(flag)
	doctor.day = 2
	doctor.minutes = PlayerProfile.DAY_START + 20
	doctor.total_xp = 240
	doctor.record_score("scrub", 92)
	doctor.record_score("monitor", 74)
	return doctor


static func sample_profile_at_work() -> PlayerProfile:
	var doctor := sample_profile()
	doctor.opening_seen = true
	doctor.set_flag("met_iyer")
	return doctor


## A moment from the opening story: plays forward until the moment, then
## holds still for the picture.
func _opening_shot(shot_name: String, moment: Callable, reply: int = 2) -> void:
	var opening := Opening.new(sample_profile())
	await _shot(shot_name, opening, func() -> void:
		if not opening.play_until(moment.bind(opening), reply):
			push_error("The opening never reached %s" % shot_name)
		opening.set_process(false))


## The doctor used in every screenshot.
static func sample_profile() -> PlayerProfile:
	var doctor := PlayerProfile.new()
	doctor.name = "Asha Verma"
	doctor.address_form = "last"
	doctor.day = 1
	doctor.created = true
	var look := AvatarConfig.new()
	look.skin = 5
	look.hair_style = 7
	look.hair_colour = 1
	look.face = 1
	look.eyes = 1
	look.brows = 4
	look.scrubs = 0
	doctor.avatar = look
	return doctor


func _wanted(shot_name: String) -> bool:
	if _only.is_empty():
		return true
	for part in _only.split(","):
		if not part.is_empty() and shot_name.contains(part):
			return true
	return false


func _shot(shot_name: String, node: Node, prepare: Callable = Callable()) -> void:
	if not _wanted(shot_name):
		node.free()
		return
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()
	root.add_child(node)
	await process_frame
	if prepare.is_valid():
		prepare.call()
	for frame in FRAMES_TO_SETTLE:
		await process_frame
	# Finish any fades and pops in the interface.
	for running in get_processed_tweens():
		running.custom_step(30.0)
	# Hold every character still: eyes open, gestures finished.
	for found in node.find_children("*", "AvatarRig", true, false):
		var rig := found as AvatarRig
		rig.blink_every = 0.0
		rig.settle()
	await process_frame
	var path := _out.path_join("%s-%s.png" % [_prefix, shot_name])
	root.get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
