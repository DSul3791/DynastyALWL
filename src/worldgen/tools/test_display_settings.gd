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
	# Client bug hunt 23 Nov 2026: the 1920x1080 default window hung off a 1366x768 screen (the supported floor).
	var fit: Callable = DisplaySettingsScript.fit_window
	check(fit.call(Vector2i(1920, 1080), Vector2i(1366, 728)) == Vector2i(1294, 728), "1920x1080 on a 1366x768 screen (taskbar 40 px) shrinks to the biggest 16:9 that fits (got %s)" % str(fit.call(Vector2i(1920, 1080), Vector2i(1366, 728))))
	check(fit.call(Vector2i(1920, 1080), Vector2i(2560, 1400)) == Vector2i(1920, 1080), "a window that fits keeps its chosen size")
	check(fit.call(Vector2i(1600, 900), Vector2i(3440, 1400)) == Vector2i(1600, 900), "an ultrawide screen keeps the chosen size")
	check(fit.call(Vector2i(1920, 1080), Vector2i.ZERO) == Vector2i(1920, 1080), "no screen size known: the chosen size")
	# Mouse sensitivity is saved, read back and kept in range.
	var temp: String = "user://test_display_settings.cfg"
	var a = DisplaySettingsScript.new()
	a.path = temp
	a.mouse_look = 1.75
	a.save()
	var b = DisplaySettingsScript.new()
	b.path = temp
	b.load_saved()
	check(absf(b.mouse_look - 1.75) < 0.001, "mouse sensitivity survives a restart (got %.2f)" % b.mouse_look)
	a.mouse_look = 0.0
	a.save()
	b.load_saved()
	check(b.mouse_look >= DisplaySettingsScript.MOUSE_LOOK_MIN, "a mouse sensitivity of 0 is never saved: the view would not turn")
	check(src.contains("MOUSE_SENSITIVITY * display.mouse_look"), "the mouse look uses the saved sensitivity")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
	print("display settings: %d failures" % failures)
	quit(1 if failures > 0 else 0)
