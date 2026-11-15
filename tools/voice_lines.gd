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
			for day in [9, 10, 11, 12, 15, 16, 19, 22, 25, 26]:
				_play_ward(day, doctor_name, quality)
		# The Senior Resident's operations at every difficulty, on two days
		# (each day rolls its own case).
		for procedure: String in ["hip", "spleen"]:
			for level: String in OperationTask.DIFFICULTIES:
				for day in [3, 4]:
					_play_theatre(quality, "", {"procedure": procedure, "difficulty": level,
						"lead": "bhatt" if procedure == "hip" else "sethi"}, day)
		# The Surgeon's blocked bowel with either team, and the crash's
		# triage at every difficulty (each seed brings different casualties).
		for level: String in OperationTask.DIFFICULTIES:
			for team: Array in [["tom", "khan"], ["neha", "bose"]]:
				for chest_safe: bool in [true, false]:
					_play_theatre(quality, "", {"procedure": "obstruction", "difficulty": level, "scrub_nurse": team[0],
						"anaesthetist": team[1], "chest_safe": chest_safe, "lungs_known": chest_safe,
						"lose_swab": 1 if team[0] == "tom" else 0}, 3 + int(chest_safe))
			for with_seed in [1, 2, 3, 4, 5, 6]:
				_play_triage(level, with_seed, quality)
			# Mrs. Sinha's bile leak, with and without her penicillin on the
			# board, on two days (each rolls where it leaks on hard).
			for known: bool in [true, false]:
				for day in [3, 4]:
					_play_theatre(quality, "", {"procedure": "bile_leak", "difficulty": level, "allergy_known": known,
						"scrub_nurse": "neha"}, day)
		_chief_runs(quality)
	print("The extra runs noted %d more lines." % (Speech.heard.size() - before))


## The Chief's days: every casebook patient on the table at every
## difficulty (with what they said known and not known) and once in the
## simulator, tonight's rota and the highway crash with many seeds, and
## the generated days themselves, including a new tier and a milestone.
func _chief_runs(quality: String) -> void:
	for id: String in ChiefDays.CASEBOOK:
		var entry: Dictionary = ChiefDays.CASEBOOK[id]
		var team: Array = entry["team"]
		for level: String in OperationTask.DIFFICULTIES:
			for known: bool in [true, false]:
				var setup := {"procedure": entry["procedure"], "difficulty": level, "casebook": ChiefDays.casebook_setup(id),
					"lead": team[0], "scrub_nurse": team[1], "anaesthetist": team[2], "intensity": 1.3}
				for key: String in entry.get("op_flags", {}):
					setup[key] = known
				_play_theatre(quality, "", setup, 3 + int(known))
		for level: String in ["hard", "extreme"]:
			_play_theatre(quality, "", {"procedure": entry["procedure"], "difficulty": level, "lead": "iyer",
				"scrub_nurse": "neha", "anaesthetist": "khan", "casebook": ChiefDays.casebook_setup(id, true)}, 5)
	for level: String in OperationTask.DIFFICULTIES:
		for with_seed in [1, 2, 3, 4, 5, 6, 7, 8]:
			_play_rota("chief_rota", level, with_seed, quality)
			_play_triage(level, with_seed, quality, "chief_triage")
	for doctor_name: String in NAMES.slice(0, 2):
		for day in [29, 30, 31, 32, 33, 34, 35, 36, 38, 39, 42, 46, 50]:
			_play_ward(day, doctor_name, quality)


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
	var rank := Rank.SURGEON if day >= 19 else (Rank.SENIOR_RESIDENT if day >= 14 else Rank.JUNIOR_RESIDENT)
	if day >= 24:
		rank = Rank.HEAD_OF_DEPARTMENT
	if day >= ChiefDays.FIRST_DAY:
		rank = Rank.CHIEF
	doctor.total_xp = LevelCurve.total_xp_to_reach(Rank.FIRST_LEVELS[rank]) + 400
	doctor.rank_held = rank
	for flag: String in ["op_rohit_done", "op_rohit_won", "promoted", "beds_saved", "rider_treated", "jump_9"]:
		doctor.set_flag(flag)
	if day >= 14:
		doctor.set_flag("jump_14")
	if day >= 19:
		doctor.set_flag("jump_19")
	if day >= 24:
		doctor.set_flag("jump_24")
	if day >= ChiefDays.FIRST_DAY:
		for flag: String in ["chief_won", "strike_backed", "sinha_told"]:
			doctor.set_flag(flag)
	var ward := Ward.new(doctor)
	root.add_child(ward)
	var finished := [false]
	ward.day_finished.connect(func() -> void: finished[0] = true)
	var bot := AutoPlayer.new()
	bot.quality = quality
	ward.play_until(func() -> bool: return finished[0], Callable(), bot, 1500.0)
	ward.free()


func _play_rota(case_id: String, level: String, with_seed: int, quality: String) -> void:
	var task := RotaTask.new(case_id, with_seed, level)
	var view := RotaView.new(task)
	root.add_child(view)
	var bot := AutoPlayer.new()
	bot.quality = quality
	bot.pace = 0.1
	var waited := 0.0
	while not task.finished and waited < 120.0:
		if quality == "shaky" and level != "extreme" and int(waited * 10.0) % 37 == 0:
			view.ask_hint()
		bot.step(view, 0.1)
		view.tick(0.1)
		waited += 0.1
	view.free()


func _play_triage(level: String, with_seed: int, quality: String, case_id: String = "bus_triage") -> void:
	var task := TriageTask.new(case_id, with_seed, level)
	var view := TriageView.new(task)
	root.add_child(view)
	var bot := AutoPlayer.new()
	bot.quality = quality
	bot.pace = 0.1
	var waited := 0.0
	while not task.finished and waited < 120.0:
		if quality == "shaky" and level != "extreme" and int(waited * 10.0) % 37 == 0:
			view.ask_hint()
		bot.step(view, 0.1)
		view.tick(0.1)
		waited += 0.1
	view.free()
