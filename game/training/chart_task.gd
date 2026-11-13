class_name ChartTask
extends TrainingTask
## Check a drug chart with the intern who wrote it, before it reaches the
## patient. Some lines are wrong: a dose, a unit, a route, a time, a drug
## the patient is allergic to, a drug that has to stop before surgery, or a
## dose the kidneys can't clear. The rest are right, and the intern can say
## why. Tap a line, say what is wrong with it, then sign the chart.
##
## Which lines are wrong is rolled from the seed, so every chart differs:
##   easy     two plain mistakes, and hints are free
##   hard     three, one of them subtle, and a hint costs points
##   extreme  four, two of them subtle, and no hints at all
## Plain mistakes can be seen in the line itself (a thousand times the dose,
## a syrup into a vein); subtle ones only against the patient's card (her
## weight, her kidneys, her falls).
##
## The case lives in story/cases.json ("kind": "chart").

const REASONS := ["dose", "units", "route", "time", "allergy", "stop", "kidneys"]
const REASON_NAMES := {
	"dose": "Wrong dose",
	"units": "Wrong unit",
	"route": "Wrong route",
	"time": "Wrong time",
	"allergy": "Allergy",
	"stop": "Stop for surgery",
	"kidneys": "Too much for the kidneys",
}
## How many plain and subtle mistakes each difficulty hides.
const MISTAKES := {"easy": [2, 0], "hard": [2, 1], "extreme": [2, 2]}
const HINT_COST := 5
const FALSE_ALARM := 10
## A wrong line flagged for the wrong reason earns this share of its points.
const HALF := 0.4

var case_id := ""
var patient := ""
var about := ""
var him := "him"
var his := "his"
## The facts on the patient's card, to check the chart against.
var facts: Array[String] = []
## Who wrote the chart and answers for it.
var actor := "zoya"
var difficulty := "easy"
## The chart's lines in order: {id, drug, dose, route, when, wrong, reason,
## also, found, why, defend, hint, subtle}.
var lines: Array[Dictionary] = []
## The line picked, waiting for a reason ("" for none).
var selected := ""
## line id -> the reason given.
var flagged := {}
## line id -> "found", "half" or "false".
var verdicts := {}
var hints_used := 0
## Who said the coach line on show: the intern, or Dr. Iyer with a hint.
var speaker := "zoya"
var _case := {}


## forced: line id -> true (always wrong this time) or false (always right),
## for what happened before the chart was written.
func _init(which_case: String = "gomes_chart", with_seed: int = 1, level: String = "easy", forced: Dictionary = {}) -> void:
	id = "chart"
	case_id = which_case
	difficulty = level if MISTAKES.has(level) else "easy"
	_case = StoryBook.chapter("cases").get(which_case, {})
	patient = str(_case.get("patient", "The patient"))
	about = str(_case.get("about", ""))
	actor = str(_case.get("actor", "zoya"))
	speaker = actor
	him = str(_case.get("him", "him"))
	his = str(_case.get("his", "his"))
	for fact: Variant in _case.get("facts", []):
		facts.append(str(fact))
	_roll(SeededRandom.new(with_seed), forced)
	var briefs: Dictionary = _case.get("brief", {})
	_say(str(briefs.get(difficulty, briefs.get("easy", "Check the chart with me, please."))))


## Which lines are wrong this time, and how each line reads. A forced line
## takes one of its kind's places (plain or subtle) before the dice pick.
func _roll(dice: SeededRandom, forced: Dictionary = {}) -> void:
	var counts: Array = MISTAKES[difficulty]
	var wrong: Array = []
	for kind in [false, true]:
		var pool: Array = []
		var needed := int(counts[1 if kind else 0])
		for slot: Dictionary in _case.get("lines", []):
			if bool(slot.get("subtle", false)) != kind:
				continue
			var slot_id := str(slot["id"])
			if not forced.has(slot_id):
				pool.append(slot_id)
			elif bool(forced[slot_id]) and needed > 0:
				wrong.append(slot_id)
				needed -= 1
		wrong.append_array(dice.shuffled(pool).slice(0, maxi(0, needed)))
	for slot: Dictionary in _case.get("lines", []):
		var line: Dictionary = (slot.get("ok", {}) as Dictionary).duplicate()
		line["id"] = str(slot["id"])
		line["subtle"] = bool(slot.get("subtle", false))
		line["defend"] = str(line.get("defend", "That one's right. I checked it."))
		line["wrong"] = str(slot["id"]) in wrong
		if line["wrong"]:
			var mistake: Dictionary = slot.get("wrong", {})
			for key: String in mistake:
				line[key] = mistake[key]
		lines.append(line)


func line(line_id: String) -> Dictionary:
	for entry in lines:
		if str(entry["id"]) == line_id:
			return entry
	return {}


## The lines that are wrong on this chart.
func mistakes() -> Array[String]:
	var found: Array[String] = []
	for entry in lines:
		if bool(entry["wrong"]):
			found.append(str(entry["id"]))
	return found


## Wrong lines flagged for the right reason.
func found() -> Array[String]:
	var made: Array[String] = []
	for line_id: String in verdicts:
		if verdicts[line_id] == "found":
			made.append(line_id)
	return made


## Wrong lines nobody flagged (or flagged for the wrong reason).
func missed() -> Array[String]:
	var made: Array[String] = []
	for line_id in mistakes():
		if verdicts.get(line_id, "") != "found":
			made.append(line_id)
	return made


func false_alarms() -> int:
	return verdicts.values().count("false")


## True when every mistake was found and nothing right was flagged.
func all_right() -> bool:
	return missed().is_empty() and false_alarms() == 0


func is_flagged(line_id: String) -> bool:
	return verdicts.has(line_id)


## Picks a line to say what is wrong with it.
func select(line_id: String) -> void:
	if finished or is_flagged(line_id) or line(line_id).is_empty():
		return
	selected = line_id
	changed.emit()


func cancel() -> void:
	selected = ""
	changed.emit()


## Flags a line as wrong for a reason (the picked line, or line_id).
## The intern answers: she agrees, she half agrees, or she says why it is
## right after all.
func flag(reason: String, line_id: String = "") -> void:
	var which := line_id if not line_id.is_empty() else selected
	if finished or which.is_empty() or is_flagged(which) or reason not in REASONS:
		return
	selected = ""
	var entry := line(which)
	flagged[which] = reason
	speaker = actor
	if not bool(entry["wrong"]):
		verdicts[which] = "false"
		_say(str(entry["defend"]), true)
		return
	var accepted: Array = [str(entry.get("reason", ""))] + (entry.get("also", []) as Array)
	if reason in accepted:
		verdicts[which] = "found"
		_say(str(entry.get("found", "You're right. I'll fix it.")))
	else:
		verdicts[which] = "half"
		_say(str(_case.get("half", "That line is wrong. Not for that reason, though.")), true)


func hints_allowed() -> bool:
	return difficulty != "extreme"


func hint_cost() -> int:
	return HINT_COST if difficulty == "hard" else 0


## A nudge towards a mistake not yet found, from Dr. Iyer passing the desk.
func hint() -> String:
	if finished or not hints_allowed():
		return ""
	for line_id in missed():
		if not verdicts.has(line_id):
			hints_used += 1
			speaker = "iyer"
			_say(str(line(line_id).get("hint", "Read that chart again, slowly.")))
			return coach
	speaker = "iyer"
	_say(str(_case.get("no_more", "I'd sign it now, if I were you.")))
	return coach


## Signs the chart: the task ends.
func sign() -> void:
	if finished:
		return
	selected = ""
	var total := mistakes().size()
	var caught := found().size()
	_note(caught == total, "You caught %d of the %d mistakes on %s chart." % [caught, total, his])
	for line_id in missed():
		_note(false, str(line(line_id).get("why", "You missed a mistake.")))
	if false_alarms() > 0:
		_note(false, "%d right line%s flagged as wrong. Check against the patient before you doubt a colleague." %
			[false_alarms(), "" if false_alarms() == 1 else "s"])
	elif caught == total:
		_note(true, "No false alarms. You only flagged what was really wrong.")
	if hints_used > 0 and hint_cost() > 0:
		_note(false, "%d hint%s from Dr. Iyer (-%d)." % [hints_used, "" if hints_used == 1 else "s", hints_used * hint_cost()])
	speaker = actor
	var endings: Dictionary = _case.get("signed", {})
	_say(str(endings.get("all" if all_right() else ("some" if caught > 0 else "none"), "Signed.")))
	_finish()


func score() -> int:
	var total := mistakes().size()
	if total == 0:
		return 100
	var points := 0.0
	for line_id: String in verdicts:
		match str(verdicts[line_id]):
			"found":
				points += 100.0 / total
			"half":
				points += 100.0 / total * HALF
			"false":
				points -= FALSE_ALARM
	points -= hints_used * hint_cost()
	return clampi(roundi(points), 0, 100)


func instruction() -> String:
	if finished:
		return "Signed"
	if not selected.is_empty():
		return "What's wrong with the %s?" % str(line(selected).get("drug", "line")).to_lower()
	if difficulty == "easy":
		var left := missed().size()
		return "Tap a wrong line, say why · %d mistake%s to find" % [left, "" if left == 1 else "s"]
	return "Tap a wrong line and say why, then sign"


func progress() -> float:
	if finished:
		return 1.0
	return float(found().size()) / maxf(1.0, mistakes().size())


## How a line reads on the chart: "Morphine 10 mg" and "By mouth · Every 2 h".
static func line_text(entry: Dictionary) -> Array[String]:
	var top := "%s  %s" % [entry.get("drug", ""), entry.get("dose", "")]
	var parts: Array[String] = []
	for key: String in ["route", "when"]:
		var value := str(entry.get(key, ""))
		if not value.is_empty() and value != "-":
			parts.append(value)
	return [top.strip_edges(), " · ".join(parts)]
