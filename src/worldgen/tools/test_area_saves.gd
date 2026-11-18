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
	a._dirty = true
	a.save()
	var h2: Dictionary = header()
	check(int(h2["areas"][here]) == int(h2["gen"]) and int(h2["areas"][there]) == int(h1["gen"]) and FileAccess.get_file_as_string(area_path(there)) == there_text, "a save writes only the area that changed (gens %s)" % str(h2["areas"]))
	var b = make()
	check(loose(b) == 3 and ItemsScript.saved_world_rows(dir).size() == 3, "every area's rows load (%d items)" % loose(b))

	# A crash after an area was written but before the header: the header's gen is in .prev and is loaded.
	var h2_text: String = FileAccess.get_file_as_string(dir + "/world_items.json")
	a.drop_in_world(stone, 1, Vector3(310.0, 10.0, 20.0))
	a._dirty = true
	a.save()
	check(int(header()["areas"][there]) == int(header()["gen"]), "the far area was written again")
	var f: FileAccess = FileAccess.open(dir + "/world_items.json", FileAccess.WRITE)
	f.store_string(h2_text)   # as if the header write never happened
	f.close()
	var c = make()
	check(loose(c) == 3, "a crash between an area and the header loads the save the header names (%d items, not 4)" % loose(c))

	# An area left empty loses its file.
	a._dirty = true
	a.save()   # the header again as a has it (4 items)

	for id in a._items.keys():
		if a._items[id]["pos"].x > 200.0:
			a._items.erase(id)

	a._dirty = true
	a.save()
	check(not (header()["areas"] as Dictionary).has(there) and not FileAccess.file_exists(area_path(there)) and not FileAccess.file_exists(area_path(there) + ".prev"), "an area left empty loses its file and the header forgets it")
	check(loose(make()) == 2, "the near area still loads")

	# A damaged area file is set aside as .bad and its .prev (the save before) is read.
	var near_prev: Variant = JSON.parse_string(FileAccess.get_file_as_string(area_path(here) + ".prev"))
	f = FileAccess.open(area_path(here), FileAccess.WRITE)
	f.store_string("{\"version\": 4, \"gen\": 3, \"items\": [[1, 2")
	f.close()
	var d = make()
	check(FileAccess.file_exists(area_path(here) + ".bad") and typeof(near_prev) == TYPE_DICTIONARY and loose(d) == (near_prev["items"] as Array).size(), "a damaged area file is set aside and the save before it read (%d items)" % loose(d))

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
	wipe()
	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)
