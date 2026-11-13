class_name TriageTask
extends TrainingTask
## Sort the casualties of a crash by the START rules, the way ambulance
## crews do when there are more patients than hands:
##   walks                         green (minor, can wait)
##   not breathing, airway opened  breathes: red; still not: black
##   breathing faster than 30      red
##   nail bed pinks up after 2 s   red
##   can't follow a simple command red
##   otherwise                     yellow (serious, can wait a little)
##
## Tap a casualty, check what you need in that order, then tag them. Each
## check takes time the others don't have, so a check the rules didn't need
## costs points. Looks lie: the one screaming is often fine, the quiet one
## often isn't. Tag on a guess and you may be right for the wrong reason.
##
## The casualties are rolled from the seed out of the case's templates
## (story/cases.json, "kind": "triage"), numbers and all:
##   easy     six casualties, clear numbers, the rules on a card, free hints
##   hard     eight, numbers near the lines, hints cost points
##   extreme  ten, the nearest numbers, no card and no hints

const TAGS := ["red", "yellow", "green", "black"]
const TAG_NAMES := {"red": "Red · now", "yellow": "Yellow · soon", "green": "Green · walks", "black": "Black · beyond help"}
## The START order. The airway is only opened on someone not breathing.
const CHECKS := ["walk", "breathing", "airway", "rate", "pulse", "commands"]
const CHECK_NAMES := {
	"walk": "Can you walk?",
	"breathing": "Breathing?",
	"airway": "Open the airway",
	"rate": "Count breaths",
	"pulse": "Press a nail bed",
	"commands": "Squeeze my hand",
}
const LEVELS := ["easy", "hard", "extreme"]
const COUNTS := {"easy": 6, "hard": 8, "extreme": 10}
const HINT_COST := 5
const WASTED_CHECK := 2
## Seconds each check takes on scene (the clock the others are waiting on).
const CHECK_SECONDS := 15
## A right tag reached without the checks that decide it earns this share.
const GUESSED := 0.6
## A tag more urgent than needed: resources spent, nobody hurt.
const OVER := 0.3

var case_id := ""
var place := ""
var actor := "priya"
var difficulty := "easy"
## The casualties, each: id, who, looks, walk, breathing, airway, rate,
## refill, obeys, truth, and the lines for each check.
var casualties: Array[Dictionary] = []
## The casualty being looked at ("" for none).
var selected := ""
## id -> the checks done on them, in order.
var checked := {}
## id -> the tag given.
var tags := {}
var hints_used := 0
var wasted := 0
## Seconds spent checking.
var scene_seconds := 0
var speaker := "priya"
var _case := {}


func _init(which_case: String = "bus_triage", with_seed: int = 1, level: String = "easy") -> void:
	id = "triage"
	case_id = which_case
	difficulty = level if COUNTS.has(level) else "easy"
	_case = StoryBook.chapter("cases").get(which_case, {})
	place = str(_case.get("place", "The crash"))
	actor = str(_case.get("actor", "priya"))
	speaker = actor
	_roll(SeededRandom.new(with_seed))
	var briefs: Dictionary = _case.get("brief", {})
	_say(str(briefs.get(difficulty, briefs.get("easy", "Tag them. Red, yellow, green, black."))))


## Who is here this time, and their numbers. Templates name the level they
## first appear at; numbers come from the range for the difficulty, so hard
## and extreme sit nearer the lines. Every roll holds a red, a yellow and a
## green, so the sorting is never one colour.
func _roll(dice: SeededRandom) -> void:
	var order := LEVELS.find(difficulty)
	var pool: Array = []
	for template: Dictionary in _case.get("casualties", []):
		if LEVELS.find(str(template.get("from", "easy"))) <= order:
			pool.append(template)
	var wanted := mini(int(COUNTS[difficulty]), pool.size())
	for attempt in 20:
		casualties.clear()
		for template: Dictionary in dice.shuffled(pool).slice(0, wanted):
			casualties.append(_make(template, dice))
		var seen := {}
		for casualty in casualties:
			seen[casualty["truth"]] = true
		if seen.has("red") and seen.has("yellow") and seen.has("green"):
			break
	for index in casualties.size():
		casualties[index]["number"] = index + 1


func _make(template: Dictionary, dice: SeededRandom) -> Dictionary:
	var casualty := template.duplicate(true)
	casualty["walk"] = bool(template.get("walk", false))
	casualty["breathing"] = bool(template.get("breathing", true))
	var airway: Variant = template.get("airway", false)
	casualty["airway"] = dice.chance(float(airway)) if typeof(airway) == TYPE_FLOAT else bool(airway)
	casualty["obeys"] = bool(template.get("obeys", true))
	casualty["rate"] = _number(template.get("rate", {}), dice, 18)
	casualty["refill"] = _number(template.get("refill", {}), dice, 1)
	casualty["truth"] = start_tag(casualty)
	return casualty


## A number from {"easy": [lo, hi], "hard": [...], ...}, the nearest
## difficulty's range at or below this one.
func _number(ranges: Variant, dice: SeededRandom, fallback: int) -> int:
	if typeof(ranges) != TYPE_DICTIONARY:
		return fallback
	var order := LEVELS.find(difficulty)
	for index in range(order, -1, -1):
		var level: String = LEVELS[index]
		if (ranges as Dictionary).has(level):
			var span: Array = ranges[level]
			return dice.next_int_in(int(span[0]), int(span[1]))
	return fallback


## The START tag for a casualty's signs.
static func start_tag(casualty: Dictionary) -> String:
	if bool(casualty.get("walk", false)):
		return "green"
	if not bool(casualty.get("breathing", true)):
		return "red" if bool(casualty.get("airway", false)) else "black"
	if int(casualty.get("rate", 18)) > 30:
		return "red"
	if int(casualty.get("refill", 1)) > 2:
		return "red"
	if not bool(casualty.get("obeys", true)):
		return "red"
	return "yellow"


## The checks START needs for this casualty, in order, ending at the one
## that decides.
static func needed_checks(casualty: Dictionary) -> Array[String]:
	var path: Array[String] = ["walk"]
	if bool(casualty.get("walk", false)):
		return path
	path.append("breathing")
	if not bool(casualty.get("breathing", true)):
		path.append("airway")
		return path
	path.append("rate")
	if int(casualty.get("rate", 18)) > 30:
		return path
	path.append("pulse")
	if int(casualty.get("refill", 1)) > 2:
		return path
	path.append("commands")
	return path


func casualty(casualty_id: String) -> Dictionary:
	for entry in casualties:
		if str(entry["id"]) == casualty_id:
			return entry
	return {}


func checks_done(casualty_id: String) -> Array:
	return checked.get(casualty_id, [])


## The checks that make sense now: the airway only for someone not
## breathing, nothing twice.
func can_check(casualty_id: String, check: String) -> bool:
	if finished or check not in CHECKS or tags.has(casualty_id):
		return false
	var done := checks_done(casualty_id)
	if check in done:
		return false
	if check == "airway":
		return "breathing" in done and not bool(casualty(casualty_id).get("breathing", true))
	return true


func select(casualty_id: String) -> void:
	if finished or casualty(casualty_id).is_empty():
		return
	selected = casualty_id
	speaker = actor
	var entry := casualty(casualty_id)
	_say(str(entry.get("looks", "")))
	changed.emit()


func back() -> void:
	selected = ""
	changed.emit()


## Checks one sign on the casualty being looked at.
func check(what: String) -> void:
	if selected.is_empty() or not can_check(selected, what):
		return
	var entry := casualty(selected)
	var done: Array = checked.get(selected, [])
	done.append(what)
	checked[selected] = done
	scene_seconds += CHECK_SECONDS
	if what not in needed_checks(entry):
		wasted += 1
	speaker = actor
	_say(check_line(entry, what))


## What a check finds, said aloud.
static func check_line(entry: Dictionary, what: String) -> String:
	match what:
		"walk":
			if bool(entry.get("walk", false)):
				return str(entry.get("walks", "Gets up and walks over to the kerb."))
			return str(entry.get("stays", "Can't get up."))
		"breathing":
			return "Breathing." if bool(entry.get("breathing", true)) else "Not breathing."
		"airway":
			return "Chin lifted... a breath. Breathing now." if bool(entry.get("airway", false)) \
				else "Chin lifted. Still no breath."
		"rate":
			return "Breathing %d a minute." % int(entry.get("rate", 18))
		"pulse":
			var refill := int(entry.get("refill", 1))
			return "Nail bed pinks up in %d second%s." % [refill, "" if refill == 1 else "s"]
		"commands":
			return "Squeezes your hand." if bool(entry.get("obeys", true)) else "Doesn't squeeze. Eyes open, nobody home."
	return ""


func tag(which: String) -> void:
	if finished or selected.is_empty() or which not in TAGS or tags.has(selected):
		return
	tags[selected] = which
	speaker = actor
	var entry := casualty(selected)
	selected = ""
	var said: Dictionary = _case.get("tagged", {})
	_say(str(said.get(which, "Tagged.")).replace("{who}", str(entry.get("short", "them"))))


func all_tagged() -> bool:
	return tags.size() >= casualties.size()


## How a tag sits against the truth: "right", "guessed", "over", "under",
## "black" (written off but could live) or "untagged".
func verdict(casualty_id: String) -> String:
	if not tags.has(casualty_id):
		return "untagged"
	var entry := casualty(casualty_id)
	var given := str(tags[casualty_id])
	var truth := str(entry["truth"])
	if given == truth:
		for needed in needed_checks(entry):
			if needed not in checks_done(casualty_id):
				return "guessed"
		return "right"
	if given == "black":
		return "black"
	if truth == "black":
		return "over"
	return "over" if TAGS.find(given) < TAGS.find(truth) else "under"


func under_triaged() -> Array[String]:
	var found: Array[String] = []
	for entry in casualties:
		if verdict(str(entry["id"])) in ["under", "black", "untagged"] and str(entry["truth"]) != "black":
			found.append(str(entry["id"]))
	return found


func all_right() -> bool:
	for entry in casualties:
		if verdict(str(entry["id"])) not in ["right", "guessed"]:
			return false
	return true


func hints_allowed() -> bool:
	return difficulty != "extreme"


func hint_cost() -> int:
	return HINT_COST if difficulty == "hard" else 0


## The next START step for the casualty being looked at, or who to look at.
func hint() -> String:
	if finished or not hints_allowed():
		return ""
	hints_used += 1
	speaker = actor
	if selected.is_empty():
		for entry in casualties:
			if not tags.has(str(entry["id"])):
				_say("Start with %s. Everyone gets a tag before anyone gets a second look." % str(entry.get("short", "the next one")))
				return coach
		_say("Everyone's tagged. Send them in.")
		return coach
	var entry := casualty(selected)
	for needed in needed_checks(entry):
		if needed not in checks_done(selected):
			_say(str({
				"walk": "First thing: can they walk? Anyone who walks is green.",
				"breathing": "Can't walk. So: are they breathing?",
				"airway": "Not breathing. Open the airway before you decide anything.",
				"rate": "Breathing. Now count it. Over thirty is red.",
				"pulse": "Breathing's under thirty. Press a nail bed. Over two seconds is red.",
				"commands": "Pinks up fast. Last check: can they follow a command?",
			}[needed]))
			return coach
	_say("You know enough. Tag them and move on.")
	return coach


## Sends the tagged casualties in: the task ends.
func finish_triage() -> void:
	if finished:
		return
	selected = ""
	var right := 0
	for entry in casualties:
		var casualty_id := str(entry["id"])
		var who := str(entry.get("short", "Someone"))
		match verdict(casualty_id):
			"right":
				right += 1
			"guessed":
				right += 1
				_note(false, "%s: right tag, but on a guess. You never checked %s." %
					[who.capitalize(), _missing_checks(entry)])
			"over":
				_note(false, "%s was %s, not %s. Tagged too urgent: someone sicker waits." %
					[who.capitalize(), entry["truth"], tags[casualty_id]])
			"under":
				_note(false, "%s was %s, tagged %s. %s" % [who.capitalize(), entry["truth"], tags[casualty_id],
					str(entry.get("why", "Sent to wait when they couldn't."))])
			"black":
				_note(false, "%s was written off but could have lived: %s." % [who.capitalize(), entry["truth"]])
			"untagged":
				_note(false, "%s was never tagged. Everyone gets a tag." % who.capitalize())
	_note(right == casualties.size(), "%d of %d tagged right." % [right, casualties.size()])
	if wasted > 0:
		_note(false, "%d check%s the rules didn't need (-%d). Each one is fifteen seconds someone else waits." %
			[wasted, "" if wasted == 1 else "s", wasted * WASTED_CHECK])
	elif right == casualties.size():
		_note(true, "No wasted checks. Each one stopped where the rules said.")
	if hints_used > 0 and hint_cost() > 0:
		_note(false, "%d hint%s from Priya (-%d)." % [hints_used, "" if hints_used == 1 else "s", hints_used * hint_cost()])
	speaker = actor
	var endings: Dictionary = _case.get("sent", {})
	_say(str(endings.get("all" if all_right() else ("under" if not under_triaged().is_empty() else "some"), "Sending them in.")))
	_finish()


func _missing_checks(entry: Dictionary) -> String:
	var missing: Array[String] = []
	for needed in needed_checks(entry):
		if needed not in checks_done(str(entry["id"])):
			missing.append(str(CHECK_NAMES[needed]).to_lower().trim_suffix("?"))
	return " or ".join(missing)


func score() -> int:
	if casualties.is_empty():
		return 100
	var each := 100.0 / casualties.size()
	var points := 0.0
	for entry in casualties:
		match verdict(str(entry["id"])):
			"right":
				points += each
			"guessed":
				points += each * GUESSED
			"over":
				points += each * OVER
	points -= wasted * WASTED_CHECK
	points -= hints_used * hint_cost()
	return clampi(roundi(points), 0, 100)


func instruction() -> String:
	if finished:
		return "Sent in"
	if not selected.is_empty():
		return "Check in order, then tag %s" % str(casualty(selected).get("short", "them"))
	var left := casualties.size() - tags.size()
	if left == 0:
		return "Everyone's tagged · send them in"
	return "Tap someone, check, tag · %d left" % left


func progress() -> float:
	if finished:
		return 1.0
	return float(tags.size()) / maxf(1.0, casualties.size())
