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


func _carve(rules: Dictionary, fall_per_m: float, profile: Array = []) -> PackedFloat32Array:
	# Default: flat 60 m plateau for 20 samples, then a slope of `fall_per_m` down to column 120, flat below.
	# With a profile ([[column, height], ...] joined by straight lines): that land instead.
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(SIDE * SIDE)

	for j in range(SIDE):
		for i in range(SIDE):
			if profile.is_empty():
				heights[j * SIDE + i] = maxf(60.0 - maxf(float(i) - 30.0, 0.0) * SPACING * fall_per_m, 60.0 - 70.0 * SPACING * fall_per_m)
			else:
				var h: float = float(profile[profile.size() - 1][1])

				for n in range(profile.size() - 1):
					if float(i) <= float(profile[n + 1][0]):
						h = lerpf(float(profile[n][1]), float(profile[n + 1][1]), clampf((float(i) - float(profile[n][0])) / (float(profile[n + 1][0]) - float(profile[n][0])), 0.0, 1.0))
						break

				heights[j * SIDE + i] = h

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


# A face is one or two neighbouring drops (the cut edge is never exactly on a sample).
func _merge_faces(faces: Array) -> Array:
	var merged: Array = []

	for face in faces:
		if not merged.is_empty() and int(face[0]) - int(merged[merged.size() - 1][0]) <= 2:
			merged[merged.size() - 1][1] = float(merged[merged.size() - 1][1]) + float(face[1])
		else:
			merged.append([face[0], face[1]])

	return merged


func _init() -> void:
	var errors: Array = []
	var rules: Dictionary = TileHeightScript.load_rules("res://worlds/base_world/plan/tile_rules.json", errors)

	if not errors.is_empty():
		push_error("\n".join(errors))
		quit(1)
		return

	# Dave 2026-10-21: never steps. A 60 m cliff onto a plateau, a river across it, then a 30 m cliff:
	# two clean chutes, one face each, a plunge pool at each foot, no benches on the way down.
	var land: Array = [[0, 200.0], [30, 200.0], [34, 140.0], [70, 140.0], [73, 110.0], [120, 110.0]]
	var chutes: PackedFloat32Array = _carve(rules, 0.0, land)

	if OS.get_cmdline_user_args().has("--profile"):
		for i in range(20, 125):
			print("col %d  %.1f  (%.1f)" % [i, chutes[80 * SIDE + i], chutes[75 * SIDE + i]])

	var faces: Array = _merge_faces(_faces(chutes, 8.0))
	_check(faces.size() == 2, "two cliffs make exactly two chutes (%d faces: %s)" % [faces.size(), str(faces)])

	# No bench inside a drop: after the first face the bed only goes down to the pool floor, never steps again before the plateau.
	var first_face: int = int(faces[0][0]) if faces.size() > 0 else 0
	var second_face: int = int(faces[1][0]) if faces.size() > 1 else SIDE
	var stray: int = 0

	for i in range(first_face + 16, second_face - 8):
		if absf(chutes[80 * SIDE + i] - chutes[80 * SIDE + i + 1]) >= 3.0:
			stray += 1

	_check(stray == 0, "river reach between the chutes has no steps (%d)" % stray)

	# A plunge pool: the bed a few samples below each face lies deeper than the bed that carries on after the pool.
	var pool_a: float = INF

	for i in range(first_face + 2, first_face + 14):
		pool_a = minf(pool_a, chutes[80 * SIDE + i])

	var reach_a: float = chutes[80 * SIDE + first_face + 24]
	_check(pool_a < reach_a - 1.5, "plunge pool below the first chute (%.1f in the pool, %.1f on the reach)" % [pool_a, reach_a])

	# A very tall drop (mountain side) is one long chute at a constant gradient, not a 300 m wall.
	var tall: PackedFloat32Array = _carve(rules, 0.0, [[0, 600.0], [30, 600.0], [50, 200.0], [120, 200.0]])
	var worst: float = 0.0

	for i in range(10, 110):
		worst = maxf(worst, tall[80 * SIDE + i] - tall[80 * SIDE + i + 1])
		if OS.get_cmdline_user_args().has('--profile'):
			print('tall ', i, ' ', tall[80 * SIDE + i])

	_check(worst < 60.0, "a 400 m drop (land falls 20 m per sample) has no wall (largest single drop %.1f m)" % worst)

	# A gentle slope is left alone.
	var gentle: PackedFloat32Array = _carve(rules, 0.1)
	_check(_faces(gentle, 8.0).is_empty(), "a gentle slope has no vertical faces")
	print("terrace: %d failures" % failures)
	quit(1 if failures > 0 else 0)
