class_name Goat
extends Node3D
## A goat that has wandered into casualty (stage 26, one of the director's
## silly moments): low-poly, in from the door, across the walkway between
## the benches and the cubicles, bleating, and out the far side where
## security is apparently on the way. It frees itself when it's gone.

signal gone

const SPEED := 0.9
const COAT := Color("#EDE6D8")
const PATCH := Color("#8A6A4C")
const HORN := Color("#5C5040")
const HOOF := Color("#3A3430")

## Where it walks, in its parent's space: [from, to].
var path: Array[Vector3] = []
var _legs: Array[Node3D] = []
var _head: Node3D
var _walked := 0.0
var _length := 0.0
var _clock := 0.0
var _bleats := 0
var _pause_left := 1.6


func _ready() -> void:
	name = "Goat"
	var body := LowPoly.box(Vector3(0.36, 0.3, 0.7), COAT, "Body")
	LowPoly.put(self, body, Vector3(0, 0.5, 0))
	LowPoly.put(self, LowPoly.box(Vector3(0.37, 0.16, 0.26), PATCH, "Patch"), Vector3(0, 0.58, -0.12))
	_head = LowPoly.joint(self, "Head", Vector3(0, 0.66, 0.38))
	LowPoly.put(_head, LowPoly.box(Vector3(0.2, 0.22, 0.32), COAT, "Face"), Vector3(0, 0.04, 0.12))
	LowPoly.put(_head, LowPoly.box(Vector3(0.21, 0.08, 0.1), PATCH, "Nose"), Vector3(0, -0.02, 0.27))
	for side in [-1.0, 1.0]:
		LowPoly.put(_head, LowPoly.box(Vector3(0.16, 0.05, 0.08), COAT, "Ear"), Vector3(side * 0.16, 0.08, 0.02),
			Vector3(0, 0, side * -0.5))
		LowPoly.put(_head, LowPoly.cylinder(0.0, 0.03, 0.18, 4, HORN, "Horn"), Vector3(side * 0.06, 0.2, -0.02),
			Vector3(-0.6, 0, 0))
		LowPoly.put(_head, LowPoly.box(Vector3(0.035, 0.035, 0.035), HOOF, "Eye"), Vector3(side * 0.1, 0.08, 0.18))
	LowPoly.put(_head, LowPoly.box(Vector3(0.06, 0.12, 0.05), COAT, "Beard"), Vector3(0, -0.13, 0.2))
	LowPoly.put(self, LowPoly.box(Vector3(0.07, 0.12, 0.05), COAT, "Tail"), Vector3(0, 0.66, -0.37), Vector3(0.5, 0, 0))
	for corner: Vector2 in [Vector2(-0.12, 0.26), Vector2(0.12, 0.26), Vector2(-0.12, -0.26), Vector2(0.12, -0.26)]:
		var hip := LowPoly.joint(self, "Leg%d" % (_legs.size() + 1), Vector3(corner.x, 0.38, corner.y))
		LowPoly.put(hip, LowPoly.box(Vector3(0.07, 0.34, 0.07), COAT, "Shin"), Vector3(0, -0.17, 0))
		LowPoly.put(hip, LowPoly.box(Vector3(0.08, 0.05, 0.08), HOOF, "Hoof"), Vector3(0, -0.355, 0))
		_legs.append(hip)
	add_child(LowPoly.shadow_blob(0.42, Vector2(0.8, 1.3)))
	if path.size() >= 2:
		position = path[0]
		_length = path[0].distance_to(path[1])
		_face(path[1])


func _face(point: Vector3) -> void:
	rotation.y = atan2(point.x - position.x, point.z - position.z)


## Moves the goat on (the ward ticks it, so tests can walk it out).
func tick(delta: float) -> void:
	if path.size() < 2 or _length <= 0.0:
		_leave()
		return
	_clock += delta
	# A pause to look round half way: it is a goat, after all.
	var half := _length * 0.5
	var pausing := false
	if _walked < half or _pause_left <= 0.0:
		_walked = minf(_length if _pause_left <= 0.0 else half, _walked + SPEED * delta)
	else:
		pausing = true
		_pause_left -= delta
	var at := path[0].lerp(path[1], _walked / _length)
	var stride := _clock * 9.0 if not pausing else 0.0
	position = at + Vector3(0, absf(sin(stride)) * 0.03, 0)
	for index in _legs.size():
		_legs[index].rotation.x = sin(stride + (PI if index in [1, 2] else 0.0)) * 0.5
	if _head != null:
		_head.rotation.y = sin(_clock * 1.7) * 0.35 if pausing else lerpf(_head.rotation.y, 0.0, minf(1.0, delta * 4.0))
	if _bleats == 0 and _clock > 0.4 or _bleats == 1 and pausing:
		_bleats += 1
		Sfx.play(self, "bleat", -4.0)
	if _walked >= _length:
		_leave()


func _leave() -> void:
	if is_queued_for_deletion():
		return
	gone.emit()
	queue_free()
