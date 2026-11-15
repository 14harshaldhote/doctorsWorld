class_name ReaderPanel
extends Control
## A page of reading over the settings: the privacy policy, or the
## acknowledgements with their pages (thanks, Godot's parts, the licence
## texts) picked with chips along the top. Done closes it.

signal closed

var title_text := ""
## Each page: [chip name, Callable returning the page's BBCode].
var pages: Array = []
var page := -1
var text: RichTextLabel
var done_button: Button
var page_chips: Array[Button] = []


func _init(title: String = "", page_list: Array = []) -> void:
	title_text = title
	pages = page_list


static func privacy() -> ReaderPanel:
	return ReaderPanel.new(AboutTexts.PRIVACY_TITLE, [["", AboutTexts.privacy]])


static func acknowledgements() -> ReaderPanel:
	var made: Array = []
	for index in AboutTexts.THANKS_PAGES.size():
		made.append([AboutTexts.THANKS_PAGES[index], AboutTexts.thanks_page.bind(index)])
	return ReaderPanel.new(AboutTexts.THANKS_TITLE, made)


func _ready() -> void:
	name = "Reader"
	theme = UiKit.theme()
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.08, 0.1, 0.6)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiKit.fill(shade))
	var card := UiKit.panel(Color(10 / 255.0, 26 / 255.0, 31 / 255.0, 0.99), 20, Vector2(22, 16))
	card.name = "Card"
	var card_style := card.get_theme_stylebox("panel") as StyleBoxFlat
	card_style.border_color = Color(UiKit.MINT, 0.3)
	card_style.set_border_width_all(2)
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
	titles.add_child(UiKit.kicker("Doctors World"))
	titles.add_child(UiKit.heading(title_text, 24))
	done_button = UiKit.primary_button("Done", 44, 17)
	done_button.name = "Done"
	done_button.custom_minimum_size.x = UiKit.px(120)
	done_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	done_button.pressed.connect(close)
	header.add_child(done_button)

	if pages.size() > 1:
		var chips := UiKit.flow(8)
		column.add_child(chips)
		for index in pages.size():
			var chip := UiKit.chip(str(pages[index][0]), index == 0, 36)
			chip.name = str(pages[index][0]).replace(" ", "").replace("'", "")
			chip.pressed.connect(show_page.bind(index))
			chips.add_child(chip)
			page_chips.append(chip)

	text = RichTextLabel.new()
	text.name = "Text"
	text.bbcode_enabled = true
	text.scroll_active = true
	text.selection_enabled = false
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_font_override("normal_font", UiKit.body_font())
	text.add_theme_font_override("bold_font", UiKit.heading_font())
	text.add_theme_font_size_override("normal_font_size", UiKit.scaled_text(15))
	text.add_theme_font_size_override("bold_font_size", UiKit.scaled_text(15))
	text.add_theme_color_override("default_color", UiKit.TEXT)
	text.add_theme_constant_override("line_separation", int(UiKit.px(3)))
	column.add_child(text)
	show_page(0)


## Shows a page by index, as a tap on its chip does.
func show_page(index: int) -> void:
	if index < 0 or index >= pages.size():
		return
	for other in page_chips.size():
		UiKit.set_chip(page_chips[other], other == index)
	if index == page:
		return
	page = index
	text.text = str((pages[index][1] as Callable).call())
	text.scroll_to_line(0)


## The words on the page now, without the formatting.
func page_text() -> String:
	return text.get_parsed_text()


func close() -> void:
	closed.emit()
	queue_free()
