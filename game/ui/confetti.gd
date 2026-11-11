class_name Confetti
extends Control
## A burst of paper confetti falling over the screen, for a promotion. Drawn
## in code and moved only by tick(), so it can be posed for screenshots.

const COLOURS := [Color("#F5B841"), Color("#8FE3D2"), Color("#F07C5A"), Color("#F4FBFA"), Color("#7CC8FF")]
const PIECES := 90
const LENGTH := 5.0

var time := 0.0
var _pieces: Array[Dictionary] = []


func _init(seed_value: int = 7) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for index in PIECES:
		_pieces.append({
			"x": rng.randf(), "delay": rng.randf_range(0.0, 0.9), "speed": rng.randf_range(0.22, 0.42),
			"sway": rng.randf_range(10.0, 34.0), "wobble": rng.randf_range(1.5, 3.5), "phase": rng.randf() * TAU,
			"spin": rng.randf_range(-6.0, 6.0), "colour": COLOURS[index % COLOURS.size()],
			"size": Vector2(rng.randf_range(7.0, 12.0), rng.randf_range(4.0, 7.0)),
		})


func _ready() -> void:
	name = "Confetti"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(self)


func finished() -> bool:
	return time >= LENGTH


func tick(delta: float) -> void:
	time += delta
	visible = not finished()
	queue_redraw()


func _draw() -> void:
	var fade := clampf((LENGTH - time) / 1.0, 0.0, 1.0)
	for piece in _pieces:
		var t := time - float(piece["delay"])
		if t <= 0.0:
			continue
		var y := -UiKit.px(10) + t * float(piece["speed"]) * size.y
		if y > size.y + UiKit.px(10):
			continue
		var x := float(piece["x"]) * size.x + sin(t * float(piece["wobble"]) + float(piece["phase"])) * UiKit.px(piece["sway"])
		var piece_size: Vector2 = piece["size"]
		# Paper flips as it falls: the piece narrows and widens.
		var flip := absf(cos(t * float(piece["spin"])))
		var drawn := Vector2(UiKit.px(piece_size.x) * maxf(flip, 0.15), UiKit.px(piece_size.y))
		draw_set_transform(Vector2(x, y), t * float(piece["spin"]) * 0.4)
		draw_rect(Rect2(-drawn / 2.0, drawn), Color(piece["colour"], fade))
	draw_set_transform(Vector2.ZERO)
