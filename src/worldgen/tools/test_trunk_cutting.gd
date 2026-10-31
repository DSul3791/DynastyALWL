extends SceneTree

# Cutting a felled trunk into logs (Dave): the logs land on the ground beside the trunk and never in the pack or on the shoulder, the trunk gets shorter with each cut, the player has to stand
# by the cut line, sticks and bark still go to the pack, the last cut removes the trunk, a partly cut trunk survives a restart, and a big tree's logs are not lost to the drop cap.
#   godot --headless --path . --script res://src/worldgen/tools/test_trunk_cutting.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(dir: String):
	DirAccess.make_dir_recursive_absolute(dir)
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.setup(ItemTableScript.load_default(), dir)
	return items


func loose_logs(w, number: int) -> Array:
	var out: Array = []

	for k in w._items:
		var it: Dictionary = w._items[k]

		if not it.has("tree") and not it.has("struct") and int(it["number"]) == number:
			out.append(k)

	return out


func _init() -> void:
	var dir: String = "user://test_trunk_cutting_%d" % Time.get_ticks_usec()   # a fresh folder each run
	var w = make(dir)
	w.ground_height = func(_x, _z): return 10.0
	var standing: Dictionary = {7: true}
	var notices: Array = []
	w.game_seconds = func(): return 5000.0
	w.tree_info = func(_c, id): return {"name": "oak", "position": Vector3(10.0, 10.0, 0.0), "height": 18.0, "trunk": 0.3} if standing.has(id) else {}
	w.cut_tree = func(_c, id): standing.erase(id); return true
	w.send_notice = func(_p, text): notices.append(text)
	w.peer_connected_hello(1, "abcdef123456")
	w.report_position(1, Vector3(8.0, 10.0, 0.0))
	w.action(1, Net.ACT_ADMIN_GIVE, w.table.number_of("stone_axe"), 0, 1, Vector3.ZERO)

	for n in range(20):
		w._last_hit.clear()
		w.action(1, Net.ACT_HIT, 7, 0, 0, Vector3.ZERO)

	var trunk_id: int = 0

	for k in w._items:
		if w._items[k].has("tree") and int(w._items[k]["tree"]["state"]) == 3:
			trunk_id = k

	check(trunk_id != 0, "the oak is felled into a trunk")
	var tree: Dictionary = w._items[trunk_id]["tree"]
	var length0: float = float(tree["length"])
	var log_n: int = w.table.number_of("log_oak")
	var along: Vector3 = Vector3(sin(float(tree["yaw"])), 0.0, cos(float(tree["yaw"])))
	var base: Vector3 = w._items[trunk_id]["pos"]
	var stick: int = w.table.number_of("stick")

	# The first blows take branches (sticks) wherever the player stands along the trunk, and cut no log.
	w.report_position(1, base + along * 2.0)

	for n in range(3):
		w._last_process.clear()
		w.action(1, Net.ACT_PROCESS, trunk_id, 0, 0, Vector3.ZERO)

	check(w.inventory_of(1).count_of(stick) >= 1, "branch blows give sticks to the pack")
	check(loose_logs(w, log_n).is_empty() and w.shoulder_of(1) == "", "no log yet")

	# Far from the cut line (the far end), a blow does nothing and the player is told.
	notices.clear()
	var before_blows: int = int(tree["blows"])
	w._last_process.clear()
	w.action(1, Net.ACT_PROCESS, trunk_id, 0, 0, Vector3.ZERO)
	check(int(tree["blows"]) == before_blows and notices.has("Walk along the trunk to the cut line."), "standing far from the cut line the blow does not count and the player is told")

	# A log on the shoulder never blocks the chopping.
	w._give_shoulder(1, log_n, 1)
	check(w.shoulder_of(1) == "log_oak", "a log is on the shoulder")
	var cut_point: Vector3 = base + along * (length0 - 1.2)
	w.report_position(1, cut_point)

	for n in range(3):
		w._last_process.clear()
		w.action(1, Net.ACT_PROCESS, trunk_id, 0, 0, Vector3.ZERO)

	check(loose_logs(w, log_n).size() == 1, "the cut drops one log on the ground, not into the pack (loose logs: %d)" % loose_logs(w, log_n).size())
	check(w.shoulder_of(1) == "log_oak" and w.inventory_of(1).count_of(log_n) == 0, "the shoulder is unchanged and the pack has no log")
	check(absf(float(tree["length"]) - (length0 - 2.44)) < 0.01, "the trunk is one log shorter (%.2f from %.2f)" % [float(tree["length"]), length0])

	# Save and load mid-way keeps the shortened trunk.
	w.save()
	var w2 = make(dir)
	var kept: float = -1.0

	for k in w2._items:
		if w2._items[k].has("tree") and int(w2._items[k]["tree"]["state"]) == 3:
			kept = float(w2._items[k]["tree"]["length"])

	check(absf(kept - float(tree["length"])) < 0.01, "a partly cut trunk survives a restart (%.2f)" % kept)

	# Keep cutting, walking along: every log lands on the ground and the last cut removes the trunk.
	var guard: int = 0

	while w._items.has(trunk_id) and guard < 80:
		w.report_position(1, w.cut_line_point(trunk_id))
		w._last_process.clear()
		w.action(1, Net.ACT_PROCESS, trunk_id, 0, 0, Vector3.ZERO)
		guard += 1

	check(not w._items.has(trunk_id), "the last cut removes the trunk")
	var logs: int = loose_logs(w, log_n).size()
	check(logs == int(18.0 / 2.44), "every log of the tree lies on the ground: %d of %d" % [logs, int(18.0 / 2.44)])
	check(w.inventory_of(1).count_of(log_n) == 0, "no log went into the pack")
	var stumps: int = 0

	for k in w._items:
		if w._items[k].has("tree") and int(w._items[k]["tree"]["state"]) == 4:
			stumps += 1

	check(stumps == 1, "the stump stays")

	print("trunk cutting tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
