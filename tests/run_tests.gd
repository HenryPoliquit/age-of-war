extends SceneTree
## Headless test runner:  tools/godot --headless --path . -s tests/run_tests.gd
## Runs every `test_*` method of every tests/test_*.gd; exits 1 on any failure.
## A script error raised during a test (e.g. calling a missing method) fails that test too.


## Collects script errors: GDScript has no exceptions, so an erroring test would otherwise just
## stop early and look like a pass.
class ErrorCounter extends Logger:
	var mutex := Mutex.new()
	var errors: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_SCRIPT:
			return
		mutex.lock()
		errors.append("script error: %s (%s:%d in %s)" % [rationale if rationale != "" else code, file, line, function])
		mutex.unlock()


func _init() -> void:
	var files := Array(DirAccess.get_files_at("res://tests"))
	files.sort()
	var total := 0
	var failed: Array[String] = []
	var errors := ErrorCounter.new()
	OS.add_logger(errors)
	for f in files:
		if not (f.begins_with("test_") and f.ends_with(".gd")) or f == "test_case.gd":
			continue
		var script: GDScript = load("res://tests/" + f)
		if script == null or not script.can_instantiate():
			print("  FAIL ", f, " (does not compile)")
			failed.append(f + " does not compile")
			continue
		for m in script.get_script_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			var tc: TestCase = script.new()
			tc._current = "%s::%s" % [f.get_basename(), name]
			var seen := errors.errors.size()
			tc.call(name)
			total += 1
			for i in range(seen, errors.errors.size()):
				tc.failures.append("%s: %s" % [tc._current, errors.errors[i]])
			if tc.failures.is_empty():
				print("  ok   ", tc._current)
			else:
				print("  FAIL ", tc._current)
				for msg in tc.failures:
					print("         ", msg)
				failed.append_array(tc.failures)
	print("\n%d tests, %d failures" % [total, failed.size()])
	quit(1 if not failed.is_empty() else 0)
