extends SceneTree

# Mission 001 phase 2b: the wilderness route to the first Iron - Saw, no purchases (master s2.7 item 1, Dave [D1]), through the real server,
# recipes and blueprints. Every amount is read from the live data, so tuning the numbers keeps the test valid.
#   1. bog iron dug with a wooden spade in wet ground;
#   2. charcoal at a lit campfire from firewood;
#   3. a Smelter from its stone-and-clay blueprint, and Iron ingots smelted there (no smelting at a forge);
#   4. a Smithy from stones, clay, logs and Iron ingots; cold, it makes nothing without fuel; fired with charcoal from the pack;
#   5. the Iron - Saw at the burning Smithy from iron and wood, no Saw blade;
#   6. with the saw: a spruce log gives 6 Planks, an oak log 4 Hardwood boards.
#   godot --headless --path . --script res://src/worldgen/tools/test_iron_saw_route.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const HERE := Vector3(5.0, 10.0, 0.0)
const FIRE_AT := Vector3(2.5, 10.0, 0.0)
const SMELTER_AT := Vector3(8.0, 10.0, -0.5)
const SMITHY_AT := Vector3(5.0, 10.0, 3.5)

var failures: int = 0
var items
var said: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1
		print("     the server said: ", str(said.slice(maxi(said.size() - 3, 0))) if not said.is_empty() else "nothing")


func have(id: String) -> int:
	return items.inventory_of(1).count_of(items.table.number_of(id))


func recipe_number(id: String) -> int:
	for n in items.recipes.numbers():
		if str(items.recipes.recipe(int(n)).get("id", "")) == id:
			return int(n)

	return 0


func need_of(recipe_id: String, id: String) -> int:
	for need in items.recipes.recipe(recipe_number(recipe_id)).get("needs", []):
		if int(need[0]) == items.table.number_of(id):
			return int(need[1])

	return 0


func gives_of(recipe_id: String) -> int:
	return int(items.recipes.recipe(recipe_number(recipe_id)).get("gives", [0, 1])[1])


func craft(id: String, times: int, seconds: int) -> void:
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, recipe_number(id), 0, times, Vector3.ZERO)

	for s in range(seconds):
		items.tick(1.0)


func blueprint_of(structure: String) -> Dictionary:
	for number in items._blueprints:
		if str(items._blueprints[number].get("structure", "")) == structure:
			return items._blueprints[number]

	return {}


func build(structure: String, at: Vector3) -> int:
	var bp: Dictionary = blueprint_of(structure)

	for need in bp.get("cost", []):
		items.give(1, items.table.number_of(str(need[0])), int(need[1]))   # gathered materials: stone, clay, logs (the iron is made below and checked)

	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(bp.get("number", 0)), 0, 0, at)

	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == structure and not items._items[id]["struct"].has("site"):
			return int(id)

	return -1


func _init() -> void:
	var dir: String = "user://test_iron_saw_route"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_reject = func(_p, _r): pass
	items.send_notice = func(_p, text): said.append(str(text))
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.admin_mode_on = func(_p): return false
	var clock: Array = [1000.0 * 86400.0]
	items.game_seconds = func(): return clock[0]
	items.skill_level = func(_p, _s): return 1.0
	items.dig_ground = func(_centre, _radius): return null
	items.ground_material = func(_x, _z): return "peat"
	items.bog_deposit_at = func(_x, _z, _cfg_in): return {"key": "1,1", "size": 60, "edge": true}
	items.peer_connected_hello(1, "ironsaw00001")
	items.report_position(1, HERE)
	items.vitals_of(1)["weight"] = 5000.0   # the ore and stone are heavy; carrying is not under test

	# How much iron the route needs, from the live recipes and blueprints.
	var smithy_iron: int = 0

	for need in blueprint_of("blacksmithy").get("cost", []):
		if str(need[0]) == "iron_ingot":
			smithy_iron = int(need[1])

	var saw_iron: int = need_of("hand_saw", "iron_ingot")
	var smelts: int = ceili(float(smithy_iron + saw_iron) / float(gives_of("smelt_iron")))
	var ore_n: int = smelts * need_of("smelt_iron", "iron_ore")
	var fuel_n: int = smelts * need_of("smelt_iron", "fuel") + 4   # and a few to fire the Smithy
	check(smithy_iron > 0 and saw_iron > 0 and ore_n > 0, "the Smithy costs Iron ingots (%d) and the saw is made of iron (%d): %d ore to dig" % [smithy_iron, saw_iron, ore_n])

	# 1. Bog iron with a wooden spade.
	items.give(1, items.table.number_of("wooden_spade"), 1)

	for n in range(200):
		if have("iron_ore") >= ore_n:
			break

		items._last_dig.clear()
		items.action(1, Net.ACT_DIG, 0, 0, 0, HERE + Vector3(1.0, 0.0, 0.0))
		items.inventory_of(1).remove(items.table.number_of("soil"), have("soil"))

	check(have("iron_ore") >= ore_n, "1. a wooden spade digs %d bog iron ore out of wet ground (%d)" % [ore_n, have("iron_ore")])

	# 2. Charcoal at a lit campfire.
	items._items[items._next_id] = {"number": items.table.number_of("campfire_kit"), "count": 1, "pos": FIRE_AT, "left": 1.0e9, "fire": {"state": 1, "burn_left": 1.0e6, "covered": false, "recheck": 5.0}}
	items._next_id += 1
	var charcoal_crafts: int = ceili(float(fuel_n) / float(gives_of("charcoal")))
	items.give(1, items.table.number_of("firewood"), charcoal_crafts * need_of("charcoal", "firewood"))
	craft("charcoal", charcoal_crafts, 120 * charcoal_crafts)
	check(have("charcoal") >= fuel_n, "2. firewood burns to %d charcoal at the campfire (%d needed)" % [have("charcoal"), fuel_n])

	# 3. The Smelter and the iron.
	items.give(1, items.table.number_of("wooden_hammer"), 1)
	check(build("smelter", SMELTER_AT) >= 0, "3a. a Smelter stands, built from %s" % str(blueprint_of("smelter").get("cost", [])))
	craft("smelt_iron", smelts, 200 * smelts)
	check(have("iron_ingot") >= smithy_iron + saw_iron, "3b. the Smelter turns bog iron into %d Iron ingots (%d)" % [smithy_iron + saw_iron, have("iron_ingot")])

	# 4. The Smithy from stones, clay, logs and Iron ingots; it must burn to craft.
	var iron_before: int = have("iron_ingot")
	var bp: Dictionary = blueprint_of("blacksmithy")
	var smithy_id: int = -1

	for need in bp.get("cost", []):
		if str(need[0]) != "iron_ingot":
			items.give(1, items.table.number_of(str(need[0])), int(need[1]))

	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(bp.get("number", 0)), 0, 0, SMITHY_AT)

	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == "blacksmithy" and not items._items[id]["struct"].has("site"):
			smithy_id = int(id)

	check(smithy_id >= 0 and have("iron_ingot") == iron_before - smithy_iron, "4a. the Smithy stands and took its %d Iron ingots" % smithy_iron)
	var charcoal_n: int = have("charcoal")
	items.inventory_of(1).remove(items.table.number_of("charcoal"), charcoal_n)
	items.give(1, items.table.number_of("stick"), need_of("hand_saw", "stick"))
	craft("hand_saw", 1, 60)
	check(have("hand_saw") == 0 and not bool(items._items[smithy_id]["struct"].get("lit", false)), "4b. a cold Smithy and no fuel: no saw, nothing taken (%d ingots)" % have("iron_ingot"))
	items.inventory_of(1).add(items.table.number_of("charcoal"), charcoal_n)

	# 5. The Iron - Saw at the burning Smithy.
	craft("hand_saw", 1, 120)
	check(bool(items._items[smithy_id]["struct"].get("lit", false)) and have("charcoal") == charcoal_n - 1, "5a. the craft fires the Smithy with one charcoal")
	check(have("hand_saw") == 1 and have("saw_blade") == 0, "5b. the Iron - Saw is made at the Smithy from iron and wood, with no Saw blade")

	# 6. Planks and Hardwood boards with the saw.
	items.inventory_of(1).add(items.table.number_of("log_spruce"), 1)
	items.inventory_of(1).add(items.table.number_of("log_oak"), 1)
	craft("lumber_by_hand", 1, 60)
	craft("hardwood_board_by_hand", 1, 60)
	check(have("lumber") == 6 and have("hardwood_board") == 4, "6. the saw gives 6 Planks from a spruce log and 4 Hardwood boards from an oak log (%d, %d)" % [have("lumber"), have("hardwood_board")])

	print("iron saw route: %d failures" % failures)
	items._finish_writer()
	quit(1 if failures > 0 else 0)
