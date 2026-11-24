class_name AntakshariGame
extends MiniGame
## Antakshari, doctors against the nurses (or whoever's hosting): each side
## in turn sings a song that starts with the last letter of the one before.
## All the songs are made up (story/life.json), so nobody's lawyer calls.
## On the doctor's turn there are three to pick from before the timer runs
## out: the right one, one already sung, and one with the wrong letter. The
## other side forgets the words now and then. Ties go to the other side;
## they made the rules.

## How long the result of a turn shows, in seconds.
const SHOW := 2.0

var titles: Array = []
var rounds := 8
var seconds := 8.0
var miss := 0.25
## Songs sung so far.
var sung: Array = []
var letter := ""
var round_index := 0
var scores := [0, 0]
## "choose" (the doctor's turn), "them", "show" or "over".
var state := "choose"
var time_left := 0.0
var options: Array = []
var buttons: Array[Button] = []
var _rng: SeededRandom
var _auto := SeededRandom.new(99)
var _wait := 0.0
var _letter_label: Label
var _timer_back: ColorRect
var _timer_fill: ColorRect
var _status: Label
var _choices: VBoxContainer
var _prompt: Label


func _init(rival: String = "grace", seed_value: int = 1, data: Dictionary = {}) -> void:
	against = rival
	_rng = SeededRandom.new(seed_value % 1000003 + 11)
	titles = (data.get("titles", []) as Array).duplicate()
	rounds = maxi(2, int(data.get("rounds", 8)))
	seconds = maxf(2.0, float(data.get("seconds", 8.0)))
	miss = clampf(float(data.get("miss", 0.25)), 0.0, 1.0)
	title = "Antakshari"
	how = "Match the letter. No repeats. %d seconds." % int(seconds)


func their_team() -> String:
	return "Nurses" if against == "grace" else "Team %s" % name_of(against)


func build() -> void:
	var row := UiKit.hbox(14)
	content.add_child(row)
	var tile := UiKit.panel(UiKit.AMBER, 16, Vector2(14, 4))
	tile.custom_minimum_size = Vector2(UiKit.px(60), UiKit.px(60))
	row.add_child(tile)
	_letter_label = UiKit.label("", 36, UiKit.AMBER_TEXT, UiKit.heading_font())
	_letter_label.name = "Letter"
	_letter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_letter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tile.add_child(_letter_label)
	var words := UiKit.vbox(4)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(words)
	_prompt = UiKit.label("", 15, UiKit.TEXT, UiKit.heading_medium_font())
	_prompt.name = "Prompt"
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(_prompt)
	_timer_back = ColorRect.new()
	_timer_back.color = Color(1, 1, 1, 0.12)
	_timer_back.custom_minimum_size = Vector2(0, UiKit.px(6))
	words.add_child(_timer_back)
	_timer_fill = ColorRect.new()
	_timer_fill.color = UiKit.MINT
	_timer_back.add_child(_timer_fill)
	_timer_back.resized.connect(_timer)
	# What just happened shows where the songs were, so the card never has
	# to scroll while the clock runs.
	_status = UiKit.label("", 15, UiKit.TEXT, UiKit.heavy_font())
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.visible = false
	content.add_child(_status)
	_choices = UiKit.vbox(6)
	_choices.name = "Choices"
	content.add_child(_choices)
	letter = _any_letter()
	_start_turn()


# --- The song book -------------------------------------------------------------------

static func first_letter(song: String) -> String:
	return song.substr(0, 1).to_upper()


func _open(start: String) -> Array:
	return titles.filter(func(song: String) -> bool: return first_letter(song) == start and song not in sung)


func _any_letter() -> String:
	var open := titles.filter(func(song: String) -> bool: return song not in sung)
	if open.is_empty():
		return "A"
	return first_letter(str(open[_rng.next_int(open.size())]))


## The letter after a song: its last letter, or the last one in it that
## still has songs left, or any letter that has.
func next_letter(song: String) -> String:
	var plain := song.to_upper()
	for index in range(plain.length() - 1, -1, -1):
		var character := plain.substr(index, 1)
		if character >= "A" and character <= "Z" and not _open(character).is_empty():
			return character
	return _any_letter()


# --- Turns ------------------------------------------------------------------------------

func my_turn() -> bool:
	return round_index % 2 == 0


func _start_turn() -> void:
	if _open(letter).is_empty():
		letter = _any_letter()
	_letter_label.text = letter
	for button in buttons:
		_choices.remove_child(button)
		button.queue_free()
	buttons.clear()
	options.clear()
	_status.text = ""
	_status.visible = false
	_choices.visible = true
	if my_turn():
		state = "choose"
		time_left = seconds
		_prompt.text = "Your turn. Something with %s." % letter
		options = _options()
		for index in options.size():
			var button := UiKit.ghost_button(str(options[index]), 42, 15)
			button.name = "Song%d" % (index + 1)
			button.focus_mode = Control.FOCUS_NONE
			button.pressed.connect(pick.bind(index))
			UiKit.respond_to_press(button)
			_choices.add_child(button)
			buttons.append(button)
	else:
		state = "them"
		_wait = 1.1 + _rng.next_float() * 1.3
		time_left = 0.0
		_prompt.text = "%s are thinking. Loudly." % their_team()
	_score()
	_timer()


## Three songs: the right one, one already sung (or another wrong one), and
## one with the wrong letter, in any order.
func _options() -> Array:
	var right: Array = _open(letter)
	var picked: Array = [right[_rng.next_int(right.size())]]
	var again := sung.filter(func(song: String) -> bool: return first_letter(song) == letter)
	var other := titles.filter(func(song: String) -> bool: return first_letter(song) != letter and song not in sung)
	if not again.is_empty():
		picked.append(again[_rng.next_int(again.size())])
	for _try in 6:
		if picked.size() >= 3 or other.is_empty():
			break
		var wrong: String = other[_rng.next_int(other.size())]
		if wrong not in picked:
			picked.append(wrong)
	return _rng.shuffled(picked)


## The doctor picks a song.
func pick(index: int) -> void:
	if state != "choose" or index < 0 or index >= options.size():
		return
	var song := str(options[index])
	if first_letter(song) != letter:
		_missed("%s starts with %s. Grace is writing that down." % [song, first_letter(song)])
	elif song in sung:
		_missed("%s was sung three songs ago. The nurses are delighted." % song)
	else:
		_sang(0, song)


func _sang(side: int, song: String) -> void:
	scores[side] += 1
	sung.append(song)
	letter = next_letter(song)
	_status.text = "%s sing %s." % ["You" if side == 0 else their_team(), song]
	moment.emit("good" if side == 0 else "bad")
	_show()


func _missed(text: String) -> void:
	_status.text = text
	moment.emit("bad")
	_show()


func _show() -> void:
	state = "show"
	_wait = SHOW
	for button in buttons:
		button.disabled = true
	_choices.visible = false
	_status.visible = true
	_score()


func play(delta: float) -> void:
	match state:
		"choose":
			time_left -= delta
			_timer()
			if time_left <= 0.0:
				_missed("Time. The whole terrace hums the wrong song at you.")
		"them":
			_wait -= delta
			if _wait <= 0.0:
				var open := _open(letter)
				if open.is_empty() or _rng.chance(miss):
					_status.text = "%s go blank. The doctors cheer like they cured something." % their_team()
					moment.emit("good")
					_show()
				else:
					_sang(1, str(open[_rng.next_int(open.size())]))
		"show":
			_wait -= delta
			if _wait <= 0.0:
				round_index += 1
				if round_index >= rounds:
					_finish()
				else:
					_start_turn()


func _finish() -> void:
	state = "over"
	_score()
	if scores[0] > scores[1]:
		end("won", "Doctors win, %d to %d. Grace says it was rigged, and smiles." % [scores[0], scores[1]])
	elif scores[0] == scores[1]:
		end("lost", "%d all. Ties go to the %s. They made the rules." % [scores[0], their_team()])
	else:
		end("lost", "%s win, %d to %d. They will sing about it at handover." % [their_team(), scores[1], scores[0]])


func _score() -> void:
	set_score("Doctors %d   %s %d   Round %d of %d" % [scores[0], their_team(), scores[1], mini(round_index + 1, rounds),
		rounds])


func _timer() -> void:
	if _timer_fill == null:
		return
	var share := clampf(time_left / seconds, 0.0, 1.0) if state == "choose" else 0.0
	_timer_fill.size = Vector2(_timer_back.size.x * share, _timer_back.size.y)
	_timer_fill.color = UiKit.MINT if share > 0.35 else UiKit.CORAL


func auto_step(skill: float) -> void:
	if state != "choose" or time_left > seconds - 0.4:
		return
	var right := -1
	var wrong := -1
	for index in options.size():
		var song := str(options[index])
		if first_letter(song) == letter and song not in sung:
			right = index
		elif wrong < 0:
			wrong = index
	pick(right if _auto.chance(clampf(skill, 0.0, 1.0)) or wrong < 0 else wrong)
