class_name SaveStore
extends RefCounted
## Keeps the career in one JSON file and never loses it by accident.
##
## Saves are written to a temporary file first and then renamed, so a crash
## halfway through never leaves a broken save. A save that cannot be read
## (damaged, or written by a newer build) is moved aside, never deleted or
## overwritten. Ported from the Swift prototype's FileSaveStore.

const CURRENT_VERSION := 1
const DEFAULT_PATH := "user://save.json"

enum Outcome { FRESH, LOADED, SET_ASIDE, LEFT_IN_PLACE }

var path: String


func _init(save_path: String = DEFAULT_PATH) -> void:
	path = save_path


## Stable JSON with sorted keys, so two saves of the same career are identical.
static func encode(profile: PlayerProfile) -> String:
	return JSON.stringify({"version": CURRENT_VERSION, "profile": profile.to_dict()}, "\t", true)


## Reads save text: {"profile": PlayerProfile} or {"error": "corrupt" | "newer_version"}.
static func decode(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {"error": "corrupt"}
	var version: Variant = json.data.get("version")
	if typeof(version) not in [TYPE_INT, TYPE_FLOAT]:
		return {"error": "corrupt"}
	if int(version) > CURRENT_VERSION:
		return {"error": "newer_version", "version": int(version)}
	if int(version) < 1 or typeof(json.data.get("profile")) != TYPE_DICTIONARY:
		return {"error": "corrupt"}
	return {"profile": PlayerProfile.from_dict(json.data["profile"])}


## Loads the career, or starts a new one. Returns
## {profile, outcome, can_save, backup (path or ""), reason ("" or error)}.
func load_or_start() -> Dictionary:
	if not FileAccess.file_exists(path):
		return _result(PlayerProfile.new(), Outcome.FRESH)
	var text := FileAccess.get_file_as_string(path)
	var decoded := decode(text) if FileAccess.get_open_error() == OK else {"error": "corrupt"}
	if decoded.has("profile"):
		return _result(decoded["profile"], Outcome.LOADED)
	var reason: String = decoded["error"]
	var backup := _set_aside_path()
	if DirAccess.rename_absolute(path, backup) != OK:
		var kept := _result(PlayerProfile.new(), Outcome.LEFT_IN_PLACE)
		kept["reason"] = reason
		return kept
	var moved := _result(PlayerProfile.new(), Outcome.SET_ASIDE)
	moved["backup"] = backup
	moved["reason"] = reason
	return moved


## Writes the career atomically. Returns OK or the error.
func save(profile: PlayerProfile) -> Error:
	var folder := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(folder):
		var made := DirAccess.make_dir_recursive_absolute(folder)
		if made != OK:
			return made
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(encode(profile))
	file.close()
	return DirAccess.rename_absolute(temp, path)


## A free name next to the save: save.unreadable.json, then
## save.unreadable-2.json and so on.
func _set_aside_path() -> String:
	var folder := path.get_base_dir()
	var stem := path.get_file().get_basename()
	var number := 1
	while true:
		var suffix := "" if number == 1 else "-%d" % number
		var candidate := folder.path_join("%s.unreadable%s.json" % [stem, suffix])
		if not FileAccess.file_exists(candidate):
			return candidate
		number += 1
	return ""


static func _result(profile: PlayerProfile, outcome: Outcome) -> Dictionary:
	return {
		"profile": profile,
		"outcome": outcome,
		"can_save": outcome != Outcome.LEFT_IN_PLACE,
		"backup": "",
		"reason": "",
	}
