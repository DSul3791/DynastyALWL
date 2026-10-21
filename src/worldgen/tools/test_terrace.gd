extends SceneTree

# Waterfalls as vertical faces (owner 2026-10-21): a river down a steep slope is cut as a
# staircase of flat treads and one-sample vertical faces; a cascade has several faces.
#   godot --headless --path . --script res://src/worldgen/tools/test_terrace.gd [-- --profile]

const TileWaterScript := preload("res://src/worldgen/tile/tile_water.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")

const SIDE := 161
const SPACING := 8.0

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _carve(rules: Dictionary, fall_per_m: float) -> PackedFloat32Array:
	# Flat 60 m plateau for 20 samples, then a slope of `fall_per_m` down to column 120, flat below.
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(SIDE * SIDE)

	for j in range(SIDE):
		for i in range(SIDE):
			heights[j * SIDE + i] = maxf(60.0 - maxf(float(i) - 30.0, 0.0) * SPACING * fall_per_m, 60.0 - 70.0 * SPACING * fall_per_m)

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
	var points: PackedVector2Array = PackedVector2Array()
	var areas: PackedFloat32Array = PackedFloat32Array()

	for n in range(10, 150):
		points.append(Vector2(float(n), 80.0))
		areas.append(20.0)

	water._carve_guides([{"points": points, "areas": areas, "source": false}])
	return water.heights


# Drops between neighbouring samples along the river's row, at least min_drop high.
func _faces(heights: PackedFloat32Array, min_drop: float) -> Array:
	var faces: Array = []

	for i in range(SIDE - 1):
		var drop: float = heights[80 * SIDE + i] - heights[80 * SIDE + i + 1]

		if drop >= min_drop:
			faces.append([i, drop])

	return faces


func _init() -> void:
	var errors: Array = []
	var rules: Dictionary = TileHeightScript.load_rules("res://worlds/base_world/plan/tile_rules.json", errors)

	if not errors.is_empty():
		push_error("\n".join(errors))
		quit(1)
		return

	var steep: PackedFloat32Array = _carve(rules, 1.2)

	if OS.get_cmdline_user_args().has("--profile"):
		for i in range(20, 110):
			print("col %d  %.1f  (%.1f)" % [i, steep[80 * SIDE + i], steep[75 * SIDE + i]])

	var faces: Array = _faces(steep, 8.0)
	_check(faces.size() >= 3, "a steep slope becomes a cascade of several vertical faces (%d faces: %s)" % [faces.size(), str(faces)])

	# Treads between the faces are flat for at least two samples.
	var flat_runs: int = 0
	var run: int = 0

	for i in range(20, 110):
		if absf(steep[80 * SIDE + i] - steep[80 * SIDE + i + 1]) < 1.0:
			run += 1
		else:
			if run >= 2:
				flat_runs += 1

			run = 0

	_check(flat_runs >= 2, "flat treads of 16 m or more between the faces (%d)" % flat_runs)

	# A gentle slope is left alone.
	var gentle: PackedFloat32Array = _carve(rules, 0.1)
	_check(_faces(gentle, 8.0).is_empty(), "a gentle slope has no vertical faces")
	print("terrace: %d failures" % failures)
	quit(1 if failures > 0 else 0)
