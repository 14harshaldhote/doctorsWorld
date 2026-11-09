class_name InstrumentTask
extends TrainingTask
## Know your instruments: first match each job to the instrument on the
## tray, then call for them by name as Dr. Iyer asks in a mock operation,
## against the clock, with Tom handing them over.

const MATCH_ROUNDS := 6
const CALL_ROUNDS := 6
const CALL_TIME := 6.0
const REVEAL_TIME := 1.2
const MATCH_POINTS := 7
const MATCH_SECOND_TRY := 3
## Wrong picks on one tray before Tom shows you the answer.
const MATCH_TRIES := 3
const CALL_POINTS := 7
const CALL_SPEED_POINTS := 2
const CALL_LATE_POINTS := 3
const FINISH_POINTS := 4

## "match", "call" or "done".
var part := "match"
var round_index := 0
## The instrument wanted this round.
var wanted := ""
## The line asking for it (a job while matching, a surgeon's call later).
var prompt := ""
var time_left := CALL_TIME
var revealing := false
## The instrument handed over this round ("" until then).
var handed := ""
var points := 0
var first_try := 0
var _tries := 0
var _match_plan: Array = []
var _call_plan: Array = []
var _reveal_left := 0.0
var _rng: SeededRandom
## [wanted, picked] pairs, for the notes.
var _mixups: Array = []
var _call_times: Array[float] = []


func _init(with_seed: int = 1) -> void:
	id = "instruments"
	_rng = SeededRandom.new(with_seed + 7)
	_match_plan = _rng.shuffled(Instruments.ALL).slice(0, MATCH_ROUNDS)
	_call_plan = _rng.shuffled(Instruments.ALL).slice(0, CALL_ROUNDS)
	_start_round()
	_say("Every instrument has one job. Tap the one that does this.")


## Tapping an instrument on the tray (matching) or on the ring (calling).
func pick(instrument: String) -> void:
	if finished or revealing or instrument not in Instruments.ALL:
		return
	_tries += 1
	if instrument == wanted:
		if part == "match":
			points += MATCH_POINTS if _tries == 1 else MATCH_SECOND_TRY
			_say("%s. Yes: %s." % [Instruments.name_of(wanted), Instruments.job_of(wanted).to_lower()])
		else:
			if _tries == 1:
				points += CALL_POINTS + int(round(CALL_SPEED_POINTS * time_left / CALL_TIME))
			else:
				points += CALL_LATE_POINTS
			_call_times.append(CALL_TIME - time_left)
			_say("%s." % Instruments.name_of(wanted))
		if _tries == 1:
			first_try += 1
		_hand_over(wanted)
		return
	_mixups.append([wanted, instrument])
	if part == "match":
		if _tries >= MATCH_TRIES:
			_say("This one: the %s. %s." % [Instruments.name_of(wanted).to_lower(), Instruments.job_of(wanted)], true)
			_hand_over(wanted)
			return
		_say("That's the %s: %s." % [Instruments.name_of(instrument).to_lower(),
			Instruments.job_of(instrument).to_lower()], true)
	else:
		_say("That's the %s, Doctor. She asked for something else." % Instruments.name_of(instrument).to_lower(), true)


func tick(delta: float) -> void:
	super(delta)
	if finished:
		return
	if revealing:
		_reveal_left -= delta
		if _reveal_left <= 0.0:
			revealing = false
			_next()
		return
	if part == "call":
		time_left = maxf(0.0, time_left - delta)
		if time_left <= 0.0:
			_mixups.append([wanted, ""])
			_call_times.append(CALL_TIME)
			_say("%s. I'll take the silence as a yes, Doctor." % Instruments.name_of(wanted), true)
			_hand_over(wanted)


func score() -> int:
	var total := points + (FINISH_POINTS if finished else 0)
	return clampi(total, 0, 100)


func instruction() -> String:
	if part == "match":
		return "Tray %d of %d: tap the instrument that does the job" % [round_index + 1, MATCH_ROUNDS]
	if part == "call":
		return "Call %d of %d: ask Tom for what Dr. Iyer needs" % [round_index + 1, CALL_ROUNDS]
	return "Done"


func progress() -> float:
	if part == "match":
		return 0.5 * round_index / MATCH_ROUNDS
	if part == "call":
		return 0.5 + 0.5 * round_index / CALL_ROUNDS
	return 1.0


func _start_round() -> void:
	_tries = 0
	handed = ""
	time_left = CALL_TIME
	if part == "match":
		wanted = str(_match_plan[round_index])
		prompt = Instruments.job_of(wanted)
	else:
		wanted = str(_call_plan[round_index])
		var lines: Array = Instruments.CALLS[wanted]
		prompt = str(lines[round_index % lines.size()])
	changed.emit()


func _hand_over(instrument: String) -> void:
	handed = instrument
	revealing = true
	_reveal_left = REVEAL_TIME
	changed.emit()


func _next() -> void:
	round_index += 1
	if part == "match" and round_index >= MATCH_ROUNDS:
		part = "call"
		round_index = 0
		_say("Good. Now a mock operation. Dr. Iyer asks, you tell Tom. Don't think, call.")
	elif part == "call" and round_index >= CALL_ROUNDS:
		_end()
		return
	_start_round()


func _end() -> void:
	part = "done"
	var rounds := MATCH_ROUNDS + CALL_ROUNDS
	_note(first_try >= rounds - 1, "%d of %d right first time." % [first_try, rounds])
	var told := []
	for pair: Array in _mixups:
		var key := "%s/%s" % pair
		if key in told or told.size() >= 2:
			continue
		told.append(key)
		if str(pair[1]).is_empty():
			_note(false, "You froze on the %s. %s." % [Instruments.name_of(pair[0]).to_lower(),
				Instruments.job_of(pair[0])])
		else:
			_note(false, "You mixed up the %s and the %s. The %s: %s." % [Instruments.name_of(pair[0]).to_lower(),
				Instruments.name_of(pair[1]).to_lower(), Instruments.name_of(pair[0]).to_lower(),
				Instruments.job_of(pair[0]).to_lower()])
	var average := 0.0
	for seconds in _call_times:
		average += seconds
	average /= maxf(1.0, _call_times.size())
	if average <= 2.5:
		_note(true, "Calls in %.1f seconds on average. Tom had it ready before you finished asking." % average)
	else:
		_note(false, "Calls took %.1f seconds on average. In theatre, every second is a patient lying open." % average)
	_finish()
