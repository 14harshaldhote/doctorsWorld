extends SceneTree
var frames := 0
var out := ""
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0]
	out = args[1]
	var script: GDScript = load(scene_path)
	root.add_child(script.new())
func _process(_d: float) -> bool:
	frames += 1
	if frames == 8:
		root.get_viewport().get_texture().get_image().save_png(out)
		print("saved ", out)
		quit()
	return false
