class_name ExamChair
extends LabStation
## Take a history: a consulting corner with a chair for the patient, a desk
## with the case notes, and a screen behind. Dr. Iyer sits in the chair and
## plays the patient.

func _init() -> void:
	id = "history"
	name = "ExamChair"
	spot = Vector3(0, 0, 1.0)
	trainer_spot = Vector3(0, 0, -0.08)
	trainer_sits = true
	close_from = Vector3(0.05, 1.42, 1.32)
	close_at = Vector3(0.0, 1.06, -0.1)
	close_fov = 40.0
	close_offset = 0.0
	tag_point = Vector3(0, 1.55, -0.1)
	footprints = [Rect2(0.42, -0.62, 0.9, 0.62), Rect2(-1.1, -0.8, 1.6, 0.35)]


func _build() -> void:
	# The patient's chair: the person sits at the joint, facing +z.
	var chair := LowPoly.joint(self, "Chair", Vector3(0, 0, -0.08))
	var seat := Color("#1F8A8A")
	LowPoly.put(chair, LowPoly.box(Vector3(0.62, 0.1, 0.56), seat), Vector3(0, 0.42, 0))
	LowPoly.put(chair, LowPoly.box(Vector3(0.62, 0.6, 0.08), seat.darkened(0.12)), Vector3(0, 0.75, -0.26))
	for side: float in [-1.0, 1.0]:
		LowPoly.put(chair, LowPoly.box(Vector3(0.06, 0.06, 0.5), seat.darkened(0.2)), Vector3(0.32 * side, 0.62, -0.02))
		LowPoly.put(chair, LowPoly.box(Vector3(0.05, 0.4, 0.05), STEEL_DARK), Vector3(0.27 * side, 0.2, 0.22))
		LowPoly.put(chair, LowPoly.box(Vector3(0.05, 0.4, 0.05), STEEL_DARK), Vector3(0.27 * side, 0.2, -0.22))
	LowPoly.put(chair, LowPoly.shadow_blob(0.42, Vector2(1.0, 0.9)), Vector3.ZERO)
	# A desk on the chair's right with the case notes and a lamp.
	var desk := LowPoly.joint(self, "Desk", Vector3(0.85, 0, -0.32))
	table(desk, Vector3(0.8, 0.76, 0.56), Color("#C9A27A"))
	LowPoly.put(desk, LowPoly.box(Vector3(0.24, 0.012, 0.3), Color("#FBFAF5")), Vector3(-0.1, 0.77, 0.05), Vector3(0, 0.2, 0))
	LowPoly.put(desk, LowPoly.box(Vector3(0.26, 0.02, 0.06), Color("#8C6B48")), Vector3(-0.1, 0.78, -0.08), Vector3(0, 0.2, 0))
	LowPoly.put(desk, LowPoly.cylinder(0.08, 0.1, 0.03, 8, STEEL_DARK), Vector3(0.24, 0.77, -0.12))
	LowPoly.put(desk, LowPoly.cylinder(0.012, 0.012, 0.36, 6, STEEL_DARK), Vector3(0.24, 0.95, -0.12))
	LowPoly.put(desk, LowPoly.cylinder(0.04, 0.09, 0.1, 8, TEAL), Vector3(0.18, 1.12, -0.12), Vector3(0, 0, 0.6))
	LowPoly.put(desk, LowPoly.cylinder(0.03, 0.03, 0.1, 8, Color.WHITE), Vector3(0.05, 0.82, 0.12))
	# A privacy screen behind the chair.
	var screen := LowPoly.joint(self, "Screen", Vector3(-0.15, 0, -0.62))
	for panel in 3:
		var x := -0.62 + panel * 0.62
		LowPoly.put(screen, LowPoly.box(Vector3(0.6, 1.5, 0.03), Color("#CFE6E2")), Vector3(x, 0.95, 0),
			Vector3(0, (panel - 1) * 0.25, 0))
		LowPoly.put(screen, LowPoly.box(Vector3(0.6, 0.04, 0.05), STEEL_DARK), Vector3(x, 1.72, 0), Vector3(0, (panel - 1) * 0.25, 0))
	var notice := label3d("ROLE PLAY · HISTORY", 40, TEAL, 0.0035)
	notice.position = Vector3(-0.15, 1.45, 0.03)
	screen.add_child(notice)
