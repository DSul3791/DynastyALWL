extends SceneTree

# Stone channels, clay pipes and cisterns (plumbing PR 3, docs/design/PLUMBING_DESIGN.md s6; values PROVISIONAL): the real structures.json rows join
# the water network. A cistern's water stands half a metre over its base outlet and drives a level clay pipe at half its cap; the raised cistern's
# tank stands 2.5 m over its foot outlet (full cap) and fills through its riser only from a surface that reaches its top (a force pump), never from
# a hand pump's spout.
#   godot --headless --path . --script res://src/worldgen/tools/test_stone_clay_water.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Network := preload("res://src/shared/water_network.gd")

var failures: int = 0
var items
var clock: Array = [0.0]


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
	it.send_notice = func(_p, _t): pass
	it.ground_height = func(_x, _z): return 10.0
	it.game_seconds = func(): return clock[0]
	it.setup(ItemTableScript.load_default(), dir)
	it.fresh_water_y = func(_pos, _reach): return 6.0
	return it


func put(kind: String, pos: Vector3, yaw: float = 0.0) -> int:
	var id: int = items._next_id
	items._items[id] = {"number": items.table.number_of(str(items._structures[kind]["item"])), "count": 1, "pos": pos, "left": 1.0e9, "struct": {"kind": kind, "yaw": yaw}}
	items._next_id += 1
	items._water_add(id)
	return id


func _init() -> void:
	items = make("user://test_stone_clay_water")
	var bp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/blueprints.json"))["blueprints"]

	for id in ["stone_trough", "stone_channel", "stone_channel_corner", "stone_channel_tee", "clay_pipe_run", "clay_pipe_elbow", "clay_pipe_tee", "stone_cistern"]:
		check(bp.has(id) and bool(bp[id].get("known", false)) and not bool(bp[id].get("locked", false)), "blueprint %s is known and unlocked" % id)

	check(bp.has("stone_raised_cistern") and bool(bp["stone_raised_cistern"].get("locked", false)), "the Raised cistern stays locked until a force pump can fill it (plumbing PR 4)")
	check(int(items._structures["stone_channel"]["water"]["cap_lpm"]) == 300 and not bool(items._structures["stone_channel"]["water"]["closed"]), "a stone channel is open and carries 300 L/min")
	check(bool(items._structures["clay_pipe_run"]["water"]["closed"]), "a clay pipe is closed")

	# A cistern drains through a level clay pipe (laid along Z) into a stone trough: half a metre of head gives half the pipe's 120 L/min.
	var cistern: int = put("stone_cistern", Vector3(200.0, 10.0, 200.0))
	var pipe: int = put("clay_pipe_run", Vector3(200.0, 10.0, 202.05), 90.0)
	var trough: int = put("stone_trough", Vector3(200.0, 9.5, 204.0))
	check(items._water.downstream(cistern).has(pipe) and items._water.downstream(pipe).has(trough), "cistern, clay pipe and stone trough join")
	items._water.set_litres(cistern, 1000.0)
	items._water_dirty = true
	items._water_tick(0.0)
	check(absf(items._water.inflow_lpm(trough) - 60.0) < 0.01, "the trough fills at 60 L/min (%.2f)" % items._water.inflow_lpm(trough))

	# The raised cistern's tank stands 2.5 m over its outlet: a level clay pipe from it runs full.
	var raised: int = put("stone_raised_cistern", Vector3(300.0, 10.0, 300.0))
	var pipe2: int = put("clay_pipe_run", Vector3(300.0, 10.0, 302.05), 90.0)
	var trough2: int = put("stone_trough", Vector3(300.0, 9.5, 304.0))
	items._water.set_litres(raised, 1000.0)
	items._water_dirty = true
	items._water_tick(0.0)
	check(items._water.downstream(raised).has(pipe2) and absf(items._water.inflow_lpm(trough2) - 120.0) < 0.01, "a raised cistern drives a level clay pipe at its full 120 L/min (%.2f)" % items._water.inflow_lpm(trough2))

	# Its riser: a hand pump's spout does not reach it (no link); in the network a force pump's surface over its top fills it, a low one does not.
	var pump: int = put("wooden_hand_pump", Vector3(300.0, 10.0, 298.68))
	check(not items._water.downstream(pump).has(raised), "a hand pump's spout does not feed the raised cistern's riser")

	# A hand pump whose spout is within a join of the riser (the cistern's foot 0.4 m up): it links, but its water cannot climb the riser.
	var high: int = put("stone_raised_cistern", Vector3(400.0, 10.4, 400.0))
	var pump2: int = put("wooden_hand_pump", Vector3(400.0, 10.0, 398.68))
	items._water.pieces[pump2]["rate_lpm"] = 48.0
	items._water_dirty = true
	items._water_tick(0.0)
	check(items._water.downstream(pump2).has(high) and items._water.inflow_lpm(high) == 0.0, "a hand pump's spout at the riser links but fills nothing: lift_m (%.1f)" % items._water.inflow_lpm(high))
	var net = Network.new()
	net.add(1, {"role": "source", "outlet": Vector3(0.0, 1.0, 0.0), "rate_lpm": 60.0, "cap_lpm": 60.0, "closed": true, "push_m": 10.0})
	net.add(2, {"role": "conduit", "inlet": Vector3(0.0, 1.0, 0.0), "outlet": Vector3(2.0, 0.15, 0.0), "cap_lpm": 240.0, "closed": true})
	net.add(3, {"role": "tank", "closed": true, "inlet": Vector3(2.0, 0.15, 0.0), "lift_m": 2.85, "litres_max": 2000.0})
	net.solve(0.0)
	check(is_equal_approx(net.inflow_lpm(3), 60.0), "a force pump pushing 10 m fills the raised cistern (%.1f)" % net.inflow_lpm(3))
	net.pieces[1]["push_m"] = 0.0
	net.solve(1.0)
	check(net.inflow_lpm(3) == 0.0, "with no push the water cannot climb to its tank")

	print("stone and clay water: %d failures" % failures)
	quit(1 if failures > 0 else 0)
