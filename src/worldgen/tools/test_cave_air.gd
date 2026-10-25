extends SceneTree

# Cave air by depth (Steve_cave_air.md): the table, the walked-depth integration, wet from the leak gap. No audio needed.
#   godot --headless --path . --script res://src/worldgen/tools/test_cave_air.gd      Prints "Test done: N pass, N fail".

const Cave := preload("res://src/client/cave_sounds.gd")

var passes: int = 0
var failures: int = 0


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var t: Dictionary = Cave.load_air("res://data/sound/cave_air.json")
	check(not t.is_empty(), "cave_air.json loads")

	# The table: ends, knots and between knots.
	check(is_equal_approx(Cave.air_db(t, "Wind", 0.0), 0.0), "mouth: wind 0 dB")
	check(is_equal_approx(Cave.air_db(t, "Wind", 6.0), -6.0), "6 m in: wind -6 dB")
	check(is_equal_approx(Cave.air_db(t, "Wind", 25.0), -45.0), "25 m in: wind -45 dB")
	check(is_equal_approx(Cave.air_db(t, "Nature", 40.0), -60.0), "40 m in: nature -60 dB (muted)")
	check(is_equal_approx(Cave.air_db(t, "Nature", 99.0), -60.0), "past the table: held at the last row")
	var mid: float = Cave.air_db(t, "Wind", 15.5)
	check(mid < -6.0 and mid > -45.0, "between knots: interpolated (%.1f)" % mid)
	check(Cave.air_lowpass(t, 25.0) == 1800.0 and Cave.air_lowpass(t, 0.0) == 20000.0, "low-pass 20000 at the mouth, 1800 Hz at 25 m")

	# Walking in 25 m, standing, walking out.
	var depth: float = 0.0

	for n in range(25):
		depth = Cave.advance_depth(t, depth, 1.0, 1.0)

	check(is_equal_approx(depth, 25.0) and is_equal_approx(Cave.air_db(t, "Wind", depth), -45.0), "walk 25 m in: depth 25, wind -45 dB (%.1f)" % depth)
	check(Cave.advance_depth(t, depth, 0.0, 1.0) == depth, "standing still deep inside: unchanged")
	check(Cave.advance_depth(t, depth, 1.0, 0.4) == depth, "enclosure between 0.3 and 0.5: held")
	var out: float = depth

	for n in range(8):
		out = Cave.advance_depth(t, out, 1.0, 0.1)

	check(is_equal_approx(out, 1.0), "walk 8 m out in the open: depth falls 3x as fast, 25 -> 1 (%.1f)" % out)
	check(Cave.advance_depth(t, 1.0, 1.0, 0.0) == 0.0, "never below 0")
	check(Cave.advance_depth(t, 3.0, 0.0, 0.0) == 3.0, "standing at the mouth keeps the outside air (depth unchanged)")
	check(is_equal_approx(Cave.advance_depth(t, 0.0, 100.0, 1.0), 40.0), "a teleport into a cave starts deep (cap)")
	check(Cave.advance_depth(t, 30.0, INF, 0.0) == 0.0, "the first scan in the open starts at 0")
	check(is_equal_approx(Cave.advance_depth(t, 39.5, 5.0, 1.0), 40.0), "depth never passes the cap")

	# Wet and dry.
	check(Cave.wet_from_gap(t, 99.0) == 0.0, "no leak message: dry")
	check(Cave.wet_from_gap(t, 4.0) == 0.0, "gap 4 m: dry")
	check(is_equal_approx(Cave.wet_from_gap(t, 0.0), 1.0), "gap 0: fully wet")
	check(is_equal_approx(Cave.wet_from_gap(t, 2.0), 0.5), "gap 2 m: half wet")

	# Drips: a dry cave plays none, a wet one does, open air never.
	check(not Cave.drips_allowed(t, 1.0, 0.0), "dry cave: no drips")
	check(Cave.drips_allowed(t, 1.0, 0.6), "wet cave: drips")
	check(not Cave.drips_allowed(t, 0.2, 1.0), "wet but open air (enclosure 0.2): no drips")
	check(not Cave.drips_allowed(t, 1.0, Cave.wet_from_gap(t, 3.9)), "a gap of 3.9 m is barely wet: below the drip threshold")
	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)
