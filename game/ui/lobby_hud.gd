class_name LobbyHud
extends Control
## Everything drawn over the hospital while walking around: the doctor's
## badge and XP, the clock, the pager, today's tasks, name tags and speech
## bubbles over people, and the Phone / Career / Team / Menu buttons.
## Conversations themselves are drawn by ConversationUi on top.
##
## The doctor's phone (PhonePanel) comes up from here: the Phone button, a
## swipe up from the bottom of the screen, or P on a Mac. New messages show
## as a banner above the buttons and a number on the Phone button, and calls
## ring here, but only while the doctor is walking about, never in the
## middle of a conversation or an operation.

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
## Where the tags of a crowd went this round (start_crowd), so a crowded
## tag can make way instead of landing on top of another.
var _crowd: Array[Rect2] = []
var _bubbles := {}
var _talking := false
var _menu: PanelContainer
var _settings: SettingsPanel
var _career: CareerMap
var _career_badge: Label
var _today_dot: Panel
var _toast: PanelContainer
var _toast_label: Label
var _toast_time := 0.0
var _portrait_rig: AvatarRig
var _shown_level := -1
var _xp_tween: Tween

## Today's casualty results for the phone's Lab app (the ward sets it).
var live_lab: Callable = Callable()
## Today's pages, oldest first: [{"stamp", "text"}].
var pager_log: Array = []
var _phone: PhonePanel
var _phone_badge: Label
var _banner: PanelContainer
var _banner_name: Label
var _banner_text: Label
var _banner_answer: Control
var _banner_time := 0.0
var _banner_chat := ""
## Messages up to here have been announced.
var _announced := -1
var _summary_due := true
## How long the doctor has been free to look at a phone, in seconds.
var _free_for := 0.0
var _phone_check := 0.0
## The call ringing now ({} when none) and how long it has rung.
var ringing := {}
var _ring_time := 0.0
var _ring_next := 0.0
## Where a swipe up from the bottom began (or -1).
var _swipe_from := Vector2(-1, -1)

## Seconds the doctor must have been free before a call rings.
const CALL_AFTER_FREE := 6.0
## How long a call rings before it counts as missed, and how often it rings.
const RING_FOR := 16.0
const RING_EVERY := 2.2
const BANNER_TIME := 4.5


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
	_build_banner()
	UiKit.keep_children_off_edges(self)
	refresh_profile()
	_announced = PhoneBook.now(profile)


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
	for entry: Array in [["Phone", "phone"], ["Career", "map"], ["Team", "team"], ["Menu", "menu"]]:
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
		if entry[0] == "Phone":
			# Messages not yet read and calls missed.
			_phone_badge = _corner_badge(UiKit.AMBER)
			_phone_badge.name = "Badge"
			button.add_child(_phone_badge)
		if entry[0] == "Career":
			# How many letters are waiting to be read.
			_career_badge = _corner_badge(UiKit.AMBER)
			_career_badge.name = "Badge"
			button.add_child(_career_badge)
			# A small mint dot while today's 60-second case or the week's
			# mystery guess is waiting.
			_today_dot = Panel.new()
			_today_dot.name = "TodayDot"
			_today_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var mint := StyleBoxFlat.new()
			mint.bg_color = UiKit.MINT
			mint.set_corner_radius_all(int(UiKit.px(6)))
			_today_dot.add_theme_stylebox_override("panel", mint)
			_today_dot.offset_left = -UiKit.px(3)
			_today_dot.offset_right = UiKit.px(9)
			_today_dot.offset_top = -UiKit.px(3)
			_today_dot.offset_bottom = UiKit.px(9)
			button.add_child(_today_dot)
	refresh_letters()


## A small round count in a button's corner.
func _corner_badge(colour: Color) -> Label:
	var badge := UiKit.label("", 11, UiKit.INK, UiKit.heavy_font())
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot := StyleBoxFlat.new()
	dot.bg_color = colour
	dot.set_corner_radius_all(int(UiKit.px(10)))
	badge.add_theme_stylebox_override("normal", dot)
	badge.custom_minimum_size = Vector2(UiKit.px(20), UiKit.px(20))
	badge.anchor_left = 1.0
	badge.anchor_right = 1.0
	badge.offset_left = -UiKit.px(16)
	badge.offset_right = UiKit.px(4)
	badge.offset_top = -UiKit.px(4)
	badge.offset_bottom = UiKit.px(16)
	badge.visible = false
	return badge


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
	if which == "Phone":
		toggle_phone()
		return
	close_phone()
	if which == "Menu":
		_menu.visible = true
		return
	if which == "Career":
		open_career()
		return
	var unlocks := {"Team": "You'll meet the whole team on your first ward round."}
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
	return _menu.visible or _settings != null or _career != null


## Opens the career map (the road, the race, the letters) over the game.
func open_career(first_page: String = "map") -> CareerMap:
	if _career != null:
		return _career
	_career = CareerMap.new(profile, first_page)
	_career.closed.connect(func() -> void:
		_career = null
		refresh_letters()
		# A letter read is worth keeping even if the game closes next.
		menu_choice.emit("save"))
	add_child(_career)
	return _career


func career_map() -> CareerMap:
	return _career


## The Career button's badge: letters waiting to be read.
func refresh_letters() -> void:
	if _career_badge == null:
		return
	var unread := Letters.unread_count(profile)
	_career_badge.text = str(unread)
	_career_badge.visible = unread > 0
	if _today_dot != null:
		_today_dot.visible = profile != null and CareerMap.today_waiting(profile)


func career_badge() -> String:
	return _career_badge.text if _career_badge != null and _career_badge.visible else ""


## Whether the mint dot for today's case or the week's guess shows.
func today_dot() -> bool:
	return _today_dot != null and _today_dot.visible


## Shows a short message under the clock for a few seconds.
func toast(text: String) -> void:
	_toast_label.text = text
	if not _toast.visible:
		_toast.visible = true
		UiKit.pop_in(_toast, 0.22)
	_toast_time = 3.0


func refresh_profile() -> void:
	refresh_letters()
	refresh_phone_badge()
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
	_pager_text.text = text
	_pager.visible = _pager_shown()
	if not text.is_empty() and (pager_log.is_empty() or str(pager_log[pager_log.size() - 1]["text"]) != text):
		pager_log.append({"stamp": PhoneBook.now(profile), "text": text})


func pager_text() -> String:
	return _pager_text.text


## The pager shows while there's a page, except in a conversation or while
## the phone is up (its Pager app has every page of the day).
func _pager_shown() -> bool:
	return not _pager_text.text.is_empty() and not _talking and not phone_open()


## The line at the bottom left that says how to move around.
func set_hint(text: String) -> void:
	(_hint.get_node("Text") as Label).text = text


func hint_text() -> String:
	return (_hint.get_node("Text") as Label).text


## tasks: an array of [text, done], or [text, done, stars] to show a best
## result as three stars (-1 for none yet), or [text, done, stars, colour]
## for a dot of that colour (casualty's triage). The first unfinished task
## is highlighted. No tasks hides the card.
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
		var coloured := task.size() > 3 and task[3] is Color
		var icon := UiIcon.make("check" if done else ("dot" if current or coloured else "circle"), 15,
			task[3] if coloured else (UiKit.MINT if done or current else UiKit.TEXT_LABEL))
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


## Starts a new round of crowded tags (see set_tag's crowded).
func start_crowd() -> void:
	_crowd.clear()


## Counts a tag that is showing as part of this round's crowd, so crowded
## tags set after it keep off it.
func crowd_note(id: String) -> void:
	var tag: Control = _tags.get(id)
	if tag != null and tag.visible:
		_crowd.append(Rect2(tag.position, tag.size))


## Keeps this round's crowded tags off a part of the screen (the doctor).
func crowd_block(box: Rect2) -> void:
	_crowd.append(box)


## Name tags float over people. tags: name -> [text, screen position, visible].
## A crowded tag (people sitting close together) that would land on one set
## earlier this round moves up a row, or stays hidden if that is taken too:
## the first set win, so set the most important first.
func set_tag(id: String, text: String, at: Vector2, shown: bool, highlight: bool = false, pin: bool = false,
		crowded: bool = false) -> void:
	var tag: PanelContainer = _tags.get(id)
	if tag == null:
		tag = UiKit.panel(Color.WHITE, 14, Vector2(10, 0))
		tag.custom_minimum_size = Vector2(0, UiKit.px(28))
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row := UiKit.hbox(6)
		row.name = "Row"
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_child(row)
		var arrow := UiIcon.make("arrow", 14, UiKit.INK)
		arrow.name = "Arrow"
		arrow.visible = false
		arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(arrow)
		var label := UiKit.label(text, 13, UiKit.INK, UiKit.heavy_font())
		label.name = "Text"
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)
		add_child(tag)
		move_child(tag, 0)
		_tags[id] = tag
	var text_label := tag.get_node("Row/Text") as Label
	text_label.text = text
	var arrow := tag.get_node("Row/Arrow") as UiIcon
	var style := tag.get_theme_stylebox("panel") as StyleBoxFlat
	style.bg_color = UiKit.AMBER if highlight else Color(1, 1, 1, 0.94)
	arrow.visible = false
	tag.reset_size()
	tag.position = _keep_on_screen(at - Vector2(tag.size.x / 2.0, tag.size.y), tag.size)
	var fits := _on_screen(at) and not _covered(Rect2(tag.position, tag.size))
	if pin and shown and not _talking and not fits:
		# Off screen or under a panel: the tag waits at the nearest clear
		# edge, with an arrow pointing the way, and still takes a tap.
		arrow.visible = true
		tag.reset_size()
		tag.position = _pin_spot(at, tag.size)
		arrow.angle = (at - (tag.position + tag.size / 2.0)).angle()
		tag.visible = true
		return
	tag.visible = shown and not _talking and fits
	if crowded and tag.visible:
		var lift := tag.size.y + UiKit.px(4)
		for step in 2:
			var box := Rect2(tag.position - Vector2(0, lift * step), tag.size)
			if not _crowd.any(func(taken: Rect2) -> bool: return taken.grow(UiKit.px(3)).intersects(box)):
				if step > 0 and (_covered(box) or not _on_screen(box.position)):
					break
				tag.position = box.position
				_crowd.append(box)
				return
		tag.visible = false


## True when a screen point is on a tag that is showing (a little extra
## round it, for a thumb).
func tag_hit(id: String, at: Vector2) -> bool:
	var tag: Control = _tags.get(id)
	return tag != null and tag.visible and Rect2(tag.position, tag.size).grow(UiKit.px(12)).has_point(at)


## True when a tag is held at the edge of the screen, pointing the way.
func tag_pinned(id: String) -> bool:
	var tag: Control = _tags.get(id)
	return tag != null and tag.visible and (tag.get_node("Row/Arrow") as Control).visible


## Where a pinned tag goes: as close to the point as the screen and the
## panels allow, inside the safe area.
func _pin_spot(at: Vector2, box: Vector2) -> Vector2:
	var room := UiKit.safe_insets()
	var margin := UiKit.px(14)
	var inner := Rect2(Vector2(room.x + margin, margin), size - Vector2(room.x + room.y + margin * 2.0, margin * 2.0 + room.z))
	var centre := size / 2.0
	var start := Vector2(clampf(at.x, inner.position.x + box.x / 2.0, inner.end.x - box.x / 2.0),
		clampf(at.y, inner.position.y + box.y / 2.0, inner.end.y - box.y / 2.0))
	for step in 11:
		var spot := start.lerp(centre, step * 0.1)
		var corner := spot - box / 2.0
		if not _covered(Rect2(corner, box)):
			return corner
	return centre - box / 2.0


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
	if not hint_text().is_empty():
		panels.append(_hint)
	if _banner != null:
		panels.append(_banner)
	for panel in panels:
		if panel.visible and panel.get_global_rect().grow(UiKit.px(4)).intersects(box):
			return true
	return false


## While a conversation is on screen the walking HUD steps aside.
func set_talking(talking: bool) -> void:
	_talking = talking
	if talking:
		# Phones go away for conversations; a call ringing now goes unanswered.
		close_phone()
		_hide_banner()
		if not ringing.is_empty():
			_miss_call()
	for quiet: Control in [_hint, _buttons, get_node("Badge") as Control, get_node("Clock") as Control]:
		quiet.visible = not talking
	_pager.visible = _pager_shown()
	_today.visible = not talking and _tasks.get_child_count() > 1
	if talking:
		for tag: Control in _tags.values():
			tag.visible = false
		for bubble: Control in _bubbles.values():
			bubble.visible = false


func is_talking() -> bool:
	return _talking


func _process(delta: float) -> void:
	_tick_phone(delta)
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time / 0.4, 0.0, 1.0)
		if _toast_time <= 0.0:
			_toast.visible = false


# --- The phone -----------------------------------------------------------------------

func _build_banner() -> void:
	_banner = UiKit.panel(Color(7 / 255.0, 32 / 255.0, 37 / 255.0, 0.96), 16, Vector2(10, 8))
	_banner.name = "PhoneBanner"
	var style := _banner.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color = Color(UiKit.MINT, 0.5)
	style.set_border_width_all(int(UiKit.px(1.5)))
	_banner.custom_minimum_size = Vector2(UiKit.px(250), 0)
	_corner(_banner, false, false, 12, 84)
	_banner.visible = false
	_banner.gui_input.connect(_on_banner_input)
	add_child(_banner)
	var row := UiKit.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(row)
	var icon := UiIcon.make("chat", 18, UiKit.MINT)
	icon.name = "Icon"
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var words := UiKit.vbox(1)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	_banner_name = UiKit.label("", 11, UiKit.MINT, UiKit.heavy_font())
	words.add_child(_banner_name)
	_banner_text = UiKit.label("", 13, UiKit.TEXT)
	_banner_text.custom_minimum_size = Vector2(UiKit.px(190), 0)
	_banner_text.clip_text = true
	_banner_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(_banner_text)
	var buttons := UiKit.hbox(6)
	buttons.name = "CallButtons"
	buttons.visible = false
	row.add_child(buttons)
	for entry: Array in [["Decline", "hangup", UiKit.CORAL], ["Answer", "call", Color("#3BB273")]]:
		var button := Button.new()
		button.name = entry[0]
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(UiKit.px(40), UiKit.px(40))
		button.add_theme_stylebox_override("normal", UiKit.box(entry[2], 20))
		button.add_theme_stylebox_override("hover", UiKit.box(entry[2], 20))
		button.add_theme_stylebox_override("pressed", UiKit.box((entry[2] as Color).darkened(0.2), 20))
		var glyph := UiIcon.make(entry[1], 18, Color.WHITE)
		UiKit.fill(glyph)
		glyph.offset_left = UiKit.px(11)
		glyph.offset_top = UiKit.px(11)
		glyph.offset_right = -UiKit.px(11)
		glyph.offset_bottom = -UiKit.px(11)
		button.add_child(glyph)
		button.pressed.connect(answer_ringing if entry[0] == "Answer" else decline_ringing)
		UiKit.respond_to_press(button)
		buttons.add_child(button)
	_banner_answer = buttons


## True when the doctor could look at a phone: walking, nothing else open.
func phone_allowed() -> bool:
	return not _talking and not menu_open() and is_visible_in_tree()


func phone_open() -> bool:
	return _phone != null and is_instance_valid(_phone)


func phone_panel() -> PhonePanel:
	return _phone if phone_open() else null


## Brings the phone up (at an app, or a chat), if the doctor is free.
func open_phone(app: String = "", chat: String = "") -> PhonePanel:
	if phone_open():
		return _phone
	if not phone_allowed():
		return null
	_hide_banner()
	_phone = PhonePanel.new(profile)
	_pager.visible = false
	_phone.pager_log = pager_log
	_phone.live_lab = live_lab
	_phone.closed.connect(func() -> void:
		_phone = null
		_pager.visible = _pager_shown()
		refresh_phone_badge()
		# What was read and answered is worth keeping.
		menu_choice.emit("save"))
	_phone.call_ended.connect(_on_call_ended)
	add_child(_phone)
	if not ringing.is_empty():
		# Picked up while it rings: the call is what the phone shows.
		_phone.ring(ringing)
	elif not chat.is_empty():
		_phone.open_chat(chat)
	elif not app.is_empty():
		_phone.open_app(app)
	return _phone


func close_phone() -> void:
	if phone_open():
		_phone.close()
	_phone = null


func toggle_phone() -> void:
	if phone_open():
		if ringing.is_empty():
			close_phone()
		return
	if open_phone() == null and _talking:
		toast("Not now. Hands busy.")


## The number on the Phone button.
func refresh_phone_badge() -> void:
	if _phone_badge == null:
		return
	var count := PhoneBook.badge(profile)
	_phone_badge.text = str(count) if count < 100 else "99+"
	_phone_badge.visible = count > 0


func phone_badge() -> String:
	return _phone_badge.text if _phone_badge != null and _phone_badge.visible else ""


func _tick_phone(delta: float) -> void:
	if phone_allowed() and not phone_open():
		_free_for += delta
	else:
		_free_for = 0.0 if not phone_allowed() else _free_for
	if _banner_time > 0.0 and ringing.is_empty():
		_banner_time -= delta
		_banner.modulate.a = clampf(_banner_time / 0.4, 0.0, 1.0)
		if _banner_time <= 0.0:
			_hide_banner()
	if not ringing.is_empty():
		_ring_time += delta
		_ring_next -= delta
		if _ring_next <= 0.0:
			_ring_next = RING_EVERY
			Sfx.play(self, "ring", -6.0)
		if _ring_time >= RING_FOR:
			_miss_call()
	_phone_check -= delta
	if _phone_check > 0.0:
		return
	_phone_check = 1.0
	refresh_phone_badge()
	if not phone_allowed():
		return
	_announce()
	if ringing.is_empty() and _free_for >= CALL_AFTER_FREE and not (phone_open() and _phone.page == "call"):
		var due := PhoneBook.call_due(profile)
		if not due.is_empty():
			ring(due)


## A banner for what arrived since the last look (or, once, for what came
## overnight), unless the phone is already open.
func _announce() -> void:
	var latest := {}
	var count := 0
	var waiting := 0
	var since := _announced
	_announced = PhoneBook.now(profile)
	for item: Dictionary in PhoneBook.arrived(profile, "chat"):
		if item["from"] == "you":
			continue
		if int(item["stamp"]) > since:
			latest = item
			count += 1
	if phone_open() or not ringing.is_empty():
		return
	if count > 0:
		_summary_due = false
		var more := " (+%d more)" % (count - 1) if count > 1 else ""
		_show_banner(PhoneBook.contact_name(str(latest["chat"]), latest) + more, _banner_line(latest), str(latest["chat"]))
		Sfx.play(self, "message", -10.0)
		return
	if _summary_due and _free_for >= 2.0:
		_summary_due = false
		waiting = PhoneBook.app_unread(profile, "chats")
		if waiting > 0:
			var names: Array[String] = []
			for entry: Dictionary in PhoneBook.chats(profile):
				if int(entry["unread"]) > 0 and names.size() < 2:
					names.append(PhoneBook.short_name(str(entry["chat"]), entry["last"]))
			_show_banner("%d new message%s" % [waiting, "" if waiting == 1 else "s"], ", ".join(names), "")


func _banner_line(item: Dictionary) -> String:
	var text := str(item["text"])
	if item["deleted"]:
		text = "This message was deleted"
	elif text.is_empty():
		text = "Photo"
	if PhoneBook.is_group(str(item["chat"])):
		text = PhoneBook.short_name(str(item["from"])) + ": " + text
	return text


func _show_banner(title: String, text: String, chat: String, call: bool = false) -> void:
	_banner_name.text = title
	_banner_text.text = text
	_banner_chat = chat
	_banner_answer.visible = call
	var icon := _banner.find_child("Icon", true, false) as UiIcon
	if icon != null:
		icon.kind = "call" if call else "chat"
		icon.queue_redraw()
	_banner.modulate.a = 1.0
	if not _banner.visible:
		_banner.visible = true
		UiKit.pop_in(_banner, 0.2)
	_banner_time = BANNER_TIME


func _hide_banner() -> void:
	if _banner != null:
		_banner.visible = false
	_banner_time = 0.0


func banner_text() -> String:
	return "%s · %s" % [_banner_name.text, _banner_text.text] if _banner != null and _banner.visible else ""


func _on_banner_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or button.pressed or not ringing.is_empty():
		return
	var chat := _banner_chat
	_hide_banner()
	open_phone("chats" if chat.is_empty() else "", chat)


## A call rings: on the open phone, or as a banner with Answer and Decline.
func ring(item: Dictionary) -> void:
	ringing = item
	_ring_time = 0.0
	_ring_next = 0.0
	if phone_open():
		_phone.ring(item)
		_hide_banner()
	else:
		_show_banner(PhoneBook.contact_name(str(item["from"]), item), "Calling...", "", true)


func answer_ringing() -> void:
	if ringing.is_empty():
		return
	var item := ringing
	_hide_banner()
	var phone := open_phone()
	if phone == null:
		return
	if phone.call_phase != "ringing":
		phone.ring(item)
	phone.answer_call()
	ringing = {}


func decline_ringing() -> void:
	if ringing.is_empty():
		return
	if phone_open() and _phone.call_phase == "ringing":
		_phone.decline_call()
	else:
		PhoneBook.record_call(profile, str(ringing["id"]), "d")
	ringing = {}
	_hide_banner()
	refresh_phone_badge()


## Nobody picked up: it goes in the log as missed, with any message left.
func _miss_call() -> void:
	if ringing.is_empty():
		return
	PhoneBook.record_call(profile, str(ringing["id"]), "m")
	ringing = {}
	if phone_open():
		_phone.stop_ringing()
	_hide_banner()
	refresh_phone_badge()


func _on_call_ended(_call_id: String) -> void:
	ringing = {}
	_free_for = 0.0
	refresh_phone_badge()


## P brings the phone up or puts it away; Esc puts it away, or pauses.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed(&"phone"):
		toggle_phone()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel"):
		if phone_open():
			if ringing.is_empty():
				close_phone()
		elif _menu.visible:
			_on_menu_choice("resume")
		elif _settings == null and _career == null and not _talking:
			_menu.visible = true
		else:
			return
		get_viewport().set_input_as_handled()


## A swipe up from the bottom of the screen brings the phone up.
func _input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		var band := size.y - UiKit.px(70)
		var on_buttons := _buttons.get_global_rect().grow(UiKit.px(6)).has_point(button.position)
		if button.pressed and button.position.y >= band and not on_buttons and phone_allowed() and not phone_open():
			_swipe_from = button.position
		else:
			_swipe_from = Vector2(-1, -1)
		return
	var motion := event as InputEventMouseMotion
	if motion == null or _swipe_from.x < 0.0:
		return
	var moved := motion.position - _swipe_from
	if moved.y <= -UiKit.px(40) and absf(moved.x) < absf(moved.y):
		_swipe_from = Vector2(-1, -1)
		if open_phone() != null:
			get_viewport().set_input_as_handled()
