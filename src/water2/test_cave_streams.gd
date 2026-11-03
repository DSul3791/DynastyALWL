extends SceneTree

# Spring cave streams (Sonny, 3 Nov 2026; written without being run): a spring cave's "water" segments become stream pieces on the passage floor,
# upper end first, and its spring a pool in the bottom of its chamber; the mesh has a ribbon per piece and a fan per pool.
#   godot --headless --path . --script res://src/water2/test_cave_streams.gd

const DataScript := preload("res://src/worldgen/runtime/tile_terrain_data.gd")
const CaveStreams := preload("res://src/water2/cave_streams.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	# Mouth at y 11 (floor 10), two pieces rising into the hill, the spring at node 2 in a chamber 5 m tall; a karst cave with a "water" segment too.
	var spring_cave: Dictionary = {
		"cave_kind": "spring_cave",
		"nodes": [[0.0, 11.0, 0.0, 4.0, 2.0], [8.0, 11.4, 0.0, 4.0, 2.0], [16.0, 11.8, 0.0, 4.0, 2.0]],
		"segments": [[0, 1, "water"], [1, 2, "water"]],
		"chambers": [{"node": 2, "radius_m": 5.0, "height_m": 5.0, "features": ["spring"]}],
		"springs": [{"node": 2, "m3_s": 0.01}],
	}
	var karst: Dictionary = {
		"cave_kind": "karst", "nodes": [[100.0, 0.0, 0.0, 3.0, 3.0], [110.0, -1.0, 0.0, 3.0, 3.0]], "segments": [[0, 1, "water"]], "chambers": [],
	}
	var data = DataScript.new()
	data._load_caves([spring_cave, karst])
	var s: PackedFloat32Array = data.cave_streams
	_check(s.size() == 21, "two stream pieces and one pool from the spring cave, nothing from the karst cave (%d floats)" % s.size())

	if s.size() == 21:
		_check(is_equal_approx(s[0], 8.0) and is_equal_approx(s[1], 10.4) and is_equal_approx(s[3], 0.0) and is_equal_approx(s[4], 10.0),
			"a piece is stored upper end first, at floor height (%s)" % str(s.slice(0, 7)))
		_check(s[13] < 0.0 and s[13] > -5.0 and is_equal_approx(s[15], 11.8 - 2.5 + DataScript.CAVE_POOL_M),
			"the spring's pool lies in the bottom of its chamber, narrower than the chamber (%s)" % str(s.slice(14, 21)))

	var mesh: ArrayMesh = CaveStreams.build_mesh(s)
	_check(mesh != null and mesh.surface_get_array_len(0) == 2 * 6 + CaveStreams.POOL_SIDES * 3, "the mesh has a ribbon per piece and a fan per pool")
	_check(CaveStreams.build_mesh(PackedFloat32Array()) == null, "no streams, no mesh")
	print("cave streams: %d failures" % failures)
	quit(1 if failures > 0 else 0)
