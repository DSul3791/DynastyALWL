extends SceneTree

# Iron-nickel meteorites (Dave 21 Nov 2026: "lets have meteors about half as frequent as rocks because they have been falling for millions and
# billions of years. they break into iron chunks that count as iron ingots and can be worked or substituted directly for iron ingots. basically
# iron chunk inherits from iron ingot"; docs/design/COPPER_ROCKS.md MT-1, boulders.json meteorite_rocks). Laid on the shared ore_rocks rule at
# half the iron rocks' open-ground chance, the same by a river as away from one, with no ore body and no mountain-foot boulder; small ones are a
# loose Iron chunk, bigger ones break with any pick or the Stone Hammer into Iron chunks and stone at the plain boulder yield. An Iron chunk fills
# every need for an Iron ingot (ingredient group): recipes, building costs and repairs. Plus the client look.
#   godot --headless --path . --script res://src/worldgen/tools/test_meteorites.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const OreRockLook := preload("res://src/client/ore_rock_look.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make(dir_name: String, tool_id: String):
	var dir: String = "user://" + dir_name
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, _t): pass
	items.send_reject = func(_p, _r): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items._boulder_cfg["luck_extra"] = 0.0
	items._boulder_cfg["flint"] = {}

	if tool_id != "":
		items.peer_connected_hello(1, "meteorite01")
		items.report_position(1, Vector3(5.0, 11.5, 5.0))
		items.vitals_of(1)["weight"] = 5000.0
		items._characters["meteorite01"]["luck"] = 50   # neutral luck for the yield checks
		items._fate_rng.seed = 1517
		items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of(tool_id), 0, 1, Vector3.ZERO)

	return items


# Meteorites (or iron rocks) over cells x 0..cells-1, z 0..rows-1: [[key, pos, radius, grade, by hand, total], ...].
func lay(items, cells: int, rows: int, ore: String) -> Array:
	items._items.clear()
	var out: Array = []
	var loose: int = items.table.number_of(str(items._boulder_cfg["ore"]["items"][ore]))

	for cz in range(rows):
		for cx in range(cells):
			items._lay_out_ore_rocks(Vector2i(cx, cz), 32.0, ore)

	for id in items._items:
		var it: Dictionary = items._items[id]

		if it.has("boulder") and str(it["boulder"].get("ore", "")) == ore:
			out.append([int(it["scatter"]), it["pos"], float(it["boulder"]["radius"]), float(it["boulder"].get("grade", -1.0)), false, int(it["boulder"]["total"])])
		elif it.has("scatter") and int(it["number"]) == loose and (int(it["scatter"]) & items.ORE_KEY) != 0:
			out.append([int(it["scatter"]), it["pos"], -1.0, -1.0, true, 1])

	out.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	return out


func _init() -> void:
	var all_cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/boulders.json"))
	var met: Dictionary = all_cfg.get("ore_rocks", {}).duplicate()
	met.merge(all_cfg.get("meteorite_rocks", {}), true)
	var iron: Dictionary = all_cfg.get("ore_rocks", {}).duplicate()
	iron.merge(all_cfg.get("iron_rocks", {}), true)
	check(str(all_cfg["ore"]["items"].get("meteorite", "")) == "iron_chunk" and not (all_cfg["ore"].get("pick_only", []) as Array).has("meteorite") and not (all_cfg["ore"].get("needs_material", {}) as Dictionary).has("meteorite"), "a meteorite gives Iron chunks to any pick or the Stone Hammer")
	check(is_equal_approx(float(met["chance"]) * 2.0, float(iron["chance"])) and float(met["water_chance_coast"]) == 0.0 and float(met["water_chance_mountain"]) == 0.0 and float(met["body_reach_m"]) == 0.0 and (met["foot"] as Dictionary).is_empty(), "half as frequent as iron rocks on open ground, no more by water, no ore body, no mountain-foot boulder")
	check(int(met["slot"]) == 32 and bool(met.get("plain_yield", false)), "slots 32..39, plain boulder yield")

	# 1. A river along x 2000..2040 (shallow) on the coastal plain: meteorites lie evenly, iron rocks crowd the river.
	var w = make("test_meteorites_lay", "")
	w.water_depth_at = func(pos): return 0.5 if pos.x >= 2000.0 and pos.x < 2040.0 else 0.0
	w.water_near = func(pos, reach): return pos.x + reach >= 2000.0 and pos.x - reach < 2040.0
	w.ore_near = func(_pos, _reach, _names, _depth): return "meteorite"   # even a "body" of it changes nothing: body_reach_m 0
	var rocks: Array = lay(w, 90, 40, "meteorite")
	var land: int = 0
	var river: int = 0
	var by_hand: int = 0
	var shape_ok: bool = true
	var slots_ok: bool = true

	for r in rocks:
		var x: float = float(r[1].x)
		land += 1 if x < 1990.0 or x > 2050.0 else 0
		river += 1 if x >= 1990.0 and x < 2050.0 else 0
		var key_slot: int = int(r[0]) & 0xff
		slots_ok = slots_ok and (int(r[0]) & w.ORE_KEY) != 0 and key_slot >= 32 and key_slot < 40

		if bool(r[4]):
			by_hand += 1
			continue

		shape_ok = shape_ok and float(r[2]) >= float(met["radius_min"]) - 0.001 and float(r[2]) <= float(met["radius_max"]) + 0.001 and float(r[3]) >= float(met["grade_min"]) - 0.001 and float(r[3]) <= float(met["grade_max"]) + 0.001

	var land_per_cell: float = float(land) / (88.0 * 40.0)
	var river_per_cell: float = float(river) / (2.0 * 40.0)
	var iron_rocks: Array = lay(w, 90, 40, "iron")
	var iron_land: int = 0

	for r in iron_rocks:
		iron_land += 1 if float(r[1].x) < 1990.0 or float(r[1].x) > 2050.0 else 0

	print("meteorites: %d (%.3f a land cell, %.3f a river cell), %d by hand; iron rocks on land %d" % [rocks.size(), land_per_cell, river_per_cell, by_hand, iron_land])
	check(land_per_cell > 0.05 and land_per_cell < 0.2, "about one meteorite every 10 cells on open ground (%.3f a cell)" % land_per_cell)
	check(river_per_cell < land_per_cell * 3.0, "no more by the river than elsewhere (%.3f against %.3f)" % [river_per_cell, land_per_cell])
	check(land * 3 > iron_land and land * 3 < iron_land * 2, "about half as many as the iron rocks on open ground (%d against %d)" % [land, iron_land])
	check(by_hand > 0 and by_hand < rocks.size(), "some lie loose, the rest are meteorites to break (%d of %d)" % [by_hand, rocks.size()])
	check(shape_ok, "every meteorite to break is 40 to 70 cm across with its grade in range")
	check(slots_ok, "every meteorite key is its own (ORE_KEY, slots 32..39)")
	check(str(lay(w, 90, 40, "meteorite")) == str(rocks), "the same cells give the same meteorites every time")

	# 2. Picked up by hand: a loose one is an Iron chunk.
	var hp = make("test_meteorites_hand", "stone_hammer")
	var hand_row: Array = []

	for r in lay(hp, 40, 20, "meteorite"):
		if bool(r[4]):
			hand_row = r
			break

	var hand_id: int = 0

	for id in hp._items:
		if not hand_row.is_empty() and int(hp._items[id].get("scatter", -1)) == int(hand_row[0]):
			hand_id = id

	if hand_id != 0:
		hp.report_position(1, hp._items[hand_id]["pos"] + Vector3(0.5, 0.0, 0.0))
		hp.action(1, Net.ACT_PICKUP, hand_id, 0, 0, Vector3.ZERO)

	check(hand_id != 0 and hp.inventory_of(1).count_of(hp.table.number_of("iron_chunk")) == 1, "a small meteorite is picked up by hand as an Iron chunk")

	# 3. Broken with the Stone Hammer: Iron chunks and stone, at the plain boulder yield (a lump of metal, not a big ore rock).
	var p = make("test_meteorites_mine", "stone_hammer")
	var row: Dictionary = {"radius": 0.35, "yaw": 0.0}
	p._set_boulder_ore(row, "meteorite", p.ORE_KEY | p.BOULDER_KEY | 33)
	check(int(row["total"]) == p._boulder_stones(0.35, false) and int(row["total"]) < p._boulder_stones(0.35, true), "a meteorite holds stones at the plain yield (%d, not %d)" % [int(row["total"]), p._boulder_stones(0.35, true)])
	row["grade"] = 0.75
	p._items[900001] = {"number": 0, "count": int(row["total"]), "pos": Vector3(5.0, 11.5, 6.0), "left": 1.0e9, "scatter": p.ORE_KEY | p.BOULDER_KEY | 33, "boulder": row}
	var hammer_slot: int = 0

	for s in range(p.inventory_of(1).slot_count):
		if str(p.table.entry(p.table.id_of(p.inventory_of(1).numbers[s])).get("tool_class", "")) == "hammer":
			hammer_slot = s + 1

	for k in range(200):
		p._last_hit.clear()
		p.action(1, Net.ACT_HIT, 900001, Net.HIT_BOULDER, hammer_slot, Vector3.ZERO)

	var chunks: int = p.inventory_of(1).count_of(p.table.number_of("iron_chunk"))
	var stones: int = p.inventory_of(1).count_of(p.table.number_of("stone"))
	print("a 70 cm meteorite (grade 0.75, %d stones' worth): %d Iron chunks and %d stone" % [int(row["total"]), chunks, stones])
	check(chunks >= 3 and chunks * 3 + stones <= int(row["total"]) + 2, "the Stone Hammer breaks it into Iron chunks and some stone (%d chunks, %d stone)" % [chunks, stones])

	# 4. An Iron chunk is an Iron ingot wherever one is asked for.
	var table = ItemTableScript.load_default()
	var ingot: int = table.number_of("iron_ingot")
	var chunk: int = table.number_of("iron_chunk")
	check(chunk > 0 and int(table.entry("iron_chunk").get("number", 0)) == 1517, "Iron chunk is item 1517")
	check(table.group_members(ingot).has(chunk), "the Iron ingot group holds the Iron chunk")
	var pack = InventoryScript.new(table)
	pack.add(chunk, 3)
	check(pack.count_fill(ingot) == 3 and pack.remove_fill(ingot, 2) and pack.count_of(chunk) == 1, "three chunks count as three ingots and two are spent as ingots")

	# A real recipe that asks for Iron ingots, made with chunks only: the stand-in pack holds everything else it needs.
	var items = make("test_meteorites_craft", "stone_hammer")
	var recipe_id: String = ""

	for rid in items.recipes._by_number:
		var rec: Dictionary = items.recipes._by_number[rid]
		var asks: bool = false

		for need in rec.get("needs", []):
			asks = asks or int(need[0]) == ingot

		if asks and not bool(rec.get("retired", false)):
			recipe_id = str(rid)
			var held = InventoryScript.new(items.table)

			for need in rec.get("needs", []):
				held.add(chunk if int(need[0]) == ingot else int(need[0]), int(need[1]))

			for keep in rec.get("keeps", []):
				held.add(int(keep[0]), int(keep[1]))

			check(items.recipes.can_make(int(rid), held), "recipe %s (%s) can be made with Iron chunks in place of Iron ingots" % [str(rid), str(rec.get("name", ""))])
			break

	check(recipe_id != "", "some recipe asks for Iron ingots")

	# A repair that asks for an Iron ingot is paid with a chunk.
	var mender = make("test_meteorites_repair", "iron_pickaxe")
	var inv = mender.inventory_of(1)
	var tool_slot: int = -1

	for s in range(inv.slot_count):
		if inv.numbers[s] == mender.table.number_of("iron_pickaxe"):
			tool_slot = s

	var repair: Array = mender.table.entry("iron_pickaxe").get("repair", [])
	var asks_ingot: bool = false

	for cost in repair:
		asks_ingot = asks_ingot or str(cost[0]) == "iron_ingot"

	if tool_slot >= 0 and asks_ingot:
		for cost in repair:
			inv.add(chunk if str(cost[0]) == "iron_ingot" else mender.table.number_of(str(cost[0])), int(cost[1]))

		var station: String = str(mender.table.entry("iron_pickaxe").get("repair_station", ""))

		if station != "":
			var forge: int = mender.dev_place("%s@7,5,0,lit" % station)

			if forge > 0:
				mender._items[forge]["struct"]["owner"] = "meteorite01"
				mender._items[forge]["struct"]["lit"] = true
				mender._items[forge]["struct"]["fuel_left"] = 1.0e7

		inv.wear[tool_slot] = 50
		mender._repair(1, inv, tool_slot)
		check(inv.wear[tool_slot] == 0 and inv.count_of(chunk) == 0, "an Iron pickaxe is mended with an Iron chunk in place of its Iron ingot")
	else:
		check(false, "the Iron pickaxe has a repair that asks for an Iron ingot (slot %d)" % tool_slot)

	# 5. The client look: a dark pitted meteorite with worn bright metal and rust in the pits.
	check(OreRockLook.has_look("meteorite"), "meteorites have their own rock look")
	var src: String = str(OreRockLook.FRAGMENT.get("meteorite", ""))
	check(src.find("cells(") >= 0 and src.find("metal") >= 0 and src.find("rust") >= 0, "pits, worn metal and rust")
	print("meteorites: %d failures" % failures)
	quit(1 if failures > 0 else 0)
