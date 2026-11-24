class_name FamilyCard
extends Control
## After a death in casualty: the family in the relatives' room. Who died
## and how, one of the family saying the first words (in a recorded patient
## voice), how the doctor tells them (plainly, in medical words, or leaving
## it to Sister Priya), what that does, whose fault it was, and the porters
## taking them to the morgue. Done closes it; the name is on the wall by then.

signal finished(telling: String)

var patient: ShiftPatient
var died_text := ""
## Who is in the relatives' room: {relation, first, sex, age}.
var relative := {}
## The recorded voice the relative speaks in.
var voice := ""
## "", then the telling the doctor picked (Fates.TELLINGS).
var telling := ""
var done_button: Button
var _body: VBoxContainer
## The three ways to tell them, under the text so they never scroll away.
var _choices: VBoxContainer
var _card: PanelContainer
## The card's top and bottom offsets at full height (inside the safe area).
var _full_top := 0.0
var _full_bottom := 0.0
var _rng: SeededRandom
var _line := 0


func _init(for_patient: ShiftPatient = null, text: String = "") -> void:
	patient = for_patient
	died_text = text
	if patient != null:
		_rng = SeededRandom.new(absi(patient.look_seed) % 1000003 + 7)
		relative = family_of(patient, _rng)
		voice = PatientVoices.pick(_rng, str(relative["sex"]), int(relative["age"]), ["warm", "soft"])


## Who comes to the relatives' room: whoever came in with them, or the
## family member someone their age would have.
static func family_of(who: ShiftPatient, rng: SeededRandom) -> Dictionary:
	if not who.company.is_empty() and int(who.company.get("age", 0)) >= 16:
		return {"relation": str(who.company.get("relation", "family")), "first": str(who.company.get("first", "")),
			"sex": str(who.company.get("sex", "f")), "age": int(who.company.get("age", 40))}
	var choices: Array
	if who.age < 18:
		choices = [["mother", "f", who.age + 26], ["father", "m", who.age + 29]]
	elif who.age < 45:
		choices = [["mother", "f", who.age + 24], ["wife" if who.sex() == "m" else "husband",
			"f" if who.sex() == "m" else "m", who.age]]
	else:
		choices = [["son", "m", who.age - 27], ["daughter", "f", who.age - 25],
			["wife" if who.sex() == "m" else "husband", "f" if who.sex() == "m" else "m", who.age - 2]]
	var picked: Array = rng.pick(choices)
	return {"relation": str(picked[0]), "first": "", "sex": str(picked[1]), "age": clampi(int(picked[2]), 18, 85)}


func _ready() -> void:
	name = "FamilyCard"
	theme = UiKit.theme()
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.07, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiKit.fill(shade))
	var card := UiKit.panel(Color(12 / 255.0, 22 / 255.0, 28 / 255.0, 0.99), 20, Vector2(22, 16))
	card.name = "Card"
	var style := card.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color = Color(UiKit.TEXT_SOFT, 0.35)
	style.set_border_width_all(2)
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.0
	card.anchor_bottom = 1.0
	var wide := minf(UiKit.px(660) * GameSettings.current.text_scale(), get_viewport_rect().size.x - UiKit.px(48))
	card.offset_left = -wide / 2.0
	card.offset_right = wide / 2.0
	card.offset_top = UiKit.px(16)
	card.offset_bottom = -UiKit.px(16)
	UiKit.keep_off_edges(card)
	add_child(card)
	_card = card
	_full_top = card.offset_top
	_full_bottom = card.offset_bottom
	var column := UiKit.vbox(10)
	card.add_child(column)
	column.add_child(UiKit.kicker("The relatives' room"))
	var title := UiKit.heading("%s, %d" % [patient.full_name() if patient != null else "", patient.age if patient != null else 0], 24)
	title.name = "Title"
	column.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_body = UiKit.vbox(8)
	_body.name = "Body"
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.minimum_size_changed.connect(_fit)
	scroll.add_child(_body)
	_choices = UiKit.vbox(8)
	_choices.name = "Choices"
	column.add_child(_choices)
	done_button = UiKit.primary_button("Done", 44, 16)
	done_button.name = "Done"
	done_button.visible = false
	done_button.focus_mode = Control.FOCUS_NONE
	done_button.pressed.connect(_on_done)
	UiKit.respond_to_press(done_button)
	column.add_child(done_button)
	_fill()
	UiKit.pop_in(card, 0.3)
	_say(str(_rng.pick(Fates.family_lines("open"))) if _rng != null else "")


func _fill() -> void:
	for holder: Node in [_body, _choices]:
		for child in holder.get_children():
			holder.remove_child(child)
			child.queue_free()
	_body.add_child(_wrapped(died_text, 15, UiKit.TEXT))
	_choices.visible = telling.is_empty()
	if telling.is_empty():
		# Who is waiting matters until they're told; then what was said does.
		_body.add_child(_wrapped(intro_text(), 15, UiKit.TEXT_SOFT))
		for kind: String in Fates.TELLINGS:
			var button := UiKit.ghost_button(Fates.telling_text(kind), 44, 16)
			button.name = "Tell_" + kind
			button.focus_mode = Control.FOCUS_NONE
			button.pressed.connect(choose.bind(kind))
			UiKit.respond_to_press(button)
			_choices.add_child(button)
		_fit.call_deferred()
		return
	_body.add_child(_wrapped(Fates.after_text(telling), 15, UiKit.TEXT))
	var fault := _wrapped(Fates.family_fault_text(patient.fault), 15, UiKit.CORAL if patient.fault != "nobody" else UiKit.TEXT_SOFT)
	fault.name = "Fault"
	_body.add_child(fault)
	_body.add_child(_wrapped(Fates.morgue_text(patient.called()), 14, UiKit.TEXT_SOFT))
	done_button.visible = true
	_fit.call_deferred()


## As tall as its words need and centred, never taller than the screen
## (then the words scroll), so a tall iPad doesn't get a gap in the middle.
func _fit() -> void:
	if _card == null or not is_inside_tree():
		return
	var available := size.y + _full_bottom - _full_top
	var wanted := _card.get_combined_minimum_size().y + _body.get_combined_minimum_size().y
	var spare := maxf(0.0, available - wanted)
	_card.offset_top = _full_top + spare / 2.0
	_card.offset_bottom = _full_bottom - spare / 2.0


## "Her son is waiting by the door." / "Ramesh, his brother, is waiting..."
func intro_text() -> String:
	if patient == null:
		return ""
	var relation := "%s %s" % [patient.their(), str(relative.get("relation", "family"))]
	var first := str(relative.get("first", ""))
	var who := ("%s, %s," % [first, relation]) if not first.is_empty() else relation.substr(0, 1).to_upper() + relation.substr(1)
	return "%s is waiting by the door. They can already tell from your face." % who


## How the doctor tells the family. Ignored once told.
func choose(kind: String) -> void:
	if not telling.is_empty() or kind not in Fates.TELLINGS:
		return
	telling = kind
	_fill()
	_say(str(_rng.pick(Fates.family_lines(kind))) if _rng != null else "")


func _say(text: String) -> void:
	_stop()
	if text.is_empty() or voice.is_empty():
		return
	_line = Speech.say(text, voice)


func _stop() -> void:
	if _line != 0:
		Speech.stop_line(_line)
		_line = 0


func _on_done() -> void:
	_stop()
	finished.emit(telling)


func _exit_tree() -> void:
	_stop()


func _wrapped(text: String, size: float, colour: Color) -> Label:
	var made := UiKit.label(text, size, colour)
	made.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return made


## Button by its name (Tell_plain, Tell_jargon, Tell_nurse, Done), for tests.
func button(button_name: String) -> Button:
	return find_child(button_name, true, false) as Button
