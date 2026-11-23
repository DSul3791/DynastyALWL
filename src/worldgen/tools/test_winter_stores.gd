extends SceneTree

# Winter stores at scale (coordinator 23 Nov 2026: "the guide pushes storing food in the thousands, so test it"): a homestead's chests, barrels,
# baskets and a root cellar holding thousands of food items through a whole game year with a server restart each season, and a player living
# the winter on them.
#   1. rot by container: each kind ages at its spoilage.json place_mult (the cellar at its own cold rate), the season's multiplier on top;
#   2. a restart each season keeps every count and every age exactly;
#   3. the cost: one spoil step over the whole homestead, a save and its size, opening a full chest, Store all, Sort and Stack to nearby,
#      each against a budget a 20 Hz server tick can afford;
#   4. a winter (91 game days) eating only from the stores: the player stays fed, never loses health to hunger, and the stores last.
#   godot --headless --path . --script res://src/worldgen/tools/test_winter_stores.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const FoodEffectsScript := preload("res://src/shared/food_effects.gd")

const DIR := "user://test_winter_stores"
const KEY := "winterstores001"
const PER_SLOT := 10    # a handful per slot: thousands in all, as a player lays them in over an autumn (a slot holds far more)
const DAY_S := 3600.0   # one game day in real seconds (24:1)
const FOODS := ["jerky", "smoked_meat", "salted_fish", "dried_berries", "dried_apples", "cheese", "trail_bread", "sauerkraut", "pickled_vegetables", "hazelnuts"]
const KINDS := {"plank_chest": 6, "storage_barrel": 6, "wicker_basket": 4, "large_wooden_chest": 2, "root_cellar": 2}

var failures: int = 0
var items
var season: Array = ["autumn"]
var chest_bytes: Array = [0]
var notes: Array = []


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
	it.send_chest = func(_p, _id, b): chest_bytes[0] = (b as PackedByteArray).size()
	it.send_bulk_done = func(_p, _k, _s, _t, _ids): pass
	it.ground_height = func(_x, _z): return 10.0
	it.season_now = func(): return season[0]
	it.year_mean_at = func(_p): return 8.0
	it.weather_now = func(): return {"temp_c": 15.0, "wind": 0.0, "rain": 0.0, "snow": 0.0}
	it.setup(ItemTableScript.load_default(), DIR)
	it._hints_loaded = true
	it._hints = []
	it.peer_connected_hello(1, KEY)
	it.report_position(1, Vector3(0.0, 10.0, 0.0))
	it.vitals_of(1)["weight"] = 75.0
	return it


func n(id: String) -> int:
	return items.table.number_of(id)


# Every storage container on the homestead, by kind: [world id, inventory].
func stores() -> Array:
	var out: Array = []

	for id in items._items:
		var it: Dictionary = items._items[id]

		if it.has("struct") and KINDS.has(str(it["struct"]["kind"])):
			out.append([id, str(it["struct"]["kind"]), items._chests[int(it["struct"]["uid"])]])

	return out


# Count and summed age of every food in the stores, by item.
func tally() -> Dictionary:
	var out: Dictionary = {}

	for row in stores():
		var box = row[2]

		for s in box.slot_count:
			if box.numbers[s] != 0:
				var id: String = items.table.id_of(box.numbers[s])
				out[id] = int(out.get(id, 0)) + int(box.counts[s])
				out[id + "@age"] = int(out.get(id + "@age", 0)) + int(box.wear[s]) * int(box.counts[s])

	return out


func food_total() -> int:
	var total: int = 0
	var t: Dictionary = tally()

	for id in FOODS:
		total += int(t.get(id, 0))

	return total


func restart(stage: String) -> void:
	var before: Dictionary = tally()
	items._dirty = true
	items.save()
	items._finish_writer()
	items = make()
	var after: Dictionary = tally()
	check(after == before, "%s: a server restart keeps every count and age in the stores (%s)" % [stage, "same" if after == before else "%s -> %s" % [str(before), str(after)]])


func usec(f: Callable) -> int:
	var t0: int = Time.get_ticks_usec()
	f.call()
	return Time.get_ticks_usec() - t0


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for sub in [DIR, DIR + "/" + ItemsScript.AREA_DIR]:
		DirAccess.make_dir_recursive_absolute(sub)

		for file in DirAccess.get_files_at(sub):
			DirAccess.remove_absolute(sub + "/" + file)

	items = make()
	var placed: int = 0

	for kind in KINDS:
		for k in int(KINDS[kind]):
			var id: int = items.dev_place("%s@%d,0,%d" % [kind, 2 + (placed % 6) * 2, 2 + int(placed / 6.0) * 2])

			if id == 0:
				check(false, "a %s stands on the homestead" % kind)

			items._items[id]["struct"]["owner"] = KEY
			placed += 1

	# Fill every slot with food, a kind per slot in turn.
	var food_i: int = 0

	for row in stores():
		var box = row[2]

		for s in box.usable:
			var number: int = n(FOODS[food_i % FOODS.size()])
			box.add(number, PER_SLOT, items.table.ready_units(number))   # sealed foods (sauerkraut, pickles) go in Ready, as a player stores them
			food_i += 1

	var stored: int = food_total()
	check(stored >= 2000, "the homestead holds %d food items in %d containers (%d slots)" % [stored, stores().size(), food_i])
	restart("filled")

	# 3. The cost, with the stores full.
	var spoil_us: int = usec(func(): items._spoil_tick(float(items.table.spoilage().get("tick_s", 15))))
	check(spoil_us < 20000, "one spoil step over every container takes %.2f ms (under 20 ms)" % (spoil_us / 1000.0))
	items._dirty = true
	var save_us: int = usec(func(): items.save())
	items._finish_writer()
	var bytes: int = 0

	for file in DirAccess.get_files_at(DIR):
		bytes += FileAccess.get_file_as_bytes(DIR + "/" + file).size()

	check(save_us < 100000, "a save on the tick takes %.1f ms (under 100 ms); the save folder is %d KB" % [save_us / 1000.0, int(bytes / 1024.0)])
	var big: Array = stores().filter(func(r): return str(r[1]) == "large_wooden_chest")[0]
	items.report_position(1, items._items[big[0]]["pos"] + Vector3(1.0, 0.0, 0.0))
	var open_us: int = usec(func(): items.action(1, Net.ACT_CHEST_OPEN, big[0], 0, 0, Vector3.ZERO))
	check(open_us < 20000 and chest_bytes[0] > 0, "opening a full %d-slot chest takes %.2f ms and sends %d bytes" % [big[2].slot_count, open_us / 1000.0, chest_bytes[0]])
	var sort_us: int = usec(func(): items.action(1, Net.ACT_BULK, 3, 1, 0, Vector3.ZERO))
	check(sort_us < 20000, "Sort with it open takes %.2f ms" % (sort_us / 1000.0))
	var inv = items.inventory_of(1)

	for id in FOODS:
		inv.add(n(id), 3)

	var take_us: int = usec(func(): items.action(1, Net.ACT_BULK, 2, 0, 0, Vector3.ZERO))
	check(take_us < 50000, "Stack to nearby over %d containers takes %.2f ms" % [stores().size(), take_us / 1000.0])
	var store_us: int = usec(func(): items.action(1, Net.ACT_BULK, 1, 0, 0, Vector3.ZERO))
	check(store_us < 20000, "Store all into the open chest takes %.2f ms" % (store_us / 1000.0))
	items.action(1, Net.ACT_CHEST_CLOSE, big[0], 0, 0, Vector3.ZERO)

	# 1. Rot by container: one autumn day, then the age each kind reached against the pack's rate.
	var start_age: Dictionary = {}

	for row in stores():
		start_age[row[0]] = int(row[2].wear[0])

	items._spoil_tick(DAY_S)
	var pack_units: float = DAY_S * float(ItemsScript.GAME_RATE) / 3600.0 / float(items.table.spoilage()["unit_h"])
	var place_mult: Dictionary = items.table.spoilage()["place_mult"]
	var cellar_mult: float = ItemsScript.cold_store_mult(items.table.spoilage()["cold_store"], 8.0)

	for kind in KINDS:
		var row: Array = stores().filter(func(r): return str(r[1]) == kind)[0]
		var aged: float = float(int(row[2].wear[0]) - int(start_age[row[0]]))
		var want: float = pack_units * (cellar_mult if kind == "root_cellar" else float(place_mult.get(kind, 1.0)))
		check(absf(aged - want) <= 1.0, "a %s ages food %.0f units a day, its rate x%.2f of the pack's %.0f" % [kind, aged, aged / pack_units, pack_units])

	restart("autumn day")

	# 2. The rest of the year, a restart each season; the season's multiplier applies to all but the cellar.
	for s in ["autumn", "winter", "spring", "summer"]:
		season[0] = s

		for d in 91 if s != "autumn" else 90:
			items._spoil_tick(DAY_S)

		restart("end of %s" % s)

	var after_year: Dictionary = tally()
	var rotten: int = int(after_year.get("rotten_food", 0))
	print("  a year on: %s" % str(after_year).substr(0, 600))
	check(rotten > 0 and int(after_year.get("pickled_vegetables", 0)) > 0, "after a year the shortest-lived stores have rotted (%d rotten) and the longest still keep" % rotten)

	# 4. A winter on stores: a fresh homestead, the player eating only what the stores hold.
	for row in stores():
		var box = row[2]

		for s in box.slot_count:
			box.clear_slot(s)

	food_i = 0

	for row in stores():
		var box = row[2]

		for s in box.usable:
			var number: int = n(FOODS[food_i % FOODS.size()])
			box.add(number, PER_SLOT, items.table.ready_units(number))   # sealed foods (sauerkraut, pickles) go in Ready, as a player stores them
			food_i += 1

	season[0] = "winter"
	inv = items.inventory_of(1)   # the server since the last restart
	var v: Dictionary = items.vitals_of(1)
	v["fed"] = 2400.0
	v["health"] = 100.0
	var low_fed: float = 2400.0
	var low_health: float = 100.0
	var eaten: int = 0
	var start_food: int = food_total()

	for day in 91:
		for meal in 6:   # a meal every 4 game hours
			items.tick(DAY_S / 6.0)
			low_fed = minf(low_fed, float(v["fed"]))
			low_health = minf(low_health, float(v["health"]))

			while float(v["fed"]) < 2000.0:
				var took: bool = false

				for row in stores():
					var box = row[2]

					for s in box.slot_count:
						if box.numbers[s] != 0 and FOODS.has(items.table.id_of(box.numbers[s])):
							items.report_position(1, items._items[row[0]]["pos"] + Vector3(1.0, 0.0, 0.0))
							items.action(1, Net.ACT_CHEST_OPEN, row[0], 0, 0, Vector3.ZERO)
							items.action(1, Net.ACT_CHEST_TAKE, s, row[0], 1, Vector3.ZERO)
							took = true
							break

					if took:
						break

				if not took:
					break

				var slot: int = -1

				for k in inv.slot_count:
					if inv.numbers[k] != 0 and FOODS.has(items.table.id_of(inv.numbers[k])):
						slot = k

				if slot < 0:
					break

				items._last_eat.clear()
				var fed0: float = float(v["fed"])
				items.action(1, Net.ACT_EAT, slot, 0, 0, Vector3.ZERO)

				if float(v["fed"]) <= fed0:   # a food question (a weaker food would replace a stronger effect): the player eats it for its calories
					items._last_eat.clear()
					items.action(1, Net.ACT_EAT, slot, FoodEffectsScript.DECLINE, 0, Vector3.ZERO)

				if float(v["fed"]) <= fed0:
					break   # full: the day goes on

				eaten += 1

		if day % 30 == 29:
			restart("winter day %d" % (day + 1))
			v = items.vitals_of(1)
			inv = items.inventory_of(1)

	check(eaten > 91 and low_fed > 0.0, "a winter of 91 days eaten from the stores (%d items, %d left of %d): the stomach never empties (lowest %.0f kcal)" % [eaten, food_total(), start_food, low_fed])
	check(low_health >= 99.0, "and health never falls for want of food (lowest %.1f)" % low_health)
	check(food_total() * 2 > start_food, "the stores outlast the winter with more than half left")

	items._finish_writer()
	print("Test done: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
