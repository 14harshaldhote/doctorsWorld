class_name ScanView
extends TrainingView
## Read an X-ray: the film fills the middle of the screen, Front and Side
## buttons swap the view, tapping what is on the film zooms in on it, and
## the answers wait on the right for when you have looked properly.

## Design pixels kept clear on the left (header, coach) and right (answers).
const LEFT := 320.0
const ANSWERS := 220.0

var film: XrayFilm
var _frame: PanelContainer
var _front: Button
var _side: Button
var _answers: PanelContainer
var _answer_buttons := {}


func _scan() -> ScanTask:
	return task as ScanTask


func _kicker_text() -> String:
	var scan := _scan()
	return "Radiology · " + (scan.about if scan != null else "")


func _build() -> void:
	var scan := _scan()
	_leave.visible = false
	_frame = UiKit.panel(Color("#1E2A2E"), 14, Vector2(8, 8))
	_frame.name = "Lightbox"
	add_child(_frame)
	# A narrower coach box, so the film has the middle of the screen.
	_coach_box.custom_minimum_size.x = UiKit.px(LEFT - 20)
	_coach_text.custom_minimum_size.x = UiKit.px(LEFT - 52)
	var column := UiKit.vbox(6)
	_frame.add_child(column)
	film = XrayFilm.new()
	film.name = "Film"
	film.truth = scan.truth
	film.custom_minimum_size = Vector2(UiKit.px(250), UiKit.px(250))
	film.object_tapped.connect(zoom)
	column.add_child(film)
	var row := UiKit.hbox(6)
	column.add_child(row)
	_front = small_button("Front", 36, 13)
	_front.name = "Front"
	_front.pressed.connect(show_view.bind("front"))
	row.add_child(_front)
	_side = small_button("Side", 36, 13)
	_side.name = "Side"
	_side.pressed.connect(show_view.bind("side"))
	row.add_child(_side)
	_answers = _right_panel(ANSWERS, 12)
	_answers.name = "Answers"
	_answers.anchor_top = 1.0
	_answers.anchor_bottom = 1.0
	_answers.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_answers.offset_top = 0
	_answers.offset_bottom = -UiKit.px(12)
	var list := UiKit.vbox(6)
	_answers.add_child(list)
	list.add_child(UiKit.kicker("What is it?", 11))
	for entry in scan.answers:
		var answer_id := str(entry.get("id", ""))
		var button := small_button(str(entry.get("text", answer_id)), 44, 13)
		button.name = answer_id.to_pascal_case()
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(UiKit.px(ANSWERS - 28), UiKit.px(44))
		button.pressed.connect(answer.bind(answer_id))
		list.add_child(button)
		_answer_buttons[answer_id] = button
	_sync()


func show_view(which: String) -> void:
	if result_open():
		return
	_scan().show_view(which)
	_sync()


func zoom() -> void:
	if result_open():
		return
	_scan().toggle_zoom()
	_sync()


func answer(answer_id: String) -> void:
	if result_open():
		return
	_scan().answer(answer_id)
	_sync()


func answer_button(answer_id: String) -> Button:
	return _answer_buttons.get(answer_id)


## The film's object, in screen pixels (for taps from tests and the robot).
func object_on_screen() -> Vector2:
	return film.global_position + film.object_centre()


func _tick(_delta: float) -> void:
	_sync()


func _sync() -> void:
	var scan := _scan()
	if scan == null or film == null:
		return
	film.set_state(scan.view, scan.zoomed)
	_front.disabled = scan.view == "front" and not scan.zoomed
	_side.disabled = scan.view == "side"
	_place_film()


## The film is as big as the space between the panels allows.
func _place_film() -> void:
	var room := UiKit.safe_insets().x
	var left := maxf(UiKit.px(LEFT) + room, _header.position.x + _header.size.x + UiKit.px(12))
	var right := UiKit.px(ANSWERS + 24) + room
	var wide := size.x - left - right
	var tall := size.y - UiKit.px(24) - UiKit.px(36 + 6 + 16)
	var side := maxf(UiKit.px(160), minf(wide - UiKit.px(16), tall))
	if not is_equal_approx(film.custom_minimum_size.x, side):
		film.custom_minimum_size = Vector2(side, side)
		_frame.reset_size()
	var box := _frame.get_combined_minimum_size()
	_frame.position = Vector2(left + (wide - box.x) / 2.0, (size.y - box.y) / 2.0)


func _hide_controls() -> void:
	_frame.visible = false
	_answers.visible = false
