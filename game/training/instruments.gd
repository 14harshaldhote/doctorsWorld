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
	"syringe": "Syringe",
	"port": "Port",
	"camera": "Camera",
	"clip": "Clip applier",
	"hook": "Hook",
	"mesh": "Mesh",
	"wire": "Guide wire",
	"drill": "Drill",
	"plate": "Screw and plate",
}
## Instruments only some operations use (keyhole, wound care, hernias). Not
## in training, and not on every tray.
const EXTRA := ["syringe", "port", "camera", "clip", "hook", "mesh", "wire", "drill", "plate"]
const JOBS := {
	"scalpel": "Cut through skin",
	"forceps": "Hold tissue, gently",
	"retractor": "Hold the wound open",
	"needle_holder": "Grip the needle to stitch",
	"scissors": "Cut thread and stitches",
	"clamp": "Close off a bleeding vessel",
	"suction": "Clear blood so you can see",
	"swab": "Soak up blood and press on oozing",
	"syringe": "Numb the skin, or wash a wound out",
	"port": "A tube through the skin for keyhole tools",
	"camera": "Look inside, with the gas to make room",
	"clip": "Close a duct or a vessel with metal clips",
	"hook": "Burn through tissue to peel it free",
	"mesh": "Patch a weak spot in the muscle",
	"wire": "Mark a screw's path through bone, under X-ray",
	"drill": "Drill a channel in bone over the wire",
	"plate": "Hold a broken bone together while it heals",
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


## How far along -z each model's working tip reaches, in metres.
const TIPS := {"scalpel": 0.062, "forceps": 0.07, "retractor": 0.057, "needle_holder": 0.039, "scissors": 0.07,
	"clamp": 0.062, "suction": 0.1, "swab": 0.0, "syringe": 0.075, "port": 0.06, "camera": 0.1, "clip": 0.08,
	"hook": 0.09, "mesh": 0.0, "wire": 0.11, "drill": 0.09, "plate": 0.0}


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
		"syringe":
			LowPoly.put(root, LowPoly.cylinder(0.008, 0.008, 0.08, 8, Color("#EEF4F6")), Vector3(0, 0.008, 0.01),
				Vector3(PI / 2, 0, 0))
			LowPoly.put(root, LowPoly.cylinder(0.0015, 0.0015, 0.035, 5, STEEL), Vector3(0, 0.008, -0.05),
				Vector3(PI / 2, 0, 0))
			LowPoly.put(root, LowPoly.box(Vector3(0.024, 0.004, 0.006), HANDLE), Vector3(0, 0.008, 0.052))
		"port":
			LowPoly.put(root, LowPoly.cylinder(0.006, 0.006, 0.1, 8, STEEL), Vector3(0, 0.006, -0.01), Vector3(PI / 2, 0, 0))
			LowPoly.put(root, LowPoly.cylinder(0.012, 0.012, 0.022, 8, Color("#4FA0D8")), Vector3(0, 0.008, 0.045),
				Vector3(PI / 2, 0, 0))
		"camera", "hook":
			LowPoly.put(root, LowPoly.cylinder(0.005, 0.005, 0.15, 8, STEEL), Vector3(0, 0.005, -0.02), Vector3(PI / 2, 0, 0))
			LowPoly.put(root, LowPoly.box(Vector3(0.02, 0.016, 0.04), Color("#2B2F33") if instrument == "camera" else HANDLE),
				Vector3(0, 0.008, 0.07))
			if instrument == "hook":
				LowPoly.put(root, LowPoly.box(Vector3(0.008, 0.003, 0.003), STEEL_DARK), Vector3(0.004, 0.005, -0.095))
		"clip":
			_hinged(root, "clamp")
			LowPoly.put(root, LowPoly.box(Vector3(0.006, 0.006, 0.01), Color("#E0E6EA")), Vector3(0.004, 0.004, -0.068))
		"mesh":
			LowPoly.put(root, LowPoly.box(Vector3(0.07, 0.003, 0.05), Color("#DDE8F0")), Vector3(0, 0.002, 0))
			for line in 3:
				LowPoly.put(root, LowPoly.box(Vector3(0.07, 0.004, 0.002), Color("#A9BCCB")), Vector3(0, 0.003, -0.015 + 0.015 * line))
		"wire":
			# A long thin wire with a threaded tip, held in a small handle.
			LowPoly.put(root, LowPoly.cylinder(0.0015, 0.0015, 0.2, 5, STEEL), Vector3(0, 0.004, -0.02), Vector3(PI / 2, 0, 0))
			LowPoly.put(root, LowPoly.box(Vector3(0.014, 0.012, 0.03), HANDLE), Vector3(0, 0.006, 0.07))
		"drill":
			# A power drill: the body and grip, and a hollow bit to run over the wire.
			LowPoly.put(root, LowPoly.box(Vector3(0.03, 0.03, 0.07), Color("#E5E9EA")), Vector3(0, 0.015, 0.03))
			LowPoly.put(root, LowPoly.box(Vector3(0.022, 0.05, 0.022), Color("#4FA0D8")), Vector3(0, 0.02, 0.06), Vector3(0.5, 0, 0))
			LowPoly.put(root, LowPoly.cylinder(0.004, 0.004, 0.07, 6, STEEL), Vector3(0, 0.015, -0.04), Vector3(PI / 2, 0, 0))
		"plate":
			# A side plate with its barrel, and the big screw that slides into it.
			LowPoly.put(root, LowPoly.box(Vector3(0.016, 0.004, 0.09), STEEL), Vector3(0, 0.003, 0.0))
			for hole in 4:
				LowPoly.put(root, LowPoly.cylinder(0.003, 0.003, 0.005, 6, STEEL_DARK), Vector3(0, 0.004, -0.03 + 0.02 * hole))
			LowPoly.put(root, LowPoly.cylinder(0.005, 0.005, 0.06, 8, Color("#D9B25A")), Vector3(0.024, 0.005, -0.01),
				Vector3(PI / 2, 0, 0))
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
