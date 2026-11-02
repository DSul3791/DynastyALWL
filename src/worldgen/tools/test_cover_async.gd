extends SceneTree

# The join stall must not come back (Tyler, 2 Nov 2026): the server's _cover_at on a flora chunk that is not made yet
# returns at once (the chunk is made by a worker thread, nine chunks on the main thread froze the server 4 to 8 s), and
# once the worker has made the chunks the answer reads the real canopy.
#   godot --headless --path . --script res://src/worldgen/tools/test_cover_async.gd

const ServerScript := preload("res://scenes/terrain_server/terrain_server.gd")
const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")
const FloraStoreScript := preload("res://src/stream/server_flora.gd")

var failures: int = 0


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
	var placer = PlacerScript.new()
	placer.setup(generator, tables, rules)
	var dir: String = "user://test_cover_async"
	DirAccess.make_dir_recursive_absolute(dir)
	var flora = FloraStoreScript.new()
	flora.setup(placer, dir)
	var server = ServerScript.new()
	server.flora = flora

	# The starter tile (3,4) centre-ish; any land point works, the chunks are simply not made yet.
	var point := Vector3(3.0 * 15360.0 + 7000.0, 40.0, 4.0 * 15360.0 + 7000.0)
	var home: Vector2i = placer.normalize(Vector2i(int(floor(point.x / placer.chunk_m)), int(floor(point.z / placer.chunk_m))))
	check(not flora.chunk_made(home), "the chunk under the point is not made before the first ask")
	var started: int = Time.get_ticks_usec()
	var first: float = server._cover_at(point)
	var took_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	check(took_ms < 50.0, "_cover_at on an unmade chunk returns at once (%.1f ms, limit 50)" % took_ms)
	check(first == 0.0, "until the chunk is made the spot reads open (%s)" % str(first))
	check(server._cover_warming.size() > 0, "a worker was asked to make the chunks (%d warming)" % server._cover_warming.size())

	# The worker finishes; the deferred "done" calls run on the main loop (so pump frames).
	var waited: int = 0

	while (not flora.chunk_made(home) or not server._cover_warming.is_empty()) and waited < 600:
		await process_frame
		OS.delay_msec(50)
		waited += 1

	check(flora.chunk_made(home), "the worker made the chunk (after %d polls)" % waited)
	check(server._cover_warming.is_empty(), "the warming list is empty again")
	started = Time.get_ticks_usec()
	var second: float = server._cover_at(point)
	took_ms = float(Time.get_ticks_usec() - started) / 1000.0
	check(took_ms < 50.0, "_cover_at on a made chunk is fast (%.1f ms)" % took_ms)
	check(second >= 0.0, "the answer after the chunk is made is a real cover value (%s)" % str(second))

	# Ground truth: a point under a tree crown of this chunk reads covered once made.
	var items: Dictionary = flora.items_of(home)
	var tested: bool = false

	for n in range(items["ids"].size()):
		var species: Dictionary = placer.species_of(int(items["ids"][n]))

		if species.is_empty() or int(species["kind"]) != PlacerScript.KIND_TREE or float(items["heights"][n]) < float(species["height_ref"]) * 0.9:
			continue

		var p: Vector3 = items["positions"][n]
		var got: float = server._cover_at(Vector3(p.x, p.y + 2.0, p.z))
		check(got >= 1.0, "a point under a grown tree's crown is covered once the chunk is made (%s)" % str(got))
		tested = true
		break

	check(tested, "the chunk has a grown tree to test against")
	print("Test done: %d fail" % failures)
	quit(1 if failures > 0 else 0)
