extends SceneTree

# Small, fast drainage check (a few seconds) on a made-up 128 x 128 island: a tilted plain falling to the sea with one closed hollow in it. No baked tile needed.
# Replaces the invariants of test_drainage_flow and test_tile_lakes that still hold in the ground-first system (the fill and the flow are shared by the old and
# the natural-rivers bake): water is conserved (every unit of rain on land leaves at the sea), every land cell drains to the sea, a lake stands at its lowest rim
# and has an outlet there, a lake level never lies under its own ground, the filled surface never falls going uphill-to-downhill along a receiver, and the same
# input gives the same result. The old rule-based channel carving (drainage_channels.gd, bends and bank ratios) is not checked here: natural rivers replace it.
#   godot --headless --path . --script res://src/worldgen/tools/test_drainage_small.gd

const DrainageFillScript := preload("res://src/worldgen/tile/drainage_fill.gd")
const DrainageFlowScript := preload("res://src/worldgen/tile/drainage_flow.gd")

const SIZE := 128
const CELL_M := 8.0
const BOWL_AT := Vector2i(64, 40)
const BOWL_DEPTH_M := 8.0
const BOWL_RADIUS := 7.0

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


# A plain falling to the sea along the south edge, a shallow valley down the middle, a few swells, and a round hollow (a closed basin) in the north.
func _ground() -> PackedFloat32Array:
	var ground: PackedFloat32Array = PackedFloat32Array()
	ground.resize(SIZE * SIZE)

	for row in range(SIZE):
		for column in range(SIZE):
			var north: float = float(SIZE - row) / float(SIZE)
			var across: float = float(column - SIZE / 2) / float(SIZE / 2)
			var valley: float = 5.0 * (1.0 - exp(-across * across * 3.0))
			var swell: float = 0.8 * sin(float(column) * 0.31) * sin(float(row) * 0.23)
			var h: float = 6.0 + north * 60.0 + valley + swell
			var d: float = Vector2(float(column - BOWL_AT.x), float(row - BOWL_AT.y)).length()

			if d < BOWL_RADIUS:
				h -= BOWL_DEPTH_M * (1.0 - d / BOWL_RADIUS)

			ground[row * SIZE + column] = h

	for row in range(SIZE - 10, SIZE):
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
	return {"fill": fill, "flow": flow, "runoff": runoff}


func _init() -> void:
	var begun: int = Time.get_ticks_msec()
	var ground: PackedFloat32Array = _ground()
	var sea: PackedByteArray = PackedByteArray()
	sea.resize(SIZE * SIZE)

	for index in range(SIZE * SIZE):
		sea[index] = 1 if ground[index] <= 0.0 else 0

	var first: Dictionary = _build(ground, sea)
	var second: Dictionary = _build(ground, sea)
	var fill = first["fill"]
	var flow = first["flow"]
	var runoff: PackedFloat32Array = first["runoff"]

	# Determinism.
	_check(fill.filled == second["fill"].filled and fill.receiver == second["fill"].receiver and flow.discharge == second["flow"].discharge, "same input, same fill, same routing, same flow")

	# Mass balance: all the rain on land leaves at the sea or the tile edge (a lake holds nothing back once full).
	var land_total: float = 0.0
	var leaving: float = 0.0

	for index in range(SIZE * SIZE):
		if sea[index] == 0:
			land_total += runoff[index]
			var next: int = fill.receiver[index]

			if next < 0 or sea[next] == 1:
				leaving += flow.discharge[index]

	_check(land_total > 0.0 and absf(leaving - land_total) < 0.001 * land_total, "mass balance: %.3f km2 of land, %.3f leaves" % [land_total, leaving])

	# Every land cell drains to the sea or the edge, with no loop, and the filled surface never rises going downstream.
	var stuck: int = 0
	var rising: int = 0

	for start in range(0, SIZE * SIZE, 3):
		if sea[start] == 1:
			continue

		var at: int = start
		var hops: int = 0

		while at >= 0 and sea[at] == 0 and hops <= SIZE * SIZE:
			var next: int = fill.receiver[at]

			if next >= 0 and fill.filled[next] > fill.filled[at] + 0.0005:
				rising += 1

			at = next
			hops += 1

		if hops > SIZE * SIZE:
			stuck += 1

	_check(stuck == 0, "every land cell drains to the sea or the edge (%d loops)" % stuck)
	_check(rising == 0, "the filled surface never rises going downstream (%d rises)" % rising)

	# The hollow becomes a lake: it stands at its lowest rim, the lake has an outlet on that rim, and no lake level is under its own ground.
	var bowl_cell: int = BOWL_AT.y * SIZE + BOWL_AT.x
	var id: int = fill.lake_id[bowl_cell]
	_check(id > 0, "the closed hollow became a lake (lake id %d, %d lakes in all)" % [id, fill.lakes.size()])

	if id > 0:
		var lake: Dictionary = fill.lakes[id - 1]
		var rim: float = INF

		for index in range(SIZE * SIZE):
			if fill.lake_id[index] != id:
				continue

			@warning_ignore("integer_division")
			var row: int = index / SIZE
			var column: int = index % SIZE

			for dz in range(-1, 2):
				for dc in range(-1, 2):
					var nr: int = row + dz
					var nc: int = column + dc

					if nr >= 0 and nr < SIZE and nc >= 0 and nc < SIZE and fill.lake_id[nr * SIZE + nc] != id:
						rim = minf(rim, ground[nr * SIZE + nc])

		_check(absf(float(lake["level"]) - rim) < 0.05, "the lake stands at its lowest rim (level %.2f m, lowest rim %.2f m)" % [float(lake["level"]), rim])
		_check(float(lake["depth"]) > 0.5 and float(lake["depth"]) < BOWL_DEPTH_M + 1.0, "the lake is as deep as the hollow (%.2f m of %.1f)" % [float(lake["depth"]), BOWL_DEPTH_M])
		var outlet: int = int(lake["outlet"])
		_check(outlet >= 0 and absf(fill.filled[outlet] - float(lake["level"])) < 0.05, "the lake has an outlet at its level (cell %d)" % outlet)

	var under: int = 0

	for index in range(SIZE * SIZE):
		if sea[index] == 0 and fill.filled[index] < ground[index] - 0.0005:
			under += 1

	_check(under == 0, "the filled surface is never under the ground (%d cells)" % under)
	var took: float = float(Time.get_ticks_msec() - begun) / 1000.0
	_check(took < 20.0, "runs in seconds (%.1f s)" % took)
	print("drainage small: %d failures, %.1f s" % [failures, took])
	quit(1 if failures > 0 else 0)
