extends SceneTree
## Stage 28: how long the game's own code takes per frame in its busiest
## moments, and what each one draws. Each scene is set up as a player would
## find it, then left to run for a few seconds at full speed while the
## engine's monitors are read every frame.
##
##   xvfb-run -a godot --path . --resolution 1334x750 -s res://tools/profile.gd
##   godot --headless --path . -s res://tools/profile.gd -- casualty,party
##
## Prints one line per scene: the game code in each frame's process step
## (mean, 95th percentile and worst, in ms), the physics step's mean, draw
## calls, objects, nodes and memory. Draw calls are 0 when headless.

const Shots := preload("res://tools/screenshots.gd")


## Notes the time when the frame's process (or physics) step reaches it: one
## goes first and one last, so the gap is all the game code that frame.
class Stamp extends Node:
	var at := 0
	var physics_at := 0

	func _init(order: int) -> void:
		process_priority = order
		process_physics_priority = order
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(_delta: float) -> void:
		at = Time.get_ticks_usec()

	func _physics_process(_delta: float) -> void:
		physics_at = Time.get_ticks_usec()

## Frames to let a scene settle before measuring, and frames measured.
const SETTLE := 30
const FRAMES := 300

var _only: Array = []


func _initialize() -> void:
	# As the game does at boot (Main), so no scene pays for it.
	VoiceBank.warm()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_only = (args[0] as String).split(",", false)
	_run.call_deferred()


func _wanted(label: String) -> bool:
	return _only.is_empty() or label in _only


func _run() -> void:
	print("scene        mean   p95   worst  physics  draws  objects  nodes  memory")
	if _wanted("lobby"):
		var doctor := Shots.sample_profile()
		doctor.set_flag("met_iyer")
		await _measure("lobby", Lobby.new(doctor))
	if _wanted("ward"):
		var ward := Ward.new(Shots.sample_profile_on_ward(12, ["beds_checked", "casualty_intro"]))
		ward.profile.set_count("hospital_seed", 2026)
		await _measure("ward", ward, func() -> void:
			ward.play_until(func() -> bool: return ward.mode == "walk", Ward.pick_tones(["Patient first", "Honest", "Calm"])))
	if _wanted("casualty"):
		var busy := Ward.new(Shots.sample_profile_on_ward(20, ["beds_checked", "casualty_intro"]))
		busy.profile.set_count("hospital_seed", 2026)
		await _measure("casualty", busy, func() -> void:
			Shots._into_casualty(busy))
	if _wanted("phone"):
		var phoned := Ward.new(Shots.sample_profile_on_ward(12, ["beds_checked", "casualty_intro"]))
		phoned.profile.set_count("hospital_seed", 2026)
		await _measure("phone", phoned, func() -> void:
			phoned.play_until(func() -> bool: return phoned.mode == "walk", Ward.pick_tones(["Patient first", "Honest", "Calm"]))
			PhoneBook.forget()
			phoned.hud.open_phone("chats"))
	if _wanted("theatre"):
		var theatre := Theatre.new(Shots.sample_profile_on_theatre_day())
		await _measure("theatre", theatre)
	if _wanted("evening"):
		var evening := Shots._evening_after(5)
		await _measure("evening", evening, func() -> void:
			evening.update(0.8))
	if _wanted("party"):
		var party := Shots._evening_after(13, [])
		party.profile.set_count(Lives.PREFIX + "khan_wedding", 12)
		await _measure("party", party, func() -> void:
			party.choose("party")
			party.play_until(func() -> bool: return party.game is DanceGame, 0, 0.8, 400.0))
	quit()


func _measure(label: String, node: Node, prepare: Callable = Callable()) -> void:
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()
	await process_frame
	root.add_child(node)
	await process_frame
	if prepare.is_valid():
		prepare.call()
	for frame in SETTLE:
		await process_frame
	var first := Stamp.new(-100000)
	var last := Stamp.new(100000)
	root.add_child(first)
	root.add_child(last)
	await process_frame
	var times: Array[float] = []
	var physics := 0.0
	var draws := 0.0
	for frame in FRAMES:
		await process_frame
		times.append((last.at - first.at) / 1000.0)
		physics += maxf(0.0, (last.physics_at - first.physics_at) / 1000.0)
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	root.remove_child(first)
	root.remove_child(last)
	first.free()
	last.free()
	times.sort()
	var mean := 0.0
	for value in times:
		mean += value
	mean /= times.size()
	print("%-11s %5.2f %5.2f %6.2f %8.2f %6d %8d %6d %5d MB" % [label, mean, times[int(times.size() * 0.95)], times[-1],
		physics / FRAMES, int(draws / FRAMES), int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)])
