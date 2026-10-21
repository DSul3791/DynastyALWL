extends SceneTree

# Save compatibility (Radar, 2026-10-21): hand-written files in the formats of older protocol eras (14 tool wear, 19 fire states,
# 22 crafting queue and chests, 24 thirst, 26 fitness, 37 skills before the web, 44 station tiers, 48+ remains) must still load into
# today's server with nothing lost and neutral defaults for what they never had, and a file from the future is set aside, not eaten.
#   godot --headless --path . --script res://src/worldgen/tools/test_save_compat.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")

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


func fires(items) -> Array:
	var states: Array = []

	for id in items._items:
		if items._items[id].has("fire"):
			states.append(int(items._items[id]["fire"]["state"]))

	states.sort()
	return states


func _init() -> void:
	table = ItemTableScript.load_default()
	var stone: int = table.number_of("stone")
	var stick: int = table.number_of("stick")
	var campfire: int = table.number_of("campfire")
	var chest: int = table.number_of("chest")
	var dir: String = "user://save_compat"

	# Era 14 and 19: two-field slots, six-column world rows, the retired out-fire state 2, later fire states 8 and 9.
	fresh(dir)
	put(dir, "inventories.json", {"version": 1, "inventories": {"compat-key-aaa01": [[stone, 7], [stick, 3]]}})
	put(dir, "world_items.json", {"version": 1, "next_id": 40, "items": [
		[stone, 4, 10.0, 10.0, 10.0, 600.0],
		[campfire, 1, 11.0, 10.0, 11.0, 1.0e9, 2, 30.0],
		[campfire, 1, 12.0, 10.0, 12.0, 1.0e9, 2, 0.0],
		[campfire, 1, 13.0, 10.0, 13.0, 1.0e9, 8, 0.0, 0],
		[campfire, 1, 14.0, 10.0, 14.0, 1.0e9, 9, 20.0, 0],
		[campfire, 1, 15.0, 10.0, 15.0, 1.0e9, 1, 200.0, 0]], "taken": [], "picked": {}})
	var items = boot(dir)
	items.peer_connected_hello(1, "compat-key-aaa01")
	var inv = items.inventory_of(1)
	check(inv.count_of(stone) == 7 and inv.count_of(stick) == 3, "era 14: two-field slots load with zero wear (%d stone)" % inv.count_of(stone))
	check(items.world_item_count() == 6, "era 14/19: all six world rows load (%d)" % items.world_item_count())
	check(fires(items) == [1, 8, 8, 9, 9], "old out-fire state 2 maps to 9 with wood and 8 without (%s)" % str(fires(items)))

	# Era 22: crafting queue and chests (with the chest structure row that owns the uid).
	fresh(dir)
	put(dir, "world_items.json", {"version": 1, "next_id": 5, "items": [[chest, 1, 20.0, 10.0, 20.0, 1.0e9, 6, 90.0, 0, "chest", 2]], "taken": [], "picked": {}})
	put(dir, "chests.json", {"version": 1, "next_uid": 3, "chests": {"2": [[stone, 12, 0]]}})
	put(dir, "craft_queues.json", {"version": 1, "players": {"compat-key-aaa01": {"entries": [[1, 2]], "elapsed": 0.5}}})
	items = boot(dir)
	check(items.world_item_count() == 1 and items._chests.has(2) and items._chests[2].count_of(stone) == 12, "era 22: the chest and its contents load")
	check(items._craft_queues.has("compat-key-aaa01") and items._craft_queues["compat-key-aaa01"]["entries"].size() == 1, "era 22: the crafting queue loads (entry without needs)")

	# Era 24 to 37: vitals without thirst, warmth, energy or sickness; characters with luck only, then fitness, then old skill records.
	fresh(dir)
	put(dir, "vitals.json", {"version": 1, "players": {"compat-key-aaa01": {"fed": 1200.0, "weight": 70.0, "health": 80.0}}})
	put(dir, "characters.json", {"version": 1, "players": {"compat-key-aaa01": {"luck": 5}, "compat-key-bbb02": {"luck": -2, "fitness": -3}, "compat-key-ccc03": {"luck": 0, "skills": {"mining": {"p": 100.0, "peak": 100.0, "trained": 0.0}}}}})
	items = boot(dir)
	var v: Dictionary = items._vitals.get("compat-key-aaa01", {})
	check(not v.is_empty() and absf(float(v["fed"]) - 1200.0) < 0.1 and float(v["wet"]) > 0.0 and float(v["warmth"]) == 100.0 and float(v["energy"]) == 100.0 and float(v["sick"]) == 0.0, "era 24: older vitals start full where they never had a field (%s)" % str(v))
	check(int(items._characters["compat-key-aaa01"]["luck"]) == 5 and int(items._characters["compat-key-bbb02"]["fitness"]) == -3, "era 26: luck and fitness survive")
	check(int(items._characters["compat-key-aaa01"]["strength"]) == 0 and items._characters["compat-key-aaa01"]["worn"].count(0) == 6 and items._characters["compat-key-aaa01"]["skills"].is_empty(), "newer attributes default to neutral (%s)" % str(items._characters["compat-key-aaa01"]))
	check(items._characters["compat-key-ccc03"]["skills"].has("mining") and int(items._characters["compat-key-ccc03"].get("skills_v", 0)) == 2, "era 37: old skill records migrate to the web")
	check(FileAccess.file_exists(dir + "/characters.json.v1.bak"), "and the old file is kept as a backup")

	# Era 44 and after: station tiers (states 16 to 18, ids unchanged) and remains rows.
	fresh(dir)
	var bench: int = table.number_of("log_workbench")
	var forge: int = table.number_of("stone_forge")
	var smithy: int = table.number_of("blacksmithy")
	put(dir, "world_items.json", {"version": 1, "next_id": 9, "items": [
		[bench, 1, 30.0, 10.0, 30.0, 1.0e9, 16, 0.0, 0, "log_workbench", 0],
		[forge, 1, 33.0, 10.0, 30.0, 1.0e9, 17, 0.0, 0, "stone_forge", 0],
		[smithy, 1, 36.0, 10.0, 30.0, 1.0e9, 18, 0.0, 0, "blacksmithy", 0],
		[chest, 1, 39.0, 10.0, 30.0, 1.0e9, 11, 0.0, 0, "remains", 0, "compat-key-aaa01", 400.0, true]], "taken": [], "picked": {}})
	items = boot(dir)
	check(items.world_item_count() == 4, "era 44+: station and remains rows load (%d)" % items.world_item_count())
	var kinds: Array = []

	for id in items._items:
		kinds.append(str(items._items[id].get("struct", {}).get("kind", "")))

	kinds.sort()
	check(kinds == ["blacksmithy", "log_workbench", "remains", "stone_forge"], "with their kinds intact (%s)" % str(kinds))

	# Save again and reload: nothing lost on the round trip.
	items._dirty = true
	items.save()
	var again = boot(dir)
	check(again.world_item_count() == 4, "a save and reload keeps all four")

	# From the future: set aside, never eaten, the server still starts.
	fresh(dir)
	put(dir, "world_items.json", {"version": 99, "next_id": 1, "items": [[stone, 1, 1.0, 1.0, 1.0, 1.0]], "taken": [], "picked": {}})
	put(dir, "inventories.json", {"version": 99, "inventories": {}})
	items = boot(dir)
	check(items.world_item_count() == 0 and FileAccess.file_exists(dir + "/world_items.json.bad") and FileAccess.file_exists(dir + "/inventories.json.bad"), "files from a newer version are set aside as .bad")

	print("save compat: %d failures" % failures)
	quit(1 if failures > 0 else 0)
