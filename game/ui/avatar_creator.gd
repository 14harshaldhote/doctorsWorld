class_name AvatarCreator
extends Control
## Step 2 of a new career: design the doctor. The 3D character on the left
## updates on every tap and can be turned by dragging; the choices sit in
## five tabs on the right.

signal back_pressed
signal done_pressed

const TABS := ["Body", "Face", "Hair", "Clothes", "Extras"]
## Each section: [kind, field, label, grid columns]. Kinds are "swatches",
## "chips", "toggle", "mood" (preview only), "voice" (the doctor's speaking
## voice, kept in the settings) and "locked" (earned later).
const SECTIONS := {
	"Body": [["swatches", "skin", "Skin tone", 5], ["chips", "body", "Build", 1], ["chips", "height", "Height", 2],
		["voice", "", "Voice", 2]],
	"Face": [["chips", "face", "Face shape", 3], ["chips", "eyes", "Eyes", 4], ["chips", "brows", "Brows", 3],
		["chips", "nose", "Nose", 3], ["mood", "", "Try an expression", 4]],
	"Hair": [["chips", "hair_style", "Style", 4], ["swatches", "hair_colour", "Colour", 5],
		["chips", "facial_hair", "Facial hair", 3]],
	"Clothes": [["swatches", "scrubs", "Scrubs", 4], ["toggle", "coat", "White coat", 2],
		["toggle", "watch", "Watch", 2]],
	"Extras": [["chips", "glasses", "Glasses", 3], ["toggle", "stethoscope", "Stethoscope", 2],
		["locked", "", "Earned later", 1]],
}
const LOCKED := [
	["Embroidered coat", "Junior Resident"],
	["Chief's long coat", "Chief of Medicine"],
]
## Camera framing: whole body, or close on the head for face and hair.
const FULL_VIEW := [Vector3(0, 0.98, 4.1), Vector3(0, 0.8, 0)]
const HEAD_VIEW := [Vector3(0, 1.56, 2.25), Vector3(0, 1.38, 0)]

var profile: PlayerProfile
var config: AvatarConfig
var tab := "Body"
var rig: AvatarRig

var _tab_buttons := {}
var _content: VBoxContainer
var _scroll: ScrollContainer
var _camera: Camera3D
var _camera_goal: Array = FULL_VIEW
var _dragging := false
var _turn := -0.35


func _init(for_profile: PlayerProfile = null) -> void:
	profile = for_profile if for_profile != null else PlayerProfile.new()
	config = profile.avatar.copy()


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.fill(self)
	var background := ColorRect.new()
	background.color = UiKit.PANEL_DEEP
	add_child(UiKit.fill(background))

	var layout := UiKit.hbox(0)
	add_child(UiKit.fill(layout))
	UiKit.keep_off_edges(layout)
	layout.add_child(_build_stage())

	var side := MarginContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for edge in ["left", "right"]:
		side.add_theme_constant_override("margin_" + edge, int(UiKit.px(22)))
	side.add_theme_constant_override("margin_top", int(UiKit.px(18)))
	side.add_theme_constant_override("margin_bottom", int(UiKit.px(16)))
	layout.add_child(side)
	var column := UiKit.vbox(12)
	side.add_child(column)

	var header := UiKit.hbox(10)
	column.add_child(header)
	var title := UiKit.heading("Design your doctor", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(UiKit.kicker("Step 2 of 2"))

	var tabs := UiKit.hbox(6)
	tabs.name = "Tabs"
	column.add_child(tabs)
	for tab_name: String in TABS:
		var button := Button.new()
		button.name = tab_name
		button.text = tab_name
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, UiKit.px(44))
		button.pressed.connect(show_tab.bind(tab_name))
		tabs.add_child(button)
		_tab_buttons[tab_name] = button

	var panel := UiKit.panel(UiKit.PANEL_SOLID, 16, Vector2(14, 14))
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_scroll)
	_content = UiKit.vbox(14)
	_content.name = "Choices"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)

	var buttons := UiKit.hbox(10)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(buttons)
	var back := UiKit.ghost_button("Back", 48, 16)
	back.name = "Back"
	back.pressed.connect(func() -> void: back_pressed.emit())
	buttons.add_child(back)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	var randomise := UiKit.ghost_button("Randomise", 48, 16)
	randomise.name = "Randomise"
	randomise.icon = null
	randomise.pressed.connect(_on_randomise)
	buttons.add_child(randomise)
	var done := UiKit.primary_button("Looks good", 48, 18)
	done.name = "LooksGood"
	done.pressed.connect(_on_done)
	buttons.add_child(done)

	show_tab(tab)


func _build_stage() -> Control:
	var holder := Control.new()
	holder.name = "Stage"
	holder.custom_minimum_size = Vector2(UiKit.px(300), 0)
	holder.clip_contents = true
	var view := SubViewportContainer.new()
	view.stretch = true
	UiKit.fill(view)
	view.gui_input.connect(_on_stage_input)
	holder.add_child(view)
	var viewport := SubViewport.new()
	viewport.msaa_3d = Viewport.MSAA_2X
	view.add_child(viewport)
	var stage := Node3D.new()
	stage.name = "World"
	viewport.add_child(stage)
	StageLighting.add_to(stage, UiKit.PANEL_SIDE, Vector3(-32, 30, 0))
	LowPoly.put(stage, LowPoly.cylinder(0.62, 0.68, 0.1, 10, Color("#1F5560")), Vector3(0, -0.05, 0))
	LowPoly.put(stage, LowPoly.cylinder(0.5, 0.5, 0.012, 10, Color("#2C6A74")), Vector3(0, 0.006, 0))
	rig = AvatarRig.new(config)
	rig.name = "Doctor"
	rig.rotation.y = _turn
	stage.add_child(rig)
	_camera = Camera3D.new()
	_camera.fov = 32
	stage.add_child(_camera)
	_camera.look_at_from_position(FULL_VIEW[0], FULL_VIEW[1])

	var fade := Gradient.new()
	fade.set_color(0, Color(UiKit.PANEL_SIDE, 0.0))
	fade.set_color(1, Color(UiKit.PANEL_SIDE.darkened(0.35), 0.92))
	var fade_texture := GradientTexture2D.new()
	fade_texture.gradient = fade
	fade_texture.fill_from = Vector2(0, 0)
	fade_texture.fill_to = Vector2(0, 1)
	fade_texture.width = 4
	fade_texture.height = 64
	var shade := TextureRect.new()
	shade.texture = fade_texture
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.anchor_top = 1.0
	shade.anchor_right = 1.0
	shade.anchor_bottom = 1.0
	shade.offset_top = -UiKit.px(80)
	holder.add_child(shade)

	var caption := UiKit.vbox(2)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.alignment = BoxContainer.ALIGNMENT_END
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption.offset_bottom = -UiKit.px(14)
	holder.add_child(caption)
	var name_label := UiKit.label(profile.full_title(), 18, UiKit.TEXT, UiKit.heading_font())
	name_label.name = "DoctorName"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_child(name_label)
	var hint := UiKit.hbox(6)
	hint.alignment = BoxContainer.ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_child(UiIcon.make("turn", 14, UiKit.TEXT_SOFT))
	hint.add_child(UiKit.label("Drag to turn", 12, UiKit.TEXT_SOFT, UiKit.heavy_font()))
	caption.add_child(hint)
	return holder


## Shows one tab's choices and frames the camera to suit it.
func show_tab(tab_name: String) -> void:
	tab = tab_name
	for other: String in _tab_buttons:
		var button: Button = _tab_buttons[other]
		var on := other == tab_name
		button.set_pressed_no_signal(on)
		var style := UiKit.box(UiKit.MINT if on else Color(1, 1, 1, 0.04), 12, Color(UiKit.MINT, 0.35), 1)
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			button.add_theme_stylebox_override(state, style)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			button.add_theme_color_override(state, UiKit.MINT_TEXT if on else UiKit.TEXT)
		button.add_theme_font_override("font", UiKit.heading_medium_font())
		UiKit.set_text_size(button, 15)
		button.focus_mode = Control.FOCUS_NONE
	_camera_goal = HEAD_VIEW if tab_name == "Face" or tab_name == "Hair" or tab_name == "Extras" else FULL_VIEW
	if tab_name != "Face" and rig.mood != AvatarConfig.Mood.CALM:
		rig.set_mood(AvatarConfig.Mood.CALM)
	_build_choices()


func _build_choices() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	var sections := UiKit.flow(24)
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(sections)
	for section: Array in SECTIONS[tab]:
		sections.add_child(_section(section))
	_scroll.scroll_vertical = 0


func _section(section: Array) -> Control:
	var kind: String = section[0]
	var field: String = section[1]
	var box := UiKit.vbox(8)
	box.name = field.capitalize().replace(" ", "") if not field.is_empty() else kind.capitalize()
	box.add_child(UiKit.label(section[2], 13, UiKit.TEXT_LABEL, UiKit.heavy_font()))
	var grid := UiKit.grid(section[3], 8)
	box.add_child(grid)
	match kind:
		"swatches":
			var colours := AvatarConfig.catalogue(field)
			for index in colours.size():
				var swatch := UiKit.swatch(colours[index], config.get(field) == index)
				swatch.tooltip_text = _choice_name(field, index)
				swatch.pressed.connect(_pick.bind(field, index))
				grid.add_child(swatch)
		"chips":
			var names := AvatarConfig.catalogue(field)
			for index in names.size():
				grid.add_child(_chip(_choice_name(field, index), config.get(field) == index, _pick.bind(field, index)))
		"toggle":
			for value: bool in [true, false]:
				grid.add_child(_chip("On" if value else "Off", config.get(field) == value, _pick.bind(field, value)))
		"mood":
			for index in AvatarConfig.EXPRESSIONS.size():
				grid.add_child(_chip(AvatarConfig.EXPRESSIONS[index], rig.mood == index, _try_mood.bind(index)))
		"voice":
			for index in 2:
				grid.add_child(_chip(Speech.YOUR_VOICE_NAMES[index], GameSettings.current.your_voice == index,
					_pick_voice.bind(index)))
		"locked":
			for item: Array in LOCKED:
				grid.add_child(_locked_row(item[0], item[1]))
	return box


func _chip(text: String, selected: bool, action: Callable) -> Button:
	var chip := UiKit.chip(text, selected)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.custom_minimum_size.x = UiKit.px(76)
	chip.pressed.connect(action)
	return chip


func _locked_row(item: String, rank_name: String) -> Control:
	var row := PanelContainer.new()
	var style := UiKit.box(Color(1, 1, 1, 0.03), 12, Color(UiKit.MINT, 0.45), 1, Vector2(12, 0))
	row.add_theme_stylebox_override("panel", style)
	row.custom_minimum_size = Vector2(UiKit.px(250), UiKit.px(44))
	var line := UiKit.hbox(10)
	row.add_child(line)
	var lock := UiIcon.make("lock", 16, UiKit.TEXT_LABEL)
	lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(lock)
	var text := UiKit.label("%s · %s" % [item, rank_name], 14, UiKit.TEXT_LABEL)
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(text)
	return row


func _choice_name(field: String, index: int) -> String:
	match field:
		"skin":
			return "Skin tone %d" % (index + 1)
		"hair_colour":
			return AvatarConfig.HAIR_COLOUR_NAMES[index]
		"scrubs":
			return AvatarConfig.SCRUB_NAMES[index]
	var names := AvatarConfig.catalogue(field)
	return str(names[index])


## Applies one choice, rebuilds the character and refreshes the tab.
func _pick(field: String, value: Variant) -> void:
	config.set(field, value)
	_apply()


## The speaking voice belongs to the settings (it can be changed there
## later); picking one here saves it and says hello in it.
func _pick_voice(index: int) -> void:
	GameSettings.current.your_voice = index
	if not SettingsPanel.save_path.is_empty():
		GameSettings.current.save_to(SettingsPanel.save_path)
	Speech.preview_you()
	_build_choices()


func _try_mood(index: int) -> void:
	rig.set_mood(index)
	_build_choices()


func _apply() -> void:
	var mood := rig.mood
	rig.set_config(config)
	rig.set_mood(mood)
	var scroll := _scroll.scroll_vertical
	_build_choices()
	_scroll.set_deferred("scroll_vertical", scroll)


func _on_randomise() -> void:
	config = AvatarConfig.random(SeededRandom.new(Time.get_ticks_usec()))
	_apply()


func _on_done() -> void:
	profile.avatar = config.copy()
	done_pressed.emit()


func _on_stage_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_dragging = (event as InputEventMouseButton).pressed
	elif event is InputEventMouseMotion and _dragging:
		_turn += (event as InputEventMouseMotion).relative.x * 0.012
	elif event is InputEventScreenDrag:
		_turn += (event as InputEventScreenDrag).relative.x * 0.012


func _process(delta: float) -> void:
	if rig != null:
		rig.rotation.y = lerp_angle(rig.rotation.y, _turn, minf(1.0, delta * 12.0))
	if _camera != null:
		var goal_from: Vector3 = _camera_goal[0]
		var goal_at: Vector3 = _camera_goal[1]
		var weight := minf(1.0, delta * 6.0)
		var from := _camera.position.lerp(goal_from, weight)
		var looking := (-_camera.global_transform.basis.z * from.distance_to(goal_at) + _camera.position).lerp(goal_at,
			weight)
		_camera.look_at_from_position(from, looking)


## Jumps the camera straight to its framing (for screenshots).
func settle_camera() -> void:
	_camera.look_at_from_position(_camera_goal[0], _camera_goal[1])
