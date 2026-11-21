class_name SaveStore
extends RefCounted
## Keeps the career in one JSON file, never loses it by accident, and
## notices when it has been edited outside the game.
##
## Saves are written to a temporary file first and then renamed, so a crash
## halfway through never leaves a broken save. The last three saves are kept
## as backups (save.bak1.json is the newest). A save that cannot be used
## (damaged, written by a newer build, or edited) is moved aside, never
## deleted or overwritten, and the newest backup that is still good takes
## its place; with none, a new career starts.
##
## Version 3 seals each save: an HMAC-SHA256 of its contents, keyed with a
## phrase in the code and a random secret made once per install (kept in
## .install next to the save). Changing a number in a text editor breaks the
## seal. Someone who takes the app itself apart could still forge one; this
## stops save editing, not that. An older, unsealed save (version 1 or 2) is
## taken once, from before this install sealed anything, and never after.
## Every save loaded is also checked for numbers no career could reach.

## Version 2 added story progress: trust, story facts, the clock and settings.
## Version 3 added the seal.
const CURRENT_VERSION := 3
const DEFAULT_PATH := "user://save.json"
const BACKUPS := 3
## Part of the seal's key. Not a secret from anyone who reads the app's
## code, but enough that a hand-edited save is caught.
const PEPPER := "dw|ward4|casualty|7f3a9c1e5b|the-chai-is-always-cold"
const INSTALL_FILE := ".install"
## The most experience a career could have: very generous, so it only
## catches numbers typed in, never a long or lucky career.
const XP_ALLOWANCE := 20000
const XP_PER_DAY_ALLOWANCE := 4000

enum Outcome { FRESH, LOADED, SET_ASIDE, LEFT_IN_PLACE, RESTORED }

var path: String
## {"secret": hex, "signed": bool}: this install's secret, and whether it
## has sealed a save yet (after which unsealed saves are refused).
var _install := {}


func _init(save_path: String = DEFAULT_PATH) -> void:
	path = save_path


## Stable JSON with sorted keys, so two saves of the same career are
## identical (the save's body; the seal is added when it is written).
static func encode(profile: PlayerProfile) -> String:
	return JSON.stringify(_body(profile), "\t", true)


static func _body(profile: PlayerProfile) -> Dictionary:
	return {"version": CURRENT_VERSION, "profile": profile.to_dict()}


## Reads save text: {"profile": PlayerProfile, "version", "data"} or
## {"error": "corrupt" | "newer_version"}. Does not check the seal (load_or_start does).
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
	return {"profile": PlayerProfile.from_dict(json.data["profile"]), "version": int(version), "data": json.data}


## Keeps a loaded career inside what could really happen. Returns what was
## changed ("" if nothing).
static func make_plausible(profile: PlayerProfile) -> String:
	var most := XP_ALLOWANCE + XP_PER_DAY_ALLOWANCE * maxi(1, profile.day)
	if profile.total_xp > most:
		profile.total_xp = most
		return "xp"
	if profile.total_xp < 0:
		profile.total_xp = 0
		return "xp"
	return ""


## Loads the career, or starts a new one. Returns {profile, outcome,
## can_save, backup (where an unusable save was moved, or ""), restored
## (the backup loaded instead, or ""), reason ("" or "corrupt",
## "newer_version", "tampered")}.
func load_or_start() -> Dictionary:
	_read_install()
	if not FileAccess.file_exists(path):
		# A crash after the old save became a backup but before the new one
		# was renamed into place leaves the new one, whole, as the temporary
		# file: it is the latest save.
		var temp := path + ".tmp"
		if FileAccess.file_exists(temp):
			var finished := _read(temp)
			if finished.has("profile"):
				DirAccess.rename_absolute(temp, path)
				return _result(finished["profile"], Outcome.LOADED)
		return _result(PlayerProfile.new(), Outcome.FRESH)
	var verdict := _read(path)
	if verdict.has("profile"):
		return _result(verdict["profile"], Outcome.LOADED)
	var reason: String = verdict["error"]
	var aside := _set_aside_path("tampered" if reason == "tampered" else "unreadable")
	if DirAccess.rename_absolute(path, aside) != OK:
		var kept := _result(PlayerProfile.new(), Outcome.LEFT_IN_PLACE)
		kept["reason"] = reason
		return kept
	var backup := _newest_good_backup()
	var result := _result(PlayerProfile.new(), Outcome.SET_ASIDE)
	if not backup.is_empty():
		result = _result(backup["profile"], Outcome.RESTORED)
		result["restored"] = backup["path"]
	result["backup"] = aside
	result["reason"] = reason
	return result


## Writes the career atomically, sealed, keeping the last saves as backups.
## Returns OK or the error.
func save(profile: PlayerProfile) -> Error:
	var folder := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(folder):
		var made := DirAccess.make_dir_recursive_absolute(folder)
		if made != OK:
			return made
	_read_install()
	var data := _body(profile)
	data["seal"] = _seal(JSON.parse_string(JSON.stringify(data, "", true)))
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t", true))
	file.close()
	_rotate_backups()
	var moved := DirAccess.rename_absolute(temp, path)
	if moved == OK and not bool(_install.get("signed", false)):
		_install["signed"] = true
		_write_install()
	return moved


## The save's backups, newest first.
func backup_paths() -> PackedStringArray:
	var found := PackedStringArray()
	var stem := path.get_basename()
	for number in range(1, BACKUPS + 1):
		found.append("%s.bak%d.json" % [stem, number])
	return found


## Reads and checks one save file: {"profile"} or {"error"}.
func _read(file_path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(file_path)
	if FileAccess.get_open_error() != OK:
		return {"error": "corrupt"}
	var decoded := decode(text)
	if decoded.has("error"):
		return decoded
	var data: Dictionary = decoded["data"]
	if int(decoded["version"]) >= 3:
		var body := data.duplicate()
		body.erase("seal")
		if str(data.get("seal", "")) != _seal(body):
			return {"error": "tampered"}
	elif bool(_install.get("signed", false)):
		# An unsealed save after this install has sealed one: someone took
		# the seal off.
		return {"error": "tampered"}
	var profile: PlayerProfile = decoded["profile"]
	make_plausible(profile)
	return {"profile": profile}


func _newest_good_backup() -> Dictionary:
	for backup in backup_paths():
		if not FileAccess.file_exists(backup):
			continue
		var verdict := _read(backup)
		if verdict.has("profile"):
			return {"profile": verdict["profile"], "path": backup}
	return {}


## bak2 -> bak3, bak1 -> bak2, the save -> bak1 (the oldest drops off).
func _rotate_backups() -> void:
	var backups := backup_paths()
	for index in range(backups.size() - 1, 0, -1):
		if FileAccess.file_exists(backups[index - 1]):
			if FileAccess.file_exists(backups[index]):
				DirAccess.remove_absolute(backups[index])
			DirAccess.rename_absolute(backups[index - 1], backups[index])
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(backups[0]):
			DirAccess.remove_absolute(backups[0])
		DirAccess.rename_absolute(path, backups[0])


## The seal of a save's body (everything but the seal), as hex.
func _seal(body: Variant) -> String:
	var canonical := JSON.stringify(body, "", true)
	var key := (PEPPER + "|" + str(_install.get("secret", ""))).sha256_buffer()
	return Crypto.new().hmac_digest(HashingContext.HASH_SHA256, key, canonical.to_utf8_buffer()).hex_encode()


func _install_path() -> String:
	return path.get_base_dir().path_join(INSTALL_FILE)


## Reads this install's secret, making one the first time.
func _read_install() -> void:
	if not _install.is_empty():
		return
	var install_path := _install_path()
	if FileAccess.file_exists(install_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(install_path))
		if parsed is Dictionary and str(parsed.get("secret", "")).length() == 64:
			_install = {"secret": str(parsed["secret"]), "signed": bool(parsed.get("signed", false))}
			return
	_install = {"secret": Crypto.new().generate_random_bytes(32).hex_encode(), "signed": false}
	_write_install()


func _write_install() -> void:
	var folder := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(folder):
		DirAccess.make_dir_recursive_absolute(folder)
	var file := FileAccess.open(_install_path(), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_install, "", true))
		file.close()


## A free name next to the save: save.unreadable.json (or save.tampered.json),
## then save.unreadable-2.json and so on.
func _set_aside_path(label: String = "unreadable") -> String:
	var folder := path.get_base_dir()
	var stem := path.get_file().get_basename()
	var number := 1
	while true:
		var suffix := "" if number == 1 else "-%d" % number
		var candidate := folder.path_join("%s.%s%s.json" % [stem, label, suffix])
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
		"restored": "",
		"reason": "",
	}
