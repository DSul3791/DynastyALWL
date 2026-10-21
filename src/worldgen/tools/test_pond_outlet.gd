extends SceneTree

# Head pond outlet (owner report 2026-10-20, build 200: no river left the pond). A world head
# pond on a flat bench with its brook and river cut by TileWater._carve_guides, then a
# spring of the base flow runs in it on the live water sim. From the pond's edge downstream
# the water must be drawn (water_sim.gd draw rules) all the way, not spread into a sheet too
# thin to show.
#   godot --headless --path . --script res://src/worldgen/tools/test_pond_outlet.gd

const TileWaterScript := preload("res://src/worldgen/tile/tile_water.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const WaterSim := preload("res://src/water/water_sim.gd")

const SIDE := 161
const SPACING := 8.0
const SPRING_M3S := 10.0          # terrain_server.gd WATER_BASE_RATE
const RUN_S := 10800.0

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var errors: Array = []
	var rules: Dictionary = TileHeightScript.load_rules("res://worlds/base_world/plan/tile_rules.json", errors)

	if not errors.is_empty():
		push_error("\n".join(errors))
		quit(1)
		return

	# Like pond A in tile 3,4: a bench at 30 m out to the end of the pond's shore, then land
	# falling 8 cm per metre away from it, the brook leaving on a slant across the grid.
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(SIDE * SIDE)

	for j in range(SIDE):
		for i in range(SIDE):
			heights[j * SIDE + i] = 30.0 - maxf(Vector2(float(i), float(j)).distance_to(Vector2(40.0, 80.0)) * SPACING - 75.0, 0.0) * 0.08

	var water = TileWaterScript.new()
	water._rules = rules["water"]
	water.spacing_m = SPACING
	water.samples = SIDE
	water.heights = heights.duplicate()
	water.water_class = PackedByteArray()
	water.water_class.resize(SIDE * SIDE)
	water.water_surface = PackedFloat32Array()
	water.water_surface.resize(SIDE * SIDE)
	water.flow = PackedFloat32Array()
	water.flow.resize(SIDE * SIDE)
	water._ocean = PackedByteArray()
	water._ocean.resize(SIDE * SIDE)

	for k in range(SIDE * SIDE):
		water._ocean[k] = 1 if heights[k] <= 0.0 else 0

	var row: float = 80.0
	var centre: Vector2 = Vector2(40.0, row)
	var head: Vector2 = Vector2(60.0, 71.0)
	var radius: float = float(rules["water"]["head_pond_diameter_m"]) * 0.5
	water._world_ponds = [{
		"centre": centre * SPACING, "radius": radius, "level": 30.0,
		"heads": [head * SPACING], "head_levels": [heights[int(head.y) * SIDE + int(head.x)]],
		"paths": [PackedVector2Array([centre * SPACING, head * SPACING])],
	}]
	var points: PackedVector2Array = PackedVector2Array()
	var areas: PackedFloat32Array = PackedFloat32Array()
	var along: Vector2 = (head - centre).normalized()
	var at: Vector2 = head

	while at.x < float(SIDE - 2) and at.y > 1.0:
		points.append(at)
		areas.append(float(rules["water"]["river_start_km2"]))
		at += along * 0.5

	water._carve_guides([{"points": points, "areas": areas, "source": true}])

	var sim = WaterSim.new()
	sim.setup(SIDE, SPACING, water.heights)
	sim.add_spring(int(centre.x), int(centre.y), SPRING_M3S)

	while sim.seconds < RUN_S:
		sim.step()

	var levels: PackedFloat32Array = sim.level_map()
	var depth: PackedFloat32Array = sim.get_depth()
	var pond_level: float = NAN

	for n in [Vector2(-1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(-1, 1)]:
		var level: float = levels[int(centre.y + n.y) * SIDE + int(centre.x + n.x)]
		pond_level = level if is_nan(pond_level) else (pond_level if is_nan(level) else maxf(pond_level, level))
	if OS.get_cmdline_user_args().has("--profile"):
		for n in range(0, 40):
			var cell: Vector2 = (centre + along * float(n)).round()
			var i: int = int(cell.x)
			var k: int = int(cell.y) * SIDE + i
			print("col %d ground %.2f depth %.2f drawn %s | row-1 %.2f/%.2f row+1 %.2f/%.2f" % [i, water.heights[k], depth[k], str(not is_nan(levels[k])), water.heights[k - SIDE], depth[k - SIDE], water.heights[k + SIDE], depth[k + SIDE]])

	_check(not is_nan(pond_level), "the pond holds water (level %.2f m)" % pond_level)

	# Along the brook's line from the pond's edge to 300 m out, the water across the channel is
	# deep enough to draw on its own depth, not only as a thin film between deeper water (the
	# sheet over the wide flat sill in tile 3,4 was 2 to 12 cm).
	var gaps: PackedStringArray = PackedStringArray()
	var step: float = radius / SPACING

	while step < (radius + 300.0) / SPACING:
		var point: Vector2 = centre + along * step

		# Past the coast the river is the sea (the estuary sinks its last stretch under 0 m).
		if water.heights[int(point.y) * SIDE + int(point.x)] <= 0.0:
			step += 0.5
			continue

		var deepest: float = 0.0
		var drawn: bool = false

		for j in range(int(point.y) - 2, int(point.y) + 3):
			for i in range(int(point.x) - 2, int(point.x) + 3):
				if Vector2(float(i), float(j)).distance_to(point) <= 2.0:
					deepest = maxf(deepest, depth[j * SIDE + i])
					drawn = drawn or not is_nan(levels[j * SIDE + i])

		if not drawn or deepest < WaterSim.WET_M:
			gaps.append("%.0f m (%.2f m)" % [step * SPACING - radius, deepest])

		step += 0.5

	_check(gaps.is_empty(), "the river runs deep enough to show from the pond's edge down (too thin at: %s)" % ", ".join(gaps))
	print("pond outlet: %d failures" % failures)
	quit(1 if failures > 0 else 0)
