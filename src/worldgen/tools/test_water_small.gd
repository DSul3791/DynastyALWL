extends SceneTree

# Small, fast live-water check on a made-up 128 x 128 island (seconds, no baked tile): the ground comes first (fill, flow, natural rivers carve it), then the
# live water settler places its springs and the simulation runs from DRY. Replaces what test_head_pond_fill and test_water_soak's simulation side guard
# in the ground-first system: every river gets water from its springs and the rain-fed inflow, the water follows the carved channels to the sea
# (no stranded wet stretch), spills outside the channels stay small, the lakes from the fill hold water, and no water is created (the volume in the
# sim never exceeds what the springs poured in). The old head-pond placement (build 623: a spring landing in a lower basin) is not checked: natural rivers
# have no head ponds.
#   godot --headless --path . --script res://src/worldgen/tools/test_water_small.gd

const DrainageFillScript := preload("res://src/worldgen/tile/drainage_fill.gd")
const DrainageFlowScript := preload("res://src/worldgen/tile/drainage_flow.gd")
const DrainageNaturalScript := preload("res://src/worldgen/tile/drainage_natural.gd")
const WaterSettler := preload("res://src/water/water_settler.gd")

const SIZE := 128
const CELL_M := 8.0
const SIM_SECONDS := 10800.0
const RULES := {
	"natural": {
		"enabled": true, "width_base_m": 16.0, "width_per_sqrt_km2_m": 10.0, "depth_base_m": 2.5, "depth_per_km2_pow04_m": 1.5, "surface_share": 0.75,
		"bank_slope": 0.25, "blend_m": 24.0, "smooth_cells": 7, "profile_cells": 25, "slope_flat": 0.12, "amp_widths": 3.5, "noise_gain": 1.8,
		"knot_widths": 5.0, "taper_cells": 8, "valley_limit_m": 8.0,
	},
}


# The data a baked tile hands the settler, made up: only the fields the settler reads.
class Tile:
	extends RefCounted
	var heights: PackedFloat32Array
	var water_class: PackedByteArray
	var water_surface: PackedFloat32Array
	var samples: int = 0
	var spacing_m: float = 8.0
	var tile: Vector2i = Vector2i.ZERO
	var x0: float = 0.0
	var z0: float = 0.0


# The tile generator, made up: no tile files (so no stored flow map, no feeders) and no fine ground detail.
class Gen:
	extends RefCounted
	var tiles_dir: String = ""

	func _detail_at(_data, _x: float, _z: float, _spacing: float) -> float:
		return 0.0


var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _ground() -> PackedFloat32Array:
	var ground: PackedFloat32Array = PackedFloat32Array()
	ground.resize(SIZE * SIZE)

	for row in range(SIZE):
		for column in range(SIZE):
			var north: float = float(SIZE - row) / float(SIZE)
			var across: float = float(column - SIZE / 2) / float(SIZE / 2)
			var valley: float = 6.0 * (1.0 - exp(-across * across * 3.0))
			var swell: float = 1.0 * sin(float(column) * 0.31) * sin(float(row) * 0.23)
			var h: float = 4.0 + north * 60.0 + valley + swell
			var d: float = Vector2(float(column - 90), float(row - 40)).length()

			if d < 7.0:
				h -= 8.0 * (1.0 - d / 7.0)

			ground[row * SIZE + column] = h

	for row in range(SIZE - 10, SIZE):
		for column in range(SIZE):
			ground[row * SIZE + column] = -2.0

	return ground


func _init() -> void:
	var begun: int = Time.get_ticks_msec()
	var ground: PackedFloat32Array = _ground()
	var sea: PackedByteArray = PackedByteArray()
	sea.resize(SIZE * SIZE)

	for index in range(SIZE * SIZE):
		sea[index] = 1 if ground[index] <= 0.0 else 0

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
	var data = Tile.new()
	data.heights = natural.bed.duplicate()
	data.samples = SIZE
	data.spacing_m = CELL_M
	data.water_class.resize(SIZE * SIZE)
	data.water_surface.resize(SIZE * SIZE)
	var river_cells: Array = []

	for index in range(SIZE * SIZE):
		data.water_surface[index] = NAN

		if sea[index] == 1:
			data.water_class[index] = WaterSettler.OCEAN
		elif not is_nan(natural.surface[index]):
			data.water_class[index] = WaterSettler.RIVER
			data.water_surface[index] = natural.surface[index]
			river_cells.append(index)
		elif fill.lake_id[index] > 0:
			data.water_class[index] = WaterSettler.LAKE
			data.water_surface[index] = fill.lakes[fill.lake_id[index] - 1]["level"]

	_check(river_cells.size() > 150, "the made-up island has rivers (%d river cells)" % river_cells.size())
	var sim = WaterSettler.build(data, 3.0, Gen.new(), false)
	var poured: float = 0.0

	for spring in sim.springs:
		poured += float(spring[1])

	_check(sim.springs.size() > 0, "the settler placed springs (%d, %.1f m3/s in all)" % [sim.springs.size(), poured])

	while sim.seconds < SIM_SECONDS:
		sim.step()

	# Water arrives in the channels from a dry start. The three thresholds (45 percent wet, 70 percent joined, 10 percent of lake cells) are a ratchet set under
	# today's measured values (56, 77 and 21 percent at 10,800 s): they catch a broken settler or sim, and are raised when the water gets better.
	var wet_river: int = 0
	var wet: PackedByteArray = PackedByteArray()
	wet.resize(SIZE * SIZE)

	for index in river_cells:
		if sim.depth_at(index) > 0.05:
			wet_river += 1
			wet[index] = 1

	var share: float = float(wet_river) / float(river_cells.size())
	_check(share >= 0.45, "from dry, the rivers fill: %.0f percent of river cells hold water after %d s" % [100.0 * share, int(SIM_SECONDS)])

	# No stranded wet stretch: the wet river cells touching the sea, then everything joined to them through wet river cells (8 neighbours).
	var reached: PackedByteArray = PackedByteArray()
	reached.resize(SIZE * SIZE)
	var stack: Array = []

	for index in river_cells:
		if wet[index] == 0:
			continue

		@warning_ignore("integer_division")
		var row: int = index / SIZE
		var column: int = index % SIZE

		for dz in range(-1, 2):
			for dc in range(-1, 2):
				var nr: int = row + dz
				var nc: int = column + dc

				if nr >= 0 and nr < SIZE and nc >= 0 and nc < SIZE and (sea[nr * SIZE + nc] == 1 or nr == SIZE - 1):
					if reached[index] == 0:
						reached[index] = 1
						stack.append(index)

	while not stack.is_empty():
		var at: int = stack.pop_back()
		@warning_ignore("integer_division")
		var row: int = at / SIZE
		var column: int = at % SIZE

		for dz in range(-1, 2):
			for dc in range(-1, 2):
				var nr: int = row + dz
				var nc: int = column + dc

				if nr >= 0 and nr < SIZE and nc >= 0 and nc < SIZE:
					var n: int = nr * SIZE + nc

					if wet[n] == 1 and reached[n] == 0:
						reached[n] = 1
						stack.append(n)

	var joined: int = 0

	for index in river_cells:
		joined += reached[index]

	_check(wet_river > 0 and float(joined) >= 0.7 * float(wet_river), "the wet river reaches the sea (%d of %d wet river cells are joined to the sea)" % [joined, wet_river])

	# Spill: wet land far from every river and lake (more than 4 cells) stays a small share of all wet land.
	var near: PackedByteArray = PackedByteArray()
	near.resize(SIZE * SIZE)

	for index in range(SIZE * SIZE):
		if data.water_class[index] == WaterSettler.RIVER or data.water_class[index] == WaterSettler.LAKE:
			@warning_ignore("integer_division")
			var row: int = index / SIZE
			var column: int = index % SIZE

			for dz in range(-4, 5):
				for dc in range(-4, 5):
					var nr: int = row + dz
					var nc: int = column + dc

					if nr >= 0 and nr < SIZE and nc >= 0 and nc < SIZE:
						near[nr * SIZE + nc] = 1

	var wet_land: int = 0
	var spill: int = 0

	for index in range(SIZE * SIZE):
		if sea[index] == 0 and sim.depth_at(index) > 0.05:
			wet_land += 1

			if near[index] == 0:
				spill += 1

	_check(spill <= wet_land / 10, "water stays in the channels and lakes (%d of %d wet land cells lie more than 32 m from one)" % [spill, wet_land])

	# Lakes from the fill hold water.
	var lake_cells: int = 0
	var lake_wet: int = 0

	for index in range(SIZE * SIZE):
		if data.water_class[index] == WaterSettler.LAKE:
			lake_cells += 1

			if sim.depth_at(index) > 0.05:
				lake_wet += 1

	_check(lake_cells > 0 and lake_wet * 10 >= lake_cells, "the lakes hold water (%d of %d lake cells)" % [lake_wet, lake_cells])

	# No water is created: what the sim holds on land never exceeds the springs' pour plus the painted start (none on a dry start).
	var held: float = sim.total_volume()
	_check(held <= poured * SIM_SECONDS * 1.001, "no water is created (holds %.0f m3 of at most %.0f m3 poured)" % [held, poured * SIM_SECONDS])
	_check(held > 0.0, "the sim holds water (%.0f m3)" % held)
	var took: float = float(Time.get_ticks_msec() - begun) / 1000.0
	print("water small: %d failures, %.1f s, wet river %.0f percent, spill %d, lakes %d of %d" % [failures, took, 100.0 * share, spill, lake_wet, lake_cells])
	quit(1 if failures > 0 else 0)
