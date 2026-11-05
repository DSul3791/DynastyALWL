extends RefCounted

# Rivers that run out (Dave 4 Nov 2026, x 57835 z 70585: "the river just runs out. no more riverbed. that aint right"). Rivers are routed over the ground as
# it was before the ledges and scree went on, so a river can meet a hollow in that old ground that the drainage paints as a lake. On the final ground the
# hollow is a ridge: tile_pond_level lowers the lake to its real spill, the lake cells above it turn dry, and the river stops dead at the ridge with dry ground
# below it (tile 3,4 had 34 such pieces, 7042 water cells, cut off from the sea). Water does not stop in the middle of a hillside, so this pass digs each one
# on: for every piece of water with a river in it that reaches neither the sea nor the edge of the frame, a priority flood from the piece finds the lowest way
# out (as water would) to lower water, and a channel is cut along it, its level falling the whole way, with sloping banks.

const PondLevel := preload("res://src/worldgen/tile/tile_pond_level.gd")

const OCEAN := 1
const LAKE := 2
const RIVER := 3
const MIN_RIVER_CELLS := 20       # a piece with fewer river cells is a puddle, left alone
const MAX_VISIT := 300000         # cells one flood may look at before it gives up
const RADIUS_M := 12.0            # half the channel's width (the drainage's narrowest river is 24 m)
const DEPTH_M := 1.2              # the channel's depth under its water at the centre line
const BANK_SLOPE := 0.5           # rise per metre of the cut's banks
const BANK_REACH_M := 24.0        # how far out the banks reach
const FALL_M := 0.02              # the least fall per cell along the cut


# Returns {"pieces": landlocked pieces found, "mended": pieces dug through, "cells": cells made wet}.
static func mend(heights: PackedFloat32Array, water_class: PackedByteArray, water_surface: PackedFloat32Array, n: int, cell_m: float) -> Dictionary:
	var piece_of: PackedInt32Array = PackedInt32Array()
	piece_of.resize(n * n)
	piece_of.fill(-1)
	var pieces: Array = []   # [cells PackedInt32Array, open bool, river cells int]

	# Pieces of water, 8-connected; a piece is open when it touches the sea or the frame edge.
	for start in range(n * n):
		if water_class[start] == 0 or piece_of[start] >= 0:
			continue

		var id: int = pieces.size()
		var cells: PackedInt32Array = PackedInt32Array([start])
		piece_of[start] = id
		var open: bool = false
		var rivers: int = 0
		var at: int = 0

		while at < cells.size():
			var k: int = cells[at]
			at += 1
			var column: int = k % n

			if water_class[k] == OCEAN or column == 0 or column == n - 1 or k < n or k >= n * (n - 1):
				open = true

			if water_class[k] == RIVER:
				rivers += 1

			for dz in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if (dx == 0 and dz == 0) or column + dx < 0 or column + dx >= n:
						continue

					var m: int = k + dz * n + dx

					if m >= 0 and m < n * n and water_class[m] != 0 and piece_of[m] < 0:
						piece_of[m] = id
						cells.append(m)

		pieces.append([cells, open, rivers])

	var landlocked: int = 0
	var mended: int = 0
	var wet: int = 0

	# Highest pieces first, so a piece dug into a lower landlocked piece is carried on when that one is dug.
	var order: Array = []

	for id in range(pieces.size()):
		if not bool(pieces[id][1]) and int(pieces[id][2]) >= MIN_RIVER_CELLS:
			order.append(id)

	order.sort_custom(func(a: int, b: int) -> bool: return _lowest(heights, pieces[a][0]) > _lowest(heights, pieces[b][0]))

	for id in order:
		landlocked += 1
		var path: PackedInt32Array = _way_out(heights, water_class, piece_of, n, pieces[id][0], id)

		if path.size() < 2:
			continue

		mended += 1
		wet += _cut(heights, water_class, water_surface, n, cell_m, path)

	return {"pieces": landlocked, "mended": mended, "cells": wet}


static func _lowest(heights: PackedFloat32Array, cells: PackedInt32Array) -> float:
	var low: float = INF

	for k in cells:
		low = minf(low, heights[k])

	return low


# Priority flood from the piece, lowest ground first; the first cell of other water lying below the piece's lowest ground (or the sea, or the frame edge) ends
# it. Returns the path from the piece's cell it started at to that cell, or an empty array when the flood gives up.
static func _way_out(heights: PackedFloat32Array, water_class: PackedByteArray, piece_of: PackedInt32Array, n: int, cells: PackedInt32Array, id: int) -> PackedInt32Array:
	var keys: PackedFloat32Array = PackedFloat32Array()
	var nodes: PackedInt32Array = PackedInt32Array()
	var came: Dictionary = {}
	var floor_m: float = _lowest(heights, cells)

	for k in cells:
		came[k] = -1
		PondLevel._push(keys, nodes, heights[k], k)

	while not keys.is_empty() and came.size() < MAX_VISIT:
		var k: int = int(PondLevel._pop(keys, nodes).y)
		var column: int = k % n
		var edge: bool = column == 0 or column == n - 1 or k < n or k >= n * (n - 1)

		if piece_of[k] != id and (edge or water_class[k] == OCEAN or (water_class[k] != 0 and heights[k] < floor_m - 0.5)):
			var path: PackedInt32Array = PackedInt32Array()
			var walker: int = k

			while walker >= 0:
				path.append(walker)
				walker = int(came[walker])

			path.reverse()
			return path

		if edge:
			continue

		for step in [1, -1, n, -n, n + 1, n - 1, -n + 1, -n - 1]:
			var m: int = k + step

			if not came.has(m) and absi(m % n - column) <= 1:
				came[m] = k
				PondLevel._push(keys, nodes, heights[m], m)

	return PackedInt32Array()


# Cuts a channel along `path` (from inside the piece to the water it reaches): the water level falls from the start's ground to the end's, never rising, a
# parabolic section RADIUS_M wide either side and DEPTH_M deep under it, banks rising BANK_SLOPE out to BANK_REACH_M. Cells under the level become river.
static func _cut(heights: PackedFloat32Array, water_class: PackedByteArray, water_surface: PackedFloat32Array, n: int, cell_m: float, path: PackedInt32Array) -> int:
	var count: int = path.size()
	var start: float = heights[path[0]]
	var finish: float = minf(heights[path[count - 1]], start - FALL_M * float(count))
	var level: PackedFloat32Array = PackedFloat32Array()
	level.resize(count)
	var running: float = start

	for k in range(count):
		var line: float = lerpf(start, finish, float(k) / float(maxi(count - 1, 1)))
		running = minf(running - (FALL_M if k > 0 else 0.0), minf(line, heights[path[k]]))
		level[k] = running

	var reach: int = int(ceil((RADIUS_M + BANK_REACH_M) / cell_m))
	var made: int = 0

	for k in range(count):
		var centre: int = path[k]
		var row: int = centre / n
		var column: int = centre % n

		for dz in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var r: int = row + dz
				var c: int = column + dx

				if r < 0 or r >= n or c < 0 or c >= n:
					continue

				var m: int = r * n + c
				var d: float = sqrt(float(dx * dx + dz * dz)) * cell_m
				var target: float

				if d <= RADIUS_M:
					target = level[k] - DEPTH_M * (1.0 - pow(d / RADIUS_M, 2.0))
				else:
					target = level[k] + (d - RADIUS_M) * BANK_SLOPE

				if water_class[m] == OCEAN:
					continue

				heights[m] = minf(heights[m], target)

				if d <= RADIUS_M and heights[m] < level[k] - 0.05 and water_class[m] == 0:
					water_class[m] = RIVER
					water_surface[m] = level[k]
					made += 1
				elif d <= RADIUS_M and water_class[m] == RIVER and (is_nan(water_surface[m]) or water_surface[m] < level[k]):
					water_surface[m] = level[k]

	return made
