extends SceneTree

# Stage E readers (docs/water/stage_e_readers_design.md, Steve 7 Nov 2026): the baked distance to perennial fresh water (water_record.gd), its
# tile file encoding, and the animals' near_fresh_water_m habitat reading it before the live water probe.
#   godot --headless --path . --script res://src/worldgen/tools/test_water_record.gd

const WaterRecordScript := preload("res://src/worldgen/record/water_record.gd")
const AnimalsScript := preload("res://src/stream/server_animals.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	# A 20 x 20 frame of 8 m cells: a river down column 5, a lake cell at (15, 15), the sea (class 1) along row 0, which is not fresh water.
	var n: int = 20
	var wc: PackedByteArray = PackedByteArray()
	wc.resize(n * n)

	for j in n:
		wc[j * n + 5] = WaterRecordScript.RIVER

	for i in n:
		wc[i] = 1

	wc[15 * n + 15] = WaterRecordScript.LAKE
	var d: PackedFloat32Array = WaterRecordScript.fresh_distance(wc, n, 8.0)
	check(d[10 * n + 5] == 0.0 and d[15 * n + 15] == 0.0, "river and lake cells are 0 m from fresh water")
	check(is_equal_approx(d[10 * n + 8], 24.0), "three cells beside the river is 24 m (%.1f)" % d[10 * n + 8])
	check(is_equal_approx(d[13 * n + 13], 16.0 * sqrt(2.0)), "two diagonal cells from the lake is 22.6 m (%.1f)" % d[13 * n + 13])
	check(d[0 * n + 12] > 50.0, "the sea is not fresh water (%.1f m at the shore far from the river)" % d[0 * n + 12])
	var round_trip: PackedFloat32Array = WaterRecordScript.decode_fresh(WaterRecordScript.encode_fresh(PackedFloat32Array([0.0, 23.0, 509.0, 2000.0, INF])))
	check(round_trip[0] == 0.0 and absf(round_trip[1] - 23.0) <= 1.0 and absf(round_trip[2] - 509.0) <= 1.0, "fresh_m keeps 2 m steps")
	check(is_inf(round_trip[3]) and is_inf(round_trip[4]), "beyond 510 m reads as far (INF)")

	# The habitat: the baked distance decides when the tile has it; NAN falls back to the live probe; no source at all keeps the old no-rule.
	var a = AnimalsScript.new()
	a.fresh_water_m = func(x, _z): return 10.0 if x < 100.0 else 200.0
	a.water_level = func(_x, _z): return 5.0   # live water everywhere: must not be used while the baked distance answers
	check(a._fresh_near(50.0, 0.0, 30.0) and not a._fresh_near(150.0, 0.0, 30.0), "the baked distance decides near fresh water")
	a.fresh_water_m = func(_x, _z): return NAN
	check(a._fresh_near(150.0, 0.0, 30.0), "a tile baked before fresh_m falls back to the live water probe")
	a.fresh_water_m = Callable()
	a.water_level = Callable()
	check(a._fresh_near(150.0, 0.0, 30.0), "with no water source at all there is no rule (as before)")

	print("water record tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
