extends SkeletonModifier3D

# A hand closed on what it holds (BugsList 177, picture checker 26 Nov 2026: "a smooth fingerless ball at the wrist with the shaft through it, and the open real
# hand below"). Dave's body has no finger bones, so since his decision card of 5 Nov a skin-coloured ball was drawn round every third-person grip (held_item.gd
# third_fist_on); the hand stayed open and its fingers hung below the ball. Here, while a hand mount holds something drawn, the hand bone is drawn shorter along
# its length (CLOSED_LENGTH, about where the knuckles of a fist are) and a little thicker, so the real hand sits round the grip like a closed hand, in the body's
# own skin, and the ball is not drawn (held_item.gd hand_closes). The mount hangs on a bone of its own under the hand (dynasty_body.gd GRIP_BONE) whose scale
# undoes the hand's, so the tool keeps its size and turn even read before the modifiers ran; the grip point comes in with the shorter hand. It eases in and out over EASE_S, so changing what is held never pops. Drawing only: the hand mesh and the mounts.
# Made by dynasty_body.gd under the skeleton, after the Proportions modifier (which writes the hand's own scale each frame); `body` is the body node.

const P := "mixamorig_"
const CLOSED_LENGTH := 0.9    # the hand's length while closed: a little shorter, the curled fingers do the rest
const CLOSED_THICK := 1.1     # and its thickness: the curled fingers stand off the palm
# The fingers curl round the handle (coordinator's look at the laptop pictures, 27 Nov 2026: the fingers stayed open and splayed, the handle lay against the
# palm). Dave's glb has no finger bones, so each hand gets one made here (add_finger_bones): the hand's vertices past the knuckles (KNUCKLE_SHARE of the hand
# mesh's length from the wrist, eased over BLEND_SHARE either side) are skinned to it instead of the hand, and while the hand holds it turns CURL_DEG toward
# the palm about the line of the knuckles. One fixed curl for every held item, good enough (Dave, 27 Nov: "good enough is a good rule").
const FINGERS_BONE := "HandFingers"   # P + side + this
const CURL_DEG := 100.0
const KNUCKLE_SHARE := 0.5
const BLEND_SHARE := 0.08
const CURL_META := "finger_curl_axis"   # on the skeleton: side -> the curl axis in the finger bone's frame
static var _fingered: Dictionary = {}   # source mesh rid -> [ArrayMesh, Skin, {"Right": rest, "Left": rest}], made once for every body that shares the mesh
static var _keep: Array = []            # the source meshes, held so their rids stay theirs
const EASE_S := 0.12
const GRIP_BONE := "HandGrip"   # P + side + this: the bone under each hand that its mount hangs on (dynasty_body.gd _build_mounts)
const FIST_NAME := "ThirdFist"   # held_item.gd THIRD_FIST_NAME

static var closes: bool = true   # false: the old ball fist instead (tools/shot_held.gd and body_pose_shot.gd --fist=ball, for before and after pictures)

var body: Node3D
var closed: Array = [0.0, 0.0]   # right, left: 0 open, 1 closed
var _hands: Array = [-2, -2]     # bone index of the right and left hand, found on the first frame
var _grips: Array = [-1, -1]     # and of the bone under each that its mount hangs on (dynasty_body.gd GRIP_BONE)
var _mounts: Array = [null, null]
var _open_written: Array = [false, false]
var _axes: Array = [-1, -1]      # each hand bone's own axis that runs along the hand (wrist to fingers)
var _thick: Array = [-1, -1]     # and the one that runs through the palm (back of the hand to the palm)
var _fingers: Array = [-1, -1]   # each hand's finger bone (add_finger_bones), -1 on a body without one
var _curl_axis: Array = [Vector3.ZERO, Vector3.ZERO]   # in the finger bone's frame: turning about it by +angle curls the fingers toward the palm


# The hand bone's scale for a closed share `c` (0 open, 1 closed): shorter along `along`, thicker along `thick`.
static func closed_scale(c: float, along: int, thick: int) -> Vector3:
	var k: Vector3 = Vector3.ONE

	if along >= 0:
		k[along] = lerpf(1.0, CLOSED_LENGTH, c)

	if thick >= 0:
		k[thick] = lerpf(1.0, CLOSED_THICK, c)

	return k


# Whether a hand mount holds something gripped: a drawn model with the grip's fist on it (held_item.gd third_fist_on, the ball's old place). Food and
# small things carried in the palm (kits) get no fist, so their hand stays as it was. The player's own third-person bow hand gets one (held_item.gd), other players' bow does not (player_view.gd hold_in).
static func holds(mount: Node3D) -> bool:
	if mount == null or not mount.is_visible_in_tree():
		return false

	for child in mount.get_children():
		if child is Node3D and (child as Node3D).visible:
			var fist: Node3D = (child as Node3D).get_node_or_null(FIST_NAME) as Node3D

			if fist != null and fist.visible:
				return true

	return false


func _process_modification_with_delta(delta: float) -> void:
	var s: Skeleton3D = get_skeleton()

	if s == null or body == null or not is_instance_valid(body):
		return

	if int(_hands[0]) == -2:
		_find(s)

	for side in 2:
		var i: int = int(_hands[side])
		var mount: Marker3D = _mounts[side] as Marker3D

		if i < 0 or int(_grips[side]) < 0 or mount == null or not is_instance_valid(mount):
			continue

		var want: float = 1.0 if closes and holds(mount) else 0.0
		closed[side] = move_toward(float(closed[side]), want, delta / EASE_S)

		if float(closed[side]) <= 0.0 and bool(_open_written[side]):
			continue   # open and already put back: nothing to write (the bones' own poses are the clip's)

		var k: Vector3 = closed_scale(float(closed[side]), int(_axes[side]), int(_thick[side]))
		var own: float = float(body.call("hand_scale"))   # the creator's hand slider (Proportions writes it each frame; written whole again here, so it never adds up)
		s.set_bone_pose_scale(i, Vector3.ONE * own * k)
		s.set_bone_pose_scale(int(_grips[side]), Vector3.ONE / k)   # undone on the mount's own bone: the mount never carries the hand's scale

		if int(_fingers[side]) >= 0 and (_curl_axis[side] as Vector3) != Vector3.ZERO:
			s.set_bone_pose_rotation(int(_fingers[side]), Quaternion(_curl_axis[side] as Vector3, deg_to_rad(CURL_DEG) * float(closed[side])))

		var base: Transform3D = body.call("mount_base", mount)
		mount.transform = Transform3D(base.basis, base.origin * k)   # the grip comes in with the shorter hand
		_open_written[side] = float(closed[side]) <= 0.0


# Each hand's bone, its axis along the hand (the forearm's direction at rest, read in the hand bone's own frame) and the palm's axis (the body's front at rest,
# as dynasty_body.gd _mount takes it). At rest the arms are out and the palms down, so the front runs across the knuckles and the remaining axis through the palm.
func _find(s: Skeleton3D) -> void:
	for side in 2:
		var side_name: String = ["Right", "Left"][side]
		var hand: int = s.find_bone(P + side_name + "Hand")
		var fore: int = s.find_bone(P + side_name + "ForeArm")
		_hands[side] = hand
		_grips[side] = s.find_bone(P + side_name + GRIP_BONE)
		_fingers[side] = s.find_bone(P + side_name + FINGERS_BONE)
		_mounts[side] = body.get(["hand_mount_r", "hand_mount_l"][side])

		if hand < 0 or fore < 0:
			continue

		var rest: Basis = s.get_bone_global_rest(hand).basis.orthonormalized()
		var along: Vector3 = rest.inverse() * (s.get_bone_global_rest(hand).origin - s.get_bone_global_rest(fore).origin).normalized()
		var front: Vector3 = rest.inverse() * Vector3(0.0, 0.0, 1.0)
		_axes[side] = along.abs().max_axis_index()

		if absf(along[int(_axes[side])]) < 0.9:
			push_warning("dynasty_grip: the %s hand bone does not run along the forearm (%s); the closed hand may squash the wrong way" % [side_name, str(along)])

		var rest_axes: Array = [0, 1, 2]
		rest_axes.erase(int(_axes[side]))
		# Of the two axes across the hand, the one nearer the body's front runs across the knuckles (the hand's width); the other goes through the palm.
		_thick[side] = int(rest_axes[1]) if absf(front[int(rest_axes[0])]) > absf(front[int(rest_axes[1])]) else int(rest_axes[0])
		_curl_axis[side] = (s.get_meta(CURL_META, {}) as Dictionary).get(side_name, Vector3.ZERO)   # add_finger_bones: from the hand mesh's own relaxed curl


# Gives each hand of `skeleton` a finger bone (FINGERS_BONE, under the hand at the knuckles, the hand's turn) and skins the hand's vertices past the knuckles
# to it, on a copy of `mesh_inst`'s mesh and skin (made once per source mesh, then shared). Call before the body's shapes and garment layers read the mesh.
# Leaves everything as it was when the mesh is not one skinned body with both hands.
static func add_finger_bones(skeleton: Skeleton3D, mesh_inst: MeshInstance3D) -> void:
	if skeleton == null or mesh_inst == null or mesh_inst.skin == null or not (mesh_inst.mesh is ArrayMesh):
		return

	var key: RID = mesh_inst.mesh.get_rid()

	if not _fingered.has(key):
		_fingered[key] = _make_fingered(mesh_inst.mesh as ArrayMesh, mesh_inst.skin, skeleton)
		_keep.append(mesh_inst.mesh)

	var made: Array = _fingered[key]

	if made.is_empty():
		return

	for side in ["Right", "Left"]:
		if skeleton.find_bone(P + side + FINGERS_BONE) < 0:
			var b: int = skeleton.get_bone_count()
			var rest: Transform3D = (made[2] as Dictionary)[side]
			skeleton.add_bone(P + side + FINGERS_BONE)
			skeleton.set_bone_parent(b, skeleton.find_bone(P + side + "Hand"))
			skeleton.set_bone_rest(b, rest)
			skeleton.set_bone_pose_position(b, rest.origin)
			skeleton.set_bone_pose_rotation(b, Quaternion.IDENTITY)

	skeleton.set_meta(CURL_META, made[3])
	mesh_inst.mesh = made[0]
	mesh_inst.skin = made[1]


static func _bind_of(skin: Skin, skeleton: Skeleton3D, bone_name: String) -> int:
	for i in range(skin.get_bind_count()):
		var n: String = String(skin.get_bind_name(i))

		if n == "" and skin.get_bind_bone(i) >= 0:
			n = skeleton.get_bone_name(skin.get_bind_bone(i))

		if n == bone_name:
			return i

	return -1


static func _make_fingered(src: ArrayMesh, skin: Skin, skeleton: Skeleton3D) -> Array:
	var t0: int = Time.get_ticks_msec()
	var out_skin: Skin = skin.duplicate() as Skin
	var hands: Array = []   # per side: [hand bind, fingers bind, hand head (mesh space), along, knuckle, band]
	var rests: Dictionary = {}
	var axes: Dictionary = {}

	for side in ["Right", "Left"]:
		var hand: int = _bind_of(skin, skeleton, P + side + "Hand")
		var fore: int = _bind_of(skin, skeleton, P + side + "ForeArm")

		if hand < 0 or fore < 0:
			return []

		var hand_rest: Transform3D = skin.get_bind_pose(hand).affine_inverse()   # the hand bone's rest in mesh space
		var head: Vector3 = hand_rest.origin
		var along: Vector3 = (head - skin.get_bind_pose(fore).affine_inverse().origin).normalized()
		hands.append([hand, -1, head, along, 0.0, 0.0, side, hand_rest, []])

	for surface in range(src.get_surface_count()):   # the hand mesh's length from the wrist, from the vertices skinned mostly to it
		var arrays: Array = src.surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
		var per: int = bones.size() / maxi(verts.size(), 1)

		for v in range(verts.size()):
			for j in range(per):
				if weights[v * per + j] <= 0.5:
					continue

				for h in hands:
					if bones[v * per + j] == int(h[0]):
						var d: Vector3 = verts[v] - (h[2] as Vector3)
						var pr: float = d.dot(h[3] as Vector3)
						h[4] = maxf(float(h[4]), pr)
						(h[8] as Array).append(Vector4(d.x, d.y, d.z, pr))

	for h in hands:
		var length: float = float(h[4])

		if length <= 0.0:
			return []

		h[4] = length * KNUCKLE_SHARE
		h[5] = length * BLEND_SHARE
		var hand_rest: Transform3D = h[7]
		var finger_rest: Transform3D = Transform3D(hand_rest.basis, (h[2] as Vector3) + (h[3] as Vector3) * float(h[4]))
		h[1] = out_skin.get_bind_count()
		out_skin.add_named_bind(P + str(h[6]) + FINGERS_BONE, finger_rest.affine_inverse())
		rests[str(h[6])] = hand_rest.affine_inverse() * finger_rest   # under the hand, in its frame: the same in the skeleton's space
		# Which way the fingers curl: the relaxed hand's fingertips already lean toward the palm (Dave's glb: about 4 cm off the hand's line at the tips,
		# against 2.6 cm across the palm), so the palm side is where the tips sit, off the line, against the middle of the hand.
		var tips: Vector3 = Vector3.ZERO
		var mid: Vector3 = Vector3.ZERO
		var n_tips: int = 0
		var n_mid: int = 0

		for q in h[8]:
			var off: Vector3 = Vector3(q.x, q.y, q.z) - (h[3] as Vector3) * q.w

			if q.w > length * 0.8:
				tips += off
				n_tips += 1
			elif q.w > length * 0.3 and q.w < length * 0.5:
				mid += off
				n_mid += 1

		var palm: Vector3 = tips / maxf(float(n_tips), 1.0) - mid / maxf(float(n_mid), 1.0)
		palm -= (h[3] as Vector3) * palm.dot(h[3] as Vector3)
		var axis: Vector3 = (h[3] as Vector3).cross(palm.normalized())   # a right-hand turn about along x palm turns the fingers' length toward the palm
		axes[str(h[6])] = (hand_rest.basis.orthonormalized().inverse() * axis).normalized() if palm.length() > 0.001 else Vector3.ZERO

	var out: ArrayMesh = ArrayMesh.new()

	for surface in range(src.get_surface_count()):
		var arrays: Array = src.surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
		var per: int = bones.size() / maxi(verts.size(), 1)

		for v in range(verts.size()):
			for h in hands:
				var t: float = clampf(((verts[v] - (h[2] as Vector3)).dot(h[3] as Vector3) - (float(h[4]) - float(h[5]))) / (2.0 * float(h[5])), 0.0, 1.0)

				if t <= 0.0:
					continue

				for j in range(per):
					var at: int = v * per + j

					if bones[at] != int(h[0]) or weights[at] <= 0.0:
						continue

					var free: int = -1

					for k in range(per):
						if weights[v * per + k] <= 0.0:
							free = v * per + k
							break

					if t >= 1.0 or (free < 0 and t > 0.5):
						bones[at] = int(h[1])
					elif free >= 0:
						bones[free] = int(h[1])
						weights[free] = weights[at] * t
						weights[at] = weights[at] * (1.0 - t)

		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		out.add_surface_from_arrays(src.surface_get_primitive_type(surface), arrays, src.surface_get_blend_shape_arrays(surface), {}, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0)
		out.surface_set_material(surface, src.surface_get_material(surface))

	print("dynasty grip: finger bones made in %d ms" % (Time.get_ticks_msec() - t0))
	return [out, out_skin, rests, axes]
