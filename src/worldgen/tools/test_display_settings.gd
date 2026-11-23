extends SceneTree

# The window mode carries through joining (Dave 23 Nov 2026: fullscreen before joining, and the join shrank the window): apply(window, true)
# keeps a fullscreen or maximised window and saves fullscreen as the choice; the Settings switch (keep_current false) still makes a window.
#   godot --headless --path . --script res://src/worldgen/tools/test_display_settings.gd

const DisplaySettingsScript := preload("res://src/client/display_settings.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	var keep: Callable = DisplaySettingsScript.keep_mode
	check(keep.call(Window.MODE_FULLSCREEN, false) == Window.MODE_FULLSCREEN and keep.call(Window.MODE_EXCLUSIVE_FULLSCREEN, false) == Window.MODE_FULLSCREEN, "a fullscreen window stays fullscreen through a join, either kind")
	check(keep.call(Window.MODE_MAXIMIZED, false) == Window.MODE_MAXIMIZED, "a maximised window stays maximised when the choice is windowed")
	check(keep.call(Window.MODE_MAXIMIZED, true) == -1, "a maximised window goes fullscreen when that is the saved choice")
	check(keep.call(Window.MODE_WINDOWED, false) == -1 and keep.call(Window.MODE_WINDOWED, true) == -1, "a plain window takes the saved choice")
	var src: String = FileAccess.get_file_as_string("res://scenes/terrain_client/terrain_client.gd")
	check(src.contains("display.apply(get_window(), true)"), "joining a world keeps the player's window mode")
	check(not FileAccess.get_file_as_string("res://src/client/game_menu.gd").contains("apply(_c.get_window(), true)"), "the Settings switches still set the window as chosen")
	print("display settings: %d failures" % failures)
	quit(1 if failures > 0 else 0)
