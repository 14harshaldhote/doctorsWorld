class_name InstrumentView
extends TrainingView
## Know your instruments. First part: a job appears in the white card and
## the player taps the instrument on the tray that does it. Second part:
## Dr. Iyer calls for things mid-operation and the player asks Tom for each
## one on the instrument ring, against the clock.

var ring: InstrumentRing
var _prompt: PanelContainer
var _prompt_kicker: Label
var _prompt_text: Label
var _timer_track: Control
var _timer_fill: ColorRect
var _shown_round := ""


func _build() -> void:
	_prompt = UiKit.panel(Color(1, 1, 1, 0.96), 16, Vector2(16, 10))
	_prompt.name = "Prompt"
	_prompt.position = Vector2(UiKit.px(324), UiKit.px(12))
	_prompt.custom_minimum_size = Vector2(UiKit.px(290), 0)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)
	var column := UiKit.vbox(4)
	_prompt.add_child(column)
	_prompt_kicker = UiKit.label("", 11, UiKit.TEAL, UiKit.heavy_font())
	column.add_child(_prompt_kicker)
	_prompt_text = UiKit.label("", 17, UiKit.INK, UiKit.heading_font())
	_prompt_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_text.custom_minimum_size = Vector2(UiKit.px(258), 0)
	column.add_child(_prompt_text)
	_timer_track = Control.new()
	_timer_track.custom_minimum_size = Vector2(0, UiKit.px(5))
	column.add_child(_timer_track)
	var back := ColorRect.new()
	back.color = Color(UiKit.INK, 0.12)
	UiKit.fill(back)
	_timer_track.add_child(back)
	_timer_fill = ColorRect.new()
	_timer_fill.color = UiKit.AMBER
	UiKit.fill(_timer_fill)
	_timer_track.add_child(_timer_fill)
	ring = InstrumentRing.new()
	ring.name = "Ring"
	ring.anchor_left = 1.0
	ring.anchor_right = 1.0
	ring.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ring.offset_right = -UiKit.px(16)
	ring.offset_top = UiKit.px(70)
	ring.picked.connect(pick)
	add_child(ring)
	_sync()


func _tray() -> InstrumentTask:
	return task as InstrumentTask


## Picking an instrument, on the tray or on the ring.
func pick(instrument: String) -> void:
	var tray := _tray()
	if result_open() or tray.finished or tray.revealing:
		return
	var right := instrument == tray.wanted
	if not right:
		var trolley := station() as InstrumentTrolley
		if trolley != null:
			trolley.flash_wrong(instrument)
		if tray.part == "call":
			ring.mark(instrument, "wrong")
	tray.pick(instrument)
	_sync()


func world_tap(screen_point: Vector2) -> void:
	var trolley := station() as InstrumentTrolley
	var camera := view_camera()
	if trolley == null or camera == null:
		return
	var found := trolley.instrument_at(camera, screen_point)
	if not found.is_empty():
		pick(found)


func _tick(_delta: float) -> void:
	_sync()


func _sync() -> void:
	var tray := _tray()
	if tray == null or ring == null:
		return
	var round_key := "%s%d" % [tray.part, tray.round_index]
	if round_key != _shown_round:
		_shown_round = round_key
		ring.clear_marks()
	if tray.revealing and tray.part == "call":
		ring.mark(tray.handed, "right")
	ring.visible = tray.part == "call"
	_prompt.visible = tray.part != "done"
	if tray.part == "match":
		_prompt_kicker.text = "THE JOB · TAP IT ON THE TRAY"
	else:
		_prompt_kicker.text = "DR. IYER"
	_prompt_text.text = tray.prompt if tray.part == "match" else "\"%s\"" % tray.prompt
	_timer_track.visible = tray.part == "call"
	_timer_fill.anchor_right = clampf(tray.time_left / InstrumentTask.CALL_TIME, 0.0, 1.0)
	_timer_fill.color = UiKit.AMBER if tray.time_left > 2.0 else UiKit.CORAL


func _hide_controls() -> void:
	ring.visible = false
	_prompt.visible = false
