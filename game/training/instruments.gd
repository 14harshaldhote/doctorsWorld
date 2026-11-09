class_name Instruments
extends RefCounted
## The surgical instruments: names, what each is for, what a surgeon says
## when they want one, and a low-poly model of each for trays and hands.
## Training teaches them; operations call for them.

const ALL := ["scalpel", "forceps", "retractor", "needle_holder", "scissors", "clamp", "suction", "swab"]
const NAMES := {
	"scalpel": "Scalpel",
	"forceps": "Forceps",
	"retractor": "Retractor",
	"needle_holder": "Needle holder",
	"scissors": "Scissors",
	"clamp": "Clamp",
	"suction": "Suction",
	"swab": "Swab",
}
const JOBS := {
	"scalpel": "Cut through skin",
	"forceps": "Hold tissue, gently",
	"retractor": "Hold the wound open",
	"needle_holder": "Grip the needle to stitch",
	"scissors": "Cut thread and stitches",
	"clamp": "Close off a bleeding vessel",
	"suction": "Clear blood so you can see",
	"swab": "Soak up blood and press on oozing",
}
## What a surgeon says when they need it.
const CALLS := {
	"scalpel": ["Right. Let's open. I need to cut.", "Skin incision, here. Go."],
	"forceps": ["I need to lift this tissue. Gently.", "Something to hold this edge."],
	"retractor": ["I can't see a thing. Hold the edges apart.", "Open it up for me, wider."],
	"needle_holder": ["Time to close. I'm stitching.", "Load the needle for me."],
	"scissors": ["Cut the thread. Leave a little tail.", "Trim these ends."],
	"clamp": ["That vessel is bleeding. Close it off!", "Bleeder! Stop it, now."],
	"suction": ["Too much blood in here. I can't see.", "Clear the field, quickly."],
	"swab": ["It's oozing. Press on it.", "Dab that dry for me."],
}

const STEEL := Color("#C7D3D6")
const STEEL_DARK := Color("#8FA1A6")
const HANDLE := Color("#5F7378")


static func name_of(instrument: String) -> String:
	return str(NAMES.get(instrument, instrument.capitalize()))


static func job_of(instrument: String) -> String:
	return str(JOBS.get(instrument, ""))


## A model lying flat, pointing along -z (tip away), about 14 cm long.
static func make(instrument: String) -> Node3D:
	var root := Node3D.new()
	root.name = instrument.to_pascal_case()
	match instrument:
		"scalpel":
			LowPoly.put(root, LowPoly.box(Vector3(0.016, 0.008, 0.1), HANDLE), Vector3(0, 0.004, 0.03))
			LowPoly.put(root, LowPoly.box(Vector3(0.012, 0.004, 0.045), STEEL), Vector3(0.002, 0.004, -0.04),
				Vector3(0, 0.12, 0))
		"forceps":
			for side: int in [-1, 1]:
				LowPoly.put(root, LowPoly.box(Vector3(0.008, 0.005, 0.14), STEEL), Vector3(0.008 * side, 0.003, 0),
					Vector3(0, -0.06 * side, 0))
		"retractor":
			LowPoly.put(root, LowPoly.box(Vector3(0.014, 0.006, 0.12), STEEL), Vector3(0, 0.003, 0.01))
			LowPoly.put(root, LowPoly.box(Vector3(0.04, 0.006, 0.014), STEEL_DARK), Vector3(0.013, 0.003, -0.05))
			LowPoly.put(root, LowPoly.box(Vector3(0.006, 0.018, 0.014), STEEL_DARK), Vector3(0.031, 0.01, -0.05))
		"needle_holder", "scissors", "clamp":
			_hinged(root, instrument)
		"suction":
			LowPoly.put(root, LowPoly.cylinder(0.006, 0.006, 0.12, 6, Color("#E8EEEE")), Vector3(0, 0.006, 0.0),
				Vector3(PI / 2, 0, 0))
			LowPoly.put(root, LowPoly.cylinder(0.003, 0.005, 0.04, 6, STEEL), Vector3(0, 0.006, -0.08),
				Vector3(PI / 2, 0, 0))
			LowPoly.put(root, LowPoly.cylinder(0.004, 0.004, 0.08, 6, Color("#9FD3E6")), Vector3(0.02, 0.004, 0.09),
				Vector3(PI / 2, 0, 0.5))
		"swab":
			LowPoly.put(root, LowPoly.box(Vector3(0.06, 0.012, 0.06), Color("#F7F7F2")), Vector3(0, 0.006, 0))
			LowPoly.put(root, LowPoly.box(Vector3(0.062, 0.002, 0.006), Color("#4FA0D8")), Vector3(0, 0.013, 0.012))
	return root


## Scissor-like instruments: two rings, a hinge and jaws that differ.
static func _hinged(root: Node3D, instrument: String) -> void:
	for side: int in [-1, 1]:
		LowPoly.put(root, LowPoly.torus(0.006, 0.011, STEEL_DARK, 8, 3), Vector3(0.016 * side, 0.004, 0.055))
		LowPoly.put(root, LowPoly.box(Vector3(0.005, 0.005, 0.06), STEEL), Vector3(0.008 * side, 0.004, 0.02),
			Vector3(0, -0.22 * side, 0))
	LowPoly.put(root, LowPoly.cylinder(0.005, 0.005, 0.008, 6, STEEL_DARK), Vector3(0, 0.006, -0.008))
	match instrument:
		"scissors":
			for side: int in [-1, 1]:
				LowPoly.put(root, LowPoly.box(Vector3(0.007, 0.004, 0.06), STEEL), Vector3(0.004 * side, 0.004, -0.04),
					Vector3(0, 0.1 * side, 0))
		"clamp":
			LowPoly.put(root, LowPoly.box(Vector3(0.007, 0.006, 0.055), STEEL), Vector3(0.004, 0.004, -0.035),
				Vector3(0, 0.25, 0))
			# The ratchet that locks it shut.
			LowPoly.put(root, LowPoly.box(Vector3(0.014, 0.006, 0.006), STEEL_DARK), Vector3(0, 0.005, 0.038))
		_:
			LowPoly.put(root, LowPoly.box(Vector3(0.008, 0.006, 0.03), Color("#D9B25A")), Vector3(0, 0.004, -0.024))
