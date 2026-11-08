extends TestCase
## Walking around the hospital floor without passing through furniture.


func _room() -> WalkArea:
	var area := WalkArea.new(Rect2(-5, -4, 10, 8), 0.3)
	area.add_blocker(Rect2(-1, -1, 2, 2))  # a desk in the middle
	return area


func test_walls_and_furniture_are_not_walkable() -> void:
	var area := _room()
	expect(area.is_walkable(Vector2(-3, 0)))
	expect(not area.is_walkable(Vector2(0, 0)), "inside the desk")
	expect(not area.is_walkable(Vector2(-1.2, 0)), "too close to the desk")
	expect(not area.is_walkable(Vector2(4.9, 0)), "too close to the wall")
	expect(not area.is_walkable(Vector2(9, 0)), "outside the room")


func test_closest_walkable_pulls_points_out_of_blockers_and_walls() -> void:
	var area := _room()
	for point in [Vector2(0, 0), Vector2(0.9, 0.1), Vector2(20, 20), Vector2(-5, -4)]:
		var fixed := area.closest_walkable(point)
		expect(area.is_walkable(fixed), "fixed point %s should be walkable" % fixed)
	var near_desk := area.closest_walkable(Vector2(0.95, 0))
	expect_near(near_desk.x, 1.31, 0.05, "nearest edge of the desk")


func test_clear_lines_and_blocked_lines() -> void:
	var area := _room()
	expect(area.line_clear(Vector2(-3, -3), Vector2(3, -3)))
	expect(not area.line_clear(Vector2(-3, 0), Vector2(3, 0)), "straight through the desk")


func test_direct_path_when_nothing_is_in_the_way() -> void:
	var area := _room()
	var path := area.find_path(Vector2(-3, -3), Vector2(3, -3))
	expect_equal(path.size(), 1)
	expect(path[0].is_equal_approx(Vector2(3, -3)))


func test_path_goes_around_the_desk_and_every_leg_is_clear() -> void:
	var area := _room()
	var start := Vector2(-3, 0)
	var path := area.find_path(start, Vector2(3, 0))
	expect(path.size() >= 2, "needs at least one turn")
	expect(path[path.size() - 1].is_equal_approx(Vector2(3, 0)), "ends at the target")
	var previous := start
	var length := 0.0
	for point in path:
		expect(area.line_clear(previous, point), "leg %s → %s should be clear" % [previous, point])
		length += previous.distance_to(point)
		previous = point
	expect_between(length, 6.0, 9.0, "a sensible detour, not a wander")


func test_tapping_inside_furniture_walks_to_its_edge() -> void:
	var area := _room()
	var path := area.find_path(Vector2(-3, 0), Vector2(0, 0))
	expect(not path.is_empty())
	expect(area.is_walkable(path[path.size() - 1]))


func test_no_path_into_a_sealed_room() -> void:
	var area := WalkArea.new(Rect2(0, 0, 10, 4), 0.3)
	area.add_blocker(Rect2(4.5, -1, 1, 6))  # a wall across the whole room
	var path := area.find_path(Vector2(1, 2), Vector2(9, 2))
	expect(path.is_empty() or area.line_clear(Vector2(1, 2), path[path.size() - 1]),
		"either no path, or it stops on the reachable side")
