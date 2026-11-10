extends SceneTree

# The Bedroll (Part C plan 5, design/part_c_code_plan.md; sleep.json "bedroll"): in the pack it lifts sleep on open dry ground from 0.6 to
# 0.85 and takes half a bed's warmth off the cold stress while lying down. Under cover it adds nothing to sleep, rain still stops sleep in
# the open, and it is not a bed. Jamie's row is not in yet, so a stand-in bedroll is used.
#   godot --headless --path . --script res://src/worldgen/tools/test_bedroll.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var dir: String = "user://test_bedroll"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var cover: Array = [0.0]
	var rain: Array = [0.0]
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, _t): pass
	items.ground_height = func(_x, _z): return 10.0
	items.cover_at = func(_p): return cover[0]
	items.rain_now = func(): return rain[0]
	items.weather_now = func(): return {"temp_c": 10.0, "wind": 0.0, "rain": rain[0]}
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "roll-key-00000001")
	items.report_position(1, Vector3(5.0, 0.0, 5.0))
	var cfg: Dictionary = items._sleep_cfg["bedroll"]
	check(is_equal_approx(float(cfg["open_dry"]), 0.85) and is_equal_approx(float(cfg["warmth_bonus"]), 0.05), "the bedroll numbers are the plan's")

	if not items.table.has_id("bedroll"):
		var row: Dictionary = {"id": "bedroll", "number": 99992, "name": "Bedroll", "kind": "placeable", "stack": 1, "unstackable": true}
		items.table._by_id["bedroll"] = row
		items.table._by_number[99992] = row

	var open_q: float = float(items._sleep_cfg["quality"]["open_dry"])
	check(is_equal_approx(items._sleep_quality(1), open_q), "open dry ground without a bedroll is %.2f" % open_q)
	var stand_bare: float = items.warmth_target(1)
	items._stance[1] = 3
	var bare: float = items.warmth_target(1)
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("bedroll"), 0, 1, Vector3.ZERO)
	check(items._has_bedroll(1), "the bedroll is in the pack")
	check(is_equal_approx(items._sleep_quality(1), 0.85), "with it, open dry ground is 0.85 (%.2f)" % items._sleep_quality(1))
	var rolled: float = items.warmth_target(1)
	check(rolled > bare and rolled - bare < 0.1 * (100.0 - bare) + 0.01, "lying in it the cold bites a little less (%.2f against %.2f)" % [rolled, bare])
	items._stance[1] = 0
	check(is_equal_approx(items.warmth_target(1), stand_bare), "standing, it gives no warmth")
	cover[0] = 1.0
	check(is_equal_approx(items._sleep_quality(1), float(items._sleep_cfg["quality"]["covered"])), "under cover it adds nothing to sleep")
	cover[0] = 0.0
	rain[0] = 0.5
	check(items._sleep_quality(1) < 0.0, "rain in the open still stops sleep: a bedroll is not a roof")
	rain[0] = 0.0
	check(not items.on_good_bed(1), "it is not a good bed")
	print("bedroll tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
