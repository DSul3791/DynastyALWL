extends SceneTree

# Spring cave water sounds (cave_water_sounds.gd): the list parsing, the nearest point on the stream, and the flow rule (springs add: +3 dB per doubling).
#   godot --headless --path . --script res://src/worldgen/tools/test_cave_water_sounds.gd

const CaveWater := preload("res://src/client/cave_water_sounds.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	# Two stream pieces down a passage along +x (upper end first, falling) and one pool at the top.
	var floats: PackedFloat32Array = PackedFloat32Array([
		0, 10, 0, 20, 8, 0, 3.0,
		20, 8, 0, 40, 6, 0, 3.0,
		0, 10, 0, 0, 0, 0, -2.5,
	])
	var pieces: Array = []
	var pools: Array = []
	CaveWater.parse(floats, pieces, pools)
	check(pieces.size() == 2 and pools.size() == 1, "two stream pieces and one pool (%d, %d)" % [pieces.size(), pools.size()])
	check(is_equal_approx(float(pools[0][1]), 2.5) and pools[0][0] == Vector3(0, 10, 0), "the pool keeps its centre and a positive radius")
	var hit: Dictionary = CaveWater.nearest_stream(pieces, Vector3(25.0, 8.0, 4.0))
	check(absf(float(hit["distance"]) - 4.0) < 0.01 and absf(hit["point"].x - 25.0) < 0.01, "the nearest stream point is straight across the passage (%.2f m)" % float(hit["distance"]))
	hit = CaveWater.nearest_stream(pieces, Vector3(-10.0, 10.0, 0.0))
	check(absf(float(hit["distance"]) - 10.0) < 0.01, "before the upper end it clamps to the end (10 m)")
	check(is_inf(float(CaveWater.nearest_stream([], Vector3.ZERO)["distance"])), "no streams: infinite distance")
	check(CaveWater.flow_db(1) == 0.0 and absf(CaveWater.flow_db(2) - 3.0) < 0.01 and absf(CaveWater.flow_db(4) - 6.0) < 0.01 and CaveWater.flow_db(0) == 0.0, "springs add: 0, +3, +6 dB for 1, 2, 4")
	var empty: Array = []
	var empty_pools: Array = []
	CaveWater.parse(PackedFloat32Array([1, 2, 3]), empty, empty_pools)
	check(empty.is_empty() and empty_pools.is_empty(), "a short list parses to nothing")
	print("cave water sounds: %d failures" % failures)
	quit(1 if failures > 0 else 0)
