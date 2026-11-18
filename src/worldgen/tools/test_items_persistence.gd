extends SceneTree

# Persistence and cap stress for the server items: corrupt-file fallback for every save file, and a run
# of 1000 items against the per-chunk caps with save and load timings (printed as "stress:" lines).
#   godot --headless --path . --script res://src/worldgen/tools/test_items_persistence.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const BowScript := preload("res://src/stream/server_bow.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(dir: String):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.setup(ItemTableScript.load_default(), dir)
	return items


func wipe(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	DirAccess.make_dir_recursive_absolute(dir + "/" + ItemsScript.AREA_DIR)

	for file in DirAccess.get_files_at(dir + "/" + ItemsScript.AREA_DIR):
		DirAccess.remove_absolute(dir + "/" + ItemsScript.AREA_DIR + "/" + file)


# The world items as saved, without the save count: [header text, rows text].
func world_save(dir: String) -> Array:
	var head: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "/world_items.json"))
	head.erase("gen")
	head.erase("areas")
	return [JSON.stringify(head), JSON.stringify(ItemsScript.saved_world_rows(dir))]


func folder_size(dir: String) -> int:
	var total: int = 0

	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".json"):
			total += size_of(dir + "/" + file)

	return total


func size_of(path: String) -> int:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	return f.get_length() if f != null else -1


func _init() -> void:
	var stone: int = ItemTableScript.load_default().number_of("stone")

	# Corrupt files: each is set aside as .bad and the server starts clean.
	var dir: String = "user://test_persist_a"
	wipe(dir)
	var a = make(dir)
	a.ground_height = func(x, z): return 10.0
	a.peer_connected_hello(1, "abcdef123456")
	a.action(1, Net.ACT_ADMIN_GIVE, stone, 0, 5, Vector3.ZERO)
	a.drop_in_world(stone, 3, Vector3(10.0, 10.0, 10.0))
	a._items[a._next_id] = {"number": 0, "count": 1, "pos": Vector3(5.0, 10.0, 5.0), "left": 1.0e9, "tree": {"state": 4, "chunk": [0, 0], "species": "oak", "yaw": 0.0, "length": 5.0, "radius": 0.2, "felled_at": 0.0}}
	a._next_id += 1
	a._dirty = true
	a.save()

	for file in ["inventories.json", "world_items.json", "tree_states.json"]:
		check(FileAccess.file_exists(dir + "/" + file), "%s is written" % file)

	var ok = make(dir)
	ok.peer_connected_hello(1, "abcdef123456")
	check(ok.inventory_of(1).count_of(stone) == 5 and ok.world_item_count() >= 2, "clean restart brings everything back")

	# The periodic save (audit 18 Nov 2026 finding 2): the tick copies, the background writer builds and writes. Its files must match a direct save's
	# (a fire, a lit standing torch and an arrow stuck in a tree among the items), and a change made on the tick after the copy must not reach them.
	a.drop_in_world(stone, 1, Vector3(12.0, 10.0, 12.0))
	a._bow = BowScript.new()   # made at the first shot in play; _stick_arrow reads its config
	var arrow_id: int = a._next_id
	a._stick_arrow(stone, Vector3(14.0, 13.0, 14.0), Vector3(1.0, 0.2, 0.0))
	a._items[a._next_id] = {"number": stone, "count": 1, "pos": Vector3(16.0, 10.0, 16.0), "left": 1.0e9, "fire": {"state": 1, "burn_left": 500.0, "recheck": 0.0, "covered": false}}
	a._next_id += 1
	a._items[a._next_id] = {"number": stone, "count": 1, "pos": Vector3(18.0, 10.0, 18.0), "left": 1.0e9, "struct": {"kind": "standing_torch", "yaw": 0.0, "lit": true, "fuel_left": 40.0}}
	a._next_id += 1
	check(a._items.has(arrow_id) and a._tilted.has(arrow_id), "the stuck arrow is in the world and marked tilted")
	var tree_id: int = -1

	for id in a._items:
		if a._items[id].has("tree"):
			tree_id = id

	a._dirty = true
	a.save()
	var direct: Dictionary = {}
	var files: Array = ["inventories.json", "tree_states.json", "lights.json", "kilns.json", "chests.json"]
	var direct_world: Array = world_save(dir)

	for file in files + ["world_items.json"]:
		direct[file] = FileAccess.get_file_as_string(dir + "/" + file)
		DirAccess.remove_absolute(dir + "/" + file)

	for file in DirAccess.get_files_at(dir + "/" + ItemsScript.AREA_DIR):
		DirAccess.remove_absolute(dir + "/" + ItemsScript.AREA_DIR + "/" + file)   # the periodic save must write the areas again (the file is gone)

	check(str(direct["lights.json"]).contains("40") and str(direct_world[1]).contains("500"), "the direct save holds the lit light and the fire")
	a._dirty = true
	a._async_writes = true
	a.save()
	a._async_writes = false
	a._items[tree_id]["tree"]["state"] = 3   # a nested change after the copy, before the writer runs
	a._items[a._next_id - 2]["fire"]["burn_left"] = 7.0
	a._start_writer()
	a._finish_writer()

	for file in files:
		check(FileAccess.file_exists(dir + "/" + file) and FileAccess.get_file_as_string(dir + "/" + file) == direct[file], "%s: the periodic save writes what a direct save writes, as of its copy" % file)

	check(FileAccess.file_exists(dir + "/world_items.json") and world_save(dir) == direct_world, "world items: the periodic save writes what a direct save writes, as of its copy")

	for id in a._items.keys():
		if id != tree_id and int(id) >= a._next_id - 3:
			a._items.erase(id)

	a._items[tree_id]["tree"]["state"] = 4

	for file in ["world_items.json", "tree_states.json"]:
		var f: FileAccess = FileAccess.open(dir + "/" + file, FileAccess.WRITE)
		f.store_string("{\"version\": 1, \"trunc")
		f.close()
		var b = make(dir)
		b.peer_connected_hello(1, "abcdef123456")
		check(FileAccess.file_exists(dir + "/" + file + ".bad"), "%s: corrupt copy set aside" % file)
		check(b.inventory_of(1).count_of(stone) == 5, "%s: corrupt file leaves inventories alone" % file)
		b.tick(1.0)
		b.save()

	var wrong = FileAccess.open(dir + "/world_items.json", FileAccess.WRITE)
	wrong.store_string("{\"version\": 9999, \"items\": []}")
	wrong.close()
	var w = make(dir)
	var loose: int = 0

	for k in w._items:
		if not w._items[k].has("tree"):
			loose += 1

	check(loose == 0, "a save from a newer version is not read (%d loose items)" % loose)

	# An old save (protocol 18) holds an out fire as state 2: empty ashes when no wood is left, loaded when some is.
	var old = FileAccess.open(dir + "/world_items.json", FileAccess.WRITE)
	var fire_number: int = ItemTableScript.load_default().number_of("campfire_kit")
	old.store_string(JSON.stringify({"version": 1, "next_id": 10, "items": [[fire_number, 1, 5.0, 10.0, 5.0, 100.0, 2, 0.0, 0], [fire_number, 1, 50.0, 10.0, 5.0, 100.0, 2, 300.0, 0]]}))
	old.close()
	var o = make(dir)
	var states: Array = []

	for k in o._items:
		if o._items[k].has("fire"):
			states.append(int(o._items[k]["fire"]["state"]))

	states.sort()
	check(states == [8, 9], "old out fires load as empty (8) or loaded (9): %s" % str(states))

	# Stress: 1000 drops over 4 chunks all lie on the ground (Dave 16 Nov 2026: "there should be no limit").
	var sd: String = "user://test_persist_b"
	wipe(sd)
	var s = make(sd)
	s.ground_height = func(x, z): return 10.0
	var accepted: int = 0

	for n in range(1000):
		var cx: int = n % 2
		var cz: int = (n / 2) % 2
		var pos: Vector3 = Vector3(float(cx) * 256.0 + 5.0 + float(n % 4), 10.0, float(cz) * 256.0 + 5.0 + float((n * 7) % 4))

		if s.drop_in_world(s.table.number_of("stone_axe"), 1, pos, 1):
			accepted += 1

	check(accepted == 1000 and s.world_item_count() == accepted, "no cap on world items (%d accepted of 1000)" % accepted)

	# Fires: 40 kits in one chunk give 8 fires.
	s.peer_connected_hello(1, "abcdef123456")
	s.action(1, Net.ACT_ADMIN_GIVE, s.table.number_of("campfire_kit"), 0, 30, Vector3.ZERO)
	var before_fires: int = s.world_item_count()

	for n in range(40):
		s.report_position(1, Vector3(1030.0 + float(n) * 4.0, 10.0, 1000.0))
		var slot: int = 0

		while slot < 29 and s.inventory_of(1).numbers[slot] == 0:
			slot += 1

		s.action(1, Net.ACT_PLACE, slot, 0, 0, Vector3(1030.0 + float(n) * 4.0 + 1.0, 10.0, 1000.0))

	check(s.world_item_count() - before_fires == ItemsScript.FIRES_PER_CHUNK, "fires stop at the near-spot cap (%d)" % (s.world_item_count() - before_fires))

	# Saplings: 400 stumps in one chunk, about half take, capped at 64.
	s.world_seed = 3
	s.standing_near = func(name, pos, radius): return [pos + Vector3(10.0, 0.0, 0.0)] if name == "oak" else []

	for n in range(400):
		s._maybe_sapling({"pos": Vector3(5.0 + float(n % 240), 10.0, 600.0 + float((n * 11) % 100)), "tree": {"species": "oak", "chunk": [2, 2], "state": 4}})

	var in_chunk: int = 0

	for sapling in s._saplings:
		in_chunk += 1

	check(in_chunk > 0 and in_chunk <= ItemsScript.SAPLINGS_PER_CHUNK, "saplings stop at the near-spot cap (%d)" % in_chunk)

	# 1000 stump records across 40 chunks: save and reload time and size.
	for n in range(1000):
		s._items[s._next_id] = {"number": 0, "count": 1, "pos": Vector3(float(n) * 3.0, 10.0, float(n % 40) * 256.0), "left": 1.0e9, "tree": {"state": 4, "chunk": [n % 40, 0], "species": "oak", "yaw": 0.0, "length": 12.0, "radius": 0.3, "felled_at": 0.0}}
		s._next_id += 1

	s._dirty = true
	var t0: int = Time.get_ticks_usec()
	s.save()
	var save_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	var again = make(sd)
	var load_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	check(again.world_item_count() == s.world_item_count(), "everything survives the restart (%d items)" % again.world_item_count())
	print("stress: %d items+stumps saved in %.1f ms, loaded in %.1f ms; world_items.json %d bytes, tree_states.json %d bytes" % [s.world_item_count(), save_ms, load_ms, size_of(sd + "/world_items.json") + folder_size(sd + "/" + ItemsScript.AREA_DIR), size_of(sd + "/tree_states.json")])

	t0 = Time.get_ticks_usec()

	for n in range(100):
		s.tick(0.1)

	print("stress: 100 server ticks with %d records took %.1f ms (%.2f ms per tick)" % [s._items.size(), float(Time.get_ticks_usec() - t0) / 1000.0, float(Time.get_ticks_usec() - t0) / 100000.0])
	print("persistence tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
