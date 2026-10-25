extends SceneTree

# No flora on water: runs the runtime flora placer over every chunk that holds or touches water on a tile (settled water
# file and painted lakes and rivers), and counts the instances that stand on a wet cell (any species but reeds and the other
# water species) or, for trees and shrubs, one cell beside it. Must be 0.
#   godot --headless --path . --script res://src/worldgen/tools/test_flora_wet.gd [-- --tile=3,4 | --all]
# Needs the baked tiles and their water files (worlds/base_world/tiles, worlds/base_world/water).

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")

const WORLD_DIR := "res://worlds/base_world"
const NINE: Array = [[2, 3], [2, 4], [2, 5], [3, 3], [3, 4], [3, 5], [4, 3], [4, 4], [4, 5]]

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var tiles: Array = [[3, 4]]

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tile="):
			var parts: PackedStringArray = argument.trim_prefix("--tile=").split(",")
			tiles = [[int(parts[0]), int(parts[1])]]
		elif argument == "--all":
			tiles = NINE

	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(WORLD_DIR + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(WORLD_DIR + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())

	if settings == null or not errors.is_empty():
		push_error("\n".join(errors))
		quit(1)
		return

	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, WORLD_DIR + "/tiles")
	var placer = PlacerScript.new()
	placer.setup(generator, tables, rules)

	for entry in tiles:
		_tile(generator, placer, settings, Vector2i(int(entry[0]), int(entry[1])))

	print("test_flora_wet: %d failures" % failures)
	quit(1 if failures > 0 else 0)


# True when the cell holds water: settled (sim) level, or a painted lake or river with a surface.
func _wet(data, sim: PackedFloat32Array, k: int) -> bool:
	if not sim.is_empty() and not is_nan(sim[k]):
		return true

	return data.water_class[k] > 1 and not is_nan(data.water_surface[k])


func _wet_near(data, sim: PackedFloat32Array, x: float, z: float) -> bool:
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if _wet(data, sim, data.nearest(x + float(dx) * data.spacing_m, z + float(dz) * data.spacing_m)):
				return true

	return false


func _tile(generator, placer, settings, tile: Vector2i) -> void:
	var data = generator.get_tile(tile)

	if data.placeholder:
		print("tile %s is open sea: nothing to check" % str(tile))
		return

	var sim: PackedFloat32Array = data.sim_snapshot()
	var chunk_m: float = placer.chunk_m
	var per_side: int = int(ceil(settings.tile_size_m / chunk_m))
	var wet_chunks: Dictionary = {}
	var step: int = 4
	var side: int = data.samples

	for j in range(0, side, step):
		for i in range(0, side, step):
			var k: int = j * side + i

			if _wet(data, sim, k):
				var chunk: Vector2i = placer.chunk_of(data.x0 + float(i) * data.spacing_m, data.z0 + float(j) * data.spacing_m)

				for dz in range(-1, 2):
					for dx in range(-1, 2):
						wet_chunks[Vector2i(chunk.x + dx, chunk.y + dz)] = true

	if wet_chunks.is_empty():
		print("tile %s has no water: nothing to check" % str(tile))
		return

	var total: int = 0
	var on_water: int = 0
	var shown: int = 0

	for chunk in wet_chunks:
		var origin: Vector2 = placer.chunk_origin(chunk)

		if generator.tile_of(origin.x + 1.0, origin.y + 1.0) != tile:
			continue

		var items: Dictionary = placer.chunk_items(chunk)
		var positions: PackedVector3Array = items["positions"]

		for n in range(positions.size()):
			var p: Vector3 = positions[n]
			var species: Dictionary = placer.species_by_id(int(items["ids"][n]))
			total += 1

			# Reeds and the other species that list water classes may stand in or at the water; the rest may not.
			if str(species.get("shape", "")) == "reed" or int(species.get("water_mask", 0)) != 0:
				continue

			var on_cell: bool = _wet(data, sim, data.nearest(p.x, p.z))
			var beside: bool = species["kind"] != PlacerScript.KIND_PLANT and _wet_near(data, sim, p.x, p.z)

			if on_cell or beside:
				on_water += 1

				if shown < 8:
					shown += 1
					print("  flora %d (%s) at %.0f,%.0f (height %.1f) %s" % [items["ids"][n], str(species.get("name", "?")), p.x, p.z, p.y, "on a wet cell" if on_cell else "beside water"])

	print("tile %s: settled water file %s, %d wet chunks, %d flora instances there, %d on or beside water" % [str(tile), "yes" if not sim.is_empty() else "NO", wet_chunks.size(), total, on_water])
	_check(not sim.is_empty(), "tile %s has its settled water loaded when flora is placed" % str(tile))
	_check(on_water == 0, "tile %s: no flora on or beside a wet cell (%d)" % [str(tile), on_water])
