extends SceneTree

# Which ore a boulder is an outcrop of (TileTerrainData.ore_at; Jamie's tin check, 10 Nov 2026): the nearest compact body (lens, halo, pipe, vein, placer)
# within reach comes before any layer; a layer or scatter body counts only in its own province and only where one of its bands nears the bedrock
# surface; bodies of ores boulders do not carry (gems, flint) never hide the rest. Before, the first body whose box held the spot won, and a layer's
# box is the whole tile, so every outcrop near spawn was coal.
#   godot --headless --path . --script res://src/worldgen/tools/test_ore_near.gd

const TileDataScript := preload("res://src/worldgen/runtime/tile_terrain_data.gd")

const NAMES := {"coal": "coal", "copper": "copper_ore", "tin": "tin_ore", "iron": "iron_ore"}

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	# A 2 km tile in two provinces: x under 500 m is p0, the rest p1; both with their top at 100 m, no cover.
	var data = TileDataScript.new()
	data.samples = 3
	data.spacing_m = 1000.0
	data.province = PackedByteArray([0, 1, 1, 0, 1, 1, 0, 1, 1])
	data.prov_datum = PackedFloat32Array([100.0, 100.0])
	data.layer_offset = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0])
	data.cover = PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0])
	data.prov_index_of = {"p0": 0, "p1": 1}
	# Listed as a bake lists them: the layer and the gem first, so taking the first box that holds the spot gives the wrong answer.
	data._load_ores([
		{"shape": "layer", "resource": "coal", "province": "p1", "depth_below_datum_m": 5.0, "cycle_m": 100.0, "thickness_m": 2.0, "repeat_to_m": 1000.0},
		{"shape": "scatter", "resource": "flint", "province": "p0", "depth_below_datum_m": 0.0, "cycle_m": 50.0, "thickness_m": 10.0, "repeat_to_m": 1000.0, "density": 0.1},
		{"shape": "lens", "resource": "ruby", "center": [1500.0, 90.0, 1500.0], "radius_a_m": 60.0, "radius_b_m": 40.0, "thickness_m": 4.0},
		{"shape": "lens", "resource": "tin", "center": [1500.0, 90.0, 1500.0], "radius_a_m": 50.0, "radius_b_m": 30.0, "thickness_m": 4.0},
		{"shape": "pipe", "resource": "copper", "center": [1700.0, 1500.0], "radius_m": 20.0, "top_y": 95.0, "bottom_y": 0.0},
	], {"coal": 1, "flint": 2, "ruby": 3, "tin": 4, "copper": 5}, {})
	check(data.ores.size() == 5, "all five bodies load (%d)" % data.ores.size())

	check(data.ore_at(Vector3(1520.0, 100.0, 1500.0), 40.0, NAMES, 10.0) == "tin", "a boulder over the tin lens is tin, not the coal seam listed first or the ruby lens that boulders do not carry")
	check(data.ore_at(Vector3(1700.0, 100.0, 1510.0), 40.0, NAMES, 10.0) == "copper", "over the copper pipe it is copper")
	check(data.ore_at(Vector3(1600.0, 100.0, 1500.0), 100.0, NAMES, 10.0) == "tin", "with both in reach the nearer body wins: tin 50 m away before copper 80 m")
	check(data.ore_at(Vector3(1650.0, 100.0, 1500.0), 100.0, NAMES, 10.0) == "copper", "and copper 30 m away before tin 100 m")
	check(data.ore_at(Vector3(1610.0, 100.0, 1500.0), 40.0, NAMES, 10.0) == "coal", "away from both, in the coal province, a seam 5 m under the ground shows as coal")
	check(data.ore_at(Vector3(1610.0, 94.0, 1500.0), 40.0, NAMES, 10.0) == "coal", "where the ground cuts the seam it is coal too")
	check(data.ore_at(Vector3(1610.0, 140.0, 1500.0), 40.0, NAMES, 10.0) == "", "on a hill with the seam 45 m down there is no coal")
	check(data.ore_at(Vector3(1610.0, 80.0, 1500.0), 40.0, NAMES, 10.0) == "", "in a valley cut below the seam, with the next band 25 m further down, there is none")
	check(data.ore_at(Vector3(1610.0, 0.0, 1500.0), 40.0, NAMES, 10.0) == "coal", "deeper down the next band shows again")
	check(data.ore_at(Vector3(200.0, 100.0, 1500.0), 40.0, NAMES, 10.0) == "", "in the other province the coal seam is not there, and its flint is not a boulder ore")

	var sea = TileDataScript.new()
	sea.placeholder = true
	check(sea.ore_at(Vector3(10.0, 0.0, 10.0), 40.0, NAMES, 10.0) == "", "open ocean has no ore")

	print("ore near: %d failures" % failures)
	quit(1 if failures > 0 else 0)
