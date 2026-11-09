extends SceneTree
## Renders the store-style screenshots of every screen and story moment.
##
##   godot --path . --resolution 1688x780 -s res://tools/screenshots.gd -- shots iphone
##
## The first argument is the output folder, the second a prefix for the file
## names (for example the device), and an optional third limits the run to
## shots whose name contains it.

const FRAMES_TO_SETTLE := 10

var _out := "shots"
var _prefix := "shot"
var _only := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_prefix = args[1]
	if args.size() > 2:
		_only = args[2]
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var doctor := sample_profile()
	await _shot("01-title", TitleScreen.new(doctor))
	await _shot("02-name", NameScreen.new(doctor))
	for tab_name in AvatarCreator.TABS:
		var creator := AvatarCreator.new(doctor)
		await _shot("03-creator-%s" % tab_name.to_lower(), creator, func() -> void:
			creator.show_tab(tab_name)
			if tab_name == "Face":
				creator.rig.set_mood(AvatarConfig.Mood.HAPPY)
			creator.settle_camera())
	await _shot("04-avatar-range", AvatarSheet.new())
	var lobby := Lobby.new(sample_profile_at_work())
	await _shot("05-lobby", lobby, func() -> void: lobby.stage_for_screenshot("walk"))
	var talking := Lobby.new(sample_profile_at_work())
	await _shot("06-lobby-talk", talking, func() -> void: talking.stage_for_screenshot("talk"))
	await _opening_shot("07-opening-graduation", func(o: Opening) -> bool:
		return o.set_name == "graduation" and o.ui.line_text().begins_with("Congratulations") and not o.ui.is_typing())
	await _opening_shot("08-opening-family", func(o: Opening) -> bool:
		return o.set_name == "graduation" and o.ui.line_text().begins_with("Twenty-two") and not o.ui.is_typing())
	await _opening_shot("09-opening-letter", func(o: Opening) -> bool:
		return o.overlay.letter_open() and o.overlay._letter.modulate.a >= 1.0, -1)
	await _opening_shot("10-opening-choice", func(o: Opening) -> bool:
		return o.set_name == "home" and o.ui.is_choosing(), -1)
	await _opening_shot("11-opening-morning", func(o: Opening) -> bool:
		return o.set_name == "morning" and o.ui.line_text().begins_with("Okay") and not o.ui.is_typing())
	var arriving := Lobby.new(sample_profile(), true)
	await _shot("12-lobby-arrival", arriving, func() -> void: arriving.stage_for_screenshot("arrival"))
	quit(0)


static func sample_profile_at_work() -> PlayerProfile:
	var doctor := sample_profile()
	doctor.opening_seen = true
	doctor.set_flag("met_iyer")
	return doctor


## A moment from the opening story: plays forward until the moment, then
## holds still for the picture.
func _opening_shot(shot_name: String, moment: Callable, reply: int = 2) -> void:
	var opening := Opening.new(sample_profile())
	await _shot(shot_name, opening, func() -> void:
		if not opening.play_until(moment.bind(opening), reply):
			push_error("The opening never reached %s" % shot_name)
		opening.set_process(false))


## The doctor used in every screenshot.
static func sample_profile() -> PlayerProfile:
	var doctor := PlayerProfile.new()
	doctor.name = "Asha Verma"
	doctor.address_form = "last"
	doctor.day = 1
	doctor.created = true
	var look := AvatarConfig.new()
	look.skin = 5
	look.hair_style = 7
	look.hair_colour = 1
	look.face = 1
	look.eyes = 1
	look.brows = 4
	look.scrubs = 0
	doctor.avatar = look
	return doctor


func _shot(shot_name: String, node: Node, prepare: Callable = Callable()) -> void:
	if not _only.is_empty() and not shot_name.contains(_only):
		node.free()
		return
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()
	root.add_child(node)
	await process_frame
	if prepare.is_valid():
		prepare.call()
	for frame in FRAMES_TO_SETTLE:
		await process_frame
	# Hold every character still: eyes open, gestures finished.
	for found in node.find_children("*", "AvatarRig", true, false):
		var rig := found as AvatarRig
		rig.blink_every = 0.0
		rig.settle()
	await process_frame
	var path := _out.path_join("%s-%s.png" % [_prefix, shot_name])
	root.get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
