extends SceneTree
## Renders the store-style screenshots of every screen and story moment.
##
##   godot --path . --resolution 1688x780 -s res://tools/screenshots.gd -- shots iphone
##
## The first argument is the output folder, the second a prefix for the file
## names (for example the device), and an optional third limits the run to
## shots whose name contains it (or any of a comma-separated list).

const FRAMES_TO_SETTLE := 10


## A phone that has allowed reminders, for the reminder shots.
class ShotPhone extends ReminderBackend:
	func supported() -> bool:
		return true

	func status() -> String:
		return "granted"

	func send(_payload: String) -> void:
		pass

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
	# The shots are taken on story time, without waiting for voices.
	Speech.enabled = false
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

	# Stage 8: the Senior Resident's week, a year later.
	var senior := Ward.pick_tones(["Open door", "Patient first", "Honest", "Explain", "Plain", "Check", "Own it", "Report",
		"Night doctor", "Together", "Call senior", "Ask", "Theatre", "Zoya holds", "Thank", "Truth", "Credit", "Speak up",
		"Grateful", "Her call"])
	var gomes := ["zoya_ask", "gomes_history_done", "gomes_history_medicines", "gomes_history_allergy", "gomes_faced",
		"gomes_own_consent", "francis_explained"]
	await _ward_shot("68-year-later", 14, [], "", func(w: Ward) -> bool:
		return w._day_card_in > 0.0 and w._day_card_in < 2.0, senior)
	await _ward_shot("69-broken-hip", 14, ["zoya_ask"], "gomes", func(w: Ward) -> bool:
		return w.conversation == "gomes_arrive" and w.talk_ui.is_choosing(), senior)
	await _ward_shot("70-her-son", 14, gomes.slice(0, 6), "francis", func(w: Ward) -> bool:
		return w.conversation == "francis_talk" and w.talk_ui.is_choosing(), senior)
	await _ward_shot("71-drug-chart", 15, gomes, "chart", func(w: Ward) -> bool:
		return _chart_at(w, false) and not w.talk_ui.is_typing(), senior)
	await _ward_shot("72-chart-reason", 15, gomes, "chart", func(w: Ward) -> bool:
		return _chart_at(w, true), senior)
	await _ward_shot("73-hip-xray", 15, gomes + ["gomes_chart_done", "chart_kind"], "gomes_op", func(w: Ward) -> bool:
		return w.operation != null and w.operation.step == "xray" and w.operation.phase == "decide", senior)
	await _ward_shot("74-hip-wire", 15, gomes + ["gomes_chart_done", "chart_kind"], "gomes_op", func(w: Ward) -> bool:
		return w.operation != null and w.operation.step == "wire" and w.operation.phase == "act", senior)
	var night := gomes + ["gomes_chart_done", "op_gomes_done", "op_gomes_won"]
	await _ward_shot("75-night-round", 16, night, "nanda", func(w: Ward) -> bool:
		return w.view is ExamView and (w.view.task as ExamTask).examined.size() >= 2, senior)
	await _ward_shot("76-scaffold-fall", 16, night + ["nanda_called"], "imran", func(w: Ward) -> bool:
		return w.view is ExamView and (w.view.task as ExamTask).examined.size() >= 3, senior)
	await _ward_shot("77-spleen-pack", 16, night + ["nanda_called", "imran_allergy_asked"], "imran_op", func(w: Ward) -> bool:
		return w.operation != null and w.operation.step == "pack" and w.operation.phase == "act", senior)
	await _ward_shot("78-spleen-decide", 16, night + ["nanda_called", "imran_allergy_asked"], "imran_op", func(w: Ward) -> bool:
		return w.operation != null and w.operation.step == "look" and w.operation.phase == "decide", senior)
	var week := night + ["nanda_called", "imran_allergy_asked", "op_imran_done", "op_imran_won", "night_round_together"]
	await _ward_shot("79-m-and-m", 17, week, "mm", func(w: Ward) -> bool:
		return w.conversation == "mm" and w.talk_ui.is_choosing(), senior)
	await _ward_shot("80-budget-vote", 17, week + ["mm_credit_zoya"], "vote", func(w: Ward) -> bool:
		return w.conversation == "vote" and w.talk_ui.is_choosing(), senior)
	var year_done := week + ["mm_credit_zoya", "vote_night_doctor", "imran_truth"]
	await _ward_shot("81-surgeon-review", 18, year_done, "review", func(w: Ward) -> bool:
		return w.conversation == "review_surgeon" and w.talk_ui.line_text().contains("Surgeon") and not w.talk_ui.is_typing(),
		senior)
	await _ward_shot("82-surgeon", 18, year_done, "review", func(w: Ward) -> bool:
		return w.mode == "end" and w.overlay.fade_amount() > 0.9, senior)

	# Stage 9: the Surgeon's first months, three months later.
	var surgeon := Ward.pick_tones(["Fresh hands", "Start now", "Patient first", "Plain", "Truth now", "Together", "Truth",
		"Listen", "Promise", "Explain", "Fair fight", "Call in", "Own it", "Credit Priya", "Ready", "Count rule", "Talk"])
	var kurup := ["team_neha", "team_bose", "kurup_history_done", "kurup_history_lungs", "kurup_history_surgery",
		"kurup_history_allergy", "kurup_consent_plain"]
	await _ward_shot("83-three-months", 19, [], "", func(w: Ward) -> bool:
		return w._day_card_in > 0.0 and w._day_card_in < 2.0, surgeon)
	await _ward_shot("84-your-team", 19, [], "", func(w: Ward) -> bool:
		return w.conversation == "handover19" and w.talk_ui.is_choosing(), surgeon)
	await _ward_shot("85-blocked-bowel", 19, ["team_neha", "team_bose"], "", func(w: Ward) -> bool:
		return w.view is HistoryView and (w.view.task as HistoryTask).asked.size() >= 2, surgeon)
	await _ward_shot("86-find-the-block", 19, kurup, "", func(w: Ward) -> bool:
		return w.operation != null and w.operation.step == "run" and w.operation.phase == "act", surgeon)
	await _ward_shot("87-old-swab", 19, kurup, "", func(w: Ward) -> bool:
		return w.operation != null and w.operation.step == "look" and w.operation.phase == "decide", surgeon)
	await _ward_shot("88-cut-the-band", 19, kurup, "", func(w: Ward) -> bool:
		return w.operation != null and w.operation.step == "free" and w.operation.phase == "act", surgeon)
	await _ward_shot("89-the-2004-notes", 19, kurup, "", func(w: Ward) -> bool:
		return w.conversation == "kurup_after_op" and w.talk_ui.is_choosing(), surgeon)
	var told := kurup + ["op_kurup_done", "op_kurup_won", "kurup_told_now"]
	await _ward_shot("90-dr-rao", 20, told, "rao", func(w: Ward) -> bool:
		return w.conversation == "rao_swab" and w.talk_ui.is_choosing(), surgeon)
	await _ward_shot("91-side-by-side", 20, told + ["candour_together"], "", func(w: Ward) -> bool:
		return w.conversation == "kurup_truth" and w.talk_ui.is_choosing(), surgeon)
	var listened := told + ["candour_together", "kurup_promise"]
	await _ward_shot("92-rao-retires", 21, listened, "rao", func(w: Ward) -> bool:
		return w.conversation == "rao_retires" and w.talk_ui.is_choosing(), surgeon)
	var crash := listened + ["count_rule", "sethi_fair"]
	await _ward_shot("93-triage", 22, crash, "triage", func(w: Ward) -> bool:
		return w.view is TriageView and (w.view.task as TriageTask).tags.size() >= 2 \
			and (w.view.task as TriageTask).selected.is_empty(), surgeon)
	await _ward_shot("94-triage-checks", 22, crash, "triage", func(w: Ward) -> bool:
		if not w.view is TriageView:
			return false
		var triage := w.view.task as TriageTask
		return triage.tags.size() >= 1 and not triage.selected.is_empty() and triage.checks_done(triage.selected).size() >= 2,
		surgeon)
	await _ward_shot("95-after-the-crash", 22, crash + ["crash_called", "bus_triage_done", "bus_triage_right"], "evening",
		func(w: Ward) -> bool:
			return w.conversation == "crash_evening" and w.talk_ui.is_choosing(), surgeon)
	var months := crash + ["crash_called", "bus_triage_done", "bus_triage_right", "crash_credit_priya"]
	await _ward_shot("96-interview", 23, months, "interview", func(w: Ward) -> bool:
		return w.conversation == "review_hod" and w.talk_ui.is_choosing(), surgeon)
	await _ward_shot("97-head-of-department", 23, months, "interview", func(w: Ward) -> bool:
		return w.mode == "end" and w.overlay.fade_amount() > 0.9, surgeon)

	# Stage 10: Head of Department, six months later, and the last day.
	var head := Ward.pick_tones(["Support", "Ask", "Explain", "Together", "Promise", "Refuse", "Tea", "Truth", "Credit Grace",
		"Own it", "Patients", "Sethi", "Families", "Everything"])
	await _ward_shot("98-six-months", 24, [], "", func(w: Ward) -> bool:
		return w._day_card_in > 0.0 and w._day_card_in < 2.0, head)
	await _ward_shot("99-strike-vote", 24, [], "", func(w: Ward) -> bool:
		return w.conversation == "morning24" and w.talk_ui.is_choosing(), head)
	await _ward_shot("100-dr-kapoor", 24, ["strike_backed"], "kapoor", func(w: Ward) -> bool:
		return w.conversation == "kapoor_tour" and w.talk_ui.is_choosing(), head)
	var backed := ["strike_backed", "kapoor_asked"]
	await _ward_shot("101-day-case", 25, backed, "", func(w: Ward) -> bool:
		return w.view is HistoryView and (w.view.task as HistoryTask).asked.size() >= 2, head)
	await _ward_shot("102-find-the-leak", 25, backed, "", func(w: Ward) -> bool:
		return w.operation != null and w.operation.step == "find" and w.operation.phase == "act", head)
	await _ward_shot("103-where-is-it-leaking", 25, backed, "", func(w: Ward) -> bool:
		return w.operation != null and w.operation.step == "look" and w.operation.phase == "decide", head)
	await _ward_shot("104-stop-the-leak", 25, backed, "", func(w: Ward) -> bool:
		return w.operation != null and w.operation.step == "fix" and w.operation.phase == "act", head)
	await _ward_shot("105-dr-sethi-asks", 25, backed, "", func(w: Ward) -> bool:
		return w.conversation == "sethi_leak" and w.talk_ui.is_choosing(), head)
	await _ward_shot("106-the-whole-sentence", 25, backed, "", func(w: Ward) -> bool:
		return w.conversation == "sinha_truth" and w.talk_ui.is_choosing(), head)
	var owned := backed + ["sinha_history_done", "sinha_history_right", "op_sinha_done", "op_sinha_won", "sinha_together",
		"pilot_paused"]
	await _ward_shot("107-strike-cover", 26, owned, "", func(w: Ward) -> bool:
		return w.view is RotaView and (w.view.task as RotaTask).assigned.size() >= 3 \
			and (w.view.task as RotaTask).selected.is_empty(), head)
	await _ward_shot("108-who-takes-them", 26, owned, "", func(w: Ward) -> bool:
		return w.view is RotaView and (w.view.task as RotaTask).assigned.size() >= 2 \
			and not (w.view.task as RotaTask).selected.is_empty(), head)
	var struck := owned + ["strike_rota_done", "strike_rota_right"]
	await _ward_shot("109-agency-nurses", 26, struck, "midday", func(w: Ward) -> bool:
		return w.conversation == "strike_midday" and w.talk_ui.is_choosing(), head)
	await _ward_shot("110-picket-line", 26, struck + ["strike_no_agency"], "picket", func(w: Ward) -> bool:
		return w.conversation == "picket" and w.talk_ui.is_choosing(), head)
	var voted := struck + ["strike_no_agency", "picket_tea"]
	await _ward_shot("111-board-vote", 27, voted, "board", func(w: Ward) -> bool:
		return w.conversation == "board_vote" and w.talk_ui.is_choosing(), head)
	await _ward_shot("112-chief-of-medicine", 27, voted, "board", func(w: Ward) -> bool:
		return w.mode == "end" and w.overlay.fade_amount() > 0.9, head)
	var last := voted + ["promoted"]
	await _ward_shot("113-head-of-surgery", 28, last, "", func(w: Ward) -> bool:
		return w.conversation == "morning28" and w.talk_ui.is_choosing(), head)
	await _ward_shot("114-new-intern", 28, last + ["hos_sethi"], "intern", func(w: Ward) -> bool:
		return w.conversation == "intern_day1" and w.talk_ui.is_choosing(), head)
	await _ward_shot("115-end-of-the-day", 28, last + ["hos_sethi", "lesson_ask"], "ending", func(w: Ward) -> bool:
		return w.conversation == "ending" and w.talk_ui.is_choosing(), head)
	await _ward_shot("116-the-end", 28, last + ["hos_sethi", "lesson_ask"], "ending", func(w: Ward) -> bool:
		return w.mode == "end" and w.overlay.fade_amount() > 0.9, head)

	# Stage 11: the Chief's days, for ever.
	var chief := Ward.pick_tones(["Warm", "Patient", "Kind", "Calm", "Listen", "Gentle", "Sorry", "Promote", "Everything",
		"Town", "Staff"])
	var chair := last + ["hos_iyer", "lesson_ask", "strike_backed", "sinha_together"]
	var hooked := func(w: Ward) -> bool:
		return w.mode == "end" and w.overlay.end_card_lines().size() >= 2 and w.overlay.card_left() < 6.5
	await _ward_shot("117-first-morning-as-chief", 29, chair, "", func(w: Ward) -> bool:
		return w.conversation == "cb_banerjee_morning" and w.talk_ui.is_choosing(), chief)
	await _ward_shot("118-mrs-banerjee-is-back", 29, chair, "patient", func(w: Ward) -> bool:
		return w.view is HistoryView and (w.view.task as HistoryTask).asked.size() >= 2, chief)
	await _ward_shot("119-a-hard-call", 29, chair, "call", func(w: Ward) -> bool:
		return w.conversation == "hc_night_nurses" and w.talk_ui.is_choosing(), chief)
	await _ward_shot("120-tomorrow", 29, chair, "call", hooked, chief)
	await _ward_shot("121-mr-malhotras-son", 30, chair, "patient", func(w: Ward) -> bool:
		return w.conversation == "cb_dev_arrive" and w.talk_ui.is_choosing(), chief)
	await _ward_shot("122-tom-on-the-table", 31, chair, "op", func(w: Ward) -> bool:
		return w.operation != null and w.operation.phase == "timeout", chief)
	await _ward_shot("123-tonights-rota", 31, chair, "rota", func(w: Ward) -> bool:
		return w.view is RotaView and (w.view.task as RotaTask).assigned.size() >= 3 \
			and (w.view.task as RotaTask).selected.is_empty(), chief)
	await _ward_shot("124-the-highway-crash", 32, chair, "triage", func(w: Ward) -> bool:
		return w.view is TriageView and (w.view.task as TriageTask).tags.size() >= 2 \
			and (w.view.task as TriageTask).selected.is_empty(), chief)
	await _ward_shot("125-sister-grace", 35, chair, "patient", func(w: Ward) -> bool:
		return w.conversation == "cb_grace_arrive" and w.talk_ui.is_choosing(), chief)
	await _ward_shot("126-board-report", 38, chair, "report", func(w: Ward) -> bool:
		return w.conversation == "board_report" and w.talk_ui.is_choosing(), chief)
	await _ward_shot("127-the-simulator", 47, chair, "sim", func(w: Ward) -> bool:
		return w.operation != null and w.operation.phase == "act", chief)
	var desk := 39
	while ChiefDays.call_for(sample_profile_on_ward(desk), desk) != "family_complaint":
		desk += 1
	await _ward_shot("128-complaints-desk", desk, chair, "call", func(w: Ward) -> bool:
		return w.conversation == "hc_family_complaint" and w.talk_ui.is_choosing(), chief)
	await _ward_shot("129-day-50-tomorrow", 49, chair, "call", hooked, chief)

	# Stage 12: no two weeks the same. Days are found for the sample doctor.
	var sample := sample_profile_on_ward(43, chair)
	var first_day := func(test: Callable) -> int:
		var day := 43
		while not test.call(day):
			day += 1
		return day
	var rains: int = first_day.call(func(d: int) -> bool:
		return ChiefDays.event_starts(sample, d) and ChiefDays.event_for(sample, d) == "monsoon" \
			and ChiefDays.walkin_for(sample, d).is_empty())
	await _ward_shot("130-the-rains-arrive", rains, chair, "", func(w: Ward) -> bool:
		return w.conversation == "rounds_morning" and w.talk_ui.line_text().contains("The rains have come") \
			and not w.talk_ui.is_typing(), chief)
	var fair: int = first_day.call(func(d: int) -> bool:
		return ChiefDays.event_for(sample, d) == "festival" and ChiefDays.rounds_puzzle(sample, d) == "triage" \
			and ChiefDays.walkin_for(sample, d).is_empty() and not ChiefDays.busy_day(sample, d))
	await _ward_shot("131-festival-crash", fair, chair, "triage", func(w: Ward) -> bool:
		return w.view is TriageView and (w.view.task as TriageTask).tags.size() >= 2 \
			and (w.view.task as TriageTask).selected.is_empty(), chief)
	var bug: int = first_day.call(func(d: int) -> bool:
		return ChiefDays.event_for(sample, d) == "outbreak" and ChiefDays.walkin_for(sample, d).is_empty())
	await _ward_shot("132-outbreak-rota", bug, chair, "rota", func(w: Ward) -> bool:
		return w.view is RotaView and (w.view.task as RotaTask).assigned.size() >= 3 \
			and (w.view.task as RotaTask).selected.is_empty(), chief)
	var walkin := ChiefDays.walkin_for(sample, ChiefDays.WALKIN_FROM)
	await _ward_shot("133-a-walk-in", ChiefDays.WALKIN_FROM, chair, "patient", func(w: Ward) -> bool:
		return w.conversation == "cb_%s_arrive" % walkin and w.talk_ui.is_choosing(), chief)
	await _ward_shot("134-walk-in-on-the-table", ChiefDays.WALKIN_FROM, chair, "op", func(w: Ward) -> bool:
		return w.operation != null and w.operation.phase == "timeout", chief)
	var vip: int = first_day.call(func(d: int) -> bool:
		return ChiefDays.call_for(sample, d) == "vip_queue" and ChiefDays.patient_today(sample, d).is_empty())
	await _ward_shot("135-somebody-important", vip, chair, "call", func(w: Ward) -> bool:
		return w.conversation == "hc_vip_queue" and w.talk_ui.is_choosing(), chief)
	var eve: int = first_day.call(func(d: int) -> bool:
		return ChiefDays.event_starts(sample, d + 1) and ChiefDays.walkin_for(sample, d + 1).is_empty() \
			and ChiefDays.walkin_for(sample, d).is_empty() and not ChiefDays.is_report_day(d))
	await _ward_shot("136-next-week", eve, chair, "call", hooked, chief)

	# Stage 13: reminders, the privacy policy and the acknowledgements.
	var backend_before := Reminders.backend
	Reminders.use_backend(ShotPhone.new())
	var asked := Lobby.new(sample_profile_at_work())
	await _shot("137-reminder-ask", asked, func() -> void:
		asked.stage_for_screenshot("walk")
		asked.add_child(ReminderAsk.new()))
	GameSettings.current.reminders = true
	var about_title := TitleScreen.new(sample_profile())
	await _shot("138-settings-reminders", about_title, func() -> void: about_title.open_settings().show_about())
	var privacy_title := TitleScreen.new(sample_profile())
	await _shot("139-privacy", privacy_title, func() -> void: privacy_title.open_settings().open_reader("Privacy"))
	var thanks_title := TitleScreen.new(sample_profile())
	await _shot("140-acknowledgements", thanks_title, func() -> void:
		thanks_title.open_settings().open_reader("Acknowledgements"))
	GameSettings.current.reminders = false
	Reminders.use_backend(backend_before)

	# Stage 14: a drill between days, and a place to go that is off screen.
	var drilling := SkillsLab.new(_drill_profile(12), Drills.before_day(12))
	await _shot("141-drill-card", drilling, func() -> void:
		for frame in 120:
			if drilling.drill_card != null:
				break
			drilling.update(1.0 / 30.0)
		drilling.set_process(false))
	var drilled := SkillsLab.new(_drill_profile(9), Drills.before_day(9))
	await _shot("142-drill-score", drilled, func() -> void:
		for frame in 120:
			if drilled.drill_card != null:
				break
			drilled.update(1.0 / 30.0)
		drilled.drill_card.start_button.pressed.emit()
		drilled.play_task()
		for frame in 90:
			drilled.view._type_coach(1.0 / 30.0)
		drilled.settle_camera()
		drilled.set_process(false))
	await _ward_shot("143-place-off-screen", 6, [], "", func(w: Ward) -> bool:
		return w.mode == "walk" and w.beat().get("id", "") == "rider", careful)

	# Stage 15: XP for a new day, and a history drill with a practice patient.
	var returning := Ward.new(sample_profile_on_ward(5, ["beds_checked"]))
	await _shot("144-welcome-back", returning, func() -> void:
		returning.play_until(func() -> bool: return returning.mode == "walk", careful, AutoPlayer.new())
		returning.add_child(WelcomeCard.new({"xp": 25, "streak": 4, "next": 30}))
		returning.set_process(false))
	var asking := SkillsLab.new(_drill_profile(6), Drills.before_day(6))
	await _shot("145-history-drill", asking, func() -> void:
		for frame in 120:
			if asking.drill_card != null:
				break
			asking.update(1.0 / 30.0)
		asking.drill_card.start_button.pressed.emit()
		asking.play_task(func() -> bool: return (asking.view.task as HistoryTask).asked.size() >= 2)
		for frame in 90:
			asking.view._type_coach(1.0 / 30.0)
		asking.settle_camera()
		asking.set_process(false))

	# Stage 17: the career map, the race with Varun, and the letters.
	await _career_shots(careful)

	# Stage 18: the eight crises, each in the middle of being solved.
	await _crisis_shots(careful)

	# Stage 19: the 60-second case, the weekly mystery and the badges.
	await _daily_shots()

	# Stage 20: the cold open, a new quick case, the lab's extras, Varun's
	# first message.
	await _hook_shots()


## The career map over the ward: the road and the race, a Chief's road,
## the wall of letters, one letter open, and the end card with the post.
func _career_shots(careful: Callable) -> void:
	var racing := sample_profile_on_ward(6, ["beds_checked", "rider_treated"])
	racing.set_count("rival_from", 4)
	racing.set_count("rival_base", racing.total_xp - 560)
	var on_map := Ward.new(racing)
	await _shot("146-career-map", on_map, func() -> void:
		on_map.play_until(func() -> bool: return on_map.mode == "walk", careful, AutoPlayer.new())
		on_map.settle_camera()
		on_map.hud.open_career()
		on_map.set_process(false))
	var chief := sample_profile_on_ward(41, ["rider_treated", "joseph_asked", "aarav_battery_found", "kunal_room",
		"mehra_charmed", "raju_first", "zoya_lead", "crash_credit_priya", "sinha_told"])
	chief.rank_held = Rank.CHIEF
	chief.total_xp = LevelCurve.total_xp_to_reach(Rank.FIRST_LEVELS[Rank.CHIEF]) + 4200
	chief.set_count("rival_from", 38)
	chief.set_count("rival_base", chief.total_xp - 1150)
	chief.set_count("rival_won", 4)
	chief.set_count("rival_lost", 2)
	chief.set_count("op_streak_best", 6)
	var chief_map := CareerMap.new(chief)
	await _shot("147-career-map-chief", chief_map, func() -> void:
		await process_frame
		chief_map.scroll.scroll_vertical = int(chief_map.scroll.get_v_scroll_bar().max_value))
	var wall_doctor := sample_profile_on_ward(14, ["joseph_asked", "aarav_battery_found", "kunal_room", "mehra_charmed",
		"raju_first", "banerjee_room"])
	for slot: Dictionary in Letters.slots().slice(0, 4):
		Letters.mark_read(wall_doctor, slot)
	await _shot("148-letters-wall", CareerMap.new(wall_doctor, "letters"))
	var reading := CareerMap.new(sample_profile_on_ward(9, ["aarav_battery_found"]), "letters")
	await _shot("149-letter-open", reading, func() -> void:
		for slot: Dictionary in Letters.slots():
			if str(slot["id"]) == "aarav":
				reading.open_letter(slot))
	await _ward_shot("150-end-card-post", 8, ["beds_checked", "banerjee_room", "rider_treated", "rider_named",
		"joseph_asked", "beds_saved"], "", func(w: Ward) -> bool:
		return w.mode == "end" and w.overlay.end_card_lines().size() >= 4 and w.overlay.card_left() < 6.5, careful)


## The Today page (a Thursday: four clues open), the 60-second case in
## play, the mystery once guessed, and the wall of badges.
func _daily_shots() -> void:
	DailyReward.today_override = "2026-11-19"
	var fresh := sample_profile_on_ward(12, ["beds_checked", "rider_treated"])
	fresh.set_count("daily_case_date", DailyCase.date_number("2026-11-18"))
	fresh.set_count("daily_case_streak", 4)
	fresh.set_count("daily_case_best", 4)
	var today := CareerMap.new(fresh, "today")
	await _shot("159-today-page", today, func() -> void:
		today.pick_mystery(str(WeeklyMystery.current()["options"][1]["id"])))
	var playing := CareerMap.new(sample_profile_on_ward(12, ["beds_checked"]), "today")
	await _shot("160-daily-case", playing, func() -> void:
		var view := playing.start_daily_case()
		await process_frame
		var task := view.task as CrisisTask
		view.pick(str(CrisisTask.right_answer(task.current())))
		view.confirm()
		view.pick(str(AutoPlayer.crisis_wrong_answer(task.current())))
		view.tick(0.0)
		for frame in 90:
			view._type_coach(1.0 / 30.0)
		task.time_total = 23.0
		view.tick(0.0)
		playing.set_process(false))
	var solved := sample_profile_on_ward(12, ["beds_checked"])
	WeeklyMystery.guess(solved, str(WeeklyMystery.current()["answer"]), "2026-11-18")
	var guessed := CareerMap.new(solved, "today")
	await _shot("161-mystery-solved", guessed, func() -> void:
		await process_frame
		guessed.scroll.scroll_vertical = int(guessed.scroll.get_v_scroll_bar().max_value))
	var proud := sample_profile_on_ward(52, ["beds_checked"])
	proud.set_flag("promoted")
	for counter: Array in [["crises", 6], ["crises_right", 5], ["daily_cases", 9], ["daily_case_best", 7],
			["daily_cases_perfect", 3], ["op_streak_best", 6], ["rival_won", 1]]:
		proud.set_count(str(counter[0]), int(counter[1]))
	await _shot("162-badges", CareerMap.new(proud, "badges"))
	DailyReward.today_override = ""


## The cold open before convocation, the head-injury case in play, the
## Day 2 board with two extra stations, and Day 1's card with Varun.
func _hook_shots() -> void:
	await _opening_shot("163-cold-open", func(o: Opening) -> bool:
		return o.overlay._card_title.text.begins_with("\u201cDoctor") and o.overlay._card_t >= 0.9)
	var date := "2026-11-19"
	for index in 30:
		if DailyCase.case_for(date) == "quick_head":
			break
		date = Time.get_date_string_from_unix_time(Time.get_unix_time_from_datetime_string(date + "T12:00:00") + 86400)
	DailyReward.today_override = date
	var head := CareerMap.new(sample_profile_on_ward(12, ["beds_checked"]), "today")
	await _shot("164-quick-head", head, func() -> void:
		var view := head.start_daily_case()
		await process_frame
		for frame in 90:
			view._type_coach(1.0 / 30.0)
		(view.task as CrisisTask).time_total = 48.0
		view.tick(0.0)
		head.set_process(false))
	DailyReward.today_override = ""
	var keen := sample_profile_in_lab()
	for flag: String in ["trained_history", "trained_instruments", "training_done"]:
		keen.set_flag(flag)
	keen.record_score("history", 81)
	keen.record_score("instruments", 88)
	var lab := SkillsLab.new(keen)
	await _shot("165-lab-extras", lab, func() -> void:
		lab.player.position = Vector3(-0.4, 0, 1.6)
		lab.player.rotation.y = PI * 0.92
		lab.update(0.1)
		lab.settle_camera())
	var first := sample_profile_at_work()
	first.set_flag("met_iyer")
	var evening := Lobby.new(first)
	await _shot("166-day1-card", evening, func() -> void:
		evening.stage_for_screenshot("walk")
		evening._end_day()
		for frame in 60:
			evening.overlay.tick(1.0 / 30.0)
		evening.set_process(false))


## The crises on their story days: [shot, day, step on show, answers given].
const CRISIS_SHOTS := [["151-crisis-power-cut", 20, 0, 0], ["152-crisis-ramesh", 10, 1, 0], ["153-crisis-crowd", 24, 2, 0],
	["154-crisis-donors", 17, 0, 2], ["155-crisis-insurance", 14, 0, 2], ["156-crisis-snakebite", 16, 0, 0],
	["157-crisis-dengue", 15, 0, 3], ["158-crisis-inspection", 26, 0, 3]]


func _crisis_shots(careful: Callable) -> void:
	for entry: Array in CRISIS_SHOTS:
		await _ward_shot(str(entry[0]), int(entry[1]), [], "crisis", _crisis_at.bind(int(entry[2]), int(entry[3])), careful)


## A crisis on the given step with that many answers picked so far.
static func _crisis_at(ward: Ward, step: int, given: int) -> bool:
	if not ward.view is CrisisView or ward.view.result_open():
		return false
	var crisis := ward.view.task as CrisisTask
	if crisis.step_index != step:
		return false
	var count := 0
	match crisis.kind():
		"one":
			count = 0 if str(crisis.picked).is_empty() else 1
		_:
			count = (crisis.picked as Dictionary).size() if crisis.picked is Dictionary else (crisis.picked as Array).size()
	return count >= given


## The drug chart with a line already flagged: the list, or the reasons.
static func _chart_at(ward: Ward, picking: bool) -> bool:
	if not ward.view is ChartView:
		return false
	var chart := ward.view.task as ChartTask
	return chart.verdicts.size() >= 1 and chart.selected.is_empty() != picking


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
	if day >= 14:
		# A year on: a Senior Resident, the Junior year behind them.
		for flag: String in ["op_raju_won", "credit_proof", "sethi_apology", "jump_14"]:
			doctor.set_flag(flag)
		doctor.rank_held = Rank.SENIOR_RESIDENT
		doctor.total_xp = LevelCurve.total_xp_to_reach(Rank.FIRST_LEVELS[Rank.SENIOR_RESIDENT]) + 300 * (day - 14)
	if day >= 19:
		# Three months on: a Surgeon, the Senior year behind them.
		for flag: String in ["op_gomes_won", "nanda_called", "op_imran_won", "mm_credit_zoya", "vote_night_doctor", "jump_19"]:
			doctor.set_flag(flag)
		doctor.rank_held = Rank.SURGEON
		doctor.total_xp = LevelCurve.total_xp_to_reach(Rank.FIRST_LEVELS[Rank.SURGEON]) + 400 * (day - 19)
	if day >= 24:
		# Six months on: Head of Department, the Surgeon's months behind them.
		for flag: String in ["op_kurup_won", "kurup_told_now", "candour_together", "kurup_promise", "count_rule", "sethi_fair",
				"bus_triage_right", "hod_talk", "jump_24"]:
			doctor.set_flag(flag)
		doctor.rank_held = Rank.HEAD_OF_DEPARTMENT if day < 28 else Rank.CHIEF
		doctor.total_xp = LevelCurve.total_xp_to_reach(Rank.FIRST_LEVELS[doctor.rank_held]) + 400 * (day - 24)
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


## Between two days: the save has moved on to the next morning and a drill
## waits in the skills lab before it.
static func _drill_profile(day: int) -> PlayerProfile:
	var doctor := sample_profile_on_ward(day)
	doctor.set_flag(Drills.FLAG)
	for id: String in TrainingTask.IDS:
		doctor.record_score(id, 78)
	return doctor


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
