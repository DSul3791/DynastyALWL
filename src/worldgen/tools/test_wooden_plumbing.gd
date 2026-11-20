extends SceneTree

# Wooden plumbing (plumbing PR 2, docs/design/PLUMBING_DESIGN.md s5; Dave 14 Nov 2026 06:30Z "pipes were originally made from wood"; values PROVISIONAL):
# the real structures.json rows of the Wooden - Channel / corner / tee, Sluice, Wooden - Trough and the Wooden - Pipe (set down as
# an old 2 m hammer piece loads; pipes laid from the hand are test_pipe_runs.gd) join the water network. A channel or pipe turns so its inlet is the end the water comes from, whatever order it was built in; a spout pours into
# a channel or trough below it; a shut sluice stops the flow and E opens it; a trough drains down a log pipe into a lower trough under head.
#   godot --headless --path . --script res://src/worldgen/tools/test_wooden_plumbing.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const Network := preload("res://src/shared/water_network.gd")
const GameClockScript := preload("res://src/shared/game_clock.gd")

var failures: int = 0
var items
var clock: Array = [0.0]
var said: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make(dir: String):
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	return open_dir(dir)


# The server on a world folder as it is (a restart).
func open_dir(dir: String):
	var it = ItemsScript.new()
	it.send_full = func(_p, _b): pass
	it.send_slots = func(_p, _b): pass
	it.send_world_items = func(_p, _a, _r): pass
	it.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	it.send_notice = func(_p, t): said.append(str(t))
	it.ground_height = func(_x, _z): return 10.0
	it.game_seconds = func(): return clock[0]
	it.setup(ItemTableScript.load_default(), dir)
	it.fresh_water_y = func(_pos, _reach): return 6.0   # 4 m down
	return it


func put(kind: String, pos: Vector3, yaw: float = 0.0) -> int:
	var id: int = items._next_id
	items._items[id] = {"number": items.table.number_of(str(items._structures[kind]["item"])), "count": 1, "pos": pos, "left": 1.0e9, "struct": {"kind": kind, "yaw": yaw}}
	items._next_id += 1
	items._pipe_from_legacy(items._items[id])   # a Wooden - Pipe set down this way is an old 2 m hammer piece, as a save from before laid runs loads (PLUMBING_DESIGN s9)
	items._water_add(id)
	return id


func near(a: Vector3, b: Vector3) -> bool:
	return a.distance_to(b) < 0.001


func _init() -> void:
	items = make("user://test_wooden_plumbing")
	var bp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/blueprints.json"))["blueprints"]

	# Data: the wooden pieces are built with the hammer from the start. The log pipes are laid from the hand since 19 Nov 2026 (PLUMBING_DESIGN s9): their
	# hammer blueprints are retired and the elbow and tee load as plain pipe (a laid run turns any way, so they are not needed).
	for id in ["wooden_trough", "wooden_channel", "wooden_channel_corner", "wooden_channel_tee", "wooden_sluice"]:
		check(bp.has(id) and bool(bp[id].get("known", false)) and not bool(bp[id].get("locked", false)), "blueprint %s is known and unlocked" % id)

	for id in ["wooden_pipe", "wooden_pipe_elbow", "wooden_pipe_tee"]:
		check(bool(bp[id].get("retired", false)) and not bool(bp[id].get("known", true)), "blueprint %s is retired: pipe is laid from the hand" % id)

	# The pumps are retired (Dave 20 Nov 2026: no pump technology, water moves by gravity and rain; PLUMBING_DESIGN s10): their rows stay for their
	# numbers, nothing builds them, and a placed one joins no water network.
	for id in ["wooden_hand_pump", "iron_hand_pump", "iron_deep_well_pump"]:
		check(bool(bp[id].get("retired", false)) and not items._blueprints.has(int(bp[id]["number"])) and bool(items._structures[id].get("retired", false)) and not items._structures[id].has("water"), "%s is retired: no blueprint, no water" % id)

	check(str(items._structures["wooden_pipe_elbow"].get("becomes", "")) == "wooden_pipe" and str(items._structures["wooden_pipe_tee"].get("becomes", "")) == "wooden_pipe" and not items._structures["wooden_pipe_tee"].has("water"), "a saved elbow or tee becomes a Wooden - Pipe")
	check(bool(items._structures["wooden_pipe"]["water"]["closed"]) and not bool(items._structures["wooden_channel"]["water"]["closed"]), "a log pipe is closed, a flume open")

	# A tee has one inlet and two outlets; a channel's outlet sits its 1 cm fall lower.
	var tee: Dictionary = items.water_piece(items._structures["wooden_channel_tee"], Vector3(0.0, 10.0, 0.0), 0.0)
	check(near(tee["inlet"], Vector3(-1.0, 10.23, 0.0)) and near(tee["outlet"], Vector3(1.0, 10.22, 0.0)) and (tee.get("outlets", []) as Array).size() == 1 and near(tee["outlets"][0], Vector3(0.0, 10.22, 1.0)), "a tee runs in at -X and out at +X and +Z, 1 cm lower (%s)" % str(tee))

	# A well's spout (a stand-in with the old hand pump's spout; there are no pumps since Dave 20 Nov 2026) pours into the +X end of a channel below
	# it: the channel turns to run from +X to -X. Built channel first, well after.
	items._structures["test_well"] = {"kit": "test_well_kit", "item": "wooden_trough", "state": 9913, "footprint_x": 0.5, "footprint_z": 0.5, "cap_per_chunk": 60, "use_reach_m": 3.0, "water": {"role": "source", "ground_water": true, "windlass": true, "draw_l": 8, "max_depth_m": 7, "effort": 0.7, "outlet": [0.0, 0.7, 0.27], "cap_lpm": 48, "quality": "clean"}}
	var a: int = put("wooden_channel", Vector3(100.0, 10.0, 100.0))
	check(near(items._water.pieces[a]["inlet"], Vector3(99.0, 10.23, 100.0)), "a channel alone runs from its first end")
	var pump: int = put("test_well", Vector3(101.0, 10.0, 99.73))
	check(items._water.downstream(pump).has(a) and near(items._water.pieces[a]["inlet"], Vector3(101.0, 10.23, 100.0)), "with the well's spout over its +X end it turns round: the well feeds it (%s)" % str(items._water.pieces[a]["inlet"]))

	# The sluice next along takes the channel's water; shut as built, it passes none.
	var sluice: int = put("wooden_sluice", Vector3(98.0, 10.0, 100.0))
	check(items._water.downstream(a).has(sluice) and near(items._water.pieces[sluice]["inlet"], Vector3(99.0, 10.23, 100.0)), "the sluice joins below the channel, turned to it")
	var trough: int = put("wooden_trough", Vector3(96.2, 9.6, 100.0), 180.0)
	check(items._water.downstream(sluice).has(trough), "the sluice's outlet over the trough's rim feeds it")

	# Work the well: 48 L a minute at 4 m down (an 8 L draw each 10 s); the shut sluice holds it all back.
	items.peer_connected_hello(1, "plumber00001")
	items.report_position(1, Vector3(99.8, 10.0, 99.5))
	var inv = items.inventory_of(1)
	items._use_struct(1, inv, pump)
	check(int(items._pumping.get(1, 0)) == pump, "E works the well")
	items._water_tick(0.0)
	check(items._water.inflow_lpm(trough) == 0.0, "the shut sluice passes nothing")

	# E opens the sluice: the trough fills at the well's rate.
	items._last_use.erase(1)
	items._use_struct(1, inv, sluice)
	check(str(items._items[sluice]["struct"]["kind"]) == "wooden_sluice_open" and bool(items._water.pieces[sluice]["open"]) and items._water_kind[sluice] == "wooden_sluice_open", "E opens the sluice: it becomes its open twin")
	check(said.has("You open the sluice."), "and says so (%s)" % str(said))
	items._water_tick(0.0)
	check(is_equal_approx(items._water.inflow_lpm(trough), Network.windlass_lpm(4.0, 8.0)), "the trough fills at the well's %.1f L/min (%.1f)" % [Network.windlass_lpm(4.0, 8.0), items._water.inflow_lpm(trough)])
	items._last_use.erase(1)
	items._use_struct(1, inv, sluice)
	items._water_tick(0.0)
	check(str(items._items[sluice]["struct"]["kind"]) == "wooden_sluice" and items._water.inflow_lpm(trough) == 0.0, "E again shuts it")
	items._use_struct(1, inv, pump)

	# The trough drains from its base down a log pipe into a lower trough: a 12 cm head gives 12 percent of the pipe's 60 L/min.
	var pipe: int = put("wooden_pipe", Vector3(94.25, 9.5, 100.0))
	var low: int = put("wooden_trough", Vector3(92.5, 9.0, 100.0))
	check(items._water.downstream(trough).has(pipe) and items._water.downstream(pipe).has(low), "trough, log pipe and lower trough join")
	check(near(items._water.pieces[pipe]["inlet"], Vector3(95.25, 9.63, 100.0)), "the pipe turns to take the trough's water at its +X end (%s)" % str(items._water.pieces[pipe]["inlet"]))
	items._water.set_litres(trough, 50.0)
	items._water_dirty = true
	items._water_tick(0.0)
	check(absf(items._water.inflow_lpm(low) - 60.0 * 0.12) < 0.01, "the lower trough fills at 7.2 L/min (%.2f)" % items._water.inflow_lpm(low))

	# Built in any order: loading the world again turns every piece the same way, and the litres stay.
	var before: Dictionary = {}

	for id in [a, sluice, pipe]:
		before[id] = items._water.pieces[id]["inlet"]

	items._water_rebuild(items._water_tanks_save())
	var same: bool = true

	for id in before:
		same = same and near(items._water.pieces[id]["inlet"], before[id])

	check(same and items._water.downstream(pump).has(a) and items._water.downstream(pipe).has(low), "after a load every channel and pipe runs the same way")
	check(absf(items._water.litres(trough, items._water_now_s()) - 50.0) < 0.5, "and the trough keeps its water (%.2f)" % items._water.litres(trough, items._water_now_s()))

	# Building again turns the pieces again (a relink) without losing what the old network knew: a tank's water quality and its still clock, and the
	# water that was flowing into a plot until that moment (a stand-in spring and 2 x 2 plot, 1 percent a litre, as in test_water_pieces).
	items._structures["test_spring"] = {"kit": "test_spring_kit", "item": "wooden_channel", "state": 9907, "footprint_x": 1.0, "footprint_z": 1.0, "cap_per_chunk": 50, "water": {"role": "source", "outlet": [0.0, 0.5, 0.0], "rate_lpm": 30.0, "cap_lpm": 30.0, "quality": "clean"}}
	items._structures["test_plot"] = {"kit": "test_plot_kit", "item": "wooden_channel", "state": 9910, "plot": true, "footprint_x": 2.0, "footprint_z": 2.0, "cap_per_chunk": 50, "water": {"role": "consumer", "inlet": [0.0, 0.2, 0.0]}}
	put("test_spring", Vector3(200.0, 10.0, 200.0))
	var run: int = put("wooden_channel", Vector3(201.0, 10.0, 200.0))
	var plot: int = put("test_plot", Vector3(202.0, 10.0, 200.0))
	items._water_tick(0.0)
	check(is_equal_approx(items._water.inflow_lpm(plot), 30.0), "a spring pours into a channel that feeds a plot at 30 L/min (%.1f, inlet %s)" % [items._water.inflow_lpm(plot), str(items._water.pieces[run]["inlet"])])
	var t0: float = items._water_now_s()
	items._water._quality[trough] = "river"
	items._water._last_in_s[trough] = t0
	clock[0] += 30.0 * GameClockScript.RATIO   # 30 real seconds: 15 L into the plot
	put("wooden_pipe", Vector3(300.0, 10.0, 300.0))
	check(absf(items.plot_moisture(Vector3(202.0, 10.0, 200.0)) - 65.0) < 0.01, "a piece built 30 s later credits the plot its 15 L first: 65 percent (%.2f)" % items.plot_moisture(Vector3(202.0, 10.0, 200.0)))
	check(is_equal_approx(items._water.inflow_lpm(plot), 30.0), "and the new network goes on feeding it at once")
	check(items._water.quality(trough) == "river" and is_equal_approx(float(items._water._last_in_s.get(trough, -1.0)), t0), "the trough keeps its river water and its still clock (%s, %.1f)" % [items._water.quality(trough), float(items._water._last_in_s.get(trough, -1.0))])
	clock[0] += 30.0 * GameClockScript.RATIO
	items._water_dirty = true
	items._water_tick(0.0)
	check(absf(items.plot_moisture(Vector3(202.0, 10.0, 200.0)) - 80.0) < 0.01, "and 30 s more bring it to 80 percent (%.2f)" % items.plot_moisture(Vector3(202.0, 10.0, 200.0)))

	# A plot taken down and a water piece placed before the next tick: the gone plot leaves first, nothing errors and the new piece's tail runs.
	items._items.erase(plot)
	var late_well: int = put("primitive_well", Vector3(400.0, 10.0, 400.0))
	check(not items._water_kind.has(plot) and items._well_store.has(late_well), "a piece placed just after a plot is taken down: the plot leaves and the new well gets its store")

	# Each connected run is relinked on its own (finding 5): a channel built far away leaves the pump's run as it was, and a run is found from its end.
	var held: Dictionary = items._water.pieces[a]
	var far: int = put("wooden_channel", Vector3(500.0, 10.0, 500.0))
	check(is_same(items._water.pieces[a], held), "a channel built far away does not turn the pump's run again")
	var pump_run: Array = items._water.runs([Vector3(101.0, 10.23, 100.0)])
	check(pump_run.size() == 1 and (pump_run[0] as Array).has(pump) and (pump_run[0] as Array).has(low) and not (pump_run[0] as Array).has(far), "the pump's run reaches down to the lower trough and not to the far channel")

	# Taking the pump away: the channel stands alone and runs from its first end again.
	items._items.erase(pump)
	items._water_tick(0.0)
	check(not items._water_kind.has(pump) and near(items._water.pieces[a]["inlet"], Vector3(99.0, 10.23, 100.0)), "with the pump gone the channel turns back")

	check(not items._retired_blueprint_of_kit.has("rough_bed_kit") and items._retired_blueprint_of_kit.size() == 3, "only the pumps' retired blueprints are cleared at load (a rough bed still takes down as its bed)")
	# A Wooden - Hand pump already standing in a saved world (Dave 20 Nov 2026: "the wooden hand pumps should be gone too") is cleared when the world
	# loads and leaves its materials where it stood (6 lumber, 20 nails, 2 twine, 1 hide); a site leaves what had been put into it.
	var old_pump: int = put("wooden_hand_pump", Vector3(110.0, 10.0, 110.0))
	var old_site: int = put("wooden_hand_pump", Vector3(120.0, 10.0, 120.0))
	items._items[old_site]["struct"]["site"] = {"bp": 129, "have": {"lumber": 2}}
	check(not items._water_kind.has(old_pump), "a placed retired pump joins no water network")
	items._clear_retired_pieces()
	var lumber_n: int = items.table.number_of("lumber")
	check(not items._items.has(old_pump) and items._ground_count(lumber_n, Vector3(110.0, 10.0, 110.0), 2.0) == 6 and items._ground_count(items.table.number_of("nails"), Vector3(110.0, 10.0, 110.0), 2.0) == 20, "a loaded pump is gone, its materials on the ground where it stood (lumber %d)" % items._ground_count(lumber_n, Vector3(110.0, 10.0, 110.0), 2.0))
	var piles_last: bool = true

	for gid in items._items:
		var g: Dictionary = items._items[gid]

		if not g.has("struct") and int(g.get("number", 0)) == lumber_n and (g["pos"] as Vector3).distance_to(Vector3(110.0, 10.0, 110.0)) < 2.0:
			piles_last = piles_last and float(g["left"]) > 1.0e8

	check(piles_last, "what a cleared pump leaves never despawns")
	check(not items._items.has(old_site) and items._ground_count(lumber_n, Vector3(120.0, 10.0, 120.0), 2.0) == 2, "a pump site is gone and leaves what was put in (lumber %d)" % items._ground_count(lumber_n, Vector3(120.0, 10.0, 120.0), 2.0))

	# The round trip: a pump saved in a world is gone once the world loads, its materials lie where it stood, and the next save no longer holds it
	# (loaded again, nothing is given twice).
	var kept = items
	items = make("user://test_pump_clear")
	put("wooden_hand_pump", Vector3(50.0, 10.0, 50.0))
	items.save()
	items = open_dir("user://test_pump_clear")
	var pumps_left: Array = items._items.values().filter(func(g): return g.has("struct") and str(g["struct"]["kind"]) == "wooden_hand_pump")
	check(pumps_left.is_empty() and items._ground_count(lumber_n, Vector3(50.0, 10.0, 50.0), 2.0) == 6, "after a restart the saved pump is gone and its 6 lumber lie there (%d)" % items._ground_count(lumber_n, Vector3(50.0, 10.0, 50.0), 2.0))
	items.save()
	items = open_dir("user://test_pump_clear")
	check(items._ground_count(lumber_n, Vector3(50.0, 10.0, 50.0), 2.0) == 6, "saved and loaded again: the pump stays gone and nothing is given twice (%d)" % items._ground_count(lumber_n, Vector3(50.0, 10.0, 50.0), 2.0))
	items = kept

	print("wooden plumbing: %d failures" % failures)
	quit(1 if failures > 0 else 0)
