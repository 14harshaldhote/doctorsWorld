class_name StoryBook
extends RefCounted
## Loads the story files in res://story: the cast (cast.json) and the
## conversations and scenes (one JSON file per chapter).
##
## Writing a new conversation means editing a JSON file, not code. Each
## conversation is a list of steps; see StoryRunner for what a step can be.

const FOLDER := "res://story"

static var _cache := {}


## The cast: id -> {name, role, voice, trust}. "you" is the player.
static func cast() -> Dictionary:
	return chapter("cast")


## A whole chapter file, for example chapter("day1") -> {conversation id: steps}.
static func chapter(chapter_name: String) -> Dictionary:
	if not _cache.has(chapter_name):
		_cache[chapter_name] = _read(FOLDER.path_join(chapter_name + ".json"))
	return _cache[chapter_name]


## One conversation's steps, or [] if it does not exist.
static func conversation(chapter_name: String, id: String) -> Array:
	var found: Variant = chapter(chapter_name).get(id)
	return found if typeof(found) == TYPE_ARRAY else []


## Every chapter file in the story folder except the cast.
static func chapter_names() -> PackedStringArray:
	var names := PackedStringArray()
	for file in DirAccess.get_files_at(FOLDER):
		# Exported games list "file.json.remap" style names for some files.
		var plain := file.trim_suffix(".remap")
		if plain.ends_with(".json") and plain != "cast.json":
			names.append(plain.get_basename())
	names.sort()
	return names


static func _read(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Story file missing or empty: %s" % path)
		return {}
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("Story file %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("Story file %s must hold an object" % path)
		return {}
	return json.data
