class_name WallPanel
extends Control
## The wall by the desk on Ward 4: everyone who died on the player's watch,
## newest first, with the day, what it was, and whose fault. Nobody takes
## the names down. Done closes it.

signal closed

var entries: Array = []
var done_button: Button
var list: VBoxContainer


func _init(wall: Array = []) -> void:
	entries = wall.duplicate(true)
	entries.reverse()


func _ready() -> void:
	name = "Wall"
	theme = UiKit.theme()
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.06, 0.08, 0.66)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiKit.fill(shade))
	var card := UiKit.panel(Color(14 / 255.0, 24 / 255.0, 29 / 255.0, 0.99), 20, Vector2(22, 16))
	card.name = "Card"
	var style := card.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color = Color(UiKit.TEXT_SOFT, 0.3)
	style.set_border_width_all(2)
	UiKit.fill(card)
	card.offset_left = UiKit.px(40)
	card.offset_right = -UiKit.px(40)
	card.offset_top = UiKit.px(16)
	card.offset_bottom = -UiKit.px(16)
	UiKit.keep_off_edges(card)
	add_child(card)
	var column := UiKit.vbox(8)
	card.add_child(column)
	var header := UiKit.hbox(12)
	column.add_child(header)
	var titles := UiKit.vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	titles.add_child(UiKit.kicker("Ward 4, by the desk"))
	titles.add_child(UiKit.heading("The wall", 24))
	done_button = UiKit.primary_button("Done", 44, 17)
	done_button.name = "Done"
	done_button.custom_minimum_size.x = UiKit.px(120)
	done_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	done_button.focus_mode = Control.FOCUS_NONE
	done_button.pressed.connect(func() -> void: closed.emit())
	UiKit.respond_to_press(done_button)
	header.add_child(done_button)
	var lead := UiKit.label(lead_text(), 14, UiKit.TEXT_SOFT)
	lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(lead)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	list = UiKit.vbox(8)
	list.name = "Names"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for entry: Dictionary in entries:
		list.add_child(_row(entry))
	UiKit.pop_in(card, 0.26)


## "Three names. Every doctor has a wall; ..." with how many were nobody's
## fault.
func lead_text() -> String:
	if entries.is_empty():
		return "No names yet. Every doctor gets a wall eventually. Yours is still blank."
	var nobody := entries.filter(func(entry: Dictionary) -> bool: return str(entry.get("fault", "")) == "nobody").size()
	var count := "One name." if entries.size() == 1 else "%d names." % entries.size()
	if nobody == entries.size():
		return count + " Nobody could have saved them. You read them anyway."
	if nobody > 0:
		return count + " %d nobody could have saved. The rest, you think about." % nobody
	return count + " Every one of them, you think about."


func _row(entry: Dictionary) -> Control:
	var row := UiKit.vbox(2)
	row.name = "Name%d" % list.get_child_count()
	row.add_child(UiKit.label("%s, %d" % [str(entry.get("full", "")), int(entry.get("age", 0))], 16, UiKit.TEXT,
		UiKit.heavy_font()))
	var fault := str(entry.get("fault", ""))
	var line := UiKit.label("Day %d · %s · %s" % [int(entry.get("day", 0)), str(entry.get("what", "")),
		Fates.fault_text(fault)], 13, UiKit.TEXT_SOFT if fault == "nobody" else UiKit.CORAL)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(line)
	return row
