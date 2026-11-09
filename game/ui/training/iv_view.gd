class_name IvView
extends TrainingView
## IV line, in three steps. Tap the vein you'd use on the practice arm. Set
## the needle's angle with the slider, watching the side view, then insert.
## Then drag to keep the needle tip inside the circle while it wanders.

## Screen pixels per millimetre on the steadying pad.
const PIXELS_PER_MM := 16.0

var _angle_panel: PanelContainer
var _diagram: AngleDiagram
var _slider: HSlider
var _insert: Button
var _steady_panel: PanelContainer
var _pad: SteadyPad
var _steady_label: Label


func _build() -> void:
	_angle_panel = _right_panel(300)
	_angle_panel.name = "Angle"
	var column := UiKit.vbox(8)
	_angle_panel.add_child(column)
	column.add_child(UiKit.kicker("Needle angle · side view", 11))
	_diagram = AngleDiagram.new()
	_diagram.name = "Diagram"
	_diagram.clip_contents = true
	_diagram.custom_minimum_size = Vector2(0, UiKit.px(120))
	column.add_child(_diagram)
	_slider = HSlider.new()
	_slider.name = "Slider"
	_slider.min_value = 0
	_slider.max_value = 60
	_slider.step = 1
	_slider.custom_minimum_size = Vector2(0, UiKit.px(30))
	_slider.value_changed.connect(set_angle)
	column.add_child(_slider)
	_insert = UiKit.primary_button("Insert", 44, 16)
	_insert.name = "Insert"
	_insert.pressed.connect(insert)
	column.add_child(_insert)
	_steady_panel = _right_panel(250)
	_steady_panel.name = "Steady"
	var steady := UiKit.vbox(8)
	_steady_panel.add_child(steady)
	steady.add_child(UiKit.kicker("Keep the tip in the vein", 11))
	_pad = SteadyPad.new()
	_pad.name = "Pad"
	_pad.view = self
	_pad.custom_minimum_size = Vector2(UiKit.px(226), UiKit.px(190))
	steady.add_child(_pad)
	_steady_label = UiKit.label("", 13, UiKit.TEXT, UiKit.heavy_font())
	steady.add_child(_steady_label)
	_slider.set_value_no_signal(_iv().angle)
	_sync()


func _iv() -> IvTask:
	return task as IvTask


func pick_vein(which: String) -> void:
	if not result_open():
		_iv().pick_vein(which)
		_sync()


func set_angle(degrees: float) -> void:
	if not result_open():
		_iv().set_angle(degrees)
		if not is_equal_approx(_slider.value, degrees):
			_slider.set_value_no_signal(degrees)
		_sync()


func insert() -> void:
	if not result_open():
		_iv().insert()
		_sync()


## A drag while steadying, in screen pixels: moves the tip the same way.
func drag(relative: Vector2) -> void:
	if not result_open():
		_iv().nudge(relative / UiKit.px(PIXELS_PER_MM))


func world_tap(screen_point: Vector2) -> void:
	var arm := station() as ArmPad
	var camera := view_camera()
	if arm == null or camera == null or _iv().phase != "vein":
		return
	var found := arm.vein_at(camera, screen_point)
	if not found.is_empty():
		pick_vein(found)


func world_drag(relative: Vector2) -> void:
	if _iv().phase == "steady":
		drag(relative)


func _tick(_delta: float) -> void:
	_sync()


func _sync() -> void:
	var iv := _iv()
	if iv == null or _diagram == null:
		return
	_angle_panel.visible = iv.phase == "angle"
	_steady_panel.visible = iv.phase == "steady"
	_diagram.angle = iv.angle
	_diagram.queue_redraw()
	_pad.offset = iv.offset
	_pad.inside = iv.is_inside()
	_pad.queue_redraw()
	_steady_label.text = "In the vein: %d%%" % int(round(100.0 * iv.inside_time / maxf(0.01, iv.steady_time))) \
		if iv.steady_time > 0.0 else "Drag against the wobble"


func _hide_controls() -> void:
	_angle_panel.visible = false
	_steady_panel.visible = false


## The needle from the side: the skin, the vein beneath, the safe angles
## shaded green, and the needle at the angle set.
class AngleDiagram extends Control:
	var angle := 40.0

	func _draw() -> void:
		var skin_y := size.y * 0.55
		draw_rect(Rect2(0, skin_y, size.x, size.y - skin_y), Color("#F0C9B4", 0.22))
		draw_line(Vector2(0, skin_y), Vector2(size.x, skin_y), Color("#F0C9B4"), UiKit.px(2))
		var entry := Vector2(size.x * 0.62, skin_y)
		var vein_y := skin_y + size.y * 0.2
		draw_rect(Rect2(0, vein_y - UiKit.px(6), size.x, UiKit.px(12)), Color("#4C6DB2", 0.85))
		var reach := minf(size.x * 0.5, skin_y * 0.9 / sin(deg_to_rad(maxf(angle, 30.0))))
		var wedge := PackedVector2Array([entry])
		for step in 7:
			var edge := deg_to_rad(lerpf(IvTask.ANGLE_LOW, IvTask.ANGLE_HIGH, step / 6.0))
			wedge.append(entry + Vector2(-cos(edge), -sin(edge)) * reach)
		draw_colored_polygon(wedge, Color(UiKit.MINT, 0.22))
		var a := deg_to_rad(angle)
		var good := angle >= IvTask.ANGLE_LOW and angle <= IvTask.ANGLE_HIGH
		var colour := UiKit.MINT if good else UiKit.CORAL
		var back := entry + Vector2(-cos(a), -sin(a)) * reach
		var tip := entry + Vector2(cos(a), sin(a)) * size.y * 0.22
		draw_line(back, tip, Color("#DDE6E8"), UiKit.px(3))
		draw_line(back, back.lerp(entry, 0.35), Color("#F48FB1"), UiKit.px(7))
		draw_string(UiKit.heading_font(), Vector2(size.x - UiKit.px(50), UiKit.px(22)), "%d°" % int(round(angle)),
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(UiKit.px(20)), colour)
		draw_string(UiKit.heavy_font(), Vector2(UiKit.px(4), size.y - UiKit.px(6)), "Aim: 15° to 30°",
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(UiKit.px(11)), UiKit.TEXT_KICKER)


## The steadying target: a circle for the vein and a dot for the needle tip.
## Dragging anywhere on it moves the tip.
class SteadyPad extends Control:
	var view: IvView
	var offset := Vector2.ZERO
	var inside := true
	var _held := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		var button := event as InputEventMouseButton
		if button != null and button.button_index == MOUSE_BUTTON_LEFT:
			_held = button.pressed
			accept_event()
			return
		var motion := event as InputEventMouseMotion
		if motion != null and _held and view != null:
			view.drag(motion.relative)
			accept_event()

	func _draw() -> void:
		var centre := size / 2.0
		var per_mm := UiKit.px(IvView.PIXELS_PER_MM)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.25))
		draw_circle(centre, IvTask.TARGET_RADIUS * per_mm, Color(UiKit.MINT, 0.14))
		draw_arc(centre, IvTask.TARGET_RADIUS * per_mm, 0, TAU, 40, Color(UiKit.MINT, 0.8), UiKit.px(2))
		var tip := centre + offset * per_mm
		tip = Vector2(clampf(tip.x, 0, size.x), clampf(tip.y, 0, size.y))
		draw_circle(tip, UiKit.px(7), UiKit.MINT if inside else UiKit.CORAL)
		draw_arc(tip, UiKit.px(11), 0, TAU, 24, Color(UiKit.TEXT, 0.6), UiKit.px(1.5))
