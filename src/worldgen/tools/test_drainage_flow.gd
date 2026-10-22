extends SceneTree

# Option B stage 2: runoff gathers into rivers. Mass balance and agreement with today's rivers.
#   godot --headless --path . --script res://src/worldgen/tools/test_drainage_flow.gd [-- --tile=3,4]

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const DrainageFillScript := preload("res://src/worldgen/tile/drainage_fill.gd")
const DrainageFlowScript := preload("res://src/worldgen/tile/drainage_flow.gd")

const STEP := 2                # 16 m cells
const RIVER_CELLS_KM2 := 0.5   # river_start_km2 of today's world network
const NEAR_CELLS := 4          # 64 m

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var tile: Vector2i = Vector2i(3, 4)

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tile="):
			var parts: PackedStringArray = argument.trim_prefix("--tile=").split(",")
			tile = Vector2i(int(parts[0]), int(parts[1]))

	var errors: Array = []
	var world: String = "res://worlds/base_world"
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var data = generator.get_tile(tile)

	if data.placeholder:
		print("no baked tile, skipping")
		quit(0)
		return

	var side: int = (data.samples - 1) / STEP + 1
	var cell_m: float = data.spacing_m * float(STEP)
	var h: PackedFloat32Array = PackedFloat32Array()
	h.resize(side * side)
	var sea: PackedByteArray = PackedByteArray()
	sea.resize(side * side)
	var runoff: PackedFloat32Array = PackedFloat32Array()
	runoff.resize(side * side)

	for row in range(side):
		for column in range(side):
			var k: int = row * STEP * data.samples + column * STEP
			var index: int = row * side + column
			h[index] = data.heights[k]
			sea[index] = 1 if data.heights[k] < 0.0 else 0
			runoff[index] = cell_m * cell_m * 1.0e-6   # one unit per km2 of land: discharge reads as catchment km2

	var begun: int = Time.get_ticks_msec()
	var fill = DrainageFillScript.new()
	fill.build(h, sea, side, 2.0)
	var flow = DrainageFlowScript.new()
	flow.build(fill, runoff)
	var took: float = float(Time.get_ticks_msec() - begun) / 1000.0
	var land_total: float = 0.0
	var leaving: float = 0.0

	for index in range(side * side):
		if sea[index] == 0:
			land_total += runoff[index]

			# Water leaves the tile at the sea or at the tile edge.
			var next: int = fill.receiver[index]

			if next < 0 or sea[next] == 1:
				leaving += flow.discharge[index]

	_check(absf(leaving - land_total) < 0.001 * land_total, "mass balance: %.2f km2 of land, %.2f leaves" % [land_total, leaving])
	var mask: PackedByteArray = flow.channel_cells(RIVER_CELLS_KM2)
	var rivers: int = 0
	var agree: int = 0

	for index in range(side * side):
		if data.water_class[(index / side) * STEP * data.samples + (index % side) * STEP] != 3:
			continue

		rivers += 1
		var row: int = index / side
		var column: int = index % side
		var hit: bool = false

		for dz in range(-NEAR_CELLS, NEAR_CELLS + 1):
			for dc in range(-NEAR_CELLS, NEAR_CELLS + 1):
				var nr: int = row + dz
				var nc: int = column + dc

				if nr >= 0 and nr < side and nc >= 0 and nc < side and mask[nr * side + nc] == 1:
					hit = true

		if hit:
			agree += 1

	print("today's river cells %d, within 64 m of a drainage channel: %d (%.0f%%), %.1f s" % [rivers, agree, 100.0 * float(agree) / maxf(float(rivers), 1.0), took])
	_check(took < 30.0, "fill and flow under 30 s per tile (%.1f s)" % took)
	print("drainage flow: %d failures" % failures)
	quit(1 if failures > 0 else 0)
