class_name WelcomeCard
extends CanvasLayer
## The card on the first open of a new real-world day: the XP for coming
## in, how many days in a row, and what tomorrow is worth. One button on.

signal closed

var reward := {}
var go_button: Button
var _done := false


func _init(for_reward: Dictionary = {}) -> void:
	reward = for_reward


func _ready() -> void:
	name = "WelcomeCard"
	layer = 60
	var root := Control.new()
	root.name = "Root"
	root.theme = UiKit.theme()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UiKit.fill(root))
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.08, 0.1, 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(UiKit.fill(shade))
	var centre := CenterContainer.new()
	root.add_child(UiKit.fill(centre))
	var card := UiKit.panel(Color(12 / 255.0, 30 / 255.0, 36 / 255.0, 0.98), 20, Vector2(28, 22))
	card.name = "Card"
	card.custom_minimum_size.x = UiKit.px(440)
	var style := card.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color = Color(UiKit.AMBER, 0.5)
	style.set_border_width_all(2)
	centre.add_child(card)
	var column := UiKit.vbox(10)
	card.add_child(column)
	column.add_child(UiKit.kicker("Welcome back"))
	var streak := int(reward.get("streak", 1))
	var headline := UiKit.heading("Day %d in a row" % streak if streak >= 2 else "Good to see you", 24)
	headline.name = "Headline"
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(headline)
	var row := UiKit.hbox(10)
	column.add_child(row)
	var icon := UiIcon.make("star", 26, UiKit.AMBER)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var body := UiKit.label("+%d XP for coming in today." % int(reward.get("xp", 0)), 17, UiKit.AMBER, UiKit.heavy_font())
	body.name = "Body"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(body)
	var small := UiKit.label(_tomorrow_text(streak), 13, UiKit.TEXT_SOFT)
	small.name = "Tomorrow"
	small.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(small)
	var buttons := UiKit.hbox(12)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(buttons)
	go_button = UiKit.primary_button("Start the day", 46, 17)
	go_button.name = "Go"
	go_button.custom_minimum_size.x = UiKit.px(170)
	go_button.pressed.connect(close)
	buttons.add_child(go_button)
	UiKit.pop_in(card)


func _tomorrow_text(streak: int) -> String:
	var next := int(reward.get("next", 0))
	if streak - 1 >= DailyReward.MAX_STEPS:
		return "Tomorrow is worth +%d XP again. A full week, every day. The ward has noticed." % next
	return "Come back tomorrow for +%d XP. The streak grows every day for a week." % next


func close() -> void:
	if _done:
		return
	_done = true
	Sfx.play(get_parent(), "chime", -10.0)
	closed.emit()
	queue_free()
