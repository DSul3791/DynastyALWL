extends SceneTree

# The trees' wind loops speak in gusts (SOUND_AUDIT.md, 31 Oct 2026: the steady band noise at any wind read as rain): silent in a light breeze, swelling smoothly with the wind, with a slow
# flutter of a few dB, and quieter than before. Pure functions of tree_wind.gd.
#   godot --headless --path . --script res://src/worldgen/tools/test_tree_wind.gd

const TreeWind := preload("res://src/client/tree_wind.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	check(TreeWind.gust_factor(0.0) == 0.0 and TreeWind.gust_factor(0.25) == 0.0, "no wind and a light breeze (0.25): silent")
	check(TreeWind.gust_factor(0.5) > 0.0 and TreeWind.gust_factor(0.5) < TreeWind.gust_factor(0.8) and TreeWind.gust_factor(0.8) < TreeWind.gust_factor(1.0), "the factor rises with the wind")
	check(absf(TreeWind.gust_factor(1.0) - 1.0) < 0.001 and TreeWind.gust_factor(1.5) > 1.0, "full at wind 1.0, a little more in a gale")
	var low: float = 1000.0
	var high: float = -1000.0

	for t in range(0, 240):
		var v: float = TreeWind.flutter_db(float(t) * 0.25, 1.0, "leaves")
		low = minf(low, v)
		high = maxf(high, v)

	check(high - low > 4.0 and high <= TreeWind.FLUTTER_DB and low >= -TreeWind.FLUTTER_DB, "the level swells and flutters by %.1f dB peak to peak, within +/-%.0f dB" % [high - low, TreeWind.FLUTTER_DB])
	check(absf(TreeWind.flutter_db(10.0, 0.0, "pine")) < absf(TreeWind.FLUTTER_DB) * 0.5, "and flutters less in a weak wind")
	check(TreeWind.BASE_DB <= -28.0, "the loops are quieter than the old -24 dB (now %.0f dB for a full stand in a full wind)" % TreeWind.BASE_DB)
	print("tree wind: %d failures" % failures)
	quit(1 if failures > 0 else 0)
