extends SceneTree
## Runs every test in res://tests/unit and exits with a non-zero code if any
## check fails or any engine or script error is logged while a test runs.
##
##   godot --headless --path . -s res://tests/run_tests.gd
##
## Pass "-- --only=avatar" to run only the files whose name contains "avatar".

const UNIT_DIR := "res://tests/unit"


class ErrorCatcher extends Logger:
	var errors: PackedStringArray = []
	var _lock := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var text := rationale if not rationale.is_empty() else code
		_lock.lock()
		errors.append("%s (%s:%d in %s)" % [text, file.get_file(), line, function])
		_lock.unlock()

	func take() -> PackedStringArray:
		_lock.lock()
		var taken := errors.duplicate()
		errors.clear()
		_lock.unlock()
		return taken


var _started := false


# Tests run on the first frame, once the scene tree is fully running, so
# nodes added by a test get their _ready() call like they would in the game.
func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run_all()
	return false


func _run_all() -> void:
	var catcher := ErrorCatcher.new()
	OS.add_logger(catcher)
	var only := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			only = argument.trim_prefix("--only=")

	var files := DirAccess.get_files_at(UNIT_DIR)
	var names: Array[String] = []
	for file in files:
		if file.begins_with("test_") and file.ends_with(".gd") and (only.is_empty() or file.contains(only)):
			names.append(file)
	names.sort()

	var total := 0
	var failed: Array[String] = []
	var started := Time.get_ticks_msec()
	for file in names:
		catcher.take()
		var script: GDScript = load(UNIT_DIR.path_join(file))
		var load_problems := catcher.take()
		if script == null or not script.can_instantiate() or not load_problems.is_empty():
			# A file that does not even load is a failure, not zero tests.
			total += 1
			load_problems.insert(0, "the test file failed to load")
			failed.append("%s\n      %s" % [file.get_basename(), "\n      ".join(load_problems)])
			print("✗ %s (did not load)" % file.get_basename())
			continue
		var methods: Array[String] = []
		for method in script.get_script_method_list():
			var method_name: String = method["name"]
			if method_name.begins_with("test_") and not methods.has(method_name):
				methods.append(method_name)
		methods.sort()
		var suite_failures := 0
		for method_name in methods:
			total += 1
			catcher.take()
			var case: TestCase = script.new()
			case.tree = self
			case.call(method_name)
			case.cleanup()
			var problems := case.failures.duplicate()
			problems.append_array(catcher.take())
			if not problems.is_empty():
				suite_failures += 1
				failed.append("%s › %s\n      %s" % [file.get_basename(), method_name, "\n      ".join(problems)])
		print("%s %s (%d tests)" % ["✗" if suite_failures > 0 else "✓", file.get_basename(), methods.size()])

	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	if failed.is_empty():
		print("\nAll %d tests passed in %.2f s." % [total, seconds])
		quit(0)
	else:
		print("\n%d of %d tests failed:" % [failed.size(), total])
		for line in failed:
			print("  ✗ " + line)
		quit(1)
