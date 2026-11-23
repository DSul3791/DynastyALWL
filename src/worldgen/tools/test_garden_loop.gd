extends SceneTree

# Farming and gardening end to end (coordinator 23 Nov 2026: "the same way you did cooking"), through the real ServerItems, with a server
# restart in the middle of growth. test_farm_loop walks one wheat patch from tall grass to flour; this walks what it does not:
#   1. every hoe tills, and a better hoe is faster (items.json till_speed rises with the tier, #1753);
#   2. plenty of seeds (Dave: "you should get plenty of seeds"): every crop can be started from a wild plant, a wild pick gives at least two
#      sowings, a harvest gives at least three back; a real pick of wild carrot gives carrot and parsnip seed (parsnip had no source);
#   3. the seasons: nothing is sown in winter or out of a crop's season; winter kills a seedling that does not overwinter, keeps winter
#      wheat, pauses a half-grown crop and grows turnip;
#   4. the weather at the bed (#1747, weather_at): rain over one bed and a dry sky over its neighbour, the wet one ripens on time, the dry
#      one grows half as fast and waits for wet days; a bucket poured on the dry bed wets it and it ripens;
#   5. a restart half way keeps each crop's age, wet days and its bed's moisture;
#   6. two players in one garden plot: each sows a square metre of the same plot, the other waters it, each harvests. Who may harvest whose
#      crop is Dave's open question ("owner-only crop harvest?"): the test prints what the server does now and does not judge it.
#   7. a garden across the equator keeps its own seasons (season_at, as leaves and drinking water do): sown and wintered by its own season,
#      not the starter's calendar;
#   godot --headless --path . --script res://src/worldgen/tools/test_garden_loop.gd

const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const DIR := "user://test_garden_loop"
const ACROSS_Z := 1000.0   # season_at: past this line the beds lie across the equator, half a year on
const OPPOSITE := {"spring": "autumn", "summer": "winter", "autumn": "spring", "winter": "summer"}
const WET_X := 40.0   # weather_at rains on beds east of this line and keeps the sky dry west of it

var failures: int = 0
var items
var clock: Array = [0.0]
var season: Array = ["spring"]
var rain_east: Array = [0.8]
var rain_west: Array = [0.0]
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
	it.send_hoe_verdict = func(_p, _k, _c, _at, _s, _why, _m): pass
	it.ground_height = func(_x, _z): return 10.0
	it.game_seconds = func(): return clock[0]
	it.season_now = func(): return season[0]
	it.season_at = func(pos: Vector3): return OPPOSITE[season[0]] if pos.z > ACROSS_Z else season[0]   # beds past ACROSS_Z lie across the equator
	it.weather_at = func(pos: Vector3): return {"rain": rain_east[0] if pos.x > WET_X else rain_west[0], "temp_c": 15.0, "wind": 0.0}
	it.setup(ItemTableScript.load_default(), DIR)
	it.peer_connected_hello(1, "gardenloop00001")
	it.peer_connected_hello(2, "gardenloop00002")
	it.report_position(1, Vector3(0.0, 10.0, 0.0))
	it.report_position(2, Vector3(0.0, 10.0, 0.0))
	it.gather_pace_ms = 0
	return it


func n(id: String) -> int:
	return items.table.number_of(id)


func count(id: String, peer: int = 1) -> int:
	return items.inventory_of(peer).count_of(n(id))


func give(id: String, k: int, peer: int = 1) -> void:
	var left: int = k

	while left > 0:   # an admin give is at most 100 at a time
		items.action(peer, Net.ACT_ADMIN_GIVE, n(id), 0, mini(left, 100), Vector3.ZERO)
		left -= 100


func empty_pack(peer: int = 1) -> void:
	var inv = items.inventory_of(peer)

	for s in inv.slot_count:
		inv.numbers[s] = 0
		inv.counts[s] = 0
		inv.wear[s] = 0


func crops() -> Dictionary:
	return items._crop_table()


func pinch(crop: String) -> int:
	return maxi(int(crops()[crop].get("sow_seeds", 1)), 1)


func hoe_slot(peer: int = 1) -> int:
	var inv = items.inventory_of(peer)

	for s in inv.slot_count:
		if inv.numbers[s] != 0 and str(items.table.entry(items.table.id_of(inv.numbers[s])).get("tool_class", "")) == "hoe":
			return s

	return -1


# A 1 m bed tilled at `at` by `peer` standing beside it; -> its id (0 when refused).
func till_at(at: Vector3, peer: int = 1) -> int:
	items.report_position(peer, at + Vector3(0.5, 0.0, 0.0))
	items._last_dig.clear()
	var hoe: int = hoe_slot(peer)
	items.inventory_of(peer).wear[hoe] = 0
	return items.till(peer, items.inventory_of(peer), at, hoe)


# One spot sown at `at` with `seed_id` (a 1 x 1 Plant grid); -> the spots sown.
func sow_at(at: Vector3, seed_id: String, peer: int = 1) -> int:
	items.report_position(peer, at + Vector3(0.5, 0.0, 0.0))
	items._last_dig.clear()
	items._hoe_check_ms.clear()
	var hoe: int = hoe_slot(peer)
	items.inventory_of(peer).wear[hoe] = 0
	return items.plant_grid(peer, items.inventory_of(peer), hoe, n(seed_id), 101, at)


func bed_pos(id: int) -> Vector3:
	return items._items[id]["pos"]


func crop_at(pos: Vector3) -> Dictionary:
	return items._crops.get(items._bed_key(pos), {})


# A crop's record as plain values (a loaded save reads its numbers back as floats).
func crop_row(pos: Vector3) -> Array:
	var c: Dictionary = crop_at(pos)
	return [] if c.is_empty() else [str(c["crop"]), int(c["sown"]), snappedf(float(c["age"]), 0.01), int(c["wet"]), int(c["day"]), bool(c["compost"])]


# The bed standing at `pos` (ids are handed out afresh when the world loads).
func bed_near(pos: Vector3) -> int:
	for id in items._items:
		var it: Dictionary = items._items[id]

		if it.has("struct") and items._is_plot_kind(str(it["struct"]["kind"])) and Vector2(it["pos"].x - pos.x, it["pos"].z - pos.z).length() < 0.1:
			return id

	return 0


func days(k: int) -> void:
	for d in k:
		clock[0] += 86400.0
		items._crops_tick()


func restart() -> void:
	items._dirty = true
	items.save()
	items._finish_writer()
	items = make()


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	items = make()
	hoes_part()
	seeds_part()
	seasons_part()
	weather_part()
	two_players_part()
	hemisphere_part()
	print("test_garden_loop: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)


# 1. Every hoe tills a bed, and each step up the tool tiers (TOOL-TIERS-1: Stone or Wooden, Copper, Bronze, Iron, Steel) tills faster: its till_speed is above
# the step before (a garden job does that many times the work a step, #1753). The wooden and the stone hoe are the same first step.
const HOE_STEPS := {"wooden_hoe": 0, "stone_hoe": 0, "copper_hoe": 1, "bronze_hoe": 2, "iron_hoe": 3, "steel_hoe": 4}


func hoes_part() -> void:
	var hoes: Array = []

	for id in items.table.ids():
		var e: Dictionary = items.table.entry(id)

		if str(e.get("tool_class", "")) == "hoe" and not bool(e.get("future", false)):
			check(HOE_STEPS.has(str(id)), "%s is a hoe on the tier steps" % id)
			hoes.append([int(HOE_STEPS.get(str(id), -1)), float(e.get("till_speed", 1.0)), str(id)])

	hoes.sort()
	check(hoes.size() == HOE_STEPS.size(), "all %d hoes are in the game (%d)" % [HOE_STEPS.size(), hoes.size()])
	var x: float = -30.5

	for k in hoes.size():
		empty_pack()
		give(str(hoes[k][2]), 1)
		x -= 3.0
		var bed: int = till_at(Vector3(x, 10.0, -30.5))
		check(bed != 0, "%s tills a bed" % hoes[k][2])

		if k > 0 and int(hoes[k][0]) > int(hoes[k - 1][0]):
			check(float(hoes[k][1]) > float(hoes[k - 1][1]), "%s tills faster than %s, a step below it: %.2f against %.2f" % [hoes[k][2], hoes[k - 1][2], hoes[k][1], hoes[k - 1][1]])
		elif k > 0:
			check(float(hoes[k][1]) == float(hoes[k - 1][1]), "%s tills as fast as %s, the same step: %.2f" % [hoes[k][2], hoes[k - 1][2], hoes[k][1]])

	check(items._hoe_speed(items.inventory_of(1), hoe_slot()) == float(hoes[hoes.size() - 1][1]), "the server reads the best hoe's speed for its garden jobs")


# 2. Plenty of seeds, from the wild and back from every harvest.
func seeds_part() -> void:
	var drops: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/drops.json"))
	var seed_drops: Dictionary = drops.get("seed_drops", {})
	var wild: Dictionary = {}   # seed item -> its fewest sowings from one pick

	for species in seed_drops:
		if str(species) == "note":
			continue

		for row in seed_drops[species]["rows"]:
			wild[str(row[0])] = mini(int(wild.get(str(row[0]), 1 << 30)), int(row[1]))

	var no_source: Array = []
	var thin_wild: Array = []
	var thin_back: Array = []

	for crop in crops():
		if str(crop).begins_with("_"):
			continue

		var seed_id: String = str(crops()[crop]["seed"])
		var tree_nut: bool = pinch(crop) == 1   # a bush grown from its nut (hazel): its seed is the bush's own harvest

		if not wild.has(seed_id) and not tree_nut:
			no_source.append(crop)
		elif wild.has(seed_id) and int(wild[seed_id]) < 2 * pinch(crop):
			thin_wild.append("%s %d < 2 x %d" % [crop, int(wild[seed_id]), pinch(crop)])

		var back: Array = crops()[crop].get("seeds_back", [])

		if back.size() != 2 or str(back[0]) != seed_id or int(back[1][0]) < 3 * pinch(crop):
			thin_back.append(str(crop))

	check(no_source.is_empty(), "every crop can be started from a wild plant's seed (none without: %s)" % str(no_source))
	check(thin_wild.is_empty(), "one wild pick gives at least two sowings of every crop (short: %s)" % str(thin_wild))
	check(thin_back.is_empty(), "every harvest gives back at least three sowings of its own seed (short: %s)" % str(thin_back))

	# A real pick of wild carrot in summer: carrot and parsnip seed, each enough for two spots or more.
	empty_pack()
	season[0] = "summer"
	items.report_position(1, Vector3(500.0, 10.0, 500.0))
	items._last_gather.clear()
	items.gather(1, "wild_carrot", "plant", "0,0,901", 901, Vector3(501.0, 10.0, 500.0))
	check(count("carrot_seeds") >= 2 * pinch("carrot"), "a wild carrot picked in summer gives %d carrot seeds (%d a spot)" % [count("carrot_seeds"), pinch("carrot")])
	check(count("parsnip_seeds") >= 2 * pinch("parsnip"), "and %d parsnip seeds (%d a spot): parsnip can be started now" % [count("parsnip_seeds"), pinch("parsnip")])

	# Parsnip all the way: sown in spring, grown in rain, harvested by hand, more seed back than went in.
	season[0] = "spring"
	give("stone_hoe", 1)
	var pos: Vector3 = Vector3(60.5, 10.0, 60.5)   # east of WET_X: it rains here
	var bed: int = till_at(pos)
	var seed_in: int = count("parsnip_seeds")
	check(bed != 0 and sow_at(pos, "parsnip_seeds") == 1 and seed_in - count("parsnip_seeds") == pinch("parsnip"), "a pinch of the wild parsnip seed sows a tilled bed")
	days(int(crops()["parsnip"]["grow_days"]) + 1)
	check(not crop_at(pos).is_empty() and items.crop_stage(crop_at(pos)) == 3, "the parsnip ripens after its grow days in the rain")
	var before: int = count("parsnip_seeds")
	check(items.harvest(1, items.inventory_of(1), bed) and count("parsnip") == int(crops()["parsnip"]["yields"][0][1]), "harvested by hand it gives %d parsnips" % count("parsnip"))
	check(count("parsnip_seeds") - before >= 3 * pinch("parsnip"), "and %d seeds back, three sowings or more" % (count("parsnip_seeds") - before))


# 3. Seasons: sowing and winter.
func seasons_part() -> void:
	empty_pack()
	give("stone_hoe", 1)

	for seed_id in ["wheat_seeds", "barley_seeds", "turnip_seeds", "radish_seeds", "carrot_seeds"]:
		give(seed_id, 400)

	var x: float = 80.5   # in the rain
	var beds: Dictionary = {}

	for name in ["frozen", "barley_summer", "wheat_seedling", "barley_seedling", "barley_half", "turnip", "radish_late"]:
		x += 3.0
		beds[name] = Vector3(x, 10.0, 80.5)
		check(till_at(beds[name]) != 0, "a bed for %s is tilled" % name)

	season[0] = "winter"
	notes.clear()
	check(sow_at(beds["frozen"], "turnip_seeds") == 0 and crop_at(beds["frozen"]).is_empty(), "nothing is sown in winter, even turnip that grows in it")
	check(notes.any(func(t): return str(t).begins_with("The ground is frozen hard")), "the player is told the ground is frozen (%s)" % str(notes))
	season[0] = "summer"
	notes.clear()
	check(sow_at(beds["barley_summer"], "barley_seeds") == 0, "barley, a spring crop, is not sown in summer")
	check(notes.any(func(t): return str(t).contains("sow it in spring")), "and the player is told when to sow it (%s)" % str(notes))

	# Late autumn sowings meet the winter: winter wheat (overwinters) and barley as seedlings, a half-grown barley, a turnip, a radish.
	season[0] = "spring"
	sow_at(beds["barley_half"], "barley_seeds")
	days(int(int(crops()["barley"]["grow_days"]) * 0.6))
	var half: float = float(crop_at(beds["barley_half"]).get("age", 0.0))
	check(items.crop_stage(crop_at(beds["barley_half"])) == 2, "a barley sown in spring is half grown and more (stage %d)" % items.crop_stage(crop_at(beds["barley_half"])))
	season[0] = "autumn"
	check(sow_at(beds["wheat_seedling"], "wheat_seeds") == 1 and sow_at(beds["turnip"], "turnip_seeds") == 1 and sow_at(beds["radish_late"], "radish_seeds") == 1, "wheat, turnip and radish go in in autumn")
	items._crops[items._bed_key(beds["barley_seedling"])] = {"crop": "barley", "sown": items._game_day(), "age": 0.0, "wet": 0, "day": items._game_day(), "compost": false}   # a spring crop's seedling caught by the frost (sown late in spring in play)
	season[0] = "winter"
	days(10)
	check(not crop_at(beds["wheat_seedling"]).is_empty() and float(crop_at(beds["wheat_seedling"])["age"]) == 0.0, "winter wheat sits out the frost as a seedling")
	check(crop_at(beds["barley_seedling"]).is_empty(), "a barley seedling, which does not overwinter, is killed by the frost")
	check(crop_at(beds["radish_late"]).is_empty(), "so is a radish sown too late in autumn")
	check(not crop_at(beds["barley_half"]).is_empty() and float(crop_at(beds["barley_half"])["age"]) == half, "a half-grown barley waits out the winter, neither growing nor dying (age %.1f)" % float(crop_at(beds["barley_half"]).get("age", -1.0)))
	check(not crop_at(beds["turnip"]).is_empty() and items.crop_stage(crop_at(beds["turnip"])) == 3, "turnip grows through the winter and is ripe")
	restart()
	season[0] = "spring"
	days(int(crops()["wheat"]["grow_days"]) + 1)
	check(not crop_at(beds["wheat_seedling"]).is_empty() and items.crop_stage(crop_at(beds["wheat_seedling"])) == 3, "after a restart and the spring the winter wheat ripens")
	check(not crop_at(beds["barley_half"]).is_empty() and items.crop_stage(crop_at(beds["barley_half"])) == 3, "and so does the barley that waited")


# 4 and 5. The weather at the bed, a bucket, and a restart half way.
func weather_part() -> void:
	empty_pack()
	give("stone_hoe", 1)
	give("carrot_seeds", 200)
	season[0] = "spring"
	rain_east[0] = 0.8
	rain_west[0] = 0.0
	var wet_pos: Vector3 = Vector3(WET_X + 10.5, 10.0, 120.5)
	var dry_pos: Vector3 = Vector3(WET_X - 10.5, 10.0, 120.5)
	var wet_bed: int = till_at(wet_pos)
	var dry_bed: int = till_at(dry_pos)
	check(wet_bed != 0 and dry_bed != 0, "two beds 21 m apart, one under rain and one under a dry sky")
	check(sow_at(wet_pos, "carrot_seeds") == 1 and sow_at(dry_pos, "carrot_seeds") == 1, "both are sown with carrot")
	var grow: int = int(crops()["carrot"]["grow_days"])
	days(floori(grow * 0.5))
	check(items.plot_moisture(wet_pos) > 70.0, "the rained-on bed is wet (%.0f percent)" % items.plot_moisture(wet_pos))
	check(items.plot_moisture(dry_pos) < 25.0, "the bed under a dry sky has dried out (%.0f percent)" % items.plot_moisture(dry_pos))
	var wet_age: float = float(crop_at(wet_pos)["age"])
	var dry_age: float = float(crop_at(dry_pos)["age"])
	check(wet_age > dry_age, "the wet carrot is further on than the dry one (%.1f days against %.1f)" % [wet_age, dry_age])

	# A restart half way: age, wet days and both beds' moisture come back as they were.
	var keep: Array = [crop_row(wet_pos), crop_row(dry_pos), snappedf(items.plot_moisture(wet_pos), 0.01), snappedf(items.plot_moisture(dry_pos), 0.01)]
	restart()
	var back: Array = [crop_row(wet_pos), crop_row(dry_pos), snappedf(items.plot_moisture(wet_pos), 0.01), snappedf(items.plot_moisture(dry_pos), 0.01)]
	check(str(back) == str(keep), "a restart half way keeps both crops (age, wet days) and their beds' moisture (%s -> %s)" % [str(keep), str(back)])
	dry_bed = bed_near(dry_pos)

	days(grow - floori(grow * 0.5) + 1)
	check(items.crop_stage(crop_at(wet_pos)) == 3, "the rained-on carrot is ripe on time")
	check(items.crop_stage(crop_at(dry_pos)) < 3, "the dry one is not (age %.1f of %d days, %d wet days)" % [float(crop_at(dry_pos)["age"]), grow, int(crop_at(dry_pos)["wet"])])
	notes.clear()
	items.report_position(1, dry_pos + Vector3(0.5, 0.0, 0.0))
	check(not items.harvest(1, items.inventory_of(1), dry_bed) and notes.any(func(t): return str(t).contains("water")), "E on it says to water it (%s)" % str(notes))

	# A bucket a day on the dry bed: it wets the soil and the carrot ripens.
	give("bucket", 1)
	var bucket: int = items.inventory_of(1).numbers.find(n("bucket"))
	var waited: int = 0

	while items.crop_stage(crop_at(dry_pos)) < 3 and waited < 3 * grow:
		items.inventory_of(1).wear[bucket] = 8000
		items.water_bed(1, items.inventory_of(1), dry_bed, bucket)
		days(1)
		waited += 1

	check(items.crop_stage(crop_at(dry_pos)) == 3, "watered by bucket the dry carrot ripens too (%d more days)" % waited)
	var got: int = count("carrot")
	check(items.harvest(1, items.inventory_of(1), dry_bed) and count("carrot") - got == int(crops()["carrot"]["yields"][0][1]), "and gives its full harvest")


# 6. Two players working one garden plot.
func two_players_part() -> void:
	season[0] = "spring"
	rain_east[0] = 0.0   # a dry spell: the plot is kept by bucket
	rain_west[0] = 0.0
	empty_pack(1)
	empty_pack(2)

	for peer in [1, 2]:
		give("stone_hoe", 1, peer)
		give("lettuce_seeds", 100, peer)
		give("bucket", 1, peer)

	var plot: int = items.dev_place("wooden_garden_plot@160,160")
	var cells: Array = items._bed_cells(items._items[plot])
	check(cells.size() >= 2, "a garden plot of %d square metres stands" % cells.size())
	var a_cell: Vector3 = cells[0]
	var b_cell: Vector3 = cells[1]
	check(sow_at(a_cell, "lettuce_seeds", 1) == 1, "player A sows one square metre of the plot")
	check(sow_at(b_cell, "lettuce_seeds", 2) == 1, "player B sows another square metre of the same plot")
	check(not crop_at(a_cell).is_empty() and not crop_at(b_cell).is_empty() and items._crops.size() >= 2, "both crops grow side by side")
	var grow: int = int(crops()["lettuce"]["grow_days"])

	for d in grow + 1:
		var waterer: int = 1 + d % 2   # they take turns with the bucket
		var inv = items.inventory_of(waterer)
		var bucket: int = inv.numbers.find(n("bucket"))
		inv.wear[bucket] = 8000
		items.report_position(waterer, items._items[plot]["pos"] + Vector3(1.5, 0.0, 0.0))
		items.water_bed(waterer, inv, plot, bucket)
		days(1)

	check(items.crop_stage(crop_at(a_cell)) == 3 and items.crop_stage(crop_at(b_cell)) == 3, "watered by both in turn, both lettuces are ripe")
	restart()
	plot = _plot_by_kind("wooden_garden_plot")
	check(plot != 0 and items.crop_stage(crop_at(a_cell)) == 3 and items.crop_stage(crop_at(b_cell)) == 3, "a restart keeps the shared plot's two ripe crops")
	items.report_position(1, a_cell + Vector3(0.5, 0.0, 0.0))
	items.report_position(2, b_cell + Vector3(0.5, 0.0, 0.0))
	var a_had: int = count("lettuce", 1)
	var b_had: int = count("lettuce", 2)
	check(items.harvest(1, items.inventory_of(1), plot, a_cell) and count("lettuce", 1) > a_had and crop_at(a_cell).is_empty(), "player A harvests their own square metre")
	check(not crop_at(b_cell).is_empty(), "and B's lettuce is still standing")
	check(items.harvest(2, items.inventory_of(2), plot, b_cell) and count("lettuce", 2) > b_had and crop_at(b_cell).is_empty(), "player B harvests theirs")

	# Who may harvest another's crop is Dave's to decide: report what the server does now, without a pass or fail.
	check(sow_at(a_cell, "lettuce_seeds", 1) == 1, "player A sows again")
	items._crops[items._bed_key(a_cell)]["age"] = float(grow)
	items._crops[items._bed_key(a_cell)]["wet"] = grow
	items.report_position(2, a_cell + Vector3(0.5, 0.0, 0.0))
	var took: bool = items.harvest(2, items.inventory_of(2), plot, a_cell)
	print("note open question for Dave (owner-only crop harvest?): player B %s player A's ripe lettuce in a shared plot" % ("CAN harvest" if took else "cannot harvest"))


func _plot_by_kind(kind: String) -> int:
	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == kind:
			return id

	return 0


# 7. Across the equator: the calendar says spring, the garden's own season is autumn; then summer at home is winter there.
func hemisphere_part() -> void:
	empty_pack()
	give("stone_hoe", 1)
	give("barley_seeds", 200)
	give("rye_seeds", 200)
	give("radish_seeds", 200)
	season[0] = "spring"
	rain_east[0] = 0.8
	var barley_pos: Vector3 = Vector3(60.5, 10.0, ACROSS_Z + 50.5)
	var rye_pos: Vector3 = Vector3(63.5, 10.0, ACROSS_Z + 50.5)
	var radish_pos: Vector3 = Vector3(66.5, 10.0, ACROSS_Z + 50.5)

	for pos in [barley_pos, rye_pos, radish_pos]:
		check(till_at(pos) != 0, "a bed across the equator is tilled")

	notes.clear()
	check(sow_at(barley_pos, "barley_seeds") == 0, "in the calendar's spring, barley (a spring crop) is not sown where it is autumn")
	check(notes.any(func(t): return str(t).contains("it is autumn now")), "and the player is told it is autumn there (%s)" % str(notes))
	check(sow_at(rye_pos, "rye_seeds") == 1 and sow_at(radish_pos, "radish_seeds") == 1, "rye and radish (autumn crops) are sown there")
	season[0] = "summer"   # winter across the equator
	days(5)
	check(crop_at(radish_pos).is_empty(), "the radish seedling is killed by that side's winter while the calendar says summer")
	check(not crop_at(rye_pos).is_empty() and float(crop_at(rye_pos)["age"]) == 0.0, "the rye (it overwinters) sits that winter out as a seedling")
	restart()
	season[0] = "autumn"   # spring across the equator
	days(int(crops()["rye"]["grow_days"]) + 1)
	check(not crop_at(rye_pos).is_empty() and items.crop_stage(crop_at(rye_pos)) == 3, "after a restart and that side's spring the rye ripens")

	# A tree's seed in open ground goes by the place's season too: refused in that side's winter (calendar summer), planted in its summer.
	var by_species: Dictionary = ((items._drops.get("trunk", {}) as Dictionary).get("felled_seeds", {}) as Dictionary).get("by_species", {})
	check(not by_species.is_empty(), "there are tree seeds to plant")

	if by_species.is_empty():
		return

	var tree_seed: String = str(by_species.values()[0])
	give(tree_seed, 2)
	var spot: Vector3 = Vector3(300.5, 10.0, ACROSS_Z + 300.5)
	season[0] = "summer"
	notes.clear()
	check(sow_at(spot, tree_seed) == 0 and notes.any(func(t): return str(t).begins_with("The ground is frozen hard")), "the %s is not planted where it is winter while the calendar says summer (%s)" % [tree_seed, str(notes)])
	season[0] = "winter"
	check(sow_at(spot, tree_seed) == 1, "and is planted there in that side's summer while the calendar says winter")
