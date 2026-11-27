extends SkeletonModifier3D

# Legs held out to the sides like a real alligator's (Dave 27 Nov 2026: "bend his legs more like a real alligator"; its borrowed cat
# and dog clips walk on upright legs). Laid over the clip every frame: each listed leg bone keeps the clip's fore-and-aft swing and lift
# but is turned about the body's long axis (skeleton Z) to the rest pose's sideways angle, so the elbows and knees stand out and bend as
# in the rest pose (the alligator's lies belly down, legs sprawled). Off while the body is rolled onto its side (a death clip).
# Data: a models.json row's "leg_sprawl": [[root bone, ..., end bone] per leg], the first two a left and right pair.

const TailDrag := preload("res://src/client/tail_drag.gd")
const ROLLED := 0.5      # the line between the first pair's roots this steep (sin 30 degrees): the body is on its side

var legs: Array = []          # PackedInt32Array per leg, root to end
var rest_side: Array = []     # PackedFloat32Array per leg: each bone's sideways angle at rest


static func side_angle(d: Vector3) -> float:
	return atan2(d.x, -d.y)      # 0 straight down, + out toward +X


func setup(sk: Skeleton3D, table: Array) -> PackedStringArray:
	var missing: PackedStringArray = PackedStringArray()

	for names in table:
		var chain: PackedInt32Array = PackedInt32Array()

		for bone_name in names:
			var bone: int = sk.find_bone(str(bone_name))

			if bone < 0:
				missing.append(str(bone_name))
			else:
				chain.append(bone)

		if chain.size() < 2 or chain.size() != (names as Array).size():
			continue

		var angles: PackedFloat32Array = PackedFloat32Array()

		for c in chain.size() - 1:
			angles.append(side_angle(TailDrag.global_of(sk, chain[c + 1], true).origin - TailDrag.global_of(sk, chain[c], true).origin))

		legs.append(chain)
		rest_side.append(angles)

	return missing


func _process_modification() -> void:
	var sk: Skeleton3D = get_skeleton()

	if sk != null:
		apply(sk)


# The legs turned out on the skeleton's current poses (called by the modifier each frame; the test calls it directly).
func apply(sk: Skeleton3D) -> void:
	if legs.is_empty():
		return

	if legs.size() >= 2:
		var across: Vector3 = TailDrag.global_of(sk, legs[0][0]).origin - TailDrag.global_of(sk, legs[1][0]).origin

		if across.length_squared() > 1e-10 and absf(across.normalized().y) > ROLLED:
			return

	for l in legs.size():
		var chain: PackedInt32Array = legs[l]
		var up: int = sk.get_bone_parent(chain[0])
		var parent_g: Transform3D = TailDrag.global_of(sk, up) if up >= 0 else Transform3D.IDENTITY

		for c in chain.size() - 1:
			var g: Transform3D = parent_g * sk.get_bone_pose(chain[c])
			var d: Vector3 = g.basis * sk.get_bone_pose_position(chain[c + 1])

			if Vector2(d.x, d.y).length_squared() > 1e-10:
				var turn: float = wrapf(float(rest_side[l][c]) - side_angle(d), -PI, PI)
				g.basis = Basis(Vector3.BACK, turn) * g.basis
				sk.set_bone_pose_rotation(chain[c], (parent_g.basis.inverse() * g.basis).get_rotation_quaternion())

			parent_g = g
