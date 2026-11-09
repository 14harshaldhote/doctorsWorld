class_name MonitorTask
extends TrainingTask
## Read the monitor: learn what the four numbers mean, then spot the one
## that is wrong, round after round, against the clock. Some screens are
## all fine, and saying so is the right answer.

const ROUNDS := 6
const ROUND_TIME := 8.0
const REVEAL_TIME := 1.6
const POINTS_FOR_LEARNING := 4
const POINTS_PER_ROUND := 12
const SPEED_POINTS := 4
## The problems the rounds are made from: [kind, direction]; "none" is all fine.
const PROBLEMS := [["spo2", "low"], ["hr", "high"], ["none", ""], ["bp", "low"], ["rr", "high"], ["hr", "low"],
	["bp", "high"]]

## "learn", "quiz" or "done".
var phase := "learn"
var learned: Array[String] = []
var round_index := -1
var vitals: Vitals
## Seconds left to answer this round.
var time_left := ROUND_TIME
## True while a round's answer is on show before the next screen.
var revealing := false
## What the player picked this round ("" for running out of time).
var picked := ""
var correct := 0
var round_points := 0
var _reveal_left := 0.0
var _plan: Array = []
var _rng: SeededRandom
var _missed: Array[String] = []
var _answer_times: Array[float] = []


func _init(with_seed: int = 1) -> void:
	id = "monitor"
	_rng = SeededRandom.new(with_seed)
	var pool: Array = _rng.shuffled(PROBLEMS)
	_plan = pool.slice(0, ROUNDS)
	vitals = Vitals.healthy(_rng)
	_say("Four numbers keep your patient alive. Tap each one and I'll tell you what it means.")


## The answer for this round: a vital's kind, or "none" when all is fine.
func answer_now() -> String:
	var problems := vitals.problems()
	return problems[0] if not problems.is_empty() else "none"


## Tapping a number while learning.
func learn(kind: String) -> void:
	if phase != "learn" or kind not in Vitals.KINDS:
		return
	if kind not in learned:
		learned.append(kind)
	var line := "%s: %s. Normal is %s." % [Vitals.NAMES[kind], Vitals.MEANING[kind], Vitals.NORMAL[kind]]
	if learned.size() == Vitals.KINDS.size():
		line += " Right. Now I'll show you some patients. Tap whatever is wrong."
	_say(line)


## Starts the quiz once every number has been explained.
func start_quiz() -> void:
	if phase != "learn" or learned.size() < Vitals.KINDS.size():
		return
	phase = "quiz"
	_next_round()


## Picking an answer: a vital's kind, or "none" for "all fine".
func answer(kind: String) -> void:
	if phase != "quiz" or revealing:
		return
	picked = kind
	var right := answer_now()
	_answer_times.append(ROUND_TIME - time_left)
	if kind == right:
		correct += 1
		round_points += POINTS_PER_ROUND + int(round(SPEED_POINTS * time_left / ROUND_TIME))
		if right == "none":
			_say("Right: everything is in range. Not every screen is an emergency.")
		else:
			_say("Yes. %s %s is %s. Normal is %s." % [Vitals.NAMES[right], vitals.value_text(right),
				vitals.problem_words(right), Vitals.NORMAL[right]])
	else:
		_miss(right, kind)
	revealing = true
	_reveal_left = REVEAL_TIME
	changed.emit()


func tick(delta: float) -> void:
	super(delta)
	if phase != "quiz":
		return
	if revealing:
		_reveal_left -= delta
		if _reveal_left <= 0.0:
			revealing = false
			_next_round()
		return
	time_left = maxf(0.0, time_left - delta)
	if time_left <= 0.0:
		picked = ""
		_answer_times.append(ROUND_TIME)
		_miss(answer_now(), "")
		revealing = true
		_reveal_left = REVEAL_TIME
		changed.emit()


func score() -> int:
	var points := round_points
	if learned.size() == Vitals.KINDS.size():
		points += POINTS_FOR_LEARNING
	return clampi(points, 0, 100)


func instruction() -> String:
	if phase == "learn":
		return "Tap each number to learn it: %d of %d" % [learned.size(), Vitals.KINDS.size()]
	if phase == "quiz":
		return "Patient %d of %d: tap what's wrong, or All fine" % [round_index + 1, ROUNDS]
	return "Done"


func progress() -> float:
	if phase == "learn":
		return 0.15 * learned.size() / Vitals.KINDS.size()
	if phase == "quiz":
		return 0.15 + 0.85 * float(round_index) / ROUNDS
	return 1.0


func _next_round() -> void:
	round_index += 1
	if round_index >= ROUNDS:
		_end()
		return
	var problem: Array = _plan[round_index]
	if str(problem[0]) == "none":
		vitals = Vitals.healthy(_rng)
	else:
		vitals = Vitals.with_problem(_rng, str(problem[0]), str(problem[1]))
	time_left = ROUND_TIME
	picked = ""
	changed.emit()


func _miss(right: String, kind: String) -> void:
	var what := ""
	if right == "none":
		what = "Everything was in range: %s %s is normal." % [Vitals.NAMES[kind], vitals.value_text(kind)] \
			if not kind.is_empty() else "Everything was in range there."
	else:
		what = "%s %s is %s; normal is %s." % [Vitals.NAMES[right], vitals.value_text(right),
			vitals.problem_words(right), Vitals.NORMAL[right]]
		if not kind.is_empty() and kind != "none":
			what = "%s %s is fine. %s" % [Vitals.NAMES[kind], vitals.value_text(kind), what]
	if kind.is_empty():
		what = "Too slow. " + what
	if right not in _missed:
		_missed.append(right)
	_say(what, true)


func _end() -> void:
	phase = "done"
	_note(correct >= ROUNDS - 1, "You read %d of %d monitors right." % [correct, ROUNDS])
	for kind: String in _missed.slice(0, 2):
		if kind == "none":
			_note(false, "When everything is in range, say so. Treating a healthy number wastes time you'll need.")
		else:
			_note(false, "Watch the %s: normal is %s." % [str(Vitals.NAMES[kind]).to_lower(), Vitals.NORMAL[kind]])
	var average := 0.0
	for seconds in _answer_times:
		average += seconds
	average /= maxf(1.0, _answer_times.size())
	if average <= 3.5:
		_note(true, "Quick eyes: %.1f seconds a screen on average. In theatre, that's what saves people." % average)
	else:
		_note(false, "%.1f seconds a screen on average. Get it under 3 and the monitor stops being scary." % average)
	_finish()
