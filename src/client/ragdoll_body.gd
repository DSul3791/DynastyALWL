extends Node3D

# The plain ragdoll-type character (owner, 2026-10-21: "a simple ragdoll type character, no features, just a
# body, head, arms, legs and hands"). One Skeleton3D with 17 bones, one skinned mesh of capsule and box limbs in
# a neutral skin colour (about 1.8 m tall, about 3.2 thousand triangles, one draw call), an AnimationPlayer with the ten
# animations the game needs, and a mount on each hand for held tools. Built in code; nothing to import.
#
#   var body := RagdollBody.new()                 # full body (third person), feet at the node's origin, facing -Z
#   var arms := RagdollBody.new(true)             # first person: just the arms and hands, see below
#   body.play("walk")                             # idle walk run crouch sit lie swing jab throw use
#   body.hand_mount_r                             # Marker3D: parent a held tool here (see assets/character/README.md)
#
# Bone rotations are about local X: for an arm or leg hanging down, + swings it forward (-Z), - back; elbows and
# wrists bend with +, knees with -. Animations key every bone, so switching never leaves a bone in the last pose.

const SKIN := Color(0.78, 0.62, 0.5)

# Bones: name, parent, rest offset from the parent (metres, standing, facing -Z). Right is +X.
const BONES := [
	["hips", "", Vector3(0.0, 0.95, 0.0)],
	["spine", "hips", Vector3(0.0, 0.12, 0.0)],
	["chest", "spine", Vector3(0.0, 0.2, 0.0)],
	["neck", "chest", Vector3(0.0, 0.22, 0.0)],
	["head", "neck", Vector3(0.0, 0.07, 0.0)],
	["arm_r", "chest", Vector3(0.21, 0.2, 0.0)],
	["forearm_r", "arm_r", Vector3(0.0, -0.29, 0.0)],
	["hand_r", "forearm_r", Vector3(0.0, -0.26, 0.0)],
	["arm_l", "chest", Vector3(-0.21, 0.2, 0.0)],
	["forearm_l", "arm_l", Vector3(0.0, -0.29, 0.0)],
	["hand_l", "forearm_l", Vector3(0.0, -0.26, 0.0)],
	["thigh_r", "hips", Vector3(0.1, -0.05, 0.0)],
	["shin_r", "thigh_r", Vector3(0.0, -0.45, 0.0)],
	["foot_r", "shin_r", Vector3(0.0, -0.4, 0.0)],
	["thigh_l", "hips", Vector3(-0.1, -0.05, 0.0)],
	["shin_l", "thigh_l", Vector3(0.0, -0.45, 0.0)],
	["foot_l", "shin_l", Vector3(0.0, -0.4, 0.0)],
]

# The first-person model keeps only these (the chest is its root, at the node's origin).
const ARM_BONES := ["chest", "arm_r", "forearm_r", "hand_r", "arm_l", "forearm_l", "hand_l"]

# Shapes, each on one bone, in that bone's own space: bone, shape, centre, size, in arms only (the first person model).
# capsule size = (radius, total height); ellipsoid size = (x, y, z radii); sphere size = (radius, height).
# Rounded ragdoll (owner, 2026-10-21: "the blockiness rounded off, proper knees and elbows, hands as spheroids,
# a head that is head shaped, no fine details"): ellipsoids for the torso, head, joints, hands and feet, capsules
# for the limbs between them. Every shape follows one bone, so a bent joint closes over its own sphere.
const PARTS := [
	["hips", "ellipsoid", Vector3(0.0, -0.01, 0.0), Vector3(0.19, 0.15, 0.13), false],
	["spine", "ellipsoid", Vector3(0.0, 0.09, 0.0), Vector3(0.18, 0.17, 0.12), false],
	["chest", "ellipsoid", Vector3(0.0, 0.1, 0.0), Vector3(0.2, 0.21, 0.125), false],
	["neck", "capsule", Vector3(0.0, 0.03, 0.0), Vector3(0.05, 0.15, 0.0), false],
	["head", "ellipsoid", Vector3(0.0, 0.15, 0.005), Vector3(0.1, 0.12, 0.115), false],
	["head", "ellipsoid", Vector3(0.0, 0.07, -0.03), Vector3(0.08, 0.085, 0.085), false],
	["arm_r", "ellipsoid", Vector3(0.0, 0.0, 0.0), Vector3(0.062, 0.062, 0.062), true],
	["arm_r", "capsule", Vector3(0.0, -0.145, 0.0), Vector3(0.05, 0.3, 0.0), true],
	["forearm_r", "ellipsoid", Vector3(0.0, 0.0, 0.0), Vector3(0.055, 0.055, 0.055), true],
	["forearm_r", "capsule", Vector3(0.0, -0.13, 0.0), Vector3(0.045, 0.28, 0.0), true],
	["hand_r", "ellipsoid", Vector3(0.0, -0.065, 0.0), Vector3(0.042, 0.075, 0.03), true],
	["arm_l", "ellipsoid", Vector3(0.0, 0.0, 0.0), Vector3(0.062, 0.062, 0.062), true],
	["arm_l", "capsule", Vector3(0.0, -0.145, 0.0), Vector3(0.05, 0.3, 0.0), true],
	["forearm_l", "ellipsoid", Vector3(0.0, 0.0, 0.0), Vector3(0.055, 0.055, 0.055), true],
	["forearm_l", "capsule", Vector3(0.0, -0.13, 0.0), Vector3(0.045, 0.28, 0.0), true],
	["hand_l", "ellipsoid", Vector3(0.0, -0.065, 0.0), Vector3(0.042, 0.075, 0.03), true],
	["thigh_r", "capsule", Vector3(0.0, -0.22, 0.0), Vector3(0.082, 0.5, 0.0), false],
	["shin_r", "ellipsoid", Vector3(0.0, 0.0, 0.0), Vector3(0.07, 0.07, 0.07), false],
	["shin_r", "capsule", Vector3(0.0, -0.2, 0.0), Vector3(0.06, 0.46, 0.0), false],
	["foot_r", "ellipsoid", Vector3(0.0, -0.03, -0.06), Vector3(0.056, 0.04, 0.135), false],
	["thigh_l", "capsule", Vector3(0.0, -0.22, 0.0), Vector3(0.082, 0.5, 0.0), false],
	["shin_l", "ellipsoid", Vector3(0.0, 0.0, 0.0), Vector3(0.07, 0.07, 0.07), false],
	["shin_l", "capsule", Vector3(0.0, -0.2, 0.0), Vector3(0.06, 0.46, 0.0), false],
	["foot_l", "ellipsoid", Vector3(0.0, -0.03, -0.06), Vector3(0.056, 0.04, 0.135), false],
]

const ANIMATIONS := ["idle", "walk", "jog", "run", "crouch", "sit", "lie", "swing", "jab", "throw", "use"]

var arms_only: bool = false
var skeleton: Skeleton3D
var body_mesh: MeshInstance3D
var animation_player: AnimationPlayer
var hand_mount_r: Marker3D       # where the right hand holds a tool (see the README for the axes)
var hand_mount_l: Marker3D
var head_mount: Marker3D         # a hat, or a camera for a head cam: the middle of the head
var _bones: Dictionary = {}      # name -> index


func _init(arms: bool = false) -> void:
	arms_only = arms
	name = "RagdollArms" if arms else "RagdollBody"
	_build_skeleton()
	_build_mesh()
	_build_mounts()
	_build_animations()


# The animation to show; one-shot animations (swing jab throw use) run once and hold their last frame,
# which is the rest pose, so `play("idle")` afterwards is smooth.
func play(animation: String, speed: float = 1.0, blend: float = 0.15) -> void:
	if animation_player != null and animation_player.has_animation(animation):
		animation_player.play(animation, blend, speed)


func current() -> String:
	return animation_player.current_animation if animation_player != null else ""


func is_one_shot_playing() -> bool:
	return animation_player != null and animation_player.is_playing() and animation_player.get_animation(animation_player.current_animation).loop_mode == Animation.LOOP_NONE


# ---------------------------------------------------------------- build

func _wanted(bone: String) -> bool:
	return not arms_only or bone in ARM_BONES


func _build_skeleton() -> void:
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	add_child(skeleton)

	for row in BONES:
		if not _wanted(row[0]):
			continue

		skeleton.add_bone(row[0])
		var index: int = skeleton.get_bone_count() - 1
		_bones[row[0]] = index
		var offset: Vector3 = row[2]

		if arms_only and row[0] == "chest":
			offset = Vector3.ZERO     # the arms model is rooted at the chest

		skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, offset))

		if row[1] != "" and _bones.has(row[1]):
			skeleton.set_bone_parent(index, _bones[row[1]])

	skeleton.reset_bone_poses()


func _global_rest(bone: String) -> Transform3D:
	var index: int = _bones[bone]
	return skeleton.get_bone_global_rest(index)


# Clothes: every vertex carries its region in the red channel (0 skin, 0.34 coat, 0.67 trousers, 1 shoes) so `dress` can colour
# one shared mesh per character with a tiny shader. The plain material ignores it (the player stays one skin colour).
static func _region(bone: String) -> float:
	if bone.begins_with("foot"):
		return 1.0

	if bone.begins_with("thigh") or bone.begins_with("shin") or bone == "hips":
		return 0.67

	if bone.begins_with("arm") or bone.begins_with("forearm") or bone == "spine" or bone == "chest":
		return 0.34

	return 0.0


static var _full_mesh: ArrayMesh
static var _full_skin: Skin
static var _dress_shader: Shader

const DRESS_SHADER := """
shader_type spatial;
uniform vec3 skin_color : source_color = vec3(0.78, 0.62, 0.5);
uniform vec3 coat_color : source_color = vec3(0.4, 0.34, 0.28);
uniform vec3 trouser_color : source_color = vec3(0.25, 0.22, 0.2);
uniform vec3 shoe_color : source_color = vec3(0.14, 0.11, 0.09);
void fragment() {
	float r = COLOR.r;
	vec3 c = mix(skin_color, coat_color, step(0.17, r));
	c = mix(c, trouser_color, step(0.5, r));
	c = mix(c, shoe_color, step(0.83, r));
	ALBEDO = c;
	ROUGHNESS = 0.9;
}
"""


# Paint this character: skin, coat (torso and arms), trousers (hips and legs) and shoes, one cheap shader material each.
func dress(skin_color: Color, coat: Color, trousers: Color, shoes: Color = Color(0.14, 0.11, 0.09)) -> void:
	if _dress_shader == null:
		_dress_shader = Shader.new()
		_dress_shader.code = DRESS_SHADER

	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _dress_shader
	material.set_shader_parameter("skin_color", skin_color)
	material.set_shader_parameter("coat_color", coat)
	material.set_shader_parameter("trouser_color", trousers)
	material.set_shader_parameter("shoe_color", shoes)
	body_mesh.material_override = material


func _build_mesh() -> void:
	if not arms_only and _full_mesh != null:
		body_mesh = MeshInstance3D.new()
		body_mesh.name = "Body"
		body_mesh.mesh = _full_mesh
		body_mesh.skin = _full_skin
		body_mesh.skeleton = NodePath("..")
		skeleton.add_child(body_mesh)
		return

	var colors: PackedColorArray = PackedColorArray()
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var bone_ids: PackedInt32Array = PackedInt32Array()
	var weights: PackedFloat32Array = PackedFloat32Array()
	var skin: Skin = Skin.new()

	for bone in _bones:
		skin.add_bind(_bones[bone], _global_rest(bone).affine_inverse())

	for part in PARTS:
		if not _bones.has(part[0]) or (arms_only and not part[4]):
			continue

		var arrays: Array = _shape_arrays(part[1], part[3])
		var model: Transform3D = _global_rest(part[0]) * Transform3D(Basis.IDENTITY, part[2])
		var first: int = vertices.size()
		var source_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var source_uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var source_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

		for v in range(source_vertices.size()):
			vertices.append(model * source_vertices[v])
			colors.append(Color(_region(part[0]), 0.0, 0.0, 1.0))
			normals.append(model.basis * source_normals[v])
			uvs.append(source_uvs[v])
			bone_ids.append_array(PackedInt32Array([_bones[part[0]], 0, 0, 0]))
			weights.append_array(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))

		for i in source_indices:
			indices.append(first + i)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_BONES] = bone_ids
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# Limbs swing well away from their rest shape: a box of the whole body keeps the culling honest.
	mesh.custom_aabb = AABB(Vector3(-1.2, -0.2, -1.2), Vector3(2.4, 2.4, 2.4))
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = SKIN
	material.roughness = 0.9
	mesh.surface_set_material(0, material)
	body_mesh = MeshInstance3D.new()
	body_mesh.name = "Body"
	body_mesh.mesh = mesh
	body_mesh.skin = skin
	body_mesh.skeleton = NodePath("..")
	skeleton.add_child(body_mesh)

	if not arms_only:
		_full_mesh = mesh
		_full_skin = skin


func _shape_arrays(kind: String, size: Vector3) -> Array:
	if kind == "ellipsoid":
		# A unit sphere stretched to the radii; the normals follow the stretch (divide, then renormalise).
		var unit: SphereMesh = SphereMesh.new()
		unit.radius = 1.0
		unit.height = 2.0
		var big: bool = maxf(size.x, maxf(size.y, size.z)) > 0.09
		var round_head: bool = size.y > 0.1 and size.y < 0.13 and size.z > 0.1
		unit.radial_segments = 14 if round_head else 10
		unit.rings = 7 if round_head else 4
		var arrays: Array = unit.get_mesh_arrays()
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]

		for i in range(points.size()):
			points[i] = Vector3(points[i].x * size.x, points[i].y * size.y, points[i].z * size.z)
			normals[i] = Vector3(normals[i].x / size.x, normals[i].y / size.y, normals[i].z / size.z).normalized()

		arrays[Mesh.ARRAY_VERTEX] = points
		arrays[Mesh.ARRAY_NORMAL] = normals
		return arrays

	return _shape(kind, size).get_mesh_arrays()


func _shape(kind: String, size: Vector3) -> Mesh:
	if kind == "box":
		var box: BoxMesh = BoxMesh.new()
		box.size = size
		return box

	if kind == "sphere":
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = size.x
		sphere.height = size.y
		sphere.radial_segments = 12
		sphere.rings = 6
		return sphere

	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = size.x
	capsule.height = size.y
	capsule.radial_segments = 10
	capsule.rings = 2
	return capsule


func _mount(bone: String, mount_name: String, offset: Vector3, basis: Basis) -> Marker3D:
	var attachment: BoneAttachment3D = BoneAttachment3D.new()
	attachment.name = "Attach_" + mount_name
	skeleton.add_child(attachment)
	attachment.bone_name = bone
	var marker: Marker3D = Marker3D.new()
	marker.name = mount_name
	marker.transform = Transform3D(basis, offset)
	attachment.add_child(marker)
	return marker


func _build_mounts() -> void:
	# A held tool's origin is the grip; its -Z points out along the fingers (see the README for the other axes).
	var grip: Basis = Basis(Vector3.RIGHT, -PI * 0.5)
	hand_mount_r = _mount("hand_r", "HandMount_R", Vector3(0.0, -0.07, 0.0), grip)
	hand_mount_l = _mount("hand_l", "HandMount_L", Vector3(0.0, -0.07, 0.0), grip)

	if _bones.has("head"):
		head_mount = _mount("head", "HeadMount", Vector3(0.0, 0.14, 0.0), Basis.IDENTITY)


# ---------------------------------------------------------------- animation

# A pose: bone name -> rotation (Vector3 of X, Y, Z radians); "hips_move" -> the hips' offset from rest.
func _build_animations() -> void:
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	add_child(animation_player)
	var library: AnimationLibrary = AnimationLibrary.new()
	library.add_animation("idle", _loop(3.0, 12, _idle))
	library.add_animation("walk", _loop(1.0, 16, _walk))
	library.add_animation("jog", _loop(0.75, 16, _jog))
	library.add_animation("run", _loop(0.62, 16, _run))
	library.add_animation("crouch", _loop(2.0, 8, _crouch))
	library.add_animation("sit", _loop(3.0, 8, _sit))
	library.add_animation("lie", _loop(4.0, 8, _lie))
	library.add_animation("swing", _once(0.7, 14, _swing))
	library.add_animation("jab", _once(0.5, 10, _jab))
	library.add_animation("throw", _once(0.8, 16, _throw))
	library.add_animation("use", _once(0.6, 12, _use))
	animation_player.add_animation_library("", library)
	animation_player.play("idle")


func _loop(length: float, frames: int, pose: Callable) -> Animation:
	return _animation(length, frames, pose, true)


func _once(length: float, frames: int, pose: Callable) -> Animation:
	return _animation(length, frames, pose, false)


func _animation(length: float, frames: int, pose: Callable, loop: bool) -> Animation:
	var animation: Animation = Animation.new()
	animation.length = length
	animation.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var tracks: Dictionary = {}

	for bone in _bones:
		var track: int = animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, NodePath("Skeleton3D:" + bone))
		tracks[bone] = track

	var hips_track: int = -1

	if _bones.has("hips"):
		hips_track = animation.add_track(Animation.TYPE_POSITION_3D)
		animation.track_set_path(hips_track, NodePath("Skeleton3D:hips"))

	for k in range(frames + 1):
		var phase: float = float(k) / float(frames)
		var values: Dictionary = pose.call(phase)

		for bone in _bones:
			var angles: Vector3 = values.get(bone, Vector3.ZERO)
			var q: Quaternion = Quaternion.from_euler(angles)
			animation.rotation_track_insert_key(tracks[bone], phase * length, q)

		if hips_track >= 0:
			animation.position_track_insert_key(hips_track, phase * length, Vector3(0.0, 0.95, 0.0) + (values.get("hips_move", Vector3.ZERO) as Vector3))

	return animation


# Smooth interpolation through [phase, value] keys (phase 0 to 1, in order); holds the first and last.
static func _keys(keys: Array, phase: float) -> Variant:
	if phase <= float(keys[0][0]):
		return keys[0][1]

	for i in range(1, keys.size()):
		if phase <= float(keys[i][0]):
			var a: Array = keys[i - 1]
			var b: Array = keys[i]
			var t: float = smoothstep(0.0, 1.0, (phase - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001))
			return a[1] + (b[1] - a[1]) * t if a[1] is Vector3 else lerpf(a[1], b[1], t)

	return keys[keys.size() - 1][1]


func _idle(p: float) -> Dictionary:
	var breath: float = sin(TAU * p)
	return {
		"chest": Vector3(0.02 * breath, 0.0, 0.0), "head": Vector3(-0.01 * breath, 0.0, 0.0),
		"arm_l": Vector3(0.0, 0.0, -0.07), "arm_r": Vector3(0.0, 0.0, 0.07),
		"forearm_l": Vector3(0.12, 0.0, 0.0), "forearm_r": Vector3(0.12, 0.0, 0.0),
		"hips_move": Vector3(0.0, 0.004 * breath, 0.0),
	}


# Gait clips (Tyler's table, BEST_PRACTICES "Natural walk, jog, run"): knee swing peak about 60 / 95 / 110 degrees and 15 / 35 /
# 45 degrees at foot plant, elbow 25 / 70 / 90 degrees, forward lean 2 / 6 / 10 degrees with the head level, shoulders turning
# against the hips, the body rising twice a stride. Natural speeds (m/s) where the stride matches the ground: walk 1.4, jog 3.2,
# run 6.0; terrain_client.gd scales the playback inside a limited range around them.
func _gait(p: float, thigh: float, knee_swing: float, knee_plant: float, arm: float, elbow: float, lean: float, twist: float, bob: float, sink: float, hop: float = 0.0) -> Dictionary:
	var s: float = sin(TAU * p)
	var c: float = cos(TAU * p)
	var swing_l: float = maxf(c, 0.0)
	var swing_r: float = maxf(-c, 0.0)
	return {
		"thigh_l": Vector3(thigh * s, 0.0, 0.0), "thigh_r": Vector3(-thigh * s, 0.0, 0.0),
		"shin_l": Vector3(-(knee_plant + (knee_swing - knee_plant) * swing_l), 0.0, 0.0), "shin_r": Vector3(-(knee_plant + (knee_swing - knee_plant) * swing_r), 0.0, 0.0),
		"foot_l": Vector3(0.2 * swing_l, 0.0, 0.0), "foot_r": Vector3(0.2 * swing_r, 0.0, 0.0),
		"arm_l": Vector3(-arm * s, 0.0, -0.06), "arm_r": Vector3(arm * s, 0.0, 0.06),
		"forearm_l": Vector3(elbow + 0.25 * elbow * maxf(-s, 0.0), 0.0, 0.0), "forearm_r": Vector3(elbow + 0.25 * elbow * maxf(s, 0.0), 0.0, 0.0),
		"hips": Vector3(0.0, -0.4 * twist * s, 0.0),
		"spine": Vector3(-lean * 0.6, twist * s, 0.0), "chest": Vector3(-lean * 0.4, -0.3 * twist * s, 0.0), "head": Vector3(lean * 0.9, 0.0, 0.0),
		"hips_move": Vector3(0.0, bob * cos(2.0 * TAU * p) - sink + hop * maxf(cos(2.0 * TAU * p) - 0.3, 0.0) / 0.7, 0.0),
	}


func _walk(p: float) -> Dictionary:
	return _gait(p, 0.45, 1.05, 0.3, 0.3, 0.4, 0.035, 0.08, 0.02, 0.01)


func _jog(p: float) -> Dictionary:
	return _gait(p, 0.6, 1.65, 0.65, 0.5, 1.2, 0.1, 0.12, 0.03, 0.04)


func _run(p: float) -> Dictionary:
	return _gait(p, 0.75, 1.9, 0.75, 0.8, 1.5, 0.18, 0.16, 0.045, 0.07, 0.03)


func _crouch(p: float) -> Dictionary:
	var sway: float = sin(TAU * p)
	return {
		"thigh_l": Vector3(1.25, 0.0, -0.0), "thigh_r": Vector3(1.25, 0.0, -0.0),
		"shin_l": Vector3(-1.6, 0.0, 0.0), "shin_r": Vector3(-1.6, 0.0, 0.0),
		"foot_l": Vector3(0.35, 0.0, 0.0), "foot_r": Vector3(0.35, 0.0, 0.0),
		"spine": Vector3(-0.35, 0.0, 0.0), "chest": Vector3(-0.1 + 0.01 * sway, 0.0, 0.0), "head": Vector3(0.45, 0.0, 0.0),
		"arm_l": Vector3(0.4, 0.0, -0.08), "arm_r": Vector3(0.4, 0.0, 0.08),
		"forearm_l": Vector3(0.6, 0.0, 0.0), "forearm_r": Vector3(0.6, 0.0, 0.0),
		"hips_move": Vector3(0.0, -0.36, 0.2),
	}


func _sit(p: float) -> Dictionary:
	var breath: float = sin(TAU * p)
	return {
		"thigh_l": Vector3(1.5708, 0.0, -0.05), "thigh_r": Vector3(1.5708, 0.0, 0.05),
		"shin_l": Vector3(-1.5708, 0.0, 0.0), "shin_r": Vector3(-1.5708, 0.0, 0.0),
		"chest": Vector3(0.02 * breath, 0.0, 0.0),
		"arm_l": Vector3(0.25, 0.0, -0.05), "arm_r": Vector3(0.25, 0.0, 0.05),
		"forearm_l": Vector3(0.9, 0.0, 0.0), "forearm_r": Vector3(0.9, 0.0, 0.0),
		"hips_move": Vector3(0.0, -0.45, 0.0),
	}


# On the back, head toward +Z (the node's origin stays under the hips).
func _lie(p: float) -> Dictionary:
	var breath: float = sin(TAU * p)
	return {
		"hips": Vector3(1.5708, 0.0, 0.0),
		"chest": Vector3(0.02 * breath, 0.0, 0.0),
		"arm_l": Vector3(0.0, 0.0, -0.12), "arm_r": Vector3(0.0, 0.0, 0.12),
		"forearm_l": Vector3(0.1, 0.0, 0.0), "forearm_r": Vector3(0.1, 0.0, 0.0),
		"thigh_l": Vector3(0.0, 0.0, -0.06), "thigh_r": Vector3(0.0, 0.0, 0.06),
		"hips_move": Vector3(0.0, -0.77, 0.0),
	}


# Right arm over the head and down, both hands on the tool (an axe or a pick).
func _swing(p: float) -> Dictionary:
	var arm: float = _keys([[0.0, 0.2], [0.35, 3.0], [0.55, 0.5], [1.0, 0.2]], p)
	var elbow: float = _keys([[0.0, 0.12], [0.35, 0.8], [0.55, 0.2], [1.0, 0.12]], p)
	var lean: float = _keys([[0.0, 0.0], [0.35, 0.15], [0.55, -0.35], [1.0, 0.0]], p)
	return {
		"arm_r": Vector3(arm, 0.0, 0.07), "forearm_r": Vector3(elbow, 0.0, 0.0),
		"arm_l": Vector3(arm * 0.75, 0.0, -0.1), "forearm_l": Vector3(elbow + 0.2, 0.0, 0.0),
		"spine": Vector3(lean, 0.0, 0.0), "chest": Vector3(lean * 0.5, 0.0, 0.0),
		"hips_move": Vector3(0.0, -0.05 * maxf(lean * -1.0, 0.0), 0.0),
	}


# A thrust straight ahead from the shoulder (a spear).
func _jab(p: float) -> Dictionary:
	var arm: float = _keys([[0.0, 0.2], [0.4, 0.9], [0.55, 1.45], [1.0, 0.2]], p)
	var elbow: float = _keys([[0.0, 0.12], [0.4, 1.6], [0.55, 0.05], [1.0, 0.12]], p)
	var twist: float = _keys([[0.0, 0.0], [0.4, 0.3], [0.55, -0.25], [1.0, 0.0]], p)
	return {
		"arm_r": Vector3(arm, 0.0, 0.07), "forearm_r": Vector3(elbow, 0.0, 0.0),
		"arm_l": Vector3(0.8, 0.0, -0.2), "forearm_l": Vector3(0.9, 0.0, 0.0),
		"spine": Vector3(0.0, twist, 0.0), "chest": Vector3(-0.1 * absf(twist), twist, 0.0),
	}


# Wind up behind the shoulder and let go forward.
func _throw(p: float) -> Dictionary:
	var arm: float = _keys([[0.0, 0.2], [0.45, -1.1], [0.6, 2.0], [1.0, 0.2]], p)
	var elbow: float = _keys([[0.0, 0.12], [0.45, 1.0], [0.6, 0.1], [1.0, 0.12]], p)
	var twist: float = _keys([[0.0, 0.0], [0.45, -0.4], [0.6, 0.35], [1.0, 0.0]], p)
	var lean: float = _keys([[0.0, 0.0], [0.45, 0.25], [0.6, -0.3], [1.0, 0.0]], p)
	var other: float = _keys([[0.0, 0.2], [0.45, 1.2], [0.6, 0.5], [1.0, 0.2]], p)
	return {
		"arm_r": Vector3(arm, 0.0, 0.1), "forearm_r": Vector3(elbow, 0.0, 0.0),
		"arm_l": Vector3(other, 0.0, -0.2), "forearm_l": Vector3(0.3, 0.0, 0.0),
		"spine": Vector3(lean, twist, 0.0), "chest": Vector3(lean * 0.5, twist * 0.6, 0.0),
	}


# Reach out and touch, press or pick: right arm forward, a small push in the middle.
func _use(p: float) -> Dictionary:
	var arm: float = _keys([[0.0, 0.2], [0.3, 1.0], [0.5, 1.25], [0.7, 1.0], [1.0, 0.2]], p)
	var elbow: float = _keys([[0.0, 0.12], [0.3, 0.7], [0.5, 0.45], [0.7, 0.7], [1.0, 0.12]], p)
	return {
		"arm_r": Vector3(arm, 0.0, 0.07), "forearm_r": Vector3(elbow, 0.0, 0.0),
		"arm_l": Vector3(0.0, 0.0, -0.07), "forearm_l": Vector3(0.12, 0.0, 0.0),
		"chest": Vector3(-0.08 * sin(PI * p), 0.0, 0.0), "head": Vector3(0.1 * sin(PI * p), 0.0, 0.0),
	}
