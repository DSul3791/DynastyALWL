extends SceneTree

# Which kind of work stops scaling when many threads run it at once (15 Nov 2026: on David4 a flora chunk took 30 to 60 times longer with
# 11 placing threads than alone, while Dave's PC scaled). Each case runs the same fixed work on every thread; with perfect scaling the wall
# time stays flat as threads are added (up to the core count). Read only; one Godot instance.
#
#   godot --headless --path . --script res://src/worldgen/tools/thread_scale_probe.gd -- [--threads=1,2,4,6,11] [--ops=200000]
#
# Cases:
#   math          local float arithmetic only (the baseline: no engine call, no shared data)
#   own_call      a script method on an object of the thread's own
#   shared_call   the same method on one object every thread shares
#   tile_height   TileTerrainData.height_at on the spawn tile every thread shares (what flora placing does most)
#   shared_noise  FastNoiseLite.get_noise_2d on one noise every thread shares (the terrain detail noise)
#   own_noise     the same on a noise of the thread's own
#   shared_dict   reading a String and a float from one Dictionary every thread shares (the species tables)
#   alloc         a new small Array and Dictionary per op (the memory allocator)
#   new_object    RandomNumberGenerator.new() per op (the object database)
# Prints "SCALE <case> threads=<n> wall_ms=<ms> x_alone=<wall / wall at 1 thread>".

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")


class Box:
	var k: float = 1.0001

	func step(x: float) -> float:
		return x * k + 0.5


var ops: int = 200000
var shared_box: Box = Box.new()
var shared_noise: FastNoiseLite
var shared_dict: Dictionary = {"kind": "tree", "name": "scots_pine", "height": 22.0, "spacing": 4.5}
var tile = null
var origin: Vector2 = Vector2.ZERO


func _make_noise() -> FastNoiseLite:
	var n: FastNoiseLite = FastNoiseLite.new()
	n.seed = 1234
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 4
	n.frequency = 1.0 / 600.0
	return n


func _run(kind: String, index: int) -> void:
	var acc: float = 0.0
	var mine: Box = Box.new()
	var my_noise: FastNoiseLite = _make_noise()
	var step: float = 0.37 + 0.01 * float(index)

	match kind:
		"math":
			var x: float = 1.0

			for i in range(ops):
				x = x * 1.0001 + 0.5
				acc += x - floor(x)

		"own_call":
			for i in range(ops):
				acc += mine.step(float(i))

		"shared_call":
			for i in range(ops):
				acc += shared_box.step(float(i))

		"tile_height":
			for i in range(ops):
				acc += tile.height_at(origin.x + fposmod(float(i) * step, 250.0), origin.y + fposmod(float(i) * 0.71, 250.0))

		"shared_noise":
			for i in range(ops):
				acc += shared_noise.get_noise_2d(float(i) * step, float(i) * 0.71)

		"own_noise":
			for i in range(ops):
				acc += my_noise.get_noise_2d(float(i) * step, float(i) * 0.71)

		"shared_dict":
			for i in range(ops):
				var s: String = shared_dict["kind"]
				acc += float(shared_dict["height"]) + float(s.length())

		"alloc":
			for i in range(ops):
				var a: Array = [i, acc]
				var d: Dictionary = {"i": i}
				acc += float(a.size() + d.size())

		"new_object":
			for i in range(ops):
				var r: RandomNumberGenerator = RandomNumberGenerator.new()
				acc += float(r.seed & 1)

	if acc == 0.123456:   # keep the loop
		print(acc)


func _wall(kind: String, threads: int) -> int:
	var t0: int = Time.get_ticks_usec()
	var running: Array = []

	for n in range(threads):
		var t: Thread = Thread.new()
		t.start(_run.bind(kind, n))
		running.append(t)

	for t in running:
		t.wait_to_finish()

	return int((Time.get_ticks_usec() - t0) / 1000.0)


func _init() -> void:
	var counts: Array = [1, 2, 4, 6, 11]
	var cases: Array = ["math", "own_call", "shared_call", "tile_height", "shared_noise", "own_noise", "shared_dict", "alloc", "new_object"]

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--threads="):
			counts.clear()

			for part in argument.trim_prefix("--threads=").split(","):
				counts.append(maxi(int(part), 1))
		elif argument.begins_with("--ops="):
			ops = maxi(int(argument.trim_prefix("--ops=")), 1000)
		elif argument.begins_with("--cases="):
			cases = Array(argument.trim_prefix("--cases=").split(","))

	var world: String = "res://worlds/base_world"
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var spawn_xz: Vector2 = load("res://src/shared/spawn_point.gd").OVERRIDE
	tile = generator.get_tile(generator.tile_of(spawn_xz.x, spawn_xz.y))
	origin = spawn_xz
	shared_noise = _make_noise()
	print("PROBE errors=%d cpu_threads=%d ops=%d debug_build=%s version=%s" % [errors.size(), OS.get_processor_count(), ops,
		str(OS.is_debug_build()), Engine.get_version_info()["string"]])

	for kind in cases:
		var alone: int = 0

		for threads in counts:
			var wall: int = _wall(kind, threads)

			if threads == counts[0]:
				alone = maxi(wall, 1)

			print("SCALE %s threads=%d wall_ms=%d x_alone=%.1f" % [kind, threads, wall, float(wall) / float(alone)])

	print("PROBE DONE")
	quit(0)
