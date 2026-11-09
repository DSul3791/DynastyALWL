extends SceneTree

# Plants grow thicker by water (Dave 9 Nov 2026, docs/design/spring_heads_lower_design.md 2 and 3): the shared curve (NearWater), the
# placer's water samples and W by a river, the sea and a cliff, and animals going to a ground spring first.
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

	func _init() -> void:
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

	func nearest(x: float, z: float) -> int:
		return clampi(int(round(z / spacing_m)), 0, samples - 1) * samples + clampi(int(round(x / spacing_m)), 0, samples - 1)


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
