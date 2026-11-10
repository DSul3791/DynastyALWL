extends SceneTree

# Water pieces on the server (buildables plan section 6, part 6b; Steve's design note, 10 Nov 2026): a structure with a structures.json "water" block
# joins the water network when built, its ports turned with its yaw; water a channel brings to a garden plot becomes moisture (1 percent a litre on
# a 2 x 2 plot) until the plot is full; a piece taken away leaves the network; a fifth source in a chunk and a piece closing a loop are refused;
# tank litres are saved and come back. No water rows exist yet (Jamie's B6 batch), so test rows stand in.
#   godot --headless --path . --script res://src/worldgen/tools/test_water_pieces.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const GameClockScript := preload("res://src/shared/game_clock.gd")

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

	print("water pieces: %d failures" % failures)
	quit(1 if failures > 0 else 0)
