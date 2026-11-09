class_name AutoPlayer
extends RefCounted
## Plays a training task well, through its screen, the way a careful player
## would: in order, unhurried, aiming properly. Things in the 3D station (a
## vein, an instrument on the tray, a spot on the pad) are tapped on screen
## like a real finger would, so the picking is tested too.
##
## Operations can also be played badly on purpose: quality "shaky" is slow
## and makes a few mistakes, "bad" makes every mistake there is.
##
## Used by the tests' play-through of every station and by the screenshot
## tool to reach a moment in the middle of a task.

## Seconds between actions, so a watched run looks like play.
var pace := 0.3
## How many stitches to place along the cut.
var stitch_count := 10
## How well operations are played: "good", "shaky" or "bad".
var quality := "good"
var _wait := 0.2
## What the robot has already done in each moment of an operation.
var _done := {}
var _trace_t := -1.0


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
		"appendix":
			_operation(view as OperationView, delta)


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


# --- Operations -----------------------------------------------------------

func _operation(view: OperationView, delta: float) -> void:
	var op := view.task as OperationTask
	if op.busy():
		return
	match op.phase:
		"timeout":
			if _act():
				var line := op.timeout_line()
				view.answer(str(line["right"]) if quality == "good" else "confirm")
		"call":
			_op_call(view, op)
		"act":
			_op_act(view, op, delta)
		"decide":
			if not _act():
				return
			var key := "decide" + op.step
			var tries := int(_done.get(key, 0))
			_done[key] = tries + 1
			var wrong := {"pressure": ["carry_on", "deeper"], "reaction": ["fluids", "carry_on"]}
			var answer := op.right_option()
			if quality == "bad":
				answer = str(wrong[op.step][1])
			elif quality == "shaky" and tries == 0:
				answer = str(wrong[op.step][0])
			view.answer(answer)
		"count":
			if not _act():
				return
			var tries := int(_done.get("count", 0))
			_done["count"] = tries + 1
			var missing := op.swab_missing and not op.swab_found
			if quality == "bad":
				view.answer("close")
			elif quality == "shaky" and tries == 0:
				view.answer("recount")
			else:
				view.answer("look" if missing else "close")
		"search":
			if _act():
				var tries := int(_done.get("search", 0))
				_done["search"] = tries + 1
				_tap_target(view, op, "bowel" if quality == "bad" and tries < 2 else "swab")


func _op_call(view: OperationView, op: OperationTask) -> void:
	var key := "call%s%d" % [op.step, op.calls]
	var wrong_picks := int(_done.get(key, 0))
	match quality:
		"shaky":
			if op.call_time < 2.2 or not _act():
				return
		"bad":
			if op.call_time < 1.0 or not _act():
				return
		_:
			if not _act():
				return
	var pick := op.wanted
	if (quality == "shaky" and wrong_picks == 0) or quality == "bad":
		var others: Array = Instruments.ALL.filter(func(item: String) -> bool:
			return item != op.wanted and item not in ["suction", "swab"])
		pick = str(others[(wrong_picks + op.calls) % others.size()])
	_done[key] = wrong_picks + 1
	var button := view.ring.button_for(pick)
	if button != null and view.ring.visible:
		button.pressed.emit()
	else:
		view.call_for(pick)


func _op_act(view: OperationView, op: OperationTask, delta: float) -> void:
	var key := "act%s%d" % [op.step, op.calls]
	var tries := int(_done.get(key, 0))
	match op.action:
		"trace":
			_op_trace(view, op, delta)
		"hold":
			if not op.holding:
				if _act():
					view.hold()
				return
			var early := (quality == "shaky" and tries < 1) or (quality == "bad" and tries < 3)
			if early and op.hold_time >= 0.9:
				_done[key] = tries + 1
				view.release()
		"tap":
			if not _act():
				return
			_done[key] = tries + 1
			var miss := (quality == "shaky" and tries == 0 and op.step == "find") or (quality == "bad" and tries < 4)
			_tap_target(view, op, "bowel" if miss else op.target)
		"stitch":
			if not _act():
				return
			var wanted := {"good": 6, "shaky": 4, "bad": 3}
			var count := int(wanted.get(quality, 6))
			if op.stitches.size() >= count:
				view.tie_off()
				return
			var t := 0.08 + 0.84 * op.stitches.size() / maxf(1.0, count - 1.0)
			var spot := op.guide_point(t)
			if quality != "good":
				spot += op.guide_direction(t).orthogonal() * (0.45 if op.stitches.size() % 2 == 0 else -0.3)
			_tap_skin(view, op, spot)


## Draws the incision over a second or so, wobbling with quality.
func _op_trace(view: OperationView, op: OperationTask, delta: float) -> void:
	var wobble := {"good": 0.12, "shaky": 0.55, "bad": 1.1}
	var reach := 1.0 if quality == "good" else (0.92 if quality == "shaky" else 0.75)
	if not op.tracing:
		if not _act():
			return
		_trace_t = 0.0
		var start := _trace_spot(op, 0.0, float(wobble[quality]))
		var point: Variant = _skin_screen(view, start)
		if point != null:
			view.world_press(point)
		if not op.tracing:
			op.trace_begin(start)
		return
	_trace_t = minf(reach, _trace_t + delta * 1.1)
	var spot := _trace_spot(op, _trace_t, float(wobble[quality]))
	var screen: Variant = _skin_screen(view, spot)
	var before := op.trace.size()
	if screen != null:
		view.world_move(screen)
	if op.trace.size() == before:
		op.trace_to(spot)
	if _trace_t >= reach:
		view.world_release(Vector2.ZERO)
		_wait = pace


func _trace_spot(op: OperationTask, t: float, wobble: float) -> Vector2:
	return op.guide_point(t) + op.guide_direction(t).orthogonal() * wobble * sin(t * 9.0)


func _skin_screen(view: OperationView, spot: Vector2) -> Variant:
	var table := view.station() as OperatingTable
	var camera := view.view_camera()
	if table == null or camera == null:
		return null
	var point := camera.unproject_position(table.skin_world(spot))
	var back: Variant = table.skin_point(camera, point)
	if back == null or (back as Vector2).distance_to(spot) > 0.3:
		return null
	return point


func _tap_skin(view: OperationView, op: OperationTask, spot: Vector2) -> void:
	var point: Variant = _skin_screen(view, spot)
	if point != null:
		view.world_tap(point)
	else:
		op.place_stitch(spot)


func _tap_target(view: OperationView, op: OperationTask, which: String) -> void:
	var table := view.station() as OperatingTable
	var camera := view.view_camera()
	if table != null and camera != null:
		var point := camera.unproject_position(table.target_point(which))
		if table.target_at(camera, point, op) == which:
			view.world_tap(point)
			return
	op.tap(which)
