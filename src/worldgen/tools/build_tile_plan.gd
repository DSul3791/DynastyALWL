extends SceneTree

# Builds the tile plan from the world sketch. Run with:
#
#   godot --headless --path . --script res://src/worldgen/tools/build_tile_plan.gd
#
# Options (after "--"):
#   --fresh      ignore the saved plan (locked and baked tiles are otherwise kept)
#   --cell=N     elevation cell size in meters (default from sketch_rules.json)
#   --world=DIR  world folder (default res://worlds/base_world)
#
# Needs plan/world_sketch.json (run build_sketch.gd first). Writes
# plan/tile_plan.json, plan/island_list.json and plan/tile_plan_summary.txt.

const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const SketchScript := preload("res://src/worldgen/sketch/world_sketch.gd")
const ElevationScript := preload("res://src/worldgen/sketch/world_elevation.gd")
const TileMatrixScript := preload("res://src/worldgen/matrix/tile_matrix.gd")
const TilePlanScript := preload("res://src/worldgen/plan/tile_plan.gd")
const SummaryScript := preload("res://src/worldgen/plan/tile_plan_summary.gd")


func _init() -> void:
	var fresh: bool = false
	var cell: float = 0.0
	var world_dir: String = "res://worlds/base_world"

	for argument in OS.get_cmdline_user_args():
		if argument == "--fresh":
			fresh = true
		elif argument.begins_with("--cell="):
			cell = float(argument.trim_prefix("--cell="))
		elif argument.begins_with("--world="):
			world_dir = argument.trim_prefix("--world=")

	quit(_run(world_dir, fresh, cell))


func _run(world_dir: String, fresh: bool, cell: float) -> int:
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world_dir + "/world.json", errors)

	if settings == null:
		push_error("\n".join(errors))
		return 1

	var rules: Dictionary = SketchScript.load_rules(world_dir + "/plan/sketch_rules.json", errors)
	var sketch_path: String = world_dir + "/plan/world_sketch.json"

	if rules.is_empty() or not FileAccess.file_exists(sketch_path):
		push_error("Missing sketch rules or world_sketch.json (run build_sketch.gd first)")
		return 1

	var sketch: Variant = JSON.parse_string(FileAccess.get_file_as_string(sketch_path))

	if typeof(sketch) != TYPE_DICTIONARY:
		push_error("world_sketch.json is not valid")
		return 1

	var plan_path: String = world_dir + "/plan/tile_plan.json"
	var existing = null

	if not fresh and FileAccess.file_exists(plan_path):
		existing = TileMatrixScript.load_file(plan_path, errors)

	var started: int = Time.get_ticks_msec()
	var elevation = ElevationScript.new()
	elevation.build(settings, rules, sketch, cell)
	print("Elevation built in %d ms" % (Time.get_ticks_msec() - started))

	started = Time.get_ticks_msec()
	var plan = TilePlanScript.new()
	plan.setup(settings, sketch, elevation)
	var matrix = plan.build(existing)
	print("Tile plan built in %d ms" % (Time.get_ticks_msec() - started))

	if not matrix.save(plan_path):
		return 1

	_write_text(world_dir + "/plan/island_list.json", plan.islands_json())
	var summary: String = SummaryScript.build(settings, plan, matrix)
	_write_text(world_dir + "/plan/tile_plan_summary.txt", summary)
	print(summary)
	return 0


func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
