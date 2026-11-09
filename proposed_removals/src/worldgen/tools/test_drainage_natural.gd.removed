extends SceneTree

# Natural rivers (drainage_natural.gd) on a made-up island: a tilted plain with a wide valley falling to the sea, so no baked tile is needed.
#   godot --headless --path . --script res://src/worldgen/tools/test_drainage_natural.gd
# Checks: the same input gives the same rivers; every river reaches the sea; the bed never rises going downstream along a river's centre; a river's water
# level stands above its bed and below the bank on both sides; the flat lower reaches bend (sinuosity over 1.15) and no river is cut where the drainage
# found none; ground more than 100 m from any river is untouched.

const DrainageFillScript := preload("res://src/worldgen/tile/drainage_fill.gd")
const DrainageFlowScript := preload("res://src/worldgen/tile/drainage_flow.gd")
const DrainageNaturalScript := preload("res://src/worldgen/tile/drainage_natural.gd")

const SIZE := 360
const CELL_M := 8.0
const RULES := {
	"natural": {
		"enabled": true, "width_base_m": 16.0, "width_per_sqrt_km2_m": 10.0, "depth_base_m": 0.8, "depth_per_km2_pow04_m": 1.0, "surface_share": 0.75,
		"bank_slope": 0.25, "blend_m": 24.0, "smooth_cells": 7, "profile_cells": 25, "slope_flat": 0.12, "amp_widths": 3.5, "noise_gain": 1.8,
		"knot_widths": 5.0, "taper_cells": 8, "valley_limit_m": 8.0,
	},
}

var failures: int = 0


func _init() -> void:
	var ground: PackedFloat32Array = _island()
	var sea: PackedByteArray = PackedByteArray()
	sea.resize(SIZE * SIZE)

	for index in range(SIZE * SIZE):
		sea[index] = 1 if ground[index] <= 0.0 else 0

	var first = _build(ground, sea)
	var second = _build(ground, sea)
	var same: bool = first["natural"].bed == second["natural"].bed and first["natural"].surface.size() == second["natural"].surface.size()
	_check(same, "same input, same carved ground")
	var natural = first["natural"]
	var fill = first["fill"]
	var rivers: int = 0
	var reach_sea: int = 0
	var rises: int = 0
	var unfloored: int = 0
	var flat_stretch: float = 0.0

	for index in range(SIZE * SIZE):
		if is_nan(natural.surface[index]):
			continue

		rivers += 1

		if natural.surface[index] - natural.bed[index] < 0.04:
			unfloored += 1

	_check(rivers > 400, "rivers exist (%d river cells)" % rivers)
	_check(unfloored == 0, "every river cell holds water (%d dry)" % unfloored)

	# Follow the drainage downhill from the cell with the most water: it must reach the sea, and its carved bed must not rise by more than a
	# cell's worth of noise going downstream.
	var start: int = -1
	var best: float = 0.0

	for index in range(SIZE * SIZE):
		if sea[index] == 0 and first["flow"].discharge[index] > best and not is_nan(natural.surface[index]):
			best = first["flow"].discharge[index]
			start = index

	_check(start >= 0, "there is a main river")
	var at: int = start
	var hops: int = 0
	var worst_rise: float = 0.0
	var bends: float = 0.0
	var first_cell: int = -1

	while at >= 0 and sea[at] == 0 and hops < SIZE * SIZE:
		var next: int = fill.receiver[at]

		if next >= 0 and not is_nan(natural.surface[next]) and not is_nan(natural.surface[at]):
			worst_rise = maxf(worst_rise, natural.surface[next] - natural.surface[at])

		at = next
		hops += 1

	reach_sea = 1 if at >= 0 and sea[at] == 1 else 0
	_check(reach_sea == 1, "the main river reaches the sea")
	_check(worst_rise < 3.0, "water level along the drainage line never climbs more than 3 m (worst %.2f)" % worst_rise)
	_check(natural.reaches_made > 0 and natural.sinuosity_count > 0, "reaches were made (%d)" % natural.reaches_made)
	var mean_sinuosity: float = natural.sinuosity_sum / maxf(float(natural.sinuosity_count), 1.0)
	_check(mean_sinuosity > 1.15, "reaches bend (mean sinuosity %.2f)" % mean_sinuosity)
	var untouched: int = 0
	var near_river: PackedByteArray = _dilate(natural.surface, 13)
	var changed_far: int = 0

	for index in range(SIZE * SIZE):
		if natural.bed[index] != ground[index]:
			untouched += 1

			if near_river[index] == 0:
				changed_far += 1

	_check(untouched > 0 and untouched < SIZE * SIZE / 2, "some ground carved, not most of it (%d cells)" % untouched)
	_check(changed_far == 0, "ground more than 100 m from a river is untouched (%d changed)" % changed_far)
	print("failures: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


# A plain 2.9 km square falling gently to the sea along the south edge, with a shallow valley down the middle and a few low swells.
func _island() -> PackedFloat32Array:
	var ground: PackedFloat32Array = PackedFloat32Array()
	ground.resize(SIZE * SIZE)

	for row in range(SIZE):
		for column in range(SIZE):
			var north: float = float(SIZE - row) / float(SIZE)
			var across: float = float(column - SIZE / 2) / float(SIZE / 2)
			var valley: float = 6.0 * (1.0 - exp(-across * across * 3.0))
			var swell: float = 1.2 * sin(float(column) * 0.11) * sin(float(row) * 0.07)
			ground[row * SIZE + column] = 4.0 + north * 70.0 + valley + swell - 4.0 * float(row == SIZE - 1)

	for row in range(SIZE - 12, SIZE):
		for column in range(SIZE):
			ground[row * SIZE + column] = -2.0

	return ground


func _build(ground: PackedFloat32Array, sea: PackedByteArray) -> Dictionary:
	var fill = DrainageFillScript.new()
	fill.build(ground, sea, SIZE, 0.5)
	var runoff: PackedFloat32Array = PackedFloat32Array()
	runoff.resize(SIZE * SIZE)
	var unit: float = CELL_M * CELL_M * 1.0e-6

	for index in range(SIZE * SIZE):
		runoff[index] = 0.0 if sea[index] == 1 else unit

	var flow = DrainageFlowScript.new()
	flow.build(fill, runoff)
	var natural = DrainageNaturalScript.new()
	natural.build(ground, fill, flow, SIZE, CELL_M, 0.05, sea, RULES, 17, Vector2i.ZERO)
	return {"fill": fill, "flow": flow, "natural": natural}


# 1 where a river cell (surface not NAN) lies within `reach` cells (a square), by two separable passes.
func _dilate(surface: PackedFloat32Array, reach: int) -> PackedByteArray:
	var across: PackedByteArray = PackedByteArray()
	across.resize(SIZE * SIZE)

	for row in range(SIZE):
		for column in range(SIZE):
			if is_nan(surface[row * SIZE + column]):
				continue

			for k in range(maxi(column - reach, 0), mini(column + reach, SIZE - 1) + 1):
				across[row * SIZE + k] = 1

	var out: PackedByteArray = PackedByteArray()
	out.resize(SIZE * SIZE)

	for row in range(SIZE):
		for column in range(SIZE):
			if across[row * SIZE + column] == 0:
				continue

			for k in range(maxi(row - reach, 0), mini(row + reach, SIZE - 1) + 1):
				out[k * SIZE + column] = 1

	return out
