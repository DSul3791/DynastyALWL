extends SceneTree

# Farming rules on the server (FARMING_SPEC.md steps 2 to 5; Tyler 31 Oct 2026). A hoe tills a bed; a seed is sown only in its season and is used up; a game day with
# rain or poured water is a wet day; a crop is ripe only when old enough AND wet enough (a dry bed stalls at stage 2); winter pauses growth and kills a seedling (turnip
# grows on); compost speeds growth by 20 percent; harvest gives the yields and seeds back, half without the sickle for grain; an unripe crop is refused; crops are saved.
#   godot --headless --path . --script res://src/worldgen/tools/test_farming.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var items
var clock: Array = [0.0]
var season: Array = ["spring"]
var rain: Array = [0.0]


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make(dir: String):
	DirAccess.make_dir_recursive_absolute(dir)
	var it = ItemsScript.new()
	it.send_full = func(_p, _b): pass
	it.send_slots = func(_p, _b): pass
	it.send_world_items = func(_p, _a, _r): pass
	it.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	it.send_notice = func(_p, _t): pass
	it.ground_height = func(_x, _z): return 10.0
	it.game_seconds = func(): return clock[0]
	it.season_now = func(): return season[0]
	it.rain_now = func(): return rain[0]
	it.setup(ItemTableScript.load_default(), dir)
	return it


func count(id: String) -> int:
	return items.inventory_of(1).count_of(items.table.number_of(id))


func give(id: String, n: int) -> void:
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of(id), 0, n, Vector3.ZERO)


func slot_of(id: String) -> int:
	return items.inventory_of(1).numbers.find(items.table.number_of(id))


func bed_id() -> int:
	for k in items._items:
		if items._items[k].has("struct") and str(items._items[k]["struct"]["kind"]) == "tilled_bed":
			return k

	return 0


func days(n: int) -> void:
	clock[0] += float(n) * 86400.0
	items._crops_tick()


func _init() -> void:
	var dir: String = "user://test_farming"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = make(dir)
	items.peer_connected_hello(1, "farmer000001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items.vitals_of(1)["weight"] = 2000.0
	var crops: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/crops.json"))["crops"]
	check(crops.size() == 12 and crops["wheat"]["grow_days"] > 20, "crops.json lists the 12 crops (wheat grows %d days)" % int(crops["wheat"]["grow_days"]))

	# Till.
	check(items.till(1, items.inventory_of(1), Vector3(1.0, 10.0, 1.0)) == 0, "no hoe: nothing is tilled")
	give("wooden_hoe" if items.table.has_id("wooden_hoe") else "stone_hoe", 1)
	var made: int = items.till(1, items.inventory_of(1), Vector3(1.2, 10.0, 1.2))
	check(made != 0 and bed_id() != 0, "with a hoe a bed is tilled")
	items._last_dig.clear()
	check(items.till(1, items.inventory_of(1), Vector3(1.3, 10.0, 1.3)) == 0 and items._items.keys().filter(func(k): return items._items[k].has("struct") and str(items._items[k]["struct"]["kind"]) == "tilled_bed").size() == 1, "the same metre is not tilled twice")

	# Sow: wheat is a spring crop.
	var bed: int = bed_id()
	give("wheat_seeds", 3)
	season[0] = "autumn"
	check(not items.sow(1, items.inventory_of(1), bed, slot_of("wheat_seeds")) and count("wheat_seeds") == 3, "wheat is refused out of season and the seed is kept")
	season[0] = "spring"
	check(items.sow(1, items.inventory_of(1), bed, slot_of("wheat_seeds")) and count("wheat_seeds") == 2, "in spring the sowing works and uses one seed")
	check(not items.sow(1, items.inventory_of(1), bed, slot_of("wheat_seeds")), "a bed with a crop takes no second seed")
	var key: String = items._bed_key(items._items[bed]["pos"])
	check(items.crop_stage(items._crops[key]) == 0 and not items.harvest(1, items.inventory_of(1), bed), "a seedling is not ripe: harvest refused")

	# Growth: the grow days of wheat, rain on every day = ripe; a dry bed stalls at stage 2.
	var grow: int = int(crops["wheat"]["grow_days"])
	rain[0] = 0.5
	days(1)
	check(int(items._crops[key]["age"]) == 1 and int(items._crops[key]["wet"]) == 1, "a rainy day is a wet day and the crop is a day older")
	items._crops[key]["compost"] = true
	days(10)
	check(absf(float(items._crops[key]["age"]) - (1.0 + 12.0)) < 0.01, "with compost each day is 1.2 days of growth (age %.1f after 11 days)" % float(items._crops[key]["age"]))
	items._crops[key]["compost"] = false
	season[0] = "summer"
	days(grow)
	check(items.crop_stage(items._crops[key]) == 3, "after the grow days with rain on each, the crop is ripe")

	# A dry bed: same age, no wet days: stalls at stage 2.
	var dry_key: String = "99,99"
	items._crops[dry_key] = {"crop": "wheat", "sown": 0, "age": float(grow) + 5.0, "wet": 0, "day": items._game_day(), "compost": false, "rained": -1, "poured": -1}
	check(items.crop_stage(items._crops[dry_key]) == 2, "old enough but never watered: stalls at stage 2, not ripe")
	items._crops.erase(dry_key)

	# Harvest: without a sickle half the yield.
	var yield_wheat: int = int(crops["wheat"]["yields"][0][1])
	check(items.harvest(1, items.inventory_of(1), bed) and count("wheat") == int(ceil(float(yield_wheat) / 2.0)) and count("wheat_seeds") >= 4 and not items._crops.has(key), "no sickle: half the wheat (%d of %d), the seeds come back, the bed is empty" % [count("wheat"), yield_wheat])

	# Full yield with a sickle, second crop; winter and frost.
	give("sickle", 1)
	season[0] = "spring"
	rain[0] = 0.0
	check(items.sow(1, items.inventory_of(1), bed, slot_of("wheat_seeds")), "the bed is sown again")
	season[0] = "winter"
	days(1)
	check(not items._crops.has(key), "a seedling does not survive winter frost")
	give("turnip_seeds", 1)
	check(items.sow(1, items.inventory_of(1), bed, slot_of("turnip_seeds")), "turnip can be sown in winter")
	days(2)
	check(items._crops.has(key) and float(items._crops[key]["age"]) >= 2.0, "and grows through it")

	# Wheat with the sickle: put a ripe crop in directly (growth was tested above) and harvest it with the tool.
	items._crops.erase(key)
	items._crops[key] = {"crop": "wheat", "sown": 0, "age": float(grow), "wet": grow, "day": items._game_day(), "compost": false, "rained": -1, "poured": -1}
	var before: int = count("wheat")
	check(items.harvest(1, items.inventory_of(1), bed) and count("wheat") - before == yield_wheat, "with a sickle the full yield (%d)" % (count("wheat") - before))

	# Water poured counts: sow, pour, next day wet.
	season[0] = "spring"
	give("water", 1)
	give("barley_seeds", 1)
	items.sow(1, items.inventory_of(1), bed, slot_of("barley_seeds"))
	check(items.water_bed(1, items.inventory_of(1), bed) and not items.water_bed(1, items.inventory_of(1), bed), "one water pours on the bed per day")
	days(1)
	check(int(items._crops[key]["wet"]) == 1, "water poured makes the next game day wet")

	# Save and restart.
	items._save_characters()
	items._write_atomic("crops.json", {"version": 1, "crops": items._crops})
	items._finish_writer()
	var again = make(dir)
	check(again._crops.has(key) and str(again._crops[key]["crop"]) == "barley", "the crop is saved and still growing after a restart")
	print("farming: %d failures" % failures)
	quit(1 if failures > 0 else 0)
