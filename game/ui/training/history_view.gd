class_name HistoryView
extends TrainingView
## Take a history: the questions on the right, the patient's answers in the
## speech box, and a case notes card that fills up with what was learned.
## Each question asked gets a quick verdict from Dr. Iyer: it mattered, it
## was useful, or it told you nothing.

const VERDICTS := {"key": ["Matters", UiKit.MINT], "useful": ["Useful", UiKit.AMBER], "": ["No help", UiKit.CORAL]}

var _panel: PanelContainer
var _left: Label
var _questions := {}
var _chips := {}
var _done: Button
var _notes_card: PanelContainer
var _notes: VBoxContainer
var _shown_facts := -1


func _build() -> void:
	var history := _history()
	speaker_override = history.patient
	_panel = _right_panel(330)
	_panel.name = "Questions"
	_panel.anchor_bottom = 1.0
	_panel.offset_bottom = -UiKit.px(12)
	var column := UiKit.vbox(8)
	_panel.add_child(column)
	_left = UiKit.kicker("", 11)
	column.add_child(_left)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := UiKit.vbox(6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for entry in history.questions:
		var question_id := str(entry.get("id", ""))
		var row := UiKit.hbox(6)
		list.add_child(row)
		var button := small_button(str(entry.get("ask", "")), 38, 13)
		button.name = question_id.capitalize()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(UiKit.px(220), UiKit.px(38))
		button.pressed.connect(ask.bind(question_id))
		row.add_child(button)
		_questions[question_id] = button
		var chip := UiKit.label("", 11, UiKit.MINT, UiKit.heavy_font())
		chip.custom_minimum_size = Vector2(UiKit.px(58), 0)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(chip)
		_chips[question_id] = chip
	_done = UiKit.primary_button("I've got what I need", 42, 15)
	_done.name = "Done"
	_done.pressed.connect(done_asking)
	column.add_child(_done)
	_build_notes()
	_sync()


func _build_notes() -> void:
	# The notes card sits under the header, whatever the header's height.
	_notes_card = UiKit.panel(Color(1, 1, 1, 0.94), 14, Vector2(12, 8))
	_notes_card.name = "CaseNotes"
	_notes_card.custom_minimum_size = Vector2(UiKit.px(300), 0)
	_notes_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notes_card)
	_notes = UiKit.vbox(3)
	_notes_card.add_child(_notes)


func _history() -> HistoryTask:
	return task as HistoryTask


func ask(question_id: String) -> void:
	if result_open():
		return
	_history().ask(question_id)
	_sync()


func done_asking() -> void:
	if result_open():
		return
	_history().finish_early()
	_sync()


func _coach_line() -> Array:
	var history := _history()
	return [history.last_answer if not history.last_answer.is_empty() else history.opening, false]


func _tick(_delta: float) -> void:
	_sync()


func _place_notes() -> void:
	if _header != null and _notes_card != null:
		_notes_card.position = Vector2(UiKit.px(12), _header.position.y + _header.get_combined_minimum_size().y + UiKit.px(8))


func _sync() -> void:
	var history := _history()
	if history == null or _left == null:
		return
	_left.text = "Ask %s · %d left" % [history.patient, history.remaining()]
	for question_id: String in _questions:
		var button: Button = _questions[question_id]
		var asked := history.is_asked(question_id)
		button.disabled = asked or history.finished or history.remaining() <= 0
		var chip: Label = _chips[question_id]
		if asked:
			var verdict: Array = VERDICTS.get(str(history.question(question_id).get("weight", "")), VERDICTS[""])
			chip.text = str(verdict[0])
			chip.add_theme_color_override("font_color", verdict[1])
		else:
			chip.text = ""
	_done.disabled = history.asked.is_empty() or history.finished
	if history.facts.size() != _shown_facts:
		_shown_facts = history.facts.size()
		for child in _notes.get_children():
			_notes.remove_child(child)
			child.queue_free()
		_notes.add_child(UiKit.label("CASE NOTES · " + history.patient.to_upper(), 11, UiKit.TEAL, UiKit.heavy_font()))
		_notes.add_child(UiKit.label(history.about, 12, UiKit.INK.lightened(0.25)))
		for fact in history.facts:
			var line := UiKit.label("• " + fact, 12, UiKit.INK, UiKit.heavy_font())
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.custom_minimum_size = Vector2(UiKit.px(276), 0)
			_notes.add_child(line)
	_place_notes()


func _hide_controls() -> void:
	_panel.visible = false
	_notes_card.visible = false


func button_for(question_id: String) -> Button:
	return _questions.get(question_id)
