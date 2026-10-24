extends RefCounted

# Natural hollows in the baked ground (priority flood): the level water would fill each hollow to before it spills. Used by the basin census
# tool and by the settler's hollow springs (v7). Ground is sampled every `step`th cell to keep it quick (a tile takes about 6 s at step 2).


# [{cell: full-resolution index of the deepest cell, area_m2, depth_m (deepest), volume_m3, spill_m (level), cells: coarse indices}] for every
# joined group of cells whose fill is min_depth_m or more above the ground, whatever its size. `side` of the coarse grid = samples / step.
static func find(data, step: int, min_depth_m: float) -> Array:
	var full: int = data.samples
	@warning_ignore("integer_division")
	var side: int = full / step
	var cell_m2: float = pow(data.spacing_m * float(step), 2.0)
	var ground: PackedFloat32Array = PackedFloat32Array()
	ground.resize(side * side)

	for j in range(side):
		for i in range(side):
			ground[j * side + i] = data.heights[j * step * full + i * step]

	var filled: PackedFloat32Array = ground.duplicate()
	var closed: PackedByteArray = PackedByteArray()
	closed.resize(side * side)
	var heap_key: PackedFloat32Array = PackedFloat32Array()
	var heap_idx: PackedInt32Array = PackedInt32Array()

	for j in range(side):
		for i in range(side):
			var k: int = j * side + i

			if ground[k] <= 0.0 or i == 0 or j == 0 or i == side - 1 or j == side - 1:
				closed[k] = 1
				_push(heap_key, heap_idx, ground[k], k)

	while not heap_idx.is_empty():
		var top: Array = _pop(heap_key, heap_idx)
		var level: float = top[0]
		var k: int = top[1]
		var ki: int = k % side
		@warning_ignore("integer_division")
		var kj: int = k / side

		for n in [k - 1 if ki > 0 else -1, k + 1 if ki < side - 1 else -1, k - side if kj > 0 else -1, k + side if kj < side - 1 else -1]:
			if n < 0 or closed[n] != 0:
				continue

			closed[n] = 1
			filled[n] = maxf(ground[n], level)
			_push(heap_key, heap_idx, filled[n], n)

	var label: PackedByteArray = PackedByteArray()
	label.resize(side * side)
	var out: Array = []

	for start in range(side * side):
		if label[start] != 0 or filled[start] - ground[start] < min_depth_m:
			continue

		var queue: PackedInt32Array = PackedInt32Array([start])
		var cells: PackedInt32Array = PackedInt32Array()
		label[start] = 1
		var max_depth: float = 0.0
		var volume: float = 0.0
		var deepest: int = start

		while not queue.is_empty():
			var k: int = queue[queue.size() - 1]
			queue.resize(queue.size() - 1)
			cells.append(k)
			var d: float = filled[k] - ground[k]
			volume += d * cell_m2

			if d > max_depth:
				max_depth = d
				deepest = k

			var ki: int = k % side
			@warning_ignore("integer_division")
			var kj: int = k / side

			for n in [k - 1 if ki > 0 else -1, k + 1 if ki < side - 1 else -1, k - side if kj > 0 else -1, k + side if kj < side - 1 else -1]:
				if n >= 0 and label[n] == 0 and filled[n] - ground[n] >= min_depth_m:
					label[n] = 1
					queue.append(n)

		@warning_ignore("integer_division")
		out.append({"cell": (deepest / side) * step * full + (deepest % side) * step, "area_m2": float(cells.size()) * cell_m2, "depth_m": max_depth, "volume_m3": volume, "spill_m": filled[start], "cells": cells, "side": side})

	return out


static func _push(keys: PackedFloat32Array, idx: PackedInt32Array, key: float, value: int) -> void:
	keys.append(key)
	idx.append(value)
	var c: int = keys.size() - 1

	while c > 0:
		@warning_ignore("integer_division")
		var p: int = (c - 1) / 2

		if keys[p] <= keys[c]:
			break

		var tk: float = keys[p]
		keys[p] = keys[c]
		keys[c] = tk
		var tv: int = idx[p]
		idx[p] = idx[c]
		idx[c] = tv
		c = p


static func _pop(keys: PackedFloat32Array, idx: PackedInt32Array) -> Array:
	var result: Array = [keys[0], idx[0]]
	var last: int = keys.size() - 1
	keys[0] = keys[last]
	idx[0] = idx[last]
	keys.resize(last)
	idx.resize(last)
	var c: int = 0

	while true:
		var l: int = c * 2 + 1
		var r: int = l + 1
		var m: int = c

		if l < last and keys[l] < keys[m]:
			m = l

		if r < last and keys[r] < keys[m]:
			m = r

		if m == c:
			break

		var tk: float = keys[m]
		keys[m] = keys[c]
		keys[c] = tk
		var tv: int = idx[m]
		idx[m] = idx[c]
		idx[c] = tv
		c = m

	return result
