extends SceneTree

# The cooking and preserving loop, over server restarts (the coordinator, 23 Nov 2026): every live food recipe is made at its station from
# live inputs and gives what its row says; what it gives feeds what its tooltip says (VitalsRules.food_value, as the server's eat) and, for a
# dish, its dishes.json kcal (kcal foods are eaten; drinks, medicines and energy aids are only checked to do something); every raw food the
# campfire cooks roasts into its cooks_into row on the fire (raw meat also in the fire's store) and keeps longer than it did raw; raw meat
# makes you sick later and rotten food at once, roast meat not at all; raw meat ages slower in a chest and slower still in a root cellar than in
# the pack; a craft half done at a station (with its progress), the fire's store and food ages carry over a restart; two players' crafts at
# one station both finish, each from their own pack; a herbal tea is a cup of water with its energy or cure. A year of rot by container is test_winter_stores'; the jar's maturing is test_goal_events'.
#   godot --headless --path . --script res://src/worldgen/tools/test_cooking_loop.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const CraftHand := preload("res://src/worldgen/tools/craft_hand.gd")
const VitalsRules := preload("res://src/shared/vitals_rules.gd")

const DIR := "user://test_cooking_loop"
const SPACING := 256.0   # one yard to a 256 m chunk: no station serves another yard

var failures: int = 0
var passes: int = 0
var items
var said: Dictionary = {}
var next_peer: int = 100
var clock: Array = [1000.0 * 86400.0 + 12.0 * 3600.0]
var unix: Array = [2.0e9]


func check(ok: bool, what: String, peer: int = 0) -> void:
	if ok:
		passes += 1
	else:
		failures += 1

	print(("ok   " if ok else "FAIL ") + what)

	if not ok and peer != 0:
		var told: Array = said.get(peer, [])
		print("     the server said: ", str(told.slice(maxi(told.size() - 3, 0))) if not told.is_empty() else "nothing")


func start(wipe: bool) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	if wipe:
		for sub in ["", "/world_items"]:
			DirAccess.make_dir_recursive_absolute(DIR + sub)

			for file in DirAccess.get_files_at(DIR + sub):
				DirAccess.remove_absolute(DIR + sub + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_reject = func(p, r): said.get_or_add(p, []).append("reject " + str(r))
	items.send_notice = func(p, text): said.get_or_add(p, []).append(str(text))
	items.ground_height = func(_x, _z): return 10.0
	items.unix_now = func(): return unix[0]
	items.setup(ItemTableScript.load_default(), DIR)
	items.admin_mode_on = func(_p): return false
	items.game_seconds = func(): return clock[0]
	items.skill_level = func(_p, _s): return 1.0
	items.dig_ground = func(_centre, _radius): return null
	items.ground_material = func(_x, _z): return "soil"


func save_all() -> void:
	items._dirty = true
	items.save()
	items._finish_writer()


func run(seconds: int) -> void:
	for s in seconds:
		items.tick(1.0)


# Queues recipe `number` for `peer` (its station and inputs already there) and runs until the queue is empty. Returns what came out.
func make(peer: int, number: int, r: Dictionary, give: bool = true) -> int:
	if give:
		for row in r.get("keeps", []):
			give_any(peer, int(row[0]), int(row[1]))

		for row in r.get("needs", []):
			give_any(peer, int(row[0]), int(row[1]))

	var out_n: int = int(r["gives"][0])
	var before: int = have(peer, out_n)
	items._last_queue_act.clear()
	items.action(peer, Net.ACT_CRAFT_QUEUE, number, 0, 1, CraftHand.at(items, peer, number))
	items.tick(1.0)

	for s in range(900):
		if items.craft_queue_of(peer).is_empty():
			break

		items.tick(1.0)

	items.tick(1.0)
	collect(peer)
	pick_up_near(peer, out_n)
	return have(peer, out_n) - before


func fire_near(at: Vector3) -> int:
	for id in items._items:
		if items._items[id].has("fire") and (items._items[id]["pos"] as Vector3).distance_to(at) < 0.5:
			return int(id)

	return -1


func slot_of(peer: int, number: int) -> int:
	return items.inventory_of(peer).numbers.find(number)


# Eats one of `number` from an empty stomach: the kcal it fed, and the kcal its tooltip promised (VitalsRules at its freshness).
func eat_one(peer: int, number: int) -> Array:
	var inv = items.inventory_of(peer)
	var slot: int = slot_of(peer, number)

	if slot < 0:
		return [-1, -1]

	var promised: int = VitalsRules.eaten_kcal(VitalsRules.food_value(items.table.id_of(number), items._vitals_cfg), items.table.freshness(number, inv.wear[slot]))
	var v: Dictionary = items.vitals_of(peer)
	v["fed"] = 0.0
	items._last_eat.clear()
	items.action(peer, Net.ACT_EAT, slot, 0, 0, Vector3.ZERO)
	return [int(round(float(v["fed"]))), promised]


# A new player standing in their own yard, far from every other.
func new_player() -> int:
	next_peer += 1
	var peer: int = next_peer
	items.peer_connected_hello(peer, "cookloop%07d" % peer)
	items.report_position(peer, yard(peer))
	items.vitals_of(peer)["weight"] = 1.0e6   # carrying is not under test
	items.vitals_of(peer)["food"] = 100.0
	items.vitals_of(peer)["water"] = 100.0
	return peer


func yard(peer: int) -> Vector3:
	var n: int = peer - 100
	return Vector3(128.0 + float(n % 40) * SPACING, 10.0, 128.0 + floorf(float(n) / 40.0) * SPACING)


func have(peer: int, number: int) -> int:
	return items.inventory_of(peer).count_of(number)


# Gives `count` of `number`; a group (Any nails, Any knife) gives its first live member, not its own plain id. Returns the number given.
func give_any(peer: int, number: int, count: int) -> int:
	for member in items.table.group_members(number):   # a group lists its own id first (the plain "knife", a material): a real live member
		var e: Dictionary = items.table.entry(items.table.id_of(int(member)))

		if int(member) != number and not bool(e.get("retired", false)) and not bool(e.get("future", false)):
			number = int(member)
			break

	if str(items.table.entry(items.table.id_of(number)).get("kind", "")) == "tool":
		items.give(peer, number, count)   # a tool, with its wear
	elif items.table.id_of(number).begins_with("log"):   # logs ride on the shoulder and a full shoulder swings no hammer: they lie at the feet,
		for one in range(count):                        # where a craft and a hammered site take them from (CraftStock LOOSE_STOCK_M)
			items.drop_in_world(number, 1, yard(peer) + Vector3(0.5 + 0.3 * float(one % 5), 0.0, -1.0 - 0.3 * floorf(float(one) / 5.0)))
	else:
		items.inventory_of(peer).add(number, count)   # a material into the pack

	return number


# The structure kind that gives `station` at `level` or more (its own station level, or an "also" row), the lowest that does.
func station_kind(station: String, level: int) -> String:
	var best: String = ""
	var best_lv: int = 99

	for kind in items._structures:
		var def: Dictionary = items._structures[kind]
		var lv: int = 0

		if str(def.get("station", "")) == station:
			lv = int(def.get("station_level", 1))
		elif def.get("also", {}) is Dictionary and (def.get("also", {}) as Dictionary).has(station):
			lv = int(def["also"][station])

		if lv >= level and lv < best_lv and str(def.get("kit", "")) != "" and (items._blueprint_of_kit.has(str(def["kit"])) or items.table.has_id(str(def["kit"]))):
			best = kind
			best_lv = lv

	return best


func newest_struct(kind: String) -> int:
	var best: int = -1

	for id in items._items:
		var it: Dictionary = items._items[id]

		if it.has("struct") and str(it["struct"]["kind"]) == kind and not it["struct"].has("site") and int(id) > best:
			best = int(id)

	return best


# A station of `station` at `level` beside the player, ready to work: fuel in its fuel slot, lit if it lights. "" when nothing gives it.
func set_station(peer: int, station: String, level: int) -> String:
	var at: Vector3 = yard(peer) + Vector3(1.5, 0.0, 0.0)

	if station == "campfire" and level <= 1:
		lay_fire(at)
		return "campfire"

	var kind: String = station_kind(station, level)

	if kind == "":
		return ""

	if kind == "campfire_pot":   # it hangs over a small fire: lay the fire first
		lay_fire(at)

	var kit: String = str(items._structures[kind]["kit"])

	if items._blueprint_of_kit.has(kit):
		items.place_piece(peer, kit, at)
	else:   # a station made as an item (the Mortar and pestle) is set down from the pack
		items.give(peer, items.table.number_of(kit), 1)
		items.place_item(peer, items.table.number_of(kit), at)

	var id: int = newest_struct(kind)

	if id < 0:
		return ""

	var def: Dictionary = items._structures[kind]

	if str(def.get("fuel_slot", "")) != "":
		var fuel: int = give_any(peer, items.table.number_of(str(def["fuel_slot"])), 20)
		put_in(peer, id, fuel, 20)

	return kind


func lay_fire(at: Vector3) -> void:
	items._items[items._next_id] = {"number": items.table.number_of("campfire_kit"), "count": 1, "pos": at, "left": 1.0e9, "fire": {"state": 1, "burn_left": 1.0e6, "covered": false, "recheck": 5.0}}
	items._next_id += 1


func put_in(peer: int, id: int, number: int, count: int) -> void:
	items.action(peer, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)
	items.action(peer, Net.ACT_CHEST_PUT, items.inventory_of(peer).numbers.find(number), id, count, Vector3.ZERO)
	items.action(peer, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)


# Takes everything out of the station stores beside the player (open, Take all, close), as after a craft.
func collect(peer: int) -> void:
	for id in items._items.keys():
		var it: Dictionary = items._items.get(id, {})

		if it.has("struct") and items._is_station_store(it) and (it["pos"] as Vector3).distance_to(yard(peer)) <= 4.0:
			items.action(peer, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)
			items.action(peer, Net.ACT_BULK, ItemsScript.BULK_TAKE_ALL, 0, 0, Vector3.ZERO)
			items.action(peer, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)


# Loose stacks of `number` on the ground beside the player, picked up.
func pick_up_near(peer: int, number: int) -> void:
	for id in items._items.keys():
		var it: Dictionary = items._items.get(id, {})

		if int(it.get("number", 0)) == number and not it.has("struct") and not it.has("scatter") and not it.has("fire") and (it["pos"] as Vector3).distance_to(yard(peer)) <= 5.0:
			items.action(peer, Net.ACT_PICKUP, int(id), 0, int(it["count"]), Vector3.ZERO)


func _init() -> void:
	start(true)
	var recipes: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/items/recipes.json")) as Dictionary)["recipes"]
	var dishes: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/items/dishes.json")) as Dictionary)["dishes"]

	# 1. Every live food recipe at its station, and what it gives feeds what the tooltip says.
	var made_n: int = 0
	var eligible: int = 0
	var skipped: Array = []
	var used: Dictionary = {}   # every item some live recipe takes, a group's members too
	var dead: Array = []

	for n in items.recipes.numbers():
		var ur: Dictionary = items.recipes.recipe(int(n))

		if bool(ur.get("locked", false)) or bool(ur.get("retired", false)):
			continue

		for row in ur.get("needs", []):
			for member in items.table.group_members(int(row[0])):
				used[int(member)] = true

			used[int(row[0])] = true

	for n in items.recipes.numbers():
		var r: Dictionary = items.recipes.recipe(int(n))
		var rid: String = str(r.get("id", ""))

		if bool(r.get("locked", false)) or bool(r.get("retired", false)) or str(recipes.get(rid, {}).get("category", "")) != "Food and drink":
			continue

		var matured: bool = float(r.get("ready_age", 0.0)) > 0.0

		for row in r.get("needs", []):
			for maker in items.recipes.makers_of(int(row[0])):
				matured = matured or float(items.recipes.recipe(int(maker)).get("ready_age", 0.0)) > 0.0

		if matured:
			skipped.append(rid)   # a jar matures it for game days: test_goal_events
			continue

		eligible += 1
		var peer: int = new_player()
		var station: String = str(r.get("station", ""))

		if station != "" and set_station(peer, station, int(r.get("station_level", 1))) == "":
			check(false, "1. %s: no structure gives its station %s" % [rid, station], peer)
			continue

		var out_n: int = int(r["gives"][0])
		var out_id: String = items.table.id_of(out_n)
		var got: int = make(peer, int(n), r)
		made_n += 1
		check(got >= int(r["gives"][1]), "1. %s%s gives %d %s (%d)" % [rid, " at " + station if station != "" else " by hand", int(r["gives"][1]), out_id, got], peer)
		var kcal: int = VitalsRules.food_value(out_id, items._vitals_cfg)

		if kcal <= 0 and VitalsRules.drink_value(out_id, items._vitals_cfg) <= 0 and VitalsRules.heal_value(out_id, items._vitals_cfg) <= 0 and not items._vitals_cfg.get("medicines", {}).has(out_id) and not items._vitals_cfg.get("energy_aids", {}).has(out_id) and not used.has(out_n) and not dead.has(out_id):
			dead.append(out_id)

		if dishes.has(out_id) and dishes[out_id].has("kcal"):
			check(kcal == int(dishes[out_id]["kcal"]), "1. %s feeds its dish row's %d kcal (%d)" % [out_id, int(dishes[out_id]["kcal"]), kcal])

		if got > 0 and kcal > 0 and VitalsRules.heal_value(out_id, items._vitals_cfg) <= 0:
			var fed: Array = eat_one(peer, out_n)
			check(fed[0] == fed[1] and fed[0] > 0, "1. %s eaten feeds what its tooltip says (%d, tooltip %d)" % [out_id, fed[0], fed[1]], peer)

		items.peer_left(peer)

	check(dead.is_empty(), "1. every food recipe gives something that feeds, drinks, heals, cures, gives energy or goes into another recipe (%s do none)" % str(dead))
	check(eligible > 0 and made_n == eligible, "1. %d of %d live food recipes made (%d matured in a jar, left to test_goal_events: %s)" % [made_n, eligible, skipped.size(), str(skipped)])

	# 2. Every raw food the campfire cooks: on the fire and in its store, into its cooks_into row, keeping longer than raw.
	var cook: int = new_player()
	var fire_at: Vector3 = yard(cook) + Vector3(1.5, 0.0, 0.0)
	items.give(cook, items.table.number_of("campfire_kit"), 1)
	items.inventory_of(cook).add(items.table.number_of("plant_fibre"), 4)
	items.action(cook, Net.ACT_PLACE, slot_of(cook, items.table.number_of("campfire_kit")), 0, 0, fire_at)
	var fire: int = fire_near(fire_at)

	if fire >= 0:
		items.action(cook, Net.ACT_LIGHT, fire, 0, 0, Vector3.ZERO)

	check(fire >= 0 and items.fire_is_lit(int(items._items[fire]["fire"]["state"])), "2. a campfire is set and lit", cook)

	if fire < 0:
		print("Test done: %d pass, %d fail" % [passes, failures])
		quit(1)
		return

	put_in(cook, fire, give_any(cook, items.table.number_of("firewood"), 10), 10)   # wood in its store keeps it burning
	var into: Dictionary = items._cooking.get("cooks_into", {})
	var wrong: Array = []
	var shorter: Array = []

	for raw_id in into:
		var raw_n: int = items.table.number_of(str(raw_id))
		var out_n: int = items.table.number_of(str(into[raw_id]))

		if raw_n == 0 or out_n == 0 or bool(items.table.entry(str(raw_id)).get("future", false)):
			continue

		items.inventory_of(cook).add(raw_n, 1)
		var before: int = have(cook, out_n)
		items._last_cook.clear()
		items.action(cook, Net.ACT_COOK, fire, 0, 0, Vector3.ZERO)

		if have(cook, out_n) != before + 1 or have(cook, raw_n) != 0:
			wrong.append(raw_id)
			items.inventory_of(cook).remove(raw_n, have(cook, raw_n))

		if items.table.shelf_units(raw_n) > 0 and items.table.shelf_units(out_n) <= items.table.shelf_units(raw_n):
			shorter.append("%s %d -> %s %d" % [raw_id, items.table.shelf_units(raw_n), into[raw_id], items.table.shelf_units(out_n)])

	check(wrong.is_empty(), "2. every raw food roasts on the campfire into its cooks_into row (%d kinds; wrong: %s)" % [into.size(), str(wrong)], cook)
	check(shorter.is_empty(), "2. and every roast keeps longer than it did raw (%s)" % str(shorter))
	var store_fire: Dictionary = items._items[fire]["fire"]
	var box = items._chests.get(int(store_fire.get("uid", -1))) if store_fire.has("uid") else null

	if box == null:
		box = items._chest_of(cook, fire)

	check(box != null, "2. the campfire has its store")
	var meat: int = items.table.number_of("raw_meat")
	var roast: int = items.table.number_of("roast_meat")

	if box != null:
		box.add(meat, 3)

		for k in 20:
			items._tend_fire(fire, items._items[fire], items._items[fire]["fire"], 2.0)

		check(box.count_of(roast) >= 3 and box.count_of(meat) == 0, "2. raw meat in the fire's store roasts there (%d roasts)" % box.count_of(roast))

	# 3. Sickness: raw animal food and rotten food make you sick, cooked food never does.
	var eater: int = new_player()
	items._characters[items.key_of(eater)]["grace_s"] = 0.0   # past the first hour's grace (Dave's open question: raw meat in the grace hour)
	items._sick_cfg["infection"]["odds"]["raw_meat"] = 1.0   # the 1 in 5 made certain for the test
	items.inventory_of(eater).add(meat, 1)
	var ate_raw: Array = eat_one(eater, meat)
	var due: Variant = items.vitals_of(eater).get("sick_due", [])
	check(int(ate_raw[0]) > 0 and typeof(due) == TYPE_ARRAY and not (due as Array).is_empty() and float(items.vitals_of(eater).get("sick", 0.0)) <= 0.0, "3. raw meat eaten makes you sick later, after its onset hours, not at once", eater)
	var cooked_eater: int = new_player()
	items._characters[items.key_of(cooked_eater)]["grace_s"] = 0.0
	items.inventory_of(cooked_eater).add(roast, 1)
	var ate_roast: Array = eat_one(cooked_eater, roast)
	check(int(ate_roast[0]) > 0 and have(cooked_eater, roast) == 0, "3. roast meat is eaten", cooked_eater)
	var due2: Variant = items.vitals_of(cooked_eater).get("sick_due", [])
	check((typeof(due2) != TYPE_ARRAY or (due2 as Array).is_empty()) and float(items.vitals_of(cooked_eater).get("sick", 0.0)) <= 0.0, "3. roast meat does not")
	var rot_eater: int = new_player()
	items._characters[items.key_of(rot_eater)]["grace_s"] = 0.0
	var rotten: int = items.table.number_of(str(items.table.spoilage().get("rotten_item", "")))
	check(rotten != 0, "3. food that rots turns into %s" % str(items.table.spoilage().get("rotten_item", "")))
	items.inventory_of(rot_eater).add(rotten, 1)
	eat_one(rot_eater, rotten)
	check(have(rot_eater, rotten) == 0 and float(items.vitals_of(rot_eater).get("sick", 0.0)) > 0.0, "3. eating it makes you sick at once", rot_eater)

	# 4. Raw meat ages slower in a chest than in the pack, slower still in a root cellar (place_mult, the cellar's cold; a year is test_winter_stores').
	var keeper: int = new_player()
	items.year_mean_at = func(_p): return 8.0   # the cellar's ground temperature
	var stores: Dictionary = {}

	for kind in ["chest", "root_cellar"]:
		var at: Vector3 = yard(keeper) + Vector3(1.5 if kind == "chest" else -2.5, 0.0, 0.0)
		var kit: String = str(items._structures[kind]["kit"])

		if items._blueprint_of_kit.has(kit):
			items.place_piece(keeper, kit, at)
		else:
			items.give(keeper, items.table.number_of(kit), 1)
			items.place_item(keeper, items.table.number_of(kit), at)

		stores[kind] = newest_struct(kind)

	check(int(stores["chest"]) >= 0 and int(stores["root_cellar"]) >= 0, "4. a chest and a root cellar stand in the yard", keeper)
	var ages: Dictionary = {}

	if int(stores["chest"]) >= 0 and int(stores["root_cellar"]) >= 0:
		for kind in stores:
			items.inventory_of(keeper).add(meat, 1)
			items.report_position(keeper, items._items[int(stores[kind])]["pos"] + Vector3(1.0, 0.0, 0.0))
			put_in(keeper, int(stores[kind]), meat, 1)

		items.inventory_of(keeper).add(meat, 1)

		for k in 40:
			items._spoil_tick(60.0)

		var pack_slot: int = slot_of(keeper, meat)
		ages["pack"] = int(items.inventory_of(keeper).wear[pack_slot]) if pack_slot >= 0 else -1

		for kind in stores:
			var store = items._chests[int(items._items[int(stores[kind])]["struct"]["uid"])]
			var at_slot: int = store.numbers.find(meat)
			ages[kind] = int(store.wear[at_slot]) if at_slot >= 0 else -1

		check(int(ages["pack"]) > int(ages["chest"]) and int(ages["chest"]) > int(ages["root_cellar"]) and int(ages["root_cellar"]) >= 0, "4. the same meat ages most in the pack, less in a chest, least in a root cellar (%s)" % str(ages))

	# 5. Over a restart: a craft half done at a station, raw food in the fire's store, food ages.
	var baker: int = new_player()
	var slow_n: int = -1
	var slow_r: Dictionary = {}

	for n in items.recipes.numbers():
		var r: Dictionary = items.recipes.recipe(int(n))

		if str(r.get("station", "")) == "clay_hearth" and not bool(r.get("locked", false)) and not bool(r.get("retired", false)) and float(r.get("craft_s", 0.0)) >= 8.0 and float(r.get("ready_age", 0.0)) <= 0.0:
			var plain: bool = true

			for row in r.get("needs", []):
				for maker in items.recipes.makers_of(int(row[0])):
					plain = plain and float(items.recipes.recipe(int(maker)).get("ready_age", 0.0)) <= 0.0

			if plain:
				slow_n = int(n)
				slow_r = r
				break

	check(slow_n > 0, "5. a hearth recipe to leave half done (%s)" % str(slow_r.get("id", "")))

	if slow_n <= 0:
		print("Test done: %d pass, %d fail" % [passes, failures])
		quit(1)
		return

	var baker_key: String = items.key_of(baker)
	var baker_at: Vector3 = yard(baker)
	set_station(baker, "clay_hearth", 1)

	for row in slow_r.get("keeps", []):
		give_any(baker, int(row[0]), int(row[1]))

	for row in slow_r.get("needs", []):
		give_any(baker, int(row[0]), int(row[1]))

	items._last_queue_act.clear()
	items.action(baker, Net.ACT_CRAFT_QUEUE, slow_n, 0, 1, CraftHand.at(items, baker, slow_n))
	run(int(float(slow_r["craft_s"]) / 2.0))
	check(not items.craft_queue_of(baker).is_empty(), "5. the hearth craft is half done when the server stops")
	var aged: int = new_player()
	var aged_key: String = items.key_of(aged)
	items.inventory_of(aged).add(meat, 2, 37)
	var keep_fire_box: int = box.count_of(roast) if box != null else 0
	check(keep_fire_box >= 3, "5. the fire's store holds its roasts when the server stops (%d)" % keep_fire_box)
	save_all()

	start(false)
	items.peer_connected_hello(baker, baker_key)
	items.report_position(baker, baker_at)
	items.vitals_of(baker)["weight"] = 1.0e6
	check(not items.craft_queue_of(baker).is_empty() and float(items._craft_queues.get(baker_key, {}).get("elapsed", 0.0)) > 0.0, "5. after a restart the half-done hearth craft is still queued with its progress (%s, %.1f s done)" % [str(items.craft_queue_of(baker)), float(items._craft_queues.get(baker_key, {}).get("elapsed", 0.0))])
	var out_n2: int = int(slow_r["gives"][0])
	var before2: int = have(baker, out_n2)

	for s in range(900):
		if items.craft_queue_of(baker).is_empty():
			break

		items.tick(1.0)

	items.tick(1.0)
	collect(baker)
	pick_up_near(baker, out_n2)
	check(have(baker, out_n2) - before2 >= int(slow_r["gives"][1]), "5. and it finishes and gives its %s" % items.table.id_of(out_n2), baker)
	items.peer_connected_hello(aged, aged_key)
	var inv_aged = items.inventory_of(aged)
	var meat_slot: int = inv_aged.numbers.find(meat)
	check(meat_slot >= 0 and inv_aged.counts[meat_slot] == 2 and inv_aged.wear[meat_slot] == 37, "5. food in the pack keeps its count and age over a restart")
	var fire_after: Dictionary = items._items.get(fire_near(fire_at), {})
	check(not fire_after.is_empty() and fire_after.has("fire"), "5. the campfire is still there after a restart")

	var box2 = items._chests.get(int(fire_after["fire"]["uid"])) if not fire_after.is_empty() and fire_after.has("fire") and fire_after["fire"].has("uid") else null
	check(box2 != null and box2.count_of(roast) == keep_fire_box, "5. with the roasts in its store (%d, was %d)" % [box2.count_of(roast) if box2 != null else -1, keep_fire_box])

	# 6. Two players at one station: both crafts finish, each from their own pack.
	var a: int = new_player()
	var b: int = new_player()
	var hearth_at: Vector3 = yard(a)
	items.report_position(b, hearth_at + Vector3(0.5, 0.0, 0.5))
	set_station(a, "clay_hearth", 1)
	var given: Array = []   # [peer, number] of every input handed out

	for p in [a, b]:
		for row in slow_r.get("keeps", []):
			give_any(p, int(row[0]), int(row[1]))

		for row in slow_r.get("needs", []):
			given.append([p, give_any(p, int(row[0]), int(row[1]))])

	var out3: int = int(slow_r["gives"][0])
	var held0: int = have(a, out3) + have(b, out3)
	items._last_queue_act.clear()
	items.action(a, Net.ACT_CRAFT_QUEUE, slow_n, 0, 1, CraftHand.at(items, a, slow_n))
	items._last_queue_act.clear()
	items.action(b, Net.ACT_CRAFT_QUEUE, slow_n, 0, 1, CraftHand.at(items, b, slow_n))
	check(not items.craft_queue_of(a).is_empty() and not items.craft_queue_of(b).is_empty(), "6. two players queue at one hearth", b)

	for s in range(900):
		if items.craft_queue_of(a).is_empty() and items.craft_queue_of(b).is_empty():
			break

		items.tick(1.0)

	items.tick(1.0)
	var spent: Array = []

	for row in given:
		if have(int(row[0]), int(row[1])) != 0:
			spent.append("%d still has %s" % [int(row[0]), items.table.id_of(int(row[1]))])

	check(spent.is_empty() and items.craft_queue_of(a).is_empty() and items.craft_queue_of(b).is_empty(), "6. both crafts finish, each taking its inputs from its own player's pack (%s)" % str(spent), b)
	var made3: int = have(a, out3) + have(b, out3) - held0

	for id in items._items.keys():
		var it: Dictionary = items._items.get(id, {})

		if (it["pos"] as Vector3).distance_to(hearth_at) <= 6.0:
			if it.has("struct") and items._is_station_store(it) and it["struct"].has("uid") and items._chests.has(int(it["struct"]["uid"])):
				made3 += items._chests[int(it["struct"]["uid"])].count_of(out3)
			elif int(it.get("number", 0)) == out3 and not it.has("struct"):
				made3 += int(it["count"])

	check(made3 >= 2 * int(slow_r["gives"][1]), "6. and the hearth gave both batches (%d %s)" % [made3, items.table.id_of(out3)], b)

	# 7. A herbal tea is a cup of water too (coordinator ruling for Dave, 23 Nov 2026): it gives the water it is brewed from, with its energy or cure.
	var unit_ml: int = items.table.liquid_unit_ml(items.table.number_of("water"))
	var teas: Array = []

	for n in items.recipes.numbers():
		var r: Dictionary = items.recipes.recipe(int(n))
		var tea_id: String = items.table.id_of(int(r["gives"][0]))

		if bool(r.get("retired", false)) or not tea_id.ends_with("_tea") or not (items._vitals_cfg.get("medicines", {}).has(tea_id) or items._vitals_cfg.get("energy_aids", {}).has(tea_id)):
			continue

		var water_n: int = 0

		for row in r.get("needs", []):
			water_n += int(row[1]) if items.table.id_of(int(row[0])) == "water" else 0

		if water_n == 0:
			continue

		teas.append(tea_id)
		var tea_n: int = int(r["gives"][0])
		var ml: int = VitalsRules.drink_value(tea_id, items._vitals_cfg)
		check(ml == water_n * unit_ml, "7. %s gives the %d mL of water it is brewed from (%d)" % [tea_id, water_n * unit_ml, ml])
		var drinker: int = new_player()
		var v: Dictionary = items.vitals_of(drinker)
		v["wet"] = 200.0
		v["energy"] = 40.0
		var sick_before: float = 0.0

		if items._vitals_cfg.get("medicines", {}).has(tea_id):
			items.make_sick(drinker, 24.0, false)
			sick_before = float(v.get("sick", 0.0))

		items.inventory_of(drinker).add(tea_n, 1)
		items._last_eat.clear()
		items._last_dose.clear()
		items.action(drinker, Net.ACT_EAT, slot_of(drinker, tea_n), 0, 0, Vector3.ZERO)
		var effect: bool = float(v.get("sick", 0.0)) < sick_before if sick_before > 0.0 else float(v.get("energy", 0.0)) > 40.0
		check(have(drinker, tea_n) == 0 and absf(float(v["wet"]) - 200.0 - float(ml)) < 1.0 and effect, "7. drinking %s quenches thirst by %d mL (%.0f) and still does its work" % [tea_id, ml, float(v["wet"]) - 200.0], drinker)
		var well: int = new_player()
		items.vitals_of(well)["wet"] = 200.0
		items.inventory_of(well).add(tea_n, 1)
		items._last_eat.clear()
		items.action(well, Net.ACT_EAT, slot_of(well, tea_n), 0, 0, Vector3.ZERO)
		check(have(well, tea_n) == 0 and float(items.vitals_of(well)["wet"]) > 200.0, "7. a thirsty player who is well drinks %s too" % tea_id, well)

	check(teas.size() >= 5, "7. the herbal teas found (%s)" % str(teas))

	items._finish_writer()
	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)
