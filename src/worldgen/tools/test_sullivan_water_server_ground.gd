extends SceneTree

# Sullivan water M3 second half: the terrain adapter reading the server's REAL ground (server_ground_source.gd over server_block_store.gd,
# the baked tiles of worlds/base_world), and a real server dig going through the edit coordinator. Uses a throwaway store folder in user://.
#   godot --headless --path . --script res://src/worldgen/tools/test_sullivan_water_server_ground.gd

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const StoreScript := preload("res://src/stream/server_block_store.gd")
const SpawnPoint := preload("res://src/shared/spawn_point.gd")
const Grid := preload("res://src/sullivan_water/freshwater/water_grid_2d.gd")
const Adapter := preload("res://src/sullivan_water/freshwater/terrain_adapter.gd")
const Coordinator := preload("res://src/sullivan_water/freshwater/terrain_water_edit_coordinator.gd")
const Source := preload("res://src/sullivan_water/freshwater/server_ground_source.gd")

const CELL := 2.0
const SIZE := 12

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var begun: int = Time.get_ticks_msec()
	var world: String = "res://worlds/base_world"
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var store = StoreScript.new()
	var dir: String = "user://test_sullivan_server_ground_%d" % OS.get_process_id()
	var problem: String = store.setup(generator, dir)
	_check(problem == "", "server store opens (%s)" % problem)

	var source = Source.new(store)
	var corner: Vector2 = Vector2(SpawnPoint.OVERRIDE.x, SpawnPoint.OVERRIDE.y) - Vector2(SIZE, SIZE) * CELL * 0.5
	var adapter = Adapter.new(source, corner, CELL)
	adapter.scan_step_m = 0.5   # guide 24.2: min(voxel 1 m, cell / 4)
	var grid = Grid.new(SIZE, SIZE, CELL)
	var coordinator = Coordinator.new(grid, adapter)
	var t0: int = Time.get_ticks_msec()
	var built: Dictionary = coordinator.build()
	print("  read %d cells in %d ms, %d blocks loaded" % [int(built["cells"]), Time.get_ticks_msec() - t0, source.blocks_loaded])
	_check(bool(built["ok"]), "the adapter reads the spawn area from the server's ground (%s)" % built["reason"])

	var worst: float = 0.0

	for j in range(SIZE):
		for i in range(SIZE):
			var c: Vector2 = adapter.cell_centre(i, j)
			worst = maxf(worst, absf(grid.bed[grid.index(i, j)] - float(generator.surface_height(c.x, c.y))))

	print("  largest bed vs generator height difference %.3f m" % worst)
	_check(worst < 1.0, "the beds match the generator's ground height within 1 m (the voxel ground is 1 m voxels; worst %.3f m)" % worst)

	var k: int = grid.index(6, 6)
	var before: float = grid.bed[k]
	var centre: Vector2 = adapter.cell_centre(6, 6)
	var dig: Dictionary = coordinator.edit_sphere(Vector3(centre.x, before, centre.y), 2.0, false)
	_check(dig["result"] == Coordinator.COMMITTED, "a real server dig through the coordinator commits (%s %s)" % [dig["result"], dig["reason"]])
	_check(grid.bed[k] < before - 1.0, "the dug cell's bed drops (%.2f to %.2f m)" % [before, grid.bed[k]])
	_check(store.ops.edits_near(Vector3(centre.x, before, centre.y), 4.0).size() >= 1, "the dig is in the server's edit log")

	var far: Dictionary = coordinator.edit_sphere(Vector3(-50.0, 0.0, -50.0), 1.0, false)
	_check(far["result"] == Coordinator.REJECTED_UNLOADED, "a dig outside the world is refused (%s)" % far["result"])

	store.flush()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))
	print("%d failures, %d ms" % [failures, Time.get_ticks_msec() - begun])
	quit(1 if failures > 0 else 0)
