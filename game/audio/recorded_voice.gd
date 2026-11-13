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


func _ready() -> void:
	finished.connect(_on_finished)
	if index >= 0 and index < parts.size() and not playing:
		_play_current()


## Starts a line: parts are {stream, length, words}. speed above 1 plays
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
	stop()


func _play_current() -> void:
	if index < 0 or index >= parts.size():
		return
	stream = (parts[index] as Dictionary)["stream"]
	play()
	if index == 0:
		started.emit()


func _on_finished() -> void:
	if index < 0:
		return
	index += 1
	if index >= parts.size():
		index = -1
		ran_out.emit()
		return
	_play_current()
