extends SkeletonModifier3D

# Per-species bone corrections laid over whatever clip plays (Dave 8 Nov 2026: "doesn't the crow have a skeleton in it and you
# can manipulate it to make it stand upright?"). A bought model whose clips hold a pose we do not want (the crow hunched with its
# wings half raised) keeps its clips; this modifier turns chosen bones a fixed amount after the animation is applied, every frame.
# Data: a models.json row's "bone_offsets" {bone name: [x, y, z] degrees, in the bone's own axes}; animal_view.gd adds one of these
# to the model's skeleton. A bone name the skeleton lacks is skipped with a note.

var offsets: Dictionary = {}      # bone index -> Quaternion
var waves: Array = []             # [bone, axis Vector3, swing radians, phase 0..1, period s]: a tail wag, flick or swish laid over the clip
var wave_scale: float = 0.0       # 0 still to 1 full swing; animal_view sets it from what the animal is doing (tail_motion)
var ears: Array = []              # [bone, side +1 left / -1 right]: the ear roots that swivel and flatten (ear_motion)
var ear_axes: Array = [Vector3.UP, Vector3.RIGHT]      # swivel axis, flatten axis (in the bone's own axes)
var ear_max: Vector2 = Vector2(0.7, 0.9)              # largest swivel and flatten, radians
var ear_turn: float = 0.0         # -1 .. 1: both ears turned toward a sound on the animal's left (+) or right (-)
var ear_flat: float = 0.0         # 0 up .. 1 laid back (threatened)
var breath_bone: int = -1         # the chest or spine bone that swells (breath)
var breath_axes: Vector3 = Vector3(1.0, 0.0, 1.0)      # which of the bone's axes swell (not the one along the spine)
var breath_swell: float = 0.03
var breath_per_min: float = 15.0
var breath_rate: float = 1.0      # animal_view: 2 just after a run, settling to 1
var breath_on: float = 0.0        # animal_view: 0 while moving fast, 1 at rest
var _breath_phase: float = 0.0
var look_bones: PackedInt32Array = PackedInt32Array()   # neck to head (look): they share the turn toward the target
var look_max: float = 1.2         # radians the whole neck may turn
var look_target: Vector3 = Vector3.ZERO      # world position looked at (animal_view: the camera)
var look_weight: float = 0.0      # 0 the clip's own head to 1 looking at the target
var _t: float = 0.0


func setup(sk: Skeleton3D, table: Dictionary) -> PackedStringArray:
	var missing: PackedStringArray = PackedStringArray()

	for bone_name in table:
		var bone: int = sk.find_bone(str(bone_name))

		if bone < 0:
			missing.append(str(bone_name))
			continue

		var deg: Array = table[bone_name]
		offsets[bone] = Quaternion.from_euler(Vector3(deg_to_rad(float(deg[0])), deg_to_rad(float(deg[1])), deg_to_rad(float(deg[2]))))

	return missing


# Tail motion (docs/design/TAIL_MOTION.md): a models.json row's "tail_motion" {period_s, bones {bone: [phase, swing degrees, axis]}}.
func setup_waves(sk: Skeleton3D, spec: Dictionary) -> PackedStringArray:
	var missing: PackedStringArray = PackedStringArray()
	var period: float = float(spec.get("period_s", 0.6))

	for bone_name in (spec.get("bones", {}) as Dictionary):
		var bone: int = sk.find_bone(str(bone_name))

		if bone < 0:
			missing.append(str(bone_name))
			continue

		var b: Array = spec["bones"][bone_name]
		var axis: Vector3 = {"x": Vector3.RIGHT, "y": Vector3.UP, "z": Vector3.BACK}.get(str(b[2]) if b.size() > 2 else "y", Vector3.UP)
		waves.append([bone, axis, deg_to_rad(float(b[1])), float(b[0]), period])

	return missing


# Ear motion (docs/design/EAR_AND_BREATH.md): a row's "ear_motion" {left: bone, right: bone, swivel_axis, flatten_axis, swivel_deg, flatten_deg}.
func setup_ears(sk: Skeleton3D, spec: Dictionary) -> PackedStringArray:
	var missing: PackedStringArray = PackedStringArray()
	var axes: Dictionary = {"x": Vector3.RIGHT, "y": Vector3.UP, "z": Vector3.BACK}
	ear_axes = [axes.get(str(spec.get("swivel_axis", "y")), Vector3.UP), axes.get(str(spec.get("flatten_axis", "x")), Vector3.RIGHT)]
	ear_max = Vector2(deg_to_rad(float(spec.get("swivel_deg", 40.0))), deg_to_rad(float(spec.get("flatten_deg", 50.0))))

	for side in [["left", 1.0], ["right", -1.0]]:
		var bone: int = sk.find_bone(str(spec.get(side[0], "")))

		if bone < 0:
			missing.append(str(spec.get(side[0], "")))
			continue

		ears.append([bone, side[1]])

	return missing


# Breathing (docs/design/EAR_AND_BREATH.md section 2): a row's "breath" {bone, per_min, swell, long_axis}.
func setup_breath(sk: Skeleton3D, spec: Dictionary) -> PackedStringArray:
	breath_bone = sk.find_bone(str(spec.get("bone", "")))
	breath_per_min = float(spec.get("per_min", 15.0))
	breath_swell = float(spec.get("swell", 0.03))
	var long_axis: String = str(spec.get("long_axis", "y"))
	breath_axes = Vector3(0.0 if long_axis == "x" else 1.0, 0.0 if long_axis == "y" else 1.0, 0.0 if long_axis == "z" else 1.0)
	return PackedStringArray() if breath_bone >= 0 else PackedStringArray([str(spec.get("bone", ""))])


# Head tracking (docs/design/HEAD_TRACKING.md): a row's "look" {bones [neck ... head], max_deg}.
func setup_look(sk: Skeleton3D, spec: Dictionary) -> PackedStringArray:
	var missing: PackedStringArray = PackedStringArray()
	look_max = deg_to_rad(float(spec.get("max_deg", 70.0)))

	for bone_name in spec.get("bones", []):
		var bone: int = sk.find_bone(str(bone_name))

		if bone < 0:
			missing.append(str(bone_name))
		else:
			look_bones.append(bone)

	return missing


func _process_modification() -> void:
	var sk: Skeleton3D = get_skeleton()

	if sk == null:
		return

	for bone in offsets:
		sk.set_bone_pose_rotation(bone, sk.get_bone_pose_rotation(bone) * (offsets[bone] as Quaternion))

	if breath_bone >= 0 and breath_on > 0.001:
		_breath_phase = fmod(_breath_phase + get_process_delta_time() * breath_per_min * breath_rate / 60.0, 1.0)
		var swell: float = 1.0 + breath_swell * breath_on * breath_rate * (0.5 - 0.5 * cos(TAU * _breath_phase))
		var grow: Vector3 = Vector3.ONE + breath_axes * (swell - 1.0)
		sk.set_bone_pose_scale(breath_bone, sk.get_bone_pose_scale(breath_bone) * grow)

	for e in ears:
		var swivel: float = ear_max.x * ear_turn * float(e[1])
		var flat: float = ear_max.y * ear_flat
		var q: Quaternion = Quaternion(ear_axes[0] as Vector3, swivel) * Quaternion(ear_axes[1] as Vector3, -flat * float(e[1]))
		sk.set_bone_pose_rotation(int(e[0]), sk.get_bone_pose_rotation(int(e[0])) * q)

	if look_bones.size() >= 2 and look_weight > 0.001:
		_look(sk)

	if waves.is_empty() or wave_scale <= 0.001:
		return

	_t += get_process_delta_time()

	for w in waves:
		var angle: float = float(w[2]) * wave_scale * sin(TAU * (_t / float(w[4]) + float(w[3])))
		sk.set_bone_pose_rotation(int(w[0]), sk.get_bone_pose_rotation(int(w[0])) * Quaternion(w[1] as Vector3, angle))



# Turn the neck and head so the head points at look_target. Axis-free: the turn is the one that carries the line from the neck base
# to the head onto the line from the neck base to the target, clamped to look_max and scaled by look_weight, and each bone takes an
# equal share about its own pivot, so the neck curves instead of the head snapping round.
func _look(sk: Skeleton3D) -> void:
	var target: Vector3 = sk.global_transform.affine_inverse() * look_target
	var base: Vector3 = sk.get_bone_global_pose(look_bones[0]).origin
	var head: Vector3 = sk.get_bone_global_pose(look_bones[look_bones.size() - 1]).origin
	var now_dir: Vector3 = head - base
	var want_dir: Vector3 = target - base

	if now_dir.length() < 0.0001 or want_dir.length() < 0.0001:
		return

	var turn: Quaternion = Quaternion(now_dir.normalized(), want_dir.normalized())
	var angle: float = turn.get_angle()

	if angle > look_max:
		turn = Quaternion.IDENTITY.slerp(turn, look_max / angle)

	var share: Quaternion = Quaternion.IDENTITY.slerp(turn, look_weight / float(look_bones.size()))

	for bone in look_bones:
		var parent: int = sk.get_bone_parent(bone)
		var p_basis: Basis = sk.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
		var local_turn: Quaternion = (p_basis.inverse() * Basis(share) * p_basis).get_rotation_quaternion()
		sk.set_bone_pose_rotation(bone, local_turn * sk.get_bone_pose_rotation(bone))
