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
	var cordage: int = items.table.number_of("cordage")
	items.action(1, Net.ACT_ADMIN_GIVE, stone, 0, 4, Vector3.ZERO)
	items.action(1, Net.ACT_ADMIN_GIVE, stick, 0, 30, Vector3.ZERO)
	items.action(1, Net.ACT_ADMIN_GIVE, cordage, 0, 8, Vector3.ZERO)
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, spade, 0, 1, Vector3.ZERO)
	check(items.craft_queue_of(1).is_empty() and not said.is_empty(), "no bench, no craft (%s)" % str(said))
	check(not items.station_near(1, "workbench"), "no station near yet")

	# Make and place the bench.
	var bench_recipe: int = 0

	for number in items.recipes.numbers():
		if str(items.recipes.recipe(number)["id"]) == "workbench_kit":
			bench_recipe = number

	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, bench_recipe, 0, 1, Vector3.ZERO)
	items._craft_tick(60.0)
	var kit: int = items.table.number_of("workbench_kit")
	check(items.inventory_of(1).count_of(kit) == 1, "the camp bench kit is hand-made")
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(kit), 0, 0, Vector3(2.0, 10.0, 0.0))
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

	# Add-ons raise the bench's level: a tool rack and a vice beside it.
	check(not items.station_near(1, "workbench", 2), "a bare bench is level 1")
	var rack: int = items.table.number_of("tool_rack_kit")
	items.action(1, Net.ACT_ADMIN_GIVE, rack, 0, 1, Vector3.ZERO)
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(rack), 0, 0, Vector3(2.0, 10.0, 3.5))
	check(items.station_near(1, "workbench", 2) and not items.station_near(1, "workbench", 3), "a tool rack makes it level 2")
	var vice: int = items.table.number_of("vice_kit")
	items.action(1, Net.ACT_ADMIN_GIVE, vice, 0, 1, Vector3.ZERO)
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(vice), 0, 0, Vector3(2.0, 10.0, -2.5))
	check(items.station_near(1, "workbench", 3), "a vice as well makes it level 3")

	print("station tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
