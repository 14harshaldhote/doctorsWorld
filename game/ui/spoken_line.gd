class_name SpokenLine
extends RefCounted
## One typed line read aloud: it starts the voice and tells the typing how
## far it may go, so each word appears as it is said. When the device can't
## speak, start() returns false and the owner types the line itself with
## the murmur, as before.
##
## A tap can show the whole line at once; the voice carries on to the end of
## the line unless the next line (or leaving) stops it.

## Letters a second while a word that has just been said appears.
const REVEAL_SPEED := 90.0
## If the voice gives no word marks for a while, the text creeps on at about
## speaking pace, so it can never stall.
const CREEP_SPEED := 13.0
const CREEP_AFTER := 0.9
## A voice that has not started by then is given up on.
const START_TIMEOUT := 2.0
## Once the whole line shows, a voice that never says it has finished is
## treated as done after this long (it may go on speaking).
const END_GRACE := 3.0

var text := ""
var who := ""
## True from start() until the voice ends, fails or is stopped.
var speaking := false
## True when the voice never started: the owner types the rest itself.
var failed := false
## How many words the voice has reached (the mouth moves on each).
var words := 0

var _id := 0
var _token := 0
var _upto := 0
var _clock := 0.0
var _since_word := 0.0
var _started := false
var _late := false


## Starts reading a line aloud as a cast member. False when it can't be.
func start(line: String, speaker: String) -> bool:
	stop()
	_token += 1
	text = line
	who = speaker
	words = 0
	_upto = 0
	_clock = 0.0
	_since_word = 0.0
	_started = false
	_late = false
	failed = false
	_id = Speech.say(line, speaker, _on_start.bind(_token), _on_word.bind(_token), _on_done.bind(_token))
	speaking = _id != 0
	return speaking


## Stops the voice (a new line, a skip or leaving).
func stop() -> void:
	_token += 1
	if speaking:
		speaking = false
		Speech.stop_line(_id)


## True once the voice is done with the line (or never spoke it).
func is_done() -> bool:
	return not speaking or _late


## Moves time on. Returns how many letters of the line may show now,
## given how many show already.
func advance(delta: float, shown: float) -> float:
	if not speaking:
		return float(text.length())
	Speech.tick(delta)
	_clock += delta
	_since_word += delta
	if not speaking:
		return float(text.length())
	if not _started:
		if _clock > START_TIMEOUT:
			failed = true
			stop()
		return shown
	var target := float(_upto)
	if _since_word > CREEP_AFTER:
		var pace := CREEP_SPEED * float(Speech.SPEEDS[clampi(GameSettings.current.speech_speed, 0, Speech.SPEEDS.size() - 1)])
		target = maxf(target, shown + delta * pace)
	if shown >= text.length() and _since_word > END_GRACE:
		_late = true
	return minf(target, float(text.length()))


func _on_start(token: int) -> void:
	if token == _token:
		_started = true


func _on_word(end: int, token: int) -> void:
	if token != _token:
		return
	_started = true
	_upto = maxi(_upto, end)
	_since_word = 0.0
	words += 1


func _on_done(token: int) -> void:
	if token == _token:
		speaking = false
