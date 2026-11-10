extends SceneTree

# Walking on snow (Part C plan 7, data/items/snow_walk.json, src/shared/snow_walk.gd): snow and glacial ice slow the walk to 0.6 and make it
# 1.4 times the work; worn snowshoes bring that to 0.9 and 1.1. The server's exertion follows the ground under the player. Jamie's
# Snowshoes row is not in yet, so a stand-in row is used.
#   godot --headless --path . --script res://src/worldgen/tools/test_snow_walk.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const SnowWalk := preload("res://src/shared/snow_walk.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _effort_after_step(items, ground: String) -> float:
	items.ground_material = func(_x, _z): return ground
	items._snow_memo.clear()
	items._exertion[1] = 0.0
	items._motion[1] = [Vector3(0.0, 10.0, 0.0), Time.get_ticks_msec() - 1000]
	items._note_motion(1, Vector3(3.2, 10.0, 0.0))
	return float(items._exertion[1])


func _init() -> void:
	var cfg: Dictionary = SnowWalk.config()
	check(is_equal_approx(float(cfg["pace_mult"]), 0.6) and is_equal_approx(float(cfg["effort_mult"]), 1.4), "bare feet on snow: 0.6 the pace, 1.4 the work")
	check(is_equal_approx(float(cfg["shod_pace_mult"]), 0.9) and is_equal_approx(float(cfg["shod_effort_mult"]), 1.1), "on snowshoes: 0.9 and 1.1")
	check(SnowWalk.soil_is_snow(11) and SnowWalk.soil_is_snow(12) and not SnowWalk.soil_is_snow(5) and not SnowWalk.soil_is_snow(-1), "soils 11 (snow) and 12 (glacial ice) are snow; loam and nothing are not")
	check(SnowWalk.name_is_snow("snow") and SnowWalk.name_is_snow("glacial_ice") and not SnowWalk.name_is_snow("loam") and not SnowWalk.name_is_snow("rock"), "by name too")
	check(SnowWalk.pace_mult(false, false) == 1.0 and SnowWalk.effort_mult(false, true) == 1.0, "off snow nothing changes, shod or not")
	check(is_equal_approx(SnowWalk.pace_mult(true, false), 0.6) and is_equal_approx(SnowWalk.pace_mult(true, true), 0.9), "the pace on snow, bare and shod")
	check(is_equal_approx(SnowWalk.effort_mult(true, false), 1.4) and is_equal_approx(SnowWalk.effort_mult(true, true), 1.1), "the work on snow, bare and shod")

	var dir: String = "user://test_snow_walk"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, _t): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "snow-key-00000001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))

	if not items.table.has_id("snowshoes"):
		var row: Dictionary = {"id": "snowshoes", "number": 99994, "name": "Snowshoes", "kind": "clothing", "slot": "feet", "snow_walk": true, "stack": 1, "unstackable": true}
		items.table._by_id["snowshoes"] = row
		items.table._by_number[99994] = row

	var shoes: int = items.table.number_of("snowshoes")
	check(SnowWalk.shod([0, shoes, 0], items.table) and not SnowWalk.shod([0, 0], items.table), "a worn item with snow_walk is snowshoes")
	var on_loam: float = _effort_after_step(items, "loam")
	var on_snow: float = _effort_after_step(items, "snow")
	var on_ice: float = _effort_after_step(items, "glacial_ice")
	check(on_loam > 0.0 and absf(on_snow / on_loam - 1.4) < 0.01 and absf(on_ice / on_loam - 1.4) < 0.01, "the server's exertion on snow and glacial ice is 1.4 times the loam's (%.3f, %.3f against %.3f)" % [on_snow, on_ice, on_loam])
	items.ground_material = Callable()
	items._snow_memo.clear()
	check(not items._on_snow(1, Vector3.ZERO), "with no ground hook nothing is snow")
	print("snow walk tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
