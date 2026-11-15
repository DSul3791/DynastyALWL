extends SceneTree

# How often and how slowly the server places the flora chunks round a player who joins at the spawn (coordinator 15 Nov 2026: cover chunk
# jobs took 5 to 56 s each on David4 against about 0.5 s alone). Read only; one Godot instance, many threads.
#
#   godot --headless --path . --script res://src/worldgen/tools/flora_pool_profile.gd -- [--workers=11]
#
# Phase "alone": each of the 9 chunks round the spawn placed once, full and trees only, one at a time.
# Phase "join": what terrain_server starts at a join, all at once on a fresh ServerFlora: the warm thread (_warm_flora: items_of on the 9),
# a WorkerThreadPool task per chunk for the cover index (_warm_cover_chunk: chunk_bytes on the 9, full when that list is known), and --workers streaming threads
# (_worker_loop: chunk_bytes full for the 9, trees only for the 16 round them). Prints each job's time and how many times the placer
# placed each chunk and form ("PLACED <chunk> full=<n> trees=<n>").

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const ServerFloraScript := preload("res://src/stream/server_flora.gd")


class Counted extends "res://src/worldgen/runtime/flora_placer.gd":
	var placed: Dictionary = {}   # Vector3i (chunk, 1 full / 0 trees) -> times
	var count_mutex: Mutex = Mutex.new()

	func chunk_items(chunk: Vector2i, trees_only: bool = false) -> Dictionary:
		count_mutex.lock()
		var key: Vector3i = Vector3i(chunk.x, chunk.y, 0 if trees_only else 1)
		placed[key] = int(placed.get(key, 0)) + 1
		count_mutex.unlock()
		return super.chunk_items(chunk, trees_only)


var flora
var jobs: Array = []           # [kind, chunk, ms]
var jobs_mutex: Mutex = Mutex.new()
var queue: Array = []          # [chunk, full] for the streaming threads
var queue_mutex: Mutex = Mutex.new()


func _note(kind: String, chunk: Vector2i, t0: int) -> void:
	jobs_mutex.lock()
	jobs.append([kind, chunk, int((Time.get_ticks_usec() - t0) / 1000.0)])
	jobs_mutex.unlock()


func _warm(chunks: Array) -> void:
	for c in chunks:
		var t0: int = Time.get_ticks_usec()
		flora.items_of(c)
		_note("warm_full", c, t0)


func _cover(c: Vector2i) -> void:
	var t0: int = Time.get_ticks_usec()
	var full: bool = flora.has_method("full_known") and flora.full_known(c)   # as terrain_server._warm_cover_chunk asks
	flora.chunk_bytes(c, full)
	_note("cover_full" if full else "cover_trees", c, t0)


func _stream() -> void:
	while true:
		queue_mutex.lock()
		var next: Array = queue.pop_front() if not queue.is_empty() else []
		queue_mutex.unlock()

		if next.is_empty():
			return

		var t0: int = Time.get_ticks_usec()
		flora.chunk_bytes(next[0], next[1])
		_note("stream_full" if next[1] else "stream_trees", next[0], t0)


func _init() -> void:
	var workers: int = 11

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--workers="):
			workers = maxi(int(argument.trim_prefix("--workers=")), 1)

	var world: String = "res://worlds/base_world"
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var placer = Counted.new()
	placer.setup(generator, tables, rules)
	var spawn_xz: Vector2 = load("res://src/shared/spawn_point.gd").OVERRIDE
	var home: Vector2i = placer.normalize(placer.chunk_of(spawn_xz.x, spawn_xz.y))
	var inner: Array = []
	var ring: Array = []

	for dz in range(-2, 3):
		for dx in range(-2, 3):
			(inner if absi(dx) <= 1 and absi(dz) <= 1 else ring).append(placer.normalize(home + Vector2i(dx, dz)))

	generator.get_tile(generator.tile_of(spawn_xz.x, spawn_xz.y))
	print("PROFILE errors=%d workers=%d cpu_threads=%d spawn_chunk=%s" % [errors.size(), workers, OS.get_processor_count(), str(home)])

	# Alone.
	var alone_full: int = 0
	var alone_trees: int = 0

	for c in inner:
		var t0: int = Time.get_ticks_usec()
		placer.chunk_items(c)
		var t1: int = Time.get_ticks_usec()
		placer.chunk_items(c, true)
		var t2: int = Time.get_ticks_usec()
		alone_full += int((t1 - t0) / 1000.0)
		alone_trees += int((t2 - t1) / 1000.0)
		print("ALONE %s full_ms=%d trees_ms=%d" % [str(c), int((t1 - t0) / 1000.0), int((t2 - t1) / 1000.0)])

	print("ALONE total full_ms=%d trees_ms=%d (9 chunks each)" % [alone_full, alone_trees])
	placer.placed.clear()

	# Join.
	flora = ServerFloraScript.new()
	flora.setup(placer, "user://flora_pool_profile")

	for c in inner:
		queue.append([c, true])

	for c in ring:
		queue.append([c, false])

	var start: int = Time.get_ticks_usec()
	var warm: Thread = Thread.new()
	warm.start(_warm.bind(inner), Thread.PRIORITY_LOW)
	var tasks: Array = []

	for c in inner:
		tasks.append(WorkerThreadPool.add_task(_cover.bind(c)))

	var threads: Array = []

	for n in range(workers):
		var t: Thread = Thread.new()
		t.start(_stream, Thread.PRIORITY_LOW)
		threads.append(t)

	warm.wait_to_finish()

	for t in threads:
		t.wait_to_finish()

	for task in tasks:
		WorkerThreadPool.wait_for_task_completion(task)

	var wall: int = int((Time.get_ticks_usec() - start) / 1000.0)
	jobs.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[2] > b[2]))
	var by_kind: Dictionary = {}

	for j in jobs:
		print("JOB %s %s ms=%d" % [j[0], str(j[1]), j[2]])
		var row: Array = by_kind.get(j[0], [0, 0, 0])
		row[0] += 1
		row[1] += j[2]
		row[2] = maxi(row[2], j[2])
		by_kind[j[0]] = row

	for kind in by_kind:
		print("KIND %s jobs=%d total_ms=%d max_ms=%d" % [kind, by_kind[kind][0], by_kind[kind][1], by_kind[kind][2]])

	var placements: int = 0

	for c in inner + ring:
		var full_n: int = int(placer.placed.get(Vector3i(c.x, c.y, 1), 0))
		var trees_n: int = int(placer.placed.get(Vector3i(c.x, c.y, 0), 0))
		placements += full_n + trees_n
		print("PLACED %s full=%d trees=%d" % [str(c), full_n, trees_n])

	print("JOIN wall_ms=%d placements=%d (each of the 25 chunks needs 1)" % [wall, placements])
	print("PROFILE DONE")
	quit(0)
