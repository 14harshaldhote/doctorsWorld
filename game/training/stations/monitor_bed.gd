class_name MonitorBed
extends LabStation
## Read the monitor: a bed with a plastic patient wired to a monitor on a
## stand. The screen's pulse light beats with the heart rate on show; the
## numbers themselves are read on the big monitor drawn over the scene.

var _pulse: MeshInstance3D
var _chest: Node3D
var _clock := 0.0
var _beat := 0.0


func _init() -> void:
	id = "monitor"
	name = "MonitorBed"
	trainer_spot = Vector3(1.4, 0, -0.3)
	close_from = Vector3(0.55, 1.75, 1.75)
	close_at = Vector3(-0.15, 0.9, -0.15)
	close_offset = 1.05
	tag_point = Vector3(0, 1.3, 0.1)
	footprints = [Rect2(-1.15, -0.65, 2.2, 1.05)]


func _build() -> void:
	var bed := LowPoly.joint(self, "Bed", Vector3(0, 0, -0.1))
	LowPoly.put(bed, LowPoly.box(Vector3(1.95, 0.08, 0.86), STEEL_DARK), Vector3(0, 0.5, 0))
	LowPoly.put(bed, LowPoly.box(Vector3(1.85, 0.14, 0.8), WHITE), Vector3(0, 0.61, 0))
	for x: float in [-0.9, 0.9]:
		for z: float in [-0.36, 0.36]:
			LowPoly.put(bed, LowPoly.cylinder(0.025, 0.025, 0.46, 6, STEEL_DARK), Vector3(x, 0.23, z))
			LowPoly.put(bed, LowPoly.sphere(0.04, Color("#33454A"), 6, 4), Vector3(x, 0.04, z))
	LowPoly.put(bed, LowPoly.box(Vector3(0.06, 0.5, 0.86), STEEL), Vector3(-0.97, 0.75, 0))
	LowPoly.put(bed, LowPoly.box(Vector3(0.06, 0.3, 0.86), STEEL), Vector3(0.97, 0.65, 0))
	LowPoly.put(bed, LowPoly.box(Vector3(0.36, 0.08, 0.5), Color.WHITE), Vector3(-0.7, 0.72, 0), Vector3(0, 0, 0.12))
	# The plastic patient under a sheet.
	LowPoly.put(bed, LowPoly.sphere(0.12, PLASTIC, 8, 5), Vector3(-0.68, 0.82, 0))
	_chest = LowPoly.joint(bed, "Chest", Vector3(-0.28, 0.76, 0))
	LowPoly.put(_chest, LowPoly.box(Vector3(0.5, 0.16, 0.38), PLASTIC), Vector3.ZERO)
	for side: float in [-1.0, 1.0]:
		LowPoly.put(bed, LowPoly.box(Vector3(0.42, 0.08, 0.09), PLASTIC), Vector3(-0.3, 0.73, 0.26 * side))
	LowPoly.put(bed, LowPoly.box(Vector3(1.05, 0.14, 0.7), Color("#BFD9EC")), Vector3(0.38, 0.74, 0))
	LowPoly.put(bed, LowPoly.box(Vector3(0.1, 0.15, 0.7), Color("#A9C9E0")), Vector3(-0.12, 0.76, 0))
	# Sticky pads on the chest, with wires up to the monitor.
	for index in 3:
		LowPoly.put(_chest, LowPoly.cylinder(0.025, 0.025, 0.01, 8, Color.WHITE), Vector3(-0.12 + index * 0.1, 0.085, -0.08 + (index % 2) * 0.12))
	LowPoly.put(bed, LowPoly.shadow_blob(1.1, Vector2(1.0, 0.45)), Vector3.ZERO)
	# The monitor on a pole at the head end.
	var stand := LowPoly.joint(self, "Stand", Vector3(-1.0, 0, -0.5))
	LowPoly.put(stand, LowPoly.cylinder(0.025, 0.025, 1.35, 6, STEEL_DARK), Vector3(0, 0.675, 0))
	for angle_index in 4:
		var angle := angle_index * PI / 2.0 + PI / 4.0
		LowPoly.put(stand, LowPoly.box(Vector3(0.3, 0.025, 0.04), STEEL_DARK), Vector3(cos(angle) * 0.13, 0.03, sin(angle) * 0.13),
			Vector3(0, -angle, 0))
	var screen := LowPoly.joint(stand, "Screen", Vector3(0.08, 1.5, 0.05), Vector3(-0.1, 0.5, 0))
	LowPoly.put(screen, LowPoly.box(Vector3(0.56, 0.4, 0.08), Color("#26343A")), Vector3.ZERO)
	var glass := LowPoly.box(Vector3(0.5, 0.33, 0.01), Color("#062026"))
	glass.material_override = LowPoly.glow(Color("#0B3A40"), 0.6)
	LowPoly.put(screen, glass, Vector3(0, 0.01, 0.042))
	var line := LowPoly.box(Vector3(0.44, 0.012, 0.005), Color("#8FE3A6"))
	line.material_override = LowPoly.glow(Color("#8FE3A6"), 1.2)
	LowPoly.put(screen, line, Vector3(0, 0.08, 0.048))
	for index in 4:
		var colour: Color = VitalsMonitor.COLOURS[Vitals.KINDS[index]]
		var number := LowPoly.box(Vector3(0.12, 0.05, 0.005), colour)
		number.material_override = LowPoly.glow(colour, 1.0)
		LowPoly.put(screen, number, Vector3(-0.13 + (index % 2) * 0.24, -0.03 - int(index / 2.0) * 0.08, 0.048))
	_pulse = LowPoly.sphere(0.018, Color("#FF8A8A"), 6, 4)
	_pulse.material_override = LowPoly.glow(Color("#FF8A8A"), 2.0)
	LowPoly.put(screen, _pulse, Vector3(0.21, 0.14, 0.05))
	LowPoly.put(stand, LowPoly.box(Vector3(0.02, 0.02, 0.7), Color("#33454A")), Vector3(0.35, 0.9, 0.3), Vector3(0.5, 0.9, 0))


func reset_task(_task: TrainingTask) -> void:
	_clock = 0.0
	_beat = 0.0


func show_task(task: TrainingTask, delta: float) -> void:
	var monitor := task as MonitorTask
	if monitor == null:
		return
	_clock += delta
	var period := 60.0 / maxf(20.0, float(monitor.vitals.hr))
	_beat += delta
	if _beat >= period:
		_beat = fmod(_beat, period)
	var flash := clampf(1.0 - _beat / 0.18, 0.0, 1.0)
	_pulse.scale = Vector3.ONE * (0.6 + 0.8 * flash)
	# The chest rises and falls with the breathing rate.
	var breath := sin(_clock * TAU * float(monitor.vitals.rr) / 60.0)
	_chest.scale = Vector3(1, 1.0 + 0.08 * breath, 1)
