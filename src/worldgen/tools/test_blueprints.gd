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
	var numbers: Dictionary = {}

	# Data: each blueprint costs exactly what its retired kit recipe did, the recipe is retired, the number is its own.
	for id in parsed["blueprints"]:
		var row: Dictionary = parsed["blueprints"][id]
		check(not numbers.has(int(row["number"])) and int(row["number"]) < int(parsed["next_number"]), "%s: blueprint number is its own and below next_number" % id)
		numbers[int(row["number"])] = true
		check(items._structures.has(str(row["structure"])), "%s: names a structure" % id)
		var recipe: Dictionary = recipes[str(row["recipe"])]
		check(bool(recipe.get("retired", false)), "%s: kit recipe %d is retired, not removed" % [id, int(recipe["number"])])
		check(JSON.stringify(row["cost"]) == JSON.stringify(recipe["needs"]), "%s: cost equals the retired kit recipe" % id)
		check(items.recipes.number_of_id(str(row["recipe"])) == 0 if items.recipes.has_method("number_of_id") else true, "%s: kit recipe is not craftable" % id)

	check(parsed["blueprints"].size() == 8, "build 1: six section kits, the timber set and the ladder (%d)" % parsed["blueprints"].size())
	check(not parsed["blueprints"].has("lean_to") and not parsed["blueprints"].has("rough_bed") and not parsed["blueprints"].has("thatch_wall") and not parsed["blueprints"].has("chest"), "nothing in the first tier is a blueprint")

	# Place: needs a hammer of the row's tier and every material; a short pack takes nothing.
	var wall: Dictionary = parsed["blueprints"]["wall_section"]
	var spot: Vector3 = Vector3(200.0, 10.0, 202.0)
	_clear(1)
	var before: int = items.world_item_count()
	_give(1, "lumber", 4)
	_give(1, "twine", 1)
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(wall["number"]), 0, 0, spot)
	check(items.world_item_count() == before and _have(1, "lumber") == 4, "no hammer: nothing placed, nothing taken")
	_give(1, "wooden_hammer", 1)
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(wall["number"]), 0, 0, spot)
	check(items.world_item_count() == before + 1 and _have(1, "lumber") == 0, "a wooden hammer is enough (tier 1 default)")
	items.action(1, Net.ACT_PICKUP, _ids_standing("wall_section")[0], 0, 0, Vector3.ZERO)
	check(_have(1, "lumber") == 4, "taken down again for the next steps")
	# A row can ask for a better hammer (data field per row).
	items._blueprints[int(wall["number"])]["hammer"] = 2
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(wall["number"]), 0, 0, spot)
	check(items.world_item_count() == before and _have(1, "lumber") == 4, "a row with hammer 2 refuses the wooden hammer")
	items._blueprints[int(wall["number"])]["hammer"] = 1
	_clear(1)
	_give(1, "stone_hammer", 1)
	_give(1, "lumber", 3)
	_give(1, "twine", 1)
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(wall["number"]), 0, 0, spot)
	check(items.world_item_count() == before and _have(1, "lumber") == 3 and _have(1, "twine") == 1, "a short pack places nothing and takes nothing")
	_give(1, "lumber", 2)
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(wall["number"]), 0, 0, spot)
	check(items.world_item_count() == before + 1 and _ids_standing("wall_section").size() == 1, "with the hammer and the materials the wall stands")
	check(_have(1, "lumber") == 1 and _have(1, "twine") == 0 and _have(1, "wall_section_kit") == 0, "exactly the materials were taken, no kit item (lumber %d, twine %d)" % [_have(1, "lumber"), _have(1, "twine")])
	check(_have(1, "stone_hammer") == 1, "the hammer is kept")

	# A blocked spot takes nothing (over water).
	_give(1, "twine", 1)
	_give(1, "lumber", 3)
	var lumber_before: int = _have(1, "lumber")
	items.water_depth_at = func(_pos: Vector3) -> float: return 1.0
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(wall["number"]), 0, 0, Vector3(204.0, 10.0, 204.0))
	items.water_depth_at = func(_pos: Vector3) -> float: return 0.0
	check(_ids_standing("wall_section").size() == 1 and _have(1, "lumber") == lumber_before and _have(1, "twine") == 1, "a blocked spot takes nothing")

	# Take down: every material back, no kit.
	items.action(1, Net.ACT_PICKUP, _ids_standing("wall_section")[0], 0, 0, Vector3.ZERO)
	check(_ids_standing("wall_section").is_empty() and _have(1, "lumber") == lumber_before + 4 and _have(1, "twine") == 2 and _have(1, "wall_section_kit") == 0, "taking it down gives the materials back (lumber %d, twine %d)" % [_have(1, "lumber"), _have(1, "twine")])

	# An old kit still places, and takes down into the materials.
	_clear(1)
	_give(1, "wall_section_kit", 1)
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(items.table.number_of("wall_section_kit")), 0, 0, spot)
	check(_ids_standing("wall_section").size() == 1 and _have(1, "wall_section_kit") == 0, "an old kit item still places")
	items.action(1, Net.ACT_PICKUP, _ids_standing("wall_section")[0], 0, 0, Vector3.ZERO)
	check(_have(1, "lumber") == 4 and _have(1, "twine") == 1, "a kit-placed wall takes down into its materials")

	# Every blueprint places with its own materials (a stone hammer, a foundation under what needs one is not required for these).
	var spots: Dictionary = {"wall_section": 0, "floor_section": 1, "roof_section": 2, "foundation_section": 3, "doorway_section": 4, "window_section": 5, "timber_set": 6, "ladder": 7}

	items.report_position(1, Vector3(200.0, 10.0, 210.0))

	for id in parsed["blueprints"]:
		var row: Dictionary = parsed["blueprints"][id]
		_clear(1)
		_give(1, "stone_hammer", 1)

		for need in row["cost"]:
			_give(1, str(need[0]), int(need[1]))

		var at: Vector3 = Vector3(195.5 + 3.0 * float(spots[id] % 4), 10.0, 208.0 + 4.0 * float(spots[id] / 4))
		var standing: int = _ids_standing(str(row["structure"])).size()
		items.action(1, Net.ACT_PLACE_BLUEPRINT, int(row["number"]), 0, 0, at)
		check(_ids_standing(str(row["structure"])).size() == standing + 1, "%s places from the hammer" % id)

		for need in row["cost"]:
			check(_have(1, str(need[0])) == 0, "%s: %s all taken" % [id, str(need[0])])

	# Takedown into a full pack keeps the piece.
	var ladder_ids: Array = _ids_standing("ladder")
	check(not ladder_ids.is_empty(), "a ladder stands to take down")
	_clear(1)
	var inv = items.inventory_of(1)

	for slot in range(inv.SLOTS):
		inv.numbers[slot] = items.table.number_of("stone")
		inv.counts[slot] = items.table.stack_of(items.table.number_of("stone"))

	if ladder_ids.is_empty():
		ladder_ids.append(0)

	items.action(1, Net.ACT_PICKUP, ladder_ids[0], 0, 0, Vector3.ZERO)
	check(_ids_standing("ladder").size() == ladder_ids.size(), "a full pack: the ladder stays up, nothing is lost")

	# Save and load: placed pieces come back.
	items.save()
	var again = ItemsScript.new()
	again.send_full = func(_p, _b): pass
	again.send_slots = func(_p, _b): pass
	again.send_world_items = func(_p, _a, _r): pass
	again.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	again.ground_height = func(_x, _z): return 10.0
	again.setup(ItemTableScript.load_default(), dir)
	check(again.world_item_count() == items.world_item_count(), "an old-style save with blueprint pieces loads")
	print("test_blueprints: %d fail" % failures)
	quit(1 if failures > 0 else 0)
