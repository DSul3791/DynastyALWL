extends RefCounted

# Sullivan water, milestone M3: the terrain adapter (Sonny, 7 Nov 2026). Guide sections 4.1, 24.1 and 24.2.
#
# Reads the ground and turns it into the water grid's hydraulic geometry: each cell's bed height and the crest of each shared face. The water
# core never reads voxels itself (guide 4.1). It sees only what this adapter wrote into it.
#
# The ground comes from a SOURCE object, so the same code reads made-up ground in tests, the server's ground, or a client VoxelTool:
#   source.sdf(world: Vector3) -> float        signed distance in metres, NEGATIVE = solid (the project's convention, terrain_layout.gd)
#   source.is_loaded(world_box: AABB) -> bool   false where ground is not loaded or not editable: those columns are UNKNOWN, never air
#
# Per column (guide 24.2, the simple outdoor surface layer): scan from y_max down to y_min in steps of scan_step_m. The first air-to-solid
# crossing met is the top of the ground, refined by bisection to refine_m. If the scan then finds air again under that solid (a roof over
# a cave, a bridge over a river), the column holds more than one surface: it is STACKED, and this one-surface grid must not simulate it
# (guide 3.10, 24.1). Its faces are closed until the layered water graph exists.
#
# Face crests: the highest ground at the face's two ends and its midpoint (guide 24.2: "at both ends plus midpoint ... use the maximum").
# A berm on a face boundary raises the crest even though both cell centres stay low (test G01).
#
# Units: metres. The grid's cell (i, j) covers x in [origin.x + i*cell, origin.x + (i+1)*cell), z likewise; its centre is the sample point.

const OPEN_SURFACE := 0
const STACKED := 1
const UNKNOWN := 2

var source
var origin: Vector2              # world x, z of the grid's corner
var cell_m: float
var y_min: float = -64.0         # scan range, world metres
var y_max: float = 256.0
var scan_step_m: float = 0.25    # guide 24.2: min(voxel size, cell / 4); our voxels are 1 m and cells 2 m, so 0.5 m would do: 0.25 is safer
var refine_m: float = 0.01       # guide 24.2: refine crossings to at most 0.05 m

var classification: PackedByteArray   # per grid cell, after the last extract


func _init(p_source, p_origin: Vector2, p_cell_m: float) -> void:
	source = p_source
	origin = p_origin
	cell_m = p_cell_m


func cell_centre(i: int, j: int) -> Vector2:
	return origin + Vector2((i + 0.5) * cell_m, (j + 0.5) * cell_m)


# Cells (i0, j0) to (i1, j1) inclusive, in world space, with the scan height.
func cells_box(i0: int, j0: int, i1: int, j1: int) -> AABB:
	var a: Vector2 = origin + Vector2(i0 * cell_m, j0 * cell_m)
	var b: Vector2 = origin + Vector2((i1 + 1) * cell_m, (j1 + 1) * cell_m)
	return AABB(Vector3(a.x, y_min, a.y), Vector3(b.x - a.x, y_max - y_min, b.y - a.y))


# The ground at one world x, z: {"state": OPEN_SURFACE | STACKED | UNKNOWN, "top": metres (NAN unless OPEN_SURFACE or STACKED)}.
func column(x: float, z: float) -> Dictionary:
	var probe: AABB = AABB(Vector3(x - 0.5, y_min, z - 0.5), Vector3(1.0, y_max - y_min, 1.0))

	if not source.is_loaded(probe):
		return {"state": UNKNOWN, "top": NAN}

	var y: float = y_max
	var above: float = source.sdf(Vector3(x, y, z))

	if above <= 0.0:
		return {"state": UNKNOWN, "top": NAN}   # solid at the top of the scan: the range is wrong for this ground, never guess

	var top: float = NAN

	while y > y_min:
		var lower: float = maxf(y - scan_step_m, y_min)
		var below: float = source.sdf(Vector3(x, lower, z))

		if is_nan(top):
			if below <= 0.0:
				top = _refine(x, z, lower, y)
		elif below > 0.0:
			return {"state": STACKED, "top": top}   # air again under the first solid: a roof or a bridge

		y = lower

	if is_nan(top):
		return {"state": UNKNOWN, "top": NAN}   # no ground in the whole scan
	return {"state": OPEN_SURFACE, "top": top}


# Bisection between a solid height `lo` and an air height `hi`: the surface to within refine_m.
func _refine(x: float, z: float, lo: float, hi: float) -> float:
	while hi - lo > refine_m:
		var mid: float = 0.5 * (lo + hi)

		if source.sdf(Vector3(x, mid, z)) <= 0.0:
			lo = mid
		else:
			hi = mid

	return 0.5 * (lo + hi)


# Reads cells (i0, j0) to (i1, j1) inclusive, clamped to the grid, and every face touching them. Reads first and writes nothing unless every
# sample is known: no grid is ever left half updated (guide 24.2: "No tile is publishable with partially updated faces").
# Returns {"ok": bool, "reason": String, "cells": int, "stacked": int}.
func extract(grid, i0: int, j0: int, i1: int, j1: int) -> Dictionary:
	i0 = maxi(i0, 0)
	j0 = maxi(j0, 0)
	i1 = mini(i1, grid.w - 1)
	j1 = mini(j1, grid.h - 1)

	if classification.size() != grid.w * grid.h:
		classification.resize(grid.w * grid.h)
		classification.fill(UNKNOWN)

	var beds: Dictionary = {}     # cell index -> top
	var states: Dictionary = {}   # cell index -> state

	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var c: Vector2 = cell_centre(i, j)
			var col: Dictionary = column(c.x, c.y)

			if int(col["state"]) == UNKNOWN:
				return {"ok": false, "reason": "UNKNOWN ground at cell %d,%d" % [i, j], "cells": 0, "stacked": 0}

			beds[grid.index(i, j)] = float(col["top"])
			states[grid.index(i, j)] = int(col["state"])

	# The faces: east faces of cells i0-1 .. i1 and south faces of rows j0-1 .. j1, inside the grid.
	var crests_e: Dictionary = {}
	var crests_s: Dictionary = {}

	for j in range(j0, j1 + 1):
		for i in range(maxi(i0 - 1, 0), mini(i1, grid.w - 2) + 1):
			var x: float = origin.x + (i + 1) * cell_m
			var z0: float = origin.y + j * cell_m
			var crest: float = _face_crest([Vector2(x, z0), Vector2(x, z0 + 0.5 * cell_m), Vector2(x, z0 + cell_m)])

			if is_nan(crest):
				return {"ok": false, "reason": "UNKNOWN ground on the east face of cell %d,%d" % [i, j], "cells": 0, "stacked": 0}

			crests_e[grid.index(i, j)] = crest

	for j in range(maxi(j0 - 1, 0), mini(j1, grid.h - 2) + 1):
		for i in range(i0, i1 + 1):
			var z: float = origin.y + (j + 1) * cell_m
			var x0: float = origin.x + i * cell_m
			var crest: float = _face_crest([Vector2(x0, z), Vector2(x0 + 0.5 * cell_m, z), Vector2(x0 + cell_m, z)])

			if is_nan(crest):
				return {"ok": false, "reason": "UNKNOWN ground on the south face of cell %d,%d" % [i, j], "cells": 0, "stacked": 0}

			crests_s[grid.index(i, j)] = crest

	# Every sample is known: write. set_bed keeps each cell's volume (guide 25.2).
	var stacked: int = 0

	for k in beds:
		grid.bed[k] = beds[k]
		classification[k] = states[k]
		stacked += 1 if states[k] == STACKED else 0

	for k in crests_e:
		grid.crest_e[k] = _crest_or_wall(grid, k, k + 1, crests_e[k])

	for k in crests_s:
		grid.crest_s[k] = _crest_or_wall(grid, k, k + grid.w, crests_s[k])

	return {"ok": true, "reason": "", "cells": beds.size(), "stacked": stacked}


# The face is a wall next to a STACKED column; otherwise its crest is the sampled ground, or OPEN when that is no higher than the beds.
func _crest_or_wall(grid, a: int, b: int, crest: float) -> float:
	if classification[a] == STACKED or classification[b] == STACKED:
		return grid.WALL

	return crest if crest > maxf(grid.bed[a], grid.bed[b]) else grid.OPEN


func _face_crest(points: Array) -> float:
	var most: float = -INF

	for p in points:
		var col: Dictionary = column(p.x, p.y)

		if int(col["state"]) == UNKNOWN:
			return NAN

		most = maxf(most, float(col["top"]))
	return most
