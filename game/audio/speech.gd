class_name Speech
extends RefCounted
## Everyone reads their lines aloud with the device's own voices (on an
## iPhone, the voices in Settings > Accessibility > Spoken Content), so what
## you hear is exactly what you see typed. Each character keeps one voice
## for the whole game, picked by whether they speak higher or lower, with
## their own pitch on top so two people sharing a voice still sound apart.
## The player's doctor speaks too, in the voice chosen in Settings (or the
## character creator).
##
## Free, offline and on the device: nothing is sent anywhere. When the
## device has no English voice, or "Read lines aloud" is off, say() returns
## 0 and the caller falls back to the old murmur.
##
## Only one line speaks at a time; a new line cuts off the one before. The
## owner of a line hears back through its callables: on_start(), on_word(
## end of the word in the shown text) and on_done().

## Speech speed choices (Settings) and how much each one speeds the voice.
const SPEED_NAMES := ["Slower", "Normal", "Faster"]
const SPEEDS := [0.8, 1.0, 1.2]
## The player's own voice (Settings and the character creator).
const YOUR_VOICE_NAMES := ["Lighter", "Deeper", "Silent"]
## A touch under the device's default pace, for clearer speech.
const BASE_RATE := 0.95
## English voices in order of preference: the game is set in India.
const LANGUAGES := ["en-IN", "en-GB", "en-US", "en-IE", "en-AU", "en-NZ", "en-ZA"]
## Voice names by how high they speak (Apple, Microsoft and a few others).
const HIGHER := [
	"samantha", "karen", "moira", "tessa", "veena", "isha", "lekha", "sangeeta", "kiyara", "fiona", "victoria",
	"kate", "serena", "martha", "catherine", "allison", "ava", "susan", "zoe", "nicky", "stephanie", "kathy",
	"vicki", "princess", "flo", "sandy", "shelley", "grandma", "zira", "hazel", "heera", "linda", "eva", "jenny",
	"aria", "neerja", "emma", "olivia", "amy", "joanna", "kendra", "kimberly", "salli", "ivy", "raveena", "aditi",
	"female", "woman",
]
const LOWER := [
	"daniel", "alex", "fred", "aaron", "arthur", "gordon", "oliver", "rishi", "tom", "lee", "malcolm", "ralph",
	"junior", "eddy", "reed", "rocko", "grandpa", "evan", "nathan", "aditya", "jamie", "david", "mark", "ravi",
	"george", "james", "richard", "sean", "guy", "prabhat", "brian", "joey", "justin", "matthew", "russell",
	"male", "man",
]
## Joke and effect voices that would make a hospital sound like a cartoon.
const NOVELTY := [
	"albert", "bad news", "bahh", "bells", "boing", "bubbles", "cellos", "good news", "jester", "organ",
	"superstar", "trinoids", "whisper", "wobble", "zarvox", "deranged", "hysterical", "pipe organ",
]
## Capitals that are said letter by letter; other words in capitals are
## only shouted for emphasis, and are said as words.
const ACRONYMS := ["ICU", "VIP", "MBBS", "ECG", "CPR", "OPD", "MRI", "HIV", "IVF", "DNA", "CCTV", "ENT", "NICU"]
## The cast's voice levels (cast.json "voice") centre on these.
const HIGHER_MIDDLE := 1.12
const LOWER_MIDDLE := 0.9

## The voice engine. Tests put a fake one in with use_backend().
static var backend: SpeechBackend
## Off for tools that must not wait on voices (the screenshot tool).
static var enabled := true
static var _pools := {}
static var _picked := {}
static var _next_id := 0
static var _current := {}
static var _pattern: RegEx
static var _words: RegEx


static func device() -> SpeechBackend:
	if backend == null:
		backend = SpeechBackend.new()
	return backend


## Swaps the voice engine and forgets the voices picked so far.
static func use_backend(engine: SpeechBackend) -> void:
	stop()
	backend = engine
	_pools.clear()
	_picked.clear()


## True when lines can be read aloud now: the setting is on, the Voices
## volume is up and the device has an English voice.
static func available() -> bool:
	var settings := GameSettings.current
	if not enabled or not settings.read_aloud or settings.voices <= 0.0 or not device().ready():
		return false
	return not (pools()["higher"] as Array).is_empty() or not (pools()["lower"] as Array).is_empty()


## Whether this person's lines are read aloud ("you" can be set to Silent).
static func speaks(who: String) -> bool:
	if not available():
		return false
	return who != "you" or GameSettings.current.your_voice != 2


## Starts reading a line aloud as a cast member ("you" for the player).
## Returns the line's number, or 0 when it is not read aloud.
static func say(text: String, who: String, on_start: Callable = Callable(), on_word: Callable = Callable(),
		on_done: Callable = Callable()) -> int:
	if not speaks(who):
		return 0
	var voice := voice_for(who)
	var prepared := prepare(text)
	if voice.is_empty() or str(prepared["spoken"]).strip_edges().is_empty():
		return 0
	_end_current()
	_next_id += 1
	_current = {"id": _next_id, "text": text, "map": prepared["map"],
		"start": on_start, "word": on_word, "done": on_done}
	var settings := GameSettings.current
	var rate := BASE_RATE * float(SPEEDS[clampi(settings.speech_speed, 0, SPEEDS.size() - 1)]) * float(voice["rate"])
	device().speak(str(prepared["spoken"]), str(voice["id"]), clampi(roundi(settings.voices * 125.0), 0, 100),
		float(voice["pitch"]), rate, _next_id)
	return _next_id


## Stops whatever is being said.
static func stop() -> void:
	if _current.is_empty():
		return
	_end_current()
	device().stop()
	Music.duck_for_speech(false)


## Stops one line, if it is still the one being said.
static func stop_line(id: int) -> void:
	if not _current.is_empty() and int(_current["id"]) == id:
		stop()


## True while a line (this one, or any with 0) is being said.
static func speaking(id: int = 0) -> bool:
	return not _current.is_empty() and (id == 0 or int(_current["id"]) == id)


## Moves the fake engine's clock (tests); real voices run by themselves.
static func tick(delta: float) -> void:
	if backend != null:
		backend.tick(delta)


## Events from the engine: "start", "word" (at a letter of the spoken
## text), "end" and "cancel".
static func on_event(kind: String, id: int, position: int) -> void:
	if _current.is_empty() or int(_current["id"]) != id:
		return
	match kind:
		"start":
			Music.duck_for_speech(true)
			_call(_current["start"])
		"word":
			_call(_current["word"], [_word_end(position)])
		"end", "cancel":
			var done: Callable = _current["done"]
			_current = {}
			Music.duck_for_speech(false)
			_call(done)


# --- Voices ---------------------------------------------------------------

## The English voices sorted best first, split into higher and lower
## ones; voices of unknown kind go at the end of both.
static func pools() -> Dictionary:
	if _pools.is_empty():
		_pools = sort_voices(device().voices())
	return _pools


static func sort_voices(voices: Array) -> Dictionary:
	var sorted := {"higher": [], "lower": [], "unknown": []}
	for voice: Dictionary in voices:
		var language := str(voice.get("language", "")).replace("_", "-")
		if not language.to_lower().begins_with("en"):
			continue
		var id := str(voice.get("id", ""))
		var label := str(voice.get("name", "")).to_lower()
		if id.is_empty() or "speech.synthesis" in id.to_lower() or _is_novelty(label):
			continue
		var quality := 1
		for word: String in ["premium", "enhanced", "siri", "neural", "natural"]:
			if word in id.to_lower() or word in label:
				quality = 2
		if "eloquence" in id.to_lower():
			quality = 0
		var rank := LANGUAGES.size()
		for index in LANGUAGES.size():
			if language.to_lower().begins_with(str(LANGUAGES[index]).to_lower()):
				rank = index
				break
		var kind := kind_of(label + " " + id.to_lower())
		(sorted[kind] as Array).append({"id": id, "name": str(voice.get("name", "")), "language": language,
			"score": quality * 100 - rank})
	for kind: String in sorted:
		(sorted[kind] as Array).sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["score"]) > int(b["score"]) or (int(a["score"]) == int(b["score"]) and str(a["id"]) < str(b["id"])))
	return {"higher": sorted["higher"] + sorted["unknown"], "lower": sorted["lower"] + sorted["unknown"]}


## "higher", "lower" or "unknown", from the words in a voice's name.
static func kind_of(label: String) -> String:
	if _words == null:
		_words = RegEx.create_from_string("[a-z]+")
	for found in _words.search_all(label.to_lower()):
		var word := found.get_string()
		if word in HIGHER:
			return "higher"
		if word in LOWER:
			return "lower"
	return "unknown"


static func _is_novelty(label: String) -> bool:
	for name: String in NOVELTY:
		if label == name or label.begins_with(name + " "):
			return true
	return false


## The voice for a cast member: {id, pitch, rate}, or {} if none fits.
static func voice_for(who: String) -> Dictionary:
	if who == "you":
		return _your_voice()
	if _picked.has(who):
		return _picked[who]
	var cast := StoryBook.cast()
	var entry: Dictionary = cast.get(who, {})
	var higher := _speaks_higher(entry)
	var pool := _pool(higher)
	if pool.is_empty():
		return {}
	# The cast share the voices out in cast order. The first of each kind
	# is the player's, so the doctor rarely sounds like the person answering.
	var order := 0
	for other: String in cast:
		if other == who:
			break
		if _speaks_higher(cast[other]) == higher:
			order += 1
	var voice: Dictionary = pool[(order + 1) % pool.size()]
	var level := float(entry.get("voice", 1.0))
	var pitch: float
	if bool(entry.get("child", false)):
		pitch = clampf(1.22 + (level - 1.3) * 0.5, 1.15, 1.45)
	else:
		pitch = clampf(1.0 + (level - (HIGHER_MIDDLE if higher else LOWER_MIDDLE)) * 0.8, 0.86, 1.18)
	if (pools()["higher"] as Array).is_empty() != (pools()["lower"] as Array).is_empty():
		# Only one kind of voice on the device: pitch makes the difference.
		var have_higher := not (pools()["higher"] as Array).is_empty()
		if higher and not have_higher:
			pitch *= 1.2
		elif not higher and have_higher:
			pitch *= 0.82
	var picked := {"id": voice["id"], "pitch": pitch, "rate": float(entry.get("pace", 1.0))}
	_picked[who] = picked
	return picked


static func _speaks_higher(entry: Dictionary) -> bool:
	return str(entry.get("gender", "female")) == "female" or bool(entry.get("child", false))


static func _pool(higher: bool) -> Array:
	var pool: Array = pools()["higher" if higher else "lower"]
	return pool if not pool.is_empty() else pools()["lower" if higher else "higher"]


static func _your_voice() -> Dictionary:
	var choice := GameSettings.current.your_voice
	if choice == 2:
		return {}
	var pool := _pool(choice == 0)
	if pool.is_empty():
		return {}
	return {"id": pool[0]["id"], "pitch": 1.03 if choice == 0 else 0.97, "rate": 1.0}


## A short line in the player's voice, for trying the choice out.
static func preview_you() -> void:
	say("Hello. I'm the new doctor.", "you")


# --- Words ------------------------------------------------------------------

## What the voice actually says for a shown line, and for each letter of it
## the letter of the shown line it comes from: "Dr." is said "Doctor",
## "120/80" is "120 over 80", and words in capitals for emphasis are said
## as words, not spelled out.
static func prepare(text: String) -> Dictionary:
	if _pattern == null:
		_pattern = RegEx.create_from_string("\\b(?:Dr|Mr|Mrs|Ms)\\.|\\b[A-Z][A-Z']{2,}\\b|\\b\\d{2,3}/\\d{2,3}\\b|[·*—–_~]")
	var spoken := ""
	var map := PackedInt32Array()
	var at := 0
	for found in _pattern.search_all(text):
		for index in range(at, found.get_start()):
			spoken += text[index]
			map.append(index)
		var replacement := _replacement(found.get_string())
		for letter in replacement:
			spoken += letter
			map.append(found.get_start())
		at = found.get_end()
	for index in range(at, text.length()):
		spoken += text[index]
		map.append(index)
	return {"spoken": spoken, "map": map}


static func _replacement(token: String) -> String:
	match token:
		"Dr.":
			return "Doctor"
		"Mr.":
			return "Mister"
		"Mrs.":
			return "Missus"
		"Ms.":
			return "Miz"
		"·", "—", "–":
			return ","
		"*", "_", "~":
			return ""
	if "/" in token:
		return token.replace("/", " over ")
	return token if token in ACRONYMS else token.to_lower()


## Where the word that starts at a letter of the spoken text ends in the
## shown text.
static func _word_end(position: int) -> int:
	var map: PackedInt32Array = _current["map"]
	var text: String = _current["text"]
	if map.is_empty():
		return text.length()
	var at := map[clampi(position, 0, map.size() - 1)]
	while at < text.length() and text[at] in " \n":
		at += 1
	while at < text.length() and not text[at] in " \n":
		at += 1
	return at


static func _end_current() -> void:
	if _current.is_empty():
		return
	var done: Callable = _current["done"]
	_current = {}
	_call(done)


static func _call(action: Callable, arguments: Array = []) -> void:
	if action.is_valid():
		action.callv(arguments)
