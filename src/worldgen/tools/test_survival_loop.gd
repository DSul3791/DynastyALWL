extends SceneTree

# The survival loop as a player lives it (coordinator 23 Nov 2026: walk it end to end for bugs and dead ends), with a server restart after
# every stage: what the body carries (food, water, warmth, wet clothes, wounds, sickness, a limp) is kept exactly, nothing lost, nothing
# doubled. The core rule throughout (Dave 23 Nov 2026): "this game doesn't want you to die unless you do something really stupid"; at 1 health
# nothing takes more; cold falls to 1, then the player passes out and wakes at the nearest goblin camp, bandit camp, temple or the town with a
# "found you" message, the pack kept.
#   1. hunger: the stomach empties over a day, food fills it, an empty stomach burns body weight but never health;
#   2. thirst: a drink at the water's edge, a waterskin filled and drunk from; an empty body stops healing, never hurts;
#   3. food rot and storage: raw meat keeps longer in a storage barrel than in the pack, rots in the end, and rotten food sickens but never kills;
#   4. cold, warmth, wet and shelter: a cold wet night chills, cover dries slowly and a fire fast, clothes keep warmth;
#   5. sleep: lying down under cover sleeps, energy and health come back faster;
#   6. wounds and healing: a wolf cripples (limp), a poultice heals, a splint sets the leg, medicine cures sickness;
#   7. the core rule: at 1 health no blow, fall or cold takes more; cold passes the player out and a rescue carries them, the pack kept,
#      a restart while passed out included.
#   godot --headless --path . --script res://src/worldgen/tools/test_survival_loop.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const DIR := "user://test_survival_loop"
const KEY := "survivalloop001"
const HOME := Vector3(0.0, 10.0, 0.0)

var failures: int = 0
var items
var notes: Array = []
var moved: Array = []
var weather: Dictionary = {"temp_c": 18.0, "wind": 0.0, "rain": 0.0, "snow": 0.0}
var cover: Array = [0.0]
var water: Array = [false]
var season: Array = ["autumn"]


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make():
	var it = ItemsScript.new()
	it.send_full = func(_p, _b): pass
	it.send_slots = func(_p, _b): pass
	it.send_world_items = func(_p, _a, _r): pass
	it.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	it.send_notice = func(_p, t): notes.append(str(t))
	it.send_died = func(p, cause, at): moved.append([p, cause, at])
	it.ground_height = func(_x, _z): return 10.0
	it.weather_now = func(): return weather
	it.rain_now = func(): return float(weather["rain"])
	it.season_now = func(): return season[0]
	it.cover_at = func(_p): return cover[0]
	it.drink_water_near = func(_p, _r): return water[0]
	it.rescue_spots = func(_pos): return [[Vector3(400.0, 10.0, 0.0), "goblin"], [Vector3(-900.0, 10.0, 0.0), "town"]]
	it.setup(ItemTableScript.load_default(), DIR)
	it._hints_loaded = true
	it._hints = []
	it.peer_connected_hello(1, KEY)
	it.report_position(1, HOME)
	return it


func n(id: String) -> int:
	return items.table.number_of(id)


func v() -> Dictionary:
	return items.vitals_of(1)


func count(id: String) -> int:
	return items.inventory_of(1).count_of(n(id))


func slot_of(id: String) -> int:
	var inv = items.inventory_of(1)

	for s in inv.slot_count:
		if inv.numbers[s] == n(id):
			return s

	return -1


func give(id: String, k: int) -> void:
	items.action(1, Net.ACT_ADMIN_GIVE, n(id), 0, k, Vector3.ZERO)


func eat(id: String) -> void:
	items._last_eat.clear()
	items.action(1, Net.ACT_EAT, slot_of(id), 0, 0, Vector3.ZERO)


func drink(slot: int = -1) -> void:
	items._last_drink.clear()
	items.action(1, Net.ACT_DRINK, slot, 0, 0, Vector3.ZERO)


# Real seconds of the server running, in slow ticks of `step` seconds.
func run(seconds: float, step: float = 10.0) -> void:
	var left: float = seconds

	while left > 0.0:
		items.tick(minf(step, left))
		left -= step


# What the body and pack hold, for a before and after.
func snapshot() -> Dictionary:
	var pack: Dictionary = {}
	var inv = items.inventory_of(1)

	for s in inv.slot_count:
		if inv.numbers[s] != 0:
			var id: String = items.table.id_of(inv.numbers[s])
			pack[id] = int(pack.get(id, 0)) + int(inv.counts[s])
			pack[id + "@wear"] = int(pack.get(id + "@wear", 0)) + int(inv.wear[s])

	var body: Dictionary = {}

	for k in ["fed", "weight", "health", "wet", "energy", "warmth", "sick", "limp"]:
		body[k] = snappedf(float(v().get(k, 0.0)), 0.01)

	body["soak"] = snappedf(float(items._soak.get(1, 0.0)), 0.01)
	return {"pack": pack, "body": body}


func restart(stage: String) -> void:
	var before: Dictionary = snapshot()
	items._dirty = true
	items.save()
	items._finish_writer()
	items = make()
	items._update_soak(1, 0.0)   # what the new server makes of the clothes before its first tick
	var after: Dictionary = snapshot()
	check(after == before, "%s: a server restart keeps the body and the pack exactly (%s)" % [stage, "same" if after == before else "%s -> %s" % [str(before), str(after)]])


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	items = make()
	var cap: float = float(items._vitals_cfg["stomach_cap_kcal"])
	var wet_cap: float = float(items._vitals_cfg["thirst"]["cap_ml"])

	# 1. Hunger.
	check(is_equal_approx(float(v()["fed"]), cap) and is_equal_approx(float(v()["wet"]), wet_cap), "a new player starts fed and watered")
	run(1800.0, 60.0)   # half a game day
	var fed_half: float = float(v()["fed"])
	check(fed_half < cap and fed_half > cap * 0.4, "half a game day at rest empties the stomach part way (%.0f of %.0f kcal)" % [fed_half, cap])
	give("roast_forage", 3)
	eat("roast_forage")
	check(float(v()["fed"]) > fed_half + 300.0 and count("roast_forage") == 2, "a Campfire Stew fills it again (%.0f kcal)" % float(v()["fed"]))
	restart("fed")
	v()["fed"] = 0.0
	v()["health"] = 60.0
	var kg0: float = float(v()["weight"])
	run(600.0, 60.0)
	check(float(v()["weight"]) < kg0 and is_equal_approx(float(v()["health"]), 60.0), "an empty stomach burns body weight (%.2f to %.2f kg) but never health, and stops healing" % [kg0, float(v()["weight"])])
	eat("roast_forage")
	run(120.0, 60.0)
	check(float(v()["health"]) > 60.0, "fed again, health recovers (%.1f)" % float(v()["health"]))
	restart("starved and fed")

	# 2. Thirst.
	v()["wet"] = 600.0
	drink()
	check(is_equal_approx(float(v()["wet"]), 600.0), "no water in reach: no drink")
	water[0] = true
	drink()
	check(is_equal_approx(float(v()["wet"]), 600.0 + float(items._vitals_cfg["thirst"]["drink_ml"])), "at the water's edge a mouthful (%.0f ml)" % float(v()["wet"]))
	give("waterskin", 1)
	drink(slot_of("waterskin"))
	var held: int = items.inventory_of(1).wear[slot_of("waterskin")]
	check(held > 0, "a waterskin in hand is filled instead (%d ml)" % held)
	restart("waterskin filled")
	water[0] = false
	var wet0: float = float(v()["wet"])
	eat("waterskin")
	check(float(v()["wet"]) > wet0 and items.inventory_of(1).wear[slot_of("waterskin")] < held, "away from water, a drink from the waterskin (%.0f to %.0f ml)" % [wet0, float(v()["wet"])])
	v()["wet"] = 0.0
	v()["fed"] = cap
	v()["health"] = 60.0
	run(300.0, 60.0)
	check(is_equal_approx(float(v()["health"]), 60.0), "dry, health stops recovering and is never lost (%.1f)" % float(v()["health"]))
	v()["wet"] = wet_cap
	restart("thirsty")

	# 3. Food rot and storage.
	give("raw_meat", 4)
	var barrel: int = items.dev_place("storage_barrel@3,0,0")
	items._items[barrel]["pos"] = Vector3(2.0, 10.0, 0.0)
	items.action(1, Net.ACT_CHEST_PUT, slot_of("raw_meat"), barrel, 2, Vector3.ZERO)
	var chest = items._chest_of(1, barrel)
	check(chest != null and chest.count_of(n("raw_meat")) == 2 and count("raw_meat") == 2, "two raw meat go into a storage barrel, two stay in the pack")
	run(600.0, 15.0)
	var pack_age: int = items.inventory_of(1).wear[slot_of("raw_meat")]
	var box_age: int = 0

	for s in chest.slot_count:
		if chest.numbers[s] == n("raw_meat"):
			box_age = chest.wear[s]

	check(pack_age > 0 and box_age > 0 and box_age < pack_age, "the barrel's meat ages slower than the pack's (%d against %d)" % [box_age, pack_age])
	restart("meat stored")
	chest = items._chest_of(1, items._items.keys().filter(func(id): return items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == "storage_barrel")[0])
	var box_after: int = 0

	for s in chest.slot_count:
		if chest.numbers[s] == n("raw_meat"):
			box_after = chest.wear[s]

	check(box_after == box_age, "the barrel keeps its meat's age over the restart (%d)" % box_after)
	var life: int = items.table.shelf_units(n("raw_meat"))
	items.inventory_of(1).wear[slot_of("raw_meat")] = life - 1
	run(60.0, 15.0)
	check(count("raw_meat") == 0 and count("rotten_food") == 2, "left too long in the pack, it rots (%d rotten)" % count("rotten_food"))
	v()["health"] = 1.0
	items._characters[KEY]["grace_s"] = 0.0
	eat("rotten_food")
	check(float(v()["health"]) >= 1.0 and items.is_sick(1), "rotten food at 1 health sickens but never kills (%.1f, sick %s)" % [float(v()["health"]), str(items.is_sick(1))])
	run(300.0, 30.0)
	check(float(v()["health"]) >= 1.0, "a sickness at 1 health takes no health (%.1f)" % float(v()["health"]))
	restart("sick")

	# 6 (part). Medicine cures the sickness.
	give("medicine", 1)
	eat("medicine")
	check(not items.is_sick(1) or float(v()["sick"]) < 12.0 * 3600.0, "medicine shortens the sickness (%.0f game s left)" % float(v()["sick"]))
	v()["sick"] = 0.0
	v()["health"] = 100.0

	# 4. Cold, warmth, wet and shelter.
	weather = {"temp_c": 2.0, "wind": 0.6, "rain": 0.8, "snow": 0.0}
	run(300.0, 10.0)
	var soaked: float = float(items._soak.get(1, 0.0))
	check(soaked > 0.5, "a cold rain in the open soaks the player (%.2f)" % soaked)
	check(float(v()["warmth"]) < 100.0, "and chills them (%.0f)" % float(v()["warmth"]))
	restart("soaked")
	items.peer_left(1)
	items.peer_connected_hello(1, KEY)
	items.report_position(1, HOME)
	items._update_soak(1, 0.0)
	check(float(items._soak.get(1, 0.0)) > 0.5, "leaving and joining again keeps the clothes wet too (%.2f)" % float(items._soak.get(1, 0.0)))
	items._become_new_player(1)
	items._update_soak(1, 0.0)
	var fresh_dry: bool = float(items._soak.get(1, 0.0)) == 0.0
	items._dirty = true
	items.save()
	items._finish_writer()
	items = make()
	items._update_soak(1, 0.0)
	check(fresh_dry and float(items._soak.get(1, 0.0)) == 0.0, "starting over as a new player (as after a death) is dry, before and after a restart")
	v()["soak"] = soaked
	items._soak.erase(1)
	items._update_soak(1, 0.0)
	v()["health"] = 100.0
	give("waterskin", 1)
	weather = {"temp_c": 2.0, "wind": 0.6, "rain": 0.0, "snow": 0.0}
	cover[0] = 1.0
	run(300.0, 10.0)
	var under: float = float(items._soak.get(1, 0.0))
	check(under < soaked, "under a roof the clothes dry slowly (%.2f to %.2f)" % [soaked, under])
	items._items[900001] = {"number": 1, "count": 1, "pos": Vector3(1.0, 10.0, 1.0), "left": 1.0e9, "fire": {"state": 1, "burn_left": 1.0e6, "covered": false, "recheck": 0.0}}
	var cold_w: float = float(v()["warmth"])
	run(300.0, 10.0)
	check(float(items._soak.get(1, 0.0)) < under, "by a fire faster (%.2f)" % float(items._soak.get(1, 0.0)))
	check(float(v()["warmth"]) > cold_w, "and the fire warms them (%.0f to %.0f)" % [cold_w, float(v()["warmth"])])
	items._items.erase(900001)
	restart("drying by the fire")
	cover[0] = 0.0
	weather = {"temp_c": 18.0, "wind": 0.0, "rain": 0.0, "snow": 0.0}
	v()["warmth"] = 100.0
	items._soak[1] = 0.0

	# 5. Sleep under cover.
	cover[0] = 1.0
	v()["fed"] = cap
	v()["wet"] = wet_cap
	v()["energy"] = 40.0
	v()["health"] = 50.0
	items.action(1, Net.ACT_STANCE, 3, 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_SLEEP, 1, 0, 0, Vector3.ZERO)
	check(items.sleeping_of(1), "lying down under cover, the player sleeps")
	run(300.0, 10.0)
	check(float(v()["energy"]) > 40.0 and float(v()["health"]) > 50.0 + 300.0 * float(items._vitals_cfg["health_regen_per_s"]), "asleep, energy comes back and health faster than awake (%.0f energy, %.1f health)" % [float(v()["energy"]), float(v()["health"])])
	restart("slept")
	check(not items.sleeping_of(1), "after a restart the player is awake (the client lies them down again)")
	cover[0] = 0.0

	# 6. Wounds and healing.
	v()["health"] = 100.0
	var wolf: Vector3 = Vector3(0.0, 10.0, 2.0)

	for k in 12:
		if items.hurt_player(1, 15.0, false, "wolves", 25.0, "", 0.0, wolf) == "maimed":
			break

	check(float(v()["limp"]) > 0.0 and float(v()["health"]) <= 25.0 and float(v()["health"]) > 0.0, "the wolves cripple the player: a limp, health at the floor (%.1f)" % float(v()["health"]))
	restart("crippled")
	give("poultice", 1)
	var hp0: float = float(v()["health"])
	eat("poultice")
	check(float(v()["health"]) >= hp0 + float(items._vitals_cfg["heal"]["poultice"]) - 0.5 and count("poultice") == 0, "a poultice heals %d (%.1f to %.1f)" % [int(items._vitals_cfg["heal"]["poultice"]), hp0, float(v()["health"])])
	give("splint", 1)
	eat("splint")
	check(float(v()["limp"]) <= 0.0 and count("splint") == 0, "a splint sets the leg")
	restart("healed")

	# 7. The core rule.
	v()["health"] = 1.0
	check(items.hurt_player(1, 80.0, true, "wolves", 1.0, "", 0.0, wolf) != "dead" and is_equal_approx(float(v()["health"]), 1.0), "at 1 health a killing bite takes nothing more")
	items._last_fall.clear()
	items._fall(1, 3000)
	check(is_equal_approx(float(v()["health"]), 1.0), "nor a 30 m fall")
	items._crushed(1, 50.0)
	check(is_equal_approx(float(v()["health"]), 1.0), "nor a falling tree")
	v()["health"] = 40.0
	give("stone", 9)
	weather = {"temp_c": -20.0, "wind": 1.0, "rain": 0.0, "snow": 0.6}
	moved.clear()
	notes.clear()
	var ticks: int = 0

	while not items.passed_out(1) and ticks < 4000:
		items.tick(10.0)
		ticks += 1

	check(items.passed_out(1) and is_equal_approx(float(v()["health"]), 1.0), "a freezing night takes health down to 1, then the player passes out (%d s)" % (ticks * 10))
	check(notes.has(str(items._warmth_cfg["pass_out"]["say_out"])), "and is told")
	# The server restarts while they lie there: on the next tick the cold takes them again, and the rescue comes.
	restart("passed out")
	moved.clear()
	notes.clear()
	ticks = 0

	while moved.is_empty() and ticks < 100:
		items.tick(1.0)
		ticks += 1

	check(not moved.is_empty() and (moved[-1][2] as Vector3).is_equal_approx(Vector3(400.0, 10.0, 0.0)), "after the restart they are found and carried to the nearest camp, the goblins' (%s)" % str(moved))
	check(notes.has(str(items._warmth_cfg["pass_out"]["say_wake"]["goblin"])), "with the goblins' message")
	check(count("stone") == 9 and count("waterskin") == 1, "the whole pack is kept")
	check(float(v()["health"]) >= float(items._warmth_cfg["pass_out"]["wake_health"]) - 0.5, "awake with some health back (%.1f)" % float(v()["health"]))

	items._finish_writer()
	print("Test done: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
