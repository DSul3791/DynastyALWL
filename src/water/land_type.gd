extends RefCounted

# Land types from the water that is really there (design/WATER_LAND_TYPES.md, Dave 24 Oct 2026).
# R1: names the land and checks that every spring sits in a natural catch basin. Read only: nothing here
# changes plants, water or ground. Pure static functions plus the running signature (LandSignature below),
# so the headless tests need no tile.
#
# A cell is read through slowly decaying averages of depth, speed and wet share (time constant TAU_HOURS
# game hours, 30 game days), so one storm does not rename the land. The baked river and lake classes are a
# floor: a baked river stays river-or-wetter through a summer dry spell (river_dry).

const DRY := 0
const LAKE := 1
const RIVER := 2
const MARSH := 3
const SWAMP := 4
const BOG := 5
const FLOODPLAIN := 6

const NAMES := ["dry", "lake", "river", "marsh", "swamp", "bog", "floodplain"]

# Baked water_class values (tile_water.gd): 0 none, 1 ocean, 2 lake, 3 river.
const BAKED_LAKE := 2
const BAKED_RIVER := 3

const WET_M := 0.12                # water counts as drawn from 12 cm (water_sim WET_M)
const LAKE_DEPTH_M := 1.0
const LAKE_SPEED := 0.1
const LAKE_WET := 0.9
const RIVER_SPEED := 0.3           # the water wheel number (data/water_flow.json)
const RIVER_WET := 0.8
const WETLAND_DEPTH_MAX_M := 1.0
const BOG_DEPTH_MIN_M := 0.05
const WETLAND_WET := 0.7
const BOG_WET := 0.6
const FLOOD_WET_MIN := 0.05
const FLOOD_WET_MAX := 0.4
const LAKE_MIN_CELLS := 4
const WETLAND_MIN_CELLS := 8

const TAU_HOURS := 720.0           # 30 game days of game hours

# Spring catch basin rule (Dave 24 Oct 19:53): water sources start in a natural catch basin, a hollow the
# water fills before it can spill. Basin depth = the lowest level at which water standing at the spring's
# cell can get away (reach a cell clearly lower than the cell, or the edge of the look window RADIUS_CELLS
# away) minus the cell's own ground. A spring on a slope or at the top of a channel that runs out has depth
# 0; a head pond bed has the depth of its rim. The sim has no banks, so only a hollow keeps a spring's flow
# from spreading into a sheet.
const RADIUS_CELLS := 10
const ESCAPE_DROP_M := 0.3          # a cell this much lower than the spring cell is somewhere the water gets away to
const LEVEL_STEP_M := 0.1
const LEVEL_MAX_M := 3.0            # look no higher than this above the spring cell (deeper than this counts as 3.0)
const BASIN_DEPTH_M := 0.5
const SLIDE_CELLS := 10
const SPREAD_RADIUS := 12
const SPREAD_THIN_M := 0.15
const SPREAD_MAX_CELLS := 40       # thin wet cells off the painted channel (about 2,500 m2) before a spring fails

const MANNING_N := 0.035


# One cell's type from its averaged water. depth_m and speed in m and m/s, wet share 0..1, base_class the
# baked water_class, peaty/cool true on peat soil or cool wet flats, fertile_warm true on fertile mineral
# soil in a warm climate. Extent (lake 4+ joined cells, wetland 8+) is applied by filter_extent().
static func classify_cell(depth_m: float, speed: float, wet: float, base_class: int, peaty: bool = false, fertile_warm: bool = false) -> int:
	if depth_m >= LAKE_DEPTH_M and speed < LAKE_SPEED and wet >= LAKE_WET:
		return LAKE

	if depth_m >= WET_M and speed >= RIVER_SPEED and wet >= RIVER_WET:
		return RIVER

	# The baked class is a floor: a baked river stays river (slow in a dry spell) while it is mostly wet; a baked lake stays lake.
	if base_class == BAKED_RIVER and wet >= 0.5:
		return RIVER

	if base_class == BAKED_LAKE and wet >= 0.5:
		return LAKE

	if speed < RIVER_SPEED:
		if peaty and depth_m >= BOG_DEPTH_MIN_M and depth_m <= 0.4 and speed < LAKE_SPEED and wet >= BOG_WET:
			return BOG

		if depth_m >= WET_M and depth_m <= WETLAND_DEPTH_MAX_M and wet >= WETLAND_WET:
			if peaty:
				return BOG

			return SWAMP if fertile_warm else MARSH

	if wet >= FLOOD_WET_MIN and wet <= FLOOD_WET_MAX:
		return FLOODPLAIN

	return DRY


# Joined groups (4-neighbour) of one wet type smaller than the minimum fall back to DRY (lake) or FLOODPLAIN-less DRY (wetland).
# `types` is a PackedByteArray of side*side type values; returns a new array.
static func filter_extent(types: PackedByteArray, side: int) -> PackedByteArray:
	var out: PackedByteArray = types.duplicate()
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(types.size())

	for start in range(types.size()):
		var kind: int = types[start]

		if seen[start] != 0 or (kind != LAKE and kind != MARSH and kind != SWAMP and kind != BOG):
			continue

		var group: PackedInt32Array = PackedInt32Array()
		var queue: PackedInt32Array = PackedInt32Array([start])
		seen[start] = 1

		while not queue.is_empty():
			var k: int = queue[queue.size() - 1]
			queue.resize(queue.size() - 1)
			group.append(k)
			var i: int = k % side
			@warning_ignore("integer_division")
			var j: int = k / side

			for n in [k - 1 if i > 0 else -1, k + 1 if i < side - 1 else -1, k - side if j > 0 else -1, k + side if j < side - 1 else -1]:
				if n >= 0 and seen[n] == 0 and types[n] == kind:
					seen[n] = 1
					queue.append(n)

		var needed: int = LAKE_MIN_CELLS if kind == LAKE else WETLAND_MIN_CELLS

		if group.size() < needed:
			for k in group:
				out[k] = DRY

	return out


# Speed estimate in m/s for every cell from the water surface slope (Manning), the same shape the drawn
# current has. The C++ core does not expose its flow arrays, so the signature reads this instead.
static func speed_cell(ground: PackedFloat32Array, depth: PackedFloat32Array, side: int, spacing_m: float, k: int) -> float:
	var h: float = depth[k]
	var i: int = k % side
	@warning_ignore("integer_division")
	var j: int = k / side

	if h < 0.01 or i < 1 or j < 1 or i >= side - 1 or j >= side - 1:
		return 0.0

	var here: float = ground[k] + h
	var slope: float = 0.0

	for n in [k - 1, k + 1, k - side, k + side]:
		if depth[n] > 0.0:
			slope = maxf(slope, (here - (ground[n] + depth[n])) / spacing_m)

	return pow(h, 2.0 / 3.0) * sqrt(maxf(slope, 0.0)) / MANNING_N


static func speeds_from_levels(ground: PackedFloat32Array, depth: PackedFloat32Array, side: int, spacing_m: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(side * side)

	for k in range(side * side):
		if depth[k] >= 0.01:
			out[k] = speed_cell(ground, depth, side, spacing_m, k)

	return out


# How deep a hollow the cell (i, j) sits in, in metres (0 to LEVEL_MAX_M): raises a water level in steps of
# LEVEL_STEP_M from the cell's own ground and floods outwards (4 neighbours, inside the look window) over ground
# at or below that level; the first level that reaches an escape cell (clearly lower ground, sea, or the window
# edge) is the spill level.
static func basin_depth(ground: PackedFloat32Array, side: int, i: int, j: int) -> float:
	var start_height: float = ground[j * side + i]
	var steps: int = int(LEVEL_MAX_M / LEVEL_STEP_M)

	for step in range(steps + 1):
		var level: float = start_height + float(step) * LEVEL_STEP_M
		var seen: Dictionary = {j * side + i: true}
		var queue: PackedInt32Array = PackedInt32Array([j * side + i])
		var escaped: bool = false

		while not queue.is_empty() and not escaped:
			var k: int = queue[queue.size() - 1]
			queue.resize(queue.size() - 1)
			var ki: int = k % side
			@warning_ignore("integer_division")
			var kj: int = k / side

			if absi(ki - i) >= RADIUS_CELLS or absi(kj - j) >= RADIUS_CELLS or ki <= 0 or kj <= 0 or ki >= side - 1 or kj >= side - 1:
				escaped = true
				break

			for n in [k - 1, k + 1, k - side, k + side]:
				if seen.has(n):
					continue

				seen[n] = true
				var h: float = ground[n]

				if h < start_height - ESCAPE_DROP_M or h <= 0.0:
					escaped = true
					break

				if h <= level:
					queue.append(n)

		if escaped:
			return float(step) * LEVEL_STEP_M

	return LEVEL_MAX_M


# {"ok": bool, "below_m": basin depth, "fix": cell index to slide to or -1}. A spring that fails slides to the
# lowest painted river or lake cell within SLIDE_CELLS whose basin depth passes.
static func basin_report(ground: PackedFloat32Array, water_class: PackedByteArray, side: int, cell: int) -> Dictionary:
	var i: int = cell % side
	@warning_ignore("integer_division")
	var j: int = cell / side

	if i < RADIUS_CELLS or j < RADIUS_CELLS or i >= side - RADIUS_CELLS or j >= side - RADIUS_CELLS:
		return {"ok": true, "below_m": 0.0, "fix": -1, "edge": true}      # at the tile edge: the neighbour tile decides

	var depth: float = basin_depth(ground, side, i, j)

	if depth >= BASIN_DEPTH_M:
		return {"ok": true, "below_m": depth, "fix": -1}

	var best: int = -1
	var best_height: float = INF

	for dj in range(-SLIDE_CELLS, SLIDE_CELLS + 1):
		for di in range(-SLIDE_CELLS, SLIDE_CELLS + 1):
			var ni: int = i + di
			var nj: int = j + dj

			if ni < RADIUS_CELLS or nj < RADIUS_CELLS or ni >= side - RADIUS_CELLS or nj >= side - RADIUS_CELLS:
				continue

			var n: int = nj * side + ni
			var kind: int = water_class[n]

			if (kind != BAKED_RIVER and kind != BAKED_LAKE) or ground[n] >= best_height:
				continue

			if basin_depth(ground, side, ni, nj) >= BASIN_DEPTH_M:
				best_height = ground[n]
				best = n

	return {"ok": false, "below_m": depth, "fix": best}


# Thin wet cells (under SPREAD_THIN_M) near a spring that are NOT on the painted channel: a sheet spreading
# over open ground. A spring fails when there are more than SPREAD_MAX_CELLS of them.
static func spread_cells(depth: PackedFloat32Array, water_class: PackedByteArray, side: int, cell: int) -> int:
	var i: int = cell % side
	@warning_ignore("integer_division")
	var j: int = cell / side
	var count: int = 0

	for dj in range(-SPREAD_RADIUS, SPREAD_RADIUS + 1):
		for di in range(-SPREAD_RADIUS, SPREAD_RADIUS + 1):
			var ni: int = i + di
			var nj: int = j + dj

			if ni < 0 or nj < 0 or ni >= side or nj >= side:
				continue

			var n: int = nj * side + ni

			if water_class[n] == 0 and depth[n] > 0.01 and depth[n] < SPREAD_THIN_M:
				count += 1

	return count
