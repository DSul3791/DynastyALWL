extends RefCounted

# Rivers, lakes and marsh pools for drawing (starter-town playtest work).
#
# For one flora chunk, the tile's water surface on its 8 m grid: one level
# per grid point (NAN where there is no inland water). The sea is not
# included; clients draw it as one plane at 0 m.
#
# Static helpers only; thread safe.


const FallsScript := preload("res://src/worldgen/runtime/water_falls.gd")


# Water levels for the chunk with corner `origin` (wrapped coordinates):
# {"count": points per side, "spacing": m, "levels": PackedFloat32Array}.
static func chunk_levels(generator, origin: Vector2, chunk_m: float) -> Dictionary:
	var data = generator.get_tile(generator.tile_of(origin.x + 1.0, origin.y + 1.0))
	var spacing: float = 8.0 if data.placeholder else data.spacing_m
	var count: int = int(round(chunk_m / spacing)) + 1
	var levels: PackedFloat32Array = PackedFloat32Array()
	levels.resize(count * count)
	levels.fill(NAN)
	var wet: int = 0

	if data.placeholder:
		return {"count": count, "spacing": spacing, "levels": levels, "wet": 0}

	for j in range(count):
		for i in range(count):
			var level: float = _level_at(generator, data, origin.x + float(i) * spacing, origin.y + float(j) * spacing, spacing)

			if not is_nan(level):
				levels[j * count + i] = level
				wet += 1

	if wet == 0:
		return {"count": count, "spacing": spacing, "levels": levels, "wet": 0}

	# Settled simulated water is already continuous: no hole closing. Running
	# water gets a finer surface laid on the real ground (_fine_cells).
	if not data.sim_levels.is_empty():
		var still: PackedFloat32Array = _calm_still_water(count, spacing, levels)
		var sea_near: PackedFloat32Array = _ease_into_sea(generator, data, origin, count, spacing, levels, still)
		var edge: PackedFloat32Array = _shore_levels(generator, data, origin, count, spacing, levels)
		var vel: PackedFloat32Array = _velocities(generator, data, origin, count, spacing, levels, still)

		# The current dies away over the same reach, so the shader sees calm water at the sea.
		if not sea_near.is_empty():
			for k in range(count * count):
				if sea_near[k] < float(SEA_EASE_CELLS):
					var calm: float = sea_near[k] / float(SEA_EASE_CELLS)
					vel[k * 2] *= calm
					vel[k * 2 + 1] *= calm

		var fall_grid: PackedFloat32Array = _fall_grid(generator, data, origin, count, spacing, levels)
		var fall_vel: PackedFloat32Array = vel if data.fall_levels.is_empty() else _velocities(generator, data, origin, count, spacing, fall_grid)
		var falls: Array = FallsScript.find(generator, origin, count, spacing, fall_grid, fall_vel, func(x: float, z: float) -> float: return _fine_ground(generator, x, z), PackedFloat32Array() if data.fall_levels.is_empty() else levels, vel)
		return {"count": count, "spacing": spacing, "levels": levels, "wet": wet, "edge": edge, "fine": _fine_cells(generator, origin, count, spacing, levels, edge), "vel": vel, "falls": falls}

	var closed: PackedFloat32Array = levels.duplicate()

	for j in range(count):
		for i in range(count):
			if is_nan(levels[j * count + i]):
				var level: float = _gap_level(generator, data, origin.x + float(i) * spacing, origin.y + float(j) * spacing, spacing)

				if not is_nan(level):
					closed[j * count + i] = level
					wet += 1

	levels = closed

	return {"count": count, "spacing": spacing, "levels": levels, "wet": wet}


const MANNING_N := 0.035        # the water sim's bed roughness (water_sim.gd), so the speed drawn is the speed it runs at
const SPEED_MAX_M_S := 12.0
const VEL_MARK := 0xF1          # after the fine cells in an encoded chunk: two s8 (0.1 m/s) per wet point
const FLOW_FASTEST_M_S := 2.5   # the water shader's fastest drawn speed (fastest_m_s)


# The current at each wet point, m/s as x, z pairs (0 on dry points): the speed the water
# sim's own friction law gives for the depth and the surface slope there (steady flow,
# Manning), pointing downhill. Owner (2026-10-20): ripples and foam follow the true current.
const CALM_RADIUS := 3           # cells each way: the window that tells a still pond from a river (24 m)
const CALM_SLOPE := 0.003        # a surface tilting less than this over the window is standing water
const CALM_RANGE_M := 0.6        # ...and no wave taller than this in it (a cascade lip is not calmed)
const STILL_REACH := 3           # a rim cell this close to a calm cell of a pond is standing water too
const STILL_BODY_M := 0.3        # a connected still body is drawn at one level (its median) when its levels lie within this
const STILL_EASE_CELLS := 4      # the current eases in over this many cells (about 30 m) from the edge of standing water
const STILL_LEVEL_M := 0.15      # ...if its level is within this of the pond's
const CALM_WET_SHARE := 0.6      # a window must be this wet (shore windows are part dry)


# Mean tilt (x, z) and wet-cell mean of the surface over the window around (i, j), plus the
# window's range: [gx, gz, mean, range, wet share]. The sim's pond surface ripples by a
# decimetre cell to cell; over a whole window that averages out, so this tells standing
# water from a current where the one-cell slope cannot.
static func _window(levels: PackedFloat32Array, i: int, j: int, count: int, spacing: float) -> Array:
	var sum: float = 0.0
	var n: int = 0
	var lo: float = INF
	var hi: float = -INF
	var west: float = 0.0
	var east: float = 0.0
	var north: float = 0.0
	var south: float = 0.0
	var nw: int = 0
	var ne: int = 0
	var nn: int = 0
	var ns: int = 0

	for dj in range(-CALM_RADIUS, CALM_RADIUS + 1):
		for di in range(-CALM_RADIUS, CALM_RADIUS + 1):
			var ii: int = i + di
			var jj: int = j + dj

			if ii < 0 or jj < 0 or ii >= count or jj >= count:
				continue

			var level: float = levels[jj * count + ii]

			if is_nan(level):
				continue

			sum += level
			n += 1
			lo = minf(lo, level)
			hi = maxf(hi, level)

			if di < 0:
				west += level
				nw += 1
			elif di > 0:
				east += level
				ne += 1

			if dj < 0:
				north += level
				nn += 1
			elif dj > 0:
				south += level
				ns += 1

	var span: float = float(CALM_RADIUS + 1) * spacing
	var gx: float = (east / float(ne) - west / float(nw)) / span if ne > 0 and nw > 0 else 0.0
	var gz: float = (south / float(ns) - north / float(nn)) / span if ns > 0 and nn > 0 else 0.0
	var cells: float = float((2 * CALM_RADIUS + 1) * (2 * CALM_RADIUS + 1))
	return [gx, gz, sum / float(maxi(n, 1)), hi - lo, float(n) / cells]


# Standing water draws flat (owner 2026-10-21: "the water is all rough in the pond"): where
# the surface barely tilts across a whole window, every level in it becomes the window mean.
static func _calm_still_water(count: int, spacing: float, levels: PackedFloat32Array) -> PackedFloat32Array:
	var still: PackedFloat32Array = _still_levels(count, spacing, levels)

	for n in range(levels.size()):
		if not is_nan(still[n]):
			levels[n] = still[n]

	return still


# Where the water stands still: the level it should be drawn at (NAN elsewhere). The core is every wet cell whose window
# (CALM_RADIUS) barely tilts and has no wave (the window mean). Owner (2026-10-21: lakes "look like moving water with
# peaks"): a pond's rim is part dry in its window, so it was not calm and drew with the Manning speed of a river
# (1 to 3 m/s) and its jittering shore level; a wet cell within STILL_REACH cells of a calm one, at about its level,
# is still too, at that level. A river is only 2 or 3 cells wide, so it never has a calm core.
static func _still_levels(count: int, spacing: float, levels: PackedFloat32Array) -> PackedFloat32Array:
	var core: PackedFloat32Array = PackedFloat32Array()
	core.resize(count * count)
	core.fill(NAN)

	for j in range(count):
		for i in range(count):
			if is_nan(levels[j * count + i]):
				continue

			var w: Array = _window(levels, i, j, count, spacing)

			if w[4] >= CALM_WET_SHARE and w[3] < CALM_RANGE_M and sqrt(w[0] * w[0] + w[1] * w[1]) < CALM_SLOPE:
				core[j * count + i] = w[2]

	var out: PackedFloat32Array = core.duplicate()

	for j in range(count):
		for i in range(count):
			var level: float = levels[j * count + i]

			if is_nan(level) or not is_nan(core[j * count + i]):
				continue

			var best: float = NAN
			var best_gap: float = STILL_LEVEL_M

			for dj in range(-STILL_REACH, STILL_REACH + 1):
				for di in range(-STILL_REACH, STILL_REACH + 1):
					var ii: int = i + di
					var jj: int = j + dj

					if ii < 0 or jj < 0 or ii >= count or jj >= count or is_nan(core[jj * count + ii]):
						continue

					var gap: float = absf(core[jj * count + ii] - level)

					if gap < best_gap:
						best_gap = gap
						best = core[jj * count + ii]

			out[j * count + i] = best

	# One level per connected body (Tyler: window means differ by a few cm between cores, faint facets on a big
	# lake): the median of the body's levels, when they all lie within STILL_BODY_M of each other.
	var body: PackedInt32Array = PackedInt32Array()
	body.resize(count * count)
	body.fill(-1)

	for start in range(count * count):
		if is_nan(out[start]) or body[start] >= 0:
			continue

		var members: PackedInt32Array = PackedInt32Array([start])
		body[start] = start
		var head: int = 0

		while head < members.size():
			var n: int = members[head]
			head += 1

			for dj in range(-1, 2):
				for di in range(-1, 2):
					var ii: int = n % count + di
					var jj: int = n / count + dj

					if ii < 0 or jj < 0 or ii >= count or jj >= count:
						continue

					var m: int = jj * count + ii

					if body[m] < 0 and not is_nan(out[m]):
						body[m] = start
						members.append(m)

		var values: PackedFloat32Array = PackedFloat32Array()

		for n in members:
			values.append(out[n])

		values.sort()

		if values[values.size() - 1] - values[0] <= STILL_BODY_M:
			var median: float = values[values.size() / 2]

			for n in members:
				out[n] = median

	return out


static func _velocities(generator, data, origin: Vector2, count: int, spacing: float, levels: PackedFloat32Array, known_still: PackedFloat32Array = PackedFloat32Array()) -> PackedFloat32Array:
	var vel: PackedFloat32Array = PackedFloat32Array()
	vel.resize(count * count * 2)
	var still: PackedFloat32Array = known_still if not known_still.is_empty() else _still_levels(count, spacing, levels)

	for j in range(count):
		for i in range(count):
			var level: float = levels[j * count + i]

			if is_nan(level):
				continue

			var gx: float = 0.0
			var gz: float = 0.0
			var used: int = 0

			for dj in range(-1, 2):
				for di in range(-1, 2):
					var ii: int = i + di
					var jj: int = j + dj

					if ii < 0 or jj < 0 or ii >= count or jj >= count or is_nan(levels[jj * count + ii]):
						continue

					gx += _slope_along(levels, ii, jj, 1, 0, count, spacing)
					gz += _slope_along(levels, ii, jj, 0, 1, count, spacing)
					used += 1

			if used == 0:
				continue

			gx /= float(used)
			gz /= float(used)
			var slope: float = sqrt(gx * gx + gz * gz)

			if slope < 0.00001:
				continue

			# A pond's level ripples a decimetre cell to cell and Manning turns that into a
			# 12 m/s "current" in deep water: standing water has no current.
			var w: Array = _window(levels, i, j, count, spacing)

			if w[4] >= CALM_WET_SHARE and sqrt(w[0] * w[0] + w[1] * w[1]) < CALM_SLOPE:
				continue

			if not is_nan(still[j * count + i]):
				continue

			var x: float = origin.x + float(i) * spacing
			var z: float = origin.y + float(j) * spacing
			var source = data if (x < data.x0 + float(data.samples - 1) * spacing and z < data.z0 + float(data.samples - 1) * spacing) else generator.get_tile(generator.tile_of(x, z))
			var depth: float = 0.2 if source.placeholder else maxf(level - source.heights[source.nearest(x, z)], 0.05)
			var speed: float = minf(pow(depth, 2.0 / 3.0) * sqrt(slope) / MANNING_N, SPEED_MAX_M_S)
			# Where a river leaves a pond its current eases in instead of jumping to river speed in one cell.
			var near_still: int = STILL_EASE_CELLS

			for dj in range(-STILL_EASE_CELLS + 1, STILL_EASE_CELLS):
				for di in range(-STILL_EASE_CELLS + 1, STILL_EASE_CELLS):
					var ii: int = i + di
					var jj: int = j + dj

					if ii >= 0 and jj >= 0 and ii < count and jj < count and not is_nan(still[jj * count + ii]):
						near_still = mini(near_still, maxi(absi(di), absi(dj)))

			speed *= float(near_still) / float(STILL_EASE_CELLS)
			vel[(j * count + i) * 2] = -gx / slope * speed
			vel[(j * count + i) * 2 + 1] = -gz / slope * speed

	return vel


# A grid part-way from `old` to `new` (t 0..1), for easing the drawn water between server
# updates: levels and fine heights move where both have water, anything new just appears.
static func blend(old: Dictionary, new: Dictionary, t: float) -> Dictionary:
	if int(old.get("count", -1)) != int(new.get("count", -2)) or int(old.get("wet", 0)) == 0 or int(new.get("wet", 0)) == 0:
		return new

	var levels: PackedFloat32Array = (new["levels"] as PackedFloat32Array).duplicate()
	var old_levels: PackedFloat32Array = old["levels"]

	for n in range(levels.size()):
		if not is_nan(levels[n]) and not is_nan(old_levels[n]):
			levels[n] = lerpf(old_levels[n], levels[n], t)

	var result: Dictionary = new.duplicate()
	result["levels"] = levels
	var edge: PackedFloat32Array = new.get("edge", PackedFloat32Array())
	var old_edge: PackedFloat32Array = old.get("edge", PackedFloat32Array())

	if not edge.is_empty() and old_edge.size() == edge.size():
		edge = edge.duplicate()

		for n in range(edge.size()):
			if not is_nan(edge[n]) and not is_nan(old_edge[n]):
				edge[n] = lerpf(old_edge[n], edge[n], t)

		result["edge"] = edge

	var fine: Dictionary = {}
	var old_fine: Dictionary = old.get("fine", {})

	for cell in new.get("fine", {}):
		var heights: PackedFloat32Array = (new["fine"][cell] as PackedFloat32Array).duplicate()

		if old_fine.has(cell) and old_fine[cell].size() == heights.size():
			for n in range(heights.size()):
				heights[n] = lerpf(old_fine[cell][n], heights[n], t)

		fine[cell] = heights

	result["fine"] = fine
	return result


# Dave (2026-10-21): at middling spring rates the shore twitched and flickered. The sim's draw line (0.12 m of
# water) is crossed back and forth by cells that slosh a little, so a cell now needs HOLD_ON updates in a row
# of water to appear and HOLD_OFF updates in a row of none to vanish. `new` is changed in place (levels, wet, a
# "hold" array of per-cell streaks kept from update to update) and its prebuilt "mesh" is dropped when a cell was
# held, so the drawing is made from the steadied levels. Returns true when any cell was held or delayed.
const HOLD_ON := 2
const HOLD_OFF := 4


static func steady_edges(old: Dictionary, new: Dictionary) -> bool:
	if int(old.get("count", -1)) != int(new.get("count", -2)) or int(old.get("wet", 0)) == 0 or int(new.get("wet", 0)) == 0:
		return false

	var old_levels: PackedFloat32Array = old["levels"]
	var levels: PackedFloat32Array = new["levels"]
	var old_hold: PackedByteArray = old.get("hold", PackedByteArray())
	var hold: PackedByteArray = PackedByteArray()
	hold.resize(levels.size())
	var changed: bool = false
	var wet: int = int(new["wet"])

	for n in range(levels.size()):
		var was: bool = not is_nan(old_levels[n])
		var is_now: bool = not is_nan(levels[n])
		var streak: int = old_hold[n] if old_hold.size() == levels.size() else 0

		if was == is_now:
			continue

		# streak counts the updates in a row that disagree with what is drawn
		streak += 1
		var need: int = HOLD_ON if is_now else HOLD_OFF

		if streak >= need:
			continue

		hold[n] = streak
		changed = true

		if is_now:
			levels[n] = NAN
			wet -= 1
		else:
			levels[n] = old_levels[n]
			wet += 1

	new["hold"] = hold

	if changed:
		new["levels"] = levels
		new["wet"] = wet
		new.erase("mesh")

	return changed


# Whether two grids' levels differ anywhere by more than `limit` metres (so easing is worth it).
static func moved(old: Dictionary, new: Dictionary, limit: float) -> bool:
	if int(old.get("count", -1)) != int(new.get("count", -2)) or int(old.get("wet", 0)) == 0 or int(new.get("wet", 0)) == 0:
		return false

	var a: PackedFloat32Array = old["levels"]
	var b: PackedFloat32Array = new["levels"]

	for n in range(a.size()):
		if not is_nan(a[n]) and not is_nan(b[n]) and absf(a[n] - b[n]) > limit:
			return true

	return false


# The levels the fall finder works on: the drawn levels plus thin running water on the
# baked channels (TileTerrainData.fall_levels), so a film down a cliff still makes a fall.
static func _fall_grid(generator, data, origin: Vector2, count: int, spacing: float, levels: PackedFloat32Array) -> PackedFloat32Array:
	if data.fall_levels.size() != data.samples * data.samples:
		return levels

	var grid: PackedFloat32Array = levels.duplicate()

	for j in range(count):
		for i in range(count):
			var p: int = j * count + i

			if not is_nan(grid[p]):
				continue

			var x: float = origin.x + float(i) * spacing
			var z: float = origin.y + float(j) * spacing

			if x >= data.x0 + float(data.samples - 1) * spacing or z >= data.z0 + float(data.samples - 1) * spacing:
				continue

			var k: int = data.nearest(x, z)

			if data.heights[k] > 0.0:
				grid[p] = data.fall_levels[k]

	return grid


# The inland water level at one point (NAN when dry).
static func _level_at(generator, data, x: float, z: float, spacing: float) -> float:
	# The last row and column may sit on the next tile.
	var source = data if (x < data.x0 + float(data.samples - 1) * spacing and z < data.z0 + float(data.samples - 1) * spacing) else generator.get_tile(generator.tile_of(x, z))

	if source.placeholder:
		return NAN

	var k: int = source.nearest(x, z)

	# A tile with settled simulated water draws that; the painted classes only
	# stand in for tiles that have not been settled yet.
	if not source.sim_levels.is_empty():
		return source.sim_levels[k] if source.heights[k] > 0.0 else NAN

	var level: float = source.water_surface[k]
	return level if source.water_class[k] > 1 and not is_nan(level) else NAN


# Owner report (2026-10-20): a river reached the ocean as water standing 1 to 3 m above it,
# with a step at the last land square (the sim holds sea squares at 0 m, and a river bed
# meeting 0 m still carries its flow depth). Within SEA_EASE_CELLS of the sea the drawn
# river surface comes down to the sea in a gentle slope (at most SEA_EASE_SLOPE up from 0 m
# per meter from the sea), never under the ground, so the river runs into the ocean as one
# water. Drawing only: the simulation is unchanged.
# Tyler (2026-10-21, river mouth): real rivers are nearly flat near the sea (backwater), so the ramp
# is 0.5% over 200 m (1 m) and the current is eased to still over the same reach.
const SEA_EASE_CELLS := 25
const SEA_EASE_SLOPE := 0.005
const SEA_EASE_FILM_M := 0.1


static func _ease_into_sea(generator, data, origin: Vector2, count: int, spacing: float, levels: PackedFloat32Array, still: PackedFloat32Array) -> PackedFloat32Array:
	var reach: int = SEA_EASE_CELLS
	var side: int = count + 2 * reach
	var near: PackedFloat32Array = PackedFloat32Array()
	near.resize(side * side)
	var any_sea: bool = false

	for j in range(side):
		for i in range(side):
			if _is_sea(generator, data, origin.x + float(i - reach) * spacing, origin.y + float(j - reach) * spacing, spacing):
				near[j * side + i] = 0.0
				any_sea = true
			else:
				near[j * side + i] = INF

	if not any_sea:
		return PackedFloat32Array()

	# Distance to the nearest sea square in cells (two-pass chamfer).
	for j in range(side):
		for i in range(side):
			var k: int = j * side + i
			var best: float = near[k]

			if i > 0:
				best = minf(best, near[k - 1] + 1.0)

			if j > 0:
				best = minf(best, near[k - side] + 1.0)

				if i > 0:
					best = minf(best, near[k - side - 1] + 1.4142)

				if i < side - 1:
					best = minf(best, near[k - side + 1] + 1.4142)

			near[k] = best

	for j in range(side - 1, -1, -1):
		for i in range(side - 1, -1, -1):
			var k: int = j * side + i
			var best: float = near[k]

			if i < side - 1:
				best = minf(best, near[k + 1] + 1.0)

			if j < side - 1:
				best = minf(best, near[k + side] + 1.0)

				if i < side - 1:
					best = minf(best, near[k + side + 1] + 1.4142)

				if i > 0:
					best = minf(best, near[k + side - 1] + 1.4142)

			near[k] = best

	var result: PackedFloat32Array = PackedFloat32Array()
	result.resize(count * count)

	for j in range(count):
		for i in range(count):
			var nearest: float = near[(j + reach) * side + i + reach]
			result[j * count + i] = nearest if nearest <= float(reach) else INF
			var level: float = levels[j * count + i]

			# Still water (a pond or lake near the sea) keeps its own flat level; only running water is eased.
			if is_nan(level) or level <= SEA_EASE_FILM_M or nearest > float(reach) or not is_nan(still[j * count + i]):
				continue

			var x: float = origin.x + float(i) * spacing
			var z: float = origin.y + float(j) * spacing
			var source = data if (x < data.x0 + float(data.samples - 1) * spacing and z < data.z0 + float(data.samples - 1) * spacing) else generator.get_tile(generator.tile_of(x, z))
			var ground: float = 0.0 if source.placeholder else source.heights[source.nearest(x, z)]
			levels[j * count + i] = minf(level, maxf(nearest * spacing * SEA_EASE_SLOPE, ground + SEA_EASE_FILM_M))

	return result


# Sea under the 8 m point (x, z): ground at or below 0 m, as the water sim counts it.
static func _is_sea(generator, data, x: float, z: float, spacing: float) -> bool:
	var source = data if (x < data.x0 + float(data.samples - 1) * spacing and z < data.z0 + float(data.samples - 1) * spacing) else generator.get_tile(generator.tile_of(x, z))
	return source.placeholder or source.heights[source.nearest(x, z)] <= 0.0


# Owner report (2026-10-19): the water's edges stuck out in big square corners along the
# 8 m cells. A dry point beside water now carries the water level on into the bank (the
# mean of its wet neighbours), so the drawn surface runs flat into the rising ground and
# the terrain cuts it off along its real contour. Where the ground there is lower than
# the water (the water did not reach it) the point sinks under the ground instead, so
# the sheet dips into the ground rather than floating. NAN where a point is wet or has
# no wet neighbour.
const SHORE_SINK_M := 0.3
# Owner report (2026-10-20): the rivers stopped short of the ocean instead of running into it.
# A sea point beside river water took the sinking rule above and pulled the river's sheet
# down to the sea bed, so it ended in an edge. It now runs the sheet down to just under the
# sea's surface (drawn as one plane at 0 m), so the two surfaces meet as one water.
const SEA_TUCK_M := 0.05


static func _shore_levels(generator, data, origin: Vector2, count: int, spacing: float, levels: PackedFloat32Array) -> PackedFloat32Array:
	var edge: PackedFloat32Array = PackedFloat32Array()
	edge.resize(count * count)
	edge.fill(NAN)

	for j in range(count):
		for i in range(count):
			if not is_nan(levels[j * count + i]):
				continue

			var total: float = 0.0
			var wet: int = 0

			for dj in range(-1, 2):
				for di in range(-1, 2):
					var ii: int = i + di
					var jj: int = j + dj
					var other: float

					if ii >= 0 and jj >= 0 and ii < count and jj < count:
						other = levels[jj * count + ii]
					else:
						# Across the chunk edge: the same answer the next chunk gets.
						other = _level_at(generator, data, origin.x + float(ii) * spacing, origin.y + float(jj) * spacing, spacing)

					if not is_nan(other):
						total += other
						wet += 1

			if wet == 0:
				continue

			var level: float = total / float(wet)
			var x: float = origin.x + float(i) * spacing
			var z: float = origin.y + float(j) * spacing
			var ground: float = _fine_ground(generator, x, z)

			if ground > level:
				edge[j * count + i] = level
			elif _is_sea(generator, data, x, z, spacing):
				edge[j * count + i] = minf(level, 0.0) - SEA_TUCK_M
			else:
				edge[j * count + i] = ground - SHORE_SINK_M

	return edge


# ---------------------------------------------------------------- running water on the ground

# The 8 m grid is too coarse for thin running water: between grid points the real
# ground (smooth curve plus detail noise, up to about half a meter off a straight
# line) rises through a thin sheet or drops away under it, which showed as stripes.
# A cell whose wet corners are not level is running water; its surface is laid on
# the real ground at FINE_SUB x FINE_SUB points, each the ground plus the water depth
# blended from the corners (so the sheet never dips under the ground or floats over a
# dip). Level water (ponds, lakes) keeps the flat 8 m surface.
const FINE_SUB := 4
const FINE_SLOPE_M := 0.15     # wet corners differing more than this make a running-water cell
const FILM_M := 0.04           # a running sheet sits this far over the ground
const FINE_WALL_M := 3.0       # a cell with this much water at one corner and bank at another is a pond wall: flat surface
const FINE_DEPTH_M := 1.5      # cells where all the water is deeper than this stay flat (no stripes there)

static var _ground_cache: Dictionary = {}
static var _ground_mutex: Mutex = Mutex.new()
const GROUND_CACHE_MAX := 400000


# {cell index: PackedFloat32Array of (FINE_SUB + 1)^2 surface heights, row by row}.
static func _fine_cells(generator, origin: Vector2, count: int, spacing: float, levels: PackedFloat32Array, edge: PackedFloat32Array) -> Dictionary:
	var fine: Dictionary = {}
	var depth: PackedFloat32Array = PackedFloat32Array()
	depth.resize(count * count)
	depth.fill(NAN)
	var step: float = spacing / float(FINE_SUB)
	var side: int = FINE_SUB + 1

	for j in range(count - 1):
		for i in range(count - 1):
			var corners: Array = [j * count + i, j * count + i + 1, (j + 1) * count + i, (j + 1) * count + i + 1]
			var low: float = INF
			var high: float = -INF

			for c in corners:
				if not is_nan(levels[c]):
					low = minf(low, levels[c])
					high = maxf(high, levels[c])

			if low == INF or high - low < FINE_SLOPE_M:
				continue

			var d: Array = []

			for c in corners:
				if is_nan(levels[c]):
					# A shore point: below zero where the bank rises above the water, so
					# the sheet meets the ground along its contour instead of the cell edge.
					if is_nan(edge[c]):
						d.append(0.0)
					else:
						d.append(edge[c] - generator.surface_height(origin.x + float(c % count) * spacing, origin.y + float(c / count) * spacing, 3))

					continue

				# The simulation's ground is the 8 m grid ground (detail at 8 m spacing).
				if is_nan(depth[c]):
					depth[c] = maxf(levels[c] - generator.surface_height(origin.x + float(c % count) * spacing, origin.y + float(c / count) * spacing, 3), 0.0)

				d.append(depth[c])

			var shallowest: float = INF

			for n in range(4):
				if not is_nan(levels[corners[n]]):
					shallowest = minf(shallowest, d[n])

			if shallowest > FINE_DEPTH_M:
				continue

			# Owner report (2026-10-21, build 320, pond A at x10 flow): jagged spikes stood up out
			# of a pond's far shore. The spring's sloshing made pond cells "running" (levels
			# differ 0.15 m), and on a steep bowl wall the depth blended across a cell from deep
			# water to the dry bank put the sheet metres above the real water. A cell holding
			# deep water beside the bank is a pond wall: it keeps the flat surface.
			var deepest: float = 0.0
			var bank: bool = false

			for n in range(4):
				if is_nan(levels[corners[n]]):
					bank = true
				else:
					deepest = maxf(deepest, d[n])

			if bank and deepest > FINE_WALL_M:
				continue

			var heights: PackedFloat32Array = PackedFloat32Array()
			heights.resize(side * side)

			for b in range(side):
				var v: float = float(b) / float(FINE_SUB)

				for a in range(side):
					var u: float = float(a) / float(FINE_SUB)
					var water: float = lerpf(lerpf(d[0], d[1], u), lerpf(d[2], d[3], u), v)
					var ground: float = _fine_ground(generator, origin.x + float(i) * spacing + float(a) * step, origin.y + float(j) * spacing + float(b) * step)
					# Never above the highest water level of the cell: a running sheet lies between its corners' levels.
					heights[b * side + a] = minf(ground + water + FILM_M, high + FILM_M)

			fine[j * count + i] = heights

	return fine


# Forgets the cached ground (the tile files changed).
static func forget_ground() -> void:
	_ground_mutex.lock()
	_ground_cache.clear()
	_ground_mutex.unlock()


# Real (finest) ground height, cached: the ground does not change while water runs.
static func _fine_ground(generator, x: float, z: float) -> float:
	var key: Vector2i = Vector2i(int(round(x * 4.0)), int(round(z * 4.0)))
	_ground_mutex.lock()
	var known: Variant = _ground_cache.get(key)
	_ground_mutex.unlock()

	if known != null:
		return known

	var height: float = generator.surface_height(x, z, 0)
	_ground_mutex.lock()

	if _ground_cache.size() >= GROUND_CACHE_MAX:
		_ground_cache.clear()

	_ground_cache[key] = height
	_ground_mutex.unlock()
	return height


# How far (in grid steps) a hole in a river may be closed. Steep falls leave long holes.
const GAP_STEPS := 6


# Rivers are one or two samples wide and the baked map leaves holes along
# them, mostly where the line steps sideways. A dry point with water on
# both sides of it (up to three steps away, up and down or left and right,
# allowing one step across) takes the mean of the two, closing the hole.
static func _gap_level(generator, data, x: float, z: float, spacing: float) -> float:
	for axis in [Vector2(0, 1), Vector2(1, 0)]:
		var across: Vector2 = Vector2(axis.y, axis.x)
		var a: float = NAN
		var da: int = 0

		for before in range(1, GAP_STEPS + 1):
			for side_a in [0, -1, 1]:
				a = _level_at(generator, data, x + (across.x * side_a - axis.x * before) * spacing, z + (across.y * side_a - axis.y * before) * spacing, spacing)

				if not is_nan(a):
					break

			if not is_nan(a):
				da = before
				break

		if is_nan(a):
			continue

		for after in range(1, GAP_STEPS + 1):
			for side_b in [0, -1, 1]:
				var b: float = _level_at(generator, data, x + (across.x * side_b + axis.x * after) * spacing, z + (across.y * side_b + axis.y * after) * spacing, spacing)

				if not is_nan(b):
					# A long hole is only a waterfall when the two ends differ in height;
					# level water far apart is separate water with land between.
					if da + after > 4 and absf(a - b) < 1.5:
						break

					# Nearer end counts more, so a long drop slopes instead of stepping.
					return lerpf(a, b, float(da) / float(da + after))

	return NAN


# Packs levels for sending: empty when the chunk holds no inland water,
# else a mask (1 wet, 2 shore) with those levels in cm, then the fine cells, Zstandard-compressed.
static func encode(grid: Dictionary) -> PackedByteArray:
	if int(grid.get("wet", 0)) == 0:
		return PackedByteArray()

	var buffer: StreamPeerBuffer = StreamPeerBuffer.new()
	var levels: PackedFloat32Array = grid["levels"]
	buffer.put_u16(int(grid["count"]))
	buffer.put_float(float(grid["spacing"]))

	var edge: PackedFloat32Array = grid.get("edge", PackedFloat32Array())

	for n in range(levels.size()):
		if not is_nan(levels[n]):
			buffer.put_u8(1)
			buffer.put_32(int(round(levels[n] * 100.0)))
		elif not edge.is_empty() and not is_nan(edge[n]):
			buffer.put_u8(2)          # a shore point (_shore_levels)
			buffer.put_32(int(round(edge[n] * 100.0)))
		else:
			buffer.put_u8(0)

	var fine: Dictionary = grid.get("fine", {})
	buffer.put_u8(FINE_SUB)
	buffer.put_u32(fine.size())

	for cell in fine:
		buffer.put_u32(cell)

		for h in fine[cell]:
			buffer.put_32(int(round(h * 100.0)))

	# Version 2: the current at each wet point (old chunks without it decode with an empty
	# "vel", and the water is then drawn from the surface slope).
	var vel: PackedFloat32Array = grid.get("vel", PackedFloat32Array())

	if vel.size() == levels.size() * 2:
		buffer.put_u8(VEL_MARK)

		for n in range(levels.size()):
			if not is_nan(levels[n]):
				buffer.put_8(clampi(int(round(vel[n * 2] * 10.0)), -127, 127))
				buffer.put_8(clampi(int(round(vel[n * 2 + 1] * 10.0)), -127, 127))

	# Version 3: the fall columns (water_falls.gd), only after a velocity trailer.
	if vel.size() == levels.size() * 2:
		FallsScript.encode_into(buffer, grid.get("falls", []))

	var raw: PackedByteArray = buffer.data_array
	var packed: PackedByteArray = PackedByteArray()
	packed.resize(4)
	packed.encode_u32(0, raw.size())
	packed.append_array(raw.compress(FileAccess.COMPRESSION_ZSTD))
	return packed


static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 4:
		return {"count": 0, "spacing": 8.0, "levels": PackedFloat32Array(), "wet": 0}

	var buffer: StreamPeerBuffer = StreamPeerBuffer.new()
	buffer.data_array = bytes.slice(4).decompress(bytes.decode_u32(0), FileAccess.COMPRESSION_ZSTD)
	var count: int = buffer.get_u16()
	var spacing: float = buffer.get_float()
	var levels: PackedFloat32Array = PackedFloat32Array()
	levels.resize(count * count)
	var edge: PackedFloat32Array = PackedFloat32Array()
	edge.resize(count * count)
	edge.fill(NAN)
	var wet: int = 0

	for n in range(count * count):
		var kind: int = buffer.get_u8()
		levels[n] = NAN

		if kind == 1:
			levels[n] = float(buffer.get_32()) / 100.0
			wet += 1
		elif kind == 2:
			edge[n] = float(buffer.get_32()) / 100.0

	var fine: Dictionary = {}

	if buffer.get_available_bytes() >= 5 and buffer.get_u8() == FINE_SUB:
		var side: int = FINE_SUB + 1

		for f in range(buffer.get_u32()):
			var cell: int = buffer.get_u32()
			var heights: PackedFloat32Array = PackedFloat32Array()
			heights.resize(side * side)

			for n in range(side * side):
				heights[n] = float(buffer.get_32()) / 100.0

			fine[cell] = heights

	var vel: PackedFloat32Array = PackedFloat32Array()
	var falls: Array = []

	# Trailers, each led by a mark byte: the current, then the fall columns.
	while buffer.get_available_bytes() >= 1:
		var mark: int = buffer.get_u8()

		if mark == VEL_MARK:
			vel.resize(count * count * 2)

			for n in range(count * count):
				if not is_nan(levels[n]):
					vel[n * 2] = float(buffer.get_8()) / 10.0
					vel[n * 2 + 1] = float(buffer.get_8()) / 10.0
		elif mark == FallsScript.FALL_MARK:
			falls = FallsScript.decode_from(buffer)
		else:
			break

	return {"count": count, "spacing": spacing, "levels": levels, "wet": wet, "edge": edge, "fine": fine, "vel": vel, "falls": falls}


# A water mesh for a chunk: one smooth surface over the grid. Wet points
# sit at their own level; dry points beside water are pulled under the bank
# (SHORE_DROP m lower) and fade out, so the surface slides under the ground
# without hard edges or overlapping panels. Only cells with at least one
# wet corner are drawn. Vertex positions are relative to the chunk corner;
# vertex alpha carries the fade; red and green carry the downhill slope of the
# water surface (blue 0 marks it) so the water shader can run ripples downstream.
const SHORE_DROP := 1.5
const FLOW_SLOPE_FULL := 0.05   # a surface slope this steep is drawn as the fastest flow


# The vertex colour for a point: downhill direction and steepness of the water surface
# around grid point (i, j), from the levels on either side.
static func _flow_color(levels: PackedFloat32Array, i: int, j: int, count: int, spacing: float, alpha: float, vel: PackedFloat32Array = PackedFloat32Array()) -> Color:
	if not vel.is_empty():
		return _current_color(levels, vel, i, j, count, alpha)

	# Averaged over the 3 x 3 points around, so the flow turns smoothly from square to
	# square (owner, 2026-10-19: sharp changes drew zigzags and square seams in the ripples).
	var gx: float = 0.0
	var gz: float = 0.0
	var used: int = 0

	for dj in range(-1, 2):
		for di in range(-1, 2):
			var ii: int = i + di
			var jj: int = j + dj

			if ii < 0 or jj < 0 or ii >= count or jj >= count or is_nan(levels[jj * count + ii]):
				continue

			gx += _slope_along(levels, ii, jj, 1, 0, count, spacing)
			gz += _slope_along(levels, ii, jj, 0, 1, count, spacing)
			used += 1

	if used > 0:
		gx /= float(used)
		gz /= float(used)

	var scale: float = 0.5 / FLOW_SLOPE_FULL
	return Color(0.5 + clampf(-gx * scale, -0.5, 0.5), 0.5 + clampf(-gz * scale, -0.5, 0.5), 0.0, alpha)


# The vertex colour from the server's current: the mean over the 3 x 3 wet points around, as a
# direction and a "steepness" the shader turns back into the speed (speed = fastest * sqrt(steep)).
static func _current_color(levels: PackedFloat32Array, vel: PackedFloat32Array, i: int, j: int, count: int, alpha: float) -> Color:
	var vx: float = 0.0
	var vz: float = 0.0
	var used: int = 0

	for dj in range(-1, 2):
		for di in range(-1, 2):
			var ii: int = i + di
			var jj: int = j + dj

			if ii < 0 or jj < 0 or ii >= count or jj >= count or is_nan(levels[jj * count + ii]):
				continue

			vx += vel[(jj * count + ii) * 2]
			vz += vel[(jj * count + ii) * 2 + 1]
			used += 1

	if used == 0:
		return Color(0.5, 0.5, 0.0, alpha)

	vx /= float(used)
	vz /= float(used)
	var speed: float = sqrt(vx * vx + vz * vz)

	if speed < 0.001:
		return Color(0.5, 0.5, 0.0, alpha)

	var steep: float = clampf(pow(speed / FLOW_FASTEST_M_S, 2.0), 0.0, 1.0)
	return Color(0.5 + vx / speed * steep * 0.5, 0.5 + vz / speed * steep * 0.5, 0.0, alpha)


static func _slope_along(levels: PackedFloat32Array, i: int, j: int, di: int, dj: int, count: int, spacing: float) -> float:
	var here: float = levels[j * count + i] if i >= 0 and j >= 0 and i < count and j < count else NAN
	var ahead: float = levels[(j + dj) * count + i + di] if i + di < count and j + dj < count else NAN
	var back: float = levels[(j - dj) * count + i - di] if i - di >= 0 and j - dj >= 0 else NAN

	if not is_nan(ahead) and not is_nan(back):
		return (ahead - back) / (2.0 * spacing)

	if not is_nan(here) and not is_nan(ahead):
		return (ahead - here) / spacing

	if not is_nan(here) and not is_nan(back):
		return (here - back) / spacing

	return 0.0


const ICE_CALM_M_S := 0.15       # a pond cell: slower than this
const ICE_FLAT_M := 0.05         # ...on a surface this flat across the cell
const ICE_CORE := 2              # a pond's body: every point within this many cells all wet and calm (40 m wide)
const ICE_REACH := 2             # the sheet reaches this far from the body, so it runs out to the shore


# The ice sheet of a still water body as triangles (chunk coordinates, counter-clockwise from
# above) at the water level: the quads whose four points are wet, flat and slow and that lie within
# ICE_REACH of the body of a pond or lake. Rivers are narrower than ICE_CORE * 2 + 1 cells and
# never freeze. Walkable ice for the client (a collider only; the sheet is drawn by the water).
static func ice_triangles(grid: Dictionary) -> PackedVector3Array:
	var triangles: PackedVector3Array = PackedVector3Array()
	var count: int = int(grid.get("count", 0))

	if count < 2 or int(grid.get("wet", 0)) == 0:
		return triangles

	var levels: PackedFloat32Array = grid["levels"]
	var vel: PackedFloat32Array = grid.get("vel", PackedFloat32Array())
	var spacing: float = float(grid["spacing"])
	var calm: PackedByteArray = PackedByteArray()
	calm.resize(count * count)

	for n in range(count * count):
		if is_nan(levels[n]):
			continue

		var still: bool = vel.size() < (n + 1) * 2 or Vector2(vel[n * 2], vel[n * 2 + 1]).length() <= ICE_CALM_M_S
		calm[n] = 1 if still else 0

	var core: PackedByteArray = PackedByteArray()
	core.resize(count * count)

	for j in range(count):
		for i in range(count):
			var all: bool = calm[j * count + i] == 1

			for dj in range(-ICE_CORE, ICE_CORE + 1):
				if not all:
					break

				for di in range(-ICE_CORE, ICE_CORE + 1):
					var ii: int = i + di
					var jj: int = j + dj

					if ii < 0 or jj < 0 or ii >= count or jj >= count:
						continue

					if calm[jj * count + ii] == 0:
						all = false
						break

			core[j * count + i] = 1 if all else 0

	for j in range(count - 1):
		for i in range(count - 1):
			var a: int = j * count + i
			var b: int = a + 1
			var c: int = a + count
			var d: int = c + 1

			if calm[a] == 0 or calm[b] == 0 or calm[c] == 0 or calm[d] == 0:
				continue

			var top: float = maxf(maxf(levels[a], levels[b]), maxf(levels[c], levels[d]))
			var bottom: float = minf(minf(levels[a], levels[b]), minf(levels[c], levels[d]))

			if top - bottom > ICE_FLAT_M:
				continue

			var near: bool = false

			for dj in range(-ICE_REACH, ICE_REACH + 2):
				for di in range(-ICE_REACH, ICE_REACH + 2):
					var ii: int = i + di
					var jj: int = j + dj

					if ii >= 0 and jj >= 0 and ii < count and jj < count and core[jj * count + ii] == 1:
						near = true

			if not near:
				continue

			var level: float = (top + bottom) * 0.5
			var x0: float = float(i) * spacing
			var z0: float = float(j) * spacing
			triangles.append(Vector3(x0, level, z0))
			triangles.append(Vector3(x0, level, z0 + spacing))
			triangles.append(Vector3(x0 + spacing, level, z0))
			triangles.append(Vector3(x0 + spacing, level, z0))
			triangles.append(Vector3(x0, level, z0 + spacing))
			triangles.append(Vector3(x0 + spacing, level, z0 + spacing))

	return triangles


static func build_mesh(grid: Dictionary, material: Material) -> ArrayMesh:
	var count: int = int(grid["count"])
	var spacing: float = float(grid["spacing"])
	var levels: PackedFloat32Array = grid["levels"]
	var fine: Dictionary = grid.get("fine", {})
	var edge: PackedFloat32Array = grid.get("edge", PackedFloat32Array())
	var vel: PackedFloat32Array = grid.get("vel", PackedFloat32Array())
	var height: PackedFloat32Array = PackedFloat32Array()
	height.resize(count * count)
	height.fill(NAN)

	for j in range(count):
		for i in range(count):
			var n: int = j * count + i

			if not is_nan(levels[n]):
				height[n] = levels[n]
				continue

			if not edge.is_empty() and not is_nan(edge[n]):
				height[n] = edge[n]
				continue

			var total: float = 0.0
			var wet: int = 0

			for dj in range(-1, 2):
				for di in range(-1, 2):
					var jj: int = j + dj
					var ii: int = i + di

					if jj < 0 or jj >= count or ii < 0 or ii >= count:
						continue

					var other: float = levels[jj * count + ii]

					if not is_nan(other):
						total += other
						wet += 1

			if wet > 0:
				height[n] = total / float(wet) - SHORE_DROP

	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	var slot: PackedInt32Array = PackedInt32Array()
	slot.resize(count * count)
	slot.fill(-1)

	for j in range(count - 1):
		for i in range(count - 1):
			var corners: Array = [j * count + i, j * count + i + 1, (j + 1) * count + i + 1, (j + 1) * count + i]
			var any_wet: bool = false

			for c in corners:
				if not is_nan(levels[c]):
					any_wet = true

			if not any_wet:
				continue

			if fine.has(j * count + i):
				_add_fine_cell(_seal_fine_edges(fine, i, j, count, height), i, j, spacing, levels, edge, count, vertices, normals, colors, indices, vel)
				continue

			var ids: Array = []

			for c in corners:
				if slot[c] < 0:
					slot[c] = vertices.size()
					var level: float = height[c]

					if is_nan(level):
						# A dry corner with no wet neighbor in this chunk: sit with the cell's wet ones.
						level = 0.0
						var wet_total: float = 0.0
						var wet_count: int = 0

						for d in corners:
							if not is_nan(levels[d]):
								wet_total += levels[d]
								wet_count += 1

						level = wet_total / float(wet_count) - SHORE_DROP

					vertices.append(Vector3(float(c % count) * spacing, level, float(c / count) * spacing))
					normals.append(Vector3.UP)
					colors.append(_flow_color(levels, c % count, c / count, count, spacing, 1.0 if not is_nan(levels[c]) or _is_shore(edge, c) else 0.0, vel))

				ids.append(slot[c])

			indices.append_array(PackedInt32Array([ids[0], ids[1], ids[2], ids[0], ids[2], ids[3]]))

	var mesh: ArrayMesh = ArrayMesh.new()

	if vertices.is_empty():
		return mesh

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh


# Owner report (2026-10-19, thin lines in the water): a fine cell's edge must meet its
# neighbour exactly. Where the cell across an edge is drawn plain (or lies in the next
# chunk), the edge follows that plain cell's straight edge between the shared corners; a
# corner touching any plain cell takes the plain corner height. Edges between two fine
# cells already match. Returns the cell's heights with its edges sealed.
static func _seal_fine_edges(fine: Dictionary, i: int, j: int, count: int, height: PackedFloat32Array) -> PackedFloat32Array:
	var heights: PackedFloat32Array = PackedFloat32Array(fine[j * count + i])
	var side: int = FINE_SUB + 1
	var plain: Callable = func(ci: int, cj: int) -> bool:
		return ci < 0 or cj < 0 or ci >= count - 1 or cj >= count - 1 or not fine.has(cj * count + ci)
	var corner_h: Callable = func(ci: int, cj: int, own: float) -> float:
		var h: float = height[cj * count + ci]
		return own if is_nan(h) else h
	# Each side: the cell across it, its two corners (grid i, j) and the sample indices along it.
	var sides: Array = [
		[i, j - 1, Vector2i(i, j), Vector2i(i + 1, j), func(t: int) -> int: return t],
		[i, j + 1, Vector2i(i, j + 1), Vector2i(i + 1, j + 1), func(t: int) -> int: return FINE_SUB * side + t],
		[i - 1, j, Vector2i(i, j), Vector2i(i, j + 1), func(t: int) -> int: return t * side],
		[i + 1, j, Vector2i(i + 1, j), Vector2i(i + 1, j + 1), func(t: int) -> int: return t * side + FINE_SUB],
	]

	for entry in sides:
		if not plain.call(entry[0], entry[1]):
			continue

		var at: Callable = entry[4]
		var a: Vector2i = entry[2]
		var b: Vector2i = entry[3]
		var ha: float = corner_h.call(a.x, a.y, heights[at.call(0)])
		var hb: float = corner_h.call(b.x, b.y, heights[at.call(FINE_SUB)])

		for t in range(side):
			heights[at.call(t)] = lerpf(ha, hb, float(t) / float(FINE_SUB))

	# Corners shared with a plain cell only diagonally.
	var corners: Array = [[0, 0, -1, -1], [FINE_SUB, 0, 1, -1], [0, FINE_SUB, -1, 1], [FINE_SUB, FINE_SUB, 1, 1]]

	for c in corners:
		var ci: int = i + (1 if c[0] > 0 else 0)
		var cj: int = j + (1 if c[1] > 0 else 0)

		if plain.call(i + c[2], j + c[3]):
			heights[c[1] * side + c[0]] = corner_h.call(ci, cj, heights[c[1] * side + c[0]])

	return heights


# A shore point (the water runs on into the bank there and the ground cuts it off).
static func _is_shore(edge: PackedFloat32Array, n: int) -> bool:
	return not edge.is_empty() and not is_nan(edge[n])


# A running-water cell drawn from its fine heights: own vertices, normals from the
# surface slope, alpha blended from the wet corners (the sheet fades out toward a dry one).
static func _add_fine_cell(heights: PackedFloat32Array, i: int, j: int, spacing: float, levels: PackedFloat32Array, edge: PackedFloat32Array, count: int, vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array, vel: PackedFloat32Array = PackedFloat32Array()) -> void:
	var side: int = FINE_SUB + 1
	var step: float = spacing / float(FINE_SUB)
	var w00: float = 0.0 if is_nan(levels[j * count + i]) and not _is_shore(edge, j * count + i) else 1.0
	var w10: float = 0.0 if is_nan(levels[j * count + i + 1]) and not _is_shore(edge, j * count + i + 1) else 1.0
	var w01: float = 0.0 if is_nan(levels[(j + 1) * count + i]) and not _is_shore(edge, (j + 1) * count + i) else 1.0
	var w11: float = 0.0 if is_nan(levels[(j + 1) * count + i + 1]) and not _is_shore(edge, (j + 1) * count + i + 1) else 1.0
	var first: int = vertices.size()
	var flow: Array = [
		_flow_color(levels, i, j, count, spacing, 1.0, vel), _flow_color(levels, i + 1, j, count, spacing, 1.0, vel),
		_flow_color(levels, i, j + 1, count, spacing, 1.0, vel), _flow_color(levels, i + 1, j + 1, count, spacing, 1.0, vel),
	]

	for b in range(side):
		for a in range(side):
			var u: float = float(a) / float(FINE_SUB)
			var v: float = float(b) / float(FINE_SUB)
			var h: float = heights[b * side + a]
			var dx: float = heights[b * side + mini(a + 1, FINE_SUB)] - heights[b * side + maxi(a - 1, 0)]
			var dz: float = heights[mini(b + 1, FINE_SUB) * side + a] - heights[maxi(b - 1, 0) * side + a]
			var run_x: float = step * float(mini(a + 1, FINE_SUB) - maxi(a - 1, 0))
			var run_z: float = step * float(mini(b + 1, FINE_SUB) - maxi(b - 1, 0))
			vertices.append(Vector3(float(i) * spacing + float(a) * step, h, float(j) * spacing + float(b) * step))
			normals.append(Vector3(-dx / run_x, 1.0, -dz / run_z).normalized())
			var color: Color = (flow[0] as Color).lerp(flow[1], u).lerp((flow[2] as Color).lerp(flow[3], u), v)
			color.a = lerpf(lerpf(w00, w10, u), lerpf(w01, w11, u), v)
			colors.append(color)

	for b in range(FINE_SUB):
		for a in range(FINE_SUB):
			var p: int = first + b * side + a
			indices.append_array(PackedInt32Array([p, p + 1, p + side + 1, p, p + side + 1, p + side]))
