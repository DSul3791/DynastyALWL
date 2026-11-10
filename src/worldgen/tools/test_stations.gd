extends SceneTree

# Crafting stations (Items refill 12): a recipe with a station is queued only near a placed station, waits while you are away,
# and the camp bench places like the other kits.
#   godot --headless --path . --script res://src/worldgen/tools/test_stations.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var said: Array = []


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var dir: String = "user://test_stations"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_craft_queue = func(_p, _e, _l): pass
	items.send_notice = func(_p, text): said.append(text)
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "station-key-0001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	var spade: int = items.recipes.recipe(0).get("number", 0)

	for number in items.recipes.numbers():
		if str(items.recipes.recipe(number)["id"]) == "stone_spade":
			spade = number

	check(str(items.recipes.recipe(spade).get("station", "")) == "workbench", "the stone spade is a camp bench recipe")
	var stone: int = items.table.number_of("stone")
	var stick: int = items.table.number_of("stick")
	var twine: int = items.table.number_of("twine")
	items.action(1, Net.ACT_ADMIN_GIVE, stone, 0, 4, Vector3.ZERO)
	items.action(1, Net.ACT_ADMIN_GIVE, stick, 0, 30, Vector3.ZERO)
	items.action(1, Net.ACT_ADMIN_GIVE, twine, 0, 8, Vector3.ZERO)
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, spade, 0, 1, Vector3.ZERO)
	check(items.craft_queue_of(1).is_empty() and not said.is_empty(), "no bench, no craft (%s)" % str(said))
	check(not items.station_near(1, "workbench"), "no station near yet")

	# Place the bench (a hammer blueprint now, no kit).
	var kit: int = items.table.number_of("workbench_kit")
	items.place_item(1, kit, Vector3(2.0, 10.0, 0.0), 0)
	check(items.station_near(1, "workbench"), "the placed bench is a station in reach")
	check(not items.station_near(1, "workbench", 2), "a level 2 recipe needs a better bench")

	# Craft near it; step away and the craft waits.
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("wooden_spade"), 0, 1, Vector3.ZERO)
	items.action(1, Net.ACT_ADMIN_GIVE, stone, 0, 2, Vector3.ZERO)
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, spade, 0, 1, Vector3.ZERO)
	check(not items.craft_queue_of(1).is_empty(), "near the bench the craft is queued")
	items.report_position(1, Vector3(30.0, 10.0, 0.0))
	items._craft_tick(60.0)
	check(not items.craft_queue_of(1).is_empty() and items.inventory_of(1).count_of(items.table.number_of("stone_spade")) == 0, "away from the bench the craft waits")
	items.report_position(1, Vector3(1.0, 10.0, 0.0))
	items._craft_tick(60.0)
	check(items.inventory_of(1).count_of(items.table.number_of("stone_spade")) == 1, "back at the bench it finishes")

	# Add-ons raise the bench's level: a tool rack beside it.
	check(not items.station_near(1, "workbench", 2), "a bare bench is level 1")
	var rack: int = items.table.number_of("tool_rack_kit")
	items.action(1, Net.ACT_ADMIN_GIVE, rack, 0, 1, Vector3.ZERO)
	items.place_item(1, rack, Vector3(2.0, 10.0, 3.5), 0)
	check(items.station_near(1, "workbench", 2) and not items.station_near(1, "workbench", 3), "a tool rack makes it level 2")
	# The vice kit is retired (Dave 25 Oct): the log workbench carries its own vice, so only the tool rack is an add-on now.
	check(not items.station_near(1, "workbench", 3), "a camp bench with a rack stays level 2")

	# The tiers: workbench 1, sturdy (log) workbench 2; the forges are forges 1 to 4 and no longer count as workbench levels (items review stage 1, 9 Nov 2026;
	# was Dave 2026-10-21: stone forge workbench 3, blacksmithy and up workbench 4). Bench level 3 and 4 now come from the rack and vice add-ons.
	var dir2: String = "user://test_stations_tiers"
	DirAccess.make_dir_recursive_absolute(dir2)

	for file in DirAccess.get_files_at(dir2):
		DirAccess.remove_absolute(dir2 + "/" + file)

	var tiers = ItemsScript.new()
	tiers.send_full = func(_p, _b): pass
	tiers.send_slots = func(_p, _b): pass
	tiers.send_world_items = func(_p, _a, _r): pass
	tiers.send_craft_queue = func(_p, _e, _l): pass
	tiers.send_notice = func(_p, text): said.append(text)
	tiers.ground_height = func(_x, _z): return 10.0
	tiers.setup(ItemTableScript.load_default(), dir2)
	tiers.peer_connected_hello(1, "tier-key-000001")
	tiers.report_position(1, Vector3(0.0, 10.0, 0.0))
	var spots: Array = [Vector3(3.0, 10.0, 0.0), Vector3(200.0, 10.0, 0.0), Vector3(400.0, 10.0, 0.0), Vector3(600.0, 10.0, 0.0), Vector3(800.0, 10.0, 0.0)]
	var kits: Array = ["log_workbench_kit", "stone_forge_kit", "blacksmithy_kit", "large_forge_kit", "master_forge_kit"]
	# [workbench, forge, brick_forge]. The Brick - Forge is its own body (item_system.md, forge levels ruled 9 Nov 2026): brick_forge 2 for iron, and a
	# level-1 forge for bronze (also). The large and master forges are parked and keep their old forge levels.
	var want: Array = [[2, 0, 0], [0, 1, 0], [0, 1, 2], [0, 3, 0], [0, 4, 0]]

	for n in 5:
		var kit_number: int = tiers.table.number_of(kits[n])
		check(kit_number > 0, "%s is an item" % kits[n])
		tiers.report_position(1, spots[n] - Vector3(2.0, 0.0, 0.0))
		tiers.action(1, Net.ACT_ADMIN_GIVE, kit_number, 0, 1, Vector3.ZERO)
		tiers.place_item(1, kit_number, spots[n], 0)
		
		check(int(want[n][0]) == 0 or tiers.station_near(1, "workbench", int(want[n][0])), "%s gives workbench %d" % [kits[n], int(want[n][0])])
		check(not tiers.station_near(1, "workbench", int(want[n][0]) + 1), "%s gives no more than %d" % [kits[n], int(want[n][0])])
		check(tiers.station_near(1, "forge", int(want[n][1])) or int(want[n][1]) == 0, "%s forge %d" % [kits[n], int(want[n][1])])
		check(int(want[n][1]) == 0 or not tiers.station_near(1, "forge", int(want[n][1]) + 1), "%s forge capped" % kits[n])
		check(tiers.station_near(1, "brick_forge", int(want[n][2])) or int(want[n][2]) == 0, "%s brick forge %d" % [kits[n], int(want[n][2])])
		check(not tiers.station_near(1, "brick_forge", int(want[n][2]) + 1), "%s brick forge capped at %d" % [kits[n], int(want[n][2])])

	var steel: int = 0

	for number in tiers.recipes.numbers():
		if str(tiers.recipes.recipe(number)["id"]) == "steel_pickaxe":
			steel = number

	check(str(tiers.recipes.recipe(steel).get("station", "")) == "brick_forge" and int(tiers.recipes.recipe(steel).get("station_level", 1)) == 3, "steel needs the brick forge at level 3 (bronze forge 1, iron brick forge 2, steel brick forge 3)")

	# The Iron - Anvil beside the brick forge is the steel step: brick forge 2 plus one add-on kind is level 3. Beside a stone forge it adds nothing.
	tiers.report_position(1, spots[2] - Vector3(2.0, 0.0, 0.0))
	check(not tiers.station_near(1, "brick_forge", 3), "no anvil yet: the brick forge is level 2")
	var anvil: int = tiers.table.number_of("iron_anvil_kit")
	tiers.action(1, Net.ACT_ADMIN_GIVE, anvil, 0, 1, Vector3.ZERO)
	tiers.place_item(1, anvil, spots[2] + Vector3(0.0, 0.0, 2.0), 0)
	check(tiers.station_near(1, "brick_forge", 3) and not tiers.station_near(1, "brick_forge", 4), "an anvil beside it makes the brick forge level 3, for steel")
	check(tiers.station_near(1, "forge", 1) and not tiers.station_near(1, "forge", 2), "and it is still a level 1 forge for bronze, no higher")
	tiers.report_position(1, spots[1] - Vector3(2.0, 0.0, 0.0))
	tiers.action(1, Net.ACT_ADMIN_GIVE, anvil, 0, 1, Vector3.ZERO)
	tiers.place_item(1, anvil, spots[1] + Vector3(0.0, 0.0, 2.0), 0)
	check(not tiers.station_near(1, "forge", 2) and not tiers.station_near(1, "brick_forge", 1), "an anvil beside a stone forge does nothing: the stone forge never reaches iron")

	print("station tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
