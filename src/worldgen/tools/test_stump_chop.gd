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
	print("stump chop tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func _loose(w, number: int) -> int:
	var n: int = 0

	for k in w._items:
		var it: Dictionary = w._items[k]

		if not it.has("tree") and not it.has("struct") and int(it["number"]) == number:
			n += 1

	return n
