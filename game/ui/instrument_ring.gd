class_name InstrumentRing
extends Control
## The instrument ring: round buttons in a circle, one per instrument,
## with "Ask Tom" in the middle. Tapping one asks the scrub nurse for it.
## Used in training and in every operation.

signal picked(instrument: String)

const BUTTON := 66.0
const RADIUS := 92.0

var instruments: Array = Instruments.ALL.duplicate()
## Smaller rings fit beside other panels (operations use 0.8).
var ring_scale := 1.0
## Who to ask, shown in the middle.
var ask_name := "TOM"
var _buttons := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var reach := UiKit.px((RADIUS + BUTTON / 2.0) * ring_scale + 4)
	custom_minimum_size = Vector2(reach * 2, reach * 2)
	var middle := UiKit.vbox(0)
	middle.name = "Middle"
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(middle)
	var ask := UiKit.label("ASK " + ask_name, 11, UiKit.TEXT_KICKER, UiKit.heavy_font())
	ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	middle.add_child(ask)
	var call := UiKit.label("Call for…", 14, UiKit.TEXT, UiKit.heading_font())
	call.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	middle.add_child(call)
	for instrument: String in instruments:
		var button := Button.new()
		button.name = instrument.to_pascal_case()
		button.text = Instruments.name_of(instrument).replace(" ", "\n")
		button.custom_minimum_size = Vector2(UiKit.px(BUTTON * ring_scale), UiKit.px(BUTTON * ring_scale))
		button.size = button.custom_minimum_size
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.pressed.connect(func() -> void: picked.emit(instrument))
		add_child(button)
		_buttons[instrument] = button
		mark(instrument, "")
	resized.connect(_layout)
	_layout()


## Colours a button's ring: "right", "wrong" or "" for normal.
func mark(instrument: String, how: String) -> void:
	var button: Button = _buttons.get(instrument)
	if button == null:
		return
	var ring := Color(UiKit.MINT, 0.55)
	match how:
		"right":
			ring = VitalsMonitor.RIGHT
		"wrong":
			ring = VitalsMonitor.WRONG
	var normal := UiKit.box(Color(7 / 255.0, 32 / 255.0, 37 / 255.0, 0.94), BUTTON * ring_scale / 2.0, ring, 3)
	var pressed := UiKit.box(Color("#123F46"), BUTTON * ring_scale / 2.0, UiKit.AMBER, 3)
	UiKit._style_button(button, normal, pressed, UiKit.TEXT, 11 if ring_scale >= 0.95 else 10, UiKit.heavy_font())


func clear_marks() -> void:
	for instrument: String in _buttons:
		mark(instrument, "")


func button_for(instrument: String) -> Button:
	return _buttons.get(instrument)


func _layout() -> void:
	var centre := size / 2.0
	var middle := get_node("Middle") as Control
	middle.size = Vector2(UiKit.px(90), UiKit.px(44))
	middle.position = centre - middle.size / 2.0
	var count := instruments.size()
	for index in count:
		var button: Button = _buttons[instruments[index]]
		var angle := -PI / 2.0 + TAU * index / count
		button.position = centre + Vector2(cos(angle), sin(angle)) * UiKit.px(RADIUS * ring_scale) - button.size / 2.0
