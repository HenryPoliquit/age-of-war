extends SceneTree
## Headless test runner:  tools/godot --headless --path . -s tests/run_tests.gd
## Runs every `test_*` method of every tests/test_*.gd; exits 1 on any failure.


func _init() -> void:
	var files := Array(DirAccess.get_files_at("res://tests"))
	files.sort()
	var total := 0
	var failed: Array[String] = []
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
			tc.call(name)
			total += 1
			if tc.failures.is_empty():
				print("  ok   ", tc._current)
			else:
				print("  FAIL ", tc._current)
				for msg in tc.failures:
					print("         ", msg)
				failed.append_array(tc.failures)
	print("\n%d tests, %d failures" % [total, failed.size()])
	quit(1 if not failed.is_empty() else 0)
