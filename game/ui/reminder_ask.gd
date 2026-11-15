class_name ReminderAsk
extends CanvasLayer
## The question after the first day (and once more after the first review):
## would the player like a page when patients are waiting? Yes switches
## reminders on, and the phone then asks for permission itself.

signal answered(yes: bool)

const HEADLINE := "Want a page when your patients are waiting?"
const BODY := "Dr. Iyer can page you when a new patient walks in, a hard week starts, or a winning run needs saving. " \
	+ "At most one a day, never at night, and nothing at all after a week away."
const SMALL := "Your device will ask you to allow it. Change your mind any time in Settings."

var yes_button: Button
var no_button: Button
var _done := false


func _ready() -> void:
	name = "ReminderAsk"
	layer = 60
	var root := Control.new()
	root.name = "Root"
	root.theme = UiKit.theme()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UiKit.fill(root))
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.08, 0.1, 0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(UiKit.fill(shade))

	var centre := CenterContainer.new()
	root.add_child(UiKit.fill(centre))
	var card := UiKit.panel(Color(12 / 255.0, 30 / 255.0, 36 / 255.0, 0.98), 20, Vector2(28, 22))
	card.name = "Card"
	card.custom_minimum_size.x = UiKit.px(430)
	var style := card.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color = Color(UiKit.AMBER, 0.45)
	style.set_border_width_all(2)
	centre.add_child(card)
	var column := UiKit.vbox(10)
	card.add_child(column)
	column.add_child(UiKit.kicker("Reminders"))
	var headline := UiKit.heading(HEADLINE, 22)
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(headline)
	var body := UiKit.label(BODY, 15, UiKit.TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(body)
	var small := UiKit.label(SMALL, 12, UiKit.TEXT_SOFT)
	small.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(small)
	var buttons := UiKit.hbox(12)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(buttons)
	no_button = UiKit.ghost_button("Not now", 46, 16)
	no_button.name = "NotNow"
	no_button.custom_minimum_size.x = UiKit.px(130)
	no_button.pressed.connect(answer.bind(false))
	buttons.add_child(no_button)
	yes_button = UiKit.primary_button("Page me", 46, 17)
	yes_button.name = "PageMe"
	yes_button.custom_minimum_size.x = UiKit.px(150)
	yes_button.pressed.connect(answer.bind(true))
	buttons.add_child(yes_button)
	UiKit.pop_in(card)


## The player's answer, as a tap on either button gives it.
func answer(yes: bool) -> void:
	if _done:
		return
	_done = true
	Sfx.play(get_parent(), "tap", -8.0)
	answered.emit(yes)
	queue_free()
