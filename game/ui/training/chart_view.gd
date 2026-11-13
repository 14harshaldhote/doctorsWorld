class_name ChartView
extends TrainingView
## Check a drug chart: the patient's card under the header, the chart's lines
## on the right, and the intern who wrote it in the speech box. Tap a line,
## pick what is wrong with it, and sign when you are done. Dr. Iyer passes
## the desk if you ask for a hint (not on extreme).

const VERDICTS := {"found": ["Caught", UiKit.MINT], "half": ["Wrong reason", UiKit.AMBER], "false": ["It was right", UiKit.CORAL]}

var _panel: PanelContainer
var _kicker: Label
var _list_box: VBoxContainer
var _reason_box: VBoxContainer
var _picked: Label
var _lines := {}
var _chips := {}
var _reasons := {}
var _hint: Button
var _sign: Button
var _card: PanelContainer


func _build() -> void:
	var chart := _chart()
	trainer = chart.actor
	_panel = _right_panel(340)
	_panel.name = "Chart"
	_panel.anchor_bottom = 1.0
	_panel.offset_bottom = -UiKit.px(12)
	var column := UiKit.vbox(8)
	_panel.add_child(column)
	_kicker = UiKit.kicker("DRUG CHART · " + chart.patient.to_upper(), 11)
	column.add_child(_kicker)
	_build_lines(column)
	_build_reasons(column)
	var row := UiKit.hbox(8)
	column.add_child(row)
	_hint = small_button("Ask Dr. Iyer", 42, 13)
	_hint.name = "Hint"
	_hint.pressed.connect(ask_hint)
	row.add_child(_hint)
	_sign = UiKit.primary_button("Sign the chart", 42, 15)
	_sign.name = "Sign"
	_sign.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sign.pressed.connect(sign)
	row.add_child(_sign)
	_build_card()
	_sync()


func _build_lines(column: VBoxContainer) -> void:
	_list_box = UiKit.vbox(6)
	_list_box.name = "Lines"
	_list_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_list_box)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_box.add_child(scroll)
	var grid := UiKit.grid(2, 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for entry in _chart().lines:
		var line_id := str(entry["id"])
		var cell := UiKit.vbox(2)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(cell)
		var text := ChartTask.line_text(entry)
		var button := small_button("%s\n%s" % [text[0], text[1]], 50, 12)
		button.name = line_id.to_pascal_case()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(UiKit.px(150), UiKit.px(50))
		button.pressed.connect(pick.bind(line_id))
		cell.add_child(button)
		_lines[line_id] = button
		var chip := UiKit.label("", 10, UiKit.MINT, UiKit.heavy_font())
		cell.add_child(chip)
		_chips[line_id] = chip


func _build_reasons(column: VBoxContainer) -> void:
	_reason_box = UiKit.vbox(6)
	_reason_box.name = "Reasons"
	_reason_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reason_box.visible = false
	column.add_child(_reason_box)
	_picked = UiKit.label("", 14, UiKit.TEXT, UiKit.heavy_font())
	_picked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_picked.custom_minimum_size = Vector2(UiKit.px(310), 0)
	_reason_box.add_child(_picked)
	var grid := UiKit.grid(2, 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reason_box.add_child(grid)
	for reason: String in ChartTask.REASONS:
		var button := small_button(str(ChartTask.REASON_NAMES[reason]), 36, 12)
		button.name = reason.to_pascal_case()
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(UiKit.px(150), UiKit.px(36))
		button.pressed.connect(flag.bind(reason))
		grid.add_child(button)
		_reasons[reason] = button
	var leave := small_button("Leave it", 34, 12)
	leave.name = "LeaveIt"
	leave.pressed.connect(cancel)
	grid.add_child(leave)


func _build_card() -> void:
	_card = UiKit.panel(Color(1, 1, 1, 0.94), 14, Vector2(12, 6))
	_card.name = "PatientCard"
	_card.custom_minimum_size = Vector2(UiKit.px(300), 0)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	var column := UiKit.vbox(2)
	_card.add_child(column)
	var chart := _chart()
	column.add_child(UiKit.label("PATIENT CARD · " + chart.patient.to_upper(), 11, UiKit.TEAL, UiKit.heavy_font()))
	if not chart.about.is_empty():
		var about := UiKit.label(chart.about, 12, UiKit.INK.lightened(0.25))
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		about.custom_minimum_size = Vector2(UiKit.px(276), 0)
		column.add_child(about)
	for fact in chart.facts:
		var line := UiKit.label("• " + fact, 12, UiKit.INK, UiKit.heavy_font())
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(UiKit.px(276), 0)
		column.add_child(line)


func _chart() -> ChartTask:
	return task as ChartTask


func pick(line_id: String) -> void:
	if result_open():
		return
	_chart().select(line_id)
	_sync()


func cancel() -> void:
	if result_open():
		return
	_chart().cancel()
	_sync()


func flag(reason: String) -> void:
	if result_open():
		return
	_chart().flag(reason)
	_sync()


func ask_hint() -> void:
	if result_open():
		return
	_chart().hint()
	_sync()


func sign() -> void:
	if result_open():
		return
	_chart().sign()
	_sync()


func _tick(_delta: float) -> void:
	_sync()


func _sync() -> void:
	var chart := _chart()
	if chart == null or _kicker == null:
		return
	# The speech box shows whoever spoke last: the intern, or Dr. Iyer.
	voice_override = chart.speaker
	speaker_override = str(StoryBook.cast().get(chart.speaker, {}).get("name", chart.speaker.capitalize()))
	var picking := not chart.selected.is_empty()
	if picking and _list_box.visible:
		# The reasons take the chart's place at the chart's width.
		_reason_box.custom_minimum_size.x = _list_box.size.x
	_list_box.visible = not picking
	_reason_box.visible = picking
	if picking:
		var text := ChartTask.line_text(chart.line(chart.selected))
		_picked.text = "%s · %s" % [text[0], text[1]]
	for line_id: String in _lines:
		var button: Button = _lines[line_id]
		button.disabled = chart.finished or chart.is_flagged(line_id)
		var chip: Label = _chips[line_id]
		var verdict: Array = VERDICTS.get(str(chart.verdicts.get(line_id, "")), [])
		chip.text = "" if verdict.is_empty() else str(verdict[0]).to_upper()
		if not verdict.is_empty():
			chip.add_theme_color_override("font_color", verdict[1])
	_hint.visible = chart.hints_allowed()
	var cost := chart.hint_cost()
	_hint.text = "Ask Dr. Iyer" + (" · -%d" % cost if cost > 0 else "")
	_hint.disabled = chart.finished
	_sign.disabled = chart.finished
	_place_card()


func _place_card() -> void:
	if _header != null and _card != null:
		_card.position = Vector2(_header.position.x, _header.position.y + _header.get_combined_minimum_size().y + UiKit.px(8))


func _hide_controls() -> void:
	_panel.visible = false
	_card.visible = false


func _side_card() -> Control:
	return _card


func line_button(line_id: String) -> Button:
	return _lines.get(line_id)


func reason_button(reason: String) -> Button:
	return _reasons.get(reason)
