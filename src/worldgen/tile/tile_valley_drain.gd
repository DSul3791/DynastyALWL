extends RefCounted

# Rivers are the lowest line of their valleys (Dave 6 Nov 2026: "They should be the lowest point in the valley all water should flow towards the
# river ... we should be smoothing the surrounding area so it flows towards the river"). Dry ground next to water that lies lower than the water
# is where the settled water spreads into wetlands. This pass spreads out from every river cell over the dry ground lower than the
# water (only through such ground: a ridge stops it), and raises that ground to the water level plus grade_per_m for each metre from the water,
# so it slopes up from the river and drains back into it. The same everywhere in the world: no place is left out. Lakes and the sea keep their shores; ground higher than the water is never touched.
#
# Rules (tile_rules.json water.valley_drain): enabled, reach_m (how far from the water), grade_per_m (rise away from the water), height_m (the
# raised ground stands at least this far over the water at the bank), max_raise_m, band_samples (how far past the tile edge it runs in the frame,
# so two tiles agree along their seam).

const NONE := 0
const RIVER := 3   # tile_water.gd
const TileRollingScript := preload("res://src/worldgen/tile/tile_rolling.gd")


# Raises the ground in place. `water_class` 0 is dry; `surface` is the water level of wet cells. Returns {"raised", "max_m"}.
static func apply(heights: PackedFloat32Array, water_class: PackedByteArray, surface: PackedFloat32Array, n: int, cell_m: float, margin: int, rules: Dictionary) -> Dictionary:
	var result: Dictionary = {"raised": 0, "max_m": 0.0}

	if not bool(rules.get("enabled", false)):
		return result

	var reach: float = float(rules.get("reach_m", 200.0))
	var grade: float = float(rules.get("grade_per_m", 0.01))
	var lift: float = float(rules.get("height_m", 0.3))
	var max_raise: float = float(rules.get("max_raise_m", 10.0))
	var band: int = int(rules.get("band_samples", 50))
	var lo: int = maxi(margin - band, 1)
	var hi: int = mini(n - margin + band, n - 1)   # exclusive
	var total: int = n * n
	var need: PackedFloat32Array = PackedFloat32Array()   # the least height this ground must have to drain to the water
	need.resize(total)
	need.fill(INF)
	var dist: PackedFloat32Array = PackedFloat32Array()   # metres from that water
	dist.resize(total)
	dist.fill(INF)
	var queued: PackedByteArray = PackedByteArray()
	queued.resize(total)
	queued.fill(0)   # resize does not promise zeros
	var queue: PackedInt32Array = PackedInt32Array()
	var diag: float = cell_m * sqrt(2.0)
	var offsets: PackedInt32Array = PackedInt32Array([-1, 1, -n, n, -n - 1, -n + 1, n - 1, n + 1])
	var lengths: PackedFloat32Array = PackedFloat32Array([cell_m, cell_m, cell_m, cell_m, diag, diag, diag, diag])

	# Seeds: the river cells. Lakes and the sea keep their marshy shores (land types' shore marsh); any water still stops the spread.
	for j in range(lo, hi):
		for i in range(lo, hi):
			var k: int = j * n + i

			if water_class[k] == RIVER and not is_nan(surface[k]):
				need[k] = surface[k] + lift
				dist[k] = 0.0
				queue.append(k)
				queued[k] = 1

	# Spread over dry ground lower than the need: shortest path, so each cell takes the least need (the nearest water, by grade).
	var head: int = 0

	while head < queue.size():
		var k: int = queue[head]
		head += 1
		queued[k] = 0
		var i: int = k % n
		@warning_ignore("integer_division")
		var j: int = k / n

		if i <= lo or i >= hi - 1 or j <= lo or j >= hi - 1:
			continue

		for s in range(8):
			var m: int = k + offsets[s]

			if water_class[m] != NONE:
				continue

			var d: float = dist[k] + lengths[s]

			if d > reach:
				continue

			var v: float = need[k] + grade * lengths[s]

			# A ridge stops the spread: ground at or over the need already drains.
			if v >= need[m] or heights[m] >= v:
				continue

			need[m] = v
			dist[m] = d

			if queued[m] == 0:
				queued[m] = 1
				queue.append(m)

		# Keep the queue from growing without end: drop the walked part now and then.
		if head > 1 << 20:
			queue = queue.slice(head)
			head = 0

	for j in range(lo, hi):
		for i in range(lo, hi):
			var k: int = j * n + i

			if water_class[k] != NONE or need[k] == INF or heights[k] >= need[k]:
				continue

			var raise: float = minf(need[k] - heights[k], max_raise)
			heights[k] += raise
			result["raised"] += 1
			result["max_m"] = maxf(result["max_m"], raise)

	return result


# Every dry closed hollow drains (Sonny 7 Nov 2026, Dave x 53453 z 68888: "if these areas are all higher than the river how did water get in them").
# The passes after the drainage (bank shoulders, rolling ground, river mend, mouths) leave small dips on dry shelves, and the live water's rain pools in
# them as ponds with no stream in or out. A priority flood from the outlets (rivers, lakes, the sea, the frame edge) finds each dry cell's spill level, and
# every dry cell under it is raised to it: the dip becomes a flat that drains over its lip. Rule water.valley_drain.drain_hollows. Returns {"cells", "most_m"}.
static func drain_hollows(heights: PackedFloat32Array, water_class: PackedByteArray, n: int, rules: Dictionary) -> Dictionary:
	var result: Dictionary = {"cells": 0, "most_m": 0.0}

	if not bool(rules.get("drain_hollows", false)):
		return result

	var spill: PackedFloat32Array = TileRollingScript._flood(heights, water_class, n, 0.0)

	for k in range(heights.size()):
		if water_class[k] != NONE:
			continue

		var lift: float = spill[k] - heights[k]

		if lift > 0.001:
			heights[k] = spill[k]
			result["cells"] += 1
			result["most_m"] = maxf(result["most_m"], lift)

	return result


# Bake-log census of dry closed hollows, without changing the ground: how many dry cells lie under their spill, how deep the deepest, and the
# volume (Sonny 7 Nov 2026: the P1 bakes raised 3x more hollow cells than #524 and the pass that makes them was unknown; tile_baker prints this
# after each ground pass when water.valley_drain.hollow_census is on). Same flood as drain_hollows.
static func hollow_census(heights: PackedFloat32Array, water_class: PackedByteArray, n: int) -> Dictionary:
	var result: Dictionary = {"cells": 0, "most_m": 0.0, "deep_cells": 0, "volume_m": 0.0}
	var spill: PackedFloat32Array = TileRollingScript._flood(heights, water_class, n, 0.0)

	for k in range(heights.size()):
		if water_class[k] != NONE:
			continue

		var lift: float = spill[k] - heights[k]

		if lift > 0.001:
			result["cells"] += 1
			result["volume_m"] += lift
			result["most_m"] = maxf(result["most_m"], lift)

			if lift >= 2.0:
				result["deep_cells"] += 1

	return result

