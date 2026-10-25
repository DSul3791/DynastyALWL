extends SceneTree

# Inner voice settings (Esc > Settings > Inner voice): classes, the two switches, defaults, save and load.
#   godot --headless --path . --script res://src/worldgen/tools/test_inner_voice_settings.gd      Prints "Test done: N pass, N fail".

const Settings := preload("res://src/client/inner_voice_settings.gd")
const TEMP := "user://test_inner_voice.cfg"

var passes: int = 0
var failures: int = 0


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP))
	var s = Settings.new(TEMP)
	check(s.hints and s.dialogue, "both switches default on when the file is missing")
	check(s.class_of("vomit") == "dialogue" and s.class_of("diarrhea") == "dialogue", "sickness jokes are dialogue")
	check(s.class_of("hint") == "hint" and s.class_of("hint_stick") == "hint", "the hint kind and hint_ names are hints")
	check(s.class_of("something_new") == "dialogue", "an unknown kind counts as dialogue")
	check(s.allows("vomit") and s.allows("hint_stick"), "all lines allowed by default")

	s.set_hints(false)
	check(not s.allows("hint_stick") and s.allows("vomit"), "hints off blocks only hints")
	s.set_hints(true)
	s.set_dialogue(false)
	check(s.allows("hint_stick") and not s.allows("vomit") and not s.allows("diarrhea") and not s.allows("something_new"), "dialogue off blocks only dialogue")
	s.set_hints(false)
	check(not s.allows("hint_stick") and not s.allows("vomit"), "both off blocks everything")

	var again = Settings.new(TEMP)
	check(not again.hints and not again.dialogue, "the choices are loaded back from the file")
	again.set_hints(true)
	check(Settings.new(TEMP).hints and not Settings.new(TEMP).dialogue, "a changed switch is saved on its own")

	var broken = Settings.new(TEMP, "res://data/items/does_not_exist.json")
	check(broken.class_of("vomit") == "dialogue" and broken.class_of("hint_x") == "hint", "a missing classes file still sorts by the hint_ prefix")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP))
	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)
