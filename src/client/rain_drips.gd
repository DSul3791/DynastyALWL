extends RefCounted

# Drips from tree crowns and roof eaves (docs/design/rain_look_design.md 3.3), with --rain-look. Crowns hold 0.5 to 2 mm of rain: they fill
# in about 10 game minutes of rain and go on dripping after it stops, less and less, gone in about 45 game minutes on a still grey day and
# in about 10 in a sunny breeze. The drops fall along a crown's edge (the drip line) and a roof's eaves, where the canopy map (which holds
# crowns and roofs) meets open ground, with a few from inside the cover. Big drops (4 to 6 mm) falling from a few metres: lit by the scene
# like the rain streaks, never glowing. One MultiMesh, a pool of drops moved on the CPU (at most 240).
# A crown memory per tree, the conifers' larger store and roof heights are not known on the client yet: one memory for the cover around
# the player, and drops start 3.5 to 7 m over the ground.

const GameClock := preload("res://src/shared/game_clock.gd")

const FILL_H := 10.0 / 60.0               # game hours of rain from FILL_FROM to fill the crowns
const FILL_FROM := 0.3
const HALF_H := 15.0 / 60.0               # half-life of the store after the rain, still and grey
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

var store: float = 0.0                    # 0 dry crowns .. 1 full (for checks)
var drops_live: int = 0                   # for checks
var _root: MultiMeshInstance3D
var _multimesh: MultiMesh
var _drops: Array = []                    # {"pos": Vector3, "v": float, "floor": float} per live drop
var _owed: float = 0.0
var _quality: int = 2
var _rng := RandomNumberGenerator.new()


# The crown store after `hours` of game time: fills in rain, empties on a half-life that sun and wind shorten.
static func store_step(now: float, hours: float, rain: float, wind: float, sun: float) -> float:
	if rain >= FILL_FROM:
		return minf(now + hours / FILL_H, 1.0)

	if rain > 0.05:
		return now      # light rain keeps the crowns wet

	var half: float = HALF_H * (1.0 - 0.5 * clampf(sun, 0.0, 1.0)) / (1.0 + 2.0 * clampf(wind, 0.0, 1.0))
	var left: float = now * pow(0.5, hours / maxf(half, 0.001))
	return left if left > 0.01 else 0.0


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
	store = store_step(store, delta * GameClock.RATIO / 3600.0, rain, wind, sun)

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
