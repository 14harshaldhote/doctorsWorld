class_name InstrumentTrolley
extends LabStation
## Know your instruments: a trolley with a green drape and the eight
## instruments laid out in a row, each with its name. Tom stands behind it.
## The instrument handed over lifts off the tray; a wrong pick glows red.

const SIZE := 1.6
const SLOT := 0.15
const TRAY_HEIGHT := 0.92

var _items := {}
var _rings := {}
var _flash := {}
var _lift := {}


func _init() -> void:
	id = "instruments"
	name = "InstrumentTrolley"
	spot = Vector3(0, 0, 0.85)
	trainer_spot = Vector3(0.2, 0, -0.72)
	close_from = Vector3(0, 1.74, 0.84)
	close_at = Vector3(0, 0.94, -0.2)
	close_fov = 44.0
	close_offset = 0.08
	tag_point = Vector3(0, 1.3, 0.1)
	footprints = [Rect2(-0.7, -0.4, 1.4, 0.75)]


func _build() -> void:
	var trolley := LowPoly.joint(self, "Trolley", Vector3.ZERO)
	table(trolley, Vector3(1.32, TRAY_HEIGHT - 0.02, 0.62), STEEL)
	LowPoly.put(trolley, LowPoly.box(Vector3(1.3, 0.012, 0.6), DRAPE), Vector3(0, TRAY_HEIGHT - 0.01, 0))
	LowPoly.put(trolley, LowPoly.box(Vector3(1.3, 0.2, 0.012), DRAPE.darkened(0.1)), Vector3(0, TRAY_HEIGHT - 0.11, 0.3))
	for index in Instruments.ALL.size():
		var instrument: String = Instruments.ALL[index]
		var slot := LowPoly.joint(self, "Slot" + instrument.to_pascal_case(), Vector3(-SLOT * 3.5 + index * SLOT, TRAY_HEIGHT, -0.05))
		var model := Instruments.make(instrument)
		model.scale = Vector3.ONE * SIZE
		slot.add_child(model)
		_items[instrument] = model
		var ring := LowPoly.torus(0.05, 0.065, Color("#FF8A8A"), 14, 3)
		ring.material_override = LowPoly.glow(Color("#FF8A8A"), 1.2)
		ring.scale = Vector3(1, 0.1, 1.6)
		ring.position = Vector3(0, 0.004, 0)
		ring.visible = false
		slot.add_child(ring)
		_rings[instrument] = ring
		var tag := label3d(Instruments.name_of(instrument).replace(" ", "\n"), 30, Color.WHITE, 0.00095)
		tag.rotation = Vector3(-1.05, 0, 0)
		tag.position = Vector3(0, 0.012, 0.15)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		slot.add_child(tag)


## The point on the tray that stands for an instrument, in the lab.
func instrument_point(instrument: String) -> Vector3:
	var index := Instruments.ALL.find(instrument)
	return at(Vector3(-SLOT * 3.5 + index * SLOT, TRAY_HEIGHT + 0.01, 0.02))


## The instrument drawn nearest a screen point, or "".
func instrument_at(camera: Camera3D, screen_point: Vector2) -> String:
	var points := {}
	for instrument: String in Instruments.ALL:
		points[instrument] = instrument_point(instrument)
	return nearest_on_screen(camera, screen_point, points, UiKit.px(40))


## A wrong pick: the instrument's ring glows red for a moment.
func flash_wrong(instrument: String) -> void:
	if _rings.has(instrument):
		_flash[instrument] = 0.9


func reset_task(_task: TrainingTask) -> void:
	_flash.clear()
	_lift.clear()
	for instrument: String in _items:
		(_items[instrument] as Node3D).position = Vector3.ZERO
		(_rings[instrument] as Node3D).visible = false


func show_task(task: TrainingTask, delta: float) -> void:
	var tray := task as InstrumentTask
	if tray == null:
		return
	for instrument: String in Instruments.ALL:
		var goal := 1.0 if tray.revealing and tray.handed == instrument else 0.0
		var lift := move_toward(float(_lift.get(instrument, 0.0)), goal, delta * 4.0)
		_lift[instrument] = lift
		var model: Node3D = _items[instrument]
		# Handed over: up off the drape and across towards the doctor.
		model.position = Vector3(0, 0.07 * lift, 0.12 * lift)
		model.rotation = Vector3(0, 0, 0.3 * lift)
		var left := float(_flash.get(instrument, 0.0)) - delta
		_flash[instrument] = left
		(_rings[instrument] as Node3D).visible = left > 0.0
