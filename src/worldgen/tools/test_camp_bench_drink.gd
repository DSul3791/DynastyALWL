extends SceneTree

# Camp bench and drink (Dino's finding #11, Tyler 1 Nov 2026): a bench beside a sheltered camp adds comfort (a seat piece), and drinking from water within reach of the player lowers thirst
# (the water level goes up), is refused away from water, and stops at the cap.
#   godot --headless --path . --script res://src/worldgen/tools/test_camp_bench_drink.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var items
var near_water: Array = [false]


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var dir: String = "user://test_camp_bench_drink"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, _t): pass
	items.ground_height = func(_x, _z): return 10.0
	items.cover_at = func(_p): return 1.0
	items.water_near = func(_pos, _reach): return near_water[0]
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "benchdrink0001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))

	# The bench: a sheltered character alone has 1; a bench within reach adds its points.
	var alone: int = int(items.comfort_at(1, true)["level"])
	var id: int = items._next_id
	items._items[id] = {"number": 0, "count": 1, "pos": Vector3(1.5, 10.0, 0.0), "left": 1.0e9, "struct": {"kind": "bench", "yaw": 0.0}}
	items._next_id += 1
	var with_bench: int = int(items.comfort_at(1, true)["level"])
	check(alone == 1, "sheltered alone is comfort 1 (%d)" % alone)
	check(with_bench > alone, "a bench beside the camp raises the comfort (%d -> %d)" % [alone, with_bench])
	items._items[id]["pos"] = Vector3(60.0, 10.0, 0.0)
	check(int(items.comfort_at(1, true)["level"]) == alone, "a bench 60 m away adds nothing")

	# Drinking.
	var v: Dictionary = items.vitals_of(1)
	v["wet"] = 500.0
	near_water[0] = false
	items._last_drink.clear()
	items.action(1, Net.ACT_DRINK, -1, 0, 0, Vector3.ZERO)
	check(float(v["wet"]) == 500.0, "away from water a drink does nothing (wet %.0f)" % float(v["wet"]))
	near_water[0] = true
	items._last_drink.clear()
	items.action(1, Net.ACT_DRINK, -1, 0, 0, Vector3.ZERO)
	check(float(v["wet"]) > 500.0, "beside water a drink raises the water level (wet %.0f)" % float(v["wet"]))
	var cap: float = float(items._vitals_cfg.get("thirst", {}).get("cap_ml", 2400))
	v["wet"] = cap
	items._last_drink.clear()
	items.action(1, Net.ACT_DRINK, -1, 0, 0, Vector3.ZERO)
	check(float(v["wet"]) <= cap, "a full character does not drink past the cap (wet %.0f of %.0f)" % [float(v["wet"]), cap])
	print("camp bench and drink: %d failures" % failures)
	quit(1 if failures > 0 else 0)
