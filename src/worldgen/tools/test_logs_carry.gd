extends SceneTree

# Logs as they are really carried (guide finding F-16, second half; moderator decision for Dave, Tyler 31 Oct 2026): a picked-up log rides on the SHOULDER (one at a
# time, never in the pack) and a cut log lies on the GROUND. A craft or blueprint that needs plain `log` takes the shoulder log, then logs lying within 3 m of the player,
# then the pack. This test uses the real mechanics (give -> shoulder, drop_in_world -> a log on the ground), not pack.add: a chopping block from one shoulder log and one
# ground log; rough planks from a shoulder log at a workbench; nothing is taken when the logs do not cover the recipe; a log 6 m away is not used; a blueprint paid with logs
# on the ground; the player is told "Using nearby logs".
#   godot --headless --path . --script res://src/worldgen/tools/test_logs_carry.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var items
var said: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func count(id: String) -> int:
	return items.inventory_of(1).count_of(items.table.number_of(id))


func ground_logs(radius: float = 100.0) -> int:
	var total: int = 0

	for k in items._items:
		var it: Dictionary = items._items[k]

		if not it.has("scatter") and not it.has("struct") and not it.has("tree") and str(items.table.id_of(int(it.get("number", 0)))).begins_with("log_") and it["pos"].distance_to(Vector3(0.0, 10.0, 0.0)) <= radius:
			total += int(it["count"])

	return total


func craft(recipe_id: String, n: int) -> void:
	var number: int = -1

	for k in items.recipes.numbers():
		if str(items.recipes.recipe(int(k)).get("id", "")) == recipe_id:
			number = int(k)

	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, number, 0, n, Vector3.ZERO)

	for s in range(150):
		items.tick(1.0)


func reset() -> void:
	items.lay_down_shoulder(1)

	for k in items._items.keys():
		var it: Dictionary = items._items[k]

		if not it.has("scatter") and not it.has("struct") and not it.has("tree") and str(items.table.id_of(int(it.get("number", 0)))).begins_with("log_"):
			items._items.erase(k)

	items._characters[items._peer_key[1]]["shoulder"] = ""

	for name in ["log_oak", "log_birch", "chopping_block", "rough_plank", "lumber"]:
		items.inventory_of(1).remove(items.table.number_of(name), count(name))

	said.clear()


func _init() -> void:
	var dir: String = "user://test_logs_carry"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, t): said.append(str(t))
	items.send_carry = func(_p, _id): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "logscarry001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items.vitals_of(1)["weight"] = 2000.0
	items.admin_mode_on = func(_p): return false
	items._admin_mode_off[1] = true
	var oak: int = items.table.number_of("log_oak")
	var birch: int = items.table.number_of("log_birch")

	# The real carry: a log given to the player goes on the shoulder, not into the pack.
	items.give(1, oak, 1)
	check(items.shoulder_of(1) == "log_oak" and count("log_oak") == 0, "a log given to the player rides on the shoulder, not in the pack")

	# 1. Chopping block (2 logs): one on the shoulder, one on the ground.
	items.drop_in_world(birch, 1, Vector3(1.0, 10.0, 0.0))
	check(ground_logs() == 1, "a cut log lies on the ground")
	craft("chopping_block", 1)
	check(count("chopping_block") == 1 and items.shoulder_of(1) == "" and ground_logs() == 0, "a chopping block from the shoulder log and a ground log (block %d, shoulder '%s', %d on the ground)" % [count("chopping_block"), items.shoulder_of(1), ground_logs()])
	check(said.has("Using nearby logs"), "the player is told: Using nearby logs")

	# 2. Not enough: one log on the shoulder only, a chopping block needs 2: nothing is taken.
	reset()
	items.give(1, oak, 1)
	craft("chopping_block", 1)
	check(count("chopping_block") == 0 and items.shoulder_of(1) == "log_oak" and count("log_oak") == 0, "one log is not enough for a chopping block: the shoulder log stays on the shoulder")

	# 3. A log 6 m away is not used.
	reset()
	items.give(1, oak, 1)
	items.drop_in_world(birch, 1, Vector3(6.0, 10.0, 0.0))
	craft("chopping_block", 1)
	check(count("chopping_block") == 0 and ground_logs() == 1, "a log lying 6 m away is out of reach and stays")

	# 4. Ground logs only, a stack of 2 on the ground.
	reset()
	items.drop_in_world(oak, 2, Vector3(0.5, 10.0, 0.5))
	craft("chopping_block", 1)
	check(count("chopping_block") == 1 and ground_logs() == 0, "two logs lying on the ground make a chopping block")

	# 5. Rough planks (1 log) at a workbench, log on the shoulder.
	reset()
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("workbench_kit"), 0, 1, Vector3.ZERO)
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(items.table.number_of("workbench_kit")), 0, 0, Vector3(2.0, 10.0, 0.0))
	items.give(1, oak, 1)
	craft("rough_plank", 1)
	check(count("rough_plank") == 4 and items.shoulder_of(1) == "", "rough planks from the shoulder log at the workbench (%d planks)" % count("rough_plank"))

	# 6. A pack log is used when nothing is near (the old behaviour).
	reset()
	items.inventory_of(1).add(oak, 2)
	craft("chopping_block", 1)
	check(count("chopping_block") == 1 and not said.has("Using nearby logs"), "logs in the pack work as before, with no 'nearby' notice")

	# 7. A blueprint paid with logs on the ground (the material check pulls them in).
	reset()
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("wooden_hammer"), 0, 1, Vector3.ZERO)
	var row: Dictionary = {"structure": "workbench", "known": true, "hammer": 1, "cost": [["log", 3]]}
	items.drop_in_world(oak, 2, Vector3(0.5, 10.0, 0.5))
	items.give(1, birch, 1)
	var hammer_slot: int = items.inventory_of(1).numbers.find(items.table.number_of("wooden_hammer"))
	items.inventory_of(1).numbers[0] = items.inventory_of(1).numbers[hammer_slot] if hammer_slot > 0 else items.inventory_of(1).numbers[0]
	var ok: bool = items._can_blueprint(1, items.inventory_of(1), row)
	check(ok and items.inventory_of(1).count_fill(items.table.number_of("log")) == 3 and ground_logs() == 0 and items.shoulder_of(1) == "", "a blueprint costing 3 logs is covered by a shoulder log and two ground logs")
	print("logs carry: %d failures" % failures)
	items._finish_writer()
	quit(1 if failures > 0 else 0)
