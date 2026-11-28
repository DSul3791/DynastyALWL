extends SkeletonModifier3D

# A real alligator's crawl over borrowed cat, dog and fox clips (Dave 27 Nov 2026: "bend his legs more like a real alligator and slow
# down his walk so he crawls like a real alligator"; Lane A at c817c7c3: the clips stand it tall, legs straight under it, hips high).
# Laid over the named clips every frame: the body is pitched level (hips to chest as in the rest pose, at most MAX_PITCH_DEG) and let
# down until the hips are at their rest height (the rest pose lies belly down), never raised; then each leg's upper and lower bones
# are solved so its foot stays where the clip put it (no sliding), pushed out to the rest pose's width, the elbow or knee bending out
# to the side; the foot keeps the clip's turn. Off while the body is rolled onto its side (a death clip) and in other clips (the run
# stays a high walk). The attacks (Dave 28 Nov: the bite and tail swipe "still hunch like a cat"; the leopard's pounce leaps, its feet
# off the ground, and arches the back) are laid flatter still: no pitch of the root, every spine bone from the hips to the head keeps
# the clip's sideways heading but its rest slope (the back flat, the head low, a sideways snap or sweep stays), the feet at their rest
# height on the ground. Data: a models.json row's "crawl": {"hips", "chest", "legs": [[upper, lower, foot] per leg, the first two a left
# and right pair], "clips": [clip names], "flat": [clip names laid flat, among clips], "spine": [bone names, hips to head]}.

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
var rest_foot_y: PackedFloat32Array = PackedFloat32Array()
var clips: PackedStringArray = PackedStringArray()
var flat_clips: PackedStringArray = PackedStringArray()
var spine: PackedInt32Array = PackedInt32Array()      # hips to head
var spine_dy: PackedFloat32Array = PackedFloat32Array()  # each spine joint's rest rise to the next
var flat_now: bool = false                         # the playing clip is one laid flat (always, with no player: the test)
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
			rest_foot_y.append(TailDrag.global_of(sk, leg[2], true).origin.y)

	for bone_name in spec.get("spine", []):
		var bone: int = sk.find_bone(str(bone_name))

		if bone < 0:
			missing.append(str(bone_name))
		else:
			spine.append(bone)

	if spine.size() != (spec.get("spine", []) as Array).size() or spine.size() < 2:
		spine.clear()

	for c in spine.size() - 1:
		spine_dy.append(TailDrag.global_of(sk, spine[c + 1], true).origin.y - TailDrag.global_of(sk, spine[c], true).origin.y)

	if hips < 0 or chest < 0 or legs.size() != (spec.get("legs", []) as Array).size():
		hips = -1
		return missing

	top = hips

	while sk.get_bone_parent(top) >= 0:
		top = sk.get_bone_parent(top)

	rest_hips = TailDrag.global_of(sk, hips, true).origin
	rest_chest = TailDrag.global_of(sk, chest, true).origin
	clips = PackedStringArray(spec.get("clips", []))
	flat_clips = PackedStringArray(spec.get("flat", []))
	return missing


func _process_modification() -> void:
	var sk: Skeleton3D = get_skeleton()

	if sk != null and (player == null or lowers(str(player.current_animation))):
		flat_now = player == null or flat(str(player.current_animation))
		apply(sk)


# Whether a clip (its name after any armature or library part) is one the body is let down in.
func lowers(clip: String) -> bool:
	return clips.has(_bare(clip))


# Whether a clip is one laid flat (an attack).
func flat(clip: String) -> bool:
	return flat_clips.has(_bare(clip))


static func _bare(clip: String) -> String:
	var bare: String = clip.get_slice("|", clip.count("|"))
	return bare.get_slice("/", bare.count("/"))


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
	var laid: bool = flat_now and not spine.is_empty()
	var turn: float = 0.0 if laid else clampf(tilt, -deg_to_rad(MAX_PITCH_DEG), deg_to_rad(MAX_PITCH_DEG))   # laid: the spine bones level it, whichever way it faces
	var move: Transform3D = Transform3D(Basis.IDENTITY, h) * Transform3D(Basis(Vector3.RIGHT, turn), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -h)
	move.origin.y += minf(0.0, rest_hips.y - (move * h).y)
	var root_pose: Transform3D = move * TailDrag.global_of(sk, top)
	sk.set_bone_pose_position(top, root_pose.origin)
	sk.set_bone_pose_rotation(top, root_pose.basis.get_rotation_quaternion())

	if laid:
		_lay_spine(sk)

		for i in legs.size():
			var on_ground: Transform3D = feet[i]
			on_ground.origin.y = rest_foot_y[i]
			feet[i] = on_ground

	for i in legs.size():
		_solve(sk, legs[i], feet[i], rest_foot_x[i])


# Each spine bone turned so the next joint rises from it as in the rest pose, keeping the clip's sideways heading (as tail_drag.gd lays
# the tail): the back flat and the head low, a bone pointing straight up or down left as the clip has it.
func _lay_spine(sk: Skeleton3D) -> void:
	var up: int = sk.get_bone_parent(spine[0])
	var parent_g: Transform3D = TailDrag.global_of(sk, up) if up >= 0 else Transform3D.IDENTITY

	for c in spine.size() - 1:
		var g: Transform3D = parent_g * sk.get_bone_pose(spine[c])
		var d: Vector3 = g * sk.get_bone_pose_position(spine[c + 1]) - g.origin
		var level: Vector3 = Vector3(d.x, 0.0, d.z)
		var length: float = d.length()

		if level.length_squared() > 1e-10 and length > 1e-6:
			var dy: float = clampf(spine_dy[c], -0.95 * length, 0.95 * length)
			var want: Vector3 = level.normalized() * sqrt(length * length - dy * dy) + Vector3(0.0, dy, 0.0)
			g.basis = Basis(Quaternion(d.normalized(), want.normalized())) * g.basis
			sk.set_bone_pose_rotation(spine[c], (parent_g.basis.inverse() * g.basis).get_rotation_quaternion())

		parent_g = g


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
