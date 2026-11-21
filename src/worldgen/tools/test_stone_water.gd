extends SceneTree

# Stone channels, the Stone - Trough and cisterns (plumbing PR 3, docs/design/PLUMBING_DESIGN.md s6; values PROVISIONAL): the real structures.json rows
# join the water network. Clay plumbing is retired (Dave 14 Nov 2026: "We should remove clay plumbing altogether"), so a cistern drains down a log pipe
# (Wooden - Pipe, plumbing PR 2). A cistern's water stands half a metre over its base outlet and drives a level log pipe at about half its cap; the Raised cistern
# (a big tank on a wooden frame since Dave 20 Nov 2026, PLUMBING_DESIGN s10) stands 2.5 m over its foot outlet (full cap) and fills only from above
# its open top: there are no pumps, and water never climbs.
#   godot --headless --path . --script res://src/worldgen/tools/test_stone_water.gd

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
	items._pipe_from_legacy(items._items[id])   # a Wooden - Pipe set down this way is an old 2 m hammer piece, as a save from before laid runs loads (PLUMBING_DESIGN s9)
	items._water_add(id)
	return id


func _init() -> void:
	items = make("user://test_stone_water")
	var bp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/blueprints.json"))["blueprints"]

	for id in ["stone_trough", "stone_channel", "stone_channel_corner", "stone_channel_tee", "stone_cistern"]:
		check(bp.has(id) and bool(bp[id].get("known", false)) and not bool(bp[id].get("locked", false)), "blueprint %s is known and unlocked" % id)

	var raised_cost: Dictionary = {}

	for pair in bp["stone_raised_cistern"]["cost"]:
		raised_cost[str(pair[0])] = int(pair[1])

	check(bool(bp["stone_raised_cistern"].get("known", false)) and not bool(bp["stone_raised_cistern"].get("locked", false)) and raised_cost.has("copper_ingot") and raised_cost.has("nails") and raised_cost.has("lumber") and not raised_cost.has("cobblestone"), "the Raised cistern is a big tank anyone can build: copper lined, a wooden frame, iron nails (Dave 20 Nov 2026) %s" % str(raised_cost))
	check(int(items._structures["stone_channel"]["water"]["cap_lpm"]) == 300 and not bool(items._structures["stone_channel"]["water"]["closed"]), "a stone channel is open and carries 300 L/min")
	for id in ["clay_pipe_run", "clay_pipe_elbow", "clay_pipe_tee"]:
		check(bp.has(id) and bool(bp[id].get("retired", false)) and bool(items._structures[str(bp[id]["structure"])].get("retired", false)) and not items._structures[str(bp[id]["structure"])].has("water"), "clay plumbing is retired: %s is kept for its numbers only, with no water block" % id)

	check(items.table.current_number(items.table.number_of("clay_pipe")) == items.table.number_of("clay"), "a saved Clay pipe loads as Clay")

	# A cistern drains through a level log pipe (laid along Z, its ends 0.13 m up) into a stone trough: the water stands 0.5 m over the cistern's outlet
	# (0.15 m up), 0.52 m over the pipe's far end, so it passes 52 percent of the pipe's 60 L/min.
	var cistern: int = put("stone_cistern", Vector3(200.0, 10.0, 200.0))
	var pipe: int = put("wooden_pipe", Vector3(200.0, 10.0, 202.05), 90.0)
	var trough: int = put("stone_trough", Vector3(200.0, 9.5, 204.0))
	check(items._water.downstream(cistern).has(pipe) and items._water.downstream(pipe).has(trough), "cistern, log pipe and stone trough join")
	items._water.set_litres(cistern, 1000.0)
	items._water_dirty = true
	items._water_tick(0.0)
	check(absf(items._water.inflow_lpm(trough) - 31.2) < 0.05, "the trough fills at 31.2 L/min (%.2f)" % items._water.inflow_lpm(trough))

	# A cistern spills from its base outlet into an open stone channel and corner, which pour over the rim of a stone trough standing lower.
	var c2: int = put("stone_cistern", Vector3(500.0, 10.0, 500.0))
	var run: int = put("stone_channel", Vector3(500.0, 10.0, 502.05), 90.0)
	var bend: int = put("stone_channel_corner", Vector3(500.0, 10.0, 504.05), 180.0)
	check(items._water.downstream(c2).has(run) and items._water.downstream(run).has(bend), "a cistern feeds a stone channel, the channel its corner")
	var spill: Vector3 = items._water.pieces[bend]["outlet"]
	var basin: int = put("stone_trough", Vector3(spill.x, 9.4, spill.z))
	check(items._water.downstream(bend).has(basin), "the corner's outlet over a stone trough's rim feeds it (%s)" % str(spill))
	items._water.set_litres(c2, 1000.0)
	items._water_dirty = true
	items._water_tick(0.0)
	check(absf(items._water.inflow_lpm(basin) - 300.0) < 0.01, "the stone trough fills through the channels at their full 300 L/min (%.2f)" % items._water.inflow_lpm(basin))

	# The raised cistern's tank stands 2.5 m over its outlet at its foot (its copper downpipe built in): a level log pipe from it runs full.
	var raised: int = put("stone_raised_cistern", Vector3(300.0, 10.0, 300.0))
	var pipe2: int = put("wooden_pipe", Vector3(300.0, 10.0, 302.05), 90.0)
	var trough2: int = put("stone_trough", Vector3(300.0, 9.5, 304.0))
	items._water.set_litres(raised, 500.0)
	items._water_dirty = true
	items._water_tick(0.0)
	check(items._water.downstream(raised).has(pipe2) and absf(items._water.inflow_lpm(trough2) - 60.0) < 0.01, "a raised cistern drives a level log pipe at its full 60 L/min (%.2f)" % items._water.inflow_lpm(trough2))
	var top: Dictionary = items._water.pieces[raised]
	check(not top.has("lift_m") and not bool(top.get("closed", false)) and absf((top["inlet"] as Vector3).y - 13.0) < 0.001 and float(top.get("level_base_m", 0.0)) > 2.0 and top.has("level_port"), "it is an open tank: no riser, its open top 3 m up, its floor 2.05 m up, pipes join at its foot")

	# Water never climbs (no pumps: Dave 20 Nov 2026, PLUMBING_DESIGN s10): a spout over its open top fills it; one below the top cannot reach it.
	for spout_y in [13.5, 12.0]:
		var net = Network.new()
		var tank: Dictionary = items.water_piece(items._structures["stone_raised_cistern"], Vector3(0.0, 10.0, 0.0), 0.0)
		net.add(1, {"role": "source", "outlet": Vector3(0.0, spout_y, 0.0), "rate_lpm": 30.0, "cap_lpm": 30.0})
		net.add(2, tank)
		net.solve(0.0)
		check((net.inflow_lpm(2) > 29.9) == (spout_y > 13.0), "a spout %.1f m up %s the raised cistern (%.1f L/min)" % [spout_y - 10.0, "fills" if spout_y > 13.0 else "cannot fill", net.inflow_lpm(2)])

	print("stone water: %d failures" % failures)
	quit(1 if failures > 0 else 0)
