extends TestCase
## The story engine: lines, replies, trust and flags, and the story files
## themselves.


func _runner(profile: PlayerProfile = null) -> StoryRunner:
	var player := profile
	if player == null:
		player = PlayerProfile.new()
		player.name = "Asha Verma"
		player.address_form = "last"
	return StoryRunner.new(player)


func test_lines_fill_in_the_players_name() -> void:
	var runner := _runner()
	runner.start([
		{"say": "iyer", "text": "{called}, you're late.", "mood": "focused", "gesture": "fold_arms"},
		{"say": "you", "text": "I'm {title}. {first} for short."},
	])
	var first := runner.next()
	expect_equal(first["type"], "line")
	expect_equal(first["text"], "Dr. Verma, you're late.")
	expect_equal(first["name"], "Dr. Meera Iyer")
	expect_equal(first["mood"], StoryRunner.mood_index("focused"))
	expect_equal(first["gesture"], "fold_arms")
	var second := runner.next()
	expect_equal(second["text"], "I'm Dr. Asha Verma. Asha for short.")
	expect_equal(second["name"], "Dr. Asha Verma")
	expect_equal(runner.next()["type"], "end")
	expect(runner.is_finished())
	expect_equal(runner.history.size(), 2, "every line is remembered")


func test_a_reply_changes_trust_sets_flags_and_runs_its_follow_up() -> void:
	var runner := _runner()
	runner.start([
		{"say": "grace", "text": "Rule one: wash your hands."},
		{"choose": [
			{"tone": "Warm", "text": "Yes, Sister.", "trust": {"grace": 5}, "flag": "warm_to_grace",
				"then": [{"say": "grace", "text": "Good."}]},
			{"tone": "Brisk", "text": "Fine.", "trust": {"grace": -2}},
		]},
		{"say": "grace", "text": "Off you go."},
	])
	runner.next()
	var choice := runner.next()
	expect_equal(choice["type"], "choice")
	expect_equal(choice["about"], "grace", "the reply is about the last person with a trust meter")
	expect_equal((choice["options"] as Array).size(), 2)
	expect(runner.waiting_for_choice())
	var result := runner.choose(0)
	expect_equal(result["said"], "Yes, Sister.")
	expect_equal(result["trust"]["grace"], [5, 50], "45 + 5")
	expect_equal(runner.profile.trust("grace"), 50)
	expect(runner.profile.has_flag("warm_to_grace"))
	var said := runner.next()
	expect_equal([said["speaker"], said["text"]], ["you", "Yes, Sister."], "the player says the reply first")
	expect_equal(runner.next()["text"], "Good.", "then its follow-up runs")
	expect_equal(runner.next()["text"], "Off you go.", "then the conversation carries on")


func test_trust_stays_between_0_and_100() -> void:
	var runner := _runner()
	runner.start([{"trust": {"iyer": 500}}, {"trust": {"grace": -500}}])
	runner.next()
	expect_equal(runner.profile.trust("iyer"), 100)
	expect_equal(runner.profile.trust("grace"), 0)


func test_branches_follow_flags() -> void:
	var runner := _runner()
	runner.profile.set_flag("asked_nair_wait")
	runner.start([
		{"if": "asked_nair_wait", "then": [{"say": "iyer", "text": "You asked. Good."}], "else": [{"say": "iyer", "text": "You didn't ask."}]},
		{"if": "!corrected_iyer", "then": [{"say": "iyer", "text": "And you were polite."}]},
		{"flag": "x", "xp": 10, "minutes": 15},
		{"end": true},
		{"say": "iyer", "text": "Never said."},
	])
	expect_equal(runner.next()["text"], "You asked. Good.")
	expect_equal(runner.next()["text"], "And you were polite.")
	expect_equal(runner.next()["type"], "end", "end stops the conversation")
	expect(runner.profile.has_flag("x"))
	expect_equal(runner.profile.total_xp, 10)
	expect_equal(runner.profile.clock_text(), "07:15")


func test_actions_are_handed_to_the_scene() -> void:
	var runner := _runner()
	runner.start([{"do": "walk", "who": "you", "to": "podium"}])
	var event := runner.next()
	expect_equal(event["type"], "action")
	expect_equal(event["step"]["to"], "podium")


func test_validation_catches_mistakes() -> void:
	var cast := StoryBook.cast()
	var actions := ["walk"]
	var problems := StoryRunner.validate([
		{"say": "ghost", "text": "Boo"},
		{"say": "iyer", "text": ""},
		{"say": "iyer", "text": "Hi", "gesture": "dab"},
		{"choose": [{"tone": "Only one", "text": "x"}]},
		{"choose": [{"tone": "A", "text": "a", "trust": {"aarav": 3}}, {"tone": "B", "text": "b", "colour": "red"}]},
		{"do": "teleport"},
		{"do": "walk", "who": "nobody"},
		{"mystery": 1},
	], cast, actions, "test")
	var text := "\n".join(problems)
	for expected in ["unknown speaker ghost", "a line needs text", "unknown gesture dab", "two to four replies",
			"aarav has no trust meter", "unknown key colour", "unknown action teleport", "unknown actor nobody",
			"unknown key mystery"]:
		expect(text.contains(expected), "reports: %s" % expected)


func test_every_story_file_is_valid() -> void:
	var cast := StoryBook.cast()
	expect(cast.has("iyer") and cast.has("grace"), "the cast loads")
	var actions: Array = Opening.ACTIONS + Lobby.ACTIONS + StoryPlayer.GENERIC
	var names := StoryBook.chapter_names()
	for expected in ["banter", "day1", "opening"]:
		expect(names.has(expected), "chapter %s exists" % expected)
	for chapter_name in names:
		if chapter_name == "banter":
			continue
		var chapter := StoryBook.chapter(chapter_name)
		expect(not chapter.is_empty(), "%s has conversations" % chapter_name)
		for id: String in chapter:
			var problems := StoryRunner.validate(chapter[id], cast, actions, "%s.%s" % [chapter_name, id])
			expect(problems.is_empty(), "\n".join(problems))


func test_banter_names_real_people_and_gestures() -> void:
	var cast := StoryBook.cast()
	var sets: Array = StoryBook.chapter("banter").get("lobby", [])
	expect(sets.size() >= 2, "at least two groups chatting")
	for entry: Dictionary in sets:
		var pair: Array = entry.get("between", [])
		expect_equal(pair.size(), 2, "banter is between two people")
		var lines: Array = entry.get("lines", [])
		expect(lines.size() >= 2, "a back-and-forth")
		for line: Array in lines:
			expect(pair.has(line[0]), "%s is one of the pair" % line[0])
			expect(cast.has(str(line[0])), "%s is in the cast" % line[0])
			expect(not str(line[1]).is_empty(), "a line has words")
			if line.size() > 2:
				expect(AvatarRig.GESTURES.has(str(line[2])), "gesture %s exists" % line[2])


func test_no_story_line_uses_the_developers_name() -> void:
	for chapter_name in StoryBook.chapter_names():
		var text := JSON.stringify(StoryBook.chapter(chapter_name)).to_lower()
		expect(not text.contains("harshal"), "%s keeps real names out" % chapter_name)


func test_voices_and_sounds_are_made_in_code() -> void:
	for letter in ["a", "e", "i", "o", "u", "x"]:
		var stream := Voice.syllable(letter)
		expect(stream != null and stream.data.size() > 1000, "a murmur for %s" % letter)
	expect(Voice.syllable("a") == Voice.syllable("a"), "murmurs are cached")
	for sound: String in Sfx.NAMES:
		var stream := Sfx.stream(sound)
		expect(stream != null and stream.data.size() > 1000, "%s has sound" % sound)


func test_sound_off_plays_nothing() -> void:
	var holder := add_node(Node.new())
	Voice.enabled = false
	expect(Sfx.play(holder, "knock") == null, "no sound effects when sound is off")
	var rig := AvatarRig.new()
	holder.add_child(rig)
	rig.say_syllable("a")
	expect(rig.get_node_or_null("Voice") == null, "no voice either")
	Voice.enabled = true
	expect(Sfx.play(holder, "knock") != null, "sound comes back on")
