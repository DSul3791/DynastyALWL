extends SceneTree

# Water pieces on the server (buildables plan section 6, part 6b; Steve's design note, 10 Nov 2026): a structure with a structures.json "water" block
# joins the water network when built, its ports turned with its yaw; water a channel brings to a garden plot becomes moisture (1 percent a litre on
# a 2 x 2 plot) until the plot is full; a piece taken away leaves the network; a fifth source in a chunk and a piece closing a loop are refused;
# tank litres are saved and come back; a well or pump needs fresh water within 200 m and no deeper than it reaches, E works it (exertion) and fills the
# worker's containers when nothing is linked below it; E at a trough drinks or fills from it. No water rows exist yet (Jamie's B6 batch), so test rows stand in.
#   godot --headless --path . --script res://src/worldgen/tools/test_water_pieces.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const GameClockScript := preload("res://src/shared/game_clock.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const Network := preload("res://src/shared/water_network.gd")
const TileDataScript := preload("res://src/worldgen/runtime/tile_terrain_data.gd")

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
	it._structures["test_spring"] = {"kit": "test_spring_kit", "item": "test_spring", "state": 9907, "footprint_x": 1.0, "footprint_z": 1.0, "cap_per_chunk": 50, "water": {"role": "source", "outlet": [0.0, 0.5, 0.0], "rate_lpm": 30.0, "cap_lpm": 30.0, "quality": "clean"}}
	it._structures["test_channel"] = {"kit": "test_channel_kit", "item": "test_channel", "state": 9908, "piece": true, "footprint_x": 2.0, "footprint_z": 0.3, "cap_per_chunk": 200, "water": {"role": "conduit", "inlet": [-1.0, 0.3, 0.0], "outlet": [1.0, 0.29, 0.0], "cap_lpm": 120.0, "closed": false}}
	it._structures["test_level_channel"] = {"kit": "test_level_kit", "item": "test_level_channel", "state": 9909, "piece": true, "footprint_x": 2.0, "footprint_z": 0.3, "cap_per_chunk": 200, "water": {"role": "conduit", "inlet": [-1.0, 0.3, 0.0], "outlet": [1.0, 0.3, 0.0], "cap_lpm": 120.0, "closed": false}}
	it._structures["test_plot"] = {"kit": "test_plot_kit", "item": "test_plot", "state": 9910, "plot": true, "footprint_x": 2.0, "footprint_z": 2.0, "cap_per_chunk": 50, "water": {"role": "consumer", "inlet": [0.0, 0.2, 0.0]}}
	it._structures["test_pump"] = {"kit": "test_pump_kit", "item": "test_pump", "state": 9912, "footprint_x": 1.0, "footprint_z": 1.0, "cap_per_chunk": 50, "use_reach_m": 3.0, "water": {"role": "source", "outlet": [0.0, 1.0, 0.0], "cap_lpm": 48.0, "ground_water": true, "max_depth_m": 7.0, "suction": true, "pump": {"cap_lps": 0.8, "watts": 40.0}, "effort": 0.7, "quality": "clean"}}
	it._structures["test_trough"] = {"kit": "test_trough_kit", "item": "test_trough", "state": 9911, "footprint_x": 1.0, "footprint_z": 1.0, "cap_per_chunk": 50, "water": {"role": "tank", "inlet": [0.0, 0.4, 0.0], "litres_max": 100.0}}
	return it


func put(kind: String, pos: Vector3, yaw: float) -> int:
	var id: int = items._next_id
	items._items[id] = {"number": 0, "count": 1, "pos": pos, "left": 1.0e9, "struct": {"kind": kind, "yaw": yaw}}
	items._next_id += 1
	items._water_add(id)
	return id


func at_real_s(seconds: float) -> void:
	clock[0] = seconds * GameClockScript.RATIO
	items._water_tick()


func _init() -> void:
	items = make("user://test_water_pieces")

	# Ports turn with the piece.
	var turned: Dictionary = items.water_piece(items._structures["test_channel"], Vector3(10.0, 5.0, 10.0), 90.0)
	check((turned["inlet"] as Vector3).is_equal_approx(Vector3(10.0, 5.3, 11.0)) and (turned["outlet"] as Vector3).is_equal_approx(Vector3(10.0, 5.29, 9.0)), "a channel turned 90 degrees runs from +z to -z (%s)" % str(turned))
	check(items.water_piece(items._structures.get("wall_section", {"kind": "x"}), Vector3.ZERO, 0.0).is_empty(), "a structure without a water block is no piece")

	# A spring, a channel falling 0.5 percent and a 2 x 2 plot at 50 percent: 30 L/min fill its 50 L of room in 100 s.
	var spring: int = put("test_spring", Vector3(100.0, 10.0, 100.0), 0.0)
	var channel: int = put("test_channel", Vector3(101.0, 10.2, 100.0), 0.0)
	var plot: int = put("test_plot", Vector3(102.0, 10.2, 100.0), 0.0)
	check(items._water.downstream(spring).has(channel) and items._water.downstream(channel).has(plot), "spring, channel and plot join outlet to inlet")
	at_real_s(0.0)
	check(is_equal_approx(items._water.inflow_lpm(plot), 30.0), "the plot gets the spring's 30 L/min (%.1f)" % items._water.inflow_lpm(plot))
	check(is_equal_approx(float(items._water.pieces[plot]["room_l"]), 50.0) and is_equal_approx(items._water_next_s, 100.0), "its room is 50 L at 1 percent a litre, full at 100 s (%.1f L, %.1f s)" % [float(items._water.pieces[plot]["room_l"]), items._water_next_s])
	at_real_s(60.0)
	check(is_equal_approx(items.plot_moisture(Vector3(102.0, 10.2, 100.0)), 50.0), "nothing is worked out between events")
	at_real_s(101.0)
	check(is_equal_approx(items.plot_moisture(Vector3(102.0, 10.2, 100.0)), 100.0), "at the event the water that flowed in is moisture: the plot is full (%.1f)" % items.plot_moisture(Vector3(102.0, 10.2, 100.0)))
	check(items._water.inflow_lpm(plot) == 0.0 and items._water.outflow_lpm(spring) == 0.0, "and a full plot takes no more")

	# Taking the channel away.
	items._items.erase(channel)
	at_real_s(102.0)
	check(not items._water_kind.has(channel) and items._water.downstream(spring).is_empty(), "a channel taken away leaves the network")

	# Four sources to a chunk.
	for n in range(3):
		put("test_spring", Vector3(100.0, 10.0, 102.0 + 2.0 * float(n)), 0.0)

	check(items._water_refusal(items._structures["test_spring"], Vector3(110.0, 10.0, 110.0), 0) == "Too many water sources stand here already.", "a fifth source in a chunk is refused")
	check(items._water_refusal(items._structures["test_spring"], Vector3(300.0, 10.0, 110.0), 0) == "", "in the next chunk it may go")

	# A ring of level channels: the fourth would close a loop.
	put("test_level_channel", Vector3(201.0, 10.0, 200.0), 0.0)
	put("test_level_channel", Vector3(202.0, 10.0, 199.0), 90.0)
	put("test_level_channel", Vector3(201.0, 10.0, 198.0), 180.0)
	check(items._water_refusal(items._structures["test_level_channel"], Vector3(200.0, 10.0, 199.0), 270) == "This would make a loop.", "a channel closing a ring is refused: This would make a loop.")
	check(items._water_refusal(items._structures["test_level_channel"], Vector3(199.0, 10.0, 200.0), 0) == "", "one feeding into the ring is fine")

	# Tank litres are saved and come back.
	var trough: int = put("test_trough", Vector3(150.0, 10.0, 150.0), 0.0)
	items._water.set_litres(trough, 40.0)
	var saved: Dictionary = items._water_tanks_save()
	check(is_equal_approx(float(saved.get(items._water_key(Vector3(150.0, 10.0, 150.0)), -1.0)), 40.0), "a trough's 40 L are saved by its place")
	items._water_rebuild(saved)
	check(items._water_kind.has(trough) and is_equal_approx(items._water.litres(trough, 0.0), 40.0), "and come back with the trough at load")
	check(is_equal_approx(items._water.still_after_s, 3.0 * 3600.0), "standing water goes still after 3 game days (3 real hours)")

	# The baked map's nearest fresh water: a lake sample 141 m away counts, the sea does not, and none within 100 m is NAN.
	var tile = TileDataScript.new()
	tile.samples = 3
	tile.spacing_m = 100.0
	tile.water_class = PackedByteArray([0, 0, 0, 0, 2, 0, 0, 0, 1])
	tile.water_surface = PackedFloat32Array([NAN, NAN, NAN, NAN, 5.0, NAN, NAN, NAN, -1.0])
	check(is_equal_approx(tile.fresh_water_y(Vector3(0.0, 20.0, 0.0), 200.0), 5.0), "the lake 141 m away is the nearest fresh water (%.1f)" % tile.fresh_water_y(Vector3(0.0, 20.0, 0.0), 200.0))
	check(is_nan(tile.fresh_water_y(Vector3(0.0, 20.0, 0.0), 100.0)), "none within 100 m")
	check(is_nan(tile.fresh_water_y(Vector3(200.0, 20.0, 200.0), 50.0)), "the sea is not fresh water")
	check(is_equal_approx(tile.fresh_water_near(Vector3(0.0, 20.0, 0.0), 200.0).x, sqrt(20000.0)), "fresh_water_near gives the distance too, to pick the nearest across tiles")

	# Sonny: seasonal channels and ponds (8, 9) and salt marsh (10) are not fresh water for a well; a bog (7) is, with the table at the surface.
	for code in [8, 9, 10]:
		tile.water_class = PackedByteArray([0, 0, 0, 0, code, 0, 0, 0, 1])
		check(is_nan(tile.fresh_water_y(Vector3(0.0, 20.0, 0.0), 200.0)), "water class %d does not count for a well" % code)

	tile.water_class = PackedByteArray([0, 0, 0, 0, 7, 0, 0, 0, 1])
	check(is_equal_approx(tile.fresh_water_y(Vector3(0.0, 20.0, 0.0), 200.0), 5.0), "a bog counts for a well")

	# Sonny section 1: a suction pump's 7 m falls 1 m for every 1,000 m of height; a windlass or deep pump (no suction) keeps its reach.
	check(is_equal_approx(ItemsScript._lift_limit_m(items._structures["test_pump"]["water"], Vector3(0.0, 2000.0, 0.0)), 5.0), "a hand pump 2,000 m up lifts 5 m")
	check(is_equal_approx(ItemsScript._lift_limit_m({"max_depth_m": 25.0}, Vector3(0.0, 2000.0, 0.0)), 25.0), "a windlass 2,000 m up still reaches 25 m")

	# Wells and pumps (6b part 2): they reach down to the nearest fresh water within 200 m, no deeper than their max_depth_m.
	items.fresh_water_y = func(pos, _reach): return NAN if pos.x > 500.0 else (1.0 if pos.z > 400.0 else 6.0)
	var pump_def: Dictionary = items._structures["test_pump"]
	check(items._water_refusal(pump_def, Vector3(600.0, 10.0, 300.0), 0) == "There is no fresh water within 200 m to reach down to.", "a pump with no fresh water within 200 m is refused")
	check(items._water_refusal(pump_def, Vector3(300.0, 10.0, 450.0), 0) == "The water lies 9 m down here, too deep for this.", "and one over water 9 m down, past its 7 m (%s)" % items._water_refusal(pump_def, Vector3(300.0, 10.0, 450.0), 0))
	check(items._water_refusal(pump_def, Vector3(300.0, 10.0, 300.0), 0) == "", "4 m down it may go")
	var pump: int = put("test_pump", Vector3(300.0, 10.0, 300.0), 0.0)

	# E works it, the water pours into the worker's bucket (nothing is linked below it), and the work is exertion.
	items.peer_connected_hello(1, "pumper000001")
	items.report_position(1, Vector3(301.0, 10.0, 300.0))
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("bucket"), 0, 1, Vector3.ZERO)
	var inv = items.inventory_of(1)
	var bucket: int = inv.numbers.find(items.table.number_of("bucket"))
	items._use_struct(1, inv, pump)
	check(int(items._pumping.get(1, 0)) == pump and is_equal_approx(float(items._water.pieces[pump]["rate_lpm"]), Network.pump_lpm(0.8, 40.0, 4.0)), "E starts the pump at its rate over 4 m (%.1f L/min)" % float(items._water.pieces[pump].get("rate_lpm", 0.0)))
	items._water_tick(10.0)
	check(bucket >= 0 and int(inv.wear[bucket]) == 8000, "10 s at 48 L/min fill the 8 L bucket (%d ml)" % (int(inv.wear[bucket]) if bucket >= 0 else -1))
	check(items.effort_of(1) >= 0.7, "pumping is work (%.2f)" % items.effort_of(1))
	items._water_tick(1.0)
	check(not items._pumping.has(1), "with nothing left to fill, the pump stops")
	inv.wear[bucket] = 0
	items._use_struct(1, inv, pump)
	items._use_struct(1, inv, pump)
	check(not items._pumping.has(1) and float(items._water.pieces[pump]["rate_lpm"]) == 0.0, "E again stops it")
	items._use_struct(1, inv, pump)
	items.report_position(1, Vector3(310.0, 10.0, 300.0))
	items._water_tick(0.25)
	check(not items._pumping.has(1), "walking away stops it")

	# A trough: E drinks from it, or fills the container in hand, and the water comes out of the trough.
	var water_trough: int = put("test_trough", Vector3(320.0, 10.0, 300.0), 0.0)
	items._water.set_litres(water_trough, 50.0)
	items.report_position(1, Vector3(320.5, 10.0, 300.0))
	var fill_ml: int = int(items._vitals_cfg.get("thirst", {}).get("fill_ml", 500))
	items._drink_water(1, bucket, inv)
	check(int(inv.wear[bucket]) == fill_ml and absf(items._water.litres(water_trough, items._water_now_s()) - (50.0 - float(fill_ml) / 1000.0)) < 0.001, "E with a bucket at a trough fills %d ml from it (%.3f L left)" % [fill_ml, items._water.litres(water_trough, items._water_now_s())])

	print("water pieces: %d failures" % failures)
	quit(1 if failures > 0 else 0)
