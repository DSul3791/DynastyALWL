extends SceneTree

# No step in the water levels is drawn as a slanted wall of water (WaterGrid.build_mesh skips cells whose
# corners differ by more than STEP_MAX_M); gentle slopes still draw.
#   godot --headless --path . --script res://src/worldgen/tools/test_water_steps.gd

const WG := preload("res://src/worldgen/runtime/water_grid.gd")


func _mesh_span(levels: Array) -> Array:
	var count: int = 4
	var grid: Dictionary = {"count": count, "spacing": 8.0, "levels": PackedFloat32Array(levels), "wet": levels.size()}
	var mesh: ArrayMesh = WG.build_mesh(grid, null)

	if mesh.get_surface_count() == 0:
		return [0, 0.0]

	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
	var worst: float = 0.0

	@warning_ignore("integer_division")
	for t in range(indices.size() / 3):
		var ys: Array = [vertices[indices[3 * t]].y, vertices[indices[3 * t + 1]].y, vertices[indices[3 * t + 2]].y]
		worst = maxf(worst, maxf(ys.max() - ys.min(), 0.0))

	@warning_ignore("integer_division")
	return [indices.size() / 3, worst]


func _init() -> void:
	var failures: int = 0
	var flat: Array = []
	var step: Array = []
	var slope: Array = []

	for j in range(4):
		for i in range(4):
			flat.append(10.0)
			step.append(10.0 if i < 2 else 0.0)
			slope.append(10.0 - float(i))

	var flat_result: Array = _mesh_span(flat)
	var step_result: Array = _mesh_span(step)
	var slope_result: Array = _mesh_span(slope)
	var ok: bool = flat_result[0] == 18 and float(step_result[1]) <= WG.STEP_MAX_M and int(step_result[0]) < 18 and int(slope_result[0]) == 18
	print(("ok   " if ok else "FAIL ") + "flat %s, 10 m step %s, 1 m/cell slope %s (triangles, worst span)" % [flat_result, step_result, slope_result])

	if not ok:
		failures += 1

	print("water steps: %d failures" % failures)
	quit(1 if failures > 0 else 0)
