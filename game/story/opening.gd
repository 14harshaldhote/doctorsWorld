class_name Opening
extends Node3D
## The opening story, about a minute and a half, played with the player's
## own doctor and name: convocation day, the letter at home a few weeks
## later, and the first morning outside Riverside City Hospital. It ends at
## the hospital doors; meeting Dr. Iyer happens inside, in the lobby.
##
## Tap to move the subtitles on, or hold anywhere to skip.

signal finished(skipped: bool)

const ACTIONS := ["set", "shot", "fade", "card", "letter", "cue"]

var profile: PlayerProfile
var camera: Camera3D
var ui: ConversationUi
var overlay: StoryOverlay
var story: StoryPlayer
var current_set: StorySet
var set_name := ""

var _shot := {}
var _shot_t := 0.0
var _done := false


func _init(for_profile: PlayerProfile = null) -> void:
	profile = for_profile if for_profile != null else PlayerProfile.new()


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 42
	add_child(camera)
	camera.make_current()
	var layer := CanvasLayer.new()
	layer.name = "StoryLayer"
	add_child(layer)
	overlay = StoryOverlay.new(profile)
	overlay.name = "Overlay"
	layer.add_child(overlay)
	ui = ConversationUi.new()
	ui.name = "Conversation"
	ui.mode = ConversationUi.Mode.CINEMA
	ui.skippable = true
	ui.auto_advance = 1.4
	layer.add_child(ui)
	ui.skip_requested.connect(skip)
	ui.advanced.connect(_on_tap)
	story = StoryPlayer.new(StoryRunner.new(profile), ui, self)
	story.finished.connect(_on_story_finished)
	ui.open_cinema()
	story.play(StoryBook.conversation("opening", "opening"))


func _process(delta: float) -> void:
	update(delta)


## Moves the whole scene on by delta seconds (the tests call this directly).
func update(delta: float) -> void:
	if _done:
		return
	story.update(delta)
	overlay.tick(delta)
	if current_set != null:
		current_set.tick(delta)
	_update_camera(delta)


func skip() -> void:
	if not _done:
		story.skip()


func is_done() -> bool:
	return _done


# --- What the story asks for -------------------------------------------------

func perform(step: Dictionary) -> Variant:
	match str(step["do"]):
		"set":
			_use_set(str(step.get("name", "")))
			return 0.0
		"shot":
			_start_shot(str(step.get("name", "")))
			return 0.0
		"fade":
			var time := float(step.get("time", 0.8))
			overlay.fade(str(step.get("to", "black")), time)
			return time
		"card":
			var time := float(step.get("time", 2.0))
			ui.hide_line()
			overlay.card(story.runner.fill(str(step.get("text", ""))), story.runner.fill(str(step.get("sub", ""))), time)
			return time
		"letter":
			ui.hide_line()
			overlay.show_letter()
			return func() -> bool: return not overlay.letter_open()
		"cue":
			return current_set.cue(str(step.get("name", ""))) if current_set != null else 0.0
	return null


func mark(mark_name: String) -> Variant:
	if current_set == null or not current_set.marks.has(mark_name):
		return null
	return current_set.to_global(current_set.marks[mark_name])


func _use_set(new_name: String) -> void:
	if current_set != null:
		remove_child(current_set)
		current_set.queue_free()
	match new_name:
		"graduation":
			current_set = GraduationHall.new(profile)
		"home":
			current_set = HomeRoom.new(profile)
		"morning":
			current_set = MorningStreet.new(profile)
		_:
			push_error("Unknown set: %s" % new_name)
			current_set = StorySet.new(profile)
	set_name = new_name
	current_set.name = new_name.capitalize()
	add_child(current_set)
	StaticBatch.optimise(current_set)
	story.actors = current_set.actors


func _start_shot(shot_name: String) -> void:
	if current_set == null or not current_set.shots.has(shot_name):
		push_error("Unknown shot: %s" % shot_name)
		return
	_shot = current_set.shots[shot_name]
	_shot_t = 0.0
	camera.fov = float(_shot.get("fov", 42.0))
	camera.h_offset = float(_shot.get("offset", 0.0))
	_update_camera(0.0)


func _update_camera(delta: float) -> void:
	if _shot.is_empty():
		return
	_shot_t += delta
	var from: Vector3 = _shot["from"]
	var at: Vector3 = _shot["at"]
	if _shot.has("to_from") or _shot.has("to_at"):
		var t := smoothstep(0.0, 1.0, clampf(_shot_t / float(_shot.get("time", 6.0)), 0.0, 1.0))
		from = from.lerp(_shot.get("to_from", from), t)
		at = at.lerp(_shot.get("to_at", at), t)
	camera.look_at_from_position(from, at)


func _on_tap() -> void:
	if overlay.letter_open():
		overlay.close_letter()


func _on_story_finished(skipped: bool) -> void:
	_done = true
	finished.emit(skipped)


## Plays the story forward until a condition holds (for tests and the
## screenshot tool), picking reply number choose_reply whenever asked and
## folding the letter (a negative choose_reply leaves the letter open).
## Returns true if the condition was met.
func play_until(condition: Callable, choose_reply: int = 0, seconds: float = 240.0) -> bool:
	var step := 1.0 / 30.0
	var elapsed := 0.0
	while elapsed < seconds:
		if bool(condition.call()):
			return true
		if _done:
			return false
		if ui.is_choosing():
			story.choose(maxi(choose_reply, 0))
		elif overlay.letter_open() and choose_reply >= 0:
			overlay.close_letter()
		update(step)
		elapsed += step
	return bool(condition.call())
