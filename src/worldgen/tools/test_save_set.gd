extends SceneTree

# A save is one set of files (coordinator 23 Nov 2026, the live save before Wednesday: a hard stop at any moment of a save, nothing both in a
# pack and in a chest, nothing in neither). save() writes inventories, chests, vitals, characters, craft queues, crops, smelters, smithies,
# trees, lights, kilns, the world item areas and last the world_items.json header, one file at a time. A hard stop between two of them left
# some files from the new save and the rest from the one before: Stone put from the pack into a chest was in neither, or taken out, in both.
# Every set file now carries the save's gen and the header is written last; at load a file from a save whose header never landed is read
# from its .prev (the save before), so the store always reads as one whole save.
# Here a player moves Stone from the pack into a chest and back, then sticks are dropped, and the server is stopped after each file of
# the save in turn: every stop reads back as the save before or the save after, never a mix.
#   godot --headless --path . --script res://src/worldgen/tools/test_save_set.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const DIR := "user://test_save_set"
const COPY := "user://test_save_set_stop"
const KEY := "savesetkey0001"
const HERE := Vector3(5.0, 10.0, 0.0)
# The files of one save in the order save() writes them (the world item areas between kilns and the header).
const ORDER := ["inventories.json", "chests.json", "vitals.json", "characters.json", "craft_queues.json", "crops.json", "smelters.json", "smithies.json", "tree_states.json", "lights.json", "kilns.json"]

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	failures += 0 if ok else 1


func make(dir: String):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_craft_queue = func(_p, _e, _l): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_chest = func(_p, _id, _b): pass
	items.send_chest_info = func(_p, _id, _k, _m): pass
	items.send_chest_lock = func(_p, _id, _l, _m, _o, _w, _a): pass
	items.send_notice = func(_p, _t): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	return items


func wipe(dir: String) -> void:
	for sub in ["", "/" + ItemsScript.AREA_DIR]:
		DirAccess.make_dir_recursive_absolute(dir + sub)

		for file in DirAccess.get_files_at(dir + sub):
			DirAccess.remove_absolute(dir + sub + "/" + file)


func copy_dir(from: String, to: String) -> void:
	wipe(to)

	for sub in ["", "/" + ItemsScript.AREA_DIR]:
		for file in DirAccess.get_files_at(from + sub):
			DirAccess.copy_absolute(from + sub + "/" + file, to + sub + "/" + file)


# What the store holds: Stone in packs, Stone in chests, Sticks on the ground.
func state_of(items) -> Array:
	var stone: int = items.table.number_of("stone")
	var stick: int = items.table.number_of("stick")
	var packs: int = 0
	var chests: int = 0
	var ground: int = 0

	for key in items._inventories:
		packs += items._inventories[key].count_of(stone)

	for uid in items._chests:
		chests += items._chests[uid].count_of(stone)

	for id in items._items:
		if int(items._items[id].get("number", 0)) == stick and not items._items[id].has("struct") and not items._items[id].has("scatter"):
			ground += int(items._items[id]["count"])

	return [packs, chests, ground]


# The store after a hard stop once `done` files of the last save had landed: those files from the last save, the rest as the save before
# left them (each file's .prev is the save before it, so a file not yet written is its .prev with the .prev before that beside it).
func stopped_after(done: int, from: String = DIR, to: String = COPY) -> Array:
	if from != to:
		copy_dir(from, to)

	var names: Array = ORDER.duplicate()

	for area in DirAccess.get_files_at(from + "/" + ItemsScript.AREA_DIR):
		if area.ends_with(".json"):
			names.append(ItemsScript.AREA_DIR + "/" + area)

	names.append("world_items.json")

	for k in range(done, names.size()):
		var path: String = to + "/" + str(names[k])

		if FileAccess.file_exists(path + ".prev"):
			DirAccess.copy_absolute(path + ".prev", path)   # not written yet: still the save before
		else:
			DirAccess.remove_absolute(path)   # a file this save made for the first time

	var items = make(to)
	var got: Array = state_of(items) + [items.load_failures.size()]
	items._finish_writer()
	return [got, names.size()]


# A store where the Stone is in the pack; it is put into the chest and a save runs with `block` (a path under the store, or "area" for the
# chest's world item area) unable to be written. True when the store then reads as before, and as after once the block is gone.
func lost_file_case(block: String, periodic: bool, stone: int) -> bool:
	copy_dir(DIR, COPY)
	var it = make(COPY)
	var was: Array = state_of(it)
	it.peer_connected_hello(1, KEY)
	it.report_position(1, HERE)
	var box_id: int = 0

	for id in it._items:
		if it._items[id].has("struct") and str(it._items[id]["struct"]["kind"]) == "chest":
			box_id = id

	it.action(1, Net.ACT_CHEST_OPEN, box_id, 0, 0, Vector3.ZERO)
	it.action(1, Net.ACT_CHEST_PUT, it.inventory_of(1).numbers.find(stone), box_id, 20, Vector3.ZERO)
	it.drop_in_world(it.table.number_of("stick"), 2, HERE + Vector3(0.0, 0.0, 2.0))   # a change in the area too, so the area file is written
	var wanted: Array = state_of(it)
	var area: String = ItemsScript.AREA_DIR + "/" + it.area_key_of(HERE.x, HERE.z) + ".json.tmp"
	var path: String = COPY + "/" + (area if block == "area" else block)
	DirAccess.make_dir_recursive_absolute(path)
	it._area_dirty[it.area_key_of(HERE.x, HERE.z)] = true   # what the rolling check would mark within a save interval (_save_sweep)
	it._dirty = true
	it._async_writes = periodic
	it.save()
	it._start_writer()
	it._finish_writer()
	it._async_writes = false
	var read_then = make(COPY)
	var then: Array = state_of(read_then)
	read_then._finish_writer()
	DirAccess.remove_absolute(path)
	it.tick(0.05)   # the failed save marks the world for saving again
	it.save()
	it._finish_writer()
	var read_now = make(COPY)
	var now: Array = state_of(read_now)
	read_now._finish_writer()
	it._finish_writer()

	if then != was or now != wanted:
		print("     %s periodic %s: before %s, read after the failed save %s, after the next save %s (wanted %s)" % [block, periodic, str(was), str(then), str(now), str(wanted)])

	return then == was and now == wanted


func _init() -> void:
	wipe(DIR)
	var items = make(DIR)
	items.peer_connected_hello(1, KEY)
	items.report_position(1, HERE)
	var stone: int = items.table.number_of("stone")
	var stick: int = items.table.number_of("stick")
	items.give(1, stone, 20)
	var chest: int = items.dev_place("chest@6,1")
	items._dirty = true
	items.save()
	items._dirty = true
	items.save()   # two whole saves: every file has its .prev
	var before: Array = state_of(items)

	# Into the chest: the save that follows moves Stone from inventories.json to chests.json.
	items.action(1, Net.ACT_CHEST_OPEN, chest, 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_PUT, items.inventory_of(1).numbers.find(stone), chest, 20, Vector3.ZERO)
	items.drop_in_world(stick, 3, HERE + Vector3(0.0, 0.0, 2.0))
	var after: Array = state_of(items)
	check(before == [20, 0, 0] and after == [0, 20, 3], "the player put 20 Stone into the chest and 3 Sticks lie on the ground (%s -> %s)" % [str(before), str(after)])
	items._dirty = true
	items.save()
	items._finish_writer()
	var whole: Array = stopped_after(999)[0]
	check(whole == after + [0], "the whole save reads back as it was (%s)" % str(whole))
	var count: int = int(stopped_after(0)[1])
	var mixed: Array = []

	for done in range(count + 1):
		var got: Array = stopped_after(done)[0]

		if got != before + [0] and got != after + [0]:
			mixed.append("stopped after %d files: %s" % [done, str(got)])

	check(mixed.is_empty(), "stopped after any of the %d files of the save, the store reads as the save before or the save after (%s)" % [count, "; ".join(mixed)])

	# And back out of the chest: the other way round (in both, before the fix).
	items.action(1, Net.ACT_CHEST_TAKE, items._chests[int(items._items[chest]["struct"]["uid"])].numbers.find(stone), chest, 20, Vector3.ZERO)
	before = after
	after = state_of(items)
	items._dirty = true
	items.save()
	items._finish_writer()
	mixed.clear()

	for done in range(count + 1):
		var got: Array = stopped_after(done)[0]

		if got != before + [0] and got != after + [0]:
			mixed.append("stopped after %d files: %s" % [done, str(got)])

	check(after == [20, 0, 3] and mixed.is_empty(), "taken back out: any stop reads as before or after, never Stone in both (%s)" % "; ".join(mixed))

	# Two stops in a row: stopped after the first file, restarted, the Stone taken out of the chest again, stopped again after the first file of that
	# save. The first restart put the unfinished file aside, so the second still reads as one whole save (the one both stops fell back to).
	var first: Array = stopped_after(1)[0]
	var twice = make(COPY)
	var in_pack: Array = state_of(twice)
	twice.peer_connected_hello(1, KEY)
	twice.report_position(1, HERE)
	var box_id: int = 0

	for id in twice._items:
		if twice._items[id].has("struct") and str(twice._items[id]["struct"]["kind"]) == "chest":
			box_id = id

	twice.action(1, Net.ACT_CHEST_OPEN, box_id, 0, 0, Vector3.ZERO)
	var box = twice._chests[int(twice._items[box_id]["struct"]["uid"])]
	twice.action(1, Net.ACT_CHEST_TAKE, box.numbers.find(stone), box_id, 20, Vector3.ZERO)
	var moved: Array = state_of(twice)
	twice._dirty = true
	twice.save()
	twice._finish_writer()
	var second: Array = stopped_after(1, COPY, COPY)[0]
	check(first == before + [0] and moved == [20, 0, 3] and second == in_pack + [0] and DirAccess.get_files_at(COPY).has("inventories.json.unfinished"), "stopped twice in a row, each mid-save, the store still reads as one whole save (%s, then %s)" % [str(first), str(second)])
	twice._finish_writer()

	# A file that cannot be written (a full disk, a read-only store; here a folder stands where chests.json.tmp goes): the save says so, writes
	# no header and puts back the files it did write, so the store stays the save before as a whole; once the file can be written, the next
	# save (the tick asks for it) lands whole.
	copy_dir(DIR, COPY)
	var full = make(COPY)
	var was: Array = state_of(full)
	full.peer_connected_hello(1, KEY)
	full.report_position(1, HERE)
	var full_chest: int = 0

	for id in full._items:
		if full._items[id].has("struct") and str(full._items[id]["struct"]["kind"]) == "chest":
			full_chest = id

	full.action(1, Net.ACT_CHEST_OPEN, full_chest, 0, 0, Vector3.ZERO)
	full.action(1, Net.ACT_CHEST_PUT, full.inventory_of(1).numbers.find(stone), full_chest, 20, Vector3.ZERO)
	var wanted: Array = state_of(full)
	var head_before: int = int(JSON.parse_string(FileAccess.get_file_as_string(COPY + "/world_items.json"))["gen"])
	DirAccess.make_dir_absolute(COPY + "/chests.json.tmp")
	full._dirty = true
	full.save()
	full._finish_writer()
	var head_after: int = int(JSON.parse_string(FileAccess.get_file_as_string(COPY + "/world_items.json"))["gen"])
	var inv_gen: int = int(JSON.parse_string(FileAccess.get_file_as_string(COPY + "/inventories.json")).get("gen", -1))
	var read_then = make(COPY)
	check(was == [20, 0, 3] and wanted == [0, 20, 3] and head_after == head_before and inv_gen <= head_before and state_of(read_then) == was, "a save that cannot write one file writes no header and puts back the others: the store reads as the save before (header %d -> %d, inventories gen %d, reads %s)" % [head_before, head_after, inv_gen, str(state_of(read_then))])
	read_then._finish_writer()
	DirAccess.remove_absolute(COPY + "/chests.json.tmp")
	full.tick(0.05)   # the failed save marks the world for saving again
	full.save()
	full._finish_writer()
	var read_now = make(COPY)
	check(state_of(read_now) == wanted and read_now.load_failures.is_empty(), "once the file can be written the next save lands whole (%s)" % str(state_of(read_now)))
	read_now._finish_writer()
	full._finish_writer()

	# The same with the background writer (the periodic save) and with the file lost being an area or the header itself.
	for case in [["chests.json.tmp", true], ["world_items.json.tmp", false], ["world_items.json.tmp", true], ["area", false], ["area", true]]:
		check(lost_file_case(str(case[0]), bool(case[1]), stone), "%s save that cannot write %s: no header, the others put back, the store reads as the save before; the next save lands whole" % ["a periodic" if case[1] else "a direct", "an area file" if case[0] == "area" else str(case[0]).trim_suffix(".tmp")])

	# A save after a stop goes on from the save that was read, and the next stop again reads whole.
	copy_dir(DIR, COPY)
	var redo = make(COPY)
	redo._dirty = true
	redo.save()
	redo._finish_writer()
	var again = make(COPY)
	check(state_of(again) == after and again.load_failures.is_empty(), "the next save after a restart reads back whole (%s)" % str(state_of(again)))
	again._finish_writer()
	items._finish_writer()
	print("save set: %d failures" % failures)
	quit(1 if failures > 0 else 0)
