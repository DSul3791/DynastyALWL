extends RefCounted

# Builds a tile's water simulation from its painted rivers and lakes
# (DESIGN_IDEAS 6.18): a spring at each river head, moved to flat high ground close
# by. Used by the settle tool and by the server's live water.

const WaterSim := preload("res://src/water/water_sim.gd")

const RIVER := 3
const LAKE := 2
const HEAD_RADIUS := 10           # cells (80 m): a river cell this high among the river cells around it is a head
const PLATEAU_SEARCH := 15        # cells (120 m) to look for flat high ground near a head
const PLATEAU_RANGE_M := 3.0      # height range on the ring that counts as flat


# The ground as it is drawn: the map height plus the fine detail noise the voxel
# generator adds on dry land (up to about 0.9 m, which matters to shallow water).
static func _drawn_ground(data, generator) -> PackedFloat32Array:
	var ground: PackedFloat32Array = data.heights.duplicate()
	var side: int = data.samples

	for j in range(side):
		for i in range(side):
			var k: int = j * side + i

			if ground[k] > 0.0:
				ground[k] += generator._detail_at(data, data.x0 + float(i) * data.spacing_m, data.z0 + float(j) * data.spacing_m, data.spacing_m)

	return ground


# A simulation started from the painted water with springs placed. `rate` is each
# spring's meters of water per tick.
static func build(data, rate: float, generator, seed_painted: bool = true):
	var side: int = data.samples
	var sim = WaterSim.new()
	sim.setup(side, data.spacing_m, _drawn_ground(data, generator))

	for k in range(side * side if seed_painted else 0):
		var surface: float = data.water_surface[k]

		if (data.water_class[k] == RIVER or data.water_class[k] == LAKE) and not is_nan(surface) and surface > sim.ground[k]:
			sim.depth[k] = surface - sim.ground[k]

	var placed: Array = []

	for head in _find_heads(data, side):
		# Dry start (owner, 2026-10-18): water comes only from head ponds. A head with no
		# pond (a river entering from the next tile, a short brook) got a spring on bare
		# hillside that flooded the flatland.
		if not seed_painted and _pond_near(data, head, side).x < 0:
			continue

		var spot: Vector2i = _plateau_near(sim, head, side, data)
		var duplicate: bool = false

		# A big head pond has several "heads" around its edge: one spring per pond.
		for other in placed:
			if Vector2(spot - other).length() < 30.0:
				duplicate = true

		if duplicate:
			continue

		placed.append(spot)
		sim.add_spring(spot.x, spot.y, rate)

	sim.wake_all_wet()
	return sim


# River cells that are the highest river cell around them.
static func _find_heads(data, side: int) -> Array:
	var heads: Array = []

	for j in range(HEAD_RADIUS, side - HEAD_RADIUS):
		for i in range(HEAD_RADIUS, side - HEAD_RADIUS):
			var k: int = j * side + i

			if data.water_class[k] != RIVER:
				continue

			var here: float = data.heights[k]
			var top: bool = true

			for dj in range(-HEAD_RADIUS, HEAD_RADIUS + 1):
				for di in range(-HEAD_RADIUS, HEAD_RADIUS + 1):
					var n: int = k + dj * side + di

					if n != k and data.water_class[n] == RIVER and (data.heights[n] > here or (data.heights[n] == here and n < k)):
						top = false
						break

				if not top:
					break

			if top:
				heads.append(Vector2i(i, j))

	return heads


# Springs belong on flat high ground (a plateau or the very top of a rise), not on a
# hillside: look near the head for the flattest cell that is not lower than it.
static func _plateau_near(sim, head: Vector2i, side: int, data = null) -> Vector2i:
	var pond: Vector2i = _pond_near(data, head, side) if data != null else Vector2i(-1, -1)

	if pond.x >= 0:
		return pond

	var best: Vector2i = head
	var best_score: float = INF
	var head_height: float = sim.ground[head.y * side + head.x]

	for dj in range(-PLATEAU_SEARCH, PLATEAU_SEARCH + 1):
		for di in range(-PLATEAU_SEARCH, PLATEAU_SEARCH + 1):
			var i: int = head.x + di
			var j: int = head.y + dj

			if i < 4 or j < 4 or i >= side - 4 or j >= side - 4:
				continue

			var k: int = j * side + i

			if sim.ground[k] < head_height - 1.0:
				continue

			var low: float = INF
			var high: float = -INF

			for r in range(8):
				var angle: float = TAU * float(r) / 8.0
				var h: float = sim.ground[(j + int(round(sin(angle) * 10.0))) * side + i + int(round(cos(angle) * 10.0))]
				low = minf(low, h)
				high = maxf(high, h)

			var range_m: float = high - low

			if range_m > PLATEAU_RANGE_M:
				continue

			var score: float = range_m + 0.05 * sqrt(float(di * di + dj * dj)) * sim.spacing_m * 0.1

			if score < best_score:
				best_score = score
				best = Vector2i(i, j)

	return best


# The uphill rim of the head pond near a river head (the pond holds the spring's water and
# spills it into the river), or (-1, -1) when there is none close by.
static func _pond_near(data, head: Vector2i, side: int) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_dist: float = INF

	for dj in range(-PLATEAU_SEARCH, PLATEAU_SEARCH + 1):
		for di in range(-PLATEAU_SEARCH, PLATEAU_SEARCH + 1):
			var i: int = head.x + di
			var j: int = head.y + dj

			if i < 12 or j < 12 or i >= side - 12 or j >= side - 12 or data.water_class[j * side + i] == 0:
				continue

			# The bottom of a bowl: every cell 14 steps (112 m, just inside the 120 m pond rim) around
			# it stands at least 5 m above it, which a river gorge never does. Ponds are 10 m deep
			# (owner, 2026-10-18), so the bowl wall is about 8.7 m up there.
			var floor_here: float = data.heights[j * side + i]
			var inside: bool = true

			for r in range(8):
				var angle: float = TAU * float(r) / 8.0

				if data.heights[(j + int(round(sin(angle) * 14.0))) * side + i + int(round(cos(angle) * 14.0))] < floor_here + 5.0:
					inside = false
					break

			var dist: float = sqrt(float(di * di + dj * dj))

			if inside and dist < best_dist:
				best_dist = dist
				best = Vector2i(i, j)

	# Owner's rule (2026-10-18): find the pond's lowest lip, and put the spring on the
	# opposite side of the pond, 10 m higher than that lip. Its water runs down the wall into
	# the pond, fills it to the lip and spills over there, never out over the far side.
	if best.x >= 0:
		var rim_low: float = INF
		var low_angle: float = 0.0

		for r in range(32):
			var a_r: float = TAU * float(r) / 32.0
			var rx: int = clampi(best.x + int(round(cos(a_r) * 14.0)), 0, side - 1)
			var rz: int = clampi(best.y + int(round(sin(a_r) * 14.0)), 0, side - 1)
			var rim_here: float = data.heights[rz * side + rx]

			if rim_here < rim_low:
				rim_low = rim_here
				low_angle = a_r

		var wanted: float = rim_low + 10.0
		var opposite: Vector2 = Vector2(cos(low_angle + PI), sin(low_angle + PI))
		var spot: Vector2i = best
		var spot_gap: float = INF

		for dj in range(-30, 31):
			for di in range(-30, 31):
				var i2: int = best.x + di
				var j2: int = best.y + dj

				if i2 < 4 or j2 < 4 or i2 >= side - 4 or j2 >= side - 4:
					continue

				var offset: Vector2 = Vector2(di, dj)
				var distance: float = offset.length()

				# Within a 60 degree cone on the far side, between the middle and the outer ramp.
				if distance < 8.0 or distance > 30.0 or offset.normalized().dot(opposite) < 0.866:
					continue

				var gap: float = absf(data.heights[j2 * side + i2] - wanted) + 0.01 * distance

				if gap < spot_gap:
					spot_gap = gap
					spot = Vector2i(i2, j2)

		best = spot

	return best
