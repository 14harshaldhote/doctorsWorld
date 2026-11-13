extends "res://tests/run_tests.gd"
## Lists every line the game asks to be read aloud, by who says it, for
## tools/make_voices.py. It runs the whole test suite (which plays the
## story, every station and every operation, well and badly) while Speech
## notes each line, then writes them as JSON:
##
##   godot --headless --path . -s res://tools/voice_lines.gd -- OUT.json
##
## Story lines are also read straight from story/*.json by make_voices.py,
## so lines the tests never reach are still voiced. After the tests it
## plays every operation again, well, shakily and badly, as several
## doctors (each name rolls different cases), to catch the rarer lines.

## Different names roll different difficulties and complications.
const NAMES := ["Asha Verma", "Kiran Rao", "Mei Lin", "Kofi Mensah", "Ravi Das", "Nila Joseph"]
const QUALITIES := ["good", "shaky", "bad"]


func _run_all() -> void:
	Speech.listening = true
	super()
	_extra_runs()
	var out := ""
	for argument in OS.get_cmdline_user_args():
		if argument.ends_with(".json"):
			out = argument
	var lines := []
	var keys := Speech.heard.keys()
	keys.sort()
	for key: String in keys:
		var parts := key.split("\t", true, 1)
		lines.append({"who": parts[0], "text": parts[1]})
	var file := FileAccess.open(out if not out.is_empty() else "user://voice_lines.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(lines, "\t"))
	file.close()
	print("Noted %d lines." % lines.size())


func _extra_runs() -> void:
	var before := Speech.heard.size()
	for quality: String in QUALITIES:
		for complication: String in ["bleeding", "pressure", "none"]:
			_play_theatre(quality, complication)
		for doctor_name: String in NAMES:
			for day in [9, 10, 11, 12, 15, 16]:
				_play_ward(day, doctor_name, quality)
		# The Senior Resident's operations at every difficulty, on two days
		# (each day rolls its own case).
		for procedure: String in ["hip", "spleen"]:
			for level: String in OperationTask.DIFFICULTIES:
				for day in [3, 4]:
					_play_theatre(quality, "", {"procedure": procedure, "difficulty": level,
						"lead": "bhatt" if procedure == "hip" else "sethi"}, day)
	print("The extra runs noted %d more lines." % (Speech.heard.size() - before))


func _play_theatre(quality: String, complication: String, setup: Dictionary = {}, day: int = 3) -> void:
	var doctor := PlayerProfile.new()
	doctor.name = "Asha Verma"
	doctor.day = day
	doctor.opening_seen = true
	var theatre := Theatre.new(doctor)
	root.add_child(theatre)
	theatre.operation_setup = {"complication": complication} if setup.is_empty() else setup
	theatre.skip_to("operation", [], 90)
	var bot := AutoPlayer.new()
	bot.quality = quality
	var step := 1.0 / 30.0
	for frame in int(300.0 / step):
		if theatre.view == null or theatre.view.result_open():
			break
		bot.step(theatre.view, step)
		theatre.update(step)
	theatre.free()


func _play_ward(day: int, doctor_name: String, quality: String) -> void:
	var doctor := PlayerProfile.new()
	doctor.name = doctor_name
	doctor.day = day
	doctor.opening_seen = true
	doctor.created = true
	var rank := Rank.SENIOR_RESIDENT if day >= 14 else Rank.JUNIOR_RESIDENT
	doctor.total_xp = LevelCurve.total_xp_to_reach(Rank.FIRST_LEVELS[rank]) + 400
	doctor.rank_held = rank
	for flag: String in ["op_rohit_done", "op_rohit_won", "promoted", "beds_saved", "rider_treated", "jump_9"]:
		doctor.set_flag(flag)
	if day >= 14:
		doctor.set_flag("jump_14")
	var ward := Ward.new(doctor)
	root.add_child(ward)
	var finished := [false]
	ward.day_finished.connect(func() -> void: finished[0] = true)
	var bot := AutoPlayer.new()
	bot.quality = quality
	ward.play_until(func() -> bool: return finished[0], Callable(), bot, 1500.0)
	ward.free()
