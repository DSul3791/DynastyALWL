extends SceneTree

# Pre-builds (generates and saves) the terrain blocks around the surface of
# one square of a baked tile and reports time and file size, so the cost of
# pre-building a whole tile can be worked out. Run with:
#
#   godot --headless --path . --script res://src/worldgen/tools/prebuild_blocks.gd -- --x=53000 --z=69000 --size=512 --lods=0,1,2,3
#
# Options (after "--"):
#   --x=X --z=Z    corner of the square, world metres (default: middle of tile 3,4)
#   --size=M       square side in metres (default 512)
#   --lods=A,B,..  detail levels to build (default 0,1,2,3)
#   --threads=N    worker threads (default: processors minus one)
#   --world=DIR    world folder (default res://worlds/base_world)
#   --store=DIR    where the blocks are saved (default user://prebuild_test, wiped first)
#
# Only blocks that hold the surface are built (one block above and below).

const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const StoreScript := preload("res://src/stream/server_block_store.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")

var store
var jobs: Array = []        # [block Vector3i, lod]
var _next: int = 0
var _mutex: Mutex = Mutex.new()
var _done: int = 0


func _init() -> void:
	var corner: Vector2 = Vector2(53000.0, 69000.0)
	var size: float = 512.0
	var lods: Array = [0, 1, 2, 3]
	var world_dir: String = "res://worlds/base_world"
	var store_dir: String = "user://prebuild_test"
	var threads: int = maxi(OS.get_processor_count() - 1, 1)

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--x="):
			corner.x = float(argument.trim_prefix("--x="))
		elif argument.begins_with("--z="):
			corner.y = float(argument.trim_prefix("--z="))
		elif argument.begins_with("--size="):
			size = float(argument.trim_prefix("--size="))
		elif argument.begins_with("--lods="):
			lods = []

			for part in argument.trim_prefix("--lods=").split(","):
				lods.append(int(part))
		elif argument.begins_with("--threads="):
			threads = maxi(int(argument.trim_prefix("--threads=")), 1)
		elif argument.begins_with("--world="):
			world_dir = argument.trim_prefix("--world=")
		elif argument.begins_with("--store="):
			store_dir = argument.trim_prefix("--store=")

	quit(_run(world_dir, store_dir, corner, size, lods, threads))


func _run(world_dir: String, store_dir: String, corner: Vector2, size: float, lods: Array, threads: int) -> int:
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world_dir + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world_dir + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())

	if settings == null or rules.is_empty() or not errors.is_empty():
		push_error("\n".join(errors))
		return 1

	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world_dir + "/tiles")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store_dir + "/generated.sqlite"))
	store = StoreScript.new()
	var problem: String = store.setup(generator, store_dir)

	if problem != "":
		push_error(problem)
		return 1

	# Work out which blocks hold the surface.
	for lod in lods:
		var block_m: float = float(StoreScript.BLOCK_SIZE << lod)
		var bx0: int = int(floor(corner.x / block_m))
		var bx1: int = int(floor((corner.x + size - 0.01) / block_m))
		var bz0: int = int(floor(corner.y / block_m))
		var bz1: int = int(floor((corner.y + size - 0.01) / block_m))
		var count: int = 0

		for bz in range(bz0, bz1 + 1):
			for bx in range(bx0, bx1 + 1):
				var low: float = INF
				var high: float = -INF

				for k in range(5):
					var sx: float = (float(bx) + float(k % 2) * 0.99 + (0.5 if k == 4 else 0.0) * 0.0) * block_m
					var sz: float = (float(bz) + float(k / 2 % 2) * 0.99) * block_m

					if k == 4:
						sx = (float(bx) + 0.5) * block_m
						sz = (float(bz) + 0.5) * block_m

					var h: float = generator.surface_height(sx, sz)
					low = minf(low, h)
					high = maxf(high, h)

				var by0: int = int(floor(low / block_m)) - 1
				var by1: int = int(floor(high / block_m)) + 1

				for by in range(by0, by1 + 1):
					jobs.append([Vector3i(bx, by, bz), lod])
					count += 1

		print("prebuild: LOD %d: %d blocks planned" % [lod, count])

	var started: int = Time.get_ticks_msec()
	var tasks: Array = []

	for n in range(threads):
		tasks.append(WorkerThreadPool.add_task(_work))

	for id in tasks:
		WorkerThreadPool.wait_for_task_completion(id)

	store.flush()
	var seconds: float = float(Time.get_ticks_msec() - started) / 1000.0
	var path: String = ProjectSettings.globalize_path(store_dir + "/generated.sqlite")
	var bytes: int = FileAccess.open(path, FileAccess.READ).get_length() if FileAccess.file_exists(path) else 0
	var area_km2: float = size * size / 1.0e6
	print("prebuild: %d blocks in %.1f s on %d threads (%.0f blocks/s); file %.1f MB; %.2f km2 square" % [jobs.size(), seconds, threads, float(jobs.size()) / maxf(seconds, 0.001), float(bytes) / 1048576.0, area_km2])
	print("prebuild: per km2 -> %.0f s, %.1f MB;  whole tile (235 km2) -> %.1f hours, %.1f GB" % [seconds / area_km2, float(bytes) / 1048576.0 / area_km2, seconds / area_km2 * 235.9 / 3600.0, float(bytes) / 1073741824.0 / area_km2 * 235.9])
	return 0


func _work() -> void:
	while true:
		_mutex.lock()
		var index: int = _next
		_next += 1
		_mutex.unlock()

		if index >= jobs.size():
			return

		var job: Array = jobs[index]
		store.block_bytes(job[0], job[1])
