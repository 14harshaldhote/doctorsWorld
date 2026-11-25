extends SceneTree
## Stage 28: the game played for a long while, day after day, to show that
## nothing builds up. A new career starts from the title and is played the
## way the tests play it (choices picked, tasks done by the bot), with a few
## seconds of every day also run through the real frame loop, the phone
## opened on some. After each day it notes objects, nodes, nodes left out
## of the tree and memory; at the end it checks they stayed flat.
##
##   godot --headless --path . -s res://tools/soak.gd -- 30
##
## The number is the minutes to play (30 if left out). Ends with PASS or
## FAIL; any error the engine or a script reports on the way is a failure.

const Runner := preload("res://tests/run_tests.gd")
const DIR := "user://soak/"
## Days played before the counts are taken as the baseline (the first days
## load the voices, the phone and the story for the first time).
const WARM_DAYS := 6
## How far objects and nodes may drift above the baseline before it counts
## as a leak, and how much memory.
const DRIFT := 0.08
const MEMORY_DRIFT_MB := 48.0

## The answers each rank gives (the same as the career tests).
const TONES := {
	Rank.INTERN: ["Ready", "Honest", "Reassure", "Ask her", "Check", "Own it", "Calm", "Compromise", "To Aarav",
		"Gentle", "Careful", "Stay", "Patient first", "Answer", "Light", "Ask him", "The facts", "Grateful"],
	Rank.JUNIOR_RESIDENT: ["Ready", "Calm", "Honest", "Careful", "Plain", "Explain", "Question", "Patient first",
		"Help", "Grateful", "Thorough"],
	Rank.SENIOR_RESIDENT: ["Open door", "Patient first", "Honest", "Explain", "Plain", "Check", "Own it", "Report",
		"Night doctor", "Together", "Call senior", "Ask", "Theatre", "Zoya holds", "Thank", "Truth", "Credit",
		"Grateful"],
	Rank.SURGEON: ["Fresh hands", "Start now", "Patient first", "Plain", "Truth now", "Together", "Truth", "Listen",
		"Promise", "Explain", "Fair fight", "Call in", "Own it", "Credit Priya", "Ready", "Count rule", "Talk"],
	Rank.HEAD_OF_DEPARTMENT: ["Support", "Ask", "Explain", "Together", "Promise", "Refuse", "Tea", "Truth",
		"Credit Grace", "Own it", "Patients", "Sethi", "Families", "Everything"],
}

var _minutes := 30.0
var _main: Main
var _started := 0
var _rows: Array[Dictionary] = []
var _problems: PackedStringArray = []
var _evenings := 0
var _done := {}
var _errors: Runner.ErrorCatcher


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and (args[0] as String).is_valid_float():
		_minutes = float(args[0])
	_run.call_deferred()


func _run() -> void:
	_clear()
	_errors = Runner.ErrorCatcher.new()
	OS.add_logger(_errors)
	VoiceBank.warm()
	_started = Time.get_ticks_msec()
	_main = Main.new()
	_main.store = SaveStore.new(DIR + "save.json")
	_main.settings_path = DIR + "settings.json"
	root.add_child(_main)
	await process_frame
	_new_career()
	print("day  rank                 screen      objects   nodes  orphans  memory  minutes")
	var last_day := -1
	var stuck := 0
	while _elapsed() < _minutes:
		_close_cards()
		var screen := _main.screen
		if _main.profile.day != last_day and screen is Ward:
			last_day = _main.profile.day
			await _note(screen)
		var before := screen
		var day := _main.profile.day
		await _play(screen)
		if _main.screen == before and _main.profile.day == day:
			stuck += 1
			if stuck >= 3:
				_problems.append("stuck on %s, day %d" % [_name(screen), day])
				break
		else:
			stuck = 0
	OS.remove_logger(_errors)
	_report()
	_main.queue_free()
	await process_frame
	_clear()
	quit(1 if not _problems.is_empty() else 0)


func _elapsed() -> float:
	return (Time.get_ticks_msec() - _started) / 60000.0


# --- Playing ------------------------------------------------------------------------

func _new_career() -> void:
	(_main.screen as TitleScreen).new_career_pressed.emit()
	var naming := _main.screen as NameScreen
	naming.name_field.text = "Meera Joshi"
	naming._on_name_changed(naming.name_field.text)
	naming._on_next()
	(_main.screen as AvatarCreator)._pick("hair_style", 3)
	(_main.screen as AvatarCreator)._on_done()
	(_main.screen as Opening).skip()


func _play(screen: Node) -> void:
	if screen is Lobby:
		var lobby := screen as Lobby
		for id: String in ["", "grace", "nair", "iyer"]:
			_lobby_talk(lobby, id)
		for frame in 300:
			if _main.screen != lobby:
				break
			lobby._process(1.0 / 30.0)
	elif screen is SkillsLab:
		var lab := screen as SkillsLab
		if lab.drill.is_empty():
			_training_day(lab)
		else:
			_drill(lab)
	elif screen is Theatre:
		var theatre := screen as Theatre
		theatre.play_until(func() -> bool: return _main.screen != theatre,
			Theatre.pick_tones(["Ask Rohit", "Allergies", "Explain", "Be straight", "Hold firm"]), AutoPlayer.new(), 900.0)
	elif screen is Evening:
		_evening(screen as Evening)
	elif screen is Ward:
		var ward := screen as Ward
		await _real_frames(ward)
		var tones: Array = TONES.get(_main.profile.rank(), TONES[Rank.HEAD_OF_DEPARTMENT])
		ward.play_until(func() -> bool: return _main.screen != ward, Ward.pick_tones(tones), AutoPlayer.new(), 1800.0)
	else:
		for frame in 30:
			await process_frame


## A few seconds of the day through the real frame loop, as a player would
## see them: walking about, and on every other day the phone open a while.
func _real_frames(ward: Ward) -> void:
	for frame in 90:
		await process_frame
	if _main.profile.day % 2 == 0 and ward.hud != null and ward.hud.phone_allowed():
		ward.hud.open_phone("chats")
		for frame in 60:
			await process_frame
		if ward.hud.phone_open():
			ward.hud.close_phone()
		for frame in 10:
			await process_frame


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


func _training_day(lab: SkillsLab) -> void:
	lab.talk_through()
	for id: String in TrainingTask.IDS:
		if id == "iv":
			for frame in 150:
				lab.update(1.0 / 30.0)
			lab.talk_through()
			for frame in 60:
				lab.update(1.0 / 30.0)
		if lab.go_to_task(id) and lab.play_task():
			lab.view.done_pressed.emit()
		for frame in 15:
			lab.update(1.0 / 30.0)
	for frame in 150:
		lab.update(1.0 / 30.0)
	lab.talk_through()
	lab.go_home()
	for frame in 900:
		if _main.screen != lab:
			break
		lab.update(1.0 / 30.0)


func _drill(lab: SkillsLab) -> void:
	for frame in 150:
		if lab.drill_card != null:
			break
		lab.update(1.0 / 30.0)
	if lab.drill_card == null:
		return
	if _main.profile.day % 3 == 0:
		lab.drill_card.skip_button.pressed.emit()
		return
	lab.drill_card.start_button.pressed.emit()
	lab.play_task()
	lab.view.done_pressed.emit()


## Evenings take turns: the party when there is one, chai, the hostel and a
## call home, or straight to bed.
func _evening(evening: Evening) -> void:
	_evenings += 1
	var plan: Array = [["bed"], ["canteen", "bed"], ["hostel", "call", "bed"], ["hostel", "eat", "study", "bed"]][_evenings % 4]
	if evening.available("party"):
		plan = ["party", "bed"]
	for id: String in plan:
		if _main.screen != evening:
			return
		evening.play_until(func() -> bool: return _main.screen != evening or evening.phase == "menu", 0, 0.7, 120.0)
		if evening.phase != "menu":
			continue
		evening.choose(id)
		if evening.phase != "menu" or _main.screen != evening:
			_done[id] = int(_done.get(id, 0)) + 1
		evening.play_until(func() -> bool: return _main.screen != evening or evening.phase == "menu", 0, 0.7, 600.0)


## The new-day card (the first open of a real day) waits for a tap.
func _close_cards() -> void:
	for card in _main.find_children("*", "WelcomeCard", false, false):
		(card as WelcomeCard).close()


# --- Counting -----------------------------------------------------------------------

func _note(screen: Node) -> void:
	# Let freed nodes go before counting.
	for frame in 3:
		await process_frame
	var row := {
		"day": _main.profile.day,
		"rank": Rank.title(_main.profile.rank()),
		"screen": _name(screen),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"memory": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"minutes": _elapsed(),
	}
	_rows.append(row)
	print("%3d  %-20s %-10s %8d %7d %8d %6.0f MB %7.1f" % [row["day"], row["rank"], row["screen"], row["objects"],
		row["nodes"], row["orphans"], row["memory"], row["minutes"]])


func _name(node: Node) -> String:
	if node == null:
		return "none"
	var script := node.get_script() as Script
	return str(script.get_global_name()) if script != null else node.get_class()


func _report() -> void:
	print("")
	if _rows.size() <= WARM_DAYS + 2:
		_problems.append("only %d days played" % _rows.size())
	else:
		var base := _rows[WARM_DAYS]
		var peak := {"objects": 0, "nodes": 0, "orphans": 0, "memory": 0.0}
		for index in range(WARM_DAYS, _rows.size()):
			for key: String in peak:
				peak[key] = maxf(float(peak[key]), float(_rows[index][key]))
		var last := _rows[-1]
		print("baseline day %d: %d objects, %d nodes, %d orphans, %.0f MB" % [base["day"], base["objects"], base["nodes"],
			base["orphans"], base["memory"]])
		print("last day %d: %d objects, %d nodes, %d orphans, %.0f MB (peak %.0f MB)" % [last["day"], last["objects"],
			last["nodes"], last["orphans"], last["memory"], peak["memory"]])
		# A leak climbs day on day; a busy day is only a bump. Compare the last
		# third of the run with the baseline.
		var tail := _rows.slice(maxi(WARM_DAYS + 1, _rows.size() - maxi(3, _rows.size() / 3)))
		for key: String in ["objects", "nodes"]:
			var lowest := INF
			for row: Dictionary in tail:
				lowest = minf(lowest, float(row[key]))
			if lowest > float(base[key]) * (1.0 + DRIFT):
				_problems.append("%s climbed from %d to at least %d" % [key, base[key], int(lowest)])
		var low_memory := INF
		var low_orphans := INF
		for row: Dictionary in tail:
			low_memory = minf(low_memory, float(row["memory"]))
			low_orphans = minf(low_orphans, float(row["orphans"]))
		if low_memory > float(base["memory"]) + MEMORY_DRIFT_MB:
			_problems.append("memory climbed from %.0f MB to at least %.0f MB" % [base["memory"], low_memory])
		if low_orphans > float(base["orphans"]) + 20:
			_problems.append("nodes left out of the tree climbed from %d to %d" % [base["orphans"], int(low_orphans)])
	var errors := _errors.take()
	if not errors.is_empty():
		_problems.append("%d errors, the first: %s" % [errors.size(), errors[0]])
	print("%d days in %.1f minutes (%d evenings: %s)" % [_rows.size(), _elapsed(), _evenings, _done])
	if _problems.is_empty():
		print("PASS")
	else:
		for problem in _problems:
			print("problem: " + problem)
		print("FAIL")


func _clear() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + file)
