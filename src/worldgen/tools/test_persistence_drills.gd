extends SceneTree

# Persistence drills for every server item file (Items job 63): inventories, world_items, tree_states, chests, vitals
# and craft_queues. For each file: a torn main file falls back to the save before it (.prev) with nothing lost or
# duplicated, a half-written .tmp beside a good file is harmless, a main and .prev that are both damaged lose only
# that one file, and a file from a newer version is never replaced by an older copy.
#   godot --headless --path . --script res://src/worldgen/tools/test_persistence_drills.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const FILES := ["inventories.json", "world_items.json", "tree_states.json", "chests.json", "vitals.json", "craft_queues.json", "characters.json"]
const KEY := "drillkey00001"

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
	items.send_craft_queue = func(_p, _e, _l): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l): pass
	items.ground_height = func(x, z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	return items


func wipe(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)


func write(path: String, text: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


# What a player and the world hold, as numbers: the same after any restart, and never more.
func state_of(items) -> Dictionary:
	var stone: int = items.table.number_of("stone")
	var chest_stones: int = 0

	for uid in items._chests:
		chest_stones += items._chests[uid].count_of(stone)

	var ground_stones: int = 0

	for id in items._items:
		if int(items._items[id]["number"]) == stone and not items._items[id].has("scatter"):
			ground_stones += int(items._items[id]["count"])

	return {
		"pack": items.inventory_of(1).count_of(stone), "chest": chest_stones, "ground": ground_stones,
		"trees": items.tree_row_count(), "queue": items.craft_queue_of(1), "weight": snappedf(float(items.vitals_of(1)["weight"]), 0.01), "luck": items.luck_of(1),
	}


func build_world(dir: String) -> Dictionary:
	wipe(dir)
	var a = make(dir)
	a.peer_connected_hello(1, KEY)
	a.report_position(1, Vector3(0.0, 10.0, 0.0))
	var stone: int = a.table.number_of("stone")
	var fibre: int = a.table.number_of("plant_fibre")
	var kit: int = a.table.number_of("chest_kit")
	a.action(1, Net.ACT_ADMIN_GIVE, stone, 0, 20, Vector3.ZERO)
	a.action(1, Net.ACT_ADMIN_GIVE, kit, 0, 1, Vector3.ZERO)
	a.action(1, Net.ACT_PLACE, a.inventory_of(1).numbers.find(kit), 0, 0, Vector3(2.0, 10.0, 0.0))

	for uid in a._chests:
		a._chests[uid].add(stone, 7)

	a.drop_in_world(stone, 3, Vector3(10.0, 10.0, 10.0))
	a._items[a._next_id] = {"number": 0, "count": 1, "pos": Vector3(5.0, 10.0, 5.0), "left": 1.0e9, "tree": {"state": 4, "chunk": [0, 0], "species": "oak", "yaw": 0.0, "length": 5.0, "radius": 0.2, "felled_at": 0.0}}
	a._next_id += 1
	a.vitals_of(1)["weight"] = 71.0
	a._characters[KEY]["luck"] = 7
	a.action(1, Net.ACT_ADMIN_GIVE, fibre, 0, 9, Vector3.ZERO)
	a._last_queue_act.clear()
	a.action(1, Net.ACT_CRAFT_QUEUE, 1, 0, 3, Vector3.ZERO)
	a._dirty = true
	a.save()
	a._dirty = true
	a.save()   # twice, so every file has a .prev
	return state_of(a)


func reload(dir: String):
	var b = make(dir)
	b.peer_connected_hello(1, KEY)
	return b


func _init() -> void:
	var dir: String = "user://test_drills"
	var want: Dictionary = build_world(dir)
	check(int(want["pack"]) == 20 and int(want["chest"]) == 7 and int(want["ground"]) == 3 and int(want["trees"]) == 1, "the drill world has what the drills count on %s" % str(want))

	for file in FILES:
		check(FileAccess.file_exists(dir + "/" + file), "%s is written" % file)
		check(FileAccess.file_exists(dir + "/" + file + ".prev"), "%s keeps a copy of the save before it" % file)

	var clean: Dictionary = state_of(reload(dir))
	check(clean == want, "a clean restart brings back exactly the same state (%s vs %s)" % [str(clean), str(want)])

	for file in FILES:
		# A torn main file: restored from .prev, same state, the damaged one kept as .bad.
		wipe(dir + "_x")
		var snap: String = dir + "_x"

		for name in FILES:
			DirAccess.copy_absolute(dir + "/" + name, snap + "/" + name)
			DirAccess.copy_absolute(dir + "/" + name + ".prev", snap + "/" + name + ".prev")

		write(snap + "/" + file, "{\"version\": 1, \"trunc")
		var restored: Dictionary = state_of(reload(snap))
		check(restored == want, "%s torn: restored from the save before it, nothing lost or doubled (%s)" % [file, str(restored)])
		check(FileAccess.file_exists(snap + "/" + file + ".bad"), "%s torn: the damaged file is kept as .bad" % file)
		check(FileAccess.get_file_as_string(snap + "/" + file).length() > 30, "%s torn: a good file is back in place" % file)

		# A kill mid-write leaves a half-written .tmp beside the good file: loads as if it was not there.
		wipe(snap)

		for name in FILES:
			DirAccess.copy_absolute(dir + "/" + name, snap + "/" + name)
			DirAccess.copy_absolute(dir + "/" + name + ".prev", snap + "/" + name + ".prev")

		write(snap + "/" + file + ".tmp", "{\"version\": 1, \"half")
		var torn_tmp = reload(snap)
		check(state_of(torn_tmp) == want, "%s with a half-written .tmp: state unchanged" % file)
		torn_tmp._dirty = true
		torn_tmp.save()
		check(JSON.parse_string(FileAccess.get_file_as_string(snap + "/" + file)) is Dictionary, "%s: the next save replaces the half-written .tmp cleanly" % file)

		# Both the file and its copy damaged: only this file starts clean, the rest stay, no crash.
		wipe(snap)

		for name in FILES:
			DirAccess.copy_absolute(dir + "/" + name, snap + "/" + name)
			DirAccess.copy_absolute(dir + "/" + name + ".prev", snap + "/" + name + ".prev")

		write(snap + "/" + file, "not json")
		write(snap + "/" + file + ".prev", "{\"version\": 1, \"trunc")
		var lost: Dictionary = state_of(reload(snap))
		var expect: Dictionary = want.duplicate()
		var gone: Array = {
			"inventories.json": ["pack"], "world_items.json": ["ground"], "tree_states.json": ["trees"], "chests.json": ["chest"],
			"vitals.json": ["weight"], "craft_queues.json": ["queue"], "characters.json": ["luck"],
		}[file]

		for field in gone:
			expect.erase(field)
			lost.erase(field)

		for field in expect:
			check(lost[field] == expect[field], "%s fully damaged: %s still intact (%s)" % [file, field, str(lost[field])])

	# A newer-version file is set aside and the older copy is not used in its place.
	wipe(dir + "_x")

	for name in FILES:
		DirAccess.copy_absolute(dir + "/" + name, dir + "_x/" + name)
		DirAccess.copy_absolute(dir + "/" + name + ".prev", dir + "_x/" + name + ".prev")

	write(dir + "_x/world_items.json", "{\"version\": 9999, \"items\": []}")
	var newer = reload(dir + "_x")
	check(int(state_of(newer)["ground"]) == 0 and FileAccess.file_exists(dir + "_x/world_items.json.bad"), "a file from a newer version is set aside, not replaced by an old copy")

	print("persistence drills: %d failures" % failures)
	quit(1 if failures > 0 else 0)
