extends SceneTree

# The lumber route. Mission 001 phases 2a and 2b (master s2.3, s2.7) replaced the stone-wedge route described next (kept as history): Planks and
# Hardwood boards now start at the Iron - Saw or the Sawmill. Old route (guide finding F-05, FLINT_ORE_SPEC.md; Tyler 31 Oct 2026):
# stone wedge (2 stones, 1 stick, by hand) -> workbench kit (20 sticks, 6 twine, 4 stones, by hand) -> place the workbench -> a log at the workbench with the wedge in the pack
# gives 2 lumber ("Hand-split planks", recipe lumber_wedge); rough planks are retired (recipe audit, 10 Nov 2026), so the workbench makes none. Before the ingredient groups (F-16) the log
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

	for s in range(400):
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
	items.admin_mode_on = func(_p): return false
	# Mission 001 phase 2b (master s2.3 item 6, s2.7 item 1): no stone wedges and no hand-split planks; Planks and Hardwood boards start at the first
	# Iron - Saw (made at the burning Smithy) or the Sawmill. The wedge recipes are retired, so asking for them makes nothing.
	give("stone", 8)
	give("stick", 30)
	items.inventory_of(1).add(items.table.number_of("log_spruce"), 2)
	craft("stone_wedge", 1)
	check(count("stone_wedge") == 0 and count("stone") == 8, "the Stone - Wedge is retired: no wedge is made")
	craft("lumber_wedge", 1)
	check(count("lumber") == 0 and count("log_spruce") == 2, "hand-split planks are retired: no Planks before a saw, the logs are kept")
	var saw_recipe: Dictionary = {}

	for k in items.recipes.numbers():
		if str(items.recipes.recipe(int(k)).get("id", "")) == "hand_saw":
			saw_recipe = items.recipes.recipe(int(k))

	var saw_needs: Array = saw_recipe.get("needs", []).map(func(nd): return items.table.id_of(int(nd[0])))
	check(str(saw_recipe.get("station", "")) == "brick_forge" and saw_needs.has("iron_ingot") and not saw_needs.has("saw_blade"), "the Iron - Saw is made at the Smithy from iron and wood, with no Saw blade (%s)" % str(saw_needs))
	items.inventory_of(1).remove(items.table.number_of("log_spruce"), 2)

	# Mission 001 phase 2a (master s2.3, [D4]): a hand saw turns a softwood or plain log into 6 Planks and a hardwood log into 4 Hardwood boards,
	# never the other way round; the sawmill gives the same (validate_items checks the balance row), the hand saw is slower.
	items.inventory_of(1).remove(items.table.number_of("lumber"), count("lumber"))
	items.inventory_of(1).remove(items.table.number_of("log_spruce"), count("log_spruce"))
	give("hand_saw", 1)
	items.inventory_of(1).add(items.table.number_of("log_oak"), 1)
	craft("lumber_by_hand", 1)
	check(count("lumber") == 0 and count("log_oak") == 1, "an oak log makes no Planks (%d Planks)" % count("lumber"))
	craft("hardwood_board_by_hand", 1)
	check(count("hardwood_board") == 4 and count("log_oak") == 0 and count("lumber") == 0, "an oak log saws into 4 Hardwood boards and no Planks (%d boards)" % count("hardwood_board"))
	items.inventory_of(1).add(items.table.number_of("log_spruce"), 1)
	items.inventory_of(1).add(items.table.number_of("log"), 1)
	craft("hardwood_board_by_hand", 1)
	check(count("hardwood_board") == 4 and count("log_spruce") == 1 and count("log") == 1, "softwood and plain logs make no Hardwood boards")
	craft("lumber_by_hand", 2)
	check(count("lumber") == 12 and count("log_spruce") == 0 and count("log") == 0, "a spruce log and a plain log saw into 6 Planks each (%d Planks)" % count("lumber"))
	print("lumber route: %d failures" % failures)
	items._finish_writer()
	quit(1 if failures > 0 else 0)
