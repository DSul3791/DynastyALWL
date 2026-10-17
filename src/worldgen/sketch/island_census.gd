class_name IslandCensus
extends RefCounted

# Finds every separate island in the world elevation map (connected land
# cells, wrapping at the world edges) and reports their sizes.

const CLASS_LIMITS := [
	[1.0, "islet"], [5.0, "small"], [15.0, "medium"],
	[30.0, "large"], [60.0, "great"], [INF, "colossal"],
]

# Returns {"islands": [{area_km2, cells, peak_m, peak_index, owner}],
#          "label": PackedInt32Array (island number per cell, -1 = sea)}
static func count(elevation) -> Dictionary:
	var size_x: int = elevation.size_x
	var size_z: int = elevation.size_z
	var total: int = size_x * size_z
	var label: PackedInt32Array = PackedInt32Array()
	label.resize(total)
	label.fill(-1)
	var cell_km2: float = pow(elevation.cell_m / 1000.0, 2.0)
	var islands: Array = []
	var stack: PackedInt32Array = PackedInt32Array()

	for start in range(total):
		if label[start] != -1 or elevation.heights[start] <= 0.0:
			continue

		var number: int = islands.size()
		var cells: int = 0
		var peak: float = -INF
		var peak_index: int = start
		label[start] = number
		stack.append(start)

		while not stack.is_empty():
			var index: int = stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			cells += 1
			var h: float = elevation.heights[index]

			if h > peak:
				peak = h
				peak_index = index

			var row: int = index / size_x
			var column: int = index % size_x

			for neighbor in [
				elevation.index_of(column + 1, row), elevation.index_of(column - 1, row),
				elevation.index_of(column, row + 1), elevation.index_of(column, row - 1),
			]:
				if label[neighbor] == -1 and elevation.heights[neighbor] > 0.0:
					label[neighbor] = number
					stack.append(neighbor)

		islands.append({
			"area_km2": float(cells) * cell_km2,
			"cells": cells,
			"peak_m": peak,
			"peak_index": peak_index,
			"owner": elevation.owners[peak_index],
		})

	return {"islands": islands, "label": label}


static func size_class(area_km2: float) -> String:
	for limit in CLASS_LIMITS:
		if area_km2 < float(limit[0]):
			return str(limit[1])

	return "colossal"
