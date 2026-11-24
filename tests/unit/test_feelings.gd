extends TestCase
## The director and feelings (stage 26): the shift's pacing (breathers,
## trouble after a quiet stretch, silliness in serious scenes, the week's
## emotional moments), the moment card and what a choice leaves behind,
## the colleagues' own stories, the songs, the radio and the goat.

const CAREFUL := ["Ready", "Honest", "Reassure", "Ask her", "Check", "Own it", "Calm", "Compromise", "To Aarav", "Gentle",
	"Careful", "Stay", "Patient first", "Answer", "Light", "Ask him", "The facts", "Grateful", "Plainly"]
const STEP := 1.0 / 30.0
const TOKENS := ["{patient}", "{his}", "{His}", "{him}", "{he}", "{He}", "{son}", "{where}", "{called}"]

var _rules_before: Variant = StoryBook._cache.get("feelings")


func cleanup() -> void:
	if _rules_before == null:
		StoryBook._cache.erase("feelings")
	else:
		StoryBook._cache["feelings"] = _rules_before
	if SongPlayer.active != null and is_instance_valid(SongPlayer.active):
		SongPlayer.active.stop()
	SongPlayer.active = null
	Music.hold_for_song(false)
	super()


## The director's numbers with some changed, for one test.
func _with_rules(changed: Dictionary) -> void:
	var rules: Dictionary = Feelings.data().duplicate(true)
	for key: String in changed:
		rules["director"][key] = changed[key]
	StoryBook._cache["feelings"] = rules


func _sim(day: int = 12, load: float = 0.0) -> ShiftSim:
	var sim := ShiftSim.new(77, 8 * 60, load)
	sim.day = day
	sim.director = Director.new(77)
	return sim


func _patient(sim: ShiftSim, condition_id: String, age: int, sex: String) -> ShiftPatient:
	var patient := sim.make_patient(condition_id, {"age": age, "sex": sex})
	sim.patients.append(patient)
	return patient


## Someone who walked in with a condition, of a sex and an age, who isn't
## an emergency (moments don't interrupt those).
func _someone(sim: ShiftSim, condition_id: String, sex: String, low: int, high: int) -> ShiftPatient:
	var patient: ShiftPatient
	for attempt in 400:
		patient = sim.make_patient(condition_id)
		if patient.sex() == sex and patient.age >= low and patient.age <= high and patient.triage() != "red":
			break
	sim.patients.append(patient)
	return patient


# --- The rules ---------------------------------------------------------------------

func test_the_feelings_are_complete_and_speak_in_known_voices() -> void:
	var cast := StoryBook.cast()
	var said_by := func(line: Dictionary, where: String) -> void:
		if line.is_empty():
			return
		var who := str(line.get("say", ""))
		expect(who in ["patient", "relative", "kid"] or cast.has(who), "%s: %s is someone" % [where, who])
		expect(not str(line.get("text", "")).is_empty(), "%s says something" % where)
	var check_text := func(text: String, where: String) -> void:
		for found in RegEx.create_from_string("\\{[A-Za-z]+\\}").search_all(text):
			expect(found.get_string() in TOKENS, "%s: %s is a known blank" % [where, found.get_string()])
		for character in text:
			expect(character.unicode_at(0) < 0x2190, "%s has no emoji or symbols" % where)
		expect(not text.contains("Asha"), "%s names nobody Asha" % where)
	for id: String in Feelings.moments():
		var entry := Feelings.moment(id)
		expect(str(entry.get("kind", "")) in ["patient", "staff"], "%s is a patient's or a colleague's" % id)
		expect(not Feelings.moment_title(id).is_empty() and not str(entry.get("text", "")).is_empty(), "%s has words" % id)
		check_text.call(str(entry.get("text", "")), id)
		said_by.call(entry.get("line", {}), id)
		var choices: Array = entry.get("choices", [])
		expect(choices.size() >= 2 and choices.size() <= 4, "%s offers two to four things to do" % id)
		for choice: Dictionary in choices:
			var where := "%s.%s" % [id, choice.get("id", "")]
			expect(not str(choice.get("text", "")).is_empty() and not str(choice.get("after", "")).is_empty(), where)
			check_text.call(str(choice.get("text", "")) + " " + str(choice.get("after", "")), where)
			said_by.call(choice.get("line", {}), where)
			for who: String in (choice.get("trust", {}) as Dictionary):
				expect(cast.has(who) and cast[who].has("trust"), "%s: %s has a trust meter" % [where, who])
			var payoff: Dictionary = choice.get("payoff", {})
			if not payoff.is_empty():
				check_text.call(str(payoff.get("text", "")), where + " message")
				var from := str(payoff.get("from", ""))
				expect(from in ["relative", "social"] or PhoneBook.contacts().has(from), "%s: the message comes from %s" % [where, from])
	for group: Dictionary in [Feelings.sillies(), Feelings.lifts()]:
		for id: String in group:
			var entry: Dictionary = group[id]
			expect(not str(entry.get("text", "")).is_empty(), "%s has words" % id)
			check_text.call(str(entry.get("text", "")), id)
			said_by.call(entry.get("line", {}), id)
	for id: String in Feelings.lifts():
		var song := str((Feelings.lifts()[id] as Dictionary).get("song", ""))
		expect(song.is_empty() or not Songs.song(song).is_empty(), "%s plays a real song" % id)


func test_conditions_on_the_story_flags() -> void:
	var flags := {"a": true, "b": true}
	expect(Feelings.holds(flags, ""), "nothing asked")
	expect(Feelings.holds(flags, "a") and not Feelings.holds(flags, "c"), "a flag")
	expect(Feelings.holds(flags, "!c") and not Feelings.holds(flags, "!a"), "not a flag")
	expect(Feelings.holds(flags, "a&b") and not Feelings.holds(flags, "a&c"), "both")
	expect(Feelings.holds(flags, "c|b") and not Feelings.holds(flags, "c|d"), "either")


# --- The director --------------------------------------------------------------------

func test_a_hard_stretch_brings_a_breather_and_holds_back_the_patient_nobody_can_save() -> void:
	var sim := _sim()
	var director := sim.director
	director.tension = 60.0
	sim.doomed_at = sim.minute + 120
	var events := sim.advance_to(sim.minute + 1)
	expect(director.breather_until < 0, "still hard")
	events.append_array(sim.advance_to(sim.minute + 200))
	expect(director.breather_until > 0, "a breather once it eases")
	expect(sim.doomed_at > director.breather_until, "the patient nobody can save comes after it (%d > %d)" % [sim.doomed_at,
		director.breather_until])
	var lifts := events.filter(func(event: Dictionary) -> bool: return event["kind"] == "lift")
	expect_equal(lifts.size(), 1, "something kind or funny")
	if not lifts.is_empty():
		expect(Feelings.lifts().has(str(lifts[0]["lift"])) and not str(lifts[0]["text"]).is_empty(), str(lifts[0]))
	# No trouble during it.
	expect(events.all(func(event: Dictionary) -> bool:
		return event["kind"] != "arrived" or not (event["patient"] as ShiftPatient).trouble), "no trouble in a breather")


func test_the_breathers_remember_what_the_doctor_did() -> void:
	var rng := SeededRandom.new(3)
	var picked := {}
	for index in 300:
		picked[Feelings.pick_lift(rng, {"lv_priya_cover": true}, 12, {})] = true
	expect(picked.has("biscuits_cover"), "Priya remembers the cover")
	expect(not picked.has("biscuits_rota") and not picked.has("biscuits"), "and nothing that contradicts it")
	picked.clear()
	for index in 300:
		picked[Feelings.pick_lift(rng, {}, 12, {})] = true
	expect(picked.has("biscuits") and not picked.has("biscuits_cover"), "nothing to remember: the plain one")
	expect(Feelings.pick_lift(rng, {}, 12, Feelings.lifts()).is_empty(), "each only once a day")
	expect(not picked.has("joke") or Feelings.lifts()["joke"].get("from_day", 0) <= 12, "a lift waits for its day")


func test_a_long_quiet_stretch_brings_trouble_but_not_too_much() -> void:
	var sim := _sim(12, 0.0)
	var events := sim.advance_to(sim.minute + 600)
	var trouble := events.filter(func(event: Dictionary) -> bool:
		return event["kind"] == "arrived" and (event["patient"] as ShiftPatient).trouble)
	expect(trouble.size() >= 1 and trouble.size() <= int(Feelings.rule("trouble_max", 2)), "an ambulance or two (%d)" % trouble.size())
	var minutes := []
	for event: Dictionary in trouble:
		var patient: ShiftPatient = event["patient"]
		expect(patient.triage() in ["yellow", "red"], "trouble is serious")
		minutes.append(patient.arrived_at)
	for index in range(1, minutes.size()):
		expect(int(minutes[index]) - int(minutes[index - 1]) >= int(Feelings.rule("trouble_gap", 150)), "spaced out")
	var early := _sim(int(Feelings.rule("trouble_from_day", 6)) - 1, 0.0)
	var none := early.advance_to(early.minute + 600).filter(func(event: Dictionary) -> bool: return event["kind"] == "arrived")
	expect(none.is_empty(), "not in the first days")


func test_trouble_never_changes_who_the_day_brings() -> void:
	var with_director := _arrivals(true)
	var without := _arrivals(false)
	expect(with_director.size() > 10, "a real day")
	expect_equal(with_director, without, "the same people at the same minutes")


func _arrivals(director: bool) -> Array:
	var profile := PlayerProfile.new()
	profile.day = 14
	profile.set_count("hospital_seed", 31)
	var sim := ShiftDay.make(profile, 14, 8 * 60)
	if not director:
		sim.director = null
	var rng := SeededRandom.new(9)
	while sim.minute < 15 * 60:
		var spent := ShiftBot.step(sim, rng.chance(0.9))
		sim.advance_to(mini(15 * 60, sim.minute + maxi(1, spent)))
	var found := []
	for patient in sim.patients:
		if not patient.trouble:
			found.append("%d %s %s" % [patient.arrived_at, patient.full_name(), patient.condition_id])
	return found


func test_silliness_is_rare_and_one_per_serious_scene() -> void:
	var sim := _sim()
	var director := sim.director
	var sillies: Array[Dictionary] = []
	var serious := {}
	for minute in 600:
		sim.minute += 1
		var events: Array[Dictionary] = []
		if minute % 15 == 0:
			var patient := _patient(sim, "heart_attack", 60, "m")
			serious[patient.id] = true
			events.append({"kind": "crashed", "patient": patient})
		director.step(sim, events, 0)
		for event in events:
			if event["kind"] == "silly":
				sillies.append(event)
	expect(sillies.size() >= 1 and sillies.size() <= int(Feelings.rule("silly_max", 2)), "now and then (%d)" % sillies.size())
	for event in sillies:
		expect(serious.has((event["patient"] as ShiftPatient).id), "in a serious scene")
		expect(Feelings.sillies().has(str(event["silly"])), str(event["silly"]))
	# One serious scene rolls once, however often it turns.
	_with_rules({"silly_chance": 1.0, "silly_gap": 0, "silly_max": 10})
	var again := _sim()
	var patient := _patient(again, "heart_attack", 60, "m")
	var seen := 0
	for minute in 30:
		again.minute += 1
		var events: Array[Dictionary] = []
		if minute % 5 == 0:
			events.append({"kind": "crashed", "patient": patient})
		again.director.step(again, events, 0)
		seen += events.filter(func(event: Dictionary) -> bool: return event["kind"] == "silly").size()
	expect_equal(seen, 1, "one silly thing per scene")


func test_moments_come_a_few_times_a_week_never_on_a_schedule() -> void:
	var planned := 0
	var days := 0
	var at := {}
	for hospital in range(1, 41):
		for day in range(1, 29):
			var director := Director.new(hospital * 1000 + day)
			director.plan(day, 8 * 60)
			if day < int(Feelings.rule("moment_from_day", 5)):
				expect(director.moment_at < 0, "not in the first days")
				continue
			days += 1
			if director.moment_at >= 0:
				planned += 1
				at[director.moment_at] = true
				var window: Array = Feelings.rule("moment_window", [80, 560])
				expect_between(director.moment_at, 8 * 60 + int(window[0]), 8 * 60 + int(window[1]), "inside the shift")
	var share := float(planned) / float(days)
	expect(share > 0.3 and share < 0.55, "about three days a week (%.2f)" % share)
	expect(at.size() > 60, "at all sorts of times (%d)" % at.size())


func test_a_planned_moment_finds_someone_and_comes_once() -> void:
	var fired := 0
	var planned := 0
	for hospital in range(1, 13):
		var profile := PlayerProfile.new()
		profile.day = 16
		profile.set_count("hospital_seed", hospital * 11)
		var sim := ShiftDay.make(profile, 16, 8 * 60)
		if sim.director.moment_at < 0:
			continue
		planned += 1
		var rng := SeededRandom.new(hospital)
		var moments := 0
		while sim.minute < 18 * 60:
			var spent := ShiftBot.step(sim, rng.chance(0.9))
			for event in sim.advance_to(mini(18 * 60, sim.minute + maxi(1, spent))):
				if event["kind"] == "moment":
					moments += 1
					var patient: ShiftPatient = event.get("patient")
					var id := str(event["moment"])
					expect(Feelings.moments().has(id), id)
					expect((patient == null) == (str(Feelings.moment(id).get("kind", "")) == "staff"), "%s: with the right person" % id)
		expect(moments <= 1, "never two in a day")
		fired += moments
	expect(planned > 0 and float(fired) / float(planned) > 0.6, "a planned moment nearly always happens (%d of %d)" % [fired, planned])


func test_who_a_moment_fits() -> void:
	var sim := _sim()
	var old_man := _someone(sim, "pneumonia", "m", 66, 99)
	expect(Feelings.fits("photo", old_man), "an old man waiting")
	expect(not Feelings.fits("photo", _someone(sim, "wrist_fracture", "m", 50, 62)), "not a young one")
	expect(not Feelings.fits("photo", _someone(sim, "pneumonia", "f", 66, 99)), "not a woman")
	old_man.doomed = true
	expect(not Feelings.fits("photo", old_man), "not someone beyond saving")
	old_man.doomed = false
	old_man.state = "gone"
	expect(not Feelings.fits("photo", old_man), "not someone gone")
	var lady := _someone(sim, "hip_fracture", "f", 70, 99)
	lady.company = {}
	expect(Feelings.fits("alone", lady), "an old woman on her own")
	lady.company = {"sex": "f", "age": 50, "relation": "daughter"}
	expect(not Feelings.fits("alone", lady), "not with her daughter there")
	var child := _someone(sim, "croup", "f", 4, 5)
	expect(Feelings.fits("scared", child), "a scared child")
	expect_equal(Feelings.voice_for({"say": "kid"}, child, SeededRandom.new(1)), "girl", "a girl's voice for a girl")
	expect_equal(Feelings.fill("{His} hand. {patient}, {where}.", old_man).begins_with("His hand."), true, "his")
	expect(Feelings.fill("{His} hand", lady).begins_with("Her hand"), "her")
	expect(Feelings.pick_moment(SeededRandom.new(2), sim, {}).size() == 2, "something fits")
	var seen := {}
	for id: String in Feelings.moments():
		seen[id] = sim.day
	expect(Feelings.pick_moment(SeededRandom.new(2), sim, seen).is_empty(), "nothing had in the last few days")


func test_a_choice_in_a_moment_is_remembered_and_heard_from_later() -> void:
	var profile := PlayerProfile.new()
	profile.name = "Asha Verma"
	profile.day = 12
	profile.minutes = 14 * 60
	var sim := _sim()
	var man := _someone(sim, "pneumonia", "m", 66, 99)
	Feelings.choose(profile, "photo", "listen", man)
	expect_equal(profile.count("moment_photo"), 12, "the day is remembered")
	expect_equal(profile.count("moments"), 1, "and counted")
	expect_equal(Feelings.seen_moments(profile), {"photo": 12}, "so it rests for a while")
	var kept: Array = PhoneBook.state(profile)["kept"]
	expect_equal(kept.size(), 1, "a message is on its way")
	if kept.is_empty():
		return
	var item: Dictionary = kept[0]
	expect(int(item["day"]) > 12 and int(item["day"]) <= 15, "a few days later")
	expect(not str(item["name"]).is_empty() and str(item["chat"]) == str(item["id"]), "from the family, by name")
	expect(str(item["name"]).ends_with(str(man.person.get("last", ""))), "with his surname")
	profile.day = int(item["day"])
	profile.minutes = 23 * 60
	PhoneBook.forget()
	var thread := PhoneBook.thread(profile, str(item["chat"]))
	expect_equal(thread.size(), 1, "it arrives on its day")
	var saved := PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(profile.to_dict())))
	expect_equal((PhoneBook.state(saved)["kept"] as Array).size(), 1, "and survives a save")
	# A child's mother writes about her daughter (or his son).
	var girl := _someone(sim, "croup", "f", 4, 5)
	profile.day = 16
	Feelings.choose(profile, "scared", "honest", girl)
	var mother := (PhoneBook.state(profile)["kept"] as Array).filter(func(entry: Dictionary) -> bool:
		return str(entry["id"]) == "m16_scared")
	expect_equal(mother.size(), 1, "her mother writes")
	if not mother.is_empty():
		var said := str(mother[0]["text"])
		expect(said.contains("daughter") and said.contains("she grows up") and not said.contains("{"), said)
	# The social worker writes for the papers.
	profile.day = 20
	Feelings.choose(profile, "papers", "social", man)
	expect(profile.has_flag("papers_social"), "the flag")
	var social := (PhoneBook.state(profile)["kept"] as Array).filter(func(entry: Dictionary) -> bool: return entry["chat"] == "elsy")
	expect_equal(social.size(), 1, "Sister Elsy writes")
	# Trust moves only for those with a meter.
	var before := profile.trust("priya", 45)
	Feelings.choose(profile, "sluice", "stay", null)
	expect(profile.trust("priya", 45) > before, "staying with Priya counts")


# --- Colleagues ----------------------------------------------------------------------

func test_every_colleague_s_story_hangs_together() -> void:
	var cast := StoryBook.cast()
	var lives := StoryBook.chapter("lives")
	for id: String in Lives.ids():
		var who := Lives.who(id)
		expect(cast.has(who), "%s: %s is in the cast" % [id, who])
		expect(lives.has(Lives.talk(id)), "%s: the ask %s is written" % [id, Lives.talk(id)])
		expect_equal(Lives.arc_for_talk(Lives.talk(id)), id, "the ask leads back to its story")
		expect(PhoneBook.contacts().has(who), "%s can text the doctor" % who)
		var payoff: Array = Lives.arc(id).get("payoff", [])
		expect(not payoff.is_empty(), "%s: they say how it went" % id)
		var flags := {}
		for step: Dictionary in lives.get(Lives.talk(id), []):
			for choice: Dictionary in step.get("choose", []):
				flags[str(choice.get("flag", ""))] = true
		for flag: String in flags:
			var heard := payoff.any(func(entry: Dictionary) -> bool: return Feelings.holds({flag: true}, str(entry.get("if", ""))))
			expect(heard, "%s: every answer (%s) is heard from" % [id, flag])
	for chapter: String in ["junior", "senior", "surgeon", "hod", "chief"]:
		expect(Lives.ids().any(func(id: String) -> bool: return chapter in (Lives.arc(id).get("chapters", []) as Array)),
			"someone has a story as %s" % chapter)


func test_colleagues_ask_now_and_then_in_their_stretch() -> void:
	var asks := 0
	var started := {}
	for hospital in range(1, 31):
		var profile := PlayerProfile.new()
		profile.set_count("hospital_seed", hospital * 13 + 1)
		var last := -100
		for day in range(1, 40):
			profile.day = day
			var id := Lives.today(profile)
			if id.is_empty():
				continue
			expect(day >= int(Lives.data().get("first_day", 9)), "not before the colleagues are known")
			expect(day - last >= int(Lives.data().get("gap_days", 2)), "not every day")
			expect(Lives.chapter_of(day) in (Lives.arc(id).get("chapters", []) as Array), "%s in its stretch" % id)
			var after: Array = Lives.arc(id).get("after", [1, 2])
			expect(day + int(after[1]) <= Lives.chapter_end(day), "%s: time to hear back before the story jumps" % id)
			Lives.asked(profile, id)
			expect_equal(Lives.asked_on(profile, id), day, "remembered")
			expect(Lives.today(profile).is_empty(), "one ask a day")
			expect_between(Lives.payoff_day(profile, id), day + int(after[0]), day + int(after[1]), "%s: hears back" % id)
			last = day
			asks += 1
			started[id] = true
	var per_career := float(asks) / 30.0
	expect(per_career >= 1.5 and per_career <= 6.0, "a few asks a career (%.1f)" % per_career)
	expect(started.size() >= Lives.ids().size() - 1, "most stories get told somewhere (%s)" % [started.keys()])


func test_the_colleague_texts_how_it_went() -> void:
	var profile := PlayerProfile.new()
	profile.name = "Asha Verma"
	profile.day = 10
	profile.set_flag("lv_priya_cover")
	Lives.asked(profile, "priya_course")
	var day := Lives.payoff_day(profile, "priya_course")
	profile.day = day
	profile.minutes = 23 * 60
	PhoneBook.forget()
	var found := PhoneBook.thread(profile, "priya").filter(func(item: Dictionary) -> bool: return item["id"] == "lv_priya_course")
	expect_equal(found.size(), 1, "Priya writes on day %d" % day)
	if not found.is_empty():
		expect_equal(str(found[0]["text"]), Lives.payoff_text(profile, "priya_course"), "about the cover")
	profile.minutes = 9 * 60
	PhoneBook.forget()
	expect(PhoneBook.thread(profile, "priya").all(func(item: Dictionary) -> bool: return item["id"] != "lv_priya_course"),
		"not before the evening")


# --- In the game ------------------------------------------------------------------------

func _ward(day: int) -> Ward:
	var doctor := PlayerProfile.new()
	doctor.name = "Asha Verma"
	doctor.day = day
	doctor.opening_seen = true
	doctor.created = true
	doctor.total_xp = 800
	doctor.set_count("hospital_seed", 4242)
	for flag: String in ["op_rohit_done", "op_rohit_won"]:
		doctor.set_flag(flag)
	return add_node(Ward.new(doctor)) as Ward


func _frames(ward: Ward, seconds: float) -> void:
	for frame in int(seconds / STEP):
		ward.update(STEP)


func test_a_colleague_walks_up_asks_and_goes_back() -> void:
	var ward := _ward(10)
	ward.play_until(func() -> bool: return ward.mode == "walk" and ward.place == "ward", Ward.pick_tones(CAREFUL))
	var rig := ward.rig_for("priya")
	expect(rig != null, "Priya is on the ward")
	if rig == null:
		return
	var was := rig.position
	var shown := rig.visible
	ward.feelings.start_side("priya_course")
	expect(rig.visible, "she comes over (through the door if she wasn't here)")
	expect_equal(ward.mode, "side", "the doctor waits for her")
	_frames(ward, WardFeelings.SIDE_TIMEOUT + 1.0)
	expect(ward.story.is_playing(), "she asks")
	expect_equal(ward.talking_with, "priya", "the camera is on her")
	ward.play_until(func() -> bool: return not ward.story.is_playing(), Ward.pick_tones(["Cover"]))
	expect_equal(Lives.asked_on(ward.profile, "priya_course"), ward.profile.day, "she has asked")
	expect(ward.profile.has_flag("lv_priya_cover"), "the answer is a flag")
	expect_equal(ward.mode, "walk", "back to work")
	_frames(ward, 10.0)
	if shown:
		expect(rig.position.distance_to(was) < 0.7, "and she goes back to what she was doing")
	else:
		expect(not rig.visible, "and she goes back out the door")


func test_a_colleague_waits_while_the_doctor_is_busy() -> void:
	var ward := _ward(10)
	ward.play_until(func() -> bool: return ward.mode == "walk" and ward.place == "ward", Ward.pick_tones(CAREFUL))
	ward.feelings.play_song("dal")
	ward.feelings._maybe_side()
	expect(ward.feelings.side.is_empty(), "not over a song")
	ward.feelings.stop_song()
	ward.profile.minutes = 6 * 60
	ward.feelings._maybe_side()
	expect(ward.feelings.side.is_empty(), "not first thing in the morning")


func test_a_colleague_s_moment_opens_a_card_and_closes() -> void:
	var ward := _ward(12)
	ward.play_until(func() -> bool: return ward.mode == "walk", Ward.pick_tones(CAREFUL))
	ward.feelings.on_event({"kind": "moment", "moment": "sluice", "patient": null, "text": ""})
	_frames(ward, 0.2)
	var card := ward.feelings.moment_card()
	expect(card != null and ward.mode == "family", "the moment opens")
	if card == null:
		return
	for choice: Dictionary in Feelings.moment("sluice")["choices"]:
		expect(card.button("Choose_" + str(choice["id"])) != null, "the doctor can %s" % choice["id"])
	expect(not card.done_button.visible, "something must be done")
	card.button("Choose_stay").pressed.emit()
	expect(card.done_button.visible and card.find_child("After", true, false) != null, "then what came of it")
	card.done_button.pressed.emit()
	expect(ward.feelings.moment_card() == null and ward.mode == "walk", "back to work")
	expect_equal(ward.profile.count("moment_sluice"), 12, "remembered")


func test_a_patient_s_moment_waits_for_casualty_and_drops_if_they_leave() -> void:
	var ward := _ward(12)
	ward.play_until(func() -> bool: return ward.mode == "walk", Ward.pick_tones(CAREFUL))
	var patient := _someone(ward.shift, "pneumonia", "m", 66, 99)
	ward.feelings.on_event({"kind": "moment", "moment": "photo", "patient": patient, "text": ""})
	_frames(ward, 0.2)
	expect(ward.feelings.moment_card() == null, "not on Ward 4: he's in casualty")
	ward.enter_casualty()
	_frames(ward, 0.2)
	var card := ward.feelings.moment_card()
	expect(card != null, "it opens in casualty")
	if card != null:
		expect_equal(card.speaker_name(Feelings.moment("photo")["line"]), patient.called(), "the patient speaks")
		expect(not patient.called().ends_with(" "), "by name: %s" % patient.called())
		card.button("Choose_move_on").pressed.emit()
		card.done_button.pressed.emit()
	var other := _someone(ward.shift, "pneumonia", "m", 66, 99)
	other.state = "gone"
	ward.feelings.on_event({"kind": "moment", "moment": "photo", "patient": other, "text": ""})
	_frames(ward, 0.2)
	expect(ward.feelings.moment_card() == null and ward.feelings.moments.is_empty(), "gone: the moment goes with him")


func test_the_goat_crosses_casualty_bleating_and_leaves() -> void:
	var ward := _ward(12)
	ward.play_until(func() -> bool: return ward.mode == "walk", Ward.pick_tones(CAREFUL))
	ward.enter_casualty()
	var serious := ward.shift.make_patient("heart_attack")
	ward.shift.patients.append(serious)
	ward.feelings.on_event({"kind": "silly", "silly": "goat", "patient": serious, "text": ""})
	var goat := ward.feelings.goat
	expect(goat != null and goat.is_inside_tree(), "a goat")
	if goat == null:
		return
	var gone := [false]
	goat.gone.connect(func() -> void: gone[0] = true)
	var start := goat.position
	_frames(ward, 3.0)
	expect(goat.position.distance_to(start) > 1.0, "walking")
	_frames(ward, 20.0)
	expect(gone[0], "out the far side")
	expect(ward.feelings.goat == null or not is_instance_valid(ward.feelings.goat), "and gone")
	# Silliness is only for those there to see it.
	ward.leave_casualty()
	ward.feelings.on_event({"kind": "silly", "silly": "goat", "patient": serious, "text": ""})
	expect(ward.feelings.goat == null, "no goat on Ward 4")


func test_a_goat_on_its_own() -> void:
	var goat := Goat.new()
	goat.path = [Vector3.ZERO, Vector3(4, 0, 0)]
	add_node(goat)
	expect(goat.find_child("Head", true, false) != null and goat.find_children("Leg*", "", true, false).size() == 4, "four legs, a head")
	var gone := [false]
	goat.gone.connect(func() -> void: gone[0] = true)
	var paused := false
	for frame in int(12.0 / STEP):
		if gone[0]:
			break
		var before := goat.position
		goat.tick(STEP)
		if goat.position.distance_to(before) < 0.0001 and goat.position.x > 1.5 and goat.position.x < 2.5:
			paused = true
	expect(paused, "it stops half way to look round")
	expect(gone[0], "and leaves")


# --- Songs -----------------------------------------------------------------------------

func test_every_song_keeps_time_with_its_music() -> void:
	expect(Songs.ids().size() >= 3, "three songs")
	for id: String in Songs.ids():
		var entry := Songs.song(id)
		expect(not str(entry.get("title", "")).is_empty() and not str(entry.get("by", "")).is_empty(), id)
		var lines := Songs.lines(id)
		expect(lines.size() >= 4, "%s has verses" % id)
		var cast := StoryBook.cast()
		for line: Dictionary in lines:
			expect(cast.has(str(line.get("say", ""))), "%s: %s sings" % [id, line.get("say")])
		var track := "res://assets/music/%s.ogg" % str(entry.get("track", ""))
		expect(ResourceLoader.exists(track), "%s has music" % id)
		if ResourceLoader.exists(track):
			var stream := load(track) as AudioStream
			expect_near(stream.get_length(), Songs.length(id), 0.15, "%s's music is as long as the song" % id)
			expect(not (Music.stream(str(entry["track"])) as AudioStreamOggVorbis).loop, "%s plays once" % id)
		for index in lines.size():
			expect(Songs.line_room(id) >= 3.0, "%s: room to say a line" % id)
			expect(Songs.line_start(id, index) < Songs.length(id), "every line inside the song")
	for request: Dictionary in Songs.requests():
		expect(not Songs.song(str(request.get("song", ""))).is_empty(), "a request plays a real song")


func test_the_song_player_sings_each_line_on_its_bar() -> void:
	var player := SongPlayer.new()
	player.manual = true
	var started := []
	player.line_started.connect(func(index: int) -> void: started.append([index, player.time]))
	var finished := [false]
	player.finished.connect(func() -> void: finished[0] = true)
	expect(not player.play("no_such_song"), "only real songs")
	expect(player.play("dal"), "the dal jingle")
	expect_equal(player.phase, "song", "straight into the music")
	expect(SongPlayer.active == player and Music.song_on, "the background steps back")
	var length := Songs.length("dal")
	var clock := 0.0
	while clock < length + 1.0 and player.playing():
		player.tick(0.05)
		clock += 0.05
	expect(finished[0] and not player.playing(), "it ends")
	expect(not Music.song_on and SongPlayer.active == null, "and the background comes back")
	expect_equal(started.size(), Songs.lines("dal").size(), "every line sung")
	for entry: Array in started:
		expect_near(float(entry[1]), Songs.line_start("dal", int(entry[0])), 0.06, "line %d on its bar" % entry[0])
	player.free()


func test_a_request_comes_first_and_one_song_plays_at_a_time() -> void:
	var first := SongPlayer.new()
	first.manual = true
	var second := SongPlayer.new()
	second.manual = true
	first.play("night", {"say": "rj", "text": "For {called}, from bed two."})
	expect_equal(first.phase, "request", "the dedication first")
	expect_equal(first.request_text(), "For Doctor, from bed two.", "said to the doctor")
	for step in 200:
		first.tick(0.05)
		if first.phase == "song":
			break
	expect_equal(first.phase, "song", "then the song")
	second.play("roast")
	expect(not first.playing() and second.playing() and SongPlayer.active == second, "the new one stops the old one")
	second.stop()
	expect(SongPlayer.active == null and not Music.song_on, "quiet again")
	first.free()
	second.free()


func test_the_lyrics_follow_the_song_and_stop_stops_it() -> void:
	var player := SongPlayer.new()
	player.manual = true
	add_node(player)
	player.play("night")
	var banner := LyricsBanner.new(player)
	add_node(banner)
	while player.line < 1:
		player.tick(0.1)
	banner.refresh()
	var now := banner.find_child("Now", true, false) as Label
	var next := banner.find_child("Next", true, false) as Label
	expect_equal(now.text, player.line_text(), "the line being sung")
	expect_equal(next.text, player.next_text(), "and the next")
	expect((banner.find_child("SongTitle", true, false) as Label).text.contains("NIGHT SHIFT"), "and what's playing")
	var stopped := [false]
	banner.stop_pressed.connect(func() -> void: stopped[0] = true)
	(banner.find_child("Stop", true, false) as Button).pressed.emit()
	expect(stopped[0], "Stop asks the song to stop")
	expect_equal(banner.mouse_filter, Control.MOUSE_FILTER_IGNORE, "and nothing else on it takes a tap")


func test_the_ward_sings_late_at_night_and_at_lunch() -> void:
	var ward := _ward(12)
	ward.play_until(func() -> bool: return ward.mode == "walk" and ward.place == "ward", Ward.pick_tones(CAREFUL))
	ward.profile.minutes = 13 * 60
	ward.profile.set_count("song_dal", 0)
	ward.feelings._maybe_song()
	expect(ward.feelings.songs.playing() and ward.feelings.songs.song_id == "dal", "the canteen's jingle at lunch")
	expect(ward.feelings.banner != null and ward.feelings.banner.is_inside_tree(), "with the words")
	expect_equal(ward.profile.count("song_dal"), 12, "once today")
	ward.feelings.stop_song()
	expect(ward.feelings.banner == null and not ward.feelings.songs.playing(), "Stop stops it")
	ward.feelings._maybe_song()
	expect(not ward.feelings.songs.playing(), "not twice in a day")
	ward.feelings.play_song("roast")
	ward._talk("lv_priya_ask", "priya")
	_frames(ward, 0.1)
	expect(not ward.feelings.songs.playing() and ward.feelings.banner == null, "a conversation stops a song")


# --- The radio -------------------------------------------------------------------------

func test_the_phone_has_the_hospital_radio() -> void:
	var profile := PlayerProfile.new()
	profile.day = 12
	var phone := PhonePanel.new(profile)
	add_node(phone)
	expect(phone.find_child("App_radio", true, false) != null, "an app for it")
	phone.open_app("radio")
	expect(phone.find_child("Request", true, false) != null, "today's request")
	for id: String in Songs.ids():
		expect(phone.find_child("Song_" + id, true, false) != null, "%s is on the playlist" % id)
	expect(phone.find_child("OnAir", true, false) == null, "nothing on air yet")
	expect(phone.play_radio("roast"), "plays")
	expect(phone.radio.playing() and SongPlayer.active == phone.radio, "the roast is on")
	expect(phone.find_child("OnAir", true, false) != null, "on air")
	phone.radio.time = Songs.line_start("roast", 2) - 0.01
	phone.radio.tick(0.05)
	phone._process(0.0)
	expect_equal((phone.find_child("Now", true, false) as Label).text, Songs.lines("roast")[2]["text"], "the words as it plays")
	phone._radio_pressed("roast", {})
	expect(not phone.radio.playing(), "tapping it again stops it")
	phone.play_radio("night")
	phone.ring({"id": "test_call", "from": "mum", "lines": []})
	expect(not phone.radio.playing(), "a call stops the radio")
	phone.call_phase = "ended"
	phone.play_radio("dal")
	phone.close()
	expect(SongPlayer.active == null, "putting the phone away stops it")
	var request := Songs.request_for(profile)
	expect_equal(request, Songs.request_for(profile), "the same request all day")


func test_every_line_in_the_feelings_and_songs_has_a_recording() -> void:
	if not VoiceBank.has_lines():
		return
	var missing := []
	var lines := Feelings.cast_lines()
	for id: String in Songs.ids():
		for line: Dictionary in Songs.lines(id):
			lines.append({"who": str(line["say"]), "text": str(line["text"])})
	for request: Dictionary in Songs.requests():
		lines.append({"who": str(request["say"]), "text": str(request["text"]).replace("{called}", "Doctor")})
	for line: Dictionary in lines + Feelings.patient_lines():
		if VoiceBank.find(str(line["who"]), str(line["text"])).is_empty():
			missing.append("%s: %s" % [line["who"], line["text"]])
	expect(missing.is_empty(), "every line is recorded; missing e.g. %s" % [missing.slice(0, 5)])
