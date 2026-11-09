class_name Main
extends Node
## Runs the game: loads the save, then moves between the title screen, the
## new-career steps (name, look), the opening story and the hospital.

var store := SaveStore.new()
var profile: PlayerProfile
var has_save := false
var screen: Node


func _ready() -> void:
	var loaded := store.load_or_start()
	profile = loaded["profile"]
	has_save = loaded["outcome"] == SaveStore.Outcome.LOADED and profile.created
	Voice.enabled = profile.sound_on
	show_title()


func _swap(next: Node) -> void:
	if screen != null:
		remove_child(screen)
		screen.queue_free()
	screen = next
	add_child(next)


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
## Day 2 is the skills lab, Day 3 is Rohit's operation, and after it the
## doctor practises in the lab while Rohit recovers.
func show_hospital() -> void:
	if not profile.opening_seen:
		show_opening()
		return
	if profile.day == 1 and profile.has_flag("day1_iyer"):
		# Day 1 was finished before the skills lab existed.
		_start_day(2)
		return
	Voice.enabled = profile.sound_on
	if profile.day == 3 and profile.has_flag("op_rohit_done"):
		# The operation was finished but the day was not.
		_start_day(4)
		return
	if profile.day == 3:
		show_theatre()
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
