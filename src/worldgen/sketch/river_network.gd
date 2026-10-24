class_name RiverNetwork
extends RefCounted

# The world's rivers, worked out once for the whole world on the 160 m
# elevation map (spec Section 4b). Every tile reads the rivers that pass
# through its frame, so a river that leaves one tile enters the next at
# the same place with the same size.
#
# How it works
#   1. Priority flood from the sea over the wrapped world: every land cell
#      learns the neighbor it drains into (its receiver). Basins are filled,
#      so every river reaches the sea.
#   2. Drainage area: each cell collects the area of every cell that drains
#      through it.
#   3. Cells whose area reaches the river threshold are river cells. They
#      are joined into chains: each chain starts at a source, follows the
#      receivers downhill and ends at the sea or where it joins a bigger
#      river. A chain remembers the area at every cell.
#   4. A tile asks for the chains that cross its frame. Each chain is drawn
#      as a smooth Catmull-Rom curve through its cell centers, sampled every
#      few meters, with the area interpolated along it.
#   5. Meander: every curve point is pushed sideways by a smooth random
#      field of world position (a sum of plane waves that repeat exactly
#      across the world wrap). Without it the curves follow the 160 m grid
#      in long straight 45 degree runs. Because the push depends only on
#      where a point is, neighboring tiles, both sides of the wrap seam and
#      a tributary meeting its main river all move the same way.
#
# Chains use unwrapped coordinates (they may run past the world edge); the
# lookup tries the world shifted by one period in each direction.

var size_x: int = 0
var size_z: int = 0
var cell_m: float = 160.0
var origin_x: float = 0.0
var origin_z: float = 0.0
var river_cells: int = 0
var ponds: Array = []              # head ponds (place_ponds): {"centre", "level", "heads"}
var chains: Array = []             # {"points": PackedVector2Array, "areas": PackedFloat32Array (km2), "bounds": Rect2}

var _receiver: PackedInt32Array = PackedInt32Array()
var _area_cells: PackedFloat32Array = PackedFloat32Array()
var _waves: Array = []             # meander waves: [kx, kz, phase, dx, dz, amplitude]
var _heights: PackedFloat32Array = PackedFloat32Array()   # the world elevation (meters)
var _filled: PackedFloat32Array = PackedFloat32Array()    # elevation with basins filled (water runs down it)
var _valley_cells: Dictionary = {}   # Vector2i -> [[chain, x, z, level, floor half, wall half]] (place_ponds)
var _valley_cell_m: float = 480.0
var _edge_clear_m: float = 60.0       # how far past a pond's shore the ground may not fall away
var _search_m: float = 480.0          # how far around a pond's best spot to look for flat ground clear of edges
var valley_snap_m: float = 72.0      # how far a river may slide sideways into the bottom of its valley
var meander_flat_slope: float = 0.02   # the meander is at full strength on ground flatter than this
var meander_steep_slope: float = 0.08  # and gone on ground steeper than this (owner 2026-10-19: no sideways wiggle on slopes)


func build(elevation, river_start_km2: float) -> void:
	size_x = elevation.size_x
	size_z = elevation.size_z
	cell_m = elevation.cell_m
	origin_x = elevation.origin_x
	origin_z = elevation.origin_z
	var total: int = size_x * size_z
	var heights: PackedFloat32Array = elevation.heights
	_heights = heights
	_filled = PackedFloat32Array()
	_filled.resize(total)

	# Priority flood from the sea. Heights are binned in tenths of a meter.
	var low: int = 0
	var high: int = 0

	for value in heights:
		high = maxi(high, int(value * 10.0))

	high += 2
	var head: PackedInt32Array = PackedInt32Array()
	head.resize(high - low + 2)
	head.fill(-1)
	var next: PackedInt32Array = PackedInt32Array()
	next.resize(total)
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(total)
	var level: PackedInt32Array = PackedInt32Array()
	level.resize(total)
	_receiver = PackedInt32Array()
	_receiver.resize(total)
	_receiver.fill(-1)

	for index in range(total):
		if heights[index] <= 0.0:
			seen[index] = 1

	# Land next to the sea starts the flood.
	for index in range(total):
		if seen[index] == 1:
			continue

		var row: int = index / size_x
		var column: int = index % size_x
		var touches_sea: bool = false
		var sea_cell: int = -1

		for dz in range(-1, 2):
			var nr: int = posmod(row + dz, size_z)

			for dx in range(-1, 2):
				if dx == 0 and dz == 0:
					continue

				var neighbor: int = nr * size_x + posmod(column + dx, size_x)

				if heights[neighbor] <= 0.0:
					touches_sea = true
					sea_cell = neighbor
					break

			if touches_sea:
				break

		if touches_sea:
			seen[index] = 2
			_receiver[index] = sea_cell
			_filled[index] = maxf(heights[index], 0.0)
			var key: int = maxi(int(heights[index] * 10.0), 1)
			level[index] = key
			next[index] = head[key - low]
			head[key - low] = index

	var order: PackedInt32Array = PackedInt32Array()

	for slot in range(head.size()):
		while head[slot] != -1:
			var index: int = head[slot]
			head[slot] = next[index]
			order.append(index)
			var row: int = index / size_x
			var column: int = index % size_x
			var here: int = level[index]

			for dz in range(-1, 2):
				var nr: int = posmod(row + dz, size_z)

				for dx in range(-1, 2):
					if dx == 0 and dz == 0:
						continue

					var neighbor: int = nr * size_x + posmod(column + dx, size_x)

					if seen[neighbor] != 0:
						continue

					seen[neighbor] = 2
					_receiver[neighbor] = index
					_filled[neighbor] = maxf(heights[neighbor], _filled[index])
					var filled: int = maxi(int(heights[neighbor] * 10.0), here)
					level[neighbor] = filled
					next[neighbor] = head[filled - low]
					head[filled - low] = neighbor

	# Owner (2026-10-19): water runs down the fall line. Every cell drains to its steepest
	# lower neighbor; only on flat filled ground (a filled basin or a level plain) does it
	# keep the flood's choice, which leads out of the basin by its lowest outlet.
	var position_in_order: PackedInt32Array = PackedInt32Array()
	position_in_order.resize(total)
	position_in_order.fill(-1)

	for k in range(order.size()):
		position_in_order[order[k]] = k

	for index in order:
		var row: int = index / size_x
		var column: int = index % size_x
		var here_m: float = _filled[index]
		var best_drop: float = 0.0
		var best: int = -1

		for dz in range(-1, 2):
			var nr: int = posmod(row + dz, size_z)

			for dx in range(-1, 2):
				if dx == 0 and dz == 0:
					continue

				var neighbor: int = nr * size_x + posmod(column + dx, size_x)
				var there_m: float = _filled[neighbor] if seen[neighbor] == 2 else 0.0
				var drop: float = (here_m - there_m) / (1.41421356 if dx != 0 and dz != 0 else 1.0)

				if drop > best_drop + 0.0001:
					best_drop = drop
					best = neighbor

		if best >= 0 and best_drop > 0.01:
			_receiver[index] = best

	# Drainage area: a cell drains into a lower cell, or on flat ground into one the flood
	# reached earlier, so walking from high to low (then late to early) visits every cell
	# before the cell it drains into.
	var downstream_order: Array = Array(order)
	downstream_order.sort_custom(func(a: int, b: int) -> bool:
		if _filled[a] != _filled[b]:
			return _filled[a] > _filled[b]

		return position_in_order[a] > position_in_order[b])
	order = PackedInt32Array(downstream_order)
	order.reverse()
	_area_cells = PackedFloat32Array()
	_area_cells.resize(total)

	for index in order:
		_area_cells[index] = 1.0

	for k in range(order.size() - 1, -1, -1):
		var index: int = order[k]
		var down: int = _receiver[index]

		if down >= 0 and seen[down] == 2:
			_area_cells[down] += _area_cells[index]

	_build_chains(order, seen, river_start_km2)


# Water that enters `rect` (world metres) from outside: one entry per land cell outside it whose downstream cell is inside.
# {"km2": the cell's whole catchment, "from": its centre, "to": its downstream cell's centre}. A pure function of the
# network, so two tiles that share an edge read the same amounts (tile_drainage seeds its frame edge with them).
func inflows_into(rect: Rect2) -> Array:
	var found: Array = []

	if _receiver.is_empty():
		return found

	var first_column: int = int(floor((rect.position.x - origin_x) / cell_m)) - 1
	var last_column: int = int(floor((rect.end.x - origin_x) / cell_m)) + 1
	var first_row: int = int(floor((rect.position.y - origin_z) / cell_m)) - 1
	var last_row: int = int(floor((rect.end.y - origin_z) / cell_m)) + 1
	var cell_km2: float = cell_m * cell_m * 1.0e-6

	for row in range(first_row, last_row + 1):
		for column in range(first_column, last_column + 1):
			var index: int = posmod(row, size_z) * size_x + posmod(column, size_x)
			var down: int = _receiver[index]

			if down < 0 or _heights[index] <= 0.0 or _heights[down] <= 0.0:
				continue

			var from_m: Vector2 = Vector2(origin_x + (float(column) + 0.5) * cell_m, origin_z + (float(row) + 0.5) * cell_m)

			if rect.has_point(from_m):
				continue

			var step_row: int = down / size_x - posmod(row, size_z)
			var step_column: int = down % size_x - posmod(column, size_x)

			if absi(step_row) > 1:
				step_row -= signi(step_row) * size_z

			if absi(step_column) > 1:
				step_column -= signi(step_column) * size_x

			var down_row: int = row + step_row
			var down_column: int = column + step_column
			var to_m: Vector2 = Vector2(origin_x + (float(down_column) + 0.5) * cell_m, origin_z + (float(down_row) + 0.5) * cell_m)

			if rect.has_point(to_m):
				found.append({"km2": _area_cells[index] * cell_km2, "from": from_m, "to": to_m})

	return found


func _build_chains(order: PackedInt32Array, seen: PackedByteArray, river_start_km2: float) -> void:
	var total: int = size_x * size_z
	var cell_km2: float = cell_m * cell_m / 1.0e6
	var threshold: float = river_start_km2 / cell_km2

	# The biggest upstream neighbor of each cell is the one its chain continues from.
	var main_up: PackedInt32Array = PackedInt32Array()
	main_up.resize(total)
	main_up.fill(-1)

	for index in order:
		var down: int = _receiver[index]

		if down >= 0 and seen[down] == 2 and (main_up[down] < 0 or _area_cells[index] > _area_cells[main_up[down]]):
			main_up[down] = index

	chains = []
	river_cells = 0
	var raw: Array = []

	for index in order:
		if _area_cells[index] < threshold:
			continue

		river_cells += 1
		var up: int = main_up[index]

		if up >= 0 and _area_cells[up] >= threshold:
			continue

		# A source: walk downhill until the sea or a bigger river.
		var points: PackedVector2Array = PackedVector2Array()
		var areas: PackedFloat32Array = PackedFloat32Array()
		var levels: PackedFloat32Array = PackedFloat32Array()
		var cells: PackedInt32Array = PackedInt32Array()
		var joins: bool = false
		var walker: int = index
		var previous: Vector2 = Vector2.ZERO
		var steps: int = 0

		while walker >= 0 and steps < 20000:
			steps += 1
			var center: Vector2 = _unwrapped_center(walker, previous, points.size() > 0)
			points.append(center)
			cells.append(walker)
			areas.append(_area_cells[walker] * cell_km2)
			# The water level: the land under the river, never rising downstream.
			levels.append(minf(_heights[walker], levels[levels.size() - 1]) if levels.size() > 0 else _heights[walker])
			previous = center

			if seen[walker] != 2:
				break

			var down: int = _receiver[walker]

			if down < 0:
				break

			if seen[down] != 2:
				# Reached the sea: one more point at the shore cell.
				points.append(_unwrapped_center(down, previous, true))
				cells.append(down)
				areas.append(areas[areas.size() - 1])
				levels.append(0.0)
				break

			if main_up[down] != walker:
				# Joins a bigger river: end exactly on its cell center.
				points.append(_unwrapped_center(down, previous, true))
				cells.append(down)
				joins = true
				areas.append(areas[areas.size() - 1])
				levels.append(minf(_heights[down], levels[levels.size() - 1]))
				break

			walker = down

		if points.size() < 2:
			continue

		raw.append({"points": points, "areas": areas, "levels": levels, "cells": cells, "joins": joins})

	# Owner (2026-10-19): rivers follow the lowest ground. Each chain is laid into the
	# bottom of its valley on the smooth land, then a river joining another ends where
	# that river now runs.
	var shifts: Dictionary = {}

	for chain in raw:
		_settle_in_valley(chain, shifts)

	for chain in raw:
		var points: PackedVector2Array = chain["points"]
		var cells: PackedInt32Array = chain["cells"]

		if chain["joins"] and shifts.has(cells[cells.size() - 1]):
			points[points.size() - 1] += shifts[cells[cells.size() - 1]]

		var bounds: Rect2 = Rect2(points[0], Vector2.ZERO)

		for point in points:
			bounds = bounds.expand(point)

		chains.append({"points": points, "areas": chain["areas"], "levels": chain["levels"], "bounds": bounds.grow(cell_m)})


# Moves a chain off the 160 m cell centers into the bottom of its valley: the chain is
# refined to four points per cell, each point slides sideways (up to valley_snap_m) to
# the lowest smooth ground across the river, and the slides are smoothed so the river
# bends gently. The last point (the sea or the river it joins) stays put. `shifts` learns
# where each cell center went, so a joining river can end there.
func _settle_in_valley(chain: Dictionary, shifts: Dictionary) -> void:
	var points: PackedVector2Array = chain["points"]
	var areas: PackedFloat32Array = chain["areas"]
	var levels: PackedFloat32Array = chain["levels"]
	var cells: PackedInt32Array = chain["cells"]
	var count: int = points.size()
	var dense: PackedVector2Array = PackedVector2Array()
	var dense_areas: PackedFloat32Array = PackedFloat32Array()
	var dense_levels: PackedFloat32Array = PackedFloat32Array()

	for k in range(count - 1):
		for q in range(4):
			var t: float = float(q) / 4.0
			dense.append(points[k].lerp(points[k + 1], t))
			dense_areas.append(lerpf(areas[k], areas[k + 1], t))
			dense_levels.append(lerpf(levels[k], levels[k + 1], t))

	dense.append(points[count - 1])
	dense_areas.append(areas[count - 1])
	dense_levels.append(levels[count - 1])
	var total: int = dense.size()
	var normals: PackedVector2Array = PackedVector2Array()
	var slides: PackedFloat32Array = PackedFloat32Array()
	normals.resize(total)
	slides.resize(total)

	for q in range(total):
		var along: Vector2 = dense[mini(q + 1, total - 1)] - dense[maxi(q - 1, 0)]
		var normal: Vector2 = Vector2(-along.y, along.x).normalized()
		normals[q] = normal

		if q == total - 1 or _heights.is_empty():
			continue

		var best: float = 0.0
		var best_height: float = INF
		var t: float = -valley_snap_m

		while t <= valley_snap_m:
			var probe: Vector2 = dense[q] + normal * t
			# A small pull toward the middle, so flat ground does not throw it about.
			var value: float = smooth_height(probe.x, probe.y) + 0.02 * absf(t)

			if value < best_height:
				best_height = value
				best = t

			t += 12.0

		slides[q] = best

	# Smooth the slides; the end stays fixed.
	for pass_n in range(4):
		var before: PackedFloat32Array = slides.duplicate()

		for q in range(total - 1):
			slides[q] = 0.25 * before[maxi(q - 1, 0)] + 0.5 * before[q] + 0.25 * before[q + 1]

		slides[total - 1] = 0.0

	for q in range(total):
		dense[q] += normals[q] * slides[q]

	# Where each of this chain's own cells went (not its last point, which belongs to the
	# river it joins or to the shore).
	for k in range(count - 1):
		shifts[cells[k]] = normals[k * 4] * slides[k * 4]

	chain["points"] = dense
	chain["areas"] = dense_areas
	chain["levels"] = dense_levels


# The smooth (cubic) land height at a world position: the surface a tile's height map
# starts from before its detail.
func smooth_height(x: float, z: float) -> float:
	var u: float = (x - origin_x) / cell_m - 0.5
	var v: float = (z - origin_z) / cell_m - 0.5
	var base_u: int = int(floor(u))
	var base_v: int = int(floor(v))
	var wu: PackedFloat32Array = _cubic(u - float(base_u))
	var wv: PackedFloat32Array = _cubic(v - float(base_v))
	var value: float = 0.0

	for b in range(4):
		var row: int = posmod(base_v - 1 + b, size_z) * size_x

		for a in range(4):
			value += wu[a] * wv[b] * _heights[row + posmod(base_u - 1 + a, size_x)]

	return value


static func _cubic(t: float) -> PackedFloat32Array:
	var t2: float = t * t
	var t3: float = t2 * t
	return PackedFloat32Array([-0.5 * t3 + t2 - 0.5 * t, 1.5 * t3 - 2.5 * t2 + 1.0, -1.5 * t3 + 2.0 * t2 + 0.5 * t, 0.5 * t3 - 0.5 * t2])


# Owner (2026-10-19): every river starts at a spring in a head pond. Each chain gets one:
# from its head the pond climbs the smooth land until it finds ground flat enough for the
# pond and its shore (or, with none within search_m, the flattest place it passed: the tile
# then builds the plateau), then moves back from the edge of that flat by up to setback_m.
# Heads that end up close together share a pond. Worked out once for the world, so every
# tile that touches a pond makes exactly the same one. Call after build().
func place_ponds(rules: Dictionary, valley_rules: Dictionary = {}) -> void:
	_build_valley_index(valley_rules)
	var radius: float = float(rules.get("head_pond_diameter_m", 70.0)) * 0.5
	var shore: float = float(rules.get("head_pond_shore_m", 40.0))
	var back: float = float(rules.get("head_pond_back_m", 30.0))
	var rim_range: float = float(rules.get("head_pond_max_rim_range_m", 6.0))
	var search_m: float = float(rules.get("head_pond_search_m", 2000.0))
	var setback_m: float = float(rules.get("head_pond_setback_m", 60.0))
	var radius_max: float = maxf(float(rules.get("head_pond_diameter_max_m", 70.0)) * 0.5, radius)
	var climb_max: float = float(rules.get("head_pond_climb_max_m", 60.0))
	var placed: Array = []
	var placed_radius: Array = []
	ponds = []

	for c in range(chains.size()):
		var chain: Dictionary = chains[c]
		var points: PackedVector2Array = chain["points"]
		var levels: PackedFloat32Array = chain["levels"]
		# Where a tile's river starts (the meander moves it a little on flat ground).
		var head: Vector2 = _meandered(points[0])
		var uphill: Vector2 = _smooth_gradient(head)

		if uphill.length() < 0.0001:
			uphill = (points[0] - points[mini(1, points.size() - 1)]).normalized()

		var spot: Vector2 = head + uphill.normalized() * back
		var best_at: int = 0
		var best_score: float = INF
		var climbed: float = 0.0
		var found: bool = false
		# The way up is the brook's way down: it follows the fall line.
		var path: PackedVector2Array = PackedVector2Array([head, spot])
		var head_height: float = smooth_height(head.x, head.y)

		# Owner (2026-10-19): the pond goes on the first flat ground above the head, not on
		# a summit far above it.
		while climbed <= search_m and smooth_height(spot.x, spot.y) - head_height <= climb_max:
			var score: float = _pond_score(spot, radius, shore, rim_range, c)

			if score <= 0.0:
				found = true
				best_at = path.size() - 1
				break

			if score < best_score:
				best_score = score
				best_at = path.size() - 1

			var rise: Vector2 = _smooth_gradient(spot)

			if rise.length() < 0.002:
				break

			spot += rise.normalized() * 16.0
			climbed += 16.0
			path.append(spot)

		path = path.slice(0, best_at + 1)
		spot = path[path.size() - 1]

		# Owner (2026-10-20): a pond is never left with one side cut off by a valley wall.
		# When the fall line found no flat ground clear of every drop, look around the best
		# spot (nearest first) for one, no higher than the climb allows.
		if not found:
			var around: Vector2 = _search_around(spot, radius, shore, rim_range, c, head_height + climb_max)

			if around.x != INF:
				found = true
				spot = around
				path.append(spot)

		var pond_radius: float = radius

		# Owner (2026-10-19): ponds vary from the smallest size up to small lakes. Each pond
		# draws a size (most stay small) and grows toward it only while the flat ground
		# around it still holds it with its shore, so ponds near slopes stay small.
		if found:
			var draw: float = _hash01(spot)
			var wanted: float = lerpf(radius, radius_max, draw * draw)

			while pond_radius + 5.0 <= wanted and _pond_score(spot, pond_radius + 5.0, shore, rim_range, c) <= 0.0:
				pond_radius += 5.0

		# Back from the edge of the flat, so the stream crosses it before dropping.
		if found:
			var away: Vector2 = (spot - path[maxi(path.size() - 2, 0)]).normalized()
			var moved: float = 0.0

			while moved < setback_m and _pond_score(spot + away * 8.0, pond_radius, shore, rim_range, c) <= 0.0:
				spot += away * 8.0
				moved += 8.0

			path.append(spot)

		var shared: int = -1

		for p in range(placed.size()):
			if Vector2(placed[p]).distance_to(spot) < pond_radius + float(placed_radius[p]) + shore:
				shared = p
				break

		if shared < 0:
			placed.append(spot)
			placed_radius.append(pond_radius)
			ponds.append({"centre": spot, "radius": pond_radius, "level": _rim_median(spot, pond_radius), "heads": [], "head_levels": [], "paths": []})
			shared = ponds.size() - 1
		else:
			path.append(placed[shared])

		path.reverse()
		ponds[shared]["paths"].append(path)
		ponds[shared]["heads"].append(head)
		ponds[shared]["head_levels"].append(minf(levels[0], smooth_height(head.x, head.y)))
		chain["pond"] = shared
		chain["pond_radius"] = float(ponds[shared]["radius"])


# A steady 0..1 number for a world position (the same in every tile and every bake).
static func _hash01(point: Vector2) -> float:
	var h: int = hash(Vector2i(int(round(point.x)), int(round(point.y))))
	return float(posmod(h, 1000003)) / 1000003.0


# How far a spot is from fitting a pond: 0 or less when the rim (and, at up to twice the
# range, the shore's outer edge) is flat enough. Measured on the land as the tiles will
# shape it into valleys (owner report 2026-10-20: a pond on smooth land sat at the top of
# a valley wall the tile then cut, so one side of it hung over a cliff), and the ground a
# little beyond the shore may not fall away more than four times the range: the flat is
# back from any edge, blended into the hillside. `own` is the pond's own river, whose
# valley is where the pond drains and is left out.
func _pond_score(spot: Vector2, radius: float, shore: float, rim_range: float, own: int = -1) -> float:
	# The smooth land first (cheap); the valley-shaped land only for spots that pass it.
	var smooth_score: float = _ring_score(spot, radius, shore, rim_range, own, false)

	if smooth_score > 0.0 or _valley_cells.is_empty():
		return smooth_score

	return _ring_score(spot, radius, shore, rim_range, own, true)


func _ring_score(spot: Vector2, radius: float, shore: float, rim_range: float, own: int, shaped: bool) -> float:
	var low: float = INF
	var high: float = -INF
	var outer_low: float = INF
	var outer_high: float = -INF
	var edge_low: float = INF
	var rim: Array = []

	for r in range(16):
		var direction: Vector2 = Vector2(cos(TAU * float(r) / 16.0), sin(TAU * float(r) / 16.0))
		var a: Vector2 = spot + direction * radius
		var b: Vector2 = spot + direction * (radius + shore)
		var h: float = shaped_height(a.x, a.y, own) if shaped else smooth_height(a.x, a.y)
		var o: float = shaped_height(b.x, b.y, own) if shaped else smooth_height(b.x, b.y)
		low = minf(low, h)
		high = maxf(high, h)
		rim.append(h)
		outer_low = minf(outer_low, o)
		outer_high = maxf(outer_high, o)

		if shaped:
			var e: Vector2 = spot + direction * (radius + shore + _edge_clear_m)
			edge_low = minf(edge_low, shaped_height(e.x, e.y, own))

	var score: float = maxf((high - low) - rim_range, (outer_high - outer_low) - 2.0 * rim_range)

	if shaped:
		rim.sort()
		var middle: float = (float(rim[7]) + float(rim[8])) * 0.5
		score = maxf(score, (middle - edge_low) - 4.0 * rim_range)

	return score


# The nearest spot within _search_m of `from` (rings 32 m apart, 24 directions) where a
# pond fits and whose land is no higher than `highest`, or (INF, INF).
func _search_around(from: Vector2, radius: float, shore: float, rim_range: float, own: int, highest: float) -> Vector2:
	for ring in range(1, int(_search_m / 32.0) + 1):
		for r in range(24):
			var angle: float = TAU * float(r) / 24.0
			var spot: Vector2 = from + Vector2(cos(angle), sin(angle)) * 32.0 * float(ring)

			if smooth_height(spot.x, spot.y) <= highest and _pond_score(spot, radius, shore, rim_range, own) <= 0.0:
				return spot

	return Vector2(INF, INF)


# The land as a tile shapes it into valleys (TileHeight._shape_valleys, here from the world
# river chains at their own points instead of a 32 m grid): lowered toward the nearest
# river's level, fully on its floor and less up its walls. Leaves out chain `skip`.
func shaped_height(x: float, z: float, skip: int = -1) -> float:
	var h: float = smooth_height(x, z)

	if _valley_cells.is_empty():
		return h

	var best_d2: float = INF
	var best: Vector3 = Vector3.ZERO      # level, floor half width, wall half width
	var cx: int = int(floor(x / _valley_cell_m))
	var cz: int = int(floor(z / _valley_cell_m))

	for gz in range(cz - 1, cz + 2):
		for gx in range(cx - 1, cx + 2):
			var key: Vector2i = Vector2i(gx, gz)

			if not _valley_cells.has(key):
				continue

			for entry in _valley_cells[key]:
				if int(entry[0]) == skip:
					continue

				var dx: float = float(entry[1]) - x
				var dz: float = float(entry[2]) - z
				var d2: float = dx * dx + dz * dz

				if d2 < float(entry[5]) * float(entry[5]) and d2 < best_d2:
					best_d2 = d2
					best = Vector3(float(entry[3]), float(entry[4]), float(entry[5]))

	if best_d2 == INF or h <= best.x:
		return h

	return best.x + (h - best.x) * smoothstep(best.y, best.z, sqrt(best_d2))


func _build_valley_index(valley_rules: Dictionary) -> void:
	_valley_cells = {}

	if valley_rules.is_empty():
		return

	var floor_base: float = float(valley_rules["floor_half_m"])
	var floor_scale: float = float(valley_rules["floor_half_per_sqrt_km2"])
	var wall_base: float = float(valley_rules["half_width_m"])
	var wall_scale: float = float(valley_rules["half_width_per_sqrt_km2"])
	var wall_max: float = float(valley_rules["half_width_max_m"])
	_valley_cell_m = wall_max

	for c in range(chains.size()):
		var points: PackedVector2Array = chains[c]["points"]
		var areas: PackedFloat32Array = chains[c]["areas"]
		var levels: PackedFloat32Array = chains[c]["levels"]

		for k in range(points.size()):
			var point: Vector2 = _meandered(points[k])
			var root: float = sqrt(maxf(areas[k], 0.0))
			var wall: float = minf(wall_base + wall_scale * root, wall_max)
			var floor_half: float = minf(floor_base + floor_scale * root, wall * 0.5)
			var level: float = minf(levels[k], smooth_height(point.x, point.y))
			var key: Vector2i = Vector2i(int(floor(point.x / _valley_cell_m)), int(floor(point.y / _valley_cell_m)))

			if not _valley_cells.has(key):
				_valley_cells[key] = []

			_valley_cells[key].append([c, point.x, point.y, level, floor_half, wall])


func _rim_median(spot: Vector2, radius: float) -> float:
	var rim: Array = []

	for r in range(16):
		rim.append(smooth_height(spot.x + cos(TAU * float(r) / 16.0) * radius, spot.y + sin(TAU * float(r) / 16.0) * radius))

	rim.sort()
	return (float(rim[7]) + float(rim[8])) * 0.5


func _smooth_gradient(point: Vector2) -> Vector2:
	var e: float = 16.0
	return Vector2(
		smooth_height(point.x + e, point.y) - smooth_height(point.x - e, point.y),
		smooth_height(point.x, point.y + e) - smooth_height(point.x, point.y - e)
	) / (2.0 * e)


# Head ponds near a rectangle (world meters): each as {"centre", "level" (the height of
# its flat), "heads" (the river heads it feeds), "head_levels" (the land there)}, moved by whole world widths to sit
# by the rectangle.
func ponds_in(rect: Rect2, reach_m: float) -> Array:
	var out: Array = []
	var world_w: float = float(size_x) * cell_m
	var world_h: float = float(size_z) * cell_m
	var wanted: Rect2 = rect.grow(reach_m)

	for pond in ponds:
		for kx in range(-1, 2):
			for kz in range(-1, 2):
				var shift: Vector2 = Vector2(float(kx) * world_w, float(kz) * world_h)
				var centre: Vector2 = Vector2(pond["centre"]) + shift

				if not wanted.has_point(centre):
					continue

				var heads: Array = []

				for head in pond["heads"]:
					var moved_head: Vector2 = Vector2(head) + shift

					# A head copied by the wrap lies within one world of the pond.
					while moved_head.x - centre.x > world_w * 0.5:
						moved_head.x -= world_w

					while centre.x - moved_head.x > world_w * 0.5:
						moved_head.x += world_w

					while moved_head.y - centre.y > world_h * 0.5:
						moved_head.y -= world_h

					while centre.y - moved_head.y > world_h * 0.5:
						moved_head.y += world_h

					heads.append(moved_head)

				var paths: Array = []

				for h in range(heads.size()):
					var path: PackedVector2Array = PackedVector2Array(pond["paths"][h])
					var delta: Vector2 = Vector2(heads[h]) - Vector2(pond["heads"][h])

					for q in range(path.size()):
						path[q] += delta

					paths.append(path)

				out.append({"centre": centre, "radius": pond["radius"], "level": pond["level"], "heads": heads, "head_levels": pond["head_levels"], "paths": paths})

	return out


# Turns on the meander. `octaves` is a list of {"wavelength_m", "amplitude_m"}
# (amplitude is the typical sideways push); each octave is made of
# `waves_per_octave` plane waves in random directions. Every wave fits a
# whole number of times into the world, so the field repeats exactly at
# the wrap seam. Call after build().
func set_meander(octaves: Array, rng: RandomNumberGenerator, waves_per_octave: int = 6) -> void:
	_waves = []
	var world_w: float = float(size_x) * cell_m
	var world_h: float = float(size_z) * cell_m

	for octave in octaves:
		var wavelength: float = float(octave["wavelength_m"])
		# A sum of n unit waves has a typical size of sqrt(n / 2).
		var amplitude: float = float(octave["amplitude_m"]) / sqrt(float(waves_per_octave) * 0.5)

		for _i in range(waves_per_octave):
			var angle: float = rng.randf() * TAU
			var nx: float = round(cos(angle) * world_w / wavelength)
			var nz: float = round(sin(angle) * world_h / wavelength)

			if nx == 0.0 and nz == 0.0:
				nx = 1.0

			var push: float = rng.randf() * TAU
			_waves.append([TAU * nx / world_w, TAU * nz / world_h, rng.randf() * TAU, cos(push), sin(push), amplitude])


# The meander push at a world position (meters).
func meander_offset(x: float, z: float) -> Vector2:
	var dx: float = 0.0
	var dz: float = 0.0

	for wave in _waves:
		var value: float = wave[5] * cos(wave[0] * x + wave[1] * z + wave[2])
		dx += wave[3] * value
		dz += wave[4] * value

	return Vector2(dx, dz)


# The center of a cell, moved by whole world widths so that it stays within
# half a world of the previous point of its chain.
func _unwrapped_center(index: int, previous: Vector2, has_previous: bool) -> Vector2:
	var center: Vector2 = Vector2(
		origin_x + (float(index % size_x) + 0.5) * cell_m,
		origin_z + (float(index / size_x) + 0.5) * cell_m
	)

	if has_previous:
		var width: float = float(size_x) * cell_m
		var height: float = float(size_z) * cell_m

		while center.x - previous.x > width * 0.5:
			center.x -= width

		while previous.x - center.x > width * 0.5:
			center.x += width

		while center.y - previous.y > height * 0.5:
			center.y -= height

		while previous.y - center.y > height * 0.5:
			center.y += height

	return center


# Rivers crossing a rectangle (world meters), each as a smooth polyline of
# points about `step_m` apart with the drainage area (km2) at every point.
# Points can lie a little outside the rectangle; a river that leaves and
# comes back is returned as separate pieces.
func guides_in(rect: Rect2, step_m: float) -> Array:
	var out: Array = []
	var world_w: float = float(size_x) * cell_m
	var world_h: float = float(size_z) * cell_m
	var wanted: Rect2 = rect.grow(cell_m)

	for chain in chains:
		var bounds: Rect2 = chain["bounds"]

		for kx in range(-1, 2):
			for kz in range(-1, 2):
				var shift: Vector2 = Vector2(float(kx) * world_w, float(kz) * world_h)

				# The chain, moved by `shift`, against the rectangle.
				if not Rect2(bounds.position + shift, bounds.size).intersects(wanted):
					continue

				_sample_chain(chain, shift, wanted, step_m, out)

	return out


func _sample_chain(chain: Dictionary, shift: Vector2, wanted: Rect2, step_m: float, out: Array) -> void:
	var points: PackedVector2Array = chain["points"]
	var areas: PackedFloat32Array = chain["areas"]
	var count: int = points.size()
	var piece_points: PackedVector2Array = PackedVector2Array()
	var piece_areas: PackedFloat32Array = PackedFloat32Array()
	var levels: PackedFloat32Array = chain["levels"]
	var piece_levels: PackedFloat32Array = PackedFloat32Array()
	var piece_marks: PackedByteArray = PackedByteArray()   # 1 on every 4th point of a segment (the same points in every tile)
	var piece_source: bool = false       # this piece starts at the chain's first point (a true river head)
	var pond_radius: float = float(chain.get("pond_radius", 0.0))

	for i in range(count - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]

		# Skip segments that cannot touch the rectangle.
		var segment_box: Rect2 = Rect2(a + shift, Vector2.ZERO).expand(b + shift).grow(cell_m)

		if not segment_box.intersects(wanted):
			if piece_points.size() > 1:
				out.append({"points": piece_points, "areas": piece_areas, "levels": piece_levels, "marks": piece_marks, "source": piece_source, "pond_radius": pond_radius})

			piece_points = PackedVector2Array()
			piece_areas = PackedFloat32Array()
			piece_levels = PackedFloat32Array()
			piece_marks = PackedByteArray()
			piece_source = false
			continue

		if i == 0:
			piece_source = true

		# The curve is worked out on the chain's own coordinates and moved
		# by `shift` last, so every copy of it gets exactly the same shape.
		var p0: Vector2 = points[i - 1] if i > 0 else 2.0 * a - b
		var p3: Vector2 = points[i + 2] if i + 2 < count else 2.0 * b - a
		var pieces: int = maxi(int(ceil(a.distance_to(b) / step_m)), 1)

		for s in range(pieces):
			var t: float = float(s) / float(pieces)
			piece_points.append(_meandered(_catmull_rom(p0, a, b, p3, t)) + shift)
			piece_areas.append(lerpf(areas[i], areas[i + 1], t))
			# Owner (2026-10-19): the level follows the land, not a straight line between the
			# 160 m cells (that line cut a gorge through a ridge): the upstream cell's level,
			# lowered to the smooth ground where that is lower.
			var refined: Vector2 = _catmull_rom(p0, a, b, p3, t)
			piece_levels.append(minf(levels[i], smooth_height(refined.x, refined.y)))
			piece_marks.append(1 if s % 4 == 0 else 0)

		if i == count - 2:
			piece_points.append(_meandered(b) + shift)
			piece_areas.append(areas[i + 1])
			piece_levels.append(levels[i + 1])
			piece_marks.append(1)

	if piece_points.size() > 1:
		out.append({"points": piece_points, "areas": piece_areas, "levels": piece_levels, "marks": piece_marks, "source": piece_source, "pond_radius": pond_radius})


func _meandered(point: Vector2) -> Vector2:
	if _waves.is_empty():
		return point

	# Rivers wind across flat ground but run straight down slopes.
	var steepness: float = slope_at(point.x, point.y)
	var keep: float = 1.0 - smoothstep(meander_flat_slope, meander_steep_slope, steepness)

	if keep <= 0.0:
		return point

	return point + meander_offset(point.x, point.y) * keep


# The world elevation's slope (meters per meter) at a world position, from the
# 160 m map (bilinear, wrapping).
func slope_at(x: float, z: float) -> float:
	if _heights.is_empty():
		return 0.0

	var e: float = cell_m
	var gx: float = _bilinear_world(_heights, x + e, z) - _bilinear_world(_heights, x - e, z)
	var gz: float = _bilinear_world(_heights, x, z + e) - _bilinear_world(_heights, x, z - e)
	return Vector2(gx, gz).length() / (2.0 * e)


func _bilinear_world(field: PackedFloat32Array, x: float, z: float) -> float:
	var u: float = (x - origin_x) / cell_m - 0.5
	var v: float = (z - origin_z) / cell_m - 0.5
	var i0: int = int(floor(u))
	var j0: int = int(floor(v))
	var tu: float = u - float(i0)
	var tv: float = v - float(j0)
	var a: float = field[posmod(j0, size_z) * size_x + posmod(i0, size_x)]
	var b: float = field[posmod(j0, size_z) * size_x + posmod(i0 + 1, size_x)]
	var c: float = field[posmod(j0 + 1, size_z) * size_x + posmod(i0, size_x)]
	var d: float = field[posmod(j0 + 1, size_z) * size_x + posmod(i0 + 1, size_x)]
	return lerpf(lerpf(a, b, tu), lerpf(c, d, tu), tv)


static func _catmull_rom(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * (
		2.0 * p1 + (p2 - p0) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3
	)
