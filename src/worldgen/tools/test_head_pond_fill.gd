extends SceneTree

# Head pond fill (build 623 bug: the spring landed in a lower basin beside the head pond, so the
# real pond stayed dry while the basin filled and spilled). On a dry start every spring must sit
# in a pond that then fills: after SIM_SECONDS of simulated time the water at each spring stands
# at least FILL_SHARE of the way from the ground to the baked pond level.
#   godot --headless --path . --script res://src/worldgen/tools/test_head_pond_fill.gd [-- --tile=3,4]

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const WaterSettler := preload("res://src/water/water_settler.gd")

const SIM_SECONDS := 10800.0
const FILL_SHARE := 0.8
const MIN_GROUND_M := 0.0        # below sea level is a bay or estuary hollow, not a head pond
const MIN_POND_DEPTH_M := 1.5    # drainage-mode head ponds are carved 2 to 8 m deep (drainage_channels.gd _carve_basins); 25 Oct 2026: was 10 to 14 m (the placed head_pond_depth_m ponds)
const MAX_POND_DEPTH_M := 8.5    # deeper than that is a lake or the sea, not a head pond

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


# A still pond, not a steep river cell: most of the cells within 4 samples hold baked water at the same level.
func _is_flat_water(data, k: int, surface: float) -> bool:
	var side: int = data.samples
	var same: int = 0

	for dj in range(-4, 5):
		for di in range(-4, 5):
			var n: int = k + dj * side + di
			var level: float = data.water_surface[n]

			if data.water_class[n] > 1 and not is_nan(level) and absf(level - surface) < 0.5:
				same += 1

	return same >= 20   # a carved head ppond is 25 m across at the least (about 30 cells in this window), not the old 50 m


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

	if settings == null or not errors.is_empty():
		push_error("\n".join(errors))
		quit(1)
		return

	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var data = generator.get_tile(tile)

	if data.placeholder:
		push_error("no baked tile %s" % tile)
		quit(1)
		return

	var sim = WaterSettler.build(data, 10.0, generator, false)
	var spots: Array = []

	for spring in sim.springs:
		var k: int = int(spring[0])
		var surface: float = data.water_surface[k]

		if is_nan(surface) or data.water_class[k] < 2 or surface - data.heights[k] < MIN_POND_DEPTH_M or surface - data.heights[k] > MAX_POND_DEPTH_M:
			continue

		if data.heights[k] < MIN_GROUND_M or not _is_flat_water(data, k, surface):
			continue

		spots.append([k, surface - data.heights[k]])

	_check(not spots.is_empty(), "tile %s has springs inside ponds (%d)" % [tile, spots.size()])

	while sim.seconds < SIM_SECONDS:
		sim.step()

	for spot in spots:
		var k: int = spot[0]
		var wet: float = sim.depth_at(k)
		_check(wet >= FILL_SHARE * float(spot[1]), "spring at sample %d: pond %.1f m deep, filled to %.1f m after %d s" % [k, spot[1], wet, int(SIM_SECONDS)])

	print("head pond fill: %d failures" % failures)
	quit(1 if failures > 0 else 0)
