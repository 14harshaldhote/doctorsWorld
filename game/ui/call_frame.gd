class_name CallFrame
extends Control
## The video call home on the laptop (stage 27, Evening): the family fills
## the screen (the 3D behind), and this goes over it like a call app: who's
## on the call and how long it has been, a red dot that says it's live, and
## the doctor's own little picture in the corner, which is off, as always.
## It never takes a tap.

var names := PackedStringArray()
var seconds := 0.0
var _bar: PanelContainer
var _who: Label
var _time: Label
var _self: PanelContainer
var _edge: Panel


func _ready() -> void:
	name = "CallFrame"
	theme = UiKit.theme()
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A dark rounded edge round the whole picture, like a laptop's screen.
	_edge = Panel.new()
	_edge.name = "Edge"
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var edge := StyleBoxFlat.new()
	edge.draw_center = false
	edge.border_color = Color(0.03, 0.06, 0.08, 0.92)
	edge.set_border_width_all(int(UiKit.px(7)))
	edge.set_corner_radius_all(int(UiKit.px(22)))
	_edge.add_theme_stylebox_override("panel", edge)
	add_child(UiKit.fill(_edge))
	_bar = UiKit.panel(Color(0.03, 0.08, 0.1, 0.86), 14, Vector2(14, 7))
	_bar.name = "Bar"
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UiKit.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(row)
	var live := Panel.new()
	live.mouse_filter = Control.MOUSE_FILTER_IGNORE
	live.custom_minimum_size = Vector2(UiKit.px(10), UiKit.px(10))
	live.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	live.add_theme_stylebox_override("panel", UiKit.box(UiKit.CORAL, 5))
	row.add_child(live)
	_who = UiKit.label("", 14, UiKit.TEXT, UiKit.heavy_font())
	_who.name = "Who"
	row.add_child(_who)
	_time = UiKit.label("00:00", 14, UiKit.TEXT_SOFT, UiKit.heavy_font())
	_time.name = "Time"
	row.add_child(_time)
	_bar.anchor_left = 0.5
	_bar.anchor_right = 0.5
	_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bar.offset_top = UiKit.px(16)
	add_child(_bar)
	UiKit.keep_off_edges(_bar)
	# The doctor's own picture: the camera is off. Mum has noticed.
	_self = UiKit.panel(Color(0.06, 0.12, 0.15, 0.95), 12, Vector2(10, 8))
	_self.name = "Self"
	_self.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _self.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color = Color(1, 1, 1, 0.2)
	style.set_border_width_all(1)
	var column := UiKit.vbox(2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_self.add_child(column)
	column.add_child(UiKit.label("You", 12, UiKit.TEXT, UiKit.heavy_font()))
	column.add_child(UiKit.label("Camera off", 11, UiKit.TEXT_SOFT))
	_self.anchor_left = 1.0
	_self.anchor_right = 1.0
	_self.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_self.offset_right = -UiKit.px(18)
	_self.offset_top = UiKit.px(16)
	add_child(_self)
	UiKit.keep_off_edges(_self)
	_show()


## A new call, with these people on it.
func open(people: PackedStringArray) -> void:
	names = people
	seconds = 0.0
	_show()


func tick(delta: float) -> void:
	var before := int(seconds)
	seconds += delta
	if int(seconds) != before:
		_show()


func _show() -> void:
	if _who == null:
		return
	_who.text = ", ".join(names) if not names.is_empty() else "Home"
	_time.text = "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]


## What the bar says, for tests.
func bar_text() -> String:
	return "%s %s" % [_who.text, _time.text] if _who != null else ""
