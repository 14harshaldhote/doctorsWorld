class_name TrainingView
extends Control
## The screen over a training station while its task runs: what to do now
## (top left), the trainer's coaching (bottom left), a way out (top right),
## the task's own controls, and the score card at the end.
##
## Each task has its own view (ScrubView, MonitorView...). Time passes only
## through tick(), so tests and the screenshot tool can play a task.

signal leave_pressed
signal retry_pressed
signal done_pressed
## The task has finished: the lab records the score and calls show_result().
signal task_finished(task: TrainingTask)

## Seconds between the task ending and the score card.
const RESULT_DELAY := 1.4
const TYPE_SPEED := 55.0

var task: TrainingTask
var lab: Node
var trainer := "iyer"
## Who the coach line is from, if not the trainer (an acting patient).
var speaker_override := ""
## The cast id whose voice reads the coach line, if not the trainer's.
var voice_override := ""
## The score card's main button.
var done_text := "Back to the lab"
## Real patients can't be examined twice: false hides "Try again".
var can_retry := true
## Replaces the line over the title and the score card's top line (on the
## ward: "Ward round · Bed 2").
var kicker_override := ""

var _header: PanelContainer
var _title: Label
var _instruction: Label
var _progress_fill: ColorRect
var _progress_track: Control
var _coach_box: PanelContainer
var _coach_name: Label
var _coach_text: Label
var _leave: Button
var _result: PanelContainer
var _shown_coach := ""
## The voice reading the coach line aloud, when the device can speak.
var _coach_voice := SpokenLine.new()
var _coach_heard := false
var _typed := 0.0
var _since_syllable := 1.0
var _result_in := -1.0
var _reported := false


func _init(for_task: TrainingTask = null, in_lab: Node = null) -> void:
	task = for_task
	lab = in_lab
	if task != null:
		trainer = str(TrainingTask.TRAINERS.get(task.id, "iyer"))


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_header()
	_build_coach()
	_build_leave()
	_build()
	UiKit.keep_children_off_edges(self)
	_refresh()


## Each view adds its own controls here.
func _build() -> void:
	pass


## Each view updates its own controls and 3D here, every frame.
func _tick(_delta: float) -> void:
	pass


func tick(delta: float) -> void:
	if task == null:
		return
	if not task.finished:
		task.tick(delta)
	_tick(delta)
	_refresh()
	_type_coach(delta)
	if task.finished and not _reported:
		_reported = true
		_result_in = RESULT_DELAY
	if _result_in > 0.0:
		_result_in -= delta
		if _result_in <= 0.0:
			task_finished.emit(task)


func result_open() -> bool:
	return _result != null and _result.visible


## The score card. reward: a line such as "+50 XP · new best".
func show_result(reward: String) -> void:
	if _result != null:
		_result.queue_free()
	_result = UiKit.panel(UiKit.PANEL_DEEP, 20, Vector2(22, 18))
	_result.name = "Result"
	_result.mouse_filter = Control.MOUSE_FILTER_STOP
	_result.anchor_left = 0.5
	_result.anchor_right = 0.5
	_result.anchor_top = 0.5
	_result.anchor_bottom = 0.5
	_result.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_result.grow_vertical = Control.GROW_DIRECTION_BOTH
	_result.custom_minimum_size = Vector2(UiKit.px(470), 0)
	add_child(_result)
	var column := UiKit.vbox(10)
	_result.add_child(column)
	var top := UiKit.hbox(12)
	column.add_child(top)
	var names := UiKit.vbox(2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(names)
	names.add_child(UiKit.kicker(kicker_override if not kicker_override.is_empty() else "Training · " + _trainer_name()))
	names.add_child(UiKit.heading(task.title(), 22))
	var stars := UiKit.hbox(4)
	stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(stars)
	for index in 3:
		var lit := index < task.stars()
		stars.add_child(UiIcon.make("star" if lit else "star_off", 30, UiKit.AMBER if lit else Color(UiKit.TEXT, 0.35)))
	var score_row := UiKit.hbox(10)
	column.add_child(score_row)
	var score_label := UiKit.label("%d / 100" % task.score(), 18, UiKit.TEXT, UiKit.heading_font())
	score_label.name = "Score"
	score_row.add_child(score_label)
	if not reward.is_empty():
		var reward_label := UiKit.label(reward, 13, UiKit.AMBER, UiKit.heavy_font())
		reward_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		score_row.add_child(reward_label)
	var notes := _note_list(column)
	for note in task.notes().slice(0, 4):
		var row := UiKit.hbox(8)
		notes.add_child(row)
		var ok := bool(note["ok"])
		var icon := UiIcon.make("check" if ok else "cross", 18, UiKit.MINT if ok else UiKit.CORAL)
		icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(icon)
		var text := UiKit.label(str(note["text"]), 13, Color("#DCEDEA"))
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(UiKit.px(400), 0)
		row.add_child(text)
	var buttons := UiKit.hbox(10)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(buttons)
	var again := UiKit.ghost_button("Try again", 44, 15)
	again.name = "TryAgain"
	again.pressed.connect(func() -> void: retry_pressed.emit())
	again.visible = can_retry
	buttons.add_child(again)
	var done := UiKit.primary_button(done_text, 44, 16)
	done.name = "Done"
	done.pressed.connect(func() -> void: done_pressed.emit())
	buttons.add_child(done)
	_fit_notes(notes, UiKit.px(400), 13)
	_header.visible = false
	_leave.visible = false
	_hide_controls()
	_refresh()
	UiKit.pop_in(_result)
	var lit_stars: Array[Control] = []
	for index in task.stars():
		lit_stars.append(stars.get_child(index) as Control)
	UiKit.pop_one_by_one(lit_stars, 0.35)
	Sfx.play(self, "chime" if task.stars() >= 2 else "buzz", -8.0)


## Views hide their own controls behind the score card.
func _hide_controls() -> void:
	pass


## A card of notes under the header (the exam and history views), or null.
func _side_card() -> Control:
	return null


## The score card's notes, in a list that scrolls when the card would be
## taller than the screen (big text on a small phone).
func _note_list(column: VBoxContainer) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "Notes"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := UiKit.vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return list


## Gives the notes the height they need, or whatever the screen has left.
func _fit_notes(list: VBoxContainer, width: float, text_size: float) -> void:
	var needed := 0.0
	for row in list.get_children():
		needed += UiKit.wrapped_height((row.get_child(1) as Label).text, width, text_size)
	needed += list.get_theme_constant("separation") * maxi(0, list.get_child_count() - 1)
	var room := UiKit.safe_insets()
	var left := get_viewport_rect().size.y - UiKit.px(24) - room.y - room.z - _result.get_combined_minimum_size().y
	(list.get_parent() as ScrollContainer).custom_minimum_size.y = minf(needed, maxf(left, UiKit.px(60)))


## A tap on the 3D scene (not on a panel): views that pick things in the
## station (a vein, an instrument, a spot on the pad) override this.
func world_tap(_screen_point: Vector2) -> void:
	pass


## A drag across the 3D scene, in screen pixels.
func world_drag(_relative: Vector2) -> void:
	pass


## A finger going down on the 3D scene, moving, and lifting (for strokes).
func world_press(_screen_point: Vector2) -> void:
	pass


func world_move(_screen_point: Vector2) -> void:
	pass


func world_release(_screen_point: Vector2) -> void:
	pass


## The small line over the task's title.
func _kicker_text() -> String:
	return "Skills lab · " + _trainer_name()


## The coach line on show and whether it warns: the trainer's, unless a
## view shows someone else (a patient answering).
func _coach_line() -> Array:
	return [task.coach, task.coach_warns]


func station() -> LabStation:
	if lab != null and lab.has_method("station_for"):
		return lab.station_for(task.id)
	return null


func view_camera() -> Camera3D:
	if lab != null and "camera" in lab:
		return lab.camera
	return null


## A dark panel on the right, under the Leave button.
func _right_panel(width: float, top: float = 62.0) -> PanelContainer:
	var made := UiKit.panel(Color(7 / 255.0, 32 / 255.0, 37 / 255.0, 0.9), 16, Vector2(12, 12))
	made.anchor_left = 1.0
	made.anchor_right = 1.0
	made.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	made.offset_right = -UiKit.px(12)
	made.offset_left = -UiKit.px(12 + width)
	made.offset_top = UiKit.px(top)
	made.custom_minimum_size = Vector2(UiKit.px(width), 0)
	add_child(made)
	return made


## A compact outlined button for task controls.
static func small_button(text: String, height: float = 34, size: float = 13) -> Button:
	var made := UiKit.ghost_button(text, height, size)
	for state in ["normal", "hover", "focus", "disabled", "pressed", "hover_pressed"]:
		var style := made.get_theme_stylebox(state) as StyleBoxFlat
		if style != null:
			var copy := style.duplicate() as StyleBoxFlat
			copy.content_margin_left = UiKit.px(6)
			copy.content_margin_right = UiKit.px(6)
			made.add_theme_stylebox_override(state, copy)
	made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return made


func _trainer_name() -> String:
	return str(StoryBook.cast().get(trainer, {}).get("name", trainer.capitalize()))


func _build_header() -> void:
	_header = UiKit.panel(UiKit.PANEL, 16, Vector2(14, 10))
	_header.name = "Header"
	_header.position = Vector2(UiKit.px(12), UiKit.px(12))
	_header.custom_minimum_size = Vector2(UiKit.px(300), 0)
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_header)
	var column := UiKit.vbox(5)
	_header.add_child(column)
	column.add_child(UiKit.kicker(kicker_override if not kicker_override.is_empty() else _kicker_text()))
	_title = UiKit.label(task.title() if task != null else "", 17, UiKit.TEXT, UiKit.heading_font())
	column.add_child(_title)
	_instruction = UiKit.label("", 13, Color("#DCEDEA"), UiKit.heavy_font())
	_instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_instruction.custom_minimum_size = Vector2(UiKit.px(272), 0)
	column.add_child(_instruction)
	_progress_track = Control.new()
	_progress_track.custom_minimum_size = Vector2(0, UiKit.px(6))
	column.add_child(_progress_track)
	var back := ColorRect.new()
	back.color = Color(1, 1, 1, 0.14)
	UiKit.fill(back)
	_progress_track.add_child(back)
	_progress_fill = ColorRect.new()
	_progress_fill.color = UiKit.MINT
	UiKit.fill(_progress_fill)
	_progress_fill.anchor_right = 0.0
	_progress_track.add_child(_progress_fill)


func _build_coach() -> void:
	_coach_box = UiKit.panel(Color(7 / 255.0, 32 / 255.0, 37 / 255.0, 0.92), 16, Vector2(16, 12))
	_coach_box.name = "Coach"
	_coach_box.anchor_top = 1.0
	_coach_box.anchor_bottom = 1.0
	_coach_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_coach_box.offset_left = UiKit.px(12)
	_coach_box.offset_bottom = -UiKit.px(12)
	# Narrower by the notch on each side, so it stays clear of the right panels.
	var narrower := 2.0 * UiKit.safe_insets().x
	_coach_box.custom_minimum_size = Vector2(UiKit.px(430) - narrower, UiKit.px(74))
	_coach_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_coach_box)
	var column := UiKit.vbox(4)
	_coach_box.add_child(column)
	_coach_name = UiKit.label("", 12, UiKit.AMBER, UiKit.heavy_font())
	column.add_child(_coach_name)
	_coach_text = UiKit.label("", 15, UiKit.TEXT, UiKit.heavy_font())
	_coach_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coach_text.custom_minimum_size = Vector2(UiKit.px(398) - narrower, 0)
	column.add_child(_coach_text)


func _build_leave() -> void:
	_leave = UiKit.ghost_button("Leave", 40, 14)
	_leave.name = "Leave"
	_leave.anchor_left = 1.0
	_leave.anchor_right = 1.0
	_leave.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_leave.offset_right = -UiKit.px(12)
	_leave.offset_top = UiKit.px(12)
	_leave.pressed.connect(func() -> void: leave_pressed.emit())
	add_child(_leave)


func _refresh() -> void:
	if task == null or _title == null:
		return
	_instruction.text = task.instruction()
	# Anchored, so the bar is right even before the panel has its size.
	_progress_fill.anchor_right = clampf(task.progress(), 0.0, 1.0)
	var name_text := speaker_override if not speaker_override.is_empty() else _trainer_name()
	_coach_name.text = name_text.to_upper()
	var line := _coach_line()
	if str(line[0]) != _shown_coach:
		_shown_coach = str(line[0])
		_coach_text.text = _shown_coach
		_coach_text.add_theme_color_override("font_color", Color("#FFC9B8") if bool(line[1]) else UiKit.TEXT)
		_typed = 0.0
		_coach_text.visible_characters = 0
		_coach_heard = false
		if _shown_coach.is_empty():
			_coach_voice.stop()
		else:
			_coach_heard = _coach_voice.start(_shown_coach, voice_id())
	# With big text the case notes can reach down to the coach line, which
	# then steps aside (the notes already hold what was found).
	var card := _side_card()
	var crowded := card != null and card.visible and card.position.y + card.size.y > _coach_box.position.y - UiKit.px(6)
	_coach_box.visible = not _shown_coach.is_empty() and not result_open() and not crowded


## Who reads the coach line aloud: the trainer, or the patient speaking.
func voice_id() -> String:
	return voice_override if not voice_override.is_empty() else trainer


## The voice for the coach line (for tests).
func coach_voice() -> SpokenLine:
	return _coach_voice


func _type_coach(delta: float) -> void:
	if _coach_text == null:
		return
	var voiced := _coach_heard and not _coach_voice.failed
	if _typed >= _shown_coach.length():
		if _coach_voice.speaking:
			_coach_voice.advance(delta, _typed)
		_set_trainer_talking(voiced and _coach_voice.speaking)
		return
	var before := int(_typed)
	if voiced:
		# The words appear as the voice says them.
		var target := _coach_voice.advance(delta, _typed)
		voiced = not _coach_voice.failed
		if voiced:
			_typed = minf(move_toward(_typed, target, delta * SpokenLine.REVEAL_SPEED), _shown_coach.length())
	if not voiced:
		_typed = minf(_typed + delta * TYPE_SPEED, _shown_coach.length())
	_coach_text.visible_characters = int(_typed)
	_since_syllable += delta
	for index in range(before, int(_typed)):
		var letter := _shown_coach[index].to_lower()
		if letter in "aeiou" and (index == 0 or _shown_coach[index - 1].to_lower() not in "aeiou") \
				and _since_syllable >= 0.08:
			_since_syllable = 0.0
			_trainer_syllable(letter, not voiced)
	_set_trainer_talking(_typed < _shown_coach.length())


func _exit_tree() -> void:
	_coach_voice.stop()


func _speaking_rig() -> AvatarRig:
	if lab != null and lab.has_method("rig_for"):
		return lab.rig_for(voice_id())
	return null


func _trainer_syllable(letter: String, with_voice: bool = true) -> void:
	var rig := _speaking_rig()
	if rig != null:
		rig.say_syllable(letter, with_voice)


func _set_trainer_talking(on: bool) -> void:
	var rig := _speaking_rig()
	if rig != null:
		rig.talking = on
