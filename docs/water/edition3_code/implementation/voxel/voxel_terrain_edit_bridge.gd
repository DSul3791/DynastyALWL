class_name SullivanVoxelTerrainEditBridge
extends Node
## Reference-only Voxel Tools 1.7 SDF edit bridge. Not an atomic hydraulic edit coordinator.
signal terrain_edit_committed(local_bounds: AABB, revision: int)
@export var terrain: Node3D
var terrain_revision: int = 0

func edit_sphere_world(world_center: Vector3, radius_m: float, add_matter: bool) -> bool:
    if terrain == null or not terrain.has_method("get_voxel_tool") or radius_m <= 0.0:
        push_error("Missing Voxel Tools terrain or invalid radius")
        return false
    if not terrain.scale.is_equal_approx(Vector3.ONE):
        push_error("This reference bridge requires unit terrain scale")
        return false
    var local_center: Vector3 = terrain.to_local(world_center)
    var r: float = radius_m + 2.0
    var box := AABB(local_center - Vector3.ONE * r, Vector3.ONE * (2.0 * r))
    var tool = terrain.call("get_voxel_tool")
    tool.channel = VoxelBuffer.CHANNEL_SDF
    if not tool.is_area_editable(box):
        push_warning("Edit rejected: LOD0 area not editable")
        return false
    tool.mode = VoxelTool.MODE_ADD if add_matter else VoxelTool.MODE_REMOVE
    tool.do_sphere(local_center, radius_m)
    terrain_revision += 1
    terrain_edit_committed.emit(box, terrain_revision)
    return true
