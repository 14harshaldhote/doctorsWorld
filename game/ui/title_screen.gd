class_name TitleScreen
extends Control
## The first screen: the hospital at dusk with New career and Continue.

signal new_career_pressed
signal continue_pressed

## The saved doctor, or null when there is no save to continue.
var saved: PlayerProfile

var new_button: Button
var continue_button: Button


func _init(saved_profile: PlayerProfile = null) -> void:
	saved = saved_profile


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.fill(self)
	var view := SubViewportContainer.new()
	view.name = "Backdrop"
	view.stretch = true
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(view)
	add_child(view)
	var viewport := SubViewport.new()
	viewport.msaa_3d = Viewport.MSAA_2X
	view.add_child(viewport)
	viewport.add_child(HospitalFront.new())

	# A soft dark wash on the left so the text stays readable over the sky.
	var fade := Gradient.new()
	fade.set_color(0, Color(0.03, 0.12, 0.15, 0.55))
	fade.set_color(1, Color(0.03, 0.12, 0.15, 0.0))
	var fade_texture := GradientTexture2D.new()
	fade_texture.gradient = fade
	fade_texture.width = 64
	fade_texture.height = 4
	var wash := TextureRect.new()
	wash.texture = fade_texture
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.anchor_bottom = 1.0
	wash.offset_right = UiKit.px(470)
	add_child(wash)

	var column := UiKit.vbox(10)
	column.name = "Menu"
	column.position = Vector2(UiKit.px(44), UiKit.px(40))
	column.custom_minimum_size = Vector2(UiKit.px(380), 0)
	add_child(column)
	column.add_child(UiKit.kicker("A hospital story", 13))
	var title := UiKit.label("Doctors\nWorld", 58, Color.WHITE, UiKit.font("Fredoka-SemiBold"))
	title.add_theme_constant_override("line_spacing", int(UiKit.px(-10)))
	column.add_child(title)
	var tagline := UiKit.label("From your first day as an intern to Chief of Medicine.", 16, Color("#DCEDEA"))
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tagline.custom_minimum_size = Vector2(UiKit.px(320), 0)
	tagline.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(tagline)

	var buttons := UiKit.vbox(10)
	buttons.custom_minimum_size = Vector2(UiKit.px(270), 0)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(buttons)
	new_button = UiKit.primary_button("New career", 52, 21)
	new_button.name = "NewCareer"
	new_button.pressed.connect(func() -> void: new_career_pressed.emit())
	buttons.add_child(new_button)
	if saved != null:
		continue_button = _continue_button()
		buttons.add_child(continue_button)

	var version := UiKit.label("v%s" % ProjectSettings.get_setting("application/config/version", "0"), 11,
		Color(1, 1, 1, 0.45))
	version.anchor_left = 1.0
	version.anchor_right = 1.0
	version.anchor_top = 1.0
	version.anchor_bottom = 1.0
	version.offset_left = -UiKit.px(60)
	version.offset_top = -UiKit.px(26)
	add_child(version)


func _continue_button() -> Button:
	var button := Button.new()
	button.name = "Continue"
	button.custom_minimum_size = Vector2(0, UiKit.px(56))
	var normal := UiKit.box(Color(7 / 255.0, 32 / 255.0, 37 / 255.0, 0.78), 14, UiKit.MINT, 2, Vector2(18, 0))
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(UiKit.MINT, 0.2)
	for state in ["normal", "hover", "focus"]:
		button.add_theme_stylebox_override(state, normal)
	button.add_theme_stylebox_override("pressed", pressed)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: continue_pressed.emit())
	var text := UiKit.vbox(1)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.offset_left = UiKit.px(18)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	button.add_child(text)
	var heading := UiKit.label("Continue", 18, UiKit.TEXT, UiKit.heading_font())
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(heading)
	var detail := UiKit.label("%s · %s · Day %d" % [saved.full_title(), Rank.title(saved.rank()), saved.day], 13,
		UiKit.TEXT_SOFT)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(detail)
	return button
