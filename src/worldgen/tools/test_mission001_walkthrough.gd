extends SceneTree

# Mission 001 integrated walkthrough (M001-T19; mission brief s9 "Required in-game outcomes" and s12 items 4-8): ONE world on the real server
# (server_items.gd and its helpers, the live data), a new character from nothing to a warehouse, checking the resulting game state at each step:
#   1. early survival: gather by hand, Stone - Axe and Stone - Knife, a Lean-to and a Wicker - Chest from their blueprints, a hunted deer cooked at a
#      campfire and eaten, items stored in the chest;
#   2. wood and metal: bog iron dug with a Wooden spade, charcoal, the Improved smelter and the Smithy, the Smithy fired, an Iron - Saw, Planks and Hardwood
#      boards, nothing bought;
#   3. construction and equipment: Leatherworking table, Loom, Tailor's table; Thread, Leather strap, Fibre cloth, a Fibre - Gambeson; a Rustic - Chest
#      and a Crude - Chair from boards; an iron weapon and an iron armour piece at the Smithy; gambeson + mail worn in layers; a backpack
#      worn (it has no slots: it cannot be opened); wear from use and repair at the station; a Tempered steel item from Blast furnace steel;
#   4. cooking and preservation: Food preparation table, Flatbread, a Sauerkraut batch sealed and matured, Smoked meat, Dried mushrooms, a board set
#      on a Serving platter on the table, a portion eaten, portions conserved;
#   5. food effects: three groups active, XP only when earned, expiry, an energy aid costs no Fitness;
#   6. storage: a chest locked with 0042, a second player refused then let in by the code, the Warehouse desk lists only what each may open, a Handcart
#      built, a loaded Warehouse crate wheeled to a second desk, contents identical and still ageing;
#   7. the world saves and reloads with every placed piece, container and worn item (counts by item before and after).
# Materials the world gives by gathering are given with a comment naming the route test that proves that gathering step, or saying none does (the
# forage gaps listed in docs/ai-team/missions/M001/T19_RESULTS.md). The carry limit is lifted as in the other route tests. Each step prints a STEP
# PASS/FAIL line; the test exits non-zero on any failure.
#   godot --headless --path . --script res://src/worldgen/tools/test_mission001_walkthrough.gd

const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const SmithingRules := preload("res://src/shared/smithing_rules.gd")
const FoodEffects := preload("res://src/shared/food_effects.gd")
const BagRules := preload("res://src/shared/bag_rules.gd")
const Carts := preload("res://src/stream/server_carts.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const DIR := "user://test_mission001_walkthrough"
const KEYS := {1: "walkthrough01", 2: "walkthrough02"}

# The world's places, far enough apart that one place's chests and loose stacks (12 m craft stock) and desks (16 m) never reach another.
const CAMP := Vector3(0.0, 10.0, 0.0)
const FORGE := Vector3(80.0, 10.0, 0.0)
const WORKSHOP := Vector3(80.0, 10.0, 60.0)
const KITCHEN := Vector3(0.0, 10.0, 80.0)
const DEPOT_A := Vector3(-80.0, 10.0, 0.0)
const DEPOT_B := Vector3(-80.0, 10.0, 120.0)
const BOG := Vector3(80.0, 10.0, -40.0)   # wet ground east of the forge: one bog iron deposit to every 10 m along it

var failures: int = 0
var step_failures: int = 0
var step_name: String = ""
var results: Array = []
var items
var inv
var said: Array = []
var clock: Array = [(100.0 * 24.0 + 8.0) * 3600.0]   # game seconds: day 100, 08:00
var unix: Array = [1.0e6]
var chest_sends: Dictionary = {}
var views: Dictionary = {}
var asks: Array = []
var fires: Dictionary = {}   # place name -> world id of its campfire
var bog_cell: int = 0       # the deposit along the bog being dug now


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1
		step_failures += 1
		print("     the server said: ", str(said.slice(maxi(said.size() - 3, 0))) if not said.is_empty() else "nothing")


func step(name: String) -> void:
	end_step()
	step_name = name
	step_failures = 0
	print("--- STEP %s" % name)

	if items != null and items.inventory_of(1) != null:
		print("     pack: ", pack_str())


func end_step() -> void:
	if step_name != "":
		results.append("STEP %s: %s" % [step_name, "PASS" if step_failures == 0 else "FAIL (%d)" % step_failures])
		step_name = ""


func make_server():
	var s = ItemsScript.new()
	s.send_full = func(_p, _b): pass
	s.send_slots = func(_p, _b): pass
	s.send_world_items = func(_p, _a, _r): pass
	s.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	s.send_reject = func(_p, _r): pass
	s.send_notice = func(_p, text): said.append(str(text))
	s.send_worn = func(_p, _numbers, _insts): pass
	s.send_carry = func(_p, _id): pass
	s.send_chest = func(p, _id, _b): chest_sends[p] = int(chest_sends.get(p, 0)) + 1
	s.send_chest_info = func(_p, _id, _k, _m): pass
	s.send_chest_lock = func(_p, _id, _l, _mi, _mo, _w, _a): pass
	s.send_storage_view = func(p, id, numbers, counts, containers):
		var totals: Dictionary = {}
		for i in numbers.size():
			totals[int(numbers[i])] = int(counts[i])
		views[p] = [id, totals, containers]
	s.send_craft_stock = func(_p, _n, _c): pass
	s.send_bulk_done = func(_p, _k, _s, _c, _i): pass
	s.send_craft_queue = func(_p, _e, _l): pass
	s.send_cart_pull = func(_p, _id, _pace): pass
	s.send_items_moved = func(_p, _ids, _at, _yaws): pass
	s.send_food = func(_p, _rows): pass
	s.send_food_ask = func(_p, slot, number, groups): asks.append([slot, number, groups])
	s.ground_height = func(_x, _z): return 10.0
	s.floor_below = floor_below
	s.water_depth_at = func(_pos: Vector3) -> float: return 0.0
	s.trunks_near = func(_point: Vector3, _radius: float) -> Array: return []
	s.cover_at = func(_p): return 1.0
	s.game_seconds = func(): return clock[0]
	s.unix_now = func(): return unix[0]
	s.skill_level = func(_p, _s): return 1.0
	s.dig_ground = func(_centre, _radius): return null
	s.ground_material = func(_x, _z): return "peat"
	s.bog_deposit_at = func(x, z, _cfg_in): return {"key": "%d,%d" % [floori(x / 10.0), floori(z / 10.0)], "size": 60, "edge": true} if z < BOG.z + 5.0 and z > BOG.z - 5.0 else {}
	s.setup(ItemTableScript.load_default(), DIR)
	s.admin_mode_on = func(_p): return false
	s._vitals_cfg["eat_pace_ms"] = 0
	return s


# terrain_server._floor_below's walk (5 cm steps down to the first solid point) over the flat stand-in ground (test_handcart's helper).
func floor_below(from: Vector3) -> float:
	var y: float = from.y + 0.05

	for k in range(480):
		if y < 10.0:
			return y + 0.05

		y -= 0.05

	return NAN


func join(peer: int, at: Vector3) -> void:
	items.peer_connected_hello(peer, KEYS[peer])
	items.report_position(peer, at)
	items.vitals_of(peer)["weight"] = 5000.0   # body weight sets the carry limit: carrying is checked through the backpack in step 3, not the limit


func n(id: String) -> int:
	return items.table.number_of(id)


func have(id: String, peer: int = 1) -> int:
	return items.inventory_of(peer).count_of(n(id))


func slot_of(id: String, peer: int = 1) -> int:
	return items.inventory_of(peer).numbers.find(n(id))


func go(at: Vector3, peer: int = 1) -> void:
	items.report_position(peer, at)


func recipe_number(id: String) -> int:
	for r in items.recipes.numbers():
		if str(items.recipes.recipe(int(r)).get("id", "")) == id:
			return int(r)

	return 0


func recipe(id: String) -> Dictionary:
	return items.recipes.recipe(recipe_number(id))


func need_of(recipe_id: String, id: String) -> int:
	for need in recipe(recipe_id).get("needs", []):
		if int(need[0]) == n(id):
			return int(need[1])

	return 0


func gives_of(recipe_id: String) -> int:
	return int(recipe(recipe_id).get("gives", [0, 1])[1])


func crafts_for(recipe_id: String, wanted: int) -> int:
	return ceili(float(wanted) / float(gives_of(recipe_id)))


func blueprint_of(structure: String) -> Dictionary:
	for number in items._blueprints:
		if str(items._blueprints[number].get("structure", "")) == structure:
			return items._blueprints[number]

	return {}


func cost_of(structure: String, id: String) -> int:
	for c in blueprint_of(structure).get("cost", []):
		if str(c[0]) == id:
			return int(c[1])

	return 0


# The player works between meals: the clock runs a server tick a second and, every game minute, they eat and drink from their own food (the vitals
# are not under test here; test_first_hour covers the curve). The carry limit stays lifted (as in the other route tests: the vitals tick settles
# the body weight back to its range after a meal); the trips a real 75 kg character would make are not walked here.
func run(seconds: float) -> void:
	for s in range(int(ceil(seconds))):
		clock[0] += items.GAME_RATE
		unix[0] += 1.0
		items.tick(1.0)

		if s % 60 == 0:
			for p in items._peer_key:
				var v: Dictionary = items.vitals_of(p)
				v["fed"] = 2000.0
				v["wet"] = 2000.0
				v["energy"] = 100.0
				v["weight"] = 5000.0


func craft(id: String, times: int, seconds: float = -1.0, variant: int = 0) -> void:
	while times > ItemsScript.CRAFT_QUEUE_MAX_COUNT:   # one queue entry holds at most 20 crafts: a player queues the rest again
		craft(id, ItemsScript.CRAFT_QUEUE_MAX_COUNT, -1.0, variant)
		times -= ItemsScript.CRAFT_QUEUE_MAX_COUNT

	var r: Dictionary = recipe(id)

	if seconds < 0.0:
		seconds = float(r.get("craft_s", 10.0)) * float(times) * SmithingRules.time_mult(variant) + 4.0

	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, recipe_number(id), variant, times, Vector3.ZERO)
	var waited: float = 0.0

	while waited < seconds * 3.0 + 30.0 and not items.craft_queue_of(1).is_empty():   # the crafter's pace may be slower than the recipe time
		run(5.0)
		waited += 5.0

	collect()

	for k in range(items.craft_queue_of(1).size()):   # a craft still waiting would hold up every later one: cancel it (refunded); its check then fails alone
		items.action(1, Net.ACT_CRAFT_CANCEL, 0, 0, 0, Vector3.ZERO)


# Station products stay in the station (master s2.5, M001-T18): the player takes them out of their own station stores beside them (open, Take all,
# close), as a player does.
func collect() -> void:
	for id in items._items.keys():
		var it: Dictionary = items._items.get(id, {})

		if it.has("struct") and items._is_station_store(it) and str(it["struct"].get("owner", "")) == items.key_of(1) and (it["pos"] as Vector3).distance_to(items.position_of(1)) <= 4.0:
			items.action(1, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)
			items.action(1, Net.ACT_BULK, ItemsScript.BULK_TAKE_ALL, 0, 0, Vector3.ZERO)
			items.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)


func standing_at(structure: String, at: Vector3) -> int:
	for id in items._items:
		var it: Dictionary = items._items[id]

		if it.has("struct") and str(it["struct"]["kind"]) == structure and not it["struct"].has("site") and Vector2(it["pos"].x - at.x, it["pos"].z - at.z).length() < 0.6:
			return int(id)

	return -1


# Builds from the blueprint with the hammer in the hand bar: the pack must give exactly the cost, and the piece must stand.
func build(structure: String, at: Vector3, what: String) -> int:
	var bp: Dictionary = blueprint_of(structure)
	var before: Dictionary = {}

	for c in bp.get("cost", []):
		before[str(c[0])] = have(str(c[0]))

	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(bp.get("number", 0)), 0, 0, at)
	var id: int = standing_at(structure, at)
	var spent: bool = bp.get("cost", []).all(func(c): return have(str(c[0])) == int(before[str(c[0])]) - int(c[1]))
	check(id >= 0 and spent, "%s: the %s stands, built from its blueprint %s" % [what, structure, str(bp.get("cost", []))])

	if id < 0 or not spent:
		print("     the pack held %s" % str(before))

	return id


# Gives what a blueprint costs, for materials the world provides by gathering (each call says which test proves the gathering).
func give_cost(structure: String, only: Array) -> void:
	for c in blueprint_of(structure).get("cost", []):
		if str(c[0]) in only:
			items.give(1, n(str(c[0])), int(c[1]))


func give_needs(recipe_id: String, only: Array, times: int = 1) -> void:
	for need in recipe(recipe_id).get("needs", []):
		if items.table.id_of(int(need[0])) in only:
			items.give(1, int(need[0]), int(need[1]) * times)


func pick_up_all(rounds: int = 20) -> void:
	for _pass in range(rounds):   # a heap gives a handful at a time
		for id in items._items.keys():
			if items._items.has(id) and not items._items[id].has("scatter") and not items._items[id].has("struct") and not items._items[id].has("fire") and not items._items[id].has("tree"):
				items.action(1, Net.ACT_PICKUP, id, 0, 0, Vector3.ZERO)


# A campfire kit made by hand, placed and lit with tinder from the pack, and fed firewood through its store (the F window) so it burns through a job.
func campfire_at(place: String, at: Vector3) -> int:
	give_needs("campfire", ["stick", "stone"])   # sticks and stones lie about (test_first_hour gathers them by hand)
	craft("campfire", 1)
	items.place_item(1, n("campfire_kit"), at, 0)
	var fire: int = -1

	for id in items._items:
		if items._items[id].has("fire") and (items._items[id]["pos"] as Vector3).distance_to(at) < 1.0:
			fire = int(id)

	if fire >= 0:
		items.give(1, n("plant_fibre"), 2)   # tinder: plant fibre (test_first_hour gathers it)
		items.action(1, Net.ACT_LIGHT, fire, 0, 0, Vector3.ZERO)

	fires[place] = fire
	check(fire >= 0 and items.fire_is_lit(int(items._items[fire]["fire"]["state"])), "a campfire is made by hand, placed and lit at the %s" % place)
	return fire


func feed(place: String, firewood: int) -> void:
	var fire: int = int(fires.get(place, -1))

	if fire < 0 or not items._items.has(fire):
		return

	items.give(1, n("firewood"), firewood)   # firewood split at a chopping block (test_first_town, test_lumber_route)
	items.action(1, Net.ACT_CHEST_OPEN, fire, 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_PUT, slot_of("firewood"), fire, firewood, Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)

	if not items.fire_is_lit(int(items._items[fire]["fire"]["state"])):
		items.give(1, n("plant_fibre"), 1)
		items.action(1, Net.ACT_LIGHT, fire, 0, 0, Vector3.ZERO)


# Iron made the wilderness way (step 2's route): bog ore dug with the spade at the forge yard, charcoal at its campfire, smelted by the Improved
# smelter while the player works its bellows (master s2.7 items 3 and 4: 1 Iron ore makes 1 Iron ingot), a hopper and an input load at a time.
func make_iron(wanted: int) -> bool:
	go(FORGE)
	var ore_n: int = maxi(wanted - have("iron_ingot"), 0)

	if ore_n == 0:
		return true

	var dry: int = 0

	for k in range(ore_n * 20):
		if have("iron_ore") >= ore_n or bog_cell > 40:
			break

		var spot: Vector3 = BOG + Vector3(10.0 * float(bog_cell) + 5.0, 0.0, 0.0)
		go(spot)
		var before: int = have("iron_ore")
		items._last_dig.clear()
		items.action(1, Net.ACT_DIG, HeldTool.slot_of(items, "spade"), 0, 0, spot + Vector3(1.0, 0.0, 0.0))
		items.inventory_of(1).remove(n("soil"), have("soil"))   # the peat and soil dug with it are left in the bog
		dry = dry + 1 if have("iron_ore") == before else 0

		if dry >= 3:   # this deposit is dug out: on along the bog to the next
			bog_cell += 1
			dry = 0

	go(FORGE)
	var smelt: Dictionary = items._structures["improved_smelter"]["smelt"]
	var per_ore: float = float(items._structures_cfg["smelting"].get("fuel_per_ore", 1))
	make_charcoal(int(ceil(per_ore * float(ore_n))))
	var load_n: int = mini(int(smelt["input"]), int(floor(float(smelt["hopper"]) / maxf(per_ore, 0.01))))

	while have("iron_ore") > 0 and smelter >= 0:
		var ore: int = mini(have("iron_ore"), load_n)
		var ore_before: int = have("iron_ore")
		var fuel: int = mini(have("charcoal"), int(ceil(per_ore * float(ore))))
		items.action(1, Net.ACT_CHEST_OPEN, smelter, 0, 0, Vector3.ZERO)
		items.action(1, Net.ACT_CHEST_PUT, slot_of("charcoal"), smelter, fuel, Vector3.ZERO)
		items.action(1, Net.ACT_CHEST_PUT, slot_of("iron_ore"), smelter, ore, Vector3.ZERO)
		items.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)
		go((items._items[smelter]["pos"] as Vector3) + Vector3(-1.5, 0.0, 0.0))   # beside it: E reaches 3 m (use_reach_m)
		items.action(1, Net.ACT_USE_STRUCT, smelter, 0, 0, Vector3.ZERO)   # E: work the bellows
		run(float(smelt["ingot_s"]) / float(smelt["bellows_speed"]) * float(ore) + 5.0)
		items.action(1, Net.ACT_USE_STRUCT, smelter, 0, 0, Vector3.ZERO)   # E again: leave them
		items.action(1, Net.ACT_CHEST_OPEN, smelter, 0, 0, Vector3.ZERO)
		items.action(1, Net.ACT_BULK, ItemsScript.BULK_TAKE_ALL, 0, 0, Vector3.ZERO)
		items.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)

		if have("iron_ore") >= ore_before:   # nothing smelted: stop rather than loop
			break

	go(FORGE)

	if have("iron_ingot") < wanted:
		print("     make_iron short: ore %d of %d, charcoal %d; pack %s" % [have("iron_ore"), ore_n, have("charcoal"), pack_str()])

	return have("iron_ingot") >= wanted


func make_charcoal(wanted: int) -> void:
	go(FORGE)

	if have("charcoal") >= wanted:
		return

	var crafts: int = ceili(float(wanted - have("charcoal")) / float(gives_of("charcoal")))
	feed("forge yard", 4)
	items.give(1, n("firewood"), crafts * need_of("charcoal", "firewood"))   # firewood split at a chopping block (test_first_town, test_lumber_route)
	craft("charcoal", crafts)


# What the player has no more use for is put down a few steps off, out of reach of the next pickups (the carry limit fills).
func leave(keep: Dictionary) -> void:
	for id in keep:
		while slot_of(id) >= 0 and have(id) > int(keep[id]):
			var s: int = slot_of(id)
			var before: int = have(id)
			items.action(1, Net.ACT_DROP, s, 0, mini(inv.counts[s], have(id) - int(keep[id])), items.position_of(1) + Vector3(0.0, 0.0, -5.0))

			if have(id) == before:   # refused (too much lying about already): it stays in the pack
				break


func pack_str(peer: int = 1) -> String:
	var out: Array = []
	var pinv = items.inventory_of(peer)

	for s in pinv.slot_count:
		if pinv.numbers[s] != 0:
			out.append("%s %d" % [items.table.id_of(pinv.numbers[s]), pinv.counts[s]])

	return "%d slots (%.1f kg carried, body %.1f kg): %s" % [out.size(), items.carried_kg_of(peer), float(items.vitals_of(peer).get("weight", 0.0)), ", ".join(out)]


func box_of(id: int):
	return items._chests.get(int(items._items[id]["struct"].get("uid", -1)))


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	items = make_server()
	join(1, CAMP)
	inv = items.inventory_of(1)
	step1_early_survival()
	step2_wood_and_metal()
	step3_construction_and_equipment()
	step4_cooking_and_preservation()
	step5_food_effects()
	step6_storage_and_warehousing()
	step7_save_and_reload()
	end_step()
	print("")

	for line in results:
		print(line)

	print("mission 001 walkthrough: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	items._finish_writer()
	quit(1 if failures > 0 else 0)


# --- 1. Early survival ---------------------------------------------------------------------------------------------------------------
var camp_chest: int = -1
var lean_to: int = -1

func step1_early_survival() -> void:
	step("1 early survival")
	var empty: bool = true

	for s in inv.slot_count:
		empty = empty and inv.numbers[s] == 0

	check(empty and items.worn_of(1).all(func(w): return int(w) == 0), "1a. a new character arrives with nothing in the pack and nothing worn")

	# Gathering by hand: stones, sticks, plant fibre and a large wooden block lie about (the ground scatter, plants and a felled trunk give them;
	# test_first_hour and test_first_town gather them the same way).
	var twine_n: int = need_of("stone_axe", "twine") + cost_of("lean_to", "twine") + cost_of("chest", "twine") + need_of("wooden_hammer", "twine")
	var fibre_n: int = twine_n * need_of("twine", "plant_fibre") + 4
	var stick_n: int = need_of("stone_axe", "stick") + need_of("stone_knife", "stick") + need_of("wooden_hammer", "stick") + cost_of("lean_to", "stick") + cost_of("chest", "stick") + need_of("wooden_spade", "stick")
	var stone_n: int = need_of("stone_axe", "stone") + need_of("stone_knife", "stone") + 1

	for k in range(8):
		var around: Vector3 = Vector3(cos(float(k) * TAU / 8.0), 0.0, sin(float(k) * TAU / 8.0))   # more than a metre apart, or heaps merge
		items.drop_in_world(n("plant_fibre"), ceili(float(fibre_n) / 8.0), CAMP + around * 2.6)
		items.drop_in_world(n("stick"), ceili(float(stick_n) / 8.0), CAMP + around * 1.6)

	items.drop_in_world(n("stone"), stone_n, CAMP + Vector3(0.0, 0.0, 0.6))
	items.drop_in_world(n("wooden_block_large"), 1, CAMP + Vector3(-0.6, 0.0, 0.0))
	pick_up_all()
	check(have("plant_fibre") >= fibre_n and have("stick") >= stick_n and have("stone") >= stone_n and have("wooden_block_large") == 1, "1b. gathering by hand gives %d plant fibre, %d sticks, %d stones and a large wooden block" % [have("plant_fibre"), have("stick"), have("stone")])
	craft("twine", twine_n)
	check(have("twine") >= twine_n, "1c. plant fibre is twisted into %d twine by hand" % have("twine"))
	craft("stone_axe", 1)
	craft("stone_knife", 1)
	check(have("stone_axe") == 1 and have("stone_knife") == 1, "1d. a Stone - Axe and a Stone - Knife are made by hand")
	craft("small_blocks_from_large", 1)
	craft("wooden_hammer", 1)
	check(have("wooden_hammer") == 1 and inv.on_hotbar(slot_of("wooden_hammer")), "1e. the axe splits the large block and a Wooden - Hammer is made by hand; it sits in the hand bar")

	# The Lean-to and the Wicker - Chest from their blueprints. Leaves: a felled tree gives a few (test_first_hour fells one and counts them); the
	# rest are swept from many trees, so the remainder is given.
	items.give(1, n("leaves"), cost_of("lean_to", "leaves"))
	lean_to = build("lean_to", CAMP + Vector3(-5.0, 0.0, 0.0), "1f")
	check(lean_to >= 0 and bool(items._structures["lean_to"].get("shelter", false)), "1f. the Lean-to is a shelter")
	camp_chest = build("chest", CAMP + Vector3(0.0, 0.0, 5.0), "1g")
	check(camp_chest >= 0 and items.table.entry("chest")["name"] == "Wicker - Chest" and box_of(camp_chest) != null, "1g. the Wicker - Chest stands and has a store")

	# A deer hunted (the kill: test_hunt_feedback; the carcass is what it leaves) and dressed with the stone knife.
	var fire: int = campfire_at("camp", CAMP + Vector3(3.0, 0.0, 0.0))
	var carcass: int = items.make_carcass("deer", CAMP + Vector3(1.0, 0.0, -1.5), 1)

	for blow in range(12):
		items._last_process.erase(1)
		items.action(1, Net.ACT_PROCESS, carcass, 0, 0, Vector3(float(HeldTool.slot_of(items, "knife") + 1), 0.0, 0.0))

	pick_up_all(4)
	check(not items._items.has(carcass) and have("raw_meat") >= 6 and have("hide") >= 1 and have("animal_fat") >= 1, "1h. the knife dresses the deer: %d raw meat, %d hide, %d fat, %d bone" % [have("raw_meat"), have("hide"), have("animal_fat"), have("bone")])
	go(items._items[fire]["pos"] + Vector3(1.0, 0.0, 0.0))
	var raw_before: int = have("raw_meat")

	for k in range(2):
		items._last_cook.clear()
		items.action(1, Net.ACT_COOK, fire, 0, 0, Vector3.ZERO)

	check(have("roast_meat") == 2 and have("raw_meat") == raw_before - 2, "1i. the campfire roasts two pieces of meat (%d Roast meat)" % have("roast_meat"))
	leave({"raw_meat": 0, "sinew": 0, "antler": 0, "gut": 0, "animal_fat": 0})
	items._last_eat.clear()
	items.vitals_of(1)["fed"] = 500.0
	items.action(1, Net.ACT_EAT, slot_of("roast_meat"), 0, 0, Vector3.ZERO)
	check(have("roast_meat") == 1 and float(items.vitals_of(1)["fed"]) > 500.0, "1j. a Roast meat is eaten and feeds (%.0f kcal in the stomach)" % float(items.vitals_of(1)["fed"]))

	# Stored in the Wicker - Chest: the bones and the spare stones.
	go(CAMP + Vector3(0.0, 0.0, 3.5))
	var box = box_of(camp_chest)
	var bones: int = have("bone")
	var stones: int = have("stone")
	items.action(1, Net.ACT_CHEST_OPEN, camp_chest, 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_PUT, slot_of("bone"), camp_chest, bones, Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_PUT, slot_of("stone"), camp_chest, stones, Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)
	check(bones > 0 and box.count_of(n("bone")) == bones and box.count_of(n("stone")) == stones and have("bone") == 0 and have("stone") == 0, "1k. %d bones and %d stones are stored in the Wicker - Chest" % [bones, stones])


# --- 2. Wood and metal -----------------------------------------------------------------------------------------------------------------
var smelter: int = -1
var smithy: int = -1

func step2_wood_and_metal() -> void:
	step("2 wood and metal")
	go(FORGE)
	var coins_before: int = items.coins_of(1)
	items.give(1, n("stone"), 1)   # the spade's kept stone (stones lie about: test_first_hour)
	craft("wooden_spade", 1)
	check(have("wooden_spade") == 1, "2a. a Wooden spade is made by hand")
	campfire_at("forge yard", FORGE + Vector3(-3.0, 0.0, 0.0))

	# The Improved smelter: stone, clay, logs and hide gathered (test_iron_saw_route gives them the same way); its bronze fittings come from the
	# Primitive smelter and smithy (test_bronze_path proves that route), so they are given here.
	give_cost("improved_smelter", ["stone", "clay", "log", "hide", "bronze_hinges", "bronze_nails"])
	smelter = build("improved_smelter", FORGE + Vector3(3.0, 0.0, -0.5), "2b")
	var smithy_iron: int = cost_of("blacksmithy", "iron_ingot")
	var saw_iron: int = need_of("hand_saw", "iron_ingot")
	check(make_iron(smithy_iron + saw_iron), "2c. bog iron dug with the spade, charcoal burnt at the campfire and smelted at the Improved smelter with its bellows worked: %d Iron ingots (%d needed)" % [have("iron_ingot"), smithy_iron + saw_iron])

	# The Smithy from stones, clay, logs (gathered: test_iron_saw_route) and the route's iron; cold, it is fired by the craft with charcoal.
	give_cost("blacksmithy", ["stone", "clay", "log"])
	smithy = build("blacksmithy", FORGE + Vector3(0.0, 0.0, 3.5), "2d")
	make_charcoal(4)
	var charcoal_n: int = have("charcoal")
	check(smithy >= 0 and not bool(items._items[smithy]["struct"].get("lit", false)), "2e. the new Smithy stands cold")
	items.give(1, n("stick"), need_of("hand_saw", "stick"))   # sticks lie about (test_first_hour)
	craft("hand_saw", 1)
	check(bool(items._items[smithy]["struct"].get("lit", false)) and have("charcoal") < charcoal_n, "2f. the craft fires the Smithy with charcoal from the pack")
	check(have("hand_saw") == 1 and have("saw_blade") == 0, "2g. an Iron - Saw is made at the Smithy (no Saw blade)")

	# Planks from a softwood log and Hardwood boards from a hardwood log (logs felled and worked: test_first_hour, test_lumber_route).
	inv.add(n("log_spruce"), 1)
	inv.add(n("log_oak"), 1)
	var saw_wear: int = inv.wear[slot_of("hand_saw")]
	craft("lumber_by_hand", 1)
	craft("hardwood_board_by_hand", 1)
	check(have("lumber") == gives_of("lumber_by_hand") and have("hardwood_board") == gives_of("hardwood_board_by_hand"), "2h. the saw gives %d Planks from a spruce log and %d Hardwood boards from an oak log" % [have("lumber"), have("hardwood_board")])
	check(inv.wear[slot_of("hand_saw")] > saw_wear, "2i. the saw wears with use (%d -> %d)" % [saw_wear, inv.wear[slot_of("hand_saw")]])
	check(items.coins_of(1) >= coins_before, "2j. nothing was bought: the purse never paid out (%d -> %d copper, goal rewards only)" % [coins_before, items.coins_of(1)])


# --- 3. Construction and equipment ---------------------------------------------------------------------------------------------------
var rustic_chest: int = -1
var crude_chair: int = -1

func step3_construction_and_equipment() -> void:
	step("3 construction and equipment")
	go(WORKSHOP)
	items.give(1, n("plant_fibre"), 3 * (cost_of("workbench", "twine") + cost_of("drying_rack", "twine") + cost_of("tanning_rack", "twine") + cost_of("leatherworking_table", "twine") + cost_of("loom", "twine") + cost_of("tailors_table", "twine") + need_of("rope", "twine") + need_of("hide_scraper", "twine")))   # plant fibre gathered by hand (step 1, test_first_hour)
	craft("twine", cost_of("workbench", "twine") + cost_of("drying_rack", "twine") + cost_of("tanning_rack", "twine") + cost_of("leatherworking_table", "twine") + cost_of("loom", "twine") + cost_of("tailors_table", "twine") + need_of("rope", "twine") + need_of("hide_scraper", "twine"))

	# Hides: deer hunted (test_hunt_feedback) and dressed with the stone knife until there are leather and backpack hides; a bone for the needle.
	var hides_n: int = 2 + need_of("backpack", "hide")

	for k in range(8):
		if have("hide") >= hides_n:
			break

		var carcass: int = items.make_carcass("deer", WORKSHOP + Vector3(1.0, 0.0, -1.5), 1)

		for blow in range(12):
			items._last_process.erase(1)
			items.action(1, Net.ACT_PROCESS, carcass, 0, 0, Vector3(float(HeldTool.slot_of(items, "knife") + 1), 0.0, 0.0))

	pick_up_all(4)
	check(have("hide") >= hides_n and have("bone") >= 1, "3a. more deer dressed: %d hides, %d bones" % [have("hide"), have("bone")])
	leave({"raw_meat": 0, "sinew": 0, "antler": 0, "gut": 0, "animal_fat": 0, "bone": 1})

	# A Wooden - Workbench for the hide scraper and the wooden pins (sticks and stones lie about: test_first_hour; flint off a boulder: test_flint).
	give_cost("workbench", ["stick", "stone"])
	build("workbench", WORKSHOP + Vector3(-3.0, 0.0, -3.0), "3b")
	give_needs("hide_scraper", ["flint", "stick"])
	craft("hide_scraper", 1)
	check(have("hide_scraper") == 1, "3b. a hide scraper at the workbench")

	# Leather: the hide scraped and dried at a Drying rack, tanned at a Tanning rack (tannin bark and water are given as test_textile_route gives them: no route test proves stripping bark or drawing water, T19_RESULTS gaps).
	give_cost("drying_rack", ["stick"])
	build("drying_rack", WORKSHOP + Vector3(-3.0, 0.0, 0.5), "3c")
	craft("processed_hide", 2)
	give_cost("tanning_rack", ["log"])   # logs felled and worked (test_first_hour)
	build("tanning_rack", WORKSHOP + Vector3(0.0, 0.0, -3.5), "3c")
	give_needs("leather", ["tannin_bark", "water"], 2)
	craft("leather", 2)
	check(have("leather") == 2 and have("processed_hide") == 0, "3c. two hides scraped, dried and tanned into Leather")

	# The Leatherworking table and a Leather strap; Thread by hand; the Loom and Fibre cloth; the Tailor's table and a Fibre - Gambeson.
	give_cost("leatherworking_table", ["log", "stick", "stone"])
	build("leatherworking_table", WORKSHOP + Vector3(3.0, 0.0, 0.0), "3d")
	craft("leather_strap", 1)
	check(have("leather_strap") == gives_of("leather_strap") and have("leather") == 1, "3d. the Leatherworking table cuts %d Leather straps (the knife is kept: %d)" % [have("leather_strap"), have("stone_knife")])
	var cloth_n: int = need_of("gambeson", "fibre_cloth")
	items.give(1, n("plant_fibre"), need_of("thread", "plant_fibre") + crafts_for("fibre_cloth", cloth_n) * need_of("fibre_cloth", "plant_fibre") + need_of("gambeson", "plant_fibre"))   # gathered by hand (test_first_hour)
	craft("thread", 1)
	check(have("thread") == gives_of("thread"), "3e. Thread is twisted by hand from plant fibre")
	# The Loom is first set down as a blueprint site, its materials still to come: an unbuilt site weaves nothing (docs/BLUEPRINT_SITES.md: a site
	# counts as nothing built; M001-T19 found sites serving as stations). The materials are then deposited with E and it stands.
	var loom_at: Vector3 = WORKSHOP + Vector3(0.0, 0.0, 3.0)
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(blueprint_of("loom")["number"]), 0, 0, loom_at)
	var loom_site: int = -1

	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == "loom" and items._items[id]["struct"].has("site"):
			loom_site = int(id)

	var fibre_was: int = have("plant_fibre")
	craft("fibre_cloth", 1)
	check(loom_site >= 0 and have("fibre_cloth") == 0 and have("plant_fibre") == fibre_was and not items.station_near(1, "loom"), "3f. a Loom blueprint site with its materials still to come weaves nothing")
	give_cost("loom", ["log", "stick", "clay"])
	items._last_use.clear()
	items.action(1, Net.ACT_USE_STRUCT, loom_site, 0, 0, Vector3.ZERO)
	check(standing_at("loom", loom_at) >= 0 and cost_of("loom", "log") > 0 and have("log") == 0 and have("clay") == 0, "3f. the materials deposited with E, the Loom stands")
	craft("fibre_cloth", crafts_for("fibre_cloth", cloth_n))
	check(have("fibre_cloth") >= cloth_n, "3f. the Loom weaves %d Fibre cloth" % have("fibre_cloth"))
	give_cost("tailors_table", ["log", "stick"])
	build("tailors_table", WORKSHOP + Vector3(-3.5, 0.0, 3.5), "3g")
	craft("gambeson", 1)
	check(have("gambeson") == 1, "3g. the Tailor's table makes a Fibre - Gambeson")

	# A Bone - Needle and a Hide - Backpack by hand.
	craft("sewing_needle", 1)
	craft("rope", 1)
	craft("backpack", 1)
	check(have("backpack") == 1 and have("sewing_needle") == 1, "3h. a Hide - Backpack sewn by hand (the needle is kept)")

	# Boards and pins for the furniture: oak logs sawn (test_lumber_route), a Plank into wooden pins at the workbench.
	var boards_n: int = cost_of("plank_chest", "hardwood_board") + cost_of("crude_chair", "hardwood_board")

	for k in range(4):
		if have("hardwood_board") >= boards_n:
			break

		inv.add(n("log_oak"), 1)   # felled and worked (test_first_hour, test_lumber_route)
		craft("hardwood_board_by_hand", 1)

	go(WORKSHOP + Vector3(-1.5, 0.0, -1.5))
	craft("wooden_pin", 1)
	check(have("hardwood_board") >= boards_n and have("wooden_pin") >= cost_of("crude_chair", "wooden_pin"), "3i. %d Hardwood boards sawn and %d wooden pins cut" % [have("hardwood_board"), have("wooden_pin")])

	# Nails, hinges and rivets, an iron weapon and an iron armour piece at the Smithy, from route iron.
	var iron_n: int = need_of("nails", "iron_ingot") + need_of("hinges", "iron_ingot") + need_of("rivets", "iron_ingot") + need_of("iron_mace", "iron_ingot") + need_of("mail_shirt", "iron_ingot") + 1   # one more for a repair
	check(make_iron(iron_n), "3j. %d more Iron ingots from the bog (%d)" % [iron_n, have("iron_ingot")])
	make_charcoal(8)
	go(FORGE + Vector3(0.0, 0.0, 1.5))
	craft("nails", 1)
	craft("hinges", 1)
	craft("rivets", 1)
	craft("iron_mace", 1)
	craft("mail_shirt", 1)
	check(have("nails") >= gives_of("nails") and have("hinges") >= gives_of("hinges") and have("rivets") == gives_of("rivets") - need_of("mail_shirt", "rivets"), "3k. the Smithy makes nails, hinges and rivets")
	check(have("iron_mace") == 1 and items.table.entry("iron_mace")["name"] == "Iron - Mace", "3l. an Iron - Mace (iron weapon) at the Smithy")
	check(have("mail_shirt") == 1 and have("leather") == 0, "3m. an Iron - Mail shirt (iron armour) at the Smithy, with the second Leather")

	# Furniture from boards: the Rustic - Chest at depot A (it is locked in step 6), the Crude - Chair beside it.
	go(DEPOT_A)
	rustic_chest = build("plank_chest", DEPOT_A + Vector3(2.0, 0.0, 0.0), "3n")
	crude_chair = build("crude_chair", DEPOT_A + Vector3(-2.0, 0.0, 0.0), "3n")
	check(rustic_chest >= 0 and box_of(rustic_chest) != null and int(items._chest_of(1, rustic_chest).usable) == int(items._structures["plank_chest"]["slots"]) and items.table.entry("plank_chest")["name"] == "Rustic - Chest", "3n. the Rustic - Chest opens with %d slots" % int(items._structures["plank_chest"]["slots"]))
	check(crude_chair >= 0 and items.table.entry("crude_chair")["name"] == "Crude - Chair", "3n. the Crude - Chair stands")

	# Gambeson + mail in layers.
	go(FORGE + Vector3(0.0, 0.0, 1.5))
	var alone_g: float = 0.0
	var alone_m: float = 0.0
	items.action(1, Net.ACT_WEAR, slot_of("gambeson"), 0, 0, Vector3.ZERO)
	alone_g = items.protection_of(1, "slashing")
	items.action(1, Net.ACT_WEAR, slot_of("mail_shirt"), 0, 0, Vector3.ZERO)
	var both: float = items.protection_of(1, "slashing")
	var worn: Array = items.worn_of(1)
	check(worn.has(n("gambeson")) and worn.has(n("mail_shirt")) and have("gambeson") == 0 and have("mail_shirt") == 0, "3o. the gambeson and the mail shirt are worn together on the body")
	alone_m = float(items.table.entry("mail_shirt")["protect"]["slashing"]) * float(items.table.entry("mail_shirt").get("cover", 1.0)) * float(items._protection_cfg["slots"]["body"])
	check(both > alone_g and both > alone_m - 0.0001 and both < alone_g + alone_m + 0.0001, "3o. layered they stop %.3f of a cut: more than the gambeson alone (%.3f), not more than both summed" % [both, alone_g])

	# The backpack: worn. It has no slots (Dave 13 Nov 2026: only carry weight), so it cannot be opened or filled as a container.
	items.action(1, Net.ACT_WEAR, slot_of("backpack"), 0, 0, Vector3.ZERO)
	var back_at: int = items._worn_places().find("back:base")
	check(back_at >= 0 and items.worn_of(1)[back_at] == n("backpack"), "3p. the backpack is worn on the back with the gambeson and mail")
	var pack_id: int = -1 - back_at
	items.give(1, n("stone"), 3)
	var stone_before: int = have("stone")
	var sends_before: int = int(chest_sends.get(1, 0))
	items.action(1, Net.ACT_CHEST_OPEN, pack_id, 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_PUT, slot_of("stone"), pack_id, have("stone"), Vector3.ZERO)
	check(BagRules.slots_of(items.table, n("backpack")) == 0 and int(chest_sends.get(1, 0)) == sends_before and have("stone") == stone_before and items.worn_slots_of(1)[back_at][3].get("bag", []).is_empty(), "3q. the worn backpack has no slots: it is not opened, takes nothing and the stones stay in the pack")
	leave({"stone": 0, "stick": 0, "plant_fibre": 0, "clay": 0, "sand": 0, "flint": 0, "leaves": 0, "firewood": 0, "bone": 0, "charcoal": 0, "twine": 0})   # the gathered kinds are put down, as before this check lost its bag

	# Wear from use and repair at the station: a wolf bite wears the mail shirt; away from a Smithy it is not mended, at the Smithy it is.
	var mail_at: int = items._place_of(n("mail_shirt"))
	items.hurt_player(1, 10.0, false, "wolves")
	var bitten: int = int(items.worn_slots_of(1)[mail_at][2])
	check(bitten > 0, "3r. a wolf bite wears the worn mail shirt (wear %d)" % bitten)
	items.vitals_of(1)["health"] = 100.0
	go(CAMP)
	items.action(1, Net.ACT_UNWEAR, mail_at, 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_REPAIR, slot_of("mail_shirt"), 0, 0, Vector3.ZERO)
	check(slot_of("mail_shirt") >= 0 and inv.wear[slot_of("mail_shirt")] == bitten, "3s. taken off at the camp, far from a Smithy, it is not mended")
	go(FORGE + Vector3(0.0, 0.0, 1.5))
	var iron_before: int = have("iron_ingot")
	items.action(1, Net.ACT_REPAIR, slot_of("mail_shirt"), 0, 0, Vector3.ZERO)
	check(inv.wear[slot_of("mail_shirt")] == 0 and have("iron_ingot") == iron_before - 1, "3s. at the Smithy it is mended with one Iron ingot")
	items.action(1, Net.ACT_WEAR, slot_of("mail_shirt"), 0, 0, Vector3.ZERO)
	check(items.worn_of(1)[mail_at] == n("mail_shirt"), "3s. and worn again")

	# Blast furnace steel and a Tempered steel item: bricks fired at the campfire, mortar by hand (clay and sand dug: test_server_items), the Blast
	# furnace from its blueprint, steel smelted in it, a Quenching trough beside the Smithy, a Tempered Steel - Knife.
	var steel_n: int = need_of("steel_knife", "steel_ingot")
	var iron_more: int = cost_of("large_forge", "iron_ingot") + cost_of("quenching_trough", "iron_ingot") + steel_n * need_of("smelt_steel", "iron_ingot")
	check(make_iron(iron_more), "3t. %d more Iron ingots for the Blast furnace, the trough and the steel" % iron_more)
	go(FORGE + Vector3(-2.0, 0.0, 0.0))
	feed("forge yard", 6)
	var brick_crafts: int = crafts_for("brick", cost_of("large_forge", "brick"))
	items.give(1, n("clay"), brick_crafts * need_of("brick", "clay"))   # dug clay (test_server_items)
	craft("brick", brick_crafts)
	var mortar_crafts: int = crafts_for("mortar", cost_of("large_forge", "mortar"))
	give_needs("mortar", ["sand", "clay"], mortar_crafts)   # dug sand and clay (test_server_items)
	craft("mortar", mortar_crafts)
	check(have("brick") >= cost_of("large_forge", "brick") and have("mortar") >= cost_of("large_forge", "mortar"), "3u. %d bricks fired at the campfire and %d mortar mixed by hand" % [have("brick"), have("mortar")])
	give_cost("large_forge", ["stone"])   # stones lie about (test_first_hour)
	go(FORGE + Vector3(3.0, 0.0, 3.0))
	var furnace: int = build("large_forge", FORGE + Vector3(4.5, 0.0, 5.0), "3v")
	check(furnace >= 0 and items.table.entry("large_forge")["name"] == "Blast furnace", "3v. the Blast furnace stands")
	make_charcoal(need_of("smelt_steel", "fuel") * steel_n + 6)
	go(FORGE + Vector3(3.0, 0.0, 3.0))
	craft("smelt_steel", steel_n)
	check(have("steel_ingot") == steel_n, "3w. the Blast furnace makes %d steel ingot from route iron" % have("steel_ingot"))
	give_cost("quenching_trough", ["stone", "log"])   # stones and logs (test_first_hour)
	go(FORGE + Vector3(0.0, 0.0, 1.5))
	var trough: int = build("quenching_trough", FORGE + Vector3(-3.0, 0.0, 4.5), "3x")
	var tempered: int = SmithingRules.code(true, 0)
	items.give(1, n("stick"), need_of("steel_knife", "stick"))   # sticks lie about (test_first_hour)
	check(trough >= 0 and items.craft_variants(1, recipe("steel_knife")).has(tempered), "3x. with the trough beside the Smithy, Tempered is offered for the Steel - Knife")
	craft("steel_knife", 1, -1.0, tempered)
	var ks: int = slot_of("steel_knife")
	var base_d: int = int(items.table.entry("steel_knife")["durability"])
	check(ks >= 0 and int(inv.inst_of(ks).get("temper", 0)) == 1 and inv.max_durability(ks) > base_d, "3y. a Tempered Steel - Knife from Blast furnace steel (lasts %d against %d)" % [inv.max_durability(ks) if ks >= 0 else -1, base_d])

	# Building stuff left over stays at the forge yard (the carry limit); the small things go into the Rustic - Chest at depot A.
	leave({"brick": 0, "mortar": 0, "stone": 0, "log": 0, "stick": 4, "charcoal": 12, "plant_fibre": 0, "clay": 0, "sand": 0})
	go(DEPOT_A + Vector3(2.0, 0.0, 1.5))
	items.action(1, Net.ACT_CHEST_OPEN, rustic_chest, 0, 0, Vector3.ZERO)

	for id in ["hinges", "rivets", "iron_mace", "hide_scraper", "leather_strap", "thread", "sewing_needle", "fibre_cloth"]:
		if slot_of(id) >= 0:
			items.action(1, Net.ACT_CHEST_PUT, slot_of(id), rustic_chest, have(id), Vector3.ZERO)

	items.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)
	check(rustic_chest >= 0 and box_of(rustic_chest).count_of(n("iron_mace")) == 1 and have("iron_mace") == 0, "3z. the mace, the hinges and rivets left over and the sewing tools are stored in the Rustic - Chest")


# --- 4. Cooking and preservation -------------------------------------------------------------------------------------------------------
var prep_table: int = -1
var platter: int = -1
var eaten_portions: int = 0


func told(word: String) -> bool:
	return said.slice(maxi(said.size() - 4, 0)).any(func(t): return str(t).contains(word))


func on_plate() -> int:
	var box = box_of(platter) if platter >= 0 and items._items.has(platter) else null
	return int(box.counts[0]) if box != null and box.numbers[0] != 0 else 0


func eat_slot(id: String) -> bool:
	var before: int = have(id)

	if before == 0:
		return false

	items._last_eat.clear()
	items.vitals_of(1)["fed"] = 0.0
	items.action(1, Net.ACT_EAT, slot_of(id), 0, 0, Vector3.ZERO)
	return have(id) < before


func eat_from_platter() -> bool:
	var before: int = on_plate()
	items._last_eat.clear()
	items.vitals_of(1)["fed"] = 0.0
	items.action(1, Net.ACT_USE_STRUCT, platter, 0, 0, Vector3.ZERO)
	return on_plate() < before


func step4_cooking_and_preservation() -> void:
	step("4 cooking and preservation")
	go(KITCHEN)
	var twine_n: int = cost_of("food_preparation_table", "twine") + cost_of("drying_rack", "twine") + need_of("campfire_roasting_spit", "twine")
	items.give(1, n("plant_fibre"), twine_n * need_of("twine", "plant_fibre"))   # gathered by hand (test_first_hour)
	craft("twine", twine_n)
	campfire_at("kitchen", KITCHEN + Vector3(0.0, 0.0, -3.0))
	feed("kitchen", 6)
	var carcass: int = items.make_carcass("deer", KITCHEN + Vector3(1.0, 0.0, -1.0), 1)   # hunted (test_hunt_feedback)

	for blow in range(12):
		items._last_process.erase(1)
		items.action(1, Net.ACT_PROCESS, carcass, 0, 0, Vector3(float(HeldTool.slot_of(items, "knife") + 1), 0.0, 0.0))

	pick_up_all(4)
	leave({"sinew": 0, "antler": 0, "gut": 0, "bone": 0, "hide": 0, "animal_fat": need_of("cook_onion_roast", "animal_fat"), "plant_fibre": 0})

	# The Food preparation table (logs: test_first_hour); Flatbread from flour milled by hand with a quern (wheat harvested: test_farming; water
	# given: no route test proves drawing it, T19_RESULTS gaps), prepared at the table and baked at a Clay hearth of campfire bricks.
	give_cost("food_preparation_table", ["log"])
	prep_table = build("food_preparation_table", KITCHEN + Vector3(3.0, 0.0, 0.0), "4a")
	give_needs("quern", ["stone", "stick"])   # stones and sticks lie about (test_first_hour)
	craft("quern", 1)
	give_needs("flour_from_wheat", ["wheat"])
	craft("flour_from_wheat", 1)
	check(have("flour") >= need_of("prep_flatbread", "flour"), "4b. wheat milled by hand with the quern: %d flour" % have("flour"))
	items.give(1, n("water"), need_of("prep_flatbread", "water"))
	go(KITCHEN + Vector3(1.5, 0.0, 0.0))
	craft("prep_flatbread", 1)
	check(have("unbaked_flatbread") == gives_of("prep_flatbread"), "4c. the table prepares %d Unbaked flatbread" % have("unbaked_flatbread"))
	var brick_crafts: int = crafts_for("brick", cost_of("clay_hearth", "brick"))
	items.give(1, n("clay"), brick_crafts * need_of("brick", "clay") + cost_of("clay_hearth", "clay"))   # dug clay (test_server_items)
	give_cost("clay_hearth", ["stone"])
	go(KITCHEN + Vector3(0.0, 0.0, -1.5))
	craft("brick", brick_crafts)
	go(KITCHEN)
	var hearth: int = build("clay_hearth", KITCHEN + Vector3(-3.0, 0.0, 0.0), "4d")
	go(KITCHEN + Vector3(-1.5, 0.0, 0.0))
	craft("cook_flatbread", 1)
	check(hearth >= 0 and have("flatbread") == gives_of("cook_flatbread") and have("unbaked_flatbread") == 0, "4d. the Clay hearth bakes %d Flatbread" % have("flatbread"))

	# Sauerkraut sealed as one batch at a Preserving jar (cabbage: a crop, harvested as test_farming harvests wheat; sea salt boiled from sea water:
	# test_shore_gather).
	go(KITCHEN)
	give_cost("preserving_jar", ["clay"])
	build("preserving_jar", KITCHEN + Vector3(0.0, 0.0, 3.0), "4e")
	var batch: int = 2
	give_needs("cook_sauerkraut", ["cabbage", "sea_salt"], batch)
	go(KITCHEN + Vector3(0.0, 0.0, 1.5))
	craft("cook_sauerkraut", batch)
	var kraut: int = slot_of("sauerkraut")
	check(kraut >= 0 and have("sauerkraut") == batch * gives_of("cook_sauerkraut") and inv.maturing_at(kraut) and inv.count_fill(n("sauerkraut"), false) == 0, "4e. one craft seals the batch: %d Sauerkraut, Maturing (no ingredient yet)" % have("sauerkraut"))
	check(not eat_slot("sauerkraut") and told("aturing"), "4f. a Maturing stack is not eaten")
	items._spoil_tick(float(recipe("cook_sauerkraut")["ready_age"]) * 3600.0 / items.GAME_RATE * 1.05)
	check(slot_of("sauerkraut") >= 0 and not inv.maturing_at(slot_of("sauerkraut")) and have("sauerkraut") == batch * gives_of("cook_sauerkraut"), "4g. after %s game hours the batch is Ready" % str(recipe("cook_sauerkraut")["ready_age"]))

	# Smoked meat at a Smoker; Dried mushrooms at a Drying rack (porcini given: no route test proves picking mushrooms, T19_RESULTS gaps).
	go(KITCHEN + Vector3(0.0, 0.0, -1.5))
	give_cost("smoker", ["stone", "clay"])
	build("smoker", KITCHEN + Vector3(-3.0, 0.0, -3.5), "4h")
	items.give(1, n("sea_salt"), need_of("smoked_meat", "sea_salt"))
	go(KITCHEN + Vector3(-1.5, 0.0, -2.5))
	craft("smoked_meat", 1)
	check(have("smoked_meat") == gives_of("smoked_meat"), "4h. the Smoker smokes the deer's meat into Smoked meat")
	go(KITCHEN)
	give_cost("drying_rack", ["stick"])
	build("drying_rack", KITCHEN + Vector3(3.0, 0.0, 3.5), "4i")
	give_needs("dried_mushrooms_porcini", ["porcini"])
	go(KITCHEN + Vector3(1.5, 0.0, 2.0))
	craft("dried_mushrooms_porcini", 1)
	check(have("dried_mushrooms") == gives_of("dried_mushrooms_porcini"), "4i. the Drying rack dries porcini into Dried mushrooms")

	# A Roast platter: roast meat at the campfire, a roast joint on a spit, roast roots and onion roast at the hearth (onions a crop as in test_farming; rosemary,
	# wild garlic, burdock and wild carrot given: no route test proves foraging them, T19_RESULTS gaps), assembled at the table.
	go(items._items[fires["kitchen"]]["pos"] + Vector3(1.0, 0.0, 0.0) if items._items.has(int(fires["kitchen"])) else KITCHEN)
	items._last_cook.clear()
	items.action(1, Net.ACT_COOK, fires["kitchen"], 0, 0, Vector3.ZERO)
	give_needs("campfire_roasting_spit", ["stick"])
	craft("campfire_roasting_spit", 1)
	give_needs("cook_roast_joint_campfire_roasting_spit", ["rosemary", "wild_garlic_leaves"])
	craft("cook_roast_joint_campfire_roasting_spit", 1)
	go(KITCHEN + Vector3(-1.5, 0.0, 0.0))
	give_needs("cook_roast_roots", ["burdock_roots", "wild_carrot_roots"])
	craft("cook_roast_roots", 1)
	give_needs("cook_onion_roast", ["onion"])
	craft("cook_onion_roast", 1)
	var dishes: Array = recipe("roast_platter")["needs"].map(func(need): return items.table.id_of(int(need[0])))
	check(dishes.all(func(d): return have(d) >= 1), "4j. the dishes are cooked: %s" % str(dishes.map(func(d): return "%s %d" % [d, have(d)])))
	go(KITCHEN + Vector3(1.5, 0.0, 0.0))
	craft("roast_platter", 1)
	var made: int = have("roast_platter")
	check(made == gives_of("roast_platter"), "4k. the table assembles a Roast platter of %d portions" % made)

	# The Serving platter (wooden blocks from step 1, the knife kept) set on the table, the board on it, a portion eaten.
	craft("serving_platter", 1)
	check(have("serving_platter") == 1, "4l. a Serving platter is carved by hand")
	var table_pos: Vector3 = items._items[prep_table]["pos"] if prep_table >= 0 else KITCHEN
	items.action(1, Net.ACT_PLACE, slot_of("serving_platter"), 0, 0, table_pos + Vector3(0.3, 0.0, 0.1))

	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == "serving_platter":
			platter = int(id)

	check(platter >= 0 and absf(items._items[platter]["pos"].y - table_pos.y - float(items._structures["serving_platter"]["attach_kinds"]["food_preparation_table"])) < 0.01, "4m. the Serving platter sits on the table top")

	if platter < 0:
		return

	items.action(1, Net.ACT_CHEST_PUT, slot_of("roast_platter"), platter, made, Vector3.ZERO)
	check(on_plate() == made and have("roast_platter") == 0, "4n. the board is set on the platter: %d portions" % on_plate())
	check(eat_from_platter() and FoodEffects.live(items._food_of(1), clock[0]).has("main"), "4o. a portion is eaten from the platter: a Main meal")
	eaten_portions = made - on_plate() - have("roast_platter")
	check(have("roast_platter") + on_plate() + eaten_portions == made and eaten_portions == 1, "4p. portions conserved: %d on the platter + %d in the pack + %d eaten = %d made" % [on_plate(), have("roast_platter"), eaten_portions, made])


# --- 5. Food effects -------------------------------------------------------------------------------------------------------------------
func live() -> Dictionary:
	return FoodEffects.live(items._food_of(1), clock[0])


func fitness_xp(ticks: int) -> float:
	var row: Dictionary = items._characters[KEYS[1]]
	var before: float = float(row.get("xp_today", 0.0))

	for k in ticks:
		items._train_fitness(1, 1.0, 10.0)

	return float(row.get("xp_today", 0.0)) - before


func step5_food_effects() -> void:
	step("5 food effects")
	go(KITCHEN + Vector3(1.5, 0.0, 0.0))
	clock[0] += 13.0 * 3600.0   # half a day on: the platter's 12 h Main meal has run out
	check(live().is_empty() and is_equal_approx(items.fitness_xp_mult(1), 1.0), "5a. the last meal's effect has expired")
	var plain: float = fitness_xp(6)
	var day_before: float = float(items._characters[KEYS[1]].get("xp_today", 0.0))
	var ate: Array = [eat_from_platter(), eat_slot("flatbread"), eat_slot("sauerkraut")]
	eaten_portions += 1 if ate[0] else 0
	var on: Dictionary = live()
	check(ate.all(func(a): return a) and on.has("main") and on.has("bread") and on.has("fruit_veg") and on.size() == 3, "5b. a platter portion, a Flatbread and a Sauerkraut: three groups active %s" % str(on.keys()))
	check(float(items._characters[KEYS[1]].get("xp_today", 0.0)) == day_before, "5c. eating changes no XP already earned")
	var mult: float = items.fitness_xp_mult(1)
	var fed_xp: float = fitness_xp(6)
	check(plain > 0.0 and mult > 1.0 and absf(fed_xp - plain * mult) < 0.01, "5d. XP earned afterwards is raised x%.2f (%.2f against %.2f plain)" % [mult, fed_xp, plain])

	if on.has("bread"):
		clock[0] = float(on["bread"]["until"]) + 1.0

	check(not live().has("bread") and live().has("main"), "5e. the Flatbread's effect expires on its own timer; the platter's Main meal runs on")

	# An energy aid (a Nut cake made at the table; nuts and nectar given: no route test proves foraging them, T19_RESULTS gaps) costs no Fitness.
	give_needs("energy_bar", ["nuts", "honeyspindle_nectar"])
	craft("energy_bar", 1)
	var slots_before: int = live().size()
	items.vitals_of(1)["energy"] = 40.0
	var train_before: float = float(items._characters[KEYS[1]].get("train", 0.0))
	check(slots_before < 3 and eat_slot("energy_bar"), "5f. a Nut cake is eaten into a free slot")
	check(items.energy_of(1) > 40.0 and float(items._characters[KEYS[1]].get("train", 0.0)) == train_before, "5g. it gives energy (%.0f) and costs no Fitness (train %.2f -> %.2f)" % [items.energy_of(1), train_before, float(items._characters[KEYS[1]].get("train", 0.0))])

	# The kitchen tools and the spare bricks stay in the kitchen; the food left over goes into the Wicker - Chest at the camp.
	leave({"quern": 0, "flour": 0, "brick": 0, "campfire_roasting_spit": 0, "wooden_block": 0})
	go(CAMP + Vector3(0.0, 0.0, 3.5))
	items.action(1, Net.ACT_CHEST_OPEN, camp_chest, 0, 0, Vector3.ZERO)
	var stored: int = 0

	for id in ["flatbread", "sauerkraut", "smoked_meat", "dried_mushrooms", "roast_joint", "roast_roots", "onion_roast", "roast_meat"]:
		if slot_of(id) >= 0:
			var count: int = have(id)
			items.action(1, Net.ACT_CHEST_PUT, slot_of(id), camp_chest, count, Vector3.ZERO)
			stored += count if box_of(camp_chest).count_of(n(id)) == count else 0

	items.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)
	check(stored > 0 and have("sauerkraut") == 0 and box_of(camp_chest).count_of(n("sauerkraut")) > 0, "5h. the food left over (%d pieces, the Sauerkraut among them) is stored in the Wicker - Chest" % stored)


# --- 6. Storage and warehousing --------------------------------------------------------------------------------------------------------
var desk_a: int = -1
var desk_b: int = -1
var crate: int = -1
var cart: int = -1

func view(peer: int, desk: int) -> Dictionary:
	views.erase(peer)
	items.action(peer, Net.ACT_VIEW_OPEN, desk, 0, 0, Vector3.ZERO)
	return views.get(peer, [0, {}, 0])[1]


func opens(peer: int, id: int) -> bool:
	var before: int = int(chest_sends.get(peer, 0))
	items.action(peer, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)
	var ok: bool = int(chest_sends.get(peer, 0)) > before
	items.action(peer, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)
	return ok


func counts_of(box) -> Dictionary:
	var out: Dictionary = {}

	if box == null:
		return out

	for s in box.slot_count:
		if box.numbers[s] != 0:
			out[int(box.numbers[s])] = int(out.get(int(box.numbers[s]), 0)) + int(box.counts[s])

	return out


# The puller walks in 0.2 s reports of step_m metres (2 m/s at 0.4, inside a loaded cart's pace); the clock the cart follows moves with them.
func walk(to: Vector3, step_m: float = 0.4) -> void:
	var here: Vector3 = items._peer_pos[1]

	while Vector2(to.x - here.x, to.z - here.z).length() > 0.01:
		var d: Vector3 = Vector3(to.x - here.x, 0.0, to.z - here.z)
		here += d.normalized() * minf(step_m, d.length())
		here.y = 10.0
		unix[0] += 0.2
		items.report_position(1, here)


func step6_storage_and_warehousing() -> void:
	step("6 storage and warehousing")

	# More iron for the iron hammer and the bands; boards and Planks for the desks, crate, bench and cart.
	var bands: int = cost_of("warehouse_crate", "iron_band") + 2 * need_of("wooden_cart_wheel", "iron_band") + need_of("axle", "iron_band")
	var iron_n: int = need_of("iron_hammer", "iron_ingot") + crafts_for("iron_band", bands) * need_of("iron_band", "iron_ingot")
	check(make_iron(iron_n), "6a. %d more Iron ingots from the bog" % iron_n)
	make_charcoal(6)
	go(FORGE + Vector3(0.0, 0.0, 1.5))
	items.give(1, n("stick"), need_of("iron_hammer", "stick"))   # sticks lie about (test_first_hour)
	craft("iron_hammer", 1)
	craft("iron_band", crafts_for("iron_band", bands))
	check(have("iron_hammer") == 1 and have("iron_band") >= bands, "6a. an Iron - Hammer and %d iron bands at the Smithy" % have("iron_band"))
	var iron_at: int = items.inventory_of(1).numbers.find(n("iron_hammer"))
	var free_key: int = items.inventory_of(1).numbers.slice(0, 10).find(0)

	if not items.inventory_of(1).on_hotbar(iron_at):
		items.action(1, Net.ACT_MOVE, iron_at, free_key if free_key >= 0 else 1, 0, Vector3.ZERO)   # the iron hammer into a hotbar slot, as a player would drag it

	var boards_n: int = 2 * cost_of("warehouse_desk", "hardwood_board") + cost_of("warehouse_crate", "hardwood_board")
	var planks_n: int = cost_of("log_workbench", "lumber") + 2 * need_of("wooden_cart_wheel", "lumber") + need_of("axle", "lumber") + cost_of("handcart", "lumber") + 2

	for k in range(12):
		if have("hardwood_board") >= boards_n:
			break

		inv.add(n("log_oak"), 1)   # felled and worked (test_first_hour, test_lumber_route)
		craft("hardwood_board_by_hand", 1)

	for k in range(8):
		if have("lumber") >= planks_n:
			break

		inv.add(n("log_spruce"), 1)   # felled and worked (test_first_hour, test_lumber_route)
		craft("lumber_by_hand", 1)

	check(have("hardwood_board") >= boards_n and have("lumber") >= planks_n, "6b. %d Hardwood boards and %d Planks sawn" % [have("hardwood_board"), have("lumber")])

	# Depot A: the Rustic - Chest from step 3 holds flint; the owner locks it with 0042; a second player is refused, enters the code and gets in.
	go(DEPOT_A + Vector3(0.0, 0.0, 1.0))
	desk_a = build("warehouse_desk", DEPOT_A + Vector3(0.0, 0.0, -3.0), "6c")
	crate = build("warehouse_crate", DEPOT_A + Vector3(0.0, 0.0, 4.0), "6c")

	if crate < 0 or rustic_chest < 0:
		check(false, "6c. no Warehouse crate or Rustic - Chest to go on with")
		return

	check(str(items._items[crate]["struct"].get("owner", "")) == KEYS[1], "6c. the Warehouse crate stands, owned by its builder")
	items.give(1, n("flint"), 6)   # flint off a boulder (test_flint)
	items.action(1, Net.ACT_CHEST_OPEN, rustic_chest, 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_PUT, slot_of("flint"), rustic_chest, 6, Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_LOCK, rustic_chest, ItemsScript.LOCK_SET, 42, Vector3.ZERO)
	var saved_lock: String = JSON.stringify(items._lock_of(items._items[rustic_chest]))
	check(box_of(rustic_chest).count_of(n("flint")) == 6 and not items._lock_of(items._items[rustic_chest]).is_empty() and not saved_lock.contains("0042"), "6d. the owner stores 6 flint and locks the Rustic - Chest with 0042 (only a hash is kept)")
	join(2, DEPOT_A + Vector3(1.0, 0.0, 1.0))
	check(opens(1, rustic_chest) and not opens(2, rustic_chest), "6e. the owner opens it; the second player is refused")

	# The crate holds stones and raw meat (meat from the deer of step 4, spoiling: the ageing check).
	items.give(1, n("stone"), 5)   # stones lie about (test_first_hour)
	items.action(1, Net.ACT_CHEST_OPEN, crate, 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_PUT, slot_of("stone"), crate, 5, Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_PUT, slot_of("raw_meat"), crate, 2, Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)
	var cargo: Dictionary = counts_of(box_of(crate))
	check(int(cargo.get(n("stone"), 0)) == 5 and int(cargo.get(n("raw_meat"), 0)) == 2, "6f. the Warehouse crate is loaded: %s" % str(cargo))
	var seen2: Dictionary = view(2, desk_a)
	var seen1: Dictionary = view(1, desk_a)
	check(int(seen2.get(n("stone"), 0)) == 5 and not seen2.has(n("flint")) and int(seen1.get(n("flint"), 0)) == 6, "6g. the desk shows the second player the open crate but not the locked chest; the owner sees both (%s, %s)" % [str(seen2), str(seen1)])
	items.action(2, Net.ACT_CHEST_LOCK, rustic_chest, ItemsScript.LOCK_TRY, 42, Vector3.ZERO)
	check(items._may_access(2, items._items[rustic_chest]) and opens(2, rustic_chest) and int(view(2, desk_a).get(n("flint"), 0)) == 6, "6h. the second player enters 0042 and gets in; the desk now lists the chest for them too")

	# A Carpenter's bench at the workshop (Planks, twine, pins), two wheels and an axle there, the Handcart from its blueprint at depot A.
	go(WORKSHOP)
	items.give(1, n("plant_fibre"), need_of("twine", "plant_fibre") * cost_of("log_workbench", "twine"))   # gathered by hand (test_first_hour)
	craft("twine", cost_of("log_workbench", "twine"))
	go(WORKSHOP + Vector3(-1.5, 0.0, -1.5))
	craft("wooden_pin", 2)
	go(WORKSHOP)
	var bench: int = build("log_workbench", WORKSHOP + Vector3(3.5, 0.0, -4.0), "6i")
	go(WORKSHOP + Vector3(2.0, 0.0, -2.5))
	craft("wooden_cart_wheel", 2)
	craft("axle", 1)
	check(bench >= 0 and have("wooden_cart_wheel") == 2 and have("axle") == 1, "6i. two Wooden cart wheels and an Axle at the Carpenter's bench")
	go(DEPOT_A + Vector3(4.0, 0.0, 6.0))
	cart = build("handcart", DEPOT_A + Vector3(2.6, 0.0, 4.5), "6j")

	if cart < 0:
		return

	check(str(items._items[cart]["struct"].get("owner", "")) == KEYS[1], "6j. the Handcart is its builder's")

	# Desk B at depot B.
	go(DEPOT_B + Vector3(0.0, 0.0, 1.0))
	desk_b = build("warehouse_desk", DEPOT_B + Vector3(0.0, 0.0, -3.0), "6k")

	# The loaded crate lifted onto the cart, wheeled to depot B, set down by desk B.
	go(DEPOT_A + Vector3(1.3, 0.0, 5.5))
	var cart_uid: int = int(items._items[cart]["struct"]["uid"])
	items.action(1, Net.ACT_CART, crate, Carts.OP_LOAD, 0, Vector3.ZERO)
	check(int(items._items[crate]["struct"].get("on", 0)) == cart_uid, "6l. the loaded crate goes onto the Handcart")
	check(not view(1, desk_a).has(n("stone")), "6l. desk A no longer lists it")
	var meat_slot: int = box_of(crate).numbers.find(n("raw_meat"))
	var age0: int = box_of(crate).wear[meat_slot] if meat_slot >= 0 else -1
	go(items._items[cart]["pos"] + Vector3(0.0, 0.0, 1.7))
	items.action(1, Net.ACT_CART, cart, Carts.OP_GRAB, 0, Vector3.ZERO)
	check(int(items._carts.puller_of.get(1, 0)) == cart, "6m. the owner takes the handle")
	walk(DEPOT_A + Vector3(6.0, 0.0, 60.0))
	items._spoil_tick(float(items.table.spoilage().get("tick_s", 15)) * 40.0)   # time on the road
	walk(DEPOT_B + Vector3(3.0, 0.0, 2.0))
	var aged: int = box_of(crate).wear[meat_slot] if meat_slot >= 0 else -1
	items.action(1, Net.ACT_CART, 0, Carts.OP_RELEASE, 0, Vector3.ZERO)
	check((items._items[cart]["pos"] as Vector3).distance_to(DEPOT_B) < 8.0 and int(items._carts.puller_of.get(1, 0)) == 0, "6n. the cart is wheeled to depot B and let go (%s)" % str(items._items[cart]["pos"]))
	go(items._items[cart]["pos"] + Vector3(1.0, 0.0, 0.0))
	items.action(1, Net.ACT_CART, crate, Carts.OP_UNLOAD, 0, Vector3.ZERO)
	check(not items._items[crate]["struct"].has("on"), "6o. the crate is set down at depot B")
	go(DEPOT_B + Vector3(0.0, 0.0, -1.5))
	check(counts_of(box_of(crate)) == cargo and int(view(1, desk_b).get(n("stone"), 0)) == 5 and int(views[1][1].get(n("raw_meat"), 0)) == 2, "6p. contents identical (%s) and desk B lists them" % str(counts_of(box_of(crate))))
	go(DEPOT_A)
	check(not view(1, desk_a).has(n("stone")), "6p. desk A does not")
	items._spoil_tick(float(items.table.spoilage().get("tick_s", 15)) * 20.0)
	check(age0 >= 0 and aged > age0 and box_of(crate).wear[meat_slot] > aged, "6q. the meat in the crate aged on the road (%d -> %d) and goes on ageing at B (%d)" % [age0, aged, box_of(crate).wear[meat_slot] if meat_slot >= 0 else -1])


# --- 7. Save and reload ----------------------------------------------------------------------------------------------------------------
# What the world holds: placed pieces by kind, every container's contents by uid, each player's pack and worn items (with the worn bag's contents).
func snapshot() -> Dictionary:
	var pieces: Dictionary = {}
	var boxes: Dictionary = {}
	var people: Dictionary = {}

	for id in items._items:
		if items._items[id].has("struct"):
			var kind: String = str(items._items[id]["struct"]["kind"]) + (" (site)" if items._items[id]["struct"].has("site") else "")
			pieces[kind] = int(pieces.get(kind, 0)) + 1

	for uid in items._chests:
		boxes[int(uid)] = counts_of(items._chests[uid])

	for p in KEYS:
		if items.inventory_of(p) == null:
			continue

		var worn: Array = []

		for w in items.worn_slots_of(p):
			if int(w[0]) != 0:
				worn.append([int(w[0]), int(w[2]), JSON.stringify(w[3])])

		people[KEYS[p]] = {"pack": counts_of(items.inventory_of(p)), "worn": worn}

	return {"pieces": pieces, "boxes": boxes, "people": people}


func step7_save_and_reload() -> void:
	step("7 save and reload")
	var before: Dictionary = snapshot()
	var second: bool = items.inventory_of(2) != null
	items._dirty = true
	items.save()
	items._finish_writer()
	items = make_server()
	join(1, DEPOT_B)
	if second:
		join(2, DEPOT_A)

	inv = items.inventory_of(1)
	var after: Dictionary = snapshot()

	for part in ["pieces", "boxes", "people"]:
		var a: Dictionary = before[part]
		var b: Dictionary = after[part]
		var differ: Array = []

		for k in a:
			if JSON.stringify(a[k]) != JSON.stringify(b.get(k, null)):
				differ.append("%s: %s -> %s" % [str(k), JSON.stringify(a[k]), JSON.stringify(b.get(k, null))])

		for k in b:
			if not a.has(k):
				differ.append("%s: new %s" % [str(k), JSON.stringify(b[k])])

		check(differ.is_empty() and not a.is_empty(), "7. %s: %d before, all identical after the reload %s" % [part, a.size(), str(differ.slice(0, 6))])

	var worn_now: Array = items.worn_of(1)
	check(worn_now.has(n("gambeson")) and worn_now.has(n("mail_shirt")) and worn_now.has(n("backpack")), "7. the gambeson, the mail shirt and the backpack are still worn")
	var chest_again: int = standing_at("plank_chest", DEPOT_A + Vector3(2.0, 0.0, 0.0))
	check(chest_again >= 0 and not items._lock_of(items._items[chest_again]).is_empty(), "7. the Rustic - Chest is still locked")
