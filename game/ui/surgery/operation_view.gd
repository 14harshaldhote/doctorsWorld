class_name OperationView
extends TrainingView
## The screen over the operating table in first person: what to do now (top
## left, with a hint under it on easy and hard cases), the patient monitor and
## how the patient is doing (top right), whoever is talking (bottom left),
## and on the right whatever the moment needs: the time-out board, the
## instrument ring, a decision, Tom's count, a hold button (or the gas
## gauge) or the tie-off button. The score card at the end tells the outcome,
## and there is no leaving halfway through an operation.

const MONITOR_SIZE := Vector2(236, 128)
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
var _hint_card: PanelContainer
var _hint_text: Label
var _hint_button: Button


func _init(for_task: TrainingTask = null, in_lab: Node = null, for_profile: PlayerProfile = null) -> void:
	super(for_task, in_lab)
	profile = for_profile
	trainer = "iyer"
	done_text = "Continue"


func _op() -> OperationTask:
	return task as OperationTask


func _kicker_text() -> String:
	var op := _op()
	if op == null:
		return "Theatre 2 · Rohit Kulkarni"
	return "%s · %s" % [str(op.procedure.get("theatre", "Theatre 2")), op.patient_name()]


func _build() -> void:
	_leave.visible = false
	monitor = VitalsMonitor.new()
	monitor.beeping = true
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
	ring.instruments = (_op().procedure.get("tray", Instruments.ALL) as Array).duplicate()
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
	_build_hint()
	_sync()


## Under the header: the hint itself on an easy case, or a button that asks
## Dr. Iyer for one on a hard case. Extreme cases have neither.
func _build_hint() -> void:
	_hint_card = UiKit.panel(Color(7 / 255.0, 32 / 255.0, 37 / 255.0, 0.88), 12, Vector2(10, 7))
	_hint_card.name = "Hint"
	_hint_card.custom_minimum_size = Vector2(UiKit.px(300), 0)
	add_child(_hint_card)
	var column := UiKit.vbox(4)
	_hint_card.add_child(column)
	var kicker := UiKit.kicker("HINT" if _op().difficulty == "easy" else "STUCK?", 10)
	kicker.add_theme_color_override("font_color", UiKit.AMBER)
	column.add_child(kicker)
	_hint_text = UiKit.label("", 12, Color("#DCEDEA"))
	_hint_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_text.custom_minimum_size = Vector2(UiKit.px(278), 0)
	column.add_child(_hint_text)
	_hint_button = small_button("Ask Dr. Iyer · costs %d points" % OperationTask.HINT_COST, 32, 12)
	_hint_button.name = "AskHint"
	_hint_button.pressed.connect(ask_hint)
	column.add_child(_hint_button)
	# The header grows when its text wraps (larger text, iPad), so the hint
	# follows it down rather than sitting on top of it.
	_header.resized.connect(_place_hint)
	_header.item_rect_changed.connect(_place_hint)


func _place_hint() -> void:
	_hint_card.position = Vector2(_header.position.x, _header.position.y + _header.size.y + UiKit.px(8))


## Asks for a hint on a hard case.
func ask_hint() -> void:
	if _op().use_hint().is_empty():
		return
	Sfx.play(self, "tap", -10.0)
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
	_stability_label = UiKit.label("%s · STABLE" % _op().patient_first().to_upper(), 11, UiKit.TEXT_KICKER, UiKit.heavy_font())
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
	_choices.item_rect_changed.connect(_make_room)
	_choices.visibility_changed.connect(_make_room)
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
	var helped := op.helps_now(instrument)
	op.call_for(instrument)
	if instrument != expected and not helped:
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
	_make_room()


## With big text a tall choice can reach up to the team meter: the monitor
## still shows how Rohit is, so the meter steps aside.
func _make_room() -> void:
	if _result != null or _meters == null:
		return
	_meters.visible = not (_choices.visible and _choices.position.y < _meters.position.y + _meters.size.y + UiKit.px(4))


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
	_stability_label.text = "%s · %s" % [op.patient_first().to_upper(), _condition_word(op)]
	_teamwork_label.text = "TEAMWORK %d" % op.teamwork()
	var call_key := "%s%d" % [op.step, op.calls]
	if call_key != _shown_call:
		_shown_call = call_key
		ring.clear_marks()
	var open := not result_open() and not op.finished
	ring.visible = open and op.phase == "call"
	_hold.visible = open and op.phase == "act" and op.action in ["hold", "fill"]
	if op.action == "fill":
		_hold.text = "%s · %d" % [op.hold_label(), int(op.fill_level)]
		_hold_fill.anchor_right = clampf(op.fill_level / OperationTask.FILL_MAX, 0.0, 1.0)
		var in_band := op.fill_level >= OperationTask.FILL_LOW and op.fill_level <= OperationTask.FILL_HIGH
		_hold_fill.color = Color(UiKit.MINT, 0.6) if in_band else (Color(UiKit.CORAL, 0.6)
			if op.fill_level > OperationTask.FILL_HIGH else Color(1, 1, 1, 0.35))
	else:
		_hold.text = op.hold_label()
		_hold_fill.anchor_right = clampf(op.hold_time / op.hold_needed(), 0.0, 1.0)
		_hold_fill.color = Color(1, 1, 1, 0.35)
	_tie.visible = open and op.phase == "act" and op.action == "stitch" and not op.stitches.is_empty()
	_sync_choices(op, open)
	_sync_hint(op, open)


func _sync_hint(op: OperationTask, open: bool) -> void:
	if _hint_card == null:
		return
	var easy := op.difficulty == "easy"
	var text := op.hint_text() if easy else ""
	_hint_card.visible = open and _header.visible and ((easy and not text.is_empty()) or op.can_hint())
	_hint_text.text = text
	_hint_text.visible = not text.is_empty()
	_hint_button.visible = op.can_hint()
	_place_hint()


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
			kicker = op.step_title(op.step).to_upper()
			text = op.decision_look() if not op.decision_look().is_empty() else "What do you do?"
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
	if _hint_card != null:
		_hint_card.visible = false


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
	names.add_child(UiKit.kicker("%s · %s%s" % [op.title(), op.patient_name(),
		"" if op.difficulty.is_empty() else " · " + op.difficulty.capitalize()]))
	var headline := UiKit.heading(op.outcome_line(), 21)
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
	for entry: Array in [[op.patient_first(), int(round(op.stability))], ["Teamwork", op.teamwork()], ["Technique", op.technique()],
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
	var notes := _note_list(column)
	for note in op.notes().slice(0, 4):
		var row := UiKit.hbox(8)
		notes.add_child(row)
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
	_fit_notes(notes, UiKit.px(440), 12)
	_header.visible = false
	_leave.visible = false
	monitor.visible = false
	_meters.visible = false
	_hide_controls()
	_refresh()
