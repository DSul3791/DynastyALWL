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

	# The sea (Dave 2 Nov 2026): ground under 0 m is under the sea whatever the grid level says.
	var sea: Dictionary = Swim.water_at(-2.0, NAN, -5.0)
	_check(not sea.is_empty() and is_equal_approx(float(sea["surface"]), 0.0), "sea bed at -5 m with no grid water: the surface is the sea at 0")
	_check(Swim.swimming(-2.0, float(sea["surface"]), float(sea["ground"])), "deep sea with the feet under: swimming")
	var odd: Dictionary = Swim.water_at(-2.0, -3.0, -5.0)
	_check(is_equal_approx(float(odd["surface"]), 0.0), "a grid level under 0 m over a sea bed is lifted to the sea")
	_check(not Swim.water_at(-2.0, NAN, NAN).is_empty(), "below 0 m with no collider found: open deep sea")
	_check(Swim.water_at(50.0, NAN, 49.0).is_empty(), "dry land has no water")
	_check(is_equal_approx(float(Swim.water_at(98.0, 100.0, 96.0)["surface"]), 100.0), "an inland lake keeps its own level")

	# Breath: the eyes under water deeper than a ford, and the drain pace against swimming speed.
	_check(Swim.head_under(98.0, 100.0, 96.0), "diving 2 m down in 4 m of water: the head is under")
	_check(not Swim.head_under(Swim.float_centre(100.0), 100.0, 96.0), "floating at the surface: the head is above the water")
	_check(not Swim.head_under(99.2, 100.0, 99.2), "lying in a 0.8 m ford is not head under")
	_check(not Swim.head_under(98.0, NAN, 96.0), "no water, no breath")
	_check(Swim.breath_drain(0.1, 0.5, 0.5, 2.6, 1.6) == 0.5, "resting under water spends the air at half pace")
	_check(Swim.breath_drain(2.0, 0.5, 0.5, 2.6, 1.6) == 1.0, "ordinary swimming spends it at the base pace")
	_check(Swim.breath_drain(3.0, 0.5, 0.5, 2.6, 1.6) == 1.6, "swimming hard spends it faster")

	# Buoyancy: above the float line the body sinks to it (head out) and settles; below it stays put.
	var y: float = 100.0
	var vy: float = 0.0

	for step in range(600):
		vy = Swim.vertical_speed(y, 100.0, vy, false, false, 1.0 / 60.0)
		y += vy / 60.0

	_check(absf(y - Swim.float_centre(100.0)) < 0.05, "a swimmer sinks to head-out depth and stays (centre %.2f, float line %.2f)" % [y, Swim.float_centre(100.0)])
	_check(y + 0.9 > 100.0 and y - 0.9 < 100.0, "floating, the head is above the water and the feet under it")
	y = 97.0
	vy = 0.0

	for step in range(300):
		vy = Swim.vertical_speed(y, 100.0, vy, false, false, 1.0 / 60.0)
		y += vy / 60.0

	_check(absf(y - 97.0) < 0.01, "a diver who stops swimming stays put (no drift up, centre %.2f)" % y)
	# BUG-029: no auto-rise any more; the diver stays down whatever the air (there is no air argument).
	# BUG-028: strokes follow the camera pitch. Looking up while swimming forward rises, looking down dives, level stays level.
	_check(Swim.pitch_wish(0.0, 1.0, 2.0) == 0.0 and Swim.pitch_wish(deg_to_rad(3.0), 1.0, 2.0) == 0.0, "a level look (or under 5 degrees) swims level")
	_check(Swim.pitch_wish(deg_to_rad(45.0), 1.0, 2.0) > 1.3 and Swim.pitch_wish(deg_to_rad(-45.0), 1.0, 2.0) < -1.3, "45 degrees up rises and 45 down dives at the stroke speed times the sine")
	_check(Swim.pitch_wish(deg_to_rad(45.0), -1.0, 2.0) < 0.0 and Swim.pitch_wish(deg_to_rad(45.0), 0.0, 2.0) == 0.0, "backing up (S) reverses it, no stroke gives none")
	y = 97.0
	vy = 0.0

	for step in range(120):
		vy = Swim.vertical_speed(y, 100.0, vy, false, false, 1.0 / 60.0, Swim.pitch_wish(deg_to_rad(60.0), 1.0, 2.0))
		y += vy / 60.0

	_check(y > 98.0 and y <= Swim.float_centre(100.0) + 0.01, "looking up and swimming rises (%.2f) but never above the float line" % y)
	y = Swim.float_centre(100.0)
	vy = 0.0

	for step in range(120):
		vy = Swim.vertical_speed(y, 100.0, vy, false, false, 1.0 / 60.0, Swim.pitch_wish(deg_to_rad(-60.0), 1.0, 2.0))
		y += vy / 60.0

	_check(y < Swim.float_centre(100.0) - 1.5, "looking down and swimming dives (%.2f)" % y)
	y = 97.0
	vy = 0.0

	for step in range(120):
		vy = Swim.vertical_speed(y, 100.0, vy, true, false, 1.0 / 60.0, Swim.pitch_wish(deg_to_rad(-60.0), 1.0, 2.0))
		y += vy / 60.0

	_check(y > 97.0, "Space still swims up whatever the look")
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
