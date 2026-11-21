extends TestCase
## The phone's clock (stage 22): moving the date back pays nothing daily
## (the daily XP, the 60-second case, the weekly guess) until the real date
## catches up, and the Today page says so instead of offering them.

const THURSDAY := "2026-11-19"
const MONDAY := "2026-11-16"
const NEXT_MONDAY := "2026-11-23"


func _doctor() -> PlayerProfile:
	var doctor := PlayerProfile.new()
	doctor.name = "Asha Verma"
	doctor.day = 12
	doctor.opening_seen = true
	doctor.created = true
	doctor.rank_held = Rank.JUNIOR_RESIDENT
	doctor.total_xp = 3000
	doctor.set_flag("met_iyer")
	return doctor


func _play(task: CrisisTask) -> void:
	var guard := 0
	while not task.finished and guard < 20:
		task.choose(str(CrisisTask.right_answer(task.current())))
		task.confirm()
		guard += 1


func cleanup() -> void:
	DailyReward.today_override = ""
	super.cleanup()


func test_dates_are_remembered_and_going_back_is_noticed() -> void:
	var doctor := _doctor()
	expect(not ClockGuard.rolled_back(doctor, THURSDAY), "nothing seen yet")
	ClockGuard.note(doctor, THURSDAY)
	expect(not ClockGuard.rolled_back(doctor, THURSDAY), "the same day is fine")
	expect(not ClockGuard.rolled_back(doctor, NEXT_MONDAY), "so is a later one")
	expect(ClockGuard.rolled_back(doctor, MONDAY), "an earlier one isn't")
	ClockGuard.note(doctor, MONDAY)
	expect_equal(doctor.count(ClockGuard.COUNTER), 20261119, "going back doesn't move the latest date back")


func test_the_daily_xp_waits_for_the_real_date() -> void:
	var doctor := _doctor()
	DailyReward.claim(doctor, MONDAY)
	expect(not DailyReward.claim(doctor, "2026-11-17").is_empty(), "a day later pays")
	var xp := doctor.total_xp
	expect(DailyReward.claim(doctor, MONDAY).is_empty(), "back to Monday pays nothing")
	expect_equal(doctor.total_xp, xp)
	expect_equal(doctor.last_played, "2026-11-17", "and doesn't rewrite the last day played")
	expect(not DailyReward.claim(doctor, "2026-11-18").is_empty(), "the next real day pays as usual")


func test_the_60_second_case_waits_for_the_real_date() -> void:
	var doctor := _doctor()
	var task := DailyCase.make(THURSDAY)
	_play(task)
	expect(not DailyCase.record(doctor, task, THURSDAY).is_empty(), "Thursday's case pays")
	var xp := doctor.total_xp
	var old := DailyCase.make(MONDAY)
	_play(old)
	expect(DailyCase.record(doctor, old, MONDAY).is_empty(), "Monday's, played on a phone set back, doesn't")
	expect_equal(doctor.total_xp, xp)
	expect_equal(doctor.count("daily_case_date"), 20261119, "Thursday stays the last case")
	var friday := DailyCase.make("2026-11-20")
	_play(friday)
	expect(not DailyCase.record(doctor, friday, "2026-11-20").is_empty(), "Friday's pays")
	expect_equal(DailyCase.streak(doctor, "2026-11-20"), 2, "and the streak carries on")


func test_the_weekly_guess_waits_for_the_real_date() -> void:
	var doctor := _doctor()
	ClockGuard.note(doctor, NEXT_MONDAY)
	var answer := str(WeeklyMystery.current(THURSDAY).get("answer", ""))
	expect(WeeklyMystery.guess(doctor, answer, THURSDAY).is_empty(), "last week's mystery can't be guessed from next week")
	expect_equal(doctor.count("mysteries_tried"), 0)
	var now := str(WeeklyMystery.current(NEXT_MONDAY).get("answer", ""))
	expect(not WeeklyMystery.guess(doctor, now, NEXT_MONDAY).is_empty(), "this week's can")


func test_the_today_page_says_the_date_went_back() -> void:
	var doctor := _doctor()
	ClockGuard.note(doctor, NEXT_MONDAY)
	DailyReward.today_override = THURSDAY
	expect(not CareerMap.today_waiting(doctor), "no 'new' on the career button")
	var map := add_node(CareerMap.new(doctor, "today")) as CareerMap
	expect(map.find_child("StartCase", true, false) == null, "no case to start")
	expect(map.find_child("Guess", true, false) == null, "no guess to make")
	var line := map.find_child("DailyLine", true, false) as Label
	expect(line != null and line.text.contains("gone back in time"), "and it says why")
	expect(map.start_daily_case() == null, "starting one anyway does nothing")
	DailyReward.today_override = NEXT_MONDAY
	expect(CareerMap.today_waiting(doctor), "back on the real date, all waiting again")
