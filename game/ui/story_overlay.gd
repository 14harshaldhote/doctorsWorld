class_name StoryOverlay
extends Control
## What story scenes draw over the 3D: fades to black or white, title cards
## ("A few weeks later") and the internship letter from Riverside.
##
## Time passes only through tick(), so tests can drive it.

signal letter_closed

## The letter closes by itself after this long if nobody taps.
const LETTER_TIME := 9.0
## How long the end-of-day card stays if nobody taps it away.
const END_CARD_TIME := 7.5
## A tap can't close the end-of-day card before this (a stray tap from the
## screen before it), and after one it goes in this long.
const END_CARD_MIN := 1.0
const END_CARD_OUT := 0.45

var profile: PlayerProfile

var _fade: ColorRect
var _fade_from := Color(0, 0, 0, 1)
var _fade_to := Color(0, 0, 0, 1)
var _fade_time := 0.0
var _fade_t := 0.0
var _card: VBoxContainer
var _card_title: Label
var _card_sub: Label
var _card_time := 0.0
var _card_t := 0.0
var _card_hooks: VBoxContainer
var _card_streak: Label
var _card_goal: Label
var _card_rival: Label
var _card_post: Label
var _card_next: Label
var _card_hint: Label
var _end_card := false
var _letter: PanelContainer
var _letter_t := -1.0
var _confetti: Confetti


func _init(for_profile: PlayerProfile = null) -> void:
	profile = for_profile if for_profile != null else PlayerProfile.new()


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.color = _fade_to
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(_fade)
	add_child(_fade)
	_build_card()
	_build_letter()


func _build_card() -> void:
	_card = UiKit.vbox(10)
	_card.name = "Card"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.alignment = BoxContainer.ALIGNMENT_CENTER
	UiKit.fill(_card)
	add_child(_card)
	_card_title = UiKit.label("", 34, Color.WHITE, UiKit.heading_font())
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_child(_card_title)
	_card_sub = UiKit.label("", 15, UiKit.TEXT_KICKER, UiKit.heavy_font())
	_card_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_child(_card_sub)
	# Under an end-of-day card: what keeps the career moving.
	_card_hooks = UiKit.vbox(6)
	_card_hooks.name = "Hooks"
	_card_hooks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_hooks.visible = false
	_card.add_child(_card_hooks)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, UiKit.px(8))
	_card_hooks.add_child(gap)
	_card_streak = UiKit.label("", 15, UiKit.AMBER, UiKit.heavy_font())
	_card_streak.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_hooks.add_child(_card_streak)
	_card_goal = UiKit.label("", 13, UiKit.MINT, UiKit.heavy_font())
	_card_goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_hooks.add_child(_card_goal)
	_card_rival = UiKit.label("", 13, UiKit.CORAL, UiKit.heavy_font())
	_card_rival.name = "Rival"
	_card_rival.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_rival.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_rival.custom_minimum_size = Vector2(UiKit.px(560), 0)
	_card_rival.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card_hooks.add_child(_card_rival)
	_card_post = UiKit.label("", 13, UiKit.AMBER, UiKit.heavy_font())
	_card_post.name = "Post"
	_card_post.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_post.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_post.custom_minimum_size = Vector2(UiKit.px(560), 0)
	_card_post.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card_hooks.add_child(_card_post)
	_card_next = UiKit.label("", 17, Color.WHITE, UiKit.heading_medium_font())
	_card_next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_next.custom_minimum_size = Vector2(UiKit.px(560), 0)
	_card_next.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card_hooks.add_child(_card_next)
	_card_hint = UiKit.label("Tap to go on", 11, UiKit.TEXT_KICKER, UiKit.heavy_font())
	_card_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_hooks.add_child(_card_hint)
	_card.modulate.a = 0.0


func _build_letter() -> void:
	_letter = PanelContainer.new()
	_letter.name = "Letter"
	_letter.add_theme_stylebox_override("panel", UiKit.box(Color("#FBFAF5"), 6, Color.TRANSPARENT, 0, Vector2(0, 0)))
	_letter.anchor_left = 0.5
	_letter.anchor_right = 0.5
	_letter.anchor_top = 0.5
	_letter.anchor_bottom = 0.5
	_letter.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_letter.grow_vertical = Control.GROW_DIRECTION_BOTH
	_letter.custom_minimum_size = Vector2(UiKit.px(420), 0)
	_letter.rotation = -0.025
	_letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_letter.visible = false
	add_child(_letter)
	_letter.resized.connect(func() -> void: _letter.pivot_offset = _letter.size / 2.0)


func _fill_letter() -> void:
	for child in _letter.get_children():
		_letter.remove_child(child)
		child.queue_free()
	var column := UiKit.vbox(0)
	_letter.add_child(column)
	var head := UiKit.panel(UiKit.TEAL, 0, Vector2(18, 10))
	column.add_child(head)
	var head_row := UiKit.hbox(10)
	head.add_child(head_row)
	var emblem := UiIcon.make("badge", 22, Color.WHITE)
	emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head_row.add_child(emblem)
	var names := UiKit.vbox(0)
	head_row.add_child(names)
	names.add_child(UiKit.label("RIVERSIDE CITY HOSPITAL", 15, Color.WHITE, UiKit.heading_font()))
	names.add_child(UiKit.label("Riverside Road · Riverside City", 10, Color("#CFEDEA"), UiKit.heavy_font()))
	var body := UiKit.panel(Color("#FBFAF5"), 0, Vector2(22, 14))
	column.add_child(body)
	var text := UiKit.vbox(8)
	body.add_child(text)
	var ink := Color("#22363B")
	var paragraphs := [
		["Dear %s," % profile.full_title(), true],
		["We are pleased to offer you an internship in the Department of Surgery, starting Monday at 7:00 a.m.", false],
		["Please report to Dr. Meera Iyer at the main reception. Bring this letter, your registration certificate and comfortable shoes. You will not sit down again.", false],
		["Yours sincerely,\nVikram Malhotra\nHospital Administrator", false],
	]
	for paragraph: Array in paragraphs:
		var label := UiKit.label(paragraph[0], 13, ink, UiKit.heavy_font() if paragraph[1] else UiKit.body_font())
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(UiKit.px(376), 0)
		text.add_child(label)
	var hint := UiKit.label("Tap to fold the letter", 11, Color("#7A8F93"), UiKit.heavy_font())
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	text.add_child(hint)


## Fades the screen: to "black", "white" or "clear".
func fade(to: String, time: float) -> void:
	_fade_from = _fade.color
	match to:
		"white":
			_fade_to = Color(1, 1, 1, 1)
		"black":
			_fade_to = Color(0, 0, 0, 1)
		_:
			_fade_to = Color(_fade.color.r, _fade.color.g, _fade.color.b, 0.0)
	_fade_time = maxf(time, 0.001)
	_fade_t = 0.0


func fade_amount() -> float:
	return _fade.color.a


## A title card over a dark screen for a few seconds.
func card(title: String, sub: String, time: float) -> void:
	_card_title.text = title
	_card_sub.text = sub
	_card_sub.visible = not sub.is_empty()
	_card_time = maxf(time, 0.1)
	_card_t = 0.0
	_card_hooks.visible = false
	_end_card = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0, 0, 0, 1)
	_fade_to = _fade.color
	_fade_from = _fade.color


## The card that ends a day: the day's own line, and under it what makes the
## next day worth starting ({"streak", "goal", "tomorrow"}, see DayHooks).
## It stays until tapped (or END_CARD_TIME); returns how long that is.
func end_card(title: String, sub: String, hooks: Dictionary, time: float = END_CARD_TIME) -> float:
	card(title, sub, time)
	_end_card = true
	var streak := str(hooks.get("streak", ""))
	var goal := str(hooks.get("goal", ""))
	var next := str(hooks.get("tomorrow", ""))
	_card_streak.text = streak
	_card_streak.visible = not streak.is_empty()
	_card_goal.text = goal
	_card_goal.visible = not goal.is_empty()
	var rival := str(hooks.get("rival", ""))
	_card_rival.text = rival
	_card_rival.visible = not rival.is_empty()
	var post := str(hooks.get("post", ""))
	_card_post.text = post
	_card_post.visible = not post.is_empty()
	_card_next.text = next
	_card_next.visible = not next.is_empty()
	_card_hooks.visible = true
	# The whole screen is the button.
	mouse_filter = Control.MOUSE_FILTER_STOP
	return _card_time


## True while an end-of-day card is up.
func end_card_open() -> bool:
	return _end_card and _card_t < _card_time


## What the end-of-day card says under the day's line, top to bottom.
func end_card_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	if _card_hooks.visible:
		for line: Label in [_card_streak, _card_goal, _card_rival, _card_post, _card_next]:
			if line.visible:
				lines.append(line.text)
	return lines


## A tap on the end-of-day card: it goes, and the next day starts. Returns
## false when it is too soon (or there is no such card).
func skip_end_card() -> bool:
	if not end_card_open() or _card_t < END_CARD_MIN:
		return false
	_card_time = minf(_card_time, _card_t + END_CARD_OUT)
	return true


## How long the card on screen has left.
func card_left() -> float:
	return maxf(0.0, _card_time - _card_t)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and not button.pressed and skip_end_card():
		Sfx.play(self, "tap", -8.0)
		accept_event()


## Confetti over everything, for a promotion. Nothing with Reduce motion on.
func celebrate() -> void:
	if GameSettings.current.reduce_motion:
		return
	if _confetti != null:
		_confetti.queue_free()
	_confetti = Confetti.new()
	add_child(_confetti)


func confetti() -> Confetti:
	return _confetti


func show_letter() -> void:
	_fill_letter()
	_letter.visible = true
	_letter.modulate.a = 0.0
	_letter_t = 0.0


func close_letter() -> void:
	if not _letter.visible:
		return
	_letter.visible = false
	_letter_t = -1.0
	letter_closed.emit()


func letter_open() -> bool:
	return _letter.visible


func tick(delta: float) -> void:
	if _fade_t < _fade_time:
		_fade_t = minf(_fade_t + delta, _fade_time)
		_fade.color = _fade_from.lerp(_fade_to, smoothstep(0.0, 1.0, _fade_t / _fade_time))
	if _card_t < _card_time:
		_card_t += delta
		var fade_in := clampf(_card_t / 0.5, 0.0, 1.0)
		var fade_out := clampf((_card_time - _card_t) / 0.5, 0.0, 1.0)
		_card.modulate.a = minf(fade_in, fade_out)
	if _confetti != null:
		_confetti.tick(delta)
		if _confetti.finished():
			_confetti.queue_free()
			_confetti = null
	if _letter_t >= 0.0:
		_letter_t += delta
		_letter.modulate.a = clampf(_letter_t / 0.35, 0.0, 1.0)
		_letter.scale = Vector2.ONE * lerpf(0.92, 1.0, clampf(_letter_t / 0.35, 0.0, 1.0))
		if _letter_t >= LETTER_TIME:
			close_letter()
