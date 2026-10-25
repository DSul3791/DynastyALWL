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
const HollowFinder := preload("res://src/water/hollow_finder.gd")
const TileFileScript := preload("res://src/worldgen/tile/tile_file.gd")
const VERSION := 10               # the rules version printed by the settle tool and the report (data/water_settle.json "version")


# The settle rules (data/water_settle.json); {} when the file is missing or broken.
static func rules() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH)) if FileAccess.file_exists(RULES_PATH) else null
	var out: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}

	for key in rules_override:
		out[key] = rules_override[key]

	return out


# Tools and tests set keys here to compare rule versions (land_map.gd --old-rules); empty in the game.
static var rules_override: Dictionary = {}


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
# Where each spring of the last build came from, in the order of sim.springs: "head" (_find_heads, moved to a plateau or pond middle),
# "feeder_river" (a painted river cell that is the highest of its 3 x 3) or "feeder_pond" (a pond with an outlet). For the land map tool.
static var last_kinds: Array = []


static func build(data, rate: float, generator, seed_painted: bool = true):
	last_kinds = []
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
	var flow_all: PackedFloat32Array = flow_of(data, generator)
	var heads: Array = _find_heads(data, side)
	heads.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return data.heights[a.y * side + a.x] > data.heights[b.y * side + b.x])

	for head in heads:
		# Dry start (owner, 2026-10-18): water comes only from head ponds. A head with no
		# pond (a river entering from the next tile, a short brook) got a spring on bare
		# hillside that flooded the flatland.
		if not seed_painted and _pond_near(data, head, side).x < 0:
			continue

		var spot: Vector2i = _plateau_near(sim, head, side, data)
		var in_pond: bool = _pond_near(data, head, side).x >= 0

		# Dave 24 Oct 2026: water sources start in a natural catch basin. A river head (no pond) keeps its spring ON the head, where the bake carves the basin;
		# the plateau move put springs on open ground. Ponds keep their pond middle.
		if bool(rules().get("springs_at_heads", false)) and not in_pond:
			spot = head

		# Steep ground (v6, Sonny 24 Oct): a spring on a rock face is a sheet running down it. Move it up the painted river to ground that is not
		# steep, or drop it.
		spot = _off_steep(data, side, spot)

		if spot.x < 0:
			continue

		var duplicate: bool = false

		# A big head pond has several "heads" around its edge: one spring per pond.
		for other in placed:
			if Vector2(spot - other).length() < 30.0:
				duplicate = true

		if duplicate:
			continue

		placed.append(spot)
		# Owner (2026-10-20): one spring per pond, its flow growing with the pond (1x up to
		# POND_FULL_FLOW_M across, then in step with the diameter). v6 ("catchment" in the rules): the flow follows the catchment above the head instead.
		var factor: float = 1.0 if seed_painted and not in_pond else flow_factor(_pond_diameter_m(data, spot, side))
		var q: float = rate * factor

		if catchment_on():
			q = catchment_flow(_head_km2(data, flow_all, side, spot, 20 if in_pond else HEAD_KM2_REACH))

		sim.add_spring(spot.x, spot.y, q)
		last_kinds.append("head")

	_add_feeders(sim, data, generator, side, placed, rate, heads)
	_add_hollow_springs(sim, data, flow_all, side, placed)
	_add_edge_inflows(sim, data, flow_all, side, placed)
	sim.wake_all_wet()
	return sim


# Hollow springs (v7, Sonny 24 Oct 2026: otherwise a bowl with no river stays dry). Every natural hollow or carved bowl of min_depth_m and min_area_m2 or more
# that holds no spring gets an inflow at its deepest cell: catchment_flow of the biggest drainage on its cells (0.35 km2 without a flow map).
static func _add_hollow_springs(sim, data, flow: PackedFloat32Array, side: int, placed: Array) -> int:
	var cfg: Dictionary = rules().get("hollow_springs", {})

	if not bool(cfg.get("enabled", false)):
		return 0

	var step: int = int(cfg.get("step", 2))
	var added: int = 0

	for hollow in HollowFinder.find(data, step, float(cfg.get("min_depth_m", 1.5))):
		if float(hollow["area_m2"]) < float(cfg.get("min_area_m2", 5000.0)):
			continue

		var coarse: int = hollow["side"]
		var members: Dictionary = {}
		var km2: float = 0.35

		if not flow.is_empty():
			km2 = 0.0

		for k in hollow["cells"]:
			members[k] = true

			if not flow.is_empty():
				km2 = maxf(km2, flow[(k / coarse) * step * side + (k % coarse) * step] * data.spacing_m * data.spacing_m / 1.0e6)

		var served: bool = false

		for other in placed:
			if members.has((other.y / step) * coarse + other.x / step):
				served = true
				break

		if served:
			continue

		var deepest: int = hollow["cell"]
		@warning_ignore("integer_division")
		var at: Vector2i = Vector2i(deepest % side, deepest / side)
		placed.append(at)
		sim.add_spring(at.x, at.y, catchment_flow(km2))
		last_kinds.append("hollow")
		added += 1

	return added


# Edge inflows (v9): a painted river that runs into the tile over its edge from the next tile (its top is outside this tile, so no head here) gets a
# spring on the edge cell, sized like a head from the drainage on that cell. A river cell on the outer row or column counts when the ground a cell inside
# is lower; one spring per river (none if a spring is within near_cells already).
static func _add_edge_inflows(sim, data, flow: PackedFloat32Array, side: int, placed: Array) -> int:
	var cfg: Dictionary = rules().get("edge_inflows", {})

	if not bool(cfg.get("enabled", false)) or flow.size() != side * side:
		return 0

	var near: float = float(rules().get("feeders", {}).get("near_cells", 30))
	var reach: int = int(cfg.get("reach_cells", 4))
	var found: Array = []

	for n in range(side):
		for edge in [Vector2i(n, 0), Vector2i(n, side - 1), Vector2i(0, n), Vector2i(side - 1, n)]:
			var k: int = edge.y * side + edge.x

			if data.water_class[k] != RIVER or flow[k] <= 0.0:
				continue

			@warning_ignore("integer_division")
			var dx: int = signi(side / 2 - edge.x) if edge.x == 0 or edge.x == side - 1 else 0
			@warning_ignore("integer_division")
			var dy: int = signi(side / 2 - edge.y) if edge.y == 0 or edge.y == side - 1 else 0

			# The ground a few cells inside is lower: the river runs on into the tile (a bump of a few dm right at the edge does not count).
			if data.heights[(edge.y + dy * reach) * side + edge.x + dx * reach] >= data.heights[k]:
				continue

			found.append([flow[k], edge])

	# The biggest drainage first, so the spring sits on the river's main cell, not on the thin bank cell beside it.
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var added: int = 0

	for entry in found:
		var edge: Vector2i = entry[1]
		var served: bool = false

		for other in placed:
			if Vector2(edge.x - other.x, edge.y - other.y).length() < near:
				served = true
				break

		if served:
			continue

		placed.append(edge)
		sim.add_spring(edge.x, edge.y, catchment_flow(float(entry[0]) * data.spacing_m * data.spacing_m / 1.0e6))
		last_kinds.append("edge")
		added += 1

	return added


# A spring for every river head the pond springs do not serve (a tributary head near a bigger river is not the highest river cell in its 80 m, so
# _find_heads skips it and the stretch below it stays dry). Its size follows the drainage area at the head: rate x (area / full_km2) ^ p, clamped.
# Rule-based, row by row, so the same tile always gets the same springs. Does nothing without the tile's flow map or when disabled in the rules.
static func _add_feeders(sim, data, generator, side: int, placed: Array, rate: float, heads: Array = []) -> int:
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

			var kind: int = data.water_class[k]

			# A pond cell is tried as it comes (row by row): the first one of a pond that has an outlet and no spring near gets the spring, the rest of the pond is then near it.
			# (A pond's cell heights are its bed, so "highest cell" means nothing for ponds; the outlet test uses the water surface.)
			if kind != LAKE and not (kind == RIVER and _is_top(data, side, i, j)):
				continue

			# A pond is fed only when a painted river runs out of it (a river cell lower than the pond within outlet_cells); a pond with no outlet is a natural pond.
			var outlet_flow: float = flow[k]

			if kind == LAKE:
				outlet_flow = _outlet_flow(data, flow, side, i, j, int(cfg.get("outlet_cells", 20)))

				if outlet_flow <= 0.0:
					continue

			# Dave 24 Oct 2026 (springs only at river heads): a river cell that is only the highest of its 3 x 3 (a bump in the painted bed) is no head.
			# It snaps to the nearest real head within snap_cells, or the spring is dropped.
			var at: Vector2i = Vector2i(i, j)

			if kind == RIVER and bool(rules().get("springs_at_heads", false)) and not _is_top_in(data, side, i, j, HEAD_RADIUS):
				at = _nearest_head(heads, at, int(cfg.get("snap_cells", 25)))

				if at.x < 0:
					continue

			var served: bool = false

			for other in placed:
				if Vector2(at.x - other.x, at.y - other.y).length() < near:
					served = true
					break

			if served:
				continue

			var km2: float = outlet_flow * data.spacing_m * data.spacing_m / 1.0e6
			var share: float = feeder_share(km2, cfg)
			placed.append(at)
			sim.add_spring(at.x, at.y, catchment_flow(km2) if catchment_on() else rate * share)
			last_kinds.append("feeder_pond" if kind == LAKE else "feeder_river")
			added += 1

	return added


# The biggest drainage on a painted river cell lower than the pond cell (i, j) within `reach` cells: the river that leaves the pond; 0 when none.
static func _outlet_flow(data, flow: PackedFloat32Array, side: int, i: int, j: int, reach: int) -> float:
	var surface: float = data.water_surface[j * side + i]
	var here: float = surface if not is_nan(surface) else data.heights[j * side + i]      # the pond's water level; its cell height is the bed
	var best: float = 0.0

	for dj in range(-reach, reach + 1):
		for di in range(-reach, reach + 1):
			var ni: int = i + di
			var nj: int = j + dj

			if ni < 0 or nj < 0 or ni >= side or nj >= side:
				continue

			var n: int = nj * side + ni

			if n != j * side + i and data.water_class[n] == RIVER and data.heights[n] <= here:
				best = maxf(best, flow[n])

	return best


# Thin-film option (data/water_settle.json "film", off by default): a painted river cell that carries real drainage and holds a film of settled water
# (min_seen_m up to depth_m) is raised to depth_m, so a river that runs at 0.03 to 0.1 m is drawn as water, not as a dry gap. The added water is
# counted (volume m3) and printed by the settle tool; it is a look setting, not a flow result. Returns {"cells", "volume_m3"}.
static func film_floor(depth: PackedFloat32Array, water_class: PackedByteArray, flow: PackedFloat32Array, spacing_m: float, cfg: Dictionary) -> Dictionary:
	var result: Dictionary = {"cells": 0, "volume_m3": 0.0}

	if not bool(cfg.get("enabled", false)) or flow.size() != depth.size():
		return result

	var target: float = float(cfg.get("depth_m", 0.13))
	var seen: float = float(cfg.get("min_seen_m", 0.02))
	var min_cells: float = float(cfg.get("min_km2", 0.05)) * 1.0e6 / maxf(spacing_m * spacing_m, 1.0)      # km2 of catchment as drained cells

	for k in range(depth.size()):
		if water_class[k] == RIVER and flow[k] >= min_cells and depth[k] >= seen and depth[k] < target:
			result["volume_m3"] = float(result["volume_m3"]) + (target - depth[k]) * spacing_m * spacing_m
			depth[k] = target
			result["cells"] = int(result["cells"]) + 1

	return result


# Seam stitch: tile A's last column (east, dir 0) or last row (south, dir 1) is the same ground as tile B's first column or row, so the settled
# depth there must be the same. Both get the larger of the two (water on one side only is water on both). Returns the number of cells changed.
static func stitch_edge(a: PackedFloat32Array, b: PackedFloat32Array, side: int, dir: int) -> int:
	var changed: int = 0

	for n in range(side):
		var ka: int = n * side + (side - 1) if dir == 0 else (side - 1) * side + n
		var kb: int = n * side if dir == 0 else n
		var deep: float = maxf(a[ka], b[kb])

		if a[ka] != deep:
			a[ka] = deep
			changed += 1

		if b[kb] != deep:
			b[kb] = deep
			changed += 1

	return changed


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


# Spring flow that follows the catchment (v6, data/water_settle.json "catchment"; Sonny and Dave 24 Oct 2026: a 35 m pond got 100 m3/s).
# m3 per second at the game's x1 flow key, = m3s_per_km2 x catchment km2, clamped to min_m3s .. max_m3s. The game multiplies it by the flow key (x10 start).
static func catchment_on() -> bool:
	return bool(rules().get("catchment", {}).get("enabled", false))


static func catchment_flow(km2: float) -> float:
	var cfg: Dictionary = rules().get("catchment", {})
	return clampf(float(cfg.get("m3s_per_km2", 0.1)) * maxf(km2, 0.0), float(cfg.get("min_m3s", 0.01)), float(cfg.get("max_m3s", 2.0)))


const HEAD_KM2_REACH := 6             # cells downstream of a head searched for its first drainage (the head cell itself holds 1 cell)

# The catchment above a head in km2: the biggest drainage on a painted river cell within `reach` cells of it (the head cell holds only itself).
# 0.35 km2, the river start threshold of the bake, when the tile has no flow map.
static func _head_km2(data, flow: PackedFloat32Array, side: int, at: Vector2i, reach: int) -> float:
	if flow.is_empty():
		return 0.35

	var best: float = 0.0

	for dj in range(-reach, reach + 1):
		for di in range(-reach, reach + 1):
			var ni: int = at.x + di
			var nj: int = at.y + dj

			if ni < 0 or nj < 0 or ni >= side or nj >= side:
				continue

			var n: int = nj * side + ni

			if data.water_class[n] == RIVER:
				best = maxf(best, flow[n])

	return maxf(best * data.spacing_m * data.spacing_m / 1.0e6, 0.0)


# Steeper than this is a rock face (v6): the slope is the biggest drop to a neighbour over the cell spacing.
const STEEP_TAN := 0.466              # tan 25 degrees

static func _is_steep(data, side: int, i: int, j: int) -> bool:
	if i < 1 or j < 1 or i >= side - 1 or j >= side - 1:
		return false

	var k: int = j * side + i
	var drop: float = 0.0

	for n in [k - 1, k + 1, k - side, k + side]:
		drop = maxf(drop, absf(data.heights[k] - data.heights[n]))

	return drop / data.spacing_m > STEEP_TAN


# `spot` itself when the ground is not steep; else the nearest higher painted river cell within 15 cells that is not steep; else (-1, -1).
static func _off_steep(data, side: int, spot: Vector2i) -> Vector2i:
	if not bool(rules().get("steep", {}).get("enabled", false)) or not _is_steep(data, side, spot.x, spot.y):
		return spot

	var here: float = data.heights[spot.y * side + spot.x]
	var best: Vector2i = Vector2i(-1, -1)
	var best_d: float = INF

	for dj in range(-15, 16):
		for di in range(-15, 16):
			var ni: int = spot.x + di
			var nj: int = spot.y + dj

			if ni < 1 or nj < 1 or ni >= side - 1 or nj >= side - 1:
				continue

			var n: int = nj * side + ni

			if data.water_class[n] != RIVER or data.heights[n] < here or _is_steep(data, side, ni, nj):
				continue

			var d: float = float(di * di + dj * dj)

			if d < best_d:
				best_d = d
				best = Vector2i(ni, nj)

	return best


# The nearest of `heads` within `reach` cells of `from`; (-1, -1) when none.
static func _nearest_head(heads: Array, from: Vector2i, reach: int) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_d: float = float(reach)

	for head in heads:
		var d: float = Vector2(head - from).length()

		if d <= best_d:
			best_d = d
			best = head

	return best


# Whether the cell is the highest water cell within `radius` cells (the same test as _find_heads, for any cell).
static func _is_top_in(data, side: int, i: int, j: int, radius: int) -> bool:
	var k: int = j * side + i
	var here: float = data.heights[k]

	for dj in range(-radius, radius + 1):
		for di in range(-radius, radius + 1):
			var ni: int = i + di
			var nj: int = j + dj

			if ni < 0 or nj < 0 or ni >= side or nj >= side:
				continue

			var n: int = nj * side + ni

			if n != k and data.water_class[n] == RIVER and (data.heights[n] > here or (data.heights[n] == here and n < k)):
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

	# The whole tile (v9): the old range left out the HEAD_RADIUS cells at each edge, so a river painted from 80 m inside the edge (its top is in the next tile)
	# had no head and no spring (tile 3,4 river at x60192 z76736). Neighbours outside the tile do not count.
	for j in range(side):
		for i in range(side):
			var k: int = j * side + i

			if data.water_class[k] != RIVER:
				continue

			var here: float = data.heights[k]
			var top: bool = true

			for dj in range(maxi(-HEAD_RADIUS, -j), mini(HEAD_RADIUS, side - 1 - j) + 1):
				for di in range(maxi(-HEAD_RADIUS, -i), mini(HEAD_RADIUS, side - 1 - i) + 1):
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
