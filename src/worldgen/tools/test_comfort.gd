extends SceneTree

# Comfort and the Rested buff (docs/COMFORT_DESIGN.md section 7; Tyler 31 Oct 2026): level 0 outside cover; sheltered alone = 1; a rough bed adds its point; five chairs count once;
# an unlit campfire adds 0, a lit one 1; only the best bed counts; far and other-floor pieces do not count; a rest at comfort 2 or more earns a 45 real minute buff with the tier of
# its level; a rest at a lower level does not shorten or lower it, an equal or higher one refreshes it; it is saved; death clears it.
#   godot --headless --path . --script res://src/worldgen/tools/test_comfort.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")

var failures: int = 0
var items
var covered: Array = [true]


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func add_struct(kind: String, at: Vector3) -> int:
	var id: int = items._next_id
	items._items[id] = {"number": 0, "count": 1, "pos": at, "left": 1.0e9, "struct": {"kind": kind, "yaw": 0.0}}
	items._next_id += 1
	return id


func level() -> int:
	return int(items.comfort_at(1, true)["level"])


func _init() -> void:
	var dir: String = "user://test_comfort"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, _t): pass
	items.ground_height = func(_x, _z): return 10.0
	items.cover_at = func(_p): return 1.0 if covered[0] else 0.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "comfort000001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	covered[0] = false
	check(level() == 0 and not bool(items.comfort_at(1, true)["sheltered"]), "outside any cover the level is 0")
	add_struct("chair", Vector3(2.0, 10.0, 0.0))
	check(level() == 0, "a chair does not comfort someone who is not sheltered")
	covered[0] = true
	check(level() == 3, "sheltered (1) plus a chair (2) = 3")

	for n in range(5):
		add_struct("chair", Vector3(1.0 + float(n) * 0.2, 10.0, 1.0))

	check(level() == 3, "five more chairs count as the same one kind (still 3)")
	add_struct("rough_bed", Vector3(0.0, 10.0, 3.0))
	check(level() == 4, "a rough bed adds 1 (4)")
	add_struct("straw_bed", Vector3(0.0, 10.0, -3.0))
	check(level() == 5, "only the best bed counts: a straw bed (2) instead of the rough one (5)")
	var fire: int = items._next_id
	items._items[fire] = {"number": 0, "count": 1, "pos": Vector3(3.0, 10.0, 0.0), "left": 1.0e9, "fire": {"state": 9, "burn_left": 100.0}}
	items._next_id += 1
	check(level() == 5, "a laid, unlit fire adds nothing")
	items._items[fire]["fire"]["state"] = 1
	check(level() == 6, "the same fire lit adds 1 (6)")
	var torch: int = add_struct("wall_torch", Vector3(-2.0, 10.0, 0.0))
	check(level() == 6, "an unlit wall torch adds nothing")
	items._items[torch]["struct"]["lit"] = true
	check(level() == 7, "a lit wall torch adds 1 (7)")
	add_struct("workbench", Vector3(-4.0, 10.0, 4.0))
	add_struct("chest", Vector3(4.0, 10.0, 4.0))
	check(level() == 9, "workbench (1) and chest (1) add 2 (9)")
	add_struct("bench", Vector3(40.0, 10.0, 40.0))
	check(level() == 9, "a bench 56 m away adds nothing")
	var upstairs: int = add_struct("table", Vector3(0.0, 20.0, 0.0))
	check(level() == 9, "a table on another floor (10 m up) adds nothing")
	items._items.erase(upstairs)

	# The Rested buff.
	covered[0] = false
	check(not items.rest_completed(1), "resting unsheltered earns nothing")
	covered[0] = true
	check(items.rest_completed(1) and absf(items.rested_seconds_left(1) - 45.0 * 60.0) < 5.0, "a rest at comfort 9 earns 45 real minutes (%.0f s)" % items.rested_seconds_left(1))
	var tier: Dictionary = items.rested_tier(1)
	check(float(tier["regen_mult"]) == 1.2 and float(tier["exhaustion_mult"]) == 0.85, "comfort 9 gets the 5-to-9 tier (regen x%.2f, exhaustion x%.2f)" % [float(tier["regen_mult"]), float(tier["exhaustion_mult"])])
	items._characters[items._peer_key[1]]["rested"]["until"] = Time.get_unix_time_from_system() + 600.0
	items._items.erase(fire)
	items._items.erase(torch)
	var lower: int = level()
	items.rest_completed(1)
	check(lower < 9 and items.rested_seconds_left(1) <= 605.0 and items.rested_tier(1).get("regen_mult", 0.0) == 1.2, "a rest at a lower level (%d) does not refresh or lower the buff (%.0f s left)" % [lower, items.rested_seconds_left(1)])
	add_struct("hide_rug", Vector3(2.0, 10.0, -2.0))
	add_struct("wool_rug", Vector3(2.5, 10.0, -2.0))
	add_struct("table", Vector3(-3.0, 10.0, -3.0))
	var place: int = add_struct("fireplace", Vector3(5.0, 10.0, -1.0))
	items._items[place]["struct"]["lit"] = true
	var higher: int = level()
	items.rest_completed(1)
	check(higher >= 15 and items.rested_seconds_left(1) > 44.0 * 60.0 and float(items.rested_tier(1)["regen_mult"]) == 1.35, "a rest at a higher level (%d) refreshes it to 45 minutes with the better tier" % higher)

	# Lights: E with the fuel lights a wall torch; it counts while it burns and goes out when the fuel is used up.
	var lamp: int = add_struct("wall_torch", Vector3(-5.0, 10.0, -2.0))
	items.report_position(1, Vector3(-4.0, 10.0, -2.0))
	var before_lamp: int = level()
	items._use_struct(1, items.inventory_of(1), lamp)
	check(not bool(items._items[lamp]["struct"].get("lit", false)) and level() == before_lamp, "without a stick the torch does not light")
	items.inventory_of(1).add(items.table.number_of("stick"), 2)
	items._use_struct(1, items.inventory_of(1), lamp)
	check(bool(items._items[lamp]["struct"].get("lit", false)) and level() == before_lamp + 1, "with a stick the torch burns and adds 1")
	items._lights_tick(1799.0)
	check(bool(items._items[lamp]["struct"].get("lit", false)), "it still burns after 1799 s")
	items._lights_tick(5.0)
	check(not bool(items._items[lamp]["struct"].get("lit", false)) and level() == before_lamp, "and goes out when the stick is used up")

	# The HUD message (protocol 80): level, buff level, whole minutes; told once, again when something changes.
	var told: Array = []
	items.send_comfort = func(_p, l, r, m): told.append([l, r, m])
	items._comfort_tick()
	items._comfort_tick()
	check(told.size() == 1 and told[0][0] == level() and told[0][1] > 0 and told[0][2] > 40, "the client is told the comfort level, the buff and its minutes once (%s)" % str(told))
	items._characters[items._peer_key[1]].erase("rested")
	items._comfort_tick()
	check(told.size() == 2 and told[1][1] == 0 and told[1][2] == 0, "and again when the buff ends")
	var View := load("res://src/client/inventory_view.gd")
	check(View.comfort_text(7, 2, 38) == "Comfort 7   Rested 38 min" and View.comfort_text(0, 0, 0) == "" and View.comfort_text(3, 0, 0) == "Comfort 3", "the HUD words: 'Comfort 7   Rested 38 min'")

	items.rest_completed(1)   # earn it again for the save check below

	# Saved and cleared.
	items._save_characters()
	items._finish_writer()
	var again = ItemsScript.new()
	again.send_full = func(_p, _b): pass
	again.send_slots = func(_p, _b): pass
	again.send_world_items = func(_p, _a, _r): pass
	again.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	again.send_notice = func(_p, _t): pass
	again.ground_height = func(_x, _z): return 10.0
	again.setup(ItemTableScript.load_default(), dir)
	again.peer_connected_hello(1, "comfort000001")
	check(again.rested_seconds_left(1) > 40.0 * 60.0, "the buff is saved with the character (%.0f s left after a reload)" % again.rested_seconds_left(1))
	items._characters[items._peer_key[1]].erase("rested")
	check(items.rested_tier(1).is_empty(), "without a buff there is no tier")
	print("comfort: %d failures" % failures)
	quit(1 if failures > 0 else 0)
