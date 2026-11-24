class_name Evening
extends Node3D
## The evening after a day on Ward 4 (stage 27, Life): the doctor off duty.
## It opens in Mani's canteen, where the late shift has its chai. The panel
## lists what there's time for, each with what it costs on the clock, and
## "Go to bed" ends the evening at once.
##
##   canteen  chai with one of tonight's two colleagues: gossip, a little
##            trust, and a tip for tomorrow (shown again in the morning)
##   radio    Riverside FM, one song, with the words on screen
##   hostel   the walk back to the hostel room, where there is:
##   call     a video call home: Mum, Dad and Anu, all talking at once
##   eat      something that isn't a biscuit (going to bed hungry costs sleep)
##   study    reading up on tomorrow (a little XP, an hour of sleep)
##   scroll   the phone in bed (nothing at all, forty-five minutes of it)
##   party    on a party night: the party, its game and maybe the pager; the
##            party is the rest of the evening
##
## When the doctor goes to bed decides how they slept (Life.go_to_bed),
## which the next morning reads. The clock only moves when something is
## done. Nothing is saved until bed, so closing the game mid-evening just
## means the evening starts again.
##
## Time passes only through update(), so the tests drive it directly.

signal finished

## The party is winding down after this.
const PARTY_UNTIL := 22 * 60
const CANTEEN_ROWS := ["party", "canteen", "radio", "hostel"]
const HOSTEL_ROWS := ["party", "call", "eat", "study", "scroll"]
## How long a card that moves the evening on stays, if nobody taps it.
const CARD_TIME := 5.0
## The radio's song.
const RADIO_SONG := "roast"

var profile: PlayerProfile
## The day this evening comes after.
var day := 0
## The evening's clock, in minutes from that morning's midnight (past
## 24 * 60 after midnight).
var minutes := 0
## Where the doctor is: "canteen", "hostel_room", or the party's place.
var where := ""
## Tonight's party (Life.party_on), "" on an ordinary evening.
var party := ""
## What the doctor has done tonight: {activity: true}.
var done := {}
var ate := false
## The colleague the doctor had chai with tonight.
var chai_with := ""
## "menu", "talk", "game", "song", "card" or "done".
var phase := ""
## The conversation playing: "chai", "call" or "party".
var talking := ""
## When the doctor went to bed (-1 until then).
var bedtime := -1
## The two colleagues on late tonight.
var staff: Array = []

var camera: Camera3D
var ui: ConversationUi
var overlay: StoryOverlay
var story: StoryPlayer
var current_set: EveningSet
var panel: EveningPanel
var game: MiniGame
var call_frame: CallFrame
var pager: PanelContainer
var songs: SongPlayer
var banner: LyricsBanner

var _layer: CanvasLayer
var _shot := {}
var _shot_t := 0.0
var _after_card := Callable()
var _left_at := 0
var _beat := -1


func _init(for_profile: PlayerProfile = null, finished_day: int = 4, left_at: int = 0) -> void:
	profile = for_profile if for_profile != null else PlayerProfile.new()
	day = finished_day
	_left_at = left_at


func _ready() -> void:
	name = "Evening"
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 44
	add_child(camera)
	camera.make_current()
	_layer = CanvasLayer.new()
	_layer.name = "EveningLayer"
	add_child(_layer)
	panel = EveningPanel.new()
	panel.name = "Panel"
	panel.chosen.connect(choose)
	_layer.add_child(panel)
	call_frame = CallFrame.new()
	call_frame.name = "CallFrame"
	call_frame.visible = false
	_layer.add_child(call_frame)
	ui = ConversationUi.new()
	ui.name = "Conversation"
	ui.mode = ConversationUi.Mode.TALK
	_layer.add_child(ui)
	overlay = StoryOverlay.new(profile)
	overlay.name = "Overlay"
	_layer.add_child(overlay)
	story = StoryPlayer.new(StoryRunner.new(profile), ui, self)
	story.finished.connect(_on_story_finished)
	ui.close()
	songs = SongPlayer.new()
	songs.name = "Radio"
	songs.manual = true
	songs.finished.connect(_end_radio)
	add_child(songs)
	party = Life.party_on(profile, day)
	minutes = Life.start_minutes(_left_at)
	staff = Life.staff_tonight(profile, day)
	_go("canteen")
	Music.cue("night")
	overlay.fade("clear", 0.7)
	show_menu()


func _process(delta: float) -> void:
	update(delta)


## Moves the evening on by delta seconds (the tests call this directly).
func update(delta: float) -> void:
	if phase == "done":
		return
	story.update(delta)
	overlay.tick(delta)
	if current_set != null:
		current_set.tick(delta)
	if game != null:
		game.tick(delta)
		_dance_moves()
	if phase == "song":
		songs.tick(delta)
	if call_frame.visible:
		call_frame.tick(delta)
	if phase == "card" and overlay.card_left() <= 0.0:
		overlay.fade("clear", 0.45)
		var next := _after_card
		_after_card = Callable()
		phase = ""
		if next.is_valid():
			next.call()
	# Bed may have ended the evening (and Main may have let it go).
	if phase == "done" or not is_inside_tree():
		return
	_update_camera(delta)


func is_done() -> bool:
	return phase == "done"


# --- The menu ---------------------------------------------------------------------

func show_menu() -> void:
	phase = "menu"
	talking = ""
	story.focus = ""
	_start_shot("wide", 0.5)
	panel.visible = true
	panel.show_state(_state())


## What the panel shows: the clock, how long the doctor would sleep if they
## went now, home, and the things there's time for.
func _state() -> Dictionary:
	var walk := int(_activity("hostel").get("minutes", 12)) if where == "canteen" else 0
	var hours := Life.sleep_hours(minutes + walk, ate)
	var away := Life.days_without_home(profile, day + 1)
	var home := "Called home tonight"
	if not done.has("call"):
		if away >= 2:
			home = "Home: no call for %d days" % away
		elif profile.count(Life.CALLS) == 0:
			home = "Home: waiting for your first call"
		else:
			home = "Home: called recently"
	return {
		"kicker": "Day %d · evening" % day,
		"place": "Mani's canteen" if where == "canteen" else "Your hostel room",
		"clock": Life.clock(minutes),
		"sleep": "Bed now: %s of sleep%s" % [Life.hours_text(hours), "" if ate else ", hungry"],
		"sleep_warn": hours < float(Life.rule("good_sleep", 6.5)),
		"home": home,
		"home_warn": not done.has("call") and away >= 3,
		"rows": rows(),
		"bed": "Go to bed · lights out %s" % Life.clock(minutes + walk),
	}


## The things there's time for here: [{id, title, sub, minutes, highlight}].
func rows() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for id: String in (CANTEEN_ROWS if where == "canteen" else HOSTEL_ROWS):
		if not available(id):
			continue
		var entry := _activity(id)
		var row := {"id": id, "title": str(entry.get("title", id.capitalize())), "sub": str(entry.get("sub", "")),
			"minutes": int(entry.get("minutes", 0)), "highlight": false}
		if id == "party":
			var tonight := Life.party(party)
			row["title"] = str(tonight.get("title", "A party"))
			row["sub"] = str(tonight.get("sub", ""))
			row["highlight"] = true
		elif id == "hostel" and not party.is_empty() and not done.has("party"):
			row["sub"] = "Skip the party. They'll notice."
		found.append(row)
	return found


## True when something can be done now.
func available(id: String) -> bool:
	if done.has(id):
		return false
	match id:
		"party":
			return not party.is_empty() and minutes <= PARTY_UNTIL
		"canteen":
			return not staff.is_empty()
		"radio":
			return not Songs.song(RADIO_SONG).is_empty()
		"hostel":
			return where == "canteen"
		"bed":
			return true
	return where == "hostel_room" and _activity(id).has("minutes")


func _activity(id: String) -> Dictionary:
	return (Life.rule("activities", {}) as Dictionary).get(id, {})


## Does something from the menu (the panel's rows and the tests).
func choose(id: String) -> void:
	if phase != "menu" or (id != "bed" and not available(id)):
		return
	panel.visible = false
	match id:
		"party":
			_start_party()
		"canteen":
			_start_chai()
		"radio":
			_start_radio()
		"hostel":
			_walk_home()
		"call":
			_start_call()
		"eat":
			_eat()
		"study":
			_study()
		"scroll":
			_scroll()
		"bed":
			go_to_bed()


# --- Places ---------------------------------------------------------------------------

func _go(place: String, guests: Array = [], late: Array = []) -> void:
	if current_set != null:
		remove_child(current_set)
		current_set.queue_free()
	where = place
	current_set = EveningSet.new(profile, place)
	add_child(current_set)
	match place:
		"canteen":
			current_set.add_canteen_people(staff)
		"hostel_room":
			current_set.add_hostel_people()
		_:
			current_set.add_people(guests)
			for id: String in late:
				current_set.add_late(id)
	StaticBatch.optimise(current_set)
	story.actors = current_set.actors


func _walk_home() -> void:
	var entry := _activity("hostel")
	_card(str(entry.get("title", "Back to the hostel")), _walk_line(), func() -> void:
		minutes += int(entry.get("minutes", 12))
		done["hostel"] = true
		_go("hostel_room")
		show_menu())


func _walk_line() -> String:
	var lines: Array = Life.rule("walks", [])
	if lines.is_empty():
		return ""
	return str(lines[absi(("walk|%d|%d" % [ShiftDay.hospital_seed(profile), day]).hash()) % lines.size()])


# --- Chai -----------------------------------------------------------------------------

## Mani says hello, the doctor sits with one of the two colleagues on late,
## and they talk; their tip for tomorrow comes last.
func _start_chai() -> void:
	var steps: Array = [{"do": "shot", "name": "talk"}]
	var hello := Life.mani_line(profile, day)
	if not hello.is_empty():
		steps.append(hello)
	var options := []
	for who: String in staff:
		var then: Array = [{"do": "join", "who": who}]
		then.append_array(StoryBook.conversation("evenings", Life.chai_talk(profile, who)))
		var tip := Life.tip_for(who, day + 1)
		if tip.has("line"):
			then.append(tip["line"])
		options.append({"tone": Life.short_name(who), "text": "Sit with %s." % Life.short_name(who), "then": then})
	if options.size() == 1:
		steps.append_array(options[0]["then"])
	elif not options.is_empty():
		steps.append({"choose": options})
	_play("chai", steps)


# --- The radio ------------------------------------------------------------------------

func _start_radio() -> void:
	phase = "song"
	_start_shot("radio" if current_set.shots.has("radio") else "wide")
	var mani: AvatarRig = current_set.actors.get("mani")
	if mani != null:
		mani.set_gesture("point")
	if not songs.play(RADIO_SONG, Songs.request_for(profile)):
		_end_radio()
		return
	banner = LyricsBanner.new(songs)
	banner.stop_pressed.connect(songs.stop)
	_layer.add_child(banner)
	_layer.move_child(banner, overlay.get_index())


func _end_radio() -> void:
	if banner != null:
		if banner.get_parent() != null:
			banner.get_parent().remove_child(banner)
		banner.queue_free()
		banner = null
	if phase != "song":
		return
	var mani: AvatarRig = current_set.actors.get("mani") if current_set != null else null
	if mani != null:
		mani.set_gesture("")
	done["radio"] = true
	minutes += int(_activity("radio").get("minutes", 5))
	show_menu()


# --- The hostel room --------------------------------------------------------------------

## Home on the laptop: whichever call it is tonight.
func _start_call() -> void:
	var entry := Life.call_for(profile, day)
	var steps := StoryBook.conversation("evenings", str(entry.get("id", "")))
	if steps.is_empty():
		_after_call()
		return
	var names := PackedStringArray()
	for who: String in entry.get("with", []):
		names.append(str(StoryBook.cast().get(who, {}).get("name", who.capitalize())))
	call_frame.open(names)
	call_frame.visible = true
	var opening: Array = [{"do": "shot", "name": "call"}]
	opening.append_array(steps)
	_play("call", opening)


func _after_call() -> void:
	call_frame.visible = false
	Life.called_home(profile, day)
	done["call"] = true
	minutes += int(_activity("call").get("minutes", 30))
	show_menu()


func _eat() -> void:
	var meal := Life.eat_for(profile, day)
	_card(str(meal.get("title", "Dinner")), str(meal.get("text", "")), func() -> void:
		ate = true
		done["eat"] = true
		minutes += int(_activity("eat").get("minutes", 20))
		show_menu())


## An hour with tomorrow's kind of day in mind, for a little XP.
func _study() -> void:
	var entry := _activity("study")
	var lines: Dictionary = Life.rule("studies", {})
	var text := str(lines.get(Life.kind_of(day + 1), lines.get("ward", "")))
	_card(str(entry.get("title", "Read up on tomorrow")), text, func() -> void:
		profile.total_xp += int(entry.get("xp", 0))
		done["study"] = true
		minutes += int(entry.get("minutes", 60))
		show_menu())


func _scroll() -> void:
	var entry := _activity("scroll")
	var lines: Array = Life.rule("scrolls", [])
	var text := str(lines[absi(("scroll|%d|%d" % [ShiftDay.hospital_seed(profile), day]).hash()) % lines.size()]) \
		if not lines.is_empty() else ""
	_card(str(entry.get("title", "Scroll in bed")), text, func() -> void:
		done["scroll"] = true
		minutes += int(entry.get("minutes", 45))
		show_menu())


# --- The party --------------------------------------------------------------------------

## Off to the party: its place, its people (a late arrival waits by the
## door), its music, and its conversation, which has the game and the pager
## in it. What happened at this party before is forgotten first (the
## Chief's parties come round again).
func _start_party() -> void:
	var entry := Life.party(party)
	var talk := str(entry.get("talk", party))
	var steps := StoryBook.conversation("evenings", talk)
	var forget: Array = []
	for result: String in ["won", "great", "ok", "flop"]:
		forget.append(Life.result_flag(party, result))
	var left := str(entry.get("left", ""))
	if not left.is_empty():
		forget.append_array([left, left.trim_suffix("_left") + "_stayed"])
	for flag: String in forget:
		profile.set_flag(flag, false)
	var late := _arrivals(steps)
	var guests := (entry.get("guests", []) as Array).filter(func(id: String) -> bool: return id not in late)
	_go(str(entry.get("where", "hostel")), guests, late)
	Music.cue("party")
	_play("party", steps)


## Who walks in during a conversation ({"do": "arrive"}).
static func _arrivals(steps: Array) -> Array:
	var found := []
	for step: Variant in steps:
		if typeof(step) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = step
		if str(entry.get("do", "")) == "arrive":
			found.append(str(entry.get("who", "")))
		for key: String in ["then", "else"]:
			if typeof(entry.get(key)) == TYPE_ARRAY:
				found.append_array(_arrivals(entry[key]))
		if typeof(entry.get("choose")) == TYPE_ARRAY:
			for option: Dictionary in entry["choose"]:
				found.append_array(_arrivals(option.get("then", [])))
	return found


func _after_party() -> void:
	var entry := Life.party(party)
	var bed := Life.went(profile, party, day)
	done["party"] = true
	var left := str(entry.get("left", ""))
	var cards: Dictionary = Life.rule("left_cards", {})
	if not left.is_empty() and profile.has_flag(left) and cards.has(left):
		var card: Array = cards[left]
		_card(str(card[0]), str(card[1]), _end_night.bind(bed, true))
		return
	_end_night(bed, true)


# --- What the conversations ask for ----------------------------------------------------

## The evening's own story actions (see perform).
const ACTIONS := ["shot", "join", "game", "page", "arrive"]


func perform(step: Dictionary) -> Variant:
	match str(step["do"]):
		"shot":
			_start_shot(str(step.get("name", "talk")))
			return 0.0
		"join":
			chai_with = str(step.get("who", ""))
			story.focus = chai_with
			return 0.0
		"game":
			return _start_game()
		"page":
			_page()
			return 1.4
		"arrive":
			return _arrive(str(step.get("who", "")))
	return null


func mark(mark_name: String) -> Variant:
	if current_set == null or not current_set.marks.has(mark_name):
		return null
	return current_set.to_global(current_set.marks[mark_name])


func _play(kind: String, steps: Array) -> void:
	phase = "talk"
	talking = kind
	story.focus = ""
	story.play(steps)


func _on_story_finished(_skipped: bool) -> void:
	_drop_pager()
	match talking:
		"chai":
			if not chai_with.is_empty():
				Life.had_chai(profile, chai_with, day)
			done["canteen"] = true
			minutes += int(_activity("canteen").get("minutes", 40))
			show_menu()
		"call":
			_after_call()
		"party":
			_after_party()


## The party's game, over the scene; the conversation waits for it.
func _start_game() -> Variant:
	var entry := Life.party(party)
	var against := str(entry.get("against", "varun"))
	var seed_value := absi(("game|%s|%d|%d" % [party, ShiftDay.hospital_seed(profile), day]).hash())
	match str(entry.get("game", "")):
		"carrom":
			game = CarromGame.new(against, seed_value)
		"antakshari":
			game = AntakshariGame.new(against, seed_value, Life.rule("antakshari", {}))
		"dance":
			game = DanceGame.new(against, seed_value)
		"speech":
			game = SpeechGame.new(((Life.rule("speeches", {}) as Dictionary).get(str(entry.get("speech", "")), {})),
				Life.rule("verdicts", {}))
		_:
			return 0.0
	_stage_game(against)
	game.name = "Game"
	game.finished.connect(_on_game_finished)
	game.moment.connect(_on_game_moment)
	_layer.add_child(game)
	_layer.move_child(game, overlay.get_index())
	ui.hide_line()
	ui.visible = false
	phase = "game"
	_start_shot("game")
	return func() -> bool: return game == null


## The doctor (and the rival) take their places for the game, across the
## cut to the game's shot, and everyone else turns to watch.
func _stage_game(against: String) -> void:
	if current_set == null:
		return
	var spots: Dictionary = current_set.play_spots
	var middle := Vector3.ZERO
	var placed := 0
	for key: String in spots:
		var who := "you" if key == "you" else against
		var rig: AvatarRig = story.actors.get(who)
		if rig == null or not rig.visible:
			continue
		var spot: Array = spots[key]
		rig.sitting = false
		rig.global_position = current_set.to_global(spot[0])
		rig.rotation.y = float(spot[1])
		middle += rig.global_position
		placed += 1
	if placed == 0:
		return
	middle /= float(placed)
	for id: String in story.actors:
		var rig: AvatarRig = story.actors[id]
		if id == "you" or id == against or not rig.visible:
			continue
		rig.rotation.y = atan2(middle.x - rig.global_position.x, middle.z - rig.global_position.z)


func _on_game_finished(result: String) -> void:
	if result in ["won", "great", "ok", "flop"]:
		profile.set_flag(Life.result_flag(party, result))
	if game != null:
		if game.get_parent() != null:
			game.get_parent().remove_child(game)
		game.queue_free()
		game = null
	for rig: AvatarRig in story.actors.values():
		rig.set_gesture("")
	ui.visible = true
	phase = "talk"


## The people react to the game: a good line gets a cheer, a coin in a
## pocket a clap, a flop a shrug.
func _on_game_moment(kind: String) -> void:
	var cheer := {"great": "cheer", "good": "clap", "bad": "shrug"}
	if not cheer.has(kind):
		return
	for id: String in story.actors:
		if id == "you" or not (story.actors[id] as AvatarRig).visible:
			continue
		(story.actors[id] as AvatarRig).set_gesture(cheer[kind])
	var you: AvatarRig = story.actors.get("you")
	if you != null:
		you.set_gesture({"great": "cheer", "good": "open_hands", "bad": "shrug"}[kind])


## Dancing: on every beat of a dance-off, the doctor and the rival strike
## the next move.
func _dance_moves() -> void:
	var dance := game as DanceGame
	if dance == null:
		return
	var beat := dance.beat_index()
	if beat == _beat or beat < 0:
		return
	_beat = beat
	var moves := ["cheer", "clap", "raise", "wave", "point", "clap"]
	var you: AvatarRig = story.actors.get("you")
	var rival: AvatarRig = story.actors.get(dance.against)
	if you != null:
		you.set_gesture(moves[beat % moves.size()])
	if rival != null:
		rival.set_gesture(moves[(beat + 3) % moves.size()])


## The pager goes off: the page, just above the line being said, until the
## conversation ends.
func _page() -> void:
	Sfx.play(self, "pager", -2.0)
	var talk := str(Life.party(party).get("talk", ""))
	var text := str((Life.rule("pages", {}) as Dictionary).get(talk, "You're needed."))
	_drop_pager()
	pager = UiKit.panel(Color(0.16, 0.08, 0.02, 0.95), 14, Vector2(16, 10))
	pager.name = "Pager"
	pager.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := pager.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color = UiKit.AMBER
	style.set_border_width_all(2)
	var column := UiKit.vbox(2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pager.add_child(column)
	column.add_child(UiKit.label("PAGER", 12, UiKit.AMBER, UiKit.heavy_font()))
	var words := UiKit.label(text, 15, UiKit.TEXT, UiKit.heading_medium_font())
	words.name = "Page"
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(words)
	_layer.add_child(pager)
	var line := ui.get_node_or_null("Line") as Control
	if line != null and not line.resized.is_connected(_place_pager):
		line.resized.connect(_place_pager)
	_place_pager()
	_layer.move_child(pager, overlay.get_index())
	var you: AvatarRig = story.actors.get("you")
	if you != null:
		you.set_gesture("think")
		you.set_mood(AvatarConfig.Mood.WORRIED)


## The page sits just above the line being said, the width of it, so it
## never covers the replies or the name card at the top.
func _place_pager() -> void:
	if pager == null:
		return
	var line := ui.get_node_or_null("Line") as Control
	var above := UiKit.px(14)
	if line != null and line.is_visible_in_tree():
		# A line just put up hasn't wrapped yet (it is briefly very tall): it
		# moves the page again once it has (resized).
		above += minf(line.size.y, get_viewport().get_visible_rect().size.y * 0.4) + UiKit.px(10)
	pager.anchor_left = 0.0
	pager.anchor_right = 1.0
	pager.anchor_top = 1.0
	pager.anchor_bottom = 1.0
	pager.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pager.offset_left = UiKit.px(14)
	pager.offset_right = -UiKit.px(14 + 326 + 14)
	pager.offset_bottom = -above
	pager.offset_top = pager.offset_bottom
	UiKit.keep_off_edges(pager)


func _drop_pager() -> void:
	var line: Control = null
	if ui != null:
		line = ui.get_node_or_null("Line") as Control
	if line != null and line.resized.is_connected(_place_pager):
		line.resized.disconnect(_place_pager)
	if pager != null:
		if pager.get_parent() != null:
			pager.get_parent().remove_child(pager)
		pager.queue_free()
		pager = null


## Someone walks in from the door to the next free spot.
func _arrive(who: String) -> Variant:
	var rig: AvatarRig = story.actors.get(who)
	if rig == null:
		return 0.0
	rig.visible = true
	story.walk(who, current_set.to_global(current_set.free_spot()))
	if who not in current_set.guests:
		current_set.guests.append(who)
	return func() -> bool: return not story.is_walking(who)


# --- Bed --------------------------------------------------------------------------------

## Lights out now (with the walk back from the canteen). A party not gone
## to is a party skipped.
func go_to_bed() -> void:
	if phase == "done" or bedtime >= 0:
		return
	if not party.is_empty() and not done.has("party"):
		Life.skipped(profile, party, day)
	var walk := int(_activity("hostel").get("minutes", 12)) if where == "canteen" else 0
	_end_night(minutes + walk, ate)


## The end of the evening: bed at a time, and a card with how much sleep
## that is, home, and tomorrow.
func _end_night(bed: int, had_food: bool) -> void:
	bedtime = bed
	Life.go_to_bed(profile, day, bed, had_food)
	var hours := Life.sleep_hours(bed, had_food)
	var sleep := "%s of sleep before the 06:30 alarm." % Life.hours_text(hours)
	if not had_food:
		sleep += " On an empty stomach."
	if hours < float(Life.rule("good_sleep", 6.5)):
		sleep += " Your hands will know."
	var hooks := {"goal": _home_line(), "tomorrow": DayHooks.tomorrow(profile, day)}
	panel.visible = false
	call_frame.visible = false
	phase = "card"
	overlay.end_card("Lights out · %s" % Life.clock(bed), sleep, hooks, 6.5)
	_after_card = _finish


func _home_line() -> String:
	if done.has("call"):
		return "Called home. Mum is satisfied. Temporarily."
	var away := Life.days_without_home(profile, day + 1)
	if away > int(Life.rule("home_every", 4)) - 1:
		return "No call home for %d days. Mum is packing rajma." % away
	if away >= 2:
		return "No call home for %d days. Mum has noticed." % away
	if profile.count(Life.CALLS) == 0:
		return "Home is still waiting for your first call. Mum is holding the phone."
	return ""


func _finish() -> void:
	phase = "done"
	songs.stop()
	finished.emit()


# --- Cards and the camera -------------------------------------------------------------

## A card over a dark screen (tap to go on), then something happens.
func _card(title: String, sub: String, then: Callable, time: float = CARD_TIME) -> void:
	phase = "card"
	panel.visible = false
	overlay.end_card(title, sub, {}, time)
	_after_card = then


func _start_shot(shot_name: String, offset: float = -1.0) -> void:
	if current_set == null or not current_set.shots.has(shot_name):
		return
	_shot = current_set.shots[shot_name]
	_shot_t = 0.0
	camera.fov = float(_shot.get("fov", 44.0))
	camera.h_offset = offset if offset >= 0.0 else float(_shot.get("offset", 0.0))
	camera.v_offset = float(_shot.get("lift", 0.0))
	_update_camera(0.0)


func _update_camera(delta: float) -> void:
	if _shot.is_empty() or current_set == null or not is_inside_tree():
		return
	_shot_t += delta
	var from: Vector3 = _shot["from"]
	var at: Vector3 = _shot["at"]
	# A slow drift, so a still evening still breathes.
	var drift := Vector3(sin(_shot_t * 0.21) * 0.08, sin(_shot_t * 0.17) * 0.03, 0.0)
	camera.look_at_from_position(current_set.to_global(from + drift), current_set.to_global(at))


# --- For tests and the screenshot tool --------------------------------------------------

## Plays forward until a condition holds: replies are picked (number
## choose_reply), lines read through, games played at skill (0 to 1) and
## cards tapped away. Menu choices are the caller's (choose()). Returns
## true if the condition was met.
func play_until(condition: Callable, choose_reply: int = 0, skill: float = 0.7, seconds: float = 300.0) -> bool:
	var step := 1.0 / 30.0
	var elapsed := 0.0
	var reading := ui.auto_advance
	ui.auto_advance = 0.0
	while elapsed < seconds:
		if bool(condition.call()):
			ui.auto_advance = reading
			return true
		if phase == "done":
			break
		if ui.is_choosing():
			story.choose(clampi(choose_reply, 0, ui.choice_buttons().size() - 1))
		elif game != null:
			game.auto_step(skill)
		elif phase == "card":
			overlay.skip_end_card()
		update(step)
		elapsed += step
	ui.auto_advance = reading
	return bool(condition.call())
