class_name StoryOverlay
extends Control
## What story scenes draw over the 3D: fades to black or white, title cards
## ("A few weeks later") and the internship letter from Riverside.
##
## Time passes only through tick(), so tests can drive it.

signal letter_closed

## The letter closes by itself after this long if nobody taps.
const LETTER_TIME := 9.0

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
var _letter: PanelContainer
var _letter_t := -1.0


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
	_fade.color = Color(0, 0, 0, 1)
	_fade_to = _fade.color
	_fade_from = _fade.color


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
	if _letter_t >= 0.0:
		_letter_t += delta
		_letter.modulate.a = clampf(_letter_t / 0.35, 0.0, 1.0)
		_letter.scale = Vector2.ONE * lerpf(0.92, 1.0, clampf(_letter_t / 0.35, 0.0, 1.0))
		if _letter_t >= LETTER_TIME:
			close_letter()
