extends RefCounted

const FreezeWatchScript := preload("res://src/debug/freeze_watch.gd")

# Width sliders for Dave's body (Kathreen 3 Nov 2026): Build, Muscle, Belly, Hips and Chest as blend shapes made in code from the bind pose, because Dave's glb has none and a
# non-uniform bone scale shears under animation (dynasty_proportions.gd does the lengths). Made once per run, shared by every Dynasty body, and set per body with
# MeshInstance3D.set_blend_shape_value (the creator slider value -1..1 is the weight; a negative weight makes the body thinner, flatter or narrower).
#
# Every vertex is moved in the mesh's own (bind) space, read from the skin: its dominant bone gives a segment from that bone to its child, and
#   build  pushes it away from that segment (the whole body fuller; head, hands and feet only a little),
#   muscle does the same on the arms, legs, shoulders and chest, most in the middle of each segment (bellies of muscle, not swollen joints),
#   belly  pushes the front of the lower trunk forward and a little out, round the navel,
#   hips   widens the pelvis and the tops of the thighs sideways,
#   chest  widens the rib cage and brings the chest forward,
#   bust   fills each breast out into a full, round shape (Dave 20 Nov 2026: "yes we need a bust slider"; 21 Nov: "if you increase the breasts they get pointy they
#          should get big, round and voluptuous"): each breast's own front is found on the mesh, and the chest round it is pushed 60% of the way out onto a rounded
#          shape (an ellipsoid) centred behind that front, straight out from the centre, so the breast grows wide and tall as well as forward. It joins the chest softly above
#          and with a fold below, never at the breastbone, and the shape carries its own normals so the light falls on the round. The bust slider from -1 ("none",
#          every old genome) up to -0.6 (the Even frame, which every new character starts with) leaves the body as modelled, so a new character and one at the Even
#          or Broad frame change only when the slider is moved up (a saved character already set above -0.6, such as the Curved frame's 0.3, shows its bust); +1 is
#          the fullest (shape_weight). The generated body shows its bump from about -0.95.
# and on the face (found from the head's own vertices: the nose tip is the head vertex furthest forward near the middle; Kathreen 3 Nov 2026, the creator's face sliders):
#   jaw    widens the lower face and brings the chin forward,
#   nose   makes the nose bigger and longer (push forward, grow round its tip),
#   brow   brings the brow ridge forward over the eyes,
#   ears   stands the ears out from the head.
# Sizes are fractions of the body's height in mesh units, so they hold whatever unit Dave exported in.

const P := "mixamorig_"
const NAMES := ["build", "muscle", "belly", "hips", "chest", "bust", "jaw", "nose", "brow", "ears"]
const BUST_FROM := -0.6          # the bust slider value where the mound starts: body_generator.gd FRAMES "neutral" (shown as Even), the frame a new character starts with
# The bust, as fractions of the body's height. Each breast's front is looked for in a strip BUST_OUT out to the side and about BUST_DOWN under the Spine2 joint
# (its most forward vertex there, the two sides averaged into a mirror pair). The round shape's centre sits BUST_DEPTH behind that front; at +1 the front comes
# BUST_FORWARD x (1 - BUST_KEEP) forward and the shape is BUST_WIDE across and BUST_TALL high each way from its centre. It joins the chest within BUST_SOFT_UP above its centre and
# BUST_SOFT_DOWN below (the fold under the breast). Checked offline on both bodies' meshes (21 Nov 2026): round from the front, the side and three-quarters.
const BUST_OUT := 0.055
const BUST_DOWN := 0.06
const BUST_DEPTH := 0.07
const BUST_FORWARD := 0.06
const BUST_WIDE := 0.046
const BUST_TALL := 0.05
const BUST_SOFT_UP := 0.02
const BUST_SOFT_DOWN := 0.012
const BUST_KEEP := 0.4         # each vertex goes only 60% of the way onto the shape, so the chest keeps 40% of its own relief: the top's folds and creases keep their order
                                # (all the way, they met on the shape and showed through one another in Lane A's pictures of 80e0542c, 21 Nov 2026)
const SHAPED_KEY := "dynasty_shapes"
# Skin under worn clothes (BugsList 187; the laptop picture check of 26 Nov 2026 saw skin through 58 of 79 worn items: shins, knees, feet, hands and the midriff out
# through the rigid worn pieces, worn_look.gd). One more shape per group of bones, "cover_<group>": every vertex whose strongest bone is in the group moves COVER_IN of
# the body's height in toward its bone (at most COVER_MAX of its distance from it), so the skin sits inside the pieces. worn_look.gd attach sets weight 1 on the groups
# a worn piece covers (dynasty_body.gd cover). Not the head or the neck: hats and hoods leave the face as it is.
const COVERS := ["hips", "chest", "arm", "forearm", "hand", "thigh", "shin", "foot"]
const COVER_IN := 0.012
const COVER_MAX := 0.4

static var _cache: Dictionary = {}       # source mesh rid -> shaped ArrayMesh (or null when it could not be made)
static var _keep: Array = []             # the source meshes of _cache, held so their rids stay theirs
static var _job: int = -1                # the prewarm task on the worker pool, or -1


# Dave 3 Nov 2026 (lag): making the shapes takes about 0.2 s, and it fell on the first NPC or player with a width or face slider, on the main thread.
# prewarm() reads the first body's mesh on the main thread (_gather, a few ms) and does the arithmetic on a worker thread (_compute); shaped() waits for it and
# builds the mesh (_finish). The worker touches no node, resource or server: instancing the scene or loading the glb there hung the game headless (4 Nov).
# dynasty_body.gd starts it with the first body and waits for it when a body is freed, so no task outlives the program.
static var _pending: Dictionary = {}     # the prewarm's data while the worker computes it, and its source mesh


# The cover group of a bone (Mixamo name without the prefix), or "" for bones never covered (head, neck, shoulders).
static func cover_group(bone: String) -> String:
	if bone == "Hips":
		return "hips"

	if bone.begins_with("Spine"):
		return "chest"

	if bone.ends_with("ForeArm"):
		return "forearm"

	if bone.ends_with("Arm"):
		return "arm"

	if bone.contains("Hand"):
		return "hand"

	if bone.ends_with("UpLeg"):
		return "thigh"

	if bone.ends_with("Leg"):
		return "shin"

	if bone.contains("Foot") or bone.contains("Toe"):
		return "foot"

	return ""


# The blend shape weight of slider `key` in genome `g`: the slider value (-1..1), except the bust (-1 means none): 0 up to BUST_FROM, then up to 1 at +1.
static func shape_weight(g: Dictionary, key: String) -> float:
	if key == "bust":
		return clampf((float(g.get(key, -1.0)) - BUST_FROM) / (1.0 - BUST_FROM), 0.0, 1.0)

	return clampf(float(g.get(key, 0.0)), -1.0, 1.0)


static func prewarm(mesh: Mesh, skin: Skin, skeleton: Skeleton3D) -> void:
	if _job >= 0 or not _pending.is_empty() or mesh == null or mesh.has_meta(SHAPED_KEY) or _cache.has(mesh.get_rid()):
		return

	var data: Dictionary = _gather(mesh, skin, skeleton)

	if data.is_empty():
		return

	_pending = {"data": data, "mesh": mesh}
	_job = WorkerThreadPool.add_task(_compute.bind(data), false, "dynasty shapes")


# True when shaped() would not have to wait: no prewarm is running, or it has finished on its worker. Bodies made while it runs (the player's own body at the join, the first
# NPCs) wear Dave's plain mesh until then and take their shapes in a later frame (dynasty_body.gd _set_widths): waiting here held the main thread 1 to 6 s at the join.
static func ready() -> bool:
	return _job < 0 or WorkerThreadPool.is_task_completed(_job)


static func wait() -> void:
	if _job < 0:
		return

	var t0: int = Time.get_ticks_msec()
	WorkerThreadPool.wait_for_task_completion(_job)
	_job = -1
	var mesh: Mesh = _pending["mesh"]
	_cache[mesh.get_rid()] = _finish(_pending["data"])
	_keep.append(mesh)
	_pending = {}
	FreezeWatchScript.printer.line("dynasty shapes: made on a worker, finished in %d ms" % (Time.get_ticks_msec() - t0))


# The shaped copy of `body.mesh` for `skin`, made on first use; null when the mesh is not one skinned surface with bones and weights.
static func shaped(mesh: Mesh, skin: Skin, skeleton: Skeleton3D) -> ArrayMesh:
	if mesh == null or skin == null or skeleton == null:
		return null

	if mesh.has_meta(SHAPED_KEY):
		return mesh as ArrayMesh      # already ours

	wait()
	var key: RID = mesh.get_rid()

	if _cache.has(key):
		return _cache[key]

	var t0: int = Time.get_ticks_msec()
	var made: ArrayMesh = _make(mesh, skin, skeleton)
	_cache[key] = made
	_keep.append(mesh)
	FreezeWatchScript.printer.line("dynasty shapes: %s in %d ms" % ["made" if made != null else "not made", Time.get_ticks_msec() - t0])
	return made


static func _make(mesh: Mesh, skin: Skin, skeleton: Skeleton3D) -> ArrayMesh:
	var data: Dictionary = _gather(mesh, skin, skeleton)

	if data.is_empty():
		return null

	_compute(data)
	return _finish(data)


# Three steps, so the heavy middle one can run on a worker thread: _gather reads the mesh, skin and skeleton (main thread: it calls the RenderingServer and the
# nodes), _compute is pure arithmetic on the copied arrays (any thread), _finish builds the ArrayMesh (main thread). Empty when the mesh is not one skinned body.
static func _gather(mesh: Mesh, skin: Skin, skeleton: Skeleton3D) -> Dictionary:
	if not (mesh is ArrayMesh) or mesh.get_surface_count() < 1:
		return {}

	var src: ArrayMesh = mesh as ArrayMesh

	# Bone heads in mesh space (the skin's bind poses undone), by skin bind index and by bone name.
	var head_of: Dictionary = {}          # bone name -> Vector3 in mesh space
	var bind_name: Array = []             # skin bind index -> bone name

	for i in range(skin.get_bind_count()):
		var bone_name: String = String(skin.get_bind_name(i))

		if bone_name == "" and skin.get_bind_bone(i) >= 0:
			bone_name = skeleton.get_bone_name(skin.get_bind_bone(i))

		bind_name.append(bone_name)
		head_of[bone_name] = skin.get_bind_pose(i).affine_inverse().origin

	for need in ["Hips", "Head", "LeftUpLeg", "RightUpLeg", "LeftFoot", "Spine", "Spine2"]:
		if not head_of.has(P + need):
			return {}

	var up: Vector3 = (head_of[P + "Head"] - head_of[P + "Hips"]).normalized()
	var lateral: Vector3 = (head_of[P + "LeftUpLeg"] - head_of[P + "RightUpLeg"])
	lateral = (lateral - up * lateral.dot(up)).normalized()                    # toward the body's left
	var front: Vector3 = lateral.cross(up).normalized()                        # Mixamo: left +X, up +Y, front +Z
	var height: float = (head_of[P + "Head"] - head_of[P + "LeftFoot"]).dot(up) * 1.12
	var hips: Vector3 = head_of[P + "Hips"]
	var navel: Vector3 = head_of[P + "Spine"]
	var chest_c: Vector3 = head_of[P + "Spine2"]
	# The segment of each bone: its head to the head of its first child (the end bones point up the parent's direction).
	var tail_of: Dictionary = {}

	for bone_name in head_of:
		var i: int = skeleton.find_bone(bone_name)
		var tail: Vector3 = head_of[bone_name]

		if i >= 0:
			for child in skeleton.get_bone_children(i):
				var child_name: String = skeleton.get_bone_name(child)

				if head_of.has(child_name):
					tail = head_of[child_name]
					break

		if tail.is_equal_approx(head_of[bone_name]):
			tail = head_of[bone_name] + up * height * 0.05

		tail_of[bone_name] = tail

	var surfaces: Array = []

	for s in range(src.get_surface_count()):
		surfaces.append({"arrays": src.surface_get_arrays(s), "primitive": src.surface_get_primitive_type(s), "material": src.surface_get_material(s)})

	return {"head_of": head_of, "tail_of": tail_of, "bind_name": bind_name, "up": up, "lateral": lateral, "front": front, "height": height, "hips": hips,
		"navel": navel, "chest_c": chest_c, "surfaces": surfaces}


static func _compute(data: Dictionary) -> void:
	var head_of: Dictionary = data["head_of"]
	var tail_of: Dictionary = data["tail_of"]
	var bind_name: Array = data["bind_name"]
	var up: Vector3 = data["up"]
	var lateral: Vector3 = data["lateral"]
	var front: Vector3 = data["front"]
	var height: float = data["height"]
	var hips: Vector3 = data["hips"]
	var navel: Vector3 = data["navel"]
	var chest_c: Vector3 = data["chest_c"]

	for surface in data["surfaces"]:
		var arrays: Array = surface["arrays"]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
		var per: int = bones.size() / maxi(verts.size(), 1)
		# Five separate arrays written element by element (a Packed array taken out of an Array and cast is not safe to write through).
		var s_build: PackedVector3Array = verts.duplicate()
		var s_muscle: PackedVector3Array = verts.duplicate()
		var s_belly: PackedVector3Array = verts.duplicate()
		var s_hips: PackedVector3Array = verts.duplicate()
		var s_chest: PackedVector3Array = verts.duplicate()
		var bust_verts: PackedInt32Array = PackedInt32Array()
		var head_verts: PackedInt32Array = PackedInt32Array()
		var cover_of: PackedInt32Array = PackedInt32Array()      # each vertex's cover group (COVERS index, -1 none) and where that shape puts it
		cover_of.resize(verts.size())
		cover_of.fill(-1)
		var cover_to: PackedVector3Array = verts.duplicate()

		if per > 0 and weights.size() == bones.size():
			for v in range(verts.size()):
				var p: Vector3 = verts[v]
				var best: int = -1
				var best_w: float = 0.0

				for k in range(per):
					if weights[v * per + k] > best_w:
						best_w = weights[v * per + k]
						best = bones[v * per + k]

				if best < 0 or best >= bind_name.size():
					continue

				var bone: String = String(bind_name[best]).trim_prefix(P)

				if not head_of.has(P + bone) or not tail_of.has(P + bone):
					continue      # a helper bone outside the rig's named chain (the glb's headfront): the vertex keeps its place in every shape

				var a: Vector3 = head_of[P + bone]
				var b: Vector3 = tail_of[P + bone]
				var ab: Vector3 = b - a
				var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
				var radial: Vector3 = p - (a + ab * t)
				var group: int = COVERS.find(cover_group(bone))

				if group >= 0 and radial.length() > 1e-6:
					cover_of[v] = group
					cover_to[v] = p - radial.normalized() * minf(height * COVER_IN, radial.length() * COVER_MAX)
				# build: fuller everywhere, a little on the head, hands and feet
				if bone.begins_with("Head") or bone == "headfront":
					head_verts.append(v)

				var thin: bool = bone.begins_with("Head") or bone.ends_with("Hand") or bone.ends_with("Foot") or bone.ends_with("ToeBase") or bone == "Neck" or bone == "headfront"
				s_build[v] = p + radial * (0.04 if thin else 0.16)
				# muscle: limbs, shoulders and chest, most mid-segment
				var limb: bool = bone.ends_with("Arm") or bone.ends_with("ForeArm") or bone.ends_with("UpLeg") or bone.ends_with("Leg") or bone.ends_with("Shoulder") or bone == "Spine2"
				s_muscle[v] = p + radial * ((0.05 + 0.16 * sin(PI * t)) if limb else 0.0)
				# belly: the front of the lower trunk, round the navel
				var rel: Vector3 = p - navel
				var fwd: float = rel.dot(front)
				var trunk: bool = bone == "Hips" or bone == "Spine" or bone == "Spine1"
				var around: float = exp(-pow(rel.dot(up) / (height * 0.09), 2.0))
				var belly: Vector3 = (front * maxf(fwd, 0.0) * 0.9 + lateral * rel.dot(lateral) * 0.15) * around if trunk else Vector3.ZERO
				s_belly[v] = p + belly
				# hips: the pelvis and thigh tops sideways
				var hip_rel: Vector3 = p - hips
				var near_hip: float = exp(-pow(hip_rel.dot(up) / (height * 0.08), 2.0))
				var hip_part: bool = bone == "Hips" or bone.ends_with("UpLeg") or bone == "Spine"
				s_hips[v] = p + (lateral * hip_rel.dot(lateral) * 0.22 * near_hip if hip_part else Vector3.ZERO)
				# chest: the rib cage wider and the chest forward
				var c_rel: Vector3 = p - chest_c
				var near_chest: float = exp(-pow(c_rel.dot(up) / (height * 0.1), 2.0))
				var chest_part: bool = bone == "Spine1" or bone == "Spine2" or bone.ends_with("Shoulder")
				s_chest[v] = p + ((lateral * c_rel.dot(lateral) * 0.14 + front * maxf(c_rel.dot(front), 0.0) * 0.25) * near_chest if chest_part else Vector3.ZERO)
				# bust: the trunk's and shoulders' front (not the arms, not the back); _bust moves them
				if (bone.begins_with("Spine") or bone.ends_with("Shoulder")) and c_rel.dot(front) > 0.0:
					bust_verts.append(v)

		var bust: Array = _bust(verts, arrays[Mesh.ARRAY_NORMAL], arrays[Mesh.ARRAY_INDEX], bust_verts, data)     # [positions, normals]
		var face: Array = _face(verts, head_verts, head_of, up, lateral, front)     # [jaw, nose, brow, ears]
		var blend_arrays: Array = []
		var s_cover: Array = []

		for g in range(COVERS.size()):
			var one_cover: PackedVector3Array = verts.duplicate()

			for v in range(verts.size()):
				if cover_of[v] == g:
					one_cover[v] = cover_to[v]

			s_cover.append(one_cover)

		var shapes: Array = [s_build, s_muscle, s_belly, s_hips, s_chest, bust[0], face[0], face[1], face[2], face[3]] + s_cover     # the order of NAMES, then COVERS

		for n in range(shapes.size()):
			var one: Array = []
			one.resize(Mesh.ARRAY_MAX)
			one[Mesh.ARRAY_VERTEX] = shapes[n]
			one[Mesh.ARRAY_NORMAL] = bust[1] if n < NAMES.size() and NAMES[n] == "bust" else arrays[Mesh.ARRAY_NORMAL]     # only the bust carries its own normals
			one[Mesh.ARRAY_TANGENT] = arrays[Mesh.ARRAY_TANGENT]
			blend_arrays.append(one)

		surface["blend"] = blend_arrays
		surface["flags"] = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0


# The bust shape [positions, normals] (see BUST_* above): the vertices `cand` (the trunk's and shoulders' front) pushed out onto a rounded shape in front of each
# breast, straight out from its centre, and the normals turned with the surface. Unchanged copies when either breast's front cannot be found.
static func _bust(verts: PackedVector3Array, normals: PackedVector3Array, indices: Variant, cand: PackedInt32Array, data: Dictionary) -> Array:
	var out: PackedVector3Array = verts.duplicate()
	var out_n: PackedVector3Array = normals.duplicate()
	var up: Vector3 = data["up"]
	var lateral: Vector3 = data["lateral"]
	var front: Vector3 = data["front"]
	var height: float = data["height"]
	var hips: Vector3 = data["hips"]
	var chest_c: Vector3 = data["chest_c"]
	# Each breast's front: the most forward vertex in a strip down the chest on its side.
	var tip: Dictionary = {}       # side (1.0 left, -1.0 right) -> the vertex position

	for v in cand:
		var p: Vector3 = verts[v]
		var side: float = 1.0 if (p - hips).dot(lateral) >= 0.0 else -1.0
		var q: Vector3 = p - (chest_c + lateral * side * BUST_OUT * height - up * BUST_DOWN * height)

		if absf(q.dot(lateral)) < 0.012 * height and q.dot(up) > -0.01 * height and q.dot(up) < 0.05 * height:
			if not tip.has(side) or p.dot(front) > (tip[side] as Vector3).dot(front):
				tip[side] = p

	if tip.size() < 2:
		return [out, out_n]

	# The two fronts as a mirror pair about the hips, so both breasts grow alike on a mesh that is not quite symmetric.
	var l: Vector3 = (tip[1.0] as Vector3) - hips
	var r: Vector3 = (tip[-1.0] as Vector3) - hips
	var out_side: float = (l.dot(lateral) - r.dot(lateral)) * 0.5
	var lift: Vector3 = up * (l.dot(up) + r.dot(up)) * 0.5 + front * (l.dot(front) + r.dot(front)) * 0.5
	var rx: float = BUST_WIDE * height
	var ry: float = BUST_TALL * height
	var rz: float = (BUST_DEPTH + BUST_FORWARD) * height
	var moved: Dictionary = {}

	for v in cand:
		var p: Vector3 = verts[v]
		var across: float = (p - hips).dot(lateral)
		var side: float = 1.0 if across >= 0.0 else -1.0
		var centre: Vector3 = hips + lateral * side * out_side + lift - front * BUST_DEPTH * height
		var d: Vector3 = p - centre
		var dist: float = d.length()

		if dist < 1e-9:
			continue

		var dir: Vector3 = d / dist
		var reach: float = 1.0 / sqrt(pow(dir.dot(lateral) / rx, 2.0) + pow(dir.dot(up) / ry, 2.0) + pow(dir.dot(front) / rz, 2.0))     # the shape's surface along dir
		var soft: float = (BUST_SOFT_UP if d.dot(up) > 0.0 else BUST_SOFT_DOWN) * height
		var gap: float = reach - dist
		var push: float = gap if gap > soft else ((gap + soft) * (gap + soft) / (4.0 * soft) if gap > -soft else 0.0)     # a soft join, not a crease
		var rim: float = sqrt(pow(d.dot(lateral) / rx, 2.0) + pow(d.dot(up) / ry, 2.0))
		var fade: float = (1.0 - smoothstep(1.0, 1.5, rim)) * smoothstep(0.0, 0.02 * height, absf(across))     # nothing past the shape's edge, nothing at the breastbone

		push *= 1.0 - BUST_KEEP

		if push * fade > 1e-7:
			out[v] = p + dir * push * fade
			moved[v] = true

	if indices == null or (indices as PackedInt32Array).is_empty() or normals.size() != verts.size():
		return [out, out_n]

	# The normals: each moved vertex, and its neighbours, turned by as much as the surface round it turned. Vertices at one place (texture seams) share one normal.
	var idx: PackedInt32Array = indices
	var before: Dictionary = {}    # welded place -> summed face normal, unshaped
	var after: Dictionary = {}     # the same, shaped
	var touched: Dictionary = {}

	for t in range(0, idx.size() - 2, 3):
		var a: int = idx[t]
		var b: int = idx[t + 1]
		var c: int = idx[t + 2]

		if not (moved.has(a) or moved.has(b) or moved.has(c)):
			continue

		var f0: Vector3 = (verts[b] - verts[a]).cross(verts[c] - verts[a])
		var f1: Vector3 = (out[b] - out[a]).cross(out[c] - out[a])

		for v in [a, b, c]:
			var key: Vector3i = Vector3i((verts[v] * 100000.0).round())
			before[key] = before.get(key, Vector3.ZERO) + f0
			after[key] = after.get(key, Vector3.ZERO) + f1
			touched[v] = key

	for v in touched:
		var n0: Vector3 = (before[touched[v]] as Vector3).normalized()
		var n1: Vector3 = (after[touched[v]] as Vector3).normalized()

		if n0.dot(normals[v]) < 0.0:        # the face winding runs the other way from the mesh's normals
			n0 = -n0
			n1 = -n1

		out_n[v] = (normals[v] + n1 - n0).normalized()

	return [out, out_n]

static func _finish(data: Dictionary) -> ArrayMesh:
	var out: ArrayMesh = ArrayMesh.new()
	out.set_meta(SHAPED_KEY, true)
	out.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED      # the shapes hold whole positions (base + offset); RELATIVE would add them on top of the base and grow or shrink the whole body

	for shape_name in NAMES:
		out.add_blend_shape(shape_name)

	for group in COVERS:
		out.add_blend_shape("cover_" + group)

	var s: int = 0

	for surface in data["surfaces"]:
		out.add_surface_from_arrays(surface["primitive"], surface["arrays"], surface["blend"], {}, surface["flags"])
		out.surface_set_material(s, surface["material"])
		s += 1

	return out


# The four face shapes [jaw, nose, brow, ears], each a full copy of the vertices. Sizes are fractions of the head's height (the Head bone to HeadTop_End), so they hold any export unit.
static func _face(verts: PackedVector3Array, head_verts: PackedInt32Array, head_of: Dictionary, up: Vector3, lateral: Vector3, front: Vector3) -> Array:
	var s_jaw: PackedVector3Array = verts.duplicate()
	var s_nose: PackedVector3Array = verts.duplicate()
	var s_brow: PackedVector3Array = verts.duplicate()
	var s_ears: PackedVector3Array = verts.duplicate()

	if head_verts.is_empty():
		return [s_jaw, s_nose, s_brow, s_ears]

	var base: Vector3 = head_of[P + "Head"]
	var top: Vector3 = head_of.get(P + "HeadTop_End", base + up * 0.2)
	var face_h: float = maxf((top - base).dot(up), 0.0001)
	var nose: Vector3 = verts[head_verts[0]]
	var best_front: float = -INF
	var widest: float = 0.0

	for v in head_verts:
		var rel: Vector3 = verts[v] - base
		widest = maxf(widest, absf(rel.dot(lateral)))

		if absf(rel.dot(lateral)) < face_h * 0.08 and rel.dot(up) > face_h * 0.15 and rel.dot(front) > best_front:
			best_front = rel.dot(front)
			nose = verts[v]

	var nose_up: float = (nose - base).dot(up)

	for v in head_verts:
		var p: Vector3 = verts[v]
		var rel: Vector3 = p - base
		var lat: float = rel.dot(lateral)
		var hgt: float = rel.dot(up)
		var fwd: float = rel.dot(front)
		var face_side: float = smoothstep(best_front - face_h * 0.55, best_front - face_h * 0.15, fwd)     # 1 on the face, 0 at the back of the head
		# nose: round its tip
		var to_tip: Vector3 = p - nose
		var on_nose: float = exp(-pow(to_tip.length() / (face_h * 0.11), 2.0))
		s_nose[v] = p + (front * face_h * 0.07 + to_tip * 0.35) * on_nose
		# brow: a band above the eyes, across the front
		var on_brow: float = exp(-pow((hgt - (nose_up + face_h * 0.24)) / (face_h * 0.07), 2.0)) * (1.0 - smoothstep(face_h * 0.25, face_h * 0.4, absf(lat))) * face_side
		s_brow[v] = p + front * face_h * 0.06 * on_brow
		# jaw: the lower face below the nose, wider, chin forward
		var low: float = smoothstep(nose_up - face_h * 0.1, nose_up - face_h * 0.35, hgt) * (1.0 - smoothstep(nose_up - face_h * 0.75, nose_up - face_h * 0.95, hgt)) * face_side
		s_jaw[v] = p + (lateral * lat * 0.22 + front * face_h * 0.04) * low
		# ears: the outermost sides of the head at about nose height, behind the face
		var side_out: float = smoothstep(widest * 0.78, widest * 0.95, absf(lat)) * exp(-pow((hgt - nose_up - face_h * 0.08) / (face_h * 0.2), 2.0)) * (1.0 - face_side * 0.7)
		s_ears[v] = p + lateral * signf(lat) * face_h * 0.08 * side_out

	return [s_jaw, s_nose, s_brow, s_ears]
