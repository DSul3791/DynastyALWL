extends RefCounted

# The running land-type signature (design/WATER_LAND_TYPES.md section 3): decaying averages per cell,
# updated once per game hour. Float32 on purpose: a one-byte average cannot move, because a 30 day
# constant adds under 1/255 per hour and a byte rounds that away. A save writes only cells that were
# ever wet.

const L := preload("res://src/water/land_type.gd")


var side: int = 0
var depth: PackedFloat32Array = PackedFloat32Array()
var speed: PackedFloat32Array = PackedFloat32Array()
var wet: PackedFloat32Array = PackedFloat32Array()

func setup(cells_per_side: int) -> void:
	side = cells_per_side
	depth.resize(side * side)
	speed.resize(side * side)
	wet.resize(side * side)

# Start from the settled water: the averages equal the settled state, so a restart never reads as a change.
func init_from(now_depth: PackedFloat32Array, now_speed: PackedFloat32Array) -> void:
	for k in range(side * side):
		depth[k] = now_depth[k]
		speed[k] = now_speed[k]
		wet[k] = 1.0 if now_depth[k] >= L.WET_M else 0.0

# One game hour (or `hours`) of water: now_depth / now_speed as the sim has them.
func update(now_depth: PackedFloat32Array, now_speed: PackedFloat32Array, hours: float = 1.0) -> void:
	var alpha: float = 1.0 - exp(-hours / L.TAU_HOURS)

	for k in range(side * side):
		var d: float = now_depth[k]

		if d == 0.0 and depth[k] < 0.0005 and wet[k] < 0.0005:
			continue

		depth[k] += (d - depth[k]) * alpha
		speed[k] += (now_speed[k] - speed[k]) * alpha
		wet[k] += ((1.0 if d >= L.WET_M else 0.0) - wet[k]) * alpha

func type_at(k: int, base_class: int, peaty: bool = false, fertile_warm: bool = false) -> int:
	return L.classify_cell(depth[k], speed[k], wet[k], base_class, peaty, fertile_warm)
