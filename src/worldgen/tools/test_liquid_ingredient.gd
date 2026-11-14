extends SceneTree

# GOALS-REPAIR WP-R1A commit B (recovery GA-04): a recipe's `water` ingredient is filled by the fresh water in real containers, through the real server.
#   PROVISIONAL (GOALS-REPAIR A-1): one water ingredient = 500 mL (the water item's unit_ml). PROVISIONAL (A-3): a bed takes up to 8000 mL a game day (crops.json pour_ml).
#   - the water of several part-filled containers is pooled; containers keep their identity, empty ones stay;
#   - too little water leaves every container untouched; salt water and sea_water never count (a fill at salt water is refused);
#   - a cancelled craft pours its water back into containers and never mints the stackable item (even with no container left: it spills);
#   - the water and a queued craft survive a save and load;
#   - two crafts for the same water cannot both have it; a stranger's chest is never used, the owner's chest is;
#   - the bed pour scales pour_pct by the mL poured, takes the container in hand first, and distrusts the slot the client names.
# The herb antidote (needs 1 water, no station) is the probe recipe; the fill itself is the real drink/fill action.
#   godot --headless --path . --script res://src/worldgen/tools/test_liquid_ingredient.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var items
var said: Array = []
var dir: String = ""
var clock: Array = [100.0 * 86400.0]
var near_water: Array = [true]
var rows_here: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1
		print("     the server said: ", str(said.slice(maxi(said.size() - 3, 0))) if not said.is_empty() else "nothing")


func make():
	DirAccess.make_dir_recursive_absolute(dir)
	var w = ItemsScript.new()
	w.send_full = func(_p, _b): pass
	w.send_slots = func(_p, _b): pass
	w.send_world_items = func(_p, _a, _r): pass
	w.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	w.send_notice = func(_p, t): said.append(str(t))
	w.send_chest = func(_p, _id, _b): pass
	w.send_carry = func(_p, _id): pass
	w.send_craft_stock = func(_p, _n, _c): pass
	w.ground_height = func(_x, _z): return 10.0
	w.game_seconds = func(): return clock[0]
	w.water_near = func(_pos, _reach): return near_water[0]
	w.water_source = func(_pos, _reach): return rows_here
	w.admin_mode_on = func(_p): return false
	w.setup(ItemTableScript.load_default(), dir)
	return w


func n(id: String) -> int:
	return items.table.number_of(id)


func inv():
	return items.inventory_of(1)


func have(id: String) -> int:
	return inv().count_of(n(id))


func recipe_number(id: String) -> int:
	for k in items.recipes.numbers():
		if str(items.recipes.recipe(int(k)).get("id", "")) == id:
			return int(k)

	return 0


# A new character's pack with the antidote's other needs, nothing to carry water in yet.
func reset() -> void:
	var pack = inv()

	for i in pack.slot_count:
		pack.clear_slot(i)

	items._craft_queues[items._peer_key[1]] = {"entries": [], "elapsed": 0.0}
	items._last_drink.clear()
	near_water[0] = true
	rows_here.clear()
	said.clear()
	give("plantain_leaves", 2)
	give("comfrey_leaves", 1)
	give("mortar_pestle", 1)


func give(id: String, count: int) -> void:
	items.action(1, Net.ACT_ADMIN_GIVE, n(id), 0, count, Vector3.ZERO)


# A container holding `ml` of water: given, then filled as a fill leaves it (the mL are its slot's wear). Returns its slot.
func vessel(id: String, ml: int) -> int:
	give(id, 1)

	for s in inv().slot_count:
		if inv().numbers[s] == n(id) and inv().wear[s] == 0 and ml > 0 and not _taken.has(s):
			inv().wear[s] = ml
			_taken[s] = true
			return s

	for s in inv().slot_count:
		if inv().numbers[s] == n(id) and not _taken.has(s):
			_taken[s] = true
			return s

	return -1


var _taken: Dictionary = {}


func craft(times: int = 1) -> void:
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, recipe_number("herb_antidote"), 0, times, Vector3.ZERO)

	for s in range(8 * times):
		items.tick(1.0)


func queue_only() -> void:
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, recipe_number("herb_antidote"), 0, 1, Vector3.ZERO)


# One pour on the test bed through the real action (b = the pack slot of the container in hand, -1 none); true when water left the pack.
func pour(held: int) -> bool:
	var before: int = inv().liquid_ml()
	items.action(1, Net.ACT_WATER_BED, 920001, held, 0, Vector3.ZERO)
	return inv().liquid_ml() < before


func fresh() -> void:
	_taken.clear()
	reset()


# Both players in the world, one at the origin, one far off, able to carry anything.
func join() -> void:
	items.peer_connected_hello(1, "liquidtest001")
	items.peer_connected_hello(2, "liquidtest002")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items.report_position(2, Vector3(0.0, 10.0, 300.0))
	items.vitals_of(1)["weight"] = 2000.0
	items.vitals_of(2)["weight"] = 2000.0


func _watchdog() -> void:
	print("FAIL the test did not finish (a script error stopped it)")
	quit(1)


func _init() -> void:
	# A script error part-way would leave the test hanging: this ends it, failed, well inside the lane's 300 s.
	create_timer(200.0).timeout.connect(_watchdog)
	dir = "user://test_liquid_ingredient_%d" % Time.get_ticks_usec()
	items = make()
	join()
	var water: int = n("water")
	var unit: int = items.table.liquid_unit_ml(water)

	check(unit == 500 and items.table.liquid_unit_ml(n("sea_water")) == 0 and items.table.liquid_unit_ml(n("stone")) == 0, "one water ingredient is 500 mL, from one constant in the data; sea water is no liquid ingredient")
	check(str(items.table.entry("water").get("_provisional", "")).begins_with("PROVISIONAL (GOALS-REPAIR A-1)"), "the value is tagged PROVISIONAL (GOALS-REPAIR A-1)")

	# The fill is the real action: a bucket at fresh water takes fill_ml (500); at salt water nothing goes in.
	fresh()
	var bucket: int = vessel("bucket", 0)
	items.action(1, Net.ACT_DRINK, bucket, 0, 0, Vector3.ZERO)
	check(inv().wear[bucket] == 500, "a fill at fresh water puts 500 mL in the bucket (%d)" % inv().wear[bucket])
	check(inv().count_fill(water) == 1 and inv().count_of(water) == 0, "that is one water ingredient, and no stackable water exists")
	near_water[0] = false
	rows_here.append({"kind": "salt"})
	items._last_drink.clear()
	inv().wear[bucket] = 0
	items.action(1, Net.ACT_DRINK, bucket, 0, 0, Vector3.ZERO)
	check(inv().wear[bucket] == 0 and inv().count_fill(water) == 0, "a fill at salt water is refused: the bucket stays empty")

	# Two part-filled containers pool: 300 + 300 mL is one ingredient; both containers stay, the empty one too.
	fresh()
	var skin: int = vessel("waterskin", 300)
	var bowl: int = vessel("wooden_bowl", 300)
	check(inv().count_fill(water) == 1 and inv().count_fill(water, true) == 0, "300 + 300 mL pool into one ingredient (building costs never use it)")
	craft()
	check(have("herb_antidote") == 1, "the craft is made from pooled water")
	check(inv().liquid_ml() == 100 and inv().count_of(n("waterskin")) == 1 and inv().count_of(n("wooden_bowl")) == 1, "500 mL left the containers (100 mL remain) and both containers are still there")
	check(inv().wear[skin] + inv().wear[bowl] == 100 and have("water") == 0, "the remainder sits in the containers; no stackable water was minted")

	# Too little water: nothing is touched.
	fresh()
	skin = vessel("waterskin", 200)
	bowl = vessel("wooden_bowl", 200)
	craft()
	check(have("herb_antidote") == 0 and inv().wear[skin] == 200 and inv().wear[bowl] == 200 and have("plantain_leaves") == 2 and have("comfrey_leaves") == 1, "400 mL is too little: no craft, containers and ingredients untouched")
	check(items._craft_queues[items._peer_key[1]]["entries"].is_empty(), "and nothing is queued")

	# Salt water never counts: sea water in the pack does not fill the ingredient.
	fresh()
	give("sea_water", 5)
	check(inv().count_fill(water) == 0, "sea water does not count as water")
	craft()
	check(have("herb_antidote") == 0 and have("sea_water") == 5, "sea water cannot make the antidote and stays in the pack")

	# Cancel refunds into containers, never as the item.
	fresh()
	skin = vessel("waterskin", 600)
	queue_only()
	check(inv().liquid_ml() == 100 and items._craft_queues[items._peer_key[1]]["entries"].size() == 1, "a queued craft has taken its 500 mL")
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_CANCEL, 0, 0, 0, Vector3.ZERO)
	check(inv().liquid_ml() == 600 and inv().wear[skin] == 600 and have("water") == 0 and have("plantain_leaves") == 2, "a cancel pours the water back into the container and returns the herbs")

	fresh()
	skin = vessel("waterskin", 600)
	queue_only()
	inv().clear_slot(skin)   # the container is given away before the cancel
	said.clear()
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_CANCEL, 0, 0, 0, Vector3.ZERO)
	check(have("water") == 0 and inv().liquid_ml() == 0 and said.any(func(t): return t.contains("spills")), "with no container left the water spills: it is never minted as the stackable item")

	# Save and load: the water in the containers, and a craft that is waiting, with the water it took.
	fresh()
	skin = vessel("waterskin", 1000)
	queue_only()
	check(inv().wear[skin] == 500, "the queued craft took 500 of the 1000 mL")
	items.save()
	items._finish_writer()
	items = make()
	join()   # a restarted server knows no one's position until they report it: without it nothing is in reach
	skin = inv().numbers.find(n("waterskin"))
	check(skin >= 0 and inv().wear[skin] == 500, "the container's water survives a save and load (%d mL)" % (inv().wear[skin] if skin >= 0 else -1))
	var queue: Dictionary = items._craft_queues.get(items._peer_key[1], {})
	check(not queue.is_empty() and (queue["entries"] as Array).size() == 1, "the waiting craft survives it too")
	var water_rows: Array = []

	if not queue.is_empty() and (queue["entries"] as Array).size() == 1:
		for need in queue["entries"][0][2]:
			if int(need[0]) == water and need.size() > 2:
				water_rows = need[2]

	check(not water_rows.is_empty() and (water_rows[0][1] as Dictionary).has("liquid_ml"), "and the row that records the water taken keeps its liquid_ml through the save (the instance cleaner must not drop it)")
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_CANCEL, 0, 0, 0, Vector3.ZERO)
	check(skin >= 0 and inv().wear[skin] == 1000 and have("water") == 0, "and a cancel after the reload still pours the water back (%d mL)" % (inv().wear[skin] if skin >= 0 else -1))

	# Two crafts for the same 500 mL: the second is refused; the Inventory seam agrees.
	fresh()
	vessel("waterskin", 500)
	queue_only()
	queue_only()
	check((items._craft_queues[items._peer_key[1]]["entries"] as Array).size() == 1 and inv().liquid_ml() == 0, "a second craft for the same water finds none: it is not spent twice")
	var shared = load("res://src/shared/inventory.gd").new(items.table)
	shared.add(n("waterskin"), 1, 500)
	var taken_a: Array = []
	var taken_b: Array = []
	check(shared.remove_fill(water, 1, taken_a) and not shared.remove_fill(water, 1, taken_b) and shared.liquid_ml() == 0 and taken_b.is_empty(), "two takers of one container: one gets the water, the other gets nothing")

	# A chest's water: the owner's craft draws on a waterskin in it (it stays, empty); a stranger's craft never does.
	fresh()
	var chest: int = items.dev_place("chest@2,0,0")
	items._items[chest]["struct"]["owner"] = str(items._peer_key[1])
	var box = items._chests[int(items._items[chest]["struct"]["uid"])]
	box.add(n("waterskin"), 1, 500)
	check(box.count_fill(water) == 1 and inv().count_fill(water) == 0, "the chest's skin holds an ingredient; the pack holds none")
	craft()
	check(have("herb_antidote") == 1 and box.liquid_ml() == 0 and box.count_of(n("waterskin")) == 1, "the owner's craft takes the water from the chest's container, which stays")
	items._items[chest]["struct"]["owner"] = str(items._peer_key[2])
	box.wear[box.numbers.find(n("waterskin"))] = 500
	fresh()
	craft()
	check(have("herb_antidote") == 0 and box.liquid_ml() == 500, "another player's chest is never used for water")

	# A cancel from afar: the water came from the player's own chest, they walked out of reach, the cancel pours it back into that chest (never the pack, never minted).
	fresh()
	var far_chest: int = items.dev_place("chest@8,0,0")
	items._items[far_chest]["struct"]["owner"] = str(items._peer_key[1])
	var far_box = items._chests[int(items._items[far_chest]["struct"]["uid"])]
	far_box.add(n("waterskin"), 1, 1000)
	queue_only()
	check(far_box.liquid_ml() == 500 and inv().liquid_ml() == 0, "the queued craft took its 500 mL from the chest's skin")
	items.report_position(1, Vector3(0.0, 10.0, 100.0))
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_CANCEL, 0, 0, 0, Vector3.ZERO)
	check(far_box.liquid_ml() == 1000 and inv().liquid_ml() == 0 and have("water") == 0 and have("plantain_leaves") == 2, "cancelled 100 m away: the 500 mL went back into the chest's skin, nothing minted")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items._items.erase(far_chest)

	# A stale source: the chest the water came from is gone (its world id and uid no longer match), so the cancel pours into the pack, once: no stackable water, nothing doubled.
	fresh()
	var gone_chest: int = items.dev_place("chest@8,0,0")
	items._items[gone_chest]["struct"]["owner"] = str(items._peer_key[1])
	var gone_box = items._chests[int(items._items[gone_chest]["struct"]["uid"])]
	gone_box.add(n("waterskin"), 1, 1000)
	var carrier: int = vessel("bucket", 0)
	queue_only()
	check(gone_box.liquid_ml() == 500 and inv().liquid_ml() == 0, "the queued craft took its 500 mL from the chest's skin (a bucket waits empty in the pack)")
	items._items.erase(gone_chest)
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_CANCEL, 0, 0, 0, Vector3.ZERO)
	check(inv().wear[carrier] == 500 and inv().liquid_ml() == 500 and have("water") == 0 and gone_box.liquid_ml() == 500, "the source chest is gone: the 500 mL land in the pack's bucket once, nothing minted, nothing poured into the old box")

	# The same, with the chest still standing but no longer the player's: the owner is re-checked, so the water goes to the pack.
	fresh()
	var sold_chest: int = items.dev_place("chest@8,0,0")
	items._items[sold_chest]["struct"]["owner"] = str(items._peer_key[1])
	var sold_box = items._chests[int(items._items[sold_chest]["struct"]["uid"])]
	sold_box.add(n("waterskin"), 1, 1000)
	carrier = vessel("bucket", 0)
	queue_only()
	items._items[sold_chest]["struct"]["owner"] = str(items._peer_key[2])
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_CANCEL, 0, 0, 0, Vector3.ZERO)
	check(inv().wear[carrier] == 500 and have("water") == 0 and sold_box.liquid_ml() == 500, "a chest that is no longer theirs gets none of it back: the 500 mL land in the pack")
	items._items.erase(sold_chest)

	# The bed: a bucket's 8000 mL is pour_pct; the container in hand first, the pack's other water after; up to a bucket a game day; every refusal says why.
	fresh()
	items._structures["test_plot"] = {"kit": "test_plot_kit", "item": "tilled_bed", "state": 9907, "plot": true, "moisture_factor": 1.0, "cap_per_chunk": 12}
	var spot: Vector3 = Vector3(40.5, 10.0, 40.5)
	items._items[920001] = {"number": n("tilled_bed"), "count": 1, "pos": spot, "left": 1.0e9, "struct": {"kind": "test_plot", "yaw": 0.0}}
	var key: String = items._bed_key(spot)
	items._crops[key] = {"crop": "barley", "sown": 0, "age": 0.0, "wet": 0, "day": items._game_day(), "compost": false, "poured": -1}
	items._plot_water[key] = [50.0, clock[0]]
	items.report_position(1, spot + Vector3(0.0, 0.0, 1.0))
	var cfg: Dictionary = items._moisture_cfg
	var full_pct: float = float(cfg["pour_pct"])
	check(int(cfg.get("pour_ml", 0)) == 8000 and str(cfg.get("pour_ml_note", "")).begins_with("PROVISIONAL (GOALS-REPAIR A-3)"), "a bed's bucket is 8000 mL, tagged PROVISIONAL (GOALS-REPAIR A-3)")
	check(not pour(-1) and absf(items.plot_moisture(spot) - 50.0) < 0.01 and said.any(func(t): return t.contains("no water")), "no water: refused with a notice, nothing changes")
	var big: int = vessel("bucket", 6500)
	var little: int = vessel("waterskin", 1500)
	check(pour(-1), "8000 mL across two containers pour as one bucket")
	check(absf(items.plot_moisture(spot) - (50.0 + full_pct)) < 0.01 and inv().wear[little] == 0 and inv().wear[big] == 0 and have("bucket") == 1 and have("waterskin") == 1, "that adds pour_pct (%.2f); both containers stay, empty" % items.plot_moisture(spot))
	inv().wear[big] = 3000
	said.clear()
	check(not pour(big) and inv().wear[big] == 3000 and said.any(func(t): return t.contains("had its water")), "a second pour the same day is refused with a notice: the day's bucket is poured, nothing is taken")

	clock[0] += 86400.0
	items._plot_water[key] = [50.0, clock[0]]
	inv().wear[big] = 0
	inv().wear[little] = 1500
	check(pour(little) and absf(items.plot_moisture(spot) - (50.0 + full_pct * 1500.0 / 8000.0)) < 0.01 and inv().wear[little] == 0, "1500 mL adds pour_pct x 1500/8000 (%.3f)" % (items.plot_moisture(spot) - 50.0))
	inv().wear[little] = 1500
	check(pour(little) and absf(items.plot_moisture(spot) - (50.0 + full_pct * 3000.0 / 8000.0)) < 0.01, "small pours the same day add up toward the one bucket (%.3f)" % (items.plot_moisture(spot) - 50.0))

	clock[0] += 86400.0
	items._plot_water[key] = [50.0, clock[0]]
	inv().wear[big] = 8000
	inv().wear[little] = 1500
	check(pour(little) and inv().wear[little] == 0 and inv().wear[big] == 1500, "the container in hand is drained first, the others make up the bucket")

	clock[0] += 86400.0
	items._plot_water[key] = [50.0, clock[0]]
	inv().wear[big] = 2000
	inv().wear[little] = 0
	var axe: int = vessel("stone_axe", 0)
	said.clear()
	check(not pour(axe) and not pour(999) and not pour(little) and inv().wear[big] == 2000, "a slot that is no container, does not exist, or holds no water is refused: nothing is poured")
	check(said.any(func(t): return t.contains("holds no water")), "and the player is told")
	inv().wear[big] = 0
	give("sea_water", 3)
	said.clear()
	check(not pour(-1) and have("sea_water") == 3 and said.any(func(t): return t.contains("Salt water")), "sea water cannot water a bed: refused with a notice")
	items.report_position(1, spot + Vector3(30.0, 0.0, 0.0))
	said.clear()
	check(not pour(-1) and said.any(func(t): return t.contains("Too far")), "too far from the bed: refused with a notice")
	items._items.erase(920001)
	items._structures.erase("test_plot")

	print("liquid ingredient: %d failures" % failures)
	items._finish_writer()
	quit(1 if failures > 0 else 0)
