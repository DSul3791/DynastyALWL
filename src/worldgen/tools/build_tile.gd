extends SceneTree

# Builds one tile's 8 m height map and a relief picture of it. Run with:
#
#   godot --headless --path . --script res://src/worldgen/tools/build_tile.gd -- --tile=3,4
#
# Options (after "--"):
#   --tile=X,Z   tile coordinate (default 3,4)
#   --cell=N     world elevation cell size in meters (default from sketch_rules.json)
#   --world=DIR  world folder (default res://worlds/base_world)
#
# Needs plan/world_sketch.json. Writes plan/tile_X_Z_relief.png.

const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const SketchScript := preload("res://src/worldgen/sketch/world_sketch.gd")
const ElevationScript := preload("res://src/worldgen/sketch/world_elevation.gd")
const ReliefScript := preload("res://src/worldgen/sketch/relief_preview.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TilePreviewScript := preload("res://src/worldgen/tile/tile_preview.gd")


func _init() -> void:
	var tile: Vector2i = Vector2i(3, 4)
	var cell: float = 0.0
	var world_dir: String = "res://worlds/base_world"

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tile="):
			var parts: PackedStringArray = argument.trim_prefix("--tile=").split(",")
			tile = Vector2i(int(parts[0]), int(parts[1]))
		elif argument.begins_with("--cell="):
			cell = float(argument.trim_prefix("--cell="))
		elif argument.begins_with("--world="):
			world_dir = argument.trim_prefix("--world=")

	quit(_run(world_dir, tile, cell))


func _run(world_dir: String, tile: Vector2i, cell: float) -> int:
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world_dir + "/world.json", errors)
	var rules: Dictionary = SketchScript.load_rules(world_dir + "/plan/sketch_rules.json", errors)
	var tile_rules: Dictionary = TileHeightScript.load_rules(world_dir + "/plan/tile_rules.json", errors)

	if settings == null or rules.is_empty() or tile_rules.is_empty():
		push_error("\n".join(errors))
		return 1

	var sketch: Variant = JSON.parse_string(FileAccess.get_file_as_string(world_dir + "/plan/world_sketch.json"))

	if typeof(sketch) != TYPE_DICTIONARY:
		push_error("world_sketch.json is missing or invalid (run build_sketch.gd first)")
		return 1

	var started: int = Time.get_ticks_msec()
	var elevation = ElevationScript.new()
	elevation.build(settings, rules, sketch, cell)
	print("World elevation built in %d ms" % (Time.get_ticks_msec() - started))

	started = Time.get_ticks_msec()
	var height = TileHeightScript.new()
	height.setup(settings, elevation, tile_rules)
	height.build(tile)
	print("Tile %s height map %d x %d built in %d ms" % [
		str(tile), height.samples, height.samples, Time.get_ticks_msec() - started
	])

	started = Time.get_ticks_msec()
	var image: Image = TilePreviewScript.render(settings, height, tile)
	var base: String = "%s/plan/tile_%d_%d" % [world_dir, tile.x, tile.y]
	image.save_png(base + "_relief.png")
	print("Relief drawn in %d ms" % (Time.get_ticks_msec() - started))
	return 0
