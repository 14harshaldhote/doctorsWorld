class_name StitchView
extends TrainingView
## Stitching: tap across the cut on the practice pad to place each stitch,
## then tie off.

var _tie: Button


func _build() -> void:
	_tie = UiKit.primary_button("Tie off", 46, 17)
	_tie.name = "TieOff"
	_tie.anchor_left = 1.0
	_tie.anchor_right = 1.0
	_tie.anchor_top = 1.0
	_tie.anchor_bottom = 1.0
	_tie.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_tie.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tie.offset_right = -UiKit.px(12)
	_tie.offset_bottom = -UiKit.px(12)
	_tie.custom_minimum_size = Vector2(UiKit.px(150), UiKit.px(46))
	_tie.pressed.connect(tie_off)
	add_child(_tie)
	_sync()


func _stitch() -> StitchTask:
	return task as StitchTask


## Places a stitch at a pad position in centimetres.
func place(spot: Vector2) -> bool:
	if result_open():
		return false
	var placed := _stitch().place(spot)
	_sync()
	return placed


func tie_off() -> void:
	if not result_open():
		_stitch().tie_off()
		_sync()


func world_tap(screen_point: Vector2) -> void:
	var pad := station() as SuturePad
	var camera := view_camera()
	if pad == null or camera == null:
		return
	var spot: Variant = pad.pad_point(camera, screen_point)
	if spot != null:
		place(spot as Vector2)


func _tick(_delta: float) -> void:
	_sync()


func _sync() -> void:
	if _tie != null:
		_tie.disabled = _stitch().stitches.is_empty() or task.finished


func _hide_controls() -> void:
	_tie.visible = false
