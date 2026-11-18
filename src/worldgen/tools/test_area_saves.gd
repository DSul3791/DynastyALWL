extends SceneTree

# World items saved by area (audit 18 Nov 2026 finding 2, docs/ai-team/audits/2026-11-18_oversized_reactions_audit.md): only the areas that
# changed are written, the header names each area file's gen, a crash between an area and the header loads the save before, an area left
# empty loses its file, a damaged area file falls back to its .prev, and a one-file save from before loads and is written out by area.
#   godot --headless --path . --script res://src/worldgen/tools/test_area_saves.gd      Prints "Test done: N pass, N fail".

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")

var passes: int = 0
var failures: int = 0
var dir: String = "user://test_area_saves"


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1
		print("FAIL ", what)


func make():
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	return items


func wipe() -> void:
	DirAccess.make_dir_recursive_absolute(dir + "/" + ItemsScript.AREA_DIR)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	for file in DirAccess.get_files_at(dir + "/" + ItemsScript.AREA_DIR):
		DirAccess.remove_absolute(dir + "/" + ItemsScript.AREA_DIR + "/" + file)


func header() -> Dictionary:
	var head: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + "/world_items.json"))
	return head if typeof(head) == TYPE_DICTIONARY else {}


func loose(items) -> int:
	var n: int = 0

	for id in items._items:
		if not items._items[id].has("tree") and not items._items[id].has("scatter"):
			n += 1

	return n


# The periodic save (the tick's): copied on the tick, written by the background writer, skipping the areas that did not change.
func periodic(items) -> void:
	items.save_check_now()   # the rolling check finished (the tick spreads it over a save interval; see the last section)
	items._dirty = true
	items._async_writes = true
	items.save()
	items._async_writes = false
	items._start_writer()
	items._finish_writer()


func area_path(key: String) -> String:
	return "%s/%s/%s.json" % [dir, ItemsScript.AREA_DIR, key]


func _init() -> void:
	wipe()
	var a = make()
	var stone: int = a.table.number_of("stone")
	var stick: int = a.table.number_of("stick")
	var here: String = ItemsScript.area_key_of(10.0, 10.0)
	var there: String = ItemsScript.area_key_of(300.0, 10.0)
	check(here != there, "two spots 290 m apart are in different areas")
	a.drop_in_world(stone, 3, Vector3(10.0, 10.0, 10.0))
	a.drop_in_world(stick, 2, Vector3(300.0, 10.0, 10.0))
	a._dirty = true
	a.save()
	var h1: Dictionary = header()
	check(int(h1.get("version", 0)) == ItemsScript.VERSION and (h1.get("areas", {}) as Dictionary).has(here) and (h1["areas"] as Dictionary).has(there) and not h1.has("items"), "the header names the area files and holds no rows")
	check(FileAccess.file_exists(area_path(here)) and FileAccess.file_exists(area_path(there)), "each area has its own file")

	# Only the changed area is written.
	var there_text: String = FileAccess.get_file_as_string(area_path(there))
	a.drop_in_world(stick, 1, Vector3(20.0, 10.0, 30.0))
	periodic(a)
	var h2: Dictionary = header()
	check(int(h2["areas"][here]) == int(h2["gen"]) and int(h2["areas"][there]) == int(h1["gen"]) and FileAccess.get_file_as_string(area_path(there)) == there_text, "a save writes only the area that changed (gens %s)" % str(h2["areas"]))
	var b = make()
	check(loose(b) == 3 and ItemsScript.saved_world_rows(dir).size() == 3, "every area's rows load (%d items)" % loose(b))

	# A crash after an area was written but before the header: the header's gen is in .prev and is loaded.
	var h2_text: String = FileAccess.get_file_as_string(dir + "/world_items.json")
	a.drop_in_world(stone, 1, Vector3(310.0, 10.0, 20.0))
	periodic(a)
	check(int(header()["areas"][there]) == int(header()["gen"]), "the far area was written again")
	var f: FileAccess = FileAccess.open(dir + "/world_items.json", FileAccess.WRITE)
	f.store_string(h2_text)   # as if the header write never happened
	f.close()
	var c = make()
	check(loose(c) == 3, "a crash between an area and the header loads the save the header names (%d items, not 4)" % loose(c))

	# A drop ageing on the ground does not make the periodic save write its area again; a clean (direct) save writes the exact time left.
	for id in a._items:
		if a._items[id].has("left") and float(a._items[id]["left"]) < 1.0e8:
			a._items[id]["left"] = 1000.0   # mid-step (AREA_STEP_S 600): five seconds less stays in the same step

	periodic(a)
	var gens_before: Dictionary = (header()["areas"] as Dictionary).duplicate()

	for id in a._items:
		if a._items[id].has("left") and float(a._items[id]["left"]) < 1.0e8:
			a._items[id]["left"] = float(a._items[id]["left"]) - 5.0

	periodic(a)
	check(header()["areas"] == gens_before, "five seconds of ageing writes no area in the periodic save (%s vs %s)" % [str(header()["areas"]), str(gens_before)])
	a._dirty = true
	a.save()
	check(int(header()["areas"][here]) == int(header()["gen"]), "a direct save writes every area exactly")

	# An item moved from one area to another leaves the first and is in the second, once, after the next save.
	var mover: int = -1

	for id in a._items:
		if a._items[id]["pos"].x < 100.0 and int(a._items[id]["number"]) == stick:
			mover = int(id)

	a._items[mover]["pos"] = Vector3(305.0, 10.0, 40.0)
	periodic(a)
	var moved = make()
	var near_sticks: int = 0
	var far_sticks: int = 0

	for id in moved._items:
		if int(moved._items[id]["number"]) == stick:
			if moved._items[id]["pos"].x < 100.0:
				near_sticks += 1
			else:
				far_sticks += 1

	check(near_sticks == 0 and far_sticks == 2 and loose(moved) == 4, "a moved item is saved in its new area only (%d near, %d far, %d items)" % [near_sticks, far_sticks, loose(moved)])

	# An area left empty loses its file.
	a._dirty = true
	a.save()   # the header again as a has it (4 items)

	for id in a._items.keys():
		if a._items[id]["pos"].x > 200.0:
			a._items.erase(id)

	a._dirty = true
	a.save()
	check(not (header()["areas"] as Dictionary).has(there) and not FileAccess.file_exists(area_path(there)) and not FileAccess.file_exists(area_path(there) + ".prev"), "an area left empty loses its file and the header forgets it")
	check(loose(make()) == 1, "the near area still loads")

	# A damaged area file is set aside as .bad and its .prev (the save before) is read.
	var near_prev: Variant = JSON.parse_string(FileAccess.get_file_as_string(area_path(here) + ".prev"))
	f = FileAccess.open(area_path(here), FileAccess.WRITE)
	f.store_string("{\"version\": 4, \"gen\": 3, \"items\": [[1, 2")
	f.close()
	var d = make()
	check(FileAccess.file_exists(area_path(here) + ".bad") and typeof(near_prev) == TYPE_DICTIONARY and loose(d) == (near_prev["items"] as Array).size(), "a damaged area file is set aside and the save before it read (%d items)" % loose(d))

	# A torn header: set aside as .bad, the header before it read, and each area at the gen it names (from .prev where the area changed since).
	a._dirty = true
	a.save()   # writes the damaged area again (a direct save writes every area)
	a.drop_in_world(stick, 1, Vector3(12.0, 10.0, 40.0))
	periodic(a)
	f = FileAccess.open(dir + "/world_items.json", FileAccess.WRITE)
	f.store_string("{\"version\": 4, \"gen\"")
	f.close()
	var e = make()
	check(FileAccess.file_exists(dir + "/world_items.json.bad") and loose(e) == 1, "a torn header loads the save before it, the changed area from its .prev (%d items, not 2)" % loose(e))

	# A one-file save from before (version 3) loads, and the next save writes it out by area.
	wipe()
	f = FileAccess.open(dir + "/world_items.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 3, "no_kits": true, "next_id": 5, "items": [[stone, 2, 10.0, 10.0, 10.0, 600.0], [stick, 1, 400.0, 10.0, 400.0, 600.0]], "taken": [], "picked": {}}))
	f.close()
	var old = make()
	check(loose(old) == 2, "a version 3 save loads (%d items)" % loose(old))
	old._dirty = true
	old.save()
	check((header().get("areas", {}) as Dictionary).size() == 2 and FileAccess.file_exists(dir + "/world_items.json.prev"), "the next save writes it out by area and keeps the old file as .prev")
	check(loose(make()) == 2, "and it loads again from the areas")
	# The rolling check as the tick runs it, on a bigger world: an item changed in place (count, wear, a step aside, erased, moved to another
	# area) reaches the disk within two save intervals with no help; a shutdown (direct) save right after a change is exact.
	wipe()
	var big = make()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1811

	for k in 20000:
		big._items[big._next_id] = {"number": stone, "count": 1 + k % 4, "pos": Vector3(rng.randf_range(-1500.0, 1500.0), 10.0, rng.randf_range(-1500.0, 1500.0)), "left": 1.0e9, "wear": 0}
		big._next_id += 1

	big._dirty = true
	big.save()   # a direct save: indexed and written
	var ids: Array = big._items.keys()
	var counted: int = ids[100]
	var worn: int = ids[200]
	var stepped: int = ids[300]
	var erased: int = ids[400]
	var moved_far: int = ids[500]
	big._items[counted]["count"] = 77
	big._items[worn]["wear"] = 33
	big._items[stepped]["pos"] = big._items[stepped]["pos"] + Vector3(0.3, 0.0, 0.0)
	var stepped_at: Vector3 = big._items[stepped]["pos"]
	big._items.erase(erased)
	var far_at: Vector3 = big._items[moved_far]["pos"] + Vector3(600.0, 0.0, 0.0)
	big._items[moved_far]["pos"] = far_at
	var ticks_per_save: int = int(ItemsScript.SAVE_EVERY_S / 0.05)

	for t in 2 * ticks_per_save:
		big._save_sweep(big._sweep_slice(0.05), 1000000)   # as tick() does, with no time limit (a slow test machine must not cut the slice)

		if (t + 1) % ticks_per_save == 0:
			big._dirty = true
			big._async_writes = true
			big.save()
			big._async_writes = false
			big._start_writer()
			big._finish_writer()

	var back = make()
	var found: Dictionary = {"counted": false, "worn": false, "stepped": false, "far": 0, "rows": 0}

	for id in back._items:
		var it: Dictionary = back._items[id]
		found["rows"] = int(found["rows"]) + 1

		if int(it["count"]) == 77:
			found["counted"] = true

		if int(it.get("wear", 0)) == 33:
			found["worn"] = true

		if it["pos"].distance_to(stepped_at) < 0.01:
			found["stepped"] = true

		if it["pos"].distance_to(far_at) < 0.01:
			found["far"] = int(found["far"]) + 1

	check(bool(found["counted"]) and bool(found["worn"]) and bool(found["stepped"]) and int(found["far"]) == 1 and int(found["rows"]) == 19999, "changes in place reach the disk within two save intervals, an item moved to another area once, the erased one gone (%s)" % str(found))
	big._items[ids[600]]["count"] = 55
	big._items.erase(ids[700])
	big._items[big._next_id] = {"number": stick, "count": 9, "pos": Vector3(1.0, 10.0, 1.0), "left": 1.0e9}   # made since the last check
	big._next_id += 1
	big._dirty = true
	big.save()   # shutdown: no check has seen these changes
	var after_stop = make()
	var exact: bool = false

	for id in after_stop._items:
		if int(after_stop._items[id]["count"]) == 55 and after_stop._items[id]["pos"].distance_to(big._items[ids[600]]["pos"]) < 0.01:
			exact = true

	var new_stick: bool = false

	for id in after_stop._items:
		new_stick = new_stick or (int(after_stop._items[id]["number"]) == stick and int(after_stop._items[id]["count"]) == 9)

	check(exact and new_stick and after_stop._items.size() == 19999, "a shutdown save right after changes writes them: a count, an erase, a new item (%d items)" % after_stop._items.size())

	# A load leaves nothing to write: the first periodic save after it, with nothing changed, writes no area file.
	var clean = make()
	check(clean._area_dirty.is_empty(), "a clean load marks no area to write (%d marked)" % clean._area_dirty.size())

	# A periodic save straight after a load, before the check's first pass, still writes every trunk and stump (tree_states.json).
	wipe()
	var with_stump = make()
	with_stump._items[with_stump._next_id] = {"number": 0, "count": 1, "pos": Vector3(40.0, 10.0, 40.0), "left": 1.0e9, "tree": {"state": 4, "chunk": [0, 0], "species": "oak", "yaw": 0.0, "length": 12.0, "radius": 0.3, "felled_at": 0.0}}
	with_stump._next_id += 1
	with_stump.drop_in_world(stone, 1, Vector3(41.0, 10.0, 41.0))
	with_stump._dirty = true
	with_stump.save()
	var reloaded = make()
	reloaded._dirty = true
	reloaded._async_writes = true
	reloaded.save()   # no check has run
	reloaded._async_writes = false
	reloaded._start_writer()
	reloaded._finish_writer()
	var trees_file: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + "/tree_states.json"))
	check(typeof(trees_file) == TYPE_DICTIONARY and (trees_file.get("trees", []) as Array).size() == 1, "a periodic save right after a load keeps the stump in tree_states.json")
	check(loose(make()) == 1, "and the area items")
	wipe()
	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)
