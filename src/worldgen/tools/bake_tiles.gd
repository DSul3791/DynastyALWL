extends SceneTree

# Bakes tiles to tile files. Run with:
#
#   godot --headless --path . --script res://src/worldgen/tools/bake_tiles.gd -- --tiles=3,4;3,3
#
# Options (after "--"):
#   --tiles=X,Z;X,Z   tiles to bake (default 3,4)
#   --world=DIR       world folder (default res://worlds/base_world)
#   --out=DIR         folder for the files (default <world>/tiles)
#
# Needs plan/world_sketch.json and plan/tile_plan.json.

const TileBakerScript := preload("res://src/worldgen/tile/tile_baker.gd")


func _init() -> void:
	var tiles: Array = [Vector2i(3, 4)]
	var world_dir: String = "res://worlds/base_world"
	var out_dir: String = ""

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tiles="):
			tiles = []

			for pair in argument.trim_prefix("--tiles=").split(";"):
				var parts: PackedStringArray = pair.split(",")
				tiles.append(Vector2i(int(parts[0]), int(parts[1])))
		elif argument.begins_with("--world="):
			world_dir = argument.trim_prefix("--world=")
		elif argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")

	quit(_run(world_dir, out_dir, tiles))


func _run(world_dir: String, out_dir: String, tiles: Array) -> int:
	var baker = TileBakerScript.new()
	var started: int = Time.get_ticks_msec()
	var problem: String = baker.setup(world_dir)

	if problem != "":
		push_error(problem)
		return 1

	print("Setup (world elevation, wet air, river network, tables) in %d ms; %d river cells in %d chains" % [
		Time.get_ticks_msec() - started, baker.river_network.river_cells, baker.river_network.chains.size()
	])

	for tile in tiles:
		started = Time.get_ticks_msec()
		var result: Dictionary = baker.bake_to_file(tile, out_dir)

		if not result["ok"]:
			push_error("Tile %s: %s" % [str(tile), result["error"]])
			return 1

		print("Tile %s baked in %.1f s: %.2f MB, stages %s -> %s" % [
			str(tile), float(Time.get_ticks_msec() - started) / 1000.0, float(result["bytes"]) / 1048576.0,
			str(result["timings"]), result["path"]
		])

	return 0
