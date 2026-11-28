extends RefCounted

# A fitted cloth layer under a sleeved body garment, on a body that is one skinned mesh (Dave's body, dynasty_body.gd sets rig meta "worn_shell").
# QA #15 (25-26 Nov 2026, a tester: "log chopping animation limbs not attached"; Lane A stills of the chop: skin showed between the rigid worn pieces at the shoulder blades, the
# armpit, the neck base and wherever the arm was raised). Rigid pieces cannot follow skin that stretches: measured offline against the body skinned at the chop, even shoulder
# balls 37 cm across left 150 to 300 skin points bare at t 0.1. So the garment also gets a copy of the body's own skin over the region it covers, pushed out along the skin's
# normals by OUT_M, with the same bone weights and the same width shapes: it bends with the body in every pose and covers its skin from the front, back and sides.
# The garment's pieces (worn_look.gd parts_of) stay on top for its shape, collar and quilting; this layer only fills what they leave.
# Cost: one skinned mesh per sleeved garment on a near body (worn_look.gd attach skips it on far bodies), made once per body mesh for all three garments and shared.
# Made on a worker thread (Lane A, 26 Nov 2026: on the main thread it held the frame 36 to 49 ms the first time a garment was worn): prewarm() reads the mesh on the
# main thread (_gather), the arithmetic runs on a worker (_compute) and the meshes are built when it is done (_finish). A layer hung before then waits without a mesh and
# its body fills it in a later frame (dynasty_body.gd _process), as the width shapes do (dynasty_shapes.gd).

const FreezeWatchScript := preload("res://src/debug/freeze_watch.gd")

const NODE_PREFIX := "Worn_Shell_"
# The garment -> the body's bones (Mixamo names without the prefix) whose skin it covers: a vertex is covered when its strongest bone is one of them. A long sleeve runs to the
# wrist (the forearm's skin), the mail shirt's short sleeve to the elbow (the upper arm's). The hips are left to the garment's skirt piece and the trousers.
const TORSO := ["Spine", "Spine1", "Spine2", "RightShoulder", "LeftShoulder"]
const REGIONS := {
	"tunic": TORSO + ["RightArm", "LeftArm", "RightForeArm", "LeftForeArm"],
	"padded": TORSO + ["RightArm", "LeftArm", "RightForeArm", "LeftForeArm"],
	"mailshirt": TORSO + ["RightArm", "LeftArm"],
}
# The garment's own pieces on this body (worn_look.gd attach, fit_parts): Dave's back stands further out than the pieces were written for (the chest tube's back corner
# was 2 cm inside his shoulder blades), so the layer showed his back's muscles through it as cloth-coloured lumps (Lane A qa15e, 26 Nov 2026). On his body a sleeved
# garment's chest tubes are turned a sixth of a turn so a flat face lies across the back and the chest (CylinderMesh puts a corner at the back), made deeper and set back,
# and a little narrower, since the turn puts a corner at each side. Its flat chest details (the gambeson's quilting, the shirt's lacing) are laid on the tube's front
# faces; the three garments have no other chest pieces. No mantle over the shoulders: a round one read as a hump from the back and the side
# (Lane A qa15f). Measured offline against his skinned mesh at idle (tools: the garment's surface against the body, by 5 cm of height): the garment stands at most 7.5 cm
# off his back and 8 cm past his sides (the mantle stood 10.6 cm off his back), and the layer's points outside the pieces over his shoulder blades fell from 245 (gambeson)
# and 308 (shirt) to 40 and 75; the shoulder tops above the tube stay the layer's, the garment's own shoulders.
const CHEST_TURN := PI / 6.0
const CHEST_DEEPER := 1.2
const CHEST_BACK_M := 0.01
const CHEST_NARROWER := 0.9
# How far out from the skin, in metres: inside the garment's pieces (a layer-2 garment's pieces stand 3 cm out), and a shirt under a gambeson under mail in that order.
# The gambeson's layer stands 3 cm out, as thick as its padding, and the mail shirt's goes over it.
const OUT_M := {"tunic": 0.01, "padded": 0.03, "mailshirt": 0.036}
# Garments whose fitted layer is their chest on a near body: the rigid chest tube is left off (Dave, 28 Nov 2026, the gambeson's own shape: the tube read as a squared
# block from the side, BugsList 158), so the padded jacket follows the body in every pose. Far bodies hang no layer and keep the tube.
const LAYER_IS_CHEST := ["padded"]
# Garments worn under one of those (a shirt under the gambeson): their chest pieces would stand out through its layer, so they are left off; their own layer stays under it.
const UNDER_CHEST := ["tunic"]

static var _cache: Dictionary = {}      # "<mesh id>|<builder>" -> ArrayMesh (or null: a mesh that is not one skinned body)
static var _keep: Array = []            # the source meshes, so a cached id is never reused by a new mesh
static var _jobs: Dictionary = {}       # mesh id -> {"task": worker task id, "data": what it works on}
static var _done: Dictionary = {}       # mesh id -> a finished job's data, its garments' meshes built when first asked for (_built)
static var _seen: Dictionary = {}       # mesh id -> true once prewarmed


static func covers(builder: String) -> bool:
	return REGIONS.has(builder)


# `builder`'s pieces (worn_look.gd parts_of) as they hang on a body with this layer (see CHEST_TURN). Other garments' pieces, and pieces on other bones, are returned as
# they are.
static func fit_parts(builder: String, parts: Array, near: bool = true) -> Array:
	if not covers(builder):
		return parts

	if near and builder in LAYER_IS_CHEST:
		return parts.filter(func(part: Dictionary) -> bool: return not _is_tube(part))

	var tube: Dictionary = {}

	for part in parts:
		if _is_tube(part):
			tube = part
			break

	if tube.is_empty():
		return parts

	var center_z: float = float((tube["at"] as Vector3).z) * CHEST_DEEPER + CHEST_BACK_M
	var half_x: float = float((tube["size"] as Vector3).x) * CHEST_NARROWER * 0.5
	var face: float = float((tube["size"] as Vector3).z) * CHEST_DEEPER * 0.5 * cos(CHEST_TURN)    # the front face's distance from the tube's middle
	var out: Array = []

	for part in parts:
		var piece: Dictionary = (part as Dictionary).duplicate()
		var at: Vector3 = piece["at"]
		var size: Vector3 = piece["size"]

		if str(piece["bone"]) != "chest":
			pass
		elif str(piece["shape"]) == "cyl":
			piece["rot"] = (piece.get("rot", Vector3.ZERO) as Vector3) + Vector3(0.0, CHEST_TURN, 0.0)
			piece["at"] = Vector3(at.x, at.y, at.z * CHEST_DEEPER + CHEST_BACK_M)
			piece["size"] = Vector3(size.x * CHEST_NARROWER, size.y, size.z * CHEST_DEEPER)
		elif str(piece["shape"]) == "box" and at.z < 0.0:
			piece = _on_front(piece, center_z, half_x, face, tube)

		out.append(piece)

	return out


static func _is_tube(part: Dictionary) -> bool:
	return str(part["bone"]) == "chest" and str(part["shape"]) == "cyl" and not bool(part.get("detail", false))


# A flat chest detail laid on the turned tube's front (front is -Z): on the flat face across the chest, or turned onto the slanted face beside it, its back sunk 2 mm in,
# and cut to the tube's height (Lane A qa15g, 26 Nov 2026: the shirt's lacing ran 4 cm above the tube and stood proud at the collar from the side).
static func _on_front(piece: Dictionary, center_z: float, half_x: float, face: float, tube: Dictionary) -> Dictionary:
	var at: Vector3 = piece["at"]
	var size: Vector3 = piece["size"]
	var sink: float = size.z * 0.5 - 0.002
	var tube_y: float = float((tube["at"] as Vector3).y)
	var tube_half: float = float((tube["size"] as Vector3).y) * 0.5 - 0.005
	var low: float = maxf(at.y - size.y * 0.5, tube_y - tube_half)
	var high: float = minf(at.y + size.y * 0.5, tube_y + tube_half)

	if high > low:
		at.y = (low + high) * 0.5
		piece["size"] = Vector3(size.x, high - low, size.z)
	var surface_z: float = center_z - face
	var normal: Vector2 = Vector2(0.0, -1.0)      # (x, z), outward
	var turn: float = 0.0

	if absf(at.x) > half_x * 0.5:
		var slope: float = 2.0 * face / half_x
		surface_z = center_z - face * 2.0 * (1.0 - minf(absf(at.x), half_x) / half_x)
		normal = Vector2(signf(at.x) * slope, -1.0).normalized()
		turn = -signf(at.x) * atan(slope)

	piece["at"] = Vector3(at.x + normal.x * sink, at.y, surface_z + normal.y * sink)
	piece["rot"] = (piece.get("rot", Vector3.ZERO) as Vector3) + Vector3(0.0, turn, 0.0)
	return piece


# The bone's short name: "mixamorig_RightArm" (and "mixamorig:RightArm") -> "RightArm".
static func short_name(bone_name: String) -> String:
	var plain: String = bone_name.replace(":", "_")
	return plain.substr(plain.rfind("_") + 1)


static func _key(source: Mesh, builder: String) -> String:
	return "%d|%s" % [source.get_instance_id(), builder]


# Start making the layers of every garment over `source` on a worker; nothing when they are made or being made, or the mesh is not a skinned body.
static func prewarm(source: Mesh, skin: Skin, skeleton: Skeleton3D) -> void:
	if not (source is ArrayMesh) or skin == null or skeleton == null:
		return

	var id: int = source.get_instance_id()

	if _seen.has(id):
		return

	_seen[id] = true
	_keep.append(source)
	var data: Dictionary = _gather(source as ArrayMesh, skin, skeleton)
	data["started"] = Time.get_ticks_msec()
	data["mesh"] = source
	_jobs[id] = {"task": WorkerThreadPool.add_task(_compute.bind(data), false, "worn shell"), "data": data}


# Join a finished job (or wait for it when `block`); its meshes are built later, one garment at a time, when asked for. False when it is still running.
static func _collect(id: int, block: bool) -> bool:
	if not _jobs.has(id):
		return true

	var task: int = int(_jobs[id]["task"])

	if not block and not WorkerThreadPool.is_task_completed(task):
		return false

	WorkerThreadPool.wait_for_task_completion(task)
	var data: Dictionary = _jobs[id]["data"]
	_jobs.erase(id)
	data.erase("surfaces")       # the body's arrays (several MB with the width shapes): the build needs only the worked garments
	data.erase("in_region")
	_done[id] = data
	# Worked: the arithmetic on the worker. Joined: when the main thread took it, which with nothing worn is only when the body goes (dynasty_body.gd calls wait()),
	# so it is as long as the body lived, not a cost (Lane A pr1961: "made on a worker in" 1 to 2 s on bodies that wore nothing).
	FreezeWatchScript.printer.line("worn shell: worked %d ms on a worker, joined after %d ms" % [int(data.get("worked_ms", -1)), Time.get_ticks_msec() - int(data["started"])])
	return true


# The garment's mesh over `source` from its joined job, built on first ask (only the garments actually worn are built); the job's data goes once all are.
static func _built(source: Mesh, builder: String) -> ArrayMesh:
	var key: String = _key(source, builder)
	var id: int = source.get_instance_id()

	if not _cache.has(key) and _done.has(id):
		var t0: int = Time.get_ticks_msec()
		_cache[key] = _finish(_done[id], builder)
		(_done[id]["made"] as Dictionary).erase(builder)      # built: its arrays are the mesh's now
		FreezeWatchScript.printer.line("worn shell: %s finished in %d ms" % [builder, Time.get_ticks_msec() - t0])
		var all: bool = true

		for other in REGIONS:
			all = all and _cache.has(_key(source, str(other)))

		if all:
			_done.erase(id)

	return _cache.get(key, null)


# The layer's mesh, or null while its worker is still making it (or when it cannot be made: see making()).
static func ready_mesh(source: Mesh, skin: Skin, skeleton: Skeleton3D, builder: String) -> ArrayMesh:
	if not covers(builder) or source == null:
		return null

	if not _cache.has(_key(source, builder)):
		prewarm(source, skin, skeleton)
		_collect(source.get_instance_id(), false)

	return _built(source, builder)


# True while the layers over `source` are being made.
static func making(source: Mesh) -> bool:
	return source != null and _jobs.has(source.get_instance_id())


# The layer's mesh, waiting for its worker if need be (tests and tools; the game uses ready_mesh). Null when the garment has no layer or the mesh is not a skinned body.
static func shell_mesh(source: Mesh, skin: Skin, skeleton: Skeleton3D, builder: String) -> ArrayMesh:
	if not covers(builder) or source == null:
		return null

	prewarm(source, skin, skeleton)
	_collect(source.get_instance_id(), true)
	return _built(source, builder)


# Join every running job, so no task outlives the bodies (dynasty_body.gd frees its last body this way) and a test sees every layer ready. Builds no mesh: a body freed
# before it was dressed pays only the join.
static func wait() -> void:
	for id in _jobs.keys():
		_collect(int(id), true)


# Main thread: the mesh's arrays and, per garment, which skin binds it covers.
static func _gather(src: ArrayMesh, skin: Skin, skeleton: Skeleton3D) -> Dictionary:
	var in_region: Dictionary = {}       # builder -> PackedByteArray: skin bind index -> 1 when its bone is covered

	for builder in REGIONS:
		var flags: PackedByteArray = PackedByteArray()

		for i in range(skin.get_bind_count()):
			var bone_name: String = String(skin.get_bind_name(i))

			if bone_name == "" and skin.get_bind_bone(i) >= 0:
				bone_name = skeleton.get_bone_name(skin.get_bind_bone(i))

			flags.append(1 if short_name(bone_name) in REGIONS[builder] else 0)

		in_region[builder] = flags

	var names: Array = []

	for k in range(src.get_blend_shape_count()):
		names.append(src.get_blend_shape_name(k))

	var surfaces: Array = []

	for s in range(src.get_surface_count()):
		if src.surface_get_primitive_type(s) == Mesh.PRIMITIVE_TRIANGLES:
			surfaces.append({"surface": s, "arrays": src.surface_get_arrays(s), "blends": src.surface_get_blend_shape_arrays(s)})

	return {"in_region": in_region, "names": names, "mode": src.blend_shape_mode, "surfaces": surfaces, "made": {}}


# Any thread: pure arithmetic on the copied arrays, writing data["made"][builder] = one entry per surface.
static func _compute(data: Dictionary) -> void:
	for builder in REGIONS:
		var made_surfaces: Array = []

		for surface in data["surfaces"]:
			var one_surface: Dictionary = _surface(surface, data["in_region"][builder], float(OUT_M[builder]))

			if not one_surface.is_empty():
				made_surfaces.append(one_surface)

		data["made"][builder] = made_surfaces

	data["worked_ms"] = Time.get_ticks_msec() - int(data["started"])    # the worker's own time (Time is thread safe); the join can come much later


static func _surface(surface: Dictionary, in_region: PackedByteArray, out_m: float) -> Dictionary:
	var arrays: Array = surface["arrays"]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
	var per: int = int(float(bones.size()) / float(maxi(verts.size(), 1)))      # bone slots per vertex: 4, or 8

	if per == 0 or weights.size() != bones.size() or normals.size() != verts.size():
		return {}

	var covered: PackedByteArray = PackedByteArray()
	covered.resize(verts.size())

	for v in range(verts.size()):
		var best: int = -1
		var best_w: float = 0.0

		for k in range(per):
			if weights[v * per + k] > best_w:
				best_w = weights[v * per + k]
				best = bones[v * per + k]

		covered[v] = in_region[best] if best >= 0 and best < in_region.size() else 0

	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(verts.size()))
	var new_of: PackedInt32Array = PackedInt32Array()      # source vertex -> new vertex, or -1 (not "remap": that is a global function, and the name warned)
	new_of.resize(verts.size())
	new_of.fill(-1)
	var kept: PackedInt32Array = PackedInt32Array()       # new vertex -> source vertex
	var new_index: PackedInt32Array = PackedInt32Array()

	# A triangle is kept when all three corners are covered, so the layer ends at the region's edge (the wrist, the neck) and never spills onto the hand or the face.
	for t in range(0, indices.size() - 2, 3):
		if covered[indices[t]] == 0 or covered[indices[t + 1]] == 0 or covered[indices[t + 2]] == 0:
			continue

		for c in range(3):
			var v: int = indices[t + c]

			if new_of[v] < 0:
				new_of[v] = kept.size()
				kept.append(v)

			new_index.append(new_of[v])

	if kept.is_empty():
		return {}

	var n_kept: int = kept.size()
	var pos: PackedVector3Array = PackedVector3Array()
	var nrm: PackedVector3Array = PackedVector3Array()
	var rest: PackedFloat32Array = PackedFloat32Array()      # the skin's own place, so the cloth's weave stays on the cloth as it bends (worn_look.gd CLOTH_SHADER rest_custom)
	var k_bones: PackedInt32Array = PackedInt32Array()
	var k_weights: PackedFloat32Array = PackedFloat32Array()
	pos.resize(n_kept)
	nrm.resize(n_kept)
	rest.resize(n_kept * 3)
	k_bones.resize(n_kept * per)
	k_weights.resize(n_kept * per)

	for i in range(n_kept):
		var v: int = kept[i]
		pos[i] = verts[v] + normals[v] * out_m
		nrm[i] = normals[v]
		rest[i * 3] = verts[v].x
		rest[i * 3 + 1] = verts[v].y
		rest[i * 3 + 2] = verts[v].z

		for k in range(per):
			k_bones[i * per + k] = bones[v * per + k]
			k_weights[i * per + k] = weights[v * per + k]

	var made: Array = []
	made.resize(Mesh.ARRAY_MAX)
	made[Mesh.ARRAY_VERTEX] = pos
	made[Mesh.ARRAY_NORMAL] = nrm
	made[Mesh.ARRAY_CUSTOM0] = rest
	made[Mesh.ARRAY_BONES] = k_bones
	made[Mesh.ARRAY_WEIGHTS] = k_weights
	made[Mesh.ARRAY_INDEX] = new_index
	# The width shapes (dynasty_shapes.gd: whole positions, NORMALIZED), each pushed out the same way so the layer keeps its distance on a broad or a slim body.
	var blends: Array = []

	for shape in surface["blends"]:
		var b_verts: PackedVector3Array = shape[Mesh.ARRAY_VERTEX]
		var b_normals: PackedVector3Array = shape[Mesh.ARRAY_NORMAL] if shape[Mesh.ARRAY_NORMAL] != null else normals
		var b_pos: PackedVector3Array = PackedVector3Array()
		var b_nrm: PackedVector3Array = PackedVector3Array()
		b_pos.resize(n_kept)
		b_nrm.resize(n_kept)

		for i in range(n_kept):
			var n: Vector3 = b_normals[kept[i]] if b_normals.size() == verts.size() else normals[kept[i]]
			b_pos[i] = b_verts[kept[i]] + n * out_m
			b_nrm[i] = n

		var one: Array = []
		one.resize(Mesh.ARRAY_MAX)
		one[Mesh.ARRAY_VERTEX] = b_pos
		one[Mesh.ARRAY_NORMAL] = b_nrm
		blends.append(one)

	var flags: int = Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT

	if per == 8:
		flags |= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS

	return {"surface": surface["surface"], "arrays": made, "blends": blends, "flags": flags, "vertices": kept}


# Main thread: the ArrayMesh of one garment from its worked surfaces; null when it had none.
static func _finish(data: Dictionary, builder: String) -> ArrayMesh:
	var made_surfaces: Array = data["made"].get(builder, [])

	if made_surfaces.is_empty():
		return null

	var out: ArrayMesh = ArrayMesh.new()
	out.blend_shape_mode = data["mode"]

	for shape_name in data["names"]:
		out.add_blend_shape(shape_name)

	var sources: Array = []      # per surface made: the body surface it came from and, per vertex, the body vertex under it (for the tests)

	for one in made_surfaces:
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, one["arrays"], one["blends"], {}, int(one["flags"]))
		sources.append({"surface": one["surface"], "vertices": one["vertices"]})

	out.set_meta("source_vertices", sources)
	return out if out.get_surface_count() > 0 else null


# Hang the layer of `builder` on `rig`'s skeleton, skinned like its body; null when the rig has no skinned body or the garment no layer. While its worker is still making
# it the layer hangs without a mesh, and the rig is told (wait_for_shells) so it fills it in a later frame.
static func hang(rig: Node, skeleton: Skeleton3D, builder: String, material: Material) -> MeshInstance3D:
	var body: MeshInstance3D = rig.get("body_mesh") as MeshInstance3D

	if body == null or body.mesh == null or body.skin == null:
		return null

	var mesh: ArrayMesh = ready_mesh(body.mesh, body.skin, skeleton, builder)
	var later: bool = mesh == null and making(body.mesh)

	if mesh == null and not later:
		return null

	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = NODE_PREFIX + builder
	node.set_meta("shell_builder", builder)
	node.mesh = mesh
	node.skin = body.skin
	node.material_override = material
	node.layers = body.layers
	skeleton.add_child(node, true)      # readable name kept even beside another one ("Worn_Shell_tunic2"), so attach's "Worn_" sweep always finds it
	node.transform = body.transform if body.get_parent() == skeleton else Transform3D.IDENTITY
	node.skeleton = node.get_path_to(skeleton)
	_copy_shapes(body, node)

	if later and rig.has_method("wait_for_shells"):
		rig.call("wait_for_shells")

	return node


# After the body's mesh or width weights change (dynasty_body.gd _set_widths), and each frame while a layer waits: each layer takes the mesh made from the body's current
# mesh once it is ready (until then it keeps the one it has) and the body's weights. True while any layer still waits for its worker.
static func refresh(rig: Node) -> bool:
	var body: MeshInstance3D = rig.get("body_mesh") as MeshInstance3D
	var skeleton: Skeleton3D = rig.get("skeleton") as Skeleton3D
	var waiting: bool = false

	if body == null or skeleton == null:
		return false

	for child in skeleton.get_children():
		if child is MeshInstance3D and child.has_meta("shell_builder"):
			var mesh: ArrayMesh = ready_mesh(body.mesh, body.skin, skeleton, str(child.get_meta("shell_builder")))

			if mesh != null and (child as MeshInstance3D).mesh != mesh:
				(child as MeshInstance3D).mesh = mesh
			elif mesh == null and making(body.mesh):
				waiting = true

			_copy_shapes(body, child as MeshInstance3D)

	return waiting


static func _copy_shapes(body: MeshInstance3D, node: MeshInstance3D) -> void:
	var source: ArrayMesh = body.mesh as ArrayMesh

	if source == null or node.mesh == null:
		return

	for k in range(source.get_blend_shape_count()):
		var i: int = node.find_blend_shape_by_name(source.get_blend_shape_name(k))

		if i >= 0 and not String(source.get_blend_shape_name(k)).begins_with("cover_"):      # the layer stays out where it is made; only the body's skin tucks in
			node.set_blend_shape_value(i, body.get_blend_shape_value(k))
