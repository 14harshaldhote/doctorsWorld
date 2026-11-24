class_name SongPlayer
extends Node
## Plays one of the sarcastic songs (Songs): the radio's request first when
## there is one (the RJ's dedication, in his recorded voice), then the
## music, with each line half sung, half chanted by its singer as its bar
## comes round. The background music steps back while a song plays, and
## only one song plays anywhere at a time.
##
## The ward ticks its own (manual), so tests can play a song in a blink;
## the phone's radio ticks itself.

signal line_started(index: int)
signal finished

## How loud the song's music plays, in dB.
const SONG_DB := -3.0
## A request whose voice can't report its end is over after about this long
## a letter.
const REQUEST_LETTER := 0.065

## The song playing anywhere now, or null.
static var active: SongPlayer

var song_id := ""
## Seconds into the music (the request doesn't count).
var time := 0.0
## The line sung last (-1 before the first).
var line := -1
## "", "request" (the dedication) or "song".
var phase := ""
var request := {}
## True when the owner calls tick() itself instead of every frame.
var manual := false
var _music: AudioStreamPlayer
var _speech := 0
var _request_left := 0.0


func _ready() -> void:
	set_process(not manual)


func _process(delta: float) -> void:
	tick(delta)


## True while a song (or its request) is on.
func playing() -> bool:
	return not phase.is_empty()


## Starts a song, after a request ({"say", "text"}) when given. Stops any
## other song first. False for a song that doesn't exist.
func play(id: String, with_request: Dictionary = {}) -> bool:
	if Songs.song(id).is_empty():
		return false
	if active != null and is_instance_valid(active) and active != self:
		active.stop()
	_halt()
	active = self
	song_id = id
	request = with_request
	time = 0.0
	line = -1
	var text := request_text()
	if not text.is_empty():
		phase = "request"
		_request_left = 1.0 + text.length() * REQUEST_LETTER
		_speech = Speech.say(text, str(request.get("say", "rj")))
	else:
		_start_music()
	return true


## Stops the song where it is (the music and any line being sung).
func stop() -> void:
	var was := playing()
	_halt()
	if was:
		finished.emit()


func _halt() -> void:
	if _speech != 0:
		Speech.stop_line(_speech)
		_speech = 0
	if _music != null:
		_music.stop()
	if not phase.is_empty():
		Music.hold_for_song(false)
	phase = ""
	if active == self:
		active = null


func _start_music() -> void:
	phase = "song"
	time = 0.0
	Music.hold_for_song(true)
	if _music == null:
		_music = AudioStreamPlayer.new()
		_music.name = "SongMusic"
		_music.bus = &"Music"
		add_child(_music)
	var track := str(Songs.song(song_id).get("track", ""))
	var stream := Music.stream(track) if ResourceLoader.exists("res://assets/music/%s.ogg" % track) else null
	_music.stream = stream
	_music.volume_db = SONG_DB
	if stream != null and Voice.enabled and is_inside_tree():
		GameSettings.ensure_buses()
		_music.play()


## Moves the song on.
func tick(delta: float) -> void:
	match phase:
		"request":
			if _speech != 0 and Speech.speaking(_speech):
				Speech.tick(delta)
			_request_left -= delta
			if _speech == 0 or not Speech.speaking(_speech) or _request_left <= 0.0:
				if _speech != 0:
					Speech.stop_line(_speech)
				_speech = 0
				_start_music()
		"song":
			if _speech != 0 and Speech.speaking(_speech):
				Speech.tick(delta)
			time += delta
			var lines := Songs.lines(song_id)
			while line + 1 < lines.size() and time >= Songs.line_start(song_id, line + 1):
				line += 1
				var sung: Dictionary = lines[line]
				_speech = Speech.say(str(sung.get("text", "")), str(sung.get("say", "")))
				line_started.emit(line)
			if time >= Songs.length(song_id):
				stop()


## The request's words, said to "Doctor" (the recorded line says that).
func request_text() -> String:
	return str(request.get("text", "")).replace("{called}", "Doctor")


## The words of the line being sung now ("" between songs or before the first).
func line_text() -> String:
	var lines := Songs.lines(song_id)
	return str((lines[line] as Dictionary).get("text", "")) if line >= 0 and line < lines.size() else ""


## The next line's words ("" after the last).
func next_text() -> String:
	var lines := Songs.lines(song_id)
	return str((lines[line + 1] as Dictionary).get("text", "")) if phase == "song" and line + 1 < lines.size() else ""


## How far through the song, 0 to 1.
func progress() -> float:
	return clampf(time / maxf(0.1, Songs.length(song_id)), 0.0, 1.0) if phase == "song" else 0.0


func _exit_tree() -> void:
	_halt()
