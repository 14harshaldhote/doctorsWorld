class_name UiKit
extends RefCounted
## The game's look for buttons, chips, panels and text, matching the screen
## designs. Sizes are written in design pixels (the designs are drawn at
## 844 x 390) and doubled, because the game's canvas is 1688 x 780.

const SCALE := 2.0

const PANEL := Color(7 / 255.0, 32 / 255.0, 37 / 255.0, 0.86)
const PANEL_DEEP := Color("#0E2A30")
const PANEL_SOLID := Color("#133840")
const PANEL_SIDE := Color("#173F48")
const INPUT := Color("#0B2328")
const AMBER := Color("#F5B841")
const AMBER_EDGE := Color("#B9821F")
const AMBER_TEXT := Color("#2A1A00")
const MINT := Color("#8FE3D2")
const MINT_TEXT := Color("#0B2328")
const CORAL := Color("#F07C5A")
const TEAL := Color("#127C80")
const TEXT := Color("#F4FBFA")
const TEXT_SOFT := Color("#B8D6D2")
const TEXT_LABEL := Color("#CFE6E2")
const TEXT_KICKER := Color("#A9D8D0")
const INK := Color("#12333A")

static var _fonts := {}
static var _textures := {}
## Stands in for the device's safe area in tests and screenshots (see
## safe_insets()), or null to ask the device.
static var inset_override: Variant = null


## Design pixels to canvas units.
static func px(value: float) -> float:
	return value * SCALE


static func font(font_name: String) -> Font:
	if not _fonts.has(font_name):
		_fonts[font_name] = load("res://assets/fonts/%s.woff2" % font_name)
	return _fonts[font_name]


## Rounded Fredoka for headings and buttons.
static func heading_font() -> Font:
	return font("Fredoka-SemiBold")


static func heading_medium_font() -> Font:
	return font("Fredoka-Medium")


## Nunito for body text.
static func body_font() -> Font:
	return font("Nunito-Bold")


static func heavy_font() -> Font:
	return font("Nunito-ExtraBold")


## The default theme for every screen: Nunito text, light on dark.
static func theme() -> Theme:
	var made := Theme.new()
	made.default_font = body_font()
	made.default_font_size = scaled_text(14)
	made.set_color("font_color", "Label", TEXT)
	return made


## Sets a control's text size in design pixels, grown by the Text size
## setting. refresh_text() sets it again when the setting changes.
static func set_text_size(control: Control, size: float) -> void:
	control.set_meta(&"text_size", size)
	control.add_theme_font_size_override("font_size", scaled_text(size))


## A text size in canvas units with the Text size setting applied. Body
## text grows the most; big headings, already easy to read, grow less, and
## titles of 28 and over not at all, so screens still fit.
static func scaled_text(size: float) -> int:
	var weight := clampf((size - 18.0) / 10.0, 0.0, 1.0)
	return int(px(size) * lerpf(GameSettings.current.text_scale(), 1.0, weight))


## Applies the Text size setting to every screen under root at once: the
## panels and lists grow around the bigger text.
static func refresh_text(root: Node) -> void:
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*", "Control", true, false))
	for node in nodes:
		var control := node as Control
		if control == null:
			continue
		if control.has_meta(&"text_size"):
			set_text_size(control, float(control.get_meta(&"text_size")))
		if control.theme != null:
			control.theme.default_font_size = scaled_text(14)


## How tall text wraps to in a given width (canvas units) at a design text
## size, with the Text size setting applied.
static func wrapped_height(text: String, width: float, size: float, which: Font = null) -> float:
	var used := which if which != null else body_font()
	return used.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, scaled_text(size)).y


## Keeps a button at least as tall as the column of labels inside it (plus
## padding top and bottom) as the text wraps or the text size changes.
static func fit_height(button: Control, content: Control, padding: float) -> void:
	var fit := func() -> void:
		# Before the first layout the labels have no width and wrap every word.
		if content.size.x > 1.0:
			button.custom_minimum_size.y = content.get_combined_minimum_size().y + px(padding) * 2.0
	content.minimum_size_changed.connect(fit)
	content.resized.connect(fit)


static func box(colour: Color, radius: float = 14, border: Color = Color.TRANSPARENT, border_width: float = 0,
		padding: Vector2 = Vector2.ZERO) -> StyleBoxFlat:
	var made := StyleBoxFlat.new()
	made.bg_color = colour
	made.set_corner_radius_all(int(px(radius)))
	if border_width > 0:
		made.border_color = border
		made.set_border_width_all(int(maxf(1.0, px(border_width))))
	made.content_margin_left = px(padding.x)
	made.content_margin_right = px(padding.x)
	made.content_margin_top = px(padding.y)
	made.content_margin_bottom = px(padding.y)
	made.anti_aliasing = true
	return made


static func label(text: String, size: float = 14, colour: Color = TEXT, which: Font = null) -> Label:
	var made := Label.new()
	made.text = text
	set_text_size(made, size)
	made.add_theme_color_override("font_color", colour)
	if which != null:
		made.add_theme_font_override("font", which)
	return made


## Small spaced capitals above a heading, like "STEP 1 OF 2".
static func kicker(text: String, size: float = 12) -> Label:
	var made := label(text.to_upper(), size, TEXT_KICKER, heavy_font())
	made.add_theme_constant_override("outline_size", 0)
	return made


static func heading(text: String, size: float = 24) -> Label:
	return label(text, size, TEXT, heading_font())


static func _style_button(button: Button, normal: StyleBox, pressed: StyleBox, text_colour: Color, size: float,
		which: Font) -> void:
	for state in ["normal", "hover", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, normal)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color"]:
		button.add_theme_color_override(state, text_colour)
	button.add_theme_color_override("font_disabled_color", Color(text_colour, 0.5))
	button.add_theme_font_override("font", which)
	set_text_size(button, size)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	respond_to_press(button)


## A button that dips a little when pressed and makes a soft tap. With
## Reduce motion on it only changes colour.
static func respond_to_press(button: BaseButton) -> void:
	if button.has_meta("responds"):
		return
	button.set_meta("responds", true)
	button.resized.connect(func() -> void: button.pivot_offset = button.size / 2.0)
	button.button_down.connect(func() -> void:
		if not GameSettings.current.reduce_motion:
			button.scale = Vector2.ONE * 0.96)
	button.button_up.connect(func() -> void:
		if button.scale == Vector2.ONE or not button.is_inside_tree():
			button.scale = Vector2.ONE
			return
		var back := button.create_tween()
		back.tween_property(button, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	button.pressed.connect(func() -> void: Sfx.ui("tap", -14.0))


## How far a camera moves towards its goal this frame: weight normally, or
## all the way (a cut) when Reduce motion is on.
static func motion_weight(weight: float) -> float:
	return 1.0 if GameSettings.current.reduce_motion else weight


## Fades a panel in, growing it slightly from its middle (just the fade
## with Reduce motion on).
static func pop_in(control: Control, seconds: float = 0.28) -> void:
	if control == null or not control.is_inside_tree():
		return
	control.modulate.a = 0.0
	var appear := control.create_tween().set_parallel(true)
	appear.tween_property(control, "modulate:a", 1.0, seconds * 0.8)
	if not GameSettings.current.reduce_motion:
		control.scale = Vector2.ONE * 0.94
		_keep_centred(control)
		appear.tween_property(control, "scale", Vector2.ONE, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Pops controls (such as stars) in one after another.
static func pop_one_by_one(controls: Array[Control], delay: float, gap: float = 0.14) -> void:
	for index in controls.size():
		var item := controls[index]
		if item == null or not item.is_inside_tree():
			continue
		if GameSettings.current.reduce_motion:
			continue
		item.scale = Vector2.ZERO
		_keep_centred(item)
		var grow := item.create_tween()
		grow.tween_interval(delay + gap * index)
		grow.tween_property(item, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Slides a control in from an edge (by offset, in canvas units) as it fades
## in; only the fade with Reduce motion on.
static func slide_in(control: Control, from: Vector2, seconds: float = 0.3) -> void:
	if control == null or not control.is_inside_tree():
		return
	control.modulate.a = 0.0
	var motion := control.create_tween().set_parallel(true)
	motion.tween_property(control, "modulate:a", 1.0, seconds)
	if not GameSettings.current.reduce_motion:
		var to := control.position
		control.position = to + from
		motion.tween_property(control, "position", to, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


static func _keep_centred(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
	if not control.has_meta("centred"):
		control.set_meta("centred", true)
		control.resized.connect(func() -> void: control.pivot_offset = control.size / 2.0)


## A volume slider, 0 to 100, with a big round handle for thumbs.
static func slider() -> HSlider:
	var made := HSlider.new()
	made.min_value = 0
	made.max_value = 100
	made.step = 5
	made.custom_minimum_size = Vector2(0, px(30))
	made.focus_mode = Control.FOCUS_NONE
	var track := box(Color(1, 1, 1, 0.12), 4)
	track.content_margin_top = px(3)
	track.content_margin_bottom = px(3)
	var filled := box(MINT, 4)
	filled.content_margin_top = px(3)
	filled.content_margin_bottom = px(3)
	made.add_theme_stylebox_override("slider", track)
	made.add_theme_stylebox_override("grabber_area", filled)
	made.add_theme_stylebox_override("grabber_area_highlight", filled)
	var handle := _dot_texture(int(px(11)), AMBER)
	made.add_theme_icon_override("grabber", handle)
	made.add_theme_icon_override("grabber_highlight", handle)
	return made


static func _dot_texture(radius: int, colour: Color) -> ImageTexture:
	var key := "dot%d%s" % [radius, colour.to_html()]
	if _textures.has(key):
		return _textures[key]
	var size := radius * 2 + 2
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var middle := Vector2(size / 2.0, size / 2.0)
	for y in size:
		for x in size:
			var distance := Vector2(x + 0.5, y + 0.5).distance_to(middle)
			var edge := clampf(radius - distance + 0.5, 0.0, 1.0)
			image.set_pixel(x, y, Color(colour, edge))
	var texture := ImageTexture.create_from_image(image)
	_textures[key] = texture
	return texture


## The amber call-to-action button with a darker lip underneath.
static func primary_button(text: String, height: float = 48, size: float = 18) -> Button:
	var made := Button.new()
	made.text = text
	made.custom_minimum_size = Vector2(0, px(height))
	var normal := box(AMBER, 14, Color.TRANSPARENT, 0, Vector2(26, 0))
	normal.shadow_color = AMBER_EDGE
	normal.shadow_size = 0
	normal.border_width_bottom = int(px(4))
	normal.border_color = AMBER_EDGE
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = AMBER.darkened(0.08)
	pressed.border_width_bottom = int(px(1))
	_style_button(made, normal, pressed, AMBER_TEXT, size, heading_font())
	return made


## A see-through button with a mint outline, for secondary actions.
static func ghost_button(text: String, height: float = 48, size: float = 17) -> Button:
	var made := Button.new()
	made.text = text
	made.custom_minimum_size = Vector2(0, px(height))
	var normal := box(Color(12 / 255.0, 30 / 255.0, 36 / 255.0, 0.85), 14, Color(MINT, 0.5), 2, Vector2(20, 0))
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(MINT, 0.18)
	_style_button(made, normal, pressed, TEXT, size, heading_medium_font())
	return made


## A pill-shaped choice. Selected chips are filled mint.
static func chip(text: String, selected: bool = false, height: float = 44) -> Button:
	var made := Button.new()
	made.text = text
	made.toggle_mode = true
	made.custom_minimum_size = Vector2(0, px(height))
	set_chip(made, selected)
	return made


static func set_chip(button: Button, selected: bool) -> void:
	button.set_pressed_no_signal(selected)
	var height := button.custom_minimum_size.y / SCALE
	var fill := MINT if selected else Color(1, 1, 1, 0.04)
	var style := box(fill, height / 2.0, MINT, 2, Vector2(14, 0))
	_style_button(button, style, style, MINT_TEXT if selected else TEXT, 15, heavy_font())


## A square colour choice. The chosen one gets an amber ring.
static func swatch(colour: Color, selected: bool = false, size: float = 44) -> Button:
	var made := Button.new()
	made.toggle_mode = true
	made.custom_minimum_size = Vector2(px(size), px(size))
	made.set_meta("colour", colour)
	set_swatch(made, selected)
	return made


static func set_swatch(button: Button, selected: bool) -> void:
	button.set_pressed_no_signal(selected)
	var colour: Color = button.get_meta("colour")
	var style := box(colour, 12, AMBER if selected else Color(1, 1, 1, 0.22), 3 if selected else 1.5)
	_style_button(button, style, style, TEXT, 12, body_font())


## A rounded panel with padding around its child.
static func panel(colour: Color = PANEL, radius: float = 16, padding: Vector2 = Vector2(14, 12)) -> PanelContainer:
	var made := PanelContainer.new()
	made.add_theme_stylebox_override("panel", box(colour, radius, Color.TRANSPARENT, 0, padding))
	return made


static func vbox(gap: float = 10) -> VBoxContainer:
	var made := VBoxContainer.new()
	made.add_theme_constant_override("separation", int(px(gap)))
	return made


static func hbox(gap: float = 10) -> HBoxContainer:
	var made := HBoxContainer.new()
	made.add_theme_constant_override("separation", int(px(gap)))
	return made


static func flow(gap: float = 8) -> HFlowContainer:
	var made := HFlowContainer.new()
	made.add_theme_constant_override("h_separation", int(px(gap)))
	made.add_theme_constant_override("v_separation", int(px(gap)))
	return made


static func grid(columns: int, gap: float = 8) -> GridContainer:
	var made := GridContainer.new()
	made.columns = columns
	made.add_theme_constant_override("h_separation", int(px(gap)))
	made.add_theme_constant_override("v_separation", int(px(gap)))
	return made


## Fills its parent completely.
static func fill(control: Control) -> Control:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return control


## The room to leave at the screen's edges for an iPhone's notch, rounded
## corners and home bar, in canvas units: x for the left and right (the
## same on both sides, so turning the phone round changes nothing), y for
## the top and z for the bottom. Nothing on computers.
static func safe_insets() -> Vector3:
	if inset_override != null:
		return inset_override
	var tree := Engine.get_main_loop() as SceneTree
	if not OS.has_feature("mobile") or tree == null:
		return Vector3.ZERO
	var screen := Vector2(DisplayServer.screen_get_size())
	var safe := DisplayServer.get_display_safe_area()
	if screen.x <= 0.0 or screen.y <= 0.0 or safe.size.x <= 0 or safe.size.y <= 0:
		return Vector3.ZERO
	var units := tree.root.get_visible_rect().size / screen
	var side := maxf(maxf(safe.position.x, screen.x - safe.end.x), 0.0) * units.x
	return Vector3(side, maxf(safe.position.y, 0.0) * units.y, maxf(screen.y - safe.end.y, 0.0) * units.y)


## Moves a control placed against the screen's edges (by its anchors) in by
## the safe area, so nothing sits under the notch or the home bar. Call it
## once the control is placed. Centred edges stay put.
static func keep_off_edges(control: Control) -> Control:
	var room := safe_insets()
	if room == Vector3.ZERO:
		return control
	for side: int in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		var anchor := control.get_anchor(side)
		var horizontal := side == SIDE_LEFT or side == SIDE_RIGHT
		var amount := room.x if horizontal else (room.y if is_zero_approx(anchor) else room.z)
		if is_zero_approx(anchor):
			control.set_offset(side, control.get_offset(side) + amount)
		elif is_equal_approx(anchor, 1.0):
			control.set_offset(side, control.get_offset(side) - amount)
	return control


## keep_off_edges() for every control directly under parent, except those
## that fill it (backgrounds and layers that line up with the 3D view).
static func keep_children_off_edges(parent: Control) -> void:
	if safe_insets() == Vector3.ZERO:
		return
	for child in parent.get_children():
		var control := child as Control
		if control == null:
			continue
		var fills := is_zero_approx(control.anchor_left) and is_zero_approx(control.anchor_top) \
			and is_equal_approx(control.anchor_right, 1.0) and is_equal_approx(control.anchor_bottom, 1.0)
		if not fills:
			keep_off_edges(control)
