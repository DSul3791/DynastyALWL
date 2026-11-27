extends SkeletonModifier3D

# A tail that drags on the ground whatever clip plays (Dave 27 Nov 2026, the alligator: its clips come from cats, dogs and a fox and "all
# the actions need to let the tail drag on the ground"). Laid over the clip every frame: each tail bone keeps the clip's sideways heading
# (the sway and a tail swipe stay) and is pitched so the next joint lies at its rest-pose height above the floor, sloping down at most
# SLOPE_DEG from a raised body. The rest pose must be the tail lying on the ground (the alligator's is). The floor is the ground the animal
# stands on (`ground`, its node at the ground point, so a ground_clips lift counts; Lane A 27 Nov: a floor taken from the bones left the
# tail 16 cm up in the idle), else the rest pose's lowest body bone or the body's lowest bone now if lower. Skeleton space.
# Data: a models.json row's "tail_drag": [tail bone names, base to tip]; animal_view.gd adds one of these to the model's skeleton.

const SLOPE_DEG := 70.0      # a raised body drops its tail to the ground right behind the hips (35 left it arched up: Lane A 27 Nov)

var chain: PackedInt32Array = PackedInt32Array()
var heights: PackedFloat32Array = PackedFloat32Array()    # each joint's rest height above the rest floor
var lengths: PackedFloat32Array = PackedFloat32Array()    # each bone's rest length, to the next joint
var body: PackedInt32Array = PackedInt32Array()           # every bone not in the tail
var rest_floor: float = 0.0
var tip_rest: Quaternion = Quaternion.IDENTITY
var ground: Node3D = null                                 # the animal's own node, at the ground point under it


func setup(sk: Skeleton3D, names: Array) -> PackedStringArray:
	var missing: PackedStringArray = PackedStringArray()

	for bone_name in names:
		var bone: int = sk.find_bone(str(bone_name))

		if bone < 0:
			missing.append(str(bone_name))
		else:
			chain.append(bone)

	if not missing.is_empty() or chain.size() < 2:
		chain.clear()
		return missing

	rest_floor = INF

	for i in sk.get_bone_count():
		if not chain.has(i):
			body.append(i)
			rest_floor = minf(rest_floor, global_of(sk, i, true).origin.y)

	for c in chain.size():
		var at: Vector3 = global_of(sk, chain[c], true).origin
		heights.append(at.y - rest_floor)

		if c + 1 < chain.size():
			lengths.append(at.distance_to(global_of(sk, chain[c + 1], true).origin))

	tip_rest = sk.get_bone_rest(chain[chain.size() - 1]).basis.get_rotation_quaternion()
	return missing


func _process_modification() -> void:
	var sk: Skeleton3D = get_skeleton()

	if sk == null or chain.is_empty():
		return

	var floor_y: float = rest_floor

	if ground != null and ground.is_inside_tree() and sk.is_inside_tree():
		floor_y = (sk.global_transform.affine_inverse() * ground.global_position).y
	else:
		for b in body:
			floor_y = minf(floor_y, global_of(sk, b).origin.y)

	var most: float = sin(deg_to_rad(SLOPE_DEG))
	var parent_g: Transform3D = global_of(sk, sk.get_bone_parent(chain[0])) if sk.get_bone_parent(chain[0]) >= 0 else Transform3D.IDENTITY

	for c in chain.size() - 1:
		var g: Transform3D = parent_g * sk.get_bone_pose(chain[c])
		var d: Vector3 = g * sk.get_bone_pose_position(chain[c + 1]) - g.origin
		var flat: Vector3 = Vector3(d.x, 0.0, d.z)

		if flat.length_squared() > 1e-10 and d.length_squared() > 1e-10:      # pointing straight up or down: no heading to keep this frame
			var dy: float = clampf(floor_y + heights[c + 1] - g.origin.y, -lengths[c] * most, lengths[c] * most)
			var want: Vector3 = flat.normalized() * sqrt(lengths[c] * lengths[c] - dy * dy) + Vector3(0.0, dy, 0.0)
			g.basis = Basis(Quaternion(d.normalized(), want.normalized())) * g.basis
			sk.set_bone_pose_rotation(chain[c], (parent_g.basis.inverse() * g.basis).get_rotation_quaternion())

		parent_g = g

	sk.set_bone_pose_rotation(chain[chain.size() - 1], tip_rest)      # the tip lies on along the last bone, not curled up as the clip has it


# A bone's pose (or rest) in skeleton space from the local poses up its parents. Not get_bone_global_pose: its cache was not brought up to date
# (Lane A 27 Nov 2026: every global pose read 0 in the test), and the local poses are what the clip and this modifier set.
static func global_of(sk: Skeleton3D, bone: int, rest: bool = false) -> Transform3D:
	var g: Transform3D = sk.get_bone_rest(bone) if rest else sk.get_bone_pose(bone)
	var up: int = sk.get_bone_parent(bone)

	while up >= 0:
		g = (sk.get_bone_rest(up) if rest else sk.get_bone_pose(up)) * g
		up = sk.get_bone_parent(up)

	return g
