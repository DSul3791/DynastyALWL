extends SceneTree

# A tile file is read once however many threads ask for it at the same moment (Dave's PC log, 4 Nov 2026: tile (3, 3) was read
# 11 times at once by the server's block workers, 3.2 to 4 s each, while the client joined).
#   godot --headless --path . --script res://src/worldgen/tools/test_tile_load_once.gd

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")

const ASKERS := 8

var failures: int = 0
var _got: Array = []
var _got_mutex: Mutex = Mutex.new()


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var world_dir: String = "res://worlds/base_world"
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world_dir + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world_dir + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())

	if settings == null or rules.is_empty() or not errors.is_empty():
		print("FAIL world data does not load: ", errors)
		quit(1)
		return

	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world_dir + "/tiles")
	var coord: Vector2i = Vector2i(3, 3)
	var started: int = Time.get_ticks_msec()
	var threads: Array = []

	for n in range(ASKERS):   # real threads, so the askers overlap even where the worker pool is small
		var thread: Thread = Thread.new()
		thread.start(func():
			var data = generator.get_tile(coord)
			_got_mutex.lock()
			_got.append(data)
			_got_mutex.unlock())
		threads.append(thread)

	for thread in threads:
		thread.wait_to_finish()

	var spent: int = Time.get_ticks_msec() - started
	check(_got.size() == ASKERS and _got.all(func(d): return d != null and not d.placeholder), "every asker got the real tile")
	check(generator.tile_reads == 1, "the tile file was read once, not once per asker (%d reads, %d ms)" % [generator.tile_reads, spent])
	check(_got.all(func(d): return d == _got[0]), "every asker got the same tile data")
	check(generator.tile_load_waits >= 1, "the other askers waited for the first read (%d waited)" % generator.tile_load_waits)
	var again = generator.get_tile(coord)
	check(again == _got[0] and generator.tile_reads == 1, "a later ask is served from memory")
	print("test_tile_load_once: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)
