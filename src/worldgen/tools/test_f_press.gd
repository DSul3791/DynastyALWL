extends SceneTree

# The F key (Dave: F twice puts the carried log down): the decision is pure, so the 0.6 s window is checked here without a client.
#   godot --headless --path . --script res://src/worldgen/tools/test_f_press.gd

const FPress := preload("res://src/client/f_press.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	check(FPress.decide(false, false, 1000, -1) == "open", "no log: F opens what is near, as before")
	check(FPress.decide(false, true, 1000, -1) == "open", "no log, a chest near: F opens it")
	check(FPress.decide(true, true, 1000, -1) == "open", "a log on the shoulder and a chest in reach: F still opens the chest")
	check(FPress.decide(true, true, 1000, 900) == "open", "a chest in reach never drops the log, even on a quick second F")
	check(FPress.decide(true, false, 1000, -100000) == "hint", "a log and nothing to open: the first F gives the hint")
	check(FPress.decide(true, false, 1400, 1000) == "drop", "a second F 0.4 s later puts the log down")
	check(FPress.decide(true, false, 1600, 1000) == "drop", "a second F exactly 0.6 s later still puts the log down")
	check(FPress.decide(true, false, 1601, 1000) == "hint", "a second F 0.601 s later is a new first F (hint again)")
	check(FPress.decide(true, false, 5000, 1000) == "hint", "a second F 4 s later is a new first F")
	check(FPress.decide(true, false, 1000, 1000, 1000) == "drop", "the window is a parameter (1 s)")
	check(FPress.WINDOW_MS == 600, "the default window is 0.6 s")
	print("f press tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
