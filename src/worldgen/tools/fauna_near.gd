extends SceneTree

# Fauna measurement: which biomes lie within 100 m and 500 m of a spot, and what that means for each species' spawn weight there (the same biome and habitat
# rows the server reads from data/animals/animals.json). It estimates; the live count also depends on the top-up loop, near_share, hours and the player cap.
#   godot --headless --path . --script res://src/worldgen/tools/fauna_near.gd -- --at=53301,68427 [--out=FILE]
# Per species it prints the mean biome weight (0 to 1+) over the 100 m and 500 m discs, the share of the disc the species may stand in, and the expected
# number held for a player there at day / dusk / night: target_per_player x spawn_share x mean weight x hour chance (a rough ceiling, not a simulation).
# Species without a "biomes" row use weight 1 everywhere; "hour chance" is the "active" row (1 without one).

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")

const STEP_M := 25.0
const RINGS := [100.0, 500.0]


func _init() -> void:
	var world: String = "res://worlds/base_world"
	var at: Vector2 = Vector2(53301.0, 68427.0)
	var out_path: String = ""

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--at="):
			var p: PackedStringArray = argument.trim_prefix("--at=").split(",")
			at = Vector2(float(p[0]), float(p[1]))
		elif argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")

	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var biome_names: Dictionary = {}

	for biome_entry in tables.get_entries("biomes"):
		biome_names[int(biome_entry["id"])] = str(biome_entry["name"])

	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals/animals.json"))
	var species: Dictionary = config["species"]
	var lines: PackedStringArray = []

	for ring in RINGS:
		var shares: Dictionary = {}
		var samples: int = 0
		var steps: int = int(ring / STEP_M)

		for dz in range(-steps, steps + 1):
			for dx in range(-steps, steps + 1):
				if Vector2(dx, dz).length() * STEP_M > ring:
					continue

				var x: float = at.x + float(dx) * STEP_M
				var z: float = at.y + float(dz) * STEP_M
				var tile_data = generator.get_tile(generator.tile_of(x, z))
				var biome_name: String = "" if tile_data.placeholder else str(biome_names.get(int(tile_data.biome[tile_data.nearest(x, z)]), ""))
				shares[biome_name] = int(shares.get(biome_name, 0)) + 1
				samples += 1

		lines.append("within %d m of (%.0f, %.0f): %d samples" % [int(ring), at.x, at.y, samples])
		var names: Array = shares.keys()
		names.sort_custom(func(a, b): return shares[a] > shares[b])

		for biome in names:
			lines.append("  %-22s %5.1f %%" % [str(biome) if str(biome) != "" else "(unknown)", 100.0 * float(shares[biome]) / float(maxi(samples, 1))])

		lines.append("  %-12s %7s %7s | %6s %6s %6s  (expected held: day dusk night)" % ["species", "weight", "share", "day", "dusk", "night"])

		for id in species:
			var def: Dictionary = species[id]
			var target: float = float(def.get("target_per_player", 0)) * float(def.get("spawn_share", 1.0))
			var weight_sum: float = 0.0
			var allowed: int = 0

			for biome in shares:
				var w: float = 1.0

				if def.has("biomes"):
					w = float((def["biomes"] as Dictionary).get(str(biome), 0.0))

				weight_sum += w * float(shares[biome])

				if w > 0.0:
					allowed += int(shares[biome])

			var mean: float = weight_sum / float(maxi(samples, 1))
			var hours: Dictionary = def.get("active", {})
			lines.append("  %-12s %7.2f %6.0f%% | %6.2f %6.2f %6.2f" % [str(id), mean, 100.0 * float(allowed) / float(maxi(samples, 1)), target * mean * float(hours.get("day", 1.0)), target * mean * float(hours.get("dusk", 1.0)), target * mean * float(hours.get("night", 1.0))])

		lines.append("")

	for message in errors:
		lines.append("load error: " + str(message))

	var text: String = "\n".join(lines)
	print(text)

	if out_path != "":
		var file: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)

		if file != null:
			file.store_string(text + "\n")

	quit(0)
