class_name VitalsMonitor
extends Control
## A patient monitor drawn in code: a scrolling heart trace and the four
## numbers (heart rate, blood pressure, oxygen, breathing). Tapping a number
## emits picked. Used in training, examinations and every operation.
##
## Numbers out of range get an arrow (up for too high, down for too low) as
## well as a colour, and with the colour-blind-safe setting the monitor
## uses blue and orange instead of green and red. With beeping on it beeps
## with each heartbeat, lower as the oxygen falls, like a real one.
##
## Time passes only through tick(), so the trace can be posed for tests.

signal picked(kind: String)

const BACK := Color(4 / 255.0, 18 / 255.0, 21 / 255.0, 0.95)
const EDGE := Color(143 / 255.0, 227 / 255.0, 210 / 255.0, 0.3)
const ALARM := Color("#FF8A8A")
const TRACE := Color("#8FE3A6")
const RIGHT := Color("#8FE3A6")
const WRONG := Color("#FF8A8A")
const COLOURS := {"hr": Color("#8FE3A6"), "bp": Color("#F4FBFA"), "spo2": Color("#8FE3D2"), "rr": Color("#F8D27A")}
## The colour-blind-safe palette: blue for fine, orange for a problem.
const SAFE_ALARM := Color("#FFB04A")
const SAFE_TRACE := Color("#7CC8FF")
const SAFE_COLOURS := {"hr": Color("#7CC8FF"), "bp": Color("#F4FBFA"), "spo2": Color("#B9E2FF"), "rr": Color("#F4FBFA")}
## Seconds of trace across the screen.
const WINDOW := 3.0

var vitals := Vitals.new()
## When true, out-of-range numbers turn red (off while training people to spot them).
var show_alarms := true
## Per number: "right", "wrong", "answer" or "seen", drawn as a coloured outline.
var marks := {}
var status := ""
var status_colour := ALARM
## Beep with each heartbeat (in operations and examinations).
var beeping := false
## Beeps so far, for tests.
var beeps := 0
var _time := 0.0
var _since_beat := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func tick(delta: float) -> void:
	_time += delta
	_since_beat += delta
	var period := 60.0 / maxf(20.0, float(vitals.hr))
	if _since_beat >= period:
		_since_beat = fmod(_since_beat, period)
		if beeping and is_visible_in_tree():
			beeps += 1
			var player := Sfx.play(self, "beep", -20.0)
			if player != null:
				player.pitch_scale = 0.72 + 0.28 * clampf((vitals.spo2 - 80) / 18.0, 0.0, 1.0)
	queue_redraw()


static func safe_colours() -> bool:
	return GameSettings.current.colour_safe


## The colour the status words are drawn in: the alarm colour for an alarm,
## and blue instead of green on the colour-blind-safe monitor.
func shown_status_colour() -> Color:
	if status_colour == ALARM:
		return alarm_colour()
	if safe_colours() and status_colour in [RIGHT, UiKit.MINT]:
		return SAFE_TRACE
	return status_colour


func alarm_colour() -> Color:
	return SAFE_ALARM if safe_colours() else ALARM


func _number_colour(kind: String) -> Color:
	if _alarming(kind):
		return alarm_colour()
	return (SAFE_COLOURS if safe_colours() else COLOURS)[kind]


func set_vitals(new_vitals: Vitals) -> void:
	vitals = new_vitals
	queue_redraw()


## Where a number's cell is, in this control's own coordinates.
func cell_rect(kind: String) -> Rect2:
	var index := Vitals.KINDS.find(kind)
	if index < 0:
		return Rect2()
	var pad := UiKit.px(12)
	var top := _cells_top()
	var cell_w := (size.x - pad * 3) / 2.0
	var cell_h := (size.y - top - pad * 2) / 2.0
	var column := index % 2
	var row := int(index / 2.0)
	return Rect2(pad + column * (cell_w + pad), top + row * (cell_h + pad * 0.6), cell_w, cell_h - pad * 0.3)


func _cells_top() -> float:
	return UiKit.px(24) + _trace_height() + UiKit.px(10)


func _trace_height() -> float:
	return clampf(size.y * 0.24, UiKit.px(30), UiKit.px(70))


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
		return
	for kind: String in Vitals.KINDS:
		if cell_rect(kind).has_point(button.position):
			accept_event()
			picked.emit(kind)
			return


func _alarming(kind: String) -> bool:
	return show_alarms and not vitals.is_normal(kind)


func _draw() -> void:
	var style := UiKit.box(BACK, 14, alarm_colour() if show_alarms and not vitals.problems().is_empty() else EDGE, 2)
	draw_style_box(style, Rect2(Vector2.ZERO, size))
	var pad := UiKit.px(12)
	var label_font := UiKit.heavy_font()
	var value_font := UiKit.heading_font()
	draw_string(label_font, Vector2(pad, UiKit.px(19)), "MONITOR", HORIZONTAL_ALIGNMENT_LEFT, -1, int(UiKit.px(11)),
		UiKit.TEXT_KICKER)
	if not status.is_empty():
		draw_string(label_font, Vector2(pad, UiKit.px(19)), status, HORIZONTAL_ALIGNMENT_RIGHT, size.x - pad * 2,
			int(UiKit.px(11)), shown_status_colour())
	_draw_trace(Rect2(pad, UiKit.px(26), size.x - pad * 2, _trace_height()))
	for kind: String in Vitals.KINDS:
		var cell := cell_rect(kind)
		var mark := str(marks.get(kind, ""))
		var fill := Color(1, 1, 1, 0.05)
		var outline := Color.TRANSPARENT
		var right := SAFE_TRACE if safe_colours() else RIGHT
		var wrong := SAFE_ALARM if safe_colours() else WRONG
		match mark:
			"right":
				outline = right
				fill = Color(right, 0.14)
			"wrong":
				outline = wrong
				fill = Color(wrong, 0.14)
			"answer":
				outline = UiKit.AMBER
				fill = Color(UiKit.AMBER, 0.14)
			"seen":
				outline = Color(UiKit.MINT, 0.5)
		var cell_style := UiKit.box(fill, 10, outline, 2 if outline.a > 0.0 else 0)
		draw_style_box(cell_style, cell)
		var colour := _number_colour(kind)
		if mark in ["right", "wrong"]:
			_draw_mark(cell, mark == "right", outline)
		var label_size := int(UiKit.px(10))
		var value_size := int(clampf(cell.size.y * 0.5, UiKit.px(16), UiKit.px(34)))
		if cell.size.y < UiKit.px(34):
			# A small monitor: the number on the left, its name on the right.
			var middle := cell.position.y + cell.size.y / 2.0
			draw_string(value_font, Vector2(cell.position.x + UiKit.px(8), middle + value_size * 0.36), vitals.value_text(kind),
				HORIZONTAL_ALIGNMENT_LEFT, cell.size.x * 0.62, value_size, colour)
			_draw_arrow(kind, Vector2(cell.position.x + UiKit.px(8) + _text_width(value_font, kind, value_size) + UiKit.px(7),
				middle), value_size * 0.5, colour)
			draw_string(label_font, Vector2(cell.position.x, middle + label_size * 0.36), str(Vitals.LABELS[kind]),
				HORIZONTAL_ALIGNMENT_RIGHT, cell.size.x - UiKit.px(8), label_size, UiKit.TEXT_KICKER)
			continue
		draw_string(label_font, cell.position + Vector2(UiKit.px(8), UiKit.px(15)), str(Vitals.LABELS[kind]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, UiKit.TEXT_KICKER)
		draw_string(value_font, cell.position + Vector2(UiKit.px(8), cell.size.y - UiKit.px(8)), vitals.value_text(kind),
			HORIZONTAL_ALIGNMENT_LEFT, cell.size.x - UiKit.px(12), value_size, colour)
		_draw_arrow(kind, cell.position + Vector2(UiKit.px(8) + _text_width(value_font, kind, value_size) + UiKit.px(8),
			cell.size.y - UiKit.px(8) - value_size * 0.36), value_size * 0.55, colour)


func _draw_trace(area: Rect2) -> void:
	draw_rect(area, Color(0, 0, 0, 0.25))
	var points := PackedVector2Array()
	var samples := int(clampf(area.size.x / UiKit.px(2), 40, 220))
	var period := 60.0 / maxf(20.0, float(vitals.hr))
	for index in samples + 1:
		var x := float(index) / samples
		var t := _time - (1.0 - x) * WINDOW
		var phase := fposmod(t, period) / period
		points.append(area.position + Vector2(x * area.size.x, area.size.y * (0.62 - 0.5 * _beat(phase))))
	var colour := alarm_colour() if _alarming("hr") else (SAFE_TRACE if safe_colours() else TRACE)
	draw_polyline(points, colour, UiKit.px(1.5), true)


func _text_width(which: Font, kind: String, font_size: int) -> float:
	return which.get_string_size(vitals.value_text(kind), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## A filled arrow beside an out-of-range number: up for too high, down for
## too low, so the problem doesn't depend on seeing colour.
func _draw_arrow(kind: String, centre: Vector2, height: float, colour: Color) -> void:
	if not _alarming(kind):
		return
	var up := vitals.direction(kind) > 0
	var half := height * 0.55
	var tip := centre + Vector2(0, -height / 2.0 if up else height / 2.0)
	var base_y := centre.y + (height / 2.0 if up else -height / 2.0)
	draw_colored_polygon(PackedVector2Array([tip, Vector2(centre.x - half, base_y), Vector2(centre.x + half, base_y)]),
		colour)


## A tick or a cross in the corner of a marked number.
func _draw_mark(cell: Rect2, right: bool, colour: Color) -> void:
	var size_now := UiKit.px(6)
	var corner := cell.position + Vector2(cell.size.x - UiKit.px(12), UiKit.px(11))
	if right:
		draw_polyline(PackedVector2Array([corner + Vector2(-size_now, 0), corner + Vector2(-size_now * 0.3, size_now * 0.7),
			corner + Vector2(size_now, -size_now * 0.8)]), colour, UiKit.px(2), true)
	else:
		draw_line(corner + Vector2(-size_now, -size_now), corner + Vector2(size_now, size_now), colour, UiKit.px(2), true)
		draw_line(corner + Vector2(-size_now, size_now), corner + Vector2(size_now, -size_now), colour, UiKit.px(2), true)


## The shape of one heartbeat, phase 0 to 1: a small bump, the spike, a wave.
static func _beat(phase: float) -> float:
	if phase < 0.1:
		return 0.12 * sin(phase / 0.1 * PI)
	if phase < 0.16:
		return 0.0
	if phase < 0.19:
		return -0.18 * sin((phase - 0.16) / 0.03 * PI)
	if phase < 0.25:
		return sin((phase - 0.19) / 0.06 * PI)
	if phase < 0.29:
		return -0.28 * sin((phase - 0.25) / 0.04 * PI)
	if phase < 0.42:
		return 0.0
	if phase < 0.6:
		return 0.22 * sin((phase - 0.42) / 0.18 * PI)
	return 0.0
