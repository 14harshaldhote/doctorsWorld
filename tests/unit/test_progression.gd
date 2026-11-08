extends TestCase
## The XP curve and rank ladder, ported from the Swift prototype.


func test_known_points_on_the_curve() -> void:
	expect_equal(LevelCurve.total_xp_to_reach(1), 0)
	expect_equal(LevelCurve.total_xp_to_reach(2), 710)
	expect_equal(LevelCurve.total_xp_to_reach(4), 2000)
	expect_equal(LevelCurve.total_xp_to_reach(10), 7910)


func test_curve_always_rises_and_stops_at_the_cap() -> void:
	for level in range(2, LevelCurve.MAX_LEVEL + 1):
		expect(LevelCurve.total_xp_to_reach(level) > LevelCurve.total_xp_to_reach(level - 1), "level %d" % level)
	expect_equal(LevelCurve.total_xp_to_reach(LevelCurve.MAX_LEVEL + 5), LevelCurve.total_xp_to_reach(LevelCurve.MAX_LEVEL))


func test_level_for_xp_matches_thresholds() -> void:
	expect_equal(LevelCurve.level_for_xp(0), 1)
	expect_equal(LevelCurve.level_for_xp(709), 1)
	expect_equal(LevelCurve.level_for_xp(710), 2)
	expect_equal(LevelCurve.level_for_xp(1999), 3)
	expect_equal(LevelCurve.level_for_xp(2000), 4)
	expect_equal(LevelCurve.level_for_xp(100000000), LevelCurve.MAX_LEVEL)


func test_progress_for_the_xp_bar() -> void:
	var halfway := LevelCurve.progress(1660)
	expect_equal(halfway["level"], 3)
	expect_equal(halfway["into"], 1660 - LevelCurve.total_xp_to_reach(3))
	expect_equal(halfway["needed"], 2000 - LevelCurve.total_xp_to_reach(3))
	expect_between(halfway["fraction"], 0.0, 1.0)
	var top := LevelCurve.progress(100000000)
	expect_equal(top["needed"], 0)
	expect_equal(top["fraction"], 1.0)


func test_ranks_follow_levels() -> void:
	expect_equal(Rank.for_level(1), Rank.INTERN)
	expect_equal(Rank.for_level(3), Rank.INTERN)
	expect_equal(Rank.for_level(4), Rank.JUNIOR_RESIDENT)
	expect_equal(Rank.for_level(7), Rank.SENIOR_RESIDENT)
	expect_equal(Rank.for_level(10), Rank.SURGEON)
	expect_equal(Rank.for_level(14), Rank.HEAD_OF_DEPARTMENT)
	expect_equal(Rank.for_level(18), Rank.CHIEF)
	expect_equal(Rank.for_level(50), Rank.CHIEF)


func test_rank_titles_and_order() -> void:
	expect_equal(Rank.title(Rank.INTERN), "Intern")
	expect_equal(Rank.title(Rank.CHIEF), "Chief of Medicine")
	expect_equal(Rank.next(Rank.INTERN), Rank.JUNIOR_RESIDENT)
	expect_equal(Rank.next(Rank.CHIEF), -1)
	expect_equal(Rank.count(), 6)


func test_junior_resident_starts_at_two_thousand_xp() -> void:
	expect_equal(Rank.for_level(LevelCurve.level_for_xp(1999)), Rank.INTERN)
	expect_equal(Rank.for_level(LevelCurve.level_for_xp(2000)), Rank.JUNIOR_RESIDENT)
