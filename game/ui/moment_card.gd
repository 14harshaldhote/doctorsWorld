class_name MomentCard
extends Control
## One of the director's emotional moments (stage 26, Feelings): a patient
## in casualty, or a colleague, and a few seconds that matter. What's
## happening, what they say (in their own recorded voice), two or three
## things the doctor can do, and what that does. Done closes it; the choice
## is remembered (Feelings.choose) and may bring a message days later.

signal finished(choice: String)

var id := ""
var patient: ShiftPatient
var entry := {}
## "", then the choice the doctor picked.
var choice := ""
var done_button: Button
var _body: VBoxContainer
var _choices: VBoxContainer
var _card: PanelContainer
var _full_top := 0.0
var _full_bottom := 0.0
var _rng: SeededRandom
var _line := 0
## The recorded voice each kind of speaker uses here, picked once.
var _voices := {}


func _init(moment_id: String = "", with_patient: ShiftPatient = null) -> void:
	id = moment_id
	patient = with_patient
	entry = Feelings.moment(id)
	_rng = SeededRandom.new(absi(("moment|%s|%d" % [id, patient.look_seed if patient != null else 0]).hash()) % 1000003 + 3)


func _ready() -> void:
	name = "MomentCard"
	theme = UiKit.theme()
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.07, 0.66)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiKit.fill(shade))
	var card := UiKit.panel(Color(12 / 255.0, 26 / 255.0, 31 / 255.0, 0.99), 20, Vector2(22, 16))
	card.name = "Card"
	var style := card.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color = Color(UiKit.MINT, 0.4)
	style.set_border_width_all(2)
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.0
	card.anchor_bottom = 1.0
	var wide := minf(UiKit.px(640) * GameSettings.current.text_scale(), get_viewport_rect().size.x - UiKit.px(48))
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
	var kicker := UiKit.kicker(Feelings.fill(str(entry.get("kicker", "")), patient))
	kicker.name = "Kicker"
	column.add_child(kicker)
	var title := UiKit.heading(Feelings.fill(str(entry.get("title", "")), patient), 24)
	title.name = "Title"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	_say(entry.get("line", {}))


func _fill() -> void:
	for holder: Node in [_body, _choices]:
		for child in holder.get_children():
			holder.remove_child(child)
			child.queue_free()
	_choices.visible = choice.is_empty()
	if choice.is_empty():
		_body.add_child(_wrapped(Feelings.fill(str(entry.get("text", "")), patient), 15, UiKit.TEXT_SOFT))
		_body.add_child(_spoken(entry.get("line", {})))
		for option: Dictionary in entry.get("choices", []):
			var button := UiKit.ghost_button(Feelings.fill(str(option.get("text", "")), patient), 44, 16)
			button.name = "Choose_" + str(option.get("id", ""))
			button.focus_mode = Control.FOCUS_NONE
			button.pressed.connect(choose.bind(str(option.get("id", ""))))
			UiKit.respond_to_press(button)
			_choices.add_child(button)
		_fit.call_deferred()
		return
	# What came of it, at the top where it's seen first: what the doctor
	# did, what was said back, and what happened.
	var picked := _option(choice)
	var did := _wrapped(Feelings.fill(str(picked.get("text", "")), patient), 15, UiKit.MINT)
	did.name = "Did"
	_body.add_child(did)
	_body.add_child(_spoken(picked.get("line", {})))
	var after := _wrapped(Feelings.fill(str(picked.get("after", "")), patient), 15, UiKit.TEXT)
	after.name = "After"
	_body.add_child(after)
	done_button.visible = true
	_fit.call_deferred()


## As tall as its words need and centred, never taller than the screen.
func _fit() -> void:
	if _card == null or not is_inside_tree():
		return
	var available := size.y + _full_bottom - _full_top
	var wanted := _card.get_combined_minimum_size().y + _body.get_combined_minimum_size().y
	var spare := maxf(0.0, available - wanted)
	_card.offset_top = _full_top + spare / 2.0
	_card.offset_bottom = _full_bottom - spare / 2.0


func _option(option_id: String) -> Dictionary:
	for option: Dictionary in entry.get("choices", []):
		if str(option.get("id", "")) == option_id:
			return option
	return {}


## What the doctor does. Ignored once chosen.
func choose(option_id: String) -> void:
	if not choice.is_empty() or _option(option_id).is_empty():
		return
	choice = option_id
	_fill()
	_say(_option(option_id).get("line", {}))


## Who's speaking, for the line under the words: "Priya", "Mr. Patil",
## "His son".
func speaker_name(line: Dictionary) -> String:
	var who := str(line.get("say", ""))
	match who:
		"patient", "kid":
			return patient.called() if patient != null else ""
		"relative":
			if line.has("as"):
				return Feelings.fill(str(line["as"]), patient)
			if patient != null and not patient.company.is_empty():
				return "%s %s" % [patient.their().capitalize(), str(patient.company.get("relation", "relative"))]
			return "A relative"
	var name := str(StoryBook.cast().get(who, {}).get("name", who))
	return name.split(" ")[0] if not name.begins_with("Dr.") and not name.begins_with("Sister") else name


func _spoken(line: Dictionary) -> Control:
	var text := str(line.get("text", ""))
	var holder := UiKit.vbox(2)
	holder.name = "Line"
	if text.is_empty():
		return holder
	holder.add_child(UiKit.label(speaker_name(line).to_upper(), 11, UiKit.TEXT_KICKER, UiKit.heavy_font()))
	holder.add_child(_wrapped("\"%s\"" % text, 16, UiKit.TEXT))
	return holder


## The voice a line is said in (the same one for everything a speaker says here).
func voice_of(line: Dictionary) -> String:
	var who := str(line.get("say", ""))
	if not _voices.has(who):
		_voices[who] = Feelings.voice_for(line, patient, _rng, entry.get("voices", {}))
	return str(_voices[who])


func _say(line: Dictionary) -> void:
	_stop()
	var text := str(line.get("text", ""))
	var voice := voice_of(line)
	if text.is_empty() or voice.is_empty():
		return
	_line = Speech.say(text, voice)


func _stop() -> void:
	if _line != 0:
		Speech.stop_line(_line)
		_line = 0


func _on_done() -> void:
	_stop()
	finished.emit(choice)


func _exit_tree() -> void:
	_stop()


func _wrapped(text: String, text_size: float, colour: Color) -> Label:
	var made := UiKit.label(text, text_size, colour)
	made.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return made


## A button by its name (Choose_<id>, Done), for tests.
func button(button_name: String) -> Button:
	return find_child(button_name, true, false) as Button
