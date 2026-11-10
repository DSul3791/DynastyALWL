extends SceneTree

# Running water for placement (src/stream/water_flow.gd): a sloped sheet runs at the drawn speed, flat water is still, no water is -1; and the
# water wheel's power rule (Sonny's water rules section 10): P = 150 A v^3 from the current across the wheel, over a river at least 0.4 m deep.
#   godot --headless --path . --script res://src/worldgen/tools/test_water_flow.gd

const WaterFlow := preload("res://src/stream/water_flow.gd")
const WaterGrid := preload("res://src/worldgen/runtime/water_grid.gd")
const TileTerrainData := preload("res://src/worldgen/runtime/tile_terrain_data.gd")

const N := 64

var failures: int = 0


# The whole-tile grid reaches the last row and column, which _velocities reads from the generator (the tile next door); here it is the same tile.
class StubGenerator:
	var tile

	func tile_of(_x: float, _z: float) -> Vector2i:
		return Vector2i.ZERO

	func get_tile(_at: Vector2i):
		return tile


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _tile(slope_per_cell: float) -> Object:
	var tile = TileTerrainData.new()
	tile.samples = N
	tile.spacing_m = 8.0
	tile.x0 = 1000.0
	tile.z0 = 2000.0
	tile.heights.resize(N * N)
	tile.sim_levels.resize(N * N)

	for j in range(N):
		for i in range(N):
			var level: float = 30.0 - slope_per_cell * float(i)
			tile.sim_levels[j * N + i] = level
			tile.heights[j * N + i] = level - 1.0

	return tile


func _init() -> void:
	var tile = _tile(0.1)
	var stub: StubGenerator = StubGenerator.new()
	stub.tile = tile
	var at: Vector2 = Vector2(1000.0 + 30.0 * 8.0 + 3.0, 2000.0 + 30.0 * 8.0 + 3.0)
	var speed: float = WaterFlow.speed_at(stub, tile, at.x, at.y)
	var expected: float = pow(1.0, 2.0 / 3.0) * sqrt(0.1 / 8.0) / WaterGrid.MANNING_N
	_check(absf(speed - expected) < 0.05, "a sloped sheet runs at the drawn speed (%.2f, expected %.2f)" % [speed, expected])

	# The same cells from the whole tile grid as the client draws them.
	var whole: PackedFloat32Array = WaterGrid._velocities(stub, tile, Vector2(tile.x0, tile.z0), N, 8.0, tile.sim_levels)
	var worst: float = 0.0

	for n in range(20):
		var i: int = 20 + n
		var j: int = 25
		var drawn: float = 0.0

		for dj in range(2):
			for di in range(2):
				var k: int = (j + dj) * N + i + di
				drawn = maxf(drawn, Vector2(whole[k * 2], whole[k * 2 + 1]).length())

		var got: float = WaterFlow.speed_at(stub, tile, tile.x0 + float(i) * 8.0 + 1.0, tile.z0 + float(j) * 8.0 + 1.0)
		worst = maxf(worst, absf(got - drawn))

	_check(worst < 0.001, "the server speed equals the drawn speed on 20 samples (worst %.4f)" % worst)
	var flat = _tile(0.0)
	_check(WaterFlow.speed_at(stub, flat, at.x, at.y) == 0.0, "flat water is still (0)")
	var dry = _tile(0.1)

	for k in range(N * N):
		dry.sim_levels[k] = NAN

	_check(WaterFlow.speed_at(stub, dry, at.x, at.y) == WaterFlow.NO_WATER, "dry ground is -1")
	_check(WaterFlow.speed_at(stub, null, at.x, at.y) == WaterFlow.NO_WATER, "no tile is -1")
	_wheel_checks(stub, tile, flat, dry, at)
	print("test_water_flow: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func _wheel_checks(stub, tile, flat, dry, at: Vector2) -> void:
	var rules: Dictionary = WaterFlow.load_rules()
	_check(is_equal_approx(float(rules.get("min_power_w", 0.0)), 150.0) and is_equal_approx(float(rules.get("full_power_w", 0.0)), 1000.0), "data/water_flow.json has the section 10 numbers")
	# Sonny's table: 0.4 m deep at 2 m/s is 480 W; 0.7 m or more at 1 m/s is 150 W, at 2.5 m/s 2,340 W; the current is capped at max_speed_m_s.
	_check(absf(WaterFlow.power_w(2.0, 0.4, rules) - 480.0) < 0.5, "0.4 m deep at 2 m/s gives 480 W")
	_check(absf(WaterFlow.power_w(1.0, 0.7, rules) - 150.0) < 0.5 and absf(WaterFlow.power_w(1.0, 3.0, rules) - 150.0) < 0.5, "0.7 m or deeper at 1 m/s gives 150 W (the paddles dip 0.5 m)")
	_check(absf(WaterFlow.power_w(2.5, 1.0, rules) - 2343.75) < 0.5, "at 2.5 m/s 2,340 W")
	_check(is_equal_approx(WaterFlow.power_w(12.0, 1.0, rules), WaterFlow.power_w(float(rules["max_speed_m_s"]), 1.0, rules)), "a stepped river's 12 m/s counts as the cap")
	_check(is_equal_approx(WaterFlow.wheel_share(1500.0, rules), 1.0) and is_equal_approx(WaterFlow.wheel_share(500.0, rules), 0.5) and is_equal_approx(WaterFlow.wheel_share(150.0, rules), 0.15), "the saw's share of full speed is P / 1000 W")
	var river: Array = []

	for k in range(N * N):
		river.append(3)

	tile.water_class = PackedByteArray(river)
	flat.water_class = PackedByteArray(river)
	var deep: Callable = func(_p: Vector3) -> float: return 1.0
	var shallow: Callable = func(_p: Vector3) -> float: return 0.3
	var across_a: Vector3 = Vector3(at.x, 30.0, at.y)
	var across_b: Vector3 = Vector3(at.x, 30.0, at.y + 2.0)      # the sheet runs along x; a span along z stands across it
	var turned: Dictionary = WaterFlow.wheel(stub, tile, across_a, across_b, rules, deep)
	_check(str(turned["why"]) == "" and float(turned["w"]) >= float(rules["full_power_w"]), "a wheel across a fast river turns at full power (%.0f W)" % float(turned["w"]))
	var along: Dictionary = WaterFlow.wheel(stub, tile, across_a, Vector3(at.x + 2.0, 30.0, at.y), rules, deep)
	_check(float(along["w"]) < float(rules["min_power_w"]) and bool(along["along"]), "set along the current it does nothing, and says to turn it")
	_check(str(WaterFlow.wheel(stub, tile, across_a, across_b, rules, shallow)["why"]) == "shallow", "0.3 m of water is too shallow")
	_check(str(WaterFlow.wheel(stub, flat, across_a, across_b, rules, deep)["why"]) == "still", "still water does not turn it")
	_check(str(WaterFlow.wheel(stub, dry, across_a, across_b, rules, deep)["why"]) == "dry", "no water does not")
	var lake: Array = river.duplicate()

	for k in range(N * N):
		lake[k] = 1

	tile.water_class = PackedByteArray(lake)
	_check(str(WaterFlow.wheel(stub, tile, across_a, across_b, rules, deep)["why"]) == "river", "only a river turns a wheel, never a lake")
