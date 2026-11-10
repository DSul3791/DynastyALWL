extends SceneTree

# Plants grow thicker by water (Dave 9 Nov 2026, docs/design/spring_heads_lower_design.md 2 and 3): the shared curve (NearWater), the
# placer's water samples and W by a river, the sea and a cliff, and animals going to a ground spring first. Waterways as green corridors (Dave
# 10 Nov 2026, docs/design/riparian_growth_design.md): record brooks count as water, and the bank shrubs thin out from the water's edge.
#   godot --headless --path . --script res://src/worldgen/tools/test_flora_near_water.gd

const NearWater := preload("res://src/shared/near_water_growth.gd")
const Placer := preload("res://src/worldgen/runtime/flora_placer.gd")
const AnimalsScript := preload("res://src/stream/server_animals.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


# A 10 x 10 tile of 8 m samples from (0, 0): a river down column 5 (x 40) at level 1.0, the sea in column 0.
class FakeTile:
	var x0: float = 0.0
	var z0: float = 0.0
	var spacing_m: float = 8.0
	var samples: int = 10
	var water_class: PackedByteArray = PackedByteArray()
	var water_surface: PackedFloat32Array = PackedFloat32Array()
	var biome: PackedByteArray = PackedByteArray()
	var flora_seed: int = 4242
	var brooks: PackedInt32Array = PackedInt32Array()

	func _init() -> void:
		biome.resize(samples * samples)
		water_class.resize(samples * samples)
		water_surface.resize(samples * samples)
		water_surface.fill(NAN)

		for j in samples:
			water_class[j * samples + 5] = 3
			water_surface[j * samples + 5] = 1.0
			water_class[j * samples] = 1
			water_surface[j * samples] = 0.0

	func sim_snapshot() -> PackedFloat32Array:
		return PackedFloat32Array()

	func drink_samples() -> PackedInt32Array:
		return brooks

	# The river bed (x 36 to 44) lies under the water; the banks are 0.5 m over it.
	func height_at(x: float, _z: float) -> float:
		return 0.5 if absf(x - 40.0) < 4.0 else 1.5

	func nearest(x: float, z: float) -> int:
		return clampi(int(round(z / spacing_m)), 0, samples - 1) * samples + clampi(int(round(x / spacing_m)), 0, samples - 1)


# The placer with every spot's ground fine except under the water: the riparian pass alone is under test.
class BankPlacer extends "res://src/worldgen/runtime/flora_placer.gd":
	func _ground_ok(item: Dictionary, data, _k: int, x: float, z: float, _in_belt: bool = false, _near_water: float = 0.0) -> float:
		if item["kind"] == KIND_SHRUB and _under_water(data, x, z):
			return NAN

		return data.height_at(x, z)


class FakeGround:
	var cliff_x: float = 1000.0

	func surface_height(x: float, _z: float) -> float:
		return 9.0 if x > cliff_x else 1.5


func _init() -> void:
	check(is_equal_approx(NearWater.growth_near_water(0.0), 1.0) and is_equal_approx(NearWater.growth_near_water(3.0), 0.5), "W 1 at the edge, 0.5 at 3 m")
	check(NearWater.growth_near_water(6.0) == 0.0 and NearWater.growth_near_water(INF) == 0.0, "normal growth from 6 m, and with no water near")
	check(NearWater.growth_near_water(0.0, 3.5) == 0.0, "a bank 3.5 m over the water is not watered")

	var placer = Placer.new()
	var ground = FakeGround.new()
	placer.generator = ground
	placer.chunk_m = 32.0
	var tile = FakeTile.new()
	var wet: Dictionary = placer._wet_samples(tile, Vector2(8.0, 8.0))
	check(wet.has(Vector2i(5, 3)) and not wet.has(Vector2i(0, 3)) and not wet.has(Vector2i(3, 3)), "the river's samples count, the sea's do not (%d)" % wet.size())
	var cache: Dictionary = {}
	var edge: float = placer._wetness(tile, wet, 37.0, 25.0, cache)       # cell centre x 37, 3 m from the sample, under its 4 m half-width
	var mid: float = placer._wetness(tile, wet, 47.0, 25.0, cache)        # cell centre (47, 25): 7.07 m from the sample (40, 24), 3.07 m past its edge
	var far: float = placer._wetness(tile, wet, 51.0, 25.0, cache)        # x 51: 11 m from the centre, 7 m past the edge
	check(is_equal_approx(edge, 1.0) and absf(mid - (1.0 - (sqrt(50.0) - 4.0) / 6.0)) < 0.001 and far == 0.0, "W by the river: 1 at the bank, about 0.49 at 3 m, none at 7 m (%.2f %.2f %.2f)" % [edge, mid, far])
	check(placer._wetness(tile, {}, 37.0, 25.0, {}) == 0.0, "a chunk with no fresh water: W 0")
	ground.cliff_x = 30.0
	check(placer._wetness(tile, wet, 47.0, 25.0, {}) == 0.0, "a cliff top 8 m over the river stays as it was")

	_riparian_checks()

	# Animals: a ground spring within reach comes first; the stand is 4 m out toward where the animal comes from.
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return 10.0
	a.water_level = func(_x, _z): return NAN
	a.blocked = func(_x, _z): return false
	a.player_positions = func(): return []
	a.player_stances = func(): return []
	a.hour_now = func(): return 6.0
	a.weather_ahead = func(_h): return {}
	a.setup()
	var found: Array = a.drink_spot(Vector3(0.0, 10.0, 0.0), 300.0)
	check(found.is_empty(), "no water, no spring: nowhere to drink")
	a.springs_near = func(_p, _r): return PackedVector3Array([Vector3(200.0, 12.0, 0.0), Vector3(100.0, 11.0, 0.0)])
	found = a.drink_spot(Vector3(0.0, 10.0, 50.0), 300.0)   # another 50 m cell: not the cached search
	check(found.size() == 3 and (found[1] as Vector3).is_equal_approx(Vector3(100.0, 11.0, 0.0)), "the nearest spring is the water (%s)" % str(found))
	check(found.size() == 3 and absf(Vector2(found[0].x - 100.0, found[0].z).length() - 4.0) < 0.01 and found[0].z > 0.0, "standing 4 m out on the side it came from")
	var dc: Dictionary = a._drink_cfg()
	check(float(dc.get("spring_stand_m", 0.0)) == 4.0 and (dc.get("spring_graze_s", []) as Array).size() == 2, "animals.json drink: spring_stand_m and spring_graze_s")

	print("test_flora_near_water: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)


func _riparian_checks() -> void:
	var cfg: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/water/riparian.json"))
	check(typeof(cfg) == TYPE_DICTIONARY and (cfg["shrub_by_m"] as Array).size() >= 3 and (cfg["species"] as Array).size() >= 3, "data/water/riparian.json: the curve and the species")
	var curve: Array = cfg["shrub_by_m"]
	var reach: float = float(cfg["reach_m"])
	check(Placer._curve_at(curve, reach) == 0.0 and Placer._curve_at(curve, reach + 5.0) == 0.0, "no bank shrubs from reach_m (%.0f m)" % reach)
	check(Placer._curve_at(curve, 2.0) > Placer._curve_at(curve, 6.0) and Placer._curve_at(curve, 6.0) > Placer._curve_at(curve, 10.0) and Placer._curve_at(curve, 10.0) > 0.0, "thick on the bank, thinning with every metre out")
	check(is_equal_approx(Placer._curve_at([[0.0, 0.0], [4.0, 1.0]], 1.0), 0.25) and Placer._curve_at([[0.0, 0.3], [4.0, 1.0]], -1.0) == 0.3, "the curve: straight lines between points, the end values beyond")

	var placer = BankPlacer.new()
	placer.generator = FakeGround.new()
	placer.chunk_m = 80.0
	var shrub: Dictionary = {"id": 7, "name": "elder", "kind": Placer.KIND_SHRUB, "per_biome": PackedFloat32Array([1.0]), "height_min": 1.0, "height_max": 2.0, "patch": {"spacing_m": 1.0}}
	var rules: Dictionary = (cfg as Dictionary).duplicate(true)
	rules["chosen"] = [[shrub, 1.0]]
	placer._riparian = rules
	var tile = FakeTile.new()
	tile.brooks = PackedInt32Array([2 * 10 + 9, 3 * 10 + 9, 4 * 10 + 9, 5 * 10 + 9, 6 * 10 + 9, 7 * 10 + 9])   # a record brook down x 72, z 16 to 56
	var brooks: Dictionary = {}
	var wet: Dictionary = placer._wet_samples(tile, Vector2.ZERO, brooks)
	check(wet.has(Vector2i(9, 4)) and brooks.has(Vector2i(9, 4)) and not brooks.has(Vector2i(5, 4)) and is_equal_approx(float(wet[Vector2i(9, 4)]), 1.5), "a record brook's samples are water at the ground; the river is not a brook")
	var found: Array = []
	placer._riparian_shrubs(Vector2i.ZERO, Vector2.ZERO, tile, wet, brooks, found)
	var by_band: Array = [0, 0, 0, 0]   # river banks 0-4 m, 4-8 m, 8-12 m, 12-16 m (west side, x 20 to 36, z 0 to 80, away from the brook)
	var bad: Array = []

	for f in found:
		var x: float = f[3]
		var number: int = f[2]

		if number < Placer.RIPARIAN_BASE or number >= Placer.SPRING_BASE or int(f[0]) != Placer.TIER_SHRUB or int(f[1]) != 7:
			bad.append("number %d" % number)

		if absf(x - 40.0) < 4.0:
			bad.append("in the river at x %.1f" % x)

		if absf(x - 72.0) < 1.0 and float(f[5]) > 18.0 and float(f[5]) < 54.0:
			bad.append("in the brook at x %.1f" % x)

		if x < 36.0 and x >= 20.0:
			by_band[mini(int((36.0 - x) / 4.0), 3)] += 1

		if x < 18.0:
			bad.append("%.1f m from the river" % (36.0 - x))

	check(bad.is_empty(), "every bank shrub has its own number, none in the river or the brook, none past 16 m (%s)" % str(bad.slice(0, 4)))
	check(by_band[0] > by_band[1] and by_band[1] > by_band[2] and by_band[3] < by_band[1], "the shrubs thin out with distance from the water (%s, about 46 24 9 3 expected)" % str(by_band))
	check(by_band[0] >= 30, "the bank is thick with them (%d in 4 m x 80 m)" % by_band[0])
	var near_brook: int = found.filter(func(f): return absf(float(f[3]) - 72.0) < 6.0 and float(f[5]) > 20.0 and float(f[5]) < 50.0).size()
	check(near_brook >= 10, "a record brook's banks get shrubs too (%d)" % near_brook)
	var again: Array = []
	placer._riparian_shrubs(Vector2i.ZERO, Vector2.ZERO, tile, wet, brooks, again)
	check(str(again) == str(found), "the same chunk places the same shrubs")
	var none: Array = []
	placer._riparian_shrubs(Vector2i.ZERO, Vector2.ZERO, tile, {}, {}, none)
	check(none.is_empty(), "no fresh water near: no bank shrubs")
