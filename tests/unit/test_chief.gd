extends TestCase
## The Chief's days (Day 29 on): the casebook, the hard calls, the
## hospital's standing, the endless generated days that keep getting
## harder (and never run the same week twice: events, walk-ins, fourteen
## calls), and the hooks that end every day.

const CAREFUL := ["Warm", "Patient", "Kind", "Calm", "Listen", "Gentle", "Sorry", "Promote", "Everything", "Town",
	"Staff", "Support", "Ask", "Explain", "Together", "Truth", "Patients", "Families"]
const BEFORE := ["op_rohit_done", "op_rohit_won", "promoted", "beds_saved", "rider_treated", "jump_9", "op_raju_won",
	"jump_14", "op_gomes_won", "jump_19", "op_kurup_won", "candour_together", "jump_24", "strike_backed",
	"sinha_together", "hos_iyer"]
## The old patients each casebook operation was written for.
const OLD_NAMES := {"wound": ["Deepa", "Rawat"], "appendix": ["Rohit", "Kulkarni"], "hernia": ["Raju", "Yadav"],
	"spleen": ["Imran"], "hip": ["Gomes", "Philomena"], "bile_leak": ["Sinha", "Rekha"], "gallbladder": ["Farida", "Ansari"]}


func _doctor(day: int, flags: Array = []) -> PlayerProfile:
	var doctor := PlayerProfile.new()
	doctor.name = "Asha Verma"
	doctor.day = day
	doctor.opening_seen = true
	doctor.created = true
	doctor.total_xp = LevelCurve.total_xp_to_reach(Rank.FIRST_LEVELS[Rank.CHIEF]) + 400
	doctor.rank_held = Rank.CHIEF
	for flag: String in BEFORE + flags:
		doctor.set_flag(flag)
	return doctor


func _ward(day: int, flags: Array = []) -> Ward:
	return add_node(Ward.new(_doctor(day, flags))) as Ward


func _play_day(ward: Ward, tones: Array = CAREFUL, quality: String = "good") -> bool:
	var finished := [false]
	ward.day_finished.connect(func() -> void: finished[0] = true)
	var bot := AutoPlayer.new()
	bot.quality = quality
	return ward.play_until(func() -> bool: return finished[0], Ward.pick_tones(tones), bot, 1800.0)


# --- Playing the days --------------------------------------------------------

func test_the_first_morning_as_chief_brings_mrs_banerjee_back() -> void:
	var ward := _ward(29)
	expect(not WardStory.DAYS.has(29), "the written story is over")
	expect_equal(ward.beats[0]["talk"], "cb_banerjee_morning")
	expect(_play_day(ward), "the day ends")
	for flag: String in ["cb_banerjee_history_done", "op_banerjee_done"]:
		expect(ward.profile.has_flag(flag), flag)
	expect(Standing.started(ward.profile), "the hospital's standing is counted from the first day")
	var card := ward.overlay.end_card_lines()
	expect(card.size() >= 2, "the day ends on a card with a hook (%s)" % [card])
	expect(" ".join(card).contains("Tomorrow"), "and a line about tomorrow")


func test_a_generated_day_in_a_later_tier_plays_to_the_end() -> void:
	var ward := _ward(47)
	expect_equal(ChiefDays.tier(47), 1)
	var ids: Array = ward.beats.map(func(b: Dictionary) -> String: return str(b["id"]))
	expect("sim" in ids and "call" in ids, "a simulator case and a hard call (%s)" % [ids])
	expect(_play_day(ward), "the day ends")
	expect(ward.profile.has_flag("op_sim_done"), "the simulator case was operated")
	expect(ward.profile.count("chief_days") == 1, "one more day in the chair")


func test_a_board_day_reports_on_the_hospital() -> void:
	var ward := _ward(38)
	expect(ChiefDays.is_report_day(38))
	expect_equal(ward.beats[ward.beats.size() - 1]["id"], "report", "the report is the day's last beat")
	expect(_play_day(ward), "the day ends")
	var verdicts := ["board_strong", "board_mixed", "board_poor"].filter(func(f: String) -> bool:
		return ward.profile.has_flag(f))
	expect_equal(verdicts.size(), 1, "the board gives one verdict")
	expect_equal(ward.profile.count("reports"), 1)


# --- The generator, for ever ---------------------------------------------------

func test_every_day_for_two_thousand_days_is_built_from_real_pieces() -> void:
	var cast := StoryBook.cast()
	var chief := StoryBook.chapter("chief")
	var cases := StoryBook.chapter("cases")
	var doctor := _doctor(29)
	for day in range(ChiefDays.FIRST_DAY, 2000):
		doctor.day = day
		var beats := ChiefDays.beats(doctor, day)
		expect(beats.size() >= 3, "Day %d has a morning, work and a call" % day)
		for beat: Dictionary in beats:
			var talk := str(beat.get("talk", ""))
			expect(chief.has(talk), "Day %d: %s is written" % [day, talk])
			for name in ["after", "brief"]:
				if beat.has(name):
					expect(chief.has(str(beat[name])), "Day %d: %s is written" % [day, beat[name]])
			expect(cast.has(str(beat.get("with", ""))), "Day %d: %s is in the cast" % [day, beat.get("with", "")])
			for task: Array in beat.get("tasks", []):
				if str(task[0]) == "operate":
					expect(not Procedures.get_procedure(str(task[1])).is_empty(), "Day %d: %s exists" % [day, task[1]])
				else:
					expect(cases.has(str(task[1])), "Day %d: case %s exists" % [day, task[1]])
		expect(not ChiefDays.day_line(doctor, day).is_empty(), "Day %d has a line on its card" % day)
		expect(not ChiefDays.end_line(doctor, day).is_empty(), "Day %d has a last line" % day)
		expect(ChiefDays.teaser(doctor, day + 1).begins_with("Tomorrow") or ChiefDays.teaser(doctor, day + 1).begins_with("From tomorrow"),
			"Day %d ends with a reason to play Day %d" % [day, day + 1])


func test_the_days_keep_getting_harder_and_never_level_off_early() -> void:
	var doctor := _doctor(29)
	Standing.start(doctor)
	var last := 0.0
	for day in range(29, 400):
		var level := ChiefDays.intensity(doctor, day)
		expect(level >= last, "Day %d is no gentler than the day before" % day)
		last = level
	expect_near(ChiefDays.intensity(doctor, 400), ChiefDays.MOST_INTENSE, 0.001, "it reaches the hardest the theatre can be")
	expect(ChiefDays.intensity(doctor, 60) > ChiefDays.intensity(doctor, 43), "still rising after the first month")
	expect_equal(ChiefDays.tier(45), 0)
	expect_equal(ChiefDays.tier(46), 1)
	expect_equal(ChiefDays.tier(136), 10)
	expect(ChiefDays.tier_starts(46) and ChiefDays.tier_starts(56) and not ChiefDays.tier_starts(50))
	expect("easy" in ChiefDays.puzzle_levels(40), "tier 0 still has easy puzzles")
	expect(not "easy" in ChiefDays.puzzle_levels(46), "tier 1 has none")
	expect_equal(ChiefDays.puzzle_levels(70), ["extreme"], "then only the hardest")
	expect_equal(ChiefDays.sim_levels(50), ["extreme"])
	expect(ChiefDays.board_bar(70) > ChiefDays.board_bar(50), "the board expects more")
	expect(ChiefDays.drift(100) > ChiefDays.drift(40), "and the hospital loses more ground each morning")
	# Busy days: none at first, then more of them each tier.
	var busy := [0, 0, 0]
	for day in range(36, 46):
		busy[0] += int(ChiefDays.busy_day(doctor, day))
	for day in range(46, 66):
		busy[1] += int(ChiefDays.busy_day(doctor, day))
	for day in range(126, 146):
		busy[2] += int(ChiefDays.busy_day(doctor, day))
	expect_equal(busy[0], 0, "no busy days in the first tier")
	expect(busy[2] > busy[1], "more busy days later on (%s)" % [busy])
	var weights := DayHooks.level_weights(29)
	for day in range(30, 120):
		var next := DayHooks.level_weights(day)
		expect(int(next["extreme"]) >= int(weights["extreme"]), "Day %d's cases are no gentler" % day)
		weights = next


func test_a_busy_day_brings_a_rota_and_a_crash() -> void:
	var doctor := _doctor(29)
	var found := 0
	for day in range(46, 300):
		if not ChiefDays.busy_day(doctor, day):
			continue
		var ids: Array = ChiefDays.beats(doctor, day).map(func(b: Dictionary) -> String: return str(b["id"]))
		expect("rota" in ids and "triage" in ids, "Day %d: both puzzles (%s)" % [day, ids])
		found += 1
		if found >= 5:
			break
	expect(found >= 5, "busy days come")


func test_calls_never_come_round_within_a_week_and_simulator_cases_never_repeat() -> void:
	for doctor_name: String in ["Asha Verma", "Kiran Rao"]:
		var doctor := _doctor(29)
		doctor.name = doctor_name
		var seen := {}
		for day in range(39, 1500):
			var call := ChiefDays.call_for(doctor, day)
			for back in range(1, ChiefDays.CALL_GAP + 1):
				if day - back >= 39:
					expect(ChiefDays.call_for(doctor, day - back) != call, "%s, Day %d: %s came up %d days ago" % [doctor_name, day, call, back])
			seen[call] = true
		expect_equal(seen.size(), ChiefDays.ROUNDS_CALLS.size(), "every recurring call comes round")
		expect_equal(ChiefDays.ROUNDS_CALLS.size(), 14)
		for day in range(37, 1500):
			expect(ChiefDays.sim_for(doctor, day) != ChiefDays.sim_for(doctor, day - 1), "Day %d's simulator case is new" % day)
	# Every recurring call is written, in three versions, with flags to clear.
	var chief := StoryBook.chapter("chief")
	for call: String in ChiefDays.ROUNDS_CALLS:
		expect(chief.has("hc_" + call), "%s is written" % call)
		expect_equal((ChiefDays.CALL_FLAGS[call] as Array).size(), 3, call)
		expect(ChiefDays.CALLS[call].has("teaser"), "%s has a teaser" % call)
		var text := JSON.stringify(chief["hc_" + call])
		for flag: String in ChiefDays.CALL_FLAGS[call]:
			expect(text.contains(flag), "%s sets %s" % [call, flag])


# --- Weekly events ---------------------------------------------------------------

func test_weeks_bring_the_rains_a_festival_and_an_outbreak_never_twice_running() -> void:
	for doctor_name: String in ["Asha Verma", "Kiran Rao", "Mei Lin"]:
		var doctor := _doctor(29)
		doctor.name = doctor_name
		for day in range(36, 43):
			expect_equal(ChiefDays.event_for(doctor, day), "", "the first week is ordinary")
		var first := {}
		for week in range(1, 5):
			first[ChiefDays.event_for(doctor, 36 + 7 * week)] = true
		expect_equal(first.size(), 4, "%s: the first four weeks bring all three events and one ordinary week" % doctor_name)
		var last := ""
		var counts := {}
		for week in range(1, 300):
			var day := 36 + 7 * week
			var event := ChiefDays.event_for(doctor, day)
			for offset in 7:
				expect_equal(ChiefDays.event_for(doctor, day + offset), event, "an event lasts its whole week")
			expect(event != last, "%s, week %d: %s two weeks running" % [doctor_name, week, event])
			expect_equal(ChiefDays.event_starts(doctor, day), not event.is_empty())
			expect(not ChiefDays.event_starts(doctor, day + 1))
			counts[event] = int(counts.get(event, 0)) + 1
			last = event
		for event: String in ["", "monsoon", "festival", "outbreak"]:
			expect(int(counts.get(event, 0)) > 50, "%s comes round (%s)" % [event, counts])


func test_an_events_week_changes_the_puzzles_the_mornings_and_the_evenings() -> void:
	var doctor := _doctor(29)
	var chief := StoryBook.chapter("chief")
	var seen := {}
	for day in range(43, 600):
		var event := ChiefDays.event_for(doctor, day)
		if event.is_empty() or not ChiefDays.walkin_for(doctor, day).is_empty():
			continue
		var beats := ChiefDays.beats(doctor, day)
		var tasks := {}
		for beat: Dictionary in beats:
			for task: Array in beat.get("tasks", []):
				tasks[str(task[0])] = str(task[1])
			if str(beat["id"]) in ["rota", "triage"]:
				expect_equal(str(beat["talk"]), str(ChiefDays.EVENTS[event]["talks"][beat["id"]]), "Day %d: the %s week's own words" % [day, event])
		match event:
			"outbreak":
				expect_equal(tasks.get("rota", ""), "outbreak_rota", "Day %d: the outbreak's rota" % day)
				if not ChiefDays.busy_day(doctor, day):
					expect(not tasks.has("triage"), "Day %d: no crash in an outbreak, only the bug" % day)
			"festival":
				if tasks.has("triage"):
					expect_equal(tasks["triage"], "festival_triage", "Day %d: the festival grounds" % day)
			"monsoon":
				if tasks.has("triage"):
					expect_equal(tasks["triage"], "chief_triage", "Day %d: the highway, in the rain" % day)
		seen[event + ":" + ChiefDays.rounds_puzzle(doctor, day)] = true
		expect(ChiefDays.day_line(doctor, day).begins_with(str(ChiefDays.EVENTS[event]["title"])) or ChiefDays.is_milestone(day),
			"Day %d's card names the week: %s" % [day, ChiefDays.day_line(doctor, day)])
	for want: String in ["monsoon:triage", "monsoon:rota", "festival:triage", "festival:rota", "outbreak:rota"]:
		expect(seen.has(want), "%s happens (%s)" % [want, seen.keys()])
	# Crashes come more often in the rains than in an ordinary week.
	var crashes := {"": 0, "monsoon": 0}
	for day in range(43, 800):
		var event := ChiefDays.event_for(doctor, day)
		if crashes.has(event):
			crashes[event] += int(ChiefDays.rounds_puzzle(doctor, day) == "triage")
	expect(crashes["monsoon"] > crashes[""], "%s" % [crashes])
	# The evening before, the teaser warns of it; the morning knows.
	for day in range(43, 200):
		if ChiefDays.event_starts(doctor, day) and ChiefDays.patient_today(doctor, day).is_empty():
			var event := ChiefDays.event_for(doctor, day)
			expect(ChiefDays.teaser(doctor, day).contains(str(ChiefDays.EVENTS[event]["coming"])), ChiefDays.teaser(doctor, day))
	var morning := JSON.stringify(chief["rounds_morning"])
	for event: String in ChiefDays.EVENTS:
		expect(morning.contains("event_starts&event_" + event), "the morning opens the %s week" % event)
		expect(chief.has(str(ChiefDays.EVENTS[event]["talks"]["rota"])) and chief.has(str(ChiefDays.EVENTS[event]["talks"]["triage"])))
		expect(ChiefDays.EVENT_DAY_ENDS.has(event))


func test_an_events_week_costs_its_meter_every_morning_once() -> void:
	var doctor := _doctor(29)
	var day := 43
	while ChiefDays.event_for(doctor, day) != "outbreak":
		day += 1
	doctor.day = day
	Standing.start(doctor)
	var before := Standing.value(doctor, "staff")
	ChiefDays.prepare(doctor, day)
	var lost := 1 + (ChiefDays.drift(day) if ChiefDays.drift_meter(day) == "staff" else 0)
	expect_equal(Standing.value(doctor, "staff"), before - lost, "the outbreak costs the staff")
	expect(doctor.has_flag("event_outbreak") and not doctor.has_flag("event_monsoon"))
	ChiefDays.prepare(doctor, day)
	expect_equal(Standing.value(doctor, "staff"), before - lost, "only once a day")


func test_the_festival_crash_and_the_outbreak_rota_always_roll_a_fair_puzzle() -> void:
	for level: String in RotaTask.LEVELS:
		for with_seed in range(1, 41):
			var rota := RotaTask.new("outbreak_rota", with_seed, level)
			expect_equal(rota.patients.size(), RotaTask.COUNTS[level], "%s outbreak rota %d is full" % [level, with_seed])
			expect(not rota.solution.is_empty(), "%s outbreak rota %d can be done" % [level, with_seed])
			var bug := rota.patients.filter(func(p: Dictionary) -> bool: return bool(p["infectious"]))
			expect(bug.size() >= 2, "%s outbreak rota %d is full of the bug" % [level, with_seed])
			expect_equal(rota.title(), "Outbreak cover")
			var crash := TriageTask.new("festival_triage", with_seed, level)
			var colours := {}
			for casualty in crash.casualties:
				colours[casualty["truth"]] = true
			expect(colours.has("red") and colours.has("yellow") and colours.has("green"),
				"%s festival crash %d needs sorting (%s)" % [level, with_seed, colours.keys()])


# --- Walk-ins ----------------------------------------------------------------------

func test_eight_walk_ins_come_every_fourth_day_then_join_the_simulator() -> void:
	for doctor_name: String in ["Asha Verma", "Kiran Rao"]:
		var doctor := _doctor(29)
		doctor.name = doctor_name
		var order := ChiefDays.walkins(doctor)
		expect_equal(order.size(), 8)
		var met := {}
		for day in range(36, 120):
			var id := ChiefDays.walkin_for(doctor, day)
			if id.is_empty():
				continue
			expect_equal((day - ChiefDays.WALKIN_FROM) % ChiefDays.WALKIN_EVERY, 0, "Day %d" % day)
			expect(not met.has(id), "%s comes once" % id)
			met[id] = day
			expect_equal(ChiefDays.walkin_day(doctor, id), day)
			expect(not ChiefDays.busy_day(doctor, day), "Day %d isn't also a busy day" % day)
			var ids: Array = ChiefDays.beats(doctor, day).map(func(b: Dictionary) -> String: return str(b["id"]))
			expect("patient" in ids and "op" in ids and "call" in ids, "Day %d: admitted, operated, a call (%s)" % [day, ids])
			expect(not "sim" in ids, "Day %d: no simulator on a walk-in day" % day)
			var op: Dictionary = ChiefDays.beats(doctor, day).filter(func(b: Dictionary) -> bool: return str(b["id"]) == "op")[0]
			for level: String in op["levels"]:
				expect(level in ChiefDays.CASEBOOK[id]["levels"], "%s: %s is a level the operation has" % [id, level])
			expect(ChiefDays.teaser(doctor, day).contains(str(ChiefDays.CASEBOOK[id]["teaser"])), ChiefDays.teaser(doctor, day))
		expect_equal(met.size(), 8, "%s meets all eight (%s)" % [doctor_name, met])
		# In the simulator only after their own day.
		for day in range(36, 400):
			var sim := ChiefDays.sim_for(doctor, day)
			if met.has(sim):
				expect(day > int(met[sim]), "%s is in the simulator on Day %d, after Day %d" % [sim, day, met[sim]])
		var later := {}
		for day in range(70, 400):
			later[ChiefDays.sim_for(doctor, day)] = true
		expect_equal(later.size(), ChiefDays.CASEBOOK.size(), "every case comes round in the simulator")


func test_a_walk_in_day_plays_to_the_end() -> void:
	var doctor := _doctor(29)
	var day := ChiefDays.WALKIN_FROM
	var id := ChiefDays.walkin_for(doctor, day)
	var ward := _ward(day)
	expect_equal(ChiefDays.walkin_for(ward.profile, day), id)
	expect(_play_day(ward), "the day ends")
	for flag: String in ["cb_%s_history_done" % id, "op_%s_done" % id]:
		expect(ward.profile.has_flag(flag), flag)
	expect(ward.profile.has_flag("walkin_today"))
	expect(not ward.profile.has_flag("op_sim_done"), "no simulator today")


func test_a_wrong_age_on_the_board_names_the_right_patient() -> void:
	for id: String in ChiefDays.CASEBOOK:
		var entry: Dictionary = ChiefDays.CASEBOOK[id]
		var made := Procedures.for_patient(Procedures.get_procedure(str(entry["procedure"])), ChiefDays.casebook_setup(id))
		var row: Dictionary = made["timeout"][0]
		if row.has("wrong_note"):
			expect(str(row["wrong_note"]).contains(str(entry["age"])) and str(row["wrong_note"]).contains(str(entry["wrong_age"])),
				"%s: %s" % [id, row["wrong_note"]])


func test_the_complaints_desk_shows_a_different_family_each_time() -> void:
	var withs := {}
	for day in [40, 41, 42]:
		var beat := ChiefDays._call_beat("family_complaint", day)
		withs[str(beat["with"])] = true
		expect(str(beat["put"][1][0]).begins_with("relative_"), "the family stands at the desk")
	expect_equal(withs.size(), 3)


func test_report_days_and_milestones() -> void:
	for day in [33, 38, 43, 48, 103]:
		expect(ChiefDays.is_report_day(day), "Day %d is a board day" % day)
	expect(not ChiefDays.is_report_day(28) and not ChiefDays.is_report_day(34))
	expect_equal(ChiefDays.days_to_report(34), 4)
	for day in [50, 75, 100, 150, 200, 1000]:
		expect(ChiefDays.is_milestone(day), "Day %d is a milestone" % day)
	expect(not ChiefDays.is_milestone(125))
	expect_equal(ChiefDays.next_milestone(76), 100)
	var doctor := _doctor(49)
	expect(ChiefDays.teaser(doctor, 50).begins_with("Tomorrow is Day 50"), ChiefDays.teaser(doctor, 50))
	expect(DayHooks.goal_line(doctor).contains("Day 50 is tomorrow"), DayHooks.goal_line(doctor))


# --- Standing --------------------------------------------------------------------

func test_standing_moves_stays_in_bounds_and_the_board_reads_it() -> void:
	var doctor := _doctor(29)
	Standing.start(doctor)
	expect_equal(Standing.value(doctor, "staff"), Standing.START + 8, "the nurses remember the strike")
	var money := Standing.value(doctor, "money")
	var moved := Standing.change(doctor, {"staff": 200, "money": -10})
	expect_equal(Standing.value(doctor, "staff"), 100, "never above 100")
	expect_equal(moved["money"], [-10, money - 10])
	expect(Standing.describe(moved).contains("Money -10"), Standing.describe(moved))
	expect(doctor.has_flag("staff_high"), "a high meter is a flag the story can read")
	Standing.change(doctor, {"money": -100, "public": -100})
	expect(doctor.has_flag("money_low") and doctor.has_flag("public_low"))
	expect_equal(Standing.verdict(doctor), "poor")
	Standing.change(doctor, {"money": 60, "public": 60})
	Standing.change(doctor, {"staff": 75 - Standing.value(doctor, "staff")})
	expect_equal(Standing.verdict(doctor), "strong", "%s" % Standing.summary(doctor))
	expect_equal(Standing.verdict(doctor, 60), "mixed", "a raised bar turns strong into mixed")


func test_each_morning_loses_a_little_ground_once() -> void:
	var doctor := _doctor(47)
	Standing.start(doctor)
	var meter := ChiefDays.drift_meter(47)
	var before := Standing.value(doctor, meter)
	# This week's event, if it costs the same meter, takes its point too.
	var event := ChiefDays.event_for(doctor, 47)
	var lost := ChiefDays.drift(47) + int(not event.is_empty() and str(ChiefDays.EVENTS[event]["meter"]) == meter)
	ChiefDays.prepare(doctor, 47)
	expect_equal(Standing.value(doctor, meter), before - lost)
	ChiefDays.prepare(doctor, 47)
	expect_equal(Standing.value(doctor, meter), before - lost, "a replayed day doesn't lose it twice")
	expect_equal(doctor.count("chief_days"), 1)


func test_results_and_puzzles_move_the_standing() -> void:
	var doctor := _doctor(40)
	Standing.start(doctor)
	var public := Standing.value(doctor, "public")
	var staff := Standing.value(doctor, "staff")
	ChiefDays.after_operation(doctor, "won", false)
	expect_equal(Standing.value(doctor, "public"), public + 3, "a saved patient earns the town's trust")
	ChiefDays.after_operation(doctor, "failed", true)
	expect_equal(Standing.value(doctor, "staff"), staff - 1)


# --- The casebook ------------------------------------------------------------------

func test_casebook_patients_take_over_the_whole_operation() -> void:
	for id: String in ChiefDays.CASEBOOK:
		var entry: Dictionary = ChiefDays.CASEBOOK[id]
		var procedure := str(entry["procedure"])
		for sim: bool in [false, true]:
			var made := Procedures.for_patient(Procedures.get_procedure(procedure), ChiefDays.casebook_setup(id, sim))
			var text := JSON.stringify(made)
			for old: String in OLD_NAMES[procedure]:
				expect(not text.contains(old), "%s: no trace of %s" % [id, old])
			for swap: Array in entry.get("swaps", []):
				if not str(swap[1]).contains(str(swap[0])):
					expect(not text.contains(str(swap[0])), "%s: '%s' is swapped" % [id, swap[0]])
			expect_equal(made["patient"], entry["patient"])
			var row: Dictionary = made["timeout"][0]
			expect(str(row["reads"]).begins_with(str(entry["patient"])), "%s: the board names them" % id)
			if sim:
				expect_equal(made["theatre"], "Simulation lab")


func test_what_the_patient_said_reaches_the_time_out() -> void:
	var cases := StoryBook.chapter("cases")
	for id: String in ChiefDays.CASEBOOK:
		var history: Dictionary = cases["cb_%s_history" % id]
		var asked := (history["questions"] as Array).map(func(q: Dictionary) -> String: return str(q["id"]))
		for key: String in (ChiefDays.CASEBOOK[id]["op_flags"] as Dictionary):
			var flag := str(ChiefDays.CASEBOOK[id]["op_flags"][key])
			var question := flag.trim_prefix("cb_%s_history_" % id)
			expect(question in asked, "%s: the %s question exists for %s" % [id, question, key])


func test_a_casebook_operation_plays_with_the_new_patient() -> void:
	var setup := {"procedure": "appendix", "difficulty": "hard", "casebook": ChiefDays.casebook_setup("dev"),
		"intensity": 1.4, "allergy_known": true}
	var op := OperationTask.new(7, setup)
	expect_equal(op.procedure["patient"], "Dev Malhotra")
	expect_near(op.intensity(), 1.4)
	expect_equal(OperationTask.new(7, {"procedure": "appendix", "intensity": 9.0}).intensity(), 2.0, "never past the limit")


# --- Hooks -------------------------------------------------------------------------

func test_streaks_are_counted_and_a_lost_patient_softens_tomorrow() -> void:
	var doctor := _doctor(40)
	for i in 3:
		DayHooks.record_operation(doctor, "won")
	expect_equal(doctor.count("op_streak"), 3)
	expect(DayHooks.streak_line(doctor).begins_with("3 operations won in a row"), DayHooks.streak_line(doctor))
	var harder := DayHooks.weights_for(doctor)
	DayHooks.record_operation(doctor, "failed")
	expect_equal(doctor.count("op_streak"), 0)
	expect(DayHooks.streak_line(doctor).contains("ended"), DayHooks.streak_line(doctor))
	var softer := DayHooks.weights_for(doctor)
	expect(int(softer["extreme"]) < int(harder["extreme"]), "a gentler case after a loss")
	doctor.day += 1
	DayHooks.record_operation(doctor, "struggled")
	expect(DayHooks.streak_line(doctor).contains("best run is 3"), "the next day: %s" % DayHooks.streak_line(doctor))


func test_the_end_card_waits_for_a_tap() -> void:
	var overlay := add_node(StoryOverlay.new(_doctor(30))) as StoryOverlay
	var time := overlay.end_card("Day 30", "Dev's appendix is in a jar.", {"streak": "2 operations won in a row",
		"goal": "Board report in 3 days", "tomorrow": "Tomorrow: Tom is on the table."})
	expect(time >= StoryOverlay.END_CARD_MIN)
	expect(overlay.end_card_open())
	expect_equal(overlay.end_card_lines().size(), 3, "%s" % [overlay.end_card_lines()])
	expect(not overlay.skip_end_card(), "too soon: a stray tap doesn't throw it away")
	overlay.tick(StoryOverlay.END_CARD_MIN + 0.1)
	expect(overlay.skip_end_card(), "a tap moves on")
	expect(overlay.card_left() <= StoryOverlay.END_CARD_OUT + 0.01)


func test_every_day_of_the_career_ends_with_a_reason_to_come_back() -> void:
	var doctor := _doctor(1)
	for day in range(1, 120):
		doctor.day = day
		var hooks := DayHooks.end_card(doctor, day)
		expect(not str(hooks["tomorrow"]).is_empty(), "Day %d has a line about tomorrow" % day)
		if day >= 2:
			expect(not str(hooks["goal"]).is_empty(), "Day %d names the next goal" % day)


# --- The puzzles' bigger pools -----------------------------------------------------

func test_tonights_rota_and_the_crash_roll_fresh_every_day() -> void:
	var rosters := {}
	for level: String in RotaTask.LEVELS:
		for with_seed in range(1, 13):
			var rota := RotaTask.new("chief_rota", with_seed, level)
			expect_equal(rota.patients.size(), RotaTask.COUNTS[level], "%s rota %d is full" % [level, with_seed])
			expect(not rota.solution.is_empty(), "%s rota %d can be done" % [level, with_seed])
			var names: Array = rota.patients.map(func(p: Dictionary) -> String: return str(p["id"]))
			names.sort()
			rosters[",".join(names)] = true
			var crash := TriageTask.new("chief_triage", with_seed, level)
			var colours := {}
			for casualty in crash.casualties:
				colours[casualty["truth"]] = true
			expect(colours.has("red") and colours.has("yellow") and colours.has("green"),
				"%s crash %d needs sorting (%s)" % [level, with_seed, colours.keys()])
	expect(rosters.size() >= 30, "the nights differ (%d different wards)" % rosters.size())
