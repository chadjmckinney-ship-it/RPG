extends SceneTree
## Minimal headless test runner:  godot --headless -s res://tests/run_tests.gd
## Runs every test_* method in the suites below; exits 1 on any failure.

const SUITES := ["res://tests/test_world.gd", "res://tests/test_party.gd", "res://tests/test_combat.gd", "res://tests/test_systems.gd", "res://tests/test_quests.gd", "res://tests/test_audio.gd", "res://tests/test_ui.gd", "res://tests/test_art.gd"]

var failures := 0
var passes := 0

func _initialize() -> void:
	await process_frame
	for path in SUITES:
		var script = load(path)
		if script == null or not script.can_instantiate():
			failures += 1
			print("  FAIL ", path.get_file(), " :: failed to compile")
			continue
		var suite: Object = script.new()
		suite.set("tree", self)
		for m in suite.get_method_list():
			var n: String = m.name
			if not n.begins_with("test_"):
				continue
			suite.set("_fail", "")
			await suite.call(n)
			var err: String = suite.get("_fail")
			if err == "":
				passes += 1
				print("  ok   ", path.get_file(), " :: ", n)
			else:
				failures += 1
				print("  FAIL ", path.get_file(), " :: ", n, " — ", err)
		if suite is Node:
			suite.free()
	print("\n%d passed, %d failed" % [passes, failures])
	quit(1 if failures else 0)
