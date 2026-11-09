class_name HistoryTask
extends TrainingTask
## Take a history: a limited number of questions to find what matters
## before surgery. The patient (Dr. Iyer, acting) answers each one; four
## facts are the ones that would hurt him if missed.
##
## The case lives in story/cases.json so it can be rewritten without code.

const KEY_POINTS := 20
const USEFUL_POINTS := 5

var case_id := ""
var patient := ""
var about := ""
var actor := "iyer"
var opening := ""
var limit := 5
## How the coach refers to the patient: "him" and "his", or "her" and "her".
var him := "him"
var his := "his"
## The case's questions, in the order they are offered.
var questions: Array[Dictionary] = []
var asked: Array[String] = []
## The facts written on the case card so far.
var facts: Array[String] = []
## The answer to the last question, for the screen to show.
var last_answer := ""


func _init(which_case: String = "training_history") -> void:
	id = "history"
	case_id = which_case
	var data: Dictionary = StoryBook.chapter("cases").get(which_case, {})
	patient = str(data.get("patient", "The patient"))
	about = str(data.get("about", ""))
	actor = str(data.get("actor", "iyer"))
	opening = str(data.get("opening", ""))
	limit = int(data.get("limit", 5))
	him = str(data.get("him", "him"))
	his = str(data.get("his", "his"))
	for entry: Variant in data.get("questions", []):
		if typeof(entry) == TYPE_DICTIONARY:
			questions.append(entry)
	_say(str(data.get("brief", "You get %d questions. Find out what would hurt %s on the table." % [limit, him])))


func question(question_id: String) -> Dictionary:
	for entry in questions:
		if str(entry.get("id", "")) == question_id:
			return entry
	return {}


func remaining() -> int:
	return limit - asked.size()


func is_asked(question_id: String) -> bool:
	return question_id in asked


## Asks a question. Returns the answer ("" if it can't be asked).
func ask(question_id: String) -> String:
	if finished or is_asked(question_id) or remaining() <= 0:
		return ""
	var entry := question(question_id)
	if entry.is_empty():
		return ""
	asked.append(question_id)
	last_answer = str(entry.get("answer", ""))
	if entry.has("fact"):
		facts.append(str(entry["fact"]))
	match str(entry.get("weight", "")):
		"key":
			_say("That one matters. Write it down.")
		"useful":
			_say("Useful. Not the most important thing.")
		_:
			_say("That told you nothing about %s belly." % his, true)
	if remaining() <= 0:
		_end()
	else:
		changed.emit()
	return last_answer


## "I've got what I need": stops before using every question.
func finish_early() -> void:
	if not finished and not asked.is_empty():
		_end()


func best_points() -> int:
	var keys := 0
	var useful := 0
	for entry in questions:
		match str(entry.get("weight", "")):
			"key":
				keys += 1
			"useful":
				useful += 1
	var key_asks := mini(keys, limit)
	return key_asks * KEY_POINTS + mini(useful, limit - key_asks) * USEFUL_POINTS


func points() -> int:
	var total := 0
	for question_id in asked:
		match str(question(question_id).get("weight", "")):
			"key":
				total += KEY_POINTS
			"useful":
				total += USEFUL_POINTS
	return total


func score() -> int:
	var best := best_points()
	if best <= 0:
		return 0
	return clampi(int(round(100.0 * points() / best)), 0, 100)


func instruction() -> String:
	if finished:
		return "Done"
	return "Ask what matters: %d question%s left" % [remaining(), "" if remaining() == 1 else "s"]


func progress() -> float:
	return float(asked.size()) / maxf(1.0, limit)


func _end() -> void:
	var found := 0
	var missed: Array[Dictionary] = []
	for entry in questions:
		if str(entry.get("weight", "")) != "key":
			continue
		if is_asked(str(entry.get("id", ""))):
			found += 1
		else:
			missed.append(entry)
	var keys := found + missed.size()
	_note(missed.is_empty(), "You found %d of the %d facts that could hurt %s." % [found, keys, him])
	for entry in missed:
		_note(false, str(entry.get("why", "You missed: %s." % entry.get("fact", ""))))
	var wasted := 0
	for question_id in asked:
		if str(question(question_id).get("weight", "")) == "none":
			wasted += 1
	if wasted > 0:
		_note(false, "%d question%s went on small talk. Be kind, but ask what matters first." %
			[wasted, "" if wasted == 1 else "s"])
	elif missed.is_empty():
		_note(true, "No wasted questions.")
	_finish()
