class_name RecordedVoice
extends AudioStreamPlayer
## Plays one recorded line: its parts one after the other (the words around
## a number, the number, the words after it). Speech owns one of these and
## keeps time for the words itself; this only plays the sound and says when
## it has run out.

signal started
signal ran_out

var parts: Array = []
var index := -1
## Where in its file the part playing now ends (seconds), for a part that is
## a stretch of a longer file (a name); -1 for a whole clip.
var _until := -1.0


func _ready() -> void:
	finished.connect(_on_finished)
	set_process(false)
	if index >= 0 and index < parts.size() and not playing:
		_play_current()


## Starts a line: parts are {stream, length, words}, and "from" for a part
## that starts that far into its file and lasts length. speed above 1 plays
## faster (the bus keeps the pitch where it was).
func play_parts(list: Array, speed: float) -> void:
	parts = list
	index = 0
	pitch_scale = maxf(0.5, speed)
	if is_inside_tree():
		_play_current()


## Stops the line.
func halt() -> void:
	parts = []
	index = -1
	_until = -1.0
	set_process(false)
	stop()


func _play_current() -> void:
	if index < 0 or index >= parts.size():
		return
	var part: Dictionary = parts[index]
	stream = part["stream"]
	if part.has("from"):
		_until = float(part["from"]) + float(part["length"])
		set_process(true)
		play(float(part["from"]))
	else:
		_until = -1.0
		set_process(false)
		play()
	if index == 0:
		started.emit()


func _process(_delta: float) -> void:
	# A stretch of a longer file stops where it ends and the next part starts.
	if _until >= 0.0 and playing and get_playback_position() >= _until:
		stop()
		_on_finished()


func _on_finished() -> void:
	if index < 0:
		return
	_until = -1.0
	set_process(false)
	index += 1
	if index >= parts.size():
		index = -1
		ran_out.emit()
		return
	_play_current()
