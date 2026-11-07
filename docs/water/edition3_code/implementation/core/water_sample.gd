class_name SullivanWaterSample
extends RefCounted
## A single world-space water query. A missing sample has found=false.
var found: bool = false
var body_id: int = -1
var surface_y_m: float = 0.0
var bottom_y_m: float = 0.0
var depth_m: float = 0.0
var normal_world: Vector3 = Vector3.UP
var current_world_mps: Vector3 = Vector3.ZERO
var submerged: bool = false
var quality: int = 0  # 0 missing, 1 approximate, 2 authoritative
