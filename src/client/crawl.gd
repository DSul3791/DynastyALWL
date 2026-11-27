extends SkeletonModifier3D

# A real alligator's crawl over borrowed cat, dog and fox clips (Dave 27 Nov 2026: "bend his legs more like a real alligator and slow
# down his walk so he crawls like a real alligator"; Lane A at c817c7c3: the clips stand it tall, legs straight under it, hips high).
# Laid over the named clips every frame: the body is pitched level (hips to chest as in the rest pose, at most MAX_PITCH_DEG) and let
# down until the hips are at their rest height (the rest pose lies belly down), never raised; then each leg's upper and lower bones
# are solved so its foot stays where the clip put it (no sliding), pushed out to the rest pose's width, the elbow or knee bending out
# to the side; the foot keeps the clip's turn. Off while the body is rolled onto its side (a death clip) and in other clips (the run
# stays a high walk). Data: a models.json row's "crawl": {"hips", "chest", "legs": [[upper, lower, foot] per leg, the first two a left
# and right pair], "clips": [clip names]}.

const TailDrag := preload("res://src/client/tail_drag.gd")
const MAX_PITCH_DEG := 25.0
const ROLLED := 0.5        # the line between the first pair's roots this steep (sin 30 degrees): the body is on its side
const POLE_UP := 0.3       # the elbows and knees bend out to the side and a little up

var hips: int = -1
var chest: int = -1
var top: int = -1                                  # the skeleton's root bone above the hips: the whole body moves with it
var rest_hips: Vector3 = Vector3.ZERO
var rest_chest: Vector3 = Vector3.ZERO
var legs: Array = []                               # PackedInt32Array [upper, lower, foot] per leg
var rest_foot_x: PackedFloat32Array = PackedFloat32Array()
var clips: PackedStringArray = PackedStringArray()
var player: AnimationPlayer = null                 # whose clip is playing; none: always on (the test)


func setup(sk: Skeleton3D, spec: Dictionary) -> PackedStringArray:
	var missing: PackedStringArray = PackedStringArray()
	hips = sk.find_bone(str(spec.get("hips", "")))
	chest = sk.find_bone(str(spec.get("chest", "")))

	for pair in [[hips, "hips"], [chest, "chest"]]:
		if int(pair[0]) < 0:
			missing.append(str(spec.get(pair[1], pair[1])))

	for names in spec.get("legs", []):
		var leg: PackedInt32Array = PackedInt32Array()

		for bone_name in names:
			var bone: int = sk.find_bone(str(bone_name))

			if bone < 0:
				missing.append(str(bone_name))
			else:
				leg.append(bone)

		if leg.size() == 3:
			legs.append(leg)
			rest_foot_x.append(TailDrag.global_of(sk, leg[2], true).origin.x)

	if hips < 0 or chest < 0 or legs.size() != (spec.get("legs", []) as Array).size():
		hips = -1
		return missing

	top = hips

	while sk.get_bone_parent(top) >= 0:
		top = sk.get_bone_parent(top)

	rest_hips = TailDrag.global_of(sk, hips, true).origin
	rest_chest = TailDrag.global_of(sk, chest, true).origin
	clips = PackedStringArray(spec.get("clips", []))
	return missing


func _process_modification() -> void:
	var sk: Skeleton3D = get_skeleton()

	if sk != null and (player == null or lowers(str(player.current_animation))):
		apply(sk)


# Whether a clip (its name after any armature or library part) is one the body is let down in.
func lowers(clip: String) -> bool:
	var bare: String = clip.get_slice("|", clip.count("|"))
	return clips.has(bare.get_slice("/", bare.count("/")))


func apply(sk: Skeleton3D) -> void:
	if hips < 0:
		return

	if legs.size() >= 2:
		var across: Vector3 = TailDrag.global_of(sk, legs[0][0]).origin - TailDrag.global_of(sk, legs[1][0]).origin

		if across.length_squared() > 1e-10 and absf(across.normalized().y) > ROLLED:
			return

	var feet: Array = []

	for leg in legs:
		feet.append(TailDrag.global_of(sk, leg[2]))

	# Level and let down: one move of the root bone, turning about the hips.
	var h: Vector3 = TailDrag.global_of(sk, hips).origin
	var c: Vector3 = TailDrag.global_of(sk, chest).origin
	var tilt: float = atan2(c.y - h.y, c.z - h.z) - atan2(rest_chest.y - rest_hips.y, rest_chest.z - rest_hips.z)
	var turn: float = clampf(tilt, -deg_to_rad(MAX_PITCH_DEG), deg_to_rad(MAX_PITCH_DEG))
	var move: Transform3D = Transform3D(Basis.IDENTITY, h) * Transform3D(Basis(Vector3.RIGHT, turn), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -h)
	move.origin.y += minf(0.0, rest_hips.y - (move * h).y)
	var root_pose: Transform3D = move * TailDrag.global_of(sk, top)
	sk.set_bone_pose_position(top, root_pose.origin)
	sk.set_bone_pose_rotation(top, root_pose.basis.get_rotation_quaternion())

	for i in legs.size():
		_solve(sk, legs[i], feet[i], rest_foot_x[i])


# Two-bone leg: the upper and lower bones turned so the foot joint reaches the clip's foot (pushed out to the rest width), the middle
# joint out to the side; the foot keeps the clip's turn.
func _solve(sk: Skeleton3D, leg: PackedInt32Array, foot: Transform3D, wide_x: float) -> void:
	var target: Vector3 = foot.origin

	if absf(target.x) < absf(wide_x):
		target.x = wide_x

	var up_g: Transform3D = TailDrag.global_of(sk, sk.get_bone_parent(leg[0])) if sk.get_bone_parent(leg[0]) >= 0 else Transform3D.IDENTITY
	var a_g: Transform3D = up_g * sk.get_bone_pose(leg[0])
	var b_at: Vector3 = TailDrag.global_of(sk, leg[1]).origin
	var f_at: Vector3 = TailDrag.global_of(sk, leg[2]).origin
	var a: Vector3 = a_g.origin
	var l1: float = a.distance_to(b_at)
	var l2: float = b_at.distance_to(f_at)
	var reach: Vector3 = target - a

	if l1 < 1e-6 or l2 < 1e-6 or reach.length() < 1e-6:
		return

	var u: Vector3 = reach.normalized()
	var d: float = clampf(reach.length(), absf(l1 - l2) + 1e-4, l1 + l2 - 1e-4)
	var cos_a: float = clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var pole: Vector3 = Vector3(signf(wide_x), POLE_UP, 0.0)
	pole = pole - u * u.dot(pole)

	if pole.length_squared() < 1e-10:
		return

	var knee: Vector3 = a + u * (l1 * cos_a) + pole.normalized() * (l1 * sqrt(1.0 - cos_a * cos_a))
	a_g.basis = Basis(Quaternion((b_at - a).normalized(), (knee - a).normalized())) * a_g.basis
	sk.set_bone_pose_rotation(leg[0], (up_g.basis.inverse() * a_g.basis).get_rotation_quaternion())

	var b_g: Transform3D = TailDrag.global_of(sk, leg[1])
	var f_now: Vector3 = TailDrag.global_of(sk, leg[2]).origin
	b_g.basis = Basis(Quaternion((f_now - b_g.origin).normalized(), (a + u * d - b_g.origin).normalized())) * b_g.basis
	sk.set_bone_pose_rotation(leg[1], (TailDrag.global_of(sk, sk.get_bone_parent(leg[1])).basis.inverse() * b_g.basis).get_rotation_quaternion())

	var f_up: Transform3D = TailDrag.global_of(sk, sk.get_bone_parent(leg[2]))
	sk.set_bone_pose_rotation(leg[2], (f_up.basis.inverse() * foot.basis).get_rotation_quaternion())
