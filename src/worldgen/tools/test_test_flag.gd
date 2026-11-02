extends SceneTree

# The --test launch flag (Dave, 2 Nov 2026): it skips the character select and creator pages. This pins the flag reader and that the launcher asks it.
#   godot --headless --path . --script res://src/worldgen/tools/test_test_flag.gd

const AppConfigScript := preload("res://src/shared/app_config.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	check(AppConfigScript.has_flag("test", PackedStringArray(["--role=play", "--test"])), "--test is found")
	check(not AppConfigScript.has_flag("test", PackedStringArray(["--role=play"])), "no --test: not found")
	check(not AppConfigScript.has_flag("test", PackedStringArray(["--testing", "--test=1", "test"])), "similar words are not the flag")
	check(not AppConfigScript.has_flag("test"), "the real command line of this run has no --test")
	var launcher: String = FileAccess.get_file_as_string("res://scenes/launcher.gd")
	check(launcher.contains("AppConfig.has_flag(\"test\")"), "the launcher's play role checks --test before the character pages")
	print("Test done: %d fail" % failures)
	quit(1 if failures > 0 else 0)
