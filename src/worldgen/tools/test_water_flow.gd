extends SceneTree

# Running water for placement (src/stream/water_flow.gd): a sloped sheet runs at the drawn speed, flat water is still, no water is -1.
#   godot --headless --path . --script res://src/worldgen/tools/test_water_flow.gd

const WaterFlow := preload("res://src/stream/water_flow.gd")
const WaterGrid := preload("res://src/worldgen/runtime/water_grid.gd")
const TileData := preload("res://src/worldgen/runtime/tile_terrain_data.gd")

const N := 64

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _tile(slope_per_cell: float) -> Object:
	var tile = TileData.new()
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
	var at: Vector2 = Vector2(1000.0 + 30.0 * 8.0 + 3.0, 2000.0 + 30.0 * 8.0 + 3.0)
	var speed: float = WaterFlow.speed_at(null, tile, at.x, at.y)
	var expected: float = pow(1.0, 2.0 / 3.0) * sqrt(0.1 / 8.0) / WaterGrid.MANNING_N
	_check(absf(speed - expected) < 0.05, "a sloped sheet runs at the drawn speed (%.2f, expected %.2f)" % [speed, expected])

	# The same cells from the whole tile grid as the client draws them.
	var whole: PackedFloat32Array = WaterGrid._velocities(null, tile, Vector2(tile.x0, tile.z0), N, 8.0, tile.sim_levels)
	var worst: float = 0.0

	for n in range(20):
		var i: int = 20 + n
		var j: int = 25
		var drawn: float = 0.0

		for dj in range(2):
			for di in range(2):
				var k: int = (j + dj) * N + i + di
				drawn = maxf(drawn, Vector2(whole[k * 2], whole[k * 2 + 1]).length())

		var got: float = WaterFlow.speed_at(null, tile, tile.x0 + float(i) * 8.0 + 1.0, tile.z0 + float(j) * 8.0 + 1.0)
		worst = maxf(worst, absf(got - drawn))

	_check(worst < 0.001, "the server speed equals the drawn speed on 20 samples (worst %.4f)" % worst)
	var flat = _tile(0.0)
	_check(WaterFlow.speed_at(null, flat, at.x, at.y) == 0.0, "flat water is still (0)")
	var dry = _tile(0.1)

	for k in range(N * N):
		dry.sim_levels[k] = NAN

	_check(WaterFlow.speed_at(null, dry, at.x, at.y) == WaterFlow.NO_WATER, "dry ground is -1")
	_check(WaterFlow.speed_at(null, null, at.x, at.y) == WaterFlow.NO_WATER, "no tile is -1")
	var a: Vector3 = Vector3(at.x, 30.0, at.y)
	var b: Vector3 = Vector3(at.x + 2.0, 30.0, at.y)
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/water_flow.json"))
	_check(WaterFlow.runs(null, tile, a, b, rules), "a fast 2 m span passes the 0.3 m/s rule")
	_check(not WaterFlow.runs(null, flat, a, b, rules), "a still span fails it")
	print("test_water_flow: %d failures" % failures)
	quit(failures)
