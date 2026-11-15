@tool
extends EditorExportPlugin
## On an iOS export, adds reminders_ios.cpp to the Xcode project's
## generated C++ file and links the phone's UserNotifications framework.
## The game talks to that code through two environment variables (see
## ReminderBackend), so it needs no engine headers and builds with any
## Godot version.

const SOURCE := "res://addons/dw_reminders/reminders_ios.cpp"


func _get_name() -> String:
	return "DoctorsWorldReminders"


func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformAppleEmbedded


func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	var code := FileAccess.get_file_as_string(SOURCE)
	if code.is_empty():
		push_error("Doctors World reminders: %s is missing; the build will have no reminders." % SOURCE)
		return
	add_apple_embedded_platform_cpp_code("\n" + code + "\n")
	add_apple_embedded_platform_linker_flags("-framework UserNotifications")
