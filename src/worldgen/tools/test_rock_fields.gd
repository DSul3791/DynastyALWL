extends SceneTree

# Rocky ground (boulders.json rock_fields, server_items _lay_out_rock_fields; Dave 26 Nov 2026: "rocks and boulders on and around mountains
# where they should be"). On made-up ground: scree at the foot of a cliff and none on its face, rocky ground above the treeline and none on
# the lowland, outcrops on hilltops, rounded rocks in shallow water and on banks and none in deep water, now and then a lone giant on the flat;
# keys of their own that never move the older boulders, worked rocks stay worked, nothing laid beside a build, loose stones never on a face.
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

	for r in rocks_of(rows):
		var x: float = (r[1] as Vector3).x
		foot += 1 if x >= -24.0 and x < 0.0 else 0
		face += 1 if x > 1.0 and x < 59.0 else 0
		far_out += 1 if x < -40.0 else 0

	print("rock_fields: cliff: %d rocks at its foot, %d on its face, %d out on the valley floor; %.2f ms a cell" % [foot, face, far_out, per_cell_ms])
	check(foot >= 40, "scree lies along the foot of a cliff (%d rocks in 20 cells)" % foot)
	check(face == 0, "no rock sits on the cliff face (%d)" % face)
	check(far_out <= foot / 10, "the scree thins out away from the wall (%d far out against %d at the foot)" % [far_out, foot])
	check(per_cell_ms < CELL_BUDGET_MS, "a cell under a cliff lays out in under %.0f ms on average (%.2f)" % [CELL_BUDGET_MS, per_cell_ms])
	var big_foot: float = 0.0

	for r in rocks_of(rows):
		if (int(r[0]) & 0xff) != at_cliff.FIELD_ERRATIC_SLOT:   # not a lone giant
			big_foot = maxf(big_foot, float(r[2]))

	check(big_foot > 0.9 and big_foot <= 1.5 * 1.0001, "scree rocks come up to 3 m across (largest radius %.2f)" % big_foot)
	var loose_on_face: int = 0

	for r in rows:
		if float(r[2]) == 0.0 and (r[1] as Vector3).x > 1.0 and (r[1] as Vector3).x < 59.0:
			loose_on_face += 1

	check(loose_on_face == 0, "no loose stone lies on the face (%d)" % loose_on_face)
	check(rows.size() > rocks_of(rows).size(), "the rocky ground has loose stones to pick up too (%d of %d)" % [rows.size() - rocks_of(rows).size(), rows.size()])

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

	# Nothing beside a build: a foundation at the foot of the cliff keeps its ground clear.
	var built = make("user://test_rock_fields_built", cliff)
	var house: Vector3 = Vector3(-12.0, 100.0, 80.0)
	built._items[900001] = {"number": 0, "count": 1, "pos": house, "left": 1.0e9, "struct": {"kind": "foundation"}}
	var near_house: int = 0

	for r in rocks_of(lay(built, -2, 2, 0, 19)):
		near_house += 1 if Vector2((r[1] as Vector3).x - house.x, (r[1] as Vector3).z - house.z).length() < float(r[2]) + 2.0 else 0

	check(near_house == 0, "no rock is laid within 2 m of anything built (%d)" % near_house)

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
	check(high_rocks >= 500, "ground above the treeline is rocky (%d rocks in 100 cells)" % high_rocks)
	check(low_small == 0 and low_rows.size() == low_giants, "flat lowland gets no rocky ground (%d small rocks, %d loose stones)" % [low_small, low_rows.size() - low_giants])
	check(low_giants >= 1 and low_giants <= 20, "a lone giant boulder now and then on the open flat (%d in 400 cells)" % low_giants)

	# Hilltops: rolling hills every 64 m, their tops at the middle of every other cell.
	var hills: Callable = func(x: float, z: float) -> float: return 100.0 + 5.0 * (cos(TAU * (x - 16.0) / 64.0) + cos(TAU * (z - 16.0) / 64.0))
	var hilly = make("user://test_rock_fields_hills", hills)
	var on_top: int = 0
	var hill_rows: Array = rocks_of(lay(hilly, 0, 11, 0, 11))

	for r in hill_rows:
		var p: Vector3 = r[1]
		on_top += 1 if Vector2(fposmod(p.x - 16.0 + 32.0, 64.0) - 32.0, fposmod(p.z - 16.0 + 32.0, 64.0) - 32.0).length() <= 23.0 else 0   # within a top's own cell

	check(on_top >= 6 and on_top * 2 >= hill_rows.size(), "outcrops lie on the hilltops (%d of %d rocks near a top)" % [on_top, hill_rows.size()])

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

	# density_scale 0: nothing (the measure job's off switch).
	var off = make("user://test_rock_fields_off", cliff)
	off._boulder_cfg["rock_fields"]["density_scale"] = 0.0
	check(lay(off, -2, 2, 0, 19).is_empty(), "density_scale 0 lays no rocky ground")

	print("rock fields tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
