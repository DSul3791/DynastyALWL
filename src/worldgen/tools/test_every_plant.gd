extends SceneTree

# Every plant a player can pick, sow or plant works through the real server (Dave 22 Nov 2026 roadmap: "the physical world working perfectly: trees,
# plants, ground, water" comes first; his ruling 14 Nov 2026: "All herbs and plants should produce seeds"; docs/design/HOE_GARDENING_DESIGN.md).
#   1. every crop in crops.json: its seed sown with the hoe on a tilled bed in its first sowing season, the bed kept wet, the clock run past its grow
#      days: it is ripe (stage 3), and harvest by hand (or with its tool) gives every yield in full and at least its least seeds back;
#   2. every live wild plant and shrub in flora.json with something to give: picked by hand (gather(), with a knife, shovel and axe in the pack for the
#      yields that need one) in each of its seasons that has something to give, it gives it; every seed_drops row names one of them, and each (fungi aside) has a seed in the wild or as a garden crop (shrubs too: coordinator 22 Nov 2026); and in a season its drops.json seed_drops row lists, it gives that seed;
#   3. every tree's own seed (drops.json trunk.felled_seeds): planted with the hoe's Plant grid in open ground, it is a sapling, and after the grow time
#      it is a grown tree that can be felled (dynamic_tree_info is not empty).
# Felling, logs and stumps are test_all_trees_logs, test_fell_autosplit and test_stump_chop; the rules of each step are test_farming's.
#   godot --headless --path . --script res://src/worldgen/tools/test_every_plant.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")

const SEASONS := ["spring", "summer", "autumn", "winter"]
const NO_SEED_PLANTS := ["fallen_log", "hollow_log", "old_stump", "dead_tree"]   # not plants (HOE_GARDENING_DESIGN.md "Which plants")
const FUNGI := ["mushrooms", "chanterelle", "porcini", "morel", "fly_agaric", "puffball", "tinder_fungus", "rimecap", "lumencap", "cinderfoot", "mirrorcap"]   # spores, not seed (as designed)
const FUTURE_WILD_CROPS := ["wild_potato", "wild_turnip", "sea_cabbage", "ramsons", "wild_vetch", "sea_beet", "wild_radish", "prickly_lettuce"]   # not in the world yet: their seeds have no wild source (coordinator 22 Nov 2026: switch them on)

var failures: int = 0
var checks: int = 0
var items
var clock: Array = [0.0]
var season: Array = ["spring"]
var rain: Array = [0.0]
var notes: Array = []


func check(ok: bool, what: String) -> void:
	checks += 1

	if not ok:
		print("FAIL " + what + ("  (told: %s)" % str(notes.slice(-2)) if not notes.is_empty() else ""))
		failures += 1


func count(id: String) -> int:
	return items.inventory_of(1).count_of(items.table.number_of(id))


func give(id: String, n: int) -> void:
	items.inventory_of(1).add(items.table.number_of(id), n)


func days(n: int) -> void:
	for d in range(n):
		clock[0] += 86400.0
		items._crops_tick()


func pack_total() -> int:
	var inv = items.inventory_of(1)
	var total: int = 0

	for i in range(inv.slot_count):
		if inv.numbers[i] != 0:
			total += maxi(inv.counts[i], 1)

	return total


func empty_pack() -> void:
	var inv = items.inventory_of(1)

	for i in range(inv.slot_count):
		if inv.numbers[i] != 0 and not ["stone_hoe", "stone_knife", "stone_shovel", "stone_axe", "sickle"].has(items.table.id_of(inv.numbers[i])):
			inv.remove(inv.numbers[i], inv.counts[i])


func crops_part(crops: Dictionary) -> int:
	var n: int = 0
	var pos: Vector3 = Vector3(0.5, 10.0, 0.5)

	for crop_id in crops:
		if str(crop_id).begins_with("_"):
			continue

		var def: Dictionary = crops[crop_id]
		var seed_id: String = str(def["seed"])
		var sow_seasons: Array = def.get("sow_seasons", [def.get("sow_season", "spring")])
		n += 1
		empty_pack()
		items._crops.clear()
		items._plot_water.clear()
		items._items[930001] = {"number": items.table.number_of("tilled_bed"), "count": 1, "pos": pos, "left": 1.0e9, "struct": {"kind": "tilled_bed", "yaw": 0.0}}
		items.report_position(1, Vector3(0.0, 10.0, 0.0))
		season[0] = str(sow_seasons[0])
		rain[0] = 0.5
		give(seed_id, 1)
		items._last_dig.clear()
		items._hoe_check_ms.clear()
		var hoe: int = HeldTool.slot_of(items, "hoe")
		items.inventory_of(1).wear[hoe] = 0
		notes.clear()
		var sown: int = items.plant_grid(1, items.inventory_of(1), hoe, items.table.number_of(seed_id), 101, pos)
		var key: String = items._bed_key(pos)

		if sown <= 0 or not items._crops.has(key):
			check(false, "crop %s: %s is not sown in %s" % [crop_id, seed_id, season[0]])
			continue

		days(int(def["grow_days"]) + 1)

		if not items._crops.has(key) or items.crop_stage(items._crops[key]) < 3:
			check(false, "crop %s: not ripe after %d wet days in %s (%s)" % [crop_id, int(def["grow_days"]) + 1, season[0], str(items._crops.get(key, "died"))])
			continue

		var before: Dictionary = {}

		for row in def.get("yields", []):
			before[str(row[0])] = count(str(row[0]))

		var back: Array = def.get("seeds_back", [])
		var seeds_before: int = count(seed_id)
		notes.clear()
		var took: bool = items.harvest(1, items.inventory_of(1), 930001)
		check(took, "crop %s: the ripe crop is not harvested" % crop_id)

		for row in def.get("yields", []):
			var got: int = count(str(row[0])) - int(before[str(row[0])])
			check(got >= int(row[1]), "crop %s: harvest gives %d %s, not %d" % [crop_id, got, row[0], int(row[1])])

		if back.size() == 2:
			var got_seeds: int = count(str(back[0])) - (seeds_before if str(back[0]) == seed_id else 0)
			check(got_seeds >= int((back[1] as Array)[0]), "crop %s: gives %d %s back, not at least %d" % [crop_id, got_seeds, back[0], int((back[1] as Array)[0])])

		items._items.erase(930001)

	return n


func wild_part(seed_drops: Dictionary, harvest: Dictionary, by_species: Dictionary, by_kind: Dictionary, crops: Dictionary) -> int:
	var n: int = 0
	var id: int = 1000

	for species in items._flora_by_name:
		var entry: Dictionary = items._flora_by_name[species]
		var kind: String = str(entry.get("kind", ""))

		if kind == "tree" or bool(entry.get("retired", false)) or bool(entry.get("future", false)) or NO_SEED_PLANTS.has(species):
			continue

		var seasons: Array = SEASONS if (entry.get("season", ["all"]) as Array).has("all") else entry.get("season", [])
		var seed_def: Dictionary = seed_drops.get(species, {})
		check(FUNGI.has(species) or not seed_def.is_empty() or crops.has(species), "%s %s: it gives no seed in the wild and is no garden crop (Dave: all herbs and plants produce seeds)" % [kind, species])
		n += 1

		for s in seasons:
			season[0] = str(s)
			empty_pack()
			id += 1
			items._last_gather.clear()
			var spot: Vector3 = Vector3(float(id % 200), 10.0, floorf(float(id) / 200.0))
			items.report_position(1, spot)
			var before: int = pack_total()
			notes.clear()
			items.gather(1, species, kind, "9,9,%d" % id, id, spot + Vector3(0.5, 0.0, 0.0), 2.0)
			var by_season: Dictionary = (harvest.get(species, {}) as Dictionary).get("by_season", {})
			var fixed: Array = by_species.get(species, by_kind.get(kind, []))   # the fixed drops (fibre, sticks), as gather() reads them
			var gives_here: bool = not fixed.is_empty() or (not (entry.get("yields", []) as Array).is_empty() and (by_season.is_empty() or by_season.has(str(s)))) or (seed_def.get("seasons", []) as Array).has(str(s))

			if gives_here:   # a seed-only plant (cattail) gives in its seed season; a wild rose's petals and hips are summer and autumn (drops.json harvest_yield by_season)
				check(pack_total() > before, "%s %s: picked by hand in %s, one of its seasons, it gives nothing" % [kind, species, s])

			if (seed_def.get("seasons", []) as Array).has(str(s)):
				var seeds: int = 0

				for row in seed_def["rows"]:
					seeds += count(str(row[0]))

				check(seeds > 0, "%s %s: picked in %s it gives no seed (%s)" % [kind, species, s, str(seed_def["rows"].map(func(r): return r[0]))])


	for species in seed_drops:   # every seed row names a live plant this part picked, so no seed is out of reach (Dave 14 Nov 2026)
		var entry: Dictionary = items._flora_by_name.get(species, {})

		if not entry.is_empty() and bool(entry.get("future", false)) and FUTURE_WILD_CROPS.has(species):   # a wild crop not in the world yet: its seed has no source, said, not failed
			print("NOTE seed_drops %s: the plant is future in flora.json, so %s has no wild source" % [species, str(seed_drops[species]["rows"].map(func(r): return r[0]))])
			continue

		check(str(species) == "note" or (not entry.is_empty() and str(entry.get("kind", "")) != "tree" and not bool(entry.get("retired", false))), "seed_drops %s: no live wild plant of that name gives it" % species)

	return n


func trees_part(by_species: Dictionary) -> int:
	var n: int = 0
	var at: float = 2000.5

	for species in by_species:
		var seed_id: String = str(by_species[species])
		n += 1
		empty_pack()
		at += 300.0   # a fresh flora chunk each, so no tree counts against another's room
		var spot: Vector3 = Vector3(at, 10.0, 2000.5)
		items.report_position(1, spot + Vector3(1.0, 0.0, 0.0))
		give(seed_id, 1)
		items._last_dig.clear()
		items._hoe_check_ms.clear()
		var hoe: int = HeldTool.slot_of(items, "hoe")
		items.inventory_of(1).wear[hoe] = 0
		var saplings: int = items._saplings.size()
		notes.clear()
		var planted: int = items.plant_grid(1, items.inventory_of(1), hoe, items.table.number_of(seed_id), 101, spot)

		if planted <= 0 or items._saplings.size() != saplings + 1:
			check(false, "tree %s: %s is not planted in open ground" % [species, seed_id])
			continue

		var sapling: Dictionary = items._saplings[-1]
		var home: Vector2i = Vector2i(int(sapling["chunk"][0]), int(sapling["chunk"][1]))
		var sid: int = (int(sapling["species"]) << 16) | (0xFFFF - int(sapling["slot"]))
		check(items.dynamic_tree_info(home, sid).is_empty(), "tree %s: a sapling just planted can already be felled" % species)
		clock[0] += items.SAPLING_GROWN_S + 60.0
		check(not items.dynamic_tree_info(home, sid).is_empty(), "tree %s: grown from %s it is not a tree that can be felled" % [species, seed_id])
		check(str(items._flora_by_id.get(int(sapling["species"]), {}).get("name", "")) == species, "tree %s: its seed grows a %s" % [species, str(items._flora_by_id.get(int(sapling["species"]), {}).get("name", ""))])

	return n


func _init() -> void:
	var dir: String = "user://test_every_plant"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, t): notes.append(t)
	items.send_hoe_verdict = func(_p, _k, _c, _at, _s, _why, _m): pass
	items.ground_height = func(_x, _z): return 10.0
	items.game_seconds = func(): return clock[0]
	items.season_now = func(): return season[0]
	items.rain_now = func(): return rain[0]
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "everyplant00001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items.vitals_of(1)["weight"] = 1.0e6
	items.gather_pace_ms = 0

	for tool in ["stone_hoe", "stone_knife", "stone_shovel", "stone_axe", "sickle"]:
		items.give(1, items.table.number_of(tool), 1)

	var crops: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/crops.json"))["crops"]
	var drops: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/drops.json"))
	var crops_n: int = crops_part(crops)
	var wild_n: int = wild_part(drops["seed_drops"], drops.get("harvest_yield", {}), drops.get("by_species", {}), drops.get("by_kind", {}), crops)
	var trees_n: int = trees_part(drops["trunk"]["felled_seeds"]["by_species"])
	check(crops_n >= 80 and wild_n >= 100 and trees_n >= 40, "the parts played their cases (%d crops, %d wild plants, %d tree seeds)" % [crops_n, wild_n, trees_n])
	print("%d crops grown, %d wild plants picked, %d tree seeds planted: %d checks" % [crops_n, wild_n, trees_n, checks])
	items._finish_writer()
	print("Test done: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
