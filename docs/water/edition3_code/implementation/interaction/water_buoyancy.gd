class_name SullivanWaterBuoyancy
extends RigidBody3D
## A deliberately simple single-point float. Set water_service in inspector.
## Assumption: float_marker marks the center of a submerged support sphere.
## Larger boats should use multiple sampling points and torque.
@export var water_service: SullivanWaterService
@export var float_marker: Node3D
@export_range(0.1, 10.0, 0.1) var support_depth_m: float = 1.0
@export_range(0.0, 10.0, 0.1) var buoyancy_multiplier: float = 1.3
@export_range(0.0, 10.0, 0.1) var drag_per_second: float = 1.2

func _physics_process(_delta: float) -> void:
    if water_service == null or float_marker == null:
        return
    var point: Vector3 = float_marker.global_position
    var water: SullivanWaterSample = water_service.sample(point)
    if not water.found:
        return
    var immersion: float = clampf((water.surface_y_m - point.y) / support_depth_m, 0.0, 1.0)
    if immersion <= 0.0:
        return
    var gravity_mps2: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
    var up_force: Vector3 = Vector3.UP * mass * gravity_mps2 * buoyancy_multiplier * immersion
    apply_central_force(up_force)
    var relative_velocity: Vector3 = linear_velocity - water.current_world_mps
    apply_central_force(-relative_velocity * mass * drag_per_second * immersion)
