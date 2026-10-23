class_name DrainageFill
extends RefCounted

# Option B stage 1 (tech/TERRAIN_B_DESIGN.md): every natural depression becomes a lake.
# Priority flood (Barnes 2014) raises each pit to the level of its lowest rim; the lowest rim
# cell is the lake's outlet, where a river must start. Works on any square height grid.
#   `filled`    ground raised to the level water would stand at
#   `lake_id`   0 = not a lake, else 1..lake_count (cells deeper than `min_depth_m`)
#   `lakes`     one entry per lake: level, depth (deepest), cells, outlet (index of the lowest rim cell)

const WATER_EPSILON_M := 0.001
const LEVEL_TOLERANCE_M := 0.02
const LEVEL_SET_MAX_CELLS := 4000
const BUCKETS_PER_M := 100.0   # flood order is exact to a centimetre

var size: int = 0
var filled: PackedFloat32Array = PackedFloat32Array()
var lake_id: PackedInt32Array = PackedInt32Array()
var lakes: Array = []
var _parent: PackedInt32Array = PackedInt32Array()   # cell the flood came from, -1 at seeds
var receiver: PackedInt32Array = PackedInt32Array()  # where water on this cell goes next (-1 at the sea or tile edge)
var order: PackedInt32Array = PackedInt32Array()     # cells in flood order: receivers come before the cells that drain into them


func build(h: PackedFloat32Array, sea: PackedByteArray, grid: int, min_depth_m: float) -> void:
	size = grid
	var total: int = size * size
	filled = h.duplicate()
	lake_id.resize(total)
	lake_id.fill(0)
	_parent.resize(total)
	_parent.fill(-1)
	order.clear()
	lakes.clear()
	_flood(h, sea)
	_route(h, sea)
	_label(h, sea, min_depth_m)


# Bucket queue keyed by height in centimetres; heights only rise along the flood so one pass suffices.
func _flood(h: PackedFloat32Array, sea: PackedByteArray) -> void:
	var total: int = size * size
	var high: int = 1

	for value in h:
		high = maxi(high, int(value * BUCKETS_PER_M) + 2)

	var head: PackedInt32Array = PackedInt32Array()
	head.resize(high + 2)
	head.fill(-1)
	var next: PackedInt32Array = PackedInt32Array()
	next.resize(total)
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(total)

	for index in range(total):
		@warning_ignore("integer_division")
		var row: int = index / size
		var column: int = index % size
		var edge: bool = row == 0 or column == 0 or row == size - 1 or column == size - 1
		var shore: bool = sea[index] == 1

		if not shore and not edge:
			for step in [-1, 1, -size, size]:
				if sea[index + step] == 1:
					shore = true
					break

		if shore or edge:
			seen[index] = 1
			var q: int = clampi(int(h[index] * BUCKETS_PER_M), 0, high)
			next[index] = head[q]
			head[q] = index

	for slot in range(head.size()):
		while head[slot] != -1:
			var index: int = head[slot]
			head[slot] = next[index]
			order.append(index)
			@warning_ignore("integer_division")
			var row: int = index / size
			var column: int = index % size

			for dz in range(-1, 2):
				var nr: int = row + dz

				if nr < 0 or nr >= size:
					continue

				for dc in range(-1, 2):
					var nc: int = column + dc

					if (dc == 0 and dz == 0) or nc < 0 or nc >= size:
						continue

					var neighbor: int = nr * size + nc

					if seen[neighbor] == 1:
						continue

					seen[neighbor] = 1
					filled[neighbor] = maxf(h[neighbor], filled[index])
					_parent[neighbor] = index
					var q: int = maxi(clampi(int(filled[neighbor] * BUCKETS_PER_M), 0, high + 1), slot)
					next[neighbor] = head[q]
					head[q] = neighbor


# Flow directions. Inside a lake (filled above ground) water follows the flood parent toward the outlet; on
# land it takes the steepest drop on the filled surface, so slopes drain the way they lean. Only flat
# ground with no lower neighbour falls back to the flood parent. Then `order` is rebuilt (receivers first).
func _route(h: PackedFloat32Array, sea: PackedByteArray) -> void:
	var total: int = size * size
	receiver = _parent.duplicate()
	var indegree: PackedInt32Array = PackedInt32Array()
	indegree.resize(total)

	for index in range(total):
		if sea[index] == 1 or filled[index] - h[index] > WATER_EPSILON_M:
			continue

		@warning_ignore("integer_division")
		var row: int = index / size
		var column: int = index % size
		var best: int = -1
		var best_slope: float = 0.0

		for dz in range(-1, 2):
			var nr: int = row + dz

			if nr < 0 or nr >= size:
				continue

			for dc in range(-1, 2):
				var nc: int = column + dc

				if (dc == 0 and dz == 0) or nc < 0 or nc >= size:
					continue

				var neighbor: int = nr * size + nc
				var drop: float = filled[index] - filled[neighbor]

				if dc != 0 and dz != 0:
					drop /= 1.4142

				if drop > best_slope + 1.0e-5:
					best_slope = drop
					best = neighbor

		if best >= 0:
			receiver[index] = best

	for index in range(total):
		if receiver[index] >= 0:
			indegree[receiver[index]] += 1

	var queue: PackedInt32Array = PackedInt32Array()

	for index in range(total):
		if indegree[index] == 0:
			queue.append(index)

	var head: int = 0

	while head < queue.size():
		var index: int = queue[head]
		head += 1

		if receiver[index] >= 0:
			indegree[receiver[index]] -= 1

			if indegree[receiver[index]] == 0:
				queue.append(receiver[index])

	queue.reverse()
	order = queue


# Group water cells (filled above ground) into lakes (8-neighbour, same level). A lake counts when
# its deepest cell passes `min_depth_m`. Its outlet is the cell the flood entered through: the lowest
# cell at the lake's level (in the lake or on its rim) whose flood parent stands lower than the lake.
func _label(h: PackedFloat32Array, sea: PackedByteArray, min_depth_m: float) -> void:
	var total: int = size * size
	var stack: PackedInt32Array = PackedInt32Array()
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(total)

	for start in range(total):
		if seen[start] == 1 or sea[start] == 1 or filled[start] - h[start] < WATER_EPSILON_M:
			continue

		var members: PackedInt32Array = PackedInt32Array()
		var level: float = filled[start]
		var deepest: float = 0.0
		seen[start] = 1
		stack.append(start)

		while not stack.is_empty():
			var index: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			members.append(index)
			deepest = maxf(deepest, filled[index] - h[index])
			@warning_ignore("integer_division")
			var row: int = index / size
			var column: int = index % size

			for dz in range(-1, 2):
				var nr: int = row + dz

				if nr < 0 or nr >= size:
					continue

				for dc in range(-1, 2):
					var nc: int = column + dc

					if (dc == 0 and dz == 0) or nc < 0 or nc >= size:
						continue

					var neighbor: int = nr * size + nc

					if seen[neighbor] == 0 and sea[neighbor] == 0 and absf(filled[neighbor] - level) < 0.02 and filled[neighbor] - h[neighbor] >= WATER_EPSILON_M:
						seen[neighbor] = 1
						stack.append(neighbor)

		if deepest < min_depth_m:
			continue

		var id: int = lakes.size() + 1
		var deepest_cell: int = members[0]

		for index in members:
			lake_id[index] = id

			if filled[index] - h[index] > filled[deepest_cell] - h[deepest_cell]:
				deepest_cell = index

		var outlet: int = _find_outlet(members, deepest_cell, level, h, sea)
		lakes.append({"level": level, "depth": deepest, "cells": members.size(), "outlet": outlet})


# The spill point: walk the level set (cells standing at the lake's level, water or bare rim) from the
# lake outward and take the lowest cell beside ground that stands lower than the lake (the way the
# flood left). Ties go to the one nearest the deepest water. -1 only when the lake has no lower side.
func _find_outlet(members: PackedInt32Array, deepest_cell: int, level: float, h: PackedFloat32Array, sea: PackedByteArray) -> int:
	var queue: PackedInt32Array = members.duplicate()
	var reached: Dictionary = {}

	for index in members:
		reached[index] = true

	var best: int = -1
	var best_height: float = INF
	var best_distance: float = INF
	var head: int = 0
	@warning_ignore("integer_division")
	var anchor_row: int = deepest_cell / size
	var anchor_column: int = deepest_cell % size

	while head < queue.size() and queue.size() < LEVEL_SET_MAX_CELLS:
		var index: int = queue[head]
		head += 1
		@warning_ignore("integer_division")
		var row: int = index / size
		var column: int = index % size
		var lower_side: bool = false

		for dz in range(-1, 2):
			var nr: int = row + dz

			if nr < 0 or nr >= size:
				continue

			for dc in range(-1, 2):
				var nc: int = column + dc

				if (dc == 0 and dz == 0) or nc < 0 or nc >= size:
					continue

				var neighbor: int = nr * size + nc

				if sea[neighbor] == 1 or filled[neighbor] < level - LEVEL_TOLERANCE_M:
					lower_side = true
				elif absf(filled[neighbor] - level) <= LEVEL_TOLERANCE_M and not reached.has(neighbor):
					reached[neighbor] = true
					queue.append(neighbor)

		if lower_side and lake_id[index] == 0 or lower_side and h[index] >= level - LEVEL_TOLERANCE_M:
			var distance: float = pow(float(row - anchor_row), 2.0) + pow(float(column - anchor_column), 2.0)

			if h[index] < best_height - LEVEL_TOLERANCE_M or (absf(h[index] - best_height) <= LEVEL_TOLERANCE_M and distance < best_distance):
				best = index
				best_height = h[index]
				best_distance = distance

	return best
