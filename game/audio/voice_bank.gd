class_name VoiceBank
extends RefCounted
## Recorded voices: every line made ahead of time with a natural voice
## (tools/make_voices.py), so people sound like people rather than the
## phone's reading voice. Each character has their own voice for the whole
## game. A line is found by who says it and what it says, ignoring case and
## punctuation.
##
## Lines that use the player's name are stored with {called} in its place
## and say "Doctor" there, so one clip serves every player. Lines with
## numbers in them (a pulse, a count of swabs) are stored with # for each
## number and are put together from clips: the words around the numbers,
## and each number said on its own by the same person.
##
## A line with no clip is read by the device's own voice instead (Speech).

const FOLDER := "res://assets/voices/"
const MANIFEST := FOLDER + "manifest.json"

static var _loaded := false
## "who|key" to the line's parts.
static var _lines := {}
## who to [{"regex", "kinds", "parts"}] for lines with a name or a number.
static var _patterns := {}
## who to {number: part}.
static var _numbers := {}
static var _cleaner: RegEx


## Forgets what was loaded; the manifest is read again when next needed.
static func reset() -> void:
	_loaded = false
	_lines.clear()
	_patterns.clear()
	_numbers.clear()


## Uses a manifest given as data (tests). Parts may carry a "stream"
## instead of a "clip" file.
static func use(manifest: Dictionary) -> void:
	reset()
	_read(manifest)
	_loaded = true


## True when there are recorded lines at all.
static func has_lines() -> bool:
	_load()
	return not _lines.is_empty() or not _patterns.is_empty()


## A line as it is looked up: lower case, letters, digits and {names},
## single spaces.
static func normalize(text: String) -> String:
	if _cleaner == null:
		_cleaner = RegEx.create_from_string("[^a-z0-9{}]+")
	return _cleaner.sub(text.to_lower(), " ", true).strip_edges()


## The recording of a line said by who, as parts to play one after the
## other: [{stream, length, words}], where words are the times (seconds
## into the part) at which each word ends. Empty when there is none.
static func find(who: String, text: String) -> Array:
	_load()
	var plain := normalize(text)
	if plain.is_empty():
		return []
	var key := who + "|" + plain
	if _lines.has(key):
		return _resolve(who, _lines[key], [])
	for pattern: Dictionary in _patterns.get(who, []):
		var found := (pattern["regex"] as RegEx).search(plain)
		if found == null:
			continue
		var values := []
		var kinds: Array = pattern["kinds"]
		for index in kinds.size():
			if str(kinds[index]) == "#":
				values.append(int(found.get_string(index + 1)))
		var parts := _resolve(who, pattern["parts"], values)
		if not parts.is_empty():
			return parts
	return []


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(MANIFEST):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if data is Dictionary:
		_read(data)


static func _read(manifest: Dictionary) -> void:
	for entry: Dictionary in manifest.get("lines", []):
		var who := str(entry.get("who", ""))
		var key := str(entry.get("key", ""))
		var parts: Array = entry.get("parts", [])
		if who.is_empty() or key.is_empty() or parts.is_empty():
			continue
		if not "#" in key and not "{" in key:
			_lines[who + "|" + key] = parts
			continue
		var compiled := _compile(key)
		if compiled.is_empty():
			continue
		compiled["parts"] = parts
		if not _patterns.has(who):
			_patterns[who] = []
		(_patterns[who] as Array).append(compiled)
	var numbers: Dictionary = manifest.get("numbers", {})
	for who: String in numbers:
		var said := {}
		var list: Dictionary = numbers[who]
		for value: String in list:
			said[int(value)] = list[value]
		_numbers[who] = said


## A regular expression for a key with {names} and # numbers in it, and the
## kind of each captured piece ("#" or "name"). Empty when the key is only a
## name (it would match anything).
static func _compile(key: String) -> Dictionary:
	var pieces := PackedStringArray()
	var kinds := []
	var has_words := false
	for token in key.split(" ", false):
		if token == "#":
			pieces.append("(\\d+)")
			kinds.append("#")
		elif token.begins_with("{") and token.ends_with("}"):
			pieces.append("(.+?)")
			kinds.append("name")
		else:
			pieces.append(token)
			has_words = true
	if not has_words and kinds.has("name"):
		return {}
	var regex := RegEx.create_from_string("^" + " ".join(pieces) + "$")
	if not regex.is_valid():
		return {}
	return {"regex": regex, "kinds": kinds}


## Turns stored parts into playable ones, with each {"number": n} part
## replaced by the clip of the n-th number in values. Empty if any clip is
## missing.
static func _resolve(who: String, parts: Array, values: Array) -> Array:
	var playable := []
	for part: Dictionary in parts:
		var piece := part
		if part.has("number"):
			var index := int(part["number"])
			if index >= values.size():
				return []
			piece = (_numbers.get(who, {}) as Dictionary).get(int(values[index]), {})
			if piece.is_empty():
				return []
		var stream: AudioStream = piece.get("stream")
		if stream == null:
			var path := FOLDER + str(piece.get("clip", ""))
			if not piece.has("clip") or not ResourceLoader.exists(path):
				return []
			stream = load(path) as AudioStream
		if stream == null:
			return []
		var length := float(piece.get("length", stream.get_length()))
		playable.append({"stream": stream, "length": length, "words": piece.get("words", [])})
	return playable
