extends SceneTree

# Soil ids and ground heights on a grid (Sonny, 31 Oct 2026): what the ground shader's layer comes from near a point.
#   godot --headless --path . --script res://tools/soil_probe.gd -- --x=52548 --z=66528 [--half=48]

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")


func _init() -> void:
	var world: String = "res://worlds/base_world"
	var cx: float = 52548.0
	var cz: float = 66528.0
	var half: int = 48

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--x="):
			cx = float(argument.trim_prefix("--x="))
		elif argument.begins_with("--z="):
			cz = float(argument.trim_prefix("--z="))
		elif argument.begins_with("--half="):
			half = int(argument.trim_prefix("--half="))

	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var data = generator.get_tile(Vector2i(int(floor(cx / generator.tile_size_m)), int(floor(cz / generator.tile_size_m))))
	print("rows z from %.0f to %.0f step 8, columns x from %.0f to %.0f; soil id / ground height" % [cz - half, cz + half, cx - half, cx + half])

	for dz in range(-half, half + 1, 8):
		var line: String = ""

		for dx in range(-half, half + 1, 8):
			var k: int = data.nearest(cx + dx, cz + dz)
			line += "%2d/%4.1f " % [int(data.soil[k]), data.heights[k]]

		print(line)

	quit(0)
