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


# A simulation started from the painted water with springs placed. `rate` is each
# spring's meters of water per tick.
static func build(data, rate: float):
	var side: int = data.samples
	var sim = WaterSim.new()
	sim.setup(side, data.spacing_m, data.heights.duplicate())

	for k in range(side * side):
		var surface: float = data.water_surface[k]

		if (data.water_class[k] == RIVER or data.water_class[k] == LAKE) and not is_nan(surface) and surface > sim.ground[k]:
			sim.depth[k] = surface - sim.ground[k]

	for head in _find_heads(data, side):
		var spot: Vector2i = _plateau_near(sim, head, side)
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
static func _plateau_near(sim, head: Vector2i, side: int) -> Vector2i:
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
				var h: float = sim.ground[(j + int(round(sin(angle) * 4.0))) * side + i + int(round(cos(angle) * 4.0))]
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
