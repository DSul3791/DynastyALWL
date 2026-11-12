extends SceneTree

# Dave's stump rule (1 Nov 2026): a stump still in the ground is chopped up on the spot. It does not fall over, no log is left on the ground, the stump is gone and the player receives
# firewood and kindling in the pack.
#   godot --headless --path . --script res://src/worldgen/tools/test_stump_chop.gd

const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var dir: String = "user://test_stump_chop_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(dir)
	var w = ItemsScript.new()
	w.send_full = func(_p, _b): pass
	w.send_slots = func(_p, _b): pass
	w.send_world_items = func(_p, _a, _r): pass
	w.setup(ItemTableScript.load_default(), dir)
	w.ground_height = func(_x, _z): return 10.0
	var standing: Dictionary = {7: true}
	w.game_seconds = func(): return 5000.0
	w.tree_info = func(_c, id): return {"name": "oak", "position": Vector3(10.0, 10.0, 0.0), "height": 18.0, "trunk": 0.3} if standing.has(id) else {}
	w.cut_tree = func(_c, id): standing.erase(id); return true
	w.peer_connected_hello(1, "abcdef123456")
	w.report_position(1, Vector3(8.0, 10.0, 0.0))
	w.action(1, Net.ACT_ADMIN_GIVE, w.table.number_of("stone_axe"), 0, 1, Vector3.ZERO)

	for n in range(20):
		w._last_hit.clear()
		w.action(1, Net.ACT_HIT, 7, 0, 0, HeldTool.at_axe(w))

	var stump_id: int = 0

	for k in w._items:
		if w._items[k].has("tree") and int(w._items[k]["tree"]["state"]) == 4:
			stump_id = k

	check(stump_id != 0, "felling leaves a stump in the ground")
	var logs_before: int = _loose(w, w.table.number_of("log_oak"))
	var firewood_n: int = w.table.number_of("firewood_oak") if w.table.number_of("firewood_oak") > 0 else w.table.number_of("firewood")
	var kindling_n: int = w.table.number_of("kindling")
	w.report_position(1, w._items[stump_id]["pos"] + Vector3(1.0, 0.0, 0.0))
	w._last_process.clear()
	w.action(1, Net.ACT_PROCESS, stump_id, 0, 0, Vector3.ZERO)
	check(int(w._items[stump_id]["tree"].get("blows", 0)) == 0, "nothing in hand (the axe only on the hotbar): the stump is not chopped (TEST-013)")
	var guard: int = 0

	while w._items.has(stump_id) and guard < 30:
		w._last_process.clear()
		w.action(1, Net.ACT_PROCESS, stump_id, 0, 0, HeldTool.at_axe(w))
		guard += 1

	check(not w._items.has(stump_id), "the stump is gone after the last blow (%d blows)" % guard)
	check(_loose(w, w.table.number_of("log_oak")) == logs_before, "no log was left on the ground by chopping the stump")
	check(w.inventory_of(1).count_of(firewood_n) > 0, "the player receives firewood")
	check(w.inventory_of(1).count_of(kindling_n) > 0, "the player receives kindling")
	var cfg: Dictionary = w._drops.get("stump", {})
	check(int(w._stump_final_rows(cfg, 0.15)[0][2]) == 2, "a small stump (0.15 m) gives the small row (1 to 2 firewood)")
	check(int(w._stump_final_rows(cfg, 0.3)[0][2]) == 4, "a medium stump (0.3 m) gives the medium row (2 to 4 firewood)")
	check(int(w._stump_final_rows(cfg, 0.9)[0][2]) == 5, "a large stump (0.9 m, no limit) gives the large row (3 to 5 firewood)")
	_tool_tiers(dir)
	print("stump chop tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func _loose(w, number: int) -> int:
	var n: int = 0

	for k in w._items:
		var it: Dictionary = w._items[k]

		if not it.has("tree") and not it.has("struct") and int(it["number"]) == number:
			n += 1

	return n


# TEST-013 (Dave 12 Nov 2026): "the axe should be the same for wood" (a better axe fells in fewer blows); "it would take a very very long time for
# a pickaxe to cut down a tree"; "using a pickaxe on a tree or a log will give you thatch, and kindling. not sticks or wood. if you break a log
# with a pickaxe it will just leave a pile of kindling"; "a tree cant dull a pickaxe".
func _tool_tiers(dir: String) -> void:
	var w = ItemsScript.new()
	w.send_full = func(_p, _b): pass
	w.send_slots = func(_p, _b): pass
	w.send_world_items = func(_p, _a, _r): pass
	w.setup(ItemTableScript.load_default(), dir + "_tiers")
	w.ground_height = func(_x, _z): return 10.0
	var standing: Dictionary = {11: true, 12: true, 13: true}
	w.game_seconds = func(): return 5000.0
	w.tree_info = func(_c, id): return {"name": "oak", "position": Vector3(10.0, 10.0, 0.0), "height": 18.0, "trunk": 0.3} if standing.has(id) else {}
	w.cut_tree = func(_c, id): standing.erase(id); return true
	w.peer_connected_hello(1, "tiers0000001")
	w.vitals_of(1)["weight"] = 5000.0
	w.report_position(1, Vector3(8.0, 10.0, 0.0))
	var inv = w.inventory_of(1)

	for id in ["stone_axe", "bronze_axe", "stone_pickaxe"]:
		w.action(1, Net.ACT_ADMIN_GIVE, w.table.number_of(id), 0, 1, Vector3.ZERO)

	var stone_axe: int = inv.numbers.find(w.table.number_of("stone_axe"))
	var bronze_axe: int = inv.numbers.find(w.table.number_of("bronze_axe"))
	var pick: int = inv.numbers.find(w.table.number_of("stone_pickaxe"))
	var stone_blows: int = _fell(w, standing, 11, stone_axe)
	var bronze_blows: int = _fell(w, standing, 12, bronze_axe)
	var sticks_before: int = inv.count_of(w.table.number_of("stick"))
	var kindling_before: int = inv.count_of(w.table.number_of("kindling"))
	var pick_blows: int = _fell(w, standing, 13, pick)
	check(stone_blows > 0 and bronze_blows > 0 and bronze_blows < stone_blows, "a bronze axe fells a tree in fewer blows than a stone axe (%d, %d)" % [bronze_blows, stone_blows])
	check(pick_blows >= stone_blows * 5, "a pickaxe takes a very long time to fell a tree (%d blows, a stone axe %d)" % [pick_blows, stone_blows])
	check(inv.count_of(w.table.number_of("stick")) == sticks_before and inv.count_of(w.table.number_of("kindling")) > kindling_before and inv.count_of(w.table.number_of("thatch")) > 0, "pick blows on a tree give kindling and thatch, no sticks")
	check(int(inv.wear[pick]) == 0 and int(inv.inst_of(pick).get("sharp", 0)) == 0, "the tree neither wears nor dulls the pick (wear %d)" % int(inv.wear[pick]))

	# A small log on the ground broken with the pick: a pile of kindling where it lay, after 1 / speed blows.
	var log_n: int = w.table.number_of("log")
	w.drop_in_world(log_n, 1, Vector3(9.0, 10.0, 0.0))
	var log_id: int = 0

	for k in w._items:
		if int(w._items[k]["number"]) == log_n and not w._items[k].has("tree"):
			log_id = k

	var guard: int = 0

	while w._items.has(log_id) and guard < 30:
		w._last_process.clear()
		w.action(1, Net.ACT_PROCESS, log_id, 0, 0, Vector3(float(pick + 1), 0.0, 0.0))
		guard += 1

	var pile: int = 0

	for k in w._items:
		if int(w._items[k]["number"]) == w.table.number_of("kindling"):
			pile += int(w._items[k]["count"])

	check(log_id != 0 and not w._items.has(log_id) and guard == 7, "a stone pick breaks a log in 7 blows (%d)" % guard)
	check(pile == int(w._drops["wood_tools"]["pick_log_kindling"]["small"]) and _loose(w, w.table.number_of("block")) == 0, "it leaves a pile of %d kindling and no blocks" % pile)
	check(int(inv.wear[pick]) == 0, "nor does a log wear the pick")


# Blows with the tool in `slot` until the tree is down (at most 200).
func _fell(w, standing: Dictionary, id: int, slot: int) -> int:
	var n: int = 0

	while standing.has(id) and n < 200:
		w._last_hit.clear()
		w.action(1, Net.ACT_HIT, id, 0, 0, Vector3(float(slot + 1), 0.0, 0.0))
		n += 1

	return n if not standing.has(id) else -1
