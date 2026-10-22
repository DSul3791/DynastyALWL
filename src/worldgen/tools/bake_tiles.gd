extends SceneTree

# Bakes tiles to tile files. Run with:
#
#   godot --headless --path . --script res://src/worldgen/tools/bake_tiles.gd -- --tiles=3,4;3,3
#
# Options (after "--"):
#   --tiles=X,Z;X,Z   tiles to bake (default 3,4)
#   --world=DIR       world folder (default res://worlds/base_world)
#   --out=DIR         folder for the files (default <world>/tiles)
#   --threads=N       bake N tiles at the same time (default 1; each tile is baked whole on one thread, so the
#                     files are byte-identical to a one-thread bake)
#
# Needs plan/world_sketch.json and plan/tile_plan.json.

const TileBakerScript := preload("res://src/worldgen/tile/tile_baker.gd")


const LOCK_NAME := "baking.lock"   # in the tiles folder while a bake runs (read by server_block_store.gd)


func _init() -> void:
	var tiles: Array = [Vector2i(3, 4)]
	var world_dir: String = "res://worlds/base_world"
	var out_dir: String = ""
	var threads: int = 1

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
		elif argument.begins_with("--threads="):
			threads = maxi(int(argument.trim_prefix("--threads=")), 1)

	# Owner (2026-10-19): a running game leaves the tiles alone until the whole bake is done
	# (the server waits while this lock is there, then reloads the ground once).
	var lock_path: String = (out_dir if out_dir != "" else world_dir + "/tiles") + "/" + LOCK_NAME
	_touch(lock_path)
	var code: int = _run(world_dir, out_dir, tiles, lock_path, threads)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(lock_path))
	quit(code)


func _touch(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)

	if file != null:
		file.store_string("baking since %s\n" % Time.get_datetime_string_from_system())
		file.close()


func _run(world_dir: String, out_dir: String, tiles: Array, lock_path: String, threads: int) -> int:
	var baker = TileBakerScript.new()
	var started: int = Time.get_ticks_msec()
	var problem: String = baker.setup(world_dir)

	if problem != "":
		push_error(problem)
		return 1

	print("Setup (world elevation, wet air, river network, tables) in %d ms; %d river cells in %d chains" % [
		Time.get_ticks_msec() - started, baker.river_network.river_cells, baker.river_network.chains.size()
	])

	if threads > 1 and tiles.size() > 1:
		return _run_threads(baker, out_dir, tiles, lock_path, threads)

	for tile in tiles:
		_touch(lock_path)
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


# Tiles do not depend on each other, so up to `threads` of them bake at once. Results are
# printed in tile order whatever order they finish in.
func _run_threads(baker, out_dir: String, tiles: Array, lock_path: String, threads: int) -> int:
	var results: Array = []
	results.resize(tiles.size())
	var next: Array = [0]
	var mutex: Mutex = Mutex.new()
	var started: int = Time.get_ticks_msec()
	var workers: Array = []

	for worker in range(mini(threads, tiles.size())):
		var thread: Thread = Thread.new()
		thread.start(_worker.bind(baker, out_dir, tiles, results, next, mutex))
		workers.append(thread)

	while true:
		OS.delay_msec(2000)
		_touch(lock_path)
		var alive: bool = false

		for thread in workers:
			if thread.is_alive():
				alive = true

		if not alive:
			break

	for thread in workers:
		thread.wait_to_finish()

	var code: int = 0

	for index in range(tiles.size()):
		var result: Dictionary = results[index]

		if not result["ok"]:
			push_error("Tile %s: %s" % [str(tiles[index]), result["error"]])
			code = 1
			continue

		print("Tile %s: %.2f MB, stages %s -> %s" % [str(tiles[index]), float(result["bytes"]) / 1048576.0, str(result["timings"]), result["path"]])

	print("%d tiles on %d threads in %.1f s" % [tiles.size(), threads, float(Time.get_ticks_msec() - started) / 1000.0])
	return code


func _worker(baker, out_dir: String, tiles: Array, results: Array, next: Array, mutex: Mutex) -> void:
	while true:
		mutex.lock()
		var index: int = next[0]
		next[0] = index + 1
		mutex.unlock()

		if index >= tiles.size():
			return

		results[index] = baker.bake_to_file(tiles[index], out_dir)
