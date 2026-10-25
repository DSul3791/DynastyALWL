extends SceneTree

# Headless checks for the land-type map (src/water/land_type.gd): classifier, extent filter, signature,
# spring catch basins and the spread test.
#   godot --headless --path . --script res://src/worldgen/tools/test_land_type.gd

const L := preload("res://src/water/land_type.gd")
const Sig := preload("res://src/water/land_signature.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print("%s: %s" % ["pass" if ok else "FAIL", what])
	failures += 0 if ok else 1


func _init() -> void:
	check(L.classify_cell(2.0, 0.02, 1.0, 2) == L.LAKE, "deep still water is a lake")
	check(L.classify_cell(0.8, 0.6, 1.0, 3) == L.RIVER, "flowing water is a river")
	check(L.classify_cell(0.8, 0.05, 1.0, 3) == L.RIVER, "a baked river stays river when a dry spell slows it (floor)")
	check(L.classify_cell(0.8, 0.05, 0.3, 3) != L.RIVER, "a baked river mostly dry for long is no longer river")
	check(L.classify_cell(0.3, 0.05, 0.9, 0, false, false) == L.MARSH, "shallow still water on mineral soil is marsh")
	check(L.classify_cell(0.3, 0.05, 0.9, 0, false, true) == L.SWAMP, "fertile warm shallow water is swamp")
	check(L.classify_cell(0.3, 0.05, 0.9, 0, true, true) == L.BOG, "peat shallow water is bog")
	check(L.classify_cell(0.0, 0.0, 0.2, 0) == L.FLOODPLAIN, "wet 20 percent of the time is floodplain")
	check(L.classify_cell(0.0, 0.0, 0.0, 0) == L.DRY, "dry is dry")
	check(L.classify_cell(0.0, 0.0, 0.8, 0) == L.DRY, "a field wet most of the time but with no depth now is not a wetland")

	# Extent: 3 lake cells fall away, 4 stay; 5 marsh cells fall away.
	var side: int = 8
	var types: PackedByteArray = PackedByteArray()
	types.resize(side * side)

	for i in range(3):
		types[1 * side + i] = L.LAKE

	for i in range(4):
		types[4 * side + i] = L.LAKE

	for i in range(5):
		types[6 * side + i] = L.MARSH

	var out: PackedByteArray = L.filter_extent(types, side)
	check(out[1 * side + 1] == L.DRY, "3 joined lake cells are too small")
	check(out[4 * side + 1] == L.LAKE, "4 joined lake cells are a lake")
	check(out[6 * side + 1] == L.DRY, "5 marsh cells are too small (needs 8)")

	# Signature: starts equal to the settled state; a 2 day flood barely moves it; 200 days of a new level moves it most of the way.
	var n: int = 9
	var sig = Sig.new()
	sig.setup(n)
	var d0: PackedFloat32Array = PackedFloat32Array()
	d0.resize(n * n)
	d0.fill(0.0)
	d0[40] = 1.5
	var v0: PackedFloat32Array = PackedFloat32Array()
	v0.resize(n * n)
	sig.init_from(d0, v0)
	check(is_equal_approx(sig.depth[40], 1.5) and is_equal_approx(sig.wet[40], 1.0), "signature starts at the settled state")
	var flood: PackedFloat32Array = d0.duplicate()
	flood[41] = 0.8

	for h in range(48):
		sig.update(flood, v0)

	check(sig.wet[41] < 0.1 and L.classify_cell(sig.depth[41], sig.speed[41], sig.wet[41], 0) in [L.DRY, L.FLOODPLAIN], "a 2 day flood does not rename the land (wet share %.3f)" % sig.wet[41])
	var dry: PackedFloat32Array = d0.duplicate()
	dry[40] = 0.0

	for h in range(24 * 200):
		sig.update(dry, v0)

	check(sig.wet[40] < 0.05, "200 days dry empties the old lake cell (wet share %.3f)" % sig.wet[40])

	# Spring basins: a flat plain fails; a hollow passes; a failing spring slides down the painted channel.
	var s: int = 41
	var ground: PackedFloat32Array = PackedFloat32Array()
	ground.resize(s * s)
	ground.fill(10.0)
	var wc: PackedByteArray = PackedByteArray()
	wc.resize(s * s)
	var flat_cell: int = 20 * s + 20
	check(not L.basin_report(ground, wc, s, flat_cell)["ok"], "a spring on a flat plain fails the basin rule")

	for dj in range(-1, 2):
		for di in range(-1, 2):
			ground[(20 + dj) * s + 20 + di] = 9.0

	check(L.basin_report(ground, wc, s, flat_cell)["ok"], "a spring in a 1 m hollow passes")
	var slope_cell: int = 20 * s + 28
	var report: Dictionary = L.basin_report(ground, wc, s, slope_cell)
	check(not report["ok"] and report["fix"] == -1, "a failing spring with no painted channel has no fix")
	wc[flat_cell] = L.BAKED_RIVER
	report = L.basin_report(ground, wc, s, slope_cell)
	check(not report["ok"] and report["fix"] == flat_cell, "a failing spring slides to the painted channel hollow")

	# Spread: a thin sheet of 100 cells off the channel fails; a channel-only stream passes.
	var depth: PackedFloat32Array = PackedFloat32Array()
	depth.resize(s * s)

	for dj in range(-5, 5):
		for di in range(-5, 5):
			depth[(20 + dj) * s + 20 + di] = 0.05

	check(L.spread_cells(depth, wc, s, flat_cell) > L.SPREAD_MAX_CELLS, "a thin sheet over open ground is flagged")
	depth.fill(0.0)

	for di in range(-8, 8):
		depth[20 * s + 20 + di] = 0.4
		wc[20 * s + 20 + di] = L.BAKED_RIVER

	check(L.spread_cells(depth, wc, s, flat_cell) <= L.SPREAD_MAX_CELLS, "a stream in its painted channel passes")

	print("Test done: %d fail" % failures)
	quit(1 if failures > 0 else 0)
