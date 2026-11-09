class_name IvTask
extends TrainingTask
## IV line: pick a good vein, set the needle's angle, then hold it steady
## while it goes in. Positions are in millimetres on the practice arm.

const VEINS := ["forearm", "wrist", "thin"]
const VEIN_INFO := {
	"forearm": {"points": 30, "wobble": 1.0,
		"line": "Straight, springy, easy to see. That's the one.",
		"note": "Good vein: straight and springy, away from the joints."},
	"wrist": {"points": 10, "wobble": 1.35,
		"line": "Over the wrist joint. It rolls, and every time he bends his hand the line kinks.",
		"note": "The wrist vein rolls and the line kinks every time the hand bends. Pick a straight one in the forearm."},
	"thin": {"points": 10, "wobble": 1.6,
		"line": "Thin and twisty. It'll burst the moment the needle goes in.",
		"note": "That vein was thin and twisty: it bursts easily. Feel for a fat, springy one."},
}
const BEST_ANGLE := 20.0
const ANGLE_LOW := 15.0
const ANGLE_HIGH := 30.0
const STEADY_TIME := 3.0
## The needle tip must stay within this many millimetres of the vein.
const TARGET_RADIUS := 4.0
const VEIN_POINTS := 30
const ANGLE_POINTS := 30
const STEADY_POINTS := 40

## "vein", "angle", "steady" or "done".
var phase := "vein"
var vein := ""
var angle := 40.0
var angle_points := 0
## Where each vein lies along the arm, 0 at the wrist to 1 at the elbow.
var slots := {}
## How far the needle tip has wandered from the vein, in millimetres.
var offset := Vector2.ZERO
var steady_time := 0.0
var inside_time := 0.0
var _phase_offsets := Vector2.ZERO
var _rng: SeededRandom


func _init(with_seed: int = 1) -> void:
	id = "iv"
	_rng = SeededRandom.new(with_seed + 13)
	# The wrist vein sits over the wrist; the other two swap places each try.
	var spots: Array = _rng.shuffled([0.45, 0.8])
	slots = {"wrist": 0.12, "forearm": float(spots[0]), "thin": float(spots[1])}
	_phase_offsets = Vector2(_rng.next_float() * TAU, _rng.next_float() * TAU)
	_say("Pick your vein first. Look for a straight one that springs back when you press.")


func pick_vein(which: String) -> void:
	if phase != "vein" or which not in VEINS:
		return
	vein = which
	phase = "angle"
	_say(str(VEIN_INFO[which]["line"]) + " Now the angle: shallow, but not flat.", which != "forearm")


func set_angle(degrees: float) -> void:
	if phase == "angle":
		angle = clampf(degrees, 0.0, 60.0)
		changed.emit()


func insert() -> void:
	if phase != "angle":
		return
	var miss := 0.0
	if angle < ANGLE_LOW:
		miss = ANGLE_LOW - angle
	elif angle > ANGLE_HIGH:
		miss = angle - ANGLE_HIGH
	angle_points = clampi(int(round(ANGLE_POINTS - miss * 2.0)), 0, ANGLE_POINTS)
	phase = "steady"
	offset = Vector2.ZERO
	if miss <= 0.0:
		_say("%d degrees. In you go. Now hold it steady: keep the tip in the circle." % int(round(angle)))
	elif angle > ANGLE_HIGH:
		_say("%d degrees is steep: you'll go straight out the back of the vein. Hold steady anyway." %
			int(round(angle)), true)
	else:
		_say("%d degrees is flat: you'll skate along under the skin. Hold steady anyway." % int(round(angle)), true)


## Moves the needle tip by a correction, in millimetres (the player's drag).
func nudge(by: Vector2) -> void:
	if phase == "steady":
		offset += by


## How hard the needle is trying to wander, in millimetres a second.
func drift(at: float) -> Vector2:
	var wobble := float(VEIN_INFO.get(vein, {}).get("wobble", 1.0))
	return Vector2(sin(at * 2.3 + _phase_offsets.x) + 0.5 * sin(at * 5.1),
		cos(at * 1.7 + _phase_offsets.y) + 0.4 * sin(at * 4.3 + 1.0)) * 6.0 * wobble


func is_inside() -> bool:
	return offset.length() <= TARGET_RADIUS


func tick(delta: float) -> void:
	super(delta)
	if phase != "steady":
		return
	offset += drift(steady_time) * delta
	steady_time += delta
	if is_inside():
		inside_time += delta
	if steady_time >= STEADY_TIME:
		_end()


func steadiness() -> float:
	return clampf(inside_time / STEADY_TIME, 0.0, 1.0)


func score() -> int:
	var points := int(VEIN_INFO.get(vein, {}).get("points", 0)) + angle_points
	if phase == "steady" or phase == "done":
		points += int(round(STEADY_POINTS * steadiness()))
	return clampi(points, 0, 100)


func instruction() -> String:
	match phase:
		"vein":
			return "Tap the vein you'd use"
		"angle":
			return "Set the needle's angle, then insert"
		"steady":
			return "Drag to keep the needle tip in the circle: %.1f s" % maxf(0.0, STEADY_TIME - steady_time)
	return "Line in"


func progress() -> float:
	match phase:
		"vein":
			return 0.0
		"angle":
			return 0.33
		"steady":
			return 0.66 + 0.34 * steady_time / STEADY_TIME
	return 1.0


func _end() -> void:
	phase = "done"
	var held := steadiness()
	_note(vein == "forearm", str(VEIN_INFO[vein]["note"]))
	if angle_points >= ANGLE_POINTS:
		_note(true, "A %d degree angle: shallow enough to slide into the vein, not through it." % int(round(angle)))
	else:
		_note(false, "%d degrees. Aim for 15 to 30: steeper goes through the vein, flatter skates under the skin." %
			int(round(angle)))
	if held >= 0.8:
		_note(true, "Steady hands: the tip stayed in the vein %d%% of the time." % int(round(held * 100)))
		_say("Flashback. You're in. Tape it down.")
	elif held >= 0.4:
		_note(false, "The tip wandered out %d%% of the time. Brace your little finger on the arm." %
			int(round((1.0 - held) * 100)))
		_say("You're in. Just. Tape it before it changes its mind.")
	else:
		_note(false, "The tip spent most of the time outside the vein. On a real arm, that's a bruise and an apology.")
		_say("You've blown the vein. It happens. Don't make a habit of it.", true)
	_finish()
