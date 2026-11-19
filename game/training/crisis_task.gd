class_name CrisisTask
extends TrainingTask
## A hospital crisis played as a puzzle: the lights go out in theatre, two
## patients share a name, a crowd at the door, the family's blood, the
## insurance form, a snakebite at three in the morning, dengue season, an
## inspection in thirty minutes. Each is a few steps; every step is a
## question whose right answer depends on facts rolled from the seed (what
## kind of anaesthetic, which band has which number, who drank last night),
## so nothing can be learnt by heart. The facts are on a card on the left;
## the question and its answers on the right.
##
## A step is one of three kinds:
##   one    pick one answer
##   each   give every item one of a few choices (some choices run out)
##   some   pick the items that fit; with a budget, they must fit in it
## Urgent steps have a clock on hard and extreme. Hints are free on easy,
## cost points on hard, and don't exist on extreme.
##
## The cases are built by Crises (game/training/crises.gd); what the coach
## says is in story/crisis_lines.json, so every line is recorded.

const HINT_COST := 5
## Seconds an urgent step gives on each difficulty (0: no clock).
const URGENT_TIME := {"easy": 0.0, "hard": 30.0, "extreme": 18.0}
## A wrong pick in a "some" step takes this share of a right one off.
const WRONG_PICK := 1.0
## Picking someone unsafe for a "need" step costs half a needed pick.
const UNSAFE_PICK := 0.5

var case_id := ""
var difficulty := "easy"
var actor := "grace"
var case_title := ""
var spot := ""
var card_title := ""
## The facts on the card, top to bottom (more arrive as steps go on).
var facts: Array[String] = []
## True for a crisis played in the dark (the power cut).
var dark := false
var steps: Array[Dictionary] = []
var step_index := 0
## The answer being put together for the step on show: an option id, an
## {item: choice} or an [item].
var picked: Variant = null
## Each step's mark once confirmed, 0 to 1.
var marks: Array[float] = []
## What was answered at each step, for the notes and the story after.
var answers: Array = []
var hints_used := 0
var timeouts := 0
## Seconds left on an urgent step's clock (-1: no clock).
var time_left := -1.0
## Who said the coach line on show.
var speaker := "grace"
## Anything the story needs to know about how it went (flags to set).
var outcome := {}


func _init(which_case: String = "ramesh", with_seed: int = 1, level: String = "easy", context: Dictionary = {}) -> void:
	id = "crisis"
	case_id = which_case
	difficulty = level if URGENT_TIME.has(level) else "easy"
	var built := Crises.build(which_case, SeededRandom.new(with_seed), difficulty, context)
	actor = str(built.get("actor", "grace"))
	speaker = actor
	case_title = str(built.get("title", "A crisis"))
	spot = str(built.get("spot", "Ward 4"))
	card_title = str(built.get("card", case_title))
	dark = bool(built.get("dark", false))
	for fact: Variant in built.get("facts", []):
		facts.append(str(fact))
	for step: Variant in built.get("steps", []):
		steps.append(step as Dictionary)
	_begin_step()
	_say(Crises.line(case_id, "brief_" + difficulty))


func title() -> String:
	return case_title


## The step on show ({} once done).
func current() -> Dictionary:
	return steps[step_index] if step_index < steps.size() else {}


func kind() -> String:
	return str(current().get("kind", "one"))


func _begin_step() -> void:
	var step := current()
	if step.is_empty():
		return
	for fact: Variant in step.get("facts", []):
		facts.append(str(fact))
	match str(step.get("kind", "one")):
		"each":
			picked = {}
		"some":
			picked = []
		_:
			picked = ""
	var limit := float(URGENT_TIME[difficulty]) if bool(step.get("urgent", false)) else 0.0
	time_left = limit if limit > 0.0 else -1.0


# --- Answering ---------------------------------------------------------------------

## Picks one answer ("one" steps).
func choose(option_id: String) -> void:
	if finished or kind() != "one" or not _has_option(option_id):
		return
	picked = option_id
	changed.emit()


## Gives an item one of the choices ("each" steps). A choice with a limit
## can't go to more items than that.
func assign(item_id: String, choice_id: String) -> void:
	if finished or kind() != "each" or not _has_item(item_id) or not _has_choice(choice_id):
		return
	var given: Dictionary = picked
	if given.get(item_id, "") != choice_id and not choice_open(choice_id):
		return
	given[item_id] = choice_id
	changed.emit()


## Picks or unpicks an item ("some" steps). Over the budget is refused.
func toggle(item_id: String) -> void:
	if finished or kind() != "some" or not _has_item(item_id):
		return
	var chosen: Array = picked
	if item_id in chosen:
		chosen.erase(item_id)
	else:
		var step := current()
		if step.has("budget") and spent() + int((step.get("costs", {}) as Dictionary).get(item_id, 0)) > int(step["budget"]):
			_say(Crises.line(case_id, "over_budget"), true)
			return
		chosen.append(item_id)
	changed.emit()


func is_picked(item_id: String) -> bool:
	match kind():
		"some":
			return item_id in (picked as Array)
		"one":
			return picked == item_id
	return false


func choice_of(item_id: String) -> String:
	return str((picked as Dictionary).get(item_id, "")) if kind() == "each" else ""


## How many more items a limited choice can take this step.
func choice_left(choice_id: String) -> int:
	for choice: Dictionary in current().get("choices", []):
		if str(choice["id"]) == choice_id and choice.has("limit"):
			return int(choice["limit"]) - (picked as Dictionary).values().count(choice_id)
	return 99


func choice_open(choice_id: String) -> bool:
	return choice_left(choice_id) > 0


## Minutes used so far in a step with a budget.
func spent() -> int:
	var total := 0
	var costs: Dictionary = current().get("costs", {})
	for item_id: String in (picked as Array):
		total += int(costs.get(item_id, 0))
	return total


func can_confirm() -> bool:
	if finished or current().is_empty():
		return false
	match kind():
		"one":
			return not str(picked).is_empty()
		"each":
			return (picked as Dictionary).size() == (current().get("items", []) as Array).size()
		"some":
			return not (picked as Array).is_empty()
	return false


## Locks in the step's answer: the coach says whether it was right, and the
## next step comes (or the crisis ends).
func confirm() -> void:
	if not can_confirm():
		return
	_lock(false)


func _lock(timed_out: bool) -> void:
	var step := current()
	var mark := 0.0 if timed_out else mark_for(step, picked)
	marks.append(mark)
	answers.append(picked)
	if timed_out:
		timeouts += 1
		_note(false, "Too slow: %s %s" % [str(step.get("prompt", "")).trim_suffix(":"), str(step.get("why", ""))])
	elif mark >= 0.999:
		_note(true, str(step.get("good", step.get("why", "Right."))))
	else:
		_note(false, _miss_text(step, picked))
	var key := str(step.get("right" if mark >= 0.999 else "wrong", ""))
	speaker = actor
	step_index += 1
	if step_index >= steps.size():
		_end()
		return
	if not key.is_empty():
		_say(Crises.line(case_id, key), mark < 0.999)
	else:
		_say(Crises.line(case_id, "next"), false)
	_begin_step()
	changed.emit()


func _end() -> void:
	time_left = -1.0
	if hints_used > 0 and hint_cost() > 0:
		_note(false, "%d hint%s (-%d)." % [hints_used, "" if hints_used == 1 else "s", hints_used * hint_cost()])
	var right := marks.filter(func(m: float) -> bool: return m >= 0.999).size()
	var ending := "end_all" if right == steps.size() else ("end_some" if right > 0 else "end_none")
	outcome["right"] = right == steps.size()
	speaker = actor
	_say(Crises.line(case_id, ending), ending != "end_all")
	_finish()


func tick(delta: float) -> void:
	super(delta)
	if finished or time_left < 0.0:
		return
	time_left -= delta
	if time_left <= 0.0:
		time_left = -1.0
		# Whatever was picked when the clock ran out is the answer; nothing
		# picked is the wrong one.
		if can_confirm():
			_lock(false)
		else:
			_lock(true)


# --- Marking -----------------------------------------------------------------------

## A step's mark for an answer, 0 to 1.
static func mark_for(step: Dictionary, answer: Variant) -> float:
	match str(step.get("kind", "one")):
		"one":
			return 1.0 if str(answer) == str(step.get("answer", "")) else 0.0
		"each":
			var right: Dictionary = step.get("answer", {})
			var given: Dictionary = answer if answer is Dictionary else {}
			if right.is_empty():
				return 1.0
			var good := 0
			for item_id: String in right:
				if str(given.get(item_id, "")) == str(right[item_id]):
					good += 1
			return float(good) / float(right.size())
		"some":
			var chosen: Array = answer if answer is Array else []
			if step.has("values"):
				return _budget_mark(step, chosen)
			var right: Array = step.get("answer", [])
			var hits := chosen.filter(func(i: Variant) -> bool: return i in right).size()
			var misses := chosen.size() - hits
			if step.has("need"):
				var need := int(step["need"])
				return clampf(minf(1.0, float(hits) / float(need)) - UNSAFE_PICK * misses, 0.0, 1.0)
			if right.is_empty():
				return 1.0 if chosen.is_empty() else 0.0
			return clampf((hits - WRONG_PICK * misses) / float(right.size()), 0.0, 1.0)
	return 0.0


## Points lost for each must-do job left undone (or done without what it needs).
const CRITICAL_MISSED := 40


## What a set of jobs is worth: points, with a job only counting once the
## job it needs is also done, and a must-do job left out costing a lot.
static func plan_value(step: Dictionary, chosen: Array) -> int:
	var values: Dictionary = step.get("values", {})
	var needs: Dictionary = step.get("needs", {})
	var total := 0
	var counted: Array = []
	for item_id: Variant in chosen:
		var need := str(needs.get(item_id, ""))
		if not need.is_empty() and need not in chosen:
			continue
		counted.append(item_id)
		total += int(values.get(item_id, 0))
	var critical: Dictionary = step.get("critical", {})
	for item_id: Variant in critical:
		if bool(critical[item_id]) and item_id not in counted:
			total -= CRITICAL_MISSED
	return total


## The best value that fits in the budget, and one set that gets it.
static func best_plan(step: Dictionary) -> Array:
	var items: Array = (step.get("items", []) as Array).map(func(i: Dictionary) -> String: return str(i["id"]))
	var costs: Dictionary = step.get("costs", {})
	var budget := int(step.get("budget", 0))
	var best_value := -1
	var best: Array = []
	for mask in 1 << items.size():
		var chosen: Array = []
		var cost := 0
		for index in items.size():
			if mask & (1 << index):
				chosen.append(items[index])
				cost += int(costs.get(items[index], 0))
		if cost > budget:
			continue
		var value := plan_value(step, chosen)
		if value > best_value or (value == best_value and chosen.size() < best.size()):
			best_value = value
			best = chosen
	return [best_value, best]


static func _budget_mark(step: Dictionary, chosen: Array) -> float:
	var best: int = best_plan(step)[0]
	if best <= 0:
		return 1.0
	return clampf(float(plan_value(step, chosen)) / float(best), 0.0, 1.0)


## The right answer to a step, as an answer would be given.
static func right_answer(step: Dictionary) -> Variant:
	if str(step.get("kind", "")) == "some" and step.has("values"):
		return best_plan(step)[1]
	return step.get("answer", "")


func _miss_text(step: Dictionary, answer: Variant) -> String:
	var why := str(step.get("why", ""))
	match str(step.get("kind", "one")):
		"one":
			var said := str((step.get("explain", {}) as Dictionary).get(str(answer), ""))
			return (said + " " + why).strip_edges() if not said.is_empty() else why
		"each":
			var wrong: Array[String] = []
			var right: Dictionary = step.get("answer", {})
			var reasons: Dictionary = step.get("reasons", {})
			for item_id: String in right:
				if str((answer as Dictionary).get(item_id, "")) != str(right[item_id]):
					wrong.append(str(reasons.get(item_id, item_id)))
			return " ".join(wrong) if not wrong.is_empty() else why
		"some":
			var parts: Array[String] = []
			var reasons: Dictionary = step.get("reasons", {})
			if step.has("values"):
				var best: Array = best_plan(step)[1]
				for item_id: Variant in answer:
					if reasons.has(item_id) and (int((step.get("values", {}) as Dictionary).get(item_id, 0)) <= 0
							or (step.get("needs", {}) as Dictionary).has(item_id) and str(step["needs"][item_id]) not in answer):
						parts.append(str(reasons[item_id]))
				for item_id: Variant in best:
					if item_id not in answer and bool((step.get("critical", {}) as Dictionary).get(item_id, false)):
						parts.append(str(reasons.get(item_id, "")))
			else:
				var right: Array = step.get("answer", [])
				for item_id: Variant in answer:
					if item_id not in right:
						parts.append(str(reasons.get(item_id, "")))
				if not step.has("need"):
					for item_id: Variant in right:
						if item_id not in answer:
							parts.append(str(reasons.get(item_id, "")))
			parts = parts.filter(func(p: String) -> bool: return not p.is_empty())
			return " ".join(parts) if not parts.is_empty() else why
	return why


# --- Hints and the rest --------------------------------------------------------------

func hints_allowed() -> bool:
	return difficulty != "extreme"


func hint_cost() -> int:
	return HINT_COST if difficulty == "hard" else 0


func hint() -> String:
	if finished or not hints_allowed():
		return ""
	var key := str(current().get("hint", ""))
	if key.is_empty():
		return ""
	hints_used += 1
	speaker = actor
	_say(Crises.line(case_id, key))
	return coach


## Steps answered fully right, as "step id" strings, and the rest.
func wrong_steps() -> Array[String]:
	var found: Array[String] = []
	for index in marks.size():
		if marks[index] < 0.999:
			found.append(str(steps[index].get("id", "s%d" % (index + 1))))
	return found


func all_right() -> bool:
	return finished and wrong_steps().is_empty() and timeouts == 0


func score() -> int:
	if steps.is_empty():
		return 100
	var total := 0.0
	var weights := 0.0
	for index in steps.size():
		var weight := float(steps[index].get("weight", 1.0))
		weights += weight
		if index < marks.size():
			total += marks[index] * weight
	var points := 100.0 * total / maxf(weights, 0.001)
	points -= hints_used * hint_cost()
	return clampi(roundi(points), 0, 100)


func instruction() -> String:
	if finished:
		return "Done"
	var step := current()
	var count := "%d of %d · " % [step_index + 1, steps.size()]
	match kind():
		"each":
			return count + "Decide for everyone, then confirm"
		"some":
			if step.has("budget"):
				return count + "%d of %d minutes used" % [spent(), int(step["budget"])]
			if step.has("need"):
				return count + "Pick safe donors · %d needed" % int(step["need"])
			return count + "Pick all that count, then confirm"
	return count + "Pick one, then confirm"


func progress() -> float:
	if finished:
		return 1.0
	return float(step_index) / maxf(1.0, steps.size())


func _has_option(option_id: String) -> bool:
	for option: Dictionary in current().get("options", []):
		if str(option["id"]) == option_id:
			return true
	return false


func _has_item(item_id: String) -> bool:
	for item: Dictionary in current().get("items", []):
		if str(item["id"]) == item_id:
			return true
	return false


func _has_choice(choice_id: String) -> bool:
	for choice: Dictionary in current().get("choices", []):
		if str(choice["id"]) == choice_id:
			return true
	return false
