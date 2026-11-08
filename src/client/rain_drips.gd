extends RefCounted

# Drips from tree crowns and roof eaves (docs/design/rain_look_design.md 3.3; how long by rain amount and tree
# kind below, canopy_drip_design.md). The drops fall along a crown's edge (the drip line) and a roof's eaves, where the canopy map (which holds
# crowns and roofs) meets open ground, with a few from inside the cover. Big drops (4 to 6 mm) falling from a few metres: lit by the scene
# like the rain streaks, never glowing. One MultiMesh, a pool of drops moved on the CPU (at most 240).
# A crown memory per tree, the conifers' larger store and roof heights are not known on the client yet: one memory for the cover around
# the player, and drops start 3.5 to 7 m over the ground.

const GameClock := preload("res://src/shared/game_clock.gd")

const POOL := [60, 120, 180, 240]         # drops by quality
const RATE_PER_S := [40.0, 80.0, 120.0, 160.0]   # new drops a second with full crowns, by quality
const RADIUS_M := 12.0
const EDGE_STEP_M := 1.2                  # a covered spot with open ground this close is on the drip line
const INSIDE_SHARE := 0.15
const START_M := [3.5, 7.0]
const FALL_MAX := 8.5                     # m/s: a big drop's fall speed
const GRAVITY := 9.8
const DROP_LENGTH_M := 0.14
const DROP_HALF_WIDTH_M := 0.004

var store: float = 0.0                    # 0 dry crowns .. 1 full (for checks); the drip strength min(store_mm / 1.5, 1)
# Canopy drip by rain amount and tree kind (docs/design/canopy_drip_design.md, Jamie #675): the store is mm of water,
# capped by the trees around (conifers 3 mm, broadleaves 1.5, bare winter broadleaves 0.5), filled at the rain's own rate and emptied
# at (0.04 + 0.01 x mm) mm a game minute, faster in sun and wind: a full conifer drips about 56 game minutes, a light shower 17.
const CAP_CONIFER_MM := 3.0
const CAP_BROAD_MM := 1.5
const CAP_BARE_MM := 0.5
const DRAIN_MM_MIN := 0.04
const DRAIN_PER_MM_MIN := 0.01
const STRENGTH_MM := 1.5
const RAIN_MM_H := 50.0                   # rain 0..1 as 50 x rain^2.5 mm/h (as puddles.gd)
const RAIN_MM_POWER := 2.5
var store_mm: float = 0.0
var conifer_share: float = 0.0            # set by weather_look from tree_wind's stand densities
var winter: bool = false
var drops_live: int = 0                   # for checks
var _root: MultiMeshInstance3D
var _multimesh: MultiMesh
var _drops: Array = []                    # {"pos": Vector3, "v": float, "floor": float} per live drop
var _owed: float = 0.0
var _quality: int = 2
var _rng := RandomNumberGenerator.new()


# The crowns' water capacity in mm for this mix of trees.
static func cap_mm(conifer: float, is_winter: bool) -> float:
	var c: float = clampf(conifer, 0.0, 1.0)
	return CAP_CONIFER_MM * c + (CAP_BARE_MM if is_winter else CAP_BROAD_MM) * (1.0 - c)


# The store in mm after `hours` of game time. Rain over 0.05 fills it at its own rate up to the cap; after the rain it
# empties as dS/dt = -(a + b S) per game minute, a closed form so a long step is exact.
static func store_mm_step(now_mm: float, hours: float, rain: float, wind: float, sun: float, cap: float) -> float:
	if rain > 0.05:
		return minf(now_mm + RAIN_MM_H * pow(clampf(rain, 0.0, 1.0), RAIN_MM_POWER) * hours, cap)

	var speed: float = (1.0 + 2.0 * clampf(wind, 0.0, 1.0)) * (1.0 + clampf(sun, 0.0, 1.0))
	var a: float = DRAIN_MM_MIN * speed
	var b: float = DRAIN_PER_MM_MIN * speed
	var left: float = (minf(now_mm, cap) + a / b) * exp(-b * hours * 60.0) - a / b
	return maxf(left, 0.0)


static func drip_strength(mm: float) -> float:
	return minf(mm / STRENGTH_MM, 1.0)


func setup(parent: Node3D, material: Material) -> void:
	_rng.randomize()
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.mesh = _streak_mesh()
	_multimesh.instance_count = int(POOL[POOL.size() - 1])
	_multimesh.visible_instance_count = 0
	_root = MultiMeshInstance3D.new()
	_root.name = "RainDrips"
	_root.multimesh = _multimesh
	_root.material_override = material
	_root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.extra_cull_margin = 64.0      # the instances move far from the node's own origin
	parent.add_child(_root)


func set_quality(quality: int) -> void:
	_quality = clampi(quality, 0, POOL.size() - 1)


# Every frame: the rain, wind and sun now (0..1), the eye, the canopy map (cover_at) and the ground below a point (NAN when none).
func update(delta: float, rain: float, wind: float, sun: float, eye: Vector3, canopy, ground_below: Callable, sheltered: bool) -> void:
	store_mm = store_mm_step(store_mm, delta * GameClock.RATIO / 3600.0, rain, wind, sun, cap_mm(conifer_share, winter))
	store = drip_strength(store_mm)

	if _root == null:
		return

	if not sheltered and store > 0.0 and canopy != null:
		_owed += float(RATE_PER_S[_quality]) * store * delta
		var tries: int = 0

		while _owed >= 1.0 and _drops.size() < int(POOL[_quality]) and tries < 24:
			tries += 1
			_owed -= 1.0
			_spawn(eye, canopy, ground_below)

		_owed = minf(_owed, 4.0)
	else:
		_owed = 0.0

	var kept: Array = []

	for drop in _drops:
		drop["v"] = minf(float(drop["v"]) + GRAVITY * delta, FALL_MAX)
		var pos: Vector3 = drop["pos"]
		pos.y -= float(drop["v"]) * delta

		if pos.y > float(drop["floor"]):
			drop["pos"] = pos
			kept.append(drop)

	_drops = kept
	drops_live = _drops.size()

	for i in range(_drops.size()):
		_multimesh.set_instance_transform(i, Transform3D(Basis(), _drops[i]["pos"]))

	_multimesh.visible_instance_count = _drops.size()


func _spawn(eye: Vector3, canopy, ground_below: Callable) -> void:
	var angle: float = _rng.randf() * TAU
	var r: float = sqrt(_rng.randf()) * RADIUS_M
	var x: float = eye.x + cos(angle) * r
	var z: float = eye.z + sin(angle) * r

	if float(canopy.cover_at(x, z)) < 0.5:
		return

	var edge: bool = false

	for step in [Vector2(EDGE_STEP_M, 0.0), Vector2(-EDGE_STEP_M, 0.0), Vector2(0.0, EDGE_STEP_M), Vector2(0.0, -EDGE_STEP_M)]:
		if float(canopy.cover_at(x + step.x, z + step.y)) < 0.5:
			edge = true
			break

	if not edge and _rng.randf() > INSIDE_SHARE:
		return

	var ground: float = float(ground_below.call(Vector3(x, eye.y + 12.0, z)))

	if is_nan(ground):
		return

	var top: float = ground + _rng.randf_range(float(START_M[0]), float(START_M[1]))
	_drops.append({"pos": Vector3(x, top, z), "v": _rng.randf_range(0.0, 2.0), "floor": ground})


func _streak_mesh() -> ArrayMesh:
	var half: float = DROP_HALF_WIDTH_M
	var length: float = DROP_LENGTH_M
	var vertices: PackedVector3Array = PackedVector3Array([
		Vector3(-half, 0.0, 0.0), Vector3(half, 0.0, 0.0), Vector3(half, length, 0.0), Vector3(-half, length, 0.0),
		Vector3(0.0, 0.0, -half), Vector3(0.0, 0.0, half), Vector3(0.0, length, half), Vector3(0.0, length, -half)])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7])
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
