extends SceneTree

# The Camera motion slider (Esc > Settings > Gameplay, BACKLOG rank 5): set_intensity clamps to 0..1.5, takes effect at once and is
# saved under [feel] intensity (feel_kicks.gd _init reads it on the next run); at 0 the springs move nothing.
#   godot --headless --path . --script res://src/worldgen/tools/test_feel_intensity.gd

const FeelKicks := preload("res://src/client/feel_kicks.gd")
const PATH := "user://test_feel_intensity.cfg"

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	var feel = FeelKicks.new()
	feel.set_intensity(2.0, PATH)
	check(is_equal_approx(feel.intensity, 1.5), "intensity is capped at 1.5 (%.2f)" % feel.intensity)
	feel.set_intensity(-1.0, PATH)
	check(feel.intensity == 0.0, "intensity does not go below 0")
	feel.land(9.0)
	var moved: Dictionary = feel.step(0.016)
	check(float(moved["y"]) == 0.0 and float(moved["roll"]) == 0.0, "at 0 a landing moves the eye not at all")
	feel.set_intensity(0.6, PATH)
	var file: ConfigFile = ConfigFile.new()
	check(file.load(PATH) == OK and is_equal_approx(float(file.get_value("feel", "intensity", -1.0)), 0.6), "the value is saved under [feel] intensity")
	check(FileAccess.get_file_as_string("res://src/client/game_menu.gd").contains("\"Camera motion\""), "Gameplay settings have the Camera motion slider")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("feel intensity: %d failures" % failures)
	quit(1 if failures > 0 else 0)
