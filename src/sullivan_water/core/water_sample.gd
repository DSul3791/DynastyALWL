extends RefCounted

# One world-space water query (guide section 2, "canonical query contract"). Taken from Dave's companion file
# docs/water/edition3_code/implementation/core/water_sample.gd, with the same field names and meanings. A missing sample has found = false.
# No class_name: the project loads it by preload, so it can never clash with the reference copy.

var found: bool = false
var body_id: int = -1
var surface_y_m: float = 0.0
var bottom_y_m: float = 0.0
var depth_m: float = 0.0
var normal_world: Vector3 = Vector3.UP
var current_world_mps: Vector3 = Vector3.ZERO
var submerged: bool = false
var quality: int = 0  # 0 missing, 1 approximate, 2 authoritative
