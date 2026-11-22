class_name PatientPanel
extends Control
## The card for a patient in a casualty cubicle, on the right of the screen
## so the patient stays in view on the left: who they are, their vitals,
## three questions, an examination, the tests (each with how long it takes)
## and their results, and four plans. Every piece of work says what it costs
## in hospital minutes; the ward passes them on the clock.
##
## Nothing here changes the patient: each button asks the ward through
## acted(kind, value), and the ward calls refresh() once it's done (or
## show_result() after a plan). kinds: "ask" (a question id), "exam",
## "order" (a test id), "decide" (a position on the card), "close" (step
## away, the patient stays) and "done" (after the result).

signal acted(kind: String, value: String)

const WIDTH := 430.0
const TRIAGE_COLOURS := {"red": Color("#F07C5A"), "yellow": Color("#F5B841"), "green": Color("#8FE3D2")}
const TRIAGE_WORDS := {"red": "Red", "yellow": "Yellow", "green": "Green"}

var patient: ShiftPatient
## The hospital minute now, for "back at 09:40".
var minute := 0
## A position on the card picked but not yet confirmed, or -1.
var picked := -1
var sheet: PanelContainer
var confirm_button: Button
var close_button: Button
var done_button: Button
var _body: VBoxContainer
var _scroll: ScrollContainer
var _header: VBoxContainer
var _result := {}


func _init(for_patient: ShiftPatient = null, now: int = 0) -> void:
	patient = for_patient
	minute = now


func _ready() -> void:
	name = "PatientPanel"
	theme = UiKit.theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(self)
	sheet = UiKit.panel(Color(12 / 255.0, 30 / 255.0, 36 / 255.0, 0.97), 20, Vector2(18, 14))
	sheet.name = "Sheet"
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := sheet.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color = Color(UiKit.MINT, 0.45)
	style.set_border_width_all(2)
	sheet.anchor_left = 1.0
	sheet.anchor_right = 1.0
	sheet.anchor_top = 0.0
	sheet.anchor_bottom = 1.0
	var wide := minf(UiKit.px(WIDTH) * GameSettings.current.text_scale(), get_viewport_rect().size.x * 0.62)
	sheet.offset_left = -wide - UiKit.px(12)
	sheet.offset_right = -UiKit.px(12)
	sheet.offset_top = UiKit.px(12)
	sheet.offset_bottom = -UiKit.px(12)
	add_child(sheet)
	UiKit.keep_off_edges(sheet)
	var column := UiKit.vbox(8)
	sheet.add_child(column)
	_header = UiKit.vbox(4)
	column.add_child(_header)
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	_body = UiKit.vbox(10)
	_body.name = "Body"
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)
	var footer := UiKit.hbox(10)
	column.add_child(footer)
	close_button = UiKit.ghost_button("Step away", 44, 16)
	close_button.name = "StepAway"
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.pressed.connect(func() -> void: acted.emit("close", ""))
	footer.add_child(close_button)
	confirm_button = UiKit.primary_button("Go with this plan", 44, 16)
	confirm_button.name = "Confirm"
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_button.visible = false
	confirm_button.pressed.connect(_on_confirm)
	footer.add_child(confirm_button)
	done_button = UiKit.primary_button("Done", 44, 16)
	done_button.name = "Done"
	done_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done_button.visible = false
	done_button.pressed.connect(func() -> void: acted.emit("done", ""))
	footer.add_child(done_button)
	for button: Button in [close_button, confirm_button, done_button]:
		button.focus_mode = Control.FOCUS_NONE
		UiKit.respond_to_press(button)
	refresh()
	UiKit.slide_in(sheet, Vector2(UiKit.px(60), 0), 0.24)


## Redraws the card from the patient as they are now.
func refresh(now: int = -1) -> void:
	if now >= 0:
		minute = now
	if patient == null or _body == null:
		return
	var keep_scroll := _scroll.scroll_vertical
	_clear(_header)
	_clear(_body)
	_fill_header()
	if not _result.is_empty():
		_fill_result()
		return
	_fill_known()
	_fill_questions()
	_fill_exam()
	_fill_tests()
	_fill_plans()
	confirm_button.visible = picked >= 0
	close_button.visible = true
	done_button.visible = false
	_scroll.set_deferred("scroll_vertical", keep_scroll)


func _clear(box: Container) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()


func _fill_header() -> void:
	var where := "Cubicle %d" % (patient.cubicle + 1) if patient.cubicle >= 0 else "Casualty"
	var kicker := UiKit.kicker("%s · %s · waited %s" % [where, TRIAGE_WORDS.get(patient.triage(), "Green"),
		_minutes_text(patient.waited(minute))], 11)
	kicker.add_theme_color_override("font_color", TRIAGE_COLOURS.get(patient.triage(), UiKit.MINT))
	_header.add_child(kicker)
	var name_label := UiKit.heading("%s, %d" % [patient.full_name(), patient.age], 21)
	name_label.name = "Name"
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header.add_child(name_label)
	var said := ("Back again: " if patient.returning else "") + str(patient.condition.get("board", ""))
	if patient.invented:
		# An outbreak's fever is made up, and the card never lets it pass for real.
		said = "Invented illness: " + said
	var said_label := _wrapped(said, 14, UiKit.CORAL if patient.invented else UiKit.TEXT_SOFT)
	said_label.name = "Said"
	_header.add_child(said_label)
	var vitals := _wrapped(patient.vitals_line(), 13, UiKit.MINT, UiKit.heavy_font())
	vitals.name = "Vitals"
	_header.add_child(vitals)


## The top of the card's words: an invented illness said plainly, who they
## are and who came with them, and in amber what's known up front (a mix
## that changes the plan, like warfarin or a pregnancy, and a patient met on
## an earlier day). The header above stays short, so the questions and plans
## keep most of the card.
func _fill_known() -> void:
	if patient.invented:
		var made_up := UiKit.kicker(str(patient.condition.get("label", "Invented illness")), 11)
		made_up.name = "Invented"
		made_up.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		made_up.add_theme_color_override("font_color", UiKit.CORAL)
		_body.add_child(made_up)
	var about := patient.about_line()
	if not about.is_empty():
		var who := _wrapped(about, 13, UiKit.TEXT_KICKER)
		who.name = "About"
		_body.add_child(who)
	var known := patient.known_line()
	if known.is_empty():
		return
	var note := _wrapped(known, 14, UiKit.AMBER, UiKit.heavy_font())
	note.name = "Known"
	_body.add_child(note)


func _fill_questions() -> void:
	_body.add_child(UiKit.kicker("Ask · %d min each" % ShiftSim.ASK_MINUTES, 11))
	var answering := patient.answered_by()
	if not answering.is_empty():
		var who := _wrapped(answering, 13, UiKit.TEXT_SOFT)
		who.name = "AnsweredBy"
		_body.add_child(who)
	for question: String in ShiftPatient.QUESTIONS:
		var text := str(ShiftPatient.QUESTION_TEXT[question])
		if patient.asked.has(question):
			_body.add_child(_wrapped(text, 13, UiKit.TEXT_KICKER, UiKit.heavy_font()))
			var answer := _wrapped("\"%s\"" % str((patient.condition.get("answers", {}) as Dictionary).get(question, "")),
				15, UiKit.TEXT)
			answer.name = "Answer_" + question
			_body.add_child(answer)
		else:
			var button := _wide_button(text, "%d min" % ShiftSim.ASK_MINUTES)
			button.name = "Ask_" + question
			button.pressed.connect(func() -> void: acted.emit("ask", question))
			_body.add_child(button)


func _fill_exam() -> void:
	_body.add_child(UiKit.kicker("Examine", 11))
	if patient.examined:
		var found := _wrapped(str(patient.condition.get("exam", "")), 15, UiKit.TEXT)
		found.name = "Finding"
		_body.add_child(found)
		return
	var button := _wide_button("Examine them", "%d min" % ShiftSim.EXAM_MINUTES)
	button.name = "Examine"
	button.pressed.connect(func() -> void: acted.emit("exam", ""))
	_body.add_child(button)


func _fill_tests() -> void:
	_body.add_child(UiKit.kicker("Tests · %d min to send, results when they're ready" % ShiftSim.ORDER_MINUTES, 11))
	var chips := UiKit.flow(8)
	chips.name = "Tests"
	_body.add_child(chips)
	for test: String in Conditions.ORDER:
		var info: Dictionary = Conditions.TESTS[test]
		var ordered := patient.ordered.has(test)
		var label := "%s · %d min" % [str(info["name"]), int(info["minutes"])]
		if ordered and not patient.results.has(test):
			label = "%s · back %s" % [str(info["name"]), _clock(int(patient.ordered[test]))]
		elif ordered:
			label = "%s · back" % str(info["name"])
		var chip := UiKit.chip(label, ordered, 40)
		chip.name = "Test_" + test
		chip.focus_mode = Control.FOCUS_NONE
		chip.disabled = ordered or patient.decided()
		chip.pressed.connect(func() -> void: acted.emit("order", test))
		chips.add_child(chip)
	for test: String in Conditions.ORDER:
		if not patient.results.has(test):
			continue
		var row := UiKit.vbox(2)
		row.name = "Result_" + test
		row.add_child(UiKit.label(str(Conditions.TESTS[test]["name"]), 12, UiKit.TEXT_KICKER, UiKit.heavy_font()))
		row.add_child(_wrapped(str(patient.results[test]), 14, UiKit.TEXT))
		_body.add_child(row)


func _fill_plans() -> void:
	_body.add_child(UiKit.kicker("Plan · %d min" % ShiftSim.DECIDE_MINUTES, 11))
	if not patient.pending_tests().is_empty():
		_body.add_child(_wrapped("Results still to come. You can decide now, or wait for them.", 13, UiKit.TEXT_SOFT))
	for position in patient.plan_order.size():
		var plan := patient.shown_plan(position)
		var button := _wide_button(str(plan.get("text", "")), "", position == picked)
		button.name = "Plan%d" % (position + 1)
		button.pressed.connect(func() -> void:
			picked = position
			refresh())
		_body.add_child(button)


func _on_confirm() -> void:
	if picked >= 0:
		acted.emit("decide", str(picked))


## After the plan: right or not, why, and what it earned.
func show_result(result: Dictionary, xp: int) -> void:
	_result = result.duplicate()
	_result["xp"] = xp
	picked = -1
	refresh()


func showing_result() -> bool:
	return not _result.is_empty()


func _fill_result() -> void:
	var right := bool(_result.get("right", false))
	var headline := UiKit.heading("Right call." if right else "Not the right call.", 22)
	headline.name = "Verdict"
	headline.add_theme_color_override("font_color", UiKit.MINT if right else UiKit.CORAL)
	_body.add_child(headline)
	_body.add_child(_wrapped(str(_result.get("plan", "")), 15, UiKit.TEXT, UiKit.heavy_font()))
	var why := _wrapped(str(_result.get("why", "")), 15, UiKit.TEXT_SOFT)
	why.name = "Why"
	_body.add_child(why)
	var going := str(Conditions.DESTINATIONS.get(str(patient.condition.get("go", "")), ""))
	if right and not going.is_empty():
		_body.add_child(_wrapped("%s goes %s." % [patient.called(), going], 14, UiKit.TEXT))
	elif str(_result.get("effect", "")) == "back":
		_body.add_child(_wrapped("They'll be back. They always come back.", 14, UiKit.TEXT))
	var score := UiKit.label("Score %d · +%d XP" % [int(_result.get("score", 0)), int(_result.get("xp", 0))], 16,
		UiKit.AMBER, UiKit.heavy_font())
	score.name = "Score"
	_body.add_child(score)
	confirm_button.visible = false
	close_button.visible = false
	done_button.visible = true


## A full-width button whose words wrap, with what it costs on the right.
func _wide_button(text: String, cost: String, selected: bool = false) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var normal := UiKit.box(Color(UiKit.MINT, 0.22) if selected else Color(1, 1, 1, 0.04), 12,
		UiKit.MINT if selected else Color(UiKit.MINT, 0.45), 2, Vector2(12, 9))
	var pressed := UiKit.box(Color(UiKit.MINT, 0.18), 12, UiKit.MINT, 2, Vector2(12, 9))
	for state in ["normal", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, normal)
	button.add_theme_stylebox_override("hover", pressed)
	button.add_theme_stylebox_override("pressed", pressed)
	var row := UiKit.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = UiKit.px(12)
	row.offset_right = -UiKit.px(12)
	row.offset_top = UiKit.px(9)
	row.offset_bottom = -UiKit.px(9)
	button.add_child(row)
	var words := _wrapped(text, 15, UiKit.TEXT, UiKit.heavy_font() if selected else UiKit.body_font())
	words.name = "Words"
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	if not cost.is_empty():
		var price := UiKit.label(cost, 12, UiKit.AMBER, UiKit.heavy_font())
		price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(price)
	button.custom_minimum_size.y = UiKit.px(44)
	UiKit.fit_height(button, row, 9)
	UiKit.respond_to_press(button)
	return button


func _wrapped(text: String, size: float, colour: Color, which: Font = null) -> Label:
	var made := UiKit.label(text, size, colour, which)
	made.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return made


func _clock(at_minute: int) -> String:
	return "%02d:%02d" % [(at_minute / 60) % 24, at_minute % 60]


func _minutes_text(amount: int) -> String:
	if amount < 60:
		return "%d min" % amount
	return "%dh %02dm" % [amount / 60, amount % 60]


## Button by its name (Ask_pain, Examine, Test_ecg, Plan1, Confirm, Done,
## StepAway), for tests.
func button(button_name: String) -> Button:
	return find_child(button_name, true, false) as Button
