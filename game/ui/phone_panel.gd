class_name PhonePanel
extends Control
## The doctor's phone, held up over the game (stage 23): Chats, Calls, Lab
## results, the Pager, the Feed and Photos, with the hospital's time in the
## corner. It doesn't stop the clock: patients keep waiting while the
## doctor scrolls. A tap outside it, the bar at the bottom (from the home
## screen), the Phone button or P on a Mac puts it away.
##
## Everything it shows comes from PhoneBook; it only draws and passes on
## the doctor's taps (answers in a chat, picking up a call). It is quiet
## work for the device: a page is built once when it opens, and looked at
## again only when something new has arrived.

signal closed
## A call is over (answered, declined or hung up): its id.
signal call_ended(call_id: String)

const APPS := [["chats", "Chats", "chat"], ["calls", "Calls", "call"], ["lab", "Lab results", "flask"],
	["pager", "Pager", "pager"], ["feed", "Feed", "feed"], ["photos", "Photos", "photo"], ["maps", "Maps", "map"],
	["radio", "Radio", "radio"]]
## The hospital on the Maps app: [id, name, what it's like, x, y, w, h] on a
## 100 x 100 plan, ground floor and the basement strip along the bottom.
const PLACES := [
	["ward", "Ward 4", "Six beds, one desk, and the wall of names by it.", 4, 6, 40, 30],
	["casualty", "Casualty", "Four cubicles and a waiting area that never empties.", 52, 6, 44, 30],
	["theatre", "Theatre", "Scrub sink on the left. Dr. Sethi's music on the right.", 52, 42, 44, 22],
	["skills", "Skills lab", "Mannequins that never complain. Enjoy it while it lasts.", 4, 42, 22, 22],
	["seminar", "Seminar room", "Slides, chai, and someone's laptop that won't connect.", 28, 42, 20, 22],
	["lobby", "Lobby", "Reception, the coffee machine and every rumour in the building.", 4, 68, 44, 14],
	["canteen", "Canteen", "Dal of the day. Same as yesterday's dal.", 52, 68, 44, 14],
	["morgue", "Morgue", "Basement. Service lift. Nobody takes the service lift for fun.", 4, 86, 92, 10],
]
const BODY_COLOUR := Color("#060F11")
const SCREEN_COLOUR := Color("#0B2328")
const ROW_COLOUR := Color(1, 1, 1, 0.05)
const THEIRS := Color("#173F48")
const MINE := Color("#8FE3D2")
## The phone's size in design pixels (it shrinks to fit a short screen).
const WIDTH := 214.0
const HEIGHT := 410.0
## How often an open page looks for anything new, in seconds.
const CHECK_EVERY := 1.0
## A line in a call that can't be spoken waits about this long a letter.
const CALL_LETTER := 0.055
const CALL_GAP := 0.35

var profile: PlayerProfile
## Today's pages, kept by the HUD: [{"stamp", "text"}].
var pager_log: Array = []
## Today's results from casualty, as PhoneBook lab items (set by the ward).
var live_lab: Callable = Callable()
## Where the doctor is and where the story wants them: {"here": a PLACES
## id or "", "next": the task list's open row or ""}.
var live_place: Callable = Callable()
var page := "home"
var page_arg := ""

var body: PanelContainer
var _shade: ColorRect
var _holder: Control
var _time_label: Label
var _battery_label: Label
var _battery_fill: ColorRect
var _signature := ""
var _check_in := 0.0
var _history: Array = []
## Seconds left to keep an open chat scrolled to its newest message (or to
## _pin_to, the first one not yet read).
var _pin_bottom := 0.0
var _pin_to: Control

# A call in progress.
var call_item := {}
var call_phase := ""
var _call_lines: Array = []
var _call_line := -1
var _call_wait := 0.0
var _call_seconds := 0.0
var _call_pick := -1
## How much of the line being said the voice has reached (SpokenLine needs
## it to know when a voice that never reports the end is done).
var _call_shown := 0.0
var _call_caption: Label
var _call_timer: Label
var _call_choices: Container
var _voice := SpokenLine.new()
## True while this phone is asking for fewer frames (FrameBudget).
var _calm := false
## The radio's song (Riverside FM), playing while the phone is out.
var radio: SongPlayer
var _radio_now: Label
var _radio_next: Label
var _radio_bar: ColorRect
var _radio_back: ColorRect
var _radio_line := -2
var _radio_phase := ""
## True between a press on the shade and its release.
var _shade_down := false


func _init(for_profile: PlayerProfile = null) -> void:
	profile = for_profile if for_profile != null else PlayerProfile.new()


func _enter_tree() -> void:
	if not _calm:
		_calm = true
		FrameBudget.calm(true)


func _exit_tree() -> void:
	_let_go()


## Back to full speed, and quiet (once, however the phone goes away).
func _let_go() -> void:
	_voice.stop()
	if radio != null:
		radio.stop()
	if _calm:
		_calm = false
		FrameBudget.calm(false)


func _ready() -> void:
	name = "Phone"
	theme = UiKit.theme()
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade = ColorRect.new()
	_shade.name = "Shade"
	_shade.color = Color(0.0, 0.03, 0.04, 0.32)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_shade.gui_input.connect(_on_shade_input)
	add_child(UiKit.fill(_shade))

	body = PanelContainer.new()
	body.name = "Body"
	var bezel := UiKit.box(BODY_COLOUR, 30, Color("#2C4A50"), 1.5)
	for side: int in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		bezel.set_content_margin(side, UiKit.px(6))
	body.add_theme_stylebox_override("panel", bezel)
	body.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(body)
	var screen := PanelContainer.new()
	screen.name = "Screen"
	screen.add_theme_stylebox_override("panel", UiKit.box(SCREEN_COLOUR, 24))
	screen.clip_contents = true
	body.add_child(screen)
	var column := UiKit.vbox(0)
	screen.add_child(column)
	column.add_child(_status_bar())
	_holder = Control.new()
	_holder.name = "Page"
	_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_holder.clip_contents = true
	column.add_child(_holder)
	column.add_child(_home_bar())
	resized.connect(_layout)
	_layout()
	_show(page, page_arg)
	if is_inside_tree() and not GameSettings.current.reduce_motion:
		UiKit.slide_in(body, Vector2(0, UiKit.px(60)), 0.24)


## Where the phone sits: right of centre, so the clock at the top and the
## day's tasks on the left still show, as tall as the screen allows.
func _layout() -> void:
	if body == null:
		return
	var room := UiKit.safe_insets()
	var height := minf(UiKit.px(HEIGHT), size.y - UiKit.px(20) - room.y - room.z)
	var width := minf(UiKit.px(WIDTH), height * 0.54)
	body.size = Vector2(width, height)
	var centre := size.x * 0.68
	body.position = Vector2(clampf(centre - width / 2.0, room.x + UiKit.px(10), size.x - width - room.x - UiKit.px(10)),
		room.y + (size.y - room.y - room.z - height) / 2.0)


func _status_bar() -> Control:
	var bar := UiKit.hbox(4)
	bar.name = "Status"
	bar.custom_minimum_size = Vector2(0, UiKit.px(20))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(UiKit.px(14)))
	margin.add_theme_constant_override("margin_right", int(UiKit.px(12)))
	margin.add_theme_constant_override("margin_top", int(UiKit.px(5)))
	margin.add_child(bar)
	_time_label = UiKit.label("", 10, UiKit.TEXT, UiKit.heavy_font())
	_time_label.name = "Time"
	bar.add_child(_time_label)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(gap)
	bar.add_child(UiKit.label("Ward 4G", 8, UiKit.TEXT_SOFT, UiKit.heavy_font()))
	_battery_label = UiKit.label("", 8, UiKit.TEXT_SOFT, UiKit.heavy_font())
	bar.add_child(_battery_label)
	var battery := Panel.new()
	battery.custom_minimum_size = Vector2(UiKit.px(16), UiKit.px(8))
	battery.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	battery.add_theme_stylebox_override("panel", UiKit.box(Color.TRANSPARENT, 2, UiKit.TEXT_SOFT, 1))
	bar.add_child(battery)
	_battery_fill = ColorRect.new()
	_battery_fill.position = Vector2(UiKit.px(1.5), UiKit.px(1.5))
	_battery_fill.size = Vector2(UiKit.px(13), UiKit.px(5))
	battery.add_child(_battery_fill)
	_refresh_status()
	return margin


## A shift drains it: full when the day (or the night) began, a worry by
## its end.
func battery() -> int:
	var start := PlayerProfile.DAY_START
	if int(profile.morning.get("day", -1)) == profile.day:
		start = int(profile.morning.get("minutes", start))
	return clampi(100 - (profile.minutes - start) / 9, 4, 100)


func _refresh_status() -> void:
	if _time_label == null:
		return
	_time_label.text = profile.clock_text()
	var big := _holder.find_child("BigTime", true, false) as Label if _holder != null else null
	if big != null:
		big.text = profile.clock_text()
	var level := battery()
	_battery_label.text = "%d%%" % level
	_battery_fill.size.x = UiKit.px(13) * level / 100.0
	_battery_fill.color = UiKit.CORAL if level <= 20 else UiKit.MINT


func _home_bar() -> Control:
	var bar := Button.new()
	bar.name = "Home"
	bar.focus_mode = Control.FOCUS_NONE
	bar.custom_minimum_size = Vector2(0, UiKit.px(22))
	var clear := StyleBoxEmpty.new()
	for state in ["normal", "hover", "focus", "pressed", "hover_pressed"]:
		bar.add_theme_stylebox_override(state, clear)
	var pill := Panel.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_theme_stylebox_override("panel", UiKit.box(Color(1, 1, 1, 0.6), 3))
	pill.anchor_left = 0.5
	pill.anchor_right = 0.5
	pill.anchor_top = 0.5
	pill.anchor_bottom = 0.5
	pill.offset_left = -UiKit.px(30)
	pill.offset_right = UiKit.px(30)
	pill.offset_top = -UiKit.px(2)
	pill.offset_bottom = UiKit.px(2)
	bar.add_child(pill)
	bar.pressed.connect(home_pressed)
	return bar


# --- Moving around ------------------------------------------------------------------

## The bar at the bottom: home, or away from the home screen.
func home_pressed() -> void:
	if page == "call" and call_phase in ["ringing", "talking", "choosing", "after"]:
		return
	if page == "home":
		close()
	else:
		_history.clear()
		_show("home")


func back() -> void:
	if page == "call" and call_phase in ["ringing", "talking", "choosing", "after"]:
		return
	if _history.is_empty():
		_show("home")
		return
	var last: Array = _history.pop_back()
	_show(str(last[0]), str(last[1]), false)


func open_app(app: String) -> void:
	_go(app)


func open_chat(chat: String) -> void:
	_go("chat", chat)


func open_photo(photo_id: String) -> void:
	_go("photo", photo_id)


func _go(to: String, arg: String = "") -> void:
	_history.append([page, page_arg])
	_show(to, arg, false)


func close() -> void:
	if is_queued_for_deletion():
		return
	if page == "call" and call_phase in ["talking", "choosing", "after"]:
		end_call()
	_let_go()
	# Gone at once: hidden, it takes no more taps, and the game is back to
	# full speed before the node itself is freed at the end of the frame.
	visible = false
	set_process(false)
	closed.emit()
	queue_free()


## A tap outside the phone puts it away. Only a whole tap counts (the
## press too), so lifting the finger that swiped the phone up doesn't.
func _on_shade_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.pressed:
		_shade_down = true
		return
	var tapped := _shade_down
	_shade_down = false
	if tapped and not (page == "call" and call_phase == "ringing"):
		close()


func _show(to: String, arg: String = "", clear_history: bool = true) -> void:
	if clear_history and to == "home":
		_history.clear()
	page = to
	page_arg = arg
	if _holder == null:
		return
	for child in _holder.get_children():
		_holder.remove_child(child)
		child.queue_free()
	var built: Control
	match to:
		"chats":
			built = _chats_page()
		"chat":
			built = _chat_page(arg)
		"calls":
			built = _calls_page()
			PhoneBook.mark_seen(profile, "calls")
		"call":
			built = _call_page()
		"lab":
			built = _lab_page()
			PhoneBook.mark_seen(profile, "lab")
		"pager":
			built = _pager_page()
		"feed":
			built = _feed_page()
			PhoneBook.mark_seen(profile, "feed")
		"photos":
			built = _photos_page()
			PhoneBook.mark_seen(profile, "photos")
		"photo":
			built = _photo_page(arg)
		"maps":
			built = _maps_page()
		"radio":
			built = _radio_page()
		_:
			page = "home"
			built = _home_page()
	_holder.add_child(UiKit.fill(built))
	_signature = _page_signature()
	_refresh_status()


## What the page shows, in a word: when it changes, the page is built again.
func _page_signature() -> String:
	match page:
		"chat":
			return "%d|%s" % [PhoneBook.thread(profile, page_arg).size(), str(PhoneBook.pending_reply(profile, page_arg).get("id", ""))]
		"call", "photo":
			return page
		"pager":
			return str(pager_log.size())
		"lab":
			return str(_lab_items().size())
		"radio":
			return "%s|%s|%s" % [radio.playing(), radio.song_id, str(radio.request.get("text", ""))] if radio != null else ""
	return "%d|%d" % [PhoneBook.arrived(profile).size(), PhoneBook.badge(profile)]


func _process(delta: float) -> void:
	if page == "call":
		_tick_call(delta)
	elif page == "radio":
		_tick_radio()
	if _pin_bottom > 0.0:
		_pin_bottom -= delta
		_pin_scroll()
	_check_in -= delta
	if _check_in > 0.0:
		return
	_check_in = CHECK_EVERY
	_refresh_status()
	if page != "call" and _page_signature() != _signature:
		var scroll := _scroll_position()
		_show(page, page_arg, false)
		if page != "chat":
			_set_scroll(scroll)


func _pin_scroll() -> void:
	var scroll := _holder.find_child("Scroll", true, false) as ScrollContainer
	if scroll == null or scroll.get_child_count() == 0:
		return
	if _pin_to != null and is_instance_valid(_pin_to) and _pin_to.is_inside_tree():
		# The first unread message at the top, with a line of what came before.
		var content := scroll.get_child(0) as Control
		scroll.scroll_vertical = maxi(0, int(_pin_to.global_position.y - content.global_position.y - UiKit.px(26)))
	else:
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _scroll_position() -> int:
	var scroll := _holder.find_child("Scroll", true, false) as ScrollContainer
	return scroll.scroll_vertical if scroll != null else 0


func _set_scroll(value: int) -> void:
	var scroll := _holder.find_child("Scroll", true, false) as ScrollContainer
	if scroll != null:
		scroll.set_deferred("scroll_vertical", value)


# --- Pieces ------------------------------------------------------------------------

## A page: a header (with a back arrow) and a scrolling column under it.
func _page(title: String, subtitle: String = "", contact_id: String = "", item: Dictionary = {}) -> Array:
	var column := UiKit.vbox(0)
	var header := UiKit.hbox(6)
	header.name = "Header"
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, int(UiKit.px(8)))
	margin.add_theme_constant_override("margin_top", int(UiKit.px(4)))
	margin.add_theme_constant_override("margin_bottom", int(UiKit.px(6)))
	margin.add_child(header)
	column.add_child(margin)
	var back_button := Button.new()
	back_button.name = "Back"
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.custom_minimum_size = Vector2(UiKit.px(32), UiKit.px(32))
	for state in ["normal", "hover", "focus"]:
		back_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	back_button.add_theme_stylebox_override("pressed", UiKit.box(Color(1, 1, 1, 0.1), 16))
	var arrow := UiIcon.make("back", 16, UiKit.MINT)
	UiKit.fill(arrow)
	for side: int in [SIDE_LEFT, SIDE_TOP]:
		arrow.set_offset(side, UiKit.px(6))
	for side: int in [SIDE_RIGHT, SIDE_BOTTOM]:
		arrow.set_offset(side, -UiKit.px(6))
	back_button.add_child(arrow)
	back_button.pressed.connect(back)
	header.add_child(back_button)
	if not contact_id.is_empty():
		header.add_child(_avatar(contact_id, 26, item))
	var titles := UiKit.vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(titles)
	var title_label := UiKit.label(title, 13, UiKit.TEXT, UiKit.heading_font())
	title_label.name = "Title"
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.clip_text = true
	titles.add_child(title_label)
	if not subtitle.is_empty():
		var sub := UiKit.label(subtitle, 8.5, UiKit.TEXT_SOFT)
		sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		sub.clip_text = true
		titles.add_child(sub)
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.08)
	line.custom_minimum_size = Vector2(0, 1)
	column.add_child(line)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	column.add_child(scroll)
	var inner := MarginContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_right"]:
		inner.add_theme_constant_override(side, int(UiKit.px(8)))
	inner.add_theme_constant_override("margin_top", int(UiKit.px(6)))
	inner.add_theme_constant_override("margin_bottom", int(UiKit.px(8)))
	scroll.add_child(inner)
	var list := UiKit.vbox(5)
	list.name = "List"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(list)
	return [column, list]


## The width text can use inside a page, in canvas units.
func _inner_width() -> float:
	return (body.size.x if body != null and body.size.x > 0.0 else UiKit.px(WIDTH)) - UiKit.px(12 + 16)


## A round picture with someone's initials in their colour.
func _avatar(contact_id: String, diameter: float, item: Dictionary = {}) -> Control:
	var holder := Panel.new()
	holder.custom_minimum_size = Vector2(UiKit.px(diameter), UiKit.px(diameter))
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var found := PhoneBook.contact(contact_id, item)
	var colour := Color(str(found.get("colour", "#B8D6D2")))
	holder.add_theme_stylebox_override("panel", UiKit.box(colour, diameter / 2.0))
	var letters := UiKit.label(PhoneBook.initials(contact_id, item), diameter * 0.38, UiKit.INK, UiKit.heavy_font())
	letters.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letters.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiKit.fill(letters)
	holder.add_child(letters)
	return holder


## A one-line label that ends in "..." rather than pushing the page wider.
func _clipped(label: Label) -> Label:
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _wrapped(text: String, text_size: float, colour: Color, width: float, which: Font = null) -> Label:
	var made := UiKit.label(text, text_size, colour, which)
	made.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	made.custom_minimum_size = Vector2(width, 0)
	return made


## Makes a row answer a tap (a press and release in the same place, so a
## drag that scrolls the list doesn't count).
func _tappable(control: Control, action: Callable) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in control.find_children("*", "Control", true, false):
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.gui_input.connect(func(event: InputEvent) -> void:
		var button := event as InputEventMouseButton
		if button == null or button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			control.set_meta(&"down", button.global_position)
		elif control.has_meta(&"down"):
			var start: Vector2 = control.get_meta(&"down")
			control.remove_meta(&"down")
			if start.distance_to(button.global_position) < UiKit.px(8):
				Sfx.ui("tap", -16.0)
				action.call())


func _row(name_text: String) -> PanelContainer:
	var row := PanelContainer.new()
	row.name = name_text
	row.add_theme_stylebox_override("panel", UiKit.box(ROW_COLOUR, 12, Color.TRANSPARENT, 0, Vector2(8, 6)))
	return row


func _count_dot(count: int, colour: Color = UiKit.MINT) -> Control:
	var dot := UiKit.label(str(count) if count < 100 else "99+", 8.5, UiKit.INK, UiKit.heavy_font())
	dot.name = "Unread"
	dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var style := UiKit.box(colour, 8, Color.TRANSPARENT, 0, Vector2(4, 0))
	dot.add_theme_stylebox_override("normal", style)
	dot.custom_minimum_size = Vector2(UiKit.px(16), UiKit.px(16))
	dot.size_flags_horizontal = Control.SIZE_SHRINK_END
	return dot


func _empty(text: String) -> Label:
	var said := _wrapped(text, 10, UiKit.TEXT_SOFT, _inner_width())
	said.name = "Empty"
	said.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return said


func _lab_items() -> Array:
	var live: Array = live_lab.call() if live_lab.is_valid() else []
	return PhoneBook.lab(profile, live)


# --- Home ----------------------------------------------------------------------------

func _home_page() -> Control:
	var page_root := Control.new()
	var wallpaper := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color("#127C80"))
	gradient.set_color(1, Color("#0B2328"))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.2, 0)
	texture.fill_to = Vector2(0.6, 1)
	texture.width = 32
	texture.height = 64
	wallpaper.texture = texture
	wallpaper.stretch_mode = TextureRect.STRETCH_SCALE
	wallpaper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wallpaper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page_root.add_child(UiKit.fill(wallpaper))
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, int(UiKit.px(12)))
	margin.add_theme_constant_override("margin_top", int(UiKit.px(4)))
	page_root.add_child(UiKit.fill(margin))
	var column := UiKit.vbox(5)
	margin.add_child(column)
	var big := UiKit.label(profile.clock_text(), 27, UiKit.TEXT, UiKit.heading_font())
	big.name = "BigTime"
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(big)
	var day := UiKit.label("Day %d" % profile.day, 10, UiKit.TEXT_SOFT, UiKit.heavy_font())
	day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(day)
	var grid := UiKit.grid(3, 8)
	grid.name = "Apps"
	grid.add_theme_constant_override("v_separation", int(UiKit.px(10)))
	column.add_child(grid)
	var live: Array = live_lab.call() if live_lab.is_valid() else []
	for app: Array in APPS:
		grid.add_child(_app_button(str(app[0]), str(app[1]), str(app[2]), live))
	var latest := _latest_messages(_latest_room())
	if not latest.is_empty():
		var recent := UiKit.vbox(5)
		recent.name = "Recent"
		column.add_child(recent)
		recent.add_child(UiKit.label("LATEST", 8, UiKit.TEXT_KICKER, UiKit.heavy_font()))
		for item: Dictionary in latest:
			recent.add_child(_notification_row(item))
	return page_root


func _app_button(app: String, title: String, icon: String, live: Array) -> Control:
	var cell := UiKit.vbox(3)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var button := Button.new()
	button.name = "App_" + app
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(UiKit.px(44), UiKit.px(44))
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var colour: Color = {"chats": Color("#2E9E6B"), "calls": Color("#3B8F5A"), "lab": Color("#5B6FD8"),
		"pager": Color("#C98A1E"), "feed": Color("#C2457A"), "photos": Color("#E07A3C"), "maps": Color("#3E7CB1"),
		"radio": Color("#B0482F")}.get(app, UiKit.TEAL)
	button.add_theme_stylebox_override("normal", UiKit.box(colour, 12))
	button.add_theme_stylebox_override("hover", UiKit.box(colour, 12))
	button.add_theme_stylebox_override("focus", UiKit.box(colour, 12))
	button.add_theme_stylebox_override("pressed", UiKit.box(colour.darkened(0.25), 12))
	var glyph := UiIcon.make(icon, 22, Color.WHITE)
	glyph.anchor_left = 0.5
	glyph.anchor_top = 0.5
	glyph.anchor_right = 0.5
	glyph.anchor_bottom = 0.5
	glyph.offset_left = -UiKit.px(11)
	glyph.offset_top = -UiKit.px(11)
	glyph.offset_right = UiKit.px(11)
	glyph.offset_bottom = UiKit.px(11)
	button.add_child(glyph)
	var waiting := 0 if app == "pager" else PhoneBook.app_unread(profile, app, live)
	if waiting > 0:
		var dot := _count_dot(waiting, UiKit.CORAL if app == "calls" else UiKit.AMBER)
		dot.anchor_left = 1.0
		dot.anchor_right = 1.0
		dot.offset_left = -UiKit.px(12)
		dot.offset_right = UiKit.px(6)
		dot.offset_top = -UiKit.px(5)
		dot.offset_bottom = UiKit.px(11)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(dot)
	button.pressed.connect(open_app.bind(app))
	UiKit.respond_to_press(button)
	cell.add_child(button)
	var caption := UiKit.label(title, 8.5, UiKit.TEXT, UiKit.heavy_font())
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(caption)
	return cell


## How many of the latest messages fit under the apps (2 on a phone held
## sideways, 3 on a tablet): the phone's height in design pixels, less
## what's above them, over a row's height.
func _latest_room() -> int:
	var tall := body.size.y if body != null and body.size.y > 0.0 else UiKit.px(HEIGHT)
	return clampi(int((tall / UiKit.px(1) - 255.0) / 41.0), 1, 3)


## The newest messages from other people, newest first.
func _latest_messages(count: int) -> Array:
	var found: Array = []
	var arrived := PhoneBook.arrived(profile, "chat")
	for index in range(arrived.size() - 1, -1, -1):
		var item: Dictionary = arrived[index]
		if item["from"] == "you" or item["deleted"]:
			continue
		found.append(item)
		if found.size() >= count:
			break
	return found


func _notification_row(item: Dictionary) -> Control:
	var row := _row("Note_" + str(item["id"]))
	row.add_theme_stylebox_override("panel", UiKit.box(Color(0, 0, 0, 0.28), 12, Color.TRANSPARENT, 0, Vector2(8, 5)))
	var line := UiKit.hbox(6)
	row.add_child(line)
	line.add_child(_avatar(str(item["chat"]), 20, item))
	var words := UiKit.vbox(0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(words)
	var top := UiKit.hbox(4)
	words.add_child(top)
	var who := UiKit.label(_sender_line(item), 9, UiKit.TEXT, UiKit.heavy_font())
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.clip_text = true
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(who)
	top.add_child(UiKit.label(PhoneBook.when_text(profile, int(item["stamp"])), 8, UiKit.TEXT_SOFT))
	var preview := UiKit.label(_preview(item), 9, UiKit.TEXT_SOFT)
	preview.clip_text = true
	preview.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(preview)
	_tappable(row, open_chat.bind(str(item["chat"])))
	return row


## "Varun Khanna" or, in a group, "City Med '20 · Sana".
func _sender_line(item: Dictionary) -> String:
	var chat := str(item["chat"])
	var name := PhoneBook.contact_name(chat, item)
	if PhoneBook.is_group(chat) and item["from"] != "you":
		return "%s · %s" % [name, PhoneBook.short_name(str(item["from"]))]
	return name


func _preview(item: Dictionary) -> String:
	if item["deleted"]:
		return "This message was deleted"
	var text := str(item["text"])
	if text.is_empty() and not str(item["photo"]).is_empty():
		return "Photo" + (": " + str(item["caption"]) if not str(item["caption"]).is_empty() else "")
	if item["from"] == "you":
		return "You: " + text
	return text


# --- Chats ---------------------------------------------------------------------------

func _chats_page() -> Control:
	var made := _page("Chats")
	var list: VBoxContainer = made[1]
	var all := PhoneBook.chats(profile)
	if all.is_empty():
		list.add_child(_empty("No chats yet. Give it a day. Your mother will find you."))
	for entry: Dictionary in all:
		list.add_child(_chat_row(entry))
	return made[0]


func _chat_row(entry: Dictionary) -> Control:
	var last: Dictionary = entry["last"]
	var chat := str(entry["chat"])
	var row := _row("Chat_" + chat)
	var line := UiKit.hbox(7)
	row.add_child(line)
	line.add_child(_avatar(chat, 30, last))
	var words := UiKit.vbox(1)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(words)
	var name := UiKit.label(str(entry["name"]), 10.5, UiKit.TEXT, UiKit.heavy_font())
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(name)
	var preview_text := _preview(last)
	if PhoneBook.is_group(chat) and last["from"] != "you":
		preview_text = PhoneBook.short_name(str(last["from"])) + ": " + preview_text
	var preview := UiKit.label(preview_text, 9, UiKit.TEXT_SOFT)
	preview.clip_text = true
	preview.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(preview)
	var side := UiKit.vbox(2)
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_child(side)
	var unread := int(entry["unread"])
	side.add_child(UiKit.label(PhoneBook.when_text(profile, int(last["stamp"])), 8, UiKit.MINT if unread > 0 else UiKit.TEXT_SOFT))
	if unread > 0:
		side.add_child(_count_dot(unread))
	_tappable(row, open_chat.bind(chat))
	return row


func _chat_page(chat: String) -> Control:
	var messages := PhoneBook.thread(profile, chat)
	var last: Dictionary = messages[messages.size() - 1] if not messages.is_empty() else {}
	var found := PhoneBook.contact(chat, last)
	var made := _page(PhoneBook.contact_name(chat, last), str(found.get("about", "")), chat, last)
	var column: VBoxContainer = made[0]
	var list: VBoxContainer = made[1]
	var read_up_to := PhoneBook.seen_stamp(profile, "c:" + chat)
	PhoneBook.mark_seen(profile, "c:" + chat)
	_pin_to = null
	var shown_day := -1
	for item: Dictionary in messages:
		var day := int(item["day"])
		if day != shown_day:
			shown_day = day
			list.add_child(_day_chip(day))
		var bubble := _bubble(item, PhoneBook.is_group(chat))
		list.add_child(bubble)
		if _pin_to == null and item["from"] != "you" and int(item["stamp"]) > read_up_to:
			_pin_to = bubble
	var footer := MarginContainer.new()
	footer.name = "Footer"
	for side in ["margin_left", "margin_right"]:
		footer.add_theme_constant_override(side, int(UiKit.px(8)))
	footer.add_theme_constant_override("margin_bottom", int(UiKit.px(4)))
	footer.add_theme_constant_override("margin_top", int(UiKit.px(4)))
	column.add_child(footer)
	var pending := PhoneBook.pending_reply(profile, chat)
	if pending.is_empty():
		var quiet := UiKit.panel(Color(1, 1, 1, 0.06), 14, Vector2(10, 5))
		quiet.name = "NoReply"
		footer.add_child(quiet)
		quiet.add_child(UiKit.label("Nothing to say back. Yet.", 9, Color(UiKit.TEXT_SOFT, 0.7)))
	else:
		var choices := UiKit.vbox(4)
		choices.name = "Replies"
		footer.add_child(choices)
		var options: Array = pending["reply"]
		for index in options.size():
			var chip := Button.new()
			chip.name = "Reply%d" % index
			chip.text = PhoneBook.fill(profile, str(options[index]))
			chip.focus_mode = Control.FOCUS_NONE
			chip.alignment = HORIZONTAL_ALIGNMENT_LEFT
			chip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			chip.add_theme_stylebox_override("normal", UiKit.box(Color(UiKit.MINT, 0.16), 12, Color(UiKit.MINT, 0.6), 1, Vector2(9, 5)))
			chip.add_theme_stylebox_override("hover", UiKit.box(Color(UiKit.MINT, 0.16), 12, Color(UiKit.MINT, 0.6), 1, Vector2(9, 5)))
			chip.add_theme_stylebox_override("pressed", UiKit.box(Color(UiKit.MINT, 0.4), 12, UiKit.MINT, 1, Vector2(9, 5)))
			chip.add_theme_color_override("font_color", UiKit.TEXT)
			chip.add_theme_color_override("font_pressed_color", UiKit.TEXT)
			chip.add_theme_color_override("font_hover_color", UiKit.TEXT)
			UiKit.set_text_size(chip, 9.5)
			chip.pressed.connect(choose_reply.bind(str(pending["id"]), index))
			UiKit.respond_to_press(chip)
			choices.add_child(chip)
	# Start at the newest message, as a chat app does (held there while the
	# bubbles settle into their sizes).
	_pin_bottom = 0.4
	return column


## The doctor answers with one of the offered replies.
func choose_reply(item_id: String, pick: int) -> void:
	if PhoneBook.answer(profile, item_id, pick):
		Sfx.ui("tap", -10.0)
		_show(page, page_arg, false)


## Which reply chips the open chat offers (for tests): their texts.
func reply_texts() -> PackedStringArray:
	var found := PackedStringArray()
	var choices := _holder.find_child("Replies", true, false)
	if choices != null:
		for chip in choices.get_children():
			found.append((chip as Button).text)
	return found


func _day_chip(day: int) -> Control:
	var centre := CenterContainer.new()
	var chip := UiKit.panel(Color(0, 0, 0, 0.3), 8, Vector2(8, 2))
	chip.add_child(UiKit.label("Today" if day == profile.day else ("Yesterday" if day == profile.day - 1 else "Day %d" % day), 8,
		UiKit.TEXT_SOFT, UiKit.heavy_font()))
	centre.add_child(chip)
	return centre


func _bubble(item: Dictionary, group: bool) -> Control:
	var mine := str(item["from"]) == "you"
	var line := UiKit.hbox(0)
	line.name = "Msg_" + str(item["id"]).replace("#", "_")
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if mine:
		line.add_child(gap)
	var max_width := _inner_width() * 0.82
	var bubble := PanelContainer.new()
	bubble.name = "Bubble"
	bubble.add_theme_stylebox_override("panel", UiKit.box(MINE if mine else THEIRS, 11, Color.TRANSPARENT, 0, Vector2(7, 4)))
	line.add_child(bubble)
	if not mine:
		line.add_child(gap)
	var inside := UiKit.vbox(2)
	bubble.add_child(inside)
	var ink := UiKit.INK if mine else UiKit.TEXT
	if group and not mine:
		var sender := UiKit.label(PhoneBook.short_name(str(item["from"]), item), 8.5,
			Color(str(PhoneBook.contact(str(item["from"])).get("colour", "#8FE3D2"))), UiKit.heavy_font())
		inside.add_child(sender)
	if item["deleted"]:
		var gone := UiKit.label("This message was deleted", 10, Color(UiKit.TEXT_SOFT, 0.8))
		gone.name = "Deleted"
		inside.add_child(gone)
	else:
		if not str(item["photo"]).is_empty():
			var picture_width := max_width - UiKit.px(14)
			var picture := PhotoCard.make(str(item["photo"]), Vector2(picture_width, picture_width * 0.7), str(item["id"]).hash())
			picture.name = "Photo"
			inside.add_child(picture)
			if not str(item["caption"]).is_empty():
				inside.add_child(_wrapped(str(item["caption"]), 9, Color(ink, 0.8), picture_width))
		var text := str(item["text"])
		if not text.is_empty():
			var font_size := UiKit.scaled_text(10.5)
			var natural := UiKit.body_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var width := minf(natural + 2.0, max_width - UiKit.px(14))
			if not str(item["photo"]).is_empty():
				width = max_width - UiKit.px(14)
			var said := _wrapped(text, 10.5, ink, width)
			said.name = "Text"
			inside.add_child(said)
	var time := UiKit.label(PhoneBook.clock(int(item["stamp"])), 7.5, Color(ink, 0.55))
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	inside.add_child(time)
	return line


# --- Calls ---------------------------------------------------------------------------

func _calls_page() -> Control:
	var made := _page("Calls")
	var list: VBoxContainer = made[1]
	var log := PhoneBook.call_log(profile)
	if log.is_empty():
		list.add_child(_empty("No calls yet. Everyone texts now. Except your mother."))
	for item: Dictionary in log:
		var row := _row("Call_" + str(item["id"]))
		var line := UiKit.hbox(7)
		row.add_child(line)
		line.add_child(_avatar(str(item["from"]), 28, item))
		var words := UiKit.vbox(1)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(words)
		var missed := str(item["state"]) == "missed"
		words.add_child(_clipped(UiKit.label(PhoneBook.contact_name(str(item["from"]), item), 10.5,
			UiKit.CORAL if missed else UiKit.TEXT, UiKit.heavy_font())))
		var state_text: String = {"answered": "Incoming", "declined": "Declined", "missed": "Missed"}.get(str(item["state"]), "Call")
		words.add_child(UiKit.label("%s · %s" % [state_text, PhoneBook.when_text(profile, int(item["stamp"]))], 8.5, UiKit.TEXT_SOFT))
		line.add_child(UiIcon.make("missed" if missed else "call", 14, UiKit.CORAL if missed else UiKit.MINT))
		list.add_child(row)
	return made[0]


## A call ringing on the phone: the doctor can answer or decline.
func ring(item: Dictionary) -> void:
	if radio != null:
		radio.stop()
	call_item = item
	call_phase = "ringing"
	_call_seconds = 0.0
	_call_pick = -1
	_show("call", str(item["id"]), false)


## Picks up the ringing call; its lines start.
func answer_call() -> void:
	if call_phase != "ringing":
		return
	call_phase = "talking"
	_call_lines = (call_item.get("lines", []) as Array).duplicate()
	_call_line = -1
	_call_wait = 0.3
	_show("call", str(call_item["id"]), false)


## The call stopped ringing before anyone answered (the HUD counts it as missed).
func stop_ringing() -> void:
	if call_phase == "ringing":
		call_phase = "ended"
		call_item = {}
		_show("home")


func decline_call() -> void:
	if call_phase != "ringing":
		return
	PhoneBook.record_call(profile, str(call_item["id"]), "d")
	_finish_call()


## Hangs up a call in progress.
func end_call() -> void:
	if call_phase in ["talking", "choosing", "after"]:
		PhoneBook.record_call(profile, str(call_item["id"]), "a", _call_pick)
		_finish_call()


func _finish_call() -> void:
	_voice.stop()
	var id := str(call_item.get("id", ""))
	call_phase = "ended"
	call_item = {}
	call_ended.emit(id)
	if is_inside_tree():
		_history.clear()
		_show("home")


## The doctor's reply in a call (the doctor is never heard, only shown).
func choose_call_reply(pick: int) -> void:
	if call_phase != "choosing":
		return
	var options: Array = call_item.get("reply", [])
	if pick < 0 or pick >= options.size():
		return
	_call_pick = pick
	call_phase = "after"
	var after: Array = call_item.get("after", [])
	_call_lines = [{"say": "you", "text": PhoneBook.fill(profile, str(options[pick]))}]
	if pick < after.size():
		_call_lines.append_array(after[pick])
	_call_line = -1
	_call_wait = 0.1
	_show("call", str(call_item["id"]), false)


func _call_page() -> Control:
	var column := UiKit.vbox(10)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var caller := str(call_item.get("from", ""))
	var top := Control.new()
	top.custom_minimum_size = Vector2(0, UiKit.px(16))
	column.add_child(top)
	var picture := CenterContainer.new()
	picture.add_child(_avatar(caller, 64, call_item))
	column.add_child(picture)
	var name := UiKit.label(PhoneBook.contact_name(caller, call_item), 16, UiKit.TEXT, UiKit.heading_font())
	name.name = "Caller"
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name)
	_call_timer = UiKit.label("Incoming call" if call_phase == "ringing" else "00:00", 10, UiKit.TEXT_SOFT, UiKit.heavy_font())
	_call_timer.name = "CallTimer"
	_call_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_call_timer)
	var caption_box := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		caption_box.add_theme_constant_override(side, int(UiKit.px(12)))
	caption_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(caption_box)
	_call_caption = _wrapped("", 10.5, UiKit.TEXT, _inner_width() - UiKit.px(8))
	_call_caption.name = "Caption"
	_call_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_box.add_child(_call_caption)
	# A tap on what's being said moves the call on.
	_tappable(caption_box, skip_call_line)
	_call_choices = UiKit.vbox(4)
	_call_choices.name = "CallReplies"
	var choices_box := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		choices_box.add_theme_constant_override(side, int(UiKit.px(10)))
	choices_box.add_child(_call_choices)
	column.add_child(choices_box)
	var buttons := UiKit.hbox(28)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	if call_phase == "ringing":
		buttons.add_child(_round_button("Decline", "hangup", UiKit.CORAL, decline_call))
		buttons.add_child(_round_button("Answer", "call", Color("#3BB273"), answer_call))
	else:
		buttons.add_child(_round_button("EndCall", "hangup", UiKit.CORAL, end_call))
	var bottom := Control.new()
	bottom.custom_minimum_size = Vector2(0, UiKit.px(10))
	column.add_child(bottom)
	if call_phase == "choosing":
		_show_call_choices()
	return column


func _round_button(button_name: String, icon: String, colour: Color, action: Callable) -> Control:
	var cell := UiKit.vbox(3)
	var button := Button.new()
	button.name = button_name
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(UiKit.px(44), UiKit.px(44))
	button.add_theme_stylebox_override("normal", UiKit.box(colour, 22))
	button.add_theme_stylebox_override("hover", UiKit.box(colour, 22))
	button.add_theme_stylebox_override("pressed", UiKit.box(colour.darkened(0.2), 22))
	var glyph := UiIcon.make(icon, 20, Color.WHITE)
	UiKit.fill(glyph)
	glyph.offset_left = UiKit.px(12)
	glyph.offset_top = UiKit.px(12)
	glyph.offset_right = -UiKit.px(12)
	glyph.offset_bottom = -UiKit.px(12)
	button.add_child(glyph)
	button.pressed.connect(action)
	UiKit.respond_to_press(button)
	cell.add_child(button)
	var caption := UiKit.label({"Decline": "Decline", "Answer": "Answer", "EndCall": "End"}.get(button_name, ""), 8.5, UiKit.TEXT_SOFT,
		UiKit.heavy_font())
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(caption)
	return cell


func _show_call_choices() -> void:
	if _call_choices == null:
		return
	for child in _call_choices.get_children():
		child.queue_free()
	var options: Array = call_item.get("reply", [])
	for index in options.size():
		var chip := UiKit.chip(PhoneBook.fill(profile, str(options[index])), false, 30)
		chip.name = "CallReply%d" % index
		chip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiKit.set_text_size(chip, 9.5)
		chip.pressed.connect(choose_call_reply.bind(index))
		_call_choices.add_child(chip)


func _tick_call(delta: float) -> void:
	if call_phase in ["talking", "choosing", "after"]:
		_call_seconds += delta
		if _call_timer != null:
			_call_timer.text = "%02d:%02d" % [int(_call_seconds) / 60, int(_call_seconds) % 60]
	if call_phase not in ["talking", "after"]:
		return
	if _voice.speaking:
		_call_shown = _voice.advance(delta, _call_shown)
		if not _voice.is_done():
			return
		_voice.stop()
		_call_wait = CALL_GAP
	_call_wait -= delta
	if _call_wait > 0.0:
		return
	_call_line += 1
	if _call_line >= _call_lines.size():
		if call_phase == "talking" and not (call_item.get("reply", []) as Array).is_empty():
			call_phase = "choosing"
			_show_call_choices()
			return
		# Nothing more to say: the caller hangs up.
		PhoneBook.record_call(profile, str(call_item["id"]), "a", _call_pick)
		_finish_call()
		return
	var line: Dictionary = _call_lines[_call_line]
	var who := str(line.get("say", ""))
	var text := PhoneBook.fill(profile, str(line.get("text", "")))
	var speaker := "You" if who == "you" else PhoneBook.short_name(who)
	if _call_caption != null:
		_call_caption.text = "%s: %s" % [speaker, text]
	_call_shown = 0.0
	if who == "you" or not _voice.start(text, who):
		_call_wait = 0.9 + text.length() * CALL_LETTER


## Moves a call on by a line now (a tap on the caption, and tests).
func skip_call_line() -> void:
	if call_phase in ["talking", "after"]:
		_voice.stop()
		_call_wait = 0.0


func call_caption() -> String:
	return _call_caption.text if _call_caption != null and is_instance_valid(_call_caption) else ""


# --- Lab results, pager, feed and photos ------------------------------------------------

func _lab_page() -> Control:
	var made := _page("Lab results", "Today's reports, as they come back")
	var list: VBoxContainer = made[1]
	var items := _lab_items()
	if items.is_empty():
		list.add_child(_empty("No reports yet. Send a test from casualty and it lands here when it's back."))
	for item: Dictionary in items:
		var row := _row("Lab_" + str(item["id"]))
		var words := UiKit.vbox(2)
		row.add_child(words)
		var top := UiKit.hbox(4)
		words.add_child(top)
		var who := UiKit.label(str(item.get("patient", "")), 9.5, UiKit.TEXT, UiKit.heavy_font())
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.clip_text = true
		who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		top.add_child(who)
		top.add_child(UiKit.label(PhoneBook.when_text(profile, int(item["stamp"])), 8, UiKit.TEXT_SOFT))
		var high := bool(item.get("high", false))
		words.add_child(_wrapped(str(item.get("test", "")) + ("  ·  Look at this" if high else ""), 8.5,
			UiKit.AMBER if high else UiKit.MINT, _inner_width() - UiKit.px(16), UiKit.heavy_font()))
		words.add_child(_wrapped(str(item.get("result", "")), 9.5, UiKit.TEXT_LABEL, _inner_width() - UiKit.px(16)))
		list.add_child(row)
	return made[0]


## Where the doctor is now, and where the story wants them next.
func place_now() -> Dictionary:
	var found: Variant = live_place.call() if live_place.is_valid() else {}
	return found if found is Dictionary else {}


func _maps_page() -> Control:
	var made := _page("Maps", "Riverside City Hospital")
	var list: VBoxContainer = made[1]
	var now := place_now()
	var here := str(now.get("here", ""))
	var plan := HospitalMap.new()
	plan.name = "Plan"
	plan.places = PLACES
	plan.here = here
	plan.custom_minimum_size = Vector2(_inner_width(), _inner_width() * 0.82)
	list.add_child(plan)
	var next := str(now.get("next", ""))
	if not next.is_empty():
		list.add_child(_wrapped("Next: " + next, 9.5, UiKit.AMBER, _inner_width(), UiKit.heavy_font()))
	for place: Array in PLACES:
		var row := _row("Place_" + str(place[0]))
		var words := UiKit.vbox(2)
		row.add_child(words)
		var title := str(place[1]) + ("  ·  You are here" if str(place[0]) == here else "")
		words.add_child(UiKit.label(title, 9.5, UiKit.MINT if str(place[0]) == here else UiKit.TEXT, UiKit.heavy_font()))
		words.add_child(_wrapped(str(place[2]), 8.5, UiKit.TEXT_LABEL, _inner_width() - UiKit.px(16)))
		list.add_child(row)
	return made[0]


# --- Radio ---------------------------------------------------------------------------

func _radio_page() -> Control:
	var station := Songs.station()
	var made := _page("Radio", str(station.get("name", "Radio")))
	var list: VBoxContainer = made[1]
	var width := _inner_width()
	_radio_now = null
	_radio_next = null
	_radio_bar = null
	_radio_back = null
	list.add_child(_wrapped(str(station.get("tagline", "")), 8.5, UiKit.TEXT_SOFT, width))
	var on := radio != null and radio.playing()
	if on:
		list.add_child(_on_air())
	var request := Songs.request_for(profile)
	if not request.is_empty():
		list.add_child(UiKit.label("TODAY'S REQUEST", 8, UiKit.TEXT_KICKER, UiKit.heavy_font()))
		var song := Songs.song(str(request.get("song", "")))
		var row := _radio_row("Request", str(request.get("text", "")).replace("{called}", "Doctor"),
			"Then: " + str(song.get("title", "")), on and radio.request == request)
		_tappable(row, _radio_pressed.bind(str(request.get("song", "")), request))
		list.add_child(row)
	list.add_child(UiKit.label("SONGS", 8, UiKit.TEXT_KICKER, UiKit.heavy_font()))
	for id: String in Songs.ids():
		var entry := Songs.song(id)
		var seconds := int(Songs.length(id))
		var row := _radio_row("Song_" + id, str(entry.get("title", "")),
			"%s  ·  %d:%02d" % [str(entry.get("by", "")), seconds / 60, seconds % 60],
			on and radio.request.is_empty() and radio.song_id == id, true)
		_tappable(row, _radio_pressed.bind(id, {}))
		list.add_child(row)
	return made[0]


## A row with a play button (a stop button while it is the one on air).
func _radio_row(row_name: String, top: String, under: String, playing: bool, heavy: bool = false) -> Control:
	var row := _row(row_name)
	var line := UiKit.hbox(6)
	row.add_child(line)
	var words := UiKit.vbox(2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(words)
	var width := _inner_width() - UiKit.px(16 + 30)
	words.add_child(_wrapped(top, 9.5, UiKit.TEXT if heavy else UiKit.TEXT_LABEL, width, UiKit.heavy_font() if heavy else null))
	words.add_child(_wrapped(under, 8, UiKit.MINT if not heavy else UiKit.TEXT_SOFT, width, UiKit.heavy_font() if not heavy else null))
	var dot := Panel.new()
	dot.name = "Stop" if playing else "Play"
	dot.custom_minimum_size = Vector2(UiKit.px(24), UiKit.px(24))
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.add_theme_stylebox_override("panel", UiKit.box(UiKit.AMBER if playing else Color(1, 1, 1, 0.1), 12))
	var glyph := UiIcon.make("stop" if playing else "play", 12, UiKit.AMBER_TEXT if playing else UiKit.MINT)
	UiKit.fill(glyph)
	for side: int in [SIDE_LEFT, SIDE_TOP]:
		glyph.set_offset(side, UiKit.px(6))
	for side: int in [SIDE_RIGHT, SIDE_BOTTOM]:
		glyph.set_offset(side, -UiKit.px(6))
	dot.add_child(glyph)
	line.add_child(dot)
	return row


## What's on air: the song, the line being sung, the next one and how far
## through it is.
func _on_air() -> Control:
	var card := PanelContainer.new()
	card.name = "OnAir"
	card.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.AMBER, 0.1), 12, Color(UiKit.AMBER, 0.55), 1, Vector2(8, 7)))
	var column := UiKit.vbox(3)
	card.add_child(column)
	var top := UiKit.hbox(6)
	column.add_child(top)
	var kicker := UiKit.label("ON AIR", 8, UiKit.AMBER, UiKit.heavy_font())
	kicker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kicker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(kicker)
	var stop := UiKit.ghost_button("Stop", 24, 9)
	stop.name = "RadioStop"
	stop.focus_mode = Control.FOCUS_NONE
	stop.custom_minimum_size.x = UiKit.px(52)
	stop.pressed.connect(stop_radio)
	UiKit.respond_to_press(stop)
	top.add_child(stop)
	var width := _inner_width() - UiKit.px(16)
	column.add_child(_clipped(UiKit.label(str(Songs.song(radio.song_id).get("title", "")), 10, UiKit.TEXT, UiKit.heavy_font())))
	_radio_now = _wrapped("", 10.5, UiKit.TEXT, width, UiKit.heading_medium_font())
	_radio_now.name = "Now"
	column.add_child(_radio_now)
	_radio_next = _wrapped("", 8.5, UiKit.TEXT_SOFT, width)
	_radio_next.name = "Next"
	column.add_child(_radio_next)
	_radio_back = ColorRect.new()
	_radio_back.color = Color(1, 1, 1, 0.12)
	_radio_back.custom_minimum_size = Vector2(0, UiKit.px(3))
	_radio_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_radio_back)
	_radio_bar = ColorRect.new()
	_radio_bar.color = UiKit.AMBER
	_radio_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radio_back.add_child(_radio_bar)
	_radio_line = -2
	_radio_phase = ""
	_tick_radio()
	return card


## Keeps the words on air in step with the song.
func _tick_radio() -> void:
	if radio == null or _radio_now == null or not is_instance_valid(_radio_now):
		return
	if radio.line != _radio_line or radio.phase != _radio_phase:
		_radio_line = radio.line
		_radio_phase = radio.phase
		if radio.phase == "request":
			_radio_now.text = radio.request_text()
			_radio_next.text = ""
		else:
			_radio_now.text = radio.line_text() if radio.line >= 0 else "..."
			_radio_next.text = radio.next_text()
		_radio_next.visible = not _radio_next.text.is_empty()
	if _radio_back != null and is_instance_valid(_radio_back):
		_radio_bar.size = Vector2(_radio_back.size.x * radio.progress(), _radio_back.size.y)


## Plays a song on the radio (after a request when given), or stops it if
## it is the one on air.
func play_radio(id: String, request: Dictionary = {}) -> bool:
	if call_phase in ["ringing", "talking", "choosing", "after"]:
		return false
	if radio == null:
		radio = SongPlayer.new()
		radio.name = "Radio"
		add_child(radio)
	if not radio.play(id, request):
		return false
	_rebuild_radio()
	return true


func stop_radio() -> void:
	if radio != null:
		radio.stop()
	_rebuild_radio()


func _radio_pressed(id: String, request: Dictionary) -> void:
	if radio != null and radio.playing() and radio.song_id == id and radio.request == request:
		stop_radio()
	else:
		play_radio(id, request)


func _rebuild_radio() -> void:
	if page != "radio":
		return
	var scroll := _scroll_position()
	_show("radio", "", false)
	_set_scroll(scroll)


func _pager_page() -> Control:
	var made := _page("Pager", "Today's pages, newest first")
	var list: VBoxContainer = made[1]
	if pager_log.is_empty():
		list.add_child(_empty("Quiet. Suspiciously quiet."))
	for index in range(pager_log.size() - 1, -1, -1):
		var entry: Dictionary = pager_log[index]
		var row := _row("Page_%d" % index)
		var words := UiKit.vbox(2)
		row.add_child(words)
		words.add_child(UiKit.label(PhoneBook.clock(int(entry.get("stamp", 0))), 8, UiKit.AMBER, UiKit.heavy_font()))
		words.add_child(_wrapped(str(entry.get("text", "")), 9.5, UiKit.TEXT, _inner_width() - UiKit.px(16)))
		list.add_child(row)
	return made[0]


func _feed_page() -> Control:
	var made := _page("Feed")
	var list: VBoxContainer = made[1]
	var posts := PhoneBook.feed(profile)
	if posts.is_empty():
		list.add_child(_empty("Nothing yet. Even Varun hasn't posted, which is worrying."))
	for item: Dictionary in posts:
		var card := _row("Post_" + str(item["id"]))
		var column := UiKit.vbox(5)
		card.add_child(column)
		var head := UiKit.hbox(6)
		column.add_child(head)
		var author := str(item["from"])
		head.add_child(_avatar(author, 22, item))
		var names := UiKit.vbox(0)
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(names)
		var found := PhoneBook.contact(author, item)
		names.add_child(_clipped(UiKit.label(str(found.get("name", author)), 9.5, UiKit.TEXT, UiKit.heavy_font())))
		names.add_child(_clipped(UiKit.label("@%s · %s" % [str(found.get("handle", author)),
			PhoneBook.when_text(profile, int(item["stamp"]))], 8, UiKit.TEXT_SOFT)))
		var width := _inner_width() - UiKit.px(16)
		if not str(item["photo"]).is_empty():
			column.add_child(PhotoCard.make(str(item["photo"]), Vector2(width, width * 0.62), str(item["id"]).hash()))
		column.add_child(_wrapped(str(item["text"]), 9.5, UiKit.TEXT_LABEL, width))
		var likes := UiKit.hbox(4)
		column.add_child(likes)
		likes.add_child(UiIcon.make("heart", 11, UiKit.CORAL))
		likes.add_child(UiKit.label(_likes_text(int(item.get("likes", 0))), 8.5, UiKit.TEXT_SOFT, UiKit.heavy_font()))
		list.add_child(card)
	return made[0]


static func _likes_text(likes: int) -> String:
	if likes >= 10000:
		return "%.1fk likes" % (likes / 1000.0)
	return "%d likes" % likes if likes != 1 else "1 like"


func _photos_page() -> Control:
	var made := _page("Photos", "Saved from your chats, and your own")
	var list: VBoxContainer = made[1]
	var all := PhoneBook.photos(profile)
	if all.is_empty():
		list.add_child(_empty("No photos yet. Someone will send you a good-morning flower soon. Brace yourself."))
		return made[0]
	var grid := UiKit.grid(3, 4)
	grid.name = "Grid"
	list.add_child(grid)
	var side := (_inner_width() - UiKit.px(8)) / 3.0
	for item: Dictionary in all:
		var cell := PanelContainer.new()
		cell.name = "Thumb_" + str(item["id"])
		cell.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		cell.add_child(PhotoCard.make(str(item["photo"]), Vector2(side, side), str(item["id"]).hash()))
		_tappable(cell, open_photo.bind(str(item["id"])))
		grid.add_child(cell)
	return made[0]


func _photo_page(photo_id: String) -> Control:
	var item := {}
	for entry: Dictionary in PhoneBook.photos(profile):
		if entry["id"] == photo_id:
			item = entry
	var from := "You" if item.get("kind", "") == "photo" else PhoneBook.contact_name(str(item.get("from", "")), item)
	var made := _page(from, PhoneBook.when_text(profile, int(item.get("stamp", 0))) if not item.is_empty() else "")
	var list: VBoxContainer = made[1]
	if item.is_empty():
		list.add_child(_empty("That photo has gone. Phones do that."))
		return made[0]
	var width := _inner_width()
	var picture := PhotoCard.make(str(item["photo"]), Vector2(width, width * 0.8), str(item["id"]).hash())
	picture.name = "Big"
	list.add_child(picture)
	var caption := str(item["caption"])
	if caption.is_empty():
		caption = str(item.get("text", ""))
	if not caption.is_empty():
		list.add_child(_wrapped(caption, 10.5, UiKit.TEXT, width))
	return made[0]
