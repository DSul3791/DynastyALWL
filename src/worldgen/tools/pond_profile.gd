extends SceneTree

# Prints the ground profile (tile heights and finest ground) through a spot, west to east.
#   godot --headless --path . --script res://src/worldgen/tools/pond_profile.gd -- --at=X,Z [--half=200] [--step=8]

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")


func _init() -> void:
	var at: Vector2 = Vector2.ZERO
	var half: float = 200.0
	var step: float = 8.0

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--at="):
			var parts: PackedStringArray = argument.trim_prefix("--at=").split(",")
			at = Vector2(float(parts[0]), float(parts[1]))
		elif argument.begins_with("--half="):
			half = float(argument.trim_prefix("--half="))
		elif argument.begins_with("--step="):
			step = float(argument.trim_prefix("--step="))

	var world_dir: String = "res://worlds/base_world"
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world_dir + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world_dir + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world_dir + "/tiles")
	var data = generator.get_tile(generator.tile_of(at.x, at.y))
	var offset: float = -half

	while offset <= half:
		var x: float = at.x + offset
		var k: int = data.nearest(x, at.y)
		print("x %8.1f  tile %7.1f  fine %7.1f  class %d  surface %7.1f" % [x, data.heights[k], generator.surface_height(x, at.y, 0), data.water_class[k], data.water_surface[k]])
		offset += step

	quit(0)
