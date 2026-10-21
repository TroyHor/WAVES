extends SceneTree
## Headless test runner:
##   godot --headless --path . -s res://tests/run_tests.gd [-- filter]
## Exits with code 1 if any test fails.

const TEST_DIR := "res://tests/unit/"


func _initialize() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		filter = args[0]

	var passed := 0
	var failed := 0
	for file in _test_files():
		var script: GDScript = load(TEST_DIR + file)
		if script == null:
			printerr("FAIL  could not load %s" % file)
			failed += 1
			continue
		for method in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			var full := "%s::%s" % [file.get_basename(), name]
			if filter != "" and not full.contains(filter):
				continue
			var test: TestCase = script.new()
			test.call(name)
			if test.failures.is_empty():
				passed += 1
			else:
				failed += 1
				printerr("FAIL  %s" % full)
				for f in test.failures:
					printerr("        %s" % f)

	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _test_files() -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(TEST_DIR):
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append(f)
	out.sort()
	return out
