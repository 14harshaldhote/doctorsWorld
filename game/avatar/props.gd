class_name Props
extends RefCounted
## Small things people hold: a pager, a letter, a rolled certificate, a cup
## of coffee and a phone. Each is built to sit in a hand: the hand's fingers point
## along -Y and the palm faces +Z, so with the forearm held out in front the
## prop sits the right way up.

const ITEMS := ["pager", "letter", "certificate", "coffee", "phone"]


static func make(item: String) -> Node3D:
	var prop := Node3D.new()
	match item:
		"pager":
			LowPoly.put(prop, LowPoly.box(Vector3(0.062, 0.088, 0.026), Color("#2B2F33"), "Pager"), Vector3(0, -0.02, 0.026))
			var screen := LowPoly.box(Vector3(0.044, 0.03, 0.004), Color("#8FE3A6"))
			screen.material_override = LowPoly.glow(Color("#8FE3A6"), 0.9)
			LowPoly.put(prop, screen, Vector3(0, -0.035, 0.04))
			LowPoly.put(prop, LowPoly.box(Vector3(0.016, 0.01, 0.006), Color("#F07C5A")), Vector3(0, 0.008, 0.04))
		"letter":
			LowPoly.put(prop, LowPoly.box(Vector3(0.21, 0.15, 0.004), Color("#FBFAF5"), "Letter"), Vector3(0, -0.07, 0.024))
			LowPoly.put(prop, LowPoly.box(Vector3(0.21, 0.026, 0.006), Color("#127C80")), Vector3(0, -0.13, 0.025))
			for row in 3:
				LowPoly.put(prop, LowPoly.box(Vector3(0.15, 0.008, 0.006), Color("#B7C3C6")),
					Vector3(-0.01, -0.095 + row * 0.024, 0.025))
		"certificate":
			LowPoly.put(prop, LowPoly.cylinder(0.024, 0.024, 0.3, 8, Color("#F3EBD6"), "Certificate"),
				Vector3(0, -0.01, 0.03), Vector3(0, 0, PI / 2))
			LowPoly.put(prop, LowPoly.torus(0.022, 0.03, Color("#B3263A"), 8, 4), Vector3(0, -0.01, 0.03),
				Vector3(0, 0, PI / 2))
		"coffee":
			var cup := Node3D.new()
			LowPoly.put(prop, cup, Vector3(0, -0.02, 0.018), Vector3(PI / 2, 0, 0))
			LowPoly.put(cup, LowPoly.cylinder(0.042, 0.034, 0.12, 8, Color("#F7F4EE"), "Coffee"), Vector3(0, 0.06, 0))
			LowPoly.put(cup, LowPoly.cylinder(0.043, 0.039, 0.045, 8, Color("#9A6A44")), Vector3(0, 0.055, 0))
			LowPoly.put(cup, LowPoly.cylinder(0.045, 0.045, 0.014, 8, Color("#E2DCD2")), Vector3(0, 0.124, 0))
		"phone":
			LowPoly.put(prop, LowPoly.box(Vector3(0.072, 0.148, 0.01), Color("#22262B"), "Phone"), Vector3(0, -0.06, 0.03))
			var glass := LowPoly.box(Vector3(0.062, 0.128, 0.003), Color("#7FD3E8"))
			glass.material_override = LowPoly.glow(Color("#7FD3E8"), 0.8)
			LowPoly.put(prop, glass, Vector3(0, -0.06, 0.036))
		_:
			push_error("Unknown prop: %s" % item)
	return prop
