extends TestCase
## Lines read aloud: everyone but the player's doctor speaks their typed
## lines with the device's own voices, the text keeps pace with the voice,
## the music dips under it, the settings control it, and the game falls back
## to the murmur where the device can't speak. A fake engine
## (fake_speech.gd) stands in for the phone's voices.

const FakeSpeech := preload("res://tests/unit/fake_speech.gd")
const FOLDER := "user://test_speech"
const PATH := FOLDER + "/settings.json"
const STEP := 1.0 / 30.0

var _settings_before: GameSettings = GameSettings.current
var _save_path_before: String = SettingsPanel.save_path
var _music_before: Music = Music.player
var _backend_before: SpeechBackend = Speech.backend


func _fake() -> FakeSpeech:
	GameSettings.current = GameSettings.new()
	SettingsPanel.save_path = PATH
	var fake := FakeSpeech.new()
	Speech.use_backend(fake)
	# These tests are about the device's voices: no recorded lines.
	VoiceBank.use({})
	return fake


func cleanup() -> void:
	Speech.use_backend(_backend_before)
	VoiceBank.reset()
	super()
	GameSettings.current = _settings_before
	SettingsPanel.save_path = _save_path_before
	Music.player = _music_before
	for file: String in ["settings.json", "settings.json.tmp"]:
		if FileAccess.file_exists(FOLDER + "/" + file):
			DirAccess.remove_absolute(FOLDER + "/" + file)


func _ui() -> ConversationUi:
	var ui := ConversationUi.new()
	add_node(ui)
	return ui


# --- Voices -------------------------------------------------------------------

func test_voices_are_english_clear_and_sorted_by_kind() -> void:
	var pools := Speech.sort_voices(FakeSpeech.VOICES)
	var ids := func(pool: String) -> Array:
		return (pools[pool] as Array).map(func(voice: Dictionary) -> String: return str(voice["id"]))
	var higher: Array = ids.call("higher")
	var lower: Array = ids.call("lower")
	expect(not higher.has("com.apple.speech.synthesis.voice.Albert") and not lower.has("com.apple.speech.synthesis.voice.Albert"),
		"no joke voices")
	expect(not higher.has("com.apple.voice.compact.fr-FR.Thomas"), "English voices only")
	expect_equal(lower[0], "com.apple.voice.compact.en-IN.Rishi", "Indian English first among equals")
	expect_equal(lower[lower.size() - 1], "com.apple.eloquence.en-US.Eddy", "robotic voices only as a last resort")
	expect(higher.has("com.apple.voice.compact.en-US.Samantha") and not lower.has("com.apple.voice.compact.en-US.Samantha"),
		"Samantha speaks higher")
	var better := Speech.sort_voices(FakeSpeech.VOICES + [
		{"name": "Samantha (Enhanced)", "id": "com.apple.voice.enhanced.en-US.Samantha", "language": "en-US"}])
	expect_equal(better["higher"][0]["id"], "com.apple.voice.enhanced.en-US.Samantha", "a downloaded clearer voice wins")
	expect_equal(Speech.kind_of("microsoft zira desktop"), "higher")
	expect_equal(Speech.kind_of("microsoft david desktop"), "lower")
	expect_equal(Speech.kind_of("female"), "higher", "not mistaken for 'male'")
	expect_equal(Speech.kind_of("english"), "unknown")


func test_every_character_has_their_own_voice() -> void:
	_fake()
	var cast := StoryBook.cast()
	var lower_ids: Array = (Speech.pools()["lower"] as Array).map(func(voice: Dictionary) -> String: return str(voice["id"]))
	for id: String in cast:
		var entry: Dictionary = cast[id]
		expect(str(entry.get("gender", "")) in ["female", "male"], "%s has a voice kind" % id)
		var voice := Speech.voice_for(id)
		expect(not voice.is_empty(), "%s has a voice" % id)
		expect_between(float(voice.get("pitch", 0.0)), 0.75, 1.5, "%s's pitch" % id)
		if bool(entry.get("child", false)):
			expect(not lower_ids.has(voice["id"]), "%s, a child, speaks higher" % id)
			expect(float(voice["pitch"]) > 1.1, "%s sounds young" % id)
		elif str(entry["gender"]) == "male":
			expect(lower_ids.has(voice["id"]), "%s speaks lower" % id)
	expect(Speech.voice_for("you").is_empty(), "your doctor has no voice")
	expect(Speech.voice_for("iyer")["id"] != Speech.voice_for("grace")["id"], "Dr. Iyer and Sister Grace differ")
	expect_equal(Speech.voice_for("iyer"), Speech.voice_for("iyer"), "the same voice all game")


func test_what_is_said_matches_what_is_shown() -> void:
	var prepared := Speech.prepare("Dr. Meera Iyer says BP 120/80. That's OUR {x}! ICU · now")
	expect_equal(prepared["spoken"], "Doctor Meera Iyer says BP 120 over 80. That's our {x}! ICU , now")
	var map: PackedInt32Array = prepared["map"]
	expect_equal(map.size(), str(prepared["spoken"]).length(), "every spoken letter points at a shown one")
	for index in range(1, map.size()):
		expect(map[index] >= map[index - 1], "in order")
	expect_equal(Speech.prepare("Mrs. Banerjee")["spoken"], "Missus Banerjee")
	expect_equal(Speech.prepare("DIABETIC? Mummy!")["spoken"], "diabetic? Mummy!", "shouting is said as a word")


# --- Conversations ------------------------------------------------------------

func test_a_line_is_said_aloud_and_the_text_keeps_pace() -> void:
	var fake := _fake()
	var ui := _ui()
	var line := "Good. Sleep is for people who aren't on call, Dr. Verma."
	ui.show_line("Dr. Meera Iyer", line, {"voice": "iyer"})
	expect(ui.reading_aloud(), "the line is read aloud")
	expect_equal(fake.last()["text"], Speech.prepare(line)["spoken"])
	expect_equal(fake.last()["voice"], Speech.voice_for("iyer")["id"], "in Dr. Iyer's voice")
	var time := 0.0
	var ahead := 0
	while ui.is_typing() and time < 20.0:
		ui.tick(STEP)
		time += STEP
		if fake.is_speaking():
			# Never more than the word being said is on show.
			var spoken_at := mini(int(fake.reached()), Speech.prepare(line)["map"].size() - 1)
			var said_upto: int = Speech.prepare(line)["map"][maxi(0, spoken_at)]
			var next_space := line.find(" ", said_upto + 1)
			var allowed := line.length() if next_space < 0 else next_space
			ahead = maxi(ahead, ui._text.visible_characters - allowed)
	expect_equal(ahead, 0, "the text never runs ahead of the voice")
	expect(not fake.is_speaking(), "the typing ends when the voice does")
	expect_between(time, line.length() / fake.pace * 0.8, line.length() / fake.pace * 1.6 + 1.0,
		"at speaking pace, not the old typing speed")
	expect_equal(ui._text.visible_characters, line.length(), "the whole line shows")


func test_a_tap_shows_the_line_and_the_next_line_cuts_in() -> void:
	var fake := _fake()
	var ui := _ui()
	var moved := [0]
	ui.advanced.connect(func() -> void: moved[0] += 1)
	ui.show_line("Sister Grace Mathew", "Morning. Handover. Pen out, and coffee down.", {"voice": "grace"})
	for frame in 10:
		ui.tick(STEP)
	ui.tap()
	expect(not ui.is_typing(), "a tap shows the whole line")
	expect(fake.is_speaking(), "and she carries on saying it")
	ui.tap()
	expect_equal(moved[0], 1, "the next tap moves on")
	ui.show_line("Dr. Meera Iyer", "Next.", {"voice": "iyer"})
	expect_equal(fake.spoken.size(), 2)
	expect_equal(fake.last()["voice"], Speech.voice_for("iyer")["id"], "the new speaker cuts in")
	ui.close()
	expect(not fake.is_speaking() and not Speech.speaking(), "closing stops the voice")


func test_without_voices_lines_are_murmured_as_before() -> void:
	GameSettings.current = GameSettings.new()
	Speech.use_backend(SpeechBackend.new())
	VoiceBank.use({})
	var ui := _ui()
	ui.show_line("Dr. Meera Iyer", "A line of about forty-six letters, give or take.", {"voice": "iyer"})
	expect(not ui.reading_aloud(), "a headless run has no voices")
	for frame in 45:
		ui.tick(STEP)
	expect(not ui.is_typing(), "typed at the old speed")
	var fake := _fake()
	GameSettings.current.read_aloud = false
	ui.show_line("Dr. Meera Iyer", "Read aloud is off.", {"voice": "iyer"})
	expect(not ui.reading_aloud() and fake.spoken.is_empty(), "the setting turns voices off")
	GameSettings.current.read_aloud = true
	fake.mute = true
	ui.show_line("Dr. Meera Iyer", "A voice that never starts.", {"voice": "iyer"})
	expect(ui.reading_aloud(), "it was asked to read")
	for frame in int((SpokenLine.START_TIMEOUT + 1.5) / STEP):
		ui.tick(STEP)
	expect(not ui.is_typing(), "the line still appears in full when the voice never starts")


func test_text_never_stalls_without_word_marks() -> void:
	var fake := _fake()
	fake.marks = false
	var ui := _ui()
	var line := "Some voices never say which word they are on."
	ui.show_line("Dr. Meera Iyer", line, {"voice": "iyer"})
	for frame in int(1.6 / STEP):
		ui.tick(STEP)
	expect(ui._text.visible_characters > 0, "the text creeps on with the voice")
	var time := 1.6
	while ui.is_typing() and time < 15.0:
		ui.tick(STEP)
		time += STEP
	expect(not ui.is_typing(), "and finishes when the voice does")


func test_everyone_in_a_conversation_speaks_but_you_stay_silent() -> void:
	var fake := _fake()
	var profile := PlayerProfile.new()
	profile.name = "Kiran Rao"
	profile.address_form = "first"
	profile.opening_seen = true
	profile.set_flag("met_iyer")
	var lobby := Lobby.new(profile, false)
	add_node(lobby)
	lobby._start_talk("grace")
	var replies := 0
	for frame in 6000:
		if not lobby.story.is_playing():
			break
		if lobby.talk_ui.is_choosing():
			var before := fake.spoken.size()
			lobby.story.choose(0)
			replies += 1
			expect(fake.spoken.size() == before or fake.last()["voice"] == Speech.voice_for("grace")["id"],
				"choosing a reply says nothing aloud for you")
		elif not lobby.story.is_busy() and not lobby.talk_ui.is_typing() and not fake.is_speaking():
			lobby.talk_ui.tap()
		lobby._process(STEP)
	expect(not lobby.story.is_playing(), "the conversation ended")
	expect(replies > 0, "you replied")
	var voices := {}
	for line: Dictionary in fake.spoken:
		voices[line["voice"]] = true
	expect(voices.has(Speech.voice_for("grace")["id"]), "Sister Grace speaks")
	var said_by_grace := 0
	var yours := {}
	for event: Array in lobby.story.runner.history:
		if event[0] == "grace":
			said_by_grace += 1
		elif event[0] == "you":
			yours[event[1]] = true
	expect(fake.spoken.size() >= said_by_grace, "every one of her lines was said aloud")
	for line: Dictionary in fake.spoken:
		expect(not yours.has(line["text"]), "none of yours: " + str(line["text"]))
	expect(lobby.player.get_node_or_null("Voice") == null, "your doctor doesn't even murmur")


func test_the_music_dips_while_someone_speaks() -> void:
	var fake := _fake()
	var music := Music.new()
	add_node(music)
	Music.player = music
	Music.cue("hospital")
	var ui := _ui()
	ui.show_line("Dr. Meera Iyer", "Listen.", {"voice": "iyer"})
	ui.tick(STEP)
	expect(music.is_ducked_for_speech(), "the music dips under the voice")
	for frame in 60:
		ui.tick(STEP)
	expect(not fake.is_speaking(), "the line is over")
	expect(not music.is_ducked_for_speech(), "and the music comes back")


# --- Settings -----------------------------------------------------------------

func test_speech_settings_are_kept_and_reach_the_voice() -> void:
	var fake := _fake()
	var settings := GameSettings.current
	expect(settings.read_aloud, "lines are read aloud from the start")
	expect_equal(settings.speech_speed, 1, "at normal speed")
	settings.read_aloud = false
	settings.speech_speed = 2
	expect_equal(settings.save_to(PATH), OK)
	expect_equal(GameSettings.load_from(PATH).to_dict(), settings.to_dict(), "they survive a restart")
	var old := GameSettings.from_dict({"music": 0.5, "your_voice": 1})
	expect(old.read_aloud and old.speech_speed == 1, "an older settings file gets the defaults")
	expect(not old.to_dict().has("your_voice"), "and its old voice choice for your doctor is dropped")
	var broken := GameSettings.from_dict({"speech_speed": 9, "read_aloud": "yes"})
	expect(broken.speech_speed == 2 and broken.read_aloud, "bad values are repaired")
	settings.read_aloud = true
	settings.speech_speed = 0
	Speech.say("Slow.", "iyer")
	var slow := float(fake.last()["rate"])
	settings.speech_speed = 2
	Speech.say("Fast.", "iyer")
	expect(float(fake.last()["rate"]) > slow * 1.3, "speech speed changes how fast they talk")
	settings.voices = 0.4
	Speech.say("Quiet.", "iyer")
	expect_equal(int(fake.last()["volume"]), 50, "the Voices volume sets how loud")
	expect(not Speech.speaks("you") and Speech.speaks("iyer"), "only the other characters are voiced")


func test_the_settings_screen_has_speech_choices() -> void:
	var fake := _fake()
	var panel := SettingsPanel.new()
	add_node(panel)
	expect(panel.choice_rows.has("read_aloud"), "a read aloud row")
	expect(not panel.choice_rows.has("your_voice"), "and no voice for your own doctor")
	expect_equal((panel.choice_rows["read_aloud"] as Array).size(), 4, "off, slower, normal, faster")
	panel.pick("read_aloud", 1)
	expect(GameSettings.current.read_aloud, "still reading aloud")
	expect_equal(GameSettings.current.speech_speed, 0, "but slower")
	expect(fake.spoken.size() > 0, "you hear the new speed at once")
	expect(str(fake.last()["voice"]) == str(Speech.voice_for("iyer")["id"]), "in someone else's voice")
	panel.pick("read_aloud", 0)
	expect(not GameSettings.current.read_aloud and not Speech.speaking(), "turning it off stops the voice")


func test_the_character_creator_has_no_voice_choice() -> void:
	var fake := _fake()
	var creator := AvatarCreator.new()
	add_node(creator)
	for tab: String in AvatarCreator.TABS:
		creator.show_tab(tab)
		expect(creator.find_child("Voice", true, false) == null, "no voice choice on the %s tab" % tab)
		for button in creator.find_children("*", "Button", true, false):
			expect((button as Button).text not in ["Lighter", "Deeper", "Silent"], "no voice chips on " + tab)
	expect(fake.spoken.is_empty(), "and the doctor never says hello")


# --- Training and operations --------------------------------------------------

func test_coach_lines_are_said_by_whoever_says_them() -> void:
	var fake := _fake()
	var lab := SkillsLab.new(_lab_profile())
	add_node(lab)
	lab.settle_camera()
	lab.go_to_task("history")
	var view := lab.view as HistoryView
	expect(view != null, "the history station is open")
	if view == null:
		return
	expect_equal(view.voice_id(), (view.task as HistoryTask).actor, "the patient answers in their own voice")
	view.ask("onset")
	for frame in 5:
		lab.update(STEP)
	expect(view.coach_voice().speaking or fake.spoken.size() > 0, "the answer is said aloud")
	expect_equal(fake.last()["voice"], Speech.voice_for(view.voice_id())["id"])


func _lab_profile() -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.name = "Kiran Rao"
	profile.address_form = "first"
	profile.opening_seen = true
	profile.day = 2
	for flag in ["met_iyer", "day1_grace", "day1_patient", "day1_iyer", "lab_welcome"]:
		profile.set_flag(flag)
	return profile


# --- Music in the story ---------------------------------------------------------

func test_story_music_names_real_tracks() -> void:
	var found := {}
	for chapter_name: String in StoryBook.chapter_names():
		var chapter := StoryBook.chapter(chapter_name)
		for id: String in chapter:
			_collect_music(chapter[id], found)
	for track: String in found:
		expect(track in Music.TRACKS, "%s is a track" % track)
	expect(found.has("sad"), "sad moments have sad music")
	var beats: Array = []
	for day: int in Ward.DAYS:
		beats += Ward.DAYS[day]
	for day: int in WardStory.DAYS:
		beats += WardStory.DAYS[day]
	var emergencies := 0
	for entry: Dictionary in beats:
		if entry.has("music"):
			expect(str(entry["music"]) in Music.TRACKS, "beat %s's music" % entry.get("id", ""))
			emergencies += 1
	expect(emergencies >= 2, "the crash calls have urgent music")
	for track: String in ["emergency", "sad"]:
		var stream := Music.stream(track) as AudioStreamOggVorbis
		expect(stream != null and stream.loop, "%s loops" % track)
	for track: String in Music.TRACKS:
		var stream := Music.stream(track)
		expect(stream != null and stream.get_length() > 45.0, "%s is long enough not to tire the ear" % track)


func _collect_music(steps: Variant, found: Dictionary) -> void:
	if typeof(steps) != TYPE_ARRAY:
		return
	for step: Variant in steps:
		if typeof(step) != TYPE_DICTIONARY:
			continue
		var entry := step as Dictionary
		if str(entry.get("do", "")) == "music":
			found[str(entry.get("track", ""))] = true
		for key: String in ["then", "else"]:
			_collect_music(entry.get(key), found)
		for option: Variant in entry.get("choose", []):
			if typeof(option) == TYPE_DICTIONARY:
				_collect_music((option as Dictionary).get("then"), found)


func test_a_failed_operation_brings_sad_music_until_the_talk_ends() -> void:
	_fake()
	var music := Music.new()
	add_node(music)
	Music.player = music
	Music.cue("hospital")
	var profile := PlayerProfile.new()
	profile.name = "Kiran Rao"
	profile.address_form = "first"
	profile.opening_seen = true
	profile.set_flag("met_iyer")
	var lobby := Lobby.new(profile, false)
	add_node(lobby)
	lobby.story.play([{"do": "music", "track": "sad"}, {"say": "grace", "text": "I'm sorry."}])
	expect_equal(music.track, "sad", "the music turns sad")
	for frame in 400:
		if not lobby.story.is_playing():
			break
		if not lobby.talk_ui.is_typing():
			lobby.talk_ui.tap()
		lobby._process(STEP)
	expect(not lobby.story.is_playing(), "the talk ended")
	expect_equal(music.track, "hospital", "and the ward's own music comes back")
