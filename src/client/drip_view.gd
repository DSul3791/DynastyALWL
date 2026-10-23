extends RefCounted
# Dripping ceilings under water (Dave 2026-10-23): the server sends the ceiling points near the player that have water within 4 m above
# them (leak message, protocol 73). Each point drips (a slow stream of small drops, faster the closer the water) and the floor under it is
# darker and wet-looking. Nothing collects: no water is simulated. When the messages stop everything fades out in about a second.

const MAX_POINTS := 24
const HOLD_S := 1.2
const DROP_SIZE_M := 0.03

var gap_m: float = 99.0               # metres of rock between the nearest dripping ceiling and the water above it; 99 when none (for the wet sounds)
var wet_here: bool = false            # a dripping ceiling within 3 m of the player
var _root: Node3D
var _drippers: Array = []
var _left_s: float = 0.0
var _mesh: QuadMesh
var _patch: QuadMesh
var _patch_material: StandardMaterial3D
var _client


func setup(client, parent: Node) -> void:
	_client = client
	_root = Node3D.new()
	parent.add_child(_root)
	_mesh = QuadMesh.new()
	_mesh.size = Vector2(DROP_SIZE_M, DROP_SIZE_M * 2.5)
	var drop: StandardMaterial3D = StandardMaterial3D.new()
	drop.albedo_color = Color(0.7, 0.8, 0.9, 0.75)
	drop.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_mesh.material = drop
	_patch = QuadMesh.new()
	_patch.size = Vector2(1.6, 1.6)
	_patch.orientation = PlaneMesh.FACE_Y
	_patch_material = StandardMaterial3D.new()
	_patch_material.albedo_color = Color(0.0, 0.0, 0.0, 0.0)
	_patch_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_patch_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_patch.material = _patch_material


# From the leak message: `points` are ceiling points, `closeness` 0..255 per point (255 = water right at the ceiling).
func on_leak(points: PackedVector3Array, closeness: PackedByteArray, here: Vector3) -> void:
	_left_s = HOLD_S
	var count: int = mini(points.size(), MAX_POINTS)
	gap_m = 99.0
	wet_here = false

	while _drippers.size() < count:
		_drippers.append(_make_dripper())

	for i in range(_drippers.size()):
		var entry: Dictionary = _drippers[i]
		var live: bool = i < count
		entry["drops"].visible = live
		entry["patch"].visible = live

		if not live:
			continue

		var at: Vector3 = points[i]
		var close: float = float(closeness[i]) / 255.0
		gap_m = minf(gap_m, 4.0 * (1.0 - close))
		wet_here = wet_here or at.distance_to(here) < 3.0
		entry["drops"].global_position = at + Vector3(0.0, -0.05, 0.0)
		entry["drops"].amount = 2 + int(close * 10.0)
		entry["drops"].emitting = true
		var floor_y: float = _floor_below(at)
		entry["patch"].global_position = Vector3(at.x, floor_y + 0.02, at.z)
		entry["patch"].scale = Vector3.ONE * (0.6 + 0.8 * close)


# Every frame: fades out when no message has come for a moment.
func step(delta: float) -> void:
	if _left_s <= 0.0:
		return

	_left_s -= delta

	if _left_s <= 0.0:
		gap_m = 99.0
		wet_here = false

		for entry in _drippers:
			entry["drops"].emitting = false
			entry["patch"].visible = false



func _make_dripper() -> Dictionary:
	var drops: CPUParticles3D = CPUParticles3D.new()
	drops.mesh = _mesh
	drops.amount = 4
	drops.lifetime = 0.9
	drops.local_coords = false
	drops.direction = Vector3.DOWN
	drops.spread = 3.0
	drops.initial_velocity_min = 0.0
	drops.initial_velocity_max = 0.4
	drops.gravity = Vector3(0.0, -9.0, 0.0)
	drops.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	drops.emission_sphere_radius = 0.15
	drops.emitting = false
	_root.add_child(drops)
	var patch: MeshInstance3D = MeshInstance3D.new()
	patch.mesh = _patch
	patch.material_override = _wet_material()
	patch.visible = false
	_root.add_child(patch)
	return {"drops": drops, "patch": patch}


func _wet_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.03, 0.04, 0.05, 0.45)
	material.roughness = 0.1
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


# The floor under a ceiling point (a short ray down), else 2 m below.
func _floor_below(at: Vector3) -> float:
	if _client == null or _client.body == null:
		return at.y - 2.0

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at + Vector3(0.0, -0.2, 0.0), at + Vector3(0.0, -6.0, 0.0))
	query.exclude = [_client.body.get_rid()]
	var hit: Dictionary = _client.body.get_world_3d().direct_space_state.intersect_ray(query)
	return float(hit["position"].y) if not hit.is_empty() else at.y - 2.0
