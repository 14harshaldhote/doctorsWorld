class_name MonitorView
extends TrainingView
## Read the monitor: a big patient monitor on the right. First the player
## taps each number to learn it, then six patients come up one after another
## and the player taps the number that is wrong, or "All fine", before the
## time runs out. Out-of-range numbers don't turn red here: that's the test.

var monitor: VitalsMonitor
var _column: VBoxContainer
var _start: Button
var _fine: Button
var _shown_round := -2


func _build() -> void:
	_column = UiKit.vbox(8)
	_column.name = "Controls"
	_column.anchor_left = 1.0
	_column.anchor_right = 1.0
	_column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_column.offset_right = -UiKit.px(12)
	_column.offset_left = -UiKit.px(12 + 360)
	_column.offset_top = UiKit.px(62)
	add_child(_column)
	monitor = VitalsMonitor.new()
	monitor.name = "Monitor"
	monitor.custom_minimum_size = Vector2(UiKit.px(360), UiKit.px(250))
	monitor.picked.connect(pick)
	_column.add_child(monitor)
	var row := UiKit.hbox(8)
	_column.add_child(row)
	_fine = UiKit.ghost_button("All fine", 44, 16)
	_fine.name = "AllFine"
	_fine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fine.pressed.connect(all_fine)
	row.add_child(_fine)
	_start = UiKit.primary_button("Show me patients", 44, 16)
	_start.name = "Start"
	_start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start.pressed.connect(show_patients)
	row.add_child(_start)
	_sync()


func _monitor() -> MonitorTask:
	return task as MonitorTask


## A tap on one of the four numbers.
func pick(kind: String) -> void:
	if result_open():
		return
	var current := _monitor()
	if current.phase == "learn":
		current.learn(kind)
	elif current.phase == "quiz":
		current.answer(kind)
	_sync()


func all_fine() -> void:
	if not result_open() and _monitor().phase == "quiz":
		_monitor().answer("none")
		_sync()


func show_patients() -> void:
	if not result_open():
		_monitor().start_quiz()
		_sync()


func _tick(delta: float) -> void:
	monitor.tick(delta)
	_sync()


func _sync() -> void:
	var current := _monitor()
	if current == null or monitor == null:
		return
	monitor.set_vitals(current.vitals)
	monitor.show_alarms = current.phase == "learn"
	_start.visible = current.phase == "learn"
	_start.disabled = current.learned.size() < Vitals.KINDS.size()
	_fine.visible = current.phase != "learn"
	_fine.disabled = current.phase != "quiz" or current.revealing
	if current.round_index != _shown_round:
		_shown_round = current.round_index
		monitor.marks = {}
	match current.phase:
		"learn":
			for kind: String in current.learned:
				monitor.marks[kind] = "seen"
			monitor.status = ""
		"quiz":
			if current.revealing:
				var right := current.answer_now()
				monitor.marks = {}
				if right != "none":
					monitor.marks[right] = "right" if current.picked == right else "answer"
				if current.picked != right and current.picked != "none" and not current.picked.is_empty():
					monitor.marks[current.picked] = "wrong"
				monitor.status = "RIGHT" if current.picked == right else "MISSED"
				monitor.status_colour = VitalsMonitor.RIGHT if current.picked == right else VitalsMonitor.WRONG
			else:
				monitor.status = "PATIENT %d · %d s" % [current.round_index + 1, ceili(current.time_left)]
				monitor.status_colour = UiKit.AMBER if current.time_left > 3.0 else VitalsMonitor.ALARM
		_:
			monitor.status = ""
	monitor.queue_redraw()


func _hide_controls() -> void:
	_column.visible = false
