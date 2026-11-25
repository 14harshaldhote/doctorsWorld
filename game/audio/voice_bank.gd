class_name VoiceBank
extends RefCounted
## Recorded voices: every line made ahead of time with a natural voice
## (tools/make_voices.py), so people sound like people rather than the
## phone's reading voice. Each character has their own voice for the whole
## game. A line is found by who says it and what it says, ignoring case and
## punctuation.
##
## Lines that use the player's name are stored with {called} in its place.
## Each is recorded whole, saying "Doctor" there, and also in pieces: the
## words before the name and the words after it. A few hundred common names
## are recorded as "Doctor Verma." in the voice of everyone who uses the
## player's name, so a player called one of them hears their own name, put
## between the pieces. Any other name hears the whole line with "Doctor"
## (and Speech.address shows "Doctor" on screen too). Lines with
## numbers in them (a pulse, a count of swabs) are stored with # for each
## number and are put together from clips: the words around the numbers,
## and each number said on its own by the same person.
##
## A line made of several recorded lines (a made-up patient's answer is a
## hello, their opening words and the answer itself) is put together from
## those clips, sentence by sentence.
##
## A line with no clip is read by the device's own voice instead (Speech).

const FOLDER := "res://assets/voices/"
const MANIFEST := FOLDER + "manifest.json"

static var _loaded := false
## The background task reading the manifest (warm), or -1.
static var _warming := -1
## "who|key" to the line's parts.
static var _lines := {}
## who to [{"regex", "kinds", "parts"}] for lines with a name or a number.
static var _patterns := {}
## who to {number: part}.
static var _numbers := {}
## A name as looked up ("verma") to {"clip", "said": {who: {ending: part}}}:
## the recordings of "Doctor Verma." in everyone's voice, one file a name.
static var _names := {}
## Who has lines that can be said with a name in them.
static var _naming := {}
static var _cleaner: RegEx
static var _ender: RegEx


## Forgets what was loaded; the manifest is read again when next needed.
static func reset() -> void:
	_finish_warming()
	_loaded = false
	_lines.clear()
	_patterns.clear()
	_numbers.clear()
	_names.clear()
	_naming.clear()


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
		var called := ""
		var kinds: Array = pattern["kinds"]
		for index in kinds.size():
			if str(kinds[index]) == "#":
				values.append(int(found.get_string(index + 1)))
			else:
				called = name_key(found.get_string(index + 1))
		var parts := []
		# The player's own name, when it was recorded in this voice.
		if pattern.has("named") and can_say_name(who, called):
			parts = _resolve(who, pattern["named"], values, called)
		if parts.is_empty():
			parts = _resolve(who, pattern["parts"], values)
		if not parts.is_empty():
			return parts
	return _cover(who, text)


## How a name is looked up: "Dr. D'Souza" is "d souza".
static func name_key(called: String) -> String:
	var plain := normalize(called)
	for title in ["dr ", "doctor "]:
		if plain.begins_with(title):
			return plain.substr(title.length())
	return plain


## True when who's recorded voice can say the doctor's name (as "Dr. Verma"
## or "verma") in their lines.
static func can_say_name(who: String, called: String) -> bool:
	_load()
	var entry: Dictionary = _names.get(name_key(called), {})
	return not entry.is_empty() and (entry["said"] as Dictionary).has(who)


## True when who has recorded lines with the doctor's name in them (so a
## name their voice can't say has to be "Doctor" on screen too).
static func names_doctor(who: String) -> bool:
	_load()
	return _naming.has(who)


## A line put together from recorded lines: split at the ends of sentences
## and covered from the start, each time by the longest run of sentences
## that has a clip. Empty unless every sentence is covered.
static func _cover(who: String, text: String) -> Array:
	var pieces := PackedStringArray()
	for sentence in sentences(text):
		var plain := normalize(sentence)
		if not plain.is_empty():
			pieces.append(plain)
	if pieces.size() < 2:
		return []
	var parts := []
	var start := 0
	while start < pieces.size():
		var found := false
		for stop in range(pieces.size(), start, -1):
			var key := who + "|" + " ".join(pieces.slice(start, stop))
			if _lines.has(key):
				var more := _resolve(who, _lines[key], [])
				if more.is_empty():
					return []
				parts.append_array(more)
				start = stop
				found = true
				break
		if not found:
			return []
	return parts


## A line cut into sentences, each with its own stop: "Two days. Since the
## fest!" is ["Two days.", "Since the fest!"].
static func sentences(text: String) -> PackedStringArray:
	if _ender == null:
		_ender = RegEx.create_from_string("[.?!][\"')]*\\s+")
	var found := PackedStringArray()
	var start := 0
	for ending in _ender.search_all(text):
		var piece := text.substr(start, ending.get_end() - start).strip_edges()
		if not piece.is_empty():
			found.append(piece)
		start = ending.get_end()
	var rest := text.substr(start).strip_edges()
	if not rest.is_empty():
		found.append(rest)
	return found


## Starts reading the manifest on another thread, at boot. It is 1.8 MB of
## JSON and takes a phone a good tenth of a second, which would otherwise
## stall the game the first time anyone speaks.
static func warm() -> void:
	if _loaded or _warming >= 0:
		return
	_loaded = true
	_warming = WorkerThreadPool.add_task(_read_manifest, false, "Voice manifest")


static func _load() -> void:
	_finish_warming()
	if _loaded:
		return
	_loaded = true
	_read_manifest()


# Waits for a background read to end (usually long done by now).
static func _finish_warming() -> void:
	if _warming < 0:
		return
	WorkerThreadPool.wait_for_task_completion(_warming)
	_warming = -1


static func _read_manifest() -> void:
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
		if "{" in key:
			_naming[who] = true
			if entry.has("named"):
				compiled["named"] = entry["named"]
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
	var names: Dictionary = manifest.get("names", {})
	for key: String in names:
		var entry: Dictionary = names[key]
		if entry.has("clip") or entry.has("stream"):
			_names[key] = entry


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
## replaced by the clip of the n-th number in values, and a {"name": "."}
## part by who saying the name called ends that way ("Doctor Verma."). A
## name is a stretch of its file: "from" seconds in, for "length". Empty if
## any clip is missing.
static func _resolve(who: String, parts: Array, values: Array, called: String = "") -> Array:
	var playable := []
	for part: Dictionary in parts:
		var piece := part
		if part.has("name"):
			var entry: Dictionary = _names.get(called, {})
			var said: Array = ((entry.get("said", {}) as Dictionary).get(who, {}) as Dictionary).get(str(part["name"]), [])
			if said.size() < 3:
				return []
			piece = {"from": float(said[0]), "length": float(said[1]), "words": said[2]}
			if entry.has("stream"):
				piece["stream"] = entry["stream"]
			else:
				piece["clip"] = entry["clip"]
		elif part.has("number"):
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
		var playing := {"stream": stream, "length": length, "words": piece.get("words", [])}
		if piece.has("from"):
			playing["from"] = float(piece["from"])
		playable.append(playing)
	return playable
