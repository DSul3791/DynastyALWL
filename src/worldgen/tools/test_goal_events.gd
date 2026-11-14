extends SceneTree

# The goal events the 26 approved goals need (GOALS-REPAIR, PLAYER_GOALS_CATALOG_CORRECTED.md "Approved new goals", ADD-03 to ADD-26; Dave 14 Nov 2026: "gathering counts
# when you pick it or cut it down or harvest something by your own hand"), played on the server logic. Each event is fired by the act itself, once, for the character whose
# hand did it; a refused act fires nothing, and nothing counts in Admin mode (GA-54; _goal_event pauses). The goals themselves are not in the live goal files: only the
# counter "event:<name>" is read here.
# Part 1: cooked_on_fire, bed_tilled, seed_sown, crop_harvested, bush_replanted, snare_set, tool_sharpened, tool_repaired, building_repaired, slept_night, stored_item.
# Part 2 (a fresh world): container_locked, handcart_hauled, tempered, masterwork_made, station_repaired, kiln_charcoal, bought, jar_matured, platter_served,
#   meal_effect, torch_placed, foraged_new, fish_kind_caught, ore_mined.
#   godot --headless --path . --script res://src/worldgen/tools/test_goal_events.gd

const BuildingWear := preload("res://src/shared/building_wear.gd")
const Carts := preload("res://src/stream/server_carts.gd")
const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const SmithingRules := preload("res://src/shared/smithing_rules.gd")
const TradeScript := preload("res://src/stream/server_trade.gd")

const HERE := Vector3(0.0, 10.0, 0.0)

var failures: int = 0
var items
var said: Array = []
var admin_on: Array = [false]
var season: Array = ["spring"]
var fire: int = 0
var chest: int = 0
var bench: String = ""
var clock: Array = [1.0e6]
var cart: int = 0
var target: int = 0   # the world id of the thing the current check works on
var trade
var ore_id: int = 900001


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1
		print("     the server said: ", str(said.slice(maxi(said.size() - 3, 0))) if not said.is_empty() else "nothing")


func make(dir: String):
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var it = ItemsScript.new()
	it.send_full = func(_p, _b): pass
	it.send_slots = func(_p, _b): pass
	it.send_world_items = func(_p, _a, _r): pass
	it.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	it.send_notice = func(_p, t): said.append(str(t))
	it.send_purse = func(_p, _c): pass
	it.send_reject = func(_p, _r): pass
	it.send_carry = func(_p, _id): pass
	it.send_chest = func(_p, _id, _b): pass
	it.send_chest_info = func(_p, _id, _k, _m): pass
	it.send_chest_lock = func(_p, _id, _l, _m, _o, _w, _a): pass
	it.send_craft_stock = func(_p, _n, _c): pass
	it.send_bulk_done = func(_p, _k, _s, _c, _i): pass
	it.ground_height = func(_x, _z): return 10.0
	it.game_seconds = func(): return 1000.0 * 86400.0
	it.season_now = func(): return season[0]
	it.cover_at = func(_p): return 1.0
	it.admin_ok = func(_p): return true
	it.setup(ItemTableScript.load_default(), dir)
	it.admin_mode_on = func(_p): return admin_on[0]   # after setup(), which sets its own (per-peer _admin_mode_on)
	it.skill_level = func(_p, _s): return 1.0
	it.peer_connected_hello(1, "goalevents001")
	it.report_position(1, HERE)
	it.vitals_of(1)["weight"] = 5000.0   # carrying is not under test
	return it


func n(id: String) -> int:
	return items.table.number_of(id)


func inv():
	return items.inventory_of(1)


func slot_of(id: String) -> int:
	return inv().numbers.find(n(id))


# How many times the goal counter heard the event.
func ev(name: String) -> int:
	return int(items._goal_state_of(1)["goal_counts"].get("event:" + name, 0))


# The act is done twice: first in Admin mode, where it counts nothing, then for real, where it counts once. `act` takes 0 then 1 (a place to put each try).
func admin_then_real(name: String, act: Callable, what: String) -> void:
	admin_on[0] = true
	act.call(0)
	check(ev(name) == 0, "%s in Admin mode fires nothing (%s)" % [what, name])
	admin_on[0] = false
	act.call(1)
	check(ev(name) == 1, "%s fires %s once (%d)" % [what, name, ev(name)])


func run(seconds: float) -> void:
	for k in range(int(ceil(seconds))):
		items.vitals_of(1)["energy"] = 100.0   # long waits would tire the character into a collapse; neither is under test
		items._strain.erase(1)
		items.tick(1.0)


func blueprint_of(kind: String) -> Dictionary:
	for number in items._blueprints:
		if str(items._blueprints[number].get("structure", "")) == kind:
			return items._blueprints[number]

	return {}


# A placed structure straight into the world (the way test_tool_care places a station), standing at `at`.
func place(kind: String, at: Vector3) -> int:
	var id: int = items._next_id
	items._items[id] = {"number": n(str(items._structures[kind].get("item", kind))), "count": 1, "pos": at, "left": 1.0e9, "struct": {"kind": kind, "yaw": 0.0, "uid": id, "lit": true, "fuel_left": 1.0e7}}
	items._next_id += 1
	return id


func beds() -> Array:
	return items._items.keys().filter(func(k): return items._items[k].has("struct") and str(items._items[k]["struct"]["kind"]) == "tilled_bed")


# --- ADD-03 cooked_on_fire: the campfire roasts meat and fish (cooking.json cooks_into), one press, one roast ---
func do_cook(_i: int) -> void:
	items.give(1, n("raw_meat"), 1)
	items._last_cook.clear()
	items.action(1, Net.ACT_COOK, fire, 0, 0, Vector3.ZERO)


func cook_checks() -> void:
	fire = items.dev_place("campfire@1.5,0.0,0,lit")
	items.give(1, n("blueberries"), 2)
	items._last_cook.clear()
	items.action(1, Net.ACT_COOK, fire, 0, 0, Vector3.ZERO)
	check(ev("cooked_on_fire") == 0 and inv().count_of(n("blueberries")) == 2, "a plant on the campfire is not cooked (it goes in a pot): cooked_on_fire stays 0")
	admin_then_real("cooked_on_fire", do_cook, "a roast on the campfire")
	check(inv().count_of(n("roast_meat")) == 2, "both roasts were made (%d)" % inv().count_of(n("roast_meat")))


# --- ADD-04 bed_tilled, ADD-05 seed_sown, ADD-06 crop_harvested ---
func do_till(i: int) -> void:
	items._last_dig.clear()
	items.till(1, inv(), Vector3(1.2 - 2.4 * float(i), 10.0, 1.2), HeldTool.slot_of(items, "hoe"))


func do_sow(i: int) -> void:
	items.give(1, n("wheat_seeds"), 1)
	items.sow(1, inv(), beds()[i], slot_of("wheat_seeds"))


func do_harvest(i: int) -> void:
	var bed: int = beds()[i]
	var key: String = items._bed_key(items._items[bed]["pos"])
	items._crops[key]["age"] = 1000.0   # ripe: old enough and wet enough
	items._crops[key]["wet"] = 1000
	items.harvest(1, inv(), bed)


func farm_checks() -> void:
	items.give(1, n("wooden_hoe") if items.table.has_id("wooden_hoe") else n("stone_hoe"), 1)
	check(items.till(1, inv(), Vector3(40.0, 10.0, 40.0), HeldTool.slot_of(items, "hoe")) == 0 and ev("bed_tilled") == 0, "a stroke out of reach tills nothing: bed_tilled stays 0")
	admin_then_real("bed_tilled", do_till, "a hoe stroke")
	items._last_dig.clear()
	items.till(1, inv(), Vector3(1.3, 10.0, 1.3), HeldTool.slot_of(items, "hoe"))
	check(ev("bed_tilled") == 1 and beds().size() == 2, "the same metre is not tilled twice: still 1 (%d beds)" % beds().size())

	admin_then_real("seed_sown", do_sow, "a seed sown in a bed")
	do_sow(1)
	check(ev("seed_sown") == 1, "a bed that already has a crop takes no second seed: still 1")

	admin_then_real("crop_harvested", do_harvest, "a ripe crop harvested")
	items.harvest(1, inv(), beds()[0])
	check(ev("crop_harvested") == 1, "harvesting the empty bed again counts nothing: still 1")


# --- ADD-07 bush_replanted ---
func do_bush(i: int) -> void:
	items.give(1, n("hazel_bush"), 1)
	items.action(1, Net.ACT_PLANT_BUSH, slot_of("hazel_bush"), 0, 0, Vector3(2.0 - 4.0 * float(i), 10.0, 0.0))


func bush_checks() -> void:
	admin_then_real("bush_replanted", do_bush, "a dug bush replanted")
	items.give(1, n("hazel_bush"), 1)   # a bush in the pack, so the refusal below is the reach check and not an empty slot
	check(slot_of("hazel_bush") >= 0, "a hazel bush is in the pack for the reach check")
	items.action(1, Net.ACT_PLANT_BUSH, slot_of("hazel_bush"), 0, 0, Vector3(40.0, 10.0, 40.0))
	check(ev("bush_replanted") == 1 and items._saplings.size() == 2 and slot_of("hazel_bush") >= 0, "a bush too far away is not planted and stays in the pack: still 1 (%d planted)" % items._saplings.size())
	items.give(1, n("acorns"), 1)
	items.action(1, Net.ACT_PLANT_BUSH, slot_of("acorns"), 0, 0, Vector3(0.0, 10.0, 3.0))
	check(items._saplings.size() == 3 and ev("bush_replanted") == 1, "an acorn planted as a sapling is not a replanted bush: still 1 (%d planted)" % items._saplings.size())


# --- ADD-08 snare_set: server_traps.on_placed (the Bird trap is another kind) ---
func do_snare(i: int) -> void:
	var id: int = items._next_id
	items._next_id += 1
	items._items[id] = {"number": 1, "count": 1, "pos": Vector3(200.0 + 20.0 * float(i), 10.0, 0.0), "left": 1.0e9, "wear": 0, "struct": {"kind": "snare_trap", "yaw": 0.0}}
	items._traps.on_placed(1, id)


func snare_checks() -> void:
	var bird: int = items._next_id
	items._next_id += 1
	items._items[bird] = {"number": 1, "count": 1, "pos": Vector3(300.0, 10.0, 0.0), "left": 1.0e9, "wear": 0, "struct": {"kind": "bird_trap_set", "yaw": 0.0}}
	items._traps.on_placed(1, bird)
	check(ev("snare_set") == 0, "a Bird trap is not a snare: snare_set stays 0")
	admin_then_real("snare_set", do_snare, "a snare set")


# --- ADD-09 tool_sharpened, ADD-10 tool_repaired ---
func dull(slot: int) -> void:
	var entry: Dictionary = items.table.entry(items.table.id_of(inv().numbers[slot]))
	inv().inst[slot] = {"sharp": SmithingRules.dull_at(entry, {})}


func do_sharpen(_i: int) -> void:
	var slot: int = slot_of("bronze_axe")
	dull(slot)
	items.action(1, Net.ACT_REPAIR, slot, 0, 0, Vector3.ZERO)
	run(float(SmithingRules.cfg()["whetstone"]["full_s"]) + 2.0)


func sharpen_checks() -> void:
	inv().add(n("bronze_axe"), 1)
	dull(slot_of("bronze_axe"))
	items.action(1, Net.ACT_REPAIR, slot_of("bronze_axe"), 0, 0, Vector3.ZERO)
	run(5.0)
	check(not items._sharpening.has(1) and ev("tool_sharpened") == 0, "with no whetstone or grindstone nothing is sharpened: tool_sharpened stays 0")
	inv().add(n("whetstone"), 1)
	inv().add(n("waterskin"), 1, 500)   # a waterskin holding 500 ml, the whetstone's water
	admin_then_real("tool_sharpened", do_sharpen, "a tool sharpened on a whetstone")


func do_repair_tool(_i: int) -> void:
	var row: Dictionary = items.table.entry("iron_pickaxe")

	if slot_of("iron_pickaxe") < 0:
		inv().add(n("iron_pickaxe"), 1)

	inv().wear[slot_of("iron_pickaxe")] = 100
	inv().inst[slot_of("iron_pickaxe")] = {}

	for cost in row.get("repair", []):
		inv().add(n(str(cost[0])), int(cost[1]))

	items.action(1, Net.ACT_REPAIR, slot_of("iron_pickaxe"), 0, 0, Vector3.ZERO)


func repair_tool_checks() -> void:
	bench = str(items.table.entry("iron_pickaxe").get("repair_station", ""))
	do_repair_tool(0)
	check(inv().wear[slot_of("iron_pickaxe")] == 100 and ev("tool_repaired") == 0, "away from its %s a worn tool is not repaired: tool_repaired stays 0" % bench)
	var kind: String = ""

	for k in items._structures:
		var def: Dictionary = items._structures[k]

		if kind == "" and not bool(def.get("retired", false)) and (str(def.get("station", "")) == bench or int(def.get("also", {}).get(bench, 0)) > 0):
			kind = str(k)

	place(kind, HERE + Vector3(0.0, 0.0, 2.0))
	admin_then_real("tool_repaired", do_repair_tool, "a worn tool repaired at its %s" % bench)


# --- ADD-11 building_repaired: a hammer on a worn building piece ---
func do_repair_building(_i: int) -> void:
	var wall: int = items._items.keys().filter(func(k): return items._items[k].has("struct") and str(items._items[k]["struct"]["kind"]) == "log_wall")[0]
	items._items[wall]["struct"]["born"] = 0.0   # last cared for a thousand game days ago: worn to the log floor
	var needs: Array = BuildingWear.repair_needs(blueprint_of("log_wall")["cost"], items.piece_condition(wall), float(items._wear_cfg.get("repair_share", 0.5)))

	for need in needs:
		items.give(1, n(str(need[0])), int(need[1]))

	items.action(1, Net.ACT_REPAIR_STRUCT, wall, HeldTool.slot_of(items, "hammer") + 1, 0, Vector3.ZERO)


func building_checks() -> void:
	items.give(1, n("wooden_hammer"), 1)
	var wall: int = items.dev_place("log_wall@0.0,2.0,0")
	items.action(1, Net.ACT_REPAIR_STRUCT, wall, HeldTool.slot_of(items, "hammer") + 1, 0, Vector3.ZERO)
	check(ev("building_repaired") == 0, "a new wall is in good repair and needs none: building_repaired stays 0")
	admin_then_real("building_repaired", do_repair_building, "a worn wall repaired with a hammer")


# --- ADD-12 slept_night: a sleep that filled the energy on a bed or beside a lean-to; not a nap, not a collapse ---
func do_sleep(_i: int) -> void:
	items._motion.erase(1)
	items._stance[1] = 3
	items._bed_cache.clear()
	items._asleep[1] = {"rested": 0.0, "t": 0.0}
	run(10.0)
	items._asleep.erase(1)


func sleep_checks() -> void:
	var bed: int = items.dev_place("rough_bed@0.0,0.5,0")
	admin_then_real("slept_night", do_sleep, "a night slept on a bed")
	items._items.erase(bed)
	do_sleep(2)
	check(ev("slept_night") == 1, "a sleep on bare ground, no bed and no lean-to, counts nothing: still 1")
	items._stance[1] = 0


# --- ADD-13 stored_item: a put into a chest or crate (structures.json lockable), not into a fire ---
func do_store(_i: int) -> void:
	items.give(1, n("stick"), 1)
	items.action(1, Net.ACT_CHEST_PUT, slot_of("stick"), chest, 1, Vector3.ZERO)


func store_checks() -> void:
	var far: int = items.dev_place("chest@40.0,40.0,0")
	items.give(1, n("stick"), 1)
	items.action(1, Net.ACT_CHEST_PUT, slot_of("stick"), far, 1, Vector3.ZERO)
	check(ev("stored_item") == 0 and inv().count_of(n("stick")) >= 1, "a chest out of reach takes nothing: stored_item stays 0")
	items.action(1, Net.ACT_CHEST_PUT, slot_of("stick"), fire, 1, Vector3.ZERO)
	check(ev("stored_item") == 0, "wood put on a fire is fuel, not storage: stored_item stays 0")
	chest = items.dev_place("chest@-1.5,0.0,0")
	admin_then_real("stored_item", do_store, "a stick put into a chest")
	var bag: int = inv().hotbar_slots   # Store all moves the bag slots: three stacks go in at once, one act
	inv().numbers[bag] = n("stick")
	inv().counts[bag] = 2
	inv().numbers[bag + 1] = n("stone")
	inv().counts[bag + 1] = 2
	inv().numbers[bag + 2] = n("flint")
	inv().counts[bag + 2] = 2
	items._chest_viewer[1] = chest
	items.action(1, Net.ACT_BULK, 1, 0, 0, Vector3.ZERO)
	check(items._chests[int(items._items[chest]["struct"]["uid"])].count_of(n("flint")) == 2 and ev("stored_item") == 2, "Store all of three stacks is one act: stored_item rose by 1, not 3 (%d)" % ev("stored_item"))


# ---------------- Part 2: a fresh world (no stations or fires left over from part 1) ----------------

func recipe_of(item_id: String) -> int:
	for number in items.recipes.numbers():
		var r: Dictionary = items.recipes.recipe(int(number))

		if not r.get("gives", []).is_empty() and int(r["gives"][0]) == n(item_id) and not bool(r.get("retired", false)):
			return int(number)

	return 0


# --- ADD-14 container_locked: the owner sets a valid four-digit code ---
func do_lock(i: int) -> void:
	items.action(1, Net.ACT_CHEST_LOCK, target, ItemsScript.LOCK_SET, 42 + i, Vector3.ZERO)


func lock_checks() -> void:
	target = items.dev_place("wooden_crate@0.0,-1.5,0")
	items._items[target]["struct"]["owner"] = "goalevents001"
	items.action(1, Net.ACT_CHEST_LOCK, target, ItemsScript.LOCK_SET, 10000, Vector3.ZERO)
	check(ev("container_locked") == 0 and not items._items[target]["struct"].has("lock"), "a code that is not four digits locks nothing: container_locked stays 0")
	admin_then_real("container_locked", do_lock, "a crate locked with a code")


# --- ADD-15 handcart_hauled: a crate rides the cart the puller moves; an empty cart is not a haul ---
func do_haul(_i: int) -> void:
	items.report_position(1, items._items[cart]["pos"] + Vector3(1.5, 0.0, 0.0))
	items.action(1, Net.ACT_CART, cart, Carts.OP_GRAB, 0, Vector3.ZERO)
	var here: Vector3 = items._peer_pos[1]

	for step in 10:
		here += Vector3(0.3, 0.0, 0.0)
		clock[0] += 0.2
		items.report_position(1, here)

	items.action(1, Net.ACT_CART, cart, Carts.OP_RELEASE, 0, Vector3.ZERO)


func haul_checks() -> void:
	items.unix_now = func(): return clock[0]
	cart = items.dev_place("handcart@2.0,0.0,0")
	do_haul(0)
	var at: Vector3 = items._items[cart]["pos"]
	check(ev("handcart_hauled") == 0 and at.x > 2.5, "an empty handcart pulled along fires nothing (it moved to x %.1f)" % at.x)
	target = items.dev_place("warehouse_crate@%f,%f,0" % [at.x, at.z + 2.0])
	items.report_position(1, at + Vector3(0.0, 0.0, 1.0))
	items.action(1, Net.ACT_CART, target, Carts.OP_LOAD, 0, Vector3.ZERO)
	check(items._carts.riders_of(cart).size() == 1, "the crate is on the cart")
	admin_then_real("handcart_hauled", do_haul, "a loaded handcart pulled (ten steps, one grab)")
	items.report_position(1, HERE)


# --- ADD-17 masterwork_made and tempered (ADD-16 and activity:temper_steel share it): a variant craft at the Master smithy ---
func variant_craft(item_id: String, variant: int) -> void:
	var number: int = recipe_of(item_id)
	var r: Dictionary = items.recipes.recipe(number)

	for need in SmithingRules.scaled_needs(r["needs"], variant):
		inv().add(int(need[0]), int(need[1]))

	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, number, variant, 1, Vector3.ZERO)
	run(float(r["craft_s"]) * SmithingRules.time_mult(variant) + 3.0)


func empty_pack() -> void:
	for s in inv().slot_count:
		inv().clear_slot(s)


func do_masterwork(_i: int) -> void:
	empty_pack()
	variant_craft("iron_pickaxe", SmithingRules.code(false, 1))


func do_tempered(_i: int) -> void:
	empty_pack()
	variant_craft("steel_pickaxe", SmithingRules.code(true, 0))


func smithy_checks() -> void:
	place("master_forge", HERE + Vector3(0.0, 0.0, 3.0))
	variant_craft("iron_pickaxe", 0)
	check(inv().count_of(n("iron_pickaxe")) == 1 and ev("masterwork_made") == 0 and ev("tempered") == 0, "a plain pickaxe at the Master smithy is neither masterwork nor tempered")
	admin_then_real("masterwork_made", do_masterwork, "a +1 pickaxe at the Master smithy")
	check(ev("tempered") == 0, "a +1 craft is not a tempering: tempered stays 0")
	admin_then_real("tempered", do_tempered, "a Tempered steel pickaxe at the Master smithy")
	check(ev("masterwork_made") == 1, "a Tempered craft with no +1 is not masterwork: masterwork_made stays 1")


# --- station_repaired (activity:repair_station): a hammer mends a worn smithy, not a wall ---
func smithy_needs(smithy: int) -> Array:
	var cost: Array = items._smithies.repair_cost(blueprint_of(str(items._items[smithy]["struct"]["kind"]))["cost"])
	return BuildingWear.repair_needs(cost, 0.0, float(items._wear_cfg.get("repair_share", 0.5)))


func break_smithy() -> void:
	items._items[target]["struct"]["use_wear"] = items._smithies.durability(items._structures["blacksmithy"])


func do_repair_station(_i: int) -> void:
	break_smithy()

	for need in smithy_needs(target):
		items.give(1, n(str(need[0])), int(need[1]))

	items.action(1, Net.ACT_REPAIR_STRUCT, target, HeldTool.slot_of(items, "hammer") + 1, 0, Vector3.ZERO)


func station_checks() -> void:
	empty_pack()
	items.give(1, n("wooden_hammer"), 1)
	target = items.dev_place("blacksmithy@0.0,-3.0,0,lit")
	break_smithy()
	items.action(1, Net.ACT_REPAIR_STRUCT, target, HeldTool.slot_of(items, "hammer") + 1, 0, Vector3.ZERO)
	check(ev("station_repaired") == 0 and items._smithies.broken(target), "short of materials the smithy stays broken: station_repaired stays 0")
	admin_then_real("station_repaired", do_repair_station, "a worn smithy repaired with a hammer")
	check(ev("building_repaired") == 0, "and a smithy is not a building piece: building_repaired stays 0")


# --- ADD-18 kiln_charcoal: the batch's last log is charcoal, credited to the character who lit the kiln ---
# A kiln holding one log, lit with E when `by_hand` (stamps the lighter), else placed already lit (a restart: nobody stamped).
func kiln_with_log(by_hand: bool) -> int:
	var kiln: int = items.dev_place("kiln@0.0,2.0,0" + ("" if by_hand else ",lit"))
	items._items[kiln]["struct"]["owner"] = "goalevents001"   # the owner alone earns nothing: only the one who lit it (the unlit-by-hand kiln checks that)
	items._chests[int(items._items[kiln]["struct"]["uid"])].add(n("log"), 1)

	if by_hand:
		items.action(1, Net.ACT_USE_STRUCT, kiln, 0, 0, Vector3.ZERO)

	return kiln


func burn(kiln: int, seconds: float) -> int:
	items._kiln_burn(kiln, items._items[kiln], items._structures["kiln"], seconds)
	return items._chests[int(items._items[kiln]["struct"]["uid"])].count_of(n("charcoal"))


func do_kiln(_i: int) -> void:
	check(burn(kiln_with_log(true), 400.0) > 0, "the batch burned")


func kiln_checks() -> void:
	check(burn(kiln_with_log(true), 60.0) > 0 and ev("kiln_charcoal") == 0, "a log burnt part way is not a finished batch: kiln_charcoal stays 0")
	check(burn(kiln_with_log(false), 400.0) > 0 and ev("kiln_charcoal") == 0, "a batch from a kiln nobody lit this session (its owner placed it) credits no one: stays 0")
	admin_then_real("kiln_charcoal", do_kiln, "a kiln batch burnt out that this character lit")


# --- ADD-19 bought: a purchase from a trader's shelf (a refused one fires nothing) ---
func do_buy(_i: int) -> void:
	items.add_coins(1, 5000)
	trade.deal(1, "hob", 0, 0, 1)


func buy_checks() -> void:
	trade = TradeScript.new()
	trade.items = items
	trade.npcs = {"npcs": {"hob": {"dormant": false, "placed": true, "pos": Vector3(1.0, 10.0, 0.0)}}}
	trade.setup("user://test_goal_events_2")
	items.take_coins(1, items.coins_of(1))
	check(trade.deal(1, "hob", 0, 0, 1) == "You cannot afford that." and ev("bought") == 0, "a purchase with no coins is refused: bought stays 0")
	admin_then_real("bought", do_buy, "a purchase from Hob")


# --- ADD-20 jar_matured (a Ready sealed batch eaten), ADD-22 meal_effect (a food that gave an effect) ---
func eat(id: String, wear: int = 0) -> void:
	inv().add(n(id), 1, wear)
	items._last_eat.clear()
	items.vitals_of(1)["fed"] = 0.0
	items.action(1, Net.ACT_EAT, slot_of(id), 0, 0, Vector3.ZERO)


func do_jar(_i: int) -> void:
	eat("sauerkraut", items.table.ready_units(n("sauerkraut")))


func do_meal(_i: int) -> void:
	eat("hunters_stew")


func eat_checks() -> void:
	items._vitals_cfg["eat_pace_ms"] = 0
	eat("blueberries")
	check(ev("meal_effect") == 0, "a handful of raw berries has no food effect: meal_effect stays 0")
	admin_then_real("meal_effect", do_meal, "a Hunter's stew eaten")
	eat("sauerkraut")
	check(ev("jar_matured") == 0 and inv().count_of(n("sauerkraut")) == 1, "a Maturing jar is refused and not eaten: jar_matured stays 0")
	inv().clear_slot(slot_of("sauerkraut"))
	do_jar(0)
	check(ev("jar_matured") == 0 and inv().count_of(n("sauerkraut")) == 0, "a Ready jar this character never sealed (found, not made) is eaten but fires nothing")
	items._goal_state_of(1)["goal_counts"]["made:sauerkraut"] = 1   # what _goal_made counts when the batch is sealed here
	admin_then_real("jar_matured", do_jar, "a Ready jar of sauerkraut eaten")


# --- ADD-21 platter_served: the owner sets a food board out on a Serving platter ---
func do_serve(_i: int) -> void:
	inv().add(n("roast_platter"), 1)
	items.action(1, Net.ACT_CHEST_PUT, slot_of("roast_platter"), target, 1, Vector3.ZERO)


func serve_checks() -> void:
	target = items.dev_place("serving_platter@0.5,2.0,0")
	items.give(1, n("stone"), 1)
	items.action(1, Net.ACT_CHEST_PUT, slot_of("stone"), target, 1, Vector3.ZERO)
	check(ev("platter_served") == 0 and inv().count_of(n("stone")) >= 1, "a platter takes food boards only: a stone fires nothing")
	admin_then_real("platter_served", do_serve, "a roast board set on a platter")


# --- ADD-23 torch_placed ---
func do_torch(i: int) -> void:
	inv().add(n("torch"), 1)
	items.action(1, Net.ACT_PLACE_TORCH, slot_of("torch"), 0, 0, Vector3(1.0 + float(i), 10.0, 1.0))


func torch_checks() -> void:
	inv().add(n("torch"), 1)
	items.action(1, Net.ACT_PLACE_TORCH, slot_of("torch"), 0, 0, Vector3(40.0, 10.0, 40.0))
	check(ev("torch_placed") == 0, "a torch aimed too far away is not placed: torch_placed stays 0")
	admin_then_real("torch_placed", do_torch, "a torch stuck in the ground")


# --- ADD-24 foraged_new: the first time this character picks each plant yield by hand (berries, fruit from a tree, a harvest plant) ---
func pick(species: String, flora_id: int) -> void:
	items._last_gather.clear()
	items.gather(1, species, "plant", "0,0,%d" % flora_id, flora_id, HERE + Vector3(1.0, 0.0, 0.0))


func do_forage(i: int) -> void:
	season[0] = "summer"
	pick("blueberry", 100 + i)


func forage_checks() -> void:
	season[0] = "winter"
	pick("blueberry", 99)
	check(ev("foraged_new") == 0, "a berry bush out of season gives nothing: foraged_new stays 0")
	admin_then_real("foraged_new", do_forage, "the first blueberries picked")
	pick("blueberry", 102)
	check(ev("foraged_new") == 1, "more blueberries from another bush are not a new plant: still 1")
	pick("bramble", 103)
	check(ev("foraged_new") == 2 and int(items._goal_state_of(1)["goal_counts"].get("event:foraged_new:blackberries", 0)) == 1, "blackberries are a new yield: 2")
	season[0] = "autumn"
	pick("wild_apple", 104)
	pick("hazel", 105)
	check(ev("foraged_new") == 4, "crab apples from a tree and hazelnuts from a harvest plant each count once: 4 (%d)" % ev("foraged_new"))
	season[0] = "spring"


# --- ADD-25 fish_kind_caught: the first catch of each species (the rod path; the net and spear call the same helper) ---
func land(species: String) -> void:
	items._fish_land(1, inv(), 0, {"cell": Vector2i(0, 0), "species": species})


func do_fish(_i: int) -> void:
	land("perch")


func fish_checks() -> void:
	admin_then_real("fish_kind_caught", do_fish, "the first perch landed")
	land("perch")
	check(ev("fish_kind_caught") == 1, "a second perch is not a new kind: still 1")
	land("trout")
	check(ev("fish_kind_caught") == 2, "a trout is a new kind: 2")


# --- ADD-26 ore_mined: a pick takes ore from an outcrop (one event per ore piece); a plain boulder or an axe gives none ---
func outcrop(ore: String) -> void:
	items._items[ore_id] = {"number": 0, "count": 5000, "pos": Vector3(0.0, 10.0, 1.5), "left": 1.0e9, "scatter": items.BOULDER_KEY | 7, "boulder": {"radius": 1.0, "yaw": 0.0, "total": 5000}}

	if ore != "":
		items._items[ore_id]["boulder"]["ore"] = ore


func blows(count: int) -> void:
	for k in range(count):
		items._last_hit.clear()
		items.action(1, Net.ACT_HIT, ore_id, Net.HIT_BOULDER, slot_of("stone_pickaxe") + 1, Vector3.ZERO)


func ore_checks() -> void:
	items._boulder_cfg["luck_extra"] = 0.0
	items._boulder_cfg["flint"] = {}
	items._boulder_cfg["ore"]["piece_share"] = 1.0
	inv().add(n("stone_pickaxe"), 1)
	inv().move(slot_of("stone_pickaxe"), 0)   # Inventory.add() puts a new item in the backpack (12 Nov 2026 rule); a blow needs the tool on the hotbar
	check(inv().on_hotbar(slot_of("stone_pickaxe")), "the stone pickaxe is on the hotbar for the ore blows")
	var stone_before: int = inv().count_of(n("stone"))
	outcrop("")
	blows(20)
	check(ev("ore_mined") == 0 and inv().count_of(n("stone")) > stone_before, "a pick on a plain boulder gives stone and no ore event (%d stone)" % (inv().count_of(n("stone")) - stone_before))
	outcrop("copper")
	admin_on[0] = true
	blows(20)
	var ore_admin: int = inv().count_of(n("copper_ore"))
	check(ore_admin > 0 and ev("ore_mined") == 0, "copper ore taken in Admin mode fires nothing (%d ore)" % ore_admin)
	admin_on[0] = false
	var ores: int = 0

	for k in 20:   # one event for a blow that takes ore, however many pieces it breaks off
		var before: int = inv().count_of(n("copper_ore"))
		var events: int = ev("ore_mined")
		blows(1)

		if inv().count_of(n("copper_ore")) > before:
			ores += 1
			check(ev("ore_mined") == events + 1, "a blow that took %d copper ore fires ore_mined once" % (inv().count_of(n("copper_ore")) - before))

	check(ores > 0 and ev("ore_mined") == ores, "the pick took ore on %d blows and fired %d events" % [ores, ev("ore_mined")])


func _init() -> void:
	items = make("user://test_goal_events")
	check(not items._goals_data().is_empty(), "the live goals are loaded, so the events are counted")
	cook_checks()
	farm_checks()
	bush_checks()
	snare_checks()
	sharpen_checks()
	repair_tool_checks()
	building_checks()
	sleep_checks()
	store_checks()
	items._finish_writer()   # the background save thread must finish before quit
	items = make("user://test_goal_events_2")
	lock_checks()
	haul_checks()
	smithy_checks()
	station_checks()
	kiln_checks()
	buy_checks()
	eat_checks()
	serve_checks()
	torch_checks()
	forage_checks()
	fish_checks()
	ore_checks()
	items._finish_writer()
	print("goal events: %d failures" % failures)
	quit(1 if failures > 0 else 0)
