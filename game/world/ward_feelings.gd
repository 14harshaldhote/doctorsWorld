class_name WardFeelings
extends RefCounted
## Ward 4's side of the director and the staff's lives (stage 26): it
## shows what the director decides and lets the colleagues come and ask.
##
##   moments    the emotional ones, on a MomentCard once the doctor is free
##              (a patient's only in casualty, where they are)
##   silliness  a toast and a voice in the middle of a serious scene, if the
##              doctor is there to see it (the goat walks across casualty)
##   breathers  a toast and a voice anywhere (the radio plays a song)
##   colleagues on a day one of them wants to ask (Lives), they walk up to
##              the doctor standing on the ward and the conversation plays;
##              then they go back to what they were doing. Mum does the same
##              when nobody has called home for days (Life, stage 27)
##   songs      the night nurses' song late on a night shift, the canteen's
##              jingle at lunchtime every few days, with the words on screen
##
## None of it runs while a conversation, a task, a card or the phone's own
## song is on, and the clock doesn't run while a card or a colleague is
## with the doctor.

## Seconds between looks for a colleague who wants to ask.
const LIVES_EVERY := 0.5
## How close a colleague comes to talk, in metres.
const SIDE_REACH := 1.15
## A colleague who hasn't arrived after this long just starts talking.
const SIDE_TIMEOUT := 9.0
## The night nurses sing from 23:30; the canteen's jingle plays between
## 12:45 and 14:30, one day in DAL_EVERY (and the first time casualty's open).
const NIGHT_SONG_AT := 23 * 60 + 30
const DAL_FROM := 12 * 60 + 45
const DAL_UNTIL := 14 * 60 + 30
const DAL_EVERY := 3
## The most moments waiting for the doctor at once.
const MOMENTS_QUEUE := 2

var ward: Ward
## Moments waiting to be shown: [{"moment", "patient"}].
var moments: Array[Dictionary] = []
var card: MomentCard
## The colleague walking up or talking: {"arc", "who", "talk", "phase"
## ("walking", "talking"), "was": {"visible", "position", "turn"}, "clock"}.
var side := {}
## A colleague walking back to where they were: {"who", "turn"}.
var returning := {}
## For the screenshot tool: nothing comes round by itself (no moments,
## silliness, breathers, colleagues or songs), so the other screens show
## what they are meant to.
static var hold := false

var songs: SongPlayer
var banner: LyricsBanner
var goat: Goat
var _lives_in := 0.0
var _rng := SeededRandom.new(26)


func _init(for_ward: Ward = null) -> void:
	ward = for_ward


## Makes the song player (once the ward is in the tree).
func setup() -> void:
	songs = SongPlayer.new()
	songs.name = "Songs"
	songs.manual = true
	songs.called = ward.profile.called()
	songs.finished.connect(_on_song_finished)
	ward.add_child(songs)


## A new shift: nothing carried over.
func reset() -> void:
	moments.clear()
	_close_card()
	stop_song()
	if goat != null and is_instance_valid(goat):
		goat.queue_free()
	goat = null
	if not side.is_empty():
		_put_back(str(side["who"]), side["was"])
	side = {}
	returning = {}


func tick(delta: float) -> void:
	if songs != null and songs.playing():
		if not _free_for_song(true):
			stop_song()
		else:
			songs.tick(delta)
	if goat != null:
		if not is_instance_valid(goat) or goat.is_queued_for_deletion():
			goat = null
		elif ward.place == "casualty":
			goat.tick(delta)
		else:
			goat.queue_free()
			goat = null
	_tick_side(delta)
	_tick_returning()
	_open_moment()
	_lives_in -= delta
	if _lives_in <= 0.0 and not hold:
		_lives_in = LIVES_EVERY
		_maybe_side()
		_maybe_song()


## The director's events the ward passes on.
func on_event(event: Dictionary) -> void:
	if hold:
		return
	match str(event.get("kind", "")):
		"moment":
			if moments.size() < MOMENTS_QUEUE:
				moments.append({"moment": str(event.get("moment", "")), "patient": event.get("patient")})
		"silly":
			_silly(event)
		"lift":
			_lift(event)


# --- Moments ------------------------------------------------------------------------

func _open_moment() -> void:
	if card != null or moments.is_empty() or not _free_for_card():
		return
	# A patient's moment waits for the doctor in casualty, while they're still there.
	for index in moments.size():
		var waiting: Dictionary = moments[index]
		var patient: ShiftPatient = waiting.get("patient")
		if patient != null and not patient.is_here():
			moments.remove_at(index)
			return
		if patient != null and ward.place != "casualty":
			continue
		moments.remove_at(index)
		_show_card(str(waiting["moment"]), patient)
		return


func _free_for_card() -> bool:
	return ward.mode in ["walk", "approach"] and ward.family == null and ward.wall == null and ward.view == null \
		and ward._deaths.is_empty() and side.is_empty() and ward.place in ["ward", "casualty"] and not ward.story.is_playing()


func _show_card(id: String, patient: ShiftPatient) -> void:
	stop_song()
	ward._stop_answer()
	ward._routes.erase("you")
	ward.heading = ""
	ward.mode = "family"
	ward.player.moving = 0.0
	ward.hud.set_talking(true)
	card = MomentCard.new(id, patient)
	card.finished.connect(_on_card_done.bind(id, patient))
	ward._layer.add_child(card)
	ward._layer.move_child(card, ward.overlay.get_index())


func _on_card_done(choice: String, id: String, patient: ShiftPatient) -> void:
	Feelings.choose(ward.profile, id, choice, patient)
	_close_card()
	ward._back_to_walking()
	ward.save_requested.emit()


func _close_card() -> void:
	if card != null:
		if card.get_parent() != null:
			card.get_parent().remove_child(card)
		card.queue_free()
		card = null


## The moment open now, for tests.
func moment_card() -> MomentCard:
	return card


# --- Silliness and breathers -----------------------------------------------------------

## Something silly in the middle of a serious scene, if the doctor is
## there to see it.
func _silly(event: Dictionary) -> void:
	if ward.place != "casualty":
		return
	var id := str(event.get("silly", ""))
	var entry: Dictionary = Feelings.sillies().get(id, {})
	var patient: ShiftPatient = event.get("patient")
	var line: Dictionary = entry.get("line", {})
	ward._queue_toast(str(entry.get("text", "")), 3, false,
		[str(line.get("text", "")), Feelings.voice_for(line, patient, _rng)] if not line.is_empty() else [])
	if bool(entry.get("goat", false)):
		_bring_goat()
	if entry.has("sound"):
		Sfx.play(ward, str(entry["sound"]), -6.0)


## A goat, in through casualty's door and out the far side.
func _bring_goat() -> void:
	if goat != null and is_instance_valid(goat):
		return
	goat = Goat.new()
	goat.path = [CasualtyRoom.DOOR + Vector3(-0.4, 0, 0.5), Vector3(-6.9, 0, 0.9)]
	ward.casualty.add_child(goat)


## A breather after a hard stretch: anywhere in the hospital. The radio's
## plays a song, when nothing else is on.
func _lift(event: Dictionary) -> void:
	var id := str(event.get("lift", ""))
	var entry: Dictionary = Feelings.lifts().get(id, {})
	var line: Dictionary = entry.get("line", {})
	if entry.has("song") and _free_for_song(false) and not line.is_empty():
		ward._queue_toast(str(entry.get("text", "")), 2, false)
		play_song(str(entry["song"]), line)
		return
	ward._queue_toast(str(entry.get("text", "")), 2, false,
		[str(line.get("text", "")), str(line.get("say", ""))] if not line.is_empty() else [])


# --- Songs ---------------------------------------------------------------------------

## True when a song can play (or carry on): the doctor walking on the ward
## or in casualty with nothing else on.
func _free_for_song(playing: bool) -> bool:
	if ward.place not in ["ward", "casualty"] or ward.story.is_playing() or ward.view != null:
		return false
	if not playing and (card != null or not side.is_empty() or (songs != null and songs.playing())):
		return false
	return ward.mode in ["walk", "approach"]


## Plays a song with its words on screen, after a request when given.
func play_song(id: String, request: Dictionary = {}) -> bool:
	if songs == null or not songs.play(id, request):
		return false
	if banner == null:
		banner = LyricsBanner.new(songs)
		banner.buttons_rect = ward.hud.buttons_rect
		banner.stop_pressed.connect(stop_song)
		ward._layer.add_child(banner)
		ward._layer.move_child(banner, ward.overlay.get_index())
		ward.hud.set_hint_hidden(true)
	return true


func stop_song() -> void:
	if songs != null and songs.playing():
		songs.stop()
	_drop_banner()


func _on_song_finished() -> void:
	_drop_banner()


func _drop_banner() -> void:
	if banner != null:
		ward.hud.set_hint_hidden(false)
		if banner.get_parent() != null:
			banner.get_parent().remove_child(banner)
		banner.queue_free()
		banner = null


## The songs that come round by themselves: the night nurses late on a
## night shift on the ward, the canteen's jingle at lunchtime.
func _maybe_song() -> void:
	if not _free_for_song(false) or SongPlayer.active != null:
		return
	var profile := ward.profile
	if ward.night:
		if ward.place == "ward" and profile.minutes >= NIGHT_SONG_AT and profile.count("song_night") != profile.day:
			profile.set_count("song_night", profile.day)
			play_song("night")
		return
	if ward.shift == null or profile.minutes < DAL_FROM or profile.minutes > DAL_UNTIL or profile.count("song_dal") == profile.day:
		return
	var due := profile.count("song_dal") == 0 \
		or absi(("dal|%d|%d" % [ShiftDay.hospital_seed(profile), profile.day]).hash()) % DAL_EVERY == 0
	if due:
		profile.set_count("song_dal", profile.day)
		play_song("dal")


# --- Colleagues ------------------------------------------------------------------------

## A colleague who wants to ask today walks up, if the doctor is standing
## on the ward with nothing on, the shift isn't in a hard stretch, and
## they're free to (not lying in a bed or walking somewhere for the story).
func _maybe_side() -> void:
	if not side.is_empty() or not returning.is_empty() or ward.place != "ward" or ward.mode != "walk":
		return
	if not ward.heading.is_empty() or ward._routes.has("you") or ward.story.is_playing() or ward.view != null:
		return
	if card != null or ward.family != null or ward.wall != null or (songs != null and songs.playing()):
		return
	var profile := ward.profile
	if profile.minutes < int(Lives.data().get("talk_from", 600)) and not ward.night:
		return
	if ward.shift != null and ward.shift.director != null and ward.shift.director.tension >= float(Feelings.rule("hard", 55)):
		return
	# Nobody has called home for days (stage 27, Life): Mum comes herself.
	if not ward.night and Life.mum_due(profile) and profile.count(Life.MUM) != profile.day:
		start_mum()
		return
	var arc := Lives.today(profile)
	if arc.is_empty():
		return
	var who := Lives.who(arc)
	var rig := ward.rig_for(who)
	if rig == null or rig.lying or rig.sitting or ward.is_walking(who):
		return
	start_side(arc)


## A colleague walks up to ask (also for tests and screenshots).
func start_side(arc: String) -> void:
	_visit(Lives.who(arc), Lives.talk(arc), arc)


## Mum walks onto the ward with rajma (also for tests and screenshots).
## Sister Grace has a word if she's on the ward.
func start_mum() -> void:
	var grace := ward.rig_for("grace")
	ward.profile.set_flag("lf_grace_here", grace != null and grace.visible)
	_visit("mum", str(Life.rule("visit_talk", "lf_mum_visit")), "")


func _visit(who: String, talk: String, arc: String) -> void:
	var rig := ward.rig_for(who)
	if rig == null:
		return
	side = {"arc": arc, "who": who, "talk": talk, "phase": "walking", "clock": 0.0,
		"was": {"visible": rig.visible, "position": rig.position, "turn": rig.rotation.y}}
	if not rig.visible:
		ward.put(who, "door")
	ward.mode = "side"
	ward.player.moving = 0.0
	ward.hud.set_talking(true)
	var name := str(StoryBook.cast().get(who, {}).get("name", who))
	if who == "mum":
		ward.hud.toast("Is that Mum? On Ward 4? With a steel dabba?")
	else:
		ward.hud.toast("%s is coming over." % (name if name.begins_with("Dr.") or name.begins_with("Sister") else name.split(" ")[0]))
	var towards := rig.position - ward.player.position
	towards.y = 0.0
	if towards.length() > SIDE_REACH + 0.2:
		ward._send(who, ward.player.position + towards.normalized() * SIDE_REACH, Ward.WALK_SPEED)


func _tick_side(delta: float) -> void:
	if side.is_empty() or str(side["phase"]) != "walking":
		return
	side["clock"] = float(side["clock"]) + delta
	var who := str(side["who"])
	if ward.is_walking(who) and float(side["clock"]) < SIDE_TIMEOUT:
		return
	ward._routes.erase(who)
	var rig := ward.rig_for(who)
	rig.moving = 0.0
	ward._face(rig, ward.player.position)
	ward._face(ward.player, rig.position)
	side["phase"] = "talking"
	ward.hud.hide_toast()
	ward._talk(str(side["talk"]), who)


## The ward's conversation ended: true when it was a colleague's ask (they
## are noted as having asked and walk back to what they were doing).
func talk_finished(key: String) -> bool:
	if side.is_empty() or key != str(side["talk"]):
		return false
	if not str(side["arc"]).is_empty():
		Lives.asked(ward.profile, str(side["arc"]))
	elif str(side["who"]) == "mum":
		Life.mum_came(ward.profile)
	var who := str(side["who"])
	var was: Dictionary = side["was"]
	side = {}
	if bool(was["visible"]):
		ward._send(who, was["position"], Ward.WALK_SPEED)
		returning = {"who": who, "turn": float(was["turn"]), "position": was["position"]}
	else:
		ward._leaving[who] = true
		ward._send(who, Ward.DOOR, Ward.WALK_SPEED)
		if not ward.is_walking(who):
			ward._leaving.erase(who)
			ward._hide(who)
	return true


func _tick_returning() -> void:
	if returning.is_empty():
		return
	var who := str(returning["who"])
	if ward.is_walking(who):
		return
	var rig := ward.rig_for(who)
	if rig != null and rig.position.distance_to(returning["position"]) < 0.6:
		rig.rotation.y = float(returning["turn"])
	returning = {}


## Puts someone back exactly as they were, at once (a shift ending mid-ask).
func _put_back(who: String, was: Dictionary) -> void:
	var rig := ward.rig_for(who)
	if rig == null:
		return
	ward._routes.erase(who)
	ward._leaving.erase(who)
	if not bool(was.get("visible", true)):
		ward._hide(who)
		return
	rig.position = was["position"]
	rig.rotation.y = float(was["turn"])
	rig.moving = 0.0
