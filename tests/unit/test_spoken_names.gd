extends TestCase
## The doctor's own name, said aloud: common names are recorded as "Doctor
## Verma." in each voice that uses the name, and dropped between the words
## before and after it. A name nobody recorded is "Doctor" on screen too,
## so the words shown are always the words heard.

const FakeSpeech := preload("res://tests/unit/fake_speech.gd")
const LINE := "Morning, {called}. Did you read his notes?"

var _settings_before: GameSettings = GameSettings.current
var _backend_before: SpeechBackend = Speech.backend
var _clips := {}


func cleanup() -> void:
	Speech.stop()
	Speech.use_backend(_backend_before)
	VoiceBank.reset()
	super()
	GameSettings.current = _settings_before


func _clip(seconds: float) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 8000
	var data := PackedByteArray()
	data.resize(int(8000 * seconds) * 2)
	wav.data = data
	return wav


func _part(name: String, seconds: float) -> Dictionary:
	_clips[name] = _clip(seconds)
	return {"stream": _clips[name], "length": seconds, "words": [seconds / 2.0, seconds]}


func _bank() -> void:
	GameSettings.current = GameSettings.new()
	Speech.use_backend(FakeSpeech.new())
	_clips["names"] = _clip(6.0)
	VoiceBank.use({
		"lines": [{
			"who": "iyer", "key": VoiceBank.normalize(LINE),
			"parts": [_part("whole", 2.4)],
			"named": [_part("before", 0.7), {"name": "."}, _part("after", 1.3)],
		}],
		"names": {
			"verma": {"stream": _clips["names"], "said": {"iyer": {".": [1.25, 0.8, [0.45, 0.8]]}}},
			"d souza": {"stream": _clips["names"], "said": {"iyer": {".": [3.0, 0.9, [0.5, 0.9]]}}},
		},
	})


func test_a_recorded_name_is_said_between_the_words_around_it() -> void:
	_bank()
	var parts := VoiceBank.find("iyer", "Morning, Dr. Verma. Did you read his notes?")
	expect_equal(parts.size(), 3, "the words before, the name, the words after")
	expect(parts[0]["stream"] == _clips["before"] and parts[2]["stream"] == _clips["after"])
	expect(parts[1]["stream"] == _clips["names"], "the name comes from the name's own file")
	expect_near(float(parts[1]["from"]), 1.25, 0.001, "starting where Dr. Iyer says it")
	expect_near(float(parts[1]["length"]), 0.8, 0.001, "for as long as it lasts")
	expect(not parts[0].has("from") and not parts[2].has("from"), "the other parts are whole clips")
	expect_equal(VoiceBank.find("iyer", "Morning, Dr. D'Souza. Did you read his notes?").size(), 3,
		"a name with an apostrophe is found too")


func test_a_name_nobody_recorded_plays_the_whole_line_with_doctor() -> void:
	_bank()
	for line: String in ["Morning, Dr. Konstantinopolska. Did you read his notes?", "Morning, Doctor. Did you read his notes?"]:
		var parts := VoiceBank.find("iyer", line)
		expect(parts.size() == 1 and parts[0]["stream"] == _clips["whole"], "the whole line: " + line)
	expect(VoiceBank.find("grace", "Morning, Dr. Verma. Did you read his notes?").is_empty(), "only Dr. Iyer says it")


func test_names_are_looked_up_without_titles_or_punctuation() -> void:
	expect_equal(VoiceBank.name_key("Dr. Verma"), "verma")
	expect_equal(VoiceBank.name_key("Dr. D'Souza"), "d souza")
	expect_equal(VoiceBank.name_key("Doctor Meera"), "meera")
	_bank()
	expect(VoiceBank.can_say_name("iyer", "Dr. Verma"))
	expect(not VoiceBank.can_say_name("grace", "Dr. Verma"), "Sister Grace never recorded it")
	expect(not VoiceBank.can_say_name("iyer", "Dr. Patel"), "nor anyone a name not in the list")
	expect(VoiceBank.names_doctor("iyer") and not VoiceBank.names_doctor("tom"))


func test_the_screen_says_what_the_voice_can_say() -> void:
	_bank()
	expect_equal(Speech.address("iyer", "Dr. Verma"), "Dr. Verma", "a recorded name is shown")
	expect_equal(Speech.address("iyer", "Dr. Patel"), "Doctor", "a name the voice can't say is \"Doctor\" on screen")
	expect_equal(Speech.address("tom", "Dr. Patel"), "Dr. Patel",
		"someone with no recorded lines that use the name: the phone's voice reads it")
	expect_equal(Speech.address("you", "Dr. Patel"), "Dr. Patel", "the player's own lines keep it")
	GameSettings.current.voices = 0.0
	expect_equal(Speech.address("iyer", "Dr. Patel"), "Dr. Patel", "with voices off, the name")
	GameSettings.current.voices = 1.0
	Speech.listening = true
	expect_equal(Speech.address("iyer", "Dr. Patel"), "Dr. Patel", "listing lines for recording keeps the name")
	Speech.listening = false


func test_story_lines_fill_in_what_the_speaker_can_say() -> void:
	_bank()
	var profile := PlayerProfile.new()
	profile.name = "Kiran Patel"
	profile.address_form = "last"
	var runner := StoryRunner.new(profile)
	expect_equal(runner.fill(LINE, "iyer"), "Morning, Doctor. Did you read his notes?")
	expect_equal(runner.fill(LINE), "Morning, Dr. Patel. Did you read his notes?", "text nobody says aloud keeps the name")
	profile.name = "Kiran Verma"
	expect_equal(runner.fill(LINE, "iyer"), "Morning, Dr. Verma. Did you read his notes?")


func test_a_stretch_of_a_file_plays_from_its_start_for_its_length() -> void:
	var voice := RecordedVoice.new()
	add_node(voice)
	var names := _clip(6.0)
	voice.play_parts([{"stream": names, "length": 0.8, "words": [], "from": 1.25}], 1.0)
	expect(voice.playing and voice.stream == names)
	expect_near(voice._until, 2.05, 0.001, "it stops where the name ends")
	expect(voice.is_processing(), "and watches for that while it plays")
	voice.halt()
	expect(not voice.is_processing() and voice._until < 0.0)


# --- The game's own recordings -------------------------------------------------

func test_every_line_with_the_name_puts_it_at_a_pause() -> void:
	# The name is dropped in between recordings, so it has to start a
	# sentence or follow a comma, and end with a stop.
	var named := RegEx.create_from_string("(^|[,.?!] )\\{called\\}(\\.\\.\\.|[.!])( |$)")
	var bad := []
	for line: Array in _story_lines():
		var text: String = line[1]
		if "{called}" in text and str(line[0]) != "you" and named.search(text) == null:
			bad.append("%s: %s" % line)
	expect_equal(bad, [], "every spoken line has its name at a pause")


func test_common_names_are_said_in_every_story_line_that_uses_the_name() -> void:
	VoiceBank.reset()
	GameSettings.current = GameSettings.new()
	var missing := []
	var checked := 0
	for line: Array in _story_lines():
		var who: String = line[0]
		var text: String = line[1]
		if who == "you" or not "{called}" in text:
			continue
		for called: String in ["Dr. Sharma", "Dr. Meera", "Dr. D'Souza"]:
			checked += 1
			var parts := VoiceBank.find(who, text.replace("{called}", called))
			if not parts.any(func(part: Dictionary) -> bool: return part.has("from")):
				missing.append("%s: %s" % [who, text.replace("{called}", called)])
	expect(checked > 250, "%d lines checked" % checked)
	expect_equal(missing.slice(0, 5), [], "%d lines say the name" % (checked - missing.size()))


func test_the_name_list_is_recorded() -> void:
	VoiceBank.reset()
	var file := FileAccess.open("res://tools/name_bank.txt", FileAccess.READ)
	expect(file != null, "the list is there")
	if file == null:
		return
	var names := 0
	var missing := []
	while not file.eof_reached():
		var line := file.get_line().split("#")[0].strip_edges()
		if line.is_empty():
			continue
		for spelling in line.split("|")[0].split("/"):
			names += 1
			if not VoiceBank.can_say_name("iyer", spelling.strip_edges()):
				missing.append(spelling.strip_edges())
	expect(names > 600, "%d names" % names)
	expect_equal(missing.slice(0, 10), [], "Dr. Iyer can say every one (%d missing)" % missing.size())
	for test_name in ["Verma", "Asha", "Kiran", "Rao", "Mensah", "Nila"]:
		expect(VoiceBank.can_say_name("grace", test_name), "Sister Grace says %s" % test_name)


func _story_lines() -> Array:
	var found := []
	for file_name in DirAccess.get_files_at("res://story"):
		if not file_name.ends_with(".json") or file_name in ["cast.json", "cases.json", "patients.json", "mistakes.json"]:
			continue
		_walk(JSON.parse_string(FileAccess.get_file_as_string("res://story/" + file_name)), found)
	return found


func _walk(item: Variant, found: Array) -> void:
	if item is Array:
		for step: Variant in item:
			_walk(step, found)
	elif item is Dictionary:
		if item.has("say") and item.has("text") and not str(item["say"]) in ["patient", "relative", "kid"]:
			found.append([str(item["say"]), str(item["text"])])
		for key: String in item:
			if key != "choose":
				_walk(item[key], found)
			else:
				for option: Variant in item[key]:
					if option is Dictionary:
						_walk(option, found)
