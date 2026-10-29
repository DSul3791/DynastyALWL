extends SceneTree

# Campfire dishes (Radar, 2026-10-22): every dish in data/items/dishes.json is made at a lit campfire (the hearth and oven dishes at an oven) from its ingredients, not away from
# one, feeds the stomach by its food points, and a dish with more kinds of ingredient is better (food points never fall as kinds rise).
#   godot --headless --path . --script res://src/worldgen/tools/test_dishes.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var items


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var dir: String = "user://test_dishes"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "dishkey-0001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	var text: String = FileAccess.get_file_as_string("res://data/items/dishes.json")
	var dishes: Dictionary = JSON.parse_string(text)["dishes"]
	var recipes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/recipes.json"))["recipes"]
	var vitals: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/vitals.json"))
	check(dishes.size() >= 15 and dishes.size() <= 20, "15 to 20 dishes (%d)" % dishes.size())

	# Away from a fire nothing can be cooked.
	var first: String = str(dishes.keys()[0])
	_stock(first, dishes[first])
	items.action(1, Net.ACT_CRAFT_QUEUE, int(recipes["cook_" + first]["number"]), 0, 1, Vector3.ZERO)
	_pass(20.0)
	check(items.count_for(1, first) == 0, "no dish without a fire")

	# A lit campfire at the origin.
	items._next_id += 1
	items._items[items._next_id] = {"number": items.table.number_of("campfire"), "count": 1, "pos": Vector3(1.0, 10.0, 0.0), "left": 1.0e9, "fire": {"state": 1, "burn_left": 5000.0, "covered": false, "recheck": 5.0}}

	# The stews and pastes are made in the campfire pot, which hangs over that fire.
	items._next_id += 1
	items._items[items._next_id] = {"number": items.table.number_of("campfire_pot"), "count": 1, "pos": Vector3(1.0, 10.0, 0.0), "left": 1.0e9, "struct": {"kind": "campfire_pot", "yaw": 0.0}}
	items._refresh_pots()

	# The bread and the roast are made at an oven (it cooks what a clay hearth and a campfire cook besides).
	items._next_id += 1
	items._items[items._next_id] = {"number": items.table.number_of("oven"), "count": 1, "pos": Vector3(0.0, 10.0, 1.0), "left": 1.0e9, "struct": {"kind": "oven", "yaw": 0.0}}

	var best_by_kinds: Dictionary = {}

	for dish_id in dishes:
		var d: Dictionary = dishes[dish_id]
		_stock(dish_id, d)
		items._last_queue_act.clear()
		items.action(1, Net.ACT_CRAFT_QUEUE, int(recipes["cook_" + dish_id]["number"]), 0, 1, Vector3.ZERO)
		_pass(float(d["craft_s"]) + 4.0)
		check(items.count_for(1, dish_id) == int(d["gives"]), "%s is made at the lit fire (%d)" % [dish_id, items.count_for(1, dish_id)])
		var kinds: int = (d["needs"] as Array).size()
		var points: int = int(vitals["food"]["by_id"].get(dish_id, 0))
		check(points > 0 and float(points) / float(kinds) > 100.0, "%s gives food points (%d)" % [dish_id, points])
		best_by_kinds[kinds] = maxi(int(best_by_kinds.get(kinds, 0)), points)

		if int(d["shelf_h"]) <= 0:
			check(false, "%s has a shelf life" % dish_id)

	for k in range(3, 6):
		if best_by_kinds.has(k) and best_by_kinds.has(k - 1):
			check(int(best_by_kinds[k]) > int(best_by_kinds[k - 1]), "%d kinds of ingredient beat %d (%d > %d)" % [k, k - 1, best_by_kinds[k], best_by_kinds[k - 1]])

	# Eating one fills the stomach.
	var stew: String = "hunters_stew"
	items.vitals_of(1)["fed"] = 600.0
	var before: float = float(items.vitals_of(1)["fed"])
	items._vitals_cfg["eat_pace_ms"] = 0
	items._last_eat.clear()
	items.action(1, Net.ACT_EAT, items.inventory_of(1).numbers.find(items.table.number_of(stew)), 0, 0, Vector3.ZERO)
	check(float(items.vitals_of(1)["fed"]) > before, "a stew fills the stomach")

	items._finish_writer()
	print("dishes: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func _stock(dish_id: String, d: Dictionary) -> void:
	for need in d["needs"]:
		items.give_to(1, str(need[0]), int(need[1]))


func _pass(seconds: float) -> void:
	for s in range(int(seconds)):
		items.tick(1.0)
