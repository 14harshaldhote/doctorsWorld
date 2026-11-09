class_name StitchTask
extends TrainingTask
## Stitching: close a cut on a practice pad with stitches placed across it,
## end to end, evenly spaced. Positions are in centimetres on the pad.

const PAD_SIZE := Vector2(12.0, 8.0)
const SAMPLES := 120
## A tap further than this from the cut misses it.
const MISS_DISTANCE := 0.9
const MAX_STITCHES := 14
const IDEAL_GAP := 1.1
const END_MARGIN := 0.8
const MAX_GAP := 1.8
const ACCURACY_POINTS := 35
const EVENNESS_POINTS := 35
const COVERAGE_POINTS := 30
const POINTS_PER_MISS := 5

## Stitches along the cut: {"t": 0 to 1 along it, "off": cm from the line}.
var stitches: Array[Dictionary] = []
var misses := 0
var _curve := PackedVector2Array()
var _lengths := PackedFloat32Array()


func _init() -> void:
	id = "stitch"
	for index in SAMPLES + 1:
		var t := float(index) / SAMPLES
		_curve.append(Vector2(2.0 + 8.0 * t, 4.0 + 0.7 * sin(PI * (t * 1.6 - 0.3))))
	var total := 0.0
	_lengths.append(0.0)
	for index in range(1, _curve.size()):
		total += _curve[index].distance_to(_curve[index - 1])
		_lengths.append(total)
	_say("Across the cut, end to end, about a finger-width apart. Then tie off.")


## The cut's length in centimetres.
func length() -> float:
	return _lengths[_lengths.size() - 1]


## A point on the cut, t from 0 (one end) to 1 (the other).
func point_at(t: float) -> Vector2:
	var exact := clampf(t, 0.0, 1.0) * SAMPLES
	var index := mini(int(exact), SAMPLES - 1)
	return _curve[index].lerp(_curve[index + 1], exact - index)


## Which way the cut runs at t, for drawing stitches across it.
func direction_at(t: float) -> Vector2:
	var index := clampi(int(t * SAMPLES), 0, SAMPLES - 1)
	return (_curve[index + 1] - _curve[index]).normalized()


func curve() -> PackedVector2Array:
	return _curve


## Distance along the cut, in cm, for a t.
func distance_along(t: float) -> float:
	var exact := clampf(t, 0.0, 1.0) * SAMPLES
	var index := mini(int(exact), SAMPLES - 1)
	return lerpf(_lengths[index], _lengths[index + 1], exact - index)


## The nearest point of the cut to a spot: [t, distance in cm].
func nearest(spot: Vector2) -> Array:
	var best_t := 0.0
	var best := INF
	for index in SAMPLES:
		var a := _curve[index]
		var b := _curve[index + 1]
		var closest := Geometry2D.get_closest_point_to_segment(spot, a, b)
		var distance := closest.distance_to(spot)
		if distance < best:
			best = distance
			var along := a.distance_to(closest) / maxf(0.0001, a.distance_to(b))
			best_t = (index + along) / SAMPLES
	return [best_t, best]


## A tap on the pad: places a stitch across the cut there, or misses.
func place(spot: Vector2) -> bool:
	if finished or stitches.size() >= MAX_STITCHES:
		return false
	var found := nearest(spot)
	var t: float = found[0]
	var off: float = found[1]
	if off > MISS_DISTANCE:
		misses += 1
		_say("That's beside the cut, not across it. Aim for the line.", true)
		return false
	stitches.append({"t": t, "off": off})
	stitches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	var gaps := _gaps()
	if stitches.size() == 1:
		_say("One. Keep going along the cut.")
	elif not gaps.is_empty() and gaps.min() < IDEAL_GAP * 0.45:
		_say("That one's crowding its neighbour. Even gaps heal into a neat line.", true)
	else:
		_say("%d stitches." % stitches.size())
	if stitches.size() >= MAX_STITCHES:
		tie_off()
	return true


func tie_off() -> void:
	if finished or stitches.is_empty():
		return
	_end()


func score() -> int:
	return clampi(_accuracy() + _evenness() + _coverage() - misses * POINTS_PER_MISS, 0, 100)


func instruction() -> String:
	if finished:
		return "Tied off"
	return "Tap across the cut to place each stitch: %d placed" % stitches.size()


func progress() -> float:
	if stitches.is_empty():
		return 0.0
	return clampf(float(stitches[stitches.size() - 1]["t"]), 0.0, 1.0)


func _gaps() -> Array[float]:
	var gaps: Array[float] = []
	for index in range(1, stitches.size()):
		gaps.append(distance_along(float(stitches[index]["t"])) - distance_along(float(stitches[index - 1]["t"])))
	return gaps


func _mean_off() -> float:
	if stitches.is_empty():
		return INF
	var total := 0.0
	for stitch in stitches:
		total += float(stitch["off"])
	return total / stitches.size()


func _accuracy() -> int:
	if stitches.is_empty():
		return 0
	var quality := 1.0 - clampf((_mean_off() - 0.15) / 0.55, 0.0, 1.0)
	return int(round(ACCURACY_POINTS * quality))


func _spread() -> float:
	var gaps := _gaps()
	if gaps.size() < 2:
		return 1.0
	var mean := 0.0
	for gap in gaps:
		mean += gap
	mean /= gaps.size()
	var variance := 0.0
	for gap in gaps:
		variance += (gap - mean) * (gap - mean)
	return sqrt(variance / gaps.size()) / maxf(0.0001, mean)


func _evenness() -> int:
	if stitches.size() < 3:
		return 0
	var quality := 1.0 - clampf((_spread() - 0.12) / 0.48, 0.0, 1.0)
	var points := int(round(EVENNESS_POINTS * quality))
	var gaps := _gaps()
	var mean := (distance_along(float(stitches[stitches.size() - 1]["t"])) - distance_along(float(stitches[0]["t"]))) \
		/ maxf(1.0, gaps.size())
	if mean < IDEAL_GAP * 0.55:
		points -= 10
	return maxi(0, points)


func _coverage() -> int:
	if stitches.size() < 3:
		return 0
	var points := COVERAGE_POINTS
	if distance_along(float(stitches[0]["t"])) > END_MARGIN:
		points -= 10
	if length() - distance_along(float(stitches[stitches.size() - 1]["t"])) > END_MARGIN:
		points -= 10
	var gaps := _gaps()
	if not gaps.is_empty() and gaps.max() > MAX_GAP:
		points -= 10
	return points


func _end() -> void:
	var off := _mean_off()
	if _accuracy() >= ACCURACY_POINTS - 5 and misses == 0:
		_note(true, "Every stitch right across the cut.")
	else:
		_note(false, "Stitches landed %.1f cm off the line on average%s. Off-line stitches pull the edges crooked." %
			[off, "" if misses == 0 else ", and %d missed the cut" % misses])
	if stitches.size() < 3:
		_note(false, "%d stitch%s won't hold a cut this long. You need about %d." %
			[stitches.size(), "" if stitches.size() == 1 else "es", int(round(length() / IDEAL_GAP))])
	elif _evenness() >= EVENNESS_POINTS - 6:
		_note(true, "Even spacing. It'll heal into a neat, thin line.")
	else:
		_note(false, "Uneven gaps. Where stitches bunch, the skin puckers; where they're far apart, it gapes.")
	if stitches.size() >= 3:
		if _coverage() >= COVERAGE_POINTS:
			_note(true, "Closed end to end, with no gaps.")
		else:
			_note(false, "The cut isn't closed end to end. An open corner is where infection gets in.")
	var lines := {3: "Neat. I'd let you close on my patients.", 2: "Not bad. The scar will forgive you.",
		1: "It's closed. Mostly. Practise on oranges.", 0: "That's a zip, not a wound. Again."}
	_say(str(lines[stars_for(score())]))
	_finish()
