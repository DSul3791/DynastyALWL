extends SceneTree

# Restart drill (coordinator for Dave, 22 Nov 2026): the things a player keeps in the world come back after a restart, both after a clean
# stop (the shutdown save) and after a hard kill (only what the last periodic save wrote; no save is forced dirty here, so a change that
# never marks the world for saving shows up as lost). Covered: a Storage barrel's food, a Water barrel's litres and the waterskin in it, a
# chest's contents, a lit campfire's wood and time left, a set snare, the player's pack and vitals.
# Crops (test_farming), the Map's fog (test_map), coals (test_fire_coals) and snare wear (test_traps) have their own restart checks.
#   godot --headless --path . --script res://src/worldgen/tools/test_restart_drill.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")

const DIR := "user://test_restart_drill"
const KEY := "restartdrill0001"

var failures: int = 0
var clock: Array = [8640000.0]


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make():
	var it = ItemsScript.new()
	it.send_full = func(_p, _b): pass
	it.send_slots = func(_p, _b): pass
	it.send_world_items = func(_p, _a, _r): pass
	it.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	it.send_notice = func(_p, _t): pass
	it.ground_height = func(_x, _z): return 10.0
	it.game_seconds = func(): return clock[0]
	it.setup(ItemTableScript.load_default(), DIR)
	return it


func n(it, id: String) -> int:
	return it.table.number_of(id)


func slot_of(it, id: String) -> int:
	var inv = it.inventory_of(1)

	for s in inv.slot_count:
		if inv.numbers[s] == n(it, id):
			return s

	return -1


func place(it, kind: String, x: float) -> int:
	var id: int = it.dev_place("%s@%s,0,0" % [kind, str(x)])
	it._items[id]["pos"] = Vector3(x, 10.0, 0.0)
	it._water_add(id)
	return id


func box_of(it, id: int):
	it.report_position(1, it._items[id]["pos"])
	return it._chest_of(1, id)


# What a player would look at after the restart, read the same way from any instance.
func snapshot(it, ids: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	it.peer_connected_hello(1, KEY)
	var inv = it.inventory_of(1)
	out["pack_apples"] = inv.count_of(n(it, "apple_keeping"))
	out["pack_stone"] = inv.count_of(n(it, "stone"))
	out["fed"] = snappedf(float(it.vitals_of(1).get("fed", -1.0)), 0.01)
	out["health"] = snappedf(float(it.vitals_of(1).get("health", -1.0)), 0.01)

	for name in ids:
		var found: int = -1

		for k in it._items:   # found again by kind and place (ids are kept, but a reload must not depend on that)
			var row: Dictionary = it._items[k]

			if str(row.get("struct", {}).get("kind", "")) == str(ids[name][0]) and (row["pos"] as Vector3).distance_to(ids[name][1]) < 0.2:
				found = k
			elif name == "fire" and row.has("fire") and (row["pos"] as Vector3).distance_to(ids[name][1]) < 0.2:
				found = k

		out[name + "_there"] = found != -1

		if found == -1:
			continue

		match name:
			"store":
				out["store_apples"] = box_of(it, found).count_of(n(it, "apple_keeping"))
			"water":
				var wbox = box_of(it, found)
				out["water_litres"] = snappedf(it._water.litres(found, it._water_now_s()), 0.1)
				out["water_skins"] = wbox.count_of(n(it, "waterskin"))
			"chest":
				out["chest_stone"] = box_of(it, found).count_of(n(it, "stone"))
			"fire":
				var fire: Dictionary = it._items[found]["fire"]
				out["fire_state"] = int(fire["state"])
				out["fire_firewood"] = snappedf(float(fire["wood"]["firewood"]), 0.1)
				out["fire_left"] = snappedf(float(it._items[found].get("left", -1.0)), 1.0)
			"snare":
				out["snare_owner"] = str(it._items[found]["struct"].get("owner", ""))   # set_at and away_at are not saved: nothing reads set_at, and away_at restarts at the next look (the hours a server was off are not game time)

	it.peer_left(1)
	return out


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	for file in DirAccess.get_files_at(DIR + "/" + ItemsScript.AREA_DIR):
		DirAccess.remove_absolute(DIR + "/" + ItemsScript.AREA_DIR + "/" + file)

	var a = make()
	a.peer_connected_hello(1, KEY)
	a.report_position(1, Vector3(0.0, 10.0, 0.0))
	a.vitals_of(1)["weight"] = 1.0e6   # the carry limit is not what is tested
	var inv = a.inventory_of(1)

	# A Storage barrel of keeping apples, a Water barrel with 40 L and a waterskin, a chest of stone, a lit campfire, a set snare.
	var store: int = place(a, "storage_barrel", 0.0)
	a.give(1, n(a, "apple_keeping"), 2500)
	a._box_put(1, inv, store, box_of(a, store), slot_of(a, "apple_keeping"), 2000)
	var water: int = place(a, "wooden_barrel", 4.0)
	a._water.set_litres(water, 40.0)
	a._water_dirty = true
	a.give(1, n(a, "waterskin"), 1)
	a._box_put(1, inv, water, box_of(a, water), slot_of(a, "waterskin"), 1)
	var chest: int = place(a, "chest", 8.0)
	a.give(1, n(a, "stone"), 30)
	a._box_put(1, inv, chest, box_of(a, chest), slot_of(a, "stone"), 20)
	var fire: int = a.dev_place("campfire@12,0,0,lit,firewood")
	a._items[fire]["pos"] = Vector3(12.0, 10.0, 0.0)
	var snare: int = a._next_id
	a._next_id += 1
	a._items[snare] = {"number": 1, "count": 1, "pos": Vector3(16.0, 10.0, 0.0), "left": 1.0e9, "wear": 0, "struct": {"kind": "snare_trap", "yaw": 0.0}}
	a._traps.on_placed(1, snare)
	a._dirty = true   # the snare was laid by hand above (the real placing path marks the save itself)
	a.vitals_of(1)["fed"] = 63.0
	var ids: Dictionary = {"store": ["storage_barrel", Vector3(0.0, 10.0, 0.0)], "water": ["wooden_barrel", Vector3(4.0, 10.0, 0.0)],
		"chest": ["chest", Vector3(8.0, 10.0, 0.0)], "fire": ["", Vector3(12.0, 10.0, 0.0)], "snare": ["snare_trap", Vector3(16.0, 10.0, 0.0)]}
	check(store != 0 and water != 0 and chest != 0 and fire != 0 and a._items[fire].has("fire"), "the barrels, chest and lit campfire are placed")
	var before: Dictionary = snapshot(a, ids)
	a.peer_connected_hello(1, KEY)
	check(int(before.get("store_apples", 0)) == 2000 and int(before.get("water_skins", 0)) == 1 and float(before.get("water_litres", 0.0)) > 39.0 and int(before.get("chest_stone", 0)) == 20 and int(before.get("fire_state", 0)) > 0, "the world before the restart (%s)" % str(before))

	# 1. A clean stop: the shutdown save, then a new server on the same files.
	a.note_spots_on_close()
	a.save()
	a._finish_writer()
	var b = make()
	var after_clean: Dictionary = snapshot(b, ids)
	var lost: Array = before.keys().filter(func(k): return after_clean.get(k) != before[k])
	check(lost.is_empty(), "after a clean stop everything is back (%s)" % ", ".join(PackedStringArray(lost.map(func(k): return "%s %s -> %s" % [k, str(before[k]), str(after_clean.get(k))]))))

	# 2. A hard kill: changes made, then only the periodic save (no forced dirty flag, no shutdown save), then the process is gone.
	b.peer_connected_hello(1, KEY)
	b.report_position(1, Vector3(0.0, 10.0, 0.0))
	var binv = b.inventory_of(1)
	var bstore: int = -1
	var bchest: int = -1
	var bwater: int = -1

	for k in b._items:
		match str(b._items[k].get("struct", {}).get("kind", "")):
			"storage_barrel": bstore = k
			"chest": bchest = k
			"wooden_barrel": bwater = k

	b._box_take(1, binv, box_of(b, bstore), box_of(b, bstore).numbers.find(n(b, "apple_keeping")), 500)
	b._box_put(1, binv, bchest, box_of(b, bchest), slot_of(b, "stone"), 10)
	b._water.set_litres(bwater, 25.0)
	b._water_dirty = true
	var moved: Dictionary = snapshot(b, ids)
	b.peer_connected_hello(1, KEY)
	b._autosave()   # the tick's periodic save: written off the tick by the background writer
	b._finish_writer()
	var c = make()   # the killed server's files, read by the next start
	var after_kill: Dictionary = snapshot(c, ids)
	lost = moved.keys().filter(func(k): return after_kill.get(k) != moved[k])
	check(lost.is_empty(), "after a hard kill the last periodic save has every change (%s)" % ", ".join(PackedStringArray(lost.map(func(k): return "%s %s -> %s" % [k, str(moved[k]), str(after_kill.get(k))]))))
	check(int(moved.get("chest_stone", 0)) == 30, "the drill moved stone into the chest before the kill (%s)" % str(moved.get("chest_stone")))

	# 3. A hard kill after a change that is only water: a Water barrel filled by rain (no box opened, nothing else changed).
	var wc: int = -1

	for k in c._items:
		if str(c._items[k].get("struct", {}).get("kind", "")) == "wooden_barrel":
			wc = k

	c._finish_writer()
	c._dirty = false   # the world as saved: only the water moves next
	c._water.set_litres(wc, 12.0)
	c._water_dirty = true
	c._autosave()
	c._finish_writer()
	var d = make()
	var only_water: Dictionary = snapshot(d, ids)
	check(absf(float(only_water.get("water_litres", -1.0)) - 12.0) < 0.2, "a water-only change is in the periodic save (%s L)" % str(only_water.get("water_litres")))

	# 4. A hard kill after a player only lived (hunger and thirst moved, nothing picked up or built): the periodic save has their vitals.
	d.peer_connected_hello(1, KEY)
	d._finish_writer()
	d._dirty = false
	d.vitals_of(1)["fed"] = 63.0
	d.vitals_of(1)["weight"] = float(d._new_vitals()["weight"])   # a normal body (the 1e6 above only lifted the carry limit)

	for t in 3:
		d._vitals_tick(1.0)

	var fed_now: float = snappedf(float(d.vitals_of(1)["fed"]), 0.01)
	d._autosave()
	d._finish_writer()
	var e = make()
	e.peer_connected_hello(1, KEY)
	check(absf(float(e.vitals_of(1)["fed"]) - fed_now) < 0.05 and fed_now < 63.0 and fed_now > 1.0, "a player's hunger is in the periodic save (%.2f saved, %.2f now)" % [float(e.vitals_of(1)["fed"]), fed_now])
	print("restart drill: %d failures" % failures)
	quit(1 if failures > 0 else 0)
