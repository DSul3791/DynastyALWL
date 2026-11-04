extends SceneTree

# BUG-011 (Dave 2026-11-04): running is 9 m/s (+50 percent), the run animation and the stride rate stay as they were at 6 m/s,
# and the server's effort anchors move with the speed. Run: godot --headless --path . --script res://src/worldgen/tools/test_run_speed.gd

const AvatarDriver := preload("res://src/client/character/avatar_driver.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var consts: Dictionary = load("res://scenes/terrain_client/terrain_client.gd").get_script_constant_map()
	var run: float = float(consts["RUN_SPEED"])
	_check(is_equal_approx(run, 9.0), "RUN_SPEED is 9 m/s (%.1f)" % run)
	_check(is_equal_approx(float(consts["WALK_SPEED"]), 1.4) and is_equal_approx(float(consts["JOG_SPEED"]), 3.2), "walk and jog are unchanged")

	# The animation plays at the 6 m/s rate whatever the faster pace.
	_check(is_equal_approx(AvatarDriver.speed_scale("run", run), 1.0), "running at 9 m/s plays the run clip at 1.0x")
	_check(is_equal_approx(AvatarDriver.speed_scale("run", 6.0), 1.0), "running at 6 m/s plays the run clip at 1.0x")
	_check(AvatarDriver.speed_scale("run", 4.8) < 1.0 and AvatarDriver.speed_scale("run", 4.8) >= 0.8, "a slowed runner still plays it slower")

	# Footfalls per second at the run (pace / metres per step) are the old 3 a second.
	var step_m: float = float(consts["STEP_M"][2])
	_check(absf(run / step_m - 3.0) < 0.001, "run cadence is 3 steps a second (%.2f)" % (run / step_m))

	# The server's effort curve ends at the same speed.
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/exertion.json"))
	var anchors: Array = cfg["effort_by_speed"]
	_check(is_equal_approx(float(anchors[anchors.size() - 1][0]), run) and is_equal_approx(float(anchors[anchors.size() - 1][1]), 1.0), "effort 1.0 at the run speed in exertion.json")
	_check(is_equal_approx(float(anchors[1][0]), float(consts["WALK_SPEED"])) and is_equal_approx(float(anchors[2][0]), float(consts["JOG_SPEED"])), "walk and jog anchors match the speeds")
	print("run speed: %d failures" % failures)
	quit(1 if failures > 0 else 0)
