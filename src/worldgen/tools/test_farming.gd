extends SceneTree

# Farming rules on the server (FARMING_SPEC.md steps 2 to 5; Tyler 31 Oct 2026). A hoe tills a bed; a seed is sown only in its season and is used up; a game day that
# ends with the bed's moisture at 25 percent or more (rain fills it, a pour adds to it, the weather dries it) is a wet day; a crop is ripe only when old enough AND wet enough (a dry bed stalls at stage 2); winter pauses growth and kills a seedling (turnip
# grows on); compost speeds growth by 20 percent; harvest gives the yields and seeds back, half without the sickle for grain; an unripe crop is refused; crops are saved.
# GOALS-REPAIR WP-R1B adds the player's route through the requests the client sends (ACT_SOW with the bed id and the seed's pack slot, ACT_WATER_BED, ACT_HARVEST): a real flax
# crop from wild seed to harvest, the sowing seasons of flax and the four grains in every season, a wrong seed, too far, a double harvest, the crop and stage in the bed's world
# row, and the crop's stage through a save and restart. The client half (prompts, stage looks) is held by test_farm_prompt.gd.
#   godot --headless --path . --script res://src/worldgen/tools/test_farming.gd

const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const PlotWater := preload("res://src/shared/plot_water.gd")
const Gather := preload("res://src/shared/gather_rules.gd")

var failures: int = 0
var items
var clock: Array = [0.0]
var season: Array = ["spring"]
var rain: Array = [0.0]
var sent: Array = []     # every send_world_items call: [peer, added rows, removed ids]
var notes: Array = []    # every notice the server said to the player
var last_extra: Dictionary = {}


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make(dir: String):
	DirAccess.make_dir_recursive_absolute(dir)
	var it = ItemsScript.new()
	it.send_full = func(_p, _b): pass
	it.send_slots = func(_p, _b): pass
	it.send_world_items = func(p, a, r): sent.append([p, a, r])
	it.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	it.send_notice = func(_p, t): notes.append(t)
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


# What the server sends the farmer for this bed now: the extras of its latest world row (a row is resent only when its signature changed, so a stage that did not reach the wire
# would still show the old extras here and fail the check).
func row_extra(bed: int) -> Dictionary:
	sent.clear()
	items._sync_world_items()

	for batch in sent:
		for row in batch[1]:
			if int(row[0]) == bed:
				last_extra = row[5]

	return last_extra


func act(kind: int, a: int, b: int = 0) -> void:
	items.action(1, kind, a, b, 0, Vector3.ZERO)


func days(n: int) -> void:
	clock[0] += float(n) * 86400.0
	items._crops_tick()


# Plot moisture (buildables plan B5; Sonny's water rules section 8): heavy rain fills a bed, the dry weather takes its evaporation (more when hot or
# windy, little near freezing, less from a framed plot with moisture_factor), a pour adds a bucket's 8 percent, a crop's day is wet at 25 percent or more.
func _moisture_checks(bed: int) -> void:
	var cfg: Dictionary = items._moisture_cfg
	check(not cfg.is_empty() and PlotWater.step(cfg, 10.0, 0.1, 20.0, 0.0, 0.8) == 100.0, "heavy rain fills a plot")
	var hot: float = 100.0 - PlotWater.step(cfg, 100.0, 1.0, 25.0, 0.0, 0.0)
	var cool: float = 100.0 - PlotWater.step(cfg, 100.0, 1.0, 5.0, 0.0, 0.0)
	check(absf(hot - 16.0) < 0.5 and absf(cool - 5.0) < 0.5, "a hot day takes about 16 percent, a cool one 5 (%.1f, %.1f)" % [hot, cool])
	check(100.0 - PlotWater.step(cfg, 100.0, 1.0, 0.0, 0.0, 0.0) < 0.01, "a freezing day takes nothing")
	check(100.0 - PlotWater.step(cfg, 100.0, 1.0, 25.0, 1.0, 0.0) > hot, "wind dries it faster")
	check(absf((100.0 - PlotWater.step(cfg, 100.0, 1.0, 25.0, 0.0, 0.0, 0.7)) - hot * 0.7) < 0.01, "a framed plot (factor 0.7) loses 0.7 of that")
	check(PlotWater.step(cfg, 40.0, 0.25, 15.0, 0.0, 0.2) > 40.0, "a light rain wets it")
	check(is_equal_approx(PlotWater.pour(cfg, 50.0), 58.0) and PlotWater.pour(cfg, 97.0) == 100.0, "a pour adds 8 percent, up to full")
	check(PlotWater.is_wet(cfg, 25.0) and not PlotWater.is_wet(cfg, 24.9), "25 percent is wet enough")

	# On the server: the bed dries over dry days and its crop's day is not wet once it is low; a garden plot (plot: true) is a bed too.
	var key: String = items._bed_key(items._items[bed]["pos"])
	rain[0] = 0.0
	season[0] = "summer"
	items._plot_water[key] = [30.0, clock[0]]
	var wet_before: int = int(items._crops[key]["wet"])
	days(1)
	check(items.plot_moisture(items._items[bed]["pos"]) < 30.0 and int(items._crops[key]["wet"]) == wet_before, "a dry day dries the bed below wet: the day is not wet (%.1f)" % items.plot_moisture(items._items[bed]["pos"]))
	rain[0] = 0.8
	days(1)
	check(items.plot_moisture(items._items[bed]["pos"]) == 100.0 and int(items._crops[key]["wet"]) == wet_before + 1, "a rainy day fills it and counts")
	rain[0] = 0.0
	items._structures["test_plot"] = {"kit": "test_plot_kit", "item": "tilled_bed", "state": 9907, "plot": true, "moisture_factor": 0.7, "cap_per_chunk": 12}
	items._items[920001] = {"number": items.table.number_of("tilled_bed"), "count": 1, "pos": Vector3(40.5, 10.0, 40.5), "left": 1.0e9, "struct": {"kind": "test_plot", "yaw": 0.0}}
	check(not items._bed_at(920001).is_empty(), "a garden plot takes seeds like a tilled bed")
	days(1)
	items._plot_water[key] = [100.0, clock[0]]
	items._plot_water[items._bed_key(Vector3(40.5, 10.0, 40.5))] = [100.0, clock[0]]
	days(1)
	var bed_loss: float = 100.0 - items.plot_moisture(items._items[bed]["pos"])
	var plot_loss: float = 100.0 - items.plot_moisture(Vector3(40.5, 10.0, 40.5))
	check(bed_loss > 0.0 and absf(plot_loss - bed_loss * 0.7) < 0.01, "the framed plot loses 0.7 of the bed's water (%.1f, %.1f)" % [plot_loss, bed_loss])
	items._items.erase(920001)
	items._structures.erase("test_plot")


# The player's route, as the client sends it (inventory_view.gd _bed_interaction): sow by bed id and seed slot, water, harvest. Leaves the bed empty.
func _route_checks(bed: int, crops: Dictionary) -> void:
	var inv = items.inventory_of(1)
	var key: String = items._bed_key(items._items[bed]["pos"])
	items._crops.erase(key)
	rain[0] = 0.0
	season[0] = "spring"
	check(row_extra(bed).get("crop", "") == "", "an empty bed's world row carries no crop")

	# Refusals first: a seed is kept, the bed stays empty, and the player is told why.
	var sickle_slot: int = slot_of("bronze_sickle")
	notes.clear()
	act(Net.ACT_SOW, bed, sickle_slot)
	check(not items._crops.has(key) and count("bronze_sickle") == 1 and notes.has("That cannot be sown."), "a wrong seed (a sickle) is refused: nothing sown, nothing used, the player told")
	act(Net.ACT_SOW, bed, 99)
	check(not items._crops.has(key), "a slot that does not exist sows nothing")
	var moisture_before: float = items.plot_moisture(items._items[bed]["pos"])
	act(Net.ACT_WATER_BED, bed)
	check(not items._crops.has(key) and items.plot_moisture(items._items[bed]["pos"]) == moisture_before, "watering an empty bed does nothing")
	notes.clear()
	act(Net.ACT_HARVEST, bed)
	check(not items._crops.has(key) and notes.has("Nothing is growing there to harvest."), "harvesting an empty bed does nothing and says so")
	items.report_position(1, Vector3(40.0, 10.0, 40.0))
	notes.clear()
	act(Net.ACT_HARVEST, bed)
	act(Net.ACT_SOW, bed, sickle_slot)
	check(notes.has("Too far from the bed to harvest it.") and notes.has("Too far from the bed to sow it."), "harvesting or sowing a bed out of reach is refused with a notice (%s)" % str(notes))
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	notes.clear()
	act(Net.ACT_SOW, bed, 99)
	check(not items._crops.has(key) and notes.has("There are no seeds in that slot to sow."), "a stale seed slot sows nothing and says so")

	# A blueprint site of a plot is not a bed yet: it takes no seed.
	items._items[920004] = {"number": items.table.number_of("wooden_garden_plot"), "count": 1, "pos": Vector3(-1.5, 10.0, 1.5), "left": 1.0e9, "struct": {"kind": "wooden_garden_plot", "yaw": 0.0, "site": {}}}
	check(items._bed_at(920004).is_empty() and not items.sow(1, items.inventory_of(1), 920004, sickle_slot) and not items._crops.has(items._bed_key(Vector3(-1.5, 10.0, 1.5))), "a plot's blueprint site is not a bed: nothing is sown on it")
	items._items.erase(920004)

	# Flax, from the wild seed the gather above gave to a harvest.
	if count("flax_seeds") == 0:
		give("flax_seeds", 1)

	var flax_seeds: int = count("flax_seeds")
	var flax_seasons: Array = crops["flax"].get("sow_seasons", [crops["flax"].get("sow_season", "spring")])   # the season comes from the data, as the matrix below does
	var in_season: String = str(flax_seasons[0])
	var off_season: String = str(["spring", "summer", "autumn", "winter"].filter(func(x): return not flax_seasons.has(x))[0])
	season[0] = off_season
	notes.clear()
	act(Net.ACT_SOW, bed, slot_of("flax_seeds"))
	check(not items._crops.has(key) and count("flax_seeds") == flax_seeds and notes.has("Not the season for flax. Hold the seeds you want to sow."), "flax is refused in %s (sow_seasons %s): seed kept, the server's text says why and what to do (%s)" % [off_season, str(flax_seasons), str(notes)])
	season[0] = in_season
	items.report_position(1, Vector3(40.0, 10.0, 40.0))
	act(Net.ACT_SOW, bed, slot_of("flax_seeds"))
	check(not items._crops.has(key) and count("flax_seeds") == flax_seeds, "sowing a bed out of reach is refused")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	act(Net.ACT_SOW, bed, slot_of("flax_seeds"))
	check(items._crops.has(key) and str(items._crops[key]["crop"]) == "flax" and count("flax_seeds") == flax_seeds - 1, "in %s flax is sown by bed id and seed slot and the seed is used" % in_season)
	var extra: Dictionary = row_extra(bed)
	check(extra.get("crop", "") == "flax" and int(extra.get("stage", -1)) == 0, "the bed's world row now says flax, stage 0 (%s)" % str(extra))

	# Water from a real filled bucket in hand, as the client sends it (b = the container's pack slot; crops.json moisture pour_ml, GOALS-REPAIR A-3): a full bucket is pour_pct
	# and empties, the same day's second pour is refused with a notice, and an empty container or an item that is no container is refused. Nothing is taken when refused.
	if slot_of("bucket") < 0:
		give("bucket", 1)

	var bucket: int = slot_of("bucket")
	var pos: Vector3 = items._items[bed]["pos"]
	items._plot_water[key] = [30.0, clock[0]]
	inv.wear[bucket] = 0
	notes.clear()
	act(Net.ACT_WATER_BED, bed, bucket)
	check(notes.has("That holds no water.") and items.plot_moisture(pos) == 30.0, "an empty bucket in hand pours nothing and the player is told")
	act(Net.ACT_WATER_BED, bed, sickle_slot)
	check(items.plot_moisture(pos) == 30.0 and count("bronze_sickle") == 1, "a sickle named as the container pours nothing")
	inv.wear[bucket] = 8000
	notes.clear()
	act(Net.ACT_WATER_BED, bed, bucket)
	check(inv.wear[bucket] == 0 and absf(items.plot_moisture(pos) - 38.0) < 0.01 and int(items._crops[key]["poured"]) == items._game_day(), "a filled bucket in hand waters the bed: the bucket is emptied, the bed gains a bucket's 8 percent (%.1f)" % items.plot_moisture(pos))
	inv.wear[bucket] = 8000
	notes.clear()
	act(Net.ACT_WATER_BED, bed, bucket)
	check(inv.wear[bucket] == 8000 and absf(items.plot_moisture(pos) - 38.0) < 0.01 and notes.has("The bed has had its water today."), "a second bucket the same day is refused, kept full, and the player is told")
	inv.wear[bucket] = 0

	notes.clear()
	var fibre: int = count("plant_fibre")
	act(Net.ACT_HARVEST, bed)
	check(items._crops.has(key) and notes.has("It is not ripe yet.") and count("plant_fibre") == fibre, "a flax seedling is not harvested: the player is told it is not ripe")

	var grow: int = int(crops["flax"]["grow_days"])
	season[0] = "summer"
	rain[0] = 0.5
	days(int(grow * 0.5))
	check(int(row_extra(bed).get("stage", -1)) == 2, "half way through the grow days the row says stage 2")
	days(grow - int(grow * 0.5))
	check(int(row_extra(bed).get("stage", -1)) == 3, "after the grow days with rain on each the row says stage 3, ripe")
	var flax_before: int = count("flax")
	var back_before: int = count("flax_seeds")
	act(Net.ACT_HARVEST, bed)
	check(not items._crops.has(key) and count("flax") - flax_before == int(crops["flax"]["yields"][0][1]) and count("plant_fibre") - fibre == int(crops["flax"]["yields"][1][1]) and count("flax_seeds") - back_before >= 2, "harvest with the sickle gives the full flax and plant fibre and seeds back (flax +%d, fibre +%d)" % [count("flax") - flax_before, count("plant_fibre") - fibre])
	check(row_extra(bed).get("crop", "") == "", "the bed's row loses its crop after the harvest")
	var after: int = count("flax")
	act(Net.ACT_HARVEST, bed)
	check(count("flax") == after and not items._crops.has(key), "a second harvest of the same bed gives nothing")

	# Flax and the four grains in every season: sown exactly in their sow_seasons (data/items/crops.json, GOALS-REPAIR A-4: no season data change).
	var sowable: int = 0

	for crop in ["flax", "wheat", "barley", "oats", "rye"]:
		var def: Dictionary = crops[crop]
		var seasons: Array = def.get("sow_seasons", [def.get("sow_season", "spring")])
		var seed_id: String = str(def["seed"])
		var shown: Array = []

		for s in ["spring", "summer", "autumn", "winter"]:
			season[0] = s
			give(seed_id, 1)
			var seeds: int = count(seed_id)
			act(Net.ACT_SOW, bed, slot_of(seed_id))
			var sown: bool = items._crops.has(key)
			var right: bool = sown == seasons.has(s) and (count(seed_id) == seeds - 1 if sown else count(seed_id) == seeds)
			items._crops.erase(key)
			inv.remove(items.table.number_of(seed_id), count(seed_id))
			sowable += 1 if sown else 0

			if not right:
				check(false, "%s sown in %s: expected %s" % [crop, s, str(seasons.has(s))])
			elif sown:
				shown.append(s)

		check(not shown.is_empty() and shown.size() == seasons.size(), "%s sows in exactly its seasons %s (sown in %s)" % [crop, str(seasons), str(shown)])

	check(sowable >= 5, "every one of flax and the four grains can be sown in some season (%d season slots)" % sowable)
	season[0] = "spring"


# A garden plot taken down takes its crop with it: a plot built on the same spot later starts empty (the crop record is keyed by the spot, not by the plot).
func _plot_takedown_checks() -> void:
	var spot: Vector3 = Vector3(-1.5, 10.0, -1.5)
	var kind: String = "wooden_garden_plot"
	items._items[920002] = {"number": items.table.number_of(kind), "count": 1, "pos": spot, "left": 1.0e9, "struct": {"kind": kind, "yaw": 0.0}}
	var key: String = items._bed_key(spot)
	season[0] = "spring"
	give("barley_seeds", 1)
	act(Net.ACT_SOW, 920002, slot_of("barley_seeds"))
	check(items._crops.has(key) and items.crop_row_extra(items._items[920002]).get("crop", "") == "barley", "barley is sown in a garden plot")
	# A garden plot is a hammer blueprint piece (blueprints.json), so taking it down gives its materials back, not a kit.
	var cost: Array = items._blueprints[int(items._blueprint_of_kit["wooden_garden_plot_kit"])]["cost"]
	var before: Dictionary = {}

	for need in cost:
		before[str(need[0])] = count(str(need[0]))

	act(Net.ACT_PICKUP, 920002)
	var refunded: bool = true

	for need in cost:
		refunded = refunded and count(str(need[0])) - int(before[str(need[0])]) == int(need[1])

	check(not items._items.has(920002) and refunded, "the plot is taken down and its blueprint materials come back (%s)" % str(cost))
	check(not items._crops.has(key), "its crop record went with it")
	items._items[920003] = {"number": items.table.number_of(kind), "count": 1, "pos": spot, "left": 1.0e9, "struct": {"kind": kind, "yaw": 0.0}}
	check(not items._bed_at(920003).is_empty() and items.crop_row_extra(items._items[920003]).is_empty(), "a new plot built on the same spot is empty")
	act(Net.ACT_HARVEST, 920003)
	check(not items._crops.has(key), "and has nothing to harvest")
	items._items.erase(920003)


# The hoe only tills (Dave 14 Nov 2026: "There doesn't actually need to be garden plots. It should just till the soil so you can put seeds in the ground."): with a hoe
# and no hammer on the hand bar a garden plot blueprint is refused like any other blueprint; the hoe tills the ground and the seed goes into the bed.
func _hoe_plot_checks() -> void:
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	var hoe_slot: int = HeldTool.slot_of(items, "hoe")
	check(hoe_slot >= 0 and hoe_slot < 10 and HeldTool.slot_of(items, "hammer") < 0, "the farmer has a hoe on the hand bar and no hammer")
	var plot_bp: int = int(items._blueprint_of_kit["wooden_garden_plot_kit"])
	notes.clear()
	var count_before: int = items._items.size()
	items.action(1, Net.ACT_PLACE_BLUEPRINT, plot_bp, 0, 0, Vector3(4.0, 10.0, 4.0))
	check(items._items.size() == count_before and notes.any(func(t): return str(t).contains("need a hammer")), "a hoe alone lays out no garden plot: it needs a hammer (%s)" % str(notes))


# Herb and plant seeds (Dave 14 Nov 2026: "All herbs and plants should produce seeds"; HOE_GARDENING_DESIGN.md): a wild herb picked late in its season gives its
# seed, not earlier; the seed grows in a planter (plot: true) and a ripe one gives its harvest and seeds back; every real plant has a seed and a garden row.
func _herb_seed_checks(crops: Dictionary) -> void:
	items.report_position(1, Vector3(500.0, 70.0, 500.0))
	season[0] = "spring"
	items._last_gather.clear()
	items.gather(1, "wild_thyme", "plant", "0,0,900", 900, Vector3(501.0, 70.0, 500.0))
	check(count("wild_thyme_seed") == 0 and count("thyme") > 0, "wild thyme picked in spring gives thyme but no seed (%d)" % count("wild_thyme_seed"))
	season[0] = "autumn"
	items._last_gather.clear()
	items.gather(1, "wild_thyme", "plant", "0,0,901", 901, Vector3(501.0, 70.0, 500.0))
	check(count("wild_thyme_seed") >= 1 and count("wild_thyme_seed") <= 2, "late in its season it has gone to seed: 1 to 2 Wild thyme seeds (%d)" % count("wild_thyme_seed"))
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	var spot: Vector3 = Vector3(2.5, 10.0, 2.5)
	items._items[920004] = {"number": items.table.number_of("stone_planter"), "count": 1, "pos": spot, "left": 1.0e9, "struct": {"kind": "stone_planter", "yaw": 0.0}}
	var key: String = items._bed_key(spot)
	season[0] = "summer"
	act(Net.ACT_SOW, 920004, slot_of("wild_thyme_seed"))
	check(items._crops.has(key) and str(items._crops[key]["crop"]) == "wild_thyme", "a Wild thyme seed is sown in a Stone - Planter")
	rain[0] = 0.8
	days(int(crops["wild_thyme"]["grow_days"]) + 1)
	rain[0] = 0.0
	var thyme: int = count("thyme")
	var seeds: int = count("wild_thyme_seed")
	act(Net.ACT_HARVEST, 920004)
	check(not items._crops.has(key) and count("thyme") - thyme == int(crops["wild_thyme"]["yields"][0][1]) and count("wild_thyme_seed") - seeds >= 1, "the ripe garden thyme gives its thyme and seeds back (+%d thyme, +%d seeds)" % [count("thyme") - thyme, count("wild_thyme_seed") - seeds])
	items._items.erase(920004)
	items._items[920005] = {"number": items.table.number_of("flower_pot"), "count": 1, "pos": spot, "left": 1.0e9, "struct": {"kind": "flower_pot", "yaw": 0.0}}
	check(not items._bed_at(920005).is_empty(), "a Flower pot takes seeds too")
	items._items.erase(920005)
	var drops: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/drops.json"))
	var fungi: Array = ["mushrooms", "chanterelle", "porcini", "morel", "fly_agaric", "puffball", "tinder_fungus", "rimecap", "lumencap", "cinderfoot", "mirrorcap"]
	var missing: Array = []

	for plant in items._flora_by_name:
		var entry: Dictionary = items._flora_by_name[plant]

		if str(entry.get("kind", "")) != "plant" or bool(entry.get("future", false)) or str(plant).ends_with("_log") or plant == "old_stump" or fungi.has(plant):
			continue

		var wild: Dictionary = (drops.get("seed_drops", {}) as Dictionary).get(plant, {})
		var sown: bool = false

		for row in wild.get("rows", []):
			for crop_id in crops:
				sown = sown or str(crops[crop_id].get("seed", "")) == str(row[0])

		if not sown:
			missing.append(plant)

	check(missing.is_empty(), "every real plant gives a wild seed that sows a garden crop (%s)" % str(missing))
	var dune: Dictionary = items._flora_by_name.get("dune_grass", {})
	var no_tool: Callable = func(_t: String) -> bool: return false
	var any_item: Callable = func(_i: String) -> bool: return true
	check(bool(Gather.check(dune, "plant", drops, str((drops["seed_drops"]["dune_grass"]["seasons"] as Array)[0]), no_tool, any_item)["ok"]) and not bool(Gather.check(dune, "plant", drops, "winter", no_tool, any_item)["ok"]), "dune grass, which bears nothing else, can be picked for its seed when it has gone to seed, not in winter")
	# One bed or planter to a metre cell (one crop record each): a second pot in the same cell is refused.
	items._items[920006] = {"number": items.table.number_of("flower_pot"), "count": 1, "pos": Vector3(2.3, 10.0, 2.3), "left": 1.0e9, "struct": {"kind": "flower_pot", "yaw": 0.0}}
	notes.clear()
	var before: int = items._items.size()
	items.place_piece(1, "flower_pot_kit", Vector3(2.7, 10.0, 2.7))   # free build, as from the hammer (the Flower pot kit itself is retired)
	check(items._items.size() == before and notes.has("A bed or planter is already in that spot."), "a second flower pot in the same metre cell is refused (%s)" % str(notes))
	items._items.erase(920006)


# Gardening plots (Dave 14 Nov 2026: "Gardening plots can come in three sizes small medium and large ... A small takes two planks and eight nails a medium
# takes three planks, and eight nails and a large takes four planks, and eight nails"; no tiers): the three blueprints and footprints, and a saved Thatch,
# Stone or Brick plot loads as the Medium one.
func _plot_size_checks(dir: String) -> void:
	for row in [["small_garden_plot", 1.0, 2], ["wooden_garden_plot", 2.0, 3], ["large_garden_plot", 3.0, 4]]:
		var bp: Dictionary = items._blueprints.get(int(items._blueprint_of_kit.get(str(items._structures.get(str(row[0]), {}).get("kit", "")), 0)), {})
		var def: Dictionary = items._structures.get(str(row[0]), {})
		var cost: Array = []
		for c in bp.get("cost", []):
			cost.append("%s %d" % [str(c[0]), int(c[1])])
		check(cost == ["lumber %d" % int(row[2]), "nails 8"] and is_equal_approx(float(def.get("footprint_x", 0.0)), float(row[1])) and bool(def.get("plot", false)), "%s: %d m square, %d planks and 8 nails (%s)" % [str(bp.get("name", row[0])), int(row[1]), int(row[2]), str(bp.get("cost", []))])

	for old in ["thatch_garden_plot", "stone_garden_plot", "brick_garden_plot"]:
		check(not items._structures.has(old), "the %s tier is gone" % old)

	var spot: Vector3 = Vector3(60.0, 10.0, 60.0)
	items._items[920007] = {"number": items.table.number_of("stone_garden_plot"), "count": 1, "pos": spot, "left": 1.0e9, "struct": {"kind": "stone_garden_plot", "yaw": 0.0}}   # what an old save holds
	items._dirty = true
	items.save()
	items._finish_writer()
	var again = make(dir)
	var found: Dictionary = {}

	for id in again._items:
		if again._items[id].has("struct") and (again._items[id]["pos"] as Vector3).distance_to(spot) < 0.01:
			found = again._items[id]

	check(not found.is_empty() and str(found["struct"]["kind"]) == "wooden_garden_plot" and int(found["number"]) == again.table.number_of("wooden_garden_plot"), "a saved Stone - Garden plot loads as the Medium gardening plot (%s)" % str(found.get("struct", {})))
	items._items.erase(920007)


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
	check(crops.size() >= 12 and crops["wheat"]["grow_days"] > 20, "crops.json lists the crops (wheat grows %d days)" % int(crops["wheat"]["grow_days"]))

	# Wild seeds (step 1): tall grass gives wheat or barley seeds in summer and autumn, none in winter; wild carrot gives carrot seeds; flax flax seeds.
	items.gather_pace_ms = 0
	items.report_position(1, Vector3(500.0, 70.0, 500.0))
	season[0] = "autumn"
	var got: int = 0

	for n in range(12):
		items._last_gather.clear()
		items.gather(1, "tall_grass", "plant", "0,0,%d" % (500 + n), 500 + n, Vector3(501.0, 70.0, 500.0))

	got = count("wheat_seeds") + count("barley_seeds")
	check(got >= 6, "gathering tall grass in autumn gives wheat and barley seeds (%d from 12 plants)" % got)
	season[0] = "winter"
	var before_winter: int = got

	for n in range(12):
		items._last_gather.clear()
		items.gather(1, "tall_grass", "plant", "0,0,%d" % (600 + n), 600 + n, Vector3(501.0, 70.0, 500.0))

	check(count("wheat_seeds") + count("barley_seeds") == before_winter, "and none in winter")
	season[0] = "summer"
	items._last_gather.clear()
	items.gather(1, "wild_carrot", "plant", "0,0,700", 700, Vector3(501.0, 70.0, 500.0))
	items._last_gather.clear()
	items.gather(1, "flax", "plant", "0,0,701", 701, Vector3(501.0, 70.0, 500.0))
	check(count("carrot_seeds") >= 1 and count("flax_seeds") >= 1, "wild carrot gives carrot seeds and flax gives flax seeds in summer (%d, %d)" % [count("carrot_seeds"), count("flax_seeds")])
	items.inventory_of(1).remove(items.table.number_of("wheat_seeds"), count("wheat_seeds"))
	items.inventory_of(1).remove(items.table.number_of("barley_seeds"), count("barley_seeds"))
	# Fixed drop rows obey the plant's season too (Sal's nettles: spring and summer only).
	season[0] = "winter"
	items._last_gather.clear()
	items.gather(1, "nettle", "plant", "0,0,800", 800, Vector3(501.0, 70.0, 500.0))
	check(count("nettles") == 0, "nettles do not come in winter (%d)" % count("nettles"))
	season[0] = "spring"
	items._last_gather.clear()
	items.gather(1, "nettle", "plant", "0,0,801", 801, Vector3(501.0, 70.0, 500.0))
	check(count("nettles") >= 2, "and do in spring (%d)" % count("nettles"))
	season[0] = "spring"
	items.report_position(1, Vector3(0.0, 10.0, 0.0))

	# Till.
	check(items.till(1, items.inventory_of(1), Vector3(1.0, 10.0, 1.0), HeldTool.slot_of(items, "hoe")) == 0, "no hoe: nothing is tilled")
	give("wooden_hoe" if items.table.has_id("wooden_hoe") else "stone_hoe", 1)
	var made: int = items.till(1, items.inventory_of(1), Vector3(1.2, 10.0, 1.2), HeldTool.slot_of(items, "hoe"))
	check(made != 0 and bed_id() != 0, "with a hoe a bed is tilled")
	items._last_dig.clear()
	check(items.till(1, items.inventory_of(1), Vector3(1.3, 10.0, 1.3), HeldTool.slot_of(items, "hoe")) == 0 and items._items.keys().filter(func(k): return items._items[k].has("struct") and str(items._items[k]["struct"]["kind"]) == "tilled_bed").size() == 1, "the same metre is not tilled twice")

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
	var compost_no: int = items.table.number_of("compost")
	items.inventory_of(1).add(compost_no, 1)
	check(items.compost_bed(1, items.inventory_of(1), bed) and bool(items._crops[key]["compost"]) and items.inventory_of(1).count_of(compost_no) == 0, "compost on the bed is taken and marks the crop")
	check(not items.compost_bed(1, items.inventory_of(1), bed), "a composted crop takes no more")
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
	give("bronze_sickle", 1)   # the Stone - Sickle is retired (master s3.1, Mission 001 phase 2c)
	season[0] = "spring"
	rain[0] = 0.0
	check(items.sow(1, items.inventory_of(1), bed, slot_of("wheat_seeds")), "the bed is sown again")
	season[0] = "winter"
	days(1)
	check(not items._crops.has(key), "a seedling does not survive winter frost")
	give("turnip_seeds", 2)
	check(not items.sow(1, items.inventory_of(1), bed, slot_of("turnip_seeds")), "turnip cannot be sown in winter (its seasons are spring and autumn)")
	season[0] = "autumn"
	check(items.sow(1, items.inventory_of(1), bed, slot_of("turnip_seeds")), "turnip can be sown in autumn (sow_seasons list)")
	season[0] = "winter"
	days(2)
	check(items._crops.has(key) and float(items._crops[key]["age"]) >= 2.0, "and grows through it")

	# Wheat with the sickle: put a ripe crop in directly (growth was tested above) and harvest it with the tool.
	items._crops.erase(key)
	items._crops[key] = {"crop": "wheat", "sown": 0, "age": float(grow), "wet": grow, "day": items._game_day(), "compost": false, "rained": -1, "poured": -1}
	var before: int = count("wheat")
	check(items.harvest(1, items.inventory_of(1), bed) and count("wheat") - before == yield_wheat, "with a sickle the full yield (%d)" % (count("wheat") - before))

	# Water poured counts: sow, pour, next day wet.
	season[0] = "spring"
	give("bucket", 1)
	items.inventory_of(1).wear[slot_of("bucket")] = 8000   # a filled bucket (the fill and the pour scaling: test_liquid_ingredient)
	give("barley_seeds", 1)
	items.sow(1, items.inventory_of(1), bed, slot_of("barley_seeds"))
	check(items.water_bed(1, items.inventory_of(1), bed) and not items.water_bed(1, items.inventory_of(1), bed), "one bucket of water pours on the bed per day")
	days(1)
	check(int(items._crops[key]["wet"]) == 1, "water poured makes the next game day wet")

	_moisture_checks(bed)
	_route_checks(bed, crops)
	_plot_takedown_checks()
	_hoe_plot_checks()
	_herb_seed_checks(crops)
	_plot_size_checks(dir)

	# Save and restart: a barley crop grown to a stage keeps its crop, its age and its stage (the world save, not a hand-written file).
	season[0] = "spring"
	give("barley_seeds", 1)
	act(Net.ACT_SOW, bed, slot_of("barley_seeds"))
	check(items._crops.has(key) and str(items._crops[key]["crop"]) == "barley", "barley is sown again for the save")
	season[0] = "summer"
	rain[0] = 0.5
	days(int(int(crops["barley"]["grow_days"]) * 0.5) + 1)
	var stage_saved: int = items.crop_stage(items._crops[key])
	check(stage_saved >= 2, "the barley has grown (stage %d)" % stage_saved)
	items.save()
	items._finish_writer()
	var again = make(dir)
	check(again._crops.has(key) and str(again._crops[key]["crop"]) == "barley", "the crop is saved and still growing after a restart")
	check(again._crops.has(key) and again.crop_stage(again._crops[key]) == stage_saved and float(again._crops[key]["age"]) == float(items._crops[key]["age"]), "and its age and stage (%d) are the same after the restart" % stage_saved)
	print("farming: %d failures" % failures)
	quit(1 if failures > 0 else 0)
