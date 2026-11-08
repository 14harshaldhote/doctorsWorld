class_name PolyBackdrop
extends Control
## A flat low-poly picture drawn from polygons, used behind 2D screens.
## Shapes are written in design pixels (844 x 390) and stretched to fill.

const DESIGN := Vector2(844, 390)

## Each shape is [colour, PackedVector2Array] for a polygon, or
## [colour, Vector2 centre, radius] for a circle.
var shapes: Array = []
var base := Color("#2A1F3D")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), base)
	var stretch := size / DESIGN
	for shape: Array in shapes:
		var colour: Color = shape[0]
		if shape[1] is PackedVector2Array:
			var points := PackedVector2Array()
			for point: Vector2 in shape[1]:
				points.append(point * stretch)
			draw_colored_polygon(points, colour)
		else:
			var centre: Vector2 = shape[1]
			draw_circle(centre * stretch, float(shape[2]) * minf(stretch.x, stretch.y), colour)


static func _poly(colour: String, values: Array) -> Array:
	var points := PackedVector2Array()
	for index in range(0, values.size(), 2):
		points.append(Vector2(values[index], values[index + 1]))
	return [Color(colour), points]


## The graduation hall behind the name screen: curtains, a stage and the
## backs of the audience's heads.
static func graduation_hall() -> PolyBackdrop:
	var made := PolyBackdrop.new()
	made.base = Color("#2A1F3D")
	made.shapes = [
		_poly("#5A2742", [0, 0, 120, 0, 90, 300, 0, 320]),
		_poly("#6E3152", [120, 0, 160, 0, 140, 290, 90, 300]),
		_poly("#5A2742", [844, 0, 724, 0, 754, 300, 844, 320]),
		_poly("#6E3152", [724, 0, 684, 0, 704, 290, 754, 300]),
		_poly("#6E3152", [160, 0, 684, 0, 684, 40, 160, 40]),
		_poly("#2F2545", [200, 40, 644, 40, 704, 290, 140, 290]),
		_poly("#3B3157", [330, 40, 514, 40, 600, 290, 244, 290]),
		_poly("#3A2B22", [0, 290, 844, 290, 844, 390, 0, 390]),
		_poly("#4C3A2C", [90, 290, 754, 290, 800, 320, 44, 320]),
		_poly("#6A4A33", [190, 200, 260, 200, 260, 290, 190, 290]),
		_poly("#7E5B40", [190, 200, 260, 200, 268, 190, 182, 190]),
		[Color("#C9A15A"), Vector2(225, 230), 12.0],
	]
	for x in [60, 110, 160, 684, 734, 784]:
		made.shapes.append([Color("#1E1A2A"), Vector2(x, 352 + (4 if x % 100 == 10 or x % 100 == 34 else 0)), 16.0])
	return made
