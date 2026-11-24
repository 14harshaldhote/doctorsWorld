class_name MiniGame
extends Control
## A party game (stage 27): carrom, antakshari, a dance-off or a speech,
## played over the party's 3D scene. Each one builds its own play area in
## a card (the right side of the screen unless it says otherwise), with a
## title and one line on how to play at the top and a way to sit it out.
## When it's over the result shows for a moment, then finished() says how
## it went: "won" or "lost", or for a speech "great", "ok" or "flop".
##
## Time passes only through tick() (the evening calls it), so tests play a
## game in a blink with auto_step(), which plays as well as skill (0 to 1).

signal finished(result: String)
## Something the people watching react to: "great", "good" or "bad".
signal moment(kind: String)

## How long the result stays before finished().
const END_TIME := 2.4

## Who the doctor plays against (a cast id), if anyone.
var against := ""
var title := ""
var how := ""
## The result once it's over ("" until then).
var result := ""
var card: PanelContainer
var content: VBoxContainer
## Holds content; it scrolls only when the play area can't fit.
var scroll: ScrollContainer
var sit_out: Button
var _end_left := -1.0
var _said := false
var _title_label: Label
var _how_label: Label
var _score_label: Label
var _end_label: Label


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.fill(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	card = UiKit.panel(Color(8 / 255.0, 22 / 255.0, 27 / 255.0, 0.94), 20, Vector2(18, 14))
	card.name = "Card"
	var style := card.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color = Color(UiKit.AMBER, 0.45)
	style.set_border_width_all(2)
	add_child(card)
	var stack := UiKit.vbox(8)
	card.add_child(stack)
	var top := UiKit.hbox(10)
	stack.add_child(top)
	var titles := UiKit.vbox(2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(titles)
	_title_label = UiKit.heading(title, 20)
	_title_label.name = "Title"
	titles.add_child(_title_label)
	_how_label = UiKit.label(how, 12, UiKit.TEXT_SOFT)
	_how_label.name = "How"
	_how_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(_how_label)
	sit_out = UiKit.ghost_button("Sit out", 36, 13)
	sit_out.name = "SitOut"
	sit_out.focus_mode = Control.FOCUS_NONE
	sit_out.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	sit_out.pressed.connect(give_up)
	UiKit.respond_to_press(sit_out)
	top.add_child(sit_out)
	_score_label = UiKit.label("", 14, UiKit.AMBER, UiKit.heavy_font())
	_score_label.name = "Score"
	_score_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_score_label)
	# The play area scrolls if it can't fit (big text on a small phone), so
	# the card never runs off the screen.
	scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)
	content = UiKit.vbox(8)
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	_end_label = UiKit.label("", 17, UiKit.MINT, UiKit.heading_font())
	_end_label.name = "End"
	_end_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end_label.visible = false
	stack.add_child(_end_label)
	build()
	resized.connect(_layout)
	_layout()
	if not GameSettings.current.reduce_motion:
		UiKit.pop_in(card, 0.25)


## The game's own play area, in content.
func build() -> void:
	pass


## The card down the right of the screen; a game can place it elsewhere.
func _layout() -> void:
	var view := get_viewport_rect().size if is_inside_tree() else size
	var wide := minf(UiKit.px(360) * GameSettings.current.text_scale(), view.x * 0.52)
	card.anchor_left = 1.0
	card.anchor_right = 1.0
	card.anchor_top = 0.0
	card.anchor_bottom = 1.0
	card.offset_left = -wide - UiKit.px(14)
	card.offset_right = -UiKit.px(14)
	card.offset_top = UiKit.px(14)
	card.offset_bottom = -UiKit.px(14)
	UiKit.keep_off_edges(card)


func tick(delta: float) -> void:
	if _end_left < 0.0:
		play(delta)
		return
	_end_left -= delta
	if _end_left <= 0.0 and not _said:
		_said = true
		finished.emit(result)


## The game's own time.
func play(_delta: float) -> void:
	pass


## Plays a move by itself (tests and the screenshot tool), as well as skill.
func auto_step(_skill: float) -> void:
	pass


func is_over() -> bool:
	return not result.is_empty()


func set_score(text: String) -> void:
	if _score_label != null:
		_score_label.text = text
		_score_label.visible = not text.is_empty()


## The game is over: what happened, for a moment, then finished().
func end(with_result: String, text: String) -> void:
	if is_over():
		return
	result = with_result
	_end_left = END_TIME
	_end_label.text = text
	_end_label.visible = true
	_end_label.add_theme_color_override("font_color",
		UiKit.MINT if with_result in ["won", "great", "ok"] else UiKit.CORAL)
	sit_out.visible = false
	moment.emit("great" if with_result in ["won", "great"] else ("good" if with_result == "ok" else "bad"))


## Sitting it out counts as losing.
func give_up() -> void:
	end(lost_result(), "You sat this one out. Nobody will mention it. Everybody will remember it.")


func lost_result() -> String:
	return "lost"


## A tap anywhere on the end text hurries it along.
func hurry() -> void:
	if _end_left > 0.3:
		_end_left = 0.3


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed and is_over():
		hurry()


## Someone's short name for the scores ("Varun", "Sister Grace").
static func name_of(id: String) -> String:
	return Life.short_name(id) if not id.is_empty() else "Them"
