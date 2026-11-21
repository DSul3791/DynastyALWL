extends SceneTree

# Copper, tin and iron rocks (Dave 16-17 Nov 2026, his photos; one shared rule since 21 Nov 2026, iron commoner on it since the same day;
# docs/design/COPPER_ROCKS.md). All three ores: a few
# anywhere on land, many more on river beds, in shallow water and along shores, none in deep water, more and bigger toward the mountains and
# fewer and smaller toward the sea (never none), very many over a body of their own ore, and now and then a big boulder at the foot of a
# mountain. A share of the sizes (hand_share) is loose ore picked up by hand; bigger ones are boulder rows with their own grade (share of their
# pieces that are ore). The layout is the same every time and its keys never land on the cell's boulders. Plus the client mesh.
#   godot --headless --path . --script res://src/worldgen/tools/test_copper_rocks.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
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
		items.peer_connected_hello(1, "copperrock01")
		items.report_position(1, Vector3(5.0, 11.5, 5.0))
		items.vitals_of(1)["weight"] = 5000.0
		items._characters["copperrock01"]["luck"] = 50   # a new character's luck is rolled 0..100 and nudges every ore piece (fate); the yield checks need it neutral
		items._fate_rng.seed = 1702   # and the same fate stream every run
		items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of(tool_id), 0, 1, Vector3.ZERO)

	return items


# Copper (or tin, or iron) rocks laid out over cells x 0..cells-1, z 0..rows-1: [[key, pos, radius, grade, by hand], ...], a loose ore picked up by
# hand with radius and grade -1; the boulders of the cells are laid too.
func lay(items, cells: int, rows: int, ore: String = "copper") -> Array:
	items._items.clear()
	var out: Array = []
	var loose: int = items.table.number_of(ore + "_ore")

	for cz in range(rows):
		for cx in range(cells):
			items._lay_out_boulders(Vector2i(cx, cz), 32.0)
			items._lay_out_ore_rocks(Vector2i(cx, cz), 32.0, "copper")
			items._lay_out_ore_rocks(Vector2i(cx, cz), 32.0, "tin")
			items._lay_out_ore_rocks(Vector2i(cx, cz), 32.0, "iron")

	for id in items._items:
		var it: Dictionary = items._items[id]

		if it.has("boulder") and str(it["boulder"].get("ore", "")) == ore:
			out.append([int(it["scatter"]), it["pos"], float(it["boulder"]["radius"]), float(it["boulder"].get("grade", -1.0)), false])
		elif it.has("scatter") and int(it["number"]) == loose and (int(it["scatter"]) & items.ORE_KEY) != 0:
			out.append([int(it["scatter"]), it["pos"], -1.0, -1.0, true])

	out.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	return out


func _init() -> void:
	var all_cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/boulders.json"))
	var cfg: Dictionary = all_cfg.get("ore_rocks", {}).duplicate()
	cfg.merge(all_cfg.get("copper_rocks", {}), true)
	check(not cfg.is_empty() and float(cfg.get("water_chance_coast", 0.0)) > float(cfg.get("chance", 1.0)) * 5.0, "boulders.json ships copper and tin rocks, far commoner by water than on dry land even by the sea")
	check(float(cfg.get("water_chance_mountain", 0.0)) > float(cfg.get("water_chance_coast", 1.0)) and float(cfg.get("size_coast", 1.0)) < 1.0, "more and bigger toward the mountains")
	check(all_cfg.get("tin_rocks", {}).keys().all(func(k): return k in ["note", "slot", "grade_min", "grade_max"]) and all_cfg.get("copper_rocks", {}).keys().all(func(k): return k in ["note", "slot", "grade_min", "grade_max"]), "copper and tin share one placement rule (only slot and grade are their own)")
	var iron_cfg: Dictionary = all_cfg.get("ore_rocks", {}).duplicate()
	iron_cfg.merge(all_cfg.get("iron_rocks", {}), true)
	check(int(all_cfg.get("iron_rocks", {}).get("slot", 0)) == 24 and float(iron_cfg["chance"]) > float(cfg["chance"]) and float(iron_cfg["water_chance_coast"]) > float(cfg["water_chance_coast"]) and float(iron_cfg["water_chance_mountain"]) > float(cfg["water_chance_mountain"]), "iron rocks share the rule but are commoner than copper everywhere (Dave 21 Nov 2026: \"iron should be a common thing to find a long river bed\"), slots 24..31")
	var ore_cfg: Dictionary = {"copper": cfg, "tin": all_cfg.get("tin_rocks", {}), "iron": iron_cfg}

	# 1. Land, shore, river bed and deep water. Flat ground at 310 m (under the mountains: full size); a river along x 2000..2040: shallow (0.5 m)
	# from 2000 to 2020, deep (3 m) from 2020 to 2040; its dry banks are the bank_reach_m beside it.
	var w = make("test_copper_rocks_lay", "")
	w.ground_height = func(_x, _z): return 310.0
	w.water_depth_at = func(pos): return 0.5 if pos.x >= 2000.0 and pos.x < 2020.0 else (3.0 if pos.x >= 2020.0 and pos.x < 2040.0 else 0.0)
	w.water_near = func(pos, reach): return pos.x + reach >= 2000.0 and pos.x - reach < 2040.0
	var rocks: Array = lay(w, 80, 40)
	var land: int = 0
	var shore: int = 0
	var deep: int = 0
	var sizes_ok: bool = true
	var grades_ok: bool = true
	var keys_ok: bool = true
	var lo_grade: float = 1.0
	var hi_grade: float = 0.0
	var small: int = 0
	var big: int = 0

	var by_hand: int = 0
	var hand_keys_ok: bool = true

	for r in rocks:
		var x: float = float(r[1].x)
		land += 1 if x < 1990.0 or x > 2050.0 else 0
		shore += 1 if (x >= 1990.0 and x < 2020.0) or (x >= 2040.0 and x <= 2050.0) else 0
		deep += 1 if x >= 2020.0 and x < 2040.0 else 0

		if bool(r[4]):
			by_hand += 1
			hand_keys_ok = hand_keys_ok and (int(r[0]) & 0xff) >= 8 and (int(r[0]) & 0xff) < 16 and (int(r[0]) & w.BOULDER_KEY) == 0
			continue

		sizes_ok = sizes_ok and float(r[2]) >= float(cfg["radius_min"]) - 0.001 and float(r[2]) <= float(cfg["radius_max"]) + 0.001
		grades_ok = grades_ok and float(r[3]) >= float(cfg["grade_min"]) - 0.001 and float(r[3]) <= float(cfg["grade_max"]) + 0.001
		keys_ok = keys_ok and (int(r[0]) & 15) >= w.COPPER_ROCK_FIRST
		lo_grade = minf(lo_grade, float(r[3]))
		hi_grade = maxf(hi_grade, float(r[3]))
		small += 1 if float(r[2]) < 0.45 else 0
		big += 1 if float(r[2]) > 0.7 else 0

	# Land: 3200 cells less the river strip; the river strip is 2 cells wide (64 m) over 40 rows, of which 40 m take rocks.
	var land_per_cell: float = float(land) / (78.0 * 40.0)
	var shore_per_cell: float = float(shore) / 40.0
	print("copper rocks: %d in all, %d on land (%.3f a cell), %d at the river (%.2f per 32 m of river), %d in deep water, sizes %d small %d big, grades %.2f..%.2f" % [rocks.size(), land, land_per_cell, shore, shore_per_cell, deep, small, big, lo_grade, hi_grade])
	check(land > 0 and land_per_cell < 0.2, "a few copper rocks are strewn over dry land (%d, %.3f a cell)" % [land, land_per_cell])
	check(shore_per_cell > land_per_cell * 5.0, "far more on the river bed and its banks (%.2f per 32 m of river against %.3f a land cell)" % [shore_per_cell, land_per_cell])
	check(deep == 0, "none in deep water (%d)" % deep)
	check(sizes_ok and by_hand * 2 > big and by_hand > 0 and big > 0 and small > 0, "a share of the sizes lies loose to pick up by hand, bigger ones are rocks to break (%d by hand, %d small rocks, %d big)" % [by_hand, small, big])
	check(hand_keys_ok, "a loose copper rock's key is its own (ORE_KEY, slots 8..15)")
	check(grades_ok and hi_grade - lo_grade > 0.2, "every rock has its own grade in range (%.2f..%.2f)" % [lo_grade, hi_grade])
	check(keys_ok, "copper rock keys sit after the cell's boulders (low bits from COPPER_ROCK_FIRST)")
	# Picked up by hand: E on a loose copper rock gives Copper ore, and it stays gone when the cell is laid out again.
	var hp = make("test_copper_rocks_hand", "stone_hammer")
	hp.water_depth_at = w.water_depth_at
	hp.water_near = w.water_near
	var hand_row: Array = []

	for r in lay(hp, 80, 40):
		if bool(r[4]):
			hand_row = r
			break

	var hand_id: int = 0

	for id in hp._items:
		if int(hp._items[id].get("scatter", -1)) == (int(hand_row[0]) if not hand_row.is_empty() else -2):
			hand_id = id

	if hand_id != 0:
		hp.report_position(1, hp._items[hand_id]["pos"] + Vector3(0.5, 0.0, 0.0))
		hp.action(1, Net.ACT_PICKUP, hand_id, 0, 0, Vector3.ZERO)

	var picked: int = hp.inventory_of(1).count_of(hp.table.number_of("copper_ore"))
	var again: bool = false

	for r in lay(hp, 80, 40):
		again = again or int(r[0]) == int(hand_row[0])

	check(hand_id != 0 and picked == 1 and not again, "a small copper rock is picked up by hand as Copper ore and stays taken (%d)" % picked)
	check(str(lay(w, 80, 40)) == str(rocks), "the same cells give the same copper rocks every time")

	# 2. The foot of a mountain: flat to x 1000, then a 1 in 1 slope. With the chance at 1, the big boulders lie only on the flat within
	# reach_m of the slope, never out on the plain or on the slope itself.
	var m = make("test_copper_rocks_foot", "")
	m._boulder_cfg["ore_rocks"]["chance"] = 0.0
	m._boulder_cfg["ore_rocks"]["water_chance_coast"] = 0.0
	m._boulder_cfg["ore_rocks"]["water_chance_mountain"] = 0.0
	m._boulder_cfg["ore_rocks"]["foot"]["chance"] = 1.0
	m.ground_height = func(x, _z): return 10.0 + maxf(x - 1000.0, 0.0)
	var feet: Array = lay(m, 40, 20)
	var foot_ok: bool = not feet.is_empty()
	var foot_reach: float = float(cfg["foot"]["reach_m"])

	for r in feet:
		foot_ok = foot_ok and float(r[1].x) < 1000.0 and float(r[1].x) > 1000.0 - foot_reach and float(r[2]) >= float(cfg["foot"]["radius_min"]) - 0.001 and (int(r[0]) & 15) == 15

	check(foot_ok, "big copper boulders lie at the mountain's foot only (%d, radius %s)" % [feet.size(), str(feet.map(func(r): return snappedf(float(r[2]), 0.01)))])

	# 3. Geology outcrops: a boulder by a copper body is a copper rock too, with its own grade.
	var g = make("test_copper_rocks_outcrop", "")
	g._boulder_cfg["ore_rocks"]["body_reach_m"] = 0.0   # only the slope's own boulders here: the body's ore rocks are part 6
	g._boulder_cfg["ore_rocks"]["chance"] = 0.0
	g._boulder_cfg["copper_rocks"] = {}
	g._boulder_cfg["copper_rocks"]["grade_min"] = 0.2
	g._boulder_cfg["copper_rocks"]["grade_max"] = 0.6
	g._boulder_cfg["ore"]["boulder_share"] = 1.0
	g._boulder_cfg["max_chance"] = 1.0
	g._boulder_cfg["min_slope"] = 0.0
	g.ground_height = func(x, _z): return 10.0 + x * 0.3   # boulders lie only where the ground rises
	g.ore_near = func(_pos, _reach, _names, _depth): return "copper"
	var outcrops: Array = lay(g, 6, 1)
	var graded: bool = not outcrops.is_empty()

	for r in outcrops:
		graded = graded and float(r[3]) >= 0.2 and float(r[3]) <= 0.6

	check(graded, "copper outcrop boulders of the geology carry a grade (%d)" % outcrops.size())
	# And iron outcrops since iron_rocks (Dave 21 Nov 2026): a grade in iron's range and the 0.5 to 2 m size, in place of piece_share.
	g._boulder_cfg["iron_rocks"]["chance"] = 0.0
	g._boulder_cfg["iron_rocks"]["water_chance_coast"] = 0.0
	g._boulder_cfg["iron_rocks"]["water_chance_mountain"] = 0.0
	g.ore_near = func(_pos, _reach, _names, _depth): return "iron"
	var iron_out: Array = lay(g, 6, 1, "iron")
	var iron_graded: bool = not iron_out.is_empty()

	for r in iron_out:
		iron_graded = iron_graded and not bool(r[4]) and float(r[3]) >= float(iron_cfg["grade_min"]) - 0.001 and float(r[3]) <= float(iron_cfg["grade_max"]) + 0.001 and float(r[2]) <= float(iron_cfg["radius_max"]) + 0.001 and float(r[2]) >= float(iron_cfg["radius_min"]) - 0.001

	check(iron_graded, "iron outcrop boulders of the geology carry an iron grade and the shared size range (%d)" % iron_out.size())

	# 4. Mining: the copper that comes out follows the rock's grade.
	var got: Array = []

	for grade in [0.2, 0.6]:
		var p = make("test_copper_rocks_mine_%d" % int(grade * 10.0), "stone_pickaxe")
		p._items[900001] = {"number": 0, "count": 400, "pos": Vector3(5.0, 11.5, 6.0), "left": 1.0e9, "scatter": p.BOULDER_KEY | 9, "boulder": {"radius": 0.3, "yaw": 0.0, "total": 400, "ore": "copper", "grade": grade}}
		var slot: int = 0

		for s in range(p.inventory_of(1).slot_count):
			if str(p.table.entry(p.table.id_of(p.inventory_of(1).numbers[s])).get("tool_class", "")) == "pick":
				slot = s + 1

		for k in range(200):
			p._last_hit.clear()
			p.action(1, Net.ACT_HIT, 900001, Net.HIT_BOULDER, slot, Vector3.ZERO)

		var ore: int = p.inventory_of(1).count_of(p.table.number_of("copper_ore"))
		var stone: int = p.inventory_of(1).count_of(p.table.number_of("stone"))
		got.append([ore, ore + stone])

	print("mined: grade 0.2 gave %d ore of %d pieces, grade 0.6 gave %d of %d" % [got[0][0], got[0][1], got[1][0], got[1][1]])
	check(got[0][1] > 100 and got[1][1] > 100 and got[1][0] > got[0][0] * 2, "a richer rock gives more copper (%d against %d)" % [got[1][0], got[0][0]])
	# Ore by weight (boulders PLAN.md 3c, 19 Nov 2026): a 1.5 kg ore piece takes 3 stones of 0.5 kg out of the rock, so the grade is the share of the rock's weight.
	# At grade 0.2 a piece is ore about 1 roll in 13 (p = g / (3 (1 - g) + g)), so 200 rolls give about 15 +- 4 ore; the bound sits at about 3 sd
	# so the unseeded luck roll does not fail it 1 run in 50 (gate review PR #1322).
	var rate_low: float = float(got[0][0] * 3) / float(maxi(got[0][1] + got[0][0] * 2, 1))
	check(rate_low > 0.06 and rate_low < 0.4, "a grade 0.2 rock gives about a fifth of its weight as copper (%.2f)" % rate_low)

	# 5. The client mesh: three lumpy shapes about 1 m across, flat underneath, wider than tall.
	var box_ok: bool = true

	for v in OreRockLook.VARIANTS:
		var mesh: ArrayMesh = OreRockLook.mesh_for(float(v))
		var box: AABB = mesh.get_aabb()
		box_ok = box_ok and mesh.get_surface_count() == 1 and box.size.x > 0.6 and box.size.x < 1.3 and box.size.y < box.size.x and box.size.y > 0.3

	check(box_ok and OreRockLook.mesh_for(0.0) != OreRockLook.mesh_for(1.0), "the copper rock meshes are lumpy rocks about 1 m across, and differ")
	check(OreRockLook.has_look("copper") and OreRockLook.has_look("tin") and OreRockLook.has_look("iron") and not OreRockLook.has_look("coal"), "copper, tin and iron rocks have their own looks (iron: Dave 19 Nov 2026), coal keeps the outcrop one")
	var iron_src: String = str(OreRockLook.FRAGMENT["iron"])
	check(iron_src.find("drip") >= 0 and iron_src.find("world_normal.y") >= 0 and iron_src.find("line_col") >= 0, "iron rocks carry lines all over and rust streaks down their steep sides")
	var view_src: String = FileAccess.get_file_as_string("res://src/client/inventory_view.gd")
	check(view_src.find("\t\"iron\": [Color(") < 0, "the old outcrop tint for iron is gone (decision 61)")

	# 6. One rule for both (Dave 21 Nov 2026): a river along x 2000..2040 (shallow), no ore body near it. On the coastal plain (ground at 10 m)
	# both copper and tin lie there, fewer and smaller than by the same river under the mountains (ground at 310 m).
	var by_height: Dictionary = {}

	for ground_m in [10.0, 310.0]:
		var rv = make("test_copper_rocks_river_%d" % int(ground_m), "")
		rv._boulder_cfg["ore"]["boulder_share"] = 0.0   # the plain boulders are not outcrops here
		rv.water_depth_at = func(pos): return 0.5 if pos.x >= 2000.0 and pos.x < 2040.0 else 0.0
		rv.water_near = func(pos, reach): return pos.x + reach >= 2000.0 and pos.x - reach < 2040.0
		rv.ore_near = func(_pos, _reach, _names, _depth): return ""
		rv.ground_height = func(_x, _z): return ground_m

		for ore in ["copper", "tin", "iron"]:
			var at_river: int = 0
			var broken: int = 0
			var radius_sum: float = 0.0
			var grade_ok: bool = true
			var slots_ok: bool = true
			var lo: float = float(ore_cfg[ore]["grade_min"]) - 0.001
			var hi: float = float(ore_cfg[ore]["grade_max"]) + 0.001
			var slot_lo: int = int(ore_cfg[ore]["slot"])

			for r in lay(rv, 90, 40, ore):
				if float(r[1].x) >= 1990.0 and float(r[1].x) < 2050.0:
					at_river += 1

				var key_slot: int = (int(r[0]) & 0xff) if (int(r[0]) & rv.ORE_KEY) != 0 else (int(r[0]) & 15)   # copper boulders keep the boulder form: a 4-bit slot
				slots_ok = slots_ok and key_slot >= slot_lo and key_slot < slot_lo + 8

				if not bool(r[4]):
					broken += 1
					radius_sum += float(r[2])
					grade_ok = grade_ok and float(r[3]) >= lo and float(r[3]) <= hi

			by_height["%s %d" % [ore, int(ground_m)]] = [at_river, radius_sum / maxf(float(broken), 1.0), broken, grade_ok, slots_ok]

	print("by the river (count, mean radius of rocks to break, rocks to break): %s" % str(by_height))

	for ore in ["copper", "tin", "iron"]:
		var coast: Array = by_height["%s 10" % ore]
		var hills: Array = by_height["%s 310" % ore]
		check(int(coast[0]) > 10, "%s lies along a river on the coastal plain too, with no %s body near (%d per 40 cells of river)" % [ore, ore, int(coast[0])])
		check(int(hills[0]) * 2 > int(coast[0]) * 3, "%s is more abundant by the river under the mountains (%d against %d by the sea)" % [ore, int(hills[0]), int(coast[0])])
		check(float(hills[1]) > float(coast[1]) + 0.1 and int(hills[2]) > int(coast[2]), "%s rocks are bigger under the mountains (mean radius %.2f against %.2f)" % [ore, float(hills[1]), float(coast[1])])
		check(bool(coast[3]) and bool(hills[3]), "every %s rock to break has its grade in range" % ore)
		check(bool(coast[4]) and bool(hills[4]), "every %s rock and loose piece keeps its own slots" % ore)

	for ground_m in [10, 310]:
		var iron_n: int = int(by_height["iron %d" % ground_m][0])
		var copper_n: int = int(by_height["copper %d" % ground_m][0])
		check(iron_n > copper_n, "iron is commoner than copper along the river at %d m (%d against %d)" % [ground_m, iron_n, copper_n])

	# 7. Over a body of its own ore (x under 1000, tin only), very many tin rocks on dry land far from any water; copper there stays the thin
	# land scatter.
	var bd = make("test_copper_rocks_body", "")
	bd._boulder_cfg["ore"]["boulder_share"] = 0.0
	bd.water_depth_at = func(_pos): return 0.0
	bd.water_near = func(_pos, _reach): return false
	bd.ore_near = func(pos, _reach, names, _depth): return "tin" if pos.x < 1000.0 and names.has("tin") else ""
	var tin_over: int = 0
	var tin_off: int = 0
	var copper_over: int = 0

	for r in lay(bd, 60, 20, "tin"):
		tin_over += 1 if float(r[1].x) < 960.0 else 0
		tin_off += 1 if float(r[1].x) > 1060.0 else 0

	for r in lay(bd, 60, 20, "copper"):
		copper_over += 1 if float(r[1].x) < 960.0 else 0

	var body_cells: float = 30.0 * 20.0
	print("over a tin body: %d tin (%.2f a cell), %d copper; off it %d tin" % [tin_over, float(tin_over) / body_cells, copper_over, tin_off])
	check(float(tin_over) / body_cells > 2.0, "very many tin rocks over a tin body (%.2f a cell)" % (float(tin_over) / body_cells))
	check(float(tin_off) / (28.0 * 20.0) < 0.2 and tin_off > 0, "off it only the thin land scatter, but some (%d)" % tin_off)
	check(copper_over * 10 < tin_over, "a tin body does not raise copper (%d copper against %d tin)" % [copper_over, tin_over])
	check(str(lay(bd, 60, 20, "tin")) == str(lay(bd, 60, 20, "tin")), "the same cells give the same tin every time")
	print("copper rocks: %d failures" % failures)
	quit(1 if failures > 0 else 0)
