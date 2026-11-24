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
#   --processes=N    run N copies of this tool side by side, each on its share of the columns and chunks with one thread, then join
#                    their results into --out (default 1; auto = the machine's threads minus two, at most 8). The generator gains little from threads inside one copy but scales
#                    across copies (cloud, 23 Nov 2026: 1 thread 380 blocks/s, 3 threads 540, 3 copies of 1 thread 1,000). Each copy
#                    works in --out/parts/part_K (its log in log.txt there); a stop goes on where it was if run again with the same N
#                    (blocks already in a part are skipped). The parts are deleted once joined, so a run after a finished one builds
#                    everything again. While joining, the parts and the pack both stand: about twice the pack's size on disk.
#   --stop-after=S   with --processes: stop every copy after S seconds and print "prebuild_ground: STOPPED after S s: N blocks made,
#                    R blocks/s" (a timing try: Dave 24 Nov 2026, "run the 10 test for 2 minutes ... then stop"); nothing is joined
#   --area=X,Z,M     only the M-metre square with corner X,Z (world metres) inside the tiles: for tests and quick looks
#   --plants=0       ground only (default 1: the trees and plants of every 256 m chunk too, in the pack's flora_pack/ folder,
#                    src/stream/flora_pack.gd; a tile whose plants file is already there for these game files is skipped; with
#                    --area the plants file is marked as part of a tile, which no server uses)
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
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")
const FloraPackScript := preload("res://src/stream/flora_pack.gd")
const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")

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
var placer
var _plants_s: float = 0.0
var _chunks: Array = []                # plant chunks of the tile being built (home coordinates)
var _chunk_next: int = 0
var _chunk_done: int = 0
var _lists: Dictionary = {}            # chunk -> [packed full list, packed trees-only list]
var _part: int = 0                     # this copy's share (--part=K/N, set by a parent run with --processes)
var _part_count: int = 1
var _own_total: int = 0                # columns in this copy's share
var _tiles_stamp: String = ""
var _out_dir: String = ""
var _stop_after: float = 0.0           # --stop-after (parent only)


func _init() -> void:
	var tiles: Array = ["3_4"]
	var out_dir: String = ""
	var threads: int = maxi(OS.get_processor_count() - 1, 1)
	var lods: Array = [0, 1, 2, 3, 4, 5, 6]
	var area: Array = []
	var plants: bool = true
	var processes: int = 1
	var stop_after: float = 0.0

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
		elif argument.begins_with("--stop-after="):
			stop_after = float(argument.trim_prefix("--stop-after="))
		elif argument == "--processes=auto":
			processes = clampi(OS.get_processor_count() - 2, 1, 8)   # leaves two of the machine's threads free; about 0.8 GB each
		elif argument.begins_with("--processes="):
			processes = maxi(int(argument.trim_prefix("--processes=")), 1)
		elif argument.begins_with("--part="):
			var share: PackedStringArray = argument.trim_prefix("--part=").split("/")
			_part = int(share[0])
			_part_count = maxi(int(share[1]), 1)
		elif argument == "--plants=0":
			plants = false
		elif argument.begins_with("--area="):
			for part in argument.trim_prefix("--area=").split(",", false):
				area.append(float(part))

	if out_dir == "":
		push_error("prebuild_ground: --out=DIR is needed")
		quit(1)
		return

	_stop_after = stop_after
	quit(_run(tiles, out_dir, threads, lods, area, plants, processes))


func _run(tiles: Array, out_dir: String, threads: int, lods: Array, area: Array, plants: bool, processes: int) -> int:
	_out_dir = out_dir
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(out_dir + "/" + PackScript.NOTE))   # the note marks a finished build: none while this one runs
	store = StoreScript.new()
	var problem: String = store.setup(generator, out_dir)

	if problem != "":
		push_error(problem)
		return 1

	_tiles_stamp = store.tiles_stamp
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

	_own_total = 0

	for first in range(0, _total, COLUMNS_PER_TAKE):
		if _owns_take(first, _part, _part_count):
			_own_total += mini(COLUMNS_PER_TAKE, _total - first)

	if processes > 1 and _part_count == 1:
		return _run_parent(tiles, out_dir, lods, area, plants, processes)

	print("prebuild_ground: tiles %s, levels %s, %d columns%s, %d threads, pack %s (%s)" % [",".join(tiles), str(lods), _own_total, (" (share %d of %d)" % [_part + 1, _part_count]) if _part_count > 1 else "", threads, ProjectSettings.globalize_path(out_dir), store.tiles_stamp])
	var started: int = Time.get_ticks_msec()
	var tasks: Array = []

	for n in range(threads):
		tasks.append(WorkerThreadPool.add_task(_work, true))   # high priority: low-priority tasks get only a share of the pool (threading/worker_pool/low_priority_thread_ratio)

	var last_flush: int = started
	var last_percent: int = -1
	var last_print: int = started - 10000
	var last_progress: int = 0

	while true:
		_mutex.lock()
		var done: int = _columns_done
		var made: int = _made
		var skipped: int = _skipped
		_mutex.unlock()
		var percent: int = int(100.0 * float(done) / float(maxi(_own_total, 1)))
		var now: int = Time.get_ticks_msec()

		if percent != last_percent and (now - last_print >= 10000 or done >= _own_total):   # at most one line each 10 s
			last_percent = percent
			last_print = now
			var spent_s: float = float(now - started) / 1000.0
			var left_s: float = spent_s / float(done) * float(_own_total - done) if done > 0 else 0.0
			print("prebuild_ground: %d%% (%d of %d columns), %d blocks made, %d already there, %.0f s, about %.0f min left" % [percent, done, _own_total, made, skipped, spent_s, left_s / 60.0])

		if now - last_progress >= 2000 or done >= _own_total:
			last_progress = now
			_write_progress("ground", done, _own_total, made)

		if done >= _own_total:
			break

		if tasks.all(func(id): return WorkerThreadPool.is_task_completed(id)) and _done_now() < _own_total:   # read again: the last ones may just have ended
			push_error("prebuild_ground: the workers stopped with %d of %d columns done (a script error above?); run it again to go on" % [done, _own_total])
			store.flush()
			return 1

		if float(now - last_flush) / 1000.0 >= FLUSH_EVERY_S:
			store.flush()
			last_flush = now

		OS.delay_msec(500)

	for id in tasks:
		WorkerThreadPool.wait_for_task_completion(id)

	store.flush()
	var seconds: float = float(Time.get_ticks_msec() - started) / 1000.0

	if generator.failed_tiles > 0 or store.bad_blocks > 0:
		push_error("prebuild_ground: %d tile reads failed and %d blocks failed the check, so some blocks were not saved; run it again to fill them (no finished note written)" % [generator.failed_tiles, store.bad_blocks])
		return 1

	if plants:
		placer = PlacerScript.new()
		placer.setup(generator, tables, rules)
		var plants_started: int = Time.get_ticks_msec()
		var plants_error: int = _build_plants(tiles, out_dir, threads, area)
		_plants_s = float(Time.get_ticks_msec() - plants_started) / 1000.0

		if plants_error != 0:
			return plants_error

	var info: Dictionary = PackScript.describe(out_dir)
	PackScript.write_note(out_dir, {"tiles": tiles, "lods": lods, "area": area, "blocks_made": _made, "blocks_already_there": _skipped, "seconds": snappedf(seconds, 0.1), "plants_seconds": snappedf(_plants_s, 0.1)})
	print("prebuild_ground: DONE %d blocks made, %d already there; ground %.0f s, plants %.0f s; pack %.1f MB at %s" % [_made, _skipped, seconds, _plants_s, float(info.get("bytes", 0)) / 1048576.0, ProjectSettings.globalize_path(out_dir)])
	return 0


# The trees and plants of each tile into flora_pack/tile_X_Z.fpk (flora_pack.gd).
func _build_plants(tiles: Array, out_dir: String, threads: int, area: Array) -> int:
	var print_text: String = FloraPackScript.fingerprint(_tiles_stamp)

	if area.size() == 3:
		print_text += " area"   # part of a tile only: never taken for the whole tile (here or by a server)

	print_text += share_mark(_part, _part_count, area)
	var folder: String = out_dir + "/" + FloraPackScript.FOLDER
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var tile_m: float = generator.tile_size_m
	var chunk_m: float = placer.chunk_m

	for name in tiles:
		var parts: PackedStringArray = String(name).split("_")
		var tile: Vector2i = Vector2i(int(parts[0]), int(parts[1]))
		var path: String = folder + "/" + FloraPackScript.file_name(tile)

		if FloraPackScript.print_of(path) == print_text:
			print("prebuild_ground: plants of tile %s already built" % name)
			continue

		var x0: float = float(tile.x) * tile_m
		var z0: float = float(tile.y) * tile_m
		var x1: float = x0 + tile_m
		var z1: float = z0 + tile_m

		if area.size() == 3:
			x0 = maxf(x0, area[0])
			z0 = maxf(z0, area[1])
			x1 = minf(x1, area[0] + area[2])
			z1 = minf(z1, area[1] + area[2])

		_chunks = []
		_lists = {}
		_chunk_next = 0
		_chunk_done = 0

		var counted: int = 0

		for cz in range(int(floor(z0 / chunk_m)), int(floor((z1 - 0.01) / chunk_m)) + 1):
			for cx in range(int(floor(x0 / chunk_m)), int(floor((x1 - 0.01) / chunk_m)) + 1):
				if counted % _part_count == _part:   # this copy's share
					_chunks.append(placer.normalize(Vector2i(cx, cz)))

				counted += 1

		var started: int = Time.get_ticks_msec()
		var last_print: int = started
		var tasks: Array = []

		for n in range(threads):
			tasks.append(WorkerThreadPool.add_task(_place_work, true))

		while true:
			_mutex.lock()
			var done: int = _chunk_done
			_mutex.unlock()

			if done >= _chunks.size():
				break

			if tasks.all(func(id): return WorkerThreadPool.is_task_completed(id)):
				_mutex.lock()
				done = _chunk_done
				_mutex.unlock()

				if done < _chunks.size():
					push_error("prebuild_ground: the plant workers stopped with %d of %d chunks of tile %s done (a script error above?)" % [done, _chunks.size(), name])
					return 1

			var now: int = Time.get_ticks_msec()

			if now - last_print >= 10000:
				last_print = now
				var spent_s: float = float(now - started) / 1000.0
				print("prebuild_ground: plants of tile %s: %d of %d chunks, %.0f s, about %.0f min left" % [name, done, _chunks.size(), spent_s, spent_s / float(maxi(done, 1)) * float(_chunks.size() - done) / 60.0])
				_write_progress("plants " + String(name), done, _chunks.size(), _made)

			OS.delay_msec(500)

		for id in tasks:
			WorkerThreadPool.wait_for_task_completion(id)

		if generator.failed_tiles > 0:
			push_error("prebuild_ground: a tile read failed while placing plants; run it again")
			return 1

		if not FloraPackScript.write_tile(path, print_text, _lists):
			push_error("prebuild_ground: cannot write %s" % path)
			return 1

		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		print("prebuild_ground: plants of tile %s: %d chunks in %.0f s, %.1f MB" % [name, _chunks.size(), float(Time.get_ticks_msec() - started) / 1000.0, float(file.get_length()) / 1048576.0])
		_lists = {}

	return 0


func _place_work() -> void:
	while true:
		_mutex.lock()
		var index: int = _chunk_next
		_chunk_next += 1
		_mutex.unlock()

		if index >= _chunks.size():
			return

		var home: Vector2i = _chunks[index]
		var full: Array = FloraPackScript.pack_list(placer.chunk_items(home, false))
		var trees: Array = FloraPackScript.pack_list(placer.chunk_items(home, true))
		_mutex.lock()
		_lists[home] = [full, trees]
		_chunk_done += 1
		_mutex.unlock()


func _done_now() -> int:
	_mutex.lock()
	var done: int = _columns_done
	_mutex.unlock()
	return done


# Marks a copy's plants file with its share and slice, so a run again with another count or slice never takes it (only that copy's chunks).
static func share_mark(part: int, count: int, area: Array) -> String:
	return "" if count <= 1 else " share %d/%d %s" % [part, count, str(area)]


# A take of COLUMNS_PER_TAKE columns starting at column `first` belongs to share `part` of `count`.
static func _owns_take(first: int, part: int, count: int) -> bool:
	@warning_ignore("integer_division")
	return (first / COLUMNS_PER_TAKE) % count == part


func _work() -> void:
	while true:
		_mutex.lock()
		var first: int = _next
		_next += COLUMNS_PER_TAKE
		_mutex.unlock()

		if first >= _total:
			return

		if not _owns_take(first, _part, _part_count):
			continue

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


# Column `index` as (bx, bz, lod).
func _column(index: int) -> Vector3i:
	var part: Array = _parts[0]

	for candidate in _parts:
		if int(candidate[5]) <= index:
			part = candidate

	var local: int = index - int(part[5])
	@warning_ignore("integer_division")
	return Vector3i(int(part[1]) + local % int(part[3]), int(part[2]) + local / int(part[3]), int(part[0]))


# Builds the surface blocks of one column; returns (made, already there).
func _build_column(index: int) -> Vector2i:
	var column: Vector3i = _column(index)
	var range_y: Vector2i = surface_blocks(generator, column.x, column.y, column.z)
	var result: Vector2i = Vector2i.ZERO

	for by in range(range_y.x, range_y.y + 1):
		if store.ensure_block(Vector3i(column.x, by, column.y), column.z):
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


# A copy's progress for its parent: "phase done total blocks_made".
func _write_progress(phase: String, done: int, total: int, made: int) -> void:
	if _part_count <= 1:
		return

	var file: FileAccess = FileAccess.open(_out_dir + "/progress.txt", FileAccess.WRITE)

	if file != null:
		file.store_string("%s %d %d %d" % [phase.replace(" ", "_"), done, total, made])
		file.close()


static func _progress_of(parts_dir: String, k: int) -> PackedStringArray:
	var path: String = parts_dir + "/part_%d/progress.txt" % k
	return (FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "starting 0 1 0").split(" ")


# --processes: start the copies, show their progress, then join their ground and plants into out_dir.
func _run_parent(tiles: Array, out_dir: String, lods: Array, area: Array, plants: bool, processes: int) -> int:
	var started: int = Time.get_ticks_msec()
	var parts_dir: String = out_dir + "/parts"
	var godot: String = OS.get_executable_path()
	var project: String = ProjectSettings.globalize_path("res://")
	var pids: Array = []
	print("prebuild_ground: tiles %s, levels %s, %d columns, %d copies of one thread each, pack %s (%s)" % [",".join(tiles), str(lods), _total, processes, ProjectSettings.globalize_path(out_dir), _tiles_stamp])

	for k in range(processes):
		var part_dir: String = ProjectSettings.globalize_path(parts_dir + "/part_%d" % k)
		DirAccess.make_dir_recursive_absolute(part_dir)
		DirAccess.remove_absolute(part_dir + "/progress.txt")
		var args: PackedStringArray = PackedStringArray(["--headless", "--log-file", part_dir + "/log.txt", "--path", project, "--script", "res://src/worldgen/tools/prebuild_ground.gd", "--",
			"--tiles=" + ",".join(tiles), "--lods=" + ",".join(lods.map(func(l): return str(l))), "--threads=1", "--part=%d/%d" % [k, processes], "--out=" + part_dir])

		if area.size() == 3:
			args.append("--area=%s,%s,%s" % [str(area[0]), str(area[1]), str(area[2])])

		if not plants:
			args.append("--plants=0")

		var pid: int = OS.create_process(godot, args)

		if pid <= 0:
			push_error("prebuild_ground: could not start copy %d (%s)" % [k, godot])

			for started_pid in pids:
				OS.kill(started_pid)

			return 1

		pids.append(pid)

	var last_print: int = 0

	while pids.any(func(pid): return OS.is_process_running(pid)):
		var now: int = Time.get_ticks_msec()

		if pids.any(func(pid): return not OS.is_process_running(pid) and OS.get_process_exit_code(pid) != 0):
			push_error("prebuild_ground: a copy stopped with an error (logs in %s/part_K/log.txt); the others are stopped too; run the same command again to go on" % ProjectSettings.globalize_path(parts_dir))

			for pid in pids:
				if OS.is_process_running(pid):
					OS.kill(pid)

			return 1

		if now - last_print >= 10000:
			last_print = now
			var lines: PackedStringArray = PackedStringArray()

			for k in range(processes):
				var bits: PackedStringArray = _progress_of(parts_dir, k)
				lines.append("%s %d%%" % [bits[0].replace("_", " "), int(100.0 * float(bits[1]) / float(maxi(int(bits[2]), 1)))] if bits.size() == 4 else "?")

			print("prebuild_ground: %.0f s; copies: %s" % [float(now - started) / 1000.0, ", ".join(lines)])

		if _stop_after > 0.0 and float(now - started) / 1000.0 >= _stop_after:
			var made: int = 0

			for k in range(processes):
				var bits: PackedStringArray = _progress_of(parts_dir, k)
				made += int(bits[3]) if bits.size() == 4 else 0

			for pid in pids:
				if OS.is_process_running(pid):
					OS.kill(pid)

			var spent: float = float(Time.get_ticks_msec() - started) / 1000.0
			print("prebuild_ground: STOPPED after %.0f s: %d blocks made by %d copies, %.0f blocks/s (as last reported by the copies, at most 2 s old; the first seconds are each copy reading the tiles)" % [spent, made, processes, float(made) / maxf(spent, 0.001)])
			return 0

		OS.delay_msec(1000)

	var build_s: float = float(Time.get_ticks_msec() - started) / 1000.0
	var plants_s: float = 0.0

	for k in range(processes):
		var part_dir: String = parts_dir + "/part_%d" % k
		var note: Dictionary = PackScript.describe(part_dir)["note"]

		if note.is_empty() or OS.get_process_exit_code(pids[k]) != 0:
			push_error("prebuild_ground: copy %d did not finish (its log: %s/log.txt); run the same command again to go on" % [k, ProjectSettings.globalize_path(part_dir)])
			return 1

		if PackScript.version_of(part_dir) != PackScript.version_of(out_dir):
			push_error("prebuild_ground: copy %d was made from other tiles (%s)" % [k, PackScript.version_of(part_dir)])
			return 1

		plants_s = maxf(plants_s, float(note.get("plants_seconds", 0.0)))

	print("prebuild_ground: copies finished in %.0f s; joining them" % build_s)
	var join_started: int = Time.get_ticks_msec()
	var generation: int = PackScript.generation_of(out_dir)
	var main_file: String = PackScript.ground_file(out_dir, generation)
	store.flush()
	store = null   # the joined file is written below without the store
	var main_stream: VoxelStreamSQLite = VoxelStreamSQLite.new()
	main_stream.database_path = ProjectSettings.globalize_path(main_file)
	var buffer: VoxelBuffer = Layout.make_buffer(StoreScript.BLOCK_SIZE)
	var copied: int = 0

	for k in range(processes):
		var part_dir: String = parts_dir + "/part_%d" % k
		var part_stream: VoxelStreamSQLite = VoxelStreamSQLite.new()
		part_stream.database_path = ProjectSettings.globalize_path(PackScript.ground_file(part_dir, PackScript.generation_of(part_dir)))

		for first in range(0, _total, COLUMNS_PER_TAKE):
			if not _owns_take(first, k, processes):
				continue

			for index in range(first, mini(first + COLUMNS_PER_TAKE, _total)):
				var column: Vector3i = _column(index)
				var range_y: Vector2i = surface_blocks(generator, column.x, column.y, column.z)

				for by in range(range_y.x, range_y.y + 1):
					var block: Vector3i = Vector3i(column.x, by, column.y)

					if part_stream.load_voxel_block(buffer, block, column.z) == VoxelStream.RESULT_BLOCK_FOUND:
						main_stream.save_voxel_block(buffer, block, column.z)
						copied += 1

		main_stream.flush()
		print("prebuild_ground: joined copy %d (%d blocks so far, %.0f s)" % [k, copied, float(Time.get_ticks_msec() - join_started) / 1000.0])

	main_stream.flush()
	main_stream = null

	if plants:
		var print_text: String = FloraPackScript.fingerprint(_tiles_stamp) + (" area" if area.size() == 3 else "")
		var folder: String = out_dir + "/" + FloraPackScript.FOLDER
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))

		for name in tiles:
			var parts: PackedStringArray = String(name).split("_")
			var file_name: String = FloraPackScript.file_name(Vector2i(int(parts[0]), int(parts[1])))
			var lists: Dictionary = {}

			for k in range(processes):
				var part_lists = FloraPackScript.read_lists(parts_dir + "/part_%d/%s/%s" % [k, FloraPackScript.FOLDER, file_name], print_text + share_mark(k, processes, area))

				if part_lists == null:
					push_error("prebuild_ground: copy %d has no plants file for tile %s; run the same command again" % [k, name])
					return 1

				lists.merge(part_lists)

			if not FloraPackScript.write_tile(folder + "/" + file_name, print_text, lists):
				push_error("prebuild_ground: cannot write the plants of tile %s" % name)
				return 1

	var join_s: float = float(Time.get_ticks_msec() - join_started) / 1000.0
	_remove_tree(ProjectSettings.globalize_path(parts_dir))
	var info: Dictionary = PackScript.describe(out_dir)
	PackScript.write_note(out_dir, {"tiles": tiles, "lods": lods, "area": area, "blocks_made": copied, "processes": processes, "seconds": snappedf(build_s, 0.1), "plants_seconds": snappedf(plants_s, 0.1), "join_seconds": snappedf(join_s, 0.1)})
	print("prebuild_ground: DONE %d blocks; %d copies %.0f s (plants %.0f s of it), joining %.0f s; pack %.1f MB at %s" % [copied, processes, build_s, plants_s, join_s, float(info.get("bytes", 0)) / 1048576.0, ProjectSettings.globalize_path(out_dir)])
	return 0


static func _remove_tree(path: String) -> void:
	for sub in DirAccess.get_directories_at(path):
		_remove_tree(path + "/" + sub)

	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path + "/" + file)

	DirAccess.remove_absolute(path)
