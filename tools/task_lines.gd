extends SceneTree
## Lists every line the skills lab's stations can say, by who says it, for
## tools/make_voices.py (tools/task_lines.json). Each station's task is
## played down every branch: every step tried too early, every order of
## scrubbing, every vital at every answer, every instrument, every needle
## angle, every number of stitches. So each coaching line is recorded whole
## and acted, like the story, instead of being stitched around a number or
## read by the phone's voice.
##
##   godot --headless --path . -s res://tools/task_lines.gd
##
## tests/unit/test_task_voices.gd checks that every line has a recording.

const OUT := "res://tools/task_lines.json"
## Who coaches each station: the skills lab's trainers (TrainingTask.TRAINERS,
## which the drills use too), and Tom at the theatre's scrub sink. The
## history station is left out: its lines are the patient's answers, which
## make_voices.py takes from story/cases.json.
const VOICES := {
	"scrub": ["grace", "tom"],
	"monitor": ["iyer"],
	"instruments": ["tom"],
	"iv": ["grace"],
	"stitch": ["iyer"],
}


func _init() -> void:
	var lines := collect()
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(lines, "\t") + "\n")
	file.close()
	print("Wrote %d lines to %s" % [lines.size(), OUT])
	quit()


## [{who, text}] for every line, sorted.
static func collect() -> Array:
	var found := {}
	for station: String in VOICES:
		for text: String in station_lines(station):
			for who: String in VOICES[station]:
				found[who + "\t" + text] = true
	var keys := found.keys()
	keys.sort()
	var lines := []
	for key: String in keys:
		var parts := key.split("\t", true, 1)
		lines.append({"who": parts[0], "text": parts[1]})
	return lines


## Every line one station's coach can say, sorted.
static func station_lines(station: String) -> Array:
	var said := {}
	match station:
		"scrub":
			_scrub(said)
		"monitor":
			_monitor(said)
		"instruments":
			_instruments(said)
		"iv":
			_iv(said)
		"stitch":
			_stitch(said)
	var lines := said.keys()
	lines.sort()
	return lines


## Notes each line the task's coach says from now on (and the one already said).
static func _listen(task: TrainingTask, said: Dictionary) -> void:
	var note := func() -> void:
		if not task.coach.is_empty():
			said[task.coach] = true
	task.changed.connect(note)
	note.call()


# --- Scrub in ------------------------------------------------------------------

static func _scrub(said: Dictionary) -> void:
	var all_steps: Array = ScrubTask.STEPS + ScrubTask.AREAS + ScrubTask.TRAPS
	# Every step tried at every point of a clean scrub.
	var clean := ["water", "soap", "scrubbed", "rinse", "towel", "gown", "gloves"]
	for length in clean.size() + 1:
		for step: String in all_steps:
			var task := _scrub_task(said, clean.slice(0, length))
			task.do_step(step)
	# Each part finished at every point of the scrub (each order of the six
	# turned round, so every part comes first, second and so on).
	for turn in ScrubTask.AREAS.size():
		var task := _scrub_task(said, ["water", "soap"])
		for index in ScrubTask.AREAS.size():
			var area: String = ScrubTask.AREAS[(index + turn) % ScrubTask.AREAS.size()]
			task.scrub(area, ScrubTask.SCRUB_TIME)
	# Rinsing with any parts left out.
	for mask in 1 << ScrubTask.AREAS.size():
		var task := _scrub_task(said, ["water", "soap"])
		for index in ScrubTask.AREAS.size():
			if mask & (1 << index):
				task.scrub(ScrubTask.AREAS[index], ScrubTask.SCRUB_TIME)
		task.do_step("rinse")


## A scrub played up to a point: "scrubbed" means all six parts done.
static func _scrub_task(said: Dictionary, steps: Array) -> ScrubTask:
	var task := ScrubTask.new()
	_listen(task, said)
	for step: String in steps:
		if step == "scrubbed":
			for area: String in ScrubTask.AREAS:
				task.scrub(area, ScrubTask.SCRUB_TIME)
		else:
			task.do_step(step)
	return task


# --- Read the monitor ----------------------------------------------------------

static func _monitor(said: Dictionary) -> void:
	# Learning each number, first or last.
	for last: String in Vitals.KINDS:
		var task := MonitorTask.new(1)
		_listen(task, said)
		for kind: String in Vitals.KINDS:
			if kind != last:
				task.learn(kind)
		task.learn(last)
		task.learn(last)
	# Every screen (all fine, or each number too high or too low) with every
	# answer, and with no answer in time.
	var rng := SeededRandom.new(5)
	var screens: Array[Vitals] = [Vitals.healthy(rng)]
	for kind: String in Vitals.KINDS:
		for direction: String in ["high", "low"]:
			screens.append(Vitals.with_problem(rng, kind, direction))
	for screen: Vitals in screens:
		for answer: String in Vitals.KINDS + ["none", ""]:
			var task := _monitor_quiz(said)
			task.vitals = screen
			if answer.is_empty():
				task.time_left = 0.01
				task.tick(0.05)
			else:
				task.answer(answer)
	# A whole quiz played through, for anything said on the way out.
	var whole := _monitor_quiz(said)
	for round_index in MonitorTask.ROUNDS + 1:
		whole.answer(whole.answer_now())
		whole.tick(MonitorTask.REVEAL_TIME + 0.1)


static func _monitor_quiz(said: Dictionary) -> MonitorTask:
	var task := MonitorTask.new(1)
	for kind: String in Vitals.KINDS:
		task.learn(kind)
	task.start_quiz()
	_listen(task, said)
	return task


# --- Know your instruments -----------------------------------------------------

static func _instruments(said: Dictionary) -> void:
	for wanted: String in Instruments.ALL:
		for part: String in ["match", "call"]:
			# Right first time, then each wrong one (three wrong in a row in
			# the matching part shows the right one).
			var right := _instrument_round(said, part, wanted)
			right.pick(wanted)
			for other: String in Instruments.ALL:
				if other == wanted:
					continue
				var task := _instrument_round(said, part, wanted)
				for attempt in InstrumentTask.MATCH_TRIES:
					task.pick(other)
			if part == "call":
				var slow := _instrument_round(said, part, wanted)
				slow.time_left = 0.01
				slow.tick(0.05)
	# A whole tray played through, for the lines between the parts.
	var whole := InstrumentTask.new(1)
	_listen(whole, said)
	for step in InstrumentTask.MATCH_ROUNDS + InstrumentTask.CALL_ROUNDS + 1:
		whole.pick(whole.wanted)
		whole.tick(InstrumentTask.REVEAL_TIME + 0.1)


## A fresh round of the given part, asking for one instrument.
static func _instrument_round(said: Dictionary, part: String, wanted: String) -> InstrumentTask:
	var task := InstrumentTask.new(1)
	task.part = part
	task.wanted = wanted
	task.time_left = InstrumentTask.CALL_TIME
	_listen(task, said)
	return task


# --- IV line -------------------------------------------------------------------

static func _iv(said: Dictionary) -> void:
	for vein: String in IvTask.VEINS:
		# Every angle the slider can give, in half degrees.
		for half in 121:
			var task := IvTask.new(1)
			_listen(task, said)
			task.pick_vein(vein)
			task.set_angle(half * 0.5)
			task.insert()
	# Held steady all the way, part of the way, or not at all.
	for held: float in [1.0, 0.6, 0.0]:
		var task := IvTask.new(1)
		_listen(task, said)
		task.pick_vein("forearm")
		task.set_angle(IvTask.BEST_ANGLE)
		task.insert()
		var step := 1.0 / 30.0
		while not task.finished:
			task.tick(step)
			if task.steady_time < IvTask.STEADY_TIME * held:
				task.nudge(-task.offset)


# --- Stitching -----------------------------------------------------------------

static func _stitch(said: Dictionary) -> void:
	# A miss, and one stitch crowding another.
	var task := StitchTask.new()
	_listen(task, said)
	task.place(Vector2(0.5, 0.5))
	task.place(task.point_at(0.5))
	task.place(task.point_at(0.505))
	# Every count up to a full line, evenly spaced, tied off at each count,
	# bunched at one end, and off the line (so every ending is reached).
	for count in range(1, StitchTask.MAX_STITCHES + 1):
		for spread: float in [1.0, 0.5, 0.25]:
			for off: float in [0.0, 0.7]:
				var stitched := StitchTask.new()
				_listen(stitched, said)
				for index in count:
					var along := 0.04 + 0.92 * spread * (float(index) / maxf(1.0, count - 1))
					var side := stitched.direction_at(along).orthogonal() * off
					stitched.place(stitched.point_at(along) + side)
				stitched.tie_off()
