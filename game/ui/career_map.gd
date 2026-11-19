class_name CareerMap
extends Control
## The career map, over the paused game: the whole road from Intern to the
## never-ending days with where the doctor stands and what the next stop
## needs, the race against Dr. Varun Khanna, and the wall of letters from
## the people they looked after. Back to work closes it.

signal closed

var profile: PlayerProfile
var page := ""
var close_button: Button
var map_chip: Button
var letters_chip: Button
var body: VBoxContainer
var scroll: ScrollContainer
var reader: ReaderPanel
var _done := false


func _init(for_profile: PlayerProfile = null, first_page: String = "map") -> void:
	profile = for_profile if for_profile != null else PlayerProfile.new()
	page = first_page


func _ready() -> void:
	name = "CareerMap"
	theme = UiKit.theme()
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.08, 0.1, 0.66)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiKit.fill(shade))
	var card := UiKit.panel(Color(10 / 255.0, 26 / 255.0, 31 / 255.0, 0.99), 20, Vector2(22, 16))
	card.name = "Card"
	var style := card.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color = Color(UiKit.MINT, 0.3)
	style.set_border_width_all(2)
	UiKit.fill(card)
	card.offset_left = UiKit.px(32)
	card.offset_right = -UiKit.px(32)
	card.offset_top = UiKit.px(14)
	card.offset_bottom = -UiKit.px(14)
	UiKit.keep_off_edges(card)
	add_child(card)
	var column := UiKit.vbox(8)
	card.add_child(column)

	var header := UiKit.hbox(12)
	column.add_child(header)
	var titles := UiKit.vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	titles.add_child(UiKit.kicker("Your career · %s · Day %d" % [Rank.title(profile.rank_held), profile.day]))
	var name_line := UiKit.heading(profile.full_title(), 22)
	name_line.name = "Who"
	name_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	titles.add_child(name_line)
	map_chip = UiKit.chip("Map", true, 40)
	map_chip.name = "MapChip"
	map_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	map_chip.pressed.connect(show_page.bind("map"))
	header.add_child(map_chip)
	letters_chip = UiKit.chip(_letters_chip_text(), false, 40)
	letters_chip.name = "LettersChip"
	letters_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	letters_chip.pressed.connect(show_page.bind("letters"))
	header.add_child(letters_chip)
	close_button = UiKit.primary_button("Back to work", 44, 16)
	close_button.name = "Close"
	close_button.custom_minimum_size.x = UiKit.px(150)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	header.add_child(close_button)

	scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	body = UiKit.vbox(10)
	body.name = "Body"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	var first := page
	page = ""
	show_page(first)
	UiKit.pop_in(card, 0.22)


func _letters_chip_text() -> String:
	var unread := Letters.unread_count(profile)
	return "Letters · %d new" % unread if unread > 0 else "Letters"


## "map" or "letters", as a tap on its chip does.
func show_page(which: String) -> void:
	if which == page:
		return
	page = which
	UiKit.set_chip(map_chip, which == "map")
	UiKit.set_chip(letters_chip, which == "letters")
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	if which == "letters":
		_build_letters()
	else:
		_build_map()
	scroll.scroll_vertical = 0


# --- The map ---------------------------------------------------------------

func _build_map() -> void:
	body.add_child(_race_card())
	var stops := Career.stops(profile)
	for stop: Dictionary in stops:
		body.add_child(_stop_row(stop))
		if int(stop["rank"]) == Rank.SENIOR_RESIDENT:
			body.add_child(_roads_row())
	var endless := {"title": "Never-ending days", "days": "Day 29 onwards", "line": Career.endless_line(profile),
		"state": "here" if profile.day >= DayHooks.LAST_STORY_DAY else "locked", "rank": -1}
	body.add_child(_stop_row(endless))


func _race_card() -> Control:
	var card := UiKit.panel(Color(UiKit.CORAL, 0.1), 16, Vector2(16, 12))
	card.name = "Race"
	var column := UiKit.vbox(6)
	card.add_child(column)
	column.add_child(UiKit.kicker("The race"))
	var title := UiKit.label("%s · %s" % [Rival.NAME, Rival.title(profile)], 17, UiKit.TEXT, UiKit.heavy_font())
	title.name = "RivalName"
	column.add_child(title)
	if not Rival.racing(profile) or profile.count("rival_from") < Rival.FIRST_DAY:
		column.add_child(_wrapped("Your batchmate from graduation. He took the CarePlus job, the CarePlus car and the CarePlus " +
			"hoarding at the highway signal. The race starts when you reach the ward.", 14, UiKit.TEXT_SOFT, "RaceLine"))
		return card
	if profile.count("rival_from") != Rival.stretch_start(profile.day):
		# Between two months (the drill before a new one): the new month
		# starts counting on the ward.
		column.add_child(_wrapped("A new month starts on the ward this morning. Varun has already posted a motivational " +
			"quote about it. Something about eagles, na.", 14, UiKit.TEXT_SOFT, "RaceLine"))
		var settled := Rival.record(profile)
		if not settled.is_empty():
			column.add_child(_wrapped(settled, 13, UiKit.AMBER, "Record"))
		return card
	var start := Rival.stretch_start(profile.day)
	var since := maxi(start, profile.count("rival_since"))
	var through := profile.day - 1
	var yours := Rival.yours(profile)
	var his := Rival.his(profile, through) if through >= since else 0
	var top := maxi(maxi(yours, his), 1)
	column.add_child(_wrapped("This month: Days %d to %d" % [start, Rival.stretch_end(profile.day)], 13, UiKit.TEXT_SOFT, "Month"))
	column.add_child(_race_bar("You", yours, top, UiKit.MINT, "YouBar"))
	column.add_child(_race_bar(Rival.SHORT, his, top, UiKit.CORAL, "HisBar"))
	var said := ""
	if through >= since:
		said = "Yesterday: " + str(Rival.day_entry(through)[1])
	else:
		said = "A new month. Varun has already posted a motivational quote about it."
	column.add_child(_wrapped(said, 13, UiKit.TEXT, "RivalDay"))
	var record := Rival.record(profile)
	if not record.is_empty():
		column.add_child(_wrapped(record, 13, UiKit.AMBER, "Record"))
	return card


func _race_bar(who: String, amount: int, top: int, colour: Color, node_name: String) -> Control:
	var row := UiKit.hbox(10)
	row.name = node_name
	var label := UiKit.label(who, 14, UiKit.TEXT, UiKit.heavy_font())
	label.custom_minimum_size.x = UiKit.px(70)
	row.add_child(label)
	var track := Control.new()
	track.custom_minimum_size = Vector2(0, UiKit.px(14))
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(track)
	var back := ColorRect.new()
	back.color = Color(1, 1, 1, 0.08)
	track.add_child(UiKit.fill(back))
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = colour
	fill.anchor_bottom = 1.0
	fill.anchor_right = clampf(float(amount) / float(top), 0.0, 1.0)
	track.add_child(fill)
	var value := UiKit.label("+%d XP" % amount, 14, colour, UiKit.heavy_font())
	value.name = "Value"
	value.custom_minimum_size.x = UiKit.px(90)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return row


func _stop_row(stop: Dictionary) -> Control:
	var state := str(stop["state"])
	var tint := Color(UiKit.MINT, 0.14) if state == "here" else Color(1, 1, 1, 0.04 if state == "locked" else 0.07)
	var card := UiKit.panel(tint, 16, Vector2(16, 12))
	card.name = "Stop" + str(stop["title"]).replace(" ", "").replace("-", "")
	if state == "here":
		var style := card.get_theme_stylebox("panel") as StyleBoxFlat
		style.border_color = Color(UiKit.MINT, 0.6)
		style.set_border_width_all(2)
	var row := UiKit.hbox(14)
	card.add_child(row)
	var icon_kind := {"done": "check", "here": "dot", "locked": "lock"}.get(state, "circle") as String
	var icon := UiIcon.make(icon_kind, 26, UiKit.MINT if state != "locked" else UiKit.TEXT_SOFT)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(icon)
	var column := UiKit.vbox(4)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	var heading := UiKit.hbox(10)
	column.add_child(heading)
	var title := UiKit.label(str(stop["title"]), 17, UiKit.TEXT if state != "locked" else UiKit.TEXT_SOFT, UiKit.heavy_font())
	title.name = "Title"
	heading.add_child(title)
	var days := UiKit.label(str(stop["days"]), 13, UiKit.TEXT_SOFT)
	days.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(days)
	if state == "here":
		var endless := int(stop["rank"]) < 0
		var you := UiKit.label("Still here. Obviously." if endless else "You are here", 12, UiKit.AMBER, UiKit.heavy_font())
		you.name = "StillHere" if endless else "Here"
		you.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		heading.add_child(you)
	column.add_child(_wrapped(str(stop["line"]), 14, UiKit.TEXT if state != "locked" else UiKit.TEXT_SOFT, "Line"))
	if state == "here" and int(stop["rank"]) >= 0:
		var goals := UiKit.vbox(4)
		goals.name = "Goals"
		column.add_child(goals)
		for goal: Dictionary in Career.goals(profile):
			var goal_row := UiKit.hbox(8)
			var mark := UiIcon.make("check" if bool(goal["done"]) else "circle", 16, UiKit.AMBER)
			mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			goal_row.add_child(mark)
			var text := _wrapped(str(goal["text"]), 13, UiKit.TEXT, "Goal")
			goal_row.add_child(text)
			goals.add_child(goal_row)
	return card


func _roads_row() -> Control:
	var card := UiKit.panel(Color(1, 1, 1, 0.04), 16, Vector2(16, 12))
	card.name = "Roads"
	var column := UiKit.vbox(8)
	card.add_child(column)
	column.add_child(UiKit.kicker("The road splits"))
	var chips := UiKit.flow(8)
	chips.name = "RoadChips"
	column.add_child(chips)
	for road: Dictionary in Career.ROADS:
		var open := bool(road["open"])
		var chip := UiKit.chip(str(road["name"]) + ("" if open else " · coming"), open, 36)
		chip.name = str(road["id"]).capitalize()
		chip.disabled = not open
		chip.focus_mode = Control.FOCUS_NONE
		chips.add_child(chip)
	column.add_child(_wrapped(Career.ROADS_LINE, 13, UiKit.TEXT_SOFT, "RoadsLine"))
	return card


# --- The letters -------------------------------------------------------------

func _build_letters() -> void:
	var arrived := Letters.arrived(profile).size()
	var unread := Letters.unread_count(profile)
	var count := "%d of %d letters on your wall" % [arrived, Letters.slots().size()]
	if unread > 0:
		count += " · %d new" % unread
	body.add_child(_wrapped(count, 15, UiKit.TEXT, "LetterCount"))
	body.add_child(_wrapped("Which letter comes depends on what you did for them. Some people don't write. " +
		"Some write to complain, which also counts, technically.", 13, UiKit.TEXT_SOFT, "LetterHint"))
	var grid := UiKit.grid(3, 10)
	grid.name = "Wall"
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(grid)
	for slot: Dictionary in Letters.slots():
		grid.add_child(_letter_card(slot))


func _letter_card(slot: Dictionary) -> Control:
	var state := Letters.state(profile, slot)
	var letter := Letters.letter_for(profile, slot) if state == "arrived" else {}
	var unread := state == "arrived" and not Letters.is_read(profile, slot)
	var button := Button.new()
	button.name = "Letter_" + str(slot.get("id", ""))
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, UiKit.px(92))
	var colour := Color(UiKit.AMBER, 0.16) if unread else Color(1, 1, 1, 0.07 if state == "arrived" else 0.03)
	var border := Color(UiKit.AMBER, 0.7) if unread else Color.TRANSPARENT
	for which in ["normal", "hover", "focus", "disabled"]:
		button.add_theme_stylebox_override(which, UiKit.box(colour, 14, border, 2 if unread else 0))
	button.add_theme_stylebox_override("pressed", UiKit.box(Color(UiKit.MINT, 0.25), 14))
	var inside := UiKit.vbox(3)
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fill(inside)
	inside.offset_left = UiKit.px(12)
	inside.offset_right = -UiKit.px(12)
	inside.offset_top = UiKit.px(10)
	inside.offset_bottom = -UiKit.px(8)
	button.add_child(inside)
	match state:
		"arrived":
			var kicker := UiKit.label("New letter" if unread else "Read", 11, UiKit.AMBER if unread else UiKit.TEXT_SOFT,
				UiKit.heavy_font())
			inside.add_child(kicker)
			inside.add_child(_wrapped(str(letter.get("title", "")), 14, UiKit.TEXT, "Title", true))
			inside.add_child(_wrapped("From " + str(letter.get("from", "")), 12, UiKit.TEXT_SOFT, "From", true))
			button.pressed.connect(open_letter.bind(slot))
		"none":
			inside.add_child(UiKit.label("Nobody wrote", 11, UiKit.TEXT_SOFT, UiKit.heavy_font()))
			inside.add_child(_wrapped("No letter came this time. Some careers get one here.", 12, UiKit.TEXT_SOFT, "Title", true))
			button.disabled = true
		_:
			var row := UiKit.hbox(6)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inside.add_child(row)
			row.add_child(UiIcon.make("lock", 14, UiKit.TEXT_SOFT))
			row.add_child(UiKit.label("Sealed", 11, UiKit.TEXT_SOFT, UiKit.heavy_font()))
			inside.add_child(_wrapped("Arrives after Day %d, if somebody has a reason to write." % int(slot.get("after", 0)), 12,
				UiKit.TEXT_SOFT, "Title", true))
			button.disabled = true
	return button


## Opens a letter that has come, and marks it read.
func open_letter(slot: Dictionary) -> ReaderPanel:
	var letter := Letters.letter_for(profile, slot)
	if letter.is_empty() or reader != null:
		return reader
	Letters.mark_read(profile, slot)
	var text := "[b]From %s[/b]\n\n%s" % [_escape(str(letter.get("from", ""))), _escape(Letters.body(profile, letter))]
	reader = ReaderPanel.new(str(letter.get("title", "A letter")), [["", func() -> String: return text]])
	reader.closed.connect(func() -> void:
		reader = null
		letters_chip.text = _letters_chip_text()
		var keep := scroll.scroll_vertical
		page = ""
		show_page("letters")
		scroll.set_deferred("scroll_vertical", keep))
	add_child(reader)
	Sfx.play(self, "tap", -8.0)
	return reader


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")


func _wrapped(text: String, size: float, colour: Color, node_name: String, ignore_mouse: bool = false) -> Label:
	var label := UiKit.label(text, size, colour)
	label.name = node_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if ignore_mouse:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func close() -> void:
	if _done:
		return
	_done = true
	closed.emit()
	queue_free()
