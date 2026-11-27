extends SkeletonModifier3D

# A tail that drags on the ground whatever clip plays (Dave 27 Nov 2026, the alligator: its clips come from cats, dogs and a fox and "all
# the actions need to let the tail drag on the ground"). Laid over the clip every frame: each tail bone keeps the clip's sideways heading
# (the sway and a tail swipe stay) and is pitched so the next joint lies at its rest-pose height above the floor, sloping down at most
# SLOPE_DEG from a raised body. The rest pose must be the tail lying on the ground (the alligator's is). The floor is the rest pose's lowest
# body bone, or the body's lowest bone now if the clip lowers it (a lie). Skeleton space, so a death clip that rolls the body still works.
# Data: a models.json row's "tail_drag": [tail bone names, base to tip]; animal_view.gd adds one of these to the model's skeleton.

const SLOPE_DEG := 35.0

var chain: PackedInt32Array = PackedInt32Array()
var heights: PackedFloat32Array = PackedFloat32Array()    # each joint's rest height above the rest floor
var lengths: PackedFloat32Array = PackedFloat32Array()    # each bone's rest length, to the next joint
var body: PackedInt32Array = PackedInt32Array()           # every bone not in the tail
var rest_floor: float = 0.0
var tip_rest: Quaternion = Quaternion.IDENTITY


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
			rest_floor = minf(rest_floor, sk.get_bone_global_rest(i).origin.y)

	for c in chain.size():
		var at: Vector3 = sk.get_bone_global_rest(chain[c]).origin
		heights.append(at.y - rest_floor)

		if c + 1 < chain.size():
			lengths.append(at.distance_to(sk.get_bone_global_rest(chain[c + 1]).origin))

	tip_rest = sk.get_bone_rest(chain[chain.size() - 1]).basis.get_rotation_quaternion()
	return missing


func _process_modification() -> void:
	var sk: Skeleton3D = get_skeleton()

	if sk == null or chain.is_empty():
		return

	var floor_y: float = rest_floor

	for b in body:
		floor_y = minf(floor_y, sk.get_bone_global_pose(b).origin.y)

	var most: float = sin(deg_to_rad(SLOPE_DEG))

	for c in chain.size() - 1:
		var g: Transform3D = sk.get_bone_global_pose(chain[c])
		var d: Vector3 = sk.get_bone_global_pose(chain[c + 1]).origin - g.origin
		var flat: Vector3 = Vector3(d.x, 0.0, d.z)

		if flat.length_squared() < 1e-10 or d.length_squared() < 1e-10:
			continue      # pointing straight up or down: no heading to keep this frame

		var dy: float = clampf(floor_y + heights[c + 1] - g.origin.y, -lengths[c] * most, lengths[c] * most)
		var want: Vector3 = flat.normalized() * sqrt(lengths[c] * lengths[c] - dy * dy) + Vector3(0.0, dy, 0.0)
		g.basis = Basis(Quaternion(d.normalized(), want.normalized())) * g.basis
		sk.set_bone_global_pose(chain[c], g)

	sk.set_bone_pose_rotation(chain[chain.size() - 1], tip_rest)      # the tip lies on along the last bone, not curled up as the clip has it
