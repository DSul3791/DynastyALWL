extends SceneTree

# Guaranteed river ore (tile_geology.gd _ensure_river_ore): a tile with land and rivers but no tin or copper within
# river_ore_within_m of a river gets one placer of each missing metal laid along a river.
#   godot --headless --path . --script res://src/worldgen/tools/test_river_ore.gd [-- --tile=3,4]
# Part 1 runs on made-up arrays, part 2 on the baked tile's own heights and rivers (no bake needed; skipped without a tile).

const TileGeologyScript := preload("res://src/worldgen/tile/tile_geology.gd")
const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _geology(samples: int):
	var geology = TileGeologyScript.new()
	geology.samples = samples
	geology.spacing_m = 8.0
	geology._master = 17
	geology._rules = {"ores": {
		"river_ore_resources": ["tin", "copper"], "river_ore_within_m": 1000, "river_ore_min_river_cells": 100,
		"placer_length_m": 3000, "placer_step_m": 96, "placer_thickness_m": [1, 3],
	}}
	return geology


# Distance from a point to the nearest river cell of the arrays.
func _near_river(point: Array, water_class: PackedByteArray, samples: int, x0: float, z0: float) -> float:
	var best: float = INF

	for index in range(samples * samples):
		if water_class[index] == TileGeologyScript.RIVER:
			@warning_ignore("integer_division")
			var spot: Vector2 = Vector2(x0 + float(index % samples) * 8.0, z0 + float(index / samples) * 8.0)
			best = minf(best, spot.distance_to(Vector2(float(point[0]), float(point[1]))))

	return best


func _made_up() -> void:
	var side: int = 161
	var heights: PackedFloat32Array = PackedFloat32Array()
	var water_class: PackedByteArray = PackedByteArray()
	var flow: PackedFloat32Array = PackedFloat32Array()
	heights.resize(side * side)
	water_class.resize(side * side)
	flow.resize(side * side)

	for j in range(side):
		for i in range(side):
			heights[j * side + i] = 40.0 - float(j) * 0.2

	for j in range(10, 150):
		water_class[j * side + 80] = TileGeologyScript.RIVER
		flow[j * side + 80] = float(j)
		flow[j * side + 79] = float(j) - 0.5

	var geology = _geology(side)
	geology._ensure_river_ore(Vector2i(3, 4), heights, water_class, flow, 0.0, 0.0)
	var metals: Array = []

	for body in geology.ore_bodies:
		metals.append(str(body["resource"]))
		_check(body["points"].size() >= 3, "%s placer has %d points" % [body["resource"], body["points"].size()])
		var far: float = 0.0

		for point in body["points"]:
			far = maxf(far, _near_river(point, water_class, side, 0.0, 0.0))

		_check(far <= 8.0, "%s placer stays on the river (farthest point %.0f m)" % [body["resource"], far])

	metals.sort()
	_check(metals == ["copper", "tin"], "a tile with a river and no ore gets one tin and one copper placer (%s)" % str(metals))

	var again = _geology(side)
	again._ensure_river_ore(Vector2i(3, 4), heights, water_class, flow, 0.0, 0.0)
	_check(str(again.ore_bodies) == str(geology.ore_bodies), "the same tile gives the same placers")

	var near = _geology(side)
	near.ore_bodies.append({"resource": "copper", "shape": "lens", "center": [640.0, 20.0, 600.0]})
	near._ensure_river_ore(Vector2i(3, 4), heights, water_class, flow, 0.0, 0.0)
	metals = []

	for body in near.ore_bodies:
		if bool(body.get("guaranteed", false)):
			metals.append(str(body["resource"]))

	_check(metals == ["tin"], "copper already on the river: only tin is added (%s)" % str(metals))

	var dry = _geology(side)
	var no_water: PackedByteArray = PackedByteArray()
	no_water.resize(side * side)
	dry._ensure_river_ore(Vector2i(2, 4), heights, no_water, flow, 0.0, 0.0)
	_check(dry.ore_bodies.is_empty(), "a tile without rivers gets none")


func _real_tile(tile: Vector2i) -> void:
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
		print("no baked tile %s, skipping the real-tile part" % tile)
		return

	# The runtime tile has no flow map: lower ground counts as more flow, which walks downhill.
	var flow: PackedFloat32Array = PackedFloat32Array()
	flow.resize(data.heights.size())

	for k in range(data.heights.size()):
		flow[k] = 5000.0 - data.heights[k]

	var geology = _geology(data.samples)
	geology._rules["ores"]["river_ore_min_river_cells"] = 400
	geology._ensure_river_ore(tile, data.heights, data.water_class, flow, data.x0, data.z0)
	_check(geology.ore_bodies.size() == 2, "tile %s with no bodies gets 2 guaranteed placers (%d)" % [tile, geology.ore_bodies.size()])

	for body in geology.ore_bodies:
		var wet: int = 0

		for point in body["points"]:
			if _near_river(point, data.water_class, data.samples, data.x0, data.z0) <= 16.0:
				wet += 1

		_check(body["points"].size() >= 3 and wet == body["points"].size(), "%s placer: %d points, %d on a river" % [body["resource"], body["points"].size(), wet])


func _init() -> void:
	var tile: Vector2i = Vector2i(3, 4)

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tile="):
			var parts: PackedStringArray = argument.trim_prefix("--tile=").split(",")
			tile = Vector2i(int(parts[0]), int(parts[1]))

	_made_up()
	_real_tile(tile)
	print("river ore: %d failures" % failures)
	quit(1 if failures > 0 else 0)
