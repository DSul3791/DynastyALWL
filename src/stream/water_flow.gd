extends RefCounted

# How fast the water runs at a point, for placement rules such as the water wheel (Sal's "is there running water here"). Server side.
# It asks the drawn-speed code itself (water_grid.gd _velocities) on a small block of the tile's settled levels around the point, so the
# server and the drawn current always agree and there is no second copy of the formula. The 8 m grid is coarse for a narrow stream, so a
# point takes the fastest of the 4 cells around it. Still water (ponds, lake shores) is 0; no water is -1.

const WaterGridScript := preload("res://src/worldgen/runtime/water_grid.gd")
const MARGIN_CELLS := 8             # cells each way kept around the points: the calm window (3), the easing (3) and the slope (1), with room
const NO_WATER := -1.0


# Speed (m/s) of the water at (x, z) in `tile_data`'s settled levels; NO_WATER where none. `generator` is the world generator.
static func speed_at(generator, tile_data, x: float, z: float) -> float:
	var speeds: Array = _speeds(generator, tile_data, [Vector2(x, z)])
	return float(speeds[0])


# The lowest speed along the span a to b (a point every step_m), so a wheel is only as good as its slowest metre; NO_WATER if any point is dry.
static func span_speed(generator, tile_data, a: Vector3, b: Vector3, step_m: float = 0.5) -> float:
	var points: Array = []
	var length: float = Vector2(b.x - a.x, b.z - a.z).length()
	var count: int = maxi(int(ceil(length / maxf(step_m, 0.05))), 1) + 1

	for n in range(count):
		var t: float = float(n) / float(count - 1)
		points.append(Vector2(lerpf(a.x, b.x, t), lerpf(a.z, b.z, t)))

	var lowest: float = INF

	for speed in _speeds(generator, tile_data, points):
		lowest = minf(lowest, float(speed))

	return lowest


# True when the span runs at least the data's min_speed_m_s (data/water_flow.json).
static func runs(generator, tile_data, a: Vector3, b: Vector3, rules: Dictionary) -> bool:
	return span_speed(generator, tile_data, a, b, float(rules.get("step_m", 0.5))) >= float(rules.get("min_speed_m_s", 0.3))


static func _speeds(generator, tile_data, points: Array) -> Array:
	var out: Array = []

	if tile_data == null or tile_data.placeholder or tile_data.sim_levels.is_empty():
		for p in points:
			out.append(NO_WATER)

		return out

	var spacing: float = tile_data.spacing_m
	var low_i: int = tile_data.samples
	var low_j: int = tile_data.samples
	var high_i: int = 0
	var high_j: int = 0

	for p in points:
		var i: int = int(floor((p.x - tile_data.x0) / spacing))
		var j: int = int(floor((p.y - tile_data.z0) / spacing))
		low_i = mini(low_i, i)
		low_j = mini(low_j, j)
		high_i = maxi(high_i, i + 1)
		high_j = maxi(high_j, j + 1)

	low_i -= MARGIN_CELLS
	low_j -= MARGIN_CELLS
	var count: int = maxi(high_i - low_i, high_j - low_j) + 1 + MARGIN_CELLS
	var levels: PackedFloat32Array = PackedFloat32Array()
	levels.resize(count * count)

	for j in range(count):
		for i in range(count):
			var si: int = low_i + i
			var sj: int = low_j + j
			levels[j * count + i] = tile_data.sim_levels[sj * tile_data.samples + si] if si >= 0 and sj >= 0 and si < tile_data.samples and sj < tile_data.samples else NAN

	var origin: Vector2 = Vector2(tile_data.x0 + float(low_i) * spacing, tile_data.z0 + float(low_j) * spacing)
	var vel: PackedFloat32Array = WaterGridScript._velocities(generator, tile_data, origin, count, spacing, levels)

	for p in points:
		var fastest: float = NO_WATER
		var i0: int = int(floor((p.x - origin.x) / spacing))
		var j0: int = int(floor((p.y - origin.y) / spacing))

		for dj in range(2):
			for di in range(2):
				var k: int = (j0 + dj) * count + i0 + di

				if is_nan(levels[k]):
					continue

				fastest = maxf(fastest, 0.0)
				fastest = maxf(fastest, Vector2(vel[k * 2], vel[k * 2 + 1]).length())

		out.append(fastest)

	return out
