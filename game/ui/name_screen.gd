class_name NameScreen
extends Control
## Step 1 of a new career: the doctor's name and how people address them,
## with a live preview of the coat badge.

signal back_pressed
signal next_pressed

var profile: PlayerProfile

var name_field: LineEdit
var next_button: Button
var _form_chips: Array[Button] = []
var _badge_name: Label


func _init(for_profile: PlayerProfile = null) -> void:
	profile = for_profile if for_profile != null else PlayerProfile.new()


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.fill(self)
	add_child(UiKit.fill(PolyBackdrop.graduation_hall()))

	var card := UiKit.panel(Color(12 / 255.0, 30 / 255.0, 36 / 255.0, 0.92), 20, Vector2(28, 22))
	card.name = "Card"
	var card_style := card.get_theme_stylebox("panel") as StyleBoxFlat
	card_style.border_color = Color(UiKit.MINT, 0.3)
	card_style.set_border_width_all(2)
	# Centred, so it fits whatever the text size; the buttons live inside.
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	card.custom_minimum_size = Vector2(UiKit.px(560), 0)
	add_child(card)
	var row := UiKit.hbox(24)
	card.add_child(row)

	var form := UiKit.vbox(7)
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(form)
	form.add_child(UiKit.kicker("Step 1 of 2"))
	var question := UiKit.heading("What should everyone call you, Doctor?", 23)
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question.custom_minimum_size = Vector2(UiKit.px(300), 0)
	form.add_child(question)
	form.add_child(UiKit.label("Your name", 14, UiKit.TEXT_LABEL))
	name_field = LineEdit.new()
	name_field.name = "NameField"
	name_field.text = profile.name
	name_field.placeholder_text = "First and last name"
	name_field.max_length = PlayerProfile.MAX_NAME_LENGTH
	name_field.custom_minimum_size = Vector2(0, UiKit.px(44))
	name_field.add_theme_stylebox_override("normal", UiKit.box(UiKit.INPUT, 12, UiKit.MINT, 2, Vector2(14, 0)))
	name_field.add_theme_stylebox_override("focus", UiKit.box(UiKit.INPUT, 12, UiKit.AMBER, 2, Vector2(14, 0)))
	name_field.add_theme_font_override("font", UiKit.body_font())
	UiKit.set_text_size(name_field, 18)
	name_field.add_theme_color_override("font_color", Color.WHITE)
	name_field.add_theme_color_override("font_placeholder_color", Color(1, 1, 1, 0.4))
	name_field.add_theme_color_override("caret_color", UiKit.AMBER)
	name_field.text_changed.connect(_on_name_changed)
	name_field.text_submitted.connect(func(_text: String) -> void: _on_next())
	form.add_child(name_field)
	form.add_child(UiKit.label("Patients and staff call you", 14, UiKit.TEXT_LABEL))
	var chips := UiKit.hbox(8)
	form.add_child(chips)
	for form_id in ["first", "last"]:
		var chip := UiKit.chip("", profile.address_form == form_id)
		chip.name = "Call" + form_id.capitalize()
		chip.pressed.connect(_on_form_picked.bind(form_id))
		chip.set_meta("form", form_id)
		chips.add_child(chip)
		_form_chips.append(chip)

	var badge_column := UiKit.vbox(10)
	badge_column.custom_minimum_size = Vector2(UiKit.px(196), 0)
	row.add_child(badge_column)
	var badge_title := UiKit.kicker("Your coat badge")
	badge_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_column.add_child(badge_title)
	var badge := UiKit.panel(Color.WHITE, 12, Vector2(12, 12))
	var badge_style := badge.get_theme_stylebox("panel") as StyleBoxFlat
	badge_style.border_color = Color("#B9C9CC")
	badge_style.border_width_bottom = int(UiKit.px(6))
	badge_column.add_child(badge)
	var badge_lines := UiKit.vbox(4)
	badge.add_child(badge_lines)
	var stripe := ColorRect.new()
	stripe.color = UiKit.TEAL
	stripe.custom_minimum_size = Vector2(0, UiKit.px(6))
	badge_lines.add_child(stripe)
	_badge_name = UiKit.label("", 18, UiKit.INK, UiKit.heading_font())
	_badge_name.name = "BadgeName"
	_badge_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_badge_name.custom_minimum_size = Vector2(UiKit.px(136), 0)
	badge_lines.add_child(_badge_name)
	badge_lines.add_child(UiKit.label("INTERN", 12, UiKit.TEAL, UiKit.heavy_font()))
	badge_lines.add_child(UiKit.label("Riverside City Hospital", 11, Color("#3F5A60")))

	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	badge_column.add_child(gap)
	next_button = UiKit.primary_button("Next: your look")
	next_button.name = "Next"
	next_button.pressed.connect(_on_next)
	badge_column.add_child(next_button)
	var back := UiKit.ghost_button("Back")
	back.name = "Back"
	back.pressed.connect(func() -> void: back_pressed.emit())
	badge_column.add_child(back)
	_refresh()


func _on_name_changed(_text: String) -> void:
	_refresh()


func _on_form_picked(form_id: String) -> void:
	profile.address_form = form_id
	_refresh()


func _on_next() -> void:
	if PlayerProfile.clean_name(name_field.text).is_empty():
		return
	profile.name = name_field.text
	next_pressed.emit()


## Updates the chips, the badge and the Next button from what is typed.
func _refresh() -> void:
	var typed := PlayerProfile.clean_name(name_field.text)
	var preview := PlayerProfile.new()
	preview.name = typed if not typed.is_empty() else "Your Name"
	for chip in _form_chips:
		var form_id: String = chip.get_meta("form")
		chip.text = "Dr. " + (preview.first_name() if form_id == "first" else preview.last_name())
		UiKit.set_chip(chip, profile.address_form == form_id)
	_badge_name.text = "Dr. " + preview.name
	next_button.disabled = typed.is_empty()
