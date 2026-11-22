extends SceneTree

# A drawn animal's legs keep up with the ground (src/client/animal_gait.gd; Dave 21 Nov 2026: animals "shouldn't be teleporting around or
# running without moving their feet or legs"): the speed is eased, the clip changes only past a margin, a failed clip-speed measurement
# is not trusted, the rate reaches past twice the clip's speed, and a model with one moving clip plays it while it moves.
#   godot --headless --path . --script res://src/worldgen/tools/test_animal_gait.gd

const AnimalGait := preload("res://src/client/animal_gait.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	failures += 0 if ok else 1


func _init() -> void:
	# Eased speed: a run at 10 m/s drawn with one frame of nothing (a late send) and one of double does not drop to a stand or jump to a sprint.
	var spd: float = 10.0
	var low: float = INF
	var high: float = 0.0

	for raw in [10.0, 0.0, 20.0, 10.0, 10.0, 0.0, 10.0]:
		spd = AnimalGait.smooth(spd, raw, 1.0 / 60.0)
		low = minf(low, spd)
		high = maxf(high, spd)

	check(low > 8.0 and high < 12.0, "a 10 m/s run through a late send and a double step stays 8 to 12 m/s (%.2f to %.2f)" % [low, high])
	check(AnimalGait.smooth(3.0, 500.0, 1.0 / 60.0) == 3.0, "a body put somewhere at once is not a speed")
	var start: float = 0.0

	for i in 30:
		start = AnimalGait.smooth(start, 2.0, 1.0 / 60.0)

	check(absf(start - 2.0) < 0.1, "half a second walking: the eased speed has caught up (%.2f)" % start)

	# Margins: no flicker at the edges.
	check(AnimalGait.role(0.35, "", 1.4, 10.0) == "", "standing: 0.35 m/s does not start the walk")
	check(AnimalGait.role(0.35, "walk", 1.4, 10.0) == "walk", "walking: 0.35 m/s keeps the walk")
	check(AnimalGait.role(0.2, "walk", 1.4, 10.0) == "", "walking: below 0.25 m/s it stands")
	check(AnimalGait.role(6.0, "walk", 1.4, 10.0) == "walk" and AnimalGait.role(6.0, "run", 1.4, 10.0) == "run", "at half way (5.7) the clip it has stays")
	check(AnimalGait.role(6.5, "walk", 1.4, 10.0) == "run" and AnimalGait.role(5.0, "run", 1.4, 10.0) == "walk", "well past half way it changes")

	# Rate: past twice the clip's speed, and slow ambles still move the legs.
	check(absf(AnimalGait.rate(12.0, 5.0) - 2.4) < 0.001, "a 12 m/s flight on a 5 m/s run clip plays at 2.4, not 2")
	check(AnimalGait.rate(0.1, 1.5) == AnimalGait.RATE_MIN and AnimalGait.rate(3.0, 0.0) == 1.0, "slowest rate held; no reference plays at 1")

	# Measured clip speeds against the row's speed (Dave's log, 21 Nov 2026).
	check(not AnimalGait.stride_ok(0.26, 1.3), "the lynx walk measured 0.26 m/s against 1.3 is not trusted")
	check(not AnimalGait.stride_ok(0.20, 6.0), "the guineafowl run measured 0.20 m/s against 6 is not trusted")
	check(AnimalGait.stride_ok(12.84, 9.0) and AnimalGait.stride_ok(0.63, 1.4), "the moose run 12.84 against 9 and the deer walk 0.63 against 1.4 are")
	check(AnimalGait.stride_ok(1.0, 0.0) and not AnimalGait.stride_ok(0.0, 1.0), "no row speed: trusted; nothing measured: not")

	# A model with one moving clip plays it.
	check(AnimalGait.moving_clip({"0": "Idle", "walk": "Walk"}, "run") == "Walk", "no run clip: the walk plays while it runs")
	check(AnimalGait.moving_clip({"0": "Idle", "run": "Run"}, "walk") == "Run", "no walk clip: the run plays while it walks")
	check(AnimalGait.moving_clip({"0": "Idle", "walk": "W", "run": "R"}, "run") == "R", "both: its own")
	check(AnimalGait.moving_clip({"0": "Idle"}, "walk") == "Idle", "neither: the standing clip")

	print("animal gait: %d failures" % failures)
	quit(1 if failures > 0 else 0)
