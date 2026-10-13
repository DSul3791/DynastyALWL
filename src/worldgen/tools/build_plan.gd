extends SceneTree

# Builds the tile matrix for the whole world, a text summary and the
# whole-world preview image. Run with:
#
#   godot --headless --path . --script res://src/worldgen/tools/build_plan.gd
#
# Options (after "--"):
#   --fresh      ignore the saved matrix and start from scratch
#   --world=DIR  world folder (default res://worlds/base_world)
#
# Locked tiles, and tiles already baked, are kept from the saved matrix.
# The output files are written to <world>/plan/.

const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const RandomizerScript := preload("res://src/worldgen/matrix/matrix_randomizer.gd")
const TileMatrixScript := preload("res://src/worldgen/matrix/tile_matrix.gd")
const SummaryScript := preload("res://src/worldgen/matrix/matrix_summary.gd")
const PreviewScript := preload("res://src/worldgen/matrix/matrix_preview.gd")


func _init() -> void:
	var fresh: bool = false
	var world_dir: String = "res://worlds/base_world"

	for argument in OS.get_cmdline_user_args():
		if argument == "--fresh":
			fresh = true
		elif argument.begins_with("--world="):
			world_dir = argument.trim_prefix("--world=")

	quit(_run(world_dir, fresh))


func _run(world_dir: String, fresh: bool) -> int:
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(
		world_dir + "/world.json", errors
	)

	if settings == null:
		push_error("\n".join(errors))
		return 1

	var rules: Dictionary = RandomizerScript.load_rules(
		world_dir + "/plan/matrix_rules.json", errors
	)

	if rules.is_empty():
		push_error("\n".join(errors))
		return 1

	var matrix_path: String = world_dir + "/plan/tile_matrix.json"
	var existing = null

	if not fresh and FileAccess.file_exists(matrix_path):
		existing = TileMatrixScript.load_file(matrix_path, errors)

		if existing == null:
			push_error("\n".join(errors))
			return 1

	var started: int = Time.get_ticks_msec()
	var randomizer = RandomizerScript.new()
	randomizer.setup(settings, rules)
	var matrix = randomizer.generate(existing)
	print("Matrix built in %d ms" % (Time.get_ticks_msec() - started))

	if not matrix.save(matrix_path):
		return 1

	var summary: String = SummaryScript.build(settings, rules, matrix)
	var summary_file: FileAccess = FileAccess.open(
		world_dir + "/plan/matrix_summary.txt", FileAccess.WRITE
	)
	summary_file.store_string(summary)
	summary_file.close()
	print(summary)

	started = Time.get_ticks_msec()
	var image: Image = PreviewScript.render(settings, matrix)
	var image_path: String = world_dir + "/plan/world_plan.png"
	var save_error: int = image.save_png(image_path)
	print("Preview drawn in %d ms: %s" % [Time.get_ticks_msec() - started, image_path])

	return 0 if save_error == OK else 1
