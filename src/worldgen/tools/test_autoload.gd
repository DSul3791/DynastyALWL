extends SceneTree

# Autoload (protocol 139; Dave 19 Nov 2026: "an autoload button on carts and wagons or barrels and such ... everything on the ground around you
# within say 30 meters in a list where you could choose an item and it would just pick up as much of it as it can until it fills the capacity or
# the weight limit"; "a check box beside it to make it continuously autoload every 10 minutes"). Real server state: a Small wagon loads stone
# nearest first up to its payload, taking part of a pile and leaving one past 30 m; a chest (no weight limit) takes part of one huge pile up to its
# slots; a rack refuses what it does not take; a kiln and a player out of reach get nothing; the standing autoload loads on its round, stops when
# unticked, is saved with the container and comes back after a restart.
#   godot --headless --path . --script res://src/worldgen/tools/test_autoload.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const CarryRules := preload("res://src/shared/carry_rules.gd")
const StoreRules := preload("res://src/shared/store_rules.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const DIR := "user://test_autoload"

var failures: int = 0
var items
var said: Dictionary = {}    # peer -> the last notice
var info: Dictionary = {}    # peer -> the last autoload_info [id, number]
var stone: int = 0
var clay: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make_server():
	var s = ItemsScript.new()
	s.send_full = func(_p, _b): pass
	s.send_slots = func(_p, _b): pass
	s.send_world_items = func(_p, _a, _r): pass
	s.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	s.send_notice = func(p, t): said[p] = t
	s.send_carry = func(_p, _id): pass
	s.send_chest = func(_p, _id, _b): pass
	s.send_chest_info = func(_p, _id, _k, _m): pass
	s.send_chest_lock = func(_p, _id, _l, _mi, _mo, _w, _a): pass
	s.send_autoload_info = func(p, id, number): info[p] = [id, number]
	s.send_craft_stock = func(_p, _n, _c): pass
	s.send_bulk_done = func(_p, _k, _s, _c, _i): pass
	s.ground_height = func(_x, _z): return 10.0
	s.setup(ItemTableScript.load_default(), DIR)
	s.admin_mode_on = func(_p): return false
	s.peer_connected_hello(1, "autoload001")
	s.peer_connected_hello(2, "autoload002")
	s.report_position(1, Vector3(0.0, 10.0, 0.0))
	s.report_position(2, Vector3(0.0, 10.0, 40.0))
	return s


func reset() -> void:
	for k in items._items.keys():
		if not items._items[k].has("tree") and not items._items[k].has("boulder"):
			items._items.erase(k)

	said.clear()
	info.clear()


func box(id: int):
	return items._chests[int(items._items[id]["struct"]["uid"])]


# One press; the presses' quarter-second spacing is cleared so the test can press at once.
func press(peer: int, id: int, number: int, keep: bool = false) -> void:
	items._autoload_pressed.clear()
	items.action(peer, Net.ACT_AUTOLOAD, id, number, 1 if keep else 0, Vector3.ZERO)


# A ground pile of `count` at (x, z), its world id. Big piles are written straight in (one record, as the planned boulder cones).
func pile(number: int, count: int, x: float, z: float) -> int:
	items.drop_in_world(number, mini(count, 100), Vector3(x, 10.0, z))
	var best: int = 0

	for id in items._items:
		var it: Dictionary = items._items[id]

		if int(it.get("number", 0)) == number and not it.has("struct") and Vector2(it["pos"].x - x, it["pos"].z - z).length() < 0.5:
			best = id

	items._items[best]["count"] = count
	return best


# The chest standing at (x, z) after a restart (world ids are the loaded ones), 0 none.
func chest_at(x: float, z: float) -> int:
	for id in items._items:
		var it: Dictionary = items._items[id]

		if it.has("struct") and str(it["struct"]["kind"]) == "chest" and Vector2(it["pos"].x - x, it["pos"].z - z).length() < 0.1:
			return id

	return 0


func ground_count(id: int) -> int:
	return int(items._items.get(id, {}).get("count", 0))


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	items = make_server()
	stone = items.table.number_of("stone")
	clay = items.table.number_of("clay")
	check(stone > 0 and clay > 0 and Net.ACT_AUTOLOAD == 84 and Net.PROTOCOL_VERSION >= 139, "protocol 139: ACT_AUTOLOAD 84, the test items are in the table")
	check(StoreRules.autoloads(items._structures["small_wagon"]) and StoreRules.autoloads(items._structures["wooden_barrel"]) and StoreRules.autoloads(items._structures["wooden_crate"]) and not StoreRules.autoloads(items._structures["kiln"]) and not StoreRules.autoloads(items._structures["smelter"]) and not StoreRules.autoloads(items._structures["remains"]) and not StoreRules.autoloads(items._structures["serving_platter"]) and not StoreRules.autoloads(items._structures["fish_trap_set"]), "carts, barrels and crates autoload; a kiln, smelter, remains, platter and fish trap do not")

	# 1. A Small wagon: stone nearest first up to its payload, a pile taken in part, the pile past 30 m left alone.
	reset()
	var wagon: int = items.dev_place("small_wagon@2,0,0")
	check(wagon != 0, "a Small wagon stands beside the player")
	var near_pile: int = pile(stone, 20, 6.0, 0.0)
	var big_pile: int = pile(stone, 5000, 20.0, 0.0)
	var far_pile: int = pile(stone, 50, 40.0, 0.0)
	press(1, wagon, stone)
	var each: float = CarryRules.weight_of("stone", items._carry_cfg)
	var payload: float = float(items._structures["small_wagon"]["max_kg"])
	var loaded: int = box(wagon).count_of(stone)
	check(loaded == int(floor(payload / each + 0.0001)) and loaded > 20, "the wagon takes as many stone as its %.0f kg payload holds (%d at %.2f kg)" % [payload, loaded, each])
	check(not items._items.has(near_pile) and ground_count(big_pile) == 5000 - (loaded - 20) and ground_count(far_pile) == 50, "the nearest pile went first and whole, the big one in part (%d left), the one 38 m off not at all" % ground_count(big_pile))
	check(str(said.get(1, "")).begins_with("Loaded %d stone" % loaded) and str(said.get(1, "")).contains("%d more" % ground_count(big_pile)), "the player is told what went in and what lies nearby (%s)" % str(said.get(1, "")))
	press(1, wagon, stone)
	check(box(wagon).count_of(stone) == loaded and ground_count(big_pile) == 5000 - (loaded - 20) and str(said.get(1, "")).contains("full"), "a full wagon takes no more and says so")

	# 2. A chest has no weight limit, only slots: one huge pile goes in up to its slots, the rest stays one pile.
	reset()
	var chest: int = items.dev_place("chest@1,0,0")
	var huge: int = pile(stone, 2000000, 10.0, 5.0)
	press(1, chest, stone)
	var room: int = box(chest).usable * 65535
	check(box(chest).count_of(stone) == room and ground_count(huge) == 2000000 - room, "a chest fills every slot from one 2,000,000 pile (%d in, %d left on the ground)" % [box(chest).count_of(stone), ground_count(huge)])

	# 3. What a container does not take stays on the ground; a kiln and a player out of reach get nothing.
	reset()
	var rack: int = items.dev_place("firewood_rack@1,0,0")
	var clay_pile: int = pile(clay, 30, 5.0, 0.0)
	press(1, rack, clay)
	check(box(rack).count_of(clay) == 0 and ground_count(clay_pile) == 30 and str(said.get(1, "")).contains("does not take"), "a firewood rack refuses clay (%s)" % str(said.get(1, "")))
	var kiln: int = items.dev_place("kiln@-2,0,0")
	press(1, kiln, clay)
	check(box(kiln).count_of(clay) == 0 and ground_count(clay_pile) == 30, "a kiln takes no part in Autoload")
	var far_chest: int = items.dev_place("chest@1,-3,0")
	press(2, far_chest, clay)
	check(box(far_chest).count_of(clay) == 0 and ground_count(clay_pile) == 30, "a player 40 m away cannot autoload it")

	# 4. The standing autoload: ticked, it loads now and on each round; a full one keeps its setting; unticked it stops.
	reset()
	var keeper: int = items.dev_place("chest@1,0,0")
	pile(clay, 10, 5.0, 0.0)
	press(1, keeper, clay, true)
	check(box(keeper).count_of(clay) == 10 and int(items._items[keeper]["struct"].get("autoload", 0)) == clay and info.get(1, []) == [keeper, clay], "ticked: it loads now, keeps the item and the player is told (autoload_info)")
	var later: int = pile(clay, 25, -6.0, 3.0)
	items._autoload_tick(ItemsScript.AUTOLOAD_EVERY_S - 1.0)
	check(ground_count(later) == 25, "nothing moves before the round comes")
	items._autoload_tick(1.0)
	check(box(keeper).count_of(clay) == 35 and not items._items.has(later), "the round %d s later loads what was dropped since" % int(ItemsScript.AUTOLOAD_EVERY_S))
	press(1, keeper, stone)
	check(int(items._items[keeper]["struct"].get("autoload", 0)) == 0, "a one-off load of another item ends the standing one")
	press(1, keeper, clay, true)
	items.save()
	items._finish_writer()
	items = make_server()
	keeper = chest_at(1.0, 0.0)
	check(int(items._items.get(keeper, {}).get("struct", {}).get("autoload", 0)) == clay, "the standing autoload is saved with the chest and comes back after a restart")
	press(1, keeper, 0)
	var after: int = pile(clay, 12, 4.0, 4.0)
	items._autoload_tick(ItemsScript.AUTOLOAD_EVERY_S)
	check(int(items._items[keeper]["struct"].get("autoload", 0)) == 0 and ground_count(after) == 12 and info.get(1, []) == [keeper, 0], "unticked: it stops and the next round leaves the clay on the ground")

	# 5. A locked crate: a stranger beside it without the code gets nothing; its owner loads it. A number that is no item does nothing.
	reset()
	var crate: int = items.dev_place("wooden_crate@1,0,0")
	items._items[crate]["struct"]["owner"] = str(items._peer_key[1])
	items.action(1, Net.ACT_CHEST_LOCK, crate, ItemsScript.LOCK_SET, 42, Vector3.ZERO)
	var locked_pile: int = pile(clay, 15, 4.0, 0.0)
	items.report_position(2, Vector3(0.0, 10.0, 1.0))
	press(2, crate, clay, true)
	check(items._items[crate]["struct"].has("lock") and box(crate).count_of(clay) == 0 and ground_count(locked_pile) == 15 and not items._items[crate]["struct"].has("autoload"), "a stranger cannot autoload a locked crate or set its standing autoload")
	press(1, crate, 999999, true)
	check(not items._items[crate]["struct"].has("autoload") and ground_count(locked_pile) == 15, "an item number that is no item does nothing")
	press(1, crate, clay)
	check(box(crate).count_of(clay) == 15 and not items._items.has(locked_pile), "its owner loads it")

	print("autoload: %s" % ("all passed" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)
