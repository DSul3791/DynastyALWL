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


# Every boulder and copper or tin rock the cells lay, as text sorted by key, and the milliseconds the layout took.
func lay(items, cells: Array) -> Array:
	items._items.clear()
	var started: int = Time.get_ticks_usec()

	for cell in cells:
		var reads: Dictionary = items._cell_reads(cell, CELL_M)
		items._lay_out_boulders(cell, CELL_M, reads)
		items._lay_out_ore_rocks(cell, CELL_M, "copper", reads)
		items._lay_out_ore_rocks(cell, CELL_M, "tin", reads)

	var ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	var rows: Array = []

	for id in items._items:
		var it: Dictionary = items._items[id]
		var row: Dictionary = it.get("boulder", {})
		rows.append([int(it["scatter"]), "%.9f %.9f %.9f" % [it["pos"].x, it["pos"].y, it["pos"].z], int(it["number"]), int(it["count"]), "%.9f" % float(row.get("radius", -1.0)), str(row.get("ore", "")), "%.9f" % float(row.get("grade", -1.0))])

	rows.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	return [rows, ms]


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
		rocks += 1 if str(row[5]) == "copper" or str(row[5]) == "tin" or int(row[2]) != 0 else 0

	print("cell reads: %d cells, %d rows (%d copper or tin), general reads %d in %.1f ms; bound: %d tile looks, %d general reads in %.1f ms" % [cells.size(), before[0].size(), rocks,
		int(general_calls.get("general", 0)), float(before[1]), int(bound_calls.get("cells", 0)), int(bound_calls.get("general", 0)), float(after[1])])
	check(before[0].size() > 0 and rocks > 0, "the cells lay boulders and copper or tin rocks (%d rows)" % before[0].size())
	check(str(after[0]) == str(before[0]), "the bound reads lay exactly the same rocks: keys, places, sizes, ores and grades")
	check(int(bound_calls.get("general", 0)) == 0 and int(general_calls.get("general", 0)) > cells.size() * 4, "with the bound reads the layout never takes the general (locking) path (%d general reads before)" % int(general_calls.get("general", 0)))
	check(int(bound_calls.get("cells", 0)) == cells.size(), "one tile look a cell (%d)" % int(bound_calls.get("cells", 0)))

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
	print("test_cell_reads: %d failures" % failures)
	quit(1 if failures > 0 else 0)
