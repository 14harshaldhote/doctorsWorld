class_name DanceGame
extends MiniGame
## A dance-off on the wedding's lit-up floor (stage 27): the dhol plays
## (the party track, made at BPM), dots slide along the strip into the ring,
## and the doctor taps anywhere as each one lands. Spot on is 2, close is 1,
## a tap on nothing costs 1 (no drumming the screen). The rival's score
## climbs alongside. Space or Enter taps on a Mac.

const BPM := 112.0
## The music's first beat, seconds into the track.
const LEAD := 0.0
## Seconds a dot takes to cross the strip.
const APPROACH := 1.6
const PERFECT := 0.08
const GOOD := 0.16
## A tap this far from any dot is a tap on nothing.
const STRAY := 0.26
## The beat patterns a bar can have (beats from the start of the bar).
const BARS := [[0.0, 1.0, 2.0, 3.0], [0.0, 1.0, 2.0, 2.5, 3.0], [0.0, 1.5, 2.0, 3.0], [0.0, 0.5, 1.0, 2.0, 3.0],
	[0.0, 2.0, 2.5, 3.0, 3.5], [0.0, 1.0, 1.5, 2.0, 3.0]]
const FIRST_BAR := 1
const BAR_COUNT := 8
const TRACK := "party"
## How far the music's clock may be from the frames' before it's not trusted.
const DRIFT := 0.3

## Every dot: {t (seconds), judged ("" / "perfect" / "good" / "miss")}.
var notes: Array[Dictionary] = []
var time := -0.6
var points := 0
var rival_points := 0
var combo := 0
var best_combo := 0
var last_call := ""
var lane: Control
var _rng: SeededRandom
var _rival_share := 0.65
var _call_left := 0.0
var _music: AudioStreamPlayer
var _started := false
## Seconds by the frames since the dance began (see _music_time).
var _frames := -0.6
var _over := false


func _init(rival: String = "varun", seed_value: int = 1) -> void:
	against = rival
	_rng = SeededRandom.new(seed_value % 1000003 + 13)
	_rival_share = 0.56 + _rng.next_float() * 0.22
	title = "Dance-off"
	how = "Tap anywhere as each dot lands in the ring. Spot on 2, close 1. Tapping on nothing costs you."
	var beat := 60.0 / BPM
	for bar in BAR_COUNT:
		var pattern: Array = BARS[_rng.next_int(BARS.size())] if bar > 0 else BARS[0]
		for offset: float in pattern:
			notes.append({"t": LEAD + ((FIRST_BAR + bar) * 4.0 + offset) * beat, "judged": ""})


func build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	lane = Control.new()
	lane.name = "Lane"
	lane.custom_minimum_size = Vector2(0, UiKit.px(64))
	lane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lane.draw.connect(_draw_lane)
	content.add_child(lane)
	_score()


## A strip along the bottom, so the dancers show above it. It is as tall
## as what's in it (growing up from the bottom edge), whatever the text size.
func _layout() -> void:
	var view := get_viewport_rect().size if is_inside_tree() else size
	var wide := minf(view.x - UiKit.px(28), UiKit.px(760))
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 1.0
	card.anchor_bottom = 1.0
	card.offset_left = -wide / 2.0
	card.offset_right = wide / 2.0
	card.offset_bottom = -UiKit.px(12)
	card.offset_top = card.offset_bottom
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	UiKit.keep_off_edges(card)


func most_points() -> int:
	return notes.size() * 2


## The beat the music is on (-1 before it starts or after it ends).
func beat_index() -> int:
	if time < LEAD or _over:
		return -1
	return int(floor((time - LEAD) * BPM / 60.0))


func play(delta: float) -> void:
	if not _started:
		_started = true
		_start_music()
	time = _music_time(delta)
	for note: Dictionary in notes:
		if str(note["judged"]).is_empty() and time > float(note["t"]) + GOOD:
			note["judged"] = "miss"
			combo = 0
			_call("Miss")
	_call_left -= delta
	_rival_climb()
	_score()
	if lane != null:
		lane.queue_redraw()
	if not _over and time > float(notes[notes.size() - 1]["t"]) + 0.8:
		_finish()


## The dance's clock: what the ear hears of the music, so the dots land on
## the dhol even on a slow frame. A device that isn't really playing it (no
## sound out, a test playing in a blink) drifts away from the frames, and
## then the frames keep time instead.
func _music_time(delta: float) -> float:
	_frames += delta
	if _music == null or not _music.playing:
		return _frames
	var heard := LEAD + _music.get_playback_position() + AudioServer.get_time_since_last_mix() \
		- AudioServer.get_output_latency()
	return heard if absf(heard - _frames) <= DRIFT else _frames


func _start_music() -> void:
	if not Voice.enabled or not is_inside_tree() or not ResourceLoader.exists("res://assets/music/%s.ogg" % TRACK):
		return
	Music.hold_for_song(true)
	_music = AudioStreamPlayer.new()
	_music.name = "DanceMusic"
	_music.bus = &"Music"
	_music.stream = Music.stream(TRACK)
	add_child(_music)
	GameSettings.ensure_buses()
	_music.play()
	time = 0.0
	_frames = 0.0


func _stop_music() -> void:
	if _music != null:
		_music.stop()
		_music.queue_free()
		_music = null
		Music.hold_for_song(false)


func _exit_tree() -> void:
	_stop_music()


## The doctor taps.
func tap() -> void:
	if _over or is_over():
		return
	var nearest := -1
	var gap := INF
	for index in notes.size():
		var note := notes[index]
		if not str(note["judged"]).is_empty():
			continue
		var off := absf(float(note["t"]) - time)
		if off < gap:
			gap = off
			nearest = index
	if nearest < 0 or gap > STRAY:
		points = maxi(0, points - 1)
		combo = 0
		_call("Off beat")
		return
	if gap > GOOD:
		notes[nearest]["judged"] = "miss"
		combo = 0
		_call("Miss")
		return
	var perfect := gap <= PERFECT
	notes[nearest]["judged"] = "perfect" if perfect else "good"
	points += 2 if perfect else 1
	combo += 1
	best_combo = maxi(best_combo, combo)
	_call("Spot on" if perfect else "Close")
	if combo > 0 and combo % 8 == 0:
		moment.emit("great")


func _call(text: String) -> void:
	last_call = text
	_call_left = 0.6


## The rival's score keeps pace with how far through it is, at their own rate.
func _rival_climb() -> void:
	var passed := 0
	for note: Dictionary in notes:
		if time > float(note["t"]):
			passed += 1
	var wobble := sin(time * 1.7) * 0.06
	rival_points = maxi(rival_points, int(round(passed * 2 * clampf(_rival_share + wobble, 0.0, 1.0))))


func _finish() -> void:
	_over = true
	_stop_music()
	rival_points = int(round(most_points() * _rival_share))
	_score()
	if points > rival_points:
		end("won", "You win, %d to %d. %s says the floor was slippery on his side." % [points, rival_points,
			name_of(against)])
	else:
		end("lost", "%s wins, %d to %d. The aunties have it on four phones." % [name_of(against), rival_points, points])


func _score() -> void:
	set_score("You %d   %s %d   Best run %d" % [points, name_of(against), rival_points, best_combo])


func _gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		if is_over():
			hurry()
		else:
			tap()
		accept_event()
	var touch := event as InputEventScreenTouch
	if touch != null and touch.pressed and not is_over():
		tap()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	# Space or Enter on a Mac (the accept action), never held down.
	if event.is_action_pressed(&"ui_accept", false) and not is_over():
		tap()
		get_viewport().set_input_as_handled()


func auto_step(skill: float) -> void:
	if is_over():
		return
	for note: Dictionary in notes:
		if not str(note["judged"]).is_empty():
			continue
		var off := time - float(note["t"])
		# A good player taps on the beat; a worse one a little late.
		if off >= (1.0 - clampf(skill, 0.0, 1.0)) * 0.14 - 0.01:
			tap()
		return


# --- Drawing -------------------------------------------------------------------------------

func _draw_lane() -> void:
	var area := Rect2(Vector2.ZERO, lane.size)
	var middle := area.size.y / 2.0
	var ring_x := area.size.x * 0.12
	lane.draw_rect(Rect2(0, middle - area.size.y * 0.32, area.size.x, area.size.y * 0.64), Color(1, 1, 1, 0.06))
	var radius := area.size.y * 0.3
	var glow := 1.0 - clampf(_call_left / 0.6, 0.0, 1.0)
	lane.draw_circle(Vector2(ring_x, middle), radius * 1.15, Color(UiKit.AMBER, 0.25 + 0.3 * (1.0 - glow)), false,
		maxf(2.0, radius * 0.18))
	for note: Dictionary in notes:
		var ahead := float(note["t"]) - time
		if ahead > APPROACH or ahead < -0.3:
			continue
		var x := ring_x + ahead / APPROACH * (area.size.x - ring_x - radius)
		var judged := str(note["judged"])
		var colour := UiKit.MINT
		if judged == "miss":
			colour = Color(UiKit.CORAL, 0.6)
		elif judged == "perfect" or judged == "good":
			continue
		lane.draw_circle(Vector2(x, middle), radius * 0.7, colour)
	if _call_left > 0.0 and not last_call.is_empty():
		var font := UiKit.heavy_font()
		var size := int(maxf(12.0, area.size.y * 0.3))
		var colour := UiKit.AMBER if last_call == "Spot on" else (UiKit.MINT if last_call == "Close" else UiKit.CORAL)
		lane.draw_string(font, Vector2(ring_x + radius * 1.6, middle - radius * 0.2), last_call, HORIZONTAL_ALIGNMENT_LEFT,
			-1, size, Color(colour, clampf(_call_left / 0.3, 0.0, 1.0)))
	if combo >= 4:
		lane.draw_string(UiKit.heavy_font(), Vector2(area.size.x - radius * 6.0, middle + radius * 0.4), "x%d" % combo,
			HORIZONTAL_ALIGNMENT_RIGHT, radius * 5.0, int(maxf(12.0, area.size.y * 0.28)), UiKit.AMBER)
