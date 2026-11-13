class_name TrainingTask
extends RefCounted
## One training task in the skills lab: the rules, the score and the
## explanation, with no visuals. Each task's view turns taps into calls on
## its task, and time only passes through tick(), so tests can play a task
## start to finish.
##
## Every task scores 0 to 100 and keeps notes: what went well and what to
## fix, each with the reason, because mistakes in training are meant to be
## explained, not just counted.

signal changed
signal finished_task

const IDS := ["scrub", "monitor", "history", "instruments", "iv", "stitch"]
const TITLES := {
	"scrub": "Scrub in",
	"monitor": "Read the monitor",
	"history": "Take a history",
	"instruments": "Know your instruments",
	"iv": "IV line",
	"stitch": "Stitching",
	"exam": "Examine",
	"scan": "Read the X-ray",
	"chart": "Check the drug chart",
	"triage": "Sort the casualties",
}
## Who runs each station.
const TRAINERS := {
	"scrub": "grace",
	"monitor": "iyer",
	"history": "iyer",
	"instruments": "tom",
	"iv": "grace",
	"stitch": "iyer",
	"exam": "iyer",
	"scan": "iyer",
	"chart": "zoya",
	"triage": "priya",
}

var id := ""
var finished := false
## The coach's latest line about what just happened ("" for none).
var coach := ""
## True when the coach's line is about a mistake.
var coach_warns := false
## Seconds since the task started.
var elapsed := 0.0
## Notes for the score card: {"ok": bool, "text": String}.
var _notes: Array[Dictionary] = []


static func title_of(task_id: String) -> String:
	return str(TITLES.get(task_id, task_id.capitalize()))


## A task by id. which_case picks the patient for a history, an examination
## or an X-ray ("" for the default case).
static func make(task_id: String, with_seed: int = 1, which_case: String = "") -> TrainingTask:
	match task_id:
		"scrub":
			return ScrubTask.new()
		"monitor":
			return MonitorTask.new(with_seed)
		"history":
			return HistoryTask.new() if which_case.is_empty() else HistoryTask.new(which_case)
		"exam":
			return ExamTask.new() if which_case.is_empty() else ExamTask.new(which_case)
		"scan":
			return ScanTask.new() if which_case.is_empty() else ScanTask.new(which_case)
		"instruments":
			return InstrumentTask.new(with_seed)
		"iv":
			return IvTask.new(with_seed)
		"stitch":
			return StitchTask.new()
		"chart":
			return ChartTask.new("gomes_chart" if which_case.is_empty() else which_case, with_seed)
		"triage":
			return TriageTask.new("bus_triage" if which_case.is_empty() else which_case, with_seed)
	push_error("Unknown training task: %s" % task_id)
	return null


## Stars for a score: 0 below 40, then one, two or three.
static func stars_for(points: int) -> int:
	if points >= 85:
		return 3
	if points >= 65:
		return 2
	if points >= 40:
		return 1
	return 0


func title() -> String:
	return title_of(id)


func tick(delta: float) -> void:
	if not finished:
		elapsed += delta


## 0 to 100. Only final once the task has finished.
func score() -> int:
	return 0


func stars() -> int:
	return stars_for(score())


## What went well and what to fix, for the score card.
func notes() -> Array[Dictionary]:
	return _notes


## A short line for the top of the screen: what to do now.
func instruction() -> String:
	return ""


## How far through the task the player is, 0 to 1.
func progress() -> float:
	return 1.0 if finished else 0.0


func _say(line: String, warns: bool = false) -> void:
	coach = line
	coach_warns = warns
	changed.emit()


func _note(ok: bool, text: String) -> void:
	_notes.append({"ok": ok, "text": text})


func _finish() -> void:
	if finished:
		return
	finished = true
	changed.emit()
	finished_task.emit()
