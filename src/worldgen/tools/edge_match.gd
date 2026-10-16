extends SceneTree

# Compares the shared edges of neighboring tile files (spec Section 4b).
#
#   godot --headless --path . --script res://src/worldgen/tools/edge_match.gd
#
# Options (after "--"):
#   --world=DIR   world folder (default res://worlds/base_world)
#   --dir=DIR     folder holding the tile files (default <world>/tiles)
#
# Every tile file found is compared with its east and south neighbors (the
# world wraps in both directions). A neighbor with no file is an ocean
# placeholder, so the shared edge must be ocean. Prints one line per
# pair and map, and exits 1 when a hard limit is broken.

const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileFileScript := preload("res://src/worldgen/tile/tile_file.gd")
const EdgeCompareScript := preload("res://src/worldgen/tile/edge_compare.gd")


func _init() -> void:
	var world_dir: String = "res://worlds/base_world"
	var directory: String = ""

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--world="):
			world_dir = argument.trim_prefix("--world=")
		elif argument.begins_with("--dir="):
			directory = argument.trim_prefix("--dir=")

	if directory == "":
		directory = world_dir + "/tiles"

	quit(_run(world_dir, directory))


func _run(world_dir: String, directory: String) -> int:
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world_dir + "/world.json", errors)

	if settings == null:
		push_error("\n".join(errors))
		return 1

	var plan_kinds: Dictionary = {}
	var plan: Variant = JSON.parse_string(FileAccess.get_file_as_string(world_dir + "/plan/tile_plan.json"))

	if typeof(plan) == TYPE_DICTIONARY:
		for entry in plan["cells"]:
			plan_kinds["%d,%d" % [int(entry["x"]), int(entry["z"])]] = str(entry["kind"])

	var tiles: Array = []

	for name in DirAccess.get_files_at(directory):
		if name.begins_with("tile_") and name.ends_with(".tile"):
			var parts: PackedStringArray = name.trim_prefix("tile_").trim_suffix(".tile").split("_")
			tiles.append(Vector2i(int(parts[0]), int(parts[1])))

	if tiles.is_empty():
		push_error("No tile files in %s" % directory)
		return 1

	var failures: int = 0
	var compared: int = 0

	for tile in tiles:
		for direction in ["east", "south"]:
			var neighbor: Vector2i = settings.wrap_tile(tile.x + (1 if direction == "east" else 0), tile.y + (1 if direction == "south" else 0))
			var path_a: String = "%s/tile_%d_%d.tile" % [directory, tile.x, tile.y]
			var path_b: String = "%s/tile_%d_%d.tile" % [directory, neighbor.x, neighbor.y]
			var neighbor_kind: String = str(plan_kinds.get("%d,%d" % [neighbor.x, neighbor.y], "ocean"))

			if not FileAccess.file_exists(path_b) and not ["ocean", "shallows", "trench"].has(neighbor_kind):
				print("%s -> %s (%s): neighbor is a %s tile that is not baked yet, skipped" % [str(tile), str(neighbor), direction, neighbor_kind])
				continue

			var report: Dictionary = EdgeCompareScript.compare(path_a, path_b if FileAccess.file_exists(path_b) else "", direction)
			compared += 1
			print("%s -> %s (%s)" % [str(tile), str(neighbor), direction])

			for line in report["lines"]:
				print("   " + line)

			failures += int(report["failures"])

	print("")
	print("%d edges compared, %d hard failures" % [compared, failures])
	return 1 if failures > 0 else 0
