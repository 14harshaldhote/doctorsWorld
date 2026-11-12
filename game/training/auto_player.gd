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
		"exam":
			_exam(view as ExamView)
		"scan":
			_scan(view as ScanView)
		_:
			if view is OperationView:
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


## Examines like a careful doctor: a bleed first, then gentle places
## before sore ones, every finding that matters, then the right answer.
## "shaky" presses the sore spot first and skips one finding; "bad" also
## wastes time and picks a wrong answer.
func _exam(view: ExamView) -> void:
	if not _act():
		return
	var exam := view.task as ExamTask
	if exam.phase == "decide":
		var pick := exam.right_diagnosis()
		if quality == "bad":
			for entry in exam.diagnoses:
				if not bool(entry.get("right", false)):
					pick = str(entry.get("id", ""))
					break
		view.decide(pick)
		return
	var order: Array[String] = []
	for entry in exam.spots:
		if str(entry.get("act", "")) == "pressure":
			order.append(str(entry.get("id", "")))
	var sore_first := quality != "good"
	for pass_name: String in ["first", "gentle", "key", "useful", "none"]:
		for entry in exam.spots:
			var spot_id := str(entry.get("id", ""))
			if spot_id in order:
				continue
			var weight := str(entry.get("weight", ""))
			var take := false
			match pass_name:
				"first":
					take = sore_first and bool(entry.get("sore", false))
				"gentle":
					take = bool(entry.get("gentle", false))
				"key":
					take = weight == "key"
				"useful":
					take = weight == "useful" and quality == "good"
				"none":
					take = weight == "none" and quality == "bad"
			if take:
				order.append(spot_id)
	if quality != "good":
		# Misses the last finding that matters.
		for index in range(order.size() - 1, -1, -1):
			if str(exam.spot(order[index]).get("weight", "")) == "key" and str(exam.spot(order[index]).get("act", "")) == "":
				order.remove_at(index)
				break
	for spot_id in order:
		if not exam.is_examined(spot_id):
			# Taps the patient's body where the spot is, like a finger.
			var point: Variant = view.spot_point(spot_id)
			var cam := view.view_camera()
			if point != null and cam != null and view.spot_at(cam.unproject_position(point as Vector3)) == spot_id:
				view.world_tap(cam.unproject_position(point as Vector3))
			else:
				view.examine(spot_id)
			return
	view.ready_to_decide()


## Reads the film: zoom in on the object, the side view, a moment's
## thought, then the answer. "bad" answers from the front view alone.
func _scan(view: ScanView) -> void:
	if not _act():
		return
	var scan := view.task as ScanTask
	if quality == "bad":
		view.answer("coin" if scan.right_answer() != "coin" else "battery")
		return
	if not scan.looked_zoom:
		if scan.view != "front":
			view.show_view("front")
		elif not scan.zoomed:
			view.zoom()
		return
	if not scan.looked_side:
		view.show_view("side")
		return
	if scan.elapsed < 4.5:
		return
	view.answer(scan.right_answer())


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
			var wrong := op.wrong_options()
			var answer := op.right_option()
			if quality == "bad" and not wrong.is_empty():
				answer = str(wrong[mini(1, wrong.size() - 1)])
			elif quality == "shaky" and tries == 0 and not wrong.is_empty():
				answer = str(wrong[0])
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
		var tray: Array = op.procedure.get("tray", Instruments.ALL)
		var others: Array = tray.filter(func(item: String) -> bool:
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
			var traps: Dictionary = op._data(op.step).get("traps", {})
			var slip := str(traps.keys()[0]) if not traps.is_empty() else "bowel"
			_tap_target(view, op, slip if miss else op.target)
		"fill":
			var aim := 13.5
			if quality == "bad":
				aim = 18.0
			elif quality == "shaky" and op.fill_tries == 0:
				aim = 9.0
			if not op.holding:
				if _act():
					view.hold()
				return
			if op.fill_level >= aim:
				view.release()
		"stitch":
			if not _act():
				return
			var full := op.stitch_target()
			var wanted := {"good": full, "shaky": maxi(2, full - 2), "bad": maxi(2, full - 3)}
			var count := int(wanted.get(quality, full))
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
