extends SceneTree

# Hammer blueprints (data/items/blueprints.json, ACT_PLACE_BLUEPRINT): the materials come out of the pack, no kit item, and a piece takes
# down into its materials. Old kits still place. Kit recipes are retired, not removed.
#   godot --headless --path . --script res://src/worldgen/tools/test_blueprints.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var items


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _give(peer: int, id: String, count: int) -> void:
	items.action(peer, Net.ACT_ADMIN_GIVE, items.table.number_of(id), 0, count, Vector3.ZERO)


func _have(peer: int, id: String) -> int:
	return items.inventory_of(peer).count_of(items.table.number_of(id))


func _clear(peer: int) -> void:
	var inv = items.inventory_of(peer)

	for slot in range(inv.SLOTS):
		inv.numbers[slot] = 0
		inv.counts[slot] = 0
		inv.wear[slot] = 0


func _ids_standing(kind: String) -> Array:
	var found: Array = []

	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == kind:
			found.append(id)

	return found


func _init() -> void:
	var dir: String = "user://test_blueprints"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "blueprintkey1")
	items.report_position(1, Vector3(200.0, 10.0, 200.0))
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/blueprints.json"))
	var recipes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/recipes.json"))["recipes"]
	var live: Dictionary = {}
	var numbers: Dictionary = {}

	# Data: each live blueprint costs what its retired kit recipe did, the recipe is retired, the number is its own.
	for id in parsed["blueprints"]:
		var row: Dictionary = parsed["blueprints"][id]
		check(not numbers.has(int(row["number"])) and int(row["number"]) < int(parsed["next_number"]), "%s: blueprint number is its own and below next_number" % id)
		numbers[int(row["number"])] = true

		if bool(row.get("retired", false)):
			check(not bool(recipes[str(row["recipe"])].get("retired", false)), "%s: the hand-made recipe is live again (fine wood or lower is by hand)" % id)
			continue

		live[id] = row
		check(items._structures.has(str(row["structure"])), "%s: names a structure" % id)

		if not row.has("recipe"):   # the clay hearth and the oven never had a kit recipe
			continue

		var recipe: Dictionary = recipes[str(row["recipe"])]
		check(bool(recipe.get("retired", false)), "%s: kit recipe %d is retired, not removed" % [id, int(recipe["number"])])
		check(JSON.stringify(row["cost"]) == JSON.stringify(recipe["needs"]), "%s: cost equals the retired kit recipe" % id)

	check(live.size() == 6 and live.has("stone_forge") and live.has("blacksmithy") and live.has("saw_mill") and live.has("woodworking_table") and live.has("clay_hearth") and live.has("oven"), "the heavy stations and the cooking tiers are the blueprints (%d)" % live.size())

	# Fine wood and lower are made by hand, no station: the section pieces, the foundation, the timber set, the ladder (and the thatch four).
	for kit in ["wall_section_kit", "floor_section_kit", "roof_section_kit", "foundation_section_kit", "doorway_section_kit", "window_section_kit", "timber_set_kit", "ladder_kit"]:
		var made: Dictionary = recipes[kit]
		check(not bool(made.get("retired", false)) and str(made.get("station", "")) == "" and bool(made.get("known", false)), "%s: a hand craft known from the start" % kit)

	# Place: a hammer, the station near at its level, every material; a short pack takes nothing.
	var table_bp: Dictionary = live["woodworking_table"]
	var spot: Vector3 = Vector3(200.0, 10.0, 205.0)
	items.report_position(1, Vector3(200.0, 10.0, 204.0))
	_clear(1)
	var before: int = items.world_item_count()
	_give(1, "lumber", 12)
	_give(1, "nails", 60)
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(table_bp["number"]), 0, 0, spot)
	check(items.world_item_count() == before and _have(1, "lumber") == 12, "no hammer: nothing placed, nothing taken")
	_give(1, "wooden_hammer", 1)
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(table_bp["number"]), 0, 0, spot)
	check(items.world_item_count() == before and _have(1, "lumber") == 12, "no workbench near: nothing placed, nothing taken")
	_give(1, "log_workbench_kit", 1)
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(items.table.number_of("log_workbench_kit")), 0, 0, Vector3(200.0, 10.0, 202.0))
	check(_ids_standing("log_workbench").size() == 1, "a log workbench stands (the station)")
	_clear(1)
	_give(1, "wooden_hammer", 1)
	_give(1, "lumber", 11)
	_give(1, "nails", 60)
	var with_bench: int = items.world_item_count()
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(table_bp["number"]), 0, 0, spot)
	check(items.world_item_count() == with_bench and _have(1, "lumber") == 11 and _have(1, "nails") == 60, "a short pack places nothing and takes nothing")
	_give(1, "lumber", 1)
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(table_bp["number"]), 0, 0, spot)
	check(items.world_item_count() == with_bench + 1 and _ids_standing("woodworking_table").size() == 1, "with the hammer, the bench and the materials the table stands")
	check(_have(1, "lumber") == 0 and _have(1, "nails") == 0 and _have(1, "woodworking_table_kit") == 0 and _have(1, "wooden_hammer") == 1, "exactly the materials were taken, no kit item, the hammer kept")

	# A station level the bench cannot give: the blacksmithy needs level 4, the log workbench is level 2.
	var smith: Dictionary = live["blacksmithy"]
	_give(1, "stone", 30)
	_give(1, "log", 10)
	_give(1, "clay", 10)
	var smith_before: int = items.world_item_count()
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(smith["number"]), 0, 0, Vector3(204.0, 10.0, 205.0))
	check(items.world_item_count() == smith_before and _have(1, "stone") == 30, "a bench of too low a level places nothing and takes nothing")

	# Row hammer tier: a row asking for hammer 2 refuses the wooden hammer.
	items._blueprints[int(table_bp["number"])]["hammer"] = 2
	_give(1, "lumber", 12)
	_give(1, "nails", 60)
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(table_bp["number"]), 0, 0, Vector3(196.0, 10.0, 205.0))
	check(_ids_standing("woodworking_table").size() == 1 and _have(1, "lumber") == 12, "a row with hammer 2 refuses the wooden hammer")
	items._blueprints[int(table_bp["number"])]["hammer"] = 1

	# Take down: every material back, no kit.
	items.action(1, Net.ACT_PICKUP, _ids_standing("woodworking_table")[0], 0, 0, Vector3.ZERO)
	check(_ids_standing("woodworking_table").is_empty() and _have(1, "lumber") == 24 and _have(1, "nails") == 120 and _have(1, "woodworking_table_kit") == 0, "taking it down gives the materials back (lumber %d, nails %d)" % [_have(1, "lumber"), _have(1, "nails")])

	# An old kit still places and takes down into a kit (the old way), and a by-hand piece takes down into its piece.
	_clear(1)
	_give(1, "wall_section_kit", 1)
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(items.table.number_of("wall_section_kit")), 0, 0, Vector3(200.0, 10.0, 207.0))
	check(_ids_standing("wall_section").size() == 1 and _have(1, "wall_section_kit") == 0, "a hand-made wall piece places")
	items.action(1, Net.ACT_PICKUP, _ids_standing("wall_section")[0], 0, 0, Vector3.ZERO)
	check(_have(1, "wall_section_kit") == 1, "and takes down into the piece, no blueprint refund")

	# Takedown into a full pack keeps the blueprint piece.
	_clear(1)
	_give(1, "wooden_hammer", 1)
	_give(1, "lumber", 12)
	_give(1, "nails", 60)
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(table_bp["number"]), 0, 0, Vector3(196.0, 10.0, 205.0))
	check(_ids_standing("woodworking_table").size() == 1, "the table stands again")
	var inv = items.inventory_of(1)

	for slot in range(inv.SLOTS):
		inv.numbers[slot] = items.table.number_of("stone")
		inv.counts[slot] = items.table.stack_of(items.table.number_of("stone"))

	items.action(1, Net.ACT_PICKUP, _ids_standing("woodworking_table")[0], 0, 0, Vector3.ZERO)
	check(_ids_standing("woodworking_table").size() == 1, "a full pack: the table stays up, nothing is lost")

	# A snare: the kit places as the snare_trap structure and takes down into the kit.
	_clear(1)
	items.report_position(1, Vector3(240.0, 10.0, 240.0))
	_give(1, "snare", 1)
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(items.table.number_of("snare")), 0, 0, Vector3(240.0, 10.0, 242.0))
	check(_ids_standing("snare_trap").size() == 1 and _have(1, "snare") == 0, "a snare is set on the ground")
	items.action(1, Net.ACT_PICKUP, _ids_standing("snare_trap")[0], 0, 0, Vector3.ZERO)
	check(_ids_standing("snare_trap").is_empty() and _have(1, "snare") == 1, "and taken back into the snare item")

	# Clay hearth (13) and oven (14): hammer blueprints; the oven needs a hearth within reach; the tiers cook what the lower tier cooks.
	_clear(1)
	_give(1, "wooden_hammer", 1)
	_give(1, "brick", 24)
	_give(1, "clay", 10)
	_give(1, "stone", 8)
	items.report_position(1, Vector3(230.0, 10.0, 230.0))
	var oven_bp: Dictionary = live["oven"]
	var hearth_bp: Dictionary = live["clay_hearth"]
	check(int(hearth_bp["number"]) == 13 and int(oven_bp["number"]) == 14, "hearth is blueprint 13, oven 14")
	var oven_before: int = items.world_item_count()
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(oven_bp["number"]), 0, 0, Vector3(230.0, 10.0, 233.0))
	check(items.world_item_count() == oven_before and _have(1, "brick") == 24, "an oven without a hearth near places nothing and takes nothing")
	check(not items.station_near(1, "campfire"), "no fire, no hearth: nothing cooks")
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(hearth_bp["number"]), 0, 0, Vector3(230.0, 10.0, 233.0))
	check(_ids_standing("clay_hearth").size() == 1 and _have(1, "brick") == 14 and _have(1, "clay") == 4 and _have(1, "stone") == 4, "the hearth stands for 10 brick, 6 clay, 4 stone")
	check(items.station_near(1, "clay_hearth", 2) and items.station_near(1, "campfire") and not items.station_near(1, "oven", 3), "a hearth cooks what a campfire cooks, not oven dishes")
	var dish_nums: Dictionary = {}

	for rn in items.recipes.numbers():
		dish_nums[str(items.recipes.recipe(rn)["id"])] = rn

	check(str(items.recipes.recipe(dish_nums["cook_flatbread"]).get("station", "")) == "clay_hearth" and str(items.recipes.recipe(dish_nums["cook_honey_loaf"]).get("station", "")) == "oven", "the new dishes name their station")
	_give(1, "seeds", 6)
	_give(1, "water", 2)
	_give(1, "hazelnuts", 1)
	_give(1, "honeyspindle_nectar", 1)
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, int(dish_nums["cook_honey_loaf"]), 0, 1, Vector3.ZERO)
	check(items.craft_queue_of(1).is_empty(), "a honey loaf is refused at a hearth (oven dish)")
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, int(dish_nums["cook_flatbread"]), 0, 1, Vector3.ZERO)
	check(not items.craft_queue_of(1).is_empty(), "flatbread is accepted at a hearth")
	items.action(1, Net.ACT_CRAFT_CANCEL, 0, 0, 0, Vector3.ZERO)
	_give(1, "brick", 10)
	_give(1, "clay", 6)
	_give(1, "stone", 4)
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(oven_bp["number"]), 0, 0, Vector3(234.0, 10.0, 230.0))
	check(_ids_standing("oven").size() == 1 and _have(1, "brick") == 0 and _have(1, "clay") == 0 and _have(1, "stone") == 0, "with a hearth near the oven stands for 24 brick, 10 clay, 8 stone")
	check(items.station_near(1, "oven", 3) and items.station_near(1, "clay_hearth", 2) and items.station_near(1, "campfire"), "an oven cooks what a hearth and a campfire cook")
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, int(dish_nums["cook_honey_loaf"]), 0, 1, Vector3.ZERO)
	check(not items.craft_queue_of(1).is_empty(), "a honey loaf is accepted at the oven")
	items.report_position(1, Vector3(233.0, 10.0, 231.0))
	items.action(1, Net.ACT_PICKUP, _ids_standing("oven")[0], 0, 0, Vector3.ZERO)
	check(_ids_standing("oven").is_empty() and _have(1, "brick") == 24 and _have(1, "oven_kit") == 0, "taking the oven down gives the materials back")

	# Save and load: placed pieces come back.
	items.save()
	var again = ItemsScript.new()
	again.send_full = func(_p, _b): pass
	again.send_slots = func(_p, _b): pass
	again.send_world_items = func(_p, _a, _r): pass
	again.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	again.ground_height = func(_x, _z): return 10.0
	again.setup(ItemTableScript.load_default(), dir)
	check(again.world_item_count() == items.world_item_count(), "a save with blueprint pieces loads")
	print("test_blueprints: %d fail" % failures)
	quit(1 if failures > 0 else 0)
