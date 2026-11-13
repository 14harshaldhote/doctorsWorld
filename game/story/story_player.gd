class_name StoryPlayer
extends RefCounted
## Plays a conversation or story scene on a stage: shows each line, makes
## the speaker move while they talk (gesture, mouth, voice, gaze) and the
## others look at them, offers replies, and performs actions such as walking
## and handing something over.
##
## The stage is the scene node (the lobby, the opening). It can provide:
##   perform(step) -> float seconds to wait, a Callable that returns true when
##       done, or null for actions it does not know
##   mark(name) -> Vector3 for named spots ("podium", "doors")
##   on_line(speaker, listener) to frame the camera
##
## Time passes only through update(), which the stage calls every frame.

signal finished(skipped: bool)

const WALK_SPEED := 1.5
## Actions every stage understands.
const GENERIC := ["walk", "face", "look", "gesture", "mood", "give", "hold", "drop", "wait", "sit", "stand", "sound",
	"music"]
## Lines without a gesture still move: one of these, picked by the words.
const AUTO_GESTURES := ["explain", "open_hands", "", "explain", "shrug", "", "open_hands", "explain"]
const GIVE_TIME := 1.5

var runner: StoryRunner
var ui: ConversationUi
## The characters on stage, by cast id. "you" is the player.
var actors := {}
var stage: Node
## The person the player is talking to: their card shows in talk mode.
var focus := ""

var _playing := false
var _busy := false
var _wait := 0.0
var _until := Callable()
var _speaker: AvatarRig
var _just_chose := false
var _last_change := 0
var _walks := {}
var _turns := {}
var _timed_gestures := {}
var _give := {}
## The track that played before a "music" action changed it; it comes back
## when the conversation ends.
var _music_before := ""
var _music_changed := false


func _init(story_runner: StoryRunner, conversation_ui: ConversationUi, on_stage: Node) -> void:
	runner = story_runner
	ui = conversation_ui
	stage = on_stage
	ui.advanced.connect(_on_advanced)
	ui.chosen.connect(choose)
	ui.syllable.connect(_on_syllable)
	ui.typing_finished.connect(_on_typing_finished)


func play(steps: Array) -> void:
	runner.start(steps)
	_playing = true
	_busy = false
	_just_chose = false
	_next()


func is_playing() -> bool:
	return _playing


## True while an action (a walk, a wait, a hand-over) is running.
func is_busy() -> bool:
	return _busy


func update(delta: float) -> void:
	ui.tick(delta)
	_update_walks(delta)
	_update_turns(delta)
	_update_gestures(delta)
	_update_give(delta)
	if _busy:
		_wait -= delta
		if _wait <= 0.0 and (not _until.is_valid() or bool(_until.call())):
			_busy = false
			_until = Callable()
			_next()


## Picks a reply (also called by the reply buttons).
func choose(index: int) -> void:
	if not _playing or not runner.waiting_for_choice():
		return
	var result := runner.choose(index)
	var about := _about()
	var changes: Dictionary = result.get("trust", {})
	_last_change = int(changes[about][0]) if changes.has(about) else 0
	var effect := str(result.get("effect", ""))
	if effect.is_empty():
		effect = _describe(changes)
	ui.show_result(str(result.get("said", "")), effect, str(result.get("detail", "")))
	_just_chose = true
	# The player's reply is shown, never said aloud: on to the answer.
	_next()


## Stops at once, leaving everyone standing where they are.
func skip() -> void:
	if not _playing:
		return
	for id: String in _walks:
		var rig: AvatarRig = actors.get(id)
		if rig != null:
			var to: Vector3 = _walks[id]["to"]
			rig.position = Vector3(to.x, rig.position.y, to.z)
	_walks.clear()
	_finish(true)


## Sends a character walking in a straight line (outside any story too).
func walk(id: String, to: Vector3, speed: float = WALK_SPEED) -> void:
	var rig: AvatarRig = actors.get(id)
	if rig == null:
		return
	_walks[id] = {"to": to, "speed": speed}
	rig.moving = 1.0


func is_walking(id: String) -> bool:
	return _walks.has(id)


func card_for(id: String, change: int = 0) -> Dictionary:
	if id.is_empty() or id == "you":
		return {}
	var rig: AvatarRig = actors.get(id)
	return {
		"name": runner.display_name(id),
		"role": runner.role(id),
		"mood": rig.mood if rig != null else -1,
		"trust": runner.trust_of(id),
		"change": change,
	}


func _about() -> String:
	return focus if not focus.is_empty() else runner.about()


func _describe(changes: Dictionary) -> String:
	var parts := PackedStringArray()
	for id: String in changes:
		var change: int = changes[id][0]
		if change == 0:
			continue
		parts.append("%s trusts you %s." % [runner.display_name(id), "more" if change > 0 else "less"])
	return " ".join(parts)


func _next() -> void:
	while _playing and not _busy:
		var event := runner.next()
		match str(event["type"]):
			"line":
				_show_line(event)
				return
			"choice":
				_show_choice(event)
				return
			"action":
				_perform(event["step"])
			_:
				_finish(false)
				return


func _show_line(event: Dictionary) -> void:
	var speaker_id := str(event["speaker"])
	var rig: AvatarRig = actors.get(speaker_id)
	var listener_id := str(event["to"])
	if listener_id.is_empty():
		listener_id = focus if speaker_id == "you" else "you"
	if _speaker != null and _speaker != rig and is_instance_valid(_speaker):
		_speaker.talking = false
		if not _timed_gestures.has(_actor_id(_speaker)):
			_speaker.set_gesture("")
	for id: String in actors:
		var other: AvatarRig = actors[id]
		if other == rig:
			continue
		other.talking = false
		other.listening = id == listener_id
		if rig != null and other.global_position.distance_to(rig.global_position) < 9.0:
			other.look_at_rig(rig)
	if rig != null:
		rig.talking = true
		rig.listening = false
		var move := str(event["gesture"])
		if move.is_empty() and not _timed_gestures.has(speaker_id):
			move = AUTO_GESTURES[absi(hash(event["text"])) % AUTO_GESTURES.size()]
		if not _timed_gestures.has(speaker_id):
			rig.set_gesture(move, str(event["head"]))
		else:
			rig.set_head_gesture(str(event["head"]))
		if int(event["mood"]) >= 0:
			rig.set_mood(int(event["mood"]))
		rig.look_at_rig(actors.get(listener_id))
	_speaker = rig
	if stage.has_method("on_line"):
		stage.on_line(speaker_id, listener_id)
	var info := {"voice": speaker_id}
	if ui.mode == ConversationUi.Mode.TALK:
		info["card"] = card_for(_about(), _last_change if _just_chose else 0)
	if not _just_chose:
		ui.hide_choices()
	_just_chose = false
	_last_change = 0
	ui.show_line(str(event["name"]), str(event["text"]), info)


func _show_choice(event: Dictionary) -> void:
	if _speaker != null and is_instance_valid(_speaker):
		_speaker.talking = false
	var about := str(event.get("about", ""))
	if about.is_empty():
		about = focus
	var you: AvatarRig = actors.get("you")
	if you != null:
		you.set_gesture("think" if ui.mode == ConversationUi.Mode.TALK else "")
		you.talking = false
	ui.show_choices(event["options"], card_for(about))


func _on_advanced() -> void:
	if _playing and not _busy and not runner.waiting_for_choice():
		_next()


func _on_syllable(letter: String) -> void:
	if _speaker != null and is_instance_valid(_speaker):
		# A line read aloud already has a voice, and the player's doctor has
		# none: only the mouth moves.
		var silent: bool = ui.reading_aloud() or _speaker == actors.get(Speech.PLAYER)
		_speaker.say_syllable(letter, not silent)


func _on_typing_finished() -> void:
	if _speaker != null and is_instance_valid(_speaker):
		_speaker.talking = false


func _finish(skipped: bool) -> void:
	_playing = false
	_busy = false
	if _music_changed:
		_music_changed = false
		Music.cue(_music_before)
	for id: String in actors:
		var rig: AvatarRig = actors[id]
		if not is_instance_valid(rig):
			continue
		rig.talking = false
		rig.listening = false
		rig.look_at_point(null)
		if not _timed_gestures.has(id):
			rig.set_gesture("")
	_speaker = null
	ui.close()
	finished.emit(skipped)


# --- Actions --------------------------------------------------------------

func _perform(step: Dictionary) -> void:
	var action := str(step["do"])
	var who := str(step.get("who", "you"))
	var rig: AvatarRig = actors.get(who)
	var wait := bool(step.get("wait", true))
	if ui.mode == ConversationUi.Mode.CINEMA and action not in ["mood", "hold", "drop", "look", "face", "music"]:
		ui.hide_line()
	match action:
		"walk":
			if rig == null:
				return
			var to := _point(step.get("to"), rig)
			_walks[who] = {"to": to, "speed": float(step.get("speed", WALK_SPEED))}
			rig.moving = 1.0
			if wait:
				_block(0.0, func() -> bool: return not _walks.has(who))
		"face":
			if rig != null:
				var spot := _point(step.get("at"), rig)
				_turns[who] = atan2(spot.x - rig.global_position.x, spot.z - rig.global_position.z)
				if bool(step.get("now", false)):
					rig.rotation.y = _turns[who]
					_turns.erase(who)
		"look":
			if rig != null:
				var target: Variant = step.get("at")
				if target == null:
					rig.look_at_point(null)
				elif actors.has(str(target)):
					rig.look_at_rig(actors[str(target)])
				else:
					rig.look_at_point(_point(target, rig) + Vector3(0, float(step.get("height", 1.5)), 0))
		"gesture":
			if rig != null:
				rig.set_gesture(str(step.get("gesture", "")), str(step.get("head", "")))
				var time := float(step.get("time", 0.0))
				if time > 0.0:
					_timed_gestures[who] = time
				if step.has("talk"):
					rig.talking = bool(step["talk"])
				if bool(step.get("wait", false)) and time > 0.0:
					_block(time)
		"mood":
			if rig != null:
				rig.set_mood(maxi(0, StoryRunner.mood_index(str(step.get("mood", "calm")))))
		"give":
			var giver: AvatarRig = actors.get(str(step.get("from", "")))
			var taker: AvatarRig = actors.get(str(step.get("to", "you")))
			var item := str(step.get("item", ""))
			if giver == null or taker == null:
				return
			giver.hold(item)
			giver.set_gesture("offer")
			giver.look_at_rig(taker)
			taker.look_at_rig(giver)
			_give = {"from": giver, "to": taker, "item": item, "time": 0.0, "moved": false}
			_block(GIVE_TIME)
		"hold":
			if rig != null:
				rig.hold(str(step.get("item", "")), str(step.get("side", "R")))
		"drop":
			if rig != null:
				rig.drop(str(step.get("side", "R")))
		"wait":
			_block(float(step.get("time", 1.0)))
		"sit", "stand":
			if rig != null:
				rig.sitting = action == "sit"
		"sound":
			Sfx.play(stage, str(step.get("name", "")), float(step.get("volume", 0.0)))
		"music":
			if not _music_changed:
				_music_changed = true
				_music_before = Music.current()
			Music.cue(str(step.get("track", "")))
		_:
			var result: Variant = stage.perform(step) if stage.has_method("perform") else null
			if result == null:
				push_error("The stage cannot perform %s" % action)
			elif typeof(result) == TYPE_CALLABLE:
				if wait:
					_block(0.0, result)
			elif float(result) > 0.0 and wait:
				_block(float(result))


func _block(seconds: float, until: Callable = Callable()) -> void:
	_busy = true
	_wait = seconds
	_until = until


## Where something is: an actor id, a stage mark, or [x, z] / [x, y, z].
func _point(value: Variant, mover: AvatarRig = null) -> Vector3:
	var base_y := mover.global_position.y if mover != null else 0.0
	if typeof(value) == TYPE_ARRAY:
		var list: Array = value
		if list.size() == 2:
			return Vector3(float(list[0]), base_y, float(list[1]))
		if list.size() >= 3:
			return Vector3(float(list[0]), float(list[1]), float(list[2]))
	var key := str(value)
	if actors.has(key):
		return (actors[key] as AvatarRig).global_position
	if stage.has_method("mark"):
		var spot: Variant = stage.mark(key)
		if spot != null:
			return spot
	push_error("Unknown place: %s" % key)
	return Vector3.ZERO


func _actor_id(rig: AvatarRig) -> String:
	for id: String in actors:
		if actors[id] == rig:
			return id
	return ""


func _update_walks(delta: float) -> void:
	for id: String in _walks.keys():
		var rig: AvatarRig = actors.get(id)
		if rig == null or not is_instance_valid(rig):
			_walks.erase(id)
			continue
		var walk: Dictionary = _walks[id]
		var to: Vector3 = walk["to"]
		var here := rig.global_position
		var flat := Vector2(to.x - here.x, to.z - here.z)
		var step := float(walk["speed"]) * delta
		if flat.length() <= step:
			rig.global_position = Vector3(to.x, here.y, to.z)
			rig.moving = 0.0
			_walks.erase(id)
			continue
		var move := flat.normalized() * step
		rig.global_position += Vector3(move.x, 0, move.y)
		rig.rotation.y = lerp_angle(rig.rotation.y, atan2(flat.x, flat.y), minf(1.0, delta * 10.0))


func _update_turns(delta: float) -> void:
	for id: String in _turns.keys():
		var rig: AvatarRig = actors.get(id)
		if rig == null or not is_instance_valid(rig) or _walks.has(id):
			_turns.erase(id)
			continue
		var goal: float = _turns[id]
		rig.rotation.y = lerp_angle(rig.rotation.y, goal, minf(1.0, delta * 8.0))
		if absf(angle_difference(rig.rotation.y, goal)) < 0.02:
			rig.rotation.y = goal
			_turns.erase(id)


func _update_gestures(delta: float) -> void:
	for id: String in _timed_gestures.keys():
		_timed_gestures[id] = float(_timed_gestures[id]) - delta
		if float(_timed_gestures[id]) <= 0.0:
			_timed_gestures.erase(id)
			var rig: AvatarRig = actors.get(id)
			if rig != null and is_instance_valid(rig) and rig != _speaker:
				rig.set_gesture("")


func _update_give(delta: float) -> void:
	if _give.is_empty():
		return
	_give["time"] = float(_give["time"]) + delta
	var giver: AvatarRig = _give["from"]
	var taker: AvatarRig = _give["to"]
	if not _give["moved"] and float(_give["time"]) >= GIVE_TIME * 0.45:
		_give["moved"] = true
		giver.drop()
		taker.hold(str(_give["item"]))
		taker.set_gesture("offer")
		giver.set_gesture("")
	if float(_give["time"]) >= GIVE_TIME:
		taker.set_gesture("")
		_give = {}
