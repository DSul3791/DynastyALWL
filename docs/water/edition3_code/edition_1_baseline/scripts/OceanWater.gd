class_name OceanWater
extends Node3D
## Create a MeshInstance3D child named Surface with a subdivided PlaneMesh.
## Assign res://shaders/ocean_baseline.gdshader as its material.
## Plane mesh must lie in local XZ, facing upward.

@export var sea_level: float = 0.0
@export var follow_camera: Camera3D
@onready var surface_mesh: MeshInstance3D = $Surface

const G: float = 9.81
# Must exactly match ocean_baseline.gdshader default waves until changed together.
var waves: Array[Vector4] = [
    Vector4(1.0, 0.0, 0.45, 0.12),
    Vector4(0.7, 0.7, 0.22, 0.31),
    Vector4(-0.3, 0.95, 0.09, 0.72),
    Vector4(0.9, -0.4, 0.06, 1.4)
]
var wave_clock: float = 0.0

func _ready() -> void:
    if surface_mesh.material_override == null:
        push_warning("Assign a ShaderMaterial in Surface.material_override")
    # Expand culling bounds to account for displaced vertices.
    surface_mesh.extra_cull_margin = 3.0
    global_position.y = sea_level

func _process(delta: float) -> void:
    wave_clock += delta
    if follow_camera != null:
        global_position.x = roundf(follow_camera.global_position.x / 8.0) * 8.0
        global_position.z = roundf(follow_camera.global_position.z / 8.0) * 8.0
        global_position.y = sea_level
    var shader_material := surface_mesh.material_override as ShaderMaterial
    if shader_material != null:
        shader_material.set_shader_parameter("water_time", wave_clock)

func sample_height(world_x: float, world_z: float) -> float:
    var h: float = sea_level
    for wave in waves:
        var direction := Vector2(wave.x, wave.y).normalized()
        var k: float = wave.w
        var phase: float = k * direction.dot(Vector2(world_x, world_z)) - sqrt(G * k) * wave_clock
        h += wave.z * sin(phase)
    return h

func sample_normal(world_x: float, world_z: float) -> Vector3:
    var gradient := Vector2.ZERO
    for wave in waves:
        var direction := Vector2(wave.x, wave.y).normalized()
        var k: float = wave.w
        var phase: float = k * direction.dot(Vector2(world_x, world_z)) - sqrt(G * k) * wave_clock
        gradient += wave.z * k * direction * cos(phase)
    return Vector3(-gradient.x, 1.0, -gradient.y).normalized()
