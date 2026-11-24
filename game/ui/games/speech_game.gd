class_name SpeechGame
extends MiniGame
## A speech the doctor gives (stage 27): a toast for Sister Grace, a few
## words at Dr. Rao's farewell. A line at a time, three ways to say it
## (story/life.json, "speeches"), and the room reacts to each. The lines'
## points add up to a verdict: "great", "ok" or "flop". The doctor's lines
## are on screen, never said aloud.

## How long the room's reaction shows before the next line, if nobody taps.
const REACT := 4.0

var speech := {}
var verdicts := {}
var rounds: Array = []
var line_index := 0
var points := 0
## "choose", "react" or "over".
var state := "choose"
var buttons: Array[Button] = []
var said: Array[String] = []
var _auto := SeededRandom.new(77)
var _left := 0.0
var _prompt: Label
var _choices: VBoxContainer
var _reaction: Label
var _next: Button


func _init(for_speech: Dictionary = {}, verdict_lines: Dictionary = {}) -> void:
	speech = for_speech
	verdicts = verdict_lines
	rounds = speech.get("rounds", [])
	title = str(speech.get("title", "A speech"))
	how = "Pick each line. The room is judging."


func lost_result() -> String:
	return "flop"


func build() -> void:
	_prompt = UiKit.label("", 15, UiKit.TEXT, UiKit.heading_medium_font())
	_prompt.name = "Prompt"
	content.add_child(_prompt)
	_choices = UiKit.vbox(6)
	_choices.name = "Choices"
	content.add_child(_choices)
	_reaction = UiKit.label("", 15, UiKit.TEXT, UiKit.body_font())
	_reaction.name = "Reaction"
	_reaction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reaction.visible = false
	content.add_child(_reaction)
	_next = UiKit.ghost_button("Next line", 42, 15)
	_next.name = "Next"
	_next.focus_mode = Control.FOCUS_NONE
	_next.visible = false
	_next.pressed.connect(next_line)
	UiKit.respond_to_press(_next)
	content.add_child(_next)
	_start_line()


func _start_line() -> void:
	if line_index >= rounds.size():
		_finish()
		return
	state = "choose"
	_prompt.visible = false
	_reaction.visible = false
	_next.visible = false
	for button in buttons:
		_choices.remove_child(button)
		button.queue_free()
	buttons.clear()
	var options: Array = rounds[line_index]
	for index in options.size():
		var button := _option_button(index, options[index])
		_choices.add_child(button)
		buttons.append(button)
	_choices.visible = true
	set_score("Line %d of %d" % [line_index + 1, rounds.size()])


func _option_button(index: int, option: Dictionary) -> Button:
	var button := Button.new()
	button.name = "Line%d" % (index + 1)
	button.focus_mode = Control.FOCUS_NONE
	var normal := UiKit.box(Color(1, 1, 1, 0.04), 12, Color(UiKit.MINT, 0.45), 2, Vector2(12, 7))
	var pressed := UiKit.box(Color(UiKit.MINT, 0.18), 12, UiKit.MINT, 2, Vector2(12, 7))
	for state_name in ["normal", "focus", "disabled"]:
		button.add_theme_stylebox_override(state_name, normal)
	button.add_theme_stylebox_override("hover", pressed)
	button.add_theme_stylebox_override("pressed", pressed)
	var column := UiKit.vbox(1)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = UiKit.px(12)
	column.offset_right = -UiKit.px(12)
	column.offset_top = UiKit.px(7)
	column.offset_bottom = -UiKit.px(7)
	button.add_child(column)
	column.add_child(UiKit.label(str(option.get("tone", "")), 11, UiKit.MINT, UiKit.heavy_font()))
	var words := UiKit.label(str(option.get("text", "")), 13, UiKit.TEXT)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(words)
	for child in column.find_children("*", "Control", true, false):
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.custom_minimum_size.y = UiKit.px(50)
	UiKit.fit_height(button, column, 7)
	button.pressed.connect(pick.bind(index))
	UiKit.respond_to_press(button)
	return button


## The doctor says a line.
func pick(index: int) -> void:
	if state != "choose" or line_index >= rounds.size():
		return
	var options: Array = rounds[line_index]
	if index < 0 or index >= options.size():
		return
	var option: Dictionary = options[index]
	var worth := int(option.get("points", 1))
	points += worth
	said.append(str(option.get("text", "")))
	moment.emit("great" if worth >= 3 else ("good" if worth == 2 else "bad"))
	state = "react"
	_left = REACT
	_choices.visible = false
	_prompt.text = "\"%s\"" % str(option.get("text", ""))
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.visible = true
	_reaction.text = str(option.get("reaction", ""))
	_reaction.visible = true
	_next.text = "Finish" if line_index + 1 >= rounds.size() else "Next line"
	_next.visible = true


func next_line() -> void:
	if state != "react":
		return
	line_index += 1
	_prompt.autowrap_mode = TextServer.AUTOWRAP_OFF
	_start_line()


func play(delta: float) -> void:
	if state == "react":
		_left -= delta
		if _left <= 0.0:
			next_line()


func _finish() -> void:
	state = "over"
	_choices.visible = false
	_next.visible = false
	var verdict := Life.speech_verdict(speech, points)
	end(verdict, str(verdicts.get(verdict, "")))


func auto_step(skill: float) -> void:
	match state:
		"choose":
			var options: Array = rounds[line_index]
			var best := 0
			for index in options.size():
				if int((options[index] as Dictionary).get("points", 0)) > int((options[best] as Dictionary).get("points", 0)):
					best = index
			pick(best if _auto.chance(clampf(skill, 0.0, 1.0)) else (best + 1) % options.size())
		"react":
			if _left < REACT - 0.5:
				next_line()
