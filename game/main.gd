class_name Main
extends Node
## Runs the game: loads the save, then moves between the title screen, the
## new-career steps (name, look), the opening story and the hospital.

var store := SaveStore.new()
var settings_path := GameSettings.DEFAULT_PATH
var profile: PlayerProfile
var has_save := false
var screen: Node
var music: Music
## A dark curtain that lifts after every change of screen.
var _curtain: ColorRect


func _ready() -> void:
	var loaded := store.load_or_start()
	profile = loaded["profile"]
	has_save = loaded["outcome"] == SaveStore.Outcome.LOADED and profile.created
	var had_settings := FileAccess.file_exists(settings_path)
	GameSettings.current = GameSettings.load_from(settings_path)
	if not had_settings and has_save and not profile.sound_on:
		# Sound was switched off before there were separate volumes.
		for bus: String in GameSettings.BUSES:
			GameSettings.current.set_volume(bus, 0.0)
	SettingsPanel.save_path = settings_path
	GameSettings.current.apply(get_window())
	music = Music.new()
	music.name = "Music"
	add_child(music)
	Music.player = music
	Sfx.host = self
	var layer := CanvasLayer.new()
	layer.name = "Curtain"
	layer.layer = 100
	add_child(layer)
	_curtain = ColorRect.new()
	_curtain.color = Color(0.02, 0.07, 0.09, 0.0)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(UiKit.fill(_curtain))
	show_title()


func _exit_tree() -> void:
	if Music.player == music:
		Music.player = null
	if Sfx.host == self:
		Sfx.host = null


func _swap(next: Node) -> void:
	var changing := screen != null
	if screen != null:
		remove_child(screen)
		screen.queue_free()
	screen = next
	add_child(next)
	if _curtain != null and changing:
		_lift_curtain()


## The new screen fades in from dark, quicker with Reduce motion on.
func _lift_curtain() -> void:
	_curtain.color.a = 1.0
	var lift := _curtain.create_tween()
	lift.tween_property(_curtain, "color:a", 0.0, 0.2 if GameSettings.current.reduce_motion else 0.45) \
		.set_trans(Tween.TRANS_SINE)


func show_title() -> void:
	var title := TitleScreen.new(profile if has_save else null)
	title.new_career_pressed.connect(_on_new_career)
	title.continue_pressed.connect(show_hospital)
	_swap(title)


func _on_new_career() -> void:
	profile = PlayerProfile.new()
	show_name()


func show_name() -> void:
	var naming := NameScreen.new(profile)
	naming.back_pressed.connect(show_title)
	naming.next_pressed.connect(show_creator.bind(false))
	_swap(naming)


## editing is true when changing the look from the pause menu.
func show_creator(editing: bool) -> void:
	var creator := AvatarCreator.new(profile)
	creator.back_pressed.connect(show_hospital if editing else show_name)
	creator.done_pressed.connect(_on_look_done)
	_swap(creator)


func _on_look_done() -> void:
	profile.created = true
	_save()
	show_hospital()


## Graduation, the letter and the first morning, with the player's own doctor.
func show_opening() -> void:
	var opening := Opening.new(profile)
	opening.finished.connect(_on_opening_finished)
	_swap(opening)


func _on_opening_finished(_skipped: bool) -> void:
	profile.opening_seen = true
	_save()
	show_hospital()


## The hospital. A career that has not seen the opening plays it first, and
## Day 1 starts with Dr. Iyer at the door until the player has met her.
## Day 2 is the skills lab, Day 3 is Rohit's operation, and from Day 4 the
## doctor works on the surgical ward: a week of patients, a night on call
## and the review that makes them a Junior Resident, then (Day 9, eight
## months later) the Junior Resident's operations, up to Senior Resident.
func show_hospital() -> void:
	if not profile.opening_seen:
		show_opening()
		return
	if profile.day == 1 and profile.has_flag("day1_iyer"):
		# Day 1 was finished before the skills lab existed.
		_start_day(2)
		return
	if profile.day == 3 and profile.has_flag("op_rohit_done"):
		# The operation was finished but the day was not.
		_start_day(4)
		return
	if profile.day == 3:
		show_theatre()
		return
	if profile.day > WardStory.FIRST_DAY and not profile.has_flag("jump_%d" % WardStory.FIRST_DAY):
		# Saved on a quiet day before the Junior Resident's months existed:
		# start them from their first day.
		_start_day(WardStory.FIRST_DAY)
		return
	if profile.day >= Ward.FIRST_DAY:
		show_ward()
		return
	if profile.day >= 2:
		show_skills_lab()
		return
	var lobby := Lobby.new(profile, not profile.has_flag("met_iyer"))
	lobby.save_requested.connect(_save)
	lobby.menu_choice.connect(_on_menu_choice)
	lobby.day_finished.connect(_on_day_finished)
	_swap(lobby)


## Day 2: six training stations with Dr. Iyer, Sister Grace and Tom.
func show_skills_lab() -> void:
	var lab := SkillsLab.new(profile)
	lab.save_requested.connect(_save)
	lab.menu_choice.connect(_on_menu_choice)
	lab.day_finished.connect(_on_day_finished)
	_swap(lab)


## Day 3: Rohit's appendectomy, from consent on the ward to his mother after.
func show_theatre() -> void:
	var theatre := Theatre.new(profile)
	theatre.save_requested.connect(_save)
	theatre.menu_choice.connect(_on_menu_choice)
	theatre.day_finished.connect(_on_day_finished)
	_swap(theatre)


## Day 4 onwards: the surgical ward.
func show_ward() -> void:
	var ward := Ward.new(profile)
	ward.save_requested.connect(_save)
	ward.menu_choice.connect(_on_menu_choice)
	ward.day_finished.connect(_on_day_finished)
	_swap(ward)


func _on_day_finished() -> void:
	_start_day(profile.day + 1)


func _start_day(day: int) -> void:
	profile.day = day
	profile.minutes = PlayerProfile.DAY_START
	_save()
	show_hospital()


func _on_menu_choice(choice: String) -> void:
	match choice:
		"look":
			show_creator(true)
		"title":
			show_title()


func _save() -> void:
	if store.save(profile) == OK:
		has_save = true
