extends Node3D

# Ferns on the banks and walls around the foot of the nearest waterfall (owner, 2026-10-20:
# "notice the extra growth on the walls due to the extra moisture"). Client only, look only, never
# stored or synced. One group of fern cards per fall, scattered around the landing point inside the
# spray zone (same radius rule as the damp ground in ground_material.gd set_falls), placed with a few
# downward rays per frame against the terrain collision, leaning with the slope so they sprout from
# walls as well as from the level bank. Built only for the nearest fall within SHOW_M, and rebuilt
# when that fall changes.
#
# Cost follows quality (F2): cards Low 6, Medium 40, High 80, Ultra 120 (crossed quads with an
# alpha-scissored texture, no shadows, one draw call); up to RAYS_PER_FRAME rays per frame while a
# group is being placed, nothing afterwards.

const GrassViewScript := preload("res://src/client/grass_view.gd")
const CARDS := [6, 40, 80, 120]
const SHOW_M := 110.0
const RAYS_PER_FRAME := 6

var growth_cards: int = 0          # cards drawn now

var _terrain: Node3D
var _flora
var _quality: int = 1
var _material: ShaderMaterial = null
var _mesh: ArrayMesh = null
var _fall_id: int = 0
var _has_fall: bool = false
var _fall: Dictionary = {}
var _tries: Array = []             # [x, z] spots still to cast a ray at
var _buffer: PackedFloat32Array = PackedFloat32Array()
var _count: int = 0
var _node: MultiMeshInstance3D = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(terrain: Node3D, flora, quality: int) -> void:
	_terrain = terrain
	_flora = flora
	_quality = clampi(quality, 0, CARDS.size() - 1)
	var shader: Shader = Shader.new()
	shader.code = GrassViewScript.SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("blades", GrassViewScript._load_texture("fern"))
	_material.set_shader_parameter("fade_start", 24.0)
	_material.set_shader_parameter("fade_end", 36.0)
	_material.set_shader_parameter("wind_strength", 0.04)
	_material.set_shader_parameter("backlight", 0.3)
	_mesh = GrassViewScript._make_cards(1.0, 0.7, 3)


func set_quality(quality: int) -> void:
	var q: int = clampi(quality, 0, CARDS.size() - 1)

	if q != _quality:
		_quality = q
		_restart()


# falls: flora.fall_list() rows; at: the player.
func update(falls: Array, at: Vector3) -> void:
	var best: Dictionary = {}
	var best_d: float = SHOW_M

	for fall in falls:
		var base: Vector3 = fall["base"]
		var d: float = Vector2(base.x - at.x, base.z - at.z).length()

		if d < best_d:
			best_d = d
			best = fall

	if best.is_empty():
		if _has_fall:
			_has_fall = false
			_clear()

		return

	if _has_fall and int(best["id"]) == _fall_id:
		return

	_has_fall = true
	_fall_id = int(best["id"])
	_fall = best
	_restart()


func _clear() -> void:
	if _node != null:
		_node.queue_free()
		_node = null

	growth_cards = 0
	_tries.clear()
	_count = 0


func _restart() -> void:
	_clear()

	if not _has_fall:
		return

	var base: Vector3 = _fall["base"]
	var flow: float = float(_fall["flow"])
	var radius: float = clampf(14.0 + 5.0 * sqrt(maxf(flow, 0.0)) + 0.4 * float(_fall["width"]), 14.0, 40.0)
	_rng.seed = _fall_id
	var want: int = CARDS[_quality]
	_buffer = PackedFloat32Array()
	_buffer.resize(want * 16)

	# Twice as many spots as cards: some miss water, steep faces or the collision.
	for n in range(want * 2):
		var a: float = _rng.randf() * TAU
		var r: float = 2.5 + (radius * 0.75 - 2.5) * pow(_rng.randf(), 0.8)
		_tries.append([base.x + cos(a) * r, base.z + sin(a) * r])


func _process(_delta: float) -> void:
	if _tries.is_empty() or _terrain == null:
		return

	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var base: Vector3 = _fall["base"]
	var top: Vector3 = _fall["top"]
	var want: int = CARDS[_quality]

	for k in range(RAYS_PER_FRAME):
		if _tries.is_empty() or _count >= want:
			break

		var spot: Array = _tries.pop_back()
		var x: float = float(spot[0])
		var z: float = float(spot[1])
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(x, top.y + 20.0, z), Vector3(x, base.y - 12.0, z))
		var hit: Dictionary = space.intersect_ray(query)

		if hit.is_empty() or hit["collider"].has_meta("species_ids"):
			continue

		var point: Vector3 = hit["position"]
		var normal: Vector3 = hit["normal"]
		var water: float = _flora.water_level_at(x, z)

		if (not is_nan(water) and point.y < water + 0.25) or normal.y < 0.25 or point.y > top.y + 3.0:
			continue

		# Steeper ground (the walls) takes ferns more readily than the open bank.
		if normal.y > 0.9 and _rng.randf() < 0.45:
			continue

		_put(point, normal)

	if _tries.is_empty() or _count >= want:
		_tries.clear()
		_finish()


func _put(point: Vector3, normal: Vector3) -> void:
	var up: Vector3 = Vector3.UP.lerp(normal, 0.5).normalized()
	var yaw: float = _rng.randf() * TAU
	var heading: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
	var xa: Vector3 = (heading - up * heading.dot(up)).normalized()
	var za: Vector3 = xa.cross(up)
	var size: float = _rng.randf_range(0.7, 1.35)
	var tall: float = size * _rng.randf_range(0.8, 1.2)
	var shade: float = _rng.randf_range(0.8, 1.1)
	var o: int = _count * 16
	_count += 1
	xa *= size
	up *= tall
	za *= size
	_buffer[o] = xa.x
	_buffer[o + 1] = up.x
	_buffer[o + 2] = za.x
	_buffer[o + 3] = point.x
	_buffer[o + 4] = xa.y
	_buffer[o + 5] = up.y
	_buffer[o + 6] = za.y
	_buffer[o + 7] = point.y - 0.05
	_buffer[o + 8] = xa.z
	_buffer[o + 9] = up.z
	_buffer[o + 10] = za.z
	_buffer[o + 11] = point.z
	_buffer[o + 12] = 0.62 * shade
	_buffer[o + 13] = 0.8 * shade * _rng.randf_range(0.92, 1.05)
	_buffer[o + 14] = 0.5 * shade
	_buffer[o + 15] = 1.0


func _finish() -> void:
	if _count == 0:
		return

	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = _mesh
	multi.instance_count = _count
	var buffer: PackedFloat32Array = _buffer
	buffer.resize(_count * 16)
	multi.buffer = buffer
	_node = MultiMeshInstance3D.new()
	_node.multimesh = multi
	_node.material_override = _material
	_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var base: Vector3 = _fall["base"]
	_node.custom_aabb = AABB(base - Vector3(60.0, 30.0, 60.0), Vector3(120.0, 90.0, 120.0))
	_node.visibility_range_end = 70.0
	add_child(_node)
	growth_cards = _count
