class_name CrisisView
extends TrainingView
## A hospital crisis as a puzzle (see CrisisTask): the facts on a card under
## the header, the question on the right with its answers, and whoever is
## in the middle of it in the speech box. Pick, then confirm; urgent steps
## count down on hard and extreme. In the power cut the room goes dark until
## the lights come back.

## Width of the question panel, and of the text inside its buttons.
const PANEL_WIDTH := 380.0
const TEXT_WIDTH := 318.0

var _panel: PanelContainer
var _prompt: Label
var _scroll: ScrollContainer
var _body: VBoxContainer
var _clock: Label
var _hint: Button
var _confirm: Button
var _card: PanelContainer
var _card_facts: VBoxContainer
var _card_scroll: ScrollContainer
var _dark: ColorRect
var _shown_step := -1
var _shown_facts := -1
## Buttons on show for the step: option id, item id, or "item|choice".
var _buttons := {}
## Each button's state when last styled, so it's only restyled on a change.
var _marked := {}


func _build() -> void:
	var crisis := _crisis()
	trainer = crisis.actor
	_dark = ColorRect.new()
	_dark.name = "Dark"
	_dark.color = Color(0.0, 0.01, 0.03, 0.62)
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(_dark)
	add_child(_dark)
	move_child(_dark, 0)
	_panel = _right_panel(PANEL_WIDTH)
	_panel.name = "Crisis"
	_panel.anchor_bottom = 1.0
	_panel.offset_bottom = -UiKit.px(12)
	var column := UiKit.vbox(8)
	_panel.add_child(column)
	_prompt = UiKit.label("", 14, UiKit.TEXT, UiKit.heavy_font())
	_prompt.name = "Prompt"
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.custom_minimum_size = Vector2(UiKit.px(PANEL_WIDTH - 24), 0)
	column.add_child(_prompt)
	_scroll = ScrollContainer.new()
	_scroll.name = "Answers"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_body = UiKit.vbox(6)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)
	_clock = UiKit.label("", 13, UiKit.CORAL, UiKit.heavy_font())
	_clock.name = "Clock"
	column.add_child(_clock)
	var row := UiKit.hbox(8)
	column.add_child(row)
	_hint = small_button("Ask", 42, 13)
	_hint.name = "Hint"
	_hint.pressed.connect(ask_hint)
	row.add_child(_hint)
	_confirm = UiKit.primary_button("Confirm", 42, 15)
	_confirm.name = "Confirm"
	_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm.pressed.connect(confirm)
	row.add_child(_confirm)
	_build_card()
	_sync()


func _build_card() -> void:
	_card = UiKit.panel(Color(1, 1, 1, 0.94), 14, Vector2(12, 6))
	_card.name = "FactCard"
	_card.custom_minimum_size = Vector2(UiKit.px(300), 0)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	var column := UiKit.vbox(2)
	_card.add_child(column)
	column.add_child(UiKit.label(_crisis().card_title, 11, UiKit.TEAL, UiKit.heavy_font()))
	# The facts scroll if they'd run off the bottom of the screen.
	_card_scroll = ScrollContainer.new()
	_card_scroll.name = "Facts"
	_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_card_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(_card_scroll)
	_card_facts = UiKit.vbox(2)
	_card_facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_scroll.add_child(_card_facts)


func _crisis() -> CrisisTask:
	return task as CrisisTask


func _kicker_text() -> String:
	return _crisis().spot if task != null else "Crisis"


# --- What the player does (also used by the bot and the tests) --------------------------

func pick(option_id: String) -> void:
	if result_open():
		return
	_crisis().choose(option_id)
	_sync()


func toggle(item_id: String) -> void:
	if result_open():
		return
	_crisis().toggle(item_id)
	_sync()


func assign(item_id: String, choice_id: String) -> void:
	if result_open():
		return
	_crisis().assign(item_id, choice_id)
	_sync()


func confirm() -> void:
	if result_open():
		return
	_crisis().confirm()
	_sync()


func ask_hint() -> void:
	if result_open():
		return
	_crisis().hint()
	_sync()


## The button for an option or item on show, or for an item's choice.
func answer_button(answer_id: String, choice_id: String = "") -> Button:
	return _buttons.get(answer_id if choice_id.is_empty() else "%s|%s" % [answer_id, choice_id])


# --- Drawing --------------------------------------------------------------------------

func _tick(_delta: float) -> void:
	_sync()


func _sync() -> void:
	var crisis := _crisis()
	if crisis == null or _prompt == null:
		return
	voice_override = crisis.speaker
	speaker_override = str(StoryBook.cast().get(crisis.speaker, {}).get("name", crisis.speaker.capitalize()))
	if crisis.facts.size() != _shown_facts:
		_fill_card()
	if crisis.step_index != _shown_step:
		_fill_step()
	var step := crisis.current()
	_prompt.text = str(step.get("prompt", "")) if not crisis.finished else crisis.case_title
	for key: String in _buttons:
		var button: Button = _buttons[key]
		var parts := key.split("|")
		var on := false
		var blocked := crisis.finished
		match crisis.kind():
			"each":
				if parts.size() == 2:
					on = crisis.choice_of(parts[0]) == parts[1]
					blocked = blocked or (not on and not crisis.choice_open(parts[1]))
					button.text = _choice_text(step, parts[1])
			_:
				on = crisis.is_picked(key)
		button.disabled = blocked
		_mark(button, key, on)
	var urgent := crisis.time_left >= 0.0 and not crisis.finished
	var minute := crisis.time_total >= 0.0 and not crisis.finished
	_clock.visible = urgent or minute
	if minute:
		# The 60-second case: one clock for the whole case.
		_clock.text = "%d second%s left" % [ceili(crisis.time_total), "" if ceili(crisis.time_total) == 1 else "s"]
	elif urgent:
		_clock.text = "%d seconds to decide" % ceili(crisis.time_left)
	_hint.visible = crisis.hints_allowed() and not crisis.finished
	var cost := crisis.hint_cost()
	_hint.text = "Ask %s%s" % [_first_name(crisis.actor), " · -%d" % cost if cost > 0 else ""]
	_confirm.disabled = not crisis.can_confirm()
	# Lights out in the power cut, until the last step (the lights come back).
	_dark.visible = crisis.dark and not crisis.finished and str(step.get("id", "")) != "s5"
	_place_card()


## How the player would call them: "Dr. Iyer", "Mr. Malhotra", "Sister Grace", "Tom".
func _first_name(cast_id: String) -> String:
	var full := str(StoryBook.cast().get(cast_id, {}).get("name", cast_id.capitalize()))
	if cast_id == "malhotra":
		# The administrator is Mr. Malhotra to everyone, including his mother.
		return "Mr. Malhotra"
	var words := full.split(" ")
	if words.size() >= 2 and words[0] in ["Dr.", "Mr.", "Mrs.", "Ms."]:
		return "%s %s" % [words[0], words[words.size() - 1]]
	if words.size() >= 2 and words[0] == "Sister":
		return "Sister " + words[1]
	return words[0]


func _fill_card() -> void:
	var crisis := _crisis()
	_shown_facts = crisis.facts.size()
	for child in _card_facts.get_children():
		_card_facts.remove_child(child)
		child.queue_free()
	for fact in crisis.facts:
		var line := UiKit.label("• " + fact, 12, UiKit.INK, UiKit.heavy_font())
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(UiKit.px(276), 0)
		_card_facts.add_child(line)


func _fill_step() -> void:
	var crisis := _crisis()
	_shown_step = crisis.step_index
	_buttons.clear()
	_marked.clear()
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_scroll.scroll_vertical = 0
	var step := crisis.current()
	if step.is_empty():
		return
	match crisis.kind():
		"one":
			for option: Dictionary in step.get("options", []):
				_add_answer(str(option["id"]), str(option["text"]), pick.bind(str(option["id"])))
		"some":
			for item: Dictionary in step.get("items", []):
				var text := str(item["text"])
				if not str(item.get("detail", "")).is_empty():
					text += "\n" + str(item["detail"])
				_add_answer(str(item["id"]), text, toggle.bind(str(item["id"])))
		"each":
			for item: Dictionary in step.get("items", []):
				_add_item_row(step, item)


func _add_answer(answer_id: String, text: String, action: Callable) -> void:
	var button := Button.new()
	button.name = answer_id.to_pascal_case()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tall := UiKit.wrapped_height(text, UiKit.px(TEXT_WIDTH), 12, UiKit.heavy_font())
	button.custom_minimum_size = Vector2(0, maxf(UiKit.px(40), tall + UiKit.px(16)))
	button.pressed.connect(action)
	_body.add_child(button)
	_buttons[answer_id] = button
	_mark(button, answer_id, false)


func _add_item_row(step: Dictionary, item: Dictionary) -> void:
	var item_id := str(item["id"])
	var box := UiKit.panel(Color(1, 1, 1, 0.05), 12, Vector2(10, 8))
	box.name = item_id.to_pascal_case()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(box)
	var column := UiKit.vbox(4)
	box.add_child(column)
	var who := UiKit.label(str(item["text"]), 13, UiKit.TEXT, UiKit.heavy_font())
	who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	who.custom_minimum_size = Vector2(UiKit.px(TEXT_WIDTH), 0)
	column.add_child(who)
	if not str(item.get("detail", "")).is_empty():
		var detail := UiKit.label(str(item["detail"]), 12, UiKit.TEXT_SOFT)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.custom_minimum_size = Vector2(UiKit.px(TEXT_WIDTH), 0)
		column.add_child(detail)
	var chips := UiKit.grid(2 if _has_limit(step) else 4, 4)
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(chips)
	for choice: Dictionary in step.get("choices", []):
		var choice_id := str(choice["id"])
		var button := Button.new()
		button.name = choice_id.to_pascal_case()
		button.text = _choice_text(step, choice_id)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(UiKit.px(70), UiKit.px(34))
		button.clip_text = true
		button.pressed.connect(assign.bind(item_id, choice_id))
		chips.add_child(button)
		var key := "%s|%s" % [item_id, choice_id]
		_buttons[key] = button
		_mark(button, key, false)


func _has_limit(step: Dictionary) -> bool:
	for choice: Dictionary in step.get("choices", []):
		if choice.has("limit"):
			return true
	return false


## A choice's name, with how many are left when it runs out.
func _choice_text(step: Dictionary, choice_id: String) -> String:
	for choice: Dictionary in step.get("choices", []):
		if str(choice["id"]) == choice_id:
			if choice.has("limit"):
				return "%s · %d left" % [choice["text"], maxi(0, _crisis().choice_left(choice_id))]
			return str(choice["text"])
	return choice_id


## Filled mint when chosen, outlined when not.
func _mark(button: Button, key: String, on: bool) -> void:
	if _marked.get(key, null) == on:
		return
	_marked[key] = on
	var fill := UiKit.MINT if on else Color(12 / 255.0, 30 / 255.0, 36 / 255.0, 0.85)
	var normal := UiKit.box(fill, 10, UiKit.MINT if on else Color(UiKit.MINT, 0.45), 2, Vector2(10, 6))
	UiKit._style_button(button, normal, normal, UiKit.MINT_TEXT if on else UiKit.TEXT, 12, UiKit.heavy_font())


func _place_card() -> void:
	if _header == null or _card == null:
		return
	_card.position = Vector2(_header.position.x, _header.position.y + _header.get_combined_minimum_size().y + UiKit.px(8))
	# The facts' own height, measured from the text (labels that wrap report
	# nonsense before their first layout).
	var tall := 0.0
	for fact in _crisis().facts:
		var one := UiKit.wrapped_height("• " + fact, UiKit.px(276), 12, UiKit.heavy_font())
		var line := UiKit.heavy_font().get_height(UiKit.scaled_text(12))
		# Labels add their line spacing between wrapped lines, plus the gap.
		tall += one + 3.0 * maxf(0.0, roundf(one / maxf(line, 1.0)) - 1.0) + UiKit.px(2) + 1.0
	var room := UiKit.safe_insets()
	# The facts come first: on a short screen the speech box steps aside
	# (the line is still spoken) rather than the card being cut short.
	var left := get_viewport_rect().size.y - room.z - _card.position.y - UiKit.px(12 + 34)
	_card_scroll.custom_minimum_size = Vector2(UiKit.px(276), clampf(tall, UiKit.px(40), maxf(left, UiKit.px(60))))
	# Sized now, not at the next layout, so the speech box knows at once
	# whether the card reaches down to it.
	_card.size = _card.get_combined_minimum_size()


func _hide_controls() -> void:
	_panel.visible = false
	_card.visible = false
	_dark.visible = false


func _side_card() -> Control:
	return _card
