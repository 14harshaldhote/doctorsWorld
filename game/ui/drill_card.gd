class_name DrillCard
extends Control
## The card that opens a drill between days: which station, who runs it, a
## true story from medicine, the free XP on offer and the best to beat.
## "Start drill" plays it; "Skip" goes straight on to the next day.

signal start_pressed
signal skip_pressed

var station := ""
var day := 4
var profile: PlayerProfile
var start_button: Button
var skip_button: Button
var fact_label: Label
var _done := false
var _card: PanelContainer
var _scroll: ScrollContainer
var _body: VBoxContainer
var _fitted := 0


func _init(for_station: String = "monitor", before_day: int = 4, for_profile: PlayerProfile = null) -> void:
	station = for_station
	day = before_day
	profile = for_profile if for_profile != null else PlayerProfile.new()


func _ready() -> void:
	name = "DrillCard"
	theme = UiKit.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	UiKit.fill(self)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.08, 0.1, 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiKit.fill(shade))
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiKit.fill(centre))
	var card := UiKit.panel(Color(12 / 255.0, 30 / 255.0, 36 / 255.0, 0.98), 20, Vector2(26, 18))
	card.name = "Card"
	card.custom_minimum_size.x = UiKit.px(600)
	var style := card.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color = Color(UiKit.MINT, 0.5)
	style.set_border_width_all(2)
	centre.add_child(card)
	_card = card
	var column := UiKit.vbox(8)
	card.add_child(column)
	column.add_child(UiKit.kicker("Between shifts · before Day %d" % day))
	var headline := UiKit.heading("%s drill" % TrainingTask.title_of(station), 23)
	headline.name = "Headline"
	column.add_child(headline)
	# The words scroll if big text on a small phone makes the card too tall.
	_scroll = ScrollContainer.new()
	_scroll.name = "Words"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_body = UiKit.vbox(8)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)
	var opener := UiKit.label(Drills.opener(station), 14, UiKit.TEXT)
	opener.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	opener.custom_minimum_size.x = UiKit.px(530)
	_body.add_child(opener)
	var fact_box := UiKit.panel(Color(1, 1, 1, 0.06), 14, Vector2(14, 10))
	fact_box.name = "Fact"
	_body.add_child(fact_box)
	var fact_row := UiKit.hbox(10)
	fact_box.add_child(fact_row)
	var icon := UiIcon.make("book", 22, UiKit.AMBER)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	fact_row.add_child(icon)
	var fact_column := UiKit.vbox(2)
	fact_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fact_row.add_child(fact_column)
	fact_column.add_child(UiKit.kicker("Did you know?", 11))
	fact_label = UiKit.label(Drills.fact_for(day), 14, Color("#F3DDB0"))
	fact_label.name = "FactText"
	fact_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fact_label.custom_minimum_size.x = UiKit.px(470)
	fact_column.add_child(fact_label)
	var reward := UiKit.label(_reward_text(), 13, UiKit.AMBER, UiKit.heavy_font())
	reward.name = "Reward"
	reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward.custom_minimum_size.x = UiKit.px(530)
	_body.add_child(reward)
	var buttons := UiKit.hbox(12)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(buttons)
	skip_button = UiKit.ghost_button("Skip to Day %d" % day, 46, 15)
	skip_button.name = "Skip"
	skip_button.custom_minimum_size.x = UiKit.px(150)
	skip_button.pressed.connect(_answer.bind(false))
	buttons.add_child(skip_button)
	start_button = UiKit.primary_button("Start drill", 46, 17)
	start_button.name = "Start"
	start_button.custom_minimum_size.x = UiKit.px(170)
	start_button.pressed.connect(_answer.bind(true))
	buttons.add_child(start_button)
	UiKit.pop_in(card)


func _process(_delta: float) -> void:
	# Wrapped text knows its height only once laid out: fit over the first frames.
	if _fitted < 4:
		_fitted += 1
		_fit_words()


## Gives the words the height they need, or what the screen has left once
## the title and buttons are in.
func _fit_words() -> void:
	if not is_inside_tree():
		return
	var needed := _body.get_combined_minimum_size().y
	var room := UiKit.safe_insets()
	var others := _card.get_combined_minimum_size().y - _scroll.custom_minimum_size.y
	var left := get_viewport_rect().size.y - UiKit.px(24) - room.z - others
	_scroll.custom_minimum_size.y = minf(needed, maxf(left, UiKit.px(80)))


## What turning up is worth, and the best to beat.
func _reward_text() -> String:
	var rank := profile.rank()
	var text := "Free XP: +%d just for turning up, +%d a star, +%d for a new best." % [
		Drills.xp(rank, 0, false), Drills.xp(rank, 1, false) - Drills.xp(rank, 0, false),
		Drills.xp(rank, 0, true) - Drills.xp(rank, 0, false)]
	var best := profile.best_score(station)
	if best >= 0:
		text += " Your best: %d." % best
	return text


func _answer(start: bool) -> void:
	if _done:
		return
	_done = true
	Sfx.play(get_parent(), "tap", -8.0)
	if start:
		start_pressed.emit()
	else:
		skip_pressed.emit()
	queue_free()
