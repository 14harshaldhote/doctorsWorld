class_name EveningPanel
extends Control
## The evening's menu (stage 27, Evening): a column down the right of the
## screen with the clock, how long the doctor would sleep if they went to
## bed now, how long since they called home, the things there's time for
## (each with what it costs on the clock; tonight's party first, in amber),
## and "Go to bed" at the bottom, always one tap away.

signal chosen(id: String)

## The column's width in design pixels, at the normal text size.
const WIDTH := 300.0

var bed_button: Button
var _column: PanelContainer
var _kicker: Label
var _place: Label
var _clock: Label
var _sleep: Label
var _home: Label
var _rows: VBoxContainer
var _shown := {}


func _ready() -> void:
	name = "EveningPanel"
	theme = UiKit.theme()
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column = UiKit.panel(Color(8 / 255.0, 24 / 255.0, 29 / 255.0, 0.93), 20, Vector2(16, 14))
	_column.name = "Column"
	var style := _column.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color = Color(UiKit.MINT, 0.28)
	style.set_border_width_all(2)
	add_child(_column)
	var stack := UiKit.vbox(10)
	_column.add_child(stack)
	var top := UiKit.hbox(10)
	stack.add_child(top)
	var titles := UiKit.vbox(2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(titles)
	_kicker = UiKit.kicker("")
	_kicker.name = "Kicker"
	titles.add_child(_kicker)
	_place = UiKit.heading("", 21)
	_place.name = "Place"
	_place.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(_place)
	_clock = UiKit.label("", 30, UiKit.AMBER, UiKit.heading_font())
	_clock.name = "Clock"
	_clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_clock)
	_sleep = _status_line("Sleep")
	stack.add_child(_sleep)
	_home = _status_line("Home")
	stack.add_child(_home)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)
	_rows = UiKit.vbox(8)
	_rows.name = "Rows"
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	bed_button = UiKit.primary_button("Go to bed", 50, 17)
	bed_button.name = "Bed"
	bed_button.focus_mode = Control.FOCUS_NONE
	bed_button.pressed.connect(func() -> void: chosen.emit("bed"))
	UiKit.respond_to_press(bed_button)
	stack.add_child(bed_button)
	resized.connect(_layout)
	_layout()
	if not _shown.is_empty():
		show_state(_shown)


func _status_line(id: String) -> Label:
	var made := UiKit.label("", 13, UiKit.TEXT_SOFT, UiKit.heavy_font())
	made.name = id
	made.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return made


## Down the right, clear of the notch and the home bar; a little wider when
## the text is bigger, never more than half the screen.
func _layout() -> void:
	if _column == null:
		return
	var view := get_viewport_rect().size if is_inside_tree() else size
	var wide := minf(UiKit.px(WIDTH) * GameSettings.current.text_scale(), view.x * 0.5)
	_column.anchor_left = 1.0
	_column.anchor_right = 1.0
	_column.anchor_top = 0.0
	_column.anchor_bottom = 1.0
	_column.offset_left = -wide - UiKit.px(14)
	_column.offset_right = -UiKit.px(14)
	_column.offset_top = UiKit.px(14)
	_column.offset_bottom = -UiKit.px(14)
	UiKit.keep_off_edges(_column)


## Shows the evening as it stands (Evening._state()).
func show_state(state: Dictionary) -> void:
	_shown = state
	if _rows == null:
		return
	_kicker.text = str(state.get("kicker", "")).to_upper()
	_place.text = str(state.get("place", ""))
	_clock.text = str(state.get("clock", ""))
	_sleep.text = str(state.get("sleep", ""))
	_sleep.add_theme_color_override("font_color", UiKit.CORAL if bool(state.get("sleep_warn", false)) else UiKit.MINT)
	_home.text = str(state.get("home", ""))
	_home.add_theme_color_override("font_color", UiKit.CORAL if bool(state.get("home_warn", false)) else UiKit.TEXT_SOFT)
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for row: Dictionary in state.get("rows", []):
		_rows.add_child(_row(row))
	bed_button.text = str(state.get("bed", "Go to bed"))
	if visible and not GameSettings.current.reduce_motion:
		UiKit.slide_in(_column, Vector2(UiKit.px(40), 0), 0.25)


## The row buttons on show, by activity (for tests and the screenshot tool).
func row_ids() -> PackedStringArray:
	var found := PackedStringArray()
	for child in _rows.get_children():
		found.append(str(child.get_meta("id", "")))
	return found


func _row(row: Dictionary) -> Button:
	var id := str(row.get("id", ""))
	var party := bool(row.get("highlight", false))
	var button := Button.new()
	button.name = "Row_" + id
	button.set_meta("id", id)
	button.focus_mode = Control.FOCUS_NONE
	var edge := UiKit.AMBER if party else Color(UiKit.MINT, 0.45)
	var normal := UiKit.box(Color(UiKit.AMBER, 0.1) if party else Color(1, 1, 1, 0.04), 12, edge, 2, Vector2(12, 9))
	var pressed := UiKit.box(Color(edge, 0.2), 12, edge, 2, Vector2(12, 9))
	for state in ["normal", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, normal)
	button.add_theme_stylebox_override("hover", pressed)
	button.add_theme_stylebox_override("pressed", pressed)
	var line := UiKit.hbox(8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	line.offset_left = UiKit.px(12)
	line.offset_right = -UiKit.px(12)
	line.offset_top = UiKit.px(9)
	line.offset_bottom = -UiKit.px(9)
	button.add_child(line)
	var words := UiKit.vbox(2)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(words)
	if party:
		words.add_child(UiKit.label("TONIGHT", 10, UiKit.AMBER, UiKit.heavy_font()))
	var title := UiKit.label(str(row.get("title", "")), 15, UiKit.TEXT, UiKit.heading_medium_font())
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(title)
	var sub := str(row.get("sub", ""))
	if not sub.is_empty():
		var small := UiKit.label(sub, 12, UiKit.TEXT_SOFT)
		small.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(small)
	var amount := int(row.get("minutes", 0))
	var cost := UiKit.label("+%d min" % amount if amount > 0 else "the night", 12,
		UiKit.AMBER if party else UiKit.MINT, UiKit.heavy_font())
	cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(cost)
	for child in line.find_children("*", "Control", true, false):
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.custom_minimum_size.y = UiKit.px(48)
	UiKit.fit_height(button, line, 9)
	button.pressed.connect(func() -> void: chosen.emit(id))
	UiKit.respond_to_press(button)
	return button
