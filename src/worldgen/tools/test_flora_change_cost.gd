extends SceneTree

# A planted bush, a new sapling or a felled tree re-packs its flora chunk without placing it again (Dave 15 Nov 2026: the server placed the
# whole chunk again on its main thread, about 1.8 s a dense chunk on his PC, at every planting).
#   godot --headless --path . --script res://src/worldgen/tools/test_flora_change_cost.gd
# 1. After a change the re-sent chunk (trees only, then full, as terrain_server._flora_changed asks) costs under a quarter of making it the first time.
# 2. The re-sent bytes are the bytes a server that never held the chunk makes (same removals, same sapling).
# 3. clear_memory (new tiles) forgets the placed lists too.

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")
const ServerFloraScript := preload("res://src/stream/server_flora.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var world: String = "res://worlds/base_world"
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	check(settings != null and errors.is_empty(), "world, rules and tables load")

	if settings == null or not errors.is_empty():
		quit(1)
		return

	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var placer = PlacerScript.new()
	placer.setup(generator, tables, rules)
	var spawn_xz: Vector2 = load("res://src/shared/spawn_point.gd").OVERRIDE
	var chunk: Vector2i = placer.normalize(placer.chunk_of(spawn_xz.x, spawn_xz.y))
	var tree_species: int = -1

	for sid in placer._by_id:
		if int(placer._by_id[sid]["kind"]) == PlacerScript.KIND_TREE:
			tree_species = int(sid)
			break

	# A sapling (server_items.dynamic_items numbers it species << 16 | 0xFFFF - slot) that the change brings, and a felled tree.
	var origin: Vector2 = placer.chunk_origin(chunk)
	var sapling: Dictionary = {"ids": PackedInt32Array([(tree_species << 16) | 0xFFFF]), "positions": PackedVector3Array([Vector3(origin.x + 100.0, 5.0, origin.y + 100.0)]),
		"heights": PackedFloat32Array([0.6]), "yaws": PackedFloat32Array([1.0])}
	var planted: Array = [false]
	var dynamic: Callable = func(home: Vector2i) -> Dictionary: return sapling if planted[0] and home == chunk else {}

	var flora = ServerFloraScript.new()
	flora.setup(placer, "user://test_flora_change_cost")
	flora.dynamic = dynamic
	generator.get_tile(generator.tile_of(origin.x + 1.0, origin.y + 1.0))   # the tile load is not the placing
	var t0: int = Time.get_ticks_usec()
	flora.chunk_bytes(chunk, false)
	flora.chunk_bytes(chunk, true)
	var first_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	var felled: int = int(flora.items_of(chunk)["ids"][0])
	check(flora.cut(chunk, felled), "a tree of the chunk is felled")

	# The change, as terrain_server._flora_changed handles it: forget the packed copy, then trees only and full again.
	planted[0] = true
	t0 = Time.get_ticks_usec()
	flora.invalidate(chunk)
	var trees_bytes: PackedByteArray = flora.chunk_bytes(chunk, false)
	var full_bytes: PackedByteArray = flora.chunk_bytes(chunk, true)
	var change_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	print("chunk %s: made in %.0f ms, re-sent after a planting in %.0f ms (%d items)" % [str(chunk), first_ms, change_ms, PlacerScript.decode(full_bytes, origin)["ids"].size()])
	if not flora.has_method("_placed"):   # dev before the fix: the timing above is the measurement
		check(false, "ServerFlora keeps placed lists (_placed)")
		quit(1)
		return

	check(change_ms * 4.0 < first_ms, "the re-send costs under a quarter of making the chunk (%.0f vs %.0f ms)" % [change_ms, first_ms])

	var fresh = ServerFloraScript.new()
	fresh.setup(placer, "user://test_flora_change_cost_fresh")
	fresh.dynamic = dynamic
	fresh._removed[chunk] = {felled: true}
	check(fresh.chunk_bytes(chunk, false) == trees_bytes, "the re-sent trees-only bytes are a fresh server's")
	check(fresh.chunk_bytes(chunk, true) == full_bytes, "the re-sent full bytes are a fresh server's")
	var decoded: Dictionary = PlacerScript.decode(full_bytes, origin)
	check(decoded["ids"].has(sapling["ids"][0]) and not decoded["ids"].has(felled), "the sapling is in and the felled tree is out")

	flora.clear_memory()
	check(not flora.has_items(chunk), "new tiles forget the placed lists")
	print("Test done: %d fail" % failures)
	quit(1 if failures > 0 else 0)
