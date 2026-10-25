extends SceneTree

# "Play as a new player" (ACT_NEW_PLAYER) and the open recipe list (data/items/open_recipes.json).
#   godot --headless --path . --script res://src/worldgen/tools/test_new_player.gd

const Net := preload("res://src/stream/terrain_net.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const RecipeScript := preload("res://src/shared/recipe_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")

var failures: int = 0
var said: Array = []


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(dir: String):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, text): said.append(text)
	items.admin_ok = func(p: int) -> bool: return p == 1
	items.setup(ItemTableScript.load_default(), dir)
	return items


func _init() -> void:
	var dir: String = "user://test_new_player"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = make(dir)
	items.peer_connected_hello(1, "new-key-0000001")
	items.peer_connected_hello(2, "new-key-0000002")
	items.report_position(1, Vector3(10.0, 0.0, 10.0))
	var pack = items._inventories["new-key-0000001"]
	pack.add(items.table.number_of("stick"), 5)
	items._vitals["new-key-0000001"]["fed"] = 100.0
	items.action(1, Net.ACT_NEW_PLAYER, 0, 0, 0, Vector3.ZERO)
	check(items._inventories["new-key-0000001"].is_empty(), "the pack is empty")
	check(float(items._vitals["new-key-0000001"]["fed"]) > 1000.0, "vitals are fresh")
	check(items._admin_mode_off.has(1) and not items.admin_mode_on.call(1), "Admin mode is off")
	check(bool(items._characters["new-key-0000001"]["new_player"]), "the character is flagged")
	check(items.worn_of(1).all(func(n): return n == 0), "nothing is worn")

	items.action(2, Net.ACT_NEW_PLAYER, 0, 0, 0, Vector3.ZERO)
	check(not bool(items._characters["new-key-0000002"].get("new_player", false)), "a non-admin cannot")

	items.action(1, Net.ACT_ADMIN_MODE, 1, 0, 0, Vector3.ZERO)
	check(items.admin_mode_on.call(1), "an admin can switch Admin mode back on")
	items.peer_left(1)
	items._save_characters()
	var again = make(dir)
	again._load_characters()
	again.peer_connected_hello(1, "new-key-0000001")
	check(again._admin_mode_off.has(1), "login of a flagged character starts with Admin mode off")

	var table = ItemTableScript.load_default()
	var recipes = RecipeScript.load_default(table)
	check(recipes.open_unknown.is_empty(), "every id in open_recipes.json is a recipe: %s" % str(recipes.open_unknown))
	var opened: bool = false

	for number in recipes.numbers():
		var row: Dictionary = recipes.recipe(number)

		if str(row.get("id", "")) == "foundation_section_kit":
			opened = bool(row.get("known", false))

	check(opened, "foundation_section_kit is known from the start")

	if failures == 0:
		print("Test done: all pass")
	else:
		print("Test done: ", failures, " fail")

	quit(1 if failures > 0 else 0)
