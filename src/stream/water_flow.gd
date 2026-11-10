extends RefCounted

# How fast the water runs at a point, for placement rules such as the water wheel (Sal's "is there running water here"). Server side.
# It asks the drawn-speed code itself (water_grid.gd _velocities) on a small block of the tile's settled levels around the point, so the
# server and the drawn current always agree and there is no second copy of the formula. The 8 m grid is coarse for a narrow stream, so a
# point takes the fastest of the 4 cells around it. Still water (ponds, lake shores) is 0; no water is -1.

const WaterGridScript := preload("res://src/worldgen/runtime/water_grid.gd")
const MARGIN_CELLS := 8             # cells each way kept around the points: the calm window (3), the easing (3) and the slope (1), with room
const NO_WATER := -1.0
const RIVER_CLASS := 3              # data/tables/water_classes.json: a river (the only water a wheel turns in)
const RULES_PATH := "res://data/water_flow.json"


# Speed (m/s) of the water at (x, z) in `tile_data`'s settled levels; NO_WATER where none. `generator` is the world generator.
static func speed_at(generator, tile_data, x: float, z: float) -> float:
	var speeds: Array = _speeds(generator, tile_data, [Vector2(x, z)])
	return float(speeds[0])


# Power of an undershot water wheel (Sonny's water rules section 10, approved 10 Nov 2026): P = efficiency x 1/2 rho A v^3 watts, with
# A = span x min(depth - clear, paddle) (the paddles dip up to paddle_m and clear the bed by clear_m) and v the current across the wheel,
# capped at max_speed_m_s (a real river runs 0.5 to 3 m/s; the saved water near the spawn has metre steps that read as 10 m/s until the river
# re-bake, so the cap keeps the numbers sane). data/water_flow.json holds every number.
static func power_w(across_m_s: float, depth_m: float, rules: Dictionary) -> float:
	var area: float = float(rules.get("span_m", 2.0)) * clampf(depth_m - float(rules.get("clear_m", 0.2)), 0.0, float(rules.get("paddle_m", 0.5)))
	var v: float = clampf(across_m_s, 0.0, float(rules.get("max_speed_m_s", 3.0)))
	return float(rules.get("efficiency", 0.3)) * 0.5 * 1000.0 * area * v * v * v


# A water wheel spanning a to b (its axle along the span): {"w": watts, "why": ""} or, when it cannot turn there, "w" 0 and why:
#   "dry"     a point of the span has no water
#   "river"   a point is not over a river (water_class RIVER_CLASS; never a lake, marsh, seasonal channel or sea)
#   "still"   the water at a point does not run
#   "shallow" a point is shallower than min_depth_m
# The wheel is only as good as its slowest and shallowest point. Only the current across the span turns it (|velocity . normal|); "along" is
# set when the wheel would have given min_power_w turned across the current. `depth_at` is (Vector3) -> m of water there.
static func wheel(generator, tile_data, a: Vector3, b: Vector3, rules: Dictionary, depth_at: Callable) -> Dictionary:
	var points: Array = _span_points(a, b, float(rules.get("step_m", 0.5)))
	var flows: Array = _flows(generator, tile_data, points)
	var span: Vector2 = Vector2(b.x - a.x, b.z - a.z)
	var normal: Vector2 = Vector2(-span.y, span.x).normalized() if span.length() > 0.001 else Vector2.UP
	var across: float = INF
	var current: float = INF
	var shallowest: float = INF

	for n in range(points.size()):
		var flow: Vector2 = flows[n]
		var at: Vector2 = points[n]

		if is_nan(flow.x):
			return {"w": 0.0, "why": "dry"}

		if tile_data.water_class.size() == tile_data.samples * tile_data.samples and int(tile_data.water_class[tile_data.nearest(at.x, at.y)]) != RIVER_CLASS:
			return {"w": 0.0, "why": "river"}

		if flow.length() <= 0.0:
			return {"w": 0.0, "why": "still"}

		var depth: float = float(depth_at.call(Vector3(at.x, a.y, at.y))) if depth_at.is_valid() else 0.0
		shallowest = minf(shallowest, depth)
		across = minf(across, absf(flow.dot(normal)))
		current = minf(current, flow.length())

	if shallowest < float(rules.get("min_depth_m", 0.4)):
		return {"w": 0.0, "why": "shallow"}

	var watts: float = power_w(across, shallowest, rules)
	return {"w": watts, "why": "", "along": watts < float(rules.get("min_power_w", 150.0)) and power_w(current, shallowest, rules) >= float(rules.get("min_power_w", 150.0))}


# The share of full speed a sawmill with `watts` at its wheel works at (craft time x full_power_w / P): 1 from full_power_w, down to
# min_power_w / full_power_w at the least it may be placed with (Sonny section 10: 6 s at full rate, 40 s at 150 W).
static func wheel_share(watts: float, rules: Dictionary) -> float:
	var full: float = maxf(float(rules.get("full_power_w", 1000.0)), 1.0)
	return clampf(watts / full, float(rules.get("min_power_w", 150.0)) / full, 1.0)


static func load_rules() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func _span_points(a: Vector3, b: Vector3, step_m: float) -> Array:
	var points: Array = []
	var length: float = Vector2(b.x - a.x, b.z - a.z).length()
	var count: int = maxi(int(ceil(length / maxf(step_m, 0.05))), 1) + 1

	for n in range(count):
		var t: float = float(n) / float(count - 1)
		points.append(Vector2(lerpf(a.x, b.x, t), lerpf(a.z, b.z, t)))

	return points


static func _speeds(generator, tile_data, points: Array) -> Array:
	var out: Array = []

	for flow in _flows(generator, tile_data, points):
		out.append(NO_WATER if is_nan((flow as Vector2).x) else (flow as Vector2).length())

	return out


# The water's velocity (x, z m/s) at each point: that of the fastest of the 4 cells around it (as the drawn current), Vector2.ZERO where it is
# still, Vector2(NAN, NAN) where there is none.
static func _flows(generator, tile_data, points: Array) -> Array:
	var out: Array = []

	if tile_data == null or tile_data.placeholder or tile_data.sim_snapshot().is_empty():
		for p in points:
			out.append(Vector2(NAN, NAN))

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
		var fastest: Vector2 = Vector2(NAN, NAN)
		var i0: int = int(floor((p.x - origin.x) / spacing))
		var j0: int = int(floor((p.y - origin.y) / spacing))

		for dj in range(2):
			for di in range(2):
				var k: int = (j0 + dj) * count + i0 + di

				if is_nan(levels[k]):
					continue

				var cell: Vector2 = Vector2(vel[k * 2], vel[k * 2 + 1])

				if is_nan(fastest.x) or cell.length() > fastest.length():
					fastest = cell

		out.append(fastest)

	return out
