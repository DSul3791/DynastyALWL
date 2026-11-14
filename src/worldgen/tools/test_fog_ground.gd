extends SceneTree

# Where land fog lies (src/shared/fog_ground.gd, Dave's fog instruction 14 Nov 2026): the cold-air floor is the lowest ground nearby,
# so a valley fills while the hills round it stand clear; steam fog only near fresh water; unknown ground is sea level (the old layer).
# Run: godot --headless --script res://src/worldgen/tools/test_fog_ground.gd

const FogGround := preload("res://src/shared/fog_ground.gd")

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1

	print("%s %s" % ["ok  " if ok else "FAIL", what])


func _initialize() -> void:
	# A valley at 50 m between hills rising to 250 m, a river along its floor (column 32).
	var n: int = 64
	var heights: PackedFloat32Array = PackedFloat32Array()
	var fresh: PackedFloat32Array = PackedFloat32Array()
	heights.resize(n * n)
	fresh.resize(n * n)

	for j in range(n):
		for i in range(n):
			var across: float = absf(float(i) - 32.0) * FogGround.CELL_M
			heights[j * n + i] = 50.0 + minf(across * 0.25, 200.0)
			fresh[j * n + i] = across

	var origin: Vector2 = Vector2(1000.0, 2000.0)
	var g: Dictionary = FogGround.build_grid(heights, fresh, n, origin)
	var x_floor: float = origin.x + 32.5 * FogGround.CELL_M
	var z_mid: float = origin.y + 32.5 * FogGround.CELL_M
	var floor_valley: float = FogGround.sample(g, "floor", x_floor, z_mid, -1.0)
	var x_hill: float = origin.x + 60.5 * FogGround.CELL_M          # 900 m up the side: 200 m above the floor
	var floor_hill: float = FogGround.sample(g, "floor", x_hill, z_mid, -1.0)
	_check(absf(floor_valley - 50.0) < 5.0, "the valley's floor is its bed (%.1f m)" % floor_valley)
	_check(floor_hill > 150.0, "high on the hillside the floor is the hill's own shoulder, not the valley (%.1f m)" % floor_hill)
	var depth: float = 60.0
	_check(FogGround.land_top(floor_valley, depth) > 50.0 + 1.7 and FogGround.land_top(floor_valley, depth) < 250.0, "a 60 m fog fills the valley and stays below the hilltops")
	var x_slope: float = origin.x + 36.5 * FogGround.CELL_M         # 128 m from the river, 32 m up the slope
	_check(FogGround.sample(g, "floor", x_slope, z_mid, -1.0) < 60.0, "low on the slope the floor is still the valley's: the fog reaches up it")
	_check(FogGround.sample(g, "view", x_hill, z_mid, -1.0) < floor_hill - 50.0, "seen from the hill, the layer lies over the valley below")
	_check(FogGround.sample(g, "near", x_floor, z_mid, -1.0) > 0.8, "steam fog at the river")
	_check(FogGround.sample(g, "near", x_slope, z_mid, -1.0) < 0.05, "none 128 m from the water")
	_check(FogGround.sample(g, "floor", 0.0, 0.0, -1.0) == -1.0 and FogGround.sample({}, "floor", x_floor, z_mid, 7.0) == 7.0, "off the grid or no grid: the fallback")
	# The floor is smooth: no step bigger than 10 m between neighbouring 32 m cells in this valley.
	var worst: float = 0.0
	var floor_cells: PackedFloat32Array = g["floor"]

	for i in range(1, n):
		worst = maxf(worst, absf(floor_cells[32 * n + i] - floor_cells[32 * n + i - 1]))

	_check(worst < 10.0, "the floor has no steps (worst %.1f m between cells)" % worst)
	# The sea bed is not the floor: the sea's surface is.
	var sea: PackedFloat32Array = heights.duplicate()
	sea[0] = -40.0
	_check(FogGround.sample(FogGround.build_grid(sea, fresh, n, origin), "floor", origin.x + 16.0, origin.y + 16.0, -1.0) >= 0.0, "by the sea the floor is sea level, not the sea bed")
	# The real tiles, if this checkout has them: the read finds ground.
	var real: Dictionary = FogGround.read_window("res://worlds/base_world/tiles", 15360.0, Vector2(53296.0 - 2048.0, 68080.0 - 2048.0))

	if not real.is_empty():
		var spawn_floor: float = FogGround.sample(real, "floor", 53296.0, 68080.0, NAN)
		_check(is_finite(spawn_floor) and spawn_floor >= 0.0 and spawn_floor < 2000.0, "the spawn's floor from the tiles: %.1f m" % spawn_floor)

	print("test_fog_ground: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(0 if _fails == 0 else 1)
