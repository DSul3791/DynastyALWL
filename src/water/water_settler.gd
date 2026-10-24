extends RefCounted

# Builds a tile's water simulation from its painted rivers and lakes
# (DESIGN_IDEAS 6.18): a spring at each river head, moved to flat high ground close
# by. Used by the settle tool and by the server's live water.

const WaterSim := preload("res://src/water/water_sim.gd")

const RIVER := 3
const LAKE := 2
const HEAD_RADIUS := 10           # cells (80 m): a river cell this high among the river cells around it is a head
const PLATEAU_SEARCH := 15        # cells (120 m) to look for flat high ground near a head
const POND_FULL_FLOW_M := 125.0   # a head pond this wide or smaller gets the base spring flow
const PLATEAU_RANGE_M := 3.0      # height range on the ring that counts as flat
const RULES_PATH := "res://data/water_settle.json"
const TileFileScript := preload("res://src/worldgen/tile/tile_file.gd")
const VERSION := 2                # the rules version printed by the settle tool and the report (data/water_settle.json "version")


# The settle rules (data/water_settle.json); {} when the file is missing or broken.
static func rules() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH)) if FileAccess.file_exists(RULES_PATH) else null
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


# The drainage the tile file stores, in cells per sample (decode_flow), or empty when the tile has none (placeholder, old bake, section all zero).
static func flow_of(data, generator) -> PackedFloat32Array:
	var path: String = "%s/tile_%d_%d.tile" % [str(generator.tiles_dir), data.tile.x, data.tile.y]
	var head: Dictionary = TileFileScript.read_header(path)

	if not bool(head.get("ok", false)):
		return PackedFloat32Array()

	var flow: PackedFloat32Array = TileFileScript.decode_flow(TileFileScript.read_section(path, head["table"], "flow")["raw"])
	var biggest: float = 0.0

	for value in flow:
		biggest = maxf(biggest, value)

	return flow if biggest > 2.0 and flow.size() == data.samples * data.samples else PackedFloat32Array()


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
# spring's flow in m3 per second.
static func build(data, rate: float, generator, seed_painted: bool = true):
	var side: int = data.samples
	var sim = WaterSim.new()
	sim.setup(side, data.spacing_m, _drawn_ground(data, generator))

	if seed_painted:
		var start: PackedFloat32Array = PackedFloat32Array()
		start.resize(side * side)

		for k in range(side * side):
			var surface: float = data.water_surface[k]

			if (data.water_class[k] == RIVER or data.water_class[k] == LAKE) and not is_nan(surface) and surface > sim.ground[k]:
				start[k] = surface - sim.ground[k]

		sim.set_depth(start)

	var placed: Array = []

	# Highest head first: a big head pond has several heads and keeps the spring of the first one that
	# reaches it, so the highest pond (not a lower basin beside it that the outlet carve made) gets it.
	var heads: Array = _find_heads(data, side)
	heads.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return data.heights[a.y * side + a.x] > data.heights[b.y * side + b.x])

	for head in heads:
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
		# Owner (2026-10-20): one spring per pond, its flow growing with the pond (1x up to
		# POND_FULL_FLOW_M across, then in step with the diameter).
		var factor: float = 1.0 if seed_painted and _pond_near(data, head, side).x < 0 else flow_factor(_pond_diameter_m(data, spot, side))
		sim.add_spring(spot.x, spot.y, rate * factor)

	_add_feeders(sim, data, generator, side, placed, rate)
	sim.wake_all_wet()
	return sim


# A spring for every river head the pond springs do not serve (a tributary head near a bigger river is not the highest river cell in its 80 m, so
# _find_heads skips it and the stretch below it stays dry). Its size follows the drainage area at the head: rate x (area / full_km2) ^ p, clamped.
# Rule-based, row by row, so the same tile always gets the same springs. Does nothing without the tile's flow map or when disabled in the rules.
static func _add_feeders(sim, data, generator, side: int, placed: Array, rate: float) -> int:
	var cfg: Dictionary = rules().get("feeders", {})

	if not bool(cfg.get("enabled", false)) or generator == null or str(generator.tiles_dir) == "":
		return 0

	var flow: PackedFloat32Array = flow_of(data, generator)

	if flow.is_empty():
		return 0

	var near: float = float(cfg.get("near_cells", 30))
	var added: int = 0

	for j in range(4, side - 4):
		for i in range(4, side - 4):
			var k: int = j * side + i

			if data.water_class[k] != RIVER or not _is_top(data, side, i, j):
				continue

			var served: bool = false

			for other in placed:
				if Vector2(i - other.x, j - other.y).length() < near:
					served = true
					break

			if served:
				continue

			var km2: float = flow[k] * data.spacing_m * data.spacing_m / 1.0e6
			var share: float = feeder_share(km2, cfg)
			placed.append(Vector2i(i, j))
			sim.add_spring(i, j, rate * share)
			added += 1

	return added


# The feeder spring as a share of the base spring: (area / full_km2) ^ p, clamped to min_share .. 1 (Q = k * A^p with k = rate / full_km2^p).
static func feeder_share(km2: float, cfg: Dictionary) -> float:
	return clampf(pow(km2 / maxf(float(cfg.get("full_km2", 3.0)), 0.01), float(cfg.get("p", 0.8))), float(cfg.get("min_share", 0.1)), 1.0)


# A water cell (river or lake) with no higher water cell among its eight neighbours (a tie goes to the lower index).
static func _is_top(data, side: int, i: int, j: int) -> bool:
	var k: int = j * side + i
	var here: float = data.heights[k]

	for dj in range(-1, 2):
		for di in range(-1, 2):
			var n: int = k + dj * side + di

			if n != k and data.water_class[n] != 0 and (data.heights[n] > here or (data.heights[n] == here and n < k)):
				return false

	return true


# Spring flow for a pond of this diameter, as a multiple of the base spring: 1 up to
# POND_FULL_FLOW_M, then in step with the diameter. The generator sizes the brook from
# the same number.
static func flow_factor(diameter_m: float, full_m: float = POND_FULL_FLOW_M) -> float:
	return maxf(diameter_m / full_m, 1.0)


# The pond's width around a spot inside it: the median of eight rays out to dry ground
# (the ray that runs up the brook is just one of the eight).
static func _pond_diameter_m(data, spot: Vector2i, side: int) -> float:
	var lengths: Array = []

	for r in range(8):
		var angle: float = TAU * float(r) / 8.0
		var steps: int = 0

		while steps < 40:
			var i: int = spot.x + int(round(cos(angle) * float(steps + 1)))
			var j: int = spot.y + int(round(sin(angle) * float(steps + 1)))

			if i < 0 or j < 0 or i >= side or j >= side or data.water_class[j * side + i] == 0:
				break

			steps += 1

		lengths.append(float(steps))

	lengths.sort()
	return (lengths[3] + lengths[4]) * data.spacing_m


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
		return _pond_middle(data, pond, side)

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
				var ring_row: int = clampi(j + int(round(sin(angle) * 10.0)), 0, side - 1)   # the ring (10) can pass the 4-cell edge guard
				var ring_column: int = clampi(i + int(round(cos(angle) * 10.0)), 0, side - 1)
				var h: float = sim.ground[ring_row * side + ring_column]
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


# Owner report (2026-10-21, build 333): a head pond was empty while its river ran. The spot
# found next to the head can be in the pond's outlet lobe or the brook beside it, so the spring
# poured into the channel below the pond and the pond never filled. The spring belongs in the
# middle of the pond: from `spot`, the water cell furthest from dry ground (the shortest of
# eight rays out to dry ground, the longest of these within POND_MIDDLE_SEARCH cells).
# Bowls whose water levels differ by less than this count as one pond for the pick below.
const POND_LEVEL_TIE_M := 2.0
const POND_MIDDLE_SEARCH := 26
const POND_MIDDLE_RAY_MAX := 30


static func _pond_middle(data, spot: Vector2i, side: int) -> Vector2i:
	var best: Vector2i = spot
	var best_reach: int = _dry_reach(data, spot, side)
	var pond_level: float = data.water_surface[spot.y * side + spot.x]

	for dj in range(-POND_MIDDLE_SEARCH, POND_MIDDLE_SEARCH + 1):
		for di in range(-POND_MIDDLE_SEARCH, POND_MIDDLE_SEARCH + 1):
			var i: int = spot.x + di
			var j: int = spot.y + dj

			if i < 12 or j < 12 or i >= side - 12 or j >= side - 12 or data.water_class[j * side + i] == 0:
				continue

			# Only this pond's own water: a wider, lower basin joined to it by the outlet carve is not its middle.
			var level: float = data.water_surface[j * side + i]

			if not is_nan(pond_level) and not is_nan(level) and absf(level - pond_level) > POND_LEVEL_TIE_M:
				continue

			var reach: int = _dry_reach(data, Vector2i(i, j), side, best_reach)

			if reach > best_reach:
				best_reach = reach
				best = Vector2i(i, j)

	return best


# Steps from `at` to dry ground along the shortest of eight rays (capped); stops early once it
# is no better than `to_beat`.
static func _dry_reach(data, at: Vector2i, side: int, to_beat: int = -1) -> int:
	var shortest: int = POND_MIDDLE_RAY_MAX

	for r in range(8):
		var angle: float = TAU * float(r) / 8.0
		var di: float = cos(angle)
		var dj: float = sin(angle)
		var steps: int = 0

		while steps < shortest:
			var i: int = at.x + int(round(di * float(steps + 1)))
			var j: int = at.y + int(round(dj * float(steps + 1)))

			if i < 0 or j < 0 or i >= side or j >= side or data.water_class[j * side + i] == 0:
				break

			steps += 1

		shortest = mini(shortest, steps)

		if shortest <= to_beat:
			return shortest

	return shortest


# A spot inside the head pond near a river head (the spring pours in there, the pond fills
# and spills into the river), or (-1, -1) when there is none close by.
static func _pond_near(data, head: Vector2i, side: int) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_dist: float = INF
	var best_level: float = -INF

	for dj in range(-PLATEAU_SEARCH, PLATEAU_SEARCH + 1):
		for di in range(-PLATEAU_SEARCH, PLATEAU_SEARCH + 1):
			var i: int = head.x + di
			var j: int = head.y + dj

			if i < 12 or j < 12 or i >= side - 12 or j >= side - 12 or data.water_class[j * side + i] == 0:
				continue

			# Inside a bowl: every cell a ring of steps around it stands at least 5 m above it,
			# which a river gorge never does.
			var floor_here: float = data.heights[j * side + i]
			var inside: bool = false

			# Head ponds are 35 m across now (owner, 2026-10-19), older tiles have 240, 120 or
			# 60 m ones: try a ring just inside each size.
			# Owner report (2026-10-20, an empty head pond): the pond's own outlet notch is lower
			# than the walls, so one or two ring points (one side) may miss, as long as none
			# lies below the floor; a gorge always drops away below it downstream.
			for ring in [14.0, 7.0, 3.0, 2.0]:
				var misses: int = 0

				for r in range(8):
					var angle: float = TAU * float(r) / 8.0
					# The ring (up to 14 cells) can reach past the tile edge from a centre 12 cells in: clamp.
					var ring_row: int = clampi(j + int(round(sin(angle) * ring)), 0, side - 1)
					var ring_column: int = clampi(i + int(round(cos(angle) * ring)), 0, side - 1)
					var h: float = data.heights[ring_row * side + ring_column]

					if h < floor_here - 0.5:
						misses = 8
						break

					if h < floor_here + 5.0:
						misses += 1

				if misses <= 2:
					inside = true
					break

			var dist: float = sqrt(float(di * di + dj * dj))
			var surface: float = data.water_surface[j * side + i]
			var level: float = surface if not is_nan(surface) else floor_here

			# The head pond is the highest bowl near the head: v25's wide outlet carve left a lower basin
			# beside it that a nearest-first pick chose (the real pond stayed dry, the basin filled and spilled).
			if not inside:
				continue

			if level > best_level + POND_LEVEL_TIE_M or (level > best_level - POND_LEVEL_TIE_M and dist < best_dist):
				best_level = maxf(best_level, level)
				best_dist = dist
				best = Vector2i(i, j)

	# Owner (2026-10-19): the spring sits in the pond itself and simply keeps pouring in: the pond fills until it overflows its lowest lip into the brook.
	return best
