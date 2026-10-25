extends SceneTree

# Lake sites (drainage_channels.gd _carve_basins): decided per tile, inside the tile and its block, and every tile with land and
# rivers gets at least one lake. Runs on the baked tile's own heights, no bake needed.
#   godot --headless --path . --script res://src/worldgen/tools/test_tile_lakes.gd [-- --tile=3,4]

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const DrainageFillScript := preload("res://src/worldgen/tile/drainage_fill.gd")
const DrainageChannelsScript := preload("res://src/worldgen/tile/drainage_channels.gd")
const DrainageFlowScript := preload("res://src/worldgen/tile/drainage_flow.gd")

const RIVER_KM2 := 0.35
const TILE_M := 15360.0

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _channels(data, side: int, cell_m: float, origin: Vector2i):
	var h: PackedFloat32Array = data.heights
	var sea: PackedByteArray = PackedByteArray()
	sea.resize(side * side)
	var runoff: PackedFloat32Array = PackedFloat32Array()
	runoff.resize(side * side)

	for k in range(side * side):
		sea[k] = 1 if h[k] < 0.0 else 0
		runoff[k] = cell_m * cell_m * 1.0e-6

	var fill = DrainageFillScript.new()
	fill.build(h, sea, side, 2.0)
	var flow = DrainageFlowScript.new()
	flow.build(fill, runoff)
	var rules: Dictionary = {"width_m_per_sqrt_q": 6.0, "min_width_m": 24.0, "depth_m_per_sqrt_q": 1.0, "min_depth_m": 1.5, "max_depth_m": 8.0}
	var channels = DrainageChannelsScript.new()
	channels.build(h, fill, flow, side, cell_m, RIVER_KM2, rules, 17, origin)
	return channels


func _init() -> void:
	var tile: Vector2i = Vector2i(3, 4)

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tile="):
			var parts: PackedStringArray = argument.trim_prefix("--tile=").split(",")
			tile = Vector2i(int(parts[0]), int(parts[1]))

	var errors: Array = []
	var world: String = "res://worlds/base_world"
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var data = generator.get_tile(tile)

	if data.placeholder:
		print("no baked tile, skipping")
		quit(0)
		return

	var side: int = data.samples
	var cell_m: float = data.spacing_m
	@warning_ignore("integer_division")
	var origin: Vector2i = Vector2i(int(round(data.x0 / cell_m)), int(round(data.z0 / cell_m)))
	var first = _channels(data, side, cell_m, origin)
	_check(first.lake_sites.size() >= 1, "tile %s has at least one carved lake (%d)" % [tile, first.lake_sites.size()])
	var x_min: float = float(tile.x) * TILE_M
	var z_min: float = float(tile.y) * TILE_M
	var worst: float = INF

	for site in first.lake_sites:
		var keep: float = 1.5 * float(site[2])
		var in_x: float = fposmod(float(site[0]), TILE_M)
		var in_z: float = fposmod(float(site[1]), TILE_M)
		worst = minf(worst, minf(minf(in_x, TILE_M - in_x), minf(in_z, TILE_M - in_z)) - keep)
		_check(float(site[0]) - keep >= x_min and float(site[0]) + keep <= x_min + TILE_M and float(site[1]) - keep >= z_min and float(site[1]) + keep <= z_min + TILE_M, "lake at %d,%d (radius %.0f m) lies inside its tile" % [int(site[0]), int(site[1]), float(site[2])])

	_check(worst >= -0.001, "every lake bowl stays inside its tile (margin %.0f m)" % worst)
	var second = _channels(data, side, cell_m, origin)
	_check(str(second.lake_sites) == str(first.lake_sites), "a second build gives the same lakes")
	print("tile lakes: %d failures" % failures)
	quit(1 if failures > 0 else 0)
