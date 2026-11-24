class_name LyricsBanner
extends Control
## The words of a song as it plays (stage 26), like a music video's
## captions: a strip along the bottom of the screen with who's singing, the
## line being sung, the next one fainter, and how far through the song it
## is. It never takes a tap except on its own Stop button, so the doctor
## can keep walking while the night nurses sing.

signal stop_pressed

var player: SongPlayer
## Where the corner buttons are (a Callable giving a Rect2 on screen), so
## the words sit beside them, in the hint's place, rather than over them.
var buttons_rect := Callable()
var _strip: PanelContainer
var _title: Label
var _now: Label
var _next: Label
var _bar: ColorRect
var _bar_back: ColorRect
var _shown_line := -2
var _shown_phase := ""


func _init(for_player: SongPlayer = null) -> void:
	player = for_player


func _ready() -> void:
	name = "LyricsBanner"
	theme = UiKit.theme()
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip = UiKit.panel(Color(8 / 255.0, 20 / 255.0, 24 / 255.0, 0.9), 16, Vector2(16, 10))
	_strip.name = "Strip"
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _strip.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color = Color(UiKit.AMBER, 0.5)
	style.set_border_width_all(2)
	add_child(_strip)
	var row := UiKit.hbox(12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.add_child(row)
	var words := UiKit.vbox(2)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	_title = UiKit.label("", 11, UiKit.AMBER, UiKit.heavy_font())
	_title.name = "SongTitle"
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(_title)
	_now = UiKit.label("", 17, UiKit.TEXT, UiKit.heading_medium_font())
	_now.name = "Now"
	_now.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(_now)
	_next = UiKit.label("", 13, UiKit.TEXT_SOFT)
	_next.name = "Next"
	_next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(_next)
	_bar_back = ColorRect.new()
	_bar_back.color = Color(1, 1, 1, 0.12)
	_bar_back.custom_minimum_size = Vector2(0, UiKit.px(3))
	_bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(_bar_back)
	_bar = ColorRect.new()
	_bar.color = UiKit.AMBER
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_back.add_child(_bar)
	var stop := UiKit.ghost_button("Stop", 40, 14)
	stop.name = "Stop"
	stop.focus_mode = Control.FOCUS_NONE
	stop.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stop.custom_minimum_size.x = UiKit.px(74)
	stop.pressed.connect(func() -> void: stop_pressed.emit())
	UiKit.respond_to_press(stop)
	row.add_child(stop)
	resized.connect(_layout)
	_layout()
	refresh()
	if not GameSettings.current.reduce_motion:
		UiKit.slide_in(_strip, Vector2(0, UiKit.px(40)), 0.25)


## A strip along the bottom, clear of the screen's rounded corners and the
## home bar, no wider than reads comfortably. Beside the corner buttons when
## there's room (bottom left, where the hint sits), otherwise just above them.
func _layout() -> void:
	if _strip == null:
		return
	var view := get_viewport_rect().size if is_inside_tree() else size
	var room := UiKit.safe_insets()
	var most := UiKit.px(620) * GameSettings.current.text_scale()
	var buttons: Rect2 = buttons_rect.call() if buttons_rect.is_valid() else Rect2()
	var left := room.x + UiKit.px(12)
	var bottom := -maxf(room.z, UiKit.px(12)) - UiKit.px(8)
	var wide := minf(most, view.x - room.x * 2.0 - UiKit.px(40))
	var beside := buttons.has_area() and buttons.position.x - UiKit.px(10) - left >= UiKit.px(360)
	_strip.anchor_top = 1.0
	_strip.anchor_bottom = 1.0
	if beside:
		wide = minf(most, buttons.position.x - UiKit.px(10) - left)
		_strip.anchor_left = 0.0
		_strip.anchor_right = 0.0
		_strip.offset_left = left
		_strip.offset_right = left + wide
		bottom = buttons.end.y - view.y
	else:
		_strip.anchor_left = 0.5
		_strip.anchor_right = 0.5
		_strip.offset_left = -wide / 2.0
		_strip.offset_right = wide / 2.0
		if buttons.has_area():
			bottom = buttons.position.y - view.y - UiKit.px(8)
	_strip.offset_bottom = bottom
	_strip.offset_top = _strip.offset_bottom - _strip.get_combined_minimum_size().y
	_strip.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _process(_delta: float) -> void:
	refresh()


## Shows where the song is.
func refresh() -> void:
	if player == null or _now == null:
		return
	if player.line != _shown_line or player.phase != _shown_phase:
		_shown_line = player.line
		_shown_phase = player.phase
		var entry := Songs.song(player.song_id)
		_title.text = ("%s  ·  %s  ·  %s" % [str(Songs.station().get("name", "Radio")), str(entry.get("title", "")),
			str(entry.get("by", ""))]).to_upper()
		if player.phase == "request":
			_now.text = player.request_text()
			_next.text = ""
		else:
			_now.text = player.line_text() if player.line >= 0 else "..."
			_next.text = player.next_text()
		_next.visible = not _next.text.is_empty()
		_layout.call_deferred()
	if _bar_back != null and _bar != null:
		_bar.size = Vector2(_bar_back.size.x * player.progress(), _bar_back.size.y)
