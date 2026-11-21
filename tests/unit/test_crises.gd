extends TestCase
## The hospital crises (stage 18): the power cut in theatre, two Ramesh
## Kumars, the family at the door, the family's blood, the insurance form,
## the snakebite, dengue season and the inspection. Every one is rolled from
## a seed, so these tests play many seeds at every level and check that the
## right answers really are right, the rules are the real ones, and the
## coach has a recorded line for everything.

const LEVELS := ["easy", "hard", "extreme"]
const SEEDS := 40


func _doctor(day: int, rank: int = Rank.CHIEF) -> PlayerProfile:
	var doctor := PlayerProfile.new()
	doctor.name = "Asha Verma"
	doctor.day = day
	doctor.opening_seen = true
	doctor.created = true
	doctor.rank_held = rank
	doctor.total_xp = LevelCurve.total_xp_to_reach(Rank.FIRST_LEVELS[rank]) + 300
	return doctor


## Gives a step's answer through the task, the way a player would.
func _answer(crisis: CrisisTask, answer: Variant) -> void:
	match crisis.kind():
		"one":
			crisis.choose(str(answer))
		"each":
			for item_id: String in (answer as Dictionary):
				crisis.assign(item_id, str(answer[item_id]))
		"some":
			for item_id: Variant in (answer as Array):
				crisis.toggle(str(item_id))


func _play(crisis: CrisisTask, right: bool) -> void:
	var guard := 0
	while not crisis.finished and guard < 20:
		var step := crisis.current()
		_answer(crisis, CrisisTask.right_answer(step) if right else AutoPlayer.crisis_wrong_answer(step))
		crisis.confirm()
		guard += 1


func _ids(list: Array) -> Array:
	return list.map(func(entry: Dictionary) -> String: return str(entry["id"]))


# --- Every crisis, every level, many seeds ----------------------------------------------

func test_every_crisis_builds_at_every_level_with_sound_questions() -> void:
	for crisis_id: String in Crises.IDS:
		for level: String in LEVELS:
			for with_seed in range(1, SEEDS + 1):
				var crisis := CrisisTask.new(crisis_id, with_seed, level)
				var at := "%s %s seed %d" % [crisis_id, level, with_seed]
				expect(crisis.steps.size() >= 2, "%s: has steps" % at)
				expect(crisis.facts.size() >= 3, "%s: has facts on the card" % at)
				expect_equal(crisis.actor, str(Crises.ACTORS[crisis_id]), "%s: the right person" % at)
				for step: Dictionary in crisis.steps:
					var where := "%s %s" % [at, step.get("id", "?")]
					expect(not str(step.get("prompt", "")).is_empty(), "%s: a question" % where)
					expect(not str(step.get("why", "")).is_empty(), "%s: explains why" % where)
					match str(step["kind"]):
						"one":
							var options := _ids(step["options"])
							expect(options.size() >= 2, "%s: options" % where)
							expect_equal(options.size(), _as_set(options).size(), "%s: options are unique" % where)
							expect(str(step["answer"]) in options, "%s: the answer is an option" % where)
						"some":
							var items := _ids(step["items"])
							var right: Array = CrisisTask.right_answer(step)
							for item_id: Variant in right:
								expect(str(item_id) in items, "%s: answer %s is on the list" % [where, item_id])
							if step.has("need"):
								expect(right.size() >= int(step["need"]), "%s: enough safe donors" % where)
								expect(right.size() < items.size(), "%s: somebody is unsafe" % where)
							elif step.has("budget"):
								var cost := 0
								for item_id: Variant in right:
									cost += int(step["costs"][item_id])
								expect(cost <= int(step["budget"]), "%s: the best plan fits the time" % where)
							else:
								expect(not right.is_empty(), "%s: something to find" % where)
						"each":
							var items := _ids(step["items"])
							var right: Dictionary = step["answer"]
							expect_equal(right.size(), items.size(), "%s: every item has an answer" % where)
							for choice: Dictionary in step["choices"]:
								if choice.has("limit"):
									expect(right.values().count(str(choice["id"])) <= int(choice["limit"]),
										"%s: the answer keeps to the %s limit" % [where, choice["id"]])


func _as_set(list: Array) -> Dictionary:
	var made := {}
	for entry: Variant in list:
		made[entry] = true
	return made


func test_the_right_answers_score_full_marks_and_wrong_ones_score_nothing() -> void:
	for crisis_id: String in Crises.IDS:
		for level: String in LEVELS:
			for with_seed in range(1, SEEDS + 1):
				var at := "%s %s seed %d" % [crisis_id, level, with_seed]
				var good := CrisisTask.new(crisis_id, with_seed, level)
				_play(good, true)
				expect(good.finished, "%s: finishes" % at)
				expect_equal(good.score(), 100, "%s: right answers score 100" % at)
				expect(good.all_right(), "%s: all right" % at)
				expect_equal(good.coach, Crises.line(crisis_id, "end_all"), "%s: the coach's last word" % at)
				var bad := CrisisTask.new(crisis_id, with_seed, level)
				_play(bad, false)
				expect(bad.finished, "%s: a bad run finishes" % at)
				expect_equal(bad.score(), 0, "%s: wrong answers score nothing" % at)
				expect_equal(bad.wrong_steps().size(), bad.steps.size(), "%s: every step wrong" % at)
				expect_equal(bad.coach, Crises.line(crisis_id, "end_none"), "%s: the coach is not pleased" % at)
				var miss := false
				for note: Dictionary in bad.notes():
					miss = miss or (not bool(note["ok"]) and not str(note["text"]).is_empty())
				expect(miss, "%s: the notes say what went wrong" % at)


func test_the_same_seed_gives_the_same_crisis_and_seeds_differ() -> void:
	for crisis_id: String in Crises.IDS:
		var kinds := {}
		for with_seed in range(1, 30):
			var one := CrisisTask.new(crisis_id, with_seed, "hard")
			var two := CrisisTask.new(crisis_id, with_seed, "hard")
			expect_equal(str(one.facts), str(two.facts), "%s seed %d: same facts" % [crisis_id, with_seed])
			expect_equal(str(one.steps), str(two.steps), "%s seed %d: same questions" % [crisis_id, with_seed])
			kinds[str(one.facts) + str(one.steps)] = true
		expect(kinds.size() > 5, "%s: crises differ from seed to seed (%d kinds)" % [crisis_id, kinds.size()])


func test_every_line_the_coach_can_say_is_written_and_spoken_by_the_right_person() -> void:
	var lines := Crises.lines()
	for crisis_id: String in Crises.IDS:
		var keys := {"brief_easy": true, "brief_hard": true, "brief_extreme": true, "end_all": true, "end_some": true,
			"end_none": true}
		if crisis_id == "inspection":
			keys["over_budget"] = true
		for level: String in LEVELS:
			for with_seed in range(1, SEEDS + 1):
				for step: Dictionary in CrisisTask.new(crisis_id, with_seed, level).steps:
					for which: String in ["right", "wrong", "hint"]:
						keys[str(step[which])] = true
		for key: String in keys:
			var entry: Variant = (lines.get(crisis_id, {}) as Dictionary).get(key)
			expect(entry is Dictionary, "%s.%s is written" % [crisis_id, key])
			if entry is Dictionary:
				expect(not str(entry.get("text", "")).is_empty(), "%s.%s has words" % [crisis_id, key])
				expect_equal(str(entry.get("say", "")), str(Crises.ACTORS[crisis_id]), "%s.%s: who says it" % [crisis_id, key])
				expect(not ("{" in str(entry["text"])), "%s.%s: no placeholders in a coach line" % [crisis_id, key])
		for key: String in (lines.get(crisis_id, {}) as Dictionary):
			expect(keys.has(key), "%s.%s is used somewhere" % [crisis_id, key])
	for crisis_id: String in Crises.IDS:
		for talk: String in ["crisis_%s_arrive" % crisis_id, "crisis_%s_after" % crisis_id]:
			expect(not StoryBook.conversation("crises", talk).is_empty(), "%s is written" % talk)


# --- The rules are the real ones ---------------------------------------------------------

func test_blood_groups_match_the_way_they_really_do() -> void:
	for patient: String in ["O+", "O-", "A+", "A-", "B+", "B-", "AB+", "AB-"]:
		expect(Crises.compatible("O-", patient), "O- gives to %s" % patient)
		expect(Crises.compatible("AB+", patient) == (patient == "AB+"), "AB+ only gives to AB+ (%s)" % patient)
	expect(Crises.compatible("A+", "AB+"))
	expect(Crises.compatible("A-", "A+"))
	expect(not Crises.compatible("A+", "A-"), "Rh-positive blood never goes to a Rh-negative patient")
	expect(not Crises.compatible("A+", "O+"))
	expect(not Crises.compatible("B+", "A+"))
	expect(Crises.compatible("O+", "B+"))


func test_the_donors_picked_are_compatible_and_the_rest_have_a_reason() -> void:
	for level: String in LEVELS:
		for with_seed in range(1, SEEDS + 1):
			var crisis := CrisisTask.new("donors", with_seed, level)
			var step := crisis.steps[0]
			var group := ""
			for fact in crisis.facts:
				if fact.contains(" group: "):
					group = fact.get_slice(": ", 1)
			for item: Dictionary in step["items"]:
				var donor_group := str(item["detail"]).get_slice(" · ", 0)
				var safe := str(item["id"]) in (step["answer"] as Array)
				if safe:
					expect(Crises.compatible(donor_group, group), "%s seed %d: %s can give to %s" % [level, with_seed, donor_group, group])
				else:
					expect(not str(step["reasons"].get(item["id"], "")).is_empty(), "%s seed %d: why %s can't give" % [level, with_seed, item["text"]])


func test_fasting_follows_two_hours_for_clear_fluids_and_six_for_food() -> void:
	var seen := {}
	for level: String in LEVELS:
		for with_seed in range(1, SEEDS + 1):
			var step := CrisisTask.new("ramesh", with_seed, level).steps[2]
			var prompt := str(step["prompt"])
			var expected := ""
			if "black tea at 06:30" in prompt:
				expected = "go"
			elif "water at 07:30" in prompt or "milky chai" in prompt:
				expected = "later"
			elif "wedding dinner at 01:00" in prompt:
				expected = "go"
			expect(not expected.is_empty(), "a drink we know: " + prompt)
			expect_equal(str(step["answer"]), expected, prompt)
			seen[expected + prompt.get_slice(" had ", 1).get_slice(".", 0)] = true
	expect(seen.size() >= 4, "every drink comes up")


func test_the_bands_decide_who_goes_to_theatre() -> void:
	var answers := {}
	for level: String in LEVELS:
		for with_seed in range(1, SEEDS + 1):
			var crisis := CrisisTask.new("ramesh", with_seed, level)
			var answer := str(crisis.steps[1]["answer"])
			answers[level + answer] = true
			if level == "easy":
				expect(answer != "stop", "on easy one man is the right one")
	expect(answers.has("hardstop") and answers.has("extremestop"), "hard and extreme sometimes have a wrong band")


func test_dengue_gives_platelets_to_two_at_most_and_shock_goes_to_hdu() -> void:
	for level: String in LEVELS:
		for with_seed in range(1, SEEDS + 1):
			var step := CrisisTask.new("dengue", with_seed, level).steps[0]
			var answer: Dictionary = step["answer"]
			expect(answer.values().count("plt") <= 2, "two units at most")
			for item: Dictionary in step["items"]:
				var detail := str(item["detail"])
				if "cold hands" in detail:
					expect_equal(answer[item["id"]], "hdu", "shock goes to HDU: " + detail)
				if "black stools" in detail:
					expect_equal(answer[item["id"]], "plt", "bleeding gets platelets: " + detail)
				if "no warning signs" in detail:
					expect_equal(answer[item["id"]], "home", "no warning signs, home: " + detail)
			var crisis := CrisisTask.new("dengue", with_seed, level)
			var items := _ids(crisis.current()["items"])
			for item_id: String in items:
				crisis.assign(item_id, "plt")
			expect(crisis.choice_of(items[2]) != "plt", "a third patient can't have platelets")


func test_the_insurance_form_hides_more_mistakes_on_harder_levels() -> void:
	var counts := {"easy": 2, "hard": 3, "extreme": 4}
	for level: String in LEVELS:
		for with_seed in range(1, SEEDS + 1):
			var crisis := CrisisTask.new("insurance", with_seed, level)
			expect_equal((crisis.steps[0]["answer"] as Array).size(), int(counts[level]), "%s seed %d" % [level, with_seed])
			var covered := str(crisis.steps[1]["answer"])
			var policy := str(crisis.steps[1]["prompt"])
			if "3 weeks ago" in policy:
				expect_equal(covered, "not", "nothing but accidents in the first thirty days")
			if "8 months ago" in policy and "hernia" in policy:
				expect_equal(covered, "not", "a hernia waits two years")
			if "3 years ago" in policy:
				expect_equal(covered, "covered", "three years covers everything here")


func test_the_snakebite_answer_follows_the_signs() -> void:
	for level: String in LEVELS:
		for with_seed in range(1, SEEDS + 1):
			var crisis := CrisisTask.new("snakebite", with_seed, level)
			var signs := " ".join(crisis.facts)
			var kind := str(crisis.steps[0]["answer"])
			if "still liquid" in signs or "not clotted" in signs:
				expect_equal(kind, "haemo", signs)
			elif "eyelids drooping" in signs.to_lower():
				expect_equal(kind, "neuro", signs)
			else:
				expect_equal(kind, "none", signs)
			expect_equal(str(crisis.steps[1]["answer"]), "none" if kind == "none" else "ten", "the dose follows the signs")


func test_the_inspection_plan_puts_safety_first_and_never_hides_anything() -> void:
	for level: String in LEVELS:
		for with_seed in range(1, SEEDS + 1):
			var step := CrisisTask.new("inspection", with_seed, level).steps[0]
			var plan: Array = CrisisTask.right_answer(step)
			for job in ["key", "crash", "register", "oxygen"]:
				expect(job in plan, "%s seed %d: %s is done" % [level, with_seed, job])
			expect(not "hide" in plan and not "paint" in plan, "%s seed %d: no hiding, no painting" % [level, with_seed])
	# The crash cart without its key is worth nothing.
	var step := CrisisTask.new("inspection", 3, "hard").steps[0]
	var safe := ["key", "crash", "register", "oxygen"]
	expect_equal(CrisisTask.plan_value(step, safe), 70, "the must-do jobs")
	expect_equal(CrisisTask.plan_value(step, ["crash", "register", "oxygen"]), 40 - CrisisTask.CRITICAL_MISSED,
		"no key, no crash cart, and that's a must-do job missed")
	expect(CrisisTask.plan_value(step, ["key", "beds", "fire"]) < 0, "pretty beds instead of safety is worse than nothing")


func test_the_power_cut_follows_the_anaesthetic_and_the_kit() -> void:
	for level: String in LEVELS:
		for with_seed in range(1, SEEDS + 1):
			var crisis := CrisisTask.new("power_cut", with_seed, level)
			var card := " ".join(crisis.facts)
			expect_equal(str(crisis.steps[0]["answer"]), "bag" if "ventilator breathes" in card else "talk", card)
			expect_equal(str(crisis.steps[1]["answer"]), "headlamp" if "headlamp charged" in card else "phones", card)
			expect(crisis.dark, "the power cut is played in the dark")
			expect_equal(crisis.steps.size(), 5 if level == "extreme" else 4, "%s: steps" % level)


# --- Hints, clocks and the budget ---------------------------------------------------------

func test_hints_are_free_on_easy_cost_on_hard_and_missing_on_extreme() -> void:
	var easy := CrisisTask.new("ramesh", 4, "easy")
	expect(not easy.hint().is_empty(), "a hint on easy")
	var hard := CrisisTask.new("ramesh", 4, "hard")
	hard.hint()
	_play(hard, true)
	expect_equal(hard.score(), 100 - CrisisTask.HINT_COST, "a hint on hard costs points")
	var extreme := CrisisTask.new("ramesh", 4, "extreme")
	expect(extreme.hint().is_empty(), "no hints on extreme")
	expect_equal(extreme.hints_used, 0)


func test_an_urgent_step_runs_out_of_time_on_hard_but_never_on_easy() -> void:
	var easy := CrisisTask.new("power_cut", 2, "easy")
	easy.tick(200.0)
	expect_equal(easy.step_index, 0, "no clock on easy")
	var hard := CrisisTask.new("power_cut", 2, "hard")
	expect(hard.time_left > 0.0, "a clock on hard")
	hard.tick(CrisisTask.URGENT_TIME["hard"] + 0.5)
	expect_equal(hard.step_index, 1, "time ran out: the step is locked")
	expect_equal(hard.timeouts, 1)
	expect_equal(hard.marks[0], 0.0, "doing nothing is wrong")
	# Something picked when the clock runs out is the answer.
	var extreme := CrisisTask.new("power_cut", 2, "extreme")
	extreme.choose(str(extreme.current()["answer"]))
	extreme.tick(CrisisTask.URGENT_TIME["extreme"] + 0.5)
	expect_equal(extreme.marks[0], 1.0, "the pick counts when the clock runs out")


func test_the_inspection_refuses_jobs_that_dont_fit() -> void:
	var crisis := CrisisTask.new("inspection", 9, "easy")
	var step := crisis.current()
	var budget := int(step["budget"])
	for item: Dictionary in step["items"]:
		crisis.toggle(str(item["id"]))
	expect(crisis.spent() <= budget, "never over %d minutes (%d)" % [budget, crisis.spent()])
	expect_equal(crisis.coach, Crises.line("inspection", "over_budget"), "Grace says it won't fit")


# --- When they come ------------------------------------------------------------------------

func test_each_crisis_comes_once_in_the_story_and_never_on_a_review_day() -> void:
	var doctor := _doctor(10)
	var seen := {}
	for day in range(1, Crises.CHIEF_FROM):
		var crisis := Crises.for_day(doctor, day)
		if crisis.is_empty():
			continue
		if crisis.begins_with("quick_"):
			# A quick casualty case gives a meeting day something to play.
			expect(day in [21, 23, 27], "quick cases only on the meeting days (%d)" % day)
			continue
		expect(not DayHooks.REVIEW_DAYS.has(day), "no crisis on review day %d" % day)
		expect(not seen.has(crisis), "%s comes once in the story" % crisis)
		seen[crisis] = day
	expect_equal(seen.size(), Crises.IDS.size(), "all eight in the story")


func test_the_chiefs_crises_come_every_third_day_all_eight_before_any_repeats() -> void:
	for doctor_name in ["Asha Verma", "Kiran Rao", "Meera Iyer"]:
		var doctor := _doctor(40)
		doctor.name = doctor_name
		var turns: Array = []
		for day in range(Crises.CHIEF_FROM, Crises.CHIEF_FROM + Crises.CHIEF_EVERY * 40):
			var crisis := Crises.for_day(doctor, day)
			if (day - Crises.CHIEF_FROM) % Crises.CHIEF_EVERY == 0:
				expect(not crisis.is_empty(), "day %d has a crisis" % day)
				turns.append(crisis)
			else:
				expect(crisis.is_empty(), "day %d has none" % day)
		for block in turns.size() / Crises.IDS.size():
			var round_of := turns.slice(block * 8, block * 8 + 8)
			expect_equal(_as_set(round_of).size(), 8, "%s: all eight in round %d" % [doctor_name, block])
		for index in range(1, turns.size()):
			expect(turns[index] != turns[index - 1], "%s: never the same crisis twice running" % doctor_name)


func test_a_chiefs_crisis_day_has_the_crisis_before_its_last_beat() -> void:
	var doctor := _doctor(Crises.CHIEF_FROM)
	var day_beats := ChiefDays.beats(doctor, Crises.CHIEF_FROM)
	var ids := _ids(day_beats)
	expect("crisis" in ids, "the crisis is in the day")
	expect(ids.find("crisis") > 0, "not first")
	var after := ids.slice(ids.find("crisis") + 1)
	expect(not after.is_empty(), "something comes after it")
	expect(not "crisis" in _ids(ChiefDays.beats(doctor, Crises.CHIEF_FROM + 1)), "not the day after")


func test_crisis_beats_say_where_who_and_what() -> void:
	var doctor := _doctor(10)
	for day: int in Crises.STORY_DAYS:
		var beat := Crises.beat(doctor, day)
		var crisis := str(Crises.STORY_DAYS[day])
		expect_equal(str(beat["crisis"]), crisis)
		expect_equal(beat["tasks"], [["crisis", crisis]])
		expect(beat.has("go") or beat.has("where"), "%s: somewhere to be" % crisis)
		expect(not str(beat["row"]).is_empty(), "%s: a row on the task list" % crisis)
		for entry: Array in beat["put_end"]:
			expect(str(entry[0]) != "you" and str(entry[1]) == "off", "%s: the others leave after" % crisis)


# --- Played on screen --------------------------------------------------------------------

func _play_view(crisis: CrisisTask, quality: String) -> CrisisView:
	var view := add_node(CrisisView.new(crisis)) as CrisisView
	var bot := AutoPlayer.new()
	bot.quality = quality
	bot.pace = 0.1
	var waited := 0.0
	while not crisis.finished and waited < 90.0:
		bot.step(view, 0.1)
		view.tick(0.1)
		waited += 0.1
	return view


func test_the_bot_plays_every_crisis_on_screen_well_shakily_and_badly() -> void:
	for crisis_id: String in Crises.IDS:
		for level: String in LEVELS:
			var good := CrisisTask.new(crisis_id, 11, level)
			_play_view(good, "good")
			expect(good.finished, "%s %s: the bot finishes" % [crisis_id, level])
			expect_equal(good.score(), 100, "%s %s: played well" % [crisis_id, level])
			var shaky := CrisisTask.new(crisis_id, 11, level)
			_play_view(shaky, "shaky")
			expect_equal(shaky.wrong_steps().size(), 1, "%s %s: shaky slips once" % [crisis_id, level])
			var bad := CrisisTask.new(crisis_id, 11, level)
			_play_view(bad, "bad")
			expect_equal(bad.score(), 0, "%s %s: played badly" % [crisis_id, level])


func test_the_screen_shows_the_question_the_card_and_the_dark() -> void:
	var crisis := CrisisTask.new("power_cut", 5, "extreme")
	var view := add_node(CrisisView.new(crisis)) as CrisisView
	view.tick(0.1)
	var answer := str(crisis.current()["answer"])
	expect(view.answer_button(answer) != null, "a button for every option")
	expect((view.find_child("Dark", true, false) as Control).visible, "the theatre is dark")
	expect((view.find_child("Clock", true, false) as Control).visible, "an urgent step shows its clock")
	expect(not (view.find_child("Hint", true, false) as Control).visible, "no hint button on extreme")
	expect((view.find_child("Confirm", true, false) as Button).disabled, "nothing to confirm yet")
	view.pick(answer)
	expect(not (view.find_child("Confirm", true, false) as Button).disabled, "a pick can be confirmed")
	view.confirm()
	view.tick(0.1)
	expect_equal(crisis.step_index, 1)
	expect(view.answer_button(str(crisis.current()["answer"])) != null, "the next step's buttons")
	var facts := (view.find_child("FactCard", true, false) as Control)
	expect(facts != null and facts.visible, "the card of facts")
	var dengue := CrisisTask.new("dengue", 5, "hard")
	var dengue_view := add_node(CrisisView.new(dengue)) as CrisisView
	dengue_view.tick(0.1)
	var first := str(dengue.current()["items"][0]["id"])
	expect(dengue_view.answer_button(first, "plt") != null, "a choice for every patient")
	dengue_view.assign(first, "home")
	expect_equal(dengue.choice_of(first), "home")
	expect(not (dengue_view.find_child("Dark", true, false) as Control).visible, "the lights are on in the fever ward")


# --- On the ward -----------------------------------------------------------------------------

func _ward(day: int, rank: int, flags: Array = []) -> Ward:
	var doctor := _doctor(day, rank)
	for flag: String in flags:
		doctor.set_flag(flag)
	return add_node(Ward.new(doctor)) as Ward


func _play_ward(ward: Ward) -> bool:
	var finished := [false]
	ward.day_finished.connect(func() -> void: finished[0] = true)
	return ward.play_until(func() -> bool: return finished[0], Callable(), AutoPlayer.new(), 1500.0)


func test_a_story_day_puts_its_crisis_before_the_last_beat_and_plays_to_the_end() -> void:
	var ward := _ward(10, Rank.JUNIOR_RESIDENT)
	var ids := ward.beats.map(func(entry: Dictionary) -> String: return str(entry.get("id", "")))
	expect("crisis" in ids, "Day 10 has its crisis")
	expect_equal(ids.find("crisis"), ids.size() - 3, "just before the last story beat")
	expect_equal(ids[-1], "sign_off", "and the hand over after it")
	var heard := [false]
	var finished := [false]
	ward.day_finished.connect(func() -> void: finished[0] = true)
	var until := func() -> bool:
		heard[0] = heard[0] or (ward.conversation == "crisis_ramesh_arrive" and ward.story.is_playing())
		return finished[0]
	expect(ward.play_until(until, Callable(), AutoPlayer.new(), 1500.0), "Day 10 plays to the end")
	expect(ward.profile.has_flag("crisis_ramesh_done"), "the Ramesh Kumars were sorted out")
	expect(heard[0], "Grace's talk before the crisis was heard")
	expect(ward.profile.has_flag("crisis_ramesh_right"), "the bot got it right")
	expect_equal(ward.profile.count("crises"), 1, "one crisis counted")


func test_the_power_cut_happens_in_theatre_and_everyone_changes_back_after() -> void:
	var ward := _ward(20, Rank.SURGEON)
	var places: Array = []
	var finished := [false]
	ward.day_finished.connect(func() -> void: finished[0] = true)
	var gowned := [false]
	var until := func() -> bool:
		if ward.view is CrisisView:
			if not places.has(ward.place):
				places.append(ward.place)
			gowned[0] = gowned[0] or ward.player.outfit == "theatre"
		return finished[0]
	expect(ward.play_until(until, Callable(), AutoPlayer.new(), 1500.0), "Day 20 plays to the end")
	expect_equal(places, ["theatre"], "the lights go out in theatre")
	expect(gowned[0], "gowned in theatre")
	expect(ward.player.outfit != "theatre", "back in ward clothes")
	expect(ward.profile.has_flag("crisis_power_cut_done"))
