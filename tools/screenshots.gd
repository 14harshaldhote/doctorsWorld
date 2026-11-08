extends SceneTree
## Renders the store-style screenshots of every stage-1 screen.
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
	var lobby := Lobby.new(doctor)
	await _shot("05-lobby", lobby, func() -> void: lobby.stage_for_screenshot(false))
	var talking := Lobby.new(doctor)
	await _shot("06-lobby-talk", talking, func() -> void: talking.stage_for_screenshot(true))
	quit(0)


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
	var path := _out.path_join("%s-%s.png" % [_prefix, shot_name])
	root.get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
