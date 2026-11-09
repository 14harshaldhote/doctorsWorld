class_name Lightbox
extends LabStation
## The X-ray viewer on the ward wall: a glowing panel with films clipped to
## it, and a stool. The film itself is drawn on screen by ScanView.

func _init() -> void:
	id = "scan"
	name = "Lightbox"
	spot = Vector3(0, 0, 0.85)
	trainer_spot = Vector3(0.8, 0, 0.6)
	close_from = Vector3(0.0, 1.55, 1.25)
	close_at = Vector3(0.0, 1.5, 0.0)
	close_fov = 40.0
	tag_point = Vector3(0, 2.2, 0.1)
	footprints = [Rect2(-0.5, -0.2, 1.0, 0.4)]


func _build() -> void:
	var box := LowPoly.joint(self, "Box", Vector3(0, 1.5, 0.04))
	LowPoly.put(box, LowPoly.box(Vector3(1.0, 0.7, 0.08), Color("#DDE4E4")), Vector3.ZERO)
	var glow := LowPoly.box(Vector3(0.9, 0.6, 0.01), Color("#F4FBFF"))
	glow.material_override = LowPoly.glow(Color("#F4FBFF"), 0.9)
	LowPoly.put(box, glow, Vector3(0, 0, 0.045))
	for index in 2:
		var film := LowPoly.box(Vector3(0.38, 0.5, 0.005), Color("#1A2428"))
		LowPoly.put(box, film, Vector3(-0.21 + index * 0.42, 0, 0.052))
		LowPoly.put(box, LowPoly.box(Vector3(0.05, 0.36, 0.004), Color("#8FA1A6")), Vector3(-0.21 + index * 0.42, 0.02, 0.056))
	var sign := label3d("X-RAY VIEWER", 30, TEAL, 0.0035)
	sign.position = Vector3(0, 1.95, 0.05)
	add_child(sign)
	var stool := LowPoly.joint(self, "Stool", Vector3(0.45, 0, 0.6))
	LowPoly.put(stool, LowPoly.cylinder(0.18, 0.18, 0.05, 10, Color("#1F8A8A")), Vector3(0, 0.6, 0))
	LowPoly.put(stool, LowPoly.cylinder(0.025, 0.025, 0.58, 6, STEEL_DARK), Vector3(0, 0.3, 0))
	LowPoly.put(stool, LowPoly.cylinder(0.2, 0.2, 0.03, 10, STEEL_DARK), Vector3(0, 0.02, 0))
