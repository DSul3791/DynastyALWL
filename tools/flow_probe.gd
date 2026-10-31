extends SceneTree

# How fast the drawn water runs on the settled start (Sonny, 31 Oct 2026, water phase 4): the speed the shader is given for each wet cell of a block (water_grid.gd _velocities), as shares.
#   godot --headless --path . --script res://tools/flow_probe.gd -- [--x=53350 --z=68400 --half=200]

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const WaterGridScript := preload("res://src/worldgen/runtime/water_grid.gd")


func _init() -> void:
	var world: String = "res://worlds/base_world"
	var cx: float = 53350.0
	var cz: float = 68400.0
	var half: float = 200.0

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--x="):
			cx = float(argument.trim_prefix("--x="))
		elif argument.begins_with("--z="):
			cz = float(argument.trim_prefix("--z="))
		elif argument.begins_with("--half="):
			half = float(argument.trim_prefix("--half="))

	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var data = generator.get_tile(Vector2i(int(floor(cx / generator.tile_size_m)), int(floor(cz / generator.tile_size_m))))
	var spacing: float = data.spacing_m
	var count: int = int(2.0 * half / spacing)
	var low_i: int = int((cx - half - data.x0) / spacing)
	var low_j: int = int((cz - half - data.z0) / spacing)
	var levels: PackedFloat32Array = PackedFloat32Array()
	levels.resize(count * count)

	for j in range(count):
		for i in range(count):
			levels[j * count + i] = data.sim_levels[(low_j + j) * data.samples + low_i + i]

	var origin: Vector2 = Vector2(data.x0 + float(low_i) * spacing, data.z0 + float(low_j) * spacing)
	var vel: PackedFloat32Array = WaterGridScript._velocities(generator, data, origin, count, spacing, levels)
	var wet: int = 0
	var bins: Array = [0, 0, 0, 0, 0]

	for k in range(count * count):
		if is_nan(levels[k]):
			continue

		wet += 1
		var speed: float = Vector2(vel[k * 2], vel[k * 2 + 1]).length()
		bins[0 if speed < 0.02 else (1 if speed < 0.15 else (2 if speed < 0.5 else (3 if speed < 1.5 else 4)))] += 1

	print("%d wet cells in the %.0f m block around %.0f,%.0f: still (under 0.02 m/s) %.0f%%, 0.02 to 0.15 %.0f%%, 0.15 to 0.5 %.0f%%, 0.5 to 1.5 %.0f%%, over 1.5 m/s %.0f%%" % [wet, 2.0 * half, cx, cz, 100.0 * bins[0] / maxf(wet, 1), 100.0 * bins[1] / maxf(wet, 1), 100.0 * bins[2] / maxf(wet, 1), 100.0 * bins[3] / maxf(wet, 1), 100.0 * bins[4] / maxf(wet, 1)])
	quit(0)
