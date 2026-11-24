class_name HospitalMap
extends Control
## The phone's map of the hospital: each place a rounded block on a plan
## (PhonePanel.PLACES, on a 100 x 100 grid), named, with the one the doctor
## is in lit up and a dot for "you are here". Drawn, not a picture, so it
## stays sharp at any size and costs nothing.

var places: Array = []
## The PLACES id the doctor is in, or "".
var here := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	draw_rect(area, Color("#0E2D33"))
	var font := UiKit.heavy_font()
	var font_size := maxi(8, int(UiKit.px(8)))
	for place: Array in places:
		var box := Rect2(size.x * float(place[3]) / 100.0, size.y * float(place[4]) / 100.0,
			size.x * float(place[5]) / 100.0, size.y * float(place[6]) / 100.0)
		var lit := str(place[0]) == here
		var fill := Color(UiKit.MINT, 0.32) if lit else Color(1, 1, 1, 0.07)
		_round_box(box, fill, Color(UiKit.MINT, 0.9) if lit else Color(1, 1, 1, 0.18))
		_draw_name(font, font_size, str(place[1]), box, Color.WHITE if lit else Color(1, 1, 1, 0.75))
		if lit:
			draw_circle(box.position + Vector2(UiKit.px(8), UiKit.px(8)), UiKit.px(3.5), UiKit.CORAL)


## A place's name, centred in its block: on one line if it fits (shrinking
## a little if it must), otherwise a word a line, so names never run into
## the next block.
func _draw_name(font: Font, base_size: int, text: String, box: Rect2, colour: Color) -> void:
	var room := box.size.x - UiKit.px(6)
	var lines := PackedStringArray([text])
	var font_size := base_size
	while font_size > int(base_size * 0.8) and _widest(font, lines, font_size) > room:
		font_size -= 1
	if _widest(font, lines, font_size) > room:
		lines = text.split(" ", false)
		font_size = base_size
		while font_size > int(base_size * 0.7) and _widest(font, lines, font_size) > room:
			font_size -= 1
	var line_height := font.get_height(font_size)
	var top := box.get_center().y - line_height * lines.size() / 2.0 + font.get_ascent(font_size)
	for index in lines.size():
		var width := font.get_string_size(lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(box.get_center().x - width / 2.0, top + line_height * index), lines[index],
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)


func _widest(font: Font, lines: PackedStringArray, font_size: int) -> float:
	var widest := 0.0
	for line in lines:
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	return widest


func _round_box(box: Rect2, fill: Color, edge: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(maxi(1, int(UiKit.px(1))))
	style.set_corner_radius_all(int(UiKit.px(5)))
	draw_style_box(style, box)
