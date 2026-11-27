extends SceneTree

# Rocky ground (boulders.json rock_fields, server_items _lay_out_rock_fields; Dave 26 Nov 2026: "rocks and boulders on and around mountains
# where they should be"). On made-up ground: scree at the foot of a cliff and on its face only crags, tilted to it, rocky ground above the treeline and none on
# the lowland, outcrops on hilltops, rounded rocks in shallow water and on banks and none in deep water, now and then a lone giant on the flat;
# keys of their own that never move the older boulders, worked rocks stay worked, nothing laid beside a build, a fire or a player, loose
# stones never on a face, nothing on the low coastal flats; far from every player a cell is taken up whole and comes back the same.
# Prints rock_fields: lines with counts and the layout's cost per cell.
#   godot --headless --path . --script res://src/worldgen/tools/test_rock_fields.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")

const CELL_M := 32.0
const CELL_BUDGET_MS := 8.0   # a rocky cell's whole layout (every part), on average: the scatter tick allows 40 ms for up to 8 cells

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make(dir: String, ground: Callable):
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, _t): pass
	items.setup(ItemTableScript.load_default(), dir)
	items.ground_height = ground
	return items


# Lays out cells (x0..x1, z0..z1) and returns the rows of the rocky ground's keys: [[key, pos, radius or 0 for a loose stone], ...].
func lay(items, x0: int, x1: int, z0: int, z1: int) -> Array:
	var cfg: Dictionary = items._drops.get("ground_scatter", {})

	for cx in range(x0, x1 + 1):
		for cz in range(z0, z1 + 1):
			items._lay_out_cell(Vector2i(cx, cz), CELL_M, cfg)

	return field_rows(items)


func field_rows(items) -> Array:
	var out: Array = []

	for id in items._items:
		var it: Dictionary = items._items[id]

		if it.has("scatter") and (int(it["scatter"]) & items.FIELD_KEY) != 0:
			out.append([int(it["scatter"]), it["pos"], float(it["boulder"]["radius"]) if it.has("boulder") else 0.0])

	return out


func rocks_of(rows: Array) -> Array:
	return rows.filter(func(r): return float(r[2]) > 0.0)


func _init() -> void:
	# A cliff: a valley floor at 100 m west of x 0, a face rising 1.5 m a metre to 190 m at x 60, a plateau beyond.
	var cliff: Callable = func(x: float, _z: float) -> float: return 100.0 + clampf(x, 0.0, 60.0) * 1.5
	var at_cliff = make("user://test_rock_fields_cliff", cliff)
	var started: int = Time.get_ticks_usec()
	var rows: Array = lay(at_cliff, -2, 2, 0, 19)
	var per_cell_ms: float = float(Time.get_ticks_usec() - started) / 1000.0 / 100.0
	var foot: int = 0
	var face: int = 0
	var far_out: int = 0

	var crags: int = 0
	var crag_bad: int = 0
	var crag_off_face: int = 0
	var crag_share: float = float(at_cliff._boulder_cfg["rock_fields"]["crag"].get("sink_share", 0.3))
	var rest_rise: float = float(at_cliff._boulder_cfg["rock_fields"].get("steepest", 0.7))   # the steepest ground a loose rock rests on (RF-8)

	for id in at_cliff._items:
		var it: Dictionary = at_cliff._items[id]

		if not it.has("boulder") or (int(it["scatter"]) & at_cliff.FIELD_KEY) == 0:
			continue

		var p: Vector3 = it["pos"]
		var tilt: Array = (it["boulder"] as Dictionary).get("tilt", [])

		if tilt.is_empty():
			foot += 1 if p.x >= -24.0 and p.x < 0.0 else 0
			face += 1 if p.x > 1.0 and p.x < 59.0 else 0
			far_out += 1 if p.x < -40.0 else 0
			continue

		# A crag: only where the ground is steeper than a loose rock lies on (its satellites on gentler ground are scree), leaning with the face
		# (it falls 1.5 a metre toward -x), set into it by crag.sink_share of its radius, no apron.
		crags += 1
		crag_off_face += 0 if p.x > -1.0 and p.x < 61.0 else 1
		var r_c: float = float(it["boulder"]["radius"])
		var fall_here: float = (float(cliff.call(p.x + 1.0, p.z)) - float(cliff.call(p.x - 1.0, p.z))) * 0.5   # 1.5 on the face, less within a metre of its edges
		crag_bad += 0 if fall_here > rest_rise and absf(float(tilt[0]) - fall_here) < 0.011 and absf(float(tilt[1])) < 0.02 and not (it["boulder"] as Dictionary).has("skirt") and absf(p.y - (float(cliff.call(p.x, p.z)) - crag_share * r_c)) < 0.02 else 1

	print("rock_fields: cliff: %d rocks at its foot, %d loose rocks and %d crags on its face, %d out on the valley floor; %.2f ms a cell" % [foot, face, crags, far_out, per_cell_ms])
	check(foot >= 20, "scree lies along the foot of a cliff (%d rocks in 20 cells)" % foot)
	check(face == 0, "no loose rock sits on the cliff face (%d)" % face)
	check(crags >= 20 and crag_off_face == 0, "crags stand out of the face, and only there (%d, %d off it)" % [crags, crag_off_face])
	check(crag_bad == 0, "each crag stands on ground steeper than %.1f a metre, leans with it, is set into it by %.1f of its radius and has no apron (%d not)" % [rest_rise, crag_share, crag_bad])
	check(far_out * 10 <= foot, "the scree thins out away from the wall (%d far out against %d at the foot)" % [far_out, foot])
	check(per_cell_ms < CELL_BUDGET_MS, "a cell under a cliff lays out in under %.0f ms on average (%.2f)" % [CELL_BUDGET_MS, per_cell_ms])
	var big_foot: float = 0.0

	for r in rocks_of(rows):
		if (int(r[0]) & 0xff) != at_cliff.FIELD_ERRATIC_SLOT and (r[1] as Vector3).x < 0.0:   # not a lone giant, nor a crag
			big_foot = maxf(big_foot, float(r[2]))

	var foot_most: float = float((at_cliff._boulder_cfg["rock_fields"]["radius"]["foot"] as Array)[1])
	check(big_foot > 1.5 and big_foot <= foot_most * 1.0001, "foot band cores come up to %.0f m across (largest radius %.2f)" % [foot_most * 2.0, big_foot])
	var loose_on_face: int = 0

	for r in rows:
		if float(r[2]) == 0.0 and (r[1] as Vector3).x > 1.0 and (r[1] as Vector3).x < 59.0:
			loose_on_face += 1

	check(loose_on_face == 0, "no loose stone lies on the face (%d)" % loose_on_face)
	check(rows.size() > rocks_of(rows).size(), "the rocky ground has loose stones to pick up too (%d of %d)" % [rows.size() - rocks_of(rows).size(), rows.size()])

	# Clusters: cores with satellites round them; every big mountain rock carries its gravel apron ("skirt": fall x, fall z, sink), and no
	# rock is bigger than the floor lookups reach (FLOOR_ROWS_REACH_M).
	var satellites: int = 0
	var skirt_ok: bool = true
	var biggest: float = 0.0

	for id in at_cliff._items:
		var it: Dictionary = at_cliff._items[id]

		if not it.has("boulder") or (int(it["scatter"]) & at_cliff.FIELD_KEY) == 0:
			continue

		var slot: int = int(it["scatter"]) & 0xff
		var rock_r: float = float(it["boulder"]["radius"])
		biggest = maxf(biggest, rock_r)
		satellites += 1 if slot < at_cliff.FIELD_WATER_FIRST and slot % at_cliff.FIELD_CLUSTER_SLOTS != 0 else 0
		var wants_skirt: bool = slot < at_cliff.FIELD_WATER_FIRST and rock_r >= 0.8 and not (it["boulder"] as Dictionary).has("tilt")
		skirt_ok = skirt_ok and ((it["boulder"] as Dictionary).has("skirt") == wants_skirt)

	check(satellites > 0, "the cliff foot's rocks come in clusters: smaller rocks round a core (%d)" % satellites)
	check(skirt_ok, "every mountain rock of 0.8 m or more that is not a crag, and only those, carries its gravel apron")
	var cfg_radius: Dictionary = at_cliff._boulder_cfg["rock_fields"]["radius"]
	var cfg_most: float = 0.0

	for kind in cfg_radius:
		cfg_most = maxf(cfg_most, float((cfg_radius[kind] as Array)[1]))

	check(cfg_most <= at_cliff.FLOOR_ROWS_REACH_M and biggest <= at_cliff.FLOOR_ROWS_REACH_M, "no rock is bigger than the floor lookups reach (%.1f, laid %.2f, reach %.1f)" % [cfg_most, biggest, at_cliff.FLOOR_ROWS_REACH_M])

	# Keys: every rock has the rocky ground's key and a boulder's, all different; laid again the same; the older boulders unchanged.
	var keys: Dictionary = {}
	var keys_ok: bool = true

	for r in rows:
		var key: int = int(r[0])
		keys_ok = keys_ok and not keys.has(key) and ((key & at_cliff.BOULDER_KEY) != 0) == (float(r[2]) > 0.0)
		keys[key] = true

	check(keys_ok, "every rock and stone of the rocky ground has a key of its own (%d)" % keys.size())
	var again = make("user://test_rock_fields_again", cliff)
	check(str(lay(again, -2, 2, 0, 19)) == str(rows), "the same cells lay out the same rocks in the same places")
	var old_rows: Callable = func(items) -> String:
		var out: Array = []

		for id in items._items:
			var it: Dictionary = items._items[id]

			if it.has("scatter") and (int(it["scatter"]) & items.FIELD_KEY) == 0:
				out.append([int(it["scatter"]), it["pos"], int(it["number"])])

		out.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
		return str(out)
	var without = make("user://test_rock_fields_without", cliff)
	without._boulder_cfg["rock_fields"]["enabled"] = false
	lay(without, -2, 2, 0, 19)
	check(field_rows(without).is_empty(), "rock_fields off lays none")
	check(old_rows.call(without) == old_rows.call(at_cliff), "the older boulders, ore rocks and loose stones lie where they did")

	# A worked rock stays worked, a broken one stays gone.
	var keys_by_size: Array = rocks_of(rows)
	keys_by_size.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	var worked: int = int(keys_by_size[0][0])
	var broken: int = int(keys_by_size[1][0])
	var relaid = make("user://test_rock_fields_worked", cliff)
	relaid._boulder_left[worked] = 5
	relaid._boulder_left[broken] = 0
	lay(relaid, -2, 2, 0, 19)
	var worked_count: int = -1
	var broken_there: bool = false

	for id in relaid._items:
		var it: Dictionary = relaid._items[id]
		worked_count = int(it["count"]) if int(it.get("scatter", -1)) == worked else worked_count
		broken_there = broken_there or int(it.get("scatter", -1)) == broken

	check(worked_count == 5 and not broken_there, "a worked rock comes back as worked (%d left) and a broken one stays gone" % worked_count)

	# Nothing beside a build: a foundation on the spot of a rock from the first layout clears it and the ground round it, loose stones too.
	var built = make("user://test_rock_fields_built", cliff)
	var house: Vector3 = (rocks_of(rows)[0] as Array)[1]
	var house_key: int = int((rocks_of(rows)[0] as Array)[0])
	built._items[900001] = {"number": 0, "count": 1, "pos": house, "left": 1.0e9, "struct": {"kind": "foundation"}}
	var near_house: int = 0
	var rebuilt: Array = lay(built, -2, 2, 0, 19)

	for r in rebuilt:
		near_house += 1 if Vector2((r[1] as Vector3).x - house.x, (r[1] as Vector3).z - house.z).length() < float(r[2]) + 4.0 else 0

	check(not rebuilt.any(func(r): return int(r[0]) == house_key), "the rock that lay where the foundation now stands is not laid")
	check(near_house == 0, "no rock or stone is laid within 4 m of anything built (%d)" % near_house)

	# No two rocks of one cell overlap.
	var overlaps: int = 0
	var all_rocks: Array = rocks_of(rows)

	for i in range(all_rocks.size()):
		for j in range(i + 1, all_rocks.size()):
			var a: Vector3 = all_rocks[i][1]
			var b: Vector3 = all_rocks[j][1]
			if (int(all_rocks[i][0]) >> 8) != (int(all_rocks[j][0]) >> 8):
				continue   # other cells' rocks are not looked at (the layout order would change them)

			overlaps += 1 if Vector2(a.x - b.x, a.z - b.z).length() < float(all_rocks[i][2]) + float(all_rocks[j][2]) - 0.001 else 0

	check(overlaps == 0, "no two rocks of a cell overlap (%d pairs)" % overlaps)

	# Above the treeline: rocky ground; the lowland below it: none of the mountain kinds.
	var high = make("user://test_rock_fields_high", func(_x, _z): return 700.0)
	var high_rocks: int = rocks_of(lay(high, 0, 9, 0, 9)).size()
	var low = make("user://test_rock_fields_low", func(_x, _z): return 300.0)
	var low_rows: Array = lay(low, 0, 19, 0, 19)
	var low_small: int = 0
	var low_giants: int = 0

	for r in rocks_of(low_rows):
		if float(r[2]) >= 1.5:
			low_giants += 1
		else:
			low_small += 1

	print("rock_fields: %d rocks in 100 cells above the treeline; on 400 flat lowland cells %d small and %d lone giants" % [high_rocks, low_small, low_giants])
	check(high_rocks >= 200, "ground above the treeline is rocky (%d rocks in 100 cells)" % high_rocks)
	check(low_small == 0 and low_rows.size() == low_giants, "flat lowland gets no rocky ground (%d small rocks, %d loose stones)" % [low_small, low_rows.size() - low_giants])
	check(low_giants >= 1 and low_giants <= 20, "a lone giant boulder now and then on the open flat (%d in 400 cells)" % low_giants)

	# The low coastal flats (the ground most tests stand on, 10 m): no rocky ground at all, not even a lone giant.
	var coast = make("user://test_rock_fields_coast", func(_x, _z): return 10.0)
	var coast_rows: Array = lay(coast, -10, 9, -10, 9)
	check(coast_rows.is_empty(), "the low coastal flats get no rocks or stones (%d in 400 cells)" % coast_rows.size())

	# Nothing on or beside a fire or a player standing there as the cell is laid out again.
	var camp = make("user://test_rock_fields_camp", cliff)
	var fire_at: Vector3 = (rocks_of(rows)[2] as Array)[1]
	var stand_at: Vector3 = (rocks_of(rows)[3] as Array)[1]
	camp._items[900002] = {"number": 0, "count": 1, "pos": fire_at, "left": 1.0e9, "fire": {"state": 9}}
	camp._peer_pos[7] = stand_at
	var near_camp: int = 0

	for r in lay(camp, -2, 2, 0, 19):
		for at in [fire_at, stand_at]:
			near_camp += 1 if Vector2((r[1] as Vector3).x - at.x, (r[1] as Vector3).z - at.z).length() < float(r[2]) + 4.0 else 0

	check(near_camp == 0, "no rock or stone is laid on or within 4 m of a fire or a player (%d)" % near_camp)

	# Far from every player a cell is taken up whole, with its rocks and stones; back near it, the same rows come back.
	var walk = make("user://test_rock_fields_walk", cliff)
	walk.peer_connected_hello(1, "rockwalk00001")
	walk.report_position(1, Vector3(0.0, 100.0, 300.0))
	var settle: Callable = func() -> void:
		var before: int = -1
		var guard: int = 0

		while walk._cells_done.size() != before and guard < 50:
			before = walk._cells_done.size()
			walk._scatter_around_players()
			walk._sync_world_items()
			guard += 1
	settle.call()
	var walked: Array = field_rows(walk)
	walk.report_position(1, Vector3(2000.0, 190.0, 300.0))
	settle.call()
	var gone_near: int = 0

	for r in field_rows(walk):
		gone_near += 1 if (r[1] as Vector3).x < 500.0 else 0

	var cells_near: int = 0

	for cell in walk._cells_done:
		cells_near += 1 if float(cell.x) * CELL_M < 500.0 else 0

	check(walked.size() > 0 and gone_near == 0 and cells_near == 0, "a cell far from every player is taken up with all it held (%d rows near before, %d after, %d cells still held)" % [walked.size(), gone_near, cells_near])
	walk.report_position(1, Vector3(0.0, 100.0, 300.0))
	settle.call()
	var back: Array = field_rows(walk).filter(func(r): return (r[1] as Vector3).x < 500.0)
	var keys_of: Callable = func(list: Array) -> Array:
		var out: Array = list.map(func(r): return int(r[0]))
		out.sort()
		return out
	check(keys_of.call(back) == keys_of.call(walked.filter(func(r): return (r[1] as Vector3).x < 500.0)), "back near it, the same rocks and stones are laid again (%d)" % back.size())

	# Hilltops: rolling hills every 64 m, their tops at the middle of every other cell.
	var hills: Callable = func(x: float, z: float) -> float: return 100.0 + 5.0 * (cos(TAU * (x - 16.0) / 64.0) + cos(TAU * (z - 16.0) / 64.0))
	var hilly = make("user://test_rock_fields_hills", hills)
	var on_top: int = 0
	var hill_rows: Array = rocks_of(lay(hilly, 0, 11, 0, 11))

	for r in hill_rows:
		var p: Vector3 = r[1]
		on_top += 1 if Vector2(fposmod(p.x - 16.0 + 32.0, 64.0) - 32.0, fposmod(p.z - 16.0 + 32.0, 64.0) - 32.0).length() <= 12.0 else 0   # on a crown, not down its sides

	check(on_top >= 6 and on_top * 2 >= hill_rows.size(), "outcrops lie on the hilltops' crowns (%d of %d rocks within 12 m of a top)" % [on_top, hill_rows.size()])

	# Water: a river 6 m wide at x 100..106, shallow in its edges (0.3 m) and deep in its middle (2 m).
	var river = make("user://test_rock_fields_river", func(_x, _z): return 50.0)
	river.water_near = func(pos, reach): return pos.x + reach >= 100.0 and pos.x - reach <= 106.0
	river.water_depth_at = func(pos): return 0.0 if pos.x < 100.0 or pos.x > 106.0 else (2.0 if pos.x > 101.5 and pos.x < 104.5 else 0.3)
	var by_river: Array = rocks_of(lay(river, 2, 4, 0, 19))
	var in_deep: int = 0
	var off_bank: int = 0
	var river_big: float = 0.0

	for r in by_river:
		var x: float = (r[1] as Vector3).x

		if float(r[2]) >= 1.5:
			continue   # a lone giant, kept off the water by its own rule

		in_deep += 1 if x > 101.5 and x < 104.5 else 0
		off_bank += 1 if x < 97.0 or x > 109.0 else 0
		river_big = maxf(river_big, float(r[2]))

	check(by_river.size() >= 10, "rounded rocks lie in the shallows and on the banks (%d)" % by_river.size())
	check(in_deep == 0 and off_bank == 0, "none in deep water (%d) or away from the water (%d)" % [in_deep, off_bank])
	check(river_big <= 0.7001, "river rocks stay small to medium (largest radius %.2f)" % river_big)

	# On a slope a rock is set into the ground by sink_share of the drop across it; on flat ground it lies on the ground.
	var slope_fn: Callable = func(x: float, _z: float) -> float: return 700.0 + 0.5 * x
	var sloped = make("user://test_rock_fields_slope", slope_fn)
	var share: float = float(sloped._boulder_cfg["rock_fields"].get("sink_share", 0.6))
	var sink_bad: int = 0
	var sloped_rocks: Array = rocks_of(lay(sloped, 0, 4, 0, 4))

	for r in sloped_rocks:
		var p: Vector3 = r[1]
		sink_bad += 0 if absf(p.y - (float(slope_fn.call(p.x, p.z)) - 0.5 * float(r[2]) * share)) < 0.02 else 1

	check(sloped_rocks.size() > 0 and sink_bad == 0, "rocks on a 0.5 slope are set into it by %.1f of the drop across them (%d of %d not)" % [share, sink_bad, sloped_rocks.size()])
	var flat_bad: int = 0

	for r in rocks_of(field_rows(high)):
		flat_bad += 0 if absf((r[1] as Vector3).y - 700.0) < 0.02 else 1

	check(flat_bad == 0, "on flat ground a rock lies on the ground (%d not)" % flat_bad)
	check(rest_rise <= 0.71, "no loose rock is laid on ground steeper than loose rock rests on, about 35 degrees (steepest %.2f; Dave 27 Nov 2026: placed where they have already settled)" % rest_rise)

	# density_scale 0: nothing (the measure job's off switch).
	var off = make("user://test_rock_fields_off", cliff)
	off._boulder_cfg["rock_fields"]["density_scale"] = 0.0
	check(lay(off, -2, 2, 0, 19).is_empty(), "density_scale 0 lays no rocky ground")

	print("rock fields tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
