extends TestCase
## The random generator must give exactly the SplitMix64 sequence, so the
## same seed replays the same game on every device.


func test_raw_bits_match_the_reference_sequence() -> void:
	var rng := SeededRandom.new(42)
	expect_equal(rng.next(), -4767286540954276203)
	expect_equal(rng.next(), 2949826092126892291)
	expect_equal(rng.next(), 5139283748462763858)


func test_bounded_integers_match_the_reference() -> void:
	var rng := SeededRandom.new(7)
	var drawn: Array[int] = []
	for i in 12:
		drawn.append(rng.next_int(10))
	expect_equal(drawn, [3, 0, 9, 5, 4, 2, 4, 3, 1, 4, 1, 9] as Array[int])


func test_largest_bound_uses_the_high_word() -> void:
	var rng := SeededRandom.new(123)
	expect_equal(rng.next_int(SeededRandom.MAX_BOUND), 758589173)
	expect_equal(rng.next_int(SeededRandom.MAX_BOUND), 1048612666)
	expect_equal(rng.next_int(SeededRandom.MAX_BOUND), 923055300)


func test_floats_match_the_reference_and_stay_below_one() -> void:
	var rng := SeededRandom.new(1)
	expect_near(rng.next_float(), 0.5665615751722809, 1e-15)
	expect_near(rng.next_float(), 0.7457817572627011, 1e-15)
	expect_near(rng.next_float(), 0.9710027535867962, 1e-15)
	var other := SeededRandom.new(99)
	for i in 2000:
		var value := other.next_float()
		if value < 0.0 or value >= 1.0:
			failures.append("float out of range: %s" % value)
			return


func test_same_seed_same_sequence_and_different_seed_differs() -> void:
	var a := SeededRandom.new(2026)
	var b := SeededRandom.new(2026)
	var c := SeededRandom.new(2027)
	var same := true
	var differs := false
	for i in 50:
		var va := a.next()
		same = same and va == b.next()
		differs = differs or va != c.next()
	expect(same, "same seed should repeat exactly")
	expect(differs, "a different seed should give a different sequence")


func test_ranges_cover_every_value_and_never_escape() -> void:
	var rng := SeededRandom.new(5)
	var seen := {}
	for i in 600:
		var value := rng.next_int_in(3, 8)
		expect_between(value, 3, 8)
		seen[value] = true
	expect_equal(seen.size(), 6, "all six values should appear")


func test_chance_respects_the_extremes_and_rough_rate() -> void:
	var rng := SeededRandom.new(11)
	var hits := 0
	for i in 4000:
		expect(not rng.chance(0.0))
		expect(rng.chance(1.0))
		if rng.chance(0.25):
			hits += 1
	expect_between(hits / 4000.0, 0.22, 0.28, "about a quarter")


func test_shuffle_keeps_every_item_and_is_repeatable() -> void:
	var items := ["a", "b", "c", "d", "e", "f"]
	var first := SeededRandom.new(3).shuffled(items)
	var second := SeededRandom.new(3).shuffled(items)
	expect_equal(first, second)
	var sorted := first.duplicate()
	sorted.sort()
	expect_equal(sorted, items)
	expect_equal(items, ["a", "b", "c", "d", "e", "f"], "the original stays untouched")


func test_pick_handles_empty_arrays() -> void:
	var rng := SeededRandom.new(8)
	expect_equal(rng.pick([]), null)
	expect(["x", "y"].has(rng.pick(["x", "y"])))
