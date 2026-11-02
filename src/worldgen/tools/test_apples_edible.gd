extends SceneTree

# Apples are food (Sal, 2026-10-31, Dave: crab apples must be edible): a crab apple, a wild apple and an orchard apple each raise the stomach when eaten, and the
# crab apple (small, sour) gives less than an eating apple.
#   godot --headless --path . --script res://src/worldgen/tools/test_apples_edible.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const VitalsRules := preload("res://src/shared/vitals_rules.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var dir: String = "user://test_apples_edible"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, _t): pass
	items.send_sick = func(_p, _h): pass
	items.send_thought = func(_p, _i, _t, _k): pass
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "apple-edible-01")
	items.report_position(1, Vector3(10.0, 0.0, 10.0))
	items._eat_cfg = {"none": true}
	var gains: Dictionary = {}

	for id in ["crab_apples", "wild_apples", "apple_early"]:
		items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of(id), 0, 2, Vector3.ZERO)
		check(VitalsRules.edible(id, items._vitals_cfg), "%s is food in vitals.json" % id)
		var v: Dictionary = items.vitals_of(1)
		v["fed"] = 1000.0
		items._last_eat.clear()
		items.action(1, Net.ACT_EAT, items.inventory_of(1).numbers.find(items.table.number_of(id)), 0, 0, Vector3.ZERO)
		gains[id] = float(v["fed"]) - 1000.0
		check(gains[id] > 0.0, "eating one %s raises the stomach (%d)" % [id, int(gains[id])])
		check(items.inventory_of(1).count_of(items.table.number_of(id)) == 1, "and uses up one %s" % id)

	check(gains["crab_apples"] < gains["wild_apples"] and gains["wild_apples"] < gains["apple_early"], "a crab apple feeds less than a wild apple, and that less than an orchard apple (%s)" % str(gains))
	print("apples edible: %d failures" % failures)
	quit(1 if failures > 0 else 0)
