extends SceneTree

# Wood without iron (guide finding F-05, FLINT_ORE_SPEC.md; Tyler 31 Oct 2026): the route a player can really walk from bare hands to lumber and planks:
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
	give("stone", 8)   # the wedge (2 stones) and the bench kit (pace pass: 20 sticks, 6 twine, 4 stones, 60 s)
	give("stick", 30)
	give("twine", 8)
	craft("stone_wedge", 1)
	check(count("stone_wedge") == 1 and count("stone") == 6, "a stone wedge from 2 stones and a stick, by hand")
	for spent in [["stone", 4], ["stick", 20], ["twine", 6]]:   # the bench kit used to take these; the pack stays as light as it was so the lumber is not left on the ground by the carry limit
		items.inventory_of(1).remove(items.table.number_of(str(spent[0])), int(spent[1]))
	items.inventory_of(1).add(items.table.number_of("log_spruce"), 3)   # logs in the pack: the real carry (shoulder, ground) is test_logs_carry
	craft("lumber_wedge", 1)
	check(count("lumber") == 0 and count("log_spruce") == 3, "no workbench near: no lumber, the log is kept")
	items.place_piece(1, "workbench_kit", Vector3(2.0, 10.0, 0.0))
	craft("lumber_wedge", 1)
	check(count("lumber") == 2 and count("log_spruce") == 2 and count("stone_wedge") == 1, "at the workbench, a log and the wedge give 2 lumber; the wedge is kept (%d lumber, %d logs left)" % [count("lumber"), count("log_spruce")])
	craft("rough_plank", 1)
	check(count("rough_plank") == 0 and count("log_spruce") == 2, "rough planks are retired: the workbench makes none, the log is kept (%d)" % count("rough_plank"))
	items.inventory_of(1).remove(items.table.number_of("stone_wedge"), 1)
	craft("lumber_wedge", 1)
	check(count("lumber") == 2 and count("log_spruce") == 2, "without the wedge the wedge recipe makes nothing")

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
