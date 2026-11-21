extends TestCase
## Reminders on the phone: off until the player says yes, at most one a day
## at the hour they usually play (never at night), silent after a week away,
## always about what's waiting, and handed to the phone in the shape its
## native code reads. A fake (fake_reminders.gd) stands in for the phone.

const FakeReminders := preload("res://tests/unit/fake_reminders.gd")
const FOLDER := "user://test_reminders"
const SETTINGS := FOLDER + "/settings.json"
const SAVE := FOLDER + "/save.json"
## 15 November 2026, 16:30 in India.
const NOW := 1794742800
const IST := 330

var _settings_before: GameSettings = GameSettings.current
var _save_path_before: String = SettingsPanel.save_path
var _backend_before: ReminderBackend = Reminders.backend
var _profile_before: PlayerProfile = Reminders.profile


func _fake(can_send: bool = true) -> FakeReminders:
	GameSettings.current = GameSettings.new()
	SettingsPanel.save_path = SETTINGS
	var fake := FakeReminders.new()
	fake.can_send = can_send
	Reminders.use_backend(fake)
	return fake


func cleanup() -> void:
	super()
	Reminders.use_backend(_backend_before)
	Reminders.profile = _profile_before
	GameSettings.current = _settings_before
	SettingsPanel.save_path = _save_path_before
	for file: String in ["settings.json", "settings.json.tmp", "save.json", "save.json.tmp", "save.bak1.json", "save.bak2.json", "save.bak3.json", ".install"]:
		if FileAccess.file_exists(FOLDER + "/" + file):
			DirAccess.remove_absolute(FOLDER + "/" + file)


func _doctor(day: int) -> PlayerProfile:
	var doctor := PlayerProfile.new()
	doctor.name = "Asha Verma"
	doctor.created = true
	doctor.opening_seen = true
	doctor.day = day
	return doctor


func _on() -> GameSettings:
	var settings := GameSettings.new()
	settings.reminders = true
	return settings


static func _local_hour(at: int, bias: int) -> int:
	return posmod(at + bias * 60, 86400) / 3600


static func _local_day(at: int, bias: int) -> int:
	return floori((at + bias * 60) / 86400.0)


## The first generated day from Day 36 for which test holds.
static func _first_day(doctor: PlayerProfile, test: Callable) -> int:
	for day in range(ChiefDays.ROUNDS_FROM + 1, 600):
		if test.call(day):
			return day
	return -1


# --- Settings -----------------------------------------------------------------

func test_reminders_start_off_and_survive_a_restart() -> void:
	var settings := GameSettings.new()
	expect(not settings.reminders, "reminders start off")
	expect_equal(settings.reminders_asked, 0)
	expect(settings.play_hours.is_empty())
	settings.reminders = true
	settings.reminders_asked = 1
	Reminders.note_play(settings, 21)
	Reminders.note_play(settings, 8)
	DirAccess.make_dir_recursive_absolute(FOLDER)
	expect_equal(settings.save_to(SETTINGS), OK)
	var loaded := GameSettings.load_from(SETTINGS)
	expect(loaded.reminders, "the answer is remembered")
	expect_equal(loaded.reminders_asked, 1)
	expect_equal(loaded.play_hours, [21, 8] as Array[int], "and when the player plays")
	var damaged := GameSettings.from_dict({"reminders": "yes", "reminders_asked": "lots", "play_hours": [99, "x", 7]})
	expect(not damaged.reminders, "nonsense keeps reminders off")
	expect_equal(damaged.reminders_asked, 0)
	expect_equal(damaged.play_hours, [23, 7] as Array[int], "hours are kept to the clock")


func test_reminders_come_at_the_hour_the_player_usually_plays() -> void:
	expect_equal(Reminders.usual_hour([]), Reminders.USUAL_HOUR, "early evening before the game knows")
	expect_equal(Reminders.usual_hour([13, 15, 14]), 14, "the middle of the player's hours")
	expect_equal(Reminders.usual_hour([23, 22, 23, 1]), Reminders.LATEST_HOUR, "night owls get the evening, not midnight")
	expect_equal(Reminders.usual_hour([5, 6, 7]), Reminders.EARLIEST_HOUR, "early birds get mid-morning, not dawn")
	var settings := GameSettings.new()
	for hour in 20:
		Reminders.note_play(settings, hour)
	expect_equal(settings.play_hours.size(), Reminders.KEEP_HOURS, "only the last few sessions count")
	expect_equal(settings.play_hours[settings.play_hours.size() - 1], 19)


# --- The plan -------------------------------------------------------------------

func test_no_reminders_until_the_player_says_yes() -> void:
	expect(Reminders.plan(_doctor(5), GameSettings.new(), NOW, IST).is_empty(), "off means nothing scheduled")
	var unmade := _doctor(1)
	unmade.created = false
	expect(Reminders.plan(unmade, _on(), NOW, IST).is_empty(), "no career, no reminders")
	expect(Reminders.plan(null, _on(), NOW, IST).is_empty())


func test_one_a_day_never_at_night_and_silent_after_a_week() -> void:
	for bias: int in [IST, 0, -300, 600]:
		for hours: Array in [[], [8], [13, 14], [23, 23, 2]]:
			for offset: int in [0, 3 * 3600, 7 * 3600, 11 * 3600, 19 * 3600]:
				var settings := _on()
				for hour: int in hours:
					Reminders.note_play(settings, hour)
				var now := NOW + offset
				var made := Reminders.plan(_doctor(12), settings, now, bias)
				var where := "(bias %d, hours %s, now +%dh)" % [bias, hours, offset / 3600]
				expect_equal(made.size(), Reminders.DAYS_AHEAD.size(), "four reminders " + where)
				var days := {}
				var last := now
				for entry: Dictionary in made:
					var at := int(entry["at"])
					expect(at > last, "soonest first " + where)
					last = at
					expect_between(_local_hour(at, bias), Reminders.EARLIEST_HOUR, Reminders.LATEST_HOUR,
						"never at night " + where)
					days[_local_day(at, bias)] = true
				expect_equal(days.size(), made.size(), "never two on one day " + where)
				expect(int(made[0]["at"]) - now >= 8 * 3600, "nothing within hours of playing " + where)
				expect(int(made[made.size() - 1]["at"]) - now <= 8 * 86400, "and nothing after a week " + where)


func test_the_first_page_is_about_the_day_waiting() -> void:
	for day in range(1, DayHooks.LAST_STORY_DAY + 1):
		expect(Reminders.STORY.has(day), "a page for story Day %d" % day)
	expect(Reminders.today_line(_doctor(3))[1].contains("Rohit"), "Day 3 is Rohit's operation")
	expect(Reminders.today_line(_doctor(26))[1].contains("walk out"), "Day 26 is the strike")
	for day: int in ChiefDays.CASEBOOK_DAYS:
		var said := Reminders.today_line(_doctor(day))
		expect_equal(said, Reminders.CASEBOOK[ChiefDays.CASEBOOK_DAYS[day]], "the casebook patient on Day %d" % day)
	var chief := _doctor(ChiefDays.ROUNDS_FROM)
	expect(Reminders.today_line(chief)[1].contains("hard days start"), "the generated days begin")
	var walkin := _first_day(chief, func(d: int) -> bool: return not ChiefDays.walkin_for(chief, d).is_empty())
	chief.day = walkin
	expect_equal(Reminders.today_line(chief)[1],
		"Today: " + str(ChiefDays.CASEBOOK[ChiefDays.walkin_for(chief, walkin)]["teaser"]), "a stranger walks in")
	var rains := _first_day(chief, func(d: int) -> bool:
		return ChiefDays.event_starts(chief, d) and ChiefDays.walkin_for(chief, d).is_empty())
	chief.day = rains
	var coming := str(ChiefDays.EVENTS[ChiefDays.event_for(chief, rains)]["coming"])
	expect_equal(Reminders.today_line(chief)[1].to_lower(), coming.to_lower(), "a hard week starts")
	expect(Reminders.today_line(chief)[1].left(1) == Reminders.today_line(chief)[1].left(1).to_upper(),
		"as a sentence")
	var report := _first_day(chief, func(d: int) -> bool:
		return ChiefDays.is_report_day(d) and ChiefDays.walkin_for(chief, d).is_empty() \
			and not ChiefDays.event_starts(chief, d) and not ChiefDays.is_milestone(d) and not ChiefDays.tier_starts(d))
	chief.day = report
	expect(Reminders.today_line(chief)[1].contains("Board report"), "the board report")
	chief.day = 100
	if ChiefDays.walkin_for(chief, 100).is_empty() and not ChiefDays.event_starts(chief, 100):
		expect(Reminders.today_line(chief)[1].contains("Day 100"), "a milestone")
	var plain := _first_day(chief, func(d: int) -> bool:
		return ChiefDays.walkin_for(chief, d).is_empty() and not ChiefDays.event_starts(chief, d) \
			and not ChiefDays.is_milestone(d) and not ChiefDays.tier_starts(d) and not ChiefDays.is_report_day(d))
	chief.day = plain
	expect_equal(Reminders.today_line(chief)[1],
		"Today: " + str(ChiefDays.CALLS[ChiefDays.call_for(chief, plain)]["teaser"]), "otherwise the day's hard call")


func test_the_second_page_saves_a_run_or_minds_the_weakest_number() -> void:
	var running := _doctor(15)
	running.set_count("op_streak", 3)
	var said := Reminders.run_line(running)
	expect(said[0] == "Tom" and said[1].contains("3 operations"), "a run worth saving (%s)" % [said])
	var chief := _doctor(60)
	Standing.start(chief)
	Standing.change(chief, {"money": -40})
	expect_equal(Reminders.run_line(chief), Reminders.LOW_METER["money"], "the number that's slipping")
	var early := _doctor(2)
	for day in range(1, 4):
		early.day = day
		var nudge := Reminders.run_line(early)
		expect(nudge[0] != "Mr. Malhotra" and nudge[0] != "Mrs. Banerjee", "nobody the player hasn't met yet (Day %d)" % day)
	var seen := {}
	for day in range(ChiefDays.ROUNDS_FROM, ChiefDays.ROUNDS_FROM + 30):
		var plain := _doctor(day)
		seen[Reminders.run_line(plain)[1]] = true
	expect(seen.size() >= 3, "the nudges vary from day to day")


func test_every_page_is_short_clean_and_about_today() -> void:
	var lines: Array = []
	for day in range(1, 200):
		var doctor := _doctor(day)
		lines.append(Reminders.today_line(doctor))
		lines.append(Reminders.run_line(doctor))
		lines.append(Reminders.ward_line(doctor))
		lines.append(Reminders.locker_line(doctor))
	for meter: String in Reminders.LOW_METER:
		lines.append(Reminders.LOW_METER[meter])
	for nudge: Array in Reminders.NUDGES:
		lines.append([nudge[2], nudge[3]])
	var known := ["Dr. Iyer", "Sister Grace", "Tom", "Mr. Malhotra", "Mrs. Banerjee"]
	for said: Array in lines:
		var body := str(said[1])
		expect(known.has(str(said[0])), "from someone the player knows: %s" % said[0])
		expect(body.length() <= 160, "fits a lock screen: %s" % body)
		expect(not body.contains("\t") and not body.contains("\n"), "one clean line")
		expect(not body.contains("Tomorrow") and not body.contains("{"), "about today, nothing left to fill in: %s" % body)
		expect(body.ends_with(".") or body.ends_with("?") or body.ends_with("!"), "a finished sentence: %s" % body)
		expect(not body.contains("Harshal") and not body.contains("Asha "), "no names that shouldn't be there")


# --- To the phone ---------------------------------------------------------------

func test_the_plan_reaches_the_phone_in_the_shape_its_code_reads() -> void:
	var made := Reminders.plan(_doctor(9), _on(), NOW, IST)
	made[0]["body"] = "A tab\there, and a\nbreak."
	var text := Reminders.payload(made, true)
	var lines := text.split("\n")
	expect_equal(lines[0], "DW1", "the version line first")
	expect_equal(lines[1], "ask", "then the request for permission")
	expect_equal(lines.size(), 2 + made.size(), "a line for each reminder")
	for index in range(2, lines.size()):
		var fields := lines[index].split("\t")
		expect_equal(fields.size(), 5, "kind, id, time, title, body")
		expect_equal(fields[0], "R")
		expect(fields[2].is_valid_int(), "the time is a whole number")
	var clean := Reminders.plan(_doctor(9), _on(), NOW, IST)
	for entry: Dictionary in clean:
		expect(not str(entry["body"]).contains("\t"))
	expect_equal(Reminders.payload([], false), "DW1", "nothing to send clears the phone")
	var native := FileAccess.get_file_as_string("res://addons/dw_reminders/reminders_ios.cpp")
	for agreed: String in [ReminderBackend.PAYLOAD, ReminderBackend.STATUS, "\"DW1\"", "\"ask\"", "\"R\"",
			"fields.size() == 5", "removeAllPendingNotificationRequests", "requestAuthorizationWithOptions"]:
		expect(native.contains(agreed), "the phone's side agrees on %s" % agreed)
	var plugin := FileAccess.get_file_as_string("res://addons/dw_reminders/export_plugin.gd")
	expect(plugin.contains("reminders_ios.cpp") and plugin.contains("UserNotifications"), "the export adds it")
	expect(FileAccess.get_file_as_string("res://project.godot").contains("res://addons/dw_reminders/plugin.cfg"),
		"and the export step is switched on")


func test_saves_refresh_the_plan_and_off_clears_it() -> void:
	var fake := _fake()
	var doctor := _doctor(6)
	GameSettings.current.reminders = true
	Reminders.refresh(doctor)
	expect_equal(fake.sent.size(), 1, "a plan goes to the phone")
	expect(fake.last_sent.contains("You're on call tonight"), "about tonight's on-call")
	Reminders.refresh(doctor)
	expect_equal(fake.sent.size(), 1, "the same plan isn't sent twice")
	doctor.day = 7
	Reminders.refresh(doctor)
	expect_equal(fake.sent.size(), 2, "a new day, a new plan")
	Reminders.set_enabled(GameSettings.current, false)
	expect_equal(fake.last_sent, "DW1", "switching off clears every reminder")
	var nowhere := _fake(false)
	GameSettings.current.reminders = true
	Reminders.refresh(doctor)
	expect(nowhere.sent.is_empty(), "nothing is sent where the device can't show it")


# --- Asking -----------------------------------------------------------------------

func test_the_game_asks_after_day_one_and_once_more_after_the_first_review() -> void:
	var fake := _fake()
	var settings := GameSettings.current
	var doctor := _doctor(1)
	expect(Reminders.should_ask(settings, 1), "after the first day")
	Reminders.answer(settings, doctor, 1, false)
	for day in range(1, 8):
		expect(not Reminders.should_ask(settings, day), "not again so soon (Day %d)" % day)
	expect(Reminders.should_ask(settings, 8), "once more after the first review")
	Reminders.answer(settings, doctor, 8, false)
	for day in range(8, 60):
		expect(not Reminders.should_ask(settings, day), "and then never (Day %d)" % day)
	var late := GameSettings.new()
	expect(Reminders.should_ask(late, 20), "an old career is asked once")
	Reminders.answer(late, doctor, 20, false)
	expect(not Reminders.should_ask(late, 21), "and only once")
	var keen := GameSettings.new()
	Reminders.answer(keen, _doctor(2), 1, true)
	expect(keen.reminders, "yes switches reminders on")
	expect(fake.last_sent.begins_with("DW1\nask\nR\t"), "the phone asks, and the plan goes with it")
	expect(not Reminders.should_ask(keen, 8), "a yes is never asked again")
	fake.said = "denied"
	expect(not Reminders.should_ask(GameSettings.new(), 1), "nor is a phone that has said no")
	_fake(false)
	expect(not Reminders.should_ask(GameSettings.new(), 1), "nor a device that can't show reminders")


func test_finishing_day_one_asks_before_day_two_starts() -> void:
	var fake := _fake()
	var main := Main.new()
	main.store = SaveStore.new(SAVE)
	main.settings_path = SETTINGS
	add_node(main)
	main.profile.name = "Kiran Rao"
	main.profile.created = true
	main.profile.opening_seen = true
	main.profile.day = 1
	main._on_day_finished()
	var asks := main.find_children("*", "ReminderAsk", false, false)
	expect_equal(asks.size(), 1, "the question comes up as Day 1 ends")
	expect_equal(main.profile.day, 2, "the save has moved on to Day 2 already")
	expect(not main.screen is SkillsLab, "but Day 2 waits for the answer")
	var ask := asks[0] as ReminderAsk
	expect(ask.yes_button != null and ask.no_button != null, "yes or not now")
	ask.yes_button.pressed.emit()
	expect(main.screen is SkillsLab, "then Day 2 starts")
	expect(GameSettings.current.reminders, "with reminders on")
	expect(GameSettings.load_from(SETTINGS).reminders, "remembered on the device")
	var asked := false
	for sent: String in fake.sent:
		asked = asked or sent.begins_with("DW1\nask\n")
	expect(asked, "and the phone asked")
	expect(fake.last_sent.contains("skills lab"), "the first page is about the skills lab")
	main.profile.day = 2
	main._on_day_finished()
	var waiting := main.find_children("*", "ReminderAsk", false, false).filter(func(node: Node) -> bool:
		return not node.is_queued_for_deletion())
	expect(waiting.is_empty(), "no question on the days after")
	expect_equal(main.profile.day, 3)


func test_a_device_without_reminders_goes_straight_on() -> void:
	_fake(false)
	var main := Main.new()
	main.store = SaveStore.new(SAVE)
	main.settings_path = SETTINGS
	add_node(main)
	main.profile.created = true
	main.profile.opening_seen = true
	main.profile.day = 1
	main._on_day_finished()
	expect(main.find_children("*", "ReminderAsk", false, false).is_empty(), "no question")
	expect_equal(main.profile.day, 2)


func test_the_settings_switch_reminders_on_and_off() -> void:
	var fake := _fake()
	Reminders.profile = _doctor(10)
	var panel := add_node(SettingsPanel.new()) as SettingsPanel
	expect(panel.choice_rows.has("reminders"), "a Reminders row where the device can show them")
	panel.pick("reminders", 1)
	expect(GameSettings.current.reminders, "On switches them on")
	expect(fake.last_sent.begins_with("DW1\nask"), "and asks the phone")
	expect(fake.last_sent.contains("kidney stone"), "with a plan for the day waiting")
	panel.pick("reminders", 0)
	expect(not GameSettings.current.reminders)
	expect_equal(fake.last_sent, "DW1", "Off clears them")
	fake.said = "denied"
	panel.pick("reminders", 1)
	expect(panel.reminder_note.text.contains("Settings app"), "says where to allow them when the phone said no")
	_fake(false)
	var plain := add_node(SettingsPanel.new()) as SettingsPanel
	expect(not plain.choice_rows.has("reminders"), "no Reminders row where the device can't show them")
