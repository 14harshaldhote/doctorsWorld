class_name LobbyHud
extends Control
## Everything drawn over the hospital while walking around: the doctor's
## badge and XP, the clock, the pager, today's tasks, name tags and speech
## bubbles over people, and the Phone / Casebook / Team / Menu buttons.
## Conversations themselves are drawn by ConversationUi on top.

signal menu_choice(choice: String)

var profile: PlayerProfile

var _level_label: Label
var _xp_fill: ColorRect
var _xp_track: Control
var _clock_label: Label
var _pager: PanelContainer
var _pager_text: Label
var _tasks: VBoxContainer
var _hint: PanelContainer
var _buttons: HBoxContainer
var _today: PanelContainer
var _tags := {}
var _bubbles := {}
var _talking := false
var _menu: PanelContainer
var _settings: SettingsPanel
var _toast: PanelContainer
var _toast_label: Label
var _toast_time := 0.0
var _portrait_rig: AvatarRig
var _shown_level := -1
var _xp_tween: Tween


func _init(for_profile: PlayerProfile = null) -> void:
	profile = for_profile if for_profile != null else PlayerProfile.new()


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_badge()
	_build_clock()
	_build_pager()
	_build_tasks()
	_build_hint()
	_build_buttons()
	_build_menu()
	_build_toast()
	UiKit.keep_children_off_edges(self)
	refresh_profile()


func _corner(control: Control, left: bool, top: bool, x: float, y: float) -> void:
	control.anchor_left = 0.0 if left else 1.0
	control.anchor_right = control.anchor_left
	control.anchor_top = 0.0 if top else 1.0
	control.anchor_bottom = control.anchor_top
	control.grow_horizontal = Control.GROW_DIRECTION_END if left else Control.GROW_DIRECTION_BEGIN
	control.grow_vertical = Control.GROW_DIRECTION_END if top else Control.GROW_DIRECTION_BEGIN
	control.offset_left = UiKit.px(x) if left else -UiKit.px(x)
	control.offset_right = control.offset_left
	control.offset_top = UiKit.px(y) if top else -UiKit.px(y)
	control.offset_bottom = control.offset_top


func _build_badge() -> void:
	var badge := UiKit.panel(UiKit.PANEL, 16, Vector2(8, 8))
	badge.name = "Badge"
	(badge.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = UiKit.px(14)
	_corner(badge, true, true, 12, 12)
	add_child(badge)
	var row := UiKit.hbox(10)
	badge.add_child(row)
	row.add_child(_portrait())
	var text := UiKit.vbox(3)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(text)
	text.add_child(UiKit.label(profile.full_title(), 15, UiKit.TEXT, UiKit.heading_font()))
	_level_label = UiKit.label("", 12, UiKit.TEXT_SOFT)
	text.add_child(_level_label)
	_xp_track = Panel.new()
	_xp_track.custom_minimum_size = Vector2(UiKit.px(150), UiKit.px(6))
	_xp_track.add_theme_stylebox_override("panel", UiKit.box(Color(1, 1, 1, 0.18), 3))
	text.add_child(_xp_track)
	_xp_fill = ColorRect.new()
	_xp_fill.color = UiKit.AMBER
	_xp_fill.size = Vector2(0, UiKit.px(6))
	_xp_track.add_child(_xp_fill)


## A round, live 3D portrait of the doctor's face.
func _portrait() -> Control:
	var holder := TextureRect.new()
	holder.name = "Portrait"
	holder.custom_minimum_size = Vector2(UiKit.px(44), UiKit.px(44))
	holder.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	holder.stretch_mode = TextureRect.STRETCH_SCALE
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128, 128)
	viewport.own_world_3d = true
	viewport.transparent_bg = false
	viewport.msaa_3d = Viewport.MSAA_2X
	holder.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	StageLighting.add_to(world, UiKit.TEAL.darkened(0.1), Vector3(-25, 25, 0))
	_portrait_rig = AvatarRig.new(profile.avatar)
	_portrait_rig.mood = AvatarConfig.Mood.HAPPY
	world.add_child(_portrait_rig)
	var camera := Camera3D.new()
	camera.fov = 28
	world.add_child(camera)
	camera.look_at_from_position(Vector3(0, 1.55, 1.25), Vector3(0, 1.49, 0))
	holder.texture = viewport.get_texture()
	var mask := ShaderMaterial.new()
	mask.shader = _circle_shader()
	holder.material = mask
	return holder


static func _circle_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	vec2 offset = UV - vec2(0.5);
	float edge = smoothstep(0.5, 0.47, length(offset));
	COLOR = vec4(texture(TEXTURE, UV).rgb, edge);
}
"""
	return shader


func _build_clock() -> void:
	var pill := UiKit.panel(UiKit.PANEL, 18, Vector2(14, 0))
	pill.name = "Clock"
	pill.custom_minimum_size = Vector2(0, UiKit.px(36))
	pill.anchor_left = 0.5
	pill.anchor_right = 0.5
	pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pill.offset_top = UiKit.px(14)
	add_child(pill)
	var row := UiKit.hbox(8)
	pill.add_child(row)
	var icon := UiIcon.make("clock", 16, UiKit.MINT)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	_clock_label = UiKit.label("", 14, UiKit.TEXT, UiKit.heavy_font())
	_clock_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_clock_label)


func _build_pager() -> void:
	_pager = UiKit.panel(Color(7 / 255.0, 32 / 255.0, 37 / 255.0, 0.9), 14, Vector2(12, 10))
	_pager.name = "Pager"
	var style := _pager.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color = UiKit.AMBER
	style.set_border_width_all(int(UiKit.px(2)))
	_pager.custom_minimum_size = Vector2(UiKit.px(232), 0)
	_corner(_pager, false, true, 12, 12)
	add_child(_pager)
	var row := UiKit.hbox(10)
	_pager.add_child(row)
	var icon := UiIcon.make("pager", 20, UiKit.AMBER)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(icon)
	var text := UiKit.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(UiKit.label("PAGER · NOW", 11, UiKit.AMBER, UiKit.heavy_font()))
	_pager_text = UiKit.label("", 14, UiKit.TEXT)
	_pager_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pager_text.custom_minimum_size = Vector2(UiKit.px(180), 0)
	text.add_child(_pager_text)


func _build_tasks() -> void:
	var card := UiKit.panel(UiKit.PANEL, 14, Vector2(14, 12))
	card.name = "Today"
	card.custom_minimum_size = Vector2(UiKit.px(200), 0)
	_corner(card, true, true, 12, 92)
	add_child(card)
	_today = card
	_tasks = UiKit.vbox(8)
	card.add_child(_tasks)


func _build_hint() -> void:
	_hint = UiKit.panel(Color(7 / 255.0, 32 / 255.0, 37 / 255.0, 0.8), 16, Vector2(12, 0))
	_hint.name = "Hint"
	_hint.custom_minimum_size = Vector2(0, UiKit.px(32))
	_corner(_hint, true, false, 12, 14)
	add_child(_hint)
	var text := UiKit.label("Tap the floor to walk · tap a person to talk", 12, Color("#DCEDEA"))
	text.name = "Text"
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.add_child(text)


func _build_buttons() -> void:
	var row := UiKit.hbox(8)
	row.name = "Buttons"
	_corner(row, false, false, 12, 12)
	add_child(row)
	_buttons = row
	for entry: Array in [["Phone", "phone"], ["Casebook", "book"], ["Team", "team"], ["Menu", "menu"]]:
		var button := Button.new()
		button.name = entry[0]
		button.custom_minimum_size = Vector2(UiKit.px(60), UiKit.px(60))
		var style := UiKit.box(Color(7 / 255.0, 32 / 255.0, 37 / 255.0, 0.88), 16)
		var pressed := UiKit.box(Color(UiKit.MINT, 0.3), 16)
		for state in ["normal", "hover", "focus"]:
			button.add_theme_stylebox_override(state, style)
		button.add_theme_stylebox_override("pressed", pressed)
		button.focus_mode = Control.FOCUS_NONE
		var inside := UiKit.vbox(3)
		inside.alignment = BoxContainer.ALIGNMENT_CENTER
		inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiKit.fill(inside)
		button.add_child(inside)
		var icon := UiIcon.make(entry[1], 22)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		inside.add_child(icon)
		var caption := UiKit.label(entry[0], 11, UiKit.TEXT, UiKit.heavy_font())
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inside.add_child(caption)
		button.pressed.connect(_on_corner_button.bind(entry[0]))
		row.add_child(button)


func _build_menu() -> void:
	_menu = UiKit.panel(Color(7 / 255.0, 32 / 255.0, 37 / 255.0, 0.96), 18, Vector2(18, 16))
	_menu.name = "Menu"
	_menu.anchor_left = 0.5
	_menu.anchor_right = 0.5
	_menu.anchor_top = 0.5
	_menu.anchor_bottom = 0.5
	_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	_menu.custom_minimum_size = Vector2(UiKit.px(240), 0)
	_menu.visible = false
	add_child(_menu)
	var column := UiKit.vbox(10)
	_menu.add_child(column)
	column.add_child(UiKit.heading("Paused", 20))
	for entry: Array in [["Back to work", "resume", true], ["Change my look", "look", false],
			["Settings", "settings", false], ["Title screen", "title", false]]:
		var button := UiKit.primary_button(entry[0], 46, 16) if entry[2] else UiKit.ghost_button(entry[0], 46, 16)
		button.name = str(entry[1]).capitalize()
		button.pressed.connect(_on_menu_choice.bind(entry[1]))
		column.add_child(button)


func _build_toast() -> void:
	_toast = UiKit.panel(Color(7 / 255.0, 32 / 255.0, 37 / 255.0, 0.92), 14, Vector2(14, 8))
	_toast.name = "Toast"
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = UiKit.px(62)
	_toast.visible = false
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)
	_toast_label = UiKit.label("", 14, UiKit.TEXT)
	_toast.add_child(_toast_label)


func _on_corner_button(which: String) -> void:
	if which == "Menu":
		_menu.visible = true
		return
	var unlocks := {"Phone": "Your phone rings from Day 2.", "Casebook": "Your casebook opens with your first patient.",
		"Team": "You'll meet the whole team on your first ward round."}
	toast(unlocks.get(which, ""))


func _on_menu_choice(choice: String) -> void:
	_menu.visible = false
	if choice == "settings":
		open_settings()
		return
	menu_choice.emit(choice)


## Opens the settings over the paused game; closing them goes back to the menu.
func open_settings() -> SettingsPanel:
	if _settings != null:
		return _settings
	_settings = SettingsPanel.new()
	_settings.closed.connect(func() -> void:
		_settings = null
		_menu.visible = true
		profile.sound_on = GameSettings.current.effects > 0.0 or GameSettings.current.voices > 0.0)
	add_child(_settings)
	return _settings


func settings_panel() -> SettingsPanel:
	return _settings


func menu_open() -> bool:
	return _menu.visible or _settings != null


## Shows a short message under the clock for a few seconds.
func toast(text: String) -> void:
	_toast_label.text = text
	if not _toast.visible:
		_toast.visible = true
		UiKit.pop_in(_toast, 0.22)
	_toast_time = 3.0


func refresh_profile() -> void:
	var progress := LevelCurve.progress(profile.total_xp)
	var level := int(progress["level"])
	_level_label.text = "%s · Level %d" % [Rank.title(profile.rank()), level]
	var goal := Vector2(_xp_track.custom_minimum_size.x * float(progress["fraction"]), UiKit.px(6))
	var levelled_up := _shown_level > 0 and level > _shown_level
	var first := _shown_level < 0
	_shown_level = level
	if _xp_tween != null:
		_xp_tween.kill()
		_xp_tween = null
	if first or GameSettings.current.reduce_motion or not is_inside_tree() or goal == _xp_fill.size:
		_xp_fill.size = goal
	else:
		# The bar fills up; on a new level it runs to the end and starts again.
		_xp_tween = create_tween()
		if levelled_up:
			_xp_tween.tween_property(_xp_fill, "size:x", _xp_track.custom_minimum_size.x, 0.35)
			_xp_tween.tween_callback(func() -> void: _xp_fill.size.x = 0.0)
		_xp_tween.tween_property(_xp_fill, "size", goal, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if levelled_up:
		Sfx.play(self, "levelup", -8.0)
		toast("Level %d" % level)
	if _portrait_rig != null and not _portrait_rig.config.equals(profile.avatar):
		_portrait_rig.set_config(profile.avatar)


func set_clock(text: String) -> void:
	_clock_label.text = text


func set_pager(text: String) -> void:
	_pager.visible = not text.is_empty() and not _talking
	_pager_text.text = text


func pager_text() -> String:
	return _pager_text.text


## The line at the bottom left that says how to move around.
func set_hint(text: String) -> void:
	(_hint.get_node("Text") as Label).text = text


func hint_text() -> String:
	return (_hint.get_node("Text") as Label).text


## tasks: an array of [text, done], or [text, done, stars] to show a best
## result as three stars (-1 for none yet). The first unfinished task is
## highlighted. No tasks hides the card.
func set_tasks(tasks: Array, title: String = "Today") -> void:
	for child in _tasks.get_children():
		_tasks.remove_child(child)
		child.queue_free()
	_today.visible = not tasks.is_empty() and not _talking
	if tasks.is_empty():
		return
	_tasks.add_child(UiKit.kicker(title, 11))
	var current_found := false
	for task: Array in tasks:
		var done: bool = task[1]
		var current := not done and not current_found
		if current:
			current_found = true
		var row := UiKit.hbox(8)
		var icon := UiIcon.make("check" if done else ("dot" if current else "circle"), 15,
			UiKit.MINT if done or current else UiKit.TEXT_LABEL)
		icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(icon)
		var text := UiKit.label(task[0], 13, Color("#9FBFBB") if done else (Color.WHITE if current else UiKit.TEXT_LABEL),
			UiKit.heavy_font() if current else UiKit.body_font())
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var wider := GameSettings.current.text_scale()
		text.custom_minimum_size = Vector2(UiKit.px(160) * wider, 0)
		row.add_child(text)
		if task.size() > 2 and int(task[2]) >= 0:
			text.custom_minimum_size = Vector2(UiKit.px(118) * wider, 0)
			var stars := UiKit.hbox(1)
			stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			for index in 3:
				var lit := index < int(task[2])
				stars.add_child(UiIcon.make("star" if lit else "star_off", 13, UiKit.AMBER if lit else Color(UiKit.TEXT, 0.3)))
			row.add_child(stars)
		_tasks.add_child(row)


## Name tags float over people. tags: name -> [text, screen position, visible].
func set_tag(id: String, text: String, at: Vector2, shown: bool, highlight: bool = false) -> void:
	var tag: PanelContainer = _tags.get(id)
	if tag == null:
		tag = UiKit.panel(Color.WHITE, 14, Vector2(10, 0))
		tag.custom_minimum_size = Vector2(0, UiKit.px(28))
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := UiKit.label(text, 13, UiKit.INK, UiKit.heavy_font())
		label.name = "Text"
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.add_child(label)
		add_child(tag)
		move_child(tag, 0)
		_tags[id] = tag
	var text_label := tag.get_node("Text") as Label
	text_label.text = text
	var style := tag.get_theme_stylebox("panel") as StyleBoxFlat
	style.bg_color = UiKit.AMBER if highlight else Color(1, 1, 1, 0.94)
	tag.reset_size()
	tag.position = _keep_on_screen(at - Vector2(tag.size.x / 2.0, tag.size.y), tag.size)
	tag.visible = shown and not _talking and _on_screen(at) and not _covered(Rect2(tag.position, tag.size))


## A speech bubble over someone chatting nearby ("" hides it).
func set_bubble(id: String, text: String, at: Vector2, shown: bool) -> void:
	var bubble: PanelContainer = _bubbles.get(id)
	if bubble == null:
		bubble = UiKit.panel(Color(1, 1, 1, 0.92), 12, Vector2(10, 6))
		bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := UiKit.label("", 12, UiKit.INK, UiKit.body_font())
		label.name = "Text"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(UiKit.px(150), 0)
		bubble.add_child(label)
		add_child(bubble)
		move_child(bubble, 0)
		_bubbles[id] = bubble
	var label := bubble.get_node("Text") as Label
	if label.text != text:
		label.text = text
		bubble.size = Vector2.ZERO
	bubble.reset_size()
	bubble.position = _keep_on_screen(at - Vector2(bubble.size.x / 2.0, bubble.size.y), bubble.size)
	bubble.visible = shown and not text.is_empty() and not _talking and _on_screen(at) \
		and not _covered(Rect2(bubble.position, bubble.size))


func bubble_text(id: String) -> String:
	var bubble: PanelContainer = _bubbles.get(id)
	if bubble == null or not bubble.visible:
		return ""
	return (bubble.get_node("Text") as Label).text


func _on_screen(at: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).grow(-UiKit.px(4)).has_point(at)


func _keep_on_screen(spot: Vector2, box: Vector2) -> Vector2:
	var margin := UiKit.px(6)
	return Vector2(clampf(spot.x, margin, size.x - box.x - margin), clampf(spot.y, margin, size.y - box.y - margin))


## True when a floating tag or bubble would slide under one of the HUD panels.
func _covered(box: Rect2) -> bool:
	var panels: Array[Control] = [_today, _pager, _buttons, get_node("Badge") as Control, get_node("Clock") as Control]
	for panel in panels:
		if panel.visible and panel.get_global_rect().grow(UiKit.px(4)).intersects(box):
			return true
	return false


## While a conversation is on screen the walking HUD steps aside.
func set_talking(talking: bool) -> void:
	_talking = talking
	for quiet: Control in [_hint, _buttons, get_node("Badge") as Control, get_node("Clock") as Control]:
		quiet.visible = not talking
	_pager.visible = not talking and not _pager_text.text.is_empty()
	_today.visible = not talking and _tasks.get_child_count() > 1
	if talking:
		for tag: Control in _tags.values():
			tag.visible = false
		for bubble: Control in _bubbles.values():
			bubble.visible = false


func is_talking() -> bool:
	return _talking


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time / 0.4, 0.0, 1.0)
		if _toast_time <= 0.0:
			_toast.visible = false
