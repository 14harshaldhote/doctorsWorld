class_name StoryRunner
extends RefCounted
## Walks through a conversation or scene, one step at a time, and remembers
## what the player chose.
##
## A step is a small dictionary from a story file:
##
##   {"say": "iyer", "text": "You're late.", "mood": "focused", "gesture": "fold_arms", "head": "nod"}
##       A line. "to" names who the speaker looks at (default: the player).
##   {"choose": [{"tone": "Be honest", "text": "...", "trust": {"iyer": 5}, "flag": "x", "then": [...]}]}
##       Two to four replies. The player says the chosen text, its effects
##       apply, then its "then" steps run. A reply with "if" is only offered
##       while its condition holds; one with "again": true offers the same
##       choice again afterwards (questions to ask before deciding).
##   {"do": "walk", "who": "you", "to": "podium"}
##       An action for the scene to perform (walk, give, shot, card...).
##   {"trust": {"grace": 2}}, {"flag": "met_grace"}, {"unflag": "x"}, {"xp": 10}, {"minutes": 5}
##       Silent changes to the career.
##   {"if": "flag_name", "then": [...], "else": [...]}   ("!flag" means not set)
##   {"end": true}
##
## Text can use {name}, {first}, {last}, {called} (how people address the
## player, "Dr. Verma") and {title} ("Dr. Asha Verma").

const MOODS := ["calm", "happy", "worried", "focused", "tired", "angry", "shocked"]
const LINE_KEYS := ["say", "text", "mood", "gesture", "head", "to"]
const OPTION_KEYS := ["tone", "text", "skill", "trust", "flag", "xp", "effect", "detail", "then", "gesture", "mood", "if",
	"again"]
const SILENT_KEYS := ["trust", "flag", "unflag", "xp", "minutes"]

var profile: PlayerProfile
var cast: Dictionary
## Every line said so far, as [speaker id, text].
var history: Array = []

var _stack: Array = []
var _pending: Array = []
var _pending_step := {}
var _about := ""
var _finished := true


func _init(for_profile: PlayerProfile = null, with_cast: Dictionary = {}) -> void:
	profile = for_profile if for_profile != null else PlayerProfile.new()
	cast = with_cast if not with_cast.is_empty() else StoryBook.cast()


func start(steps: Array) -> void:
	_stack = [[steps, 0]]
	_pending = []
	_about = ""
	_finished = false


func is_finished() -> bool:
	return _finished


## The person the current choice is about: the last speaker with a trust meter.
func about() -> String:
	return _about


func waiting_for_choice() -> bool:
	return not _pending.is_empty()


## The replies on offer while waiting for a choice (their tone, text...).
func offered() -> Array:
	return _pending.duplicate()


## The next thing to show: a line, a choice, an action, or the end.
func next() -> Dictionary:
	if not _pending.is_empty():
		return _choice_event()
	while not _stack.is_empty():
		var frame: Array = _stack[_stack.size() - 1]
		var steps: Array = frame[0]
		var index: int = frame[1]
		if index >= steps.size():
			_stack.pop_back()
			continue
		frame[1] = index + 1
		var step: Dictionary = steps[index]
		if step.has("say"):
			return _line_event(step)
		if step.has("choose"):
			_pending = _offered(step["choose"])
			if _pending.is_empty():
				continue
			_pending_step = step
			_about = str(step.get("about", _about))
			return _choice_event()
		if step.has("do"):
			return {"type": "action", "step": step}
		if step.has("if"):
			var branch: Variant = step.get("then", []) if _condition(str(step["if"])) else step.get("else", [])
			if typeof(branch) == TYPE_ARRAY and not (branch as Array).is_empty():
				_stack.append([branch, 0])
			continue
		if step.get("end", false):
			_stack.clear()
			break
		_apply(step)
	_finished = true
	return {"type": "end"}


## Picks a reply. Returns what happened: {said, effect, detail, trust: {id: [change, new value]}}.
func choose(index: int) -> Dictionary:
	if _pending.is_empty():
		return {}
	var option: Dictionary = _pending[clampi(index, 0, _pending.size() - 1)]
	_pending = []
	var changes := _apply(option)
	var said := fill(str(option.get("text", "")))
	if bool(option.get("again", false)):
		_stack.append([[_pending_step], 0])
	var then: Variant = option.get("then", [])
	if typeof(then) == TYPE_ARRAY and not (then as Array).is_empty():
		_stack.append([then, 0])
	var line := {"say": "you", "text": option.get("text", "")}
	for key: String in ["gesture", "mood"]:
		if option.has(key):
			line[key] = option[key]
	_stack.append([[line], 0])
	return {
		"said": said,
		"tone": str(option.get("tone", "")),
		"effect": fill(str(option.get("effect", ""))),
		"detail": fill(str(option.get("detail", ""))),
		"trust": changes,
	}


## Fills in the player's name and how people address them.
func fill(text: String) -> String:
	return text.format({
		"name": profile.name,
		"first": profile.first_name(),
		"last": profile.last_name(),
		"called": profile.called(),
		"title": profile.full_title(),
	})


func display_name(id: String) -> String:
	if id == "you":
		return profile.full_title()
	return fill(str(cast.get(id, {}).get("name", id.capitalize())))


## A character's role, which can change as the years pass ("later_roles":
## {"14": "Consultant surgeon"} from Day 14 on).
func role(id: String) -> String:
	if id == "you":
		return "You"
	var entry: Dictionary = cast.get(id, {})
	var text := str(entry.get("role", ""))
	var from_day := 0
	var later: Dictionary = entry.get("later_roles", {})
	for day_text: String in later:
		if profile != null and profile.day >= int(day_text) and int(day_text) > from_day:
			from_day = int(day_text)
			text = str(later[day_text])
	return fill(text)


## The trust a character starts with before the player has met them, or -1
## for people with no trust meter (passers-by, the player).
func start_trust(id: String) -> int:
	var entry: Dictionary = cast.get(id, {})
	return int(entry["trust"]) if entry.has("trust") else -1


func trust_of(id: String) -> int:
	var start := start_trust(id)
	return -1 if start < 0 else profile.trust(id, start)


static func mood_index(mood_name: String) -> int:
	return MOODS.find(mood_name)


func _line_event(step: Dictionary) -> Dictionary:
	var speaker := str(step["say"])
	var text := fill(str(step.get("text", "")))
	history.append([speaker, text])
	if speaker != "you" and start_trust(speaker) >= 0:
		_about = speaker
	return {
		"type": "line",
		"speaker": speaker,
		"name": display_name(speaker),
		"role": role(speaker),
		"text": text,
		"mood": mood_index(str(step.get("mood", ""))),
		"gesture": str(step.get("gesture", "")),
		"head": str(step.get("head", "")),
		"to": str(step.get("to", "")),
	}


func _choice_event() -> Dictionary:
	var options := []
	for option: Dictionary in _pending:
		options.append({
			"tone": str(option.get("tone", "")),
			"text": fill(str(option.get("text", ""))),
			"skill": str(option.get("skill", "")),
		})
	return {"type": "choice", "options": options, "about": _about}


## The replies of a choice that are on offer now.
func _offered(options: Array) -> Array:
	var found := []
	for option: Dictionary in options:
		if not option.has("if") or _condition(str(option["if"])):
			found.append(option)
	return found


func _condition(test: String) -> bool:
	if test.begins_with("!"):
		return not profile.has_flag(test.substr(1))
	return profile.has_flag(test)


## Applies a step's or reply's effects. Returns trust changes {id: [change, new value]}.
func _apply(step: Dictionary) -> Dictionary:
	var changes := {}
	var trust: Variant = step.get("trust")
	if typeof(trust) == TYPE_DICTIONARY:
		for id: String in trust:
			var start := maxi(0, start_trust(id))
			var before := profile.trust(id, start)
			var after := profile.change_trust(id, int(trust[id]), start)
			changes[id] = [after - before, after]
	if step.has("flag"):
		profile.set_flag(str(step["flag"]))
	if step.has("unflag"):
		profile.set_flag(str(step["unflag"]), false)
	if step.has("xp"):
		profile.total_xp += maxi(0, int(step["xp"]))
	if step.has("minutes"):
		profile.pass_minutes(int(step["minutes"]))
	return changes


## Checks a list of steps against the cast and the known actions. Returns
## one message per problem, or nothing when the steps are fine.
static func validate(steps: Variant, known_cast: Dictionary, actions: Array, where: String = "") -> PackedStringArray:
	var problems := PackedStringArray()
	if typeof(steps) != TYPE_ARRAY:
		problems.append("%s: steps must be a list" % where)
		return problems
	for index in (steps as Array).size():
		var step: Variant = steps[index]
		var at := "%s[%d]" % [where, index]
		if typeof(step) != TYPE_DICTIONARY:
			problems.append("%s: a step must be an object" % at)
			continue
		problems.append_array(_validate_step(step, known_cast, actions, at))
	return problems


static func _validate_step(step: Dictionary, known_cast: Dictionary, actions: Array, at: String) -> PackedStringArray:
	var problems := PackedStringArray()
	if step.has("say"):
		var speaker := str(step["say"])
		if speaker != "you" and not known_cast.has(speaker):
			problems.append("%s: unknown speaker %s" % [at, speaker])
		if str(step.get("text", "")).is_empty():
			problems.append("%s: a line needs text" % at)
		for key: String in step:
			if key not in LINE_KEYS:
				problems.append("%s: unknown key %s in a line" % [at, key])
		problems.append_array(_validate_look(step, at))
		if step.has("to") and str(step["to"]) != "you" and not known_cast.has(str(step["to"])):
			problems.append("%s: unknown listener %s" % [at, step["to"]])
	elif step.has("choose"):
		var options: Variant = step["choose"]
		if typeof(options) != TYPE_ARRAY or (options as Array).size() < 2 or (options as Array).size() > 4:
			problems.append("%s: a choice needs two to four replies" % at)
			return problems
		for number in (options as Array).size():
			var option: Variant = options[number]
			var place := "%s.choose[%d]" % [at, number]
			if typeof(option) != TYPE_DICTIONARY:
				problems.append("%s: a reply must be an object" % place)
				continue
			if str(option.get("tone", "")).is_empty() or str(option.get("text", "")).is_empty():
				problems.append("%s: a reply needs a tone and text" % place)
			for key: String in option:
				if key not in OPTION_KEYS:
					problems.append("%s: unknown key %s in a reply" % [place, key])
			problems.append_array(_validate_look(option, place))
			problems.append_array(_validate_trust(option, known_cast, place))
			if option.has("then"):
				problems.append_array(validate(option["then"], known_cast, actions, place + ".then"))
		var exits := (options as Array).filter(func(option: Variant) -> bool:
			return typeof(option) == TYPE_DICTIONARY and not bool((option as Dictionary).get("again", false)) \
				and not (option as Dictionary).has("if"))
		if exits.is_empty():
			problems.append("%s: a choice needs a reply that always moves on (no if, no again)" % at)
	elif step.has("do"):
		if str(step["do"]) not in actions:
			problems.append("%s: unknown action %s" % [at, step["do"]])
		for key: String in ["who", "from"]:
			if step.has(key) and str(step[key]) != "you" and not known_cast.has(str(step[key])):
				problems.append("%s: unknown actor %s" % [at, step[key]])
		if step.has("gesture") and str(step["gesture"]) not in AvatarRig.GESTURES:
			problems.append("%s: unknown gesture %s" % [at, step["gesture"]])
		if step.has("mood") and mood_index(str(step["mood"])) < 0:
			problems.append("%s: unknown mood %s" % [at, step["mood"]])
	elif step.has("if"):
		for key: String in ["then", "else"]:
			if step.has(key):
				problems.append_array(validate(step[key], known_cast, actions, "%s.%s" % [at, key]))
	elif not step.get("end", false):
		var silent := false
		for key: String in step:
			if key in SILENT_KEYS:
				silent = true
			else:
				problems.append("%s: unknown key %s" % [at, key])
		if not silent:
			problems.append("%s: the step does nothing" % at)
		problems.append_array(_validate_trust(step, known_cast, at))
	return problems


static func _validate_look(step: Dictionary, at: String) -> PackedStringArray:
	var problems := PackedStringArray()
	if step.has("mood") and mood_index(str(step["mood"])) < 0:
		problems.append("%s: unknown mood %s" % [at, step["mood"]])
	if step.has("gesture") and str(step["gesture"]) not in AvatarRig.GESTURES:
		problems.append("%s: unknown gesture %s" % [at, step["gesture"]])
	if step.has("head") and str(step["head"]) not in AvatarRig.HEAD_GESTURES:
		problems.append("%s: unknown head movement %s" % [at, step["head"]])
	return problems


static func _validate_trust(step: Dictionary, known_cast: Dictionary, at: String) -> PackedStringArray:
	var problems := PackedStringArray()
	var trust: Variant = step.get("trust")
	if trust == null:
		return problems
	if typeof(trust) != TYPE_DICTIONARY:
		problems.append("%s: trust must map people to changes" % at)
		return problems
	for id: Variant in trust:
		if not known_cast.has(str(id)) or not (known_cast[str(id)] as Dictionary).has("trust"):
			problems.append("%s: %s has no trust meter" % [at, id])
	return problems
