class_name UiIcon
extends Control
## Simple line icons drawn in code, so the game needs no icon files.

var kind := "circle"
var colour := UiKit.TEXT
## Line width in design pixels.
var stroke := 2.0


static func make(icon_kind: String, size: float = 22, icon_colour: Color = UiKit.TEXT) -> UiIcon:
	var made := UiIcon.new()
	made.kind = icon_kind
	made.colour = icon_colour
	made.custom_minimum_size = Vector2(UiKit.px(size), UiKit.px(size))
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return made


func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) / 2.0
	var width := UiKit.px(stroke) * s / UiKit.px(22)
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s / 24.0
	match kind:
		"phone":
			draw_rect(Rect2(p.call(7, 2), p.call(17, 22) - p.call(7, 2)), colour, false, width)
			draw_line(p.call(11, 18), p.call(13, 18), colour, width)
		"book":
			draw_polyline(PackedVector2Array([p.call(4, 4), p.call(10, 4), p.call(12, 6), p.call(12, 20), p.call(10, 18),
				p.call(4, 18), p.call(4, 4)]), colour, width)
			draw_polyline(PackedVector2Array([p.call(20, 4), p.call(14, 4), p.call(12, 6), p.call(12, 20), p.call(14, 18),
				p.call(20, 18), p.call(20, 4)]), colour, width)
		"team":
			draw_arc(p.call(9, 8), s * 3.2 / 24.0, 0, TAU, 16, colour, width)
			draw_arc(p.call(9, 21), s * 6.0 / 24.0, PI, TAU, 16, colour, width)
			draw_arc(p.call(17, 9), s * 2.6 / 24.0, 0, TAU, 16, colour, width)
			draw_arc(p.call(18, 20), s * 4.6 / 24.0, PI * 1.15, TAU, 12, colour, width)
		"menu":
			for y in [6, 12, 18]:
				draw_line(p.call(4, y), p.call(20, y), colour, width)
		"gear":
			draw_arc(p.call(12, 12), s * 3.0 / 24.0, 0, TAU, 16, colour, width)
			for step in 8:
				var angle := TAU * step / 8.0
				var dir := Vector2(cos(angle), sin(angle))
				draw_line(p.call(12, 12) + dir * s * 6.0 / 24.0, p.call(12, 12) + dir * s * 9.0 / 24.0, colour, width * 1.4)
			draw_arc(p.call(12, 12), s * 6.5 / 24.0, 0, TAU, 20, colour, width)
		"sound":
			draw_colored_polygon(PackedVector2Array([p.call(3, 9), p.call(7, 9), p.call(12, 5), p.call(12, 19),
				p.call(7, 15), p.call(3, 15)]), colour)
			draw_arc(p.call(13, 12), s * 4.0 / 24.0, -0.9, 0.9, 8, colour, width)
			draw_arc(p.call(13, 12), s * 8.0 / 24.0, -0.9, 0.9, 10, colour, width)
		"turn":
			draw_arc(p.call(12, 12), s * 8.0 / 24.0, PI * 0.15, PI * 1.85, 24, colour, width)
			draw_colored_polygon(PackedVector2Array([p.call(18, 3), p.call(21, 9), p.call(15, 9)]), colour)
		"dice":
			draw_rect(Rect2(p.call(4, 4), p.call(20, 20) - p.call(4, 4)), colour, false, width)
			for spot in [Vector2(8.5, 8.5), Vector2(15.5, 15.5), Vector2(12, 12), Vector2(15.5, 8.5), Vector2(8.5, 15.5)]:
				draw_circle(p.call(spot.x, spot.y), s * 1.3 / 24.0, colour)
		"lock":
			draw_rect(Rect2(p.call(5, 11), p.call(19, 21) - p.call(5, 11)), colour, false, width)
			draw_arc(p.call(12, 11), s * 4.5 / 24.0, PI, TAU, 12, colour, width)
		"check":
			draw_circle(p.call(12, 12), s * 9.0 / 24.0, colour)
			draw_polyline(PackedVector2Array([p.call(7.5, 12), p.call(10.5, 15), p.call(16.5, 9)]), UiKit.INK, width * 1.2)
		"cross":
			draw_circle(p.call(12, 12), s * 9.0 / 24.0, colour)
			draw_line(p.call(8.5, 8.5), p.call(15.5, 15.5), UiKit.INK, width * 1.2)
			draw_line(p.call(15.5, 8.5), p.call(8.5, 15.5), UiKit.INK, width * 1.2)
		"star", "star_off":
			var points := PackedVector2Array()
			for index in 10:
				var angle := -PI / 2.0 + TAU * index / 10.0
				var reach := 10.5 if index % 2 == 0 else 4.4
				points.append(p.call(12 + cos(angle) * reach, 12.6 + sin(angle) * reach))
			if kind == "star":
				draw_colored_polygon(points, colour)
			else:
				points.append(points[0])
				draw_polyline(points, colour, width)
		"circle":
			draw_arc(p.call(12, 12), s * 8.5 / 24.0, 0, TAU, 24, colour, width)
		"dot":
			draw_arc(p.call(12, 12), s * 8.5 / 24.0, 0, TAU, 24, colour, width)
			draw_circle(p.call(12, 12), s * 4.0 / 24.0, colour)
		"clock":
			draw_arc(p.call(12, 12), s * 9.0 / 24.0, 0, TAU, 24, colour, width)
			draw_polyline(PackedVector2Array([p.call(12, 6.5), p.call(12, 12), p.call(16, 14)]), colour, width)
		"pager":
			draw_rect(Rect2(p.call(3, 6), p.call(21, 18) - p.call(3, 6)), colour, false, width)
			draw_rect(Rect2(p.call(6, 9), p.call(14, 13) - p.call(6, 9)), colour, true)
		"walk":
			draw_circle(p.call(13, 4.5), s * 2.0 / 24.0, colour)
			draw_polyline(PackedVector2Array([p.call(9, 21), p.call(11, 15), p.call(13, 9), p.call(15, 15), p.call(17, 21)]),
				colour, width)
			draw_polyline(PackedVector2Array([p.call(7, 12), p.call(13, 9), p.call(18, 12)]), colour, width)
		"badge":
			draw_rect(Rect2(p.call(5, 3), p.call(19, 21) - p.call(5, 3)), colour, false, width)
			draw_line(p.call(9, 15), p.call(15, 15), colour, width)
			draw_circle(p.call(12, 9.5), s * 2.4 / 24.0, colour)
		_:
			draw_arc(p.call(12, 12), s * 8.5 / 24.0, 0, TAU, 24, colour, width)
