extends TestCase
## A little XP for opening the game on a new real-world day, more for days
## in a row and for rank, shown on a card over the day's screen once, and
## never lost when a day starts over.

const SAVE := "user://test_daily/save.json"


func cleanup() -> void:
	DailyReward.today_override = ""
	super()


func _main(day: int) -> Main:
	for file: String in ["save.json", "save.json.tmp", "settings.json", "settings.json.tmp"]:
		if FileAccess.file_exists("user://test_daily/" + file):
			DirAccess.remove_absolute("user://test_daily/" + file)
	var main := Main.new()
	main.store = SaveStore.new(SAVE)
	main.settings_path = "user://test_daily/settings.json"
	add_node(main)
	main.profile.name = "Kiran Rao"
	main.profile.created = true
	main.profile.opening_seen = true
	main.profile.day = day
	main.profile.total_xp = 900
	for flag in ["met_iyer", "day1_iyer", "lab_welcome", "training_done", "op_rohit_done", "op_rohit_won"]:
		main.profile.set_flag(flag)
	for id: String in TrainingTask.IDS:
		main.profile.record_score(id, 70)
	return main


func _cards(main: Main) -> int:
	var count := 0
	for child in main.get_children():
		if child is WelcomeCard and not child.is_queued_for_deletion():
			count += 1
	return count


func test_a_new_day_pays_xp_once_and_days_in_a_row_pay_more() -> void:
	var profile := PlayerProfile.new()
	expect(DailyReward.claim(profile, "2026-11-10").is_empty(), "the career's first session only notes the date")
	expect_equal(profile.last_played, "2026-11-10")
	expect_equal(profile.count(DailyReward.COUNTER), 1, "day one of the streak")
	expect_equal(profile.total_xp, 0, "and pays nothing yet")
	expect(DailyReward.claim(profile, "2026-11-10").is_empty(), "nothing more the same day")
	var reward := DailyReward.claim(profile, "2026-11-11")
	expect_equal(int(reward.get("streak", 0)), 2, "the next day is day two")
	expect_equal(int(reward.get("xp", 0)), 15, "worth 15 XP for an Intern")
	expect_equal(int(reward.get("next", 0)), 20, "and tomorrow is worth 20")
	expect_equal(profile.total_xp, 15, "the XP is on the career")
	expect(DailyReward.claim(profile, "2026-11-11").is_empty(), "once a day only")
	reward = DailyReward.claim(profile, "2026-11-14")
	expect_equal(int(reward.get("streak", 0)), 1, "a gap starts the streak again")
	expect_equal(int(reward.get("xp", 0)), 10, "at the plain amount")
	var expected := [15, 20, 25, 30, 35, 40, 40, 40]
	for index in expected.size():
		reward = DailyReward.claim(profile, "2026-11-%d" % (15 + index))
		expect_equal(int(reward.get("xp", 0)), int(expected[index]), "day %d in a row" % (index + 2))
	expect_equal(DailyReward.yesterday("2026-03-01"), "2026-02-28", "yesterday across a month")
	expect_equal(DailyReward.yesterday("2026-01-01"), "2025-12-31", "and across a year")
	expect_equal(DailyReward.xp_for(3, Rank.CHIEF), 70, "a Chief gets three and a half times the amount")


func test_the_date_and_the_streak_are_saved_with_the_career() -> void:
	var profile := PlayerProfile.new()
	DailyReward.claim(profile, "2026-11-10")
	DailyReward.claim(profile, "2026-11-11")
	var back := PlayerProfile.from_dict(profile.to_dict())
	expect_equal(back.last_played, "2026-11-11")
	expect_equal(back.count(DailyReward.COUNTER), 2)
	expect_equal(back.total_xp, 15)
	var broken := PlayerProfile.from_dict({"last_played": 42})
	expect_equal(broken.last_played, "", "a broken date is ignored")


func test_coming_back_on_a_new_day_shows_the_card_once_and_the_xp_survives_a_restart() -> void:
	DailyReward.today_override = "2026-11-16"
	var main := _main(5)
	main.profile.set_flag("beds_checked")
	main.profile.last_played = "2026-11-15"
	main.profile.set_count(DailyReward.COUNTER, 3)
	var before := main.profile.total_xp
	main.show_hospital()
	expect(main.screen is Ward, "Day 5 is on the ward")
	expect_equal(_cards(main), 1, "with the welcome card over it")
	expect_equal(main.profile.total_xp, before + 25, "day four in a row: 25 XP")
	expect_equal(main.profile.count(DailyReward.COUNTER), 4)
	expect(main.screen.process_mode == Node.PROCESS_MODE_DISABLED, "the day waits for the card")
	var card: WelcomeCard
	for child in main.get_children():
		if child is WelcomeCard:
			card = child
	expect(card != null and (card.find_child("Headline", true, false) as Label).text == "Day 4 in a row")
	expect(card != null and (card.find_child("Body", true, false) as Label).text.contains("+25 XP"))
	card.go_button.pressed.emit()
	expect(main.screen.process_mode == Node.PROCESS_MODE_INHERIT, "and goes on once it closes")
	expect_equal(_cards(main), 0, "the card is gone")
	main.show_hospital()
	expect_equal(_cards(main), 0, "no second card the same day")
	expect_equal(main.profile.total_xp, before + 25, "the day starting over keeps the XP")
	var saved: PlayerProfile = SaveStore.new(SAVE).load_or_start()["profile"]
	expect_equal(saved.last_played, "2026-11-16", "the date is saved at once")
	expect_equal(saved.total_xp, before + 25, "with the XP")


func test_the_xp_goes_into_a_day_that_was_closed_halfway() -> void:
	DailyReward.today_override = "2026-11-16"
	var main := _main(5)
	main.profile.set_flag("beds_checked")
	main.profile.last_played = "2026-11-15"
	main.profile.set_count(DailyReward.COUNTER, 1)
	# Yesterday the day was begun and the game closed halfway: the morning
	# snapshot is from before today's XP.
	main.profile.begin_day()
	main.profile.total_xp += 120
	main.show_hospital()
	expect(main.screen is Ward)
	expect_equal(int(main.profile.morning.get("total_xp", 0)), 900 + 15, "the morning snapshot takes the XP")
	expect_equal(main.profile.total_xp, 900 + 15, "the day went back to its morning, with the XP")


func test_the_first_session_of_a_career_shows_no_card() -> void:
	DailyReward.today_override = "2026-11-16"
	var main := _main(5)
	main.profile.set_flag("beds_checked")
	main.show_hospital()
	expect(main.screen is Ward)
	expect_equal(_cards(main), 0, "nothing to come back for yet")
	expect_equal(main.profile.last_played, "2026-11-16", "but the date is noted")
	expect_equal(main.profile.total_xp, 900, "and nothing is paid")
