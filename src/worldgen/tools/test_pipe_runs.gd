extends SceneTree

# Pipes laid from the hand, taps, drip heads and barrels (Dave 19 Nov 2026, docs/design/PLUMBING_DESIGN.md s9; values PROVISIONAL PV-1..PV-8):
# the data (Wooden - Pipe 2 m a piece, Copper - Pipe 3 m, the retired elbow, tee and iron pieces), PipeRules, one click pair laying a run between
# two barrels' bottom points from the pack, linked barrels levelling to one surface, rain into a barrel in the open, a run started in the middle of
# another (a junction), a tap and a drip head fitted on open ends, a worn wooden pipe leaking, taking down, the refusals, and save and load.
#   godot --headless --path . --script res://src/worldgen/tools/test_pipe_runs.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Network := preload("res://src/shared/water_network.gd")
const PipeRules := preload("res://src/shared/pipe_rules.gd")
const GameClockScript := preload("res://src/shared/game_clock.gd")
const LookTable := preload("res://src/client/look_table.gd")

const DIR := "user://test_pipe_runs"
const FOOT := Vector3(0.0, 0.05, 0.0)   # a barrel's bottom point over its spot (structures.json wooden_barrel level_port)

var failures: int = 0
var items
var clock: Array = [0.0]
var said: Array = []
var raining: Array = [0.0]
var covered: Array = [0.0]


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make(wipe: bool):
	DirAccess.make_dir_recursive_absolute(DIR)

	if wipe:
		for file in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute(DIR + "/" + file)

	var it = ItemsScript.new()
	it.send_full = func(_p, _b): pass
	it.send_slots = func(_p, _b): pass
	it.send_world_items = func(_p, _a, _r): pass
	it.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	it.send_notice = func(_p, t): said.append(str(t))
	it.ground_height = func(_x, _z): return 10.0
	it.game_seconds = func(): return clock[0]
	it.rain_now = func(): return raining[0]
	it.cover_at = func(_p): return covered[0]
	it.setup(ItemTableScript.load_default(), DIR)
	it.fresh_water_y = func(_pos, _reach): return 6.0
	return it


func n(id: String) -> int:
	return items.table.number_of(id)


func slot_of(id: String) -> int:
	var inv = items.inventory_of(1)

	for s in inv.slot_count:
		if inv.numbers[s] == n(id):
			return s

	return -1


func have(id: String) -> int:
	return items.inventory_of(1).count_of(n(id))


func barrel(x: float, z: float, y: float = 10.0) -> int:
	var id: int = items.dev_place("wooden_barrel@%s,%s,0" % [str(x), str(z)])
	items._items[id]["pos"] = Vector3(x, y, z)
	items._water_add(id)
	return id


func put(kind: String, pos: Vector3, yaw: float = 0.0) -> int:
	var id: int = items._next_id
	items._items[id] = {"number": n(str(items._structures[kind]["item"])), "count": 1, "pos": pos, "left": 1.0e9, "struct": {"kind": kind, "yaw": yaw}}
	items._next_id += 1
	items._water_add(id)
	return id


# The laid runs whose ends are a and b (either way round), 0 for none.
func run_between(a: Vector3, b: Vector3) -> int:
	for id in items._items:
		var it: Dictionary = items._items[id]

		if not it.has("struct") or not items.is_pipe_kind(str(it["struct"]["kind"])):
			continue

		var e: Array = items.pipe_ends(it)

		if ((e[0] as Vector3).distance_to(a) < 0.01 and (e[1] as Vector3).distance_to(b) < 0.01) or ((e[0] as Vector3).distance_to(b) < 0.01 and (e[1] as Vector3).distance_to(a) < 0.01):
			return int(id)

	return 0


func at_kind(kind: String, at: Vector3) -> int:
	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == kind and (items._items[id]["pos"] as Vector3).distance_to(at) < 0.01:
			return int(id)

	return 0


func litres(id: int) -> float:
	return items._water.litres(id, items._water_now_s())


func level_now() -> void:
	items._barrel_next_s = 0.0
	items._barrels_tick()


func heard(part: String) -> bool:
	for line in said:
		if part in str(line):
			return true

	return false


func _init() -> void:
	items = make(true)

	# --- Data ---
	var t: Dictionary = {"wood": items.table.entry("wooden_pipe"), "copper": items.table.entry("copper_pipe")}
	check(float(t["wood"].get("pipe_m", 0.0)) == 2.0 and float(t["copper"].get("pipe_m", 0.0)) == 3.0, "a Wooden - Pipe covers 2 m of a run, a Copper - Pipe 3 m (Dave: one copper makes about 3 m)")
	check(str(items.table.entry("copper_tap").get("fitting", "")) == "copper_tap" and str(items.table.entry("copper_drip_head").get("fitting", "")) == "copper_drip_head", "the tap and drip head are fitted from the hand")

	for id in ["wooden_pipe_elbow", "wooden_pipe_tee", "iron_pipe", "iron_pipe_elbow", "iron_tap"]:
		check(bool(items.table.entry(id).get("retired", false)) and bool(items._structures[id].get("retired", false)) and not items._structures[id].has("water"), "%s is retired: kept for its numbers only, with no water block" % id)

	check(items.table.current_number(n("wooden_pipe_elbow")) == n("wooden_pipe") and items.table.current_number(n("wooden_pipe_tee")) == n("wooden_pipe"), "a saved elbow or tee item loads as a Wooden - Pipe")
	check(items._kind_now("wooden_pipe_tee") == "wooden_pipe", "and a laid one as a Wooden - Pipe run")

	for id in ["copper_pipe", "copper_tap", "copper_drip_head"]:
		var makers: Array = items.recipes.makers_of(n(id))
		check(makers.size() == 1 and str(items.recipes.recipe(int(makers[0])).get("station", "")) == "forge", "%s is made at the forge from a Copper ingot" % id)

	check(items.recipes.makers_of(n("wooden_pipe")).size() == 1 and str(items.recipes.recipe(int(items.recipes.makers_of(n("wooden_pipe"))[0])).get("station", "")) == "", "a Wooden - Pipe is made by hand")

	for look in ["wooden_pipe", "copper_pipe", "copper_tap", "copper_tap_open", "copper_drip_head"]:
		check(LookTable.has_look(look), "look %s is in the look table" % look)

	# --- PipeRules ---
	var a0: Vector3 = Vector3(1.0, 2.0, 3.0)
	var b0: Vector3 = Vector3(4.0, 3.5, -1.0)
	var pose: Dictionary = PipeRules.pose(a0, b0)
	var back: Array = PipeRules.ends(pose["pos"], float(pose["yaw"]), float(pose["pitch"]), float(pose["len"]))
	check((back[0] as Vector3).distance_to(a0) < 0.001 and (back[1] as Vector3).distance_to(b0) < 0.001, "a run's pose gives its two ends back, tilted and turned (%s)" % str(back))
	check(PipeRules.pieces_for(7.0, 3.0) == 3 and PipeRules.pieces_for(3.0, 3.0) == 1 and PipeRules.pieces_for(0.5, 2.0) == 1, "a 7 m copper run takes 3 pieces, a 3 m one 1")
	var ray: Array = PipeRules.ray_nearest(Vector3(0.0, 1.0, 5.0), Vector3(0.0, 0.0, -1.0), Vector3(-2.0, 1.0, 0.0), Vector3(2.0, 1.0, 0.0))
	check((ray[0] as Vector3).distance_to(Vector3(0.0, 1.0, 0.0)) < 0.001 and float(ray[1]) < 0.001 and absf(float(ray[2]) - 5.0) < 0.001, "the aim along -Z meets a pipe across it at its middle (%s)" % str(ray))

	# --- Laying from barrel to barrel ---
	items.peer_connected_hello(1, "piper0000001")
	items.report_position(1, Vector3(102.0, 10.0, 100.0))
	var a: int = barrel(100.0, 100.0)
	var b: int = barrel(104.0, 100.0)
	items.give(1, n("copper_pipe"), 5)
	said.clear()
	items.pipe_lay(1, slot_of("copper_pipe"), Vector3(100.1, 10.1, 100.0), Vector3(103.9, 10.0, 100.05))   # aimed a little off each point: they snap
	var ab: int = run_between(Vector3(100.0, 10.05, 100.0), Vector3(104.0, 10.05, 100.0))
	check(ab != 0 and str(items._items[ab]["struct"]["kind"]) == "copper_pipe" and absf(float(items._items[ab]["struct"]["len"]) - 4.0) < 0.001 and int(items._items[ab]["struct"]["paid"]) == 2, "two clicks lay one 4 m copper run between the barrels' bottom points, paid with 2 pieces")
	check(have("copper_pipe") == 3 and heard("You lay 4.0 m"), "two pieces leave the pack and the player is told (%d left; %s)" % [have("copper_pipe"), str(said)])
	check(items._water.level_groups().size() == 1 and (items._water.level_groups()[0] as Array).has(a) and (items._water.level_groups()[0] as Array).has(b), "the two barrels are linked")

	# --- Levelling (PV-7) ---
	items._water.set_litres(a, 100.0)
	level_now()
	check(absf(litres(a) - 50.0) < 0.6 and absf(litres(b) - 50.0) < 0.6 and absf(litres(a) + litres(b) - 100.0) < 0.01, "linked barrels share their water equally: %.2f and %.2f" % [litres(a), litres(b)])
	var rows: Array = [[10.0, 0.85, 200.0], [10.0, 0.85, 200.0], [10.4, 0.85, 200.0]]
	var share: Array = Network.level_litres(rows, 300.0)
	check(absf(float(share[0]) - float(share[1])) < 0.01 and float(share[2]) > 30.0 and float(share[2]) < 45.0 and absf(float(share[0]) + float(share[1]) + float(share[2]) - 300.0) < 0.01, "a barrel standing 0.4 m higher holds less, like water finding one level (%s)" % str(share))
	check(absf(float(Network.level_litres(rows, 100.0)[2])) < 0.01, "and nothing until the water reaches its foot")

	# --- Rain (PV-6) ---
	var lone: int = barrel(120.0, 120.0)
	raining[0] = 1.0
	level_now()
	check(absf(float(items._water.pieces[lone].get("rain_lpm", 0.0)) - 1.0) < 0.01, "full rain puts 1 L a minute into a barrel in the open (%.2f)" % float(items._water.pieces[lone].get("rain_lpm", 0.0)))
	covered[0] = 2.0
	level_now()
	check(float(items._water.pieces[lone].get("rain_lpm", 0.0)) == 0.0, "and none under a roof")
	covered[0] = 0.0
	raining[0] = 0.0
	var box = items._chests[int(items._items[lone]["struct"]["uid"])]
	box.add(n("stick"), 1)
	level_now()
	check(float(items._water.pieces[lone].get("litres_max", -1.0)) == 0.0, "a barrel holding goods holds no water")
	box.remove(n("stick"), 1)
	level_now()
	check(float(items._water.pieces[lone].get("litres_max", 0.0)) == 200.0, "emptied, it holds 200 L again")

	# --- A junction: a run started in the middle of another ---
	said.clear()
	items.pipe_lay(1, slot_of("copper_pipe"), Vector3(102.0, 10.1, 100.0), Vector3(102.0, 10.05, 103.0))
	var mid: Vector3 = Vector3(102.0, 10.05, 100.0)
	var tip: Vector3 = Vector3(102.0, 10.05, 103.0)
	var first: int = run_between(Vector3(100.0, 10.05, 100.0), mid)
	var second: int = run_between(mid, Vector3(104.0, 10.05, 100.0))
	var branch: int = run_between(mid, tip)
	check(first == ab and second != 0 and branch != 0, "a run started on a laid pipe splits it there: three runs meet (%d, %d, %d)" % [first, second, branch])
	check(first != 0 and second != 0 and int(items._items[first]["struct"]["paid"]) + int(items._items[second]["struct"]["paid"]) == 2 and have("copper_pipe") == 2, "the split pipe keeps its 2 pieces between its halves; the branch took 1")
	check(items._water.level_groups().size() == 1 and (items._water.level_groups()[0] as Array).size() == 2, "the barrels are still linked through the junction")

	# --- A tap on the branch's open end, pouring into a trough under it ---
	var trough: int = put("wooden_trough", Vector3(102.0, 9.0, 103.0))   # its rim 0.45 m under the spout (and more than a joint below the pipe end)
	items.give(1, n("copper_tap"), 1)
	items.pipe_lay(1, slot_of("copper_tap"), tip, tip + Vector3(0.1, 0.0, 0.0))
	var tap: int = at_kind("copper_tap", tip)
	check(tap != 0 and have("copper_tap") == 0 and items._water.downstream(branch).has(tap), "a tap is fitted on the open end and the pipe feeds it")
	items._water.set_litres(a, 150.0)
	items._water.set_litres(b, 150.0)
	items._water_dirty = true
	items._water_tick(0.0)
	check(items._water.inflow_lpm(trough) == 0.0, "shut, it pours nothing")
	items.report_position(1, Vector3(102.0, 10.0, 102.0))
	items._use_struct(1, items.inventory_of(1), tap)
	items._water_dirty = true
	items._water_tick(0.0)
	check(str(items._items[tap]["struct"]["kind"]) == "copper_tap_open" and items._water.inflow_lpm(trough) > 0.0 and items._water.inflow_lpm(trough) <= 30.01, "E opens it: it pours into the trough under its spout, at most 30 L/min (%.2f)" % items._water.inflow_lpm(trough))
	items._last_use.erase(1)
	items._use_struct(1, items.inventory_of(1), tap)   # shut again: the rest of the test keeps the barrels' water
	items._water_dirty = true
	items._water_tick(0.0)
	check(str(items._items[tap]["struct"]["kind"]) == "copper_tap" and items._water.inflow_lpm(trough) == 0.0, "E again shuts it")

	# --- A drip head waters the beds within 2 m that are not above it ---
	items.report_position(1, Vector3(200.0, 10.0, 200.0))
	var e: int = barrel(200.0, 200.0)
	var near_bed: int = put("tilled_bed", Vector3(203.0, 10.0, 200.0))
	var far_bed: int = put("tilled_bed", Vector3(205.5, 10.0, 200.0))
	var high_bed: int = put("tilled_bed", Vector3(202.5, 11.0, 200.5))
	items.pipe_lay(1, slot_of("copper_pipe"), Vector3(200.0, 10.05, 200.0), Vector3(202.0, 10.05, 200.0))
	items.give(1, n("copper_drip_head"), 1)
	items.pipe_lay(1, slot_of("copper_drip_head"), Vector3(202.0, 10.05, 200.0), Vector3(202.0, 10.05, 200.0))
	var drip: int = at_kind("copper_drip_head", Vector3(202.0, 10.05, 200.0))
	var beds: Array = items._trench_beds.get(drip, [])
	check(drip != 0 and beds.has(near_bed) and not beds.has(far_bed) and not beds.has(high_bed), "a drip head waters the bed 1 m off, not one 3.5 m off or one a metre above it (%s)" % str(beds))
	items._water.set_litres(e, 150.0)
	var wet_before: float = items.plot_moisture(Vector3(203.0, 10.0, 200.0))
	items._water_dirty = true
	items._water_tick(0.0)
	clock[0] += 120.0 * GameClockScript.RATIO
	items._water_dirty = true
	items._water_tick(0.0)
	check(drip != 0 and items._water.inflow_lpm(drip) > 0.0 and items._water.inflow_lpm(drip) <= 2.01 and items.plot_moisture(Vector3(203.0, 10.0, 200.0)) > wet_before, "it lets out at most 2 L/min and the bed gets wetter (%.2f L/min, %.1f -> %.1f %%)" % [items._water.inflow_lpm(drip) if drip != 0 else 0.0, wet_before, items.plot_moisture(Vector3(203.0, 10.0, 200.0))])

	# --- A worn wooden pipe leaks: it carries its condition's share ---
	var f: int = barrel(300.0, 300.0)
	items.report_position(1, Vector3(300.0, 10.0, 300.0))
	items.give(1, n("wooden_pipe"), 1)
	items.pipe_lay(1, slot_of("wooden_pipe"), Vector3(300.0, 10.05, 300.0), Vector3(301.9, 10.05, 300.0))
	var wood: int = run_between(Vector3(300.0, 10.05, 300.0), Vector3(301.9, 10.05, 300.0))
	check(wood != 0 and have("wooden_pipe") == 0 and absf(float(items._water.pieces[wood].get("cap_lpm", 0.0)) - 60.0) < 0.01, "a new 1.9 m wooden run takes 1 piece and carries 60 L/min")
	items._items[wood]["struct"]["born"] = items._now_game_s() - 40.0 * 86400.0
	items._pipe_wear_next_s = 0.0
	items._water_tick(0.0)
	items._water_tick(0.0)
	check(wood != 0 and float(items._water.pieces[wood].get("cap_lpm", 60.0)) < 59.5 and float(items._water.pieces[wood].get("cap_lpm", 0.0)) >= 14.99, "an old one carries less (%.1f L/min at %.2f condition)" % [float(items._water.pieces[wood].get("cap_lpm", 0.0)), items.piece_condition(wood)])
	check(f != 0, "(its barrel)")

	# --- Refusals ---
	items.report_position(1, Vector3(102.0, 10.0, 100.0))
	said.clear()
	items.pipe_lay(1, slot_of("copper_pipe"), Vector3(110.0, 10.0, 110.0), Vector3(102.0, 10.0, 102.0))
	check(heard("Start a pipe at"), "a run must start at a connection point (%s)" % str(said))
	said.clear()
	var lots: int = barrel(140.0, 100.0)
	items.report_position(1, Vector3(136.0, 10.0, 100.0))
	items.pipe_lay(1, slot_of("copper_pipe"), Vector3(104.0, 10.05, 100.0), Vector3(140.0, 10.05, 100.0))
	check(heard("at most 30 m") and lots != 0, "a run longer than 30 m is refused (%s)" % str(said))
	said.clear()
	var c: int = barrel(110.0, 100.0)
	items.report_position(1, Vector3(108.0, 10.0, 100.0))
	items.pipe_lay(1, slot_of("copper_pipe"), Vector3(104.0, 10.05, 100.0), Vector3(110.0, 10.05, 100.0))
	check(heard("needs 2") and c != 0 and have("copper_pipe") == 1, "6 m of copper needs 2 pieces: with 1 it is refused and nothing is taken (%s)" % str(said))

	# --- Taking down: a run keeps its tap until that comes off, then gives its pieces back ---
	items.report_position(1, Vector3(102.0, 10.0, 102.0))
	said.clear()
	items._take_down(1, items.inventory_of(1), branch)
	check(items._items.has(branch) and heard("Take the"), "a run with a tap on its end stays until the tap comes off (%s)" % str(said))
	items._take_down(1, items.inventory_of(1), tap)
	items._take_down(1, items.inventory_of(1), branch)
	check(not items._items.has(tap) and not items._items.has(branch) and have("copper_tap") == 1 and have("copper_pipe") == 2, "the tap and the branch come back to the pack (%d tap, %d pipe)" % [have("copper_tap"), have("copper_pipe")])

	# --- Save and load ---
	var a_pos: Vector3 = items._items[a]["pos"]
	var kept_len: float = float(items._items[first]["struct"]["len"])
	var a_l: float = litres(a)
	items._dirty = true
	items.save()
	items._finish_writer()
	items = make(false)
	var first2: int = run_between(Vector3(100.0, 10.05, 100.0), mid)
	var second2: int = run_between(mid, Vector3(104.0, 10.05, 100.0))
	var wood2: int = run_between(Vector3(300.0, 10.05, 300.0), Vector3(301.9, 10.05, 300.0))
	check(first2 != 0 and second2 != 0 and wood2 != 0 and absf(float(items._items[first2]["struct"]["len"]) - kept_len) < 0.001 and int(items._items[first2]["struct"]["paid"]) + int(items._items[second2]["struct"]["paid"]) == 2, "after a load the runs lie where they were, with their length and pieces")
	var a2: int = at_kind("wooden_barrel", a_pos)
	check(a2 != 0 and absf(litres(a2) - a_l) < 0.5 and items._water.level_groups().size() >= 1, "the barrel keeps its water (%.1f of %.1f L) and its link" % [litres(a2) if a2 != 0 else -1.0, a_l])

	# An old save's Wooden - Pipe (a hammer piece, no laid row) loads as a 2 m run on its old axis, 0.13 m up.
	var old: Dictionary = {"pos": Vector3(0.0, 10.0, 0.0), "struct": {"kind": "wooden_pipe", "yaw": 90.0}}
	items._pipe_from_legacy(old)
	var old_ends: Array = PipeRules.ends(old["pos"], 90.0, float(old["struct"]["pitch"]), float(old["struct"]["len"]))
	check(absf((old["pos"] as Vector3).y - 10.13) < 0.001 and float(old["struct"]["len"]) == 2.0 and int(old["struct"]["paid"]) == 1 and absf(absf((old_ends[0] as Vector3).z) - 1.0) < 0.001, "an old Wooden - Pipe loads as a 2 m run along its old axis (%s)" % str(old_ends))

	print("pipe runs: %d failures" % failures)
	items._finish_writer()
	quit(1 if failures > 0 else 0)
