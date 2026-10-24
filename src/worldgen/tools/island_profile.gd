extends SceneTree

# Height profile of a baked starter tile: heights from the spawn toward the peak and on five other bearings (distance from
# the spawn, plus ~440 m to the coast), width of the flat top, steep-slope share, and the numeric spawn gate.
#
#   godot --headless --path . --script res://src/worldgen/tools/island_profile.gd -- <tile file> [tile_x tile_z]
#
# Targets (ISLAND_SHAPE_PLAN): about 40 m at 1 km, 130 m at 2 km, 340 m at 3.5 km from the coast.

const TileFile := preload("res://src/worldgen/tile/tile_file.gd")
const SPAWN := Vector2(53301.0, 68427.0)
const CELL_M := 8.0
const TILE_SAMPLES := 1920


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var path: String = args[0]
	var tile_x: int = int(args[1]) if args.size() > 2 else 3
	var tile_z: int = int(args[2]) if args.size() > 2 else 4
	var origin_x: int = tile_x * TILE_SAMPLES
	var origin_z: int = tile_z * TILE_SAMPLES
	var head: Dictionary = TileFile.read_header(path)
	var h: PackedFloat32Array = TileFile.decode_height(TileFile.read_section(path, head["table"], "height")["raw"])
	var side: int = int(round(sqrt(float(h.size()))))
	var best: float = -1.0
	var best_index: int = 0

	for i in range(h.size()):
		if h[i] > best:
			best = h[i]
			best_index = i

	var peak := Vector2(float(best_index % side + origin_x) * CELL_M, float(best_index / side + origin_z) * CELL_M)
	print("peak %.0f m at %.0f %.0f, %.0f m from spawn" % [best, peak.x, peak.y, SPAWN.distance_to(peak)])

	for band in [5.0, 10.0, 20.0, 40.0]:
		var n: int = 0

		for v in h:
			if v >= best - band:
				n += 1

		print("  within %2.0f m of the peak: %.1f ha, equal-area diameter %.0f m" % [band, float(n) * CELL_M * CELL_M / 1.0e4, 2.0 * sqrt(float(n) * CELL_M * CELL_M / PI)])

	var direction: Vector2 = (peak - SPAWN).normalized()
	print("height m at distance from spawn (add ~440 m for distance from coast):")

	for bearing in [0.0, -0.6, 0.6, 1.57, -1.57, 3.14159]:
		var ray: Vector2 = direction.rotated(bearing)
		var line := "  bearing %+5.2f:" % bearing

		for dist in [0, 560, 1560, 3060, 3560]:
			var at: Vector2 = SPAWN + ray * float(dist)
			var column: int = int(at.x / CELL_M) - origin_x
			var row: int = int(at.y / CELL_M) - origin_z
			var value: float = h[row * side + column] if column >= 0 and row >= 0 and column < side and row < side else -1.0
			line += "  %4d m: %4.0f" % [dist, value]

		print(line)

	# Steepness: share of land cells (over 0 m) steeper than 35 degrees and than 50 degrees (8 m cells).
	var land: int = 0
	var steep35: int = 0
	var steep50: int = 0
	var max_slope: float = 0.0

	for row in range(1, side - 1):
		for column in range(1, side - 1):
			var i: int = row * side + column

			if h[i] <= 1.0:
				continue

			var sx: float = (h[i + 1] - h[i - 1]) / (2.0 * CELL_M)
			var sz: float = (h[i + side] - h[i - side]) / (2.0 * CELL_M)
			var slope: float = rad_to_deg(atan(sqrt(sx * sx + sz * sz)))
			land += 1
			max_slope = maxf(max_slope, slope)

			if slope > 35.0:
				steep35 += 1
			if slope > 50.0:
				steep50 += 1

	print("land cells %d: over 35 deg %.2f%%, over 50 deg %.2f%%, max slope %.0f deg" % [land, 100.0 * steep35 / maxf(land, 1), 100.0 * steep50 / maxf(land, 1), max_slope])

	_by_sea_distance(h, side)

	# Spawn gate: within 30 m of the spawn point.
	var low: float = 1.0e9
	var high: float = -1.0e9
	var worst: float = 0.0

	for dz in range(-30, 31, 4):
		for dx in range(-30, 31, 4):
			if dx * dx + dz * dz > 900:
				continue

			var column: int = int((SPAWN.x + float(dx)) / CELL_M) - origin_x
			var row: int = int((SPAWN.y + float(dz)) / CELL_M) - origin_z
			var i: int = row * side + column
			var sx: float = (h[i + 1] - h[i - 1]) / (2.0 * CELL_M)
			var sz: float = (h[i + side] - h[i - side]) / (2.0 * CELL_M)
			low = minf(low, h[i])
			high = maxf(high, h[i])
			worst = maxf(worst, rad_to_deg(atan(sqrt(sx * sx + sz * sz))))

	var gate: bool = low > 30.0 and high < 33.0 and worst < 8.0
	print("spawn gate: %.2f..%.2f m, max slope %.1f deg -> %s" % [low, high, worst, "PASS" if gate else "FAIL"])
	quit(0 if gate else 1)


# Height by distance from the sea (the real measure of "flat inland"): chamfer distance on a 4x thinned grid, then the 10th
# percentile / median / 90th percentile of height per distance band.
func _by_sea_distance(h: PackedFloat32Array, side: int) -> void:
	var step: int = 4
	var n: int = side / step
	var dist: PackedFloat32Array = PackedFloat32Array()
	dist.resize(n * n)

	for row in range(n):
		for column in range(n):
			dist[row * n + column] = 0.0 if h[row * step * side + column * step] <= 0.0 else 1.0e9

	for row in range(n):
		for column in range(n):
			var at: int = row * n + column
			var best: float = dist[at]

			if column > 0:
				best = minf(best, dist[at - 1] + 1.0)
			if row > 0:
				best = minf(best, dist[at - n] + 1.0)
				if column > 0:
					best = minf(best, dist[at - n - 1] + 1.4142)
				if column < n - 1:
					best = minf(best, dist[at - n + 1] + 1.4142)

			dist[at] = best

	for row in range(n - 1, -1, -1):
		for column in range(n - 1, -1, -1):
			var at: int = row * n + column
			var best: float = dist[at]

			if column < n - 1:
				best = minf(best, dist[at + 1] + 1.0)
			if row < n - 1:
				best = minf(best, dist[at + n] + 1.0)
				if column < n - 1:
					best = minf(best, dist[at + n + 1] + 1.4142)
				if column > 0:
					best = minf(best, dist[at + n - 1] + 1.4142)

			dist[at] = best

	print("height by distance from the sea (tile only; targets p10 >= ~0.5 x curve):")

	for band in [[300.0, 700.0], [700.0, 1000.0], [1000.0, 1500.0], [1500.0, 2000.0], [2000.0, 3000.0], [3000.0, 4000.0]]:
		var values: Array = []

		for i in range(n * n):
			var d_m: float = dist[i] * float(step) * CELL_M

			if d_m >= band[0] and d_m < band[1]:
				values.append(h[(i / n) * step * side + (i % n) * step])

		values.sort()

		if values.size() < 20:
			print("  %4.0f-%4.0f m: too few cells" % [band[0], band[1]])
			continue

		print("  %4.0f-%4.0f m: %6d cells  p10 %4.0f  median %4.0f  p90 %4.0f  max %4.0f" % [band[0], band[1], values.size(), values[values.size() / 10], values[values.size() / 2], values[values.size() * 9 / 10], values[values.size() - 1]])
