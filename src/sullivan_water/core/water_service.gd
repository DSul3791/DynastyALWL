extends RefCounted

# Sullivan water: the one place game code asks "is there water here?" (guide section 2: WaterService routes every query). Adapted from Dave's
# companion file docs/water/edition3_code/implementation/core/water_service.gd:
# - It reads our WaterGrid2D (src/sullivan_water/freshwater/water_grid_2d.gd) directly instead of a node's `grid` property, so it runs in
#   headless tests. It is a RefCounted rather than a Node; a Node wrapper comes when it joins a scene.
# - The ocean is optional: any object with sample_height(x, z) and sample_normal(x, z) (Dave's OceanWater.gd has both; milestone M5).
# - Freshwater wins over the ocean, as in Dave's file. Caves and stacked water are not routed yet (guide 3.10): one surface per column.
# Read-only: nothing here changes water volume (guide section 2, strict ownership).

const Sample := preload("res://src/sullivan_water/core/water_sample.gd")

const MIN_DEPTH_M := 0.001          # thinner than this is no water (Dave's file)

var grid                            # WaterGrid2D, or null
var grid_origin_xz: Vector2 = Vector2.ZERO   # world x, z of the grid's corner
var ocean                           # optional: sample_height(x, z), sample_normal(x, z)
var freshwater_body_id: int = 100
var ocean_body_id: int = 200
var ocean_enabled: bool = true


func sample_freshwater(point: Vector3):
	var result = Sample.new()

	if grid == null:
		return result

	var i: int = floori((point.x - grid_origin_xz.x) / grid.cell_m)
	var j: int = floori((point.z - grid_origin_xz.y) / grid.cell_m)

	if not grid.inside(i, j):
		return result

	var depth_m: float = grid.depth(i, j)

	if depth_m <= MIN_DEPTH_M:
		return result

	result.found = true
	result.body_id = freshwater_body_id
	result.bottom_y_m = grid.bed[grid.index(i, j)]
	result.surface_y_m = grid.surface(i, j)
	result.depth_m = depth_m
	result.current_world_mps = grid.current_mps(i, j)
	result.submerged = point.y < result.surface_y_m and point.y >= result.bottom_y_m
	result.quality = 1   # one cell's value, not a sub-cell solution
	return result


func sample_ocean(point: Vector3):
	var result = Sample.new()

	if not ocean_enabled or ocean == null:
		return result

	result.found = true
	result.body_id = ocean_body_id
	result.surface_y_m = ocean.sample_height(point.x, point.z)
	result.normal_world = ocean.sample_normal(point.x, point.z)
	result.bottom_y_m = -INF   # the ocean has no bottom in this baseline
	result.depth_m = INF
	result.submerged = point.y < result.surface_y_m
	result.quality = 1
	return result


func sample(point: Vector3):
	var fresh = sample_freshwater(point)

	if fresh.found:
		return fresh
	return sample_ocean(point)
