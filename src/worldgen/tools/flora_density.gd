extends SceneTree

# Flora density per biome on the nine centre tiles: how many of each species the placer really places per km2.
#
#   godot --headless --path . --script res://src/worldgen/tools/flora_density.gd -- [--stride=3] [--out=FILE.json] [--world=res://worlds/base_world]
#
# Samples every `stride`th 256 m chunk of tiles x 2..4, z 3..5 (stride 1 = all), counts items by the biome under each item,
# and the sampled area by biome. Writes JSON: {area_km2: {biome: km2}, counts: {biome: {species: n}}, kinds: {species: kind}}.
# Also prints placer time and the item totals. Read only.

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")


func _init() -> void:
	var world: String = "res://worlds/base_world"
	var out: String = "user://flora_density.json"
	var stride: int = 3

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--stride="):
			stride = int(argument.trim_prefix("--stride="))
		elif argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
		elif argument.begins_with("--world="):
			world = argument.trim_prefix("--world=")

	var errors: Array = []
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
	var placer = PlacerScript.new()
	placer.setup(generator, tables, rules)
	var biome_names: Dictionary = {}

	for entry in tables.get_entries("biomes"):
		biome_names[int(entry["id"])] = str(entry["name"])

	var area: Dictionary = {}
	var counts: Dictionary = {}
	var kinds: Dictionary = {}

	for entry in tables.get_entries("flora"):
		kinds[str(entry["name"])] = str(entry["kind"])

	var chunk_m: float = placer.chunk_m
	var started: int = Time.get_ticks_msec()
	var chunks: int = 0
	var items_total: int = 0

	for tz in range(3, 6):
		for tx in range(2, 5):
			var data = generator.get_tile(Vector2i(tx, tz))

			if data.placeholder:
				print("tile %d,%d is a placeholder" % [tx, tz])
				continue

			
			var per_tile: int = int(round(generator.tile_size_m / chunk_m))

			for cj in range(0, per_tile, stride):
				for ci in range(0, per_tile, stride):
					var origin: Vector2 = Vector2(data.x0 + float(ci) * chunk_m, data.z0 + float(cj) * chunk_m)
					var chunk: Vector2i = placer.chunk_of(origin.x + 1.0, origin.y + 1.0)
					var made: Dictionary = placer.chunk_items(chunk)
					chunks += 1
					print("chunk ", chunks, " ", Time.get_ticks_msec() - started, " ms")

					# Area by biome: 16 m sample grid.
					for z in range(8, int(chunk_m), 16):
						for x in range(8, int(chunk_m), 16):
							var b: String = biome_names.get(int(data.biome[data.nearest(origin.x + x, origin.y + z)]), "?")
							area[b] = float(area.get(b, 0.0)) + 256.0 / 1.0e6

					for n in range(made["ids"].size()):
						var sp: Dictionary = placer.species_of(made["ids"][n])
						var p: Vector3 = made["positions"][n]
						var b: String = biome_names.get(int(data.biome[data.nearest(p.x, p.z)]), "?")

						if not counts.has(b):
							counts[b] = {}

						var key: String = sp["name"]
						counts[b][key] = int(counts[b].get(key, 0)) + 1
						items_total += 1

	print("chunks %d, items %d, %.1f s" % [chunks, items_total, float(Time.get_ticks_msec() - started) / 1000.0])
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify({"area_km2": area, "counts": counts, "kinds": kinds, "stride": stride}, "\t"))
	f.close()
	print("wrote ", ProjectSettings.globalize_path(out) if out.begins_with("user://") else out)
	quit(0)
