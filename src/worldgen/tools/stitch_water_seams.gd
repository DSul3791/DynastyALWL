extends SceneTree

# Admin tool: makes the settled water agree along the shared edges of neighbouring tiles. Each tile is settled alone, so its edge row/column can
# differ from the neighbour's (the report's seam MISMATCH); this gives both sides the larger depth (WaterSettler.stitch_edge) and saves the changed tiles.
# Run after every tile in the block is settled.
#
#   godot --headless --path . --script res://src/worldgen/tools/stitch_water_seams.gd -- --from=2,3 --to=4,5 [--world=DIR] [--side=N] (samples per tile side; default read from the first settled tile)

const WaterSettler := preload("res://src/water/water_settler.gd")
const WaterStore := preload("res://src/water/water_store.gd")
const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")

const DEFAULT_WORLD_DIR := "res://worlds/base_world"


func _init() -> void:
	var world_dir: String = DEFAULT_WORLD_DIR
	var from: Vector2i = Vector2i(3, 4)
	var to: Vector2i = Vector2i(3, 4)

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--world="):
			world_dir = argument.trim_prefix("--world=")
		elif argument.begins_with("--from=") or argument.begins_with("--to="):
			var parts: PackedStringArray = argument.split("=")[1].split(",")
			var corner: Vector2i = Vector2i(int(parts[0]), int(parts[1]))

			if argument.begins_with("--from="):
				from = corner
			else:
				to = corner

	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world_dir + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world_dir + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())

	if settings == null or not errors.is_empty():
		push_error("\n".join(errors))
		quit(1)
		return

	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world_dir + "/tiles")
	var side: int = generator.get_tile(from).samples
	var depths: Dictionary = {}

	for z in range(from.y, to.y + 1):
		for x in range(from.x, to.x + 1):
			var loaded: PackedFloat32Array = WaterStore.load_depth("%s/water/tile_%d_%d.water" % [world_dir, x, z], side)

			if not loaded.is_empty():
				depths[Vector2i(x, z)] = loaded

	var changed_tiles: Dictionary = {}
	var total: int = 0

	for pass_number in range(2):       # a second pass settles the corner cell shared by four tiles
		for tile in depths:
			for dir in [0, 1]:
				var other: Vector2i = tile + (Vector2i(1, 0) if dir == 0 else Vector2i(0, 1))

				if not depths.has(other):
					continue

				var changed: int = WaterSettler.stitch_edge(depths[tile], depths[other], side, dir)
				print("seam %s | %s: %d edge cells changed" % [tile, other, changed])

				if changed > 0:
					changed_tiles[tile] = true
					changed_tiles[other] = true
					total += changed

	for tile in changed_tiles:
		var count: int = WaterStore.save("%s/water/tile_%d_%d.water" % [world_dir, tile.x, tile.y], side, depths[tile])
		print("saved tile %s: %d wet cells" % [tile, count])

	print("stitch done: %d tiles read, %d edge cells changed in %d tiles" % [depths.size(), total, changed_tiles.size()])
	quit(0)
