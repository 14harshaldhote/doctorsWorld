class_name SettingsPanel
extends Control
## The settings, over whatever screen opened them (the title screen or the
## pause menu): music, sound effects and voice volume, text size, reduced
## motion, the colour-blind-safe monitor and the graphics mode. Every change
## takes effect at once so you can hear and see it; Done saves them.

signal closed

## Where Done saves the settings. Tests point this somewhere else.
static var save_path := GameSettings.DEFAULT_PATH

var settings: GameSettings
var sliders := {}
var choice_rows := {}
var done_button: Button
var _values := {}


func _init(editing: GameSettings = null) -> void:
	settings = editing if editing != null else GameSettings.current


func _ready() -> void:
	name = "Settings"
	theme = UiKit.theme()
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.08, 0.1, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiKit.fill(shade))

	var card := UiKit.panel(Color(12 / 255.0, 30 / 255.0, 36 / 255.0, 0.97), 20, Vector2(22, 16))
	card.name = "Card"
	var card_style := card.get_theme_stylebox("panel") as StyleBoxFlat
	card_style.border_color = Color(UiKit.MINT, 0.3)
	card_style.set_border_width_all(2)
	UiKit.fill(card)
	card.offset_left = UiKit.px(30)
	card.offset_right = -UiKit.px(30)
	card.offset_top = UiKit.px(16)
	card.offset_bottom = -UiKit.px(16)
	UiKit.keep_off_edges(card)
	add_child(card)
	var column := UiKit.vbox(8)
	card.add_child(column)

	var header := UiKit.hbox(12)
	column.add_child(header)
	var titles := UiKit.vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	titles.add_child(UiKit.kicker("Doctors World"))
	titles.add_child(UiKit.heading("Settings", 24))
	done_button = UiKit.primary_button("Done", 44, 17)
	done_button.name = "Done"
	done_button.custom_minimum_size.x = UiKit.px(120)
	done_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	done_button.pressed.connect(close)
	header.add_child(done_button)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var sides := UiKit.hbox(28)
	sides.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(sides)
	var left := UiKit.vbox(10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sides.add_child(left)
	var right := UiKit.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sides.add_child(right)

	left.add_child(_section("Sound"))
	for entry: Array in [["Music", "Music"], ["Effects", "Sound effects"], ["Voices", "Voices"]]:
		left.add_child(_slider_row(entry[0], entry[1]))
	left.add_child(_section("Graphics"))
	var modes: Array = []
	for mode: String in GameSettings.GRAPHICS:
		modes.append(GameSettings.GRAPHICS_NAMES[mode])
	left.add_child(_choice_row("graphics", "Graphics", modes, GameSettings.GRAPHICS.find(settings.graphics),
		"Battery saver runs at 30 frames a second, for older phones."))

	# Text size goes first on the right, so a player who needs it never has
	# to scroll (with small text) to find it.
	right.add_child(_section("Reading"))
	right.add_child(_choice_row("text_size", "Text size", GameSettings.TEXT_SIZE_NAMES, settings.text_size))
	right.add_child(_section("Comfort"))
	right.add_child(_choice_row("reduce_motion", "Reduce motion", ["Off", "On"], 1 if settings.reduce_motion else 0,
		"Cuts instead of camera sweeps, and no bouncing."))
	right.add_child(_choice_row("colour_safe", "Colour-blind-safe monitor", ["Off", "On"], 1 if settings.colour_safe else 0,
		"Blue and orange instead of green and red, with arrows."))


func _section(text: String) -> Label:
	var made := UiKit.kicker(text, 12)
	made.add_theme_color_override("font_color", UiKit.AMBER)
	return made


func _slider_row(bus: String, title: String) -> Control:
	var row := UiKit.vbox(2)
	var top := UiKit.hbox(8)
	row.add_child(top)
	var label := UiKit.label(title, 15, UiKit.TEXT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(label)
	var value := UiKit.label("", 14, UiKit.TEXT_SOFT)
	top.add_child(value)
	_values[bus] = value
	var slider := UiKit.slider()
	slider.name = bus
	slider.value = roundf(settings.volume(bus) * 100.0)
	slider.value_changed.connect(_on_slider.bind(bus))
	row.add_child(slider)
	sliders[bus] = slider
	_show_value(bus)
	return row


func _show_value(bus: String) -> void:
	var level := settings.volume(bus)
	(_values[bus] as Label).text = "Off" if level <= 0.0 else "%d%%" % roundi(level * 100.0)


func _choice_row(key: String, title: String, options: Array, selected: int, note: String = "") -> Control:
	var row := UiKit.vbox(4)
	row.add_child(UiKit.label(title, 15, UiKit.TEXT))
	var chips := UiKit.flow(8)
	row.add_child(chips)
	var buttons: Array[Button] = []
	for index in options.size():
		var chip := UiKit.chip(str(options[index]), index == selected, 38)
		chip.name = str(options[index]).replace(" ", "")
		chip.pressed.connect(_on_choice.bind(key, index))
		chips.add_child(chip)
		buttons.append(chip)
	choice_rows[key] = buttons
	if not note.is_empty():
		var hint := UiKit.label(note, 12, UiKit.TEXT_SOFT)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(hint)
	return row


func _on_slider(value: float, bus: String) -> void:
	settings.set_volume(bus, value / 100.0)
	_show_value(bus)
	settings.apply_audio()


## Picks option index of a choice row, as a tap on its chip does.
func pick(key: String, index: int) -> void:
	_on_choice(key, index)


func _on_choice(key: String, index: int) -> void:
	var buttons: Array[Button] = choice_rows[key]
	for other in buttons.size():
		UiKit.set_chip(buttons[other], other == index)
	match key:
		"text_size":
			settings.text_size = index
		"reduce_motion":
			settings.reduce_motion = index == 1
		"colour_safe":
			settings.colour_safe = index == 1
		"graphics":
			settings.graphics = GameSettings.GRAPHICS[index]
	if key == "graphics" and is_inside_tree():
		settings.apply_display(get_window())
	if key == "text_size" and is_inside_tree() and settings == GameSettings.current:
		UiKit.refresh_text(get_tree().root)


## Saves and closes.
func close() -> void:
	if settings == GameSettings.current and not save_path.is_empty():
		settings.save_to(save_path)
	closed.emit()
	queue_free()
