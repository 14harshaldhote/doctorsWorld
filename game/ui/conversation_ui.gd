class_name ConversationUi
extends Control
## Conversations and story subtitles, matching the "Talk" design.
##
## Talk mode (in the hospital): the person's card with their mood and trust
## meter at the top left, the line at the bottom left, and replies on the
## right. Cinema mode (story scenes): subtitles at the bottom centre, a reply
## panel only when the player has to choose, and "hold to skip".
##
## Lines are read aloud by the speaker's voice (see Speech) and appear word
## by word as they are said. Where the device can't speak, they appear
## letter by letter with a murmur instead. Either way each syllable is
## announced through the syllable signal so the speaker's mouth keeps time
## (reading_aloud() says whether the murmur should sound). A tap shows the
## whole line, the next tap moves on. Time only passes through tick(), which
## the owning scene calls, so tests can drive it.

signal advanced
signal chosen(index: int)
signal skip_requested
signal syllable(letter: String)
signal typing_finished

enum Mode { TALK, CINEMA }

const TYPE_SPEED := 46.0
const HOLD_TO_SKIP := 0.9
const DARK := Color(7 / 255.0, 32 / 255.0, 37 / 255.0, 0.92)

var mode := Mode.TALK
## Cinema only: show "hold to skip" and allow it.
var skippable := false
## When set (cinema), lines move on by themselves after this much reading
## time plus a little per letter. Negative waits for a tap.
var auto_advance := -1.0

var _card: PanelContainer
var _card_name: Label
var _card_mood: Label
var _card_role: Label
var _trust_row: HBoxContainer
var _trust_value: Label
var _trust_track: Control
var _trust_fill: ColorRect
var _box: PanelContainer
var _speaker: Label
var _text: Label
var _tap_hint: Label
var _subtitle: PanelContainer
var _sub_speaker: Label
var _sub_text: Label
var _choices: PanelContainer
var _choice_list: VBoxContainer
var _skip: PanelContainer
var _skip_ring: Control

var _line := ""
## The voice reading the line on show.
var _voice := SpokenLine.new()
var _voice_words := 0
## True when the line on show is read aloud (rather than murmured).
var _heard := false
var _typed := 0.0
var _typing := false
var _read_time := 0.0
var _since_syllable := 1.0
var _choosing := false
var _pressing := false
var _held := 0.0
var _shown_trust := -1.0
var _goal_trust := -1.0


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_card()
	_build_box()
	_build_subtitle()
	_build_choices()
	_build_skip()
	UiKit.keep_children_off_edges(self)
	close()


# --- Building ------------------------------------------------------------

func _panel(alpha: float, radius: float, padding: Vector2) -> PanelContainer:
	var made := UiKit.panel(Color(DARK, alpha), radius, padding)
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return made


func _build_card() -> void:
	_card = _panel(0.88, 14, Vector2(14, 10))
	_card.name = "Card"
	_card.position = Vector2(UiKit.px(14), UiKit.px(14))
	_card.custom_minimum_size = Vector2(UiKit.px(220), 0)
	add_child(_card)
	var column := UiKit.vbox(5)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(column)
	var top := UiKit.hbox(8)
	column.add_child(top)
	_card_name = UiKit.label("", 17, UiKit.TEXT, UiKit.heading_font())
	_card_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(_card_name)
	var chip := UiKit.panel(UiKit.AMBER, 10, Vector2(8, 1))
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(chip)
	_card_mood = UiKit.label("", 11, UiKit.AMBER_TEXT, UiKit.heavy_font())
	chip.add_child(_card_mood)
	_card_role = UiKit.label("", 12, UiKit.TEXT_SOFT)
	column.add_child(_card_role)
	var trust_row := UiKit.hbox(6)
	trust_row.name = "TrustRow"
	column.add_child(trust_row)
	_trust_row = trust_row
	var trust_label := UiKit.label("Trust", 12, Color("#DCEDEA"), UiKit.heavy_font())
	trust_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trust_row.add_child(trust_label)
	_trust_value = UiKit.label("", 12, Color("#DCEDEA"), UiKit.heavy_font())
	trust_row.add_child(_trust_value)
	_trust_track = Panel.new()
	_trust_track.name = "TrustTrack"
	_trust_track.custom_minimum_size = Vector2(0, UiKit.px(7))
	_trust_track.add_theme_stylebox_override("panel", UiKit.box(Color(1, 1, 1, 0.18), 4))
	column.add_child(_trust_track)
	_trust_fill = ColorRect.new()
	_trust_fill.color = UiKit.MINT
	_trust_track.add_child(_trust_fill)


func _build_box() -> void:
	_box = _panel(0.92, 14, Vector2(16, 12))
	_box.name = "Line"
	_box.anchor_top = 1.0
	_box.anchor_bottom = 1.0
	_box.anchor_right = 1.0
	_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_box.offset_left = UiKit.px(14)
	# Up to the replies panel, whatever the screen and the notch leave.
	_box.offset_right = -UiKit.px(14 + 326 + 14)
	_box.offset_bottom = -UiKit.px(14)
	add_child(_box)
	var column := UiKit.vbox(4)
	_box.add_child(column)
	var top := UiKit.hbox(8)
	column.add_child(top)
	_speaker = UiKit.label("", 12, UiKit.AMBER, UiKit.heavy_font())
	_speaker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_speaker)
	_tap_hint = UiKit.label("Tap ▸", 11, UiKit.TEXT_KICKER, UiKit.heavy_font())
	top.add_child(_tap_hint)
	_text = UiKit.label("", 16, UiKit.TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(0, UiKit.px(44))
	column.add_child(_text)


func _build_subtitle() -> void:
	_subtitle = UiKit.panel(Color(0, 0, 0, 0.72), 10, Vector2(16, 8))
	_subtitle.name = "Subtitle"
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle.anchor_left = 0.5
	_subtitle.anchor_right = 0.5
	_subtitle.anchor_top = 1.0
	_subtitle.anchor_bottom = 1.0
	_subtitle.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_subtitle.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_subtitle.offset_bottom = -UiKit.px(16)
	add_child(_subtitle)
	var column := UiKit.vbox(2)
	_subtitle.add_child(column)
	_sub_speaker = UiKit.label("", 11, UiKit.AMBER, UiKit.heavy_font())
	_sub_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_sub_speaker)
	_sub_text = UiKit.label("", 15, Color.WHITE)
	_sub_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub_text.custom_minimum_size = Vector2(UiKit.px(520), 0)
	column.add_child(_sub_text)


func _build_choices() -> void:
	_choices = _panel(0.9, 16, Vector2(14, 14))
	_choices.name = "Choices"
	_choices.mouse_filter = Control.MOUSE_FILTER_STOP
	# Top right, as tall as the replies (so it doesn't stand empty on an iPad).
	_choices.anchor_left = 1.0
	_choices.anchor_right = 1.0
	_choices.offset_left = -UiKit.px(14 + 326)
	_choices.offset_right = -UiKit.px(14)
	_choices.offset_top = UiKit.px(14)
	_choices.offset_bottom = UiKit.px(14)
	add_child(_choices)
	# The replies scroll if, with big text, they would run off the screen.
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_choices.add_child(scroll)
	_choice_list = UiKit.vbox(10)
	_choice_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_choice_list)
	var fit := func() -> void:
		var room := UiKit.safe_insets()
		var most := get_viewport_rect().size.y - UiKit.px(28 + 28) - room.y - room.z
		scroll.custom_minimum_size.y = minf(_choice_list.get_combined_minimum_size().y, most)
	_choice_list.minimum_size_changed.connect(fit)
	_choice_list.resized.connect(fit)


func _build_skip() -> void:
	_skip = _panel(0.72, 16, Vector2(12, 6))
	_skip.name = "Skip"
	_skip.anchor_left = 1.0
	_skip.anchor_right = 1.0
	_skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_skip.offset_top = UiKit.px(14)
	_skip.offset_right = -UiKit.px(14)
	_skip.offset_left = -UiKit.px(14)
	add_child(_skip)
	var row := UiKit.hbox(8)
	_skip.add_child(row)
	_skip_ring = Control.new()
	_skip_ring.custom_minimum_size = Vector2(UiKit.px(18), UiKit.px(18))
	_skip_ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_skip_ring.draw.connect(_draw_ring)
	row.add_child(_skip_ring)
	row.add_child(UiKit.label("Hold to skip", 12, UiKit.TEXT, UiKit.heavy_font()))


func _draw_ring() -> void:
	var centre := _skip_ring.size / 2.0
	var radius := minf(centre.x, centre.y) - UiKit.px(1.5)
	_skip_ring.draw_arc(centre, radius, 0, TAU, 32, Color(1, 1, 1, 0.3), UiKit.px(2.5), true)
	if _held > 0.0:
		var portion := clampf(_held / HOLD_TO_SKIP, 0.0, 1.0)
		_skip_ring.draw_arc(centre, radius, -PI / 2, -PI / 2 + TAU * portion, 32, UiKit.AMBER, UiKit.px(2.5), true)


# --- Showing lines and replies --------------------------------------------

## Shows a line. info: role, mood (index), card ({name, role, mood, trust,
## change} for the person whose card shows; empty hides it), voice (the
## cast id whose voice reads the line aloud; empty for no voice).
func show_line(speaker_name: String, text: String, info: Dictionary = {}) -> void:
	visible = true
	_line = text
	_typed = 0.0
	_typing = not text.is_empty()
	_read_time = 0.0
	_since_syllable = 1.0
	_voice_words = 0
	if text.is_empty() or str(info.get("voice", "")).is_empty():
		_voice.stop()
		_heard = false
	else:
		_heard = _voice.start(text, str(info["voice"]))
	var cinema := mode == Mode.CINEMA and not _choices.visible
	_box.visible = not cinema
	_subtitle.visible = cinema
	_speaker.text = speaker_name.to_upper()
	_sub_speaker.text = speaker_name.to_upper()
	_sub_speaker.visible = not speaker_name.is_empty()
	for label: Label in [_text, _sub_text]:
		label.text = text
		label.visible_characters = 0
	_tap_hint.visible = false
	_show_card(info.get("card", {}))
	_skip.visible = mode == Mode.CINEMA and skippable and not _choices.visible


## Shows the replies. card: the card of the person being answered.
func show_choices(options: Array, card: Dictionary = {}) -> void:
	visible = true
	_choosing = true
	_clear_choices()
	_choice_list.add_child(UiKit.kicker("Your reply", 11))
	for index in options.size():
		var option: Dictionary = options[index]
		_choice_list.add_child(_choice_button(index, option))
	var appearing := not _choices.visible
	_choices.visible = true
	if appearing:
		UiKit.pop_in(_choices, 0.24)
	_skip.visible = false
	if mode == Mode.CINEMA and _subtitle.visible:
		# Move the question to the bottom left, clear of the replies.
		_subtitle.visible = false
		_box.visible = true
	if not card.is_empty():
		_show_card(card)


## After a reply: what the player said and what it changed.
func show_result(said: String, effect: String, detail: String = "") -> void:
	_choosing = false
	_clear_choices()
	_choice_list.add_child(UiKit.kicker("You said", 11))
	var words := UiKit.label(said, 14, Color("#DCEDEA"))
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size = Vector2(UiKit.px(290), 0)
	_choice_list.add_child(words)
	if effect.is_empty() and detail.is_empty():
		_choices.visible = mode == Mode.TALK
		return
	var box := UiKit.panel(Color(UiKit.MINT, 0.1), 12, Vector2(12, 10))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice_list.add_child(box)
	var column := UiKit.vbox(8)
	box.add_child(column)
	if not effect.is_empty():
		var effect_label := UiKit.label(effect, 13, UiKit.MINT, UiKit.heavy_font())
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		effect_label.custom_minimum_size = Vector2(UiKit.px(266), 0)
		column.add_child(effect_label)
	if not detail.is_empty():
		var detail_label := UiKit.label("Found: " + detail, 13, Color("#FFE3A3"), UiKit.heavy_font())
		detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_label.custom_minimum_size = Vector2(UiKit.px(266), 0)
		column.add_child(detail_label)
	_choices.visible = true


## Cinema: an empty screen that still listens for taps and "hold to skip".
func open_cinema() -> void:
	visible = true
	hide_line()


## Clears the line (between story beats), keeping taps and skipping alive.
func hide_line() -> void:
	_line = ""
	_typing = false
	_voice.stop()
	_box.visible = false
	_subtitle.visible = false
	if mode == Mode.CINEMA:
		_card.visible = false
		if not _choosing:
			_choices.visible = false
	_skip.visible = mode == Mode.CINEMA and skippable


func hide_choices() -> void:
	_choosing = false
	_choices.visible = false
	_skip.visible = mode == Mode.CINEMA and skippable


func close() -> void:
	visible = false
	_choosing = false
	_typing = false
	_voice.stop()
	_pressing = false
	_held = 0.0


func is_open() -> bool:
	return visible


func is_typing() -> bool:
	return _typing


## True while the line on show is being read aloud by a voice (so the
## speaker's mouth moves without the murmur).
func reading_aloud() -> bool:
	return _heard and not _voice.failed


## The voice for the line on show (for tests).
func voice() -> SpokenLine:
	return _voice


func is_choosing() -> bool:
	return _choosing


func line_text() -> String:
	return _line


## The reply buttons on show (for tests and the screenshot tool).
func choice_buttons() -> Array[Button]:
	var found: Array[Button] = []
	for child in _choice_list.get_children():
		if child is Button:
			found.append(child)
	return found


func finish_typing() -> void:
	if not _typing:
		return
	_typed = _line.length()
	_reveal()
	_typing = false
	_tap_hint.visible = mode == Mode.TALK
	typing_finished.emit()


func _choice_button(index: int, option: Dictionary) -> Button:
	var button := Button.new()
	button.name = "Reply%d" % (index + 1)
	button.focus_mode = Control.FOCUS_NONE
	var normal := UiKit.box(Color(1, 1, 1, 0.04), 12, Color(UiKit.MINT, 0.45), 2, Vector2(12, 10))
	var pressed := UiKit.box(Color(UiKit.MINT, 0.18), 12, UiKit.MINT, 2, Vector2(12, 10))
	for state in ["normal", "focus"]:
		button.add_theme_stylebox_override(state, normal)
	button.add_theme_stylebox_override("hover", pressed)
	button.add_theme_stylebox_override("pressed", pressed)
	var column := UiKit.vbox(4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = UiKit.px(12)
	column.offset_right = -UiKit.px(12)
	column.offset_top = UiKit.px(9)
	column.offset_bottom = -UiKit.px(9)
	var top := UiKit.hbox(6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)
	top.add_child(UiKit.label(str(option.get("tone", "")), 12, UiKit.MINT, UiKit.heavy_font()))
	var skill := str(option.get("skill", ""))
	if not skill.is_empty():
		var chip := UiKit.panel(UiKit.AMBER, 8, Vector2(7, 1))
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(UiKit.label(skill + " skill", 10, UiKit.AMBER_TEXT, UiKit.heavy_font()))
		top.add_child(chip)
	var text := str(option.get("text", ""))
	var words := UiKit.label(text, 13, UiKit.TEXT)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(words)
	# The button is as tall as its words.
	var words_height := UiKit.wrapped_height(text, UiKit.px(268), 13)
	var tone_height := UiKit.wrapped_height("Tone", UiKit.px(268), 12, UiKit.heavy_font())
	button.custom_minimum_size.y = UiKit.px(9 + 4 + 9) + tone_height + words_height
	UiKit.fit_height(button, column, 9)
	for child in column.find_children("*", "Control", true, false):
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.pressed.connect(_pick.bind(index))
	UiKit.respond_to_press(button)
	for child in column.find_children("*", "Label", true, false):
		(child as Label).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return button


func _pick(index: int) -> void:
	if not _choosing:
		return
	_choosing = false
	chosen.emit(index)


func _clear_choices() -> void:
	for child in _choice_list.get_children():
		_choice_list.remove_child(child)
		child.queue_free()


func _show_card(card: Dictionary) -> void:
	_card.visible = not card.is_empty()
	if card.is_empty():
		return
	_card_name.text = str(card.get("name", ""))
	var mood := int(card.get("mood", -1))
	_card_mood.get_parent().visible = mood >= 0
	if mood >= 0:
		_card_mood.text = AvatarConfig.EXPRESSIONS[mood]
	_card_role.text = str(card.get("role", ""))
	var trust := int(card.get("trust", -1))
	var change := int(card.get("change", 0))
	_trust_row.visible = trust >= 0
	_trust_track.visible = trust >= 0
	if trust < 0:
		return
	var change_text := ""
	if change != 0:
		change_text = " (%s%d)" % ["+" if change > 0 else "", change]
	_trust_value.text = "%d%s" % [trust, change_text]
	_trust_value.add_theme_color_override("font_color", UiKit.MINT if change > 0 else (UiKit.CORAL if change < 0 else Color("#DCEDEA")))
	_goal_trust = trust
	if _shown_trust < 0.0 or change == 0:
		_shown_trust = trust - change
	_layout_trust()


func _layout_trust() -> void:
	var width := _trust_track.size.x if _trust_track.size.x > 0.0 else UiKit.px(192)
	_trust_fill.size = Vector2(width * clampf(_shown_trust / 100.0, 0.0, 1.0), UiKit.px(7))


# --- Time and input -------------------------------------------------------

func tick(delta: float) -> void:
	if not visible:
		return
	var voiced := _voice.speaking
	if _typing:
		var before := _visible_count()
		_since_syllable += delta
		if voiced:
			# The words appear as the voice says them.
			var target := _voice.advance(delta, _typed)
			if _voice.failed:
				_typed += delta * TYPE_SPEED
			else:
				_typed = minf(move_toward(_typed, target, delta * SpokenLine.REVEAL_SPEED), _line.length())
		else:
			_typed += delta * TYPE_SPEED
		_reveal()
		for index in range(before, _visible_count()):
			_maybe_syllable(index)
		if _typed >= _line.length() and _voice.is_done():
			finish_typing()
	else:
		if voiced:
			# The whole line shows (a tap); the voice carries on, and the
			# mouth moves with each word it says.
			_voice.advance(delta, _line.length())
			if _voice.words > _voice_words:
				_voice_words = _voice.words
				syllable.emit("a")
		if not _choosing and auto_advance >= 0.0 and not _line.is_empty() and _voice.is_done():
			_read_time += delta
			# A line that was heard needs less reading time.
			var reading := 0.3 if reading_aloud() else _line.length() * 0.035
			if _read_time >= auto_advance + reading:
				_read_time = -INF
				advanced.emit()
	if _pressing and mode == Mode.CINEMA and skippable:
		_held += delta
		_skip_ring.queue_redraw()
		if _held >= HOLD_TO_SKIP:
			_pressing = false
			_held = 0.0
			skip_requested.emit()
	if _goal_trust >= 0.0 and absf(_shown_trust - _goal_trust) > 0.01:
		_shown_trust = move_toward(_shown_trust, _goal_trust, delta * 30.0)
		_layout_trust()


## A press shorter than the skip hold counts as a tap.
func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if button.pressed:
		_pressing = true
		_held = 0.0
	elif _pressing:
		_pressing = false
		var was_hold := _held >= 0.25
		_held = 0.0
		_skip_ring.queue_redraw()
		if not was_hold:
			tap()


## Finishes the line being typed, or moves on.
func tap() -> void:
	if _choosing:
		return
	if _typing:
		finish_typing()
	elif not _line.is_empty() or mode == Mode.CINEMA:
		advanced.emit()


func _visible_count() -> int:
	return mini(int(_typed), _line.length())


func _reveal() -> void:
	var count := _visible_count()
	_text.visible_characters = count
	_sub_text.visible_characters = count


func _maybe_syllable(index: int) -> void:
	var letter := _line[index].to_lower()
	if letter not in "aeiouy":
		return
	if index > 0 and _line[index - 1].to_lower() in "aeiouy":
		return
	if _since_syllable < 0.075:
		return
	_since_syllable = 0.0
	syllable.emit(letter)
