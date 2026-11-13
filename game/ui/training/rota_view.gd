class_name RotaView
extends TrainingView
## Strike-day cover: who is left to work along the top (each with what they
## carry out of their limit, and whether they can run a drip), the patients
## below with their weight and needs. Tap a patient (Grace says who they
## are), then whoever takes them; the name goes on the patient's card, mint,
## or coral on easy when it breaks a rule. On easy the rules sit on a card
## under the header. Grace gives hints if you ask (not on extreme).

const NEED_WORDS := {"iv": "drip", "infectious": "infection", "fragile": "fragile", "confused": "confused"}

var _panel: PanelContainer
var _staff_buttons := {}
var _rows := {}
var _hint: Button
var _sign: Button
var _card: PanelContainer
var _plain := {}
var _marked := {}


func _build() -> void:
	var rota := _rota()
	trainer = rota.actor
	_panel = _right_panel(420)
	_panel.name = "Rota"
	_panel.anchor_bottom = 1.0
	_panel.offset_bottom = -UiKit.px(12)
	var column := UiKit.vbox(6)
	_panel.add_child(column)
	_build_staff(column)
	_build_patients(column)
	var row := UiKit.hbox(8)
	column.add_child(row)
	_hint = small_button("Ask Grace", 42, 13)
	_hint.name = "Hint"
	_hint.pressed.connect(ask_hint)
	row.add_child(_hint)
	_sign = UiKit.primary_button("Sign the rota", 42, 15)
	_sign.name = "Sign"
	_sign.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sign.pressed.connect(sign)
	row.add_child(_sign)
	if rota.difficulty == "easy":
		_build_card()
	_sync()


## Who is left to work, in one row: each with load, limit and drips.
func _build_staff(column: VBoxContainer) -> void:
	var grid := UiKit.grid(_rota().staff.size(), 6)
	grid.name = "Staff"
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(grid)
	for member in _rota().staff:
		var staff_id := str(member["id"])
		var button := small_button(str(member["short"]), 42, 11)
		button.name = staff_id.to_pascal_case()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(UiKit.px(70), UiKit.px(42))
		button.pressed.connect(give_to.bind(staff_id))
		grid.add_child(button)
		_staff_buttons[staff_id] = button
		_remember_styles(button)


## The patients, three to a row: name and who has them, then weight and needs.
func _build_patients(column: VBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Patients"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var grid := UiKit.grid(3, 5)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for entry in _rota().patients:
		var patient_id := str(entry["id"])
		var button := small_button(patient_text(entry, ""), 40, 11)
		button.name = patient_id.to_pascal_case()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(UiKit.px(120), UiKit.px(40))
		button.pressed.connect(pick.bind(patient_id))
		grid.add_child(button)
		_rows[patient_id] = button
		_remember_styles(button)


## "Mrs. Chawla → Tom" over "2 · drip · infection".
static func patient_text(entry: Dictionary, with: String) -> String:
	var name := str(entry.get("short", ""))
	return "%s%s\n%s" % [name, "" if with.is_empty() else " → " + with, needs_text(entry)]


## "3 · drip · fragile": how much nursing they need, and what kind.
static func needs_text(entry: Dictionary) -> String:
	var words: Array[String] = [str(int(entry.get("load", 1)))]
	for key: String in NEED_WORDS:
		if bool(entry.get(key, false)):
			words.append(str(NEED_WORDS[key]))
	return " · ".join(words)


## "4/6 drips": what someone carries out of their limit, and whether they
## can run a drip ("student" for a student nurse).
static func staff_text(member: Dictionary, load: int) -> String:
	var can := "drips" if bool(member.get("iv", false)) else "no drips"
	if bool(member.get("student", false)):
		can = "student"
	return "%s\n%d/%d %s" % [member.get("short", ""), load, int(member.get("capacity", 0)), can]


## The rules on a card under the header (easy only).
func _build_card() -> void:
	_card = UiKit.panel(Color(1, 1, 1, 0.94), 14, Vector2(12, 6))
	_card.name = "Rules"
	_card.custom_minimum_size = Vector2(UiKit.px(300), 0)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	var column := UiKit.vbox(2)
	_card.add_child(column)
	column.add_child(UiKit.label("LIFE AND LIMB COVER", 11, UiKit.TEAL, UiKit.heavy_font()))
	var lines: Array[String] = ["The number is how much nursing they need"]
	var has_student := _rota().staff.any(func(m: Dictionary) -> bool: return bool(m.get("student", false)))
	for rule: String in RotaTask.RULES:
		if rule != "student" or has_student:
			lines.append(str(RotaTask.RULE_NAMES[rule]))
	for text in lines:
		var line := UiKit.label("• " + text, 12, UiKit.INK, UiKit.heavy_font())
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(UiKit.px(276), 0)
		column.add_child(line)


func _remember_styles(button: Button) -> void:
	var plain := {}
	var marked := {}
	for state in ["normal", "hover", "focus", "pressed", "hover_pressed"]:
		var style := button.get_theme_stylebox(state) as StyleBoxFlat
		if style == null:
			continue
		plain[state] = style
		var copy := style.duplicate() as StyleBoxFlat
		copy.border_color = UiKit.AMBER
		copy.bg_color = Color(UiKit.AMBER, 0.22)
		copy.set_border_width_all(int(maxf(2.0, UiKit.px(2))))
		marked[state] = copy
	_plain[button] = plain
	_marked[button] = marked


## Amber edge for the patient being placed, and for who can take them.
func _mark(button: Button, on: bool) -> void:
	var styles: Dictionary = _marked[button] if on else _plain[button]
	for state: String in styles:
		button.add_theme_stylebox_override(state, styles[state])


func _rota() -> RotaTask:
	return task as RotaTask


func pick(patient_id: String) -> void:
	if result_open():
		return
	_rota().select(patient_id)
	_sync()


func give_to(staff_id: String) -> void:
	if result_open():
		return
	_rota().assign(staff_id)
	_sync()


func ask_hint() -> void:
	if result_open():
		return
	_rota().hint()
	_sync()


func sign() -> void:
	if result_open():
		return
	_rota().sign_rota()
	_sync()


func _tick(_delta: float) -> void:
	_sync()


func _sync() -> void:
	var rota := _rota()
	if rota == null or _sign == null:
		return
	voice_override = rota.speaker
	speaker_override = str(StoryBook.cast().get(rota.speaker, {}).get("name", rota.speaker.capitalize()))
	var placing := not rota.selected.is_empty()
	for staff_id: String in _staff_buttons:
		var button: Button = _staff_buttons[staff_id]
		button.text = staff_text(rota.member(staff_id), rota.load_of(staff_id))
		button.disabled = rota.finished or not placing
	# On easy, a rule broken shows on the card of whoever it touches.
	var broken := {}
	if rota.difficulty == "easy":
		for problem in rota.problems():
			for patient_id: String in problem["patients"]:
				broken[patient_id] = true
	for patient_id: String in _rows:
		var button: Button = _rows[patient_id]
		var with := str(rota.assigned.get(patient_id, ""))
		button.text = patient_text(rota.patient(patient_id), "" if with.is_empty() else str(rota.member(with).get("short", with)))
		button.disabled = rota.finished
		_mark(button, patient_id == rota.selected)
		var colour := UiKit.CORAL if broken.has(patient_id) else (UiKit.MINT if not with.is_empty() else UiKit.TEXT)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			button.add_theme_color_override(state, colour)
	_hint.visible = rota.hints_allowed()
	var cost := rota.hint_cost()
	var first := str(StoryBook.cast().get(rota.actor, {}).get("name", "Grace")).split(" ")
	var call := first[1] if first.size() > 1 and first[0] == "Sister" else first[0]
	_hint.text = "Ask %s%s" % [call, " · -%d" % cost if cost > 0 else ""]
	_hint.disabled = rota.finished
	_sign.disabled = rota.finished
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


func patient_button(patient_id: String) -> Button:
	return _rows.get(patient_id)


func staff_button(staff_id: String) -> Button:
	return _staff_buttons.get(staff_id)
