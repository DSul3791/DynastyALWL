extends SceneTree

# Dave 9 Nov 2026: plants by water "grow 100% thicker, and grass grows taller right at the water and its growth deminishes as it gets further from
# the water until it gets to normal growth at 6 meters away". The grass finds the water on a 1 m grid round each cell and turns the distance
# to the nearest wet spot into a lush share (grass_view.gd lush_near, near_water_growth.gd growth_near_water): 1 at the edge, 0 from 6 m. This checks both.
#   godot --headless --path . --script res://src/worldgen/tools/test_grass_lush.gd

const GrassView := preload("res://src/client/grass_view.gd")
const NearWater := preload("res://src/shared/near_water_growth.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	# The lush share by distance, on ground just over the water.
	check(is_equal_approx(GrassView.lush(0.0, 0.2), 1.0), "at the water's edge: full (twice as thick, half again as tall)")
	var last: float = 1.0
	var falls: bool = true

	for d in range(1, 7):
		var here: float = GrassView.lush(float(d), 0.2)
		falls = falls and here < last
		last = here

	check(falls, "it eases off with every metre from the water")
	check(is_equal_approx(GrassView.lush(3.0, 0.2), 0.5) and is_equal_approx(NearWater.growth_near_water(1.5), 0.75), "straight down: half at 3 m, three quarters at 1.5 m")
	check(GrassView.lush(GrassView.LUSH_M, 0.2) == 0.0 and GrassView.lush(9.0, 0.2) == 0.0, "normal growth from 6 m")
	check(GrassView.lush(INF, 0.2) == 0.0 and GrassView.lush(NAN, 0.2) == 0.0, "no water near: normal growth")
	# The roots must reach the water: a bank up to 1 m over it is fully watered, a cliff 3 m or more over a river is not.
	check(is_equal_approx(GrassView.lush(0.0, 1.0), 1.0), "1 m over the water: full")
	check(is_equal_approx(GrassView.lush(0.0, 2.0), 0.5), "2 m over the water: half")
	check(GrassView.lush(0.0, 3.0) == 0.0 and GrassView.lush(0.0, 12.0) == 0.0, "a high bank or cliff: normal growth")

	# The wet spots round a cell (x, z, level): a brook along x = 2, level 4.0, ground 0.2 m over it.
	var brook: PackedFloat32Array = PackedFloat32Array()

	for z in range(-6, 13):
		brook.append_array([2.0, float(z), 4.0])

	check(is_equal_approx(GrassView.lush_near(brook, Vector3(2.0, 4.2, 3.0)), 1.0), "on the brook's edge: full")
	check(is_equal_approx(GrassView.lush_near(brook, Vector3(5.0, 4.2, 3.0)), GrassView.lush(3.0, 0.2)), "3 m across: the 3 m share")
	check(GrassView.lush_near(brook, Vector3(8.5, 4.2, 3.0)) == 0.0, "6.5 m across: normal growth")
	check(GrassView.lush_near(brook, Vector3(4.0, 7.5, 3.0)) == 0.0, "on a bank 3.5 m over the brook: normal growth")
	# The nearest spot sets the level: a pond at 10.0 beside the brook at 4.0, the point on the pond's bank.
	var both: PackedFloat32Array = brook.duplicate()
	both.append_array([9.0, 3.0, 10.0])
	check(is_equal_approx(GrassView.lush_near(both, Vector3(9.5, 10.2, 3.0)), GrassView.lush(0.5, 0.2)), "the nearest water's level is the one used")
	check(GrassView.lush_near(PackedFloat32Array(), Vector3(0.0, 1.0, 0.0)) == 0.0, "no water round the cell: normal growth")
	# A record brook or spring head (no level, Dave 10 Nov 2026): water brook_half_m round the spot, at any height.
	var record: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, NAN])
	check(is_equal_approx(GrassView.lush_near(record, Vector3(1.0, 50.0, 0.0), 1.5), 1.0), "inside a record brook's half width: full")
	check(is_equal_approx(GrassView.lush_near(record, Vector3(4.5, 50.0, 0.0), 1.5), GrassView.lush(3.0, NAN)), "3 m past its edge: the 3 m share")
	check(GrassView.lush_near(record, Vector3(8.0, 50.0, 0.0), 1.5) == 0.0, "6.5 m past it: normal growth")

	print("test_grass_lush: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
