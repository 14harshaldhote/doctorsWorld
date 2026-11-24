extends TestCase
## Life outside the wards (stage 27): the evenings after a day on Ward 4
## (chai, the radio, the hostel, a call home, food, bed), how bedtime turns
## into steady or shaking hands, Mum turning up when nobody calls, the
## parties with their games and the pager, and how it all reaches the
## morning, the phone and theatre.

const STEP := 1.0 / 30.0


func cleanup() -> void:
	if SongPlayer.active != null and is_instance_valid(SongPlayer.active):
		SongPlayer.active.stop()
	SongPlayer.active = null
	Music.hold_for_song(false)
	PhoneBook.forget()
	super()


func _profile(day: int) -> PlayerProfile:
	var doctor := PlayerProfile.new()
	doctor.name = "Asha Verma"
	doctor.day = day
	doctor.opening_seen = true
	doctor.created = true
	doctor.total_xp = 800
	doctor.set_count("hospital_seed", 4242)
	for flag: String in ["op_rohit_done", "op_rohit_won"]:
		doctor.set_flag(flag)
	return doctor


## The evening after a finished day (the profile already on the next morning,
## as Main leaves it).
func _evening(finished: int, doctor: PlayerProfile = null) -> Evening:
	var profile := doctor if doctor != null else _profile(finished + 1)
	profile.day = finished + 1
	return add_node(Evening.new(profile, finished, 18 * 60 + 40)) as Evening


func _frames(evening: Evening, seconds: float) -> void:
	for frame in int(seconds / STEP):
		evening.update(STEP)


func _back_to_menu(evening: Evening) -> bool:
	return evening.play_until(func() -> bool: return evening.phase == "menu" or evening.is_done(), 0, 0.8, 400.0)


# --- The rules ---------------------------------------------------------------------

func test_the_evenings_book_hangs_together() -> void:
	expect("life" not in StoryBook.chapter_names(), "the rules aren't a chapter of conversations")
	expect("evenings" in StoryBook.chapter_names(), "the evenings' conversations are")
	for who: String in Life.rule("chai", {}):
		expect(CastLooks.has(who), "%s has a look for the canteen" % who)
		for key: String in Life.rule("chai", {})[who]:
			expect(not StoryBook.conversation("evenings", key).is_empty(), "the chat %s is written" % key)
	for chapter: String in Life.rule("staff", {}):
		for who: String in Life.rule("staff", {})[chapter]:
			expect((Life.rule("chai", {}) as Dictionary).has(who), "%s on late in %s has chats" % [who, chapter])
	for who: String in Life.rule("tips", {}):
		expect(who in Life.TIPPERS, "%s's tips can be remembered overnight" % who)
		var tips: Array = Life.rule("tips", {})[who]
		expect(tips.size() <= 10, "a tipper has at most ten tips (the morning code)")
		for tip: Dictionary in tips:
			expect(str(tip.get("for", "")) in ["ward", "theatre", "night", "review", "meeting", "any"], "a tip's day")
			expect(str((tip["line"] as Dictionary).get("say", "")) == who, "%s says their own tip" % who)
			expect(not str(tip.get("short", "")).is_empty(), "and it has a short form for the morning")
	for call: Dictionary in Life.rule("calls", []):
		expect(not StoryBook.conversation("evenings", str(call["id"])).is_empty(), "the call %s is written" % call["id"])
	expect(not StoryBook.conversation("evenings", "lf_mum_visit").is_empty(), "Mum's visit is written")
	for id: String in Life.parties():
		var party := Life.party(id)
		expect(not StoryBook.conversation("evenings", str(party["talk"])).is_empty(), "%s's conversation" % id)
		expect(str(party["where"]) in EveningSet.PLACES, "%s is somewhere the evening can build" % id)
		expect(str(party["game"]) in ["carrom", "antakshari", "dance", "speech"], "%s has a game" % id)
		for who: String in party.get("guests", []):
			expect(CastLooks.has(who), "%s at %s has a look" % [who, id])
		if party.has("against"):
			expect(CastLooks.has(str(party["against"])), "%s's rival has a look" % id)
		if str(party["game"]) == "speech":
			expect((Life.rule("speeches", {}) as Dictionary).has(str(party["speech"])), "%s's speech is written" % id)
		if party.has("left"):
			expect((Life.rule("left_cards", {}) as Dictionary).has(str(party["left"])), "leaving %s has a card" % id)
			expect((Life.rule("pages", {}) as Dictionary).has(str(party["talk"])), "and a page")
	var titles: Array = (Life.rule("antakshari", {}) as Dictionary).get("titles", [])
	expect(titles.size() >= 40, "plenty of made-up songs")
	var unique := {}
	for song: String in titles:
		unique[song] = true
	expect_equal(unique.size(), titles.size(), "no song twice")
	expect(StoryBook.cast().has("varun") and not StoryBook.cast()["varun"].has("trust"), "Varun is in the cast, with no trust meter")


func test_which_days_have_an_evening() -> void:
	for day in [1, 2, 3, 6, 16]:
		expect(not Life.has_evening(day), "no evening after Day %d" % day)
	for day in [4, 5, 7, 15, 17, 30]:
		expect(Life.has_evening(day), "an evening after Day %d" % day)
	var profile := _profile(6)
	expect(not Life.evening_due(profile, 5), "a day closed before evenings existed is owed none")
	Life.day_closed(profile, 5, 18 * 60)
	expect(Life.evening_due(profile, 5), "the evening after Day 5 is still to come")
	expect_equal(Life.start_minutes(profile.count(Life.LEFT)), 19 * 60, "from seven")
	Life.day_closed(profile, 6, 20 * 60)
	expect(not Life.evening_due(profile, 6), "a night shift has no evening")
	expect(Life.evening_due(profile, 5), "and doesn't take Day 5's away")
	Life.go_to_bed(profile, 5, 23 * 60, true)
	expect(not Life.evening_due(profile, 5), "and once it's had, never again")


func test_bedtime_decides_the_sleep_and_the_hands() -> void:
	expect_near(Life.sleep_hours(23 * 60 + 30, true), 7.0, 0.01, "23:30 to 06:30")
	expect_near(Life.sleep_hours(23 * 60 + 30, false), 6.5, 0.01, "hungry costs half an hour")
	expect_near(Life.sleep_hours(24 * 60 + 90, true), 5.0, 0.01, "01:30 is five hours")
	var profile := _profile(8)
	expect_near(Life.slept(profile), -1.0, 0.01, "no evening, no sleep to speak of")
	expect_near(Life.tremor(profile), 0.0, 0.001, "and steady hands")
	Life.go_to_bed(profile, 7, 22 * 60, true)
	expect_near(Life.tremor(profile), 0.0, 0.001, "eight and a half hours: steady")
	Life.go_to_bed(profile, 7, 24 * 60 + 150, false)
	expect_near(Life.slept(profile), 3.5, 0.01, "02:30, hungry: three and a half")
	expect_near(Life.tremor(profile), 1.0, 0.001, "shaking")
	Life.go_to_bed(profile, 7, 24 * 60 + 60, true)
	expect_between(Life.tremor(profile), 0.3, 0.5, "01:00: a little shaky")
	profile.day = 9
	expect_near(Life.slept(profile), -1.0, 0.01, "last night's sleep is for this morning only")
	var lines := Life.morning(_with_bed(8, 24 * 60 + 60))
	expect(not lines.is_empty() and lines[0].begins_with("Slept 5 h 30 min."), "the morning says how it went: %s" % [lines])


func _with_bed(day: int, bed: int) -> PlayerProfile:
	var profile := _profile(day)
	Life.go_to_bed(profile, day - 1, bed, true)
	return profile


func test_a_tired_hand_shakes_in_theatre_the_same_way_every_time() -> void:
	var steady := OperationTask.new(5, {})
	expect_equal(steady.shaken(Vector2(3, 4)), Vector2(3, 4), "after a good night, exactly where aimed")
	var tired := OperationTask.new(5, {})
	tired.tremor = 1.0
	var again := OperationTask.new(5, {})
	again.tremor = 1.0
	var worst := 0.0
	for index in 30:
		var spot := Vector2(10, 7)
		var a := tired.shaken(spot)
		expect_equal(a, again.shaken(spot), "the same shake every time")
		worst = maxf(worst, a.distance_to(spot))
	expect_between(worst, 0.3, OperationTask.TREMOR_REACH + 0.001, "off by up to half a unit")


# --- Home and Mum ----------------------------------------------------------------------

func test_mum_counts_the_days_and_comes_herself() -> void:
	var profile := _profile(5)
	expect_equal(Life.days_without_home(profile, 12), 0, "before any evening, nobody's counting")
	Life.go_to_bed(profile, 4, 22 * 60, true)
	profile.day = 8
	expect_equal(Life.days_without_home(profile, 8), 4, "four days since the first evening")
	expect(not Life.mum_due(profile), "not yet")
	var lines := Life.morning(profile)
	expect_equal(profile.count(Life.NAG + "8"), 4, "Mum texts that morning")
	PhoneBook.forget()
	var texts := PhoneWriter.items(profile).filter(func(item: Dictionary) -> bool: return str(item["id"]).begins_with(Life.NAG))
	expect(not texts.is_empty() and str(texts[texts.size() - 1]["text"]).begins_with("Okay. I'm coming."),
		"and the phone has it: %s" % [texts.map(func(item: Dictionary) -> String: return item["text"])])
	for day in [6, 7, 9]:
		profile.set_count(Life.NAG + str(day), mini(day - 4, 4))
	profile.day = 9
	PhoneBook.forget()
	var said := PhoneWriter.items(profile).filter(func(item: Dictionary) -> bool:
		return str(item["id"]).begins_with(Life.NAG)).map(func(item: Dictionary) -> String: return item["text"])
	expect_equal(said.size(), 3, "Mum escalates, one message a day, and never sends the same one twice: %s" % [said])
	expect(Life.mum_due(profile), "five days: Mum is on her way")
	Life.mum_came(profile)
	expect(not Life.mum_due(profile), "seeing her counts")
	expect(Life.mum_came_since_call(profile), "and the next call is about her visit")
	expect_equal(str(Life.call_for(profile, 9).get("id", "")), "vc_after_visit", "Anu wants to know everything")
	Life.called_home(profile, 9)
	expect(not Life.mum_came_since_call(profile), "after the call, that's old news")
	profile.day = 12
	expect_equal(Life.days_without_home(profile, 12), 3, "counting from the call")
	expect(lines.is_empty(), "no sleep or tip to report without an evening before")


func test_the_calls_home_take_turns_and_answer_the_day() -> void:
	var profile := _profile(6)
	Life.go_to_bed(profile, 4, 22 * 60, true)
	expect_equal(str(Life.call_for(profile, 5).get("id", "")), "vc_first", "the first call is the first call")
	Life.called_home(profile, 5)
	var seen := {}
	for index in 6:
		var call := Life.call_for(profile, 6 + index)
		seen[str(call["id"])] = true
		Life.called_home(profile, 6 + index)
	expect(seen.size() >= 4, "the ordinary calls take turns: %s" % [seen.keys()])
	profile.wall.append({"day": 13, "name": "Someone"})
	expect_equal(str(Life.call_for(profile, 13).get("id", "")), "vc_loss", "a patient lost today: Mum just listens")


# --- The canteen ---------------------------------------------------------------------

func test_two_colleagues_on_late_and_a_tip_for_the_morning() -> void:
	var profile := _profile(5)
	var staff := Life.staff_tonight(profile, 5)
	expect_equal(staff.size(), 2, "two colleagues tonight")
	expect(staff[0] != staff[1], "two different ones")
	expect_equal(staff, Life.staff_tonight(profile, 5), "the same two, however often it's asked")
	var pool: Array = (Life.rule("staff", {}) as Dictionary)["ward"]
	expect(staff.all(func(who: String) -> bool: return who in pool), "from the ward's people")
	for day in range(4, 30):
		if "zoya" in Life.staff_tonight(profile, day):
			expect(day >= 14, "Zoya isn't around before she's the intern (Day %d)" % day)
	expect_equal(Life.chai_talk(profile, "priya"), "ch_priya_1", "Priya's first chat")
	Life.had_chai(profile, "priya", 5)
	expect_equal(Life.chai_talk(profile, "priya"), "ch_priya_2", "then her second")
	expect_equal(Life.morning_tip(profile), "", "the tip is for tomorrow")
	expect(Life.morning_tip(_profile(6)).is_empty(), "nobody else's")
	profile.day = 6
	var tip := Life.morning_tip(profile)
	expect(tip.begins_with("Priya's tip: "), "this morning, Priya's tip: %s" % tip)
	expect(Life.short_name("iyer") == "Dr. Iyer" and Life.short_name("grace") == "Sister Grace", "names as the doctor says them")


# --- Parties ---------------------------------------------------------------------------

func test_the_parties_fall_on_their_evenings() -> void:
	var profile := _profile(4)
	var expected := {7: "hostel_night", 10: "diwali", 17: "grace_birthday", 23: "rao_farewell", 31: "carrom_night",
		38: "antakshari_night", 45: "sangeet_night", 52: "carrom_night"}
	for day: int in expected:
		expect_equal(Life.party_on(profile, day), expected[day], "Day %d" % day)
	for day in [4, 5, 8, 9, 11, 24, 30, 32]:
		expect_equal(Life.party_on(profile, day), "", "no party after Day %d" % day)
	expect_equal(Life.party_on(profile, 6), "", "never on a night shift")


func test_dr_khans_reception_follows_her_ask_and_her_message_follows_the_reception() -> void:
	var profile := _profile(12)
	profile.set_count(Lives.PREFIX + "khan_wedding", 12)
	expect_equal(Life.reception_day(profile, "khan_wedding"), 13, "the evening after she asked")
	expect_equal(Life.party_on(profile, 13), "khan_reception", "is her reception")
	expect(Lives.payoff_day(profile, "khan_wedding") >= 14, "her thank-you comes after it")
	profile.set_count(Lives.PREFIX + "khan_wedding", 15)
	expect_equal(Life.reception_day(profile, "khan_wedding"), 18, "not on the night shift or Grace's birthday")
	expect(Lives.payoff_day(profile, "khan_wedding") >= 19, "and the message waits for it")
	profile.set_flag("pt_khan_stayed")
	profile.set_flag("pt_khan_won")
	expect(Lives.payoff_text(profile, "khan_wedding").contains("left the family group"), "she remembers the dance-off")
	profile.set_flag("pt_khan_stayed", false)
	profile.set_flag("pt_khan_left")
	expect(Lives.payoff_text(profile, "khan_wedding").contains("two plates of biryani"), "and leaving for the page")


func test_going_or_skipping_a_party_is_noticed() -> void:
	var profile := _profile(11)
	var before := profile.trust("grace", 45)
	var xp := profile.total_xp
	expect_equal(Life.went(profile, "diwali", 10), int(Life.party("diwali")["bed"]), "bed when the party ends")
	expect(profile.trust("grace", 45) > before, "Grace liked that you came")
	expect_equal(profile.total_xp, xp + int(Life.party("diwali")["xp"]), "and it's worth some XP")
	profile.set_flag("pt_diwali_left")
	expect_equal(Life.went(profile, "diwali", 10), int(Life.party("diwali")["left_bed"]), "leaving for the page changes bedtime")
	var other := _profile(14)
	var khan := other.trust("khan", 45)
	Life.skipped(other, "khan_reception", 13)
	expect(other.trust("khan", 45) < khan, "Dr. Khan noticed you didn't come")
	expect(other.has_flag("pt_khan_missed"), "and saves you a box anyway")
	expect_equal(Life.speech_verdict({"great": 6, "ok": 4}, 6), "great")
	expect_equal(Life.speech_verdict({"great": 6, "ok": 4}, 5), "ok")
	expect_equal(Life.speech_verdict({"great": 6, "ok": 4}, 3), "flop")


# --- The games ---------------------------------------------------------------------------

func test_carrom_pockets_a_coin_struck_straight_and_counts_fouls() -> void:
	var game := add_node(CarromGame.new("varun", 3)) as CarromGame
	for piece: Dictionary in game.pieces:
		if piece != game.striker:
			piece["in"] = false
	var coin: Dictionary = game.pieces[1]
	coin["in"] = true
	coin["p"] = Vector2(0.75, -0.75)
	game.striker["p"] = Vector2(0.45, -0.45)
	game.state = "aim"
	game.shoot(Vector2(1, -1), 0.5)
	for frame in 300:
		game.tick(STEP)
		if game.state != "moving":
			break
	expect(not bool(coin["in"]), "the coin went in")
	expect_equal(game.scores[0], 1, "a point")
	expect(game.state != "moving", "the strike ends when everything stops")
	var foul := add_node(CarromGame.new("varun", 3)) as CarromGame
	for piece: Dictionary in foul.pieces:
		if piece != foul.striker:
			piece["in"] = false
	foul.pieces[1]["in"] = true
	foul.pieces[1]["p"] = Vector2(-0.5, -0.2)
	foul.scores[0] = 2
	foul.striker["p"] = Vector2(0.5, 0.5)
	foul.shoot(Vector2(1, 1), 0.6)
	for frame in 300:
		foul.tick(STEP)
		if foul.state != "moving":
			break
	expect_equal(foul.scores[0], 1, "the striker in a pocket costs a point")


func test_a_whole_game_of_carrom_plays_out_the_same_way_twice() -> void:
	var results := []
	for attempt in 2:
		var game := add_node(CarromGame.new("varun", 21)) as CarromGame
		var said := []
		game.finished.connect(func(result: String) -> void: said.append(result))
		for frame in 4000:
			game.auto_step(0.8)
			game.tick(STEP)
			if not said.is_empty():
				break
		expect_equal(said.size(), 1, "the game finishes")
		if game.coins_left() > 0:
			expect_equal(game.strikes, CarromGame.STRIKES * 2, "three strikes each")
		results.append([game.scores.duplicate(), game.result])
		var mine: int = game.scores[0]
		var theirs: int = game.scores[1]
		expect_equal(game.result, "won" if mine >= theirs else "lost", "ties go to the home board")
	expect_equal(results[0], results[1], "the same seed plays the same game")


func test_antakshari_offers_one_right_song_and_ties_go_to_the_nurses() -> void:
	var data: Dictionary = Life.rule("antakshari", {})
	var game := add_node(AntakshariGame.new("grace", 5, data)) as AntakshariGame
	expect(game.my_turn() and game.state == "choose", "the doctors go first")
	var right := 0
	for song: String in game.options:
		if AntakshariGame.first_letter(song) == game.letter and song not in game.sung:
			right += 1
	expect_equal(right, 1, "one right answer among %s for %s" % [game.options, game.letter])
	expect(game.options.size() >= 2, "and wrong ones beside it")
	expect_equal(game.next_letter("Aankhon Mein Saline"), "E", "the next song starts with the last letter")
	var said := []
	game.finished.connect(func(result: String) -> void: said.append(result))
	for frame in 3000:
		game.auto_step(1.0)
		game.tick(STEP)
		if not said.is_empty():
			break
	expect_equal(said.size(), 1, "eight rounds and done")
	expect_equal(game.scores[0], 4, "a perfect doctor sings every turn")
	var mine: int = game.scores[0]
	var theirs: int = game.scores[1]
	expect_equal(game.result, "won" if mine > theirs else "lost", "and a tie is the nurses'")
	var slow := add_node(AntakshariGame.new("grace", 5, data)) as AntakshariGame
	for frame in int((float(data.get("seconds", 8.0)) + 0.5) / STEP):
		slow.tick(STEP)
	expect_equal(slow.scores[0], 0, "too slow, no point")
	expect(slow.state != "choose", "and the turn moves on")


func test_the_dance_off_rewards_the_beat_and_not_drumming() -> void:
	var game := add_node(DanceGame.new("varun", 9)) as DanceGame
	var said := []
	game.finished.connect(func(result: String) -> void: said.append(result))
	for frame in 2000:
		game.auto_step(1.0)
		game.tick(STEP)
		if not said.is_empty():
			break
	expect_equal(said.size(), 1, "the song ends")
	expect(game.points >= game.most_points() * 3 / 4, "on the beat scores near the most (%d of %d)" % [game.points,
		game.most_points()])
	expect(game.points > game.rival_points and game.result == "won", "and beats Varun")
	var drummer := add_node(DanceGame.new("varun", 9)) as DanceGame
	for frame in 2000:
		drummer.tap()
		drummer.tick(STEP)
		if drummer.is_over():
			break
	expect(drummer.points < game.points / 2, "drumming the screen doesn't win (%d)" % drummer.points)
	var idle := add_node(DanceGame.new("varun", 9)) as DanceGame
	for frame in 2000:
		idle.tick(STEP)
		if idle.is_over():
			break
	expect(idle.points == 0 and idle.result == "lost", "standing still loses")
	expect(idle.notes.all(func(note: Dictionary) -> bool: return note["judged"] == "miss"), "every dot missed")


func test_a_speech_is_judged_by_its_lines() -> void:
	var speeches: Dictionary = Life.rule("speeches", {})
	for id: String in speeches:
		var best := add_node(SpeechGame.new(speeches[id], Life.rule("verdicts", {}))) as SpeechGame
		for frame in 2000:
			best.auto_step(1.0)
			best.tick(STEP)
			if best.is_over():
				break
		expect_equal(best.result, "great", "the best lines make %s great" % id)
		var worst := add_node(SpeechGame.new(speeches[id], Life.rule("verdicts", {}))) as SpeechGame
		for frame in 2000:
			if worst.state == "choose":
				var options: Array = worst.rounds[worst.line_index]
				var low := 0
				for index in options.size():
					if int(options[index]["points"]) < int(options[low]["points"]):
						low = index
				worst.pick(low)
			worst.tick(STEP)
			if worst.is_over():
				break
		expect_equal(worst.result, "flop", "the worst make %s a flop" % id)
		expect_equal(worst.said.size(), (speeches[id]["rounds"] as Array).size(), "every line said")


# --- The evening -------------------------------------------------------------------------

func test_an_ordinary_evening_chai_the_radio_home_a_call_food_and_bed() -> void:
	var evening := _evening(5)
	var profile := evening.profile
	expect_equal(evening.phase, "menu", "it opens on the menu")
	expect_equal(evening.where, "canteen", "in Mani's canteen")
	expect_equal(evening.minutes, 19 * 60, "at seven")
	expect_equal(Array(evening.panel.row_ids()), ["canteen", "radio", "hostel"], "chai, the radio, home")
	expect(evening.current_set.actors.has("mani"), "Mani's behind the counter")
	for who: String in evening.staff:
		expect(evening.current_set.actors.has(who), "%s is having chai" % who)
	evening.choose("canteen")
	expect_equal(evening.phase, "talk", "chai")
	expect(_back_to_menu(evening), "and back")
	expect_equal(evening.chai_with, evening.staff[0], "with the first one picked")
	expect_equal(profile.count(Life.CHAI + evening.chai_with), 1, "a chat had")
	expect_equal(profile.count(Life.TIP_DAY), 6, "and a tip for tomorrow")
	expect_equal(evening.minutes, 19 * 60 + 40, "forty minutes")
	evening.choose("radio")
	expect_equal(evening.phase, "song", "the radio")
	expect(evening.banner != null, "with the words on screen")
	expect(_back_to_menu(evening), "until the song ends")
	expect_equal(evening.minutes, 19 * 60 + 45, "five minutes")
	evening.choose("hostel")
	expect(_back_to_menu(evening), "the walk home")
	expect_equal(evening.where, "hostel_room", "the hostel room")
	expect_equal(Array(evening.panel.row_ids()), ["call", "eat", "study", "scroll"], "home, food, books, phone")
	evening.choose("call")
	expect(evening.call_frame.visible, "a video call")
	expect(evening.current_set.actors.has("mum") and evening.current_set.actors.has("anu"), "with the family")
	expect(_back_to_menu(evening), "and goodbye")
	expect_equal(profile.count(Life.CALLED), 5, "home has been called")
	expect(not evening.call_frame.visible, "the call ends")
	evening.choose("eat")
	expect(_back_to_menu(evening), "dinner")
	expect(evening.ate, "eaten")
	var xp := profile.total_xp
	evening.choose("study")
	expect(_back_to_menu(evening), "an hour with the books")
	expect_equal(profile.total_xp, xp + 15, "a little XP")
	evening.choose("bed")
	expect(evening.play_until(func() -> bool: return evening.is_done()), "lights out")
	expect_equal(evening.bedtime, 19 * 60 + 40 + 5 + 12 + 30 + 20 + 60, "at the time on the clock")
	expect_equal(profile.count(Life.BED_DAY), 6, "sleep counts for the next morning")
	expect_equal(profile.count(Life.ATE), 1, "fed")
	expect_equal(profile.count(Life.DONE), 5, "and this evening is over")


func test_bed_at_once_skips_everything_but_the_walk() -> void:
	var evening := _evening(5)
	evening.choose("bed")
	expect(evening.play_until(func() -> bool: return evening.is_done()), "straight to bed")
	expect_equal(evening.bedtime, 19 * 60 + 12, "after the walk home")
	expect_equal(evening.profile.count(Life.ATE), 0, "hungry")
	expect_equal(evening.profile.count(Life.CALLED), 0, "no call")


func test_a_party_with_its_game_the_pager_and_a_choice() -> void:
	var evening := _evening(10)
	expect_equal(evening.party, "diwali", "Diwali")
	expect_equal(Array(evening.panel.row_ids())[0], "party", "the party comes first")
	evening.choose("party")
	expect_equal(evening.where, "terrace", "on the terrace")
	expect(evening.current_set.actors.has("grace") and evening.current_set.actors.has("iyer"), "with Ward 4")
	expect(evening.play_until(func() -> bool: return evening.game != null), "a game of antakshari")
	expect(evening.game is AntakshariGame, "it's antakshari")
	expect(evening.play_until(func() -> bool: return evening.pager != null), "then the pager goes")
	expect(evening.play_until(func() -> bool: return evening.is_done(), 0), "the doctor goes (the first reply)")
	var profile := evening.profile
	expect(profile.has_flag("pt_diwali_left"), "and leaves for the page")
	expect_equal(evening.bedtime, int(Life.party("diwali")["left_bed"]), "bed after casualty")
	expect(profile.count(Life.PARTY + "diwali") == 10, "the party is remembered")


func test_skipping_a_party_and_varun_walks_in_late() -> void:
	var skip := _evening(7)
	expect_equal(skip.party, "hostel_night", "hostel night")
	skip.choose("hostel")
	expect(_back_to_menu(skip), "home instead")
	expect(skip.panel.row_ids()[0] == "party", "the party's still on offer from the hostel")
	skip.choose("bed")
	expect(skip.play_until(func() -> bool: return skip.is_done()), "bed")
	expect_equal(skip.profile.count(Life.PARTY + "hostel_night"), -7, "skipped")
	var doctor := _profile(24)
	var evening := _evening(23, doctor)
	expect_equal(evening.party, "rao_farewell", "Dr. Rao's farewell")
	evening.choose("party")
	var varun: AvatarRig = evening.current_set.actors.get("varun")
	expect(varun != null and not varun.visible, "Varun isn't there yet")
	expect(evening.play_until(func() -> bool: return evening.game != null), "the speech")
	expect(evening.game is SpeechGame, "is a speech")
	expect(evening.play_until(func() -> bool: return varun.visible), "then Varun walks in")
	expect(evening.play_until(func() -> bool: return evening.is_done()), "with flowers, and the night ends")
	expect(doctor.has_flag("pt_rao_great") or doctor.has_flag("pt_rao_ok") or doctor.has_flag("pt_rao_flop"),
		"the speech is remembered")


func test_main_has_the_evening_between_a_ward_day_and_the_next() -> void:
	_clear_saves()
	var main := Main.new()
	main.store = SaveStore.new("user://test_life/save.json")
	main.settings_path = "user://test_life/settings.json"
	add_node(main)
	main.profile = _profile(5)
	main.profile.minutes = 18 * 60 + 50
	main._on_day_finished()
	expect(main.screen is Evening, "the evening after Day 5")
	var evening := main.screen as Evening
	expect_equal(main.profile.day, 6, "the save is already on the next morning")
	expect_equal(evening.minutes, 19 * 60 + 5, "starting a little after the doctor left")
	# The game closes during the evening: continue comes back to it.
	main.show_title()
	(main.screen as TitleScreen).continue_pressed.emit()
	expect(main.screen is Evening, "continue comes back to the evening")
	evening = main.screen as Evening
	expect_equal(evening.minutes, 19 * 60 + 5, "at the same time")
	evening.choose("bed")
	evening.play_until(func() -> bool: return main.screen != evening, 0, 0.7, 30.0)
	expect(not (main.screen is Evening), "bed, then the next day (or its drill)")
	expect_equal(main.profile.count(Life.DONE), 5, "the evening is saved as had")
	main.show_hospital()
	expect(not (main.screen is Evening), "and never played twice")
	_clear_saves()


func _clear_saves() -> void:
	for file: String in ["save.json", "save.json.tmp", "settings.json", "settings.json.tmp", "save.bak1.json", "save.bak2.json",
			"save.bak3.json", ".install"]:
		var path := "user://test_life/" + file
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func test_mum_walks_onto_the_ward_and_grace_has_a_word() -> void:
	var profile := _profile(10)
	Life.go_to_bed(profile, 4, 22 * 60, true)
	profile.day = 10
	expect(Life.mum_due(profile), "no call since Day 4")
	var ward := add_node(Ward.new(profile)) as Ward
	ward.play_until(func() -> bool: return ward.mode == "walk" and ward.place == "ward", Ward.pick_tones(["Ready"]))
	ward.feelings.start_mum()
	var mum := ward.rig_for("mum")
	expect(mum != null and mum.visible, "Mum comes in")
	expect_equal(ward.mode, "side", "the doctor waits")
	for frame in int((WardFeelings.SIDE_TIMEOUT + 1.0) / STEP):
		ward.update(STEP)
	expect(ward.story.is_playing(), "she talks")
	ward.play_until(func() -> bool: return not ward.story.is_playing(), Ward.pick_tones(["Hug"]))
	expect(profile.has_flag("lf_mum_hugged"), "a hug")
	expect_equal(profile.count(Life.MUM), 10, "Mum's been")
	expect(not Life.mum_due(profile), "so she isn't due again")
