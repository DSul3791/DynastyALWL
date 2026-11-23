extends SceneTree

# The generator's last step: builds the server's ground blocks for chosen tiles ahead of time, on a fast machine (Dave's PC), so the
# server only serves them (Dave 23 Nov 2026: "the server doesnt build anything it just serves the prebuilt stuff up to the clients";
# "all needs to be part of the generator. make it a priority"). Plan: docs/design/SERVER_SCALE.md, "Prebuilt ground for the nine tiles".
#
#   godot --headless --path . --script res://src/worldgen/tools/prebuild_ground.gd -- --tiles=3_4 --out=C:/dynasty_ground
#
# Options (after "--"):
#   --tiles=A_B,C_D  tiles to build ("nine" = the nine baked tiles); default 3_4, the starter tile
#   --out=DIR        the ground pack: a server store folder holding only generated ground (made if missing). A build that stops part way
#                    goes on from where it was when run again with the same --out: blocks already in it are skipped.
#   --threads=N      worker threads (default: processors minus one)
#   --lods=A,B,..    detail levels (default 0-6, every level the client asks for)
#   --area=X,Z,M     only the M-metre square with corner X,Z (world metres) inside the tiles: for tests and quick looks
#
# Only blocks that hold the surface are built, one block above and below it (caves deeper down are still made by the server on first
# visit). The pack's terrain_version.txt names the terrain version and tile files it was made from; ground_pack.gd's install refuses a
# pack made from other tiles. Prints "prebuild_ground: N%" lines as it goes and a "prebuild_ground: DONE" line at the end.

const StoreScript := preload("res://src/stream/server_block_store.gd")
const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const PackScript := preload("res://src/stream/ground_pack.gd")

const NINE := ["2_3", "2_4", "2_5", "3_3", "3_4", "3_5", "4_3", "4_4", "4_5"]
const COLUMNS_PER_TAKE := 32           # columns a worker takes at once
const FLUSH_EVERY_S := 60.0            # the pack is written to disk this often, so a stop loses little

var store
var generator
var _parts: Array = []                 # [lod, bx0, bz0, width, depth, first index] per tile and level
var _total: int = 0                    # columns in all
var _next: int = 0
var _mutex: Mutex = Mutex.new()
var _columns_done: int = 0
var _made: int = 0
var _skipped: int = 0


func _init() -> void:
	var tiles: Array = ["3_4"]
	var out_dir: String = ""
	var threads: int = maxi(OS.get_processor_count() - 1, 1)
	var lods: Array = [0, 1, 2, 3, 4, 5, 6]
	var area: Array = []

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tiles="):
			var text: String = argument.trim_prefix("--tiles=")
			tiles = NINE.duplicate() if text == "nine" else Array(text.split(",", false))
		elif argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
		elif argument.begins_with("--threads="):
			threads = maxi(int(argument.trim_prefix("--threads=")), 1)
		elif argument.begins_with("--lods="):
			lods = []

			for part in argument.trim_prefix("--lods=").split(",", false):
				lods.append(int(part))
		elif argument.begins_with("--area="):
			for part in argument.trim_prefix("--area=").split(",", false):
				area.append(float(part))

	if out_dir == "":
		push_error("prebuild_ground: --out=DIR is needed")
		quit(1)
		return

	quit(_run(tiles, out_dir, threads, lods, area))


func _run(tiles: Array, out_dir: String, threads: int, lods: Array, area: Array) -> int:
	var world_dir: String = "res://worlds/base_world"
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world_dir + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world_dir + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())

	if settings == null or rules.is_empty() or not errors.is_empty():
		push_error("\n".join(errors))
		return 1

	generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world_dir + "/tiles")
	store = StoreScript.new()
	var problem: String = store.setup(generator, out_dir)

	if problem != "":
		push_error(problem)
		return 1

	var tile_m: float = generator.tile_size_m

	for name in tiles:
		var parts: PackedStringArray = String(name).split("_")

		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
			push_error("prebuild_ground: %s is not a tile (want X_Z, like 3_4)" % name)
			return 1

		var tile: Vector2i = Vector2i(int(parts[0]), int(parts[1]))

		if not FileAccess.file_exists(world_dir + "/tiles/tile_%d_%d.tile" % [tile.x, tile.y]):
			push_error("prebuild_ground: tile %s is not baked (no worlds/base_world/tiles/tile_%d_%d.tile)" % [name, tile.x, tile.y])
			return 1

		generator.surface_height((float(tile.x) + 0.5) * tile_m, (float(tile.y) + 0.5) * tile_m)   # reads the tile here, before the workers
		var x0: float = float(tile.x) * tile_m
		var z0: float = float(tile.y) * tile_m
		var x1: float = x0 + tile_m
		var z1: float = z0 + tile_m

		if area.size() == 3:
			x0 = maxf(x0, area[0])
			z0 = maxf(z0, area[1])
			x1 = minf(x1, area[0] + area[2])
			z1 = minf(z1, area[1] + area[2])

		if x1 <= x0 or z1 <= z0:
			continue

		for lod in lods:
			var block_m: float = float(StoreScript.BLOCK_SIZE << int(lod))
			var bx0: int = int(floor(x0 / block_m))
			var bz0: int = int(floor(z0 / block_m))
			var width: int = int(floor((x1 - 0.01) / block_m)) - bx0 + 1
			var depth: int = int(floor((z1 - 0.01) / block_m)) - bz0 + 1
			_parts.append([int(lod), bx0, bz0, width, depth, _total])
			_total += width * depth

	print("prebuild_ground: tiles %s, levels %s, %d columns, %d threads, pack %s (%s)" % [",".join(tiles), str(lods), _total, threads, ProjectSettings.globalize_path(out_dir), store.tiles_stamp])
	var started: int = Time.get_ticks_msec()
	var tasks: Array = []

	for n in range(threads):
		tasks.append(WorkerThreadPool.add_task(_work))

	var last_flush: int = started
	var last_percent: int = -1
	var last_print: int = started - 10000

	while true:
		_mutex.lock()
		var done: int = _columns_done
		var made: int = _made
		var skipped: int = _skipped
		_mutex.unlock()
		var percent: int = int(100.0 * float(done) / float(maxi(_total, 1)))
		var now: int = Time.get_ticks_msec()

		if percent != last_percent and (now - last_print >= 10000 or done >= _total):   # at most one line each 10 s
			last_percent = percent
			last_print = now
			var spent_s: float = float(now - started) / 1000.0
			var left_s: float = spent_s / float(done) * float(_total - done) if done > 0 else 0.0
			print("prebuild_ground: %d%% (%d of %d columns), %d blocks made, %d already there, %.0f s, about %.0f min left" % [percent, done, _total, made, skipped, spent_s, left_s / 60.0])

		if done >= _total:
			break

		if float(now - last_flush) / 1000.0 >= FLUSH_EVERY_S:
			store.flush()
			last_flush = now

		OS.delay_msec(500)

	for id in tasks:
		WorkerThreadPool.wait_for_task_completion(id)

	store.flush()
	var seconds: float = float(Time.get_ticks_msec() - started) / 1000.0
	var info: Dictionary = PackScript.describe(out_dir)
	PackScript.write_note(out_dir, {"tiles": tiles, "lods": lods, "area": area, "blocks_made": _made, "blocks_already_there": _skipped, "seconds": snappedf(seconds, 0.1)})
	print("prebuild_ground: DONE %d blocks made, %d already there, in %.0f s; pack %.1f MB at %s" % [_made, _skipped, seconds, float(info.get("bytes", 0)) / 1048576.0, ProjectSettings.globalize_path(out_dir)])
	return 0


func _work() -> void:
	while true:
		_mutex.lock()
		var first: int = _next
		_next += COLUMNS_PER_TAKE
		_mutex.unlock()

		if first >= _total:
			return

		var made: int = 0
		var skipped: int = 0
		var last: int = mini(first + COLUMNS_PER_TAKE, _total)

		for index in range(first, last):
			var counts: Vector2i = _build_column(index)
			made += counts.x
			skipped += counts.y

		_mutex.lock()
		_columns_done += last - first
		_made += made
		_skipped += skipped
		_mutex.unlock()


# Builds the surface blocks of one column; returns (made, already there).
func _build_column(index: int) -> Vector2i:
	var part: Array = _parts[0]

	for candidate in _parts:
		if int(candidate[5]) <= index:
			part = candidate

	var lod: int = int(part[0])
	var local: int = index - int(part[5])
	var bx: int = int(part[1]) + local % int(part[3])
	@warning_ignore("integer_division")
	var bz: int = int(part[2]) + local / int(part[3])
	var range_y: Vector2i = surface_blocks(generator, bx, bz, lod)
	var result: Vector2i = Vector2i.ZERO

	for by in range(range_y.x, range_y.y + 1):
		if store.ensure_block(Vector3i(bx, by, bz), lod):
			result.x += 1
		else:
			result.y += 1

	return result


# The block rows (lowest, highest) that hold the surface of column (bx, bz) at this level, with one row of margin each side. The surface
# is sampled on a grid across the block (finer for the big far blocks, whose hills a few samples would miss).
static func surface_blocks(terrain, bx: int, bz: int, lod: int) -> Vector2i:
	var block_m: float = float(StoreScript.BLOCK_SIZE << lod)
	var steps: int = 2 if lod <= 2 else 6
	var low: float = INF
	var high: float = -INF

	for i in range(steps + 1):
		for j in range(steps + 1):
			var h = terrain.surface_height((float(bx) + 0.99 * float(i) / float(steps)) * block_m, (float(bz) + 0.99 * float(j) / float(steps)) * block_m)

			if h == null or is_nan(float(h)):
				continue

			low = minf(low, float(h))
			high = maxf(high, float(h))

	if low == INF:
		return Vector2i(0, -1)   # nothing to build

	return Vector2i(int(floor(low / block_m)) - 1, int(floor(high / block_m)) + 1)
