extends TestCase
## Recorded voices: lines made ahead of time with natural voices play
## instead of the phone's reading voice, found by who says them and what
## they say, with the player's name and numbers fitted in; the phone's
## voice reads only lines that have no recording.

const FakeSpeech := preload("res://tests/unit/fake_speech.gd")
const STEP := 1.0 / 30.0
const LINE := "History first, then examine her."
const NAMED := "Questions are limited, Dr. Verma."
const VITALS := "Heart rate 88. Pressure 118/74."

var _settings_before: GameSettings = GameSettings.current
var _backend_before: SpeechBackend = Speech.backend
var _music_before: Music = Music.player
var _clips := {}


func cleanup() -> void:
	Speech.stop()
	Speech.use_backend(_backend_before)
	VoiceBank.reset()
	super()
	GameSettings.current = _settings_before
	Music.player = _music_before


## A silent clip of a given length.
func _clip(seconds: float) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 8000
	var data := PackedByteArray()
	data.resize(int(8000 * seconds) * 2)
	wav.data = data
	return wav


func _part(name: String, seconds: float, words: int) -> Dictionary:
	_clips[name] = _clip(seconds)
	var times := []
	for index in words:
		times.append(seconds * (index + 1) / words)
	return {"stream": _clips[name], "length": seconds, "words": times}


func _bank() -> FakeSpeech:
	GameSettings.current = GameSettings.new()
	var fake := FakeSpeech.new()
	Speech.use_backend(fake)
	VoiceBank.use({
		"lines": [
			{"who": "iyer", "key": VoiceBank.normalize(LINE), "parts": [_part("line", 2.0, 5)]},
			{"who": "iyer", "key": "questions are limited {called}", "parts": [_part("named", 1.5, 4)]},
			{"who": "khan", "key": "heart rate # pressure # #", "parts": [
				_part("heart", 0.6, 2), {"number": 0}, _part("pressure", 0.5, 1), {"number": 1},
				_part("over", 0.2, 1), {"number": 2}]},
			{"who": "you.lighter", "key": "i ll scrub in", "parts": [_part("lighter", 1.0, 3)]},
			{"who": "you.deeper", "key": "i ll scrub in", "parts": [_part("deeper", 1.0, 3)]},
		],
		"numbers": {"khan": {"88": _part("88", 0.4, 2), "118": _part("118", 0.6, 3), "74": _part("74", 0.5, 2)}},
	})
	return fake


func _ui() -> ConversationUi:
	var ui := ConversationUi.new()
	add_node(ui)
	return ui


func test_lines_are_found_by_who_says_them_and_their_words() -> void:
	_bank()
	var parts := VoiceBank.find("iyer", LINE)
	expect_equal(parts.size(), 1, "Dr. Iyer's line has a recording")
	expect(parts[0]["stream"] == _clips["line"])
	expect_equal(VoiceBank.find("iyer", "history FIRST... then examine her!").size(), 1,
		"case and punctuation don't matter")
	expect(VoiceBank.find("grace", LINE).is_empty(), "nobody else's recording is used")
	expect(VoiceBank.find("iyer", "History first.").is_empty(), "a different line has none")


func test_the_players_name_fits_any_name() -> void:
	_bank()
	for line: String in [NAMED, "Questions are limited, Dr. Asha.", "Questions are limited, Dr. Konstantinopolska-Wiśniewska."]:
		var parts := VoiceBank.find("iyer", line)
		expect(parts.size() == 1 and parts[0]["stream"] == _clips["named"], "found: " + line)
	expect(VoiceBank.find("iyer", "Questions are limited.").is_empty(), "the name has to be there")


func test_numbers_are_said_from_their_own_clips() -> void:
	_bank()
	var parts := VoiceBank.find("khan", VITALS)
	expect_equal(parts.size(), 6, "words, number, words, number, words, number")
	var streams := parts.map(func(part: Dictionary) -> AudioStream: return part["stream"])
	expect_equal(streams, [_clips["heart"], _clips["88"], _clips["pressure"], _clips["118"], _clips["over"], _clips["74"]])
	expect(VoiceBank.find("khan", "Heart rate 88. Pressure 999/74.").is_empty(),
		"a number with no clip leaves the line to the phone's voice")


func test_a_recorded_line_plays_instead_of_the_phone_voice() -> void:
	var fake := _bank()
	var music := Music.new()
	add_node(music)
	Music.player = music
	Music.cue("hospital")
	var ui := _ui()
	ui.show_line("Dr. Meera Iyer", LINE, {"voice": "iyer"})
	expect(ui.reading_aloud(), "the line is read aloud")
	expect(Speech.recorded(), "from its recording")
	expect(fake.spoken.is_empty(), "the phone's voice stays quiet")
	ui.tick(STEP)
	expect(music.is_ducked_for_speech(), "the music dips under it")
	var time := STEP
	var half := -1
	while ui.is_typing() and time < 10.0:
		ui.tick(STEP)
		time += STEP
		if half < 0 and time >= 1.0:
			half = ui._text.visible_characters
	expect_between(half, 6, LINE.length() - 6, "halfway through the clip, about half the line shows")
	expect_between(time, 1.6, 3.5, "the words appear as the clip says them")
	expect_equal(ui._text.visible_characters, LINE.length(), "the whole line shows")
	for frame in 60:
		ui.tick(STEP)
	expect(not Speech.speaking(), "the line is over when its clip is")
	expect(not music.is_ducked_for_speech(), "and the music comes back")


func test_lines_without_a_recording_are_read_by_the_phone() -> void:
	var fake := _bank()
	var ui := _ui()
	ui.show_line("Dr. Meera Iyer", "A line nobody recorded.", {"voice": "iyer"})
	expect(ui.reading_aloud() and not Speech.recorded(), "read aloud, but not from a recording")
	expect_equal(fake.last().get("text", ""), "A line nobody recorded.", "by the phone's voice")
	fake.voice_list = []
	Speech.use_backend(fake)
	ui.show_line("Dr. Meera Iyer", LINE, {"voice": "iyer"})
	expect(ui.reading_aloud() and Speech.recorded(), "a recorded line plays even on a phone with no voices")
	ui.show_line("Dr. Meera Iyer", "Another line nobody recorded.", {"voice": "iyer"})
	expect(not ui.reading_aloud(), "the rest are murmured, as before")


func test_your_voice_picks_the_lighter_or_deeper_recording() -> void:
	_bank()
	var settings := GameSettings.current
	settings.your_voice = 0
	expect_equal(Speech.recorded_as("you"), "you.lighter")
	expect(VoiceBank.find(Speech.recorded_as("you"), "I'll scrub in.")[0]["stream"] == _clips["lighter"])
	settings.your_voice = 1
	expect(VoiceBank.find(Speech.recorded_as("you"), "I'll scrub in.")[0]["stream"] == _clips["deeper"])
	expect(Speech.say("I'll scrub in.", "you") != 0 and Speech.recorded(), "your reply plays from its recording")
	settings.your_voice = 2
	expect_equal(Speech.say("I'll scrub in.", "you"), 0, "Silent means silent")
	expect_equal(Speech.recorded_as("iyer"), "iyer", "everyone else has one voice")


func test_the_speed_setting_plays_recordings_faster_at_the_same_pitch() -> void:
	_bank()
	GameSettings.current.speech_speed = 2
	var words := [0]
	var done := [false]
	expect(Speech.say(LINE, "iyer", Callable(), func(_end: int) -> void: words[0] += 1,
		func() -> void: done[0] = true) != 0)
	expect(absf(Speech._recorded.pitch_scale - 1.2) < 0.001, "the clip plays faster")
	expect(absf(Speech.recorded_pitch() - 1.0 / 1.2) < 0.001, "the bus puts the pitch back")
	var time := 0.0
	while not done[0] and time < 5.0:
		Speech.tick(STEP)
		time += STEP
	expect_equal(words[0], 5, "every word is reached")
	expect_between(time, 2.0 / 1.2, 2.0 / 1.2 + Speech.RECORDED_SLACK + 0.1, "in less time than at normal speed")
	GameSettings.current.speech_speed = 1
	Speech.say(LINE, "iyer")
	expect_equal(Speech.recorded_pitch(), 1.0, "at normal speed nothing is shifted")


func test_the_game_has_recordings_for_its_story() -> void:
	VoiceBank.reset()
	GameSettings.current = GameSettings.new()
	expect(VoiceBank.has_lines(), "the game ships with recorded voices")
	var total := 0
	var found := 0
	var missing := []
	for line: Dictionary in StoryBook.spoken_lines():
		var who := str(line["who"])
		var text := str(line["text"]).replace("{called}", "Dr. Verma")
		if "{" in text or VoiceBank.normalize(text).is_empty():
			continue  # the player's first name, or a silent "..."
		for as_who: String in (["you.lighter", "you.deeper"] if who == "you" else [who]):
			total += 1
			if not VoiceBank.find(as_who, text).is_empty():
				found += 1
			elif missing.size() < 5:
				missing.append("%s: %s" % [as_who, text])
	expect(total > 700, "the story's lines are all checked (%d)" % total)
	expect_equal(found, total, "every story line has a recording; missing e.g. %s" % [missing])
