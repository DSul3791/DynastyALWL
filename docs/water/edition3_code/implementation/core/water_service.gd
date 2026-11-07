class_name SullivanWaterService
extends Node
## Explicit body routing: 0 = freshwater, 1 = ocean in this baseline.
## Production: add body bounds, overlapping-volume selection, cave layers.
@export var freshwater_node: Node
@export var ocean_node: Node
@export var freshwater_origin_xz: Vector2 = Vector2.ZERO
@export var freshwater_body_id: int = 100
@export var ocean_body_id: int = 200
@export var ocean_enabled: bool = true

func sample_freshwater(point: Vector3) -> SullivanWaterSample:
    var result := SullivanWaterSample.new()
    if freshwater_node == null:
        return result
    # Mandatory injected contract: freshwater_node.grid: WaterGrid2D.
    var grid: WaterGrid2D = freshwater_node.get("grid") as WaterGrid2D
    if grid == null:
        return result
    var x: int = int(floor((point.x - freshwater_origin_xz.x) / grid.cell_size))
    var z: int = int(floor((point.z - freshwater_origin_xz.y) / grid.cell_size))
    if x < 0 or z < 0 or x >= grid.width or z >= grid.height:
        return result
    var depth_m: float = grid.depth(x, z)
    if depth_m <= 0.001:
        return result
    result.found = true
    result.body_id = freshwater_body_id
    result.bottom_y_m = grid.bed[grid.index(x, z)]
    result.surface_y_m = grid.surface(x, z)
    result.depth_m = depth_m
    result.current_world_mps = grid.velocity(x, z)
    result.submerged = point.y < result.surface_y_m and point.y >= result.bottom_y_m
    result.quality = 1  # Discrete cell query; not a sub-cell hydrodynamic solution.
    return result

func sample_ocean(point: Vector3) -> SullivanWaterSample:
    var result := SullivanWaterSample.new()
    if not ocean_enabled or ocean_node == null:
        return result
    # The ocean has no bottom in this prototype. Underwater is approximate.
    result.found = true
    result.body_id = ocean_body_id
    result.surface_y_m = ocean_node.sample_height(point.x, point.z)
    result.normal_world = ocean_node.sample_normal(point.x, point.z)
    result.bottom_y_m = -INF
    result.depth_m = INF
    result.submerged = point.y < result.surface_y_m
    result.quality = 1
    return result

func sample(point: Vector3) -> SullivanWaterSample:
    var fresh := sample_freshwater(point)
    if fresh.found:
        return fresh
    return sample_ocean(point)
