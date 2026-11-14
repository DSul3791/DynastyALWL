extends SceneTree

# The store half of the real-server reset check (BLOCKER-001; docs/ai-team/missions/B001/RESULTS.md). Never point it at a live save.
#   --store=DIR --seed   lays a test world's player-made state into DIR: two drops (one 3 km out), a foundation, wall, door, floor, bed,
#                        workbench, a chest with stones in it, a campfire, a tilled bed with a crop, a far chest, three terrain edits and a
#                        character with a full pack and progression
#   --store=DIR --check  reads DIR as a restarted server does and prints RESET_STORE_OK when none of that came back and the character did
#   godot --headless --path . --script res://src/worldgen/tools/reset_world_store.gd -- --store=DIR --seed|--check

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const GroundOps := preload("res://src/stream/ground_ops.gd")
const FloraLayout := preload("res://src/worldgen/runtime/flora_layout.gd")

const KEY := "resetworldstore01"


func _items(dir: String):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, _t): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	return items


func _init() -> void:
	var dir: String = ""
	var seed_it: bool = false

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--store="):
			dir = argument.trim_prefix("--store=")
		elif argument == "--seed":
			seed_it = true

	if dir == "" or dir.begins_with("user://server_store"):
		print("reset_world_store: give a throwaway --store=DIR")
		quit(2)
		return

	DirAccess.make_dir_recursive_absolute(dir)
	var ops = GroundOps.new()
	ops.open(dir + "/digs.dat")

	if seed_it:
		var items = _items(dir)
		items.peer_connected_hello(1, KEY)
		var stone: int = items.table.number_of("stone")
		var stick: int = items.table.number_of("stick")
		items.inventory_of(1).add(stone, 30)
		items.inventory_of(1).add(stick, 12)
		items._characters[KEY]["skills"] = {"digging": 1234.0}
		items._characters[KEY]["purse"] = {"coin_copper": 55}
		items.drop_in_world(stone, 5, Vector3(1.0, 10.0, 1.0))
		items.drop_in_world(stick, 3, Vector3(3000.0, 10.0, 3000.0))
		var placed: int = 0

		for spec in ["wood_foundation@20,20,0", "wall_section@24,20,0", "doorway_section@28,20,0", "floor_section@32,20,0", "rough_bed@36,20,0", "workbench@40,20,0", "chest@44,20,0", "campfire@48,20,0,lit", "tilled_bed@52,20,0", "chest@-3000,-3000,0"]:
			var id: int = items.dev_place(spec)

			if id > 0:
				placed += 1

			if spec.begins_with("chest@44"):
				items._chests[int(items._items[id]["struct"]["uid"])].add(stone, 4)

		items.drop_world_made(stone, 3, Vector3(-1500.0, 10.0, 800.0), 604800.0)   # a den pile the server laid: kept
		items._taken[5151] = true   # used-up natural content: restored
		items._boulder_left[4343] = 12
		var marks: FileAccess = FileAccess.open(dir + "/flora_removed.json", FileAccess.WRITE)   # a felled tree and a cleared plant
		marks.store_string(JSON.stringify({"layout": FloraLayout.VERSION, "3,4": [70000, 70001]}))
		marks.close()
		items._crops["b1040,400"] = {"crop": "barley", "sown": 1, "age": 1, "wet": 0, "day": 1, "compost": false}
		items._dirty = true
		items.save()
		items._finish_writer()
		ops.add(GroundOps.KIND_DIG, 0, Vector3(5.0, 9.0, 5.0), 2.0)
		ops.add(GroundOps.KIND_FILL, 5, Vector3(800.0, 11.0, -600.0), 1.5)
		ops.add(GroundOps.KIND_DIG, 0, Vector3(-2400.0, 9.5, 1900.0), 1.0)
		print("RESET_STORE_SEEDED rows=%d placed=%d edits=%d" % [items.world_item_count(), placed, ops.count])
		quit(0)
		return

	var again = _items(dir)
	var rows: int = again._items.values().filter(func(it): return not it.has("world")).size()
	var world: int = again._items.values().filter(func(it): return it.has("world")).size()
	var flora_marks: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + "/flora_removed.json"))
	var felled: int = (flora_marks as Dictionary).size() - 1 if typeof(flora_marks) == TYPE_DICTIONARY else -1   # chunk keys besides "layout"
	var chests: int = again._chests.size()
	again.peer_connected_hello(1, KEY)
	var inv = again.inventory_of(1)
	var row: Dictionary = again._characters.get(KEY, {})
	var kept: bool = inv.count_of(again.table.number_of("stone")) == 30 and inv.count_of(again.table.number_of("stick")) == 12 and float((row.get("skills", {}) as Dictionary).get("digging", 0.0)) == 1234.0 and row.get("purse", {}) == {"coin_copper": 55}
	var ok: bool = rows == 0 and world == 1 and felled == 0 and again._taken.is_empty() and again._boulder_left.is_empty() and chests == 0 and again._crops.is_empty() and ops.count == 0 and kept
	print("%s rows=%d world_piles=%d felled_chunks=%d taken=%d chests=%d crops=%d edits=%d character_kept=%s" % ["RESET_STORE_OK" if ok else "RESET_STORE_BAD", rows, world, felled, again._taken.size(), chests, again._crops.size(), ops.count, str(kept)])
	quit(0 if ok else 1)
