extends SceneTree

# Farming rules on the server (FARMING_SPEC.md steps 2 to 5; Tyler 31 Oct 2026). A hoe tills a bed; a seed is sown only in its season and is used up; a game day that
# ends with the bed's moisture at 25 percent or more (rain fills it, a pour adds to it, the weather dries it) is a wet day; a crop is ripe only when old enough AND wet enough (a dry bed stalls at stage 2); winter pauses growth and kills a seedling (turnip
# grows on); compost speeds growth by 20 percent; harvest gives the yields and seeds back, half without the sickle for grain; an unripe crop is refused; crops are saved.
# GOALS-REPAIR WP-R1B adds the player's route through the requests the client sends (sowing is the hoe's Plant grid, ACT_PLANT_GRID, since Dave's play test of 19 Nov 2026: E on a
# bed no longer sows; ACT_WATER_BED, ACT_HARVEST): a real flax
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


# Sowing is the hoe's Plant grid only (Dave play test 19 Nov 2026: seeds went in without the hoe in hand, so E on a bed no longer sows): one click of a 1 by 1 grid,
# the hoe in hand, on the bed's square metre at `at` (Vector3.ZERO: its first empty one). `hoe`: the held pack slot (-2: the hotbar's hoe). True when a seed went in.
func sow(bed: int, seed_id: String, at: Vector3 = Vector3.ZERO, hoe: int = -2) -> bool:
	var it: Dictionary = items._items.get(bed, {})

	if it.is_empty():
		return false

	var spot: Vector3 = at

	if spot == Vector3.ZERO:
		var cells: Array = items._bed_cells(it)
		spot = cells[0]

		for cell in cells:
			if not items._crops.has(items._bed_key(cell)):
				spot = cell
				break

	var held: int = HeldTool.slot_of(items, "hoe") if hoe == -2 else hoe

	if held >= 0:
		items.inventory_of(1).wear[held] = 0   # many sows in one test: the hoe is not under test here

	items._last_dig.clear()
	return items.plant_grid(1, items.inventory_of(1), held, items.table.number_of(seed_id), 101, spot) > 0


func act(kind: int, a: int, b: int = 0) -> void:
	items.action(1, kind, a, b, 0, Vector3.ZERO)


func days(n: int) -> void:
	clock[0] += float(n) * 86400.0
	items._crops_tick()


# Plot moisture (buildables plan B5; Sonny's water rules section 8): heavy rain fills a bed, the dry weather takes its evaporation (more when hot or
# windy, little near freezing, less from a framed plot with moisture_factor), a pour adds its litres over the soil store, a crop's day is wet at 25 percent
# or more and a dry day grows it half a day (garden moisture GM-3, Dave 19 Nov 2026); the look-at words are wet, damp and dry.
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
	check(is_equal_approx(PlotWater.litres_per_pct(cfg, 1.0), 0.25) and is_equal_approx(PlotWater.litres_per_pct(cfg, 4.0), 1.0), "a 1 m bed's percent is 0.25 L, a 2 x 2 plot's 1 L")
	check(is_equal_approx(PlotWater.pour(50.0, 8.0, 0.25), 82.0) and is_equal_approx(PlotWater.pour(50.0, 8.0, 1.0), 58.0) and PlotWater.pour(97.0, 8.0, 0.25) == 100.0, "a bucket adds 32 percent to a 1 m bed, 8 to a 2 x 2 plot, up to full")
	check(PlotWater.day_growth(cfg, true) == 1.0 and is_equal_approx(PlotWater.day_growth(cfg, false), 0.5), "a wet day grows a whole day, a dry one half")
	check(PlotWater.word(cfg, 70.0) == "wet" and PlotWater.word(cfg, 69.0) == "damp" and PlotWater.word(cfg, 25.0) == "damp" and PlotWater.word(cfg, 24.0) == "dry", "70 percent and up is wet, 25 damp, below that dry")
	check(PlotWater.is_wet(cfg, 25.0) and not PlotWater.is_wet(cfg, 24.9), "25 percent is wet enough")

	# On the server: the bed dries over dry days and its crop's day is not wet once it is low; a garden plot (plot: true) is a bed too.
	var key: String = items._bed_key(items._items[bed]["pos"])
	rain[0] = 0.0
	season[0] = "summer"
	items._plot_water[key] = [30.0, clock[0]]
	var wet_before: int = int(items._crops[key]["wet"])
	var age_before: float = float(items._crops[key]["age"])
	days(1)
	check(items.plot_moisture(items._items[bed]["pos"]) < 25.0 and int(items._crops[key]["wet"]) == wet_before, "a dry day dries the bed below wet: the day is not wet (%.1f)" % items.plot_moisture(items._items[bed]["pos"]))
	check(absf(float(items._crops[key]["age"]) - age_before - 0.5) < 0.01, "and the crop grew half a day (%.2f)" % (float(items._crops[key]["age"]) - age_before))
	var extra: Dictionary = items.crop_row_extra(items._items[bed])
	var shown: float = items.plot_moisture(items._items[bed]["pos"]) - float(extra.get("moist", -100))
	check(int(extra.get("moist", -1)) % 5 == 0 and shown >= 0.0 and shown < 5.0, "the bed's row carries its moisture rounded down to 5 percent steps (%s)" % str(extra))
	rain[0] = 0.8
	days(1)
	check(items.plot_moisture(items._items[bed]["pos"]) == 100.0 and int(items._crops[key]["wet"]) == wet_before + 1, "a rainy day fills it and counts")
	check(int(items.crop_row_extra(items._items[bed]).get("moist", -1)) == 100, "and the row says 100")
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


# The player's route, as the client sends it (inventory_view.gd _bed_interaction): sow with the hoe's Plant grid (sow above), water, harvest. Leaves the bed empty.
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
	sow(bed, "bronze_sickle")
	check(not items._crops.has(key) and count("bronze_sickle") == 1 and notes.has("That cannot be planted."), "a wrong seed (a sickle) is refused: nothing sown, nothing used, the player told (%s)" % str(notes))
	give("flax_seeds", 1)
	var seeds_held: int = count("flax_seeds")
	notes.clear()
	check(not sow(bed, "flax_seeds", Vector3.ZERO, -1) and not items._crops.has(key) and count("flax_seeds") == seeds_held, "seeds with no hoe in hand sow nothing (Dave play test 19 Nov 2026)")
	check(not sow(bed, "flax_seeds", Vector3.ZERO, sickle_slot) and not items._crops.has(key) and count("flax_seeds") == seeds_held, "seeds with a sickle in hand sow nothing: only the hoe plants")
	act(51, bed, slot_of("flax_seeds"))
	check(not items._crops.has(key) and count("flax_seeds") == seeds_held, "the old E sow request (kind 51) sows nothing")
	var moisture_before: float = items.plot_moisture(items._items[bed]["pos"])
	act(Net.ACT_WATER_BED, bed)
	check(not items._crops.has(key) and items.plot_moisture(items._items[bed]["pos"]) == moisture_before, "watering an empty bed does nothing")
	notes.clear()
	act(Net.ACT_HARVEST, bed)
	check(not items._crops.has(key) and notes.has("Nothing is growing there to harvest."), "harvesting an empty bed does nothing and says so")
	items.report_position(1, Vector3(40.0, 10.0, 40.0))
	notes.clear()
	act(Net.ACT_HARVEST, bed)
	check(notes.has("Too far from the bed to harvest it.") and not sow(bed, "flax_seeds") and not items._crops.has(key), "harvesting or sowing a bed out of reach is refused (%s)" % str(notes))
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items.inventory_of(1).remove(items.table.number_of("flax_seeds"), count("flax_seeds"))
	notes.clear()
	check(not sow(bed, "flax_seeds") and not items._crops.has(key) and notes.has("You have none to plant."), "seeds the farmer does not have sow nothing and the player is told (%s)" % str(notes))

	# A blueprint site of a plot is not a bed yet: it takes no seed.
	items._items[920004] = {"number": items.table.number_of("wooden_garden_plot"), "count": 1, "pos": Vector3(-1.5, 10.0, 1.5), "left": 1.0e9, "struct": {"kind": "wooden_garden_plot", "yaw": 0.0, "site": {}}}
	check(items._bed_at(920004).is_empty() and not sow(920004, "flax_seeds") and not items._crops.has(items._bed_key(Vector3(-1.5, 10.0, 1.5))), "a plot's blueprint site is not a bed: nothing is sown on it")
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
	sow(bed, "flax_seeds")
	check(not items._crops.has(key) and count("flax_seeds") == flax_seeds and notes.has("Not the season for flax."), "flax is refused in %s (sow_seasons %s): seed kept, the server's text says why and what to do (%s)" % [off_season, str(flax_seasons), str(notes)])
	season[0] = in_season
	items.report_position(1, Vector3(40.0, 10.0, 40.0))
	sow(bed, "flax_seeds")
	check(not items._crops.has(key) and count("flax_seeds") == flax_seeds, "sowing a bed out of reach is refused")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	sow(bed, "flax_seeds")
	check(items._crops.has(key) and str(items._crops[key]["crop"]) == "flax" and count("flax_seeds") == flax_seeds - 1, "in %s flax is sown with the hoe's Plant grid and the seed is used" % in_season)
	var extra: Dictionary = row_extra(bed)
	check(extra.get("crop", "") == "flax" and int(extra.get("stage", -1)) == 0, "the bed's world row now says flax, stage 0 (%s)" % str(extra))

	# Water from a real filled bucket in hand, as the client sends it (b = the container's pack slot; crops.json moisture pour_ml, GOALS-REPAIR A-3, GM-2): a full
	# bucket adds 32 percent to a 1 m bed and empties, a second goes in the same day up to what the soil has room for, soil wet through is refused with a notice,
	# and an empty container or an item that is no container is refused. Nothing is taken when refused.
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
	check(inv.wear[bucket] == 0 and absf(items.plot_moisture(pos) - 62.0) < 0.01, "a filled bucket in hand waters the bed: the bucket is emptied, the 1 m bed gains 32 percent (%.1f)" % items.plot_moisture(pos))
	inv.wear[bucket] = 8000
	act(Net.ACT_WATER_BED, bed, bucket)
	check(inv.wear[bucket] == 0 and absf(items.plot_moisture(pos) - 94.0) < 0.01, "a second bucket the same day goes in too (%.1f)" % items.plot_moisture(pos))
	inv.wear[bucket] = 8000
	act(Net.ACT_WATER_BED, bed, bucket)
	check(inv.wear[bucket] == 6500 and absf(items.plot_moisture(pos) - 100.0) < 0.01, "a third pours only the 1.5 L the soil has room for (%d mL left)" % inv.wear[bucket])
	notes.clear()
	act(Net.ACT_WATER_BED, bed, bucket)
	check(inv.wear[bucket] == 6500 and notes.has("The soil is wet through already."), "soil wet through takes no more, the bucket is kept and the player is told")
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
			sow(bed, seed_id)
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
	var key: String = items._bed_key(items._bed_cells(items._items[920002])[0])   # a Medium plot's first square metre (it holds 4 crops)
	season[0] = "spring"
	give("barley_seeds", 1)
	sow(920002, "barley_seeds")
	check(items._crops.has(key) and str(items.crop_row_extra(items._items[920002])["cells"][0][0]) == "barley", "barley is sown in a garden plot's first square metre")
	check(str(items.crop_row_extra(items._items[920002]).get("crop", "")) == "barley", "a part-planted plot's row names its crop, so E waters it (an empty square metre is the hoe's to sow)")
	# A garden plot is a hammer blueprint piece (blueprints.json), so taking it down gives its materials back, not a kit.
	# A group cost (Nails) comes back as its lowest member (Bronze nails, ItemTable.spend_order), so the count is of the item the refund gives.
	var cost: Array = items._blueprints[int(items._blueprint_of_kit["wooden_garden_plot_kit"])]["cost"]
	var before: Dictionary = {}
	var back: Callable = func(id): return items.inventory_of(1).count_of(items._refund_number(items.table.number_of(id)))

	for need in cost:
		before[str(need[0])] = back.call(str(need[0]))

	act(Net.ACT_PICKUP, 920002)
	var refunded: bool = true

	for need in cost:
		refunded = refunded and back.call(str(need[0])) - int(before[str(need[0])]) == int(need[1])

	check(not items._items.has(920002) and refunded, "the plot is taken down and its blueprint materials come back (%s)" % str(cost))
	check(not items._crops.has(key), "its crop record went with it")
	items._items[920003] = {"number": items.table.number_of(kind), "count": 1, "pos": spot, "left": 1.0e9, "struct": {"kind": kind, "yaw": 0.0}}
	check(not items._bed_at(920003).is_empty() and not items.crop_row_extra(items._items[920003]).has("crop"), "a new plot built on the same spot is empty")
	act(Net.ACT_HARVEST, 920003)
	check(not items._crops.has(key), "and has nothing to harvest")
	items._items.erase(920003)
	_plot_cell_checks()


# A plot holds one crop a square metre (Dave 14 Nov 2026: Medium 4, Large 9). The Plant grid sows the one it aims at; the row
# lists each; harvest takes the first ripe one; the plot's moisture is shared; a 1 m bed and a planter stay one crop on their own key.
func _plot_cell_checks() -> void:
	var spot: Vector3 = Vector3(-1.0, 10.0, -1.0)
	items._items[920030] = {"number": items.table.number_of("wooden_garden_plot"), "count": 1, "pos": spot, "left": 1.0e9, "struct": {"kind": "wooden_garden_plot", "yaw": 0.0}}
	items._items[920031] = {"number": items.table.number_of("large_garden_plot"), "count": 1, "pos": Vector3(3.0, 10.0, -3.0), "left": 1.0e9, "struct": {"kind": "large_garden_plot", "yaw": 90.0}}
	var cells: Array = items._bed_cells(items._items[920030])
	check(cells.size() == 4 and items._bed_cells(items._items[920031]).size() == 9 and items._bed_cells({"pos": spot, "struct": {"kind": "stone_planter"}}).size() == 1, "a Medium plot has 4 square metres, a Large 9, a planter 1")
	check(cells.any(func(c): return c.is_equal_approx(Vector3(-1.5, 10.0, -1.5))) and cells.any(func(c): return c.is_equal_approx(Vector3(-0.5, 10.0, -0.5))), "the Medium plot's square metres are its four quarters (%s)" % str(cells))
	season[0] = "spring"
	give("barley_seeds", 5)

	for n in 4:
		sow(920030, "barley_seeds")

	var keys: Array = cells.map(func(c): return items._bed_key(c))
	check(keys.all(func(k): return items._crops.has(k)) and count("barley_seeds") >= 1, "four sows fill the four square metres")
	notes.clear()
	sow(920030, "barley_seeds", cells[1])
	check(notes.has("Something is growing there already."), "a fifth is refused: the plot is full (%s)" % str(notes))
	var extra: Dictionary = items.crop_row_extra(items._items[920030])
	check((extra.get("cells", []) as Array).size() == 4 and str(extra.get("crop", "")) == "barley", "the plot's row lists its four crops (%s)" % str(extra))
	items._crops[keys[2]]["age"] = 200.0
	items._crops[keys[2]]["wet"] = 200
	extra = items.crop_row_extra(items._items[920030])
	check(int(extra["stage"]) == 3, "a ripe square metre is what E names next")
	act(Net.ACT_HARVEST, 920030)
	check(not items._crops.has(keys[2]) and items._crops.has(keys[0]) and items._crops.has(keys[1]) and items._crops.has(keys[3]), "harvest takes the ripe one and leaves the rest")
	sow(920030, "barley_seeds", Vector3(cells[2].x + 0.2, 10.0, cells[2].z - 0.1))
	check(items._crops.has(keys[2]), "the Plant grid sows the square metre it aims at")
	check(str(items._crops[keys[0]].get("plot", "")) == items._bed_key(spot), "a square metre's crop takes the plot's moisture")

	# The water is the whole plot's: a bucket on the 2 x 2 plot adds 8 percent to its one moisture, and a second the same day adds 8 more.
	give("bucket", 1)
	items._plot_water[items._bed_key(spot)] = [30.0, clock[0]]
	items.inventory_of(1).wear[slot_of("bucket")] = 8000
	check(items.water_bed(1, items.inventory_of(1), 920030) and absf(items.plot_moisture(spot) - 38.0) < 0.01, "a bucket waters the plot: 8 percent on 2 x 2 m (%.1f)" % items.plot_moisture(spot))
	items.inventory_of(1).wear[slot_of("bucket")] = 8000
	items._crops.erase(keys[0])
	check(items.water_bed(1, items.inventory_of(1), 920030) and absf(items.plot_moisture(spot) - 46.0) < 0.01, "a second bucket the same day adds 8 more, whichever crop went (%.1f)" % items.plot_moisture(spot))

	# No two beds share a square metre: a Large plot whose square metre lies on the Medium one's clashes, one a metre clear does not; a bed is not tilled on a plot.
	check(items._beds_clash(items._bed_cells({"pos": Vector3(1.0, 10.0, -1.0), "struct": {"kind": "large_garden_plot", "yaw": 0.0}}), items._items[920030]), "a Large plot over the Medium one's edge square metres is refused")
	check(not items._beds_clash(items._bed_cells({"pos": Vector3(2.5, 10.0, -1.0), "struct": {"kind": "large_garden_plot", "yaw": 0.0}}), items._items[920030]), "a Large plot beside it is not")
	items._last_dig.clear()
	check(items.till(1, items.inventory_of(1), Vector3(-0.4, 10.0, -1.4), HeldTool.slot_of(items, "hoe"), 15) == 0, "the hoe does not till a bed on a plot's square metre")

	for k in keys:
		items._crops.erase(k)

	items._items.erase(920030)
	items._items.erase(920031)


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
	sow(920004, "wild_thyme_seed")
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

		if str(entry.get("kind", "")) != "plant" or bool(entry.get("future", false)) or str(plant).ends_with("_log") or plant in ["old_stump", "dead_tree"] or fungi.has(plant):   # logs, stumps and dead trees are scenery
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
	var holly: Dictionary = items._flora_by_name.get("sea_holly", {})
	check(bool(Gather.check(holly, "plant", drops, "summer", no_tool, any_item)["ok"]) and not bool(Gather.check(holly, "plant", drops, "winter", no_tool, any_item)["ok"]), "sea holly, which bears nothing else, can be picked for its seed when it has gone to seed, not in winter")
	var dune_rows: Array = (drops.get("by_species", {}) as Dictionary).get("dune_grass", [])
	check(not dune_rows.is_empty() and str(dune_rows[0][0]) == "plant_fibre" and bool(Gather.check(dune, "plant", drops, "spring", no_tool, any_item)["ok"]) and not bool(Gather.check(dune, "plant", drops, "winter", no_tool, any_item)["ok"]), "dune grass is picked by hand like tall grass for plant fibre in its seasons (Dave 21 Nov 2026), not in winter")
	# One bed or planter to a spot (one crop record each, _bed_key): a second pot on the same spot is refused.
	items._items[920006] = {"number": items.table.number_of("flower_pot"), "count": 1, "pos": Vector3(2.3, 10.0, 2.3), "left": 1.0e9, "struct": {"kind": "flower_pot", "yaw": 0.0}}
	notes.clear()
	var before: int = items._items.size()
	items.place_piece(1, "flower_pot_kit", Vector3(2.3, 10.0, 2.3))   # free build, as from the hammer (the Flower pot kit itself is retired)
	check(items._items.size() == before and notes.has("A bed or planter is already in that spot."), "a second flower pot on the same spot is refused (%s)" % str(notes))
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
		check(cost == ["lumber %d" % int(row[2]), "bronze_nails 8"] and is_equal_approx(float(def.get("footprint_x", 0.0)), float(row[1])) and bool(def.get("plot", false)), "%s: %d m square, %d planks and 8 nails (%s)" % [str(bp.get("name", row[0])), int(row[1]), int(row[2]), str(bp.get("cost", []))])

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


# The hoe grid's tilling (Dave 14 Nov 2026): a turned bed stands where its grid point is, turned with it; old metre-cell crop keys move to the bed at load;
# Till Garden Grid, Till Soil 2m and Plant (BugsList_Current.md entry 6): the whole area is checked first, then levelled, blended and tilled as one job;
# Plant fills a grid in one click from the crafting stock.
func _garden_till_checks() -> void:
	var inv = items.inventory_of(1)
	var hoe: int = HeldTool.slot_of(items, "hoe")
	items.report_position(1, Vector3(20.0, 10.0, 20.0))
	items._last_dig.clear()
	var turned: int = items.till(1, inv, Vector3(20.37, 10.0, 20.12), hoe, 15)
	check(turned != 0 and items._items[turned]["pos"].is_equal_approx(Vector3(20.35, 10.02, 20.1)) and is_equal_approx(float(items._items[turned]["struct"]["yaw"]), 15.0), "a turned grid's bed stands at its point (to 5 cm), turned 15 degrees")
	items._last_dig.clear()
	check(items.till(1, inv, Vector3(20.9, 10.0, 20.4), hoe, 15) == 0, "a bed closer than 0.9 m to another is not tilled")
	items._last_dig.clear()
	check(items.till(1, inv, Vector3(21.35, 10.0, 20.1), hoe, 15) != 0, "one a metre along is")
	check(items._bed_key(Vector3(20.35, 10.0, 20.1)) != items._bed_key(Vector3(20.9, 10.0, 20.1)) and items._bed_key(Vector3(20.35, 10.0, 20.1)) == items._bed_key(Vector3(20.36, 11.0, 20.09)), "a bed's key is its own position in 5 cm steps, not its metre cell")

	# A save from before turned beds: its crop and moisture keys are metre cells; they move to the bed in that cell, and a key with no bed is dropped.
	items._items[920020] = {"number": items.table.number_of("tilled_bed"), "count": 1, "pos": Vector3(30.5, 10.02, 30.5), "left": 1.0e9, "struct": {"kind": "tilled_bed", "yaw": 0.0}}
	items._crops["30,30"] = {"crop": "wheat", "sown": 0, "age": 1.0, "wet": 0, "day": 0, "compost": false}
	items._plot_water["30,30"] = [60.0, 0.0]
	items._crops["77,77"] = {"crop": "wheat", "sown": 0, "age": 1.0, "wet": 0, "day": 0, "compost": false}
	items._rekey_old_beds()
	var new_key: String = items._bed_key(Vector3(30.5, 10.0, 30.5))
	check(items._crops.has(new_key) and str(items._crops[new_key]["crop"]) == "wheat" and items._plot_water.has(new_key) and not items._crops.has("30,30") and not items._crops.has("77,77"), "old metre-cell keys move to their bed; one with no bed is dropped")
	items._crops.erase(new_key)
	items._plot_water.erase(new_key)
	items._items.erase(920020)

	# Till Garden Grid (BugsList entry 6, Dave 18 Nov 2026) on a slope of 0.3 m a metre: the beds' heights are averaged, the 3 by 3 garden is levelled to the average
	# and tilled, and its edge blends back to the slope no steeper than GARDEN_BLEND_GRADE. Aimed a little off the metre cells: an unturned garden's beds snap to them.
	var made_edits: Array = []
	var verdicts: Array = []
	items.send_hoe_verdict = func(_p, kind, code, at, state, why, marks): verdicts.append([kind, code, at, state, why, marks])
	items.ground_height = func(x, _z): return 10.0 + 0.3 * (x - 40.5)
	items.edits_near = func(_p, _r): return made_edits.duplicate()
	items.dig_ground = func(c, r): made_edits.append([0, c, r]); return true
	items.fill_ground = func(c, r, _m): made_edits.append([1, c, r]); return true
	items.report_position(1, Vector3(40.0, 10.0, 40.0))
	notes.clear()
	items._hoe_check_ms.clear()
	check(not items.till_garden(1, inv, Vector3(40.3, 10.0, 40.7), hoe, 0, 10000303) and not items._garden_jobs.has(1) and made_edits.is_empty() and verdicts.size() == 1 and int(verdicts[0][3]) == 1, "the preview's question is answered green and changes nothing (%s)" % str(verdicts))
	items._items[920030] = {"number": items.table.number_of("stone"), "count": 1, "pos": Vector3(40.5, 10.0, 40.5), "left": 1.0e9, "scatter": 777001}
	var stones_before: int = inv.count_of(items.table.number_of("stone"))
	items._last_dig.clear()
	check(items.till_garden(1, inv, Vector3(40.3, 10.0, 40.7), hoe, 0, 303) and items._garden_jobs.has(1) and int(verdicts[-1][3]) == 2, "a 3 by 3 garden on a gentle slope is taken on in one click (%s)" % str(notes))
	check(not items._items.has(920030) and inv.count_of(items.table.number_of("stone")) == stones_before + 1, "the small rock on the garden is picked up on the click")
	items._last_dig.clear()
	check(not items.till_garden(1, inv, Vector3(40.3, 10.0, 40.7), hoe, 0, 303), "one garden at a time")
	items.report_position(1, Vector3(90.0, 10.0, 40.0))   # walking off does not stop it: the area was checked when it was taken on
	var steps: int = 0

	while items._garden_jobs.has(1) and steps < 500:
		items._garden_jobs[1]["next_ms"] = 0
		items._garden_jobs_tick()
		steps += 1

	var beds: Array = items._items.keys().filter(func(k): return items._items[k].has("struct") and str(items._items[k]["struct"]["kind"]) == "tilled_bed" and Vector2(items._items[k]["pos"].x - 40.5, items._items[k]["pos"].z - 40.5).length() < 1.6)
	check(not items._garden_jobs.has(1) and beds.size() == 9 and notes.has("The garden is ready: 9 beds tilled."), "the garden is levelled and its 9 beds tilled in %d steps, the player gone (%s)" % [steps, str(notes)])
	check(made_edits.any(func(op): return int(op[0]) == 0) and made_edits.any(func(op): return int(op[0]) == 1) and inv.count_of(items.table.number_of("soil")) == 0, "the high side is cut and the low side filled, with no soil")
	var flat: bool = true

	for x in [39.5, 40.5, 41.5]:
		for z in [39.5, 40.5, 41.5]:
			flat = flat and absf(items._edited_height(x, z, made_edits) - 10.0) <= items.LEVEL_MIN_M + 0.01

	check(flat, "every bed is level with the average height (10 m)")
	check(beds.all(func(k): return absf(items._items[k]["pos"].y - 10.02) <= items.LEVEL_MIN_M + 0.01), "each bed lies on the levelled ground, not the slope as it was")

	for k in beds:
		items._crops.erase(items._bed_key(items._items[k]["pos"]))
		items._items.erase(k)

	var edge: float = items._edited_height(43.0, 40.5, made_edits)
	check(edge > 10.0 - 0.06 and edge <= 10.0 + items.GARDEN_BLEND_GRADE * 1.0 + 0.12, "a metre outside the garden the ground is no higher than the blend's slope allows (%.2f)" % edge)
	check(items.GARDEN_BLEND_GRADE <= 1.0 and items.GARDEN_BLEND_GRADE <= 0.5, "the blend is 45 degrees or gentler, and at most 1 in 2 (steeper, neighbouring spheres undo each other)")
	items.report_position(1, Vector3(60.5, 10.0, 40.5))
	items._last_dig.clear()
	notes.clear()
	check(not items.till_garden(1, inv, Vector3(60.5, 10.0, 40.5), hoe, 0, 101) and notes.any(func(n): return str(n).begins_with("The next garden grid is ready in")), "the next garden waits for the 20 s countdown, wherever the player is (%s)" % str(notes))
	items._garden_ready_ms.clear()

	# Too steep: a slope of 0.6 m a metre never meets a 0.5 blend within 20 m: refused, red, nothing touched.
	items.ground_height = func(x, _z): return 10.0 + 0.6 * (x - 60.5)
	made_edits.clear()
	notes.clear()
	items._last_dig.clear()
	check(not items.till_garden(1, inv, Vector3(60.5, 10.0, 40.5), hoe, 0, 501) and made_edits.is_empty() and notes.any(func(n): return str(n).contains("falls away too steeply")) and int(verdicts[-1][3]) == 0, "ground the blend cannot meet within 20 m is refused (%s)" % str(notes))

	# A 5 by 5 garden on a gentle slope: done well inside the edit cap.
	items.ground_height = func(x, _z): return 10.0 + 0.3 * (x - 120.5)
	items.report_position(1, Vector3(120.5, 10.0, 40.5))
	made_edits.clear()
	items._last_dig.clear()
	check(items.till_garden(1, inv, Vector3(120.5, 10.0, 40.5), hoe, 0, 505), "a 5 by 5 garden on a gentle slope is taken on")
	steps = 0

	while items._garden_jobs.has(1) and steps < 800:
		items._garden_jobs[1]["next_ms"] = 0
		items._garden_jobs_tick()
		steps += 1

	check(not items._garden_jobs.has(1) and made_edits.size() < items.GARDEN_MAX_EDITS, "the 5 by 5 garden is levelled in %d edits, under the cap of %d" % [made_edits.size(), items.GARDEN_MAX_EDITS])
	items._garden_ready_ms.clear()

	# A wall beside the garden: Dave: no ground changed within 2 m of a building, and no hole round it: the whole garden is refused before anything changes.
	items.ground_height = func(x, _z): return 10.0 + 0.3 * (x - 80.5)
	items._items[920021] = {"number": items.table.number_of("thatch_wall"), "count": 1, "pos": Vector3(83.1, 10.0, 40.5), "left": 1.0e9, "struct": {"kind": "thatch_wall", "yaw": 0.0}}
	items.report_position(1, Vector3(80.5, 10.0, 40.5))
	made_edits.clear()
	notes.clear()
	items._last_dig.clear()
	check(not items.till_garden(1, inv, Vector3(80.5, 10.0, 40.5), hoe, 0, 303) and made_edits.is_empty() and notes.any(func(n): return str(n).begins_with("Too close to a building")), "a garden whose ground or blend comes within 2 m of a wall is refused, nothing changed (%s)" % str(notes))
	items._items.erase(920021)

	# A tree or a large rock on the garden: refused.
	items.trunks_near = func(_p, _r): return [[Vector3(80.5, 10.0, 40.5), 0.3, 12.0]]
	items._last_dig.clear()
	notes.clear()
	check(not items.till_garden(1, inv, Vector3(80.5, 10.0, 40.5), hoe, 0, 303) and made_edits.is_empty() and notes.any(func(n): return str(n).begins_with("A tree is in the way")), "a tree on the garden refuses it (%s)" % str(notes))
	items.trunks_near = Callable()
	items._items[920022] = {"number": 0, "count": 40, "pos": Vector3(81.5, 10.0, 41.5), "left": 1.0e9, "scatter": 777002, "boulder": {"radius": 0.6, "yaw": 0.0, "total": 40}}
	items._last_dig.clear()
	notes.clear()
	check(not items.till_garden(1, inv, Vector3(80.5, 10.0, 40.5), hoe, 0, 303) and made_edits.is_empty() and notes.any(func(n): return str(n).begins_with("A large rock is in the way")), "a large rock on the garden refuses it (%s)" % str(notes))
	items._items.erase(920022)

	# Till Soil 2m: a 2 by 2 patch levelled to its average and tilled, no blend, no countdown.
	items.ground_height = func(x, _z): return 10.0 + 0.2 * (x - 100.0)
	items.report_position(1, Vector3(100.0, 10.0, 40.0))
	made_edits.clear()
	items._last_dig.clear()
	check(items.till_garden(1, inv, Vector3(100.0, 10.0, 40.0), hoe, 0, 10000 + 909) and not items._garden_ready_ms.has(1), "Till Soil 2m is taken on whatever grid size is sent, and starts no countdown")
	steps = 0

	while items._garden_jobs.has(1) and steps < 300:
		items._garden_jobs[1]["next_ms"] = 0
		items._garden_jobs_tick()
		steps += 1

	var soil_beds: Array = items._items.keys().filter(func(k): return items._items[k].has("struct") and str(items._items[k]["struct"]["kind"]) == "tilled_bed" and Vector2(items._items[k]["pos"].x - 100.0, items._items[k]["pos"].z - 40.0).length() < 1.5)
	check(soil_beds.size() == 4 and made_edits.all(func(op): return absf(float(op[2]) - items.SOIL_SPHERE_M) < 0.001 and Vector2(op[1].x - 100.0, op[1].z - 40.0).length() < 1.2), "the 2 m patch has 4 beds and only small spheres inside it (no blend; %d edits)" % made_edits.size())

	for k in soil_beds:
		items._items.erase(k)

	# Plant: one click fills the grid's usable points, from the pack and then from what lies nearby; a crop needs a tilled bed.
	items.ground_height = func(_x, _z): return 10.0
	made_edits.clear()
	items.report_position(1, Vector3(200.0, 10.0, 200.0))
	items._last_dig.clear()
	var bed_a: int = items.till(1, inv, Vector3(200.5, 10.0, 200.5), hoe, 0)
	items._last_dig.clear()
	var bed_b: int = items.till(1, inv, Vector3(201.5, 10.0, 200.5), hoe, 0)
	var was_season: String = season[0]
	season[0] = "spring"
	var seed_n: int = items.table.number_of("wheat_seeds")
	inv.remove(seed_n, inv.count_of(seed_n))
	items.action(1, Net.ACT_ADMIN_GIVE, seed_n, 0, 1, Vector3.ZERO)
	items._items[920031] = {"number": seed_n, "count": 1, "pos": Vector3(199.5, 10.0, 199.5), "left": 1.0e9}
	items._hoe_check_ms.clear()
	verdicts.clear()
	items.plant_grid(1, inv, hoe, seed_n, 10000000 + 301, Vector3(201.5, 10.0, 200.5))
	var cells: PackedByteArray = verdicts[0][5] if not verdicts.is_empty() else PackedByteArray()
	check(bed_a != 0 and bed_b != 0 and cells.size() == 3 and cells[0] == 1 and cells[1] == 1 and cells[2] == 0 and inv.count_of(seed_n) == 1, "the planting preview: the two beds green, open ground red for a crop, nothing taken (%s)" % str(cells))
	items._last_dig.clear()
	notes.clear()
	check(items.plant_grid(1, inv, hoe, seed_n, 301, Vector3(201.5, 10.0, 200.5)) == 2 and inv.count_of(seed_n) == 0 and not items._items.has(920031), "one click sows both beds: the seed in the pack and the one on the ground (%s)" % str(notes))
	check(items._crops.has(items._bed_key(items._items[bed_a]["pos"])) and items._crops.has(items._bed_key(items._items[bed_b]["pos"])), "both beds have wheat growing")
	items._last_dig.clear()
	check(items.plant_grid(1, inv, hoe, seed_n, 301, Vector3(201.5, 10.0, 200.5)) == 0, "nothing left: nothing planted, and a growing bed takes no second plant")
	season[0] = was_season

	for k in [bed_a, bed_b]:
		items._crops.erase(items._bed_key(items._items[k]["pos"]))
		items._items.erase(k)

	items.ground_height = func(_x, _z): return 10.0
	items.dig_ground = Callable()
	items.fill_ground = Callable()
	items.edits_near = Callable()
	items.send_hoe_verdict = Callable()
	items.report_position(1, Vector3(0.0, 10.0, 0.0))


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
	check(not sow(bed, "wheat_seeds") and count("wheat_seeds") == 3, "wheat is refused out of season and the seed is kept")
	season[0] = "spring"
	check(sow(bed, "wheat_seeds") and count("wheat_seeds") == 2, "in spring the sowing works and uses one seed")
	check(not sow(bed, "wheat_seeds", items._items[bed]["pos"]) and count("wheat_seeds") == 2, "a bed with a crop takes no second seed")
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
	items._crops[dry_key] = {"crop": "wheat", "sown": 0, "age": float(grow) + 5.0, "wet": 0, "day": items._game_day(), "compost": false, "rained": -1}
	check(items.crop_stage(items._crops[dry_key]) == 2, "old enough but never watered: stalls at stage 2, not ripe")
	items._crops.erase(dry_key)

	# Harvest: without a sickle half the yield.
	var yield_wheat: int = int(crops["wheat"]["yields"][0][1])
	check(items.harvest(1, items.inventory_of(1), bed) and count("wheat") == int(ceil(float(yield_wheat) / 2.0)) and count("wheat_seeds") >= 4 and not items._crops.has(key), "no sickle: half the wheat (%d of %d), the seeds come back, the bed is empty" % [count("wheat"), yield_wheat])

	# Full yield with a sickle, second crop; winter and frost.
	give("bronze_sickle", 1)   # the Stone - Sickle is retired (master s3.1, Mission 001 phase 2c)
	season[0] = "spring"
	rain[0] = 0.0
	check(sow(bed, "wheat_seeds"), "the bed is sown again")
	season[0] = "winter"
	days(1)
	check(not items._crops.has(key), "a seedling does not survive winter frost")
	give("turnip_seeds", 2)
	check(not sow(bed, "turnip_seeds"), "turnip cannot be sown in winter (its seasons are spring and autumn)")
	season[0] = "autumn"
	check(sow(bed, "turnip_seeds"), "turnip can be sown in autumn (sow_seasons list)")
	season[0] = "winter"
	days(2)
	check(items._crops.has(key) and float(items._crops[key]["age"]) >= 2.0, "and grows through it")

	# Wheat with the sickle: put a ripe crop in directly (growth was tested above) and harvest it with the tool.
	items._crops.erase(key)
	items._crops[key] = {"crop": "wheat", "sown": 0, "age": float(grow), "wet": grow, "day": items._game_day(), "compost": false, "rained": -1}
	var before: int = count("wheat")
	check(items.harvest(1, items.inventory_of(1), bed) and count("wheat") - before == yield_wheat, "with a sickle the full yield (%d)" % (count("wheat") - before))
	# Worms (Dave 14 Nov 2026): each ripe garden crop taken rolls crops.json worm.chance (0.2) for a Worm; forced to 1 and 0 here to see both ends.
	check(is_equal_approx(float(items._crops_file_extra["worm"]["chance"]), 0.2), "a ripe crop gives a worm one time in five (%s)" % str(items._crops_file_extra.get("worm", {})))
	var worm_chance: Dictionary = items._crops_file_extra["worm"]
	var worms: int = count("worm")
	worm_chance["chance"] = 1.0
	items._crops[key] = {"crop": "wheat", "sown": 0, "age": float(grow), "wet": grow, "day": items._game_day(), "compost": false, "rained": -1}
	check(items.harvest(1, items.inventory_of(1), bed) and count("worm") == worms + 1, "a sure worm roll gives one Worm with the harvest")
	worm_chance["chance"] = 0.0
	items._crops[key] = {"crop": "wheat", "sown": 0, "age": float(grow), "wet": grow, "day": items._game_day(), "compost": false, "rained": -1}
	check(items.harvest(1, items.inventory_of(1), bed) and count("worm") == worms + 1, "no worm roll, no worm")
	worm_chance["chance"] = 0.2

	# Water poured counts: sow, pour, next day wet.
	season[0] = "spring"
	give("bucket", 1)
	items.inventory_of(1).wear[slot_of("bucket")] = 8000   # a filled bucket (the fill and the pour scaling: test_liquid_ingredient)
	give("barley_seeds", 1)
	sow(bed, "barley_seeds")
	items._plot_water[key] = [20.0, clock[0]]   # a dry bed
	check(items.water_bed(1, items.inventory_of(1), bed) and absf(items.plot_moisture(items._items[bed]["pos"]) - 52.0) < 0.01, "a bucket of water pours on the dry bed")
	days(1)
	check(int(items._crops[key]["wet"]) == 1, "water poured makes the next game day wet")

	_moisture_checks(bed)
	_route_checks(bed, crops)
	_plot_takedown_checks()
	_hoe_plot_checks()
	_herb_seed_checks(crops)
	_plot_size_checks(dir)
	_garden_till_checks()

	# Save and restart: a barley crop grown to a stage keeps its crop, its age and its stage (the world save, not a hand-written file).
	season[0] = "spring"
	give("barley_seeds", 1)
	sow(bed, "barley_seeds")
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
