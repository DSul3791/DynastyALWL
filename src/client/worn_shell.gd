extends RefCounted

# A fitted cloth layer under a sleeved body garment, on a body that is one skinned mesh (Dave's body, dynasty_body.gd sets rig meta "worn_shell").
# QA #15 (25-26 Nov 2026, a tester: "log chopping animation limbs not attached"; Lane A stills of the chop: skin showed between the rigid worn pieces at the shoulder blades, the
# armpit, the neck base and wherever the arm was raised). Rigid pieces cannot follow skin that stretches: measured offline against the body skinned at the chop, even shoulder
# balls 37 cm across left 150 to 300 skin points bare at t 0.1. So the garment also gets a copy of the body's own skin over the region it covers, pushed out along the skin's
# normals by OUT_M, with the same bone weights and the same width shapes: it bends with the body in every pose and covers its skin from the front, back and sides.
# The garment's pieces (worn_look.gd parts_of) stay on top for its shape, collar and quilting; this layer only fills what they leave.
# Cost: one skinned mesh per sleeved garment on a near body (worn_look.gd attach skips it on far bodies), made once per body mesh and garment and shared.

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
# How far out from the skin, in metres: inside the garment's pieces (a layer-2 garment's pieces stand 3 cm out), and a shirt under a gambeson under mail in that order.
const OUT_M := {"tunic": 0.01, "padded": 0.018, "mailshirt": 0.024}

static var _cache: Dictionary = {}      # "<mesh id>|<builder>" -> ArrayMesh (or null: a mesh that is not one skinned body)
static var _keep: Array = []            # the source meshes, so a cached id is never reused by a new mesh


static func covers(builder: String) -> bool:
	return REGIONS.has(builder)


# The bone's short name: "mixamorig_RightArm" (and "mixamorig:RightArm") -> "RightArm".
static func short_name(bone_name: String) -> String:
	var plain: String = bone_name.replace(":", "_")
	return plain.substr(plain.rfind("_") + 1)


# The layer's mesh for `builder` over `source` (the body's current mesh), made on first use; null when the garment has no layer or the mesh is not a skinned body.
static func shell_mesh(source: Mesh, skin: Skin, skeleton: Skeleton3D, builder: String) -> ArrayMesh:
	if not covers(builder) or not (source is ArrayMesh) or skin == null or skeleton == null:
		return null

	var key: String = "%d|%s" % [source.get_instance_id(), builder]

	if not _cache.has(key):
		var t0: int = Time.get_ticks_msec()
		_cache[key] = _make(source as ArrayMesh, skin, skeleton, REGIONS[builder], float(OUT_M[builder]))
		_keep.append(source)
		FreezeWatchScript.printer.line("worn shell: %s %s in %d ms" % [builder, "made" if _cache[key] != null else "not made", Time.get_ticks_msec() - t0])

	return _cache[key]


static func _make(src: ArrayMesh, skin: Skin, skeleton: Skeleton3D, region: Array, out_m: float) -> ArrayMesh:
	var in_region: PackedByteArray = PackedByteArray()      # skin bind index -> 1 when its bone is covered

	for i in range(skin.get_bind_count()):
		var bone_name: String = String(skin.get_bind_name(i))

		if bone_name == "" and skin.get_bind_bone(i) >= 0:
			bone_name = skeleton.get_bone_name(skin.get_bind_bone(i))

		in_region.append(1 if short_name(bone_name) in region else 0)

	var out: ArrayMesh = ArrayMesh.new()
	out.blend_shape_mode = src.blend_shape_mode

	for k in range(src.get_blend_shape_count()):
		out.add_blend_shape(src.get_blend_shape_name(k))

	var sources: Array = []      # per surface made: the body surface it came from and, per vertex, the body vertex under it (for the tests)

	for s in range(src.get_surface_count()):
		if src.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			continue

		var arrays: Array = src.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
		var per: int = int(float(bones.size()) / float(maxi(verts.size(), 1)))      # bone slots per vertex: 4, or 8

		if per == 0 or weights.size() != bones.size() or normals.size() != verts.size():
			continue

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
		var remap: PackedInt32Array = PackedInt32Array()
		remap.resize(verts.size())
		remap.fill(-1)
		var kept: PackedInt32Array = PackedInt32Array()       # new vertex -> source vertex
		var new_index: PackedInt32Array = PackedInt32Array()

		# A triangle is kept when all three corners are covered, so the layer ends at the region's edge (the wrist, the neck) and never spills onto the hand or the face.
		for t in range(0, indices.size() - 2, 3):
			if covered[indices[t]] == 0 or covered[indices[t + 1]] == 0 or covered[indices[t + 2]] == 0:
				continue

			for c in range(3):
				var v: int = indices[t + c]

				if remap[v] < 0:
					remap[v] = kept.size()
					kept.append(v)

				new_index.append(remap[v])

		if kept.is_empty():
			continue

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

		for shape in src.surface_get_blend_shape_arrays(s):
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

		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, made, blends, {}, flags)
		sources.append({"surface": s, "vertices": kept})

	out.set_meta("source_vertices", sources)
	return out if out.get_surface_count() > 0 else null


# Hang the layer of `builder` on `rig`'s skeleton, skinned like its body; null when the rig has no skinned body or the garment no layer.
static func hang(rig: Node, skeleton: Skeleton3D, builder: String, material: Material) -> MeshInstance3D:
	var body: MeshInstance3D = rig.get("body_mesh") as MeshInstance3D

	if body == null or body.mesh == null or body.skin == null:
		return null

	var mesh: ArrayMesh = shell_mesh(body.mesh, body.skin, skeleton, builder)

	if mesh == null:
		return null

	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = NODE_PREFIX + builder
	node.set_meta("shell_builder", builder)
	node.mesh = mesh
	node.skin = body.skin
	node.material_override = material
	node.layers = body.layers
	skeleton.add_child(node)
	node.transform = body.transform if body.get_parent() == skeleton else Transform3D.IDENTITY
	node.skeleton = node.get_path_to(skeleton)
	_copy_shapes(body, node)
	return node


# After the body's mesh or width weights change (dynasty_body.gd _set_widths): each layer takes the mesh made from the new one and the same weights.
static func refresh(rig: Node) -> void:
	var body: MeshInstance3D = rig.get("body_mesh") as MeshInstance3D
	var skeleton: Skeleton3D = rig.get("skeleton") as Skeleton3D

	if body == null or skeleton == null:
		return

	for child in skeleton.get_children():
		if child is MeshInstance3D and child.has_meta("shell_builder"):
			var mesh: ArrayMesh = shell_mesh(body.mesh, body.skin, skeleton, str(child.get_meta("shell_builder")))

			if mesh != null and (child as MeshInstance3D).mesh != mesh:
				(child as MeshInstance3D).mesh = mesh

			_copy_shapes(body, child as MeshInstance3D)


static func _copy_shapes(body: MeshInstance3D, node: MeshInstance3D) -> void:
	var source: ArrayMesh = body.mesh as ArrayMesh

	if source == null:
		return

	for k in range(source.get_blend_shape_count()):
		var i: int = node.find_blend_shape_by_name(source.get_blend_shape_name(k))

		if i >= 0:
			node.set_blend_shape_value(i, body.get_blend_shape_value(k))
