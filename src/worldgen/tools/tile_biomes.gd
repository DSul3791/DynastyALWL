extends SceneTree
# Biome share of each tile in a block (default the starter tile 3,4 and its 8 neighbours), sampled every 64 m, and the tile centres.
#   godot --headless --path . --script res://src/worldgen/tools/tile_biomes.gd [-- --tiles=2..4,3..5]
const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")

func _init() -> void:
	var world: String = "res://worlds/base_world"
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var names: Dictionary = {}
	for entry in tables.get_entries("biomes"):
		names[int(entry["id"])] = str(entry["name"])
	for tz in range(3, 6):
		for tx in range(2, 5):
			var data = generator.get_tile(Vector2i(tx, tz))
			if data == null:
				print("tile %d,%d: not baked" % [tx, tz])
				continue
			var counts: Dictionary = {}
			var total: int = 0
			var span: float = 1761.0 * 8.0
			for z in range(0, int(span), 64):
				for x in range(0, int(span), 64):
					var b: int = int(data.biome[data.nearest(data.x0 + 640.0 + x, data.z0 + 640.0 + z)])
					counts[b] = int(counts.get(b, 0)) + 1
					total += 1
			var parts: Array = []
			var keys: Array = counts.keys()
			keys.sort_custom(func(a, b): return counts[a] > counts[b])
			for b in keys.slice(0, 12):
				parts.append("%s %d%%" % [names.get(b, str(b)), roundi(100.0 * counts[b] / total)])
			print("tile %d,%d centre (%.0f, %.0f): %s" % [tx, tz, data.x0 + 640.0 + span * 0.5, data.z0 + 640.0 + span * 0.5, ", ".join(parts)])
	quit(0)
