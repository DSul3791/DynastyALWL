class_name SullivanFreshwaterRunner
extends Node3D
## Explicit 10 Hz prototype tick. Grid and render steps are separate.
const GRID_SCRIPT = preload("res://addons/sullivan_water/edition_1_baseline/scripts/WaterGrid2D.gd")
@export_range(2, 256) var width: int = 32
@export_range(2, 256) var height: int = 32
@export_range(0.25, 16.0) var cell_size_m: float = 2.0
@export_range(1, 60) var sim_hz: int = 10
var grid: WaterGrid2D
var accumulated: float = 0.0
const MAX_STEPS_PER_FRAME: int = 4

func _ready() -> void:
    grid = GRID_SCRIPT.new(width, height, cell_size_m)

func _physics_process(delta: float) -> void:
    var step_seconds: float = 1.0 / float(sim_hz)
    accumulated += delta
    var steps: int = 0
    while accumulated >= step_seconds and steps < MAX_STEPS_PER_FRAME:
        grid.step(step_seconds)
        accumulated -= step_seconds
        steps += 1
    # IMPORTANT: do not silently discard remaining simulation time.
    # If consistently behind, report, lower resolution, or activate fewer cells.
    if accumulated > 1.0:
        push_warning("Freshwater simulation backlog over 1 second")

func add_spring(x: int, z: int, flow_m3_per_s: float, dt: float) -> void:
    assert(flow_m3_per_s >= 0.0 and dt >= 0.0)
    grid.add_water(x, z, flow_m3_per_s * dt)
