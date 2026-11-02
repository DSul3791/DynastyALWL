extends SceneTree

# Temperature readout (Dave 2 Nov 2026): warmth percent shown as body temperature, switchable C/F in Esc > Settings > Gameplay, saved.
#   godot --headless --path . --script res://src/worldgen/tools/test_temperature.gd

const DisplayScript := preload("res://src/client/display_settings.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	DisplayScript.fahrenheit = false
	check(absf(DisplayScript.body_temp_c(100.0) - 37.0) < 0.001 and absf(DisplayScript.body_temp_c(0.0) - 28.0) < 0.001, "100% warmth is 37 C, 0% is 28 C")
	check(DisplayScript.temp_text(100.0) == "37.0 °C", "Celsius text")
	DisplayScript.fahrenheit = true
	check(DisplayScript.temp_text(100.0) == "98.6 °F", "Fahrenheit text (37 C is 98.6 F)")
	var settings = DisplayScript.new()
	settings.path = "user://test_temperature_display.cfg"
	settings.save()
	DisplayScript.fahrenheit = false
	var back = DisplayScript.new()
	back.path = "user://test_temperature_display.cfg"
	back.load_saved()
	check(DisplayScript.fahrenheit, "the C/F choice persists in the settings file")
	DisplayScript.fahrenheit = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_temperature_display.cfg"))
	print("temperature: %d failures" % failures)
	quit(1 if failures > 0 else 0)
