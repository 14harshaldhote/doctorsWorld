@tool
extends EditorPlugin
## Registers the export step that adds the reminders code to the iOS build.

var _export: EditorExportPlugin


func _enter_tree() -> void:
	_export = preload("res://addons/dw_reminders/export_plugin.gd").new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	if _export != null:
		remove_export_plugin(_export)
		_export = null
