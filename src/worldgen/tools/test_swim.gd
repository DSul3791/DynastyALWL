extends SceneTree

# Swimming rules (src/shared/swim.gd): when a player swims, where they float, how water slows a
# wader, and what a swimmer costs in effort.
#   godot --headless --path . --script res://src/worldgen/tools/test_swim.gd

const Swim := preload("res://src/shared/swim.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	# A lake 4 m deep: surface 100, ground 96.
	_check(not Swim.swimming(97.0, 100.0, 99.0), "a shallow wade (1 m) is not swimming")
	_check(Swim.swimming(98.0, 100.0, 96.0), "deep water with the feet under the surface is swimming")
	_check(not Swim.swimming(100.9, 100.0, 96.0), "standing on ice at the surface of deep water is not swimming")
	_check(not Swim.swimming(98.0, NAN, 96.0), "no water, no swimming")

	# Buoyancy: below the float line the body rises, above it sinks, and it settles at the line.
	var y: float = 97.5
	var vy: float = 0.0

	for step in range(600):
		vy = Swim.vertical_speed(y, 100.0, vy, false, false, 1.0 / 60.0)
		y += vy / 60.0

	_check(absf(y - Swim.float_centre(100.0)) < 0.05, "a swimmer floats up to the surface and stays (centre %.2f, float line %.2f)" % [y, Swim.float_centre(100.0)])
	_check(y + 0.9 > 100.0 and y - 0.9 < 100.0, "floating, the head is above the water and the feet under it")
	vy = 0.0
	y = Swim.float_centre(100.0)

	for step in range(60):
		vy = Swim.vertical_speed(y, 100.0, vy, false, true, 1.0 / 60.0)
		y += vy / 60.0

	_check(y < Swim.float_centre(100.0) - 1.0, "Ctrl dives (%.2f m down in a second)" % (Swim.float_centre(100.0) - y))
	_check(Swim.wade_factor(0.1) == 1.0 and Swim.wade_factor(Swim.SWIM_DEPTH_M) == Swim.WADE_MIN and Swim.wade_factor(0.8) < 1.0, "water slows a wader down to %.0f percent at chest depth" % (Swim.WADE_MIN * 100.0))
	_check(Swim.pace(false) < 6.0 and Swim.pace(true) > Swim.pace(false), "swimming is slower than walking, hard swimming faster")

	# Effort: walking is 0.5, rest 0.52 (exertion.json): a steady swim is work, hard swimming more.
	_check(Swim.effort(0.0) > 0.52 and Swim.effort(2.0) > Swim.effort(0.0) and Swim.effort(3.0) > Swim.effort(2.0), "treading water, swimming and swimming hard cost more and more")
	print("swim: %d failures" % failures)
	quit(1 if failures > 0 else 0)
