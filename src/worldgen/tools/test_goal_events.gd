extends SceneTree

# The goal events the 26 approved goals need (GOALS-REPAIR, PLAYER_GOALS_CATALOG_CORRECTED.md "Approved new goals", ADD-03 to ADD-26; Dave 14 Nov 2026: "gathering counts
# when you pick it or cut it down or harvest something by your own hand"), played on the server logic. Each event is fired by the act itself, once, for the character whose
# hand did it; a refused act fires nothing, and nothing counts in Admin mode (GA-54; _goal_event pauses). The goals themselves are not in the live goal files: only the
# counter "event:<name>" is read here.
# Commit 1: cooked_on_fire, bed_tilled, seed_sown, crop_harvested, bush_replanted, snare_set, tool_sharpened, tool_repaired, building_repaired, slept_night, stored_item.
#   godot --headless --path . --script res://src/worldgen/tools/test_goal_events.gd

const BuildingWear := preload("res://src/shared/building_wear.gd")
const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const SmithingRules := preload("res://src/shared/smithing_rules.gd")

const HERE := Vector3(0.0, 10.0, 0.0)

var failures: int = 0
var items
var said: Array = []
var admin_on: Array = [false]
var season: Array = ["spring"]
var fire: int = 0
var chest: int = 0
var bench: String = ""


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
	it.admin_mode_on = func(_p): return admin_on[0]
	it.setup(ItemTableScript.load_default(), dir)
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
	items.action(1, Net.ACT_PLANT_BUSH, slot_of("hazel_bush"), 0, 0, Vector3(40.0, 10.0, 40.0))
	check(ev("bush_replanted") == 1 and items._saplings.size() == 2, "a bush too far away is not planted: still 1 (%d planted)" % items._saplings.size())


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
	print("goal events: %d failures" % failures)
	quit(1 if failures > 0 else 0)
