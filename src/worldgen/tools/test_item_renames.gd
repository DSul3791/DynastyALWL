extends SceneTree

# Item renames (data/items/renames.json): a retired item in an old save loads as the item that replaced it, in packs, chests, on the
# ground, in worn slots and on hotbar keys (Hide leggings -> Hide trousers, Jamie's merge). A pair counts only once the old row is retired.
#   godot --headless --path . --script res://src/worldgen/tools/test_item_renames.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")

var failures: int = 0
var table


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func fresh(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)


func put(dir: String, name: String, data: Variant) -> void:
	var f: FileAccess = FileAccess.open(dir + "/" + name, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()


func boot(dir: String):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.ground_height = func(_x, _z): return 10.0
	items.game_seconds = func(): return 1000.0
	items.setup(table, dir)
	return items


func _init() -> void:
	table = ItemTableScript.load_default()
	var old_n: int = table.number_of("hide_leggings")
	var new_n: int = table.number_of("hide_trousers")
	check(old_n > 0 and new_n > 0 and old_n != new_n, "both rows exist (%d, %d)" % [old_n, new_n])

	# Every pair in the file names two real items.
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ItemTableScript.RENAMES_PATH))
	check(typeof(parsed) == TYPE_DICTIONARY and typeof(parsed.get("renames", null)) == TYPE_DICTIONARY, "renames.json has a renames table")

	for old_id in parsed.get("renames", {}):
		check(table.has_id(old_id) and table.has_id(str(parsed["renames"][old_id])), "%s -> %s: both ids are items" % [old_id, str(parsed["renames"][old_id])])

	# Until the old row is retired, nothing changes.
	var retired_now: bool = bool(table.entry("hide_leggings").get("retired", false))

	if not retired_now:
		check(table.current_number(old_n) == old_n, "a row that is not retired keeps its number")
		table.entry("hide_leggings")["retired"] = true   # the same dictionary the number map holds
		table.load_renames(ItemTableScript.RENAMES_PATH)

	check(table.current_number(old_n) == new_n, "a retired Hide leggings stands for Hide trousers (%d)" % table.current_number(old_n))
	check(table.current_number(new_n) == new_n and table.current_number(0) == 0, "other numbers pass through")

	# Pack bytes: the slot keeps its count and wear.
	var inv = InventoryScript.new(table)
	inv.from_json_array([[old_n, 1, 3]])
	check(inv.numbers[0] == new_n and inv.counts[0] == 1 and inv.wear[0] == 3, "a pack slot loads as trousers with its wear (%d, %d)" % [inv.numbers[0], inv.wear[0]])

	# A whole save: pack, chest, ground item, worn legs slot and a hotbar key.
	var dir: String = "user://item_renames"
	var key: String = "rename-key-aaa01"
	var legs: int = 2
	var worn: Array = [0, 0, old_n, 0, 0, 0]
	fresh(dir)
	put(dir, "inventories.json", {"version": 1, "inventories": {key: [[old_n, 1, 5]]}})
	put(dir, "chests.json", {"version": 1, "next_uid": 10, "chests": {"7": [[old_n, 1, 0]]}})
	put(dir, "world_items.json", {"version": 1, "no_kits": true, "next_id": 5, "items": [[old_n, 1, 10.0, 10.0, 10.0, 600.0]], "taken": [], "picked": {}})
	put(dir, "characters.json", {"version": 1, "players": {key: {"worn": worn, "hotbar": [old_n, 0, 0, 0, 0, 0, 0, 0, 0, 0]}}})
	var items = boot(dir)
	items.peer_connected_hello(1, key)
	var pack = items.inventory_of(1)
	check(pack.count_of(new_n) == 1 and pack.count_of(old_n) == 0, "the pack holds trousers, not leggings")
	check(items._chests.has(7) and items._chests[7].count_of(new_n) == 1, "the chest holds trousers")
	var ground: Array = []

	for id in items._items:
		ground.append(int(items._items[id]["number"]))

	check(ground.has(new_n) and not ground.has(old_n), "the ground item is trousers (%s)" % str(ground))
	check(int(items.worn_of(1)[legs]) == new_n, "the worn legs slot is trousers (%s)" % str(items.worn_of(1)))
	check(pack.hotbar.has(new_n) and not pack.hotbar.has(old_n), "the hotbar key points at trousers (%s)" % str(pack.hotbar))

	if failures == 0:
		print("item renames: all checks passed")

	quit(1 if failures > 0 else 0)
