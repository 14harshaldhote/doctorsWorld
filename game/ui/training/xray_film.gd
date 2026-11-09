class_name XrayFilm
extends Control
## A child's neck and chest X-ray drawn in code: the spine, ribs and collar
## bones, and something round stuck in the gullet. From the front a button
## battery and a coin look alike until you zoom in on the edge (a battery
## shows a second ring, its "halo"); from the side a battery has a step at
## its edge where a coin is a thin flat line.

signal object_tapped

const FILM := Color("#0B1214")
const BONE := Color("#C9D3D6")
const SOFT := Color("#2A3A3E")
const METAL := Color("#F4FAFB")

## "battery", "coin" or "none".
var truth := "battery"
## "front" or "side".
var view := "front"
var zoomed := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func set_state(new_view: String, new_zoom: bool) -> void:
	if new_view != view or new_zoom != zoomed:
		view = new_view
		zoomed = new_zoom
		queue_redraw()


## Where the object is on the film, in this control's pixels.
func object_centre() -> Vector2:
	if zoomed:
		return size / 2.0
	return Vector2(size.x * (0.5 if view == "front" else 0.47), size.y * 0.34)


func object_radius() -> float:
	return minf(size.x, size.y) * (0.3 if zoomed else 0.05)


func _gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		if truth == "none" or press.position.distance_to(object_centre()) <= object_radius() * 1.8 + UiKit.px(16):
			object_tapped.emit()
			accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), FILM)
	if zoomed:
		_draw_zoom()
	elif view == "front":
		_draw_front()
	else:
		_draw_side()
	# Film markings.
	var font := UiKit.heavy_font()
	draw_string(font, Vector2(UiKit.px(10), UiKit.px(18)), "R", HORIZONTAL_ALIGNMENT_LEFT, -1, int(UiKit.px(14)), BONE)
	var caption := "ZOOM" if zoomed else ("AP" if view == "front" else "LATERAL")
	draw_string(font, Vector2(0, size.y - UiKit.px(10)), caption, HORIZONTAL_ALIGNMENT_RIGHT, size.x - UiKit.px(10),
		int(UiKit.px(11)), Color(BONE, 0.7))


func _draw_front() -> void:
	var w := size.x
	var h := size.y
	var mid := w * 0.5
	# Soft tissue of the neck and chest.
	draw_colored_polygon(PackedVector2Array([Vector2(mid - w * 0.12, 0), Vector2(mid + w * 0.12, 0),
		Vector2(mid + w * 0.14, h * 0.28), Vector2(w * 0.95, h * 0.42), Vector2(w * 0.95, h),
		Vector2(w * 0.05, h), Vector2(w * 0.05, h * 0.42), Vector2(mid - w * 0.14, h * 0.28)]), SOFT)
	# The spine: a column of vertebrae down the middle.
	for index in 12:
		var y := h * 0.02 + index * h * 0.08
		draw_rect(Rect2(mid - w * 0.035, y, w * 0.07, h * 0.06), Color(BONE, 0.55))
	# Collar bones.
	for side: float in [-1.0, 1.0]:
		draw_polyline(PackedVector2Array([Vector2(mid + side * w * 0.05, h * 0.36), Vector2(mid + side * w * 0.2, h * 0.31),
			Vector2(mid + side * w * 0.36, h * 0.33)]), Color(BONE, 0.8), UiKit.px(7), true)
	# Ribs: arcs either side.
	for index in 6:
		var y := h * 0.44 + index * h * 0.085
		for side: float in [-1.0, 1.0]:
			var points := PackedVector2Array()
			for step in 9:
				var t := step / 8.0
				points.append(Vector2(mid + side * (w * 0.05 + t * w * 0.36), y + sin(t * PI) * -h * 0.05 + t * h * 0.06))
			draw_polyline(points, Color(BONE, 0.42), UiKit.px(4), true)
	# The heart's shadow.
	draw_circle(Vector2(mid + w * 0.06, h * 0.7), w * 0.12, Color(BONE, 0.12))
	if truth != "none":
		var centre := object_centre()
		draw_circle(centre, object_radius(), METAL)


func _draw_side() -> void:
	var w := size.x
	var h := size.y
	# Neck and chest from the side: the airway in front, the spine behind.
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.32, 0), Vector2(w * 0.68, 0), Vector2(w * 0.78, h * 0.4),
		Vector2(w * 0.86, h), Vector2(w * 0.14, h), Vector2(w * 0.24, h * 0.4)]), SOFT)
	for index in 12:
		var y := h * 0.02 + index * h * 0.08
		draw_rect(Rect2(w * 0.6, y, w * 0.08, h * 0.065), Color(BONE, 0.55))
	draw_line(Vector2(w * 0.4, 0), Vector2(w * 0.42, h * 0.55), Color(0, 0, 0, 0.6), UiKit.px(10))
	if truth == "none":
		return
	var centre := object_centre()
	var long := object_radius() * 2.0
	if truth == "battery":
		# Edge on: thick, with a step where the two halves meet.
		draw_rect(Rect2(centre.x - UiKit.px(5), centre.y - long / 2.0, UiKit.px(10), long), METAL)
		draw_rect(Rect2(centre.x + UiKit.px(4), centre.y - long * 0.38, UiKit.px(4), long * 0.76), METAL)
	else:
		draw_rect(Rect2(centre.x - UiKit.px(2), centre.y - long / 2.0, UiKit.px(4), long), METAL)


func _draw_zoom() -> void:
	var centre := object_centre()
	var radius := object_radius()
	draw_circle(centre, radius * 1.5, SOFT)
	if truth == "none":
		return
	draw_circle(centre, radius, METAL)
	if truth == "battery":
		# The halo: a second, inner ring around the battery's centre.
		draw_arc(centre, radius * 0.78, 0, TAU, 48, Color("#7F8C90"), UiKit.px(6), true)
		draw_circle(centre, radius * 0.7, Color("#E6EEF0"))
	else:
		draw_arc(centre, radius * 0.92, 0, TAU, 48, Color("#D3DCDF"), UiKit.px(2), true)
