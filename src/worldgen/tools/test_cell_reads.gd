extends SceneTree

# A scatter cell's ground, water and ore reads bound to its tile (src/stream/cell_reads.gd, server_items._cell_reads; Dave's PC 21 Nov 2026:
# one cell's copper and tin rocks waited 409 ms on the generator lock while a player ran into new ground) give exactly the boulders and
# copper and tin rocks the per-read callables give, on the real starter tile: the same keys, places, sizes, ores and grades. With the bound
# reads the layout never calls the general callables (each takes the generator's lock), and the cell asks for its tile once.
#   godot --headless --path . --script res://src/worldgen/tools/test_cell_reads.gd

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const DrinkRulesScript := preload("res://src/shared/drink_rules.gd")
const CellReadsScript := preload("res://src/stream/cell_reads.gd")
const SpawnPointScript := preload("res://src/shared/spawn_point.gd")

const WORLD := "res://worlds/base_world"
const STORE := "user://test_cell_reads"
const CELL_M := 32.0

var failures: int = 0


# A stand-in for the running water (terrain_server's water_live, WaterHub2): its tile's live levels are `sim`.
class FakeHub:
	var water: FakeWater

	func data_of(_tile: Vector2i) -> FakeWater:
		return water


class FakeWater:
	var sim: PackedFloat32Array
	var real

	func sim_snapshot() -> PackedFloat32Array:
		return sim

	func nearest(x: float, z: float) -> int:
		return real.nearest(x, z)


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


# A fresh items server on the real tile, with the general callables wired as terrain_server.gd wires them (no running water: depth from the
# sea only, or `hub`'s levels), each counting its calls in `calls`; with `bound`, also the cell reads.
func make(generator, settings, calls: Dictionary, bound: bool, hub: FakeHub = null):
	DirAccess.make_dir_recursive_absolute(STORE)
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.setup(ItemTableScript.load_default(), STORE)
	items._boulder_left = {}
	items._taken = {}
	items.world_seed = int(settings.master_seed)
	items.ground_height = func(x, z):
		calls["general"] = int(calls.get("general", 0)) + 1
		return generator.surface_height(x, z)
	items.water_near = func(pos, reach):
		calls["general"] = int(calls.get("general", 0)) + 1
		return DrinkRulesScript.water_near(generator.get_tile(generator.tile_of(pos.x, pos.z)), pos, reach, false)
	items.water_depth_at = func(pos: Vector3) -> float:
		calls["general"] = int(calls.get("general", 0)) + 1
		var water: Array = CellReadsScript.water_at(generator, generator.get_tile(generator.tile_of(pos.x, pos.z)), hub.data_of(Vector2i.ZERO) if hub != null else null, hub != null, pos)
		return 0.0 if is_nan(water[0]) else maxf(float(water[0]) - float(water[1]), 0.0)
	items.ore_near = func(pos, reach, names, depth_m):
		calls["general"] = int(calls.get("general", 0)) + 1
		return generator.get_tile(generator.tile_of(pos.x, pos.z)).ore_at(pos, reach, names, depth_m)
	items.rock_near = func(pos): return generator.get_tile(generator.tile_of(pos.x, pos.z)).bedrock_name_at(pos)

	if bound:
		items.cell_reads = func(x: float, z: float) -> Dictionary:
			calls["cells"] = int(calls.get("cells", 0)) + 1
			return CellReadsScript.bound(generator, hub, x, z)

	return items


# Every boulder and ore rock the cells lay, as text sorted by key, the milliseconds the layout took, and the ore rocks' costs per cell: the slowest
# cell's ore rocks in ms, the most ore body looks in one cell, and the meteorites' body looks and ms over all cells.
func lay(items, cells: Array) -> Array:
	items._items.clear()
	var started: int = Time.get_ticks_usec()
	var worst_ms: float = 0.0
	var worst_cell: Vector2i = Vector2i.ZERO
	var most_looks: int = 0
	var met_looks: int = 0
	var met_usec: int = 0
	var body_usec: Dictionary = {}    # ore -> usec in its ore body looks over all cells
	var body_looks: Dictionary = {}   # ore -> its ore body looks over all cells

	for cell in cells:
		var reads: Dictionary = items._cell_reads(cell, CELL_M)
		items._lay_out_boulders(cell, CELL_M, reads)
		items._ore_usec = PackedInt64Array([0, 0, 0, 0, 0, 0, 0])
		items._ore_split.clear()
		var ore_started: int = Time.get_ticks_usec()
		var looks_before: int = 0

		for ore in ["copper", "tin", "iron", "meteorite"]:
			var body_before: int = items._ore_usec[1]
			looks_before = items._ore_usec[5]
			items._lay_out_ore_rocks(cell, CELL_M, ore, reads)
			body_usec[ore] = int(body_usec.get(ore, 0)) + items._ore_usec[1] - body_before
			body_looks[ore] = int(body_looks.get(ore, 0)) + items._ore_usec[5] - looks_before

		var cell_ms: float = float(Time.get_ticks_usec() - ore_started) / 1000.0
		met_looks += items._ore_usec[5] - looks_before
		met_usec += int(items._ore_split.get("meteorite", 0))
		most_looks = maxi(most_looks, items._ore_usec[5])

		if cell_ms > worst_ms:
			worst_ms = cell_ms
			worst_cell = cell

	var ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	print("ore rocks: slowest cell %s %.1f ms, at most %d ore body looks in a cell; meteorites %d looks, %.1f ms in all" % [str(worst_cell), worst_ms, most_looks, met_looks, float(met_usec) / 1000.0])
	var rows: Array = []

	for id in items._items:
		var it: Dictionary = items._items[id]
		var row: Dictionary = it.get("boulder", {})
		rows.append([int(it["scatter"]), "%.9f %.9f %.9f" % [it["pos"].x, it["pos"].y, it["pos"].z], int(it["number"]), int(it["count"]), "%.9f" % float(row.get("radius", -1.0)), str(row.get("ore", "")), "%.9f" % float(row.get("grade", -1.0))])

	rows.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	return [rows, ms, worst_ms, most_looks, met_looks, float(met_usec) / 1000.0, body_usec, body_looks]


# The microseconds one ore body look of `ore` took on average in a lay() result, or 0 with no look.
func per_look(result: Array, ore: String) -> float:
	var looks: int = int((result[7] as Dictionary).get(ore, 0))
	return float((result[6] as Dictionary).get(ore, 0)) / float(looks) if looks > 0 else 0.0


func _init() -> void:
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(WORLD + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(WORLD + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())

	if not errors.is_empty():
		check(false, "the world loads (%s)" % str(errors))
		quit(1)
		return

	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, WORLD + "/tiles")
	# The cells round the spawn (the slow one on Dave's PC, 1815, 2229, among them) and round the tin body to its north east.
	var spawn: Vector2 = SpawnPointScript.OVERRIDE
	var cells: Array = []

	for centre in [spawn, Vector2(58751.0, 72843.0)]:
		var mid: Vector2i = Vector2i(int(floor(centre.x / CELL_M)), int(floor(centre.y / CELL_M)))

		for dz in range(-4, 5):
			for dx in range(-4, 5):
				cells.append(mid + Vector2i(dx, dz))

	check(cells.has(Vector2i(1815, 2229)), "the cell that took 409 ms on Dave's PC is among them")
	generator.surface_height(spawn.x, spawn.y)   # the tile read, outside the timing
	var general_calls: Dictionary = {}
	var bound_calls: Dictionary = {}
	var before: Array = lay(make(generator, settings, general_calls, false), cells)
	var after: Array = lay(make(generator, settings, bound_calls, true), cells)
	var rocks: int = 0

	for row in before[0]:
		rocks += 1 if str(row[5]) in ["copper", "tin", "iron", "meteorite"] or int(row[2]) != 0 else 0

	print("cell reads: %d cells, %d rows (%d copper, tin or iron), general reads %d in %.1f ms; bound: %d tile looks, %d general reads in %.1f ms" % [cells.size(), before[0].size(), rocks,
		int(general_calls.get("general", 0)), float(before[1]), int(bound_calls.get("cells", 0)), int(bound_calls.get("general", 0)), float(after[1])])
	check(before[0].size() > 0 and rocks > 0, "the cells lay boulders and copper, tin or iron rocks (%d rows)" % before[0].size())
	check(str(after[0]) == str(before[0]), "the bound reads lay exactly the same rocks: keys, places, sizes, ores and grades")
	check(int(bound_calls.get("general", 0)) == 0 and int(general_calls.get("general", 0)) > cells.size() * 4, "with the bound reads the layout never takes the general (locking) path (%d general reads before)" % int(general_calls.get("general", 0)))
	check(int(bound_calls.get("cells", 0)) == cells.size(), "one tile look a cell (%d)" % int(bound_calls.get("cells", 0)))
	# The ore rocks' cost per cell (Lane B 21 Nov 2026: slow-cell lines of 55 to 60 ms in the ore part near spawn), with the cells round spawn among
	# them. Body looks are bounded by the rule: one per ore for the cell, then at most one per try for each ore whose body is near; meteorites none.
	# The time bound is generous (a slow lane machine; about 1 ms a cell is usual) and still catches a stall of the size seen.
	check(int(after[3]) <= 3 * 8 and int(after[4]) == 0, "ore body looks stay bounded: at most %d in a cell, meteorites %d" % [int(after[3]), int(after[4])])
	check(minf(float(before[2]), float(after[2])) < 25.0, "no cell's ore rocks take long: the slowest cell of each of two runs (%.1f and %.1f ms); a one-off hiccup of a busy machine shows in one run only" % [float(before[2]), float(after[2])])
	check(float(after[5]) < float(after[1]) * 0.25, "meteorites are a small share of the layout (%.1f of %.1f ms)" % [float(after[5]), float(after[1])])

	# Cold (Lane B 21 Nov 2026, #1457 join smoke: "ore bodies 42.2 in 3 looks ... iron 42.0" in cell 1817, 2228 at 25 s): a fresh generator and
	# items server, the tile read inside the first cell's reads as on a joining server, and that cell first. The starter tile has no iron body, so
	# an iron look answers at once (TileTerrainData.ore_names) instead of walking every body of the tile twice. That walk is about what a copper or
	# tin look costs (well under 1 ms), so it cannot by itself be a 42 ms look: that one is a stall of the server's main thread while the join
	# loads (Lane B samples the load); the test keeps every look's own work small, cold or warm.
	check(cells.has(Vector2i(1817, 2228)), "the cell slow in the #1457 join smoke is among them")
	var cold_generator = GeneratorScript.new()
	cold_generator.setup(settings, rules, tables, WORLD + "/tiles")
	var cold_cells: Array = [Vector2i(1817, 2228)]

	for cell in cells:
		if cell != cold_cells[0]:
			cold_cells.append(cell)

	var cold: Array = lay(make(cold_generator, settings, {}, true), cold_cells)
	check(str(cold[0]) == str(after[0]), "the cold run, slow cell first, lays the same rocks")
	var tile_now = cold_generator.get_tile(cold_generator.tile_of(spawn.x, spawn.y))
	check(not tile_now.ore_names.has("iron") and tile_now.ore_names.has("copper") and tile_now.ore_names.has("tin"), "the starter tile has copper and tin bodies and no iron body")
	check(str(tile_now.ore_at(Vector3(spawn.x, 60.0, spawn.y), 500.0, {"iron": "iron_ore"}, 10.0)) == "", "an iron look there answers no iron")
	var iron_us: float = per_look(cold, "iron")
	var other_us: float = maxf(per_look(cold, "copper"), per_look(cold, "tin"))
	print("ore body looks, cold: copper %.1f us, tin %.1f us, iron %.1f us a look (%d iron looks); warm bound: copper %.1f, tin %.1f, iron %.1f" % [per_look(cold, "copper"),
		per_look(cold, "tin"), iron_us, int((cold[7] as Dictionary).get("iron", 0)), per_look(after, "copper"), per_look(after, "tin"), per_look(after, "iron")])
	check(int((cold[7] as Dictionary).get("iron", 0)) > 0 and iron_us <= other_us + 20.0, "an iron body look costs no more than a copper or tin look, cold (%.1f us against %.1f)" % [iron_us, other_us])
	check(per_look(after, "iron") <= maxf(per_look(after, "copper"), per_look(after, "tin")) + 20.0, "and warm (%.1f us against %.1f)" % [per_look(after, "iron"), maxf(per_look(after, "copper"), per_look(after, "tin"))])
	var spot: Vector3 = Vector3(spawn.x, float(cold_generator.surface_height(spawn.x, spawn.y)), spawn.y)
	var timed: Dictionary = {}

	for ore in ["copper", "tin", "iron"]:
		var names: Dictionary = {ore: ore + "_ore"}
		var t0: int = Time.get_ticks_usec()

		for _n in range(2000):
			tile_now.ore_at(spot, 45.0, names, 10.0)

		timed[ore] = float(Time.get_ticks_usec() - t0) / 2000.0

	print("ore_at at spawn, 2000 looks each: copper %.2f us, tin %.2f us, iron %.2f us" % [float(timed["copper"]), float(timed["tin"]), float(timed["iron"])])
	check(float(timed["iron"]) < 0.25 * minf(float(timed["copper"]), float(timed["tin"])) + 0.5, "a look for an ore the tile lacks answers without walking the bodies: under a quarter of a copper or tin look (iron %.2f us)" % float(timed["iron"]))

	# With running water: the live levels a little over the baked rivers and lakes round both places, dry elsewhere. Both ways read the same
	# depths, so the same rocks again.
	var tile_data = generator.get_tile(generator.tile_of(spawn.x, spawn.y))
	var hub: FakeHub = FakeHub.new()
	hub.water = FakeWater.new()
	hub.water.real = tile_data
	var sim: PackedFloat32Array = PackedFloat32Array()
	sim.resize(tile_data.water_surface.size())
	sim.fill(NAN)
	var wet: int = 0

	for cell in cells:
		for sz in range(5):
			for sx in range(5):
				var k: int = tile_data.nearest((float(cell.x) + float(sx) * 0.25) * CELL_M, (float(cell.y) + float(sz) * 0.25) * CELL_M)

				if int(tile_data.water_class[k]) > 1 and not is_nan(tile_data.water_surface[k]):
					wet += 1 if is_nan(sim[k]) else 0
					sim[k] = float(tile_data.water_surface[k]) + 0.3

	hub.water.sim = sim
	check(wet > 0, "the setup: running water lies in some of the cells (%d samples)" % wet)

	var live_general: Dictionary = {}
	var live_bound: Dictionary = {}
	var live_before: Array = lay(make(generator, settings, live_general, false, hub), cells)
	var live_after: Array = lay(make(generator, settings, live_bound, true, hub), cells)
	print("cell reads with running water: %d rows (dry %d); %.1f ms general, %.1f ms bound" % [live_before[0].size(), before[0].size(), float(live_before[1]), float(live_after[1])])
	check(str(live_after[0]) == str(live_before[0]), "with running water the bound reads lay exactly the same rocks too")
	check(int(live_bound.get("general", 0)) == 0, "and take no general read (%d)" % int(live_bound.get("general", 0)))
	# Off the bound tile (gate review Y part 3, 21 Nov 2026): a probe that reaches past the tile edge takes the general path, so it answers as the
	# general callables do. Bound 2 m inside the spawn tile's east edge; the probes stand 2 m past it, on the next tile.
	var edge_x: float = (floorf(spawn.x / generator.tile_size_m) + 1.0) * generator.tile_size_m
	var edge_reads: Dictionary = CellReadsScript.bound(generator, null, edge_x - 2.0, spawn.y)
	var off_ok: bool = generator.tile_of(edge_x + 2.0, spawn.y) != generator.tile_of(edge_x - 2.0, spawn.y)
	var off_tile = generator.get_tile(generator.tile_of(edge_x + 2.0, spawn.y))

	for off_dz in [-30.0, 0.0, 30.0]:
		var probe: Vector3 = Vector3(edge_x + 2.0, 0.0, spawn.y + off_dz)
		probe.y = float(generator.surface_height(probe.x, probe.z))
		var general_depth: Array = CellReadsScript.water_at(generator, off_tile, null, false, probe)
		off_ok = off_ok and is_equal_approx(float(edge_reads["ground"].call(probe.x, probe.z)), float(generator.surface_height(probe.x, probe.z)))
		off_ok = off_ok and bool(edge_reads["water_near"].call(probe, 40.0)) == DrinkRulesScript.water_near(off_tile, probe, 40.0, false)
		off_ok = off_ok and is_equal_approx(float(edge_reads["water_depth_at"].call(probe)), 0.0 if is_nan(general_depth[0]) else maxf(float(general_depth[0]) - float(general_depth[1]), 0.0))
		off_ok = off_ok and str(edge_reads["ore_near"].call(probe, 300.0, {"copper": "copper_ore", "tin": "tin_ore", "iron": "iron_ore"}, 10.0)) == str(off_tile.ore_at(probe, 300.0, {"copper": "copper_ore", "tin": "tin_ore", "iron": "iron_ore"}, 10.0))

	check(off_ok, "reads past the bound tile's edge answer as the general reads do (ground, water near, depth, ore)")
	# Ground below sea level cut off from the open sea (the fen flats, Lane A 22 Nov 2026): no sea over it when the cut_off check says so.
	var fen: Vector3 = Vector3(58428.0, 0.0, 71580.0)
	var fen_data = generator.get_tile(generator.tile_of(fen.x, fen.z))
	var fen_ground: float = float(generator.surface_height(fen.x, fen.z))
	var cut: Callable = func(_x: float, _z: float) -> bool: return true
	var sea_here: Array = CellReadsScript.water_at(generator, fen_data, null, false, fen)
	var cut_here: Array = CellReadsScript.water_at(generator, fen_data, null, false, fen, cut)
	check(fen_ground <= 0.0 and float(sea_here[0]) == 0.0 and is_nan(float(cut_here[0])), "fen ground at %.2f m: the sea by the old rule, none when cut off from it" % fen_ground)
	var fen_reads: Dictionary = CellReadsScript.bound(generator, null, fen.x, fen.z, cut)
	check(float(fen_reads["water_depth_at"].call(fen)) == 0.0 and float(CellReadsScript.bound(generator, null, fen.x, fen.z)["water_depth_at"].call(fen)) > 0.0, "and the bound depth read agrees")
	print("test_cell_reads: %d failures" % failures)
	quit(1 if failures > 0 else 0)
