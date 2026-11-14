extends SceneTree

# Wells in three tiers (plumbing PR 1, docs/design/PLUMBING_DESIGN.md s4; Dave 14 Nov 2026 06:35Z; every number PROVISIONAL): Primitive - Well,
# Improved - Well (the old stone_well, id kept) and Advanced - Well are water-network sources worked with E (a windlass); each holds at most a day's
# yield (100, 200, 600 L), what is drawn comes out of it, a drawn-dry well stops and refuses until it fills again over the game day, and the store is
# saved in crops.json "wells" by position. The real structures.json and blueprints.json rows, not stand-ins.
#   godot --headless --path . --script res://src/worldgen/tools/test_wells.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const GameClockScript := preload("res://src/shared/game_clock.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const Network := preload("res://src/shared/water_network.gd")

var failures: int = 0
var items
var clock: Array = [0.0]
var said: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make(dir: String):
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var it = ItemsScript.new()
	it.send_full = func(_p, _b): pass
	it.send_slots = func(_p, _b): pass
	it.send_world_items = func(_p, _a, _r): pass
	it.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	it.send_notice = func(_p, t): said.append(str(t))
	it.ground_height = func(_x, _z): return 10.0
	it.game_seconds = func(): return clock[0]
	it.setup(ItemTableScript.load_default(), dir)
	it.fresh_water_y = func(pos, _reach): return 2.0 if pos.z > 400.0 else 6.0   # 4 m down, or 8 m down past z 400
	return it


func put(kind: String, pos: Vector3) -> int:
	var id: int = items._next_id
	items._items[id] = {"number": items.table.number_of(str(items._structures[kind]["item"])), "count": 1, "pos": pos, "left": 1.0e9, "struct": {"kind": kind, "yaw": 0.0}}
	items._next_id += 1
	items._water_add(id)
	return id


func _init() -> void:
	items = make("user://test_wells")
	var bp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/blueprints.json"))["blueprints"]

	# Data: three tiers, named as Dave named them, each yielding more than the last, built with the hammer from the start.
	var yields: Array = []

	for row in [["primitive_well", "Primitive - Well", 6.0], ["stone_well", "Improved - Well", 25.0], ["advanced_well", "Advanced - Well", 40.0]]:
		var water: Dictionary = items._structures[row[0]].get("water", {})
		yields.append(float(water.get("yield_l_day", 0.0)))
		check(str(water.get("role", "")) == "source" and bool(water.get("ground_water", false)) and bool(water.get("windlass", false)) and is_equal_approx(float(water.get("max_depth_m", 0.0)), row[2]), "%s is a ground-water windlass source reaching %d m" % [row[0], int(row[2])])
		check(str(bp[row[0]]["name"]) == row[1] and bool(bp[row[0]].get("known", false)) and not bool(bp[row[0]].get("locked", false)), "blueprint %s is %s, known and unlocked" % [row[0], row[1]])
		check(items.table.name_of(items.table.number_of(row[0])) == row[1], "item %s is named %s" % [row[0], row[1]])

	check(yields == [100.0, 200.0, 600.0], "daily yields 100, 200 (double), 600 L (%s)" % str(yields))

	# The Primitive well reaches 6 m: over water 8 m down it is refused, the Improved one may go there.
	check(items._water_refusal(items._structures["primitive_well"], Vector3(100.0, 10.0, 450.0), 0) == "The water lies 8 m down here, too deep for this.", "a Primitive well over water 8 m down is refused")
	check(items._water_refusal(items._structures["stone_well"], Vector3(100.0, 10.0, 450.0), 0) == "", "an Improved well reaches it")

	# A new well is full.
	check(is_equal_approx(items._well_left(put("primitive_well", Vector3(50.0, 10.0, 100.0))), 100.0), "a new Primitive well holds its 100 L")
	check(is_equal_approx(float(items._structures["primitive_well"]["water"]["draw_l"]), 3.0), "the Primitive well hauls a 3 L clay pot")
	var well: int = put("stone_well", Vector3(100.0, 10.0, 100.0))
	check(is_equal_approx(items._well_left(well), 200.0), "a new Improved well holds its 200 L (%.1f)" % items._well_left(well))

	# E draws with the windlass: 10 L a bucket each 4 + 1.5 x 4 s at 4 m down, 60 L/min; what is poured comes out of the well.
	items.peer_connected_hello(1, "drawer000001")
	items.report_position(1, Vector3(101.0, 10.0, 100.0))
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("bucket"), 0, 1, Vector3.ZERO)
	var inv = items.inventory_of(1)
	var bucket: int = inv.numbers.find(items.table.number_of("bucket"))
	items._use_struct(1, inv, well)
	check(int(items._pumping.get(1, 0)) == well and is_equal_approx(float(items._water.pieces[well]["rate_lpm"]), Network.windlass_lpm(4.0, 10.0)), "E starts drawing at the windlass rate (%.1f L/min)" % float(items._water.pieces[well].get("rate_lpm", 0.0)))
	items._water_tick(5.0)
	check(bucket >= 0 and int(inv.wear[bucket]) == 5000 and absf(items._well_left(well) - 195.0) < 0.01, "5 s pour 5 L into the bucket and the well holds 195 L (%d ml, %.2f L)" % [int(inv.wear[bucket]) if bucket >= 0 else -1, items._well_left(well)])
	items._water_tick(5.0)
	check(int(inv.wear[bucket]) == 8000 and absf(items._well_left(well) - 192.0) < 0.01, "a full bucket takes only its 8 L: the well gives only what was poured (%.2f L left)" % items._well_left(well))

	# Drawn dry: it stops, says so and refuses E until it fills again.
	items._stop_pump(1, "")
	inv.wear[bucket] = 0
	items._well_store[well] = [3.0, clock[0]]
	items._use_struct(1, inv, well)
	items._water_tick(10.0)
	check(not items._pumping.has(1) and int(inv.wear[bucket]) == 3000 and items._well_left(well) < 0.01, "3 L left: the bucket gets 3 L and the well stops (%d ml)" % int(inv.wear[bucket]))
	check(said.has("The well is drawn dry. It fills again through the day."), "and says it is drawn dry")
	said.clear()
	items._use_struct(1, inv, well)
	check(not items._pumping.has(1) and said.has("The well is drawn dry. It fills again through the day."), "E on a dry well draws nothing")

	# It fills again at its yield over a game day, never past one day's water.
	clock[0] += GameClockScript.SECONDS_PER_DAY * 0.5
	check(absf(items._well_left(well) - 100.0) < 0.01, "half a game day later it holds 100 L (%.2f)" % items._well_left(well))
	clock[0] += GameClockScript.SECONDS_PER_DAY * 3.0
	check(is_equal_approx(items._well_left(well), 200.0), "and never more than a day's 200 L")

	# Saved by place and back at load.
	items._well_store[well] = [40.0, clock[0]]
	var wells: Dictionary = items._wells_save()
	check(is_equal_approx(float((wells.get(items._water_key(Vector3(100.0, 10.0, 100.0)), [-1.0]) as Array)[0]), 40.0), "a well's 40 L are saved by its place")
	items._water_rebuild({}, wells)
	check(items._well_store.has(well) and absf(items._well_left(well) - 40.0) < 0.01, "and come back at load (%.2f)" % items._well_left(well))
	items._water_rebuild({}, {})
	check(is_equal_approx(items._well_left(well), 200.0), "a well with nothing saved loads full")

	# The Advanced well holds 600 L; a well taken down leaves its store.
	var big: int = put("advanced_well", Vector3(300.0, 10.0, 100.0))
	check(is_equal_approx(items._well_left(big), 600.0), "a new Advanced well holds 600 L")
	items._items.erase(big)
	items._water_tick(0.0)
	check(not items._well_store.has(big), "a well taken down leaves the store")

	print("wells: %d failures" % failures)
	quit(1 if failures > 0 else 0)
