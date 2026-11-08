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
	made.default_font_size = int(px(14))
	made.set_color("font_color", "Label", TEXT)
	return made


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
	made.add_theme_font_size_override("font_size", int(px(size)))
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
	button.add_theme_font_size_override("font_size", int(px(size)))
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


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
