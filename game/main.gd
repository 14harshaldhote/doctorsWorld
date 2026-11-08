class_name Main
extends Node
## Runs the game: loads the save, then moves between the title screen, the
## new-career steps (name, look) and the hospital.

var store := SaveStore.new()
var profile: PlayerProfile
var has_save := false
var screen: Node


func _ready() -> void:
	var loaded := store.load_or_start()
	profile = loaded["profile"]
	has_save = loaded["outcome"] == SaveStore.Outcome.LOADED and profile.created
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


func show_hospital() -> void:
	var lobby := Lobby.new(profile)
	lobby.save_requested.connect(_save)
	lobby.menu_choice.connect(_on_menu_choice)
	_swap(lobby)


func _on_menu_choice(choice: String) -> void:
	match choice:
		"look":
			show_creator(true)
		"title":
			show_title()


func _save() -> void:
	if store.save(profile) == OK:
		has_save = true
