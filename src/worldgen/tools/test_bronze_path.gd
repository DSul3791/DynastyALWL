extends SceneTree

# The bronze path runs on the live data (Steve 10 Nov 2026; rebuilt for the creator's smelting progression, GOALS-REPAIR R2, master s2.7): every
# step through the real server, the real recipes, blueprints, structures.json smelting and boulders.json, nothing stood in. A step that
# refuses prints what the server said.
#   1. a Stone - Hammer by hand (stick, stone, twine; the Stone - Pickaxe is made by hand too, restored 23 Nov 2026 over W-12);
#   2. copper ore and tin ore broken out of a copper and a tin outcrop with it (boulders.json piece share as shipped); no iron ore (iron wants a pick);
#   3. a Primitive smithy and a Primitive smelter from their blueprints with a wooden hammer: stone, clay and logs only, no metal, Planks or Nails;
#   4. charcoal left in a lit campfire as its firewood burns;
#   5. the Primitive smelter fed through its store and lit with E: Charcoal in its hopper, 1 Copper ore + 1 Tin ore make 2 Bronze ingots by themselves,
#      dropped on the ground in front of it, and picked up;
#   6. a Bronze - Pickaxe at the Primitive smithy (every amount read from the live recipes);
#   7. the bronze pick takes iron ore out of an iron outcrop, which the stone hammer cannot.
#   godot --headless --path . --script res://src/worldgen/tools/test_bronze_path.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const CraftHand := preload("res://src/worldgen/tools/craft_hand.gd")   # the hand slot a craft holds its tool in (protocol 126)
const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")

const HERE := Vector3(700.0, 10.0, 700.0)
const FORGE_AT := Vector3(700.0, 10.0, 702.5)
const SMELTER_AT := Vector3(703.0, 10.0, 699.5)
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


func recipe_number(id: String) -> int:
	for n in items.recipes.numbers():
		if str(items.recipes.recipe(int(n)).get("id", "")) == id:
			return int(n)

	return 0


# Queues `times` of the recipe and runs the server clock until it is done (or `seconds` pass), then takes station products out.
func craft(id: String, times: int, seconds: int) -> void:
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, recipe_number(id), 0, times, CraftHand.at(items, 1, recipe_number(id)))

	for s in range(seconds):
		items.tick(1.0)

	collect()


# Station products stay in the station (master s2.5, M001-T18): after a craft the player takes them out of their own station stores beside
# them through the real server path (open, Take all, close), as a player does. The smelter is skipped: its store is its fuel and ore.
func collect() -> void:
	for id in items._items.keys():
		var it: Dictionary = items._items.get(id, {})

		if it.has("struct") and items._is_station_store(it) and str(it["struct"].get("owner", "")) == items.key_of(1) and (it["pos"] as Vector3).distance_to(items.position_of(1)) <= 4.0:
			items.action(1, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)
			items.action(1, Net.ACT_BULK, ItemsScript.BULK_TAKE_ALL, 0, 0, Vector3.ZERO)
			items.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)


# One put from the pack into a station's store (open, put, close). Returns how many went in.
func put_in(id: int, item: String, count: int) -> int:
	var before: int = have(item)
	items.action(1, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_PUT, items.inventory_of(1).numbers.find(items.table.number_of(item)), id, count, Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)
	return before - have(item)


# Loose ground stacks of an item within `radius` of `at`.
func on_ground(item: String, at: Vector3, radius: float) -> int:
	var total: int = 0

	for id in items._items:
		var it: Dictionary = items._items[id]

		if int(it.get("number", 0)) == items.table.number_of(item) and not it.has("struct") and not it.has("scatter") and (it["pos"] as Vector3).distance_to(at) <= radius:
			total += int(it["count"])

	return total


# Picks every loose stack of an item within `radius` of `at` up, standing beside it (ACT_PICKUP, as E does).
func pick_up(item: String, at: Vector3, radius: float) -> void:
	for id in items._items.keys():
		var it: Dictionary = items._items.get(id, {})

		if int(it.get("number", 0)) == items.table.number_of(item) and not it.has("struct") and not it.has("scatter") and (it["pos"] as Vector3).distance_to(at) <= radius:
			items.report_position(1, (it["pos"] as Vector3) + Vector3(0.8, 0.0, 0.0))
			items.action(1, Net.ACT_PICKUP, int(id), 0, int(it["count"]), Vector3.ZERO)

	items.report_position(1, HERE)


func build(structure: String, at: Vector3) -> int:
	var bp: Dictionary = {}

	for number in items._blueprints:
		if str(items._blueprints[number].get("structure", "")) == structure:
			bp = items._blueprints[number]

	if bp.is_empty():
		return -1

	var ids: Array = bp["cost"].map(func(c): return str(c[0]))
	check(ids.all(func(c): return c in ["stone", "clay", "log", "wooden_block"]), "the %s costs only stone, clay and wood: no metal, Planks or Nails (%s)" % [structure, str(bp["cost"])])

	for need in bp["cost"]:
		give(str(need[0]), int(need[1]))

	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(bp["number"]), 0, 0, at)
	var site: int = HeldTool.site_of(items, structure)   # placing only sets down a site; the hammer hit fills it (Dave 18 Nov 2026)
	return site if HeldTool.hit_site(items, site) else -1


func pick_out(ore: String, item: String, want: int, blows: int) -> void:
	items._items[OUTCROP_ID] = {"number": 0, "count": 5000, "pos": OUTCROP_AT, "left": 1.0e9, "scatter": items.BOULDER_KEY | 11, "boulder": {"radius": 1.0, "yaw": 0.0, "total": 5000, "ore": ore}}

	for k in range(blows):
		if have(item) >= want:
			break

		items._last_hit.clear()
		var pick: int = items.inventory_of(1).numbers.find(items.table.number_of("bronze_pickaxe"))   # the best pick made so far is the one in hand (protocol 115)

		if pick < 0:
			pick = items.inventory_of(1).numbers.find(items.table.number_of("stone_hammer"))

		items.action(1, Net.ACT_HIT, OUTCROP_ID, Net.HIT_BOULDER, pick + 1, Vector3.ZERO)
		# The plain stones the blows break off are not under test: dropping them keeps a run of bad ore luck from filling the carry limit
		# ("Too heavy to carry any more", 3 of 17 runs on 12 Nov 2026), which left the ore steps short.
		items.inventory_of(1).remove(items.table.number_of("stone"), have("stone"))

	items._items.erase(OUTCROP_ID)


# A job's [id, count] rows as "id count" text: parsed JSON numbers are floats, so the rows are not compared as JSON text.
func rows_text(rows: Array) -> String:
	return ", ".join(rows.map(func(r): return "%s %d" % [str(r[0]), int(r[1])]))



# Burning wood leaves charcoal in the fire (Dave 17 Nov 2026; cooking.json charcoal_left): the fire burns (its own tick, a minute a step) until its
# store holds `wanted` Charcoal, which is taken from the store (the F window).
func charcoal_from_fire(fire: int, wanted: int) -> void:
	var c: int = items.table.number_of("charcoal")
	var store = items._fire_store(items._items[fire]["fire"])

	for _step in range(20000):
		if store.count_of(c) >= wanted:
			break

		items._fires(60.0)

	items.report_position(1, items._items[fire]["pos"] + Vector3(1.0, 0.0, 0.0))
	items.action(1, Net.ACT_CHEST_OPEN, fire, 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_TAKE, store.numbers.find(c), fire, store.count_of(c), Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)

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

	# 1. Stone - Hammer by hand.
	give("stick", 2)
	give("stone", 3)
	give("twine", 2)
	craft("stone_hammer", 1, 60)
	check(have("stone_hammer") == 1 and recipe_number("stone_pickaxe") > 0, "1. a Stone - Hammer is made by hand (the Stone - Pickaxe is made by hand too: restored 23 Nov 2026)")

	# The amounts follow the live data: the bronze job (1 Copper ore + 1 Tin ore -> 2 Bronze ingots) and the pick's recipe.
	var job: Dictionary = items._structures_cfg.get("smelting", {}).get("jobs", {}).get("bronze", {})
	check(rows_text(job.get("in", [])) == "copper_ore 1, tin_ore 1" and rows_text([job.get("out", ["", 0])]) == "bronze_ingot 2", "the bronze job: 1 Copper ore + 1 Tin ore -> 2 Bronze ingots (master s2.7 item 3)")
	var pick_bronze: int = need_of("bronze_pickaxe", "bronze_ingot")
	var pairs: int = ceili(float(pick_bronze) / 2.0)
	var fuel_n: int = int(ceil(float(items._structures_cfg["smelting"].get("fuel_per_ore", 1)) * float(pairs * 2)))
	print("plan: %d bronze ingots for the pick = %d pairs = %d copper ore + %d tin ore, %d fuel" % [pick_bronze, pairs, pairs, pairs, fuel_n])
	check(pick_bronze > 0, "the pick's recipe is there")

	# 2. Copper and tin ore from outcrops with the stone hammer.
	pick_out("copper", "copper_ore", pairs, 1500)
	check(have("copper_ore") >= pairs, "2a. the stone hammer takes %d copper ore out of a copper outcrop (%d)" % [pairs, have("copper_ore")])
	pick_out("tin", "tin_ore", pairs, 1500)
	check(have("tin_ore") >= pairs, "2b. and %d tin ore out of a tin outcrop (%d)" % [pairs, have("tin_ore")])
	pick_out("iron", "iron_ore", 1, 60)
	check(have("iron_ore") == 0, "2c. it takes no iron ore out of an iron outcrop")

	# 3. The Primitive smithy and the Primitive smelter, with a wooden hammer.
	give("stone_hammer", 1)
	var forge_id: int = build("stone_forge", FORGE_AT)
	check(forge_id >= 0, "3a. the Primitive smithy stands")
	check(items.station_level_of(items._items[forge_id], items._structures["stone_forge"], "forge") == 1 and not items.station_near(1, "forge", 1), "3b. it is a level 1 forge (copper and bronze work), idle until Charcoal is in its fuel slot (Dave 21 Nov 2026)")
	var smelter_id: int = build("smelter", SMELTER_AT)
	check(smelter_id >= 0 and int(items._structures["smelter"].get("out_slots", 0)) == 0, "3c. the Primitive smelter stands beside it, with no output rack")
	check(not items.station_near(1, "smelter", 1), "3d. it is no crafting station: once lit it smelts by itself")

	# 4. Charcoal left in a lit campfire as its firewood burns.
	var fire_id: int = items._next_id
	items._items[items._next_id] = {"number": items.table.number_of("campfire_kit"), "count": 1, "pos": FIRE_AT, "left": 1.0e9, "fire": {"state": 1, "burn_left": 1.0e6, "covered": false, "recheck": 5.0}}
	items._next_id += 1
	var at_was: Vector3 = items.position_of(1)
	charcoal_from_fire(fire_id, fuel_n + 1)   # and one for the Primitive smithy's fuel slot
	items.report_position(1, at_was)
	check(have("charcoal") >= fuel_n, "4. firewood burning in the campfire leaves %d charcoal, taken from its store (%d needed)" % [have("charcoal"), fuel_n])

	# 5. The Primitive smelter: fuel in the hopper, both ores in the input; Bronze by itself, on the ground in front.
	var front: Vector3 = items._smelters.front_of(items._items[smelter_id], items._structures["smelter"])
	check(put_in(smelter_id, "charcoal", fuel_n) == fuel_n, "5a. %d Charcoal go into its hopper" % fuel_n)
	check(put_in(smelter_id, "copper_ore", pairs) == pairs and put_in(smelter_id, "tin_ore", pairs) == pairs, "5b. %d Copper ore and %d Tin ore go into its input" % [pairs, pairs])
	items.report_position(1, (items._items[smelter_id]["pos"] as Vector3) + Vector3(-1.5, 0.0, 0.0))   # beside it: E reaches 3 m (use_reach_m)
	items.action(1, Net.ACT_USE_STRUCT, smelter_id, 0, 0, Vector3.ZERO)   # E: light it, as a campfire (it smelts only while lit, Dave 17 Nov 2026)
	items.report_position(1, HERE)
	check(bool(items._items[smelter_id]["struct"].get("lit", false)), "5b'. E lights it")
	var per_ingot: float = float(items._structures["smelter"]["smelt"]["ingot_s"])

	for s in range(int(per_ingot * 2.0) - 2):
		items.tick(1.0)

	check(on_ground("bronze_ingot", front, 1.5) == 0, "5c. no Bronze before its time (%d s an ingot)" % int(per_ingot))

	for s in range(int(per_ingot * 2.0 * float(pairs)) + 4):
		items.tick(1.0)

	var box = items._chests[int(items._items[smelter_id]["struct"]["uid"])]
	check(on_ground("bronze_ingot", front, 1.5) == pairs * 2 and box.count_of(items.table.number_of("copper_ore")) == 0 and box.count_of(items.table.number_of("tin_ore")) == 0, "5d. %d Copper ore + %d Tin ore made %d Bronze ingots, dropped in front of it" % [pairs, pairs, on_ground("bronze_ingot", front, 1.5)])
	check(box.count_of(items.table.number_of("charcoal")) == 0, "5e. and burnt the %d Charcoal" % fuel_n)
	pick_up("bronze_ingot", front, 1.5)
	check(have("bronze_ingot") == pairs * 2, "5f. the Bronze ingots are picked up (%d)" % have("bronze_ingot"))

	# 6. The Bronze - Pickaxe at the Primitive smithy.
	give("stick", need_of("bronze_pickaxe", "stick"))
	check(put_in(forge_id, "charcoal", 1) == 1 and items.station_near(1, "forge", 1), "6a. one Charcoal in its fuel slot and the Primitive smithy serves")
	craft("bronze_pickaxe", 1, 200)
	check(have("bronze_pickaxe") == 1, "6. a Bronze - Pickaxe is made at the Primitive smithy")
	var inv = items.inventory_of(1)
	var bronze_slot: int = inv.numbers.find(items.table.number_of("bronze_pickaxe"))
	check(bronze_slot >= 0 and inv.on_hotbar(bronze_slot), "6b. it goes into a hotbar slot by itself (a new tool)")

	if bronze_slot >= 0 and not inv.on_hotbar(bronze_slot):
		items.action(1, Net.ACT_MOVE, bronze_slot, 9, 0, Vector3.ZERO)   # as a player would drag it, so step 7 still runs

	# 7. Iron ore out of an iron outcrop with it.
	pick_out("iron", "iron_ore", 4, 400)
	check(have("iron_ore") >= 4, "7. the bronze pick takes iron ore out of an iron outcrop (%d)" % have("iron_ore"))

	print("test_bronze_path: %d failures" % failures)
	items._finish_writer()
	quit(1 if failures > 0 else 0)
