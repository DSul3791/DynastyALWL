extends SceneTree

# Mission 001 phase 2b: the wilderness route to the first Iron - Saw, no purchases (master s2.7 item 1, Dave [D1]), through the real server,
# recipes and blueprints. Every amount is read from the live data, so tuning the numbers keeps the test valid.
#   1. bog iron dug with a wooden spade in wet ground;
#   2. charcoal at a lit campfire from firewood;
#   3. the Primitive smelter refuses iron ore; an Improved smelter (its bronze fittings come from the bronze route, test_bronze_path) smelts it
#      by itself only while the player works its bellows (master s2.7 items 1 and 4), into its output rack;
#   4. an Improved smithy from stones, clay, logs and bronze (its bronze anvil and fittings, from the bronze route, test_bronze_path), no iron
#      (master s2.7 item 5, GOALS-REPAIR A-15); cold, it makes nothing without fuel; fired with charcoal from the pack;
#   5. the Iron - Saw at the burning Improved smithy from iron and wood, no Saw blade;
#   6. with the saw: a spruce log gives 6 Planks, an oak log 4 Hardwood boards;
#   7. the Iron anvil (the Advanced smithy's component, A-16) at the Improved smithy; working iron on its bronze anvil wears it faster than
#      bronze work (smithing.json station_wear, A-17).
#   godot --headless --path . --script res://src/worldgen/tools/test_iron_saw_route.gd

const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const SmithingRules := preload("res://src/shared/smithing_rules.gd")

const HERE := Vector3(5.0, 10.0, 0.0)
const FIRE_AT := Vector3(2.5, 10.0, 0.0)
const SMELTER_AT := Vector3(8.0, 10.0, -0.5)
const PRIMITIVE_AT := Vector3(2.0, 10.0, -3.0)
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

	collect()


# Station products stay in the station (master s2.5, M001-T18): after a craft the player takes them out of their own station stores beside
# them through the real server path (open, Take all, close), as a player does.
func collect() -> void:
	for id in items._items.keys():
		var it: Dictionary = items._items.get(id, {})

		if it.has("struct") and items._is_station_store(it) and str(it["struct"].get("owner", "")) == items.key_of(1) and (it["pos"] as Vector3).distance_to(items.position_of(1)) <= 4.0:
			items.action(1, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)
			items.action(1, Net.ACT_BULK, ItemsScript.BULK_TAKE_ALL, 0, 0, Vector3.ZERO)
			items.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)


# One put from the pack into a station's store, through the real server path (open, put, close), as a player does. Returns how many went in.
func put_in(id: int, item: String, count: int) -> int:
	var number: int = items.table.number_of(item)
	var before: int = have(item)
	items.action(1, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_PUT, items.inventory_of(1).numbers.find(number), id, count, Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)
	return before - have(item)


func take_all(id: int) -> void:
	items.action(1, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_BULK, ItemsScript.BULK_TAKE_ALL, 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)


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


# A job's [id, count] rows as "id count" text: parsed JSON numbers are floats, so the rows are not compared as JSON text.
func rows_text(rows: Array) -> String:
	return ", ".join(rows.map(func(r): return "%s %d" % [str(r[0]), int(r[1])]))


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
	var anvil_iron: int = need_of("iron_anvil_part", "iron_ingot")
	var job: Dictionary = items._structures_cfg.get("smelting", {}).get("jobs", {}).get("iron", {})
	var ore_n: int = saw_iron + anvil_iron   # 1 Iron ore makes 1 Iron ingot (master s2.7 item 3)
	var fuel_n: int = int(ceil(float(items._structures_cfg["smelting"].get("fuel_per_ore", 1)) * float(ore_n))) + 4   # and a few to fire the Smithy
	check(rows_text(job.get("in", [])) == "iron_ore 1" and rows_text([job.get("out", ["", 0])]) == "iron_ingot 1" and bool(job.get("bellows", false)), "the iron job: 1 Iron ore to 1 Iron ingot, only with the bellows worked")
	# The pre-saw stations take only what the wilderness gives and the route makes (master s4 item 10): no Planks, no nails, no bought metal.
	for st in ["smelter", "stone_forge", "improved_smelter", "blacksmithy"]:
		var ids: Array = blueprint_of(st).get("cost", []).map(func(c): return str(c[0]))
		check(not ids.is_empty() and ids.all(func(c): return c in ["stone", "clay", "log", "hide", "bronze_ingot", "bronze_hinges", "bronze_nails"]), "the %s costs only stone, clay, logs, hide and bronze (%s)" % [st, str(ids)])

	check(smithy_iron == 0 and saw_iron > 0 and anvil_iron > 0, "the Improved smithy costs no iron; the saw (%d) and the Iron anvil (%d) are made of iron: %d ore to dig" % [saw_iron, anvil_iron, ore_n])

	# 1. Bog iron with a wooden spade.
	items.give(1, items.table.number_of("wooden_spade"), 1)

	for n in range(200):
		if have("iron_ore") >= ore_n:
			break

		items._last_dig.clear()
		items.action(1, Net.ACT_DIG, HeldTool.slot_of(items, "spade"), 0, 0, HERE + Vector3(1.0, 0.0, 0.0))
		items.inventory_of(1).remove(items.table.number_of("soil"), have("soil"))

	check(have("iron_ore") >= ore_n, "1. a wooden spade digs %d bog iron ore out of wet ground (%d)" % [ore_n, have("iron_ore")])

	# 2. Charcoal at a lit campfire.
	items._items[items._next_id] = {"number": items.table.number_of("campfire_kit"), "count": 1, "pos": FIRE_AT, "left": 1.0e9, "fire": {"state": 1, "burn_left": 1.0e6, "covered": false, "recheck": 5.0}}
	items._next_id += 1
	var charcoal_crafts: int = ceili(float(fuel_n) / float(gives_of("charcoal")))
	items.give(1, items.table.number_of("firewood"), charcoal_crafts * need_of("charcoal", "firewood"))
	craft("charcoal", charcoal_crafts, 120 * charcoal_crafts)
	check(have("charcoal") >= fuel_n, "2. firewood burns to %d charcoal at the campfire (%d needed)" % [have("charcoal"), fuel_n])

	# 3. The iron: not at the Primitive smelter; at the Improved smelter only with its bellows worked.
	items.give(1, items.table.number_of("wooden_hammer"), 1)
	var primitive: int = build("smelter", PRIMITIVE_AT)
	check(primitive >= 0, "3a. a Primitive smelter stands, built from %s" % str(blueprint_of("smelter").get("cost", [])))
	items.report_position(1, PRIMITIVE_AT + Vector3(1.5, 0.0, 0.0))
	check(put_in(primitive, "iron_ore", 1) == 0, "3b. the Primitive smelter takes no iron ore (master s2.7 item 1)")
	items.report_position(1, HERE)
	var smelter: int = build("improved_smelter", SMELTER_AT)
	check(smelter >= 0, "3c. an Improved smelter stands, built from %s" % str(blueprint_of("improved_smelter").get("cost", [])))
	var charcoal_in: int = put_in(smelter, "charcoal", ore_n)
	var ore_in: int = put_in(smelter, "iron_ore", ore_n)
	check(charcoal_in == ore_n and ore_in == ore_n, "3d. its hopper takes %d Charcoal and its input %d Iron ore" % [charcoal_in, ore_in])
	var unmanned_s: float = float(items._structures["improved_smelter"]["smelt"]["ingot_s"]) * 3.0

	for t in range(int(unmanned_s)):
		items.tick(1.0)

	check(items._chests[int(items._items[smelter]["struct"]["uid"])].count_of(items.table.number_of("iron_ingot")) == 0, "3e. nobody at the bellows: no iron in %d s" % int(unmanned_s))
	items.report_position(1, (items._items[smelter]["pos"] as Vector3) + Vector3(-1.5, 0.0, 0.0))   # beside it: E reaches 3 m (use_reach_m)
	var goal_counts: Dictionary = items._goal_state_of(1).get("goal_counts", {})
	var bellows_before: int = int(goal_counts.get("event:bellows_iron", 0))
	items.action(1, Net.ACT_USE_STRUCT, smelter, 0, 0, Vector3.ZERO)   # E: work the bellows
	var manned_s: float = float(items._structures["improved_smelter"]["smelt"]["ingot_s"]) / float(items._structures["improved_smelter"]["smelt"]["bellows_speed"])

	for t in range(int(ceil(manned_s * float(ore_n))) + 2):
		items.tick(1.0)

	take_all(smelter)
	items.action(1, Net.ACT_USE_STRUCT, smelter, 0, 0, Vector3.ZERO)   # E again, still beside it: leave the bellows
	items.report_position(1, HERE)
	check(have("iron_ingot") >= ore_n and not items._smelters.bellows_worked(smelter), "3f. working the bellows it smelts bog iron into %d Iron ingots in its rack, about %.2f s each (%d); E again leaves them" % [ore_n, manned_s, have("iron_ingot")])
	check(int(items._goal_state_of(1).get("goal_counts", {}).get("event:bellows_iron", 0)) == bellows_before + 1, "3g. working the bellows through an iron smelt counts the goal event bellows_iron once for the worker, not once an ingot (%d ingots)" % ore_n)

	# 4. The Improved smithy from stones, clay, logs and bronze (given: the bronze route is test_bronze_path); it must burn to craft.
	items.vitals_of(1)["weight"] = 5000.0   # the ticks above may have drawn the body weight down (empty stomach): the given build cost must fit the pack
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

	check(smithy_id >= 0 and have("iron_ingot") == iron_before, "4a. the Improved smithy stands, built without iron")
	var charcoal_n: int = have("charcoal")
	items.inventory_of(1).remove(items.table.number_of("charcoal"), charcoal_n)
	items.give(1, items.table.number_of("stick"), need_of("hand_saw", "stick"))
	craft("hand_saw", 1, 60)
	check(have("hand_saw") == 0 and have("iron_ingot") == iron_before and not bool(items._items[smithy_id]["struct"].get("lit", false)), "4b. a cold Smithy and no fuel: no saw, nothing taken (%d ingots)" % have("iron_ingot"))
	items.inventory_of(1).add(items.table.number_of("charcoal"), charcoal_n)

	# 5. The Iron - Saw at the burning Smithy.
	craft("hand_saw", 1, 120)
	check(bool(items._items[smithy_id]["struct"].get("lit", false)) and have("charcoal") == charcoal_n - 1, "5a. the craft fires the Smithy with one charcoal")
	check(have("hand_saw") == 1 and have("saw_blade") == 0, "5b. the Iron - Saw is made at the Improved smithy from iron and wood, with no Saw blade")
	var wear_cfg: Dictionary = SmithingRules.cfg().get("station_wear", {})
	var per_craft: float = float(wear_cfg.get("per_craft", 1.0))
	var iron_x: float = float(wear_cfg.get("iron_on_bronze", 1.0))
	check(iron_x > 1.0 and is_equal_approx(items._smithies.wear_of(smithy_id), per_craft * iron_x), "5c. the iron saw wore the bronze anvil %.1f (iron on bronze: x%.1f)" % [items._smithies.wear_of(smithy_id), iron_x])

	# 6. Planks and Hardwood boards with the saw.
	items.inventory_of(1).add(items.table.number_of("log_spruce"), 1)
	items.inventory_of(1).add(items.table.number_of("log_oak"), 1)
	craft("lumber_by_hand", 1, 60)
	craft("hardwood_board_by_hand", 1, 60)
	check(have("lumber") == 6 and have("hardwood_board") == 4, "6. the saw gives 6 Planks from a spruce log and 4 Hardwood boards from an oak log (%d, %d)" % [have("lumber"), have("hardwood_board")])

	# 7. The Iron anvil at the Improved smithy; iron work wears its bronze anvil faster than bronze work.
	items.give(1, items.table.number_of("log"), need_of("iron_anvil_part", "log"))
	craft("iron_anvil_part", 1, 120)
	check(have("iron_anvil_part") == 1, "7a. the Iron anvil is forged at the Improved smithy from %d Iron ingots" % anvil_iron)
	check(is_equal_approx(items._smithies.wear_of(smithy_id), 2.0 * per_craft * iron_x), "7b. its anvil wore %.1f more" % (per_craft * iron_x))
	items.give(1, items.table.number_of("bronze_ingot"), need_of("bronze_knife", "bronze_ingot"))
	items.give(1, items.table.number_of("stick"), need_of("bronze_knife", "stick"))
	craft("bronze_knife", 1, 60)
	check(have("bronze_knife") == 1 and is_equal_approx(items._smithies.wear_of(smithy_id), 2.0 * per_craft * iron_x + per_craft), "7c. a Bronze - Knife there (bronze work) wears it only %.1f" % per_craft)
	items.save()
	items._finish_writer()
	var again = ItemsScript.new()
	again.send_full = func(_p, _b): pass
	again.send_slots = func(_p, _b): pass
	again.send_world_items = func(_p, _a, _r): pass
	again.ground_height = func(_x, _z): return 10.0
	again.setup(ItemTableScript.load_default(), dir)
	var again_smithy: int = -1   # world ids are handed out again on load; the store uid (and the kind here) stays

	for id in again._items:
		if again._items[id].has("struct") and str(again._items[id]["struct"]["kind"]) == "blacksmithy" and not again._items[id]["struct"].has("site"):
			again_smithy = int(id)

	check(again_smithy >= 0 and is_equal_approx(again._smithies.wear_of(again_smithy), items._smithies.wear_of(smithy_id)), "7d. save and load keep the anvil's wear (%.1f)" % (again._smithies.wear_of(again_smithy) if again_smithy >= 0 else -1.0))
	again._finish_writer()

	print("iron saw route: %d failures" % failures)
	items._finish_writer()
	quit(1 if failures > 0 else 0)
