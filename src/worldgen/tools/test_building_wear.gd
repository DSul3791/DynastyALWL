extends SceneTree

# Building wear and hammer repair (src/shared/building_wear.gd, data/items/building_wear.json, server_items.gd _repair_struct): condition falls with the
# square of the time since care down to the material's floor, a repair costs part of the blueprint materials (ground, then containers, then pack),
# and sets the piece back to full.
#   godot --headless --path . --script res://src/worldgen/tools/test_building_wear.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const Wear := preload("res://src/shared/building_wear.gd")

var failures: int = 0
var items
var clock: float = 1000.0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _give(id: String, count: int) -> void:
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of(id), 0, count, Vector3.ZERO)


func _have(id: String) -> int:
	return items.inventory_of(1).count_of(items.table.number_of(id))


func _clear() -> void:
	var inv = items.inventory_of(1)

	for slot in range(inv.SLOTS):
		inv.numbers[slot] = 0
		inv.counts[slot] = 0
		inv.wear[slot] = 0


func _init() -> void:
	var cfg: Dictionary = Wear.load_config()
	var log_rule: Dictionary = Wear.rule_for(cfg, "log_wall")
	check(not log_rule.is_empty() and Wear.rule_for(cfg, "stone_wall").is_empty() and Wear.rule_for(cfg, "chest").is_empty(), "log walls wear; stone walls and chests do not")
	check(is_equal_approx(Wear.condition(log_rule, 0.0, 0.0), 1.0), "new is full condition")
	check(is_equal_approx(Wear.condition(log_rule, 0.0, float(log_rule["T_s"]) * 0.5), 1.0 - 0.5 * 0.25), "half the time to failure has lost a quarter of the way to the floor (squared)")
	check(is_equal_approx(Wear.condition(log_rule, 0.0, float(log_rule["T_s"]) * 10.0), 0.5), "it never goes below the floor")
	var needs: Array = Wear.repair_needs([["log", 6], ["twine", 2]], 0.5, 0.5)
	check(needs == [["log", 2], ["twine", 1]], "half worn, half share: 2 of 6 logs, at least 1 twine (%s)" % str(needs))

	var dir: String = "user://test_building_wear"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.ground_height = func(_x, _z): return 10.0
	items.game_seconds = func(): return clock
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "wearkey1")
	items.report_position(1, Vector3(200.0, 10.0, 200.0))
	var bp: Dictionary = {}

	for row in JSON.parse_string(FileAccess.get_file_as_string("res://data/items/blueprints.json"))["blueprints"].values():
		if str(row["structure"]) == "log_wall" and not bool(row.get("retired", false)):
			bp = row

	_clear()
	_give("wooden_hammer", 1)
	_give("log", 6)
	_give("twine", 2)
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(bp["number"]), 0, 0, Vector3(200.0, 10.0, 202.0))
	var wall: int = 0

	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == "log_wall":
			wall = id

	check(wall != 0 and is_equal_approx(items.piece_condition(wall), 1.0), "a fresh log wall is in full condition")
	var before_repair: int = _have("log")
	items.action(1, Net.ACT_REPAIR_STRUCT, wall, 0, 0, Vector3.ZERO)
	check(_have("log") == before_repair, "a wall in good repair is not repaired and costs nothing")

	var rule: Dictionary = Wear.rule_for(items._wear_cfg, "log_wall")
	clock += float(rule["T_s"]) * 0.8
	var worn: float = items.piece_condition(wall)
	check(worn < 0.9 and worn >= 0.5, "after most of T the wall has worn (%f)" % worn)

	_clear()
	_give("wooden_hammer", 1)
	items.action(1, Net.ACT_REPAIR_STRUCT, wall, 0, 0, Vector3.ZERO)
	check(items.piece_condition(wall) < 0.9, "no materials: nothing is repaired")

	var need_logs: int = int(Wear.repair_needs(bp["cost"], worn, 0.5)[0][1])
	items.drop_in_world(items.table.number_of("twine"), 2, Vector3(200.0, 10.0, 203.0))
	_give("log", need_logs)
	items.action(1, Net.ACT_REPAIR_STRUCT, wall, 0, 0, Vector3.ZERO)
	check(is_equal_approx(items.piece_condition(wall), 1.0), "with the logs in the pack and the twine on the ground the wall is mended")
	check(_have("log") == 0 and _have("wooden_hammer") == 1, "exactly the logs were taken and the hammer kept")
	print("test_building_wear: %d fail" % failures)
	quit(1 if failures > 0 else 0)
