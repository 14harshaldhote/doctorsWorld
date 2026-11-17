class_name Crowd
extends RefCounted
## Keeps people out of each other. Every walk in the game (a tap on the
## floor, a story walk, someone going home) plans its way round the
## furniture and round anyone standing still, and on every frame steps
## aside for anyone in the way, or waits. Nobody ends a walk standing in
## someone else, and a walk that stays blocked ends where it is instead of
## pushing through.

## How close two people's centres may come, in metres (shoulder to shoulder).
const GAP := 0.5
## Angles tried, in turn, when the straight step walks into someone: a
## little to the right first, so two people meeting both pass on the same side.
const TURNS := [0.0, 0.55, -0.55, 1.05, -1.05, 1.6, -1.6]
## Seconds a walker waits for someone to clear before finding another way.
const REPLAN_AFTER := 0.7
## Seconds blocked before a walk simply ends where it is.
const GIVE_UP := 2.4
## A blocked walker this close to where it was going counts as there.
const NEAR_ENOUGH := 0.9
## People on another floor (theatre and seminar sit far below the ward).
const SAME_FLOOR := 0.6


## The people taking up floor space near a mover (everyone on show on the
## same floor, sitting or standing; not someone lying in bed).
static func others(mover: AvatarRig, everyone: Array) -> Array[AvatarRig]:
	var found: Array[AvatarRig] = []
	if mover == null:
		return found
	var level := mover.global_position.y
	for item: Variant in everyone:
		var rig := item as AvatarRig
		if rig == null or rig == mover or rig in found or not is_instance_valid(rig):
			continue
		if not rig.is_visible_in_tree() or rig.lying:
			continue
		if absf(rig.global_position.y - level) > SAME_FLOOR:
			continue
		found.append(rig)
	return found


## Where the others stand, flat (x, z), for WalkArea.find_path().
static func spots(people: Array[AvatarRig]) -> PackedVector2Array:
	var found := PackedVector2Array()
	for rig in people:
		found.append(Vector2(rig.global_position.x, rig.global_position.z))
	return found


## One frame's step: the step wanted, turned aside if it would walk into
## someone (or off the floor), or zero when the walker has to wait.
static func steer(mover: AvatarRig, wanted: Vector2, people: Array[AvatarRig], area: WalkArea = null) -> Vector2:
	if wanted.length() < 0.00001:
		return Vector2.ZERO
	var me := Vector2(mover.global_position.x, mover.global_position.z)
	var on_floor := area != null and area.is_walkable(me)
	for index in TURNS.size():
		var turn: float = TURNS[index]
		var step := wanted.rotated(turn) * (1.0 if index == 0 else 0.8)
		var next := me + step
		if on_floor and not area.is_walkable(next):
			continue
		if _clear(me, next, people):
			return step
	return Vector2.ZERO


## True when moving from me to next walks into nobody (moving away from
## someone already too close is always allowed, so an overlap can open up).
static func _clear(me: Vector2, next: Vector2, people: Array[AvatarRig]) -> bool:
	for rig in people:
		var them := Vector2(rig.global_position.x, rig.global_position.z)
		var after := them.distance_to(next)
		if after < GAP and after <= them.distance_to(me):
			return false
	return true


## A place to stand near a point with nobody else in it: the point itself
## if it's free, otherwise the nearest free spot, leaning towards where the
## walker comes from.
static func free_spot(point: Vector2, people: Array[AvatarRig], area: WalkArea = null,
		from: Vector2 = Vector2.INF) -> Vector2:
	if _room_at(point, people, area):
		return point
	var lean := from if from != Vector2.INF else point
	var best := point
	var best_cost := INF
	for ring in range(1, 15):
		var reach := GAP * 0.6 + ring * 0.12
		for slot in 16:
			var candidate := point + Vector2.from_angle(TAU * slot / 16.0) * reach
			if not _room_at(candidate, people, area):
				continue
			var cost := candidate.distance_to(point) + 0.35 * candidate.distance_to(lean)
			if cost < best_cost:
				best_cost = cost
				best = candidate
		if best_cost < INF:
			return best
	return point


static func _room_at(point: Vector2, people: Array[AvatarRig], area: WalkArea) -> bool:
	if area != null and area.bounds.has_point(point) and not area.is_walkable(point):
		return false
	for rig in people:
		if Vector2(rig.global_position.x, rig.global_position.z).distance_to(point) < GAP:
			return false
	return true


## Moves someone who has just been put down (or has stopped) out of anyone
## standing in the same spot. Returns true if they moved.
static func make_room(rig: AvatarRig, everyone: Array, area: WalkArea = null) -> bool:
	if rig == null or rig.lying or rig.sitting or not rig.is_visible_in_tree():
		return false
	var people := others(rig, everyone)
	var here := Vector2(rig.global_position.x, rig.global_position.z)
	var spot := free_spot(here, people, area)
	if spot.distance_to(here) < 0.001:
		return false
	rig.global_position = Vector3(spot.x, rig.global_position.y, spot.y)
	return true


## Finds the people problems on one frame: pairs closer than the gap, and
## (with a floor) people standing in furniture or outside the walls.
## [{"kind": "people" | "furniture" | "wall", "who", "with", "gap"}].
static func problems(everyone: Array, area: WalkArea = null, floor_y: float = 0.0,
		slack: float = 0.08, fixed: Array = []) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var list: Array[AvatarRig] = []
	for item: Variant in everyone:
		var rig := item as AvatarRig
		if rig != null and is_instance_valid(rig) and rig.is_visible_in_tree() and not rig in list:
			list.append(rig)
	for index in list.size():
		var one := list[index]
		var at := one.global_position
		for later in range(index + 1, list.size()):
			var other := list[later]
			if one.lying or other.lying:
				continue
			var to := other.global_position
			if absf(at.y - to.y) > SAME_FLOOR:
				continue
			var gap := Vector2(at.x - to.x, at.z - to.z).length()
			if gap < GAP - slack:
				found.append({"kind": "people", "who": str(one.name), "with": str(other.name), "gap": gap})
		if area == null or one.lying or one.sitting or one in fixed or absf(at.y - floor_y) > SAME_FLOOR:
			continue
		var spot := Vector2(at.x, at.z)
		# Walk areas stop about a quarter of a metre short of the walls; well
		# beyond that is another room (the theatre beside the ward's).
		if not area.bounds.grow(0.05).has_point(spot):
			if area.bounds.grow(0.6).has_point(spot):
				found.append({"kind": "wall", "who": str(one.name), "with": "", "gap": 0.0})
			continue
		for blocker in area.blockers:
			if blocker.grow(0.05).has_point(spot):
				found.append({"kind": "furniture", "who": str(one.name), "with": str(blocker), "gap": 0.0})
				break
	return found


## The floor (x, z) under someone.
static func flat(rig: Node3D) -> Vector2:
	return Vector2(rig.global_position.x, rig.global_position.z)


## The floor's walk area for someone, or null when they are on another
## floor (the ward's theatre and seminar room sit far below it).
static func area_for(rig: Node3D, area: WalkArea, floor_y: float = 0.0) -> WalkArea:
	if area == null or rig == null or absf(rig.global_position.y - floor_y) > SAME_FLOOR:
		return null
	return area


## A walk's waypoints from where someone stands to near a point: round the
## furniture and round everyone standing, ending in a free spot.
static func plan(rig: AvatarRig, to: Vector3, everyone: Array, area: WalkArea = null,
		floor_y: float = 0.0) -> PackedVector2Array:
	var people := others(rig, everyone)
	var floor_area := area_for(rig, area, floor_y)
	var start := flat(rig)
	if floor_area != null and floor_area.bounds.has_point(start) and not floor_area.is_walkable(start):
		# Getting up off a bed or out from behind something: step clear of it
		# first instead of walking through it.
		start = free_spot(floor_area.closest_walkable(start), people, floor_area)
		rig.global_position = Vector3(start.x, rig.global_position.y, start.y)
	var goal := free_spot(Vector2(to.x, to.z), people, floor_area, start)
	var path := PackedVector2Array()
	if floor_area != null:
		path = floor_area.find_path(start, goal, spots(people))
		if path.is_empty() and start.distance_to(goal) > 0.05:
			path.append(floor_area.closest_walkable(goal))
	elif start.distance_to(goal) > 0.02:
		path.append(goal)
	return path


## Moves a walker one frame along its route ({"path", "speed"}; "blocked"
## and "moved" are kept in it), stepping aside or waiting for people, and
## finding another way once if it stays blocked. Returns true when the walk
## is over: arrived, or blocked too long (it then stops where it is).
static func advance(rig: AvatarRig, route: Dictionary, delta: float, everyone: Array,
		area: WalkArea = null, floor_y: float = 0.0) -> bool:
	var path: PackedVector2Array = route["path"]
	var me := flat(rig)
	while not path.is_empty() and me.distance_to(path[0]) <= 0.02:
		path.remove_at(0)
	route["path"] = path
	route["moved"] = Vector2.ZERO
	if path.is_empty():
		return true
	var people := others(rig, everyone)
	var floor_area := area_for(rig, area, floor_y)
	# Someone has since stopped in the place this walk ends: end beside them.
	# (Only someone standing there, near the end: a person merely walking
	# across that spot would otherwise push the end ahead of them.)
	var last := path[path.size() - 1]
	var standing: Array[AvatarRig] = people.filter(func(other: AvatarRig) -> bool: return other.moving < 0.5)
	if me.distance_to(last) < 2.0 and not _room_at(last, standing, null):
		var instead := free_spot(last, people, floor_area, me)
		if instead.distance_to(last) > 0.01:
			path[path.size() - 1] = instead
			route["path"] = path
	var step := float(route["speed"]) * delta
	var to_next := path[0] - me
	var wanted := to_next if to_next.length() <= step else to_next.normalized() * step
	var moved := steer(rig, wanted, people, floor_area)
	if moved == Vector2.ZERO:
		var blocked := float(route.get("blocked", 0.0)) + delta
		route["blocked"] = blocked
		rig.moving = 0.0
		var left := me.distance_to(path[path.size() - 1])
		if blocked >= GIVE_UP or (left < NEAR_ENOUGH and blocked > 0.25):
			path.clear()
			route["path"] = path
			return true
		if floor_area != null and blocked >= REPLAN_AFTER and not route.has("replanned"):
			route["replanned"] = true
			var again := floor_area.find_path(me, path[path.size() - 1], spots(people))
			if not again.is_empty():
				route["path"] = again
		return false
	route["blocked"] = 0.0
	route["moved"] = moved
	var after := me + moved
	rig.global_position = Vector3(after.x, rig.global_position.y, after.y)
	rig.rotation.y = lerp_angle(rig.rotation.y, atan2(moved.x, moved.y), minf(1.0, delta * 10.0))
	rig.moving = 1.0
	if after.distance_to(path[0]) <= maxf(0.03, step * 0.5):
		path.remove_at(0)
	route["path"] = path
	if path.is_empty():
		return true
	# Stepping aside round and round someone gets nowhere: if the walk stops
	# getting closer, find another way once, then end it where it is.
	var left_now := after.distance_to(path[path.size() - 1])
	var best := float(route.get("best", INF))
	if left_now < best - 0.03:
		route["best"] = left_now
		route["since_best"] = 0.0
		return false
	var since := float(route.get("since_best", 0.0)) + delta
	route["since_best"] = since
	if (left_now < NEAR_ENOUGH and since > 0.4) or since > GIVE_UP + 1.0:
		path.clear()
		route["path"] = path
		rig.moving = 0.0
		return true
	if floor_area != null and since > REPLAN_AFTER * 2.0 and not route.has("replanned"):
		route["replanned"] = true
		var again := floor_area.find_path(after, path[path.size() - 1], spots(people))
		if not again.is_empty():
			route["path"] = again
	return false
