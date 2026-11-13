extends SceneTree

# Mission 001 phase 6: cooking and preservation (master s3.12 [D12], s3.14 [D14, D17]; companion FOOD_PREPARATION_PRESERVATION_SERVING.md s1, s2, s5)
# through the real server, recipes and blueprints. Amounts are read from the live data, so tuning keeps the test valid.
#   1. the data: a log-and-twine Food preparation table, no food made in the pack alone, every prepared food cooks from itself only;
#   2. pre-iron Flatbread: prepared at the built table, baked at a built Clay hearth (the ingredients are spent once), and on a Clay - Griddle at a
#      campfire; a cooked food inherits the age of what it was made from; a fish still roasts straight on the fire;
#   3. post-iron: a Frying pan made at a burning Smithy, an omelette fried in it at the campfire (the pan is kept);
#   4. the Fireplace cooking crane cooks a stew only while its fireplace burns;
#   5. Sauerkraut sealed as one batch at a built Preserving jar #830: Maturing (not eaten, not an ingredient), then Ready and eaten; stale
#      cabbage is refused; batches sealed at different times never merge until both are Ready; the age survives save and load;
#   6. batch room: a pack at its carry limit sends the batch to the player's nearby chest; a batch is capped to the room there, refused with none, waits when the
#      room fills before it is done, and never lands on the ground; Maturing stacks in a chest or on the ground are no craft stock; Hob will not
#      buy one and an NPC order does not count or take one;
#   7. Smoked meat at a built Smoker, Dried mushrooms at a built Drying rack (outside the mushrooms group).
# Station materials, iron, charcoal, eggs and the like are given: they are gathered or made elsewhere (test_first_hour, test_iron_saw_route).
#   godot --headless --path . --script res://src/worldgen/tools/test_cooking_route.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const TradeScript := preload("res://src/stream/server_trade.gd")

const HERE := Vector3(0.0, 10.0, 0.0)
const PRE_SAW := ["log", "stick", "twine", "stone", "clay"]   # master s3.12 reconciliation: the table needs no Planks or metal
const PREPARED := {"flatbread": "unbaked_flatbread", "rye_flatbread": "unbaked_rye_flatbread", "garlic_bread": "unbaked_garlic_flatbread",
	"honey_loaf": "unbaked_honey_loaf", "trail_bread": "unbaked_trail_bread", "oat_cakes": "unbaked_oatcakes", "chestnut_cakes": "unbaked_chestnut_cakes",
	"apple_pie": "unbaked_apple_pie", "fish_pie": "unbaked_fish_pie", "venison_pie": "unbaked_venison_pie", "meatballs": "uncooked_meatballs",
	"sausage": "uncooked_sausages", "meat_skewer": "uncooked_meat_skewers", "mushroom_skewer": "uncooked_mushroom_skewers",
	"crab_cakes": "uncooked_crab_cakes", "banana_fritter": "banana_fritter_batter"}

var failures: int = 0
var items
var said: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1
		print("     the server said: ", str(said.slice(maxi(said.size() - 3, 0))) if not said.is_empty() else "nothing")


func num(id: String) -> int:
	return items.table.number_of(id)


func have(id: String) -> int:
	return items.inventory_of(1).count_of(num(id))


func recipe_number(id: String) -> int:
	for n in items.recipes.numbers():
		if str(items.recipes.recipe(int(n)).get("id", "")) == id:
			return int(n)

	return 0


func recipe(id: String) -> Dictionary:
	return items.recipes.recipe(recipe_number(id))


func give_needs(recipe_id: String, times: int = 1) -> void:
	for need in recipe(recipe_id).get("needs", []):
		items.give(1, int(need[0]), int(need[1]) * times)


func craft(id: String, times: int, seconds: int) -> void:
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, recipe_number(id), 0, times, Vector3.ZERO)

	for s in range(seconds):
		items.tick(1.0)

	collect()

	for k in range(items.craft_queue_of(1).size()):   # a craft still waiting would hold up every later one: cancel it (refunded), the check then fails alone
		items.action(1, Net.ACT_CRAFT_CANCEL, 0, 0, 0, Vector3.ZERO)


# Station products stay in the station (master s2.5, M001-T18): after a craft the player takes them out of their own station stores beside
# them through the real server path (open, Take all, close), as a player does.
func collect() -> void:
	for id in items._items.keys():
		var it: Dictionary = items._items.get(id, {})

		if it.has("struct") and items._is_station_store(it) and str(it["struct"].get("owner", "")) == items.key_of(1) and (it["pos"] as Vector3).distance_to(items.position_of(1)) <= 4.0:
			items.action(1, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)
			items.action(1, Net.ACT_BULK, ItemsScript.BULK_TAKE_ALL, 0, 0, Vector3.ZERO)
			items.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)


func blueprint_of(structure: String) -> Dictionary:
	for number in items._blueprints:
		if str(items._blueprints[number].get("structure", "")) == structure:
			return items._blueprints[number]

	return {}


func standing(structure: String) -> int:
	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == structure and not items._items[id]["struct"].has("site"):
			return int(id)

	return -1


# Builds a structure from its blueprint: the materials are put in the pack, and the pack must give exactly the cost.
func build(structure: String, at: Vector3) -> int:
	var bp: Dictionary = blueprint_of(structure)

	for need in bp.get("cost", []):
		items.give(1, num(str(need[0])), int(need[1]))

	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(bp.get("number", 0)), 0, 0, at)
	var id: int = standing(structure)
	var spent: bool = bp.get("cost", []).all(func(c): return have(str(c[0])) == 0) if id >= 0 else false
	check(id >= 0 and spent, "the %s stands, built from %s" % [structure, str(bp.get("cost", []))])
	return id


func slots_of(id: String) -> Array:
	var out: Array = []
	var inv = items.inventory_of(1)

	for i in inv.slot_count:
		if inv.numbers[i] == num(id):
			out.append(i)

	return out


func eat(slot: int) -> void:
	items._last_eat.clear()
	items.vitals_of(1)["fed"] = 100.0
	items.action(1, Net.ACT_EAT, slot, 0, 0, Vector3.ZERO)


# Was `word` in one of the last few things the server said?
func told(word: String) -> bool:
	return said.slice(maxi(said.size() - 4, 0)).any(func(t): return str(t).contains(word))


func loose(id: String) -> int:
	var total: int = 0

	for wid in items._items:
		if not items._items[wid].has("struct") and int(items._items[wid].get("number", 0)) == num(id):
			total += int(items._items[wid]["count"])

	return total


func _init() -> void:
	var dir: String = "user://test_cooking_route"
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
	items._vitals_cfg["eat_pace_ms"] = 0
	items.peer_connected_hello(1, "cooking00001")
	items.report_position(1, HERE)
	items.vitals_of(1)["weight"] = 5000.0   # carrying is not under test until step 6

	# 1. The data.
	var table_cost: Array = blueprint_of("food_preparation_table").get("cost", []).map(func(c): return str(c[0]))
	check(not table_cost.is_empty() and table_cost.all(func(c): return c in PRE_SAW), "1a. the Food preparation table is built before the first saw and metal, of %s" % str(table_cost))

	for id in ["energy_bar", "fruit_juice"]:
		check(str(recipe(id).get("station", "")) == "food_preparation_table", "1b. %s is made at the Food preparation table, not in the pack" % id)

	for dish in PREPARED:
		var prep_id: String = "prep_" + dish
		var cook_id: String = "cook_" + dish if recipe_number("cook_" + dish) > 0 else dish
		var cook_needs: Array = recipe(cook_id).get("needs", [])
		check(str(recipe(prep_id).get("station", "")) == "food_preparation_table" and int(recipe(prep_id).get("gives", [0])[0]) == num(PREPARED[dish]), "1c. %s is prepared at the table" % PREPARED[dish])
		check(cook_needs.size() == 1 and int(cook_needs[0][0]) == num(PREPARED[dish]) and str(recipe(cook_id).get("station", "")) != "food_preparation_table", "1d. %s cooks from %s alone" % [dish, PREPARED[dish]])

	# 2. Pre-iron Flatbread.
	items.give(1, num("wooden_hammer"), 1)
	give_needs("prep_flatbread")
	craft("prep_flatbread", 1, 20)
	check(have("unbaked_flatbread") == 0 and have("flour") > 0, "2a. no table: the dough is not made in the pack")
	var prep_table: int = build("food_preparation_table", HERE + Vector3(3.0, 0.0, 0.0))
	craft("prep_flatbread", 1, 20)
	var dough: int = int(recipe("prep_flatbread")["gives"][1])
	check(have("unbaked_flatbread") == dough and have("flour") == 0 and have("water") == 0, "2b. the table makes %d Unbaked flatbread from the flour and water" % have("unbaked_flatbread"))
	craft("cook_flatbread", 1, 30)
	check(have("flatbread") == 0 and have("unbaked_flatbread") == dough, "2c. no hearth, no fire: nothing bakes")
	var hearth: int = build("clay_hearth", HERE + Vector3(-3.0, 0.0, 0.0))
	craft("cook_flatbread", 1, 30)
	check(have("flatbread") == int(recipe("cook_flatbread")["gives"][1]) and have("unbaked_flatbread") == 0 and have("flour") == 0, "2d. the Clay hearth bakes %d Flatbread from the dough only (no flour charged again)" % have("flatbread"))

	# A cooked food starts as old as its stalest input (s3.14 crafted age): half-spoiled dough bakes into half-spoiled bread.
	var inv = items.inventory_of(1)
	inv.remove(num("flatbread"), have("flatbread"))
	inv.add(num("unbaked_flatbread"), dough, int(items.table.shelf_units(num("unbaked_flatbread")) * 0.5))
	craft("cook_flatbread", 1, 30)
	var bread_slot: int = slots_of("flatbread")[0] if not slots_of("flatbread").is_empty() else -1
	check(bread_slot >= 0 and absf(items.table.freshness(num("flatbread"), inv.wear[bread_slot]) - 0.5) < 0.03, "2e. bread from half-fresh dough is half fresh (%.2f)" % (items.table.freshness(num("flatbread"), inv.wear[bread_slot]) if bread_slot >= 0 else -1.0))
	inv.remove(num("flatbread"), have("flatbread"))

	# The Clay - Griddle bakes the same dough on a plain campfire, before any hearth (pre-iron), and is kept.
	items._items.erase(hearth)
	var fire_id: int = items._next_id   # _next_id is the next free world id
	items._items[fire_id] = {"number": num("campfire_kit"), "count": 1, "pos": HERE + Vector3(0.0, 0.0, -2.0), "left": 1.0e9, "fire": {"state": 1, "burn_left": 1.0e6, "covered": false, "recheck": 5.0}}
	items._next_id += 1
	give_needs("clay_griddle")
	craft("clay_griddle", 1, 30)
	check(have("clay_griddle") == 1 and have("clay") == 0, "2f. a Clay - Griddle is fired at the campfire from clay")
	give_needs("prep_flatbread")
	craft("prep_flatbread", 1, 20)
	craft("cook_flatbread", 1, 30)
	check(have("flatbread") == 0, "2g. without the hearth the plain recipe waits")
	craft("cook_flatbread_clay_griddle", 1, 30)
	check(have("flatbread") == int(recipe("cook_flatbread_clay_griddle")["gives"][1]) and have("unbaked_flatbread") == 0 and have("clay_griddle") == 1, "2h. on the griddle over the campfire the dough bakes; the griddle is kept")
	inv.remove(num("flatbread"), have("flatbread"))
	give_needs("cook_herb_fish")
	craft("cook_herb_fish", 1, 30)
	check(have("herb_fish") == int(recipe("cook_herb_fish")["gives"][1]), "2i. a fish roasts straight on the campfire, no table step (companion s5 item 2)")
	inv.remove(num("herb_fish"), have("herb_fish"))

	# 3. Post-iron: the Frying pan at a burning Smithy, then an omelette in it.
	var smithy: int = build("blacksmithy", HERE + Vector3(0.0, 0.0, 4.0))
	give_needs("iron_frying_pan")
	items.give(1, num("charcoal"), 2)
	craft("iron_frying_pan", 1, 60)
	check(have("iron_frying_pan") == 1 and have("iron_ingot") == 0 and bool(items._items[smithy]["struct"].get("lit", false)), "3a. the Iron - Frying pan is made at the burning Smithy")
	give_needs("cook_herb_omelette_iron_frying_pan")
	craft("cook_herb_omelette_iron_frying_pan", 1, 30)
	check(have("herb_omelette") == int(recipe("cook_herb_omelette_iron_frying_pan")["gives"][1]) and have("egg") == 0 and have("iron_frying_pan") == 1, "3b. an Herb omelette fries in the pan at the campfire; the pan is kept")
	items._items.erase(smithy)
	items._items.erase(fire_id)
	items._items.erase(prep_table)

	# 4. The Fireplace cooking crane, away from every fire and pot: it cooks only while its fireplace burns.
	var hearth_at: Vector3 = Vector3(60.0, 10.0, 0.0)
	items.report_position(1, hearth_at)
	var fireplace: int = items._next_id   # set down as it stands (a fireplace needs a roof over it to be built; test_blueprints covers that)
	items._items[fireplace] = {"number": num("fireplace"), "count": 1, "pos": hearth_at + Vector3(0.0, 0.0, 3.0), "left": 1.0e9, "struct": {"kind": "fireplace", "yaw": 0.0}}
	items._next_id += 1
	var crane: int = build("fireplace_cooking_crane", hearth_at + Vector3(1.5, 0.0, 2.6))
	give_needs("cook_hunters_stew")
	craft("cook_hunters_stew", 1, 40)
	check(have("hunters_stew") == 0 and crane >= 0, "4a. a cold fireplace with its crane cooks nothing")
	items._items[fireplace]["struct"]["lit"] = true
	items._items[fireplace]["struct"]["fuel_left"] = 1.0e6   # a fireplace burns while it has fuel (ServerItems._lights_tick)
	craft("cook_hunters_stew", 1, 40)
	check(have("hunters_stew") == int(recipe("cook_hunters_stew")["gives"][1]), "4b. with the fireplace burning the crane cooks the stew (campfire pot work)")
	items._items[fireplace]["struct"]["lit"] = false
	items._items[fireplace]["struct"].erase("fuel_left")
	check(not items.station_near(1, "campfire_pot"), "4c. the fire out, the crane stops")
	inv.remove(num("hunters_stew"), have("hunters_stew"))

	# 5. Sauerkraut sealed at a built Preserving jar #830.
	var jar_at: Vector3 = Vector3(-60.0, 10.0, 0.0)
	items.report_position(1, jar_at)
	build("preserving_jar", jar_at + Vector3(2.0, 0.0, 0.0))
	var per: int = int(recipe("cook_sauerkraut")["gives"][1])
	var batch: int = 5
	give_needs("cook_sauerkraut", batch)
	craft("cook_sauerkraut", batch, int(recipe("cook_sauerkraut")["craft_s"]) + 3)
	var kraut: Array = slots_of("sauerkraut")
	check(have("sauerkraut") == per * batch and kraut.size() == 1 and have("cabbage") == 0, "5a. one craft seals the whole batch: %d Sauerkraut in one stack (%d stacks)" % [have("sauerkraut"), kraut.size()])
	check(float(recipe("cook_sauerkraut").get("ready_age", 0.0)) > 0.0 and inv.maturing_at(kraut[0]) and inv.count_fill(num("sauerkraut"), false) == 0, "5b. the batch is Maturing and counts as no ingredient")
	eat(kraut[0])
	check(have("sauerkraut") == per * batch and told("maturing"), "5c. a Maturing stack is not eaten")
	var ready_s: float = float(recipe("cook_sauerkraut")["ready_age"]) * 3600.0 / items.GAME_RATE
	items._spoil_tick(ready_s * 0.25)
	give_needs("cook_sauerkraut", 1)
	craft("cook_sauerkraut", 1, int(recipe("cook_sauerkraut")["craft_s"]) + 3)
	kraut = slots_of("sauerkraut")
	check(kraut.size() == 2 and inv.wear[kraut[0]] != inv.wear[kraut[1]], "5d. a batch sealed later is its own stack (ages %d and %d)" % [inv.wear[kraut[0]], inv.wear[kraut[1]]] if kraut.size() == 2 else "5d. two stacks")
	var older: int = kraut[0] if inv.wear[kraut[0]] > inv.wear[kraut[1]] else kraut[1]
	var newer: int = kraut[1] if older == kraut[0] else kraut[0]
	items._spoil_tick(ready_s * 0.85)
	check(not inv.maturing_at(older) and inv.maturing_at(newer), "5e. the first batch is Ready, the second still Maturing")
	inv.move(newer, older)
	check(inv.counts[older] == per * batch or inv.counts[newer] == per * batch, "5f. a Maturing stack never joins a Ready one")
	kraut = slots_of("sauerkraut")
	older = kraut[0] if inv.wear[kraut[0]] > inv.wear[kraut[1]] else kraut[1]
	eat(older)
	check(have("sauerkraut") == per * batch + per - 1, "5g. a Ready stack is eaten")
	items._spoil_tick(ready_s * 0.3)
	kraut = slots_of("sauerkraut")
	inv.move(kraut[1], kraut[0])
	check(slots_of("sauerkraut").size() == 1 and have("sauerkraut") == per * batch + per - 1, "5h. once both are Ready they join as any food does (%d stacks)" % slots_of("sauerkraut").size())

	# Stale produce is refused, and given back as it was.
	var cabbage: int = num("cabbage")
	items.table._shelf_cache[cabbage] = 1000   # cabbage keeps for ever in the data; give it a shelf life for this check only
	inv.add(cabbage, int(recipe("cook_sauerkraut")["needs"].filter(func(c): return int(c[0]) == cabbage)[0][1]), 700)
	items.give(1, num("sea_salt"), 1)
	craft("cook_sauerkraut", 1, int(recipe("cook_sauerkraut")["craft_s"]) + 3)
	check(have("sauerkraut") == per * batch + per - 1 and have("cabbage") > 0 and told("fresh"), "5i. cabbage at 30 percent freshness is not sealed and comes back")
	items.table._shelf_cache.erase(cabbage)
	inv.remove(cabbage, have("cabbage"))
	inv.remove(num("sea_salt"), have("sea_salt"))

	# The age survives save and load.
	var age_now: int = inv.wear[slots_of("sauerkraut")[0]]
	items.save()
	items._finish_writer()
	var again = ItemsScript.new()
	again.send_full = func(_p, _b): pass
	again.send_slots = func(_p, _b): pass
	again.send_world_items = func(_p, _a, _r): pass
	again.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	again.send_reject = func(_p, _r): pass
	again.send_notice = func(_p, text): said.append(str(text))
	again.ground_height = func(_x, _z): return 10.0
	again.setup(ItemTableScript.load_default(), dir)
	again.admin_mode_on = func(_p): return false
	again.peer_connected_hello(1, "cooking00001")
	var inv2 = again.inventory_of(1)
	var at2: int = inv2.numbers.find(num("sauerkraut"))
	check(at2 >= 0 and inv2.wear[at2] == age_now and inv2.count_of(num("sauerkraut")) == per * batch + per - 1, "5j. the sealed food's age and count survive save and load")
	again._finish_writer()

	# 6. Batch room: a pack at its carry limit sends the batch to the player's chest within reach; the room caps it; never the ground.
	inv.remove(num("sauerkraut"), have("sauerkraut"))
	var chest: int = build("chest", jar_at + Vector3(-2.0, 0.0, 0.0))
	var box = items._chests[int(items._items[chest]["struct"]["uid"])]

	for k in range(2000):   # the pack grows (protocol 116), so only its carry limit leaves no room: pots until one Sauerkraut is too heavy
		if items._fit(1, inv, num("sauerkraut"), 1) <= 0:
			break

		inv.add(num("clay_pot"), 1)

	var cab_need: int = int(recipe("cook_sauerkraut")["needs"].filter(func(c): return int(c[0]) == cabbage)[0][1])
	var salt_need: int = int(recipe("cook_sauerkraut")["needs"].filter(func(c): return int(c[0]) == num("sea_salt"))[0][1])
	items.drop_in_world(cabbage, cab_need * batch, jar_at + Vector3(0.5, 0.0, 0.5))
	items.drop_in_world(num("sea_salt"), salt_need * batch, jar_at + Vector3(-0.5, 0.0, 0.5))
	craft("cook_sauerkraut", batch, int(recipe("cook_sauerkraut")["craft_s"]) + 3)
	check(have("sauerkraut") == 0 and box.count_of(num("sauerkraut")) == per * batch and loose("sauerkraut") == 0 and loose("cabbage") == 0, "6a. pack at its carry limit: all %d go into the chest beside the jar (chest %d, ground %d)" % [per * batch, box.count_of(num("sauerkraut")), loose("sauerkraut")])

	# Maturing stacks in the chest and on the ground are no ingredient; once the ground stack is Ready it is (the ground ages it faster than a chest).
	var kraut_n: int = num("sauerkraut")
	items.drop_in_world(kraut_n, 3, jar_at + Vector3(0.0, 0.0, 1.5))
	check(loose("sauerkraut") == 3 and items._stock_have(inv, kraut_n, items._stock_of(1)) == 0, "6b. Maturing Sauerkraut in the chest (%d) and on the ground (3) is no craft stock" % box.count_of(kraut_n))
	items._spoil_tick(ready_s * 1.1)
	check(items._stock_have(inv, kraut_n, items._stock_of(1)) == 3, "6c. the ground stack, Ready first, counts; the chest's, still Maturing, does not (%d)" % items._stock_have(inv, kraut_n, items._stock_of(1)))
	box.remove(kraut_n, box.count_of(kraut_n))

	for wid in items._items.keys():
		if not items._items[wid].has("struct") and int(items._items[wid].get("number", 0)) == kraut_n:
			items._items.erase(wid)

	# The room caps the batch: clay fills the chest by weight until five Sauerkraut still fit, so two crafts of the five asked are sealed.
	var filler: int = num("clay")   # 0.1 kg a piece: fills the chest by weight in small steps

	for k in range(2000):
		if items._box_room(chest, kraut_n, 99) < 6:
			break

		box.add(filler, 1)

	var room_crafts: int = floori(float(items._box_room(chest, kraut_n, 99)) / float(per))
	items.drop_in_world(cabbage, cab_need * batch, jar_at + Vector3(0.5, 0.0, 0.5))
	items.drop_in_world(num("sea_salt"), salt_need * batch, jar_at + Vector3(-0.5, 0.0, 0.5))
	craft("cook_sauerkraut", batch, int(recipe("cook_sauerkraut")["craft_s"]) + 3)
	check(room_crafts > 0 and room_crafts < batch and box.count_of(kraut_n) == room_crafts * per and loose("cabbage") == cab_need * (batch - room_crafts) and loose("sauerkraut") == 0 and told("Room for only"), "6d. room for %d crafts: %d sealed into the chest, the rest of the cabbage untouched, nothing on the ground" % [room_crafts, box.count_of(kraut_n)])

	# No room at all: refused, nothing taken.
	for k in range(2000):
		if items._box_room(chest, kraut_n, 99) <= 0:
			break

		box.add(filler, 1)

	var kraut_before: int = box.count_of(kraut_n)
	craft("cook_sauerkraut", 1, int(recipe("cook_sauerkraut")["craft_s"]) + 3)
	check(box.count_of(kraut_n) == kraut_before and loose("cabbage") == cab_need * (batch - room_crafts) and loose("sauerkraut") == 0 and told("No room"), "6e. pack and chest full: the batch is refused and nothing is taken")

	# Room that fills while the batch is sealed: the finished batch waits, its ingredients held, until there is room again.
	box.remove(kraut_n, box.count_of(kraut_n))
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, recipe_number("cook_sauerkraut"), 0, 1, Vector3.ZERO)
	var queued: bool = not items.craft_queue_of(1).is_empty()

	for k in range(2000):
		if items._box_room(chest, kraut_n, 99) <= 0:
			break

		box.add(filler, 1)

	items._station_said.clear()   # the wait is said at most every 8 s; this run is faster than that

	for s in range(int(recipe("cook_sauerkraut")["craft_s"]) + 3):
		items.tick(1.0)

	check(queued and not items.craft_queue_of(1).is_empty() and box.count_of(kraut_n) == 0 and loose("sauerkraut") == 0 and told("waits"), "6f. the room filled meanwhile: the batch waits, not on the ground")
	box.remove(filler, box.count_of(filler))

	for s in range(3):
		items.tick(1.0)

	check(items.craft_queue_of(1).is_empty() and box.count_of(kraut_n) == per and loose("sauerkraut") == 0, "6g. room again: the waiting batch goes into the chest")
	inv.remove(num("clay_pot"), have("clay_pot"))

	# Hob does not buy a Maturing stack, and an NPC order neither counts nor takes one.
	inv.add(kraut_n, 2)
	var trade = TradeScript.new()
	trade.items = items
	trade.npcs = {"npcs": {"hob": {"dormant": false, "placed": true, "pos": jar_at + Vector3(0.0, 0.0, -1.0)}}}
	trade.setup(dir)
	trade.now = func(): return 1000.0
	trade.game_seconds = func(): return 0.0
	var kraut_slot: int = inv.numbers.find(kraut_n)
	check(trade.deal(1, "hob", 1, kraut_slot, 2) == "That is still maturing." and have("sauerkraut") == 2, "6h. Hob will not buy Maturing Sauerkraut")
	check(items.count_for(1, "sauerkraut", true) == 0 and not items.take_from(1, "sauerkraut", 1, true) and have("sauerkraut") == 2, "6i. an NPC order neither counts nor takes it")
	inv.remove(kraut_n, 2)

	# 7. Smoked meat and Dried mushrooms, one step each at their stations.
	var smoke_at: Vector3 = Vector3(0.0, 10.0, 60.0)
	items.report_position(1, smoke_at)
	give_needs("smoked_meat")
	craft("smoked_meat", 1, 40)
	check(have("smoked_meat") == 0, "7a. no Smoker: no smoked meat")
	build("smoker", smoke_at + Vector3(2.0, 0.0, 0.0))
	craft("smoked_meat", 1, 40)
	check(have("smoked_meat") == int(recipe("smoked_meat")["gives"][1]) and have("raw_meat") == 0, "7b. the Smoker smokes raw meat and salt into Smoked meat")
	var vit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/vitals.json"))["food"]["by_id"]
	var kg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/weights.json"))["by_id"]
	check(int(vit.get("smoked_meat", 0)) > int(vit.get("jerky", 0)) and float(kg.get("smoked_meat", 0.0)) > float(kg.get("jerky", 0.0)) and items.table.shelf_units(num("smoked_meat")) > 0, "7c. Smoked meat is a heavier joint with more food than Jerky, and it keeps")
	build("drying_rack", smoke_at + Vector3(-2.0, 0.0, 0.0))

	for id in ["porcini", "chanterelles", "morels", "puffball"]:
		give_needs("dried_mushrooms_" + id)
		craft("dried_mushrooms_" + id, 1, 30)

	check(have("dried_mushrooms") == 4 * int(recipe("dried_mushrooms_porcini")["gives"][1]) and have("porcini") == 0 and have("puffball") == 0, "7d. each fresh mushroom dries at the Drying rack (%d Dried mushrooms)" % have("dried_mushrooms"))
	check(not inv.fills_of(num("mushrooms")).has(num("dried_mushrooms")) and items.table.shelf_units(num("mushrooms")) > 0 and items.table.shelf_units(num("puffball")) > 0, "7e. Dried mushrooms are outside the mushrooms group; Mushrooms and Puffball spoil")
	check(items.table.shelf_units(num("dried_mushrooms")) > items.table.shelf_units(num("porcini")), "7f. dried mushrooms keep longer than fresh")

	print("cooking route: %d failures" % failures)
	items._finish_writer()
	quit(1 if failures > 0 else 0)
