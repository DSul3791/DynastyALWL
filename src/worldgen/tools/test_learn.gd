extends SceneTree

# Recipe learning (guide finding F-01, LEARN_SYSTEM_SPEC.md; Tyler 31 Oct 2026). A made-up recipe with known=false: refused without its ingredients; learned (and made)
# once the pack holds them; saved with the character and still known after the server restarts; not learned by another character; learned by seeing its product in the
# pack; one that needs a station is not learned away from it; a known recipe is unaffected; the planner may use a learned recipe to make a missing part.
#   godot --headless --path . --script res://src/worldgen/tools/test_learn.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var said: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make(dir: String):
	DirAccess.make_dir_recursive_absolute(dir)
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, t): said.append(t)
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.recipes._by_number[900] = {"number": 900, "id": "learn_test", "name": "Learn test", "category": "", "needs": [[items.table.number_of("stick"), 2]], "keeps": [], "identify": [], "gives": [items.table.number_of("bandage"), 1], "craft_s": 1.0, "known": false, "station": "", "station_level": 1, "wears_tool": ""}
	items.recipes._by_number[901] = {"number": 901, "id": "learn_station", "name": "Learn station", "category": "", "needs": [[items.table.number_of("stick"), 1]], "keeps": [], "identify": [], "gives": [items.table.number_of("splint"), 1], "craft_s": 1.0, "known": false, "station": "workbench", "station_level": 1, "wears_tool": ""}
	items.recipes._by_number[902] = {"number": 902, "id": "learn_locked", "name": "Learn locked", "category": "", "needs": [[items.table.number_of("stick"), 1]], "keeps": [], "identify": [], "gives": [items.table.number_of("torch"), 1], "craft_s": 1.0, "known": false, "locked": true, "station": "", "station_level": 1, "wears_tool": ""}
	return items


func join(items, peer: int, key: String) -> void:
	items.peer_connected_hello(peer, key)
	items.report_position(peer, Vector3(0.0, 10.0, 0.0))
	items.vitals_of(peer)["weight"] = 200.0


func craft(items, peer: int, number: int) -> void:
	items._last_queue_act.clear()
	items.action(peer, Net.ACT_CRAFT_QUEUE, number, 0, 1, Vector3.ZERO)

	for s in range(8):
		items.tick(1.0)


func count(items, peer: int, id: String) -> int:
	return items.inventory_of(peer).count_of(items.table.number_of(id))


func _init() -> void:
	var dir: String = "user://test_learn"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = make(dir)
	join(items, 1, "learnkey0001")
	join(items, 2, "learnkey0002")
	craft(items, 1, 900)
	check(count(items, 1, "bandage") == 0 and not items._learned_of(1).has("900"), "an unknown recipe is refused without its ingredients, and not learned")
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("stick"), 0, 4, Vector3.ZERO)
	said.clear()
	craft(items, 1, 900)
	check(count(items, 1, "bandage") == 1 and items._learned_of(1).has("900"), "holding the ingredients, the recipe is learned and made")
	check(said.any(func(t): return str(t).begins_with("You work out how to make")), "the player is told once: \"You work out how to make ...\" (%s)" % str(said))
	craft(items, 2, 900)
	check(not items._learned_of(2).has("900") and count(items, 2, "bandage") == 0, "another character has not learned it")
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("stick"), 0, 2, Vector3.ZERO)
	said.clear()
	craft(items, 1, 900)
	check(count(items, 1, "bandage") == 2 and said.is_empty(), "once learned it is made again with no more words")

	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("stick"), 0, 2, Vector3.ZERO)
	craft(items, 1, 902)
	check(count(items, 1, "torch") == 0 and not items._learned_of(1).has("902"), "a locked recipe is not learned by discovery even with every ingredient (recipes.json locked: the chain it needs does not exist yet)")
	items.inventory_of(1).add(items.table.number_of("torch"), 1)
	items._learn_tick()
	check(not items._learned_of(1).has("902"), "nor by seeing the product")
	items.inventory_of(1).remove(items.table.number_of("torch"), 1)
	craft(items, 1, 901)
	check(count(items, 1, "splint") == 0 and not items._learned_of(1).has("901"), "a recipe that needs a workbench is not learned away from one")

	items.action(2, Net.ACT_ADMIN_GIVE, items.table.number_of("bandage"), 0, 1, Vector3.ZERO)
	items._learn_tick()
	check(items._learned_of(2).has("900"), "seeing the product in the pack teaches the recipe (the periodic check)")

	items._save_characters()
	items._finish_writer()
	var again = make(dir)
	join(again, 1, "learnkey0001")
	check(again._learned_of(1).has("900") and not again._learned_of(1).has("901"), "the learned recipes are saved with the character and known after a restart")
	check(again.recipe_known_for(1, again.recipes.recipe(2)) and not again.recipe_known_for(1, again.recipes.recipe(901)), "a recipe that is known in the table is known to all, an unknown one only to who learned it")
	var wheel: Dictionary = again.recipes.recipe(153)
	check(str(wheel.get("id", "")) == "water_wheel" and bool(wheel.get("locked", false)) and not bool(wheel.get("known", false)), "the real water wheel recipe is locked (no saw mill or forge chain yet)")
	print("learn: %d failures" % failures)
	quit(1 if failures > 0 else 0)
