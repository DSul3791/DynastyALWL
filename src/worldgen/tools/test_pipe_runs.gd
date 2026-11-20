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


# One pipe_lay, as a player's click (the server paces them: PIPE_LAY_PACE_MS; the test does not wait).
func lay(slot: int, from: Vector3, to: Vector3) -> void:
	items._pipe_lay_msec.clear()
	items.pipe_lay(1, slot, from, to)


func litres(id: int) -> float:
	return items._water.litres(id, items._water_now_s())


func level_now() -> void:
	items._barrel_next_s = 0.0
	items._barrels_tick()


# The network's links are whole: every link names a piece still in it, each one both ways, and no loop (every piece is in the solve order).
func net_ok(where: String) -> void:
	var w = items._water
	var bad: Array = []

	for id in w.pieces:
		for d in w._down.get(id, []):
			if not w.pieces.has(d) or not (w._up.get(d, []) as Array).has(id):
				bad.append("%d->%d" % [id, d])

		for u in w._up.get(id, []):
			if not w.pieces.has(u) or not (w._down.get(u, []) as Array).has(id):
				bad.append("%d<-%d" % [id, u])

	var in_order: int = (w._order() as Array).size()
	check(bad.is_empty() and in_order == w.pieces.size(), "%s: the network's links are whole (%d of %d pieces in order; bad %s)" % [where, in_order, w.pieces.size(), str(bad)])


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

	for look in ["wooden_pipe", "copper_pipe", "copper_tap", "copper_drip_head"]:
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
	lay(slot_of("copper_pipe"), Vector3(100.1, 10.1, 100.0), Vector3(103.9, 10.0, 100.05))   # aimed a little off each point: they snap
	var ab: int = run_between(Vector3(100.0, 10.05, 100.0), Vector3(104.0, 10.05, 100.0))
	check(ab != 0 and str(items._items[ab]["struct"]["kind"]) == "copper_pipe" and absf(float(items._items[ab]["struct"]["len"]) - 4.0) < 0.001 and int(items._items[ab]["struct"]["paid"]) == 2, "two clicks lay one 4 m copper run between the barrels' bottom points, paid with 2 pieces")
	check(have("copper_pipe") == 3 and heard("You lay 4.0 m"), "two pieces leave the pack and the player is told (%d left; %s)" % [have("copper_pipe"), str(said)])
	check(items._water.level_groups().size() == 1 and (items._water.level_groups()[0] as Array).has(a) and (items._water.level_groups()[0] as Array).has(b), "the two barrels are linked")

	net_ok("laying")

	# --- Levelling (PV-7) ---
	items._water.set_litres(a, 100.0)
	level_now()
	check(absf(litres(a) - 50.0) < 0.6 and absf(litres(b) - 50.0) < 0.6 and absf(litres(a) + litres(b) - 100.0) < 0.01, "linked barrels share their water equally: %.2f and %.2f" % [litres(a), litres(b)])
	var rows: Array = [[10.0, 0.85, 200.0], [10.0, 0.85, 200.0], [10.4, 0.85, 200.0]]
	var share: Array = Network.level_litres(rows, 300.0)
	check(absf(float(share[0]) - float(share[1])) < 0.01 and float(share[2]) > 30.0 and float(share[2]) < 45.0 and absf(float(share[0]) + float(share[1]) + float(share[2]) - 300.0) < 0.01, "a barrel standing 0.4 m higher holds less, like water finding one level (%s)" % str(share))
	check(absf(float(Network.level_litres(rows, 100.0)[2])) < 0.01, "and nothing until the water reaches its foot")

	net_ok("levelling")

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

	net_ok("rain")

	# --- A junction: a run started in the middle of another ---
	said.clear()
	lay(slot_of("copper_pipe"), Vector3(102.0, 10.1, 100.0), Vector3(102.0, 10.05, 103.0))
	var mid: Vector3 = Vector3(102.0, 10.05, 100.0)
	var tip: Vector3 = Vector3(102.0, 10.05, 103.0)
	var first: int = run_between(Vector3(100.0, 10.05, 100.0), mid)
	var second: int = run_between(mid, Vector3(104.0, 10.05, 100.0))
	var branch: int = run_between(mid, tip)
	check(first == ab and second != 0 and branch != 0, "a run started on a laid pipe splits it there: three runs meet (%d, %d, %d)" % [first, second, branch])
	check(first != 0 and second != 0 and int(items._items[first]["struct"]["paid"]) + int(items._items[second]["struct"]["paid"]) == 2 and have("copper_pipe") == 2, "the split pipe keeps its 2 pieces between its halves; the branch took 1")
	check(items._water.level_groups().size() == 1 and (items._water.level_groups()[0] as Array).size() == 2, "the barrels are still linked through the junction")

	net_ok("junction")

	# --- A tap on the branch's open end (Dave 19 Nov 2026 20:11Z): E takes a drink, its 3 slots fill water containers, only while its pipes reach water ---
	items.give(1, n("copper_tap"), 1)
	lay(slot_of("copper_tap"), tip, tip + Vector3(0.1, 0.0, 0.0))
	var tap: int = at_kind("copper_tap", tip)
	check(tap != 0 and have("copper_tap") == 0 and items._water.downstream(branch).has(tap), "a tap is fitted on the open end and the pipe feeds it")
	check(items._kind_now("copper_tap_open") == "copper_tap" and not items._structures["copper_tap"].has("toggle"), "the tap is not opened and shut: a saved open one loads as a tap")
	items._water.set_litres(a, 150.0)
	items._water.set_litres(b, 150.0)
	items._water_dirty = true
	items._water_tick(0.0)
	check(tap != 0 and items._water.inflow_lpm(tap) == 0.0, "it lets no water out on its own")
	items.report_position(1, Vector3(102.0, 10.0, 102.0))
	var v: Dictionary = items.vitals_of(1)
	v["wet"] = 0.0
	var held: float = litres(a) + litres(b)
	items._use_struct(1, items.inventory_of(1), tap)
	check(float(v["wet"]) > 0.0 and absf(held - litres(a) - litres(b) - float(v["wet"]) / 1000.0) < 0.01, "E takes a drink: the barrels give what the player drank (%.0f ml; %.2f -> %.2f L)" % [float(v["wet"]), held, litres(a) + litres(b)])
	var keep_a: float = litres(a)
	var keep_b: float = litres(b)
	items._water.set_litres(a, 0.0)
	items._water.set_litres(b, 0.0)
	items._last_use.erase(1)
	items._last_drink.erase(1)
	said.clear()
	var wet_was: float = float(v["wet"])
	items._use_struct(1, items.inventory_of(1), tap)
	check(heard("No water comes from the tap") and float(v["wet"]) == wet_was, "with the barrels dry it gives nothing (%s)" % str(said))
	var tap_box = items._chest_of(1, tap)
	check(tap_box != null and tap_box.usable == 3, "F opens the tap's 3 slots")
	items.give(1, n("stick"), 1)
	said.clear()

	if tap_box != null:
		items._box_put(1, items.inventory_of(1), tap, tap_box, slot_of("stick"), 1)

	check(heard("does not take that") and have("stick") == 1, "only a water container goes in (%s)" % str(said))
	items.inventory_of(1).take_from_slot(slot_of("stick"), 1)
	items.give(1, n("waterskin"), 1)
	var skin_slot: int = slot_of("waterskin")
	items.inventory_of(1).wear[skin_slot] = 0

	if tap_box != null:
		items._box_put(1, items.inventory_of(1), tap, tap_box, skin_slot, 1)

	var in_tap: int = -1

	for s in (tap_box.slot_count if tap_box != null else 0):
		if tap_box.numbers[s] == n("waterskin"):
			in_tap = s

	check(in_tap >= 0 and have("waterskin") == 0, "a Waterskin goes in")
	level_now()
	check(in_tap >= 0 and tap_box.wear[in_tap] == 0, "it stays empty while the barrels are dry")
	items._water.set_litres(a, keep_a)
	items._water.set_litres(b, keep_b)
	held = litres(a) + litres(b)
	level_now()
	var got_ml: int = tap_box.wear[in_tap] if in_tap >= 0 else 0
	check(got_ml == 1500 and absf(held - litres(a) - litres(b) - 1.5) < 0.01, "with water in the barrels it fills (%d of 1500 ml) and the barrels give 1.5 L (%.2f -> %.2f L)" % [got_ml, held, litres(a) + litres(b)])

	net_ok("tap")

	# --- A drip head keeps the soil in a 10 m circle round it watered while its pipes bring any water (Dave 19 Nov 2026 20:09Z) ---
	items.report_position(1, Vector3(200.0, 10.0, 200.0))
	var e: int = barrel(200.0, 200.0)
	var near_bed: int = put("tilled_bed", Vector3(203.0, 10.0, 200.0))
	var far_bed: int = put("tilled_bed", Vector3(209.5, 10.0, 200.0))
	var high_bed: int = put("tilled_bed", Vector3(202.5, 11.0, 200.5))
	var out_bed: int = put("tilled_bed", Vector3(202.0, 10.0, 210.5))
	lay(slot_of("copper_pipe"), Vector3(200.0, 10.05, 200.0), Vector3(202.0, 10.05, 200.0))
	items.give(1, n("copper_drip_head"), 1)
	lay(slot_of("copper_drip_head"), Vector3(202.0, 10.05, 200.0), Vector3(202.0, 10.05, 200.0))
	var drip: int = at_kind("copper_drip_head", Vector3(202.0, 10.05, 200.0))
	var beds: Array = items._trench_beds.get(drip, [])
	check(drip != 0 and beds.has(near_bed) and beds.has(far_bed) and beds.has(high_bed) and not beds.has(out_bed), "a drip head waters the beds 1 m, 7.5 m and a metre up from it, not one 10.5 m off (%s)" % str(beds))
	var wet_dry: float = items.plot_moisture(Vector3(209.5, 10.0, 200.0))
	items._water_dirty = true
	items._water_tick(0.0)
	clock[0] += 120.0 * GameClockScript.RATIO
	items._water_dirty = true
	items._water_tick(0.0)
	check(items.plot_moisture(Vector3(209.5, 10.0, 200.0)) <= wet_dry + 0.01, "with its barrel empty it waters nothing (%.1f %%)" % items.plot_moisture(Vector3(209.5, 10.0, 200.0)))
	items._water.set_litres(e, 150.0)
	items._water_dirty = true
	items._water_tick(0.0)
	clock[0] += 120.0 * GameClockScript.RATIO
	items._water_dirty = true
	items._water_tick(0.0)
	var wet_now: Array = [items.plot_moisture(Vector3(203.0, 10.0, 200.0)), items.plot_moisture(Vector3(209.5, 10.0, 200.0)), items.plot_moisture(Vector3(202.5, 11.0, 200.5))]
	check(drip != 0 and items._water.inflow_lpm(drip) > 0.0 and items._water.inflow_lpm(drip) <= 2.01 and float(wet_now[0]) >= 99.9 and float(wet_now[1]) >= 99.9 and float(wet_now[2]) >= 99.9, "with water it draws at most 2 L/min and keeps every bed in its circle fully watered (%.2f L/min, %s %%)" % [items._water.inflow_lpm(drip) if drip != 0 else 0.0, str(wet_now)])
	check(items.plot_moisture(Vector3(202.0, 10.0, 210.5)) < 99.0, "the bed outside the circle is not watered (%.1f %%)" % items.plot_moisture(Vector3(202.0, 10.0, 210.5)))

	net_ok("drip head")

	# --- A worn wooden pipe leaks: it carries its condition's share ---
	var f: int = barrel(300.0, 300.0)
	items.report_position(1, Vector3(300.0, 10.0, 300.0))
	items.give(1, n("wooden_pipe"), 1)
	lay(slot_of("wooden_pipe"), Vector3(300.0, 10.05, 300.0), Vector3(301.9, 10.05, 300.0))
	var wood: int = run_between(Vector3(300.0, 10.05, 300.0), Vector3(301.9, 10.05, 300.0))
	check(wood != 0 and have("wooden_pipe") == 0 and absf(float(items._water.pieces[wood].get("cap_lpm", 0.0)) - 60.0) < 0.01, "a new 1.9 m wooden run takes 1 piece and carries 60 L/min")
	items._items[wood]["struct"]["born"] = items._now_game_s() - 40.0 * 86400.0
	items._pipe_wear_next_s = 0.0
	items._water_tick(0.0)
	items._water_tick(0.0)
	check(wood != 0 and float(items._water.pieces[wood].get("cap_lpm", 60.0)) < 59.5 and float(items._water.pieces[wood].get("cap_lpm", 0.0)) >= 14.99, "an old one carries less (%.1f L/min at %.2f condition)" % [float(items._water.pieces[wood].get("cap_lpm", 0.0)), items.piece_condition(wood)])
	check(f != 0, "(its barrel)")

	net_ok("wear")

	# --- Refusals ---
	items.report_position(1, Vector3(102.0, 10.0, 100.0))
	said.clear()
	lay(slot_of("copper_pipe"), Vector3(110.0, 10.0, 110.0), Vector3(102.0, 10.0, 102.0))
	check(heard("Start a pipe at"), "a run must start at a connection point (%s)" % str(said))
	said.clear()
	var lots: int = barrel(140.0, 100.0)
	items.report_position(1, Vector3(136.0, 10.0, 100.0))
	lay(slot_of("copper_pipe"), Vector3(104.0, 10.05, 100.0), Vector3(140.0, 10.05, 100.0))
	check(heard("at most 30 m") and lots != 0, "a run longer than 30 m is refused (%s)" % str(said))
	said.clear()
	var c: int = barrel(110.0, 100.0)
	items.report_position(1, Vector3(108.0, 10.0, 100.0))
	lay(slot_of("copper_pipe"), Vector3(104.0, 10.05, 100.0), Vector3(110.0, 10.05, 100.0))
	check(heard("needs 2") and c != 0 and have("copper_pipe") == 1, "6 m of copper needs 2 pieces: with 1 it is refused and nothing is taken (%s)" % str(said))

	net_ok("refusals")

	# --- Taking down: a run keeps its tap until that comes off, then gives its pieces back ---
	items.report_position(1, Vector3(102.0, 10.0, 102.0))
	said.clear()
	items._take_down(1, items.inventory_of(1), branch)
	check(items._items.has(branch) and heard("Take the"), "a run with a tap on its end stays until the tap comes off (%s)" % str(said))
	said.clear()
	items._take_down(1, items.inventory_of(1), tap)
	check(items._items.has(tap) and heard("Empty it first"), "a tap with a container in it stays until that is taken out (%s)" % str(said))

	if in_tap >= 0:
		tap_box.take_from_slot(in_tap, 1)

	items._take_down(1, items.inventory_of(1), tap)
	items._take_down(1, items.inventory_of(1), branch)
	check(not items._items.has(tap) and not items._items.has(branch) and have("copper_tap") == 1 and have("copper_pipe") == 2, "the tap and the branch come back to the pack (%d tap, %d pipe)" % [have("copper_tap"), have("copper_pipe")])

	net_ok("take-down")

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

	# Both ends on one pipe is refused and leaves it whole; a junction in a 1-piece run and taking all three runs down gives back exactly the pieces paid.
	items.peer_connected_hello(1, "piper0000001")   # back after the load, with the same pack
	items.report_position(1, Vector3(301.0, 10.0, 300.5))
	said.clear()
	lay(slot_of("copper_pipe"), Vector3(300.5, 10.05, 300.0), Vector3(301.5, 10.05, 300.0))
	check(heard("same pipe") and run_between(Vector3(300.0, 10.05, 300.0), Vector3(301.9, 10.05, 300.0)) == wood2, "both ends on the same pipe are refused and it stays whole (%s)" % str(said))
	var wood_before: int = have("wooden_pipe")
	var copper_before: int = have("copper_pipe")
	var split_at: Vector3 = Vector3(300.95, 10.05, 300.0)
	lay(slot_of("copper_pipe"), split_at, split_at + Vector3(0.0, 0.0, 2.0))
	var w1: int = run_between(Vector3(300.0, 10.05, 300.0), split_at)
	var w2: int = run_between(split_at, Vector3(301.9, 10.05, 300.0))
	var br: int = run_between(split_at, split_at + Vector3(0.0, 0.0, 2.0))
	check(w1 != 0 and w2 != 0 and br != 0 and int(items._items[w1]["struct"]["paid"]) + int(items._items[w2]["struct"]["paid"]) == 1 and have("copper_pipe") == copper_before - 1, "a branch from the middle of a 1-piece wooden run splits it; its halves share that one piece")

	for id in [br, w1, w2]:
		if id != 0:
			items._take_down(1, items.inventory_of(1), id)

	check(have("wooden_pipe") == wood_before + 1 and have("copper_pipe") == copper_before, "taken down, the three runs give back exactly 1 wooden and 1 copper pipe, nothing made (%d wooden, %d copper)" % [have("wooden_pipe") - wood_before, have("copper_pipe") - copper_before + 1])

	# An old save's Wooden - Pipe (a hammer piece, no laid row) loads as a 2 m run on its old axis, 0.13 m up.
	var old: Dictionary = {"pos": Vector3(0.0, 10.0, 0.0), "struct": {"kind": "wooden_pipe", "yaw": 90.0}}
	items._pipe_from_legacy(old)
	var old_ends: Array = PipeRules.ends(old["pos"], 90.0, float(old["struct"]["pitch"]), float(old["struct"]["len"]))
	check(absf((old["pos"] as Vector3).y - 10.13) < 0.001 and float(old["struct"]["len"]) == 2.0 and int(old["struct"]["paid"]) == 1 and absf(absf((old_ends[0] as Vector3).z) - 1.0) < 0.001, "an old Wooden - Pipe loads as a 2 m run along its old axis (%s)" % str(old_ends))

	net_ok("after load")

	# --- A run ending on the ground, capped ends, and a fitting or barrel on a joint (Dave 19 Nov 2026 20:31Z) ---
	var g: int = barrel(400.0, 400.0)
	var g_start: Vector3 = Vector3(400.0, 10.05, 400.0)
	var g_end: Vector3 = Vector3(408.0, 10.0, 400.0)
	items.give(1, n("copper_pipe"), 3)
	items.report_position(1, Vector3(405.0, 10.0, 400.0))
	said.clear()
	lay(slot_of("copper_pipe"), g_start, g_end)
	var garden: int = run_between(g_start, g_end)
	check(garden != 0 and int(items._items[garden]["struct"]["paid"]) == 3, "a run from a barrel can end on the ground across the garden (8 m, 3 copper pieces; %s)" % str(said))
	var joints: Array = PipeRules.joints(g_start, g_end, 3.0)
	check(joints.size() == 2 and (joints[0] as Vector3).distance_to(g_start.lerp(g_end, 3.0 / 8.0)) < 0.001, "its 3 m segments meet at 2 joints, at 3 m and 6 m (%s)" % str(joints))
	items._water.set_litres(g, 100.0)
	items._water_dirty = true
	items._water_tick(0.0)
	clock[0] += 600.0 * GameClockScript.RATIO
	items._water_dirty = true
	items._water_tick(0.0)
	check(absf(litres(g) - 100.0) < 0.01, "its open end on the ground is capped: the barrel loses nothing (%.2f L)" % litres(g))
	items.give(1, n("copper_drip_head"), 1)
	lay(slot_of("copper_drip_head"), joints[0], joints[0])
	var joint_drip: int = at_kind("copper_drip_head", joints[0])
	var to_joint: int = run_between(g_start, joints[0])
	var past_joint: int = run_between(joints[0], g_end)
	check(joint_drip != 0 and to_joint == garden and past_joint != 0 and items._water.downstream(to_joint).has(joint_drip), "a drip head fits on a joint: the run is two meeting there and the pipe feeds it (%s)" % str(said))
	check(int(items._items[to_joint]["struct"]["paid"]) + int(items._items[past_joint]["struct"]["paid"]) == 3, "the halves share the run's 3 pieces")
	items._water_dirty = true
	items._water_tick(0.0)
	check(joint_drip != 0 and items._water.inflow_lpm(joint_drip) == 0.0, "with no bed in its circle the drip head draws nothing")
	items.give(1, n("copper_tap"), 1)
	lay(slot_of("copper_tap"), g_end, g_end)
	check(at_kind("copper_tap", g_end) != 0, "a tap fits on the run's end on the ground")
	items.give(1, n("wooden_barrel_kit"), 1)
	var late: Vector3 = (joints[1] as Vector3) - FOOT
	items._place_structure(1, items.inventory_of(1), slot_of("wooden_barrel_kit"), late + Vector3(0.3, 0.0, 0.2), 0, items._structure_of_kit("wooden_barrel_kit"))
	var on_joint: int = at_kind("wooden_barrel", late)
	check(on_joint != 0 and run_between(g_start.lerp(g_end, 3.0 / 8.0), joints[1]) != 0 and run_between(joints[1], g_end) != 0, "a barrel set down by a joint sits on it and the run is split there (%s)" % str(said))
	var linked: bool = false

	for group in items._water.level_groups():
		linked = linked or ((group as Array).has(g) and (group as Array).has(on_joint))

	check(linked, "and it is linked to the first barrel through the pipe")

	net_ok("joints")

	# A run so short and steep that its two ends lie within a joint of each other never feeds itself (a loop would stop every solve).
	var h: int = barrel(420.0, 400.0)
	items.give(1, n("copper_pipe"), 1)
	items.report_position(1, Vector3(419.0, 10.0, 400.0))
	lay(slot_of("copper_pipe"), Vector3(420.0, 10.05, 400.0), Vector3(420.25, 10.3, 400.0))
	var stub: int = run_between(Vector3(420.0, 10.05, 400.0), Vector3(420.25, 10.3, 400.0))
	check(h != 0 and stub != 0 and not items._water.downstream(stub).has(stub) and not (items._water._up.get(stub, []) as Array).has(stub), "a 0.35 m steep run from a barrel is not linked to itself")
	items._water.set_litres(h, 50.0)
	items._water_dirty = true
	items._water_tick(0.0)
	net_ok("short steep run")

	print("pipe runs: %d failures" % failures)
	items._finish_writer()
	quit(1 if failures > 0 else 0)
