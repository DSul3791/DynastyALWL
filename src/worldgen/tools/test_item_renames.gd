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
		var pair: Variant = parsed["renames"][old_id]   # "new id", or ["new id", count] (a counted rename)
		var pair_id: String = str(pair[0]) if typeof(pair) == TYPE_ARRAY else str(pair)
		check(table.has_id(old_id) and table.has_id(pair_id), "%s -> %s: both ids are items" % [old_id, pair_id])

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

	# The wood merge (TREE_WOOD_TOOLS_DESIGN.md): soft firewood and blocks load 1:1, a large block loads as 4 Wooden blocks (renames.json [id, count]).
	var fire_n: int = table.number_of("firewood")
	var soft_fire_n: int = table.number_of("firewood_soft")
	var block_n: int = table.number_of("wooden_block")
	var soft_block_n: int = table.number_of("wooden_block_soft")
	var large_n: int = table.number_of("wooden_block_large")
	var soft_large_n: int = table.number_of("wooden_block_soft_large")
	check(table.current_number(soft_fire_n) == fire_n and table.current_number(soft_block_n) == block_n, "soft firewood and the soft block stand for Firewood and the Wooden block")
	check(table.current_number(large_n) == block_n and table.current_number(soft_large_n) == block_n, "both large blocks stand for the Wooden block")
	check(table.rename_count(large_n) == 4 and table.rename_count(soft_large_n) == 4, "a large block stands for 4 Wooden blocks (%d, %d)" % [table.rename_count(large_n), table.rename_count(soft_large_n)])
	check(table.rename_count(soft_fire_n) == 1 and table.rename_count(soft_block_n) == 1 and table.rename_count(block_n) == 1 and table.rename_count(old_n) == 1, "a plain rename stands for one, and so does a number that was never renamed")
	var wood_inv = InventoryScript.new(table)
	wood_inv.from_json_array([[large_n, 3], [soft_fire_n, 5], [soft_block_n, 2], [soft_large_n, 1, 0]])
	check(wood_inv.count_of(block_n) == 12 + 2 + 4 and wood_inv.count_of(large_n) == 0 and wood_inv.count_of(soft_block_n) == 0, "a pack of 3 large blocks, 2 soft blocks and 1 large softwood block loads as 18 Wooden blocks (%d)" % wood_inv.count_of(block_n))
	check(wood_inv.count_of(fire_n) == 5 and wood_inv.count_of(soft_fire_n) == 0, "5 soft firewood load as 5 Firewood (%d)" % wood_inv.count_of(fire_n))

	# A whole save: pack (its slot 0 is hotbar key 1), chest, ground item and worn legs slot.
	var dir: String = "user://item_renames"
	var key: String = "rename-key-aaa01"
	var legs: int = 2
	var worn: Array = [0, 0, old_n, 0, 0, 0]
	fresh(dir)
	put(dir, "inventories.json", {"version": 1, "inventories": {key: [[old_n, 1, 5]]}})
	put(dir, "chests.json", {"version": 1, "next_uid": 10, "chests": {"7": [[old_n, 1, 0]]}})
	put(dir, "world_items.json", {"version": 1, "no_kits": true, "next_id": 5, "items": [[old_n, 1, 10.0, 10.0, 10.0, 600.0], [large_n, 2, 14.0, 10.0, 14.0, 600.0]], "taken": [], "picked": {}})
	put(dir, "craft_queues.json", {"version": 1, "players": {key: {"entries": [[15, 1, [[large_n, 1, [[large_n, {}, 0, 1]]]], [], 0]], "elapsed": 0.0}}})   # a queued craft that holds a large block it took
	put(dir, "characters.json", {"version": 1, "players": {key: {"worn": worn}}})
	var items = boot(dir)
	var queued: Array = items._craft_queues.get(key, {}).get("entries", [])
	var queued_need: Array = queued[0][2][0] if not queued.is_empty() and (queued[0][2] as Array).size() > 0 else []
	check(queued_need.size() > 2 and int(queued_need[0]) == block_n and int(queued_need[1]) == 4 and int(queued_need[2][0][0]) == block_n and int(queued_need[2][0][3]) == 4, "a queued craft's large block loads as 4 Wooden blocks, in the need and in the units it took (%s)" % str(queued_need))
	items.peer_connected_hello(1, key)
	var pack = items.inventory_of(1)
	check(pack.count_of(new_n) == 1 and pack.count_of(old_n) == 0, "the pack holds trousers, not leggings")
	check(items._chests.has(7) and items._chests[7].count_of(new_n) == 1, "the chest holds trousers")
	var ground: Array = []

	for id in items._items:
		ground.append(int(items._items[id]["number"]))

	check(ground.has(new_n) and not ground.has(old_n), "the ground item is trousers (%s)" % str(ground))
	var ground_blocks: int = 0

	for id in items._items:
		if int(items._items[id]["number"]) == block_n:
			ground_blocks += int(items._items[id]["count"])

	check(ground_blocks == 8 and not ground.has(large_n), "2 large blocks lying on the ground load as 8 Wooden blocks (%d)" % ground_blocks)
	check(int(items.worn_of(1)[legs]) == new_n, "the worn legs slot is trousers (%s)" % str(items.worn_of(1)))
	check(pack.numbers[0] == new_n and pack.on_hotbar(0), "hotbar key 1 (pack slot 0) holds trousers (%d)" % pack.numbers[0])

	if failures == 0:
		print("item renames: all checks passed")

	quit(1 if failures > 0 else 0)
