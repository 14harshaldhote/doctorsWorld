extends TestCase
## The career map (stage 17): the road from Intern to the never-ending days,
## the race against Dr. Varun Khanna across town, and the wall of letters
## from the people the doctor looked after.

const SAVE := "user://test_career/save.json"
const WARD_CAREFUL := ["Ready", "Honest", "Reassure", "Ask her", "Check", "Own it", "Calm", "Compromise", "To Aarav",
	"Gentle", "Careful", "Stay", "Patient first", "Answer", "Light", "Ask him", "The facts", "Grateful"]
## The slots that wait for the end of Day 8, and the flags that bring a
## letter to every one of them.
const DAY_EIGHT := ["rohit", "pillai", "aarav", "pooja", "fernandes"]


func _doctor(day: int, flags: Array = [], rank: int = Rank.INTERN) -> PlayerProfile:
	var doctor := PlayerProfile.new()
	doctor.name = "Kiran Rao"
	doctor.day = day
	doctor.opening_seen = true
	doctor.created = true
	doctor.rank_held = rank
	doctor.total_xp = LevelCurve.total_xp_to_reach(Rank.FIRST_LEVELS[rank]) + 300
	for flag: String in flags:
		doctor.set_flag(flag)
	return doctor


func _slot(id: String) -> Dictionary:
	for slot: Dictionary in Letters.slots():
		if str(slot["id"]) == id:
			return slot
	return {}


## Every script and story file except the letters themselves, as one text.
func _everything_else() -> String:
	var text := PackedStringArray()
	for dir: String in ["res://story", "res://game/core", "res://game/world", "res://game/ui", "res://game"]:
		for file: String in DirAccess.get_files_at(dir):
			if (file.ends_with(".json") or file.ends_with(".gd")) and file != "letters.json":
				text.append(FileAccess.get_file_as_string(dir.path_join(file)))
	return "\n".join(text)


# --- The letters ---------------------------------------------------------------

func test_every_letter_is_whole_and_waits_for_a_real_flag() -> void:
	var slots := Letters.slots()
	expect(slots.size() >= 20, "a wall worth filling (%d slots)" % slots.size())
	var everything := _everything_else()
	var ids := {}
	var last_after := 0
	for slot: Dictionary in slots:
		var id := str(slot.get("id", ""))
		expect(not id.is_empty() and not ids.has(id), "a slot with its own id: %s" % id)
		ids[id] = true
		var after := int(slot.get("after", 0))
		expect(after >= 4, "%s arrives once the ward has begun" % id)
		expect(after >= last_after, "the wall is in the order the letters come (%s)" % id)
		last_after = after
		var letters: Array = slot.get("letters", [])
		expect(not letters.is_empty(), "%s holds at least one letter" % id)
		for letter: Dictionary in letters:
			for key: String in ["from", "title", "body"]:
				expect(not str(letter.get(key, "")).strip_edges().is_empty(), "%s has a %s" % [id, key])
			var body := str(letter["body"])
			expect(body.length() > 120 and body.length() < 1400, "%s: a letter, not a note or a novel (%d)" % [id, body.length()])
			expect(not body.replace("{called}", "").contains("{"), "%s has no unknown blanks" % id)
			expect(not body.contains("TODO") and not body.contains("Asha"), "%s is finished" % id)
			for part: String in str(letter.get("when", "")).replace("&", "|").split("|", false):
				var flag := part.trim_prefix("!")
				expect(everything.contains("\"%s\"" % flag) or everything.contains("_%s" % flag.trim_prefix("op_")) \
						or everything.contains(flag), "%s waits for %s, which the story really sets" % [id, flag])


func test_the_first_letter_that_fits_is_the_one_that_comes() -> void:
	var rohit := _slot("rohit")
	var doctor := _doctor(9)
	expect_equal(str(Letters.letter_for(doctor, rohit)["title"]), "The appendix boy writes", "a good operation, a happy boy")
	doctor.set_flag("op_rohit_failed")
	expect(str(Letters.letter_for(doctor, rohit)["title"]).contains("ICU"), "a hard one, a different letter")
	var mehra := _slot("mehra")
	var nobody := _doctor(14)
	expect(Letters.letter_for(nobody, mehra).is_empty(), "Mrs. Mehra only writes if she has a reason")
	expect_equal(Letters.state(nobody, mehra), "none", "her place on the wall stays empty")
	nobody.set_flag("mehra_complaint")
	expect(str(Letters.letter_for(nobody, mehra)["title"]).contains("board"), "and a complaint is a letter too")
	nobody.set_flag("mehra_charmed")
	expect(str(Letters.letter_for(nobody, mehra)["title"]).contains("Tea"), "charm wins over a complaint")


func test_letters_arrive_as_their_day_ends_and_not_before() -> void:
	var doctor := _doctor(8, ["rider_treated", "joseph_asked"])
	for id: String in DAY_EIGHT:
		expect_equal(Letters.state(doctor, _slot(id)), "sealed", "%s is sealed on Day 8" % id)
	var coming := Letters.arriving(doctor, 8)
	expect_equal(coming.map(func(s: Dictionary) -> String: return str(s["id"])), DAY_EIGHT, "five letters as Day 8 ends")
	expect_equal(Letters.post_line(doctor, 8), "Post: 5 letters, one from Rohit Kulkarni. They're on your career map.")
	expect_equal(Letters.post_line(doctor, 7), "", "no post on Day 7")
	expect_equal(Letters.post_line(doctor, 4), "Post: a letter from Mr. Prakash Nair. It's on your career map.")
	doctor.day = 9
	expect_equal(Letters.arrived(doctor).size(), 6, "Mr. Nair's and Day 8's five are on the wall")
	expect_equal(Letters.unread_count(doctor), 6)
	var quiet := _doctor(9)
	expect(Letters.letter_for(quiet, _slot("fernandes")).is_empty(), "Mr. Fernandes writes only if he was asked")
	expect(Letters.letter_for(quiet, _slot("pooja")).is_empty(), "and Pooja only if her father was looked after")
	expect_equal(Letters.arriving(quiet, 8).size(), 3, "so a quieter career gets three")


func test_reading_a_letter_keeps_even_if_the_day_starts_again() -> void:
	var doctor := _doctor(9)
	doctor.begin_day()
	var nair := _slot("nair")
	expect(not Letters.is_read(doctor, nair))
	Letters.mark_read(doctor, nair)
	expect(Letters.is_read(doctor, nair), "read")
	expect_equal(Letters.unread_count(doctor), Letters.arrived(doctor).size() - 1)
	expect(doctor.begin_day(), "the day starts over from its morning")
	expect(Letters.is_read(doctor, nair), "and the letter is still read")
	var back := PlayerProfile.from_dict(doctor.to_dict())
	expect(Letters.is_read(back, nair), "and saved")


func test_the_hundredth_day_letter_uses_the_doctors_name() -> void:
	var doctor := _doctor(101, [], Rank.CHIEF)
	var letter := Letters.letter_for(doctor, _slot("iyer_100"))
	var body := Letters.body(doctor, letter)
	expect(body.contains(doctor.called()), "Dr. Iyer calls the doctor by name")
	expect(not body.contains("{called}"))


# --- The race ----------------------------------------------------------------

func test_the_months_of_the_race_cover_every_day_from_the_ward_on() -> void:
	expect_equal(Rival.stretch_start(4), 4)
	expect_equal(Rival.stretch_end(4), 8, "the first month ends with the review")
	expect_equal(Rival.stretch_start(13), 9)
	expect_equal(Rival.stretch_end(13), 13)
	expect_equal(Rival.stretch_start(28), 28)
	expect_equal(Rival.stretch_end(28), 37)
	expect_equal(Rival.stretch_start(45), 38)
	expect_equal(Rival.stretch_end(1000), 1007)
	for day in range(4, 400):
		var start := Rival.stretch_start(day)
		expect(start <= day and day <= Rival.stretch_end(day), "Day %d is inside its month" % day)
		if day > 4:
			expect(start == Rival.stretch_start(day - 1) or start == day, "months follow on with no gaps (Day %d)" % day)
		var entry := Rival.day_entry(day)
		expect(str(entry[1]).contains("Varun"), "every day he does something")
		expect(Rival.pace(day) >= 250, "and keeps a real pace (Day %d)" % day)


func test_he_runs_a_fair_race_against_a_careful_and_a_careless_doctor() -> void:
	# The probe of real play: a careful doctor earns about 315 a day on the
	# ward and a careless one about 280. Varun must be beatable, and losable.
	var his_month := 0
	for day in range(4, 9):
		his_month += Rival.pace(day) + int(Rival.day_entry(day)[0])
	expect_between(his_month / 5.0, 230.0, 360.0, "his first month (%d)" % his_month)
	for start: int in [9, 14, 19, 24, 28, 38, 48]:
		var total := 0
		var end := Rival.stretch_end(start)
		for day in range(start, end + 1):
			total += Rival.pace(day) + int(Rival.day_entry(day)[0])
		var per_day := float(total) / float(end - start + 1)
		expect_between(per_day, 200.0, 460.0, "a fair pace from Day %d (%d a day)" % [start, int(per_day)])


func test_the_race_starts_on_the_ward_and_counts_once_a_month() -> void:
	var doctor := _doctor(3)
	Rival.begin_day(doctor)
	expect(not Rival.racing(doctor), "no race before the ward")
	expect_equal(doctor.count("rival_from"), 0)
	expect_equal(Rival.line(doctor, 3), "")
	doctor.day = 4
	Rival.begin_day(doctor)
	expect_equal(doctor.count("rival_from"), 4)
	var base := doctor.count("rival_base")
	expect_equal(base, doctor.total_xp)
	doctor.total_xp += 400
	doctor.day = 5
	Rival.begin_day(doctor)
	expect_equal(doctor.count("rival_base"), base, "the month goes on counting")
	expect_equal(Rival.yours(doctor), 400)
	Rival.patient_lost(doctor)
	expect_equal(Rival.his(doctor, 5), Rival.his(_month_from(4), 5) + Rival.LOSS_PUSH, "a lost patient pushes him on")
	expect_equal(Rival.record(doctor), "", "no month settled yet")
	doctor.day = 9
	Rival.begin_day(doctor)
	expect_equal(doctor.count("rival_from"), 9, "a new month")
	expect_equal(doctor.count("rival_losses"), 0, "with a clean slate")
	expect_equal(Rival.yours(doctor), 0)
	expect_equal(doctor.count("rival_lost"), 1, "400 XP in a month he earned more in is a month lost")
	expect_equal(Rival.record(doctor), "Months won: you 0, Varun 1")


func test_a_career_that_joins_the_race_late_races_only_from_then() -> void:
	# A save from before the race existed, opened on Day 7.
	var late := _month_from(7)
	expect_equal(late.count("rival_since"), 7)
	expect_equal(Rival.his(late, 7), Rival.pace(7) + int(Rival.day_entry(7)[0]), "Varun's Days 4 to 6 don't count against you")
	var map := add_node(CareerMap.new(late)) as CareerMap
	var him := map.find_child("HisBar", true, false).find_child("Value", true, false) as Label
	expect_equal(him.text, "+0 XP", "nothing for him yet this morning")
	expect((map.find_child("RivalDay", true, false) as Label).text.contains("motivational"), "and no yesterday to tell")
	late.day = 9
	Rival.begin_day(late)
	expect_equal(Rival.his(late, 9), Rival.pace(9) + int(Rival.day_entry(9)[0]), "the next month is a whole one")


func _month_from(day: int) -> PlayerProfile:
	var doctor := _doctor(day)
	Rival.begin_day(doctor)
	return doctor


func test_the_race_line_says_who_leads_and_when_the_month_ends() -> void:
	var doctor := _month_from(4)
	var his := Rival.his(doctor, 6)
	doctor.day = 6
	doctor.total_xp = doctor.count("rival_base") + his + 300
	var ahead := Rival.line(doctor, 6)
	expect(ahead.contains("300") and ahead.contains("Varun"), "ahead by 300: %s" % ahead)
	expect(not ahead.contains("month ends"), "the month isn't over on Day 6")
	doctor.total_xp = doctor.count("rival_base") + his - 150
	var behind := Rival.line(doctor, 6)
	expect(behind.contains("150") and Rival.BEHIND.any(func(t: String) -> bool: return behind == t % 150), "behind: %s" % behind)
	doctor.total_xp = doctor.count("rival_base") + his + 5
	expect_equal(Rival.line(doctor, 6), Rival.LEVEL, "five XP is neck and neck")
	doctor.day = 8
	doctor.total_xp = doctor.count("rival_base") + Rival.his(doctor, 8) + 3
	expect_equal(Rival.line(doctor, 8), Rival.LEVEL + " The month ends tonight.", "a tie on the last night still says so")
	expect_equal(Rival.title(doctor), "Intern, CarePlus", "he climbs the same ladder")
	doctor.rank_held = Rank.CHIEF
	expect_equal(Rival.title(doctor), "Head of Surgery, CarePlus", "but the Chief's chair went to you")


func test_a_won_month_is_counted_when_the_next_begins() -> void:
	var doctor := _month_from(9)
	doctor.day = 13
	doctor.total_xp = doctor.count("rival_base") + Rival.his(doctor, 13) + 500
	doctor.day = 14
	Rival.begin_day(doctor)
	expect_equal(doctor.count("rival_won"), 1)
	doctor.day = 18
	doctor.total_xp += Rival.his(doctor, 18)
	doctor.day = 19
	Rival.begin_day(doctor)
	expect_equal(doctor.count("rival_tied"), 1, "earning exactly his total is a level month")
	expect_equal(Rival.record(doctor), "Months won: you 1, Varun 0, 1 level")


# --- The map -------------------------------------------------------------------

func test_the_road_shows_where_the_doctor_stands() -> void:
	var intern := _doctor(5)
	var stops := Career.stops(intern)
	expect_equal(stops.size(), Rank.TITLES.size(), "a stop for every rank")
	expect_equal(stops.map(func(s: Dictionary) -> String: return str(s["state"])),
		["here", "locked", "locked", "locked", "locked", "locked"])
	expect(str(stops[1]["line"]).begins_with("Locked."), "a locked stop shows its teaser")
	var surgeon := _doctor(20, [], Rank.SURGEON)
	expect_equal(Career.stops(surgeon).map(func(s: Dictionary) -> String: return str(s["state"])),
		["done", "done", "done", "here", "locked", "locked"])
	expect(not str(Career.stops(surgeon)[0]["line"]).begins_with("Locked."), "a stop passed shows what it was")
	for stop: Dictionary in Career.STOPS:
		expect(str(stop["line"]).length() > 30, "every stop says something")
		if int(stop["rank"]) > Rank.INTERN:
			expect(str(stop["teaser"]).begins_with("Locked."), "and teases what's coming")


func test_the_goals_name_the_next_review_and_level() -> void:
	var intern := _doctor(5)
	intern.total_xp = 300
	var goals := Career.goals(intern)
	var text := " | ".join(goals.map(func(g: Dictionary) -> String: return str(g["text"])))
	expect(text.contains("Review for Junior Resident on Day 8 (in 3 days)"), text)
	expect(text.contains("Level 4 for Junior Resident"), text)
	expect(text.contains("Letters on your wall: 1 of %d" % Letters.slots().size()), text)
	intern.day = 8
	intern.total_xp = LevelCurve.total_xp_to_reach(4) + 10
	intern.set_count("op_streak_best", 3)
	text = " | ".join(Career.goals(intern).map(func(g: Dictionary) -> String: return str(g["text"])))
	expect(text.contains("(today)"), "the review is today: %s" % text)
	expect(text.contains("Level 4 reached"), text)
	expect(text.contains("Best run: 3 operations"), text)
	var chief := _doctor(30, [], Rank.CHIEF)
	text = " | ".join(Career.goals(chief).map(func(g: Dictionary) -> String: return str(g["text"])))
	expect(text.contains("Board report") and text.contains("milestone"), "a Chief has the board to answer to: %s" % text)
	expect(not text.contains("Review for"), "and nobody left to review them")
	expect(Career.endless_line(chief).contains("Day 30"), "the endless days say how far in")
	expect(Career.endless_line(intern).begins_with("Locked."))


func test_the_map_screen_shows_the_road_the_race_and_the_roads_to_come() -> void:
	var doctor := _doctor(6, ["rider_treated"])
	Rival.begin_day(_doctor(4))
	doctor.set_count("rival_from", 4)
	doctor.set_count("rival_base", doctor.total_xp - 500)
	var map := add_node(CareerMap.new(doctor)) as CareerMap
	expect_equal(map.page, "map")
	var here := map.find_children("Here", "Label", true, false)
	expect_equal(here.size(), 1, "exactly one 'You are here'")
	var intern := map.find_child("StopIntern", true, false)
	expect(intern != null and intern.find_child("Here", true, false) != null, "and it's on the Intern stop")
	expect(intern.find_child("Goals", true, false) != null, "with the goals under it")
	expect(map.find_child("StopChief*", true, false) != null, "the road runs to the top")
	expect(map.find_child("StopNeverendingdays", true, false) != null, "and past it")
	var emergency := map.find_child("Emergency", true, false) as Button
	expect(emergency != null and emergency.disabled, "the Emergency road is still being built")
	var surgery := map.find_child("Surgery", true, false) as Button
	expect(surgery != null and not surgery.disabled, "Surgery is open")
	var you := map.find_child("YouBar", true, false).find_child("Value", true, false) as Label
	expect_equal(you.text, "+500 XP", "the doctor's month so far")
	var him := map.find_child("HisBar", true, false).find_child("Value", true, false) as Label
	expect_equal(him.text, "+%d XP" % Rival.his(doctor, 5), "his, up to last night")
	var day := map.find_child("RivalDay", true, false) as Label
	expect(day.text.begins_with("Yesterday: Varun"), day.text)
	expect_equal((map.find_child("Month", true, false) as Label).text, "This month: Days 4 to 8")


func test_the_race_card_between_two_months_and_before_the_ward() -> void:
	var early := add_node(CareerMap.new(_doctor(2))) as CareerMap
	expect((early.find_child("RaceLine", true, false) as Label).text.contains("starts when you reach the ward"))
	expect(early.find_child("YouBar", true, false) == null)
	var between := _doctor(9)
	between.set_count("rival_from", 4)
	between.set_count("rival_won", 1)
	var map := add_node(CareerMap.new(between)) as CareerMap
	expect((map.find_child("RaceLine", true, false) as Label).text.contains("new month"), "between months, a new one is coming")
	expect_equal((map.find_child("Record", true, false) as Label).text, "Months won: you 1, Varun 0")


func test_the_wall_shows_every_slot_and_reading_one_marks_it() -> void:
	var doctor := _doctor(9, ["aarav_battery_found", "rider_treated"])
	var map := add_node(CareerMap.new(doctor, "letters")) as CareerMap
	expect_equal(map.page, "letters")
	expect_equal(map.letters_chip.text, "Letters · 5 new")
	var wall := map.find_child("Wall", true, false)
	expect_equal(wall.get_child_count(), Letters.slots().size(), "a card for every slot")
	var sealed := wall.find_child("Letter_banerjee", false, false) as Button
	expect(sealed.disabled, "Day 9's letters are still sealed")
	var aarav := wall.find_child("Letter_aarav", false, false) as Button
	expect(not aarav.disabled, "Aarav's has come")
	aarav.pressed.emit()
	var reader := map.reader
	expect(reader != null, "a tap opens it")
	var text := reader.page_text()
	expect(text.begins_with("From Aarav, age 6"), text.left(40))
	expect(text.contains("[A drawing in crayon."), "the bracketed bits are shown as written, not eaten as formatting")
	expect(text.contains("BATERY"), "spelling as a six-year-old spells it")
	expect(Letters.is_read(doctor, _slot("aarav")))
	aarav.pressed.emit()
	expect(map.reader == reader, "a second tap doesn't open a second letter")
	reader.close()
	expect(map.reader == null)
	expect_equal(map.letters_chip.text, "Letters · 4 new", "one fewer waiting")
	var again := map.find_child("Wall", true, false).find_child("Letter_aarav", false, false) as Button
	expect(again != null and again.find_child("*", true, false) != null, "the wall is rebuilt")
	var kicker := again.get_child(0).get_child(0) as Label
	expect_equal(kicker.text, "Read")
	map.show_page("map")
	expect(map.find_child("Wall", true, false) == null, "the map page has no wall")
	expect(map.find_child("Race", true, false) != null)


func test_a_slot_nobody_wrote_to_says_so() -> void:
	var doctor := _doctor(14)
	var map := add_node(CareerMap.new(doctor, "letters")) as CareerMap
	var mehra := map.find_child("Letter_mehra", true, false) as Button
	expect(mehra.disabled, "Mrs. Mehra didn't write")
	expect_equal((mehra.get_child(0).get_child(0) as Label).text, "Nobody wrote")


# --- In the game ---------------------------------------------------------------

func test_the_career_button_opens_the_map_and_counts_the_letters() -> void:
	var doctor := _doctor(9)
	var hud := add_node(LobbyHud.new(doctor)) as LobbyHud
	expect_equal(hud.career_badge(), "4", "four letters by Day 9 for this doctor")
	var saves := [0]
	hud.menu_choice.connect(func(choice: String) -> void:
		if choice == "save":
			saves[0] += 1)
	var button := hud.find_child("Career", true, false) as Button
	expect(button != null, "a Career button in the corner")
	expect(hud.find_child("Casebook", true, false) == null, "it took the Casebook's place")
	button.pressed.emit()
	var map := hud.career_map()
	expect(map != null, "it opens the map")
	expect(hud.menu_open(), "and the game waits while it's open")
	button.pressed.emit()
	expect(hud.career_map() == map, "one map at a time")
	map.show_page("letters")
	map.open_letter(_slot("nair")).close()
	map.close_button.pressed.emit()
	expect(hud.career_map() == null, "Back to work closes it")
	expect(not hud.menu_open())
	expect_equal(hud.career_badge(), "3", "one letter read")
	expect_equal(saves[0], 1, "and the game saves what was read")
	for slot: Dictionary in Letters.arrived(doctor):
		Letters.mark_read(doctor, slot)
	hud.refresh_letters()
	expect_equal(hud.career_badge(), "", "no badge when nothing waits")


func test_the_end_card_shows_the_race_and_the_post() -> void:
	var doctor := _month_from(4)
	doctor.day = 8
	doctor.set_flag("rider_treated")
	var hooks := DayHooks.end_card(doctor, 8)
	expect(not str(hooks["rival"]).is_empty(), "a line about Varun")
	expect(str(hooks["rival"]).ends_with("The month ends tonight."))
	expect(str(hooks["post"]).begins_with("Post: 4 letters"), str(hooks["post"]))
	var overlay := add_node(StoryOverlay.new()) as StoryOverlay
	overlay.end_card("Day 8", "Promoted.", hooks)
	var lines := overlay.end_card_lines()
	expect(lines.has(str(hooks["rival"])) and lines.has(str(hooks["post"])), "both on the card: %s" % [lines])
	expect(lines.find(str(hooks["rival"])) < lines.find(str(hooks["post"])), "the race, then the post")
	expect_equal(lines[lines.size() - 1], str(hooks["tomorrow"]), "and tomorrow last")
	var early := DayHooks.end_card(_doctor(2), 2)
	expect_equal(str(early["rival"]), "", "no race on Day 2")
	expect(not str(early["post"]).begins_with("Post:"), "and no letters yet")
	expect_equal(str(early["post"]), PhoneBook.evening_line(_doctor(2), 2), "only who is about to text (stage 23)")


func test_review_day_promotion_is_left_out_of_the_race() -> void:
	var ward := add_node(Ward.new(_doctor(8, ["op_rohit_done", "op_rohit_won", "beds_checked", "banerjee_room",
		"rider_treated", "rider_named", "joseph_asked", "beds_saved"]))) as Ward
	var profile := ward.profile
	expect_equal(profile.count("rival_from"), 4, "Day 8 belongs to the first month")
	# As if the four days before had earned 1,000.
	profile.set_count("rival_base", profile.total_xp - 1000)
	profile.morning["counters"] = profile.counters.duplicate(true)
	var start_xp := profile.total_xp
	var start_base := profile.count("rival_base")
	var finished := [false]
	ward.day_finished.connect(func() -> void: finished[0] = true)
	var seen := [PackedStringArray()]
	var watch := func() -> bool:
		if ward.overlay.end_card_open() and (seen[0] as PackedStringArray).is_empty():
			seen[0] = ward.overlay.end_card_lines()
		return finished[0]
	expect(ward.play_until(watch, Ward.pick_tones(WARD_CAREFUL)), "the review day ends")
	expect_equal(profile.rank(), Rank.JUNIOR_RESIDENT, "promoted")
	var promotion := profile.count("rival_base") - start_base
	expect(promotion >= Ward.REVIEW_XP, "the promotion's XP is set aside (%d)" % promotion)
	var earned := profile.total_xp - start_xp - promotion
	expect_between(earned, 100, 700, "a day's honest work (%d)" % earned)
	expect_equal(Rival.yours(profile), 1000 + earned, "the race counts the work and not the promotion")
	var card_lines: PackedStringArray = seen[0]
	var all := " ".join(card_lines)
	expect(all.contains("Varun") or all.contains("Neck and neck"), "the end card has the race: %s" % [card_lines])
	expect(all.contains("The month ends tonight."), "on the month's last night")
	expect(all.contains("Post: 5 letters"), "and Day 8's post: %s" % [card_lines])


func test_the_map_opens_from_the_ward_and_reading_is_saved() -> void:
	for file: String in ["save.json", "save.json.tmp", "settings.json", "settings.json.tmp", "save.bak1.json", "save.bak2.json", "save.bak3.json", ".install"]:
		if FileAccess.file_exists("user://test_career/" + file):
			DirAccess.remove_absolute("user://test_career/" + file)
	var main := Main.new()
	main.store = SaveStore.new(SAVE)
	main.settings_path = "user://test_career/settings.json"
	add_node(main)
	var doctor := main.profile
	doctor.name = "Kiran Rao"
	doctor.created = true
	doctor.opening_seen = true
	doctor.day = 6
	doctor.total_xp = 700
	for flag: String in ["met_iyer", "day1_iyer", "lab_welcome", "training_done", "op_rohit_done", "op_rohit_won"]:
		doctor.set_flag(flag)
	main.show_ward()
	var ward := main.screen as Ward
	expect(ward != null, "the ward is up")
	expect_equal(doctor.count("rival_from"), 4, "the race is running on Day 6")
	expect_equal(ward.hud.career_badge(), "1", "Mr. Nair's letter waits")
	var map := ward.hud.open_career("letters")
	var waiting := ward._intro_in
	expect(waiting > 0.0, "the day hasn't started its first beat yet")
	for frame in 90:
		ward.update(1.0 / 30.0)
	expect_equal(ward._intro_in, waiting, "the day waits while the map is open")
	expect_equal(ward.conversation, "", "nobody talks behind it")
	map.open_letter(_slot("nair")).close()
	map.close()
	var saved: PlayerProfile = main.store.load_or_start()["profile"]
	expect(Letters.is_read(saved, _slot("nair")), "the save knows the letter was read")
	expect_equal(ward.hud.career_badge(), "")
	for frame in 90:
		ward.update(1.0 / 30.0)
	expect(ward._intro_in < waiting, "and the day goes on once it's closed")
