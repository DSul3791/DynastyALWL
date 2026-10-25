extends SceneTree

# Fish schools (src/server/server_fish.gd) on the made-up map of test_fish_water.gd: deterministic, always on suitable water, stock conserved, salmon in autumn only, factor by distance.
#   godot --headless --path . --script res://src/worldgen/tools/test_fish_schools.gd      Prints "Test done: N pass, N fail".

const FishWater := preload("res://src/server/server_fish_water.gd")
const Fish := preload("res://src/server/server_fish.gd")

var passes: int = 0
var failures: int = 0


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1
		print("FAIL ", what)


# Same map as test_fish_water.gd: sea x < 0, brook x 100..108, river x 300..324, lake x 1000..1800, z 0..800.
func probe(x: float, z: float) -> Array:
	if x < 0.0:
		return [0.0, -(-x / 15.0), 1]

	if x >= 100.0 and x < 108.0 and z >= 0.0 and z < 800.0:
		return [10.4, 10.0, 3]

	if x >= 300.0 and x < 324.0 and z >= 0.0 and z < 800.0:
		return [12.5, 10.0, 3]

	if x >= 1000.0 and x < 1800.0 and z >= 0.0 and z < 800.0:
		return [20.0, 17.0, 2]

	return [NAN, 12.0 + x * 0.001, 0]


func _init() -> void:
	var water = FishWater.new(probe)
	var kind_fn: Callable = func(x: float, z: float) -> Dictionary: return water.water_kind_at(x, z, 0)
	var all_items: Callable = func(_s: String) -> bool: return true
	var fish = Fish.new(kind_fn, all_items)
	var again = Fish.new(kind_fn, all_items)
	var stock_fn: Callable = func(_c: Vector2i) -> int: return 9

	# Deterministic: another instance and a second call give the same schools.
	var same: bool = true
	var made: int = 0

	for cx in range(0, 15):
		for cz in range(0, 7):
			var a: Array = fish.schools(Vector2i(cx, cz), 40, "autumn", 9, 1000.0)
			var b: Array = again.schools(Vector2i(cx, cz), 40, "autumn", 9, 1000.0)
			made += a.size()
			same = same and str(a) == str(b)

	check(same and made > 0, "the same cell and day gives the same schools (%d schools)" % made)

	# Every school, over many days and times, sits on water whose kind suits its species.
	var bad: int = 0
	var seen: Dictionary = {}

	for day in range(0, 40):
		for cx in [-2, -1, 0, 2, 3, 8, 9, 12]:
			for cz in range(0, 7):
				for s in fish.schools(Vector2i(cx, cz), day, "autumn", 9, float(day) * 86400.0 + float(cz) * 5000.0):
					var kind: String = str(kind_fn.call((s["centre"] as Vector2).x, (s["centre"] as Vector2).y)["kind"])
					seen[str(s["species"])] = kind
					var ok: bool = false

					for row in fish.cfg["species_by_kind"].get(kind, []):
						ok = ok or str(row[0]) == str(s["species"])

					bad += 0 if ok else 1

	check(bad == 0, "every school and every drifted centre is on suitable water (%d wrong)" % bad)
	check(not seen.is_empty(), "schools were made on the sea, rivers and lake (%s)" % str(seen))

	# Dry cells have none.
	var dry: int = 0

	for day in range(0, 40):
		for s in fish.schools(Vector2i(3, 2), day, "autumn", 9, 0.0):
			dry += 1

	check(dry == 0, "a cell of dry land has no schools")

	# Stock conserved: the sizes never exceed the stock; no stock, no school.
	var over: int = 0

	for stock in [0, 1, 4, 9, 12]:
		for day in range(0, 20):
			for cx in [8, 9, 10]:
				var total: int = 0

				for s in fish.schools(Vector2i(cx, 2), day, "summer", stock, 0.0):
					total += int(s["size"])

				over += 1 if total > stock else 0

	check(over == 0, "school sizes never add up to more than the cell's stock")
	check(fish.schools(Vector2i(8, 2), 5, "summer", 0, 0.0).is_empty(), "a cell with no stock has no school")

	# Salmon only in autumn and only in a river; mackerel only in summer.
	var salmon_autumn: int = 0
	var salmon_other: int = 0
	var salmon_wrong_water: int = 0

	for day in range(0, 200):
		for cz in range(0, 7):
			for season in ["spring", "summer", "autumn", "winter"]:
				for s in fish.schools(Vector2i(2, cz), day, season, 9, 0.0):
					if s["species"] == "salmon":
						salmon_autumn += 1 if season == "autumn" else 0
						salmon_other += 0 if season == "autumn" else 1
						salmon_wrong_water += 0 if str(kind_fn.call((s["centre"] as Vector2).x, (s["centre"] as Vector2).y)["kind"]) == "river" else 1

	check(salmon_autumn > 0 and salmon_other == 0 and salmon_wrong_water == 0, "salmon only in autumn and only in a river (%d autumn, %d other)" % [salmon_autumn, salmon_other])

	var no_salmon = Fish.new(kind_fn, func(s: String) -> bool: return s != "salmon")
	var any_salmon: int = 0

	for day in range(0, 100):
		for cz in range(0, 7):
			for s in no_salmon.schools(Vector2i(2, cz), day, "autumn", 9, 0.0):
				any_salmon += 1 if s["species"] == "salmon" else 0

	check(any_salmon == 0, "a species with no item yet is left out")

	# Factor by distance: find a school, stand in it, near it, and far from it (still on water).
	var found: Dictionary = {}

	for day in range(0, 60):
		for s in fish.schools(Vector2i(9, 2), day, "summer", 9, 0.0):
			found = {"day": day, "s": s}
			break

		if not found.is_empty():
			break

	check(not found.is_empty(), "a lake school to measure")

	if not found.is_empty():
		var c: Vector2 = found["s"]["centre"]
		var r: float = float(found["s"]["radius"])
		var day: int = int(found["day"])
		var inside: Dictionary = fish.factor_at(c.x, c.y, day, "summer", 0.0, stock_fn)
		check(is_equal_approx(float(inside["factor"]), 1.0) and inside["species"] == found["s"]["species"], "inside the radius: factor 1.0, the school's species")
		var near: Dictionary = fish.factor_at(c.x + r * 1.5, c.y, day, "summer", 0.0, stock_fn)
		var near_ok: bool = float(near["factor"]) == 0.5 or float(near["factor"]) == 1.0      # another school may overlap
		check(near_ok, "within twice the radius: 0.5 (%.2f)" % float(near["factor"]))
		var far: Dictionary = fish.factor_at(1790.0 - fmod(c.x, 5.0), 790.0, day, "summer", 0.0, stock_fn)
		check(float(far["factor"]) <= 1.0 and bool(far["active"]), "elsewhere on the lake the factor is a number and the module is active (%.2f)" % float(far["factor"]))

	var land: Dictionary = fish.factor_at(500.0, 400.0, 3, "summer", 0.0, stock_fn)
	check(float(land["factor"]) == 1.0 and not bool(land["active"]), "on land the module has nothing to say: factor 1.0, not active")
	var none = Fish.new()
	check(float(none.factor_at(1400.0, 400.0, 3, "summer", 0.0, stock_fn)["factor"]) == 1.0, "no water kind function: factor 1.0")

	# A far point with no school within twice the radius gets the lowest factor.
	var lowest: float = 1.0

	for k in 40:
		lowest = minf(lowest, float(fish.factor_at(1100.0 + float(k) * 17.0, 20.0 + float(k) * 13.0, 7, "summer", 0.0, stock_fn)["factor"]))

	check(is_equal_approx(lowest, 0.15), "away from every school: 0.15 (lowest seen %.2f)" % lowest)

	# Cost: 17 factor lookups (one rod cast) with warm caches.
	var t0: int = Time.get_ticks_usec()

	for n in 200:
		for k in 17:
			fish.factor_at(1100.0 + float(k) * 3.0, 100.0, 7, "summer", 0.0, stock_fn)

	var per_cast_ms: float = float(Time.get_ticks_usec() - t0) / 200.0 / 1000.0
	check(per_cast_ms < 1.0, "a cast's 17 lookups cost %.3f ms (limit 1)" % per_cast_ms)
	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)
