extends TestCase
## The daily hooks (stage 19): the 60-second case, the weekly mystery and
## the badges. Quick cases are rolled from the day's seed, so these tests
## play many seeds at every level; the dates are fixed with
## DailyReward.today_override so the week maths is checked on real days.

const LEVELS := ["easy", "hard", "extreme"]
const SEEDS := 40
## A Thursday, the 19th of November 2026.
const THURSDAY := "2026-11-19"


func _doctor(day: int = 12, rank: int = Rank.JUNIOR_RESIDENT) -> PlayerProfile:
	var doctor := PlayerProfile.new()
	doctor.name = "Asha Verma"
	doctor.day = day
	doctor.opening_seen = true
	doctor.created = true
	doctor.rank_held = rank
	doctor.total_xp = LevelCurve.total_xp_to_reach(Rank.FIRST_LEVELS[rank]) + 50
	return doctor


func _play(task: CrisisTask, right: bool) -> void:
	var guard := 0
	while not task.finished and guard < 20:
		var step := task.current()
		task.choose(str(CrisisTask.right_answer(step) if right else AutoPlayer.crisis_wrong_answer(step)))
		task.confirm()
		guard += 1


func _ids(list: Array) -> Array:
	return list.map(func(entry: Dictionary) -> String: return str(entry["id"]))


func cleanup() -> void:
	DailyReward.today_override = ""
	super.cleanup()


# --- The quick cases ---------------------------------------------------------------------

func test_every_quick_case_builds_at_every_level_with_sound_questions() -> void:
	for case_id: String in QuickCases.IDS:
		var kinds := {}
		for level: String in LEVELS:
			for with_seed in range(1, SEEDS + 1):
				var task := CrisisTask.new(case_id, with_seed, level)
				var at := "%s %s seed %d" % [case_id, level, with_seed]
				expect_equal(task.steps.size(), 3, "%s: three questions" % at)
				expect(task.facts.size() >= 3, "%s: facts on the card" % at)
				expect_equal(task.actor, "iyer", "%s: Dr. Iyer coaches" % at)
				expect(not task.title().is_empty(), "%s: a title" % at)
				for step: Dictionary in task.steps:
					var where := "%s %s" % [at, step["id"]]
					var options := _ids(step["options"])
					expect_equal(str(step["kind"]), "one", "%s: one answer" % where)
					expect(options.size() >= 2, "%s: options" % where)
					var unique := {}
					for option_id: String in options:
						unique[option_id] = true
					expect_equal(unique.size(), options.size(), "%s: options are unique" % where)
					expect(str(step["answer"]) in options, "%s: the answer is an option" % where)
					expect(not str(step["why"]).is_empty(), "%s: explains why" % where)
					for option: Dictionary in step["options"]:
						expect(not str(option["text"]).is_empty(), "%s: option %s has words" % [where, option["id"]])
				kinds[str(task.facts)] = true
		expect(kinds.size() > 6, "%s: differs from seed to seed (%d kinds)" % [case_id, kinds.size()])


func test_right_answers_score_full_marks_and_wrong_ones_nothing() -> void:
	for case_id: String in QuickCases.IDS:
		for level: String in LEVELS:
			for with_seed in range(1, SEEDS + 1):
				var at := "%s %s seed %d" % [case_id, level, with_seed]
				var good := CrisisTask.new(case_id, with_seed, level)
				good.time_total = DailyCase.SECONDS
				_play(good, true)
				expect(good.finished, "%s: finishes" % at)
				expect_equal(good.score(), 100, "%s: right scores 100" % at)
				expect(good.all_right(), "%s: all right" % at)
				expect_equal(good.coach, Crises.line(case_id, "end_all"), "%s: Dr. Iyer's last word" % at)
				var bad := CrisisTask.new(case_id, with_seed, level)
				_play(bad, false)
				expect_equal(bad.score(), 0, "%s: wrong scores 0" % at)
				expect_equal(bad.coach, Crises.line(case_id, "end_none"), "%s: Dr. Iyer is not pleased" % at)


func test_every_quick_line_is_written_and_spoken_by_dr_iyer() -> void:
	var group: Dictionary = Crises.lines().get("quick", {})
	var keys := {"brief_easy": true, "brief_hard": true, "brief_extreme": true, "end_all": true, "end_some": true,
		"end_none": true}
	for case_id: String in QuickCases.IDS:
		for level: String in LEVELS:
			for with_seed in range(1, 10):
				for step: Dictionary in CrisisTask.new(case_id, with_seed, level).steps:
					for which: String in ["right", "wrong", "hint"]:
						keys[str(step[which])] = true
	for key: String in keys:
		var entry: Variant = group.get(key)
		expect(entry is Dictionary, "quick.%s is written" % key)
		if entry is Dictionary:
			expect_equal(str(entry.get("say", "")), "iyer", "quick.%s: Dr. Iyer says it" % key)
			expect(not str(entry.get("text", "")).is_empty(), "quick.%s has words" % key)
			expect(not ("{" in str(entry["text"])), "quick.%s: no placeholders" % key)
	for key: String in group:
		expect(keys.has(key), "quick.%s is used" % key)
	expect_equal(Crises.line("quick_burns", "right"), Crises.line("quick_sugar", "right"), "one set of lines for all six")


func test_the_minute_runs_out_and_locks_what_is_left() -> void:
	var task := CrisisTask.new("quick_heart", 5, "hard")
	task.time_total = DailyCase.SECONDS
	task.choose(str(CrisisTask.right_answer(task.current())))
	task.confirm()
	task.tick(30.0)
	expect(not task.finished, "half a minute in: still going")
	task.tick(31.0)
	expect(task.finished, "the minute is up")
	expect_equal(task.timeouts, 2, "two questions left unanswered")
	expect_equal(task.score(), 33, "one of three right")
	var ran_out := false
	for note: Dictionary in task.notes():
		ran_out = ran_out or "minute ran out" in str(note["text"])
	expect(ran_out, "the notes say the minute ran out")
	var calm := CrisisTask.new("quick_heart", 5, "hard")
	calm.tick(500.0)
	expect(not calm.finished, "no minute without time_total: the crises don't change")


func test_the_rules_are_the_real_ones() -> void:
	for with_seed in range(1, 120):
		var burns := CrisisTask.new("quick_burns", with_seed, "hard")
		var percent := int(str(burns.steps[0]["answer"]).substr(1))
		var kg := int(str(burns.facts[0]).get_slice(", ", 2).get_slice(" ", 0).to_int())
		expect(percent % 9 == 0 and percent > 0, "burns seed %d: the rule of nines (%d%%)" % [with_seed, percent])
		expect_equal(int(str(burns.steps[1]["answer"]).substr(1)), 2 * kg * percent, "burns seed %d: Parkland, half in 8 h" % with_seed)
		var baby := CrisisTask.new("quick_diarrhoea", with_seed, "extreme")
		var months := int(str(baby.facts[0]).get_slice(", ", 1).get_slice(" ", 0).to_int())
		expect_equal(str(baby.steps[2]["answer"]), "z10" if months < 6 else "z20", "diarrhoea seed %d: zinc by age" % with_seed)
		if str(baby.steps[0]["answer"]) == "some":
			var baby_kg := int(str(baby.facts[0]).get_slice(", ", 2).get_slice(" ", 0).to_int())
			expect_equal(str(baby.steps[1]["answer"]), "n%d" % (75 * baby_kg), "diarrhoea seed %d: Plan B 75 ml/kg" % with_seed)
		var heart := CrisisTask.new("quick_heart", with_seed, "extreme")
		var low_bp := "84/56" in str(heart.facts)
		var sildenafil := "sildenafil" in str(heart.facts)
		expect_equal(str(heart.steps[2]["answer"]), "no" if low_bp or sildenafil else "gtn", "heart seed %d: GTN" % with_seed)
		expect_equal(str(heart.steps[1]["answer"]), "clopidogrel" if "aspirin (" in str(heart.facts) else "aspirin",
			"heart seed %d: the first drug" % with_seed)
		if sildenafil:
			expect(str(heart.facts[0]).begins_with("Mr."), "heart seed %d: sildenafil only for the men" % with_seed)


# --- The 60-second case, once a day ----------------------------------------------------------

func test_the_days_case_is_the_same_for_everyone_and_never_twice_running() -> void:
	var seen := {}
	var date := THURSDAY
	var previous := ""
	for index in 120:
		var today := DailyCase.case_for(date)
		expect(today in QuickCases.IDS, "%s: a real case" % date)
		expect(today != previous, "%s: not yesterday's case again" % date)
		expect_equal(DailyCase.case_for(date), today, "%s: the same every time" % date)
		seen[today] = true
		previous = today
		date = _next(date)
	expect_equal(seen.size(), QuickCases.IDS.size(), "every case comes up")


func _next(date: String) -> String:
	var unix := Time.get_unix_time_from_datetime_string(date + "T12:00:00") + 86400
	return Time.get_date_string_from_unix_time(unix)


func test_weekdays_get_harder_towards_the_weekend() -> void:
	expect_equal(DailyCase.level_for("2026-11-16"), "easy", "Monday")
	expect_equal(DailyCase.level_for("2026-11-18"), "easy", "Wednesday")
	expect_equal(DailyCase.level_for(THURSDAY), "hard", "Thursday")
	expect_equal(DailyCase.level_for("2026-11-20"), "hard", "Friday")
	expect_equal(DailyCase.level_for("2026-11-21"), "extreme", "Saturday")
	expect_equal(DailyCase.level_for("2026-11-22"), "extreme", "Sunday")
	var task := DailyCase.make(THURSDAY)
	expect_equal(task.time_total, DailyCase.SECONDS, "one minute on the clock")
	expect_equal(task.difficulty, "hard")
	expect_equal(task.case_id, DailyCase.case_for(THURSDAY))
	expect_equal(str(task.steps), str(DailyCase.make(THURSDAY).steps), "the same questions for every doctor")


func test_a_case_a_day_builds_a_streak_and_pays() -> void:
	var doctor := _doctor()
	var xp := doctor.total_xp
	var monday := DailyCase.make("2026-11-16")
	_play(monday, true)
	var first := DailyCase.record(doctor, monday, "2026-11-16")
	expect_equal(int(first["streak"]), 1)
	expect(bool(first["perfect"]))
	expect_equal(int(first["xp"]), DailyCase.BASE_XP + 50 + DailyCase.PERFECT_XP, "base, half the score, perfect")
	expect_equal(doctor.total_xp, xp + int(first["xp"]))
	expect(DailyCase.played_today(doctor, "2026-11-16"))
	expect(DailyCase.record(doctor, DailyCase.make("2026-11-16"), "2026-11-16").is_empty(), "once a day")
	var tuesday := DailyCase.make("2026-11-17")
	_play(tuesday, false)
	var second := DailyCase.record(doctor, tuesday, "2026-11-17")
	expect_equal(int(second["streak"]), 2, "two days running")
	expect_equal(int(second["xp"]), DailyCase.BASE_XP + DailyCase.STREAK_XP, "a bad case still pays for showing up")
	expect_equal(DailyCase.streak(doctor, "2026-11-18"), 2, "alive the next day")
	expect_equal(DailyCase.streak(doctor, "2026-11-19"), 0, "gone after a missed day")
	var friday := DailyCase.make("2026-11-20")
	_play(friday, true)
	expect_equal(int(DailyCase.record(doctor, friday, "2026-11-20")["streak"]), 1, "starts again from one")
	expect_equal(doctor.count("daily_case_best"), 2, "the best is kept")
	expect_equal(doctor.count("daily_cases"), 3)
	expect_equal(doctor.count("daily_cases_perfect"), 2)


func test_the_case_survives_the_day_being_started_again() -> void:
	var doctor := _doctor()
	doctor.morning = {"day": doctor.day, "total_xp": doctor.total_xp, "counters": {}}
	var task := DailyCase.make(THURSDAY)
	_play(task, true)
	var result := DailyCase.record(doctor, task, THURSDAY)
	expect_equal(int(doctor.morning["total_xp"]), doctor.total_xp, "the morning keeps the XP")
	expect_equal(int(doctor.morning["counters"]["daily_case_date"]), DailyCase.date_number(THURSDAY))
	expect(int(result["xp"]) > 0)


# --- The weekly mystery ------------------------------------------------------------------------

func test_weeks_start_on_monday() -> void:
	expect_equal(WeeklyMystery.weekday("1970-01-05"), 0, "5 January 1970 was a Monday")
	expect_equal(WeeklyMystery.week_of("1970-01-05"), 0)
	expect_equal(WeeklyMystery.week_of("1970-01-04"), -1, "the Sunday before is the week before")
	expect_equal(WeeklyMystery.weekday(THURSDAY), 3)
	var week := WeeklyMystery.week_of("2026-11-16")
	for date: String in ["2026-11-17", "2026-11-18", THURSDAY, "2026-11-20", "2026-11-21", "2026-11-22"]:
		expect_equal(WeeklyMystery.week_of(date), week, "%s is the same week as Monday" % date)
	expect_equal(WeeklyMystery.week_of("2026-11-23"), week + 1, "the next Monday is a new week")
	expect_equal(WeeklyMystery.clues_open("2026-11-16"), 1, "one clue on Monday")
	expect_equal(WeeklyMystery.clues_open(THURSDAY), 4)
	expect_equal(WeeklyMystery.clues_open("2026-11-20"), 5, "five on Friday")
	expect_equal(WeeklyMystery.clues_open("2026-11-22"), 5, "and all weekend")
	expect_equal(WeeklyMystery.opens_on(4), "Friday")


func test_every_mystery_is_whole_and_each_comes_once_before_any_repeats() -> void:
	var all := WeeklyMystery.all()
	expect(all.size() >= 8, "eight mysteries (%d)" % all.size())
	var ids := {}
	for mystery: Dictionary in all:
		var at := str(mystery.get("id", "?"))
		ids[at] = true
		expect(not str(mystery.get("title", "")).is_empty(), "%s: a title" % at)
		expect(not str(mystery.get("patient", "")).is_empty(), "%s: a patient" % at)
		expect(not str(mystery.get("explain", "")).is_empty(), "%s: an explanation" % at)
		expect_equal((mystery.get("clues", []) as Array).size(), WeeklyMystery.CLUES, "%s: five clues" % at)
		var options := _ids(mystery.get("options", []))
		expect(options.size() >= 4, "%s: options" % at)
		expect(str(mystery.get("answer", "")) in options, "%s: the answer is an option" % at)
		for clue: Variant in mystery["clues"]:
			expect(not str(clue).is_empty(), "%s: a clue has words" % at)
	expect_equal(ids.size(), all.size(), "every mystery has its own id")
	var start := WeeklyMystery.week_of(THURSDAY)
	var seen := {}
	for week in range(start, start + all.size()):
		seen[str(WeeklyMystery.for_week(week)["id"])] = true
	expect_equal(seen.size(), all.size(), "a full round before any repeats")


func test_one_guess_a_week_worth_more_on_fewer_clues() -> void:
	expect_equal(WeeklyMystery.xp_for(1), WeeklyMystery.TOP_XP)
	expect_equal(WeeklyMystery.xp_for(5), WeeklyMystery.TOP_XP - 4 * WeeklyMystery.CLUE_COST)
	var doctor := _doctor()
	var mystery := WeeklyMystery.current("2026-11-17")
	var xp := doctor.total_xp
	expect(not WeeklyMystery.guessed(doctor, "2026-11-17"))
	var result := WeeklyMystery.guess(doctor, str(mystery["answer"]), "2026-11-17")
	expect(bool(result["right"]), "the right guess")
	expect_equal(int(result["clues"]), 2, "on Tuesday's two clues")
	expect_equal(int(result["xp"]), WeeklyMystery.xp_for(2))
	expect_equal(doctor.total_xp, xp + WeeklyMystery.xp_for(2))
	expect(WeeklyMystery.guessed(doctor, "2026-11-22"), "guessed for the rest of the week")
	expect(WeeklyMystery.guess(doctor, "anything", "2026-11-20").is_empty(), "no second guess")
	expect(not WeeklyMystery.guessed(doctor, "2026-11-23"), "a new week, a new guess")
	expect_equal(doctor.count("mystery_best"), 2)
	var next := WeeklyMystery.current("2026-11-27")
	var wrong := ""
	for option: Dictionary in next["options"]:
		if str(option["id"]) != str(next["answer"]):
			wrong = str(option["id"])
	var miss := WeeklyMystery.guess(doctor, wrong, "2026-11-27")
	expect(not bool(miss["right"]))
	expect_equal(int(miss["xp"]), 0, "no XP for a wrong guess")
	expect_equal(doctor.count("mysteries_tried"), 2)
	expect_equal(doctor.count("mysteries_solved"), 1)
	expect_equal(doctor.count("mystery_best"), 2, "the best stays")
	expect(str(next["id"]) != str(mystery["id"]), "a different mystery the next week")


# --- Badges ------------------------------------------------------------------------------------

func test_every_badge_is_written_and_has_a_rule_that_can_hold() -> void:
	var ids := {}
	for badge: Array in Badges.ALL:
		var at := str(badge[0])
		ids[at] = true
		expect_equal(badge.size(), 5, "%s: five parts" % at)
		for part in 4:
			expect(not str(badge[part]).is_empty(), "%s: part %d written" % [at, part])
		expect(str((badge[4] as Array)[0]) in ["count", "flag", "day", "rank", "letters", "sharp", "all_crises", "all_quick"],
			"%s: a known rule" % at)
	expect_equal(ids.size(), Badges.ALL.size(), "every badge has its own id")
	expect(Badges.check(_doctor(1, Rank.INTERN)).is_empty(), "a new intern has earned nothing")


func test_badges_are_earned_once_and_kept() -> void:
	var doctor := _doctor(50)
	doctor.set_count("crises", 1)
	var new := Badges.check(doctor)
	expect("first_crisis" in new, "first crisis")
	expect("day_fifty" in new, "Day 50")
	expect(not ("day_hundred" in new))
	expect_equal(Badges.toast_text(["cool_head"]), "Badge: Cool head")
	expect_equal(Badges.toast_text(["a", "b", "c"]), "3 new badges")
	expect_equal(Badges.toast_text([]), "")
	expect(Badges.check(doctor).is_empty(), "nothing new the second time")
	doctor.set_count("op_streak_best", 5)
	expect_equal(Badges.check(doctor), ["steady_five"])
	doctor.set_count("crises", 0)
	expect(Badges.has(doctor, "first_crisis"), "kept even when the count drops")
	doctor.rank_held = Rank.CHIEF
	expect("chief" in Badges.check(doctor))


func test_the_mystery_and_crisis_badges() -> void:
	var doctor := _doctor()
	var mystery := WeeklyMystery.current("2026-11-16")
	WeeklyMystery.guess(doctor, str(mystery["answer"]), "2026-11-16")
	var new := Badges.check(doctor)
	expect("mystery_one" in new and "mystery_sharp" in new, "solved on one clue: both")
	for index in Crises.IDS.size() - 1:
		doctor.set_flag("ever_right_crisis_" + str(Crises.IDS[index]))
	expect(not ("seen_it_all" in Badges.check(doctor)), "not with one kind missing")
	doctor.set_flag("crisis_%s_right" % Crises.IDS[-1])
	expect("seen_it_all" in Badges.check(doctor), "an older career's story flag counts")


# --- On the career map ------------------------------------------------------------------------

func test_the_today_page_plays_the_case_and_takes_the_guess() -> void:
	DailyReward.today_override = THURSDAY
	var doctor := _doctor()
	expect(CareerMap.today_waiting(doctor), "both waiting")
	var map := add_node(CareerMap.new(doctor, "today")) as CareerMap
	expect_equal(map.today_chip.text, "Today · new")
	expect(map.find_child("DailyCase", true, false) != null, "the case card")
	expect(map.find_child("Mystery", true, false) != null, "the mystery card")
	expect(map.find_child("Clue4", true, false) != null, "four clues on Thursday")
	var clue5 := map.find_child("Clue5", true, false)
	expect("Friday" in str((clue5.find_child("Text", true, false) as Label).text), "the fifth opens Friday")
	var view := map.start_daily_case()
	expect(view != null and map.case_view == view, "the case opens")
	expect(map.start_daily_case() == view, "one case at a time")
	map.close()
	expect(is_instance_valid(map) and not map.is_queued_for_deletion(), "can't close the map mid-case")
	var task := view.task as CrisisTask
	view.tick(1.2)
	var clock := view.find_child("Clock", true, false) as Label
	expect(clock.visible, "the minute is on show")
	expect_equal(clock.text, "59 seconds left")
	var guard := 0
	while not task.finished and guard < 10:
		var answer := str(CrisisTask.right_answer(task.current()))
		expect(view.answer_button(answer) != null, "a button for %s" % answer)
		view.pick(answer)
		view.confirm()
		guard += 1
	for frame in 40:
		view.tick(0.1)
	expect(view.result_open(), "the result shows")
	expect(DailyCase.played_today(doctor), "the case is recorded")
	expect_equal(doctor.count("daily_case_score"), 100)
	expect(Badges.has(doctor, "minute_one"), "the first case's badge")
	expect(Badges.has(doctor, "minute_perfect"))
	view.done_pressed.emit()
	expect(map.case_view == null, "back to the career")
	var card := map.find_child("DailyCase", true, false)
	expect("100" in _texts(card), "today's score on the card")
	var mystery := WeeklyMystery.current(THURSDAY)
	var guess := map.find_child("Guess", true, false) as Button
	expect(guess.disabled, "nothing picked yet")
	map.pick_mystery(str(mystery["answer"]))
	expect(not (map.find_child("Guess", true, false) as Button).disabled)
	var result := map.guess_mystery()
	expect(bool(result["right"]), "a right guess")
	expect_equal(int(result["xp"]), WeeklyMystery.xp_for(4))
	expect(map.find_child("Verdict", true, false) != null, "the verdict")
	expect(map.find_child("Guess", true, false) == null, "no second guess")
	expect_equal(map.today_chip.text, "Today", "nothing waits now")
	expect(not CareerMap.today_waiting(doctor))


func test_a_case_left_early_is_handed_in_as_it_stands() -> void:
	DailyReward.today_override = THURSDAY
	var doctor := _doctor()
	var map := add_node(CareerMap.new(doctor, "today")) as CareerMap
	var view := map.start_daily_case()
	view.leave_pressed.emit()
	for frame in 40:
		map._process(0.1)
	expect(view.task.finished, "leaving ends the minute")
	expect(DailyCase.played_today(doctor), "and it counts")
	expect_equal(doctor.count("daily_case_score"), 0)


func test_the_today_page_waits_for_the_ward() -> void:
	DailyReward.today_override = THURSDAY
	var early := _doctor(2, Rank.INTERN)
	expect(not CareerMap.today_waiting(early))
	var map := add_node(CareerMap.new(early, "today")) as CareerMap
	expect(map.find_child("StartCase", true, false) == null, "no case before the ward")
	expect(map.start_daily_case() == null, "and none can start")


func test_the_badges_page_shows_every_badge() -> void:
	var doctor := _doctor(50)
	var map := add_node(CareerMap.new(doctor, "badges")) as CareerMap
	var wall := map.find_child("BadgeWall", true, false)
	expect(wall != null)
	expect_equal(wall.get_child_count(), Badges.ALL.size())
	expect(Badges.has(doctor, "day_fifty"), "opening the page gives what's earned")
	expect("Fifty days" in _texts(wall.find_child("Badge_day_fifty", true, false)), "an earned badge says its line")
	expect("Reach Day 100." in _texts(wall.find_child("Badge_day_hundred", true, false)), "a locked one says how")
	map.show_page("map")
	expect(map.find_child("BadgeWall", true, false) == null or map.find_child("BadgeWall", true, false).is_queued_for_deletion())


func _texts(node: Node) -> String:
	var out := ""
	if node is Label:
		out += (node as Label).text + "\n"
	for child in node.get_children():
		out += _texts(child)
	return out


func test_the_career_button_shows_a_dot_while_today_waits() -> void:
	DailyReward.today_override = THURSDAY
	var doctor := _doctor()
	var hud := add_node(LobbyHud.new(doctor)) as LobbyHud
	expect(hud.today_dot(), "the dot shows while the case and the guess wait")
	var task := DailyCase.make()
	_play(task, true)
	DailyCase.record(doctor, task)
	hud.refresh_letters()
	expect(hud.today_dot(), "still the mystery to guess")
	WeeklyMystery.guess(doctor, "anything")
	hud.refresh_letters()
	expect(not hud.today_dot(), "nothing waits: no dot")
	var intern := add_node(LobbyHud.new(_doctor(2, Rank.INTERN))) as LobbyHud
	expect(not intern.today_dot(), "no dot before the ward")


# --- Stage 20: six more cases, story beats, an earlier start --------------------------------

func test_the_new_cases_follow_the_real_rules() -> void:
	for with_seed in range(1, 150):
		for level: String in LEVELS:
			var at := "seed %d %s" % [with_seed, level]
			var head := CrisisTask.new("quick_head", with_seed, level)
			var gcs := int(str(head.steps[0]["answer"]).substr(1))
			expect(gcs >= 3 and gcs <= 15, "%s: a real score (%d)" % [at, gcs])
			for option: Dictionary in head.steps[0]["options"]:
				var n := int(str(option["id"]).substr(1))
				expect(n >= 3 and n <= 15, "%s: every score offered is possible (%d)" % [at, n])
			var facts := str(head.facts)
			var urgent := gcs < 13 or "three times" in facts or "panda" in facts or "one ear" in facts
			var ct := str(head.steps[1]["answer"])
			expect_equal(ct, "hour" if urgent else ("eight" if "warfarin" in facts else "none"), "%s: the CT rule" % at)
			if gcs <= 8:
				expect_equal(str(head.steps[2]["answer"]), "tube", "%s: 8 or less gets a tube" % at)
			var sepsis := CrisisTask.new("quick_sepsis", with_seed, level)
			var sf := str(sepsis.facts)
			var score := int("26 a minute" in sf) + int("86/50" in sf) + int("nonsense" in sf)
			expect_equal(str(sepsis.steps[0]["answer"]), "n%d" % score, "%s: qSOFA" % at)
			var heat := CrisisTask.new("quick_heat", with_seed, level)
			var stroke := "Confused" in str(heat.facts)
			expect_equal(str(heat.steps[0]["answer"]), "stroke" if stroke else "exhaustion", "%s: heat" % at)
			expect_equal(str(heat.steps[2]["answer"]), "t39" if stroke else "none", "%s: stop cooling at 39" % at)
			var fit := CrisisTask.new("quick_seizure", with_seed, level)
			if "pregnant" in str(fit.facts):
				expect_equal(level, "extreme", "%s: eclampsia only on extreme" % at)
				expect_equal(str(fit.steps[0]["answer"]), "magnesium", "%s: magnesium for eclampsia" % at)
			else:
				expect_equal(str(fit.steps[1]["answer"]), "lorazepam" if "working" in str(fit.facts) else "midazolam",
					"%s: the route follows the line" % at)
			var asthma := CrisisTask.new("quick_asthma", with_seed, level)
			if level == "easy":
				expect(str(asthma.steps[0]["answer"]) != "life", "%s: no life-threatening attack on easy" % at)
			var poison := CrisisTask.new("quick_poison", with_seed, level)
			if "paracetamol" in str(poison.facts):
				expect(level != "easy", "%s: the paracetamol case starts on hard" % at)
				var kg := int(Array(str(poison.facts[0]).split(", "))[-1].get_slice(" ", 0))
				var tablets := int(str(poison.facts[1]).get_slice(" ", 1))
				expect_equal(str(poison.steps[0]["answer"]), "n%d" % (tablets * 500 / kg), "%s: mg per kg" % at)


func test_the_meeting_days_get_a_quick_case_with_the_right_patient() -> void:
	for day: int in [21, 23, 27]:
		var case_id := str(Crises.STORY_DAYS[day])
		expect(case_id.begins_with("quick_"), "day %d has a quick case" % day)
		var doctor := _doctor(day, Rank.SURGEON)
		var beat := Crises.beat(doctor, day)
		expect_equal(str(beat["crisis"]), case_id)
		expect_equal(str(beat["with"]), "iyer")
		for talk: String in ["crisis_%s_arrive" % case_id, "crisis_%s_after" % case_id]:
			expect(not StoryBook.conversation("crises", talk).is_empty(), "%s is written" % talk)
		for with_seed in range(1, 20):
			var story := CrisisTask.new(case_id, with_seed, "hard", {"story": true})
			var who: String = {"quick_heat": "constable", "quick_asthma": "painter", "quick_sepsis": "Mrs. Shanti Kamble"}[case_id]
			expect(who in str(story.facts[0]), "day %d seed %d: the patient the talk names" % [day, with_seed])
			expect_equal(story.time_total, -1.0, "no minute on the ward")


func test_the_today_page_opens_on_day_one_after_meeting_dr_iyer() -> void:
	DailyReward.today_override = THURSDAY
	var first := _doctor(1, Rank.INTERN)
	expect(not CareerMap.today_waiting(first), "not before Dr. Iyer")
	first.set_flag("met_iyer")
	expect(CareerMap.today_waiting(first), "from meeting her on Day 1")
	var map := add_node(CareerMap.new(first, "today")) as CareerMap
	expect(map.find_child("StartCase", true, false) != null, "the case can start on Day 1")
	expect(map.start_daily_case() != null)


func test_varun_writes_on_the_first_evening() -> void:
	var doctor := _doctor(1, Rank.INTERN)
	expect("Varun" in Rival.line(doctor, 1), "a WhatsApp on Day 1")
	expect("Day 4" in Rival.line(doctor, 1), "and when the race starts")
	expect_equal(Rival.line(doctor, 2), "", "then quiet until the race")
	expect("Varun" in str(DayHooks.end_card(doctor, 1)["rival"]))


func test_every_kind_of_quick_case_right_earns_the_casualty_badge() -> void:
	var doctor := _doctor()
	for index in QuickCases.IDS.size() - 1:
		doctor.set_flag("ever_right_" + str(QuickCases.IDS[index]))
	expect(not ("all_quick" in Badges.check(doctor)), "not with one missing")
	var task := CrisisTask.new(str(QuickCases.IDS[-1]), 3, "easy")
	_play(task, true)
	DailyCase.record(doctor, task, THURSDAY)
	expect(doctor.has_flag("ever_right_" + str(QuickCases.IDS[-1])), "a perfect case marks its kind")
	expect("all_quick" in Badges.check(doctor), "all twelve")
	doctor.morning = {"day": doctor.day, "flags": {}}
	doctor.set_count("daily_cases", 29)
	doctor.add_count("daily_cases", 1)
	expect("minute_thirty" in Badges.check(doctor))
	expect(bool((doctor.morning["flags"] as Dictionary).get("badge_minute_thirty", false)), "a badge survives a restarted day")
