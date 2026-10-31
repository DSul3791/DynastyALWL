extends SceneTree

# Wood without iron (guide finding F-05, FLINT_ORE_SPEC.md; Tyler 31 Oct 2026): the route a player can really walk from bare hands to lumber and planks:
# stone wedge (2 stones, 1 stick, by hand) -> workbench kit (12 sticks, 3 twine, by hand) -> place the workbench -> a log at the workbench with the wedge in the pack
# gives 2 lumber ("Rough planks", recipe lumber_wedge); and 1 log at the workbench gives rough planks (recipe rough_plank). Before the ingredient groups (F-16) the log
# step could never be filled. The wedge is kept (not used up). Without the workbench near, nothing is made; without the wedge, no lumber from the wedge recipe.
#   godot --headless --path . --script res://src/worldgen/tools/test_lumber_route.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var items


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func count(id: String) -> int:
	return items.inventory_of(1).count_of(items.table.number_of(id))


func give(id: String, n: int) -> void:
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of(id), 0, n, Vector3.ZERO)


func craft(recipe_id: String, n: int) -> void:
	var number: int = -1

	for k in items.recipes.numbers():
		if str(items.recipes.recipe(int(k)).get("id", "")) == recipe_id:
			number = int(k)

	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, number, 0, n, Vector3.ZERO)

	for s in range(120):
		items.tick(1.0)


func _init() -> void:
	var dir: String = "user://test_lumber_route"
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
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "lumber000001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items.vitals_of(1)["weight"] = 2000.0
	items._admin_mode_off[1] = true   # play by the rules: no free crafting
	items.admin_mode_on = func(_p): return false
	give("stone", 2)
	give("stick", 14)
	give("twine", 3)
	craft("stone_wedge", 1)
	check(count("stone_wedge") == 1 and count("stone") == 0, "a stone wedge from 2 stones and a stick, by hand")
	craft("workbench_kit", 1)
	check(count("workbench_kit") == 1, "a workbench kit from 12 sticks and 3 twine, by hand")
	give("log_oak", 3)
	craft("lumber_wedge", 1)
	check(count("lumber") == 0 and count("log_oak") == 3, "no workbench near: no lumber, the log is kept")
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(items.table.number_of("workbench_kit")), 0, 0, Vector3(2.0, 10.0, 0.0))
	craft("lumber_wedge", 1)
	check(count("lumber") == 2 and count("log_oak") == 2 and count("stone_wedge") == 1, "at the workbench, a log and the wedge give 2 lumber; the wedge is kept (%d lumber, %d logs left)" % [count("lumber"), count("log_oak")])
	craft("rough_plank", 1)
	check(count("rough_plank") == 4 and count("log_oak") == 1, "at the workbench, a log gives 4 rough planks (%d)" % count("rough_plank"))
	items.inventory_of(1).remove(items.table.number_of("stone_wedge"), 1)
	craft("lumber_wedge", 1)
	check(count("lumber") == 2 and count("log_oak") == 1, "without the wedge the wedge recipe makes nothing")
	print("lumber route: %d failures" % failures)
	items._finish_writer()
	quit(1 if failures > 0 else 0)
