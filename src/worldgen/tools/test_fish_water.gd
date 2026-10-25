extends SceneTree

# Fishing water kinds (src/server/server_fish_water.gd), on a made-up map: sea at several depths, a thin and a wide river, a big lake, a small pond, land.
#   godot --headless --path . --script res://src/worldgen/tools/test_fish_water.gd      Prints "Test done: N pass, N fail".

const FishWater := preload("res://src/server/server_fish_water.gd")

var passes: int = 0
var failures: int = 0
var now: int = 0
var dug: bool = false


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1
		print("FAIL ", what)


# x < 0 sea (sea floor falls with -x: 3 m at -45, 10 m at -200, 40 m at -600), a 1-cell brook along x=100..108, a 3-cell river along x=300..324,
# a lake (100 x 100 cells) at x 1000..1800, a pond (3 x 3 cells) at x 3000..3024, dry land elsewhere. [surface, ground, baked class]
func probe(x: float, z: float) -> Array:
	if x < 0.0:
		return [0.0, -(-x / 15.0), 1]

	if x >= 100.0 and x < 108.0 and z >= 0.0 and z < 800.0:
		return [10.4, 10.0, 3]       # 0.4 m deep, 8 m wide

	if x >= 300.0 and x < 324.0 and z >= 0.0 and z < 800.0:
		return [12.5, 10.0, 3]       # 2.5 m deep, 24 m wide

	if x >= 1000.0 and x < 1800.0 and z >= 0.0 and z < 800.0:
		return [20.0, 17.0, 2]

	if x >= 3000.0 and x < 3024.0 and z >= 0.0 and z < 24.0:
		return [30.0, 29.0, 2]

	if dug and x >= 5000.0 and x < 5016.0 and z >= 0.0 and z < 16.0:
		return [41.0, 40.0, 0]       # a hole someone dug and the rain filled

	return [NAN, 12.0 + x * 0.001, 0]


func _init() -> void:
	var fw = FishWater.new(probe)

	for spec in [[-45.0, "sea_shallow", 3.0], [-200.0, "sea_mid", 13.0], [-600.0, "sea_deep", 40.0]]:
		var at: Dictionary = fw.water_kind_at(float(spec[0]), 50.0, now)
		check(at["kind"] == spec[1] and absf(float(at["depth"]) - float(spec[2])) < 6.0, "x %.0f is %s (%s, %.1f m)" % [float(spec[0]), spec[1], at["kind"], float(at["depth"])])

	check(fw.water_kind_at(-40.0, 50.0, now)["kind"] == "sea_shallow", "3 m of sea is shallow")
	check(fw.water_kind_at(100.5, 400.0, now)["kind"] == "brook", "a one-cell shallow river is a brook")
	check(fw.water_kind_at(312.0, 400.0, now)["kind"] == "river", "a wide deep river is a river")
	check(fw.water_kind_at(1400.0, 400.0, now)["kind"] == "lake", "a big baked lake is a lake")
	check(fw.water_kind_at(3012.0, 12.0, now)["kind"] == "pond", "a small baked lake is a pond")
	check(fw.water_kind_at(500.0, 400.0, now)["kind"] == "" and fw.water_kind_at(500.0, 400.0, now)["depth"] == 0.0, "dry land is not water")

	# Never land as water: every cell on a sweep whose probe says dry (NAN or depth under the wet limit) answers "".
	var wrong: int = 0

	for ix in range(-20, 400):
		for iz in range(0, 40):
			var x: float = float(ix) * 8.0 + 4.0
			var z: float = float(iz) * 8.0 + 4.0
			var raw: Array = probe(x, z)
			var is_dry: bool = is_nan(float(raw[0])) or float(raw[0]) - float(raw[1]) < 0.12
			var kind: String = fw.water_kind_at(x, z, now)["kind"]
			wrong += 1 if (is_dry and kind != "") or (not is_dry and kind == "") else 0

	check(wrong == 0, "land is never water and water is never land (%d wrong cells)" % wrong)

	# Dug ground: not water, then water after the rain, seen once the cached answer is older than the ttl.
	check(fw.water_kind_at(5008.0, 8.0, now)["kind"] == "", "a hole not yet filled is dry")
	dug = true
	check(fw.water_kind_at(5008.0, 8.0, now + 1000)["kind"] == "", "the answer is kept for a while")
	check(fw.water_kind_at(5008.0, 8.0, now + 25000)["kind"] == "pond", "after the ttl a filled hole is a pond")

	# Cost of a cached answer.
	var t0: int = Time.get_ticks_usec()

	for n in 20000:
		fw.water_kind_at(1400.0, 400.0, now + 25000)

	var per_cell_ms: float = float(Time.get_ticks_usec() - t0) / 20000.0 / 1000.0
	check(per_cell_ms < 0.05, "a cached answer costs %.4f ms (limit 0.05)" % per_cell_ms)
	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)
