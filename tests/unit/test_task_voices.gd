extends TestCase
## The skills lab's coaching is recorded, whole and acted, in each trainer's
## own voice: nothing in training falls back to the phone's reading voice
## or is stitched together around a number.

const TaskLines := preload("res://tools/task_lines.gd")
const LIST := "res://tools/task_lines.json"
const SAVE := "user://test_task_voices/save.json"


func test_the_list_of_training_lines_is_up_to_date() -> void:
	var listed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LIST))
	expect(listed is Array, "tools/task_lines.json is there")
	expect_equal(listed, TaskLines.collect(),
		"tools/task_lines.json matches the code (run tools/task_lines.gd, then make_voices.py)")


func test_every_training_line_has_a_recording() -> void:
	VoiceBank.reset()
	var lines := TaskLines.collect()
	expect(lines.size() > 250, "every station's lines are listed (%d)" % lines.size())
	var missing := []
	for line: Dictionary in lines:
		if VoiceBank.find(str(line["who"]), str(line["text"])).is_empty():
			missing.append("%s: %s" % [line["who"], line["text"]])
	expect_equal(missing.size(), 0, "every training line has a recording; missing e.g. %s" % [missing.slice(0, 5)])


func test_each_line_is_one_whole_recording() -> void:
	# Joined-up pieces sound like a phone menu; a training line is one take.
	VoiceBank.reset()
	var pieced := []
	for line: Dictionary in TaskLines.collect():
		var parts := VoiceBank.find(str(line["who"]), str(line["text"]))
		if parts.size() > 1:
			pieced.append(str(line["text"]))
	expect_equal(pieced.size(), 0, "no training line is put together from pieces; e.g. %s" % [pieced.slice(0, 5)])


func test_the_lines_are_said_by_the_stations_trainers() -> void:
	for station: String in TaskLines.VOICES:
		expect(str(TrainingTask.TRAINERS[station]) in TaskLines.VOICES[station],
			"%s's trainer's voice is listed" % station)
	expect("tom" in TaskLines.VOICES["scrub"], "and Tom's, at the theatre's sink")


func test_playing_the_stations_any_way_says_only_listed_lines() -> void:
	# Random play, well and badly, never reaches a line the list missed.
	for station: String in TaskLines.VOICES:
		var listed := {}
		for text: String in TaskLines.station_lines(station):
			listed[text] = true
		var heard := {}
		for with_seed in range(1, 31):
			_play_randomly(station, with_seed, heard)
		var unlisted := heard.keys().filter(func(text: String) -> bool: return not listed.has(text))
		expect(heard.size() > 5, "%s says plenty (%d)" % [station, heard.size()])
		expect_equal(unlisted.size(), 0, "%s: every line said is listed; e.g. %s" % [station, unlisted.slice(0, 3)])


func test_the_first_two_days_say_only_recorded_lines() -> void:
	# A new career from the first morning through the whole skills lab, played
	# through every view, with every line asked to be read aloud noted.
	VoiceBank.reset()
	# tools/voice_lines.gd notes every line the tests say: add to what it has
	# noted instead of wiping it.
	var listening_before := Speech.listening
	var heard_before := Speech.heard
	Speech.listening = true
	Speech.heard = {}
	var main := Main.new()
	main.store = SaveStore.new(SAVE)
	main.settings_path = "user://test_task_voices/settings.json"
	add_node(main)
	(main.screen as TitleScreen).new_career_pressed.emit()
	var naming := main.screen as NameScreen
	naming.name_field.text = "Kiran Rao"
	naming._on_name_changed(naming.name_field.text)
	naming._on_next()
	(main.screen as AvatarCreator)._on_done()
	(main.screen as Opening).skip()
	var lobby := main.screen as Lobby
	expect(lobby != null, "the first morning, in the lobby")
	if lobby != null:
		for id: String in ["", "grace", "nair", "iyer"]:
			_lobby_talk(lobby, id)
		for frame in 300:
			if main.screen != lobby:
				break
			lobby._process(1.0 / 30.0)
	var lab := main.screen as SkillsLab
	expect(lab != null, "then the skills lab")
	if lab != null:
		lab.talk_through()
		for id: String in TrainingTask.IDS:
			if id == "iv":
				for frame in 150:
					lab.update(1.0 / 30.0)
				lab.talk_through()
				for frame in 60:
					lab.update(1.0 / 30.0)
			expect(lab.go_to_task(id), "the %s station opens" % id)
			for frame in 40:
				lab.update(1.0 / 30.0)
			lab.play_task()
			for frame in 40:
				lab.update(1.0 / 30.0)
			if lab.view != null:
				lab.view.done_pressed.emit()
			for frame in 15:
				lab.update(1.0 / 30.0)
		for frame in 150:
			lab.update(1.0 / 30.0)
		lab.talk_through()
	var heard := Speech.heard
	Speech.heard = heard_before
	Speech.listening = listening_before
	if listening_before:
		Speech.heard.merge(heard)
	var total := 0
	var missing := []
	for key: String in heard:
		var parts := key.split("\t", true, 1)
		if parts.size() < 2 or parts[0] == Speech.PLAYER or VoiceBank.normalize(parts[1]).is_empty():
			continue
		total += 1
		if VoiceBank.find(parts[0], parts[1]).is_empty():
			missing.append("%s: %s" % [parts[0], parts[1]])
	expect(total > 60, "the first two days say a lot (%d lines)" % total)
	expect_equal(missing.size(), 0, "every line has a recording; missing e.g. %s" % [missing.slice(0, 5)])


func test_no_story_line_says_the_players_name_unrecorded() -> void:
	# "{called}" is recorded as "Doctor"; a full or first name can't be.
	var named := []
	for line: Dictionary in StoryBook.spoken_lines():
		var text := str(line["text"])
		for field: String in ["{name}", "{first}", "{last}", "{title}"]:
			if field in text and str(line["who"]) != Speech.PLAYER:
				named.append("%s: %s" % [line["who"], text])
	expect_equal(named.size(), 0, "nobody says a name a recording can't; e.g. %s" % [named.slice(0, 3)])


func _lobby_talk(lobby: Lobby, id: String) -> void:
	if not lobby.story.is_playing() and not id.is_empty():
		lobby._start_talk(id)
	for frame in 4000:
		if not lobby.story.is_playing():
			return
		if lobby.talk_ui.is_choosing():
			lobby.story.choose(0)
		elif not lobby.story.is_busy():
			lobby.talk_ui.tap()
		lobby._process(1.0 / 30.0)


## One run of a station with random taps, notes every coach line said.
func _play_randomly(station: String, with_seed: int, heard: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = with_seed * 7919 + station.hash()
	var task := TrainingTask.make(station, with_seed)
	task.changed.connect(func() -> void:
		if not task.coach.is_empty():
			heard[task.coach] = true)
	heard[task.coach] = true
	for action in 400:
		if task.finished:
			break
		match station:
			"scrub":
				var scrub := task as ScrubTask
				var steps: Array = ScrubTask.STEPS + ScrubTask.AREAS + ScrubTask.TRAPS
				var step: String = steps[rng.randi() % steps.size()]
				if ScrubTask.AREAS.has(step) and rng.randf() < 0.7:
					scrub.scrub(step, rng.randf_range(0.3, 1.6))
				else:
					scrub.do_step(step)
			"monitor":
				var monitor := task as MonitorTask
				if monitor.phase == "learn":
					monitor.learn(Vitals.KINDS[rng.randi() % Vitals.KINDS.size()])
					if rng.randf() < 0.3:
						monitor.start_quiz()
				elif rng.randf() < 0.6:
					var answers: Array = Vitals.KINDS + ["none"]
					monitor.answer(answers[rng.randi() % answers.size()])
				task.tick(rng.randf_range(0.2, MonitorTask.ROUND_TIME))
			"instruments":
				if rng.randf() < 0.7:
					(task as InstrumentTask).pick(Instruments.ALL[rng.randi() % Instruments.ALL.size()])
				task.tick(rng.randf_range(0.2, InstrumentTask.CALL_TIME))
			"iv":
				var iv := task as IvTask
				match iv.phase:
					"vein":
						iv.pick_vein(IvTask.VEINS[rng.randi() % IvTask.VEINS.size()])
					"angle":
						iv.set_angle(rng.randf_range(0.0, 60.0))
						if rng.randf() < 0.4:
							iv.insert()
					_:
						if rng.randf() < 0.5:
							iv.nudge(-iv.offset * rng.randf())
						iv.tick(1.0 / 30.0)
			"stitch":
				var stitch := task as StitchTask
				if rng.randf() < 0.04 and not stitch.stitches.is_empty():
					stitch.tie_off()
				else:
					var spot := stitch.point_at(rng.randf()) + Vector2(rng.randf_range(-1.2, 1.2), rng.randf_range(-1.2, 1.2))
					stitch.place(spot)
