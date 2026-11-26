extends SceneTree

# BUG-011 (Dave 2026-11-04): running is 9 m/s (+50 percent), and the server's effort anchors move with the speed. R-MOVE-RUN-FEET (Dave 26 Nov 2026):
# the run clip plays faster to keep up with the 9 m/s, so the planted foot stays put, and the footsteps and the camera bob follow its steps.
# Run: godot --headless --path . --script res://src/worldgen/tools/test_run_speed.gd

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
	_check(is_equal_approx(float(consts["WALK_SPEED"]), 3.2) and not consts.has("JOG_SPEED"), "two gaits (Dave 10 Nov 2026): the walk is the old 3.2 m/s jog, no jog")
	_check(is_equal_approx(float(consts["WALK_SPEED"]) * float(load("res://src/client/stance.gd").get_script_constant_map()["SPEED"][1]), 0.64), "crouching stays about 0.64 m/s")

	# The run clip is retimed to 6 m/s (dynasty_body.gd CLIP_MAP); faster it plays faster in step, so the feet do not slide.
	_check(is_equal_approx(AvatarDriver.speed_scale("run", run), run / 6.0), "running at 9 m/s plays the run clip at 1.5x (%.2f)" % AvatarDriver.speed_scale("run", run))
	_check(is_equal_approx(AvatarDriver.speed_scale("run", 6.0), 1.0), "running at 6 m/s plays the run clip at 1.0x")
	_check(AvatarDriver.speed_scale("run", 4.8) < 1.0 and AvatarDriver.speed_scale("run", 4.8) >= 0.8, "a slowed runner still plays it slower")

	# Footsteps follow the feet: the run clip (RunFast, one stride of two steps in 0.467 s, retimed 1.22) steps 1.71 m at any speed it keeps up with.
	var body_map: Dictionary = load("res://src/client/character/dynasty_body.gd").get_script_constant_map()["CLIP_MAP"]
	var clip_step_m: float = 6.0 * 0.4667 * float(body_map["run"][4]) / 2.0
	var step_m: float = float(consts["STEP_M"][1])
	_check(absf(step_m - clip_step_m) < 0.05, "the run's footstep length is the clip's own step (%.2f m, clip %.2f m)" % [step_m, clip_step_m])
	_check(absf(run / step_m - run / clip_step_m) < 0.2, "run cadence follows the feet: %.1f steps a second" % (run / step_m))
	var view_step: float = float(load("res://src/client/player_view.gd").get_script_constant_map()["STEP_M"][1])
	_check(is_equal_approx(view_step, step_m), "other players' run footsteps use the same step (%.2f m)" % view_step)

	# The server's effort curve ends at the same speed.
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/exertion.json"))
	var anchors: Array = cfg["effort_by_speed"]
	_check(is_equal_approx(float(anchors[anchors.size() - 1][0]), run) and is_equal_approx(float(anchors[anchors.size() - 1][1]), 1.0), "effort 1.0 at the run speed in exertion.json")
	_check(is_equal_approx(float(anchors[1][0]), float(consts["WALK_SPEED"])) and float(anchors[1][1]) < float(cfg["rest_effort"]), "the walk anchor is at the walking speed and under rest_effort, so walking stays restful")
	_check(anchors.size() == 3, "three anchors: still, walk, run")
	print("run speed: %d failures" % failures)
	quit(1 if failures > 0 else 0)
