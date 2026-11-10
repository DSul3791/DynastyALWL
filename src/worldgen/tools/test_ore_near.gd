extends SceneTree

# Which ore a boulder is an outcrop of (TileTerrainData.ore_at; Jamie's tin check, 10 Nov 2026): the nearest compact body (lens, halo, pipe, vein, placer)
# within reach comes before any layer; a layer or scatter body counts only in its own province and only where one of its bands nears the bedrock
# surface; bodies of ores boulders do not carry (gems, flint) never hide the rest. Before, the first body whose box held the spot won, and a layer's
# box is the whole tile, so every outcrop near spawn was coal.
#   godot --headless --path . --script res://src/worldgen/tools/test_ore_near.gd

const TileDataScript := preload("res://src/worldgen/runtime/tile_terrain_data.gd")

const NAMES := {"coal": "coal", "copper": "copper_ore", "tin": "tin_ore", "iron": "iron_ore", "salt": "salt"}

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
	check(data.ore_at(Vector3(1600.0, 100.0, 1500.0), 100.0, NAMES, 10.0) == "tin", "with both in reach and the spot in neither, the nearer in its own size wins: tin 50 m from a 50 m lens before copper 80 m from a 20 m pipe")
	check(data.ore_at(Vector3(1650.0, 100.0, 1500.0), 100.0, NAMES, 10.0) == "copper", "and copper 30 m from its pipe before tin 100 m from its lens")
	check(data.ore_at(Vector3(1610.0, 100.0, 1500.0), 40.0, NAMES, 10.0) == "coal", "away from both, in the coal province, a seam 5 m under the ground shows as coal")
	check(data.ore_at(Vector3(1610.0, 94.0, 1500.0), 40.0, NAMES, 10.0) == "coal", "where the ground cuts the seam it is coal too")
	check(data.ore_at(Vector3(1610.0, 140.0, 1500.0), 40.0, NAMES, 10.0) == "", "on a hill with the seam 45 m down there is no coal")
	check(data.ore_at(Vector3(1610.0, 80.0, 1500.0), 40.0, NAMES, 10.0) == "", "in a valley cut below the seam, with the next band 25 m further down, there is none")
	check(data.ore_at(Vector3(1610.0, 0.0, 1500.0), 40.0, NAMES, 10.0) == "coal", "deeper down the next band shows again")
	check(data.ore_at(Vector3(200.0, 100.0, 1500.0), 40.0, NAMES, 10.0) == "", "in the other province the coal seam is not there, and its flint is not a boulder ore")

	# A wide tin halo listed first, with a small copper lens inside it (tile 3,4 has tin halo 552, about 920 m across, round copper halo 554 and lens 555):
	# where the copper sits it is copper; elsewhere in the halo, tin.
	var wide = TileDataScript.new()
	wide.samples = 3
	wide.spacing_m = 1000.0
	wide.province = PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0])
	wide.prov_datum = PackedFloat32Array([100.0])
	wide.layer_offset = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0])
	wide.cover = PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0])
	wide._load_ores([
		{"shape": "halo", "resource": "tin", "center": [1000.0, 1000.0], "radius_a_m": 900.0, "radius_b_m": 700.0, "top_y": 95.0, "thickness_m": 10.0},
		{"shape": "lens", "resource": "copper", "center": [1200.0, 90.0, 1000.0], "radius_a_m": 40.0, "radius_b_m": 30.0, "thickness_m": 4.0},
		{"shape": "vein", "resource": "iron", "points": [[600.0, 600.0], [600.0, 1400.0]], "top_y": 95.0, "bottom_y": 0.0, "dip_deg": 70.0, "dip_side": 1, "width_m": 4.0},
	], {"tin": 1, "copper": 2, "iron": 3}, {})
	check(wide.ore_at(Vector3(1210.0, 100.0, 1000.0), 40.0, NAMES, 10.0) == "copper", "a small copper lens inside a wide tin halo is copper where it sits")
	check(wide.ore_at(Vector3(1260.0, 100.0, 1000.0), 40.0, NAMES, 10.0) == "tin", "just outside the lens it is tin again")
	check(wide.ore_at(Vector3(1000.0, 100.0, 1300.0), 40.0, NAMES, 10.0) == "tin", "and over the rest of the halo")
	check(wide.ore_at(Vector3(601.0, 100.0, 1000.0), 40.0, NAMES, 10.0) == "iron", "a boulder on an iron vein's trace inside the halo is iron")

	# Rock salt (10 Nov 2026): an evaporite salt bed near the ground shows in boulders; a salt dome (a pipe) only where its top comes within
	# depth_m of the bedrock surface, so one buried 80 m deep gives none.
	var basin = TileDataScript.new()
	basin.samples = 3
	basin.spacing_m = 1000.0
	basin.province = PackedByteArray([0, 0, 0, 0, 0, 0, 1, 1, 1])
	basin.prov_datum = PackedFloat32Array([100.0, 100.0])
	basin.layer_offset = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0])
	basin.cover = PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0])
	basin.prov_index_of = {"p0": 0, "p1": 1}
	basin._load_ores([
		{"shape": "pipe", "resource": "salt", "center": [500.0, 500.0], "radius_m": 300.0, "top_y": 20.0, "bottom_y": -1400.0},
		{"shape": "pipe", "resource": "salt", "center": [1500.0, 500.0], "radius_m": 300.0, "top_y": 95.0, "bottom_y": -1400.0},
		{"shape": "layer", "resource": "salt", "province": "p1", "depth_below_datum_m": 4.0, "cycle_m": 1.0e9, "thickness_m": 8.0, "repeat_to_m": 5.0},
	], {"salt": 10}, {})
	check(basin.ore_at(Vector3(500.0, 100.0, 500.0), 40.0, NAMES, 10.0) == "", "over a salt dome buried 80 m deep there is no rock salt")
	check(basin.ore_at(Vector3(1500.0, 100.0, 500.0), 40.0, NAMES, 10.0) == "salt", "over one whose top is 5 m down there is")
	check(basin.ore_at(Vector3(1000.0, 100.0, 1900.0), 40.0, NAMES, 10.0) == "salt", "a salt bed 4 m under the ground shows as rock salt")
	check(data.ore_at(Vector3(1700.0, 100.0, 1510.0), 40.0, NAMES, 10.0) == "copper", "a pipe reaching the ground still shows (the copper pipe, top 5 m down)")

	var sea = TileDataScript.new()
	sea.placeholder = true
	check(sea.ore_at(Vector3(10.0, 0.0, 10.0), 40.0, NAMES, 10.0) == "", "open ocean has no ore")

	# The rock at the bedrock surface (bedrock_name_at; Dave 10 Nov 2026, limestone for Concrete): one province, 20 m of limestone at the top of each
	# 100 m cycle over granite; a fold belt turns limestone deeper than 300 m to marble.
	var bed = TileDataScript.new()
	bed.samples = 3
	bed.spacing_m = 1000.0
	bed.province = PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0])
	bed.layer_offset = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0])
	bed.cover = PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0])
	bed.prov_datum = PackedFloat32Array([100.0])
	bed.prov_cycle = PackedFloat32Array([100.0])
	bed.prov_repeat_to = PackedFloat32Array([1000.0])
	bed.prov_marble_depth = PackedFloat32Array([300.0])
	bed.prov_base = PackedInt32Array([5])
	bed.prov_bottoms = [PackedFloat32Array([20.0])]
	bed.prov_rocks = [PackedInt32Array([3])]
	bed.set_rock_ids({"limestone": 3, "granite": 5, "marble": 9})
	check(bed.bedrock_name_at(Vector3(500.0, 95.0, 500.0)) == "limestone", "5 m under the province top the bedrock is limestone")
	check(bed.bedrock_name_at(Vector3(500.0, 50.0, 500.0)) == "granite", "50 m under it, below the limestone band, granite")
	check(bed.bedrock_name_at(Vector3(500.0, -210.0, 500.0)) == "marble", "deep in the fold belt the limestone is marble")
	check(TileDataScript.new().bedrock_name_at(Vector3.ZERO) == "", "a tile with no provinces names no rock")

	print("ore near: %d failures" % failures)
	quit(1 if failures > 0 else 0)
