class_name SpeechBackend
extends RefCounted
## The device's own text-to-speech, through Godot's DisplayServer: on an
## iPhone or iPad that is Apple's speech synthesiser, on a Mac the system
## voices. It reports when an utterance starts, each word it reaches and
## when it ends, so the subtitles can keep pace with the voice.
##
## Tests swap in a fake with the same methods (tests/unit/fake_speech.gd),
## because a headless test run has no voices.

var _hooked := false


## True when the device can speak at all.
func ready() -> bool:
	return ProjectSettings.get_setting("audio/general/text_to_speech", false) \
		and DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH)


## Every voice: dictionaries with name, id and language.
func voices() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if not ready():
		return found
	for voice: Dictionary in DisplayServer.tts_get_voices():
		found.append(voice)
	return found


func speak(text: String, voice: String, volume: int, pitch: float, rate: float, id: int) -> void:
	if not ready():
		return
	_hook()
	DisplayServer.tts_speak(text, voice, volume, pitch, rate, id, true)


func stop() -> void:
	if ready():
		DisplayServer.tts_stop()


func is_speaking() -> bool:
	return ready() and DisplayServer.tts_is_speaking()


## The fake moves its clock here; the real voices run by themselves.
func tick(_delta: float) -> void:
	pass


func _hook() -> void:
	if _hooked:
		return
	_hooked = true
	DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_STARTED, _on_started)
	DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_BOUNDARY, _on_boundary)
	DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_ENDED, _on_ended)
	DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_CANCELED, _on_canceled)


func _on_started(id: int) -> void:
	Speech.on_event("start", id, 0)


func _on_boundary(position: int, id: int) -> void:
	Speech.on_event("word", id, position)


func _on_ended(id: int) -> void:
	Speech.on_event("end", id, 0)


func _on_canceled(id: int) -> void:
	Speech.on_event("cancel", id, 0)
