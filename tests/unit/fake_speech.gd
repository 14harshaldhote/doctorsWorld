extends SpeechBackend
## A pretend voice engine for the tests: voices like a fresh iPhone's, and
## speech that runs on tick() at a steady pace, sending the same events as
## the real one (start, each word, end, cancel).

const VOICES := [
	{"name": "Samantha", "id": "com.apple.voice.compact.en-US.Samantha", "language": "en-US"},
	{"name": "Karen", "id": "com.apple.voice.compact.en-AU.Karen", "language": "en-AU"},
	{"name": "Moira", "id": "com.apple.voice.compact.en-IE.Moira", "language": "en-IE"},
	{"name": "Rishi", "id": "com.apple.voice.compact.en-IN.Rishi", "language": "en-IN"},
	{"name": "Daniel", "id": "com.apple.voice.compact.en-GB.Daniel", "language": "en-GB"},
	{"name": "Albert", "id": "com.apple.speech.synthesis.voice.Albert", "language": "en-US"},
	{"name": "Eddy", "id": "com.apple.eloquence.en-US.Eddy", "language": "en-US"},
	{"name": "Thomas", "id": "com.apple.voice.compact.fr-FR.Thomas", "language": "fr-FR"},
]

## Every line spoken: {text, voice, volume, pitch, rate, id}.
var spoken: Array[Dictionary] = []
## Letters a second at rate 1.
var pace := 15.0
## True: lines never start (a broken engine).
var mute := false
## False: no word marks are sent (some engines don't).
var marks := true
var voice_list: Array = VOICES

var _line := {}
var _words: Array[int] = []


func ready() -> bool:
	return true


func voices() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for voice: Dictionary in voice_list:
		found.append(voice.duplicate())
	return found


func speak(text: String, voice: String, volume: int, pitch: float, rate: float, id: int) -> void:
	_cancel()
	spoken.append({"text": text, "voice": voice, "volume": volume, "pitch": pitch, "rate": rate, "id": id})
	if mute:
		return
	_line = {"text": text, "id": id, "time": 0.0, "started": false, "rate": rate}
	_words.clear()
	for index in text.length():
		if text[index] != " " and (index == 0 or text[index - 1] == " "):
			_words.append(index)


func stop() -> void:
	_cancel()


func is_speaking() -> bool:
	return not _line.is_empty()


## The letter of the spoken text the voice has reached (-1 when silent).
func reached() -> float:
	if _line.is_empty():
		return -1.0
	return float(_line["time"]) * pace * float(_line["rate"])


func last() -> Dictionary:
	return spoken[spoken.size() - 1] if not spoken.is_empty() else {}


func tick(delta: float) -> void:
	if _line.is_empty():
		return
	var id := int(_line["id"])
	if not bool(_line["started"]):
		_line["started"] = true
		Speech.on_event("start", id, 0)
		if not _same(id):
			return
	_line["time"] = float(_line["time"]) + delta
	while marks and not _words.is_empty() and _words[0] <= reached():
		Speech.on_event("word", id, _words.pop_front())
		if not _same(id):
			return
	if reached() >= str(_line["text"]).length():
		_line = {}
		Speech.on_event("end", id, 0)


func _same(id: int) -> bool:
	return not _line.is_empty() and int(_line["id"]) == id


func _cancel() -> void:
	if _line.is_empty():
		return
	var id := int(_line["id"])
	_line = {}
	Speech.on_event("cancel", id, 0)
