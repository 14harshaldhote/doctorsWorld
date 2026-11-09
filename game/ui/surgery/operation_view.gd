class_name OperationView
extends TrainingView
## The screen over the operating table in first person: what to do now (top
## left), the patient monitor and how Rohit is doing (top right), whoever is
## talking (bottom left), and on the right whatever the moment needs: the
## time-out board, the instrument ring, a decision, Tom's count, a hold
## button or the tie-off button. The score card at the end tells the
## outcome, and there is no leaving halfway through an operation.

const MONITOR_SIZE := Vector2(236, 128)
const OUTCOME_LINES := {
	"won": "Rohit is fine. You did that.",
	"struggled": "You got there. Not prettily.",
	"failed": "Dr. Iyer had to take over.",
}
const TIMEOUT_TEXT := {"confirm": "Confirm", "stop": "Stop, that's wrong", "unsure": "Not sure"}

var ring: InstrumentRing
var monitor: VitalsMonitor
var profile: PlayerProfile
var _meters: PanelContainer
var _stability_fill: ColorRect
var _stability_label: Label
var _teamwork_label: Label
var _choices: PanelContainer
var _choice_kicker: Label
var _choice_text: Label
var _choice_list: VBoxContainer
var _choice_key := ""
var _hold: Button
var _hold_fill: ColorRect
var _tie: Button
var _shown_call := ""


func _init(for_task: TrainingTask = null, in_lab: Node = null, for_profile: PlayerProfile = null) -> void:
	super(for_task, in_lab)
	profile = for_profile
	trainer = "iyer"
	done_text = "Continue"


func _op() -> OperationTask:
	return task as OperationTask


func _kicker_text() -> String:
	return "Theatre 2 · Rohit Kulkarni"


func _build() -> void:
	_leave.visible = false
	monitor = VitalsMonitor.new()
	monitor.name = "Monitor"
	monitor.anchor_left = 1.0
	monitor.anchor_right = 1.0
	monitor.offset_left = -UiKit.px(12 + MONITOR_SIZE.x)
	monitor.offset_right = -UiKit.px(12)
	monitor.offset_top = UiKit.px(12)
	monitor.offset_bottom = UiKit.px(12 + MONITOR_SIZE.y)
	monitor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(monitor)
	_build_meters()
	ring = InstrumentRing.new()
	ring.name = "Ring"
	ring.ring_scale = 0.74
	ring.anchor_left = 1.0
	ring.anchor_right = 1.0
	ring.anchor_top = 1.0
	ring.anchor_bottom = 1.0
	ring.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ring.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ring.offset_right = -UiKit.px(14)
	ring.offset_bottom = -UiKit.px(8)
	ring.picked.connect(call_for)
	add_child(ring)
	_build_choices()
	_hold = UiKit.primary_button("Hold", 64, 18)
	_hold.name = "Hold"
	_hold.clip_contents = true
	_corner(_hold, 210)
	_hold_fill = ColorRect.new()
	_hold_fill.name = "Fill"
	UiKit.fill(_hold_fill)
	_hold_fill.anchor_right = 0.0
	_hold_fill.color = Color(1, 1, 1, 0.35)
	_hold_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hold.add_child(_hold_fill)
	_hold.button_down.connect(hold)
	_hold.button_up.connect(release)
	add_child(_hold)
	_tie = UiKit.primary_button("Tie off", 52, 17)
	_tie.name = "TieOff"
	_corner(_tie, 170)
	_tie.pressed.connect(tie_off)
	add_child(_tie)
	_sync()


func _corner(control: Control, width: float) -> void:
	control.anchor_left = 1.0
	control.anchor_right = 1.0
	control.anchor_top = 1.0
	control.anchor_bottom = 1.0
	control.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	control.grow_vertical = Control.GROW_DIRECTION_BEGIN
	control.offset_right = -UiKit.px(16)
	control.offset_bottom = -UiKit.px(16)
	control.custom_minimum_size = Vector2(UiKit.px(width), 0)


func _build_meters() -> void:
	_meters = UiKit.panel(Color(7 / 255.0, 32 / 255.0, 37 / 255.0, 0.9), 12, Vector2(10, 7))
	_meters.name = "Meters"
	_meters.anchor_left = 1.0
	_meters.anchor_right = 1.0
	_meters.offset_left = -UiKit.px(12 + MONITOR_SIZE.x)
	_meters.offset_right = -UiKit.px(12)
	_meters.offset_top = UiKit.px(18 + MONITOR_SIZE.y)
	_meters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_meters)
	var column := UiKit.vbox(4)
	_meters.add_child(column)
	var top := UiKit.hbox(6)
	column.add_child(top)
	_stability_label = UiKit.label("ROHIT · STABLE", 11, UiKit.TEXT_KICKER, UiKit.heavy_font())
	_stability_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_stability_label)
	_teamwork_label = UiKit.label("TEAMWORK 100", 11, UiKit.TEXT_KICKER, UiKit.heavy_font())
	top.add_child(_teamwork_label)
	var track := Control.new()
	track.custom_minimum_size = Vector2(0, UiKit.px(6))
	column.add_child(track)
	var back := ColorRect.new()
	back.color = Color(1, 1, 1, 0.14)
	UiKit.fill(back)
	track.add_child(back)
	_stability_fill = ColorRect.new()
	UiKit.fill(_stability_fill)
	_stability_fill.anchor_right = 1.0
	track.add_child(_stability_fill)


func _build_choices() -> void:
	_choices = UiKit.panel(Color(7 / 255.0, 32 / 255.0, 37 / 255.0, 0.94), 16, Vector2(14, 12))
	_choices.name = "Choices"
	_choices.anchor_left = 1.0
	_choices.anchor_right = 1.0
	_choices.anchor_top = 1.0
	_choices.anchor_bottom = 1.0
	_choices.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_choices.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_choices.offset_right = -UiKit.px(12)
	_choices.offset_bottom = -UiKit.px(12)
	_choices.custom_minimum_size = Vector2(UiKit.px(252), 0)
	add_child(_choices)
	var column := UiKit.vbox(6)
	_choices.add_child(column)
	_choice_kicker = UiKit.kicker("", 11)
	column.add_child(_choice_kicker)
	_choice_text = UiKit.label("", 16, UiKit.TEXT, UiKit.heading_font())
	_choice_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_choice_text.custom_minimum_size = Vector2(UiKit.px(224), 0)
	column.add_child(_choice_text)
	_choice_list = UiKit.vbox(6)
	column.add_child(_choice_list)


# --- What the player does -------------------------------------------------

func call_for(instrument: String) -> void:
	var op := _op()
	if result_open() or op.finished or op.phase != "call":
		return
	var expected := op.wanted
	op.call_for(instrument)
	if instrument != expected and not (op.step in ["bleeding", "burst"] and instrument in ["suction", "swab"]):
		ring.mark(instrument, "wrong")
	_sync()


func answer(choice: String) -> void:
	var op := _op()
	if result_open() or op.finished:
		return
	match op.phase:
		"timeout":
			op.answer_timeout(choice)
		"decide":
			op.decide(choice)
		"count":
			op.count(choice)
	_sync()


func hold() -> void:
	_op().hold_start()


func release() -> void:
	_op().hold_stop()


func tie_off() -> void:
	_op().tie_off()


func world_press(screen_point: Vector2) -> void:
	var op := _op()
	if op.phase != "act" or op.action != "trace":
		return
	var spot: Variant = _skin_at(screen_point)
	if spot != null:
		op.trace_begin(spot as Vector2)


func world_move(screen_point: Vector2) -> void:
	var op := _op()
	if not op.tracing:
		return
	var spot: Variant = _skin_at(screen_point)
	if spot != null:
		op.trace_to(spot as Vector2)


func world_release(_screen_point: Vector2) -> void:
	var op := _op()
	if op.tracing:
		op.trace_end()


func world_tap(screen_point: Vector2) -> void:
	var op := _op()
	if op.phase == "act" and op.action == "stitch":
		var spot: Variant = _skin_at(screen_point)
		if spot != null:
			op.place_stitch(spot as Vector2)
		return
	if op.phase == "search" or (op.phase == "act" and op.action == "tap"):
		var table := station() as OperatingTable
		var camera := view_camera()
		if table == null or camera == null:
			return
		var found := table.target_at(camera, screen_point, op)
		if not found.is_empty():
			op.tap(found)


func _skin_at(screen_point: Vector2) -> Variant:
	var table := station() as OperatingTable
	var camera := view_camera()
	if table == null or camera == null:
		return null
	return table.skin_point(camera, screen_point)


# --- Every frame ----------------------------------------------------------

func _tick(delta: float) -> void:
	monitor.tick(delta)
	_sync()


func _coach_line() -> Array:
	var op := _op()
	trainer = op.speaker
	return [op.coach, op.coach_warns]


func _sync() -> void:
	var op := _op()
	if op == null or ring == null:
		return
	monitor.set_vitals(op.vitals)
	monitor.status = op.condition()
	monitor.status_colour = VitalsMonitor.RIGHT if op.condition() == "STABLE" else VitalsMonitor.ALARM
	var steady := op.stability / 100.0
	_stability_fill.anchor_right = clampf(steady, 0.0, 1.0)
	_stability_fill.color = UiKit.MINT if op.stability >= 70.0 else (UiKit.AMBER if op.stability >= 40.0 else UiKit.CORAL)
	_stability_label.text = "ROHIT · %s" % _condition_word(op)
	_teamwork_label.text = "TEAMWORK %d" % op.teamwork()
	var call_key := "%s%d" % [op.step, op.calls]
	if call_key != _shown_call:
		_shown_call = call_key
		ring.clear_marks()
	var open := not result_open() and not op.finished
	ring.visible = open and op.phase == "call"
	_hold.visible = open and op.phase == "act" and op.action == "hold"
	_hold.text = "Hold the suction" if op.step == "burst" else "Hold it open"
	var needed := OperationTask.WASH_TIME if op.step == "burst" else OperationTask.HOLD_TIME
	_hold_fill.anchor_right = clampf(op.hold_time / needed, 0.0, 1.0)
	_tie.visible = open and op.phase == "act" and op.action == "stitch" and not op.stitches.is_empty()
	_sync_choices(op, open)


func _condition_word(op: OperationTask) -> String:
	if op.takeover:
		return "DR. IYER IN CHARGE"
	if op.stability >= 70.0:
		return "STABLE"
	if op.stability >= 40.0:
		return "UNSTEADY"
	return "CRITICAL"


func _sync_choices(op: OperationTask, open: bool) -> void:
	var key := ""
	var kicker := ""
	var text := ""
	var entries: Array = []
	match op.phase:
		"timeout":
			var line := op.timeout_line()
			if not line.is_empty():
				key = "timeout%d" % op.timeout_index
				kicker = "TIME-OUT BOARD · %s" % str(line["label"]).to_upper()
				text = str(line["reads"])
				for choice: String in op.timeout_choices():
					entries.append([choice, TIMEOUT_TEXT[choice]])
		"decide":
			key = "decide%s%d" % [op.step, op.decisions_wrong]
			kicker = OperationTask.title_of_step(op.step).to_upper()
			text = "What do you do?"
			for option: Dictionary in op.options:
				entries.append([option["id"], option["text"]])
		"count":
			key = "count%d" % op.recounts
			kicker = "THE COUNT · TOM"
			text = "Swabs: %d out, %d back" % [op.swabs_out, op.swabs_back]
			for option: Dictionary in op.options:
				entries.append([option["id"], option["text"]])
	_choices.visible = open and not key.is_empty()
	if key == _choice_key:
		return
	_choice_key = key
	_choice_kicker.text = kicker
	_choice_text.text = text
	for child in _choice_list.get_children():
		_choice_list.remove_child(child)
		child.queue_free()
	for entry: Array in entries:
		var button := small_button(str(entry[1]), 38, 14)
		button.name = str(entry[0]).to_pascal_case()
		button.pressed.connect(answer.bind(str(entry[0])))
		_choice_list.add_child(button)


## The button for an answer on the right-hand card, for tests.
func choice_button(choice: String) -> Button:
	return _choice_list.get_node_or_null(choice.to_pascal_case()) as Button


func _hide_controls() -> void:
	ring.visible = false
	_choices.visible = false
	_hold.visible = false
	_tie.visible = false


# --- The score card -------------------------------------------------------

func show_result(reward: String) -> void:
	var op := _op()
	if _result != null:
		_result.queue_free()
	_result = UiKit.panel(UiKit.PANEL_DEEP, 20, Vector2(22, 16))
	_result.name = "Result"
	_result.mouse_filter = Control.MOUSE_FILTER_STOP
	_result.anchor_left = 0.5
	_result.anchor_right = 0.5
	_result.anchor_top = 0.5
	_result.anchor_bottom = 0.5
	_result.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_result.grow_vertical = Control.GROW_DIRECTION_BOTH
	_result.custom_minimum_size = Vector2(UiKit.px(500), 0)
	add_child(_result)
	var column := UiKit.vbox(8)
	_result.add_child(column)
	var top := UiKit.hbox(12)
	column.add_child(top)
	var names := UiKit.vbox(2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(names)
	names.add_child(UiKit.kicker("Appendectomy · Rohit Kulkarni"))
	var headline := UiKit.heading(str(OUTCOME_LINES.get(op.outcome, "Done.")), 21)
	headline.name = "Outcome"
	names.add_child(headline)
	var stars := UiKit.hbox(4)
	stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(stars)
	for index in 3:
		var lit := index < op.stars()
		stars.add_child(UiIcon.make("star" if lit else "star_off", 28, UiKit.AMBER if lit else Color(UiKit.TEXT, 0.35)))
	var score_row := UiKit.hbox(10)
	column.add_child(score_row)
	var score_label := UiKit.label("%d / 100" % op.score(), 18, UiKit.TEXT, UiKit.heading_font())
	score_label.name = "Score"
	score_row.add_child(score_label)
	if not reward.is_empty():
		var reward_label := UiKit.label(reward, 13, UiKit.AMBER, UiKit.heavy_font())
		reward_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		score_row.add_child(reward_label)
	var parts := UiKit.hbox(8)
	column.add_child(parts)
	for entry: Array in [["Rohit", int(round(op.stability))], ["Teamwork", op.teamwork()], ["Technique", op.technique()],
			["Safety", op.safety()]]:
		var cell := UiKit.panel(Color(1, 1, 1, 0.06), 10, Vector2(8, 5))
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		parts.add_child(cell)
		var stack := UiKit.vbox(0)
		cell.add_child(stack)
		stack.add_child(UiKit.label(str(entry[0]).to_upper(), 10, UiKit.TEXT_KICKER, UiKit.heavy_font()))
		var value := int(entry[1])
		stack.add_child(UiKit.label(str(value), 17, UiKit.MINT if value >= 70 else (UiKit.AMBER if value >= 40 else UiKit.CORAL),
			UiKit.heading_font()))
	for note in op.notes().slice(0, 4):
		var row := UiKit.hbox(8)
		column.add_child(row)
		var ok := bool(note["ok"])
		var icon := UiIcon.make("check" if ok else "cross", 17, UiKit.MINT if ok else UiKit.CORAL)
		icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(icon)
		var text := UiKit.label(str(note["text"]), 12, Color("#DCEDEA"))
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(UiKit.px(440), 0)
		row.add_child(text)
	var buttons := UiKit.hbox(10)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(buttons)
	var done := UiKit.primary_button(done_text, 42, 16)
	done.name = "Done"
	done.pressed.connect(func() -> void: done_pressed.emit())
	buttons.add_child(done)
	_header.visible = false
	_leave.visible = false
	monitor.visible = false
	_meters.visible = false
	_hide_controls()
	_refresh()
