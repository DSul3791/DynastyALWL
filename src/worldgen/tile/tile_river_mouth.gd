extends RefCounted

# River mouths (Dave 5 Nov 2026, x 52164 z 68570: "the mouth of this river looks really wrong. I would assume it should run right into the ocean and get wider
# at the shore and the ocean should overlap into the mouth"). The estuary rule was decided on 20 Oct 2026 (tile_rules water.estuary_*: "a river that ends in the
# sea gets an estuary ... the sea comes up the channel and the water meets it at one level") but only the old river loop in tile_water.gd carved it; the
# drainage rivers ran to the beach as a narrow ditch with a sand bar across. This pass carves it on the final ground: over the last estuary_m of every river
# that reaches the sea the bed sinks to estuary_depth_m under sea level (a submerged bar at estuary_bar_at_m, bed estuary_bar_bed_m), the channel widens to
# estuary_widen times at the shore, the banks rise gently (estuary_bank), and every cell carved under sea level and joined to the sea becomes sea.
# A river that meets the sea from ground higher than estuary_max_bed_m (over a cliff) is not drowned.

const PondLevel := preload("res://src/worldgen/tile/tile_pond_level.gd")

const OCEAN := 1
const LAKE := 2
const RIVER := 3
const RADIUS_M := 12.0          # half the width of the drainage's narrowest river; the estuary widens this
const RIM_M := 0.2              # the channel's rim at the shore stands this much over the sea
const BANK_REACH_M := 30.0      # how far out the gentle banks reach
const NEAR_SEA := 2             # river cells this many cells from the sea are mouths


# Returns {"mouths": river cells at the sea, "cells": cells carved, "sea": cells made sea}.
static func carve(heights: PackedFloat32Array, water_class: PackedByteArray, water_surface: PackedFloat32Array, n: int, cell_m: float, rules: Dictionary) -> Dictionary:
	var estuary_m: float = float(rules.get("estuary_m", 300.0))
	var depth_m: float = float(rules.get("estuary_depth_m", 2.5))
	var bar_bed: float = float(rules.get("estuary_bar_bed_m", -0.6))
	var bar_at: float = float(rules.get("estuary_bar_at_m", 60.0))
	var bar_half: float = maxf(float(rules.get("estuary_bar_half_m", 30.0)), 1.0)
	var bank: float = float(rules.get("estuary_bank", 0.125))
	var widen: float = float(rules.get("estuary_widen", 2.5))
	var max_bed: float = float(rules.get("estuary_max_bed_m", 4.0))

	# Distance up the river from the sea: a flood along river and lake cells from the river cells that touch the sea.
	var to_sea: PackedFloat32Array = PackedFloat32Array()
	to_sea.resize(n * n)
	to_sea.fill(INF)
	var keys: PackedFloat32Array = PackedFloat32Array()
	var nodes: PackedInt32Array = PackedInt32Array()
	var mouths: int = 0

	for k in range(n * n):
		if water_class[k] != RIVER or not _near_sea(water_class, n, k):
			continue

		to_sea[k] = 0.0
		PondLevel._push(keys, nodes, 0.0, k)
		mouths += 1

	while not keys.is_empty():
		var popped: Vector2 = PondLevel._pop(keys, nodes)
		var k: int = int(popped.y)

		if popped.x > to_sea[k] or popped.x >= estuary_m:
			continue

		var column: int = k % n

		for dz in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if (dx == 0 and dz == 0) or column + dx < 0 or column + dx >= n:
					continue

				var m: int = k + dz * n + dx

				if m < 0 or m >= n * n or (water_class[m] != RIVER and water_class[m] != LAKE):
					continue

				var d: float = popped.x + cell_m * (1.41421356 if dx != 0 and dz != 0 else 1.0)

				if d < to_sea[m]:
					to_sea[m] = d
					PondLevel._push(keys, nodes, d, m)

	# The carve, from the original ground so overlapping sections do not dig each other deeper.
	var ground: PackedFloat32Array = heights.duplicate()
	var cut: PackedByteArray = PackedByteArray()
	cut.resize(n * n)
	var carved: int = 0

	for k in range(n * n):
		if to_sea[k] >= estuary_m:
			continue

		var share: float = 1.0 - to_sea[k] / estuary_m
		share *= clampf(1.0 - (ground[k] - max_bed) / 6.0, 0.0, 1.0)

		if share <= 0.0:
			continue

		var bar: float = maxf(1.0 - absf(to_sea[k] - bar_at) / bar_half, 0.0)
		var sunk: float = lerpf(-depth_m, bar_bed, bar)
		var centre: float = minf(ground[k], lerpf(ground[k], sunk, share))
		var rim: float = minf(ground[k], lerpf(ground[k], RIM_M, share))
		var radius: float = RADIUS_M * lerpf(1.0, widen, share)
		var reach: int = int(ceil((radius + BANK_REACH_M) / cell_m))
		var row: int = k / n
		var column: int = k % n

		for dz in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var r: int = row + dz
				var c: int = column + dx

				if r < 0 or r >= n or c < 0 or c >= n:
					continue

				var m: int = r * n + c

				if water_class[m] == OCEAN:
					continue

				var d: float = sqrt(float(dx * dx + dz * dz)) * cell_m
				var target: float

				if d <= radius:
					target = lerpf(centre, rim, pow(d / radius, 2.0))
				else:
					target = rim + (d - radius) * bank

				if target < heights[m]:
					heights[m] = target

					if cut[m] == 0:
						cut[m] = 1
						carved += 1

	# The sea comes up the mouth: every cell under sea level joined to the sea (through such cells) is sea.
	var front: PackedInt32Array = PackedInt32Array()

	for k in range(n * n):
		if water_class[k] == OCEAN:
			front.append(k)

	var made_sea: int = 0
	var at: int = 0

	while at < front.size():
		var k: int = front[at]
		at += 1
		var column: int = k % n

		for step in [1, -1, n, -n]:
			var m: int = k + step

			if m < 0 or m >= n * n or (step == 1 and column == n - 1) or (step == -1 and column == 0):
				continue

			if water_class[m] != OCEAN and heights[m] < 0.0 and (cut[m] == 1 or to_sea[m] < INF):
				water_class[m] = OCEAN
				water_surface[m] = 0.0
				front.append(m)
				made_sea += 1

	# River water in the estuary meets the sea at one level: no surface below the sea, and none standing far over a bed sunk towards it.
	for k in range(n * n):
		if water_class[k] == RIVER and to_sea[k] < estuary_m and not is_nan(water_surface[k]):
			water_surface[k] = maxf(minf(water_surface[k], maxf(heights[k] + 1.0, 0.0)), 0.0)

	return {"mouths": mouths, "cells": carved, "sea": made_sea}


# Within NEAR_SEA cells of the sea: a river that stops behind a one-cell sand bar is a mouth too (the carve opens the bar).
static func _near_sea(water_class: PackedByteArray, n: int, k: int) -> bool:
	var column: int = k % n

	for dz in range(-NEAR_SEA, NEAR_SEA + 1):
		for dx in range(-NEAR_SEA, NEAR_SEA + 1):
			if column + dx < 0 or column + dx >= n:
				continue

			var m: int = k + dz * n + dx

			if m >= 0 and m < n * n and water_class[m] == OCEAN:
				return true

	return false
