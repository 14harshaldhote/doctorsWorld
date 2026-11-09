class_name ScanTask
extends TrainingTask
## Read an X-ray: look at the front view, zoom in on what is there, turn to
## the side view, then say what it is. Rushing misses things: a button
## battery looks like a coin until you look at its edge.
##
## The case lives in story/cases.json (a "kind": "scan" entry): the lines
## for each look and the possible answers. Time only passes through tick().

const ZOOM_POINTS := 30
const SIDE_POINTS := 25
const ANSWER_POINTS := 35
const PATIENCE_POINTS := 10

var case_id := ""
var patient := ""
var about := ""
var opening := ""
## What is really on the film: "battery", "coin" or "none".
var truth := "battery"
var answers: Array[Dictionary] = []
var lines := {}

## "front" or "side".
var view := "front"
var zoomed := false
var looked_zoom := false
var looked_side := false
var chosen := ""


func _init(which_case: String = "aarav_scan") -> void:
	id = "scan"
	case_id = which_case
	var data: Dictionary = StoryBook.chapter("cases").get(which_case, {})
	patient = str(data.get("patient", "The patient"))
	about = str(data.get("about", ""))
	opening = str(data.get("opening", "Read the film."))
	truth = str(data.get("truth", "battery"))
	var found: Variant = data.get("lines", {})
	if typeof(found) == TYPE_DICTIONARY:
		lines = found
	for entry: Variant in data.get("answers", []):
		if typeof(entry) == TYPE_DICTIONARY:
			answers.append(entry)
	_say(opening)


func title() -> String:
	return "Read " + patient + "'s X-ray"


## Switches between the front and the side film.
func show_view(which: String) -> void:
	if finished or which == view or which not in ["front", "side"]:
		return
	view = which
	zoomed = false
	if which == "side" and not looked_side:
		looked_side = true
		_say(str(lines.get("side", "From the side.")))
	else:
		changed.emit()


## Zooms in on the object (or back out).
func toggle_zoom() -> void:
	if finished:
		return
	zoomed = not zoomed
	if zoomed and view == "front" and not looked_zoom:
		looked_zoom = true
		_say(str(lines.get("zoom", "Closer.")))
	else:
		changed.emit()


func answer(answer_id: String) -> void:
	if finished:
		return
	var entry := answer_entry(answer_id)
	if entry.is_empty():
		return
	chosen = answer_id
	_write_notes()
	_finish()


func answer_entry(answer_id: String) -> Dictionary:
	for entry in answers:
		if str(entry.get("id", "")) == answer_id:
			return entry
	return {}


func right_answer() -> String:
	for entry in answers:
		if bool(entry.get("right", false)):
			return str(entry.get("id", ""))
	return truth


func answered_right() -> bool:
	return not chosen.is_empty() and chosen == right_answer()


func patient_enough() -> bool:
	return looked_zoom and looked_side


func score() -> int:
	var points := 0
	points += ZOOM_POINTS if looked_zoom else 0
	points += SIDE_POINTS if looked_side else 0
	points += ANSWER_POINTS if answered_right() else 0
	points += PATIENCE_POINTS if patient_enough() and elapsed >= 4.0 else 0
	return clampi(points, 0, 100)


func instruction() -> String:
	if finished:
		return "Done"
	if not looked_zoom:
		return "Tap what you see on the film to look closer"
	if not looked_side:
		return "Now the side view"
	return "What is it? Decide"


func progress() -> float:
	if finished:
		return 1.0
	return 0.3 * int(looked_zoom) + 0.3 * int(looked_side)


func _write_notes() -> void:
	_note(looked_zoom, "You looked closely at its edge." if looked_zoom else
		str(lines.get("missed_zoom", "You never looked closely at its edge.")))
	_note(looked_side, "You checked the side view too." if looked_side else
		str(lines.get("missed_side", "You never looked at the side view.")))
	var picked := answer_entry(chosen)
	_note(answered_right(), str(picked.get("why", picked.get("text", ""))))
