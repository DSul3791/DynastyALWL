extends SceneTree

# Irrigation (garden moisture stage 2, docs/design/GARDEN_MOISTURE.md s3; Dave 19 Nov 2026: pipes from a water source uphill run "onto the garden or into an
# irrigation trench that should improve the moisture level of the soil around it for upto 30 meters in either direction"; values PROVISIONAL GM-5..GM-8):
# a garden plot under a channel's end takes its water as moisture; the hoe digs an irrigation trench (ACT_DIG_TRENCH) that catches a channel's water and
# shares it among the beds within 30 m that are no higher than 0.5 m above it, each by the room its soil has; a full set of beds takes no more.
#   godot --headless --path . --script res://src/worldgen/tools/test_irrigation.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const GameClockScript := preload("res://src/shared/game_clock.gd")
const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")

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

	var it = ItemsScript.new()
	it.send_full = func(_p, _b): pass
	it.send_slots = func(_p, _b): pass
	it.send_world_items = func(_p, _a, _r): pass
	it.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	it.send_notice = func(_p, t): said.append(str(t))
	it.ground_height = func(_x, _z): return 10.0
	it.game_seconds = func(): return clock[0]
	it.setup(ItemTableScript.load_default(), dir)
	return it


func put(kind: String, pos: Vector3, yaw: float = 0.0) -> int:
	var id: int = items._next_id
	items._items[id] = {"number": items.table.number_of(str(items._structures[kind]["item"])), "count": 1, "pos": pos, "left": 1.0e9, "struct": {"kind": kind, "yaw": yaw}}
	items._next_id += 1
	items._water_add(id)
	return id


# A stand-in spring of 30 L a minute whose outlet pours into the +X end of a channel at `at` (the channel then runs to -X, its outlet at at.x - 1).
func spring_and_channel(at: Vector3) -> int:
	put("test_spring", at + Vector3(1.0, 0.0, 0.0))
	return put("wooden_channel", at)


func moist(id: int) -> float:
	return items.plot_moisture(items._items[id]["pos"])


func _init() -> void:
	items = make("user://test_irrigation")
	items._crop_table()

	# Data: the trench is a new structure and item (Dave named it); every garden plot catches water.
	var trench_row: Dictionary = items._structures.get("irrigation_trench", {})
	check(int(trench_row.get("state", 0)) == 457 and str(trench_row.get("kit", "x")) == "" and str((trench_row.get("water", {}) as Dictionary).get("role", "")) == "consumer", "the irrigation trench is structure state 457, dug (no kit), a water consumer")
	check(is_equal_approx(float(trench_row.get("irrigates_m", 0.0)), 30.0) and items.table.number_of("irrigation_trench") == 1507, "it waters beds within 30 m; item 1507")

	for kind in ["small_garden_plot", "wooden_garden_plot", "large_garden_plot"]:
		check(str(((items._structures[kind] as Dictionary).get("water", {}) as Dictionary).get("role", "")) == "consumer", "%s catches water (a consumer)" % kind)

	items._structures["test_spring"] = {"kit": "test_spring_kit", "item": "wooden_channel", "state": 9907, "footprint_x": 1.0, "footprint_z": 1.0, "cap_per_chunk": 50, "water": {"role": "source", "outlet": [0.0, 0.5, 0.0], "rate_lpm": 30.0, "cap_lpm": 30.0, "quality": "clean"}}

	# The end of a channel over a Medium plot (2 x 2 m, 1 L a percent): 30 L a minute is 30 percent a real minute.
	var run: int = spring_and_channel(Vector3(200.0, 10.0, 200.0))
	var plot: int = put("wooden_garden_plot", Vector3(198.6, 10.0, 200.0))
	items._water_tick(0.0)
	check(items._water.downstream(run).has(plot) and is_equal_approx(items._water.inflow_lpm(plot), 30.0), "a channel's end over a garden plot pours in at 30 L/min (%.1f)" % items._water.inflow_lpm(plot))
	clock[0] += 30.0 * GameClockScript.RATIO   # 30 real seconds: 15 L
	items._water_dirty = true
	items._water_tick(0.0)
	check(absf(moist(plot) - 65.0) < 0.01, "30 s later the plot has had 15 L: 50 to 65 percent (%.2f)" % moist(plot))

	# A trench under a channel's end, with beds near and far, low and high.
	var near_bed: int = put("tilled_bed", Vector3(110.0, 10.02, 100.0))
	var near_dry: int = put("tilled_bed", Vector3(90.0, 9.0, 100.0))
	var far_bed: int = put("tilled_bed", Vector3(140.0, 10.02, 100.0))
	var high_bed: int = put("tilled_bed", Vector3(100.0, 11.0, 115.0))
	items._plot_water[items._bed_key(items._items[near_dry]["pos"])] = [20.0, clock[0]]
	var feed: int = spring_and_channel(Vector3(100.0, 10.0, 100.0))

	# Dig it with the hoe, as the client sends it: the held hoe slot, the way the player faces, the point aimed at.
	items.peer_connected_hello(1, "irrigator0001")
	items.report_position(1, Vector3(98.5, 10.0, 101.0))
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("wooden_hoe" if items.table.has_id("wooden_hoe") else "stone_hoe"), 0, 1, Vector3.ZERO)   # onto the hotbar, as test_farming gives
	var hoe: int = HeldTool.slot_of(items, "hoe")
	items.action(1, Net.ACT_DIG_TRENCH, -1, 0, 0, Vector3(98.6, 10.0, 100.0))
	check(items._items.keys().filter(func(k): return items._items[k].has("struct") and str(items._items[k]["struct"]["kind"]) == "irrigation_trench").is_empty(), "no hoe in hand: no trench")
	items.action(1, Net.ACT_DIG_TRENCH, hoe, 90, 0, Vector3(98.6, 10.0, 100.0))
	var trenches: Array = items._items.keys().filter(func(k): return items._items[k].has("struct") and str(items._items[k]["struct"]["kind"]) == "irrigation_trench")
	check(trenches.size() == 1, "with the hoe in hand one trench is dug")
	var trench: int = int(trenches[0]) if trenches.size() == 1 else -1

	if trench < 0:
		print("irrigation: %d failures" % (failures))
		quit(1)
		return

	check(is_equal_approx(float(items._items[trench]["struct"]["yaw"]), 90.0) and items._water_kind.has(trench), "it is turned the way the player faces and joins the water network")
	var waters: Array = items._trench_beds.get(trench, [])
	check(waters.has(near_bed) and waters.has(near_dry) and not waters.has(far_bed) and not waters.has(high_bed), "it waters the beds within 30 m no higher than 0.5 m above it, not the one 40 m off or the one 1 m up (%s)" % str(waters))
	check(items._water.downstream(feed).has(trench), "the channel's end over it feeds it")

	items._last_dig.clear()
	said.clear()
	items.action(1, Net.ACT_DIG_TRENCH, hoe, 0, 0, Vector3(98.9, 10.0, 100.2))
	check(said.has("A trench is dug there already."), "a second trench on top of it is refused (%s)" % str(said))
	items._last_dig.clear()
	said.clear()
	items.report_position(1, Vector3(108.0, 10.0, 100.0))
	items.action(1, Net.ACT_DIG_TRENCH, hoe, 0, 0, Vector3(110.0, 10.0, 100.0))
	check(said.has("That is a garden bed: dig the trench beside it."), "a trench on a bed is refused")

	# The water is shared by each bed's room: both beds' rooms are 12.5 L (50 percent) and 20 L (80), 32.5 L in all; 30 s at 30 L/min is 15 L.
	items._water_tick(0.0)
	check(is_equal_approx(items._water.inflow_lpm(trench), 30.0), "the trench takes the channel's 30 L/min (%.1f)" % items._water.inflow_lpm(trench))
	clock[0] += 30.0 * GameClockScript.RATIO
	items._water_dirty = true
	items._water_tick(0.0)
	var share: float = 15.0 / 32.5
	check(absf(moist(near_bed) - (50.0 + 50.0 * share)) < 0.05 and absf(moist(near_dry) - (20.0 + 80.0 * share)) < 0.05, "15 L shared by room: %.1f and %.1f percent (%.2f, %.2f)" % [50.0 + 50.0 * share, 20.0 + 80.0 * share, moist(near_bed), moist(near_dry)])
	check(is_equal_approx(moist(far_bed), 50.0) and is_equal_approx(moist(high_bed), 50.0), "the far bed and the high bed get none")

	# A minute more fills both; then the trench takes no more and the channel's water backs up.
	clock[0] += 60.0 * GameClockScript.RATIO
	items._water_dirty = true
	items._water_tick(0.0)
	check(moist(near_bed) > 99.9 and moist(near_dry) > 99.9, "a minute more fills both beds (%.2f, %.2f)" % [moist(near_bed), moist(near_dry)])
	items._water_dirty = true
	items._water_tick(0.0)
	check(items._water.inflow_lpm(trench) == 0.0, "with every bed full the trench takes nothing")

	# A bed tilled near it later joins at the next hourly plots pass; a gone trench leaves the network and its list.
	var late_bed: int = put("tilled_bed", Vector3(100.0, 10.02, 85.0))
	items._plots_at_s = -1.0e18
	items._plots_tick()
	check((items._trench_beds.get(trench, []) as Array).has(late_bed), "a bed tilled later is watered from the next hourly pass")
	items._items.erase(trench)
	items._water_tick(0.0)
	check(not items._water_kind.has(trench) and not items._trench_beds.has(trench), "a trench gone leaves the network")

	print("irrigation: %d failures" % failures)
	quit(1 if failures > 0 else 0)
