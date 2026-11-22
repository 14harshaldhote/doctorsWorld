extends SceneTree
## Writes every line a made-up casualty patient can say, in every voice that
## can say it (PatientVoices.catalogue()), for tools/make_voices.py:
##
##   godot --headless --path . -s res://tools/patient_lines.gd
##
## The file is tools/patient_lines.json: [{"who", "text", "mood"}]. Run it
## again whenever story/conditions.json or story/patients.json changes.


func _initialize() -> void:
	var lines := PatientVoices.catalogue()
	var file := FileAccess.open("res://tools/patient_lines.json", FileAccess.WRITE)
	if file == null:
		push_error("can't write tools/patient_lines.json")
		quit(1)
		return
	file.store_string(JSON.stringify(lines, "\t") + "\n")
	file.close()
	print("%d patient lines" % lines.size())
	quit()
