extends SceneTree

# Where a new player appears and how wet it is there (Sonny, 31 Oct 2026): the server's spawn (x, z from terrain_server SPAWN_OVERRIDE, y = ground + 2 m), the ground, the settled
# water level and the distance to the nearest wet cell, plus a map of the 80 m around it ('~' water, '.' dry) and the nearest cells that satisfy the spawn rule.
#   godot --headless --path . --script res://tools/spawn_probe.gd -- [--x=53316 --z=68476]

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")


func _initialize() -> void:
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
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var data = generator.get_tile(Vector2i(int(floor(cx / generator.tile_size_m)), int(floor(cz / generator.tile_size_m))))
	print("tile %s samples %d spacing %.1f" % [str(data.tile), data.samples, data.spacing_m])
	print("spawn %.0f,%.0f ground %.2f" % [cx, cz, float(generator.surface_height(cx, cz))])
	_describe(data, cx, cz)
	print("map (8 m cells, rows north to south, columns west to east, spawn in the middle): ~ water, . dry")

	for dz in range(-10, 11):
		var line: String = ""

		for dx in range(-10, 11):
			var wet: bool = _level(data, cx + dx * 8.0, cz + dz * 8.0) == _level(data, cx + dx * 8.0, cz + dz * 8.0) and not is_nan(_level(data, cx + dx * 8.0, cz + dz * 8.0))
			line += "~" if wet else "."

		print(line)

	quit(0)


func _level(data, x: float, z: float) -> float:
	var k: int = data.nearest(x, z)
	var levels: PackedFloat32Array = data.sim_levels

	if k >= 0 and k < levels.size() and not is_nan(levels[k]):
		return levels[k]

	var ws: float = data.water_surface[k] if k < data.water_surface.size() else NAN
	return ws


func _describe(data, x: float, z: float) -> void:
	var ground: float = data.height_at(x, z)
	var level: float = _level(data, x, z)
	var near: float = 1e9
	var near_level: float = NAN

	for dz in range(-12, 13):
		for dx in range(-12, 13):
			var l: float = _level(data, x + dx * 8.0, z + dz * 8.0)

			if not is_nan(l):
				var d: float = Vector2(dx * 8.0, dz * 8.0).length()

				if d < near:
					near = d
					near_level = l

	print("at %.0f,%.0f: ground %.2f, water level %s, nearest wet cell %.0f m away (level %s)" % [x, z, ground, str(level), near, str(near_level)])
