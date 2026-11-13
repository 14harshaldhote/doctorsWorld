class_name GameSettings
extends RefCounted
## The player's settings for this device: how loud the music, sound effects
## and voices are, whether lines are read aloud (how fast, and in which
## voice for the player's doctor), the text size, reduced motion, the
## colour-blind-safe monitor and the graphics mode. They belong to the device, not the career,
## so a new career keeps them. Kept in their own small JSON file, written
## safely the same way as the save.

const DEFAULT_PATH := "user://settings.json"
## How much bigger text gets at each text size.
const TEXT_SCALES := [1.0, 1.12, 1.25]
const TEXT_SIZE_NAMES := ["Standard", "Large", "Larger"]
## "smooth" runs at 60 frames a second at full resolution; "saver" runs at
## 30 at a lower 3D resolution, for older iPhones and long sessions.
const GRAPHICS := ["smooth", "saver"]
const GRAPHICS_NAMES := {"smooth": "Smooth", "saver": "Battery saver"}
const SAVER_3D_SCALE := 0.75
const BUSES := ["Music", "Effects", "Voices"]

## The settings in use. Main loads them at start-up.
static var current := GameSettings.new()

var music := 0.6
var effects := 0.8
var voices := 0.8
var text_size := 0
var reduce_motion := false
var colour_safe := false
var graphics := "smooth"
## Characters read their lines aloud (see Speech).
var read_aloud := true
## Index into Speech.SPEEDS: slower, normal, faster.
var speech_speed := 1


func text_scale() -> float:
	return TEXT_SCALES[clampi(text_size, 0, TEXT_SCALES.size() - 1)]


## The volume (0 to 1) of a bus by name.
func volume(bus: String) -> float:
	match bus:
		"Music":
			return music
		"Effects":
			return effects
		"Voices":
			return voices
	return 1.0


func set_volume(bus: String, value: float) -> void:
	var clean := clampf(value, 0.0, 1.0)
	match bus:
		"Music":
			music = clean
		"Effects":
			effects = clean
		"Voices":
			voices = clean


func to_dict() -> Dictionary:
	return {"music": music, "effects": effects, "voices": voices, "text_size": text_size,
		"reduce_motion": reduce_motion, "colour_safe": colour_safe, "graphics": graphics,
		"read_aloud": read_aloud, "speech_speed": speech_speed}


## Reads saved settings, keeping the default for anything missing or broken.
static func from_dict(data: Variant) -> GameSettings:
	var made := GameSettings.new()
	if typeof(data) != TYPE_DICTIONARY:
		return made
	var raw := data as Dictionary
	for bus: String in BUSES:
		var key := bus.to_lower()
		if typeof(raw.get(key)) in [TYPE_INT, TYPE_FLOAT]:
			made.set_volume(bus, float(raw[key]))
	if typeof(raw.get("text_size")) in [TYPE_INT, TYPE_FLOAT]:
		made.text_size = clampi(int(raw["text_size"]), 0, TEXT_SCALES.size() - 1)
	if typeof(raw.get("speech_speed")) in [TYPE_INT, TYPE_FLOAT]:
		made.speech_speed = clampi(int(raw["speech_speed"]), 0, 2)
	for toggle: String in ["reduce_motion", "colour_safe", "read_aloud"]:
		if typeof(raw.get(toggle)) == TYPE_BOOL:
			made.set(toggle, raw[toggle])
	if str(raw.get("graphics", "")) in GRAPHICS:
		made.graphics = str(raw["graphics"])
	return made


func duplicate_settings() -> GameSettings:
	return GameSettings.from_dict(to_dict())


## The graphics mode a device starts with. Older iPhones (before the iPhone
## 11) and iPads (before the 8th generation) start on Battery saver. model
## is OS.get_model_name(), such as "iPhone12,1".
static func default_graphics(model: String) -> String:
	for family: String in ["iPhone", "iPad"]:
		if model.begins_with(family):
			var major := model.trim_prefix(family).get_slice(",", 0)
			if major.is_valid_int():
				return "saver" if int(major) < (12 if family == "iPhone" else 11) else "smooth"
	return "smooth"


## Loads the settings file. A missing or damaged file gives the defaults
## (with the graphics mode chosen for this device).
static func load_from(path: String = DEFAULT_PATH) -> GameSettings:
	if not FileAccess.file_exists(path):
		var fresh := GameSettings.new()
		fresh.graphics = default_graphics(OS.get_model_name())
		return fresh
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return GameSettings.new()
	return from_dict(json.data)


## Writes the settings to a temporary file, then renames it into place.
func save_to(path: String = DEFAULT_PATH) -> Error:
	var folder := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(folder):
		var made := DirAccess.make_dir_recursive_absolute(folder)
		if made != OK:
			return made
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_dict(), "\t", true))
	file.close()
	return DirAccess.rename_absolute(temp, path)


## Makes the Music, Effects and Voices buses if they are missing, set to
## the current settings.
static func ensure_buses() -> void:
	if AudioServer.get_bus_index(&"Voices") < 0:
		current.apply_audio()


## Makes the Music, Effects and Voices buses (once) and sets their volumes.
func apply_audio() -> void:
	for bus: String in BUSES:
		var index := AudioServer.get_bus_index(bus)
		if index < 0:
			AudioServer.add_bus()
			index = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")
		var level := volume(bus)
		AudioServer.set_bus_mute(index, level <= 0.001)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.001)))


## Applies the graphics mode to the game window. (Text size is applied to
## each label as it is made; see UiKit.refresh_text().)
func apply_display(window: Window) -> void:
	if window == null:
		return
	var saver := graphics == "saver"
	Engine.max_fps = 30 if saver else 60
	window.scaling_3d_scale = SAVER_3D_SCALE if saver else 1.0
	window.msaa_3d = Viewport.MSAA_DISABLED if saver else Viewport.MSAA_2X


func apply(window: Window) -> void:
	apply_audio()
	apply_display(window)
