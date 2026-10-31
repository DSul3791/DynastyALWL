extends SceneTree

# Playthrough probe 4 (read-only): what stands within a few minutes' walk of the spawn point, from the real flora placer on the baked world.
#   godot --headless --path . --script res://art/playthrough/probe_spawn.gd -- [--x=53316 --z=68476] [--out=user://spawn_survey.json]
# Counts every placed species in rings (0-50 m, 50-100 m, 100-200 m, 200-400 m) around the spawn, split by kind, with how many trees are grown
# (height at least 0.8 of the species' top, the cover rule) and the ground height and biome at the spawn and at the ring edges.

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")


func _init() -> void:
	var world: String = "res://worlds/base_world"
	var cx: float = 53316.0
	var cz: float = 68476.0

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--x="):
			cx = float(argument.trim_prefix("--x="))
		elif argument.begins_with("--z="):
			cz = float(argument.trim_prefix("--z="))

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

	var flora: Dictionary = {}

	for entry in tables.get_entries("flora"):
		flora[str(entry["name"])] = entry

	print("spawn: ground height at the spawn ", generator.surface_height(cx, cz))
	var data = generator.get_tile(Vector2i(int(floor(cx / generator.tile_size_m)), int(floor(cz / generator.tile_size_m))))
	print("spawn: biome at the spawn ", biome_names.get(int(data.biome[data.nearest(cx, cz)]), "?"))
	var rings: Array = [50.0, 100.0, 200.0, 400.0]
	var counts: Array = [{}, {}, {}, {}]
	var grown: Array = [0, 0, 0, 0]
	var trees: Array = [0, 0, 0, 0]
	var grown_at: Array = []
	var lowest: Array = [1.0e9, 1.0e9, 1.0e9, 1.0e9]
	var highest: Array = [-1.0e9, -1.0e9, -1.0e9, -1.0e9]
	var chunk_lo: Vector2i = placer.chunk_of(cx - 400.0, cz - 400.0)
	var chunk_hi: Vector2i = placer.chunk_of(cx + 400.0, cz + 400.0)

	for ci in range(chunk_lo.x, chunk_hi.x + 1):
		for cj in range(chunk_lo.y, chunk_hi.y + 1):
			var made: Dictionary = placer.chunk_items(Vector2i(ci, cj))

			for n in range(made["ids"].size()):
				var p: Vector3 = made["positions"][n]
				var d: float = Vector2(p.x - cx, p.z - cz).length()

				if d > 400.0:
					continue

				var ring: int = 0

				while d > float(rings[ring]):
					ring += 1

				var sp: Dictionary = placer.species_of(made["ids"][n])
				var name: String = str(sp.get("name", "?"))
				counts[ring][name] = int(counts[ring].get(name, 0)) + 1
				lowest[ring] = minf(float(lowest[ring]), p.y)
				highest[ring] = maxf(float(highest[ring]), p.y)

				if str(flora.get(name, {}).get("kind", "")) == "tree":
					trees[ring] += 1
					var top: float = float((flora.get(name, {}).get("height_m", [10.0, 10.0]) as Array)[1])

					if float(made["heights"][n]) >= 0.8 * top:
						grown[ring] += 1

						if d <= 100.0:
							grown_at.append([name, snappedf(p.x, 0.1), snappedf(p.y, 0.1), snappedf(p.z, 0.1), snappedf(float(made["heights"][n]), 0.1), snappedf(d, 0.1)])

	grown_at.sort_custom(func(a, b): return a[5] < b[5])
	grown_at = grown_at.slice(0, 8)
	var out: Dictionary = {"spawn": [cx, cz], "rings_m": rings, "counts": counts, "trees": trees, "grown_trees": grown, "ground_low": lowest, "ground_high": highest, "grown_trees_near": grown_at}
	print("spawn: trees (all, grown) per ring ", trees, grown)
	print("spawn: ground height range per ring ", lowest, highest)

	for r in range(4):
		var rows: Array = []

		for name in counts[r]:
			rows.append([int(counts[r][name]), name, str(flora.get(name, {}).get("kind", ""))])

		rows.sort_custom(func(a, b): return a[0] > b[0])
		print("spawn: ring ", rings[r], " m: ", rows)

	var f: FileAccess = FileAccess.open("res://art/playthrough/spawn_survey.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, " "))
	f.close()
	quit()
