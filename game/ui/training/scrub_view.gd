class_name ScrubView
extends TrainingView
## Scrub in: buttons for each step on the right. The six parts of the
## hands are held down to scrub them, and fill up as they go. Two tempting
## buttons (fix the mask, scratch the nose) are there to be left alone.

const STEP_BUTTONS := [["water", "Water on"], ["soap", "Soap"], ["rinse", "Rinse"], ["towel", "Towel"], ["gown", "Gown"],
	["gloves", "Gloves"]]
const AREA_BUTTONS := [["palms", "Palms"], ["backs", "Backs"], ["fingers", "Fingers"], ["thumbs", "Thumbs"],
	["nails", "Nails"], ["wrists", "Wrists"]]
const TRAP_BUTTONS := [["mask", "Fix mask"], ["nose", "Scratch nose"]]

## The area held down now ("" when none).
var holding := ""
var _panel: PanelContainer
var _buttons := {}
var _fills := {}


func _build() -> void:
	_panel = _right_panel(330)
	_panel.name = "Controls"
	var column := UiKit.vbox(6)
	_panel.add_child(column)
	column.add_child(UiKit.kicker("Wash", 11))
	var steps := UiKit.grid(3, 6)
	column.add_child(steps)
	for entry: Array in STEP_BUTTONS:
		var button := small_button(entry[1])
		button.name = str(entry[0]).capitalize()
		button.pressed.connect(press.bind(entry[0]))
		steps.add_child(button)
		_buttons[entry[0]] = button
	column.add_child(UiKit.kicker("Scrub · hold each one", 11))
	var areas := UiKit.grid(3, 6)
	column.add_child(areas)
	for entry: Array in AREA_BUTTONS:
		var button := small_button(entry[1])
		button.name = str(entry[0]).capitalize()
		button.clip_contents = true
		var fill := ColorRect.new()
		fill.name = "Fill"
		UiKit.fill(fill)
		fill.anchor_right = 0.0
		fill.color = Color(UiKit.MINT, 0.32)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.show_behind_parent = false
		button.add_child(fill)
		button.move_child(fill, 0)
		button.button_down.connect(hold.bind(entry[0]))
		button.button_up.connect(release)
		areas.add_child(button)
		_buttons[entry[0]] = button
		_fills[entry[0]] = fill
	column.add_child(UiKit.kicker("Also within reach", 11))
	var traps := UiKit.grid(2, 6)
	column.add_child(traps)
	for entry: Array in TRAP_BUTTONS:
		var button := small_button(entry[1])
		button.name = str(entry[0]).capitalize()
		button.pressed.connect(press.bind(entry[0]))
		traps.add_child(button)
		_buttons[entry[0]] = button


func _scrub() -> ScrubTask:
	return task as ScrubTask


## A tap on a step (or a trap).
func press(step: String) -> void:
	if result_open():
		return
	_scrub().do_step(step)


## Starts holding a part of the hands.
func hold(area: String) -> void:
	if result_open():
		return
	holding = area
	_scrub().begin_scrub(area)


func release() -> void:
	holding = ""


func _tick(delta: float) -> void:
	var scrub := _scrub()
	if not holding.is_empty():
		scrub.scrub(holding, delta)
	var sink := station() as ScrubSink
	if sink != null:
		sink.scrubbing = holding
	for entry: Array in AREA_BUTTONS:
		var area: String = entry[0]
		var fill: ColorRect = _fills[area]
		var amount := clampf(float(scrub.scrubbed.get(area, 0.0)) / ScrubTask.SCRUB_TIME, 0.0, 1.0)
		fill.anchor_right = amount
		fill.color = Color(UiKit.MINT, 0.5 if amount >= 1.0 else 0.3)


func _hide_controls() -> void:
	_panel.visible = false
	holding = ""


func button_for(step: String) -> Button:
	return _buttons.get(step)
