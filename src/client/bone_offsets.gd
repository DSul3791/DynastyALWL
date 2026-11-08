extends SkeletonModifier3D

# Per-species bone corrections laid over whatever clip plays (Dave 8 Nov 2026: "doesn't the crow have a skeleton in it and you
# can manipulate it to make it stand upright?"). A bought model whose clips hold a pose we do not want (the crow hunched with its
# wings half raised) keeps its clips; this modifier turns chosen bones a fixed amount after the animation is applied, every frame.
# Data: a models.json row's "bone_offsets" {bone name: [x, y, z] degrees, in the bone's own axes}; animal_view.gd adds one of these
# to the model's skeleton. A bone name the skeleton lacks is skipped with a note.

var offsets: Dictionary = {}      # bone index -> Quaternion


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


func _process_modification() -> void:
	var sk: Skeleton3D = get_skeleton()

	if sk == null:
		return

	for bone in offsets:
		sk.set_bone_pose_rotation(bone, sk.get_bone_pose_rotation(bone) * (offsets[bone] as Quaternion))
