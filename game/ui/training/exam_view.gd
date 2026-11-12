class_name ExamView
extends TrainingView
## Examine a patient: round buttons float over the places on their body you
## can examine, a notes card fills with what you find, and when you have
## seen enough, "Decide" lists what it could be. Emergencies add the
## patient monitor in the top right.

const DOT := 30.0
const MONITOR_SIZE := Vector2(236, 128)

var monitor: VitalsMonitor
var _spots_layer: Control
var _spots := {}
var _notes_card: PanelContainer
var _notes: VBoxContainer
var _shown_facts := -1
var _decide: Button
var _choices: PanelContainer
var _choice_list: VBoxContainer
var _choice_buttons := {}


func _exam() -> ExamTask:
	return task as ExamTask


func _kicker_text() -> String:
	var exam := _exam()
	return "Examination · " + (exam.about if exam != null and not exam.about.is_empty() else "Ward")


func _build() -> void:
	var exam := _exam()
	_leave.visible = false
	_spots_layer = Control.new()
	_spots_layer.name = "Spots"
	UiKit.fill(_spots_layer)
	_spots_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_spots_layer)
	move_child(_spots_layer, 0)
	for entry in exam.spots:
		var spot_id := str(entry.get("id", ""))
		var holder := VBoxContainer.new()
		holder.name = spot_id.to_pascal_case()
		holder.alignment = BoxContainer.ALIGNMENT_CENTER
		holder.add_theme_constant_override("separation", int(UiKit.px(2)))
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_spots_layer.add_child(holder)
		var dot := Button.new()
		dot.name = "Dot"
		dot.custom_minimum_size = Vector2(UiKit.px(DOT), UiKit.px(DOT))
		dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		dot.focus_mode = Control.FOCUS_NONE
		dot.pressed.connect(examine.bind(spot_id))
		holder.add_child(dot)
		var label := UiKit.label(str(entry.get("label", spot_id)), 11, UiKit.INK, UiKit.heavy_font())
		label.name = "Label"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var tag := UiKit.panel(Color(1, 1, 1, 0.9), 8, Vector2(6, 1))
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tag.add_child(label)
		holder.add_child(tag)
		_spots[spot_id] = holder
		_style_dot(dot, false)
	_build_notes()
	_decide = UiKit.primary_button("Decide", 46, 16)
	_decide.name = "Decide"
	_decide.anchor_left = 1.0
	_decide.anchor_right = 1.0
	_decide.anchor_top = 1.0
	_decide.anchor_bottom = 1.0
	_decide.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_decide.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_decide.offset_right = -UiKit.px(16)
	_decide.offset_bottom = -UiKit.px(16)
	_decide.custom_minimum_size = Vector2(UiKit.px(170), UiKit.px(46))
	_decide.pressed.connect(ready_to_decide)
	add_child(_decide)
	_build_choices()
	if exam.has_vitals:
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
		monitor.set_vitals(exam.vitals)
	_sync()


func _build_notes() -> void:
	_notes_card = UiKit.panel(Color(1, 1, 1, 0.94), 14, Vector2(12, 8))
	_notes_card.name = "ExamNotes"
	_notes_card.custom_minimum_size = Vector2(UiKit.px(250), 0)
	_notes_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notes_card)
	_notes = UiKit.vbox(3)
	_notes_card.add_child(_notes)


func _build_choices() -> void:
	_choices = UiKit.panel(Color(7 / 255.0, 32 / 255.0, 37 / 255.0, 0.94), 16, Vector2(14, 12))
	_choices.name = "Diagnoses"
	_choices.anchor_left = 1.0
	_choices.anchor_right = 1.0
	_choices.anchor_top = 1.0
	_choices.anchor_bottom = 1.0
	_choices.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_choices.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_choices.offset_right = -UiKit.px(12)
	_choices.offset_bottom = -UiKit.px(12)
	_choices.custom_minimum_size = Vector2(UiKit.px(286), 0)
	add_child(_choices)
	var column := UiKit.vbox(6)
	_choices.add_child(column)
	column.add_child(UiKit.kicker("What is it?", 11))
	_choice_list = UiKit.vbox(6)
	column.add_child(_choice_list)
	for entry in _exam().diagnoses:
		var diagnosis_id := str(entry.get("id", ""))
		var button := small_button(str(entry.get("text", diagnosis_id)), 40, 13)
		button.name = diagnosis_id.to_pascal_case()
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(UiKit.px(258), UiKit.px(40))
		button.pressed.connect(decide.bind(diagnosis_id))
		_choice_list.add_child(button)
		_choice_buttons[diagnosis_id] = button
	_choices.visible = false


func _style_dot(dot: Button, done: bool) -> void:
	var colour := UiKit.MINT if done else UiKit.AMBER
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := UiKit.box(Color(colour, 0.92 if state != "disabled" else 0.75), UiKit.px(DOT) / 2.0,
			Color.WHITE, UiKit.px(3))
		dot.add_theme_stylebox_override(state, style)


# --- What the player does -------------------------------------------------

func examine(spot_id: String) -> void:
	if result_open():
		return
	_exam().examine(spot_id)
	_sync()


func ready_to_decide() -> void:
	if result_open():
		return
	_exam().ready_to_decide()
	_sync()


func decide(diagnosis_id: String) -> void:
	if result_open():
		return
	_exam().decide(diagnosis_id)
	_sync()


## Taps on the patient pick the nearest spot, like the dots do.
func world_tap(screen_point: Vector2) -> void:
	var nearest := spot_at(screen_point)
	if not nearest.is_empty():
		examine(nearest)


func spot_at(screen_point: Vector2) -> String:
	var cam := view_camera()
	if cam == null:
		return ""
	var points := {}
	for entry in _exam().spots:
		var point: Variant = spot_point(str(entry.get("id", "")))
		if point != null:
			points[str(entry.get("id", ""))] = point
	return LabStation.nearest_on_screen(cam, screen_point, points, UiKit.px(34))


## Where a spot is in the world, from the station (the patient's body).
func spot_point(spot_id: String) -> Variant:
	var bed := station()
	if bed == null or not bed.has_method("spot_point"):
		return null
	return bed.spot_point(_exam().spot(spot_id))


func spot_button(spot_id: String) -> Button:
	var holder: Control = _spots.get(spot_id)
	return holder.get_node("Dot") as Button if holder != null else null


func choice_button(diagnosis_id: String) -> Button:
	return _choice_buttons.get(diagnosis_id)


# --- Every frame ------------------------------------------------------------

func _coach_line() -> Array:
	var exam := _exam()
	return [exam.coach, exam.coach_warns]


func _tick(_delta: float) -> void:
	_sync()


func _sync() -> void:
	var exam := _exam()
	if exam == null or _decide == null:
		return
	var patient_speaks := not exam.last_said.is_empty() and exam.coach == exam.last_said
	speaker_override = exam.patient if patient_speaks else ""
	voice_override = exam.actor if patient_speaks else ""
	var cam := view_camera()
	for spot_id: String in _spots:
		var holder: Control = _spots[spot_id]
		var point: Variant = spot_point(spot_id)
		var shown := cam != null and point != null and not cam.is_position_behind(point as Vector3) \
			and exam.phase == "examine" and not result_open()
		holder.visible = shown
		if shown:
			var at := cam.unproject_position(point as Vector3)
			holder.reset_size()
			holder.position = at - Vector2(holder.size.x / 2.0, UiKit.px(DOT) / 2.0)
		var dot := holder.get_node("Dot") as Button
		var done := exam.is_examined(spot_id)
		if dot.disabled != done:
			dot.disabled = done
			_style_dot(dot, done)
	_decide.visible = exam.phase == "examine" and not result_open()
	_decide.disabled = exam.examined.is_empty()
	_choices.visible = exam.phase == "decide" and not result_open()
	if monitor != null:
		monitor.set_vitals(exam.vitals)
		monitor.status = "BLEEDING" if exam.bleeding() else ("WEAK" if exam.stability < 60.0 else "STABLE")
		monitor.status_colour = VitalsMonitor.ALARM if exam.bleeding() or exam.stability < 60.0 else UiKit.MINT
	if exam.facts.size() != _shown_facts:
		_shown_facts = exam.facts.size()
		for child in _notes.get_children():
			_notes.remove_child(child)
			child.queue_free()
		_notes.add_child(UiKit.label("EXAM · " + exam.patient.to_upper(), 11, UiKit.TEAL, UiKit.heavy_font()))
		if exam.facts.is_empty():
			_notes.add_child(UiKit.label("Nothing found yet.", 12, UiKit.INK.lightened(0.3)))
		for fact in exam.facts:
			var line := UiKit.label("• " + fact, 12, UiKit.INK, UiKit.heavy_font())
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.custom_minimum_size = Vector2(UiKit.px(226), 0)
			_notes.add_child(line)
	if _header != null:
		_notes_card.position = Vector2(_header.position.x, _header.position.y + _header.get_combined_minimum_size().y + UiKit.px(8))


func _hide_controls() -> void:
	_spots_layer.visible = false
	_notes_card.visible = false
	_decide.visible = false
	_choices.visible = false


func _side_card() -> Control:
	return _notes_card
