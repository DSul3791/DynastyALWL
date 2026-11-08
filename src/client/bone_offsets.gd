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


func _process_modification() -> void:
	var sk: Skeleton3D = get_skeleton()

	if sk == null:
		return

	for bone in offsets:
		sk.set_bone_pose_rotation(bone, sk.get_bone_pose_rotation(bone) * (offsets[bone] as Quaternion))

	for e in ears:
		var swivel: float = ear_max.x * ear_turn * float(e[1])
		var flat: float = ear_max.y * ear_flat
		var q: Quaternion = Quaternion(ear_axes[0] as Vector3, swivel) * Quaternion(ear_axes[1] as Vector3, -flat * float(e[1]))
		sk.set_bone_pose_rotation(int(e[0]), sk.get_bone_pose_rotation(int(e[0])) * q)

	if waves.is_empty() or wave_scale <= 0.001:
		return

	_t += get_process_delta_time()

	for w in waves:
		var angle: float = float(w[2]) * wave_scale * sin(TAU * (_t / float(w[4]) + float(w[3])))
		sk.set_bone_pose_rotation(int(w[0]), sk.get_bone_pose_rotation(int(w[0])) * Quaternion(w[1] as Vector3, angle))
