class_name RotaTask
extends TrainingTask
## Strike day: the nurses have walked out, and the few staff left must cover
## every bed. Put each patient with one of them so that every rule holds:
##   load       nobody carries more than they can (each patient weighs 1 to 3)
##   iv         a patient on a drip goes with someone who can give IV drugs
##              (the agency nurse isn't signed off for them here)
##   infection  an infectious patient never shares a nurse with a fragile one
##              (fresh from theatre, or on chemotherapy)
##   confused   a confused patient's nurse carries 4 or less, to watch them
##   student    a student nurse takes nobody who weighs 3
##
## Tap a patient, then whoever takes them; tap again to move them. Sign the
## rota when everyone has someone. The patients and staff are rolled from the
## seed out of the case's templates (story/cases.json, "kind": "rota"), and
## every rota rolled can be done:
##   easy     six patients, three staff, the rules on a card, warnings as you
##            go and free hints
##   hard     eight patients, a student nurse too, warnings only when you
##            sign, hints cost points
##   extreme  ten patients, tighter limits, no card and no hints

const LEVELS := ["easy", "hard", "extreme"]
const COUNTS := {"easy": 6, "hard": 8, "extreme": 10}
## How full the rota should be, as load over everyone's limits.
const TIGHTNESS := {"easy": 0.7, "hard": 0.82, "extreme": 0.9}
const HINT_COST := 5
## The most a confused patient's nurse may carry, so someone can watch them.
const CONFUSED_MAX := 4
## The heaviest a student nurse may take on.
const STUDENT_MAX := 2
const RULES := ["load", "iv", "infection", "confused", "student"]
const RULE_NAMES := {
	"load": "Nobody over their limit",
	"iv": "Drips only with a nurse who can run them",
	"infection": "Infection and fragile never share",
	"confused": "Confused: their nurse carries 4 or less",
	"student": "Students: nobody who weighs 3",
}
const BROKEN_COST := 12
const UNCOVERED_COST := 15

var case_id := ""
var place := ""
var actor := "grace"
var difficulty := "easy"
## Who is left to work: id, who, short, role, capacity, iv, student.
var staff: Array[Dictionary] = []
## The patients: id, who, short, load, iv, infectious, fragile, confused,
## number.
var patients: Array[Dictionary] = []
## patient id -> staff id.
var assigned := {}
## The patient being placed ("" for none).
var selected := ""
var hints_used := 0
var moves := 0
## One way it works, found when the rota was rolled.
var solution := {}
var speaker := "grace"
var _case := {}


func _init(which_case: String = "strike_rota", with_seed: int = 1, level: String = "easy") -> void:
	id = "rota"
	case_id = which_case
	difficulty = level if COUNTS.has(level) else "easy"
	_case = StoryBook.chapter("cases").get(which_case, {})
	place = str(_case.get("place", "The ward"))
	actor = str(_case.get("actor", "grace"))
	speaker = actor
	_roll(SeededRandom.new(with_seed))
	var briefs: Dictionary = _case.get("brief", {})
	_say(str(briefs.get(difficulty, briefs.get("easy", "Everyone needs someone. Mind the rules."))))


## Who is working and who needs them. Staff and patients name the level they
## first appear at; staff limits can shrink on harder days. Of the rolls that
## can be done, the one nearest the day's tightness is kept.
func _roll(dice: SeededRandom) -> void:
	var order := LEVELS.find(difficulty)
	staff.clear()
	for template: Dictionary in _case.get("staff", []):
		if LEVELS.find(str(template.get("from", "easy"))) <= order:
			staff.append(_make_staff(template))
	var pool: Array = []
	for template: Dictionary in _case.get("patients", []):
		if LEVELS.find(str(template.get("from", "easy"))) <= order:
			pool.append(template)
	var wanted := mini(int(COUNTS[difficulty]), pool.size())
	var capacity := 0
	for member in staff:
		capacity += int(member["capacity"])
	var best: Array[Dictionary] = []
	var best_solution := {}
	var best_gap := INF
	for attempt in 60:
		var picked: Array[Dictionary] = []
		for template: Dictionary in dice.shuffled(pool).slice(0, wanted):
			picked.append(_make_patient(template))
		var found := solve(picked, staff)
		if found.is_empty():
			continue
		var load := 0
		for patient in picked:
			load += int(patient["load"])
		var gap := absf(float(load) / maxf(1.0, capacity) - float(TIGHTNESS[difficulty]))
		if gap < best_gap:
			best_gap = gap
			best = picked
			best_solution = found
	patients = best
	solution = best_solution
	for index in patients.size():
		patients[index]["number"] = index + 1


func _make_staff(template: Dictionary) -> Dictionary:
	var member := template.duplicate(true)
	var limits: Variant = template.get("capacity", 4)
	if typeof(limits) == TYPE_DICTIONARY:
		var chosen := 4
		for level: String in LEVELS.slice(0, LEVELS.find(difficulty) + 1):
			if (limits as Dictionary).has(level):
				chosen = int(limits[level])
		member["capacity"] = chosen
	else:
		member["capacity"] = int(limits)
	member["iv"] = bool(template.get("iv", false))
	member["student"] = bool(template.get("student", false))
	return member


func _make_patient(template: Dictionary) -> Dictionary:
	var patient := template.duplicate(true)
	patient["load"] = int(template.get("load", 1))
	for key: String in ["iv", "infectious", "fragile", "confused"]:
		patient[key] = bool(template.get(key, false))
	return patient


# --- The rules ------------------------------------------------------------------

## Every rule an assignment breaks: [{"rule", "staff", "patients"}].
static func breaks(people: Array[Dictionary], team: Array[Dictionary], placed: Dictionary) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for member in team:
		var member_id := str(member["id"])
		var mine: Array[Dictionary] = []
		var load := 0
		for patient in people:
			if str(placed.get(str(patient["id"]), "")) == member_id:
				mine.append(patient)
				load += int(patient["load"])
		if mine.is_empty():
			continue
		if load > int(member["capacity"]):
			found.append({"rule": "load", "staff": member_id, "patients": _ids(mine)})
		var no_iv := mine.filter(func(p: Dictionary) -> bool: return bool(p["iv"]) and not bool(member["iv"]))
		if not no_iv.is_empty():
			found.append({"rule": "iv", "staff": member_id, "patients": _ids(no_iv)})
		var infectious := mine.filter(func(p: Dictionary) -> bool: return bool(p["infectious"]))
		var fragile := mine.filter(func(p: Dictionary) -> bool: return bool(p["fragile"]))
		if not infectious.is_empty() and not fragile.is_empty():
			found.append({"rule": "infection", "staff": member_id, "patients": _ids(infectious + fragile)})
		var confused := mine.filter(func(p: Dictionary) -> bool: return bool(p["confused"]))
		if not confused.is_empty() and load > CONFUSED_MAX:
			found.append({"rule": "confused", "staff": member_id, "patients": _ids(confused)})
		var heavy := mine.filter(func(p: Dictionary) -> bool: return int(p["load"]) > STUDENT_MAX)
		if bool(member["student"]) and not heavy.is_empty():
			found.append({"rule": "student", "staff": member_id, "patients": _ids(heavy)})
	return found


static func _ids(list: Array) -> Array[String]:
	var found: Array[String] = []
	for patient: Dictionary in list:
		found.append(str(patient["id"]))
	return found


## One assignment that breaks no rule, keeping fixed ones as they are, or {}
## if there is none. Most demanding patients are placed first.
static func solve(people: Array[Dictionary], team: Array[Dictionary], fixed: Dictionary = {}) -> Dictionary:
	if not breaks(people, team, fixed).is_empty():
		return {}
	var order := people.filter(func(p: Dictionary) -> bool: return not fixed.has(str(p["id"])))
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _demand(a) > _demand(b) or (_demand(a) == _demand(b) and str(a["id"]) < str(b["id"])))
	var placed := fixed.duplicate()
	return placed if _place(order, 0, people, team, placed) else {}


static func _demand(patient: Dictionary) -> int:
	return int(patient["load"]) * 10 + int(patient["iv"]) * 6 + int(patient["confused"]) * 5 \
		+ int(patient["infectious"]) * 3 + int(patient["fragile"]) * 3


static func _place(order: Array, index: int, people: Array[Dictionary], team: Array[Dictionary], placed: Dictionary) -> bool:
	if index >= order.size():
		return true
	var patient: Dictionary = order[index]
	for member in team:
		placed[str(patient["id"])] = str(member["id"])
		if breaks(people, team, placed).is_empty() and _place(order, index + 1, people, team, placed):
			return true
	placed.erase(str(patient["id"]))
	return false


func problems() -> Array[Dictionary]:
	return breaks(patients, staff, assigned)


func uncovered() -> Array[String]:
	var found: Array[String] = []
	for patient in patients:
		if not assigned.has(str(patient["id"])):
			found.append(str(patient["id"]))
	return found


func all_right() -> bool:
	return uncovered().is_empty() and problems().is_empty()


## The rules broken by the patients placed so far, by name.
func broken_rules() -> Array[String]:
	var found: Array[String] = []
	for problem in problems():
		if str(problem["rule"]) not in found:
			found.append(str(problem["rule"]))
	return found


# --- Placing people ---------------------------------------------------------------

func patient(patient_id: String) -> Dictionary:
	for entry in patients:
		if str(entry["id"]) == patient_id:
			return entry
	return {}


func member(staff_id: String) -> Dictionary:
	for entry in staff:
		if str(entry["id"]) == staff_id:
			return entry
	return {}


func load_of(staff_id: String) -> int:
	var load := 0
	for entry in patients:
		if str(assigned.get(str(entry["id"]), "")) == staff_id:
			load += int(entry["load"])
	return load


func select(patient_id: String) -> void:
	if finished or patient(patient_id).is_empty():
		return
	selected = "" if selected == patient_id else patient_id
	if selected.is_empty():
		changed.emit()
		return
	# The nurse says who they are, the way a handover would.
	var entry := patient(selected)
	speaker = actor
	_say("%s: %s" % [str(entry.get("short", "")), str(entry.get("about", ""))])


## Puts the selected patient with a member of staff.
func assign(staff_id: String) -> void:
	if finished or selected.is_empty() or member(staff_id).is_empty():
		return
	var entry := patient(selected)
	var before := problems().size()
	assigned[selected] = staff_id
	moves += 1
	selected = ""
	speaker = actor
	var who := str(entry.get("short", "Them"))
	var with := str(member(staff_id).get("short", staff_id))
	# On easy the nurse says straight away when a rule breaks.
	if difficulty == "easy":
		for problem in problems():
			if str(entry["id"]) in (problem["patients"] as Array) or (str(problem["staff"]) == staff_id and problems().size() > before):
				var warns: Dictionary = _case.get("warn", {})
				_say(str(warns.get(str(problem["rule"]), "That breaks a rule.")).replace("{who}", who).replace("{staff}", with), true)
				return
	var placed: Dictionary = _case.get("placed", {})
	_say(str(placed.get("line", "{who} with {staff}.")).replace("{who}", who).replace("{staff}", with))


func hints_allowed() -> bool:
	return difficulty != "extreme"


func hint_cost() -> int:
	return HINT_COST if difficulty == "hard" else 0


## Where the next patient can go so the rest still works, or which choice
## has to move.
func hint() -> String:
	if finished or not hints_allowed():
		return ""
	hints_used += 1
	speaker = actor
	var kept := assigned.duplicate()
	var way := solve(patients, staff, kept)
	if way.is_empty():
		# Something already placed makes it impossible: find what to move.
		for patient_id: String in assigned:
			var without := assigned.duplicate()
			without.erase(patient_id)
			if not solve(patients, staff, without).is_empty():
				_say("Move %s. With them where they are, the rest can't work." % str(patient(patient_id).get("short", "them")))
				return coach
		_say("Start again from the sickest. It can be done.")
		return coach
	var next := selected
	if next.is_empty() or assigned.has(next):
		var waiting: Array = patients.filter(func(p: Dictionary) -> bool: return not assigned.has(str(p["id"])))
		if waiting.is_empty():
			_say("Everyone has someone. Sign it.")
			return coach
		waiting.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _demand(a) > _demand(b))
		next = str(waiting[0]["id"])
	var entry := patient(next)
	var with := member(str(way[next]))
	_say("%s with %s. %s" % [str(entry.get("short", "Them")), str(with.get("short", "")), _reason(entry, with)])
	return coach


func _reason(entry: Dictionary, with: Dictionary) -> String:
	if bool(entry["iv"]):
		return "A drip needs someone who can give IV."
	if bool(entry["confused"]):
		return "Someone with a light load, to keep an eye on them."
	if bool(entry["infectious"]):
		return "Keep the infection away from the fragile ones."
	if bool(entry["fragile"]):
		return "Fragile: nobody infectious on the same nurse."
	if int(entry["load"]) > STUDENT_MAX:
		return "Too heavy for a student."
	return "%s has the room." % str(with.get("short", "They")).capitalize()


## Signs the rota: the task ends.
func sign_rota() -> void:
	if finished:
		return
	selected = ""
	var gaps := uncovered()
	for patient_id in gaps:
		_note(false, "%s had nobody. Everyone needs a name next to them." % str(patient(patient_id).get("short", "Someone")))
	var explains: Dictionary = _case.get("explain", {})
	for problem in problems():
		var names: Array[String] = []
		for patient_id: String in problem["patients"]:
			names.append(str(patient(patient_id).get("short", patient_id)))
		var with := str(member(str(problem["staff"])).get("short", ""))
		_note(false, "%s (%s, %s): %s" % [RULE_NAMES[problem["rule"]], with, " and ".join(names),
			str(explains.get(str(problem["rule"]), ""))])
	if all_right():
		_note(true, "Every patient has someone, and every rule holds.")
	if hints_used > 0 and hint_cost() > 0:
		_note(false, "%d hint%s from %s (-%d)." % [hints_used, "" if hints_used == 1 else "s",
			str(StoryBook.cast().get(actor, {}).get("name", actor)).split(" ")[0], hints_used * hint_cost()])
	speaker = actor
	var endings: Dictionary = _case.get("signed", {})
	_say(str(endings.get("all" if all_right() else ("gap" if not gaps.is_empty() else "some"), "Signed.")))
	_finish()


func score() -> int:
	var points := 100 - problems().size() * BROKEN_COST - uncovered().size() * UNCOVERED_COST - hints_used * hint_cost()
	return clampi(points, 0, 100)


func instruction() -> String:
	if finished:
		return "Signed"
	if not selected.is_empty():
		return "Who takes %s?" % str(patient(selected).get("short", "them"))
	var left := uncovered().size()
	if left == 0:
		return "Everyone's covered · sign the rota"
	return "Tap a patient, then who takes them · %d left" % left


func progress() -> float:
	if finished:
		return 1.0
	return float(assigned.size()) / maxf(1.0, patients.size())
