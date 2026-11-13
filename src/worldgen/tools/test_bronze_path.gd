extends SceneTree

# The bronze path runs on the live data (Steve 10 Nov 2026, /mnt/project-files/steve/pickaxe_path.md): every step through the real server, the
# real recipes, blueprints and boulders.json, nothing stood in. A step that refuses prints what the server said.
#   1. a Stone - Pickaxe by hand (stick, stone, twine);
#   2. copper ore and tin ore picked out of a copper and a tin outcrop with it (boulders.json piece share as shipped);
#   3. a Stone - Forge from its blueprint with a wooden hammer;
#   4. charcoal at a lit campfire;
#   5. copper and tin ingots smelted at the Stone - Forge;
#   6. bronze ingots; 7. a Bronze - Pickaxe at the forge (every amount read from the live recipes, so either bronze ratio passes);
#   8. the bronze pick takes iron ore out of an iron outcrop, which the stone pick cannot.
#   godot --headless --path . --script res://src/worldgen/tools/test_bronze_path.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const HERE := Vector3(700.0, 10.0, 700.0)
const FORGE_AT := Vector3(700.0, 10.0, 702.5)
const FIRE_AT := Vector3(697.5, 10.0, 700.0)
const OUTCROP_AT := Vector3(702.0, 11.0, 699.0)
const OUTCROP_ID := 910001

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


func give(id: String, n: int) -> void:
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of(id), 0, n, Vector3.ZERO)


# How many of item `id` the recipe `recipe_id` needs (0 when none), from the live recipe table.
func need_of(recipe_id: String, id: String) -> int:
	for need in items.recipes.recipe(recipe_number(recipe_id)).get("needs", []):
		if int(need[0]) == items.table.number_of(id):
			return int(need[1])

	return 0


func gives_of(recipe_id: String) -> int:
	var gives: Array = items.recipes.recipe(recipe_number(recipe_id)).get("gives", [0, 1])
	return maxi(int(gives[1]), 1) if gives.size() > 1 else 1


func recipe_number(id: String) -> int:
	for n in items.recipes.numbers():
		if str(items.recipes.recipe(int(n)).get("id", "")) == id:
			return int(n)

	return 0


# Queues `times` of the recipe and runs the server clock until it is done (or `seconds` pass).
func craft(id: String, times: int, seconds: int) -> void:
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, recipe_number(id), 0, times, Vector3.ZERO)

	for s in range(seconds):
		items.tick(1.0)

	collect()


# An outcrop boulder of `ore` (as _lay_out_boulders makes one), hit up to `blows` times or until `want` of `item` are in the pack.
# Station products stay in the station (master s2.5, M001-T18): after a craft the player takes them out of their own station stores beside
# them through the real server path (open, Take all, close), as a player does.
func collect() -> void:
	for id in items._items.keys():
		var it: Dictionary = items._items.get(id, {})

		if it.has("struct") and items._is_station_store(it) and str(it["struct"].get("owner", "")) == items.key_of(1) and (it["pos"] as Vector3).distance_to(items.position_of(1)) <= 4.0:
			items.action(1, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)
			items.action(1, Net.ACT_BULK, ItemsScript.BULK_TAKE_ALL, 0, 0, Vector3.ZERO)
			items.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)


func pick_out(ore: String, item: String, want: int, blows: int) -> void:
	items._items[OUTCROP_ID] = {"number": 0, "count": 5000, "pos": OUTCROP_AT, "left": 1.0e9, "scatter": items.BOULDER_KEY | 11, "boulder": {"radius": 1.0, "yaw": 0.0, "total": 5000, "ore": ore}}

	for k in range(blows):
		if have(item) >= want:
			break

		items._last_hit.clear()
		var pick: int = items.inventory_of(1).numbers.find(items.table.number_of("bronze_pickaxe"))   # the best pick made so far is the one in hand (protocol 115)

		if pick < 0:
			pick = items.inventory_of(1).numbers.find(items.table.number_of("stone_pickaxe"))

		items.action(1, Net.ACT_HIT, OUTCROP_ID, Net.HIT_BOULDER, pick + 1, Vector3.ZERO)
		# The plain stones the blows break off are not under test: dropping them keeps a run of bad ore luck from filling the carry limit
		# ("Too heavy to carry any more", 3 of 17 runs on 12 Nov 2026), which left the ore steps short.
		items.inventory_of(1).remove(items.table.number_of("stone"), have("stone"))

	items._items.erase(OUTCROP_ID)


func _init() -> void:
	var dir: String = "user://test_bronze_path"
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
	items.peer_connected_hello(1, "bronzepath01")
	items.report_position(1, HERE)
	items.vitals_of(1)["weight"] = 5000.0   # the stones the picks break out are heavy; carrying is not under test
	var shipped_share: float = float(items._boulder_cfg.get("ore", {}).get("piece_share", 0.0))
	check(shipped_share > 0.0, "boulders.json ships an ore piece share (%.2f)" % shipped_share)

	# 1. Stone - Pickaxe by hand.
	give("stick", 2)
	give("stone", 3)
	give("twine", 2)
	craft("stone_pickaxe", 1, 60)
	check(have("stone_pickaxe") == 1, "1. a Stone - Pickaxe is made by hand")

	# The amounts follow the live recipes, so the test holds at either bronze ratio (1 + 1 -> 2 before Jamie's #993, 3 + 1 -> 4 after).
	var pick_bronze: int = need_of("bronze_pickaxe", "bronze_ingot")
	var bronze_crafts: int = ceili(float(pick_bronze) / float(gives_of("bronze_ingot")))
	var copper_ingots: int = bronze_crafts * need_of("bronze_ingot", "copper_ingot")
	var tin_ingots: int = bronze_crafts * need_of("bronze_ingot", "tin_ingot")
	var copper_smelts: int = ceili(float(copper_ingots) / float(gives_of("smelt_copper")))
	var tin_smelts: int = ceili(float(tin_ingots) / float(gives_of("smelt_tin")))
	var copper_ore_n: int = copper_smelts * need_of("smelt_copper", "copper_ore")
	var tin_ore_n: int = tin_smelts * need_of("smelt_tin", "tin_ore")
	var fuel_n: int = copper_smelts * need_of("smelt_copper", "fuel") + tin_smelts * need_of("smelt_tin", "fuel")
	var charcoal_crafts: int = ceili(float(fuel_n) / float(gives_of("charcoal")))
	print("plan: %d bronze ingots for the pick = %d bronze crafts = %d copper + %d tin ingots = %d copper ore + %d tin ore, %d fuel" % [pick_bronze, bronze_crafts, copper_ingots, tin_ingots, copper_ore_n, tin_ore_n, fuel_n])
	check(pick_bronze > 0 and copper_ingots > 0 and tin_ingots > 0 and copper_ore_n > 0 and tin_ore_n > 0, "the recipes for the path are all there")

	# 2. Copper and tin ore from outcrops with the stone pick.
	pick_out("copper", "copper_ore", copper_ore_n, 1500)
	check(have("copper_ore") >= copper_ore_n, "2a. the stone pick takes %d copper ore out of a copper outcrop (%d)" % [copper_ore_n, have("copper_ore")])
	pick_out("tin", "tin_ore", tin_ore_n, 1500)
	check(have("tin_ore") >= tin_ore_n, "2b. and %d tin ore out of a tin outcrop (%d)" % [tin_ore_n, have("tin_ore")])
	pick_out("iron", "iron_ore", 1, 60)
	check(have("iron_ore") == 0, "2c. it takes no iron ore out of an iron outcrop")

	# 3. Stone - Forge from its blueprint, with the materials its row asks for.
	var forge_bp: Dictionary = {}

	for number in items._blueprints:
		if str(items._blueprints[number].get("structure", "")) == "stone_forge":
			forge_bp = items._blueprints[number]

	check(not forge_bp.is_empty(), "3a. the Stone - Forge has a blueprint")

	if forge_bp.is_empty():
		quit(1)
		return

	give("wooden_hammer", 1)

	for need in forge_bp["cost"]:
		give(str(need[0]), int(need[1]))

	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(forge_bp["number"]), 0, 0, FORGE_AT)
	var forge_id: int = -1

	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == "stone_forge" and not items._items[id]["struct"].has("site"):
			forge_id = int(id)

	check(forge_id >= 0, "3b. the Stone - Forge stands (a wooden hammer, %s)" % str(forge_bp["cost"]))
	check(items.station_near(1, "forge", 1), "3c. it serves as a forge, level 1")

	# 3d. The Smelter beside it (Mission 001 phase 2b, master s2.7 item 3): smelting and the bronze alloy moved off the forge, which only shapes bronze.
	var smelter_bp: Dictionary = {}

	for number in items._blueprints:
		if str(items._blueprints[number].get("structure", "")) == "smelter":
			smelter_bp = items._blueprints[number]

	for need in smelter_bp.get("cost", []):
		give(str(need[0]), int(need[1]))

	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(smelter_bp.get("number", 0)), 0, 0, HERE + Vector3(3.0, 0.0, -0.5))
	check(not smelter_bp.is_empty() and items.station_near(1, "smelter", 1), "3d. a Smelter stands beside the forge, from its stone-and-clay blueprint (%s)" % str(smelter_bp.get("cost", [])))
	check(not items.station_near(1, "smelter", 1) or items.recipes.recipe(recipe_number("smelt_copper")).get("station", "") == "smelter", "3e. copper is smelted at the Smelter, not the forge")

	# 4. Charcoal at a lit campfire, one fuel a smelt.
	items._items[items._next_id] = {"number": items.table.number_of("campfire_kit"), "count": 1, "pos": FIRE_AT, "left": 1.0e9, "fire": {"state": 1, "burn_left": 1.0e6, "covered": false, "recheck": 5.0}}
	items._next_id += 1
	give("firewood", charcoal_crafts * need_of("charcoal", "firewood"))
	craft("charcoal", charcoal_crafts, 120 * charcoal_crafts)
	check(have("charcoal") >= fuel_n, "4. %d firewood make %d charcoal at the campfire (%d needed)" % [charcoal_crafts * need_of("charcoal", "firewood"), have("charcoal"), fuel_n])

	# 5. Copper and tin ingots at the Smelter, charcoal as the fuel.
	craft("smelt_copper", copper_smelts, 120 * copper_smelts)
	check(have("copper_ingot") >= copper_ingots, "5a. %d copper ore make %d copper ingots (%d)" % [copper_ore_n, copper_ingots, have("copper_ingot")])
	craft("smelt_tin", tin_smelts, 120 * tin_smelts)
	check(have("tin_ingot") >= tin_ingots, "5b. %d tin ore make %d tin ingots (%d)" % [tin_ore_n, tin_ingots, have("tin_ingot")])

	# 6. Bronze ingots: enough for the pick.
	craft("bronze_ingot", bronze_crafts, 120 * bronze_crafts)
	check(have("bronze_ingot") >= pick_bronze, "6. %d bronze crafts make %d bronze ingots (%d needed)" % [bronze_crafts, have("bronze_ingot"), pick_bronze])

	# 7. The Bronze - Pickaxe at the forge.
	give("stick", need_of("bronze_pickaxe", "stick"))
	craft("bronze_pickaxe", 1, 200)
	check(have("bronze_pickaxe") == 1, "7. a Bronze - Pickaxe is made at the Stone - Forge")
	var inv = items.inventory_of(1)
	var bronze_slot: int = inv.numbers.find(items.table.number_of("bronze_pickaxe"))
	check(bronze_slot >= 0 and inv.on_hotbar(bronze_slot), "7b. it goes into a hotbar slot by itself (a new tool)")

	if bronze_slot >= 0 and not inv.on_hotbar(bronze_slot):
		items.action(1, Net.ACT_MOVE, bronze_slot, 9, 0, Vector3.ZERO)   # as a player would drag it, so step 8 still runs

	# 8. Iron ore out of an iron outcrop with it.
	pick_out("iron", "iron_ore", 4, 400)
	check(have("iron_ore") >= 4, "8. the bronze pick takes iron ore out of an iron outcrop (%d)" % have("iron_ore"))

	print("test_bronze_path: %d failures" % failures)
	items._finish_writer()
	quit(1 if failures > 0 else 0)
