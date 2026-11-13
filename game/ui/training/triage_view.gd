class_name TriageView
extends TrainingView
## Sort the casualties of a crash: the list of casualties on the right, each
## with their tag once given. Tap one to check them in order (walk, breathing,
## airway, breaths, nail bed, a command) and tag them; "Back to the list"
## takes Send's place while looking. On easy the START
## rules sit on a card under the header. Priya speaks in the speech box, and
## gives hints if you ask (not on extreme).

const TAG_COLOURS := {"red": UiKit.CORAL, "yellow": UiKit.AMBER, "green": UiKit.MINT, "black": Color("#AEB8BC")}
## Shorter words on the buttons, so a casualty's whole card fits an iPhone.
const CHECK_BUTTONS := {"walk": "Walk?", "breathing": "Breathing?", "airway": "Open airway", "rate": "Count breaths",
	"pulse": "Nail bed", "commands": "Squeeze hand"}
const RULES := ["Walks: GREEN", "Not breathing: open the airway. Breathes: RED. Still not: BLACK",
	"Breathing over 30: RED", "Nail bed over 2 seconds: RED", "Can't follow a command: RED", "Otherwise: YELLOW"]

var _panel: PanelContainer
var _kicker: Label
var _list_box: VBoxContainer
var _detail_box: VBoxContainer
var _who: Label
var _found: Label
var _rows := {}
var _chips := {}
var _checks := {}
var _tags := {}
var _hint: Button
var _send: Button
var _back: Button
var _card: PanelContainer


func _build() -> void:
	var triage := _triage()
	trainer = triage.actor
	_panel = _right_panel(360)
	_panel.name = "Triage"
	_panel.anchor_bottom = 1.0
	_panel.offset_bottom = -UiKit.px(12)
	var column := UiKit.vbox(8)
	_panel.add_child(column)
	_kicker = UiKit.kicker("TRIAGE · " + triage.place.to_upper(), 11)
	column.add_child(_kicker)
	_build_list(column)
	_build_detail(column)
	var row := UiKit.hbox(8)
	column.add_child(row)
	_hint = small_button("Ask Priya", 42, 13)
	_hint.name = "Hint"
	_hint.pressed.connect(ask_hint)
	row.add_child(_hint)
	_send = UiKit.primary_button("Send them in", 42, 15)
	_send.name = "Send"
	_send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_send.pressed.connect(send)
	row.add_child(_send)
	# Looking at someone, the way back to the list takes Send's place.
	_back = small_button("Back to the list", 42, 13)
	_back.name = "Back"
	_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_back.pressed.connect(back)
	_back.visible = false
	row.add_child(_back)
	if triage.difficulty == "easy":
		_build_card()
	_sync()


func _build_list(column: VBoxContainer) -> void:
	_list_box = UiKit.vbox(6)
	_list_box.name = "Casualties"
	_list_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_list_box)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_box.add_child(scroll)
	var grid := UiKit.grid(2, 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for entry in _triage().casualties:
		var casualty_id := str(entry["id"])
		var cell := UiKit.vbox(2)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(cell)
		var button := small_button("%d · %s" % [int(entry["number"]), entry.get("who", "")], 44, 12)
		button.name = casualty_id.to_pascal_case()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(UiKit.px(160), UiKit.px(44))
		button.pressed.connect(pick.bind(casualty_id))
		cell.add_child(button)
		_rows[casualty_id] = button
		var chip := UiKit.label("", 10, UiKit.MINT, UiKit.heavy_font())
		cell.add_child(chip)
		_chips[casualty_id] = chip


func _build_detail(column: VBoxContainer) -> void:
	_detail_box = UiKit.vbox(6)
	_detail_box.name = "Casualty"
	_detail_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_box.visible = false
	column.add_child(_detail_box)
	_who = UiKit.label("", 14, UiKit.TEXT, UiKit.heavy_font())
	_who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_box.add_child(_who)
	_found = UiKit.label("", 12, UiKit.TEXT_SOFT)
	_found.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_box.add_child(_found)
	var checks := UiKit.grid(3, 6)
	checks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_box.add_child(checks)
	for check: String in TriageTask.CHECKS:
		var button := small_button(str(CHECK_BUTTONS[check]), 34, 12)
		button.name = check.to_pascal_case()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(UiKit.px(100), UiKit.px(34))
		button.pressed.connect(check_sign.bind(check))
		checks.add_child(button)
		_checks[check] = button
	var tags := UiKit.grid(4, 6)
	tags.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_box.add_child(tags)
	for which: String in TriageTask.TAGS:
		var button := _tag_button(which)
		button.pressed.connect(give_tag.bind(which))
		tags.add_child(button)
		_tags[which] = button


## A tag button: the tag's colour on its edge and its name.
func _tag_button(which: String) -> Button:
	var button := small_button(which.capitalize(), 38, 13)
	button.name = "Tag" + which.to_pascal_case()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(UiKit.px(74), UiKit.px(38))
	var colour: Color = TAG_COLOURS[which]
	for state in ["normal", "hover", "focus", "pressed", "hover_pressed"]:
		var style := button.get_theme_stylebox(state) as StyleBoxFlat
		if style != null:
			var copy := style.duplicate() as StyleBoxFlat
			copy.border_color = colour
			copy.set_border_width_all(int(maxf(2.0, UiKit.px(2))))
			button.add_theme_stylebox_override(state, copy)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, colour)
	button.add_theme_font_override("font", UiKit.heavy_font())
	return button


## The START rules on a card under the header (easy only).
func _build_card() -> void:
	_card = UiKit.panel(Color(1, 1, 1, 0.94), 14, Vector2(12, 6))
	_card.name = "Rules"
	_card.custom_minimum_size = Vector2(UiKit.px(300), 0)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	var column := UiKit.vbox(2)
	_card.add_child(column)
	column.add_child(UiKit.label("START · IN THIS ORDER", 11, UiKit.TEAL, UiKit.heavy_font()))
	for rule: String in RULES:
		var line := UiKit.label("• " + rule, 12, UiKit.INK, UiKit.heavy_font())
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(UiKit.px(276), 0)
		column.add_child(line)


func _triage() -> TriageTask:
	return task as TriageTask


func pick(casualty_id: String) -> void:
	if result_open():
		return
	_triage().select(casualty_id)
	_sync()


func back() -> void:
	if result_open():
		return
	_triage().back()
	_sync()


func check_sign(what: String) -> void:
	if result_open():
		return
	_triage().check(what)
	_sync()


func give_tag(which: String) -> void:
	if result_open():
		return
	_triage().tag(which)
	_sync()


func ask_hint() -> void:
	if result_open():
		return
	_triage().hint()
	_sync()


func send() -> void:
	if result_open():
		return
	_triage().finish_triage()
	_sync()


func _tick(_delta: float) -> void:
	_sync()


func _sync() -> void:
	var triage := _triage()
	if triage == null or _kicker == null:
		return
	voice_override = triage.speaker
	speaker_override = str(StoryBook.cast().get(triage.speaker, {}).get("name", triage.speaker.capitalize()))
	var looking := not triage.selected.is_empty()
	if looking and _list_box.visible:
		_detail_box.custom_minimum_size.x = _list_box.size.x
	_list_box.visible = not looking
	_detail_box.visible = looking
	if looking:
		var entry := triage.casualty(triage.selected)
		_who.text = "%d · %s" % [int(entry["number"]), entry.get("who", "")]
		var lines: Array[String] = []
		for done: String in triage.checks_done(triage.selected):
			lines.append("• " + TriageTask.check_line(entry, done))
		_found.text = "\n".join(lines) if not lines.is_empty() else str(entry.get("looks", ""))
		for check: String in _checks:
			(_checks[check] as Button).disabled = not triage.can_check(triage.selected, check)
		for which: String in _tags:
			(_tags[which] as Button).disabled = triage.finished
	for casualty_id: String in _rows:
		var button: Button = _rows[casualty_id]
		button.disabled = triage.finished or triage.tags.has(casualty_id)
		var chip: Label = _chips[casualty_id]
		var given := str(triage.tags.get(casualty_id, ""))
		chip.text = "" if given.is_empty() else str(TriageTask.TAG_NAMES[given]).to_upper()
		if not given.is_empty():
			chip.add_theme_color_override("font_color", TAG_COLOURS[given])
	_hint.visible = triage.hints_allowed()
	var cost := triage.hint_cost()
	_hint.text = "Ask Priya" + (" · -%d" % cost if cost > 0 else "")
	_hint.disabled = triage.finished
	_send.disabled = triage.finished
	_send.visible = not looking
	_back.visible = looking
	_back.disabled = triage.finished
	_place_card()


func _place_card() -> void:
	if _header != null and _card != null:
		_card.position = Vector2(_header.position.x, _header.position.y + _header.get_combined_minimum_size().y + UiKit.px(8))


func _hide_controls() -> void:
	_panel.visible = false
	if _card != null:
		_card.visible = false


func _side_card() -> Control:
	return _card


func casualty_button(casualty_id: String) -> Button:
	return _rows.get(casualty_id)


func check_button(what: String) -> Button:
	return _checks.get(what)


func tag_button(which: String) -> Button:
	return _tags.get(which)
