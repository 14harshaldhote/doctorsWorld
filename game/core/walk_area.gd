class_name WalkArea
extends RefCounted
## Where characters can walk on a floor, seen from above (x and z in metres).
##
## The floor is a rectangle with rectangular blockers (desks, benches, walls).
## Paths are found on a grid with A*, then straightened wherever a direct
## line is clear, so characters walk around furniture instead of into it.

var bounds: Rect2
var radius: float
var cell: float
var blockers: Array[Rect2] = []
var _grid: AStarGrid2D
var _dirty := true


func _init(area_bounds: Rect2, character_radius: float = 0.3, cell_size: float = 0.25) -> void:
	bounds = area_bounds
	radius = character_radius
	cell = cell_size


func add_blocker(rect: Rect2) -> void:
	blockers.append(rect)
	_dirty = true


## True if a character's centre can stand at this point.
func is_walkable(point: Vector2) -> bool:
	if point.x < bounds.position.x + radius or point.x > bounds.end.x - radius:
		return false
	if point.y < bounds.position.y + radius or point.y > bounds.end.y - radius:
		return false
	for blocker in blockers:
		if blocker.grow(radius).has_point(point):
			return false
	return true


## The nearest point a character can stand on.
func closest_walkable(point: Vector2) -> Vector2:
	if is_walkable(point):
		return point
	var clamped := Vector2(
		clampf(point.x, bounds.position.x + radius + 0.001, bounds.end.x - radius - 0.001),
		clampf(point.y, bounds.position.y + radius + 0.001, bounds.end.y - radius - 0.001))
	if is_walkable(clamped):
		return clamped
	# Inside a blocker: try the four edges of every blocker that contains it.
	var best := Vector2.INF
	for blocker in blockers:
		var grown := blocker.grow(radius + 0.01)
		if not grown.has_point(clamped):
			continue
		for candidate in [
			Vector2(grown.position.x, clamped.y), Vector2(grown.end.x, clamped.y),
			Vector2(clamped.x, grown.position.y), Vector2(clamped.x, grown.end.y),
		]:
			if is_walkable(candidate) and clamped.distance_to(candidate) < clamped.distance_to(best):
				best = candidate
	if best != Vector2.INF:
		return best
	return _cell_centre(_nearest_open_cell(clamped))


## True if a character can walk straight from a to b.
func line_clear(a: Vector2, b: Vector2) -> bool:
	var length := a.distance_to(b)
	var steps := maxi(1, ceili(length / (cell * 0.5)))
	for index in range(steps + 1):
		if not is_walkable(a.lerp(b, float(index) / steps)):
			return false
	return true


## Waypoints from one point to another, ending at the closest walkable
## point to the target. Empty if there is no way there.
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var target := closest_walkable(to)
	var start := from if is_walkable(from) else closest_walkable(from)
	var result := PackedVector2Array()
	if line_clear(start, target):
		result.append(target)
		return result
	_build_grid()
	var ids := _grid.get_id_path(_nearest_open_cell(start), _nearest_open_cell(target))
	if ids.is_empty():
		return result
	var points: Array[Vector2] = [start]
	for id in ids:
		points.append(_cell_centre(id))
	points.append(target)
	# Straighten: from each kept point, jump to the furthest point in sight.
	var index := 0
	while index < points.size() - 1:
		var furthest := index + 1
		for later in range(points.size() - 1, index, -1):
			if line_clear(points[index], points[later]):
				furthest = later
				break
		result.append(points[furthest])
		index = furthest
	return result


func _build_grid() -> void:
	if not _dirty and _grid != null:
		return
	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(0, 0, ceili(bounds.size.x / cell), ceili(bounds.size.y / cell))
	_grid.cell_size = Vector2(cell, cell)
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.update()
	for x in _grid.region.size.x:
		for y in _grid.region.size.y:
			var id := Vector2i(x, y)
			_grid.set_point_solid(id, not is_walkable(_cell_centre(id)))
	_dirty = false


func _cell_centre(id: Vector2i) -> Vector2:
	return bounds.position + (Vector2(id) + Vector2(0.5, 0.5)) * cell


func _nearest_open_cell(point: Vector2) -> Vector2i:
	_build_grid()
	var home := Vector2i(((point - bounds.position) / cell).floor())
	home = home.clamp(Vector2i.ZERO, _grid.region.size - Vector2i.ONE)
	if not _grid.is_point_solid(home):
		return home
	for ring in range(1, maxi(_grid.region.size.x, _grid.region.size.y)):
		var best := Vector2i(-1, -1)
		var best_distance := INF
		for dx in range(-ring, ring + 1):
			for dy in range(-ring, ring + 1):
				if absi(dx) != ring and absi(dy) != ring:
					continue
				var id := home + Vector2i(dx, dy)
				if not _grid.region.has_point(id) or _grid.is_point_solid(id):
					continue
				var distance := _cell_centre(id).distance_to(point)
				if distance < best_distance:
					best_distance = distance
					best = id
		if best.x >= 0:
			return best
	return home
