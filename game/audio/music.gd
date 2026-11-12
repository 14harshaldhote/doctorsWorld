class_name Music
extends Node
## The background music: one looping track at a time, crossfading when the
## place or the mood changes, plus the promotion fanfare. The tracks are made
## by tools/make_music.py and play on the Music bus, so the Music setting
## controls them.
##
## Main adds the one Music node; scenes ask for a track with Music.cue(),
## which does nothing in tests and tools where there is no Music node.
## While someone speaks a line aloud the music dips (duck_for_speech), so
## every word is clear.

const TRACKS := ["title", "hospital", "theatre", "night", "emergency", "sad"]
const FADE := 1.4
## How far the music dips while the fanfare plays, in dB.
const DUCK := -14.0
## How far the music dips under a spoken line, in dB.
const SPEECH_DUCK := -10.0

static var player: Music

## The track playing (or fading in) now, or "".
var track := ""
var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _fanfare: AudioStreamPlayer
var _tweens: Array[Tween] = []
## Lowers the whole Music bus under speech (an effect on the bus, so it
## leaves the crossfades alone).
var _speech_gain: AudioEffectAmplify
var _speech_tween: Tween
var _speech_ducked := false


static func stream(track_name: String) -> AudioStream:
	var path := "res://assets/music/%s.ogg" % track_name
	if not ResourceLoader.exists(path):
		push_error("No music called %s" % track_name)
		return null
	var loaded := load(path) as AudioStreamOggVorbis
	if loaded != null:
		loaded.loop = track_name in TRACKS
	return loaded


## Asks for a track ("" for silence). Safe to call when there is no player.
static func cue(track_name: String) -> void:
	if player != null and is_instance_valid(player):
		player.play_track(track_name)


## The promotion fanfare, with the music dipped under it.
static func fanfare() -> void:
	if player != null and is_instance_valid(player):
		player.play_fanfare()


## The track playing now ("" when there is none or no player).
static func current() -> String:
	if player != null and is_instance_valid(player):
		return player.track
	return ""


## Dips the music while a line is spoken aloud, and brings it back after.
static func duck_for_speech(on: bool) -> void:
	if player != null and is_instance_valid(player):
		player.set_speech_duck(on)


func _ready() -> void:
	GameSettings.ensure_buses()
	for index in 2:
		var made := AudioStreamPlayer.new()
		made.name = "Track%d" % index
		made.bus = &"Music"
		made.volume_db = -80.0
		add_child(made)
		_players.append(made)
	_fanfare = AudioStreamPlayer.new()
	_fanfare.name = "Fanfare"
	_fanfare.bus = &"Music"
	add_child(_fanfare)
	_speech_gain = _bus_gain()
	if _speech_gain != null:
		_speech_gain.volume_db = 0.0


## The gain effect on the Music bus that speech ducking turns down.
static func _bus_gain() -> AudioEffectAmplify:
	var bus := AudioServer.get_bus_index(&"Music")
	if bus < 0:
		return null
	for index in AudioServer.get_bus_effect_count(bus):
		var effect := AudioServer.get_bus_effect(bus, index)
		if effect is AudioEffectAmplify:
			return effect
	var made := AudioEffectAmplify.new()
	AudioServer.add_bus_effect(bus, made)
	return made


func is_ducked_for_speech() -> bool:
	return _speech_ducked


func set_speech_duck(on: bool) -> void:
	if on == _speech_ducked:
		return
	_speech_ducked = on
	if _speech_gain == null:
		_speech_gain = _bus_gain()
	if _speech_gain == null or not is_inside_tree():
		return
	if _speech_tween != null:
		_speech_tween.kill()
	_speech_tween = create_tween()
	if on:
		_speech_tween.tween_property(_speech_gain, "volume_db", SPEECH_DUCK, 0.25)
	else:
		# A short wait first, so the music doesn't pump between lines.
		_speech_tween.tween_interval(0.6)
		_speech_tween.tween_property(_speech_gain, "volume_db", 0.0, 0.9)


func play_track(track_name: String) -> void:
	if track_name == track or _players.is_empty():
		return
	track = track_name
	for running in _tweens:
		running.kill()
	_tweens.clear()
	var old := _players[_active]
	_active = 1 - _active
	var next := _players[_active]
	_fade(old, -80.0, true)
	if track_name.is_empty():
		return
	next.stream = stream(track_name)
	next.volume_db = -40.0
	next.play()
	_fade(next, 0.0, false)


func play_fanfare() -> void:
	if _fanfare == null:
		return
	_fanfare.stream = stream("fanfare")
	_fanfare.play()
	var current := _players[_active]
	var dip := create_tween()
	dip.tween_property(current, "volume_db", DUCK, 0.3)
	dip.tween_interval(5.0)
	dip.tween_property(current, "volume_db", 0.0, 1.5)
	_tweens.append(dip)


func _fade(which: AudioStreamPlayer, to_db: float, stop_after: bool) -> void:
	var fade := create_tween()
	fade.tween_property(which, "volume_db", to_db, FADE)
	if stop_after:
		fade.tween_callback(which.stop)
	_tweens.append(fade)
