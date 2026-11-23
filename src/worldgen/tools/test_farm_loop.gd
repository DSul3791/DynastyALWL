extends SceneTree

# The whole farming loop as a player plays it, with the seed amounts of 23 Nov 2026 (Dave: "you should get plenty of seeds"; a seed weighs one
# real seed; a planting spot takes a pinch, crops.json sow_seeds), and a server restart after every stage: nothing lost, nothing doubled.
#   1. gather wild seed from tall grass: hundreds of seeds, one pack slot, a few grams;
#   2. till a 2 x 2 patch with the hoe and sow it in one Plant grid click: four pinches taken, the player told how many;
#   3. grow it through wet days to ripe; 4. harvest with the sickle: grain, straw and plenty of seed back;
#   5. replant the patch from the harvest; 6. store the grain and seed in a Storage barrel; 7. grind flour at a quern;
#   and a restart between each, comparing the pack, the barrel and the beds before and after.
#   godot --headless --path . --script res://src/worldgen/tools/test_farm_loop.gd

const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")
const CraftHand := preload("res://src/worldgen/tools/craft_hand.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const CarryRules := preload("res://src/shared/carry_rules.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const DIR := "user://test_farm_loop"

var failures: int = 0
var items
var clock: Array = [0.0]
var season: Array = ["autumn"]
var rain: Array = [0.0]
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
	it.ground_height = func(_x, _z): return 10.0
	it.game_seconds = func(): return clock[0]
	it.season_now = func(): return season[0]
	it.rain_now = func(): return rain[0]
	it.setup(ItemTableScript.load_default(), DIR)
	it.peer_connected_hello(1, "farmloop0000001")
	it.report_position(1, Vector3(0.0, 10.0, 0.0))
	it.gather_pace_ms = 0
	return it


func n(id: String) -> int:
	return items.table.number_of(id)


func count(id: String) -> int:
	return items.inventory_of(1).count_of(n(id))


func slots_of(id: String) -> int:
	var inv = items.inventory_of(1)
	var used: int = 0

	for s in inv.slot_count:
		used += 1 if inv.numbers[s] == n(id) else 0

	return used


func give(id: String, k: int) -> void:
	var left: int = k

	while left > 0:   # an admin give is at most 100 at a time
		items.action(1, Net.ACT_ADMIN_GIVE, n(id), 0, mini(left, 100), Vector3.ZERO)
		left -= 100


func pinch(crop: String) -> int:
	return int(items._crop_table()[crop]["sow_seeds"])


# Everything the farmer has, for a before and after: the pack's counts, the crops, the barrel's counts.
func snapshot(barrel: int = 0) -> Dictionary:
	var pack: Dictionary = {}
	var inv = items.inventory_of(1)

	for s in inv.slot_count:
		if inv.numbers[s] != 0:
			pack[items.table.id_of(inv.numbers[s])] = int(pack.get(items.table.id_of(inv.numbers[s]), 0)) + int(inv.counts[s])

	var crops: Dictionary = {}

	for key in items._crops:
		crops[key] = [str(items._crops[key]["crop"]), snappedf(float(items._crops[key]["age"]), 0.01), int(items._crops[key]["wet"])]

	var box: Dictionary = {}
	var found: int = 0

	for id in items._items:   # found by kind: a world id is handed out afresh when the world loads
		if barrel != 0 and items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == "storage_barrel":
			found = id

	if found != 0:
		var chest = items._chest_of(1, found)

		for s in chest.slot_count:
			if chest.numbers[s] != 0:
				box[items.table.id_of(chest.numbers[s])] = int(box.get(items.table.id_of(chest.numbers[s]), 0)) + int(chest.counts[s])

	return {"pack": pack, "crops": crops, "box": box}


func restart(stage: String, barrel: int = 0) -> void:
	var before: Dictionary = snapshot(barrel)
	items._dirty = true
	items.save()
	items._finish_writer()
	items = make()
	var after: Dictionary = snapshot(barrel)
	check(after == before, "%s: a server restart keeps the pack, the crops and the barrel exactly (%s)" % [stage, "same" if after == before else "%s -> %s" % [str(before), str(after)]])


func patch_beds() -> Array:
	var out: Array = []

	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == "tilled_bed":
			out.append(id)

	return out


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	items = make()
	give("stone_hoe", 1)
	give("bronze_sickle", 1)
	var hoe: int = HeldTool.slot_of(items, "hoe")
	check(hoe >= 0, "the farmer holds a hoe on the hotbar")

	# 1. Wild seed: tall grass in autumn gives every grain's seed by the pinch.
	items.report_position(1, Vector3(500.0, 70.0, 500.0))

	for k in range(3):
		items._last_gather.clear()
		items.gather(1, "tall_grass", "plant", "0,0,%d" % (700 + k), 700 + k, Vector3(501.0, 70.0, 500.0))

	var wheat: int = count("wheat_seeds")
	var kg: float = CarryRules.weight_of("wheat_seeds", items._carry_cfg) * float(wheat)
	check(wheat >= 4 * pinch("wheat"), "three tall grass picks give enough wheat seed for four spots and more (%d seeds, %d a spot)" % [wheat, pinch("wheat")])
	check(slots_of("wheat_seeds") == 1, "all of it in one pack slot (%d slots)" % slots_of("wheat_seeds"))
	check(kg < 0.1, "and it weighs %s, a few grams" % CarryRules.weight_text(kg))
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	restart("after gathering")

	# 2. Till a 2 x 2 patch and sow it in one click of the Plant grid.
	season[0] = "spring"

	for p in [Vector3(-0.5, 10.0, -0.5), Vector3(0.5, 10.0, -0.5), Vector3(-0.5, 10.0, 0.5), Vector3(0.5, 10.0, 0.5)]:
		items._last_dig.clear()
		items.inventory_of(1).wear[hoe] = 0
		items.till(1, items.inventory_of(1), p, hoe)

	check(patch_beds().size() == 4, "the hoe tills four square metres (%d beds)" % patch_beds().size())
	var seed_before: int = count("wheat_seeds")
	notes.clear()
	items._last_dig.clear()
	var planted: int = items.plant_grid(1, items.inventory_of(1), hoe, n("wheat_seeds"), 202, Vector3(0.0, 10.0, 0.0))
	check(planted == 4 and items._crops.size() == 4, "one click of a 2 x 2 grid sows the four beds (%d planted, %d crops)" % [planted, items._crops.size()])
	check(seed_before - count("wheat_seeds") == 4 * pinch("wheat"), "it takes four pinches of seed (%d)" % (seed_before - count("wheat_seeds")))
	check(notes.has("Sowed 4 spots with %d wheat seeds." % (4 * pinch("wheat"))), "and says so (%s)" % str(notes))
	restart("after sowing")

	# Fewer seeds than a pinch (a pack saved before pinches, build 9257, holds a few): they still sow one spot, all of them used.
	var spare: int = count("wheat_seeds")
	items.inventory_of(1).remove(n("wheat_seeds"), spare)
	give("wheat_seeds", 8)
	items._crops.clear()
	notes.clear()
	items._last_dig.clear()
	check(items.plant_grid(1, items.inventory_of(1), hoe, n("wheat_seeds"), 202, Vector3(0.0, 10.0, 0.0)) == 1 and count("wheat_seeds") == 0 and items._crops.size() == 1, "8 seeds, fewer than a pinch, still sow one spot and are used up (%d crops)" % items._crops.size())
	check(notes.has("Sowed 1 spot with 8 wheat seeds: no more to sow."), "and the player is told (%s)" % str(notes))
	notes.clear()
	items._last_dig.clear()
	check(items.plant_grid(1, items.inventory_of(1), hoe, n("wheat_seeds"), 202, Vector3(0.0, 10.0, 0.0)) == 0 and notes.has("You have none to plant."), "with none left nothing is sown and the player is told (%s)" % str(notes))
	give("wheat_seeds", spare)
	items._crops.clear()
	items._last_dig.clear()
	items.plant_grid(1, items.inventory_of(1), hoe, n("wheat_seeds"), 202, Vector3(0.0, 10.0, 0.0))
	check(items._crops.size() == 4, "the patch is sown again")

	# 3. Grow: rain every day until ripe, with a restart half way.
	rain[0] = 0.8
	var grow: int = int(items._crop_table()["wheat"]["grow_days"])

	for d in range(int(grow * 0.5)):
		clock[0] += 86400.0
		items._crops_tick()

	restart("half grown")

	for d in range(grow):
		clock[0] += 86400.0
		items._crops_tick()

	var ripe: int = 0

	for key in items._crops:
		ripe += 1 if items.crop_stage(items._crops[key]) == 3 else 0

	check(ripe == 4, "after its grow days with rain the four beds are ripe (%d)" % ripe)
	restart("ripe")

	# 4. Harvest with the sickle in the pack: grain, straw and seed back by the pinch.
	var grain_before: int = count("wheat")
	var straw_before: int = count("straw")
	seed_before = count("wheat_seeds")
	var back: Array = items._crop_table()["wheat"]["seeds_back"][1]

	for bed in patch_beds():
		items.harvest(1, items.inventory_of(1), bed)

	check(items._crops.is_empty(), "the four beds are harvested")
	check(count("wheat") - grain_before == 4 * int(items._crop_table()["wheat"]["yields"][0][1]), "the full grain (%d)" % (count("wheat") - grain_before))
	check(count("straw") > straw_before, "and straw (%d)" % (count("straw") - straw_before))
	var seed_back: int = count("wheat_seeds") - seed_before
	check(seed_back >= int(4.0 * float(back[0]) * 2.0 / 3.0) and seed_back <= int(4.0 * float(back[1]) * 1.5), "and plenty of seed back: %d (%d to %d a bed)" % [seed_back, int(back[0]), int(back[1])])
	check(seed_back >= 12 * pinch("wheat"), "enough to sow the patch three times over (%d spots)" % int(float(seed_back) / float(pinch("wheat"))))
	restart("harvested")

	# 5. Replant from the harvest.
	seed_before = count("wheat_seeds")
	items._last_dig.clear()
	items.inventory_of(1).wear[hoe] = 0
	check(items.plant_grid(1, items.inventory_of(1), hoe, n("wheat_seeds"), 202, Vector3(0.0, 10.0, 0.0)) == 4 and seed_before - count("wheat_seeds") == 4 * pinch("wheat"), "the harvest's seed sows the patch again")
	restart("replanted")

	# 6. Store the grain and the seed in a Storage barrel.
	var barrel: int = items.dev_place("storage_barrel@3,0,0")
	items._items[barrel]["pos"] = Vector3(3.0, 10.0, 0.0)
	items.report_position(1, Vector3(2.0, 10.0, 0.0))
	var seeds_now: int = count("wheat_seeds")
	var grain_now: int = count("wheat")
	items.action(1, Net.ACT_CHEST_PUT, items.inventory_of(1).numbers.find(n("wheat_seeds")), barrel, seeds_now, Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_PUT, items.inventory_of(1).numbers.find(n("wheat")), barrel, grain_now - 3, Vector3.ZERO)
	var box: Dictionary = snapshot(barrel)["box"]
	check(int(box.get("wheat_seeds", 0)) == seeds_now and count("wheat_seeds") == 0, "all %d seeds go into the barrel in one move" % seeds_now)
	check(int(box.get("wheat", 0)) == grain_now - 3 and count("wheat") == 3, "the grain too, keeping 3 for the quern")
	restart("stored", barrel)

	# 7. Grind flour at a quern from the kept grain.
	var quern: int = items.dev_place("quern@1,0,1")
	items._items[quern]["pos"] = Vector3(1.0, 10.0, 1.0)
	var recipes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/recipes.json"))["recipes"]
	var flour_recipe: int = int(recipes["flour_from_wheat"]["number"])
	items.action(1, Net.ACT_CRAFT_QUEUE, flour_recipe, 0, 1, CraftHand.at(items, 1, flour_recipe))
	items._craft_tick(float(recipes["flour_from_wheat"]["craft_s"]) + 1.0)
	check(count("flour") == int(recipes["flour_from_wheat"]["gives"][1]) and count("wheat") == 0, "the quern grinds the three grain into flour (%d flour)" % count("flour"))
	restart("ground", barrel)

	print("test_farm_loop: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)
