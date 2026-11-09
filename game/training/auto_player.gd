class_name AutoPlayer
extends RefCounted
## Plays a training task well, through its screen, the way a careful player
## would: in order, unhurried, aiming properly. Things in the 3D station (a
## vein, an instrument on the tray, a spot on the pad) are tapped on screen
## like a real finger would, so the picking is tested too.
##
## Used by the tests' play-through of every station and by the screenshot
## tool to reach a moment in the middle of a task.

## Seconds between actions, so a watched run looks like play.
var pace := 0.3
## How many stitches to place along the cut.
var stitch_count := 10
var _wait := 0.2


## One frame of play. Call before the view's tick().
func step(view: TrainingView, delta: float) -> void:
	if view.task == null or view.task.finished or view.result_open():
		return
	_wait -= delta
	match view.task.id:
		"scrub":
			_scrub(view as ScrubView)
		"monitor":
			_monitor(view as MonitorView)
		"history":
			_history(view as HistoryView)
		"instruments":
			_instruments(view as InstrumentView)
		"iv":
			_iv(view as IvView)
		"stitch":
			_stitch(view as StitchView)


func _act() -> bool:
	if _wait > 0.0:
		return false
	_wait = pace
	return true


func _scrub(view: ScrubView) -> void:
	var scrub := view.task as ScrubTask
	if scrub.stage == 2:
		var next := scrub.next_expected()
		if next == "rinse":
			if not view.holding.is_empty():
				view.release()
				_wait = pace
			elif _act():
				view.press("rinse")
			return
		if view.holding == next:
			return
		if not view.holding.is_empty():
			view.release()
			_wait = pace * 0.5
			return
		if _act():
			view.hold(next)
		return
	if _act():
		view.press(scrub.next_expected())


func _monitor(view: MonitorView) -> void:
	var monitor := view.task as MonitorTask
	if monitor.phase == "learn":
		if not _act():
			return
		for kind: String in Vitals.KINDS:
			if kind not in monitor.learned:
				view.pick(kind)
				return
		view.show_patients()
	elif monitor.phase == "quiz" and not monitor.revealing:
		# A second to read the screen, then answer.
		if monitor.time_left > MonitorTask.ROUND_TIME - 1.0:
			return
		var right := monitor.answer_now()
		if right == "none":
			view.all_fine()
		else:
			view.pick(right)


func _history(view: HistoryView) -> void:
	if not _act():
		return
	var history := view.task as HistoryTask
	for weight: String in ["key", "useful"]:
		for entry in history.questions:
			var question_id := str(entry.get("id", ""))
			if str(entry.get("weight", "")) == weight and not history.is_asked(question_id):
				view.ask(question_id)
				return
	view.done_asking()


func _instruments(view: InstrumentView) -> void:
	var tray := view.task as InstrumentTask
	if tray.revealing:
		# A moment to read the next one.
		_wait = pace * 2.5
		return
	if not _act():
		return
	if tray.part == "call":
		var button := view.ring.button_for(tray.wanted)
		if button != null:
			button.pressed.emit()
			return
	var trolley := view.station() as InstrumentTrolley
	var camera := view.view_camera()
	if trolley != null and camera != null:
		var point := camera.unproject_position(trolley.instrument_point(tray.wanted))
		if trolley.instrument_at(camera, point) == tray.wanted:
			view.world_tap(point)
			return
	view.pick(tray.wanted)


func _iv(view: IvView) -> void:
	var iv := view.task as IvTask
	match iv.phase:
		"vein":
			if not _act():
				return
			var arm := view.station() as ArmPad
			var camera := view.view_camera()
			if arm != null and camera != null:
				var point := camera.unproject_position(arm.vein_point("forearm"))
				if arm.vein_at(camera, point) == "forearm":
					view.world_tap(point)
					return
			view.pick_vein("forearm")
		"angle":
			if not _act():
				return
			if absf(iv.angle - 22.0) > 0.5:
				view.set_angle(22.0)
			else:
				view.insert()
		"steady":
			# Push back against the wobble every frame.
			view.drag(-iv.offset * UiKit.px(IvView.PIXELS_PER_MM) * 0.5)


func _stitch(view: StitchView) -> void:
	if not _act():
		return
	var stitch := view.task as StitchTask
	if stitch.stitches.size() >= stitch_count:
		view.tie_off()
		return
	var t := 0.05 + 0.9 * stitch.stitches.size() / (stitch_count - 1.0)
	var target := stitch.point_at(t)
	var pad := view.station() as SuturePad
	var camera := view.view_camera()
	if pad != null and camera != null:
		var point := camera.unproject_position(pad.pad_point_world(target))
		var found: Variant = pad.pad_point(camera, point)
		if found != null and (found as Vector2).distance_to(target) < 0.3:
			view.world_tap(point)
			return
	view.place(target)
