class_name PhotoCard
extends Control
## A small picture drawn in code, for the phone: Dad's good-morning
## forward, Mum's tiffin, Pooja's drawing, the blue tin, Varun's sunset.
## No image files and no camera: each kind is a few flat shapes, the same
## every time for the same seed, so the camera roll costs almost nothing.

const KINDS := ["gate", "hospital", "goodmorning", "tiffin", "kheer", "drawing", "tin", "sunset", "certificate",
	"scanner", "stage", "podcast", "retreat", "xray", "theatre", "hoarding", "gym", "food", "news", "cake", "group",
	"splint", "heart", "rain", "robot", "ward", "shoes"]

const SKY := Color("#9FD8E8")
const SKIN := [Color("#C68B59"), Color("#8D5524"), Color("#E0AC69"), Color("#A86B3C"), Color("#F1C27D")]
const SCRUBS := [Color("#127C80"), Color("#3B6FB6"), Color("#7A4FA0"), Color("#2E8B57"), Color("#B5476B")]

var kind := "hospital"
var seed_value := 0


static func make(photo_kind: String, picture_size: Vector2, picture_seed: int = 0) -> PhotoCard:
	var card := PhotoCard.new()
	card.kind = photo_kind if photo_kind in KINDS else "hospital"
	card.seed_value = picture_seed
	card.custom_minimum_size = picture_size
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.clip_contents = true
	return card


func _p(x: float, y: float) -> Vector2:
	return Vector2(x * size.x, y * size.y)


func _r(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(_p(x, y), Vector2(w * size.x, h * size.y))


## Sky or wall from one colour at the top to another at the bottom.
func _bands(top: Color, bottom: Color, from: float = 0.0, to: float = 1.0, steps: int = 8) -> void:
	for step in steps:
		var y := from + (to - from) * step / float(steps)
		draw_rect(_r(0, y, 1, (to - from) / steps + 0.002), top.lerp(bottom, step / float(steps - 1)))


func _ellipse(centre: Vector2, rx: float, ry: float, colour: Color, points: int = 24) -> void:
	var shape := PackedVector2Array()
	for index in points:
		var angle := TAU * index / points
		shape.append(_p(centre.x + cos(angle) * rx, centre.y + sin(angle) * ry))
	draw_colored_polygon(shape, colour)


func _poly(points: Array, colour: Color) -> void:
	var shape := PackedVector2Array()
	for point: Vector2 in points:
		shape.append(_p(point.x, point.y))
	draw_colored_polygon(shape, colour)


func _line(a: Vector2, b: Vector2, colour: Color, width: float = 0.012) -> void:
	draw_line(_p(a.x, a.y), _p(b.x, b.y), colour, maxf(1.0, width * size.y), true)


func _dot(x: float, y: float, r: float, colour: Color) -> void:
	draw_circle(_p(x, y), r * size.y, colour)


func _text(text: String, x: float, y: float, height: float, colour: Color, centred: bool = true) -> void:
	var font := UiKit.heading_font()
	var font_size := maxi(6, int(height * size.y))
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := _p(x, y) - Vector2(width / 2.0 if centred else 0.0, 0)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)


## A head and shoulders: a person in a photo.
func _person(x: float, y: float, scale: float, body: Color, skin: Color, cap: Color = Color.TRANSPARENT) -> void:
	_ellipse(Vector2(x, y + 0.2 * scale), 0.11 * scale, 0.13 * scale, body)
	draw_rect(_r(x - 0.11 * scale, y + 0.2 * scale, 0.22 * scale, 0.3 * scale), body)
	_ellipse(Vector2(x, y), 0.06 * scale, 0.085 * scale, skin)
	if cap.a > 0.0:
		_ellipse(Vector2(x, y - 0.05 * scale), 0.065 * scale, 0.045 * scale, cap)
	_line(Vector2(x - 0.025 * scale, y + 0.025 * scale), Vector2(x + 0.025 * scale, y + 0.025 * scale), Color(0.2, 0.1, 0.05, 0.7), 0.008 * scale)


func _pick(colours: Array, salt: int) -> Color:
	return colours[absi(seed_value * 31 + salt * 17) % colours.size()]


func _draw() -> void:
	match kind:
		"gate", "hospital":
			_bands(SKY, Color("#E8F4F0"), 0, 0.7)
			draw_rect(_r(0, 0.7, 1, 0.3), Color("#8AA39B"))
			draw_rect(_r(0.18, 0.22, 0.64, 0.52), Color("#F4EFE6"))
			draw_rect(_r(0.18, 0.22, 0.64, 0.06), Color("#127C80"))
			for row in 3:
				for column in 6:
					draw_rect(_r(0.23 + column * 0.095, 0.33 + row * 0.12, 0.055, 0.07), Color("#7FB3C8"))
			draw_rect(_r(0.46, 0.6, 0.08, 0.14), Color("#5A4636"))
			draw_rect(_r(0.47, 0.235, 0.06, 0.03), Color.WHITE)
			_line(Vector2(0.5, 0.228), Vector2(0.5, 0.272), Color("#E03B3B"), 0.012)
			_line(Vector2(0.48, 0.25), Vector2(0.52, 0.25), Color("#E03B3B"), 0.012)
			if kind == "gate":
				_line(Vector2(0.04, 0.95), Vector2(0.04, 0.5), Color("#3C4A48"), 0.03)
				_line(Vector2(0.96, 0.95), Vector2(0.96, 0.5), Color("#3C4A48"), 0.03)
				draw_rect(_r(0.04, 0.46, 0.92, 0.08), Color("#3C4A48"))
				_text("RIVERSIDE CITY HOSPITAL", 0.5, 0.525, 0.06, Color("#F5B841"))
			else:
				_ellipse(Vector2(0.08, 0.66), 0.07, 0.1, Color("#4E8F5A"))
				_ellipse(Vector2(0.92, 0.66), 0.07, 0.1, Color("#4E8F5A"))
			_dot(0.86, 0.12, 0.06, Color("#FFE08A"))
		"goodmorning":
			_bands(Color("#FF9A6B"), Color("#FFE3A3"), 0, 1)
			_ellipse(Vector2(0.5, 0.62), 0.22, 0.28, Color("#FFD66B"))
			draw_rect(_r(0, 0.62, 1, 0.38), Color("#F7B6A3"))
			for index in 7:
				var x := 0.08 + index * 0.14
				_line(Vector2(x, 1.0), Vector2(x, 0.8), Color("#3E7F4A"), 0.015)
				for petal in 5:
					var angle := TAU * petal / 5.0
					_dot(x + cos(angle) * 0.03, 0.78 + sin(angle) * 0.04, 0.035, [Color("#E8508A"), Color("#FFFFFF"), Color("#F5B841")][index % 3])
				_dot(x, 0.78, 0.02, Color("#F5B841"))
			_text("Good Morning", 0.5, 0.3, 0.16, Color(0.4, 0.1, 0.1, 0.35))
			_text("Good Morning", 0.495, 0.29, 0.16, Color.WHITE)
		"tiffin", "food":
			_bands(Color("#B07A4F"), Color("#8A5A36"), 0, 1, 4)
			if kind == "tiffin":
				for level in 3:
					var y := 0.28 + level * 0.2
					draw_rect(_r(0.3, y, 0.4, 0.17), Color("#C9CFD2").lerp(Color("#9AA3A8"), level * 0.3))
					draw_rect(_r(0.3, y, 0.4, 0.025), Color("#EEF2F4"))
				_line(Vector2(0.3, 0.27), Vector2(0.3, 0.12), Color("#7D868B"), 0.025)
				_line(Vector2(0.7, 0.27), Vector2(0.7, 0.12), Color("#7D868B"), 0.025)
				_line(Vector2(0.3, 0.12), Vector2(0.7, 0.12), Color("#7D868B"), 0.025)
			else:
				_ellipse(Vector2(0.5, 0.52), 0.4, 0.44, Color("#D9DEE0"))
				_ellipse(Vector2(0.5, 0.52), 0.34, 0.38, Color("#EEF2F4"))
				_ellipse(Vector2(0.38, 0.4), 0.09, 0.11, Color("#F2B33D"))
				_ellipse(Vector2(0.62, 0.4), 0.09, 0.11, Color("#7A9A3A"))
				_ellipse(Vector2(0.5, 0.66), 0.17, 0.12, Color("#E9D9B0"))
				_ellipse(Vector2(0.64, 0.66), 0.07, 0.08, Color("#C0392B"))
		"kheer":
			_bands(Color("#F6E7D0"), Color("#E9D0AE"), 0, 1, 4)
			_ellipse(Vector2(0.5, 0.55), 0.36, 0.3, Color("#C9A26B"))
			_ellipse(Vector2(0.5, 0.5), 0.33, 0.24, Color("#FFF6E3"))
			for index in 6:
				var angle := TAU * index / 6.0 + seed_value
				_ellipse(Vector2(0.5 + cos(angle) * 0.17, 0.5 + sin(angle) * 0.1), 0.035, 0.02, Color("#E3C08A"))
			_line(Vector2(0.62, 0.42), Vector2(0.92, 0.12), Color("#B8BEC2"), 0.03)
		"drawing", "heart":
			draw_rect(_r(0, 0, 1, 1), Color("#FFFDF4"))
			for row in 9:
				_line(Vector2(0, 0.1 + row * 0.1), Vector2(1, 0.1 + row * 0.1), Color("#C9DDF0"), 0.004)
			if kind == "drawing":
				var crayon := Color("#E05A47")
				_line(Vector2(0.08, 0.3), Vector2(0.48, 0.3), crayon, 0.02)
				_line(Vector2(0.08, 0.3), Vector2(0.08, 0.88), crayon, 0.02)
				_line(Vector2(0.48, 0.3), Vector2(0.48, 0.88), crayon, 0.02)
				_line(Vector2(0.08, 0.88), Vector2(0.48, 0.88), crayon, 0.02)
				_line(Vector2(0.28, 0.4), Vector2(0.28, 0.56), crayon, 0.03)
				_line(Vector2(0.2, 0.48), Vector2(0.36, 0.48), crayon, 0.03)
				var blue := Color("#3B6FB6")
				for figure: Array in [[0.64, blue, true], [0.84, Color("#2E8B57"), false]]:
					var x: float = figure[0]
					var colour: Color = figure[1]
					draw_arc(_p(x, 0.42), 0.06 * size.y, 0, TAU, 16, colour, 0.018 * size.y)
					if figure[2]:
						draw_arc(_p(x, 0.4), 0.075 * size.y, PI, TAU, 12, Color("#F5B841"), 0.03 * size.y)
					_line(Vector2(x, 0.48), Vector2(x, 0.72), colour, 0.018)
					_line(Vector2(x - 0.07, 0.56), Vector2(x + 0.07, 0.56), colour, 0.018)
					_line(Vector2(x, 0.72), Vector2(x - 0.05, 0.88), colour, 0.018)
					_line(Vector2(x, 0.72), Vector2(x + 0.05, 0.88), colour, 0.018)
				draw_arc(_p(0.84, 0.6), 0.04 * size.y, 0, PI, 10, Color("#555555"), 0.01 * size.y)
				_dot(0.9, 0.12, 0.06, Color("#F5B841"))
				for ray in 8:
					var angle := TAU * ray / 8.0
					_line(Vector2(0.9 + cos(angle) * 0.07, 0.12 + sin(angle) * 0.1), Vector2(0.9 + cos(angle) * 0.1, 0.12 + sin(angle) * 0.14), Color("#F5B841"), 0.01)
			else:
				_ellipse(Vector2(0.42, 0.52), 0.2, 0.3, Color("#D9443C"))
				_ellipse(Vector2(0.52, 0.42), 0.12, 0.18, Color("#E86A55"))
				_line(Vector2(0.45, 0.24), Vector2(0.4, 0.1), Color("#3B6FB6"), 0.04)
				_line(Vector2(0.55, 0.28), Vector2(0.6, 0.12), Color("#D9443C"), 0.04)
				for label in 3:
					var y := 0.3 + label * 0.2
					_line(Vector2(0.6, y), Vector2(0.78, y), Color("#555555"), 0.006)
					_line(Vector2(0.8, y), Vector2(0.95, y), Color("#9AA3A8"), 0.02)
		"tin":
			_bands(Color("#E8DCC8"), Color("#D2C2A8"), 0, 1, 4)
			_ellipse(Vector2(0.5, 0.56), 0.38, 0.4, Color("#11336B"))
			_ellipse(Vector2(0.5, 0.53), 0.36, 0.37, Color("#1E4C93"))
			draw_arc(_p(0.5, 0.53), 0.3 * size.y, 0, TAU, 40, Color("#E6C35A"), 0.015 * size.y)
			draw_arc(_p(0.5, 0.53), 0.22 * size.y, 0, TAU, 40, Color("#E6C35A"), 0.008 * size.y)
			for index in 12:
				var angle := TAU * index / 12.0
				_dot(0.5 + cos(angle) * 0.17, 0.53 + sin(angle) * 0.2, 0.012, Color("#F4FBFA"))
			_text("BUTTER", 0.5, 0.57, 0.08, Color("#F4FBFA"))
		"sunset", "retreat":
			_bands(Color("#FF7E5F"), Color("#FEB47B"), 0, 0.62)
			_ellipse(Vector2(0.5, 0.6), 0.16, 0.2, Color("#FFE29A"))
			draw_rect(_r(0, 0.62, 1, 0.38), Color("#2F6F8F") if kind == "retreat" else Color("#3A4E6B"))
			for wave in 4:
				_line(Vector2(0.1 + wave * 0.22, 0.72 + wave % 2 * 0.1), Vector2(0.22 + wave * 0.22, 0.72 + wave % 2 * 0.1), Color(1, 1, 1, 0.35), 0.008)
			if kind == "retreat":
				_line(Vector2(0.82, 0.62), Vector2(0.78, 0.18), Color("#5B3B22"), 0.03)
				for leaf in 5:
					var angle := PI + PI * leaf / 4.0
					_line(Vector2(0.78, 0.18), Vector2(0.78 + cos(angle) * 0.16, 0.18 + sin(angle) * -0.12 + 0.08), Color("#2E7D4A"), 0.03)
				_text("soft reset", 0.3, 0.3, 0.1, Color.WHITE)
			else:
				_person(0.28, 0.5, 1.2, Color(0.12, 0.12, 0.18), Color(0.12, 0.12, 0.18), Color(0.12, 0.12, 0.18))
		"certificate":
			draw_rect(_r(0, 0, 1, 1), Color("#F7F0DC"))
			draw_rect(_r(0.05, 0.07, 0.9, 0.86), Color("#B9821F"), false, 0.02 * size.y)
			_text("CERTIFICATE", 0.5, 0.26, 0.11, Color("#7A5A1A"))
			for line in 3:
				_line(Vector2(0.22, 0.42 + line * 0.11), Vector2(0.78, 0.42 + line * 0.11), Color("#C9B88F"), 0.012)
			_dot(0.8, 0.76, 0.09, Color("#C0392B"))
			_dot(0.8, 0.76, 0.06, Color("#E05A47"))
			var signature := PackedVector2Array()
			for step in 9:
				signature.append(_p(0.18 + step * 0.04, 0.8 + sin(step * 1.7) * 0.05))
			draw_polyline(signature, Color("#2A2A6A"), 0.01 * size.y, true)
		"scanner":
			draw_rect(_r(0, 0, 1, 1), Color("#1B2A33"))
			_ellipse(Vector2(0.45, 0.48), 0.3, 0.38, Color("#DDE5E8"))
			_ellipse(Vector2(0.45, 0.48), 0.15, 0.2, Color("#0E1A20"))
			draw_rect(_r(0.45, 0.5, 0.5, 0.08), Color("#AEB8BC"))
			_text("z", 0.78, 0.3, 0.1, Color("#8FE3D2"))
			_text("z", 0.85, 0.2, 0.13, Color("#8FE3D2"))
		"stage":
			draw_rect(_r(0, 0, 1, 1), Color("#1A1A2E"))
			_poly([Vector2(0.45, 0), Vector2(0.55, 0), Vector2(0.8, 1), Vector2(0.2, 1)], Color(1, 0.95, 0.7, 0.15))
			draw_rect(_r(0.1, 0.06, 0.8, 0.14), Color("#127C80"))
			_text("LEADERSHIP IN SURGERY", 0.5, 0.165, 0.07, Color.WHITE)
			_person(0.5, 0.42, 0.9, Color("#2B2B3A"), _pick(SKIN, 1))
			draw_rect(_r(0.36, 0.64, 0.28, 0.36), Color("#5A3E2B"))
			_line(Vector2(0.5, 0.64), Vector2(0.56, 0.52), Color("#999999"), 0.01)
		"podcast":
			draw_rect(_r(0, 0, 1, 1), Color("#2B2D42"))
			draw_rect(_r(0.62, 0.08, 0.3, 0.14), Color("#E03B3B"))
			_text("ON AIR", 0.77, 0.185, 0.08, Color.WHITE)
			_ellipse(Vector2(0.4, 0.4), 0.1, 0.16, Color("#8D99AE"))
			_line(Vector2(0.4, 0.56), Vector2(0.4, 0.8), Color("#8D99AE"), 0.025)
			draw_rect(_r(0.25, 0.8, 0.3, 0.05), Color("#8D99AE"))
			draw_arc(_p(0.4, 0.4), 0.2 * size.y, PI * 0.1, PI * 0.9, 12, Color("#EDF2F4"), 0.012 * size.y)
			_text("SCRUBBED IN, NO CAP", 0.5, 0.95, 0.06, Color("#F5B841"))
		"xray":
			draw_rect(_r(0, 0, 1, 1), Color("#05090C"))
			_poly([Vector2(0.15, 0.85), Vector2(0.2, 0.9), Vector2(0.62, 0.32), Vector2(0.56, 0.28)], Color("#C9DCEB"))
			_poly([Vector2(0.28, 0.92), Vector2(0.33, 0.95), Vector2(0.72, 0.4), Vector2(0.66, 0.36)], Color("#B3CADB"))
			_line(Vector2(0.48, 0.42), Vector2(0.53, 0.48), Color("#05090C"), 0.012)
			_ellipse(Vector2(0.68, 0.24), 0.12, 0.12, Color("#AFC6D8"))
			_text("R", 0.1, 0.15, 0.1, Color("#C9DCEB"))
		"theatre":
			_bands(Color("#2E8B78"), Color("#1D5E52"), 0, 1, 4)
			_ellipse(Vector2(0.5, 0.25), 0.3, 0.2, Color("#DDE8E6"))
			for light in 5:
				var angle := TAU * light / 5.0
				_ellipse(Vector2(0.5 + cos(angle) * 0.15, 0.25 + sin(angle) * 0.1), 0.06, 0.05, Color("#FFF7D6"))
			draw_rect(_r(0.15, 0.62, 0.7, 0.38), Color("#3FA48E"))
			draw_rect(_r(0.72, 0.36, 0.22, 0.2), Color("#10202A"))
			var trace := PackedVector2Array()
			for step in 10:
				trace.append(_p(0.74 + step * 0.02, 0.46 + (0.06 if step == 5 else (-0.04 if step == 6 else 0.0))))
			draw_polyline(trace, Color("#8FE3D2"), 0.008 * size.y, true)
		"hoarding":
			_bands(SKY, Color("#DDEFF2"), 0, 0.75)
			draw_rect(_r(0, 0.75, 1, 0.25), Color("#4A4A4A"))
			for dash in 5:
				draw_rect(_r(0.05 + dash * 0.2, 0.86, 0.1, 0.02), Color("#F4FBFA"))
			_line(Vector2(0.3, 0.75), Vector2(0.3, 0.55), Color("#555555"), 0.03)
			_line(Vector2(0.7, 0.75), Vector2(0.7, 0.55), Color("#555555"), 0.03)
			draw_rect(_r(0.1, 0.08, 0.8, 0.48), Color("#FFFFFF"))
			draw_rect(_r(0.1, 0.08, 0.8, 0.1), Color("#F07C5A"))
			_text("CAREPLUS", 0.5, 0.16, 0.08, Color.WHITE)
			_ellipse(Vector2(0.35, 0.36), 0.1, 0.15, _pick(SKIN, 2))
			draw_arc(_p(0.35, 0.38), 0.05 * size.y, 0.2, PI - 0.2, 10, Color("#5A2A1A"), 0.012 * size.y)
			_text("Dr. V. Khanna", 0.66, 0.34, 0.07, Color("#12333A"))
			_text("Excellence. Daily.", 0.66, 0.46, 0.05, Color("#F07C5A"))
		"gym":
			draw_rect(_r(0, 0, 1, 1), Color("#30343F"))
			draw_rect(_r(0.55, 0.08, 0.38, 0.84), Color("#8DA9B5"))
			_person(0.74, 0.35, 1.0, Color("#E03B3B"), _pick(SKIN, 3))
			_line(Vector2(0.1, 0.78), Vector2(0.42, 0.78), Color("#BBBBBB"), 0.025)
			draw_rect(_r(0.06, 0.7, 0.06, 0.16), Color("#222222"))
			draw_rect(_r(0.4, 0.7, 0.06, 0.16), Color("#222222"))
		"news":
			draw_rect(_r(0, 0, 1, 1), Color("#EDEBE4"))
			_text("CITY TIMES", 0.5, 0.15, 0.12, Color("#1A1A1A"))
			_line(Vector2(0.05, 0.2), Vector2(0.95, 0.2), Color("#1A1A1A"), 0.008)
			draw_rect(_r(0.07, 0.26, 0.86, 0.07), Color("#3A3A3A"))
			draw_rect(_r(0.07, 0.38, 0.4, 0.52), Color("#9AA3A8"))
			_person(0.27, 0.55, 0.8, Color("#5A6870"), Color("#C2C8CC"))
			for line in 7:
				_line(Vector2(0.53, 0.42 + line * 0.07), Vector2(0.93, 0.42 + line * 0.07), Color("#8A8A8A"), 0.012)
		"cake":
			_bands(Color("#FCE4EC"), Color("#F8BBD0"), 0, 1, 4)
			draw_rect(_r(0.2, 0.55, 0.6, 0.3), Color("#8B5A3C"))
			draw_rect(_r(0.2, 0.55, 0.6, 0.06), Color("#FFFFFF"))
			draw_rect(_r(0.32, 0.32, 0.36, 0.23), Color("#A0694A"))
			draw_rect(_r(0.32, 0.32, 0.36, 0.05), Color("#FFFFFF"))
			for candle in 3:
				var x := 0.4 + candle * 0.1
				_line(Vector2(x, 0.32), Vector2(x, 0.2), Color("#8FE3D2"), 0.02)
				_ellipse(Vector2(x, 0.16), 0.015, 0.03, Color("#F5B841"))
			draw_rect(_r(0.12, 0.85, 0.76, 0.04), Color("#DDDDDD"))
		"group":
			_bands(Color("#C9E4EA"), Color("#E9F1EF"), 0, 0.6)
			draw_rect(_r(0, 0.6, 1, 0.4), Color("#9AA8A6"))
			draw_rect(_r(0.05, 0.12, 0.42, 0.3), Color("#F4F4F4"))
			draw_rect(_r(0.05, 0.12, 0.42, 0.05), Color("#E03B3B"))
			_text("AMBULANCE", 0.26, 0.32, 0.06, Color("#E03B3B"))
			for index in 5:
				_person(0.14 + index * 0.18, 0.5, 0.85, _pick(SCRUBS, index), _pick(SKIN, index + 4))
		"splint":
			_bands(Color("#D7E3E8"), Color("#B9CBD3"), 0, 1, 4)
			_poly([Vector2(0.0, 0.7), Vector2(0.55, 0.45), Vector2(0.62, 0.6), Vector2(0.05, 0.92)], _pick(SKIN, 5))
			_poly([Vector2(0.15, 0.68), Vector2(0.52, 0.5), Vector2(0.58, 0.62), Vector2(0.2, 0.82)], Color("#3B6FB6"))
			_ellipse(Vector2(0.66, 0.48), 0.1, 0.12, _pick(SKIN, 5))
			_line(Vector2(0.68, 0.38), Vector2(0.7, 0.18), _pick(SKIN, 5), 0.06)
			_text("#blessed", 0.75, 0.9, 0.08, Color("#12333A"))
		"rain":
			_bands(Color("#6E7F8A"), Color("#A9B7BF"), 0, 1, 5)
			for drop in 18:
				var x := fmod(drop * 0.137 + seed_value * 0.01, 1.0)
				var y := fmod(drop * 0.29, 0.6)
				_line(Vector2(x, y), Vector2(x - 0.03, y + 0.12), Color(1, 1, 1, 0.5), 0.006)
			draw_rect(_r(0, 0.72, 1, 0.04), Color("#3C4A48"))
			for bar in 9:
				_line(Vector2(0.06 + bar * 0.11, 0.76), Vector2(0.06 + bar * 0.11, 1.0), Color("#3C4A48"), 0.012)
			draw_rect(_r(0.7, 0.58, 0.14, 0.14), Color("#B5643C"))
			_ellipse(Vector2(0.77, 0.52), 0.1, 0.1, Color("#4E8F5A"))
		"robot":
			draw_rect(_r(0, 0, 1, 1), Color("#E9F1EF"))
			draw_rect(_r(0.3, 0.75, 0.4, 0.15), Color("#9AA3A8"))
			_line(Vector2(0.5, 0.75), Vector2(0.38, 0.45), Color("#DDE5E8"), 0.07)
			_line(Vector2(0.38, 0.45), Vector2(0.66, 0.25), Color("#DDE5E8"), 0.06)
			_line(Vector2(0.66, 0.25), Vector2(0.72, 0.4), Color("#BFC8CC"), 0.03)
			_dot(0.38, 0.45, 0.05, Color("#127C80"))
			_dot(0.66, 0.25, 0.04, Color("#127C80"))
			_poly([Vector2(0.44, 0.7), Vector2(0.56, 0.62), Vector2(0.56, 0.78)], Color("#E03B3B"))
			_poly([Vector2(0.56, 0.7), Vector2(0.44, 0.62), Vector2(0.44, 0.78)], Color("#E03B3B"))
		"ward":
			_bands(Color("#E6EEF0"), Color("#D3DEE1"), 0, 1, 4)
			for bed in 3:
				var x := 0.06 + bed * 0.32
				draw_rect(_r(x, 0.55, 0.26, 0.2), Color("#FFFFFF"))
				draw_rect(_r(x, 0.5, 0.06, 0.12), Color("#AFC6D8"))
				_line(Vector2(x, 0.75), Vector2(x, 0.9), Color("#7D868B"), 0.015)
				_line(Vector2(x + 0.26, 0.75), Vector2(x + 0.26, 0.9), Color("#7D868B"), 0.015)
				draw_rect(_r(x + 0.27, 0.1, 0.03, 0.75), Color("#8FE3D2"))
		"shoes":
			draw_rect(_r(0, 0, 1, 1), Color("#B9AE9E"))
			for shoe in 2:
				var x := 0.32 + shoe * 0.36
				_ellipse(Vector2(x, 0.5), 0.13, 0.36, Color("#F4F4F4"))
				_ellipse(Vector2(x, 0.62), 0.1, 0.2, Color("#8A6E52"))
				for lace in 3:
					_line(Vector2(x - 0.05, 0.3 + lace * 0.07), Vector2(x + 0.05, 0.3 + lace * 0.07), Color("#555555"), 0.01)
			for spot in 7:
				_dot(fmod(spot * 0.31, 1.0), fmod(spot * 0.53, 1.0), 0.02 + spot % 3 * 0.01, Color("#6B4F35"))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.18), false, 1.0)
