extends SceneTree

# Beech is a key wood (Dave 1 Nov play-test: a felled beech gave no logs). A felled beech comes down already in its logs (Dave 16 Nov 2026): every whole 3 m log
# of its length lies on the ground end to end along the line it fell on, turned along it and as thick as the tree, none in the pack, no trunk is left, the stump
# stays, and the logs and stump survive a restart.
#   godot --headless --path . --script res://src/worldgen/tools/test_beech_logs.gd

const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")
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
	var dir: String = "user://test_beech_logs_%d" % Time.get_ticks_usec()   # a fresh folder each run
	var w = make(dir)
	w.ground_height = func(_x, _z): return 10.0
	var standing: Dictionary = {7: true}
	var notices: Array = []
	w.game_seconds = func(): return 5000.0
	w.tree_info = func(_c, id): return {"name": "beech", "position": Vector3(10.0, 10.0, 0.0), "height": 18.0, "trunk": 0.3} if standing.has(id) else {}
	w.cut_tree = func(_c, id): standing.erase(id); return true
	w.send_notice = func(_p, text): notices.append(text)
	w.peer_connected_hello(1, "abcdef123456")
	w.report_position(1, Vector3(8.0, 10.0, 0.0))
	w.action(1, Net.ACT_ADMIN_GIVE, w.table.number_of("stone_axe"), 0, 1, Vector3.ZERO)

	for n in range(20):
		w._last_hit.clear()
		w.action(1, Net.ACT_HIT, 7, 0, 0, HeldTool.at_axe(w))

	check(standing.is_empty(), "the beech is felled")
	check(w._items.values().all(func(it): return not it.has("tree") or int(it["tree"]["state"]) == 4), "no trunk is left lying, only the stump")
	var log_n: int = w.table.number_of("log_beech")
	var log_len: float = float(w._drops["trunk"]["log_length_m"])   # 3.0 m (Master s2.3 item 1)
	var logs: Array = loose_logs(w, log_n)
	check(logs.size() == int(18.0 / log_len), "every whole log of the tree lies on the ground: %d of %d" % [logs.size(), int(18.0 / log_len)])
	check(w.shoulder_of(1) == "" and w.inventory_of(1).count_of(log_n) == 0, "no log went into the pack or onto the shoulder")
	var stump: int = 0

	for k in w._items:
		if w._items[k].has("tree") and int(w._items[k]["tree"]["state"]) == 4:
			stump = k

	check(stump != 0, "the stump stays")
	var yaw: float = float(w._items[stump]["tree"]["yaw"])
	var along: Vector2 = Vector2(sin(yaw), cos(yaw))
	var lined: bool = not logs.is_empty()

	for k in logs:
		var it: Dictionary = w._items[k]
		var off: Vector2 = Vector2(it["pos"].x - 10.0, it["pos"].z)
		lined = lined and absf(off.dot(Vector2(-along.y, along.x))) < 0.05 and is_equal_approx(fposmod(float(it["rot_y"]) - (yaw - PI * 0.5), TAU), 0.0) and it.has("girth") and it.has("fall")

	check(lined, "the logs lie end to end on the fall line, turned along it, as thick as the tree, and falling with it")

	for n in range(8):
		w.tick(0.25)   # the tree lands (FALL_S)

	check(loose_logs(w, log_n).all(func(k): return not w._items[k].has("fall")), "once it has landed the logs are no longer falling")
	w.save()
	var w2 = make(dir)
	var kept: int = loose_logs(w2, log_n).size()
	var stumps: int = 0

	for k in w2._items:
		if w2._items[k].has("tree") and int(w2._items[k]["tree"]["state"]) == 4:
			stumps += 1

	check(kept == logs.size() and stumps == 1, "the logs and the stump survive a restart (%d logs, %d stumps)" % [kept, stumps])

	print("beech log tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
