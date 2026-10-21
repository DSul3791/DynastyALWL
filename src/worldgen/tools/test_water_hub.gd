extends SceneTree

# Water across tile borders (src/water/water_hub.gd): which border cells are coupled, and that the
# coupling moves water between two tiles without making or losing any.
#   godot --headless --path . --script res://src/worldgen/tools/test_water_hub.gd

const Hub := preload("res://src/water/water_hub.gd")
const WaterSim := preload("res://src/water/water_sim.gd")

var failures: int = 0


class FakeTile:
	var samples: int = 9
	var water_class: PackedByteArray = PackedByteArray()
	var heights: PackedFloat32Array = PackedFloat32Array()

	func _init(n: int) -> void:
		samples = n
		water_class.resize(n * n)
		heights.resize(n * n)
		heights.fill(10.0)


class FakeLive:
	var sim
	var woken: float = 0.0
	var running: bool = false

	func wants_run() -> bool:
		return running

	func wake(seconds: float = 0.0) -> void:
		woken = seconds
		running = true


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _tile_sim(n: int, ground: float) -> WaterSim:
	var sim := WaterSim.new()
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	heights.fill(ground)
	sim.setup(n, 8.0, heights)
	return sim


func _init() -> void:
	var n: int = 21
	var a := FakeTile.new(n)
	var b := FakeTile.new(n)

	# A river on a's east edge at rows 8-9, and nothing on b's side.
	a.water_class[8 * n + n - 1] = 3
	a.water_class[9 * n + n - 1] = 3
	var east: Array = Hub.border_pairs(a, b, Vector2i(1, 0))
	_check(east[0].size() == 2 + 2 * Hub.PAD and east[0][0] == (8 - Hub.PAD) * n + n - 1 and east[1][0] == (8 - Hub.PAD) * n, "an east crossing couples the river cells and %d either side (%d pairs)" % [Hub.PAD, east[0].size()])
	var west: Array = Hub.border_pairs(b, a, Vector2i(-1, 0))
	_check(west[0].size() == east[0].size() and west[0][0] == east[1][0] and west[1][0] == east[0][0], "the same border seen from the other tile pairs the same cells")
	var dry: Array = Hub.border_pairs(b, b, Vector2i(0, 1))
	_check(dry[0].is_empty(), "a dry border has no pairs")
	a.water_class[10 * n + 4] = 3
	_check(Hub.border_pairs(a, b, Vector2i(1, 0))[0].size() == east[0].size(), "a river that does not touch the border does not make a crossing")
	var south: Array = Hub.border_pairs(a, b, Vector2i(0, 1))
	_check(south[0].is_empty(), "a river on the east edge makes no south crossing")

	# Conservation and levelling: 1 m of water on a's border cells, none on b's.
	var hub = Hub.new()
	var sa := _tile_sim(n, 50.0)
	var sb := _tile_sim(n, 50.0)
	var live_a := FakeLive.new()
	var live_b := FakeLive.new()
	live_a.sim = sa
	live_b.sim = sb
	var ka: PackedInt32Array = east[0]
	var kb: PackedInt32Array = east[1]

	for k in ka:
		sa.add_water(k % n, k / n, 1.0)

	var before: float = sa.total_volume() + sb.total_volume()

	for tick in range(40):
		hub._couple(live_a, live_b, ka, kb, 0.25)

	var after: float = sa.total_volume() + sb.total_volume()
	_check(absf(after - before) < 0.01, "coupling moves water without making or losing any (%.2f -> %.2f m3)" % [before, after])
	var level_a: float = sa.depth_at(ka[3])
	var level_b: float = sb.depth_at(kb[3])
	_check(absf(level_a - level_b) < 0.05 and level_b > 0.4, "the two sides come level (%.2f m and %.2f m)" % [level_a, level_b])
	_check(live_b.woken > 0.0, "a tile that received water is woken to run it")

	# Slow: a high step is never crossed in a single tick (the speed ceiling holds the move down).
	var sc := _tile_sim(n, 50.0)
	var sd := _tile_sim(n, 50.0)
	var live_c := FakeLive.new()
	var live_d := FakeLive.new()
	live_c.sim = sc
	live_d.sim = sd
	sc.add_water(10, 10, 4.0)
	hub._couple(live_c, live_d, PackedInt32Array([10 * n + 10]), PackedInt32Array([10 * n + 10]), 0.01)
	var moved: float = sd.depth_at(10 * n + 10)
	_check(moved > 0.0 and moved <= WaterSim.SPEED_MAX_M_S * 4.0 * 0.01 / 8.0 + 0.0001, "one short tick cannot move more than the speed ceiling allows (%.3f m)" % moved)

	# Sea cells (ground at or under 0) are held by their own tile and left alone.
	var se := _tile_sim(n, -5.0)
	var sf := _tile_sim(n, 50.0)
	var live_e := FakeLive.new()
	var live_f := FakeLive.new()
	live_e.sim = se
	live_f.sim = sf
	sf.add_water(5, 5, 1.0)
	var sea_before: float = sf.depth_at(5 * n + 5)
	hub._couple(live_e, live_f, PackedInt32Array([5 * n + 5]), PackedInt32Array([5 * n + 5]), 0.25)
	_check(is_equal_approx(sf.depth_at(5 * n + 5), sea_before), "a sea cell is not coupled")

	print("water hub: %d failures" % failures)
	quit(1 if failures > 0 else 0)
