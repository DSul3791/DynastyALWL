extends "res://src/client/ragdoll_body.gd"

# The first-person arms made from Dave's own parts (assets/character/Humanoid/Dynasty_Base_Male_Parts_Split.glb, 1 Nov 2026; Kathleen). The file holds five rigid, unskinned pieces of one small figure
# (model_part0 and model_part4 are the two arms, 40 thousand triangles each; model_part1 the legs, model_part2 the torso, model_part3 the head), one material, three 2k and 4k textures.
# The arms are rigid, so each is cut here, by height, into an upper arm, a forearm and a hand, and each piece is hung on the matching bone of the old arms rig (ragdoll_body.gd with arms_only):
# the rig, its ten animations (idle, swing_fp, jab, throw, use ...), its hand mounts and the way held_item.gd and arms_view.gd place it are all unchanged, so the held tool, the swing's impact frame
# and the jab, throw and use keyframes behave as before; only the drawn arm is Dave's. The elbow bends at the cut (a hidden overlap keeps it closed); the wrist and the hand are one piece, so the
# fingers do not move. Default with the Dynasty body; `--oldbody` (or the Old body setting) keeps the old tube arms (held_item.gd).

const PARTS_GLB := "res://assets/character/Humanoid/Dynasty_Base_Male_Parts_Split.glb"
const UPPER_LEN := 0.29            # the rig's bone lengths (ragdoll_body.gd BONES): shoulder to elbow, elbow to wrist
const FORE_LEN := 0.26
const ELBOW_AT := 0.405            # fractions of the arm's length from the shoulder: the elbow, the wrist
const WRIST_AT := 0.743
const OVERLAP := 0.012             # each piece is cut this far (in the arm's own units, as a fraction of the length) beyond its joint so a bent elbow shows no gap

static var _pieces: Dictionary = {}          # "r" and "l": [upper, fore, hand] meshes, built once
static var _material: Material


func _init() -> void:
	super._init(true)
	name = "DynastyArms"
	if _pieces.is_empty():
		_load_pieces()

	# The file is not imported yet (a fresh checkout before `godot --import`): keep the old tube arms rather than draw nothing.
	if _pieces.is_empty():
		return

	body_mesh.visible = false                  # the old tube arms stay in the rig (they own the skeleton) but are not drawn
	set_meta("own_hands", true)                # held_item.gd: Dave's hands have fingers, no fist ball

	for side in ["r", "l"]:
		var rows: Array = _pieces[side]
		var bones: Array = ["arm_" + side, "forearm_" + side, "hand_" + side]

		for i in range(3):
			var attachment: BoneAttachment3D = BoneAttachment3D.new()
			attachment.name = "Dynasty_%s_%d" % [side, i]
			skeleton.add_child(attachment)
			attachment.bone_name = bones[i]
			var piece: MeshInstance3D = MeshInstance3D.new()
			piece.mesh = rows[i]
			piece.extra_cull_margin = 2.0
			attachment.add_child(piece)


# Finds the two arms among the five meshes (the two tall, thin parts on either side of the middle) and cuts each into three pieces with the elbow and wrist on the rig's bone lengths.
func _load_pieces() -> void:
	var packed: PackedScene = load(PARTS_GLB) as PackedScene

	if packed == null:
		push_error("dynasty_arms: %s is not imported (run godot --import once)" % PARTS_GLB)
		return

	var inst: Node = packed.instantiate()
	var arms: Array = []

	for c in inst.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c
		var box: AABB = mi.mesh.get_aabb()

		# An arm hangs beside the body: its middle is well to one side of the figure's middle (x = 0), and it is taller than wide.
		if absf(box.get_center().x) > 0.008 and box.size.y > box.size.x * 1.5:
			arms.append(mi)

		if _material == null:
			_material = mi.get_active_material(0)

	arms.sort_custom(func(a, b): return (a as MeshInstance3D).mesh.get_aabb().get_center().x < (b as MeshInstance3D).mesh.get_aabb().get_center().x)

	# The figure faces +Z (glTF), the game -Z: turned half a circle about Y, the arm at -X is the character's right (+X in the game).
	if arms.size() == 2:
		_pieces["r"] = _cut(arms[0].mesh as ArrayMesh)
		_pieces["l"] = _cut(arms[1].mesh as ArrayMesh)
	else:
		push_error("dynasty_arms: expected two arm parts in %s, found %d" % [PARTS_GLB, arms.size()])
		_pieces["r"] = [ArrayMesh.new(), ArrayMesh.new(), ArrayMesh.new()]
		_pieces["l"] = [ArrayMesh.new(), ArrayMesh.new(), ArrayMesh.new()]

	inst.free()


# The arm mesh cut into [upper arm, forearm, hand], each with its own joint at the origin, hanging down -Y, in metres, turned half a circle about Y.
func _cut(source: ArrayMesh) -> Array:
	var arrays: Array = source.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var box: AABB = source.get_aabb()
	var top: float = box.end.y
	var length: float = box.size.y

	# Dave's arms hang a little out from the body (about 14 degrees); the rig's bones hang straight down, so the arm is first swung about the shoulder until the line from the shoulder to the
	# wrist is vertical. Then the pieces' joints sit under each other and the elbow bends about the right point.
	var top_c: Vector3 = _centre_at(verts, top, length * 0.02)
	var wrist_c: Vector3 = _centre_at(verts, top - WRIST_AT * length, length * 0.02)
	var swing: Basis = Basis(Quaternion((wrist_c - top_c).normalized(), Vector3.DOWN))
	var bottom: float = 9.0
	top = -9.0

	for i in range(verts.size()):
		verts[i] = top_c + swing * (verts[i] - top_c)
		top = maxf(top, verts[i].y)
		bottom = minf(bottom, verts[i].y)

	length = top - bottom
	var scale: float = UPPER_LEN / (ELBOW_AT * length)
	var elbow_y: float = top - ELBOW_AT * length
	var wrist_y: float = top - WRIST_AT * length
	var joint_y: Array = [top, elbow_y, wrist_y]
	var joint: Array = []

	# The middle of the arm's cross-section at each joint height, so a piece's joint is on the arm's own axis.
	for jy in joint_y:
		var sum: Vector2 = Vector2.ZERO
		var n: int = 0

		for p in verts:
			if absf(p.y - float(jy)) < length * 0.02:
				sum += Vector2(p.x, p.z)
				n += 1

		var mid: Vector2 = sum / float(maxi(n, 1))
		joint.append(Vector3(mid.x, float(jy), mid.y))

	var pieces: Array = []
	var cuts: Array = [[top + 1.0, elbow_y - OVERLAP * length], [elbow_y + OVERLAP * length, wrist_y - OVERLAP * length], [wrist_y + OVERLAP * length, -1.0]]

	for k in range(3):
		var hi: float = float(cuts[k][0])
		var lo: float = float(cuts[k][1])
		var kept: PackedInt32Array = PackedInt32Array()

		for t in range(indices.size() / 3):
			var cy: float = (verts[indices[t * 3]].y + verts[indices[t * 3 + 1]].y + verts[indices[t * 3 + 2]].y) / 3.0

			if cy <= hi and cy >= lo:
				kept.append(t)

		# The file has positions and UVs only (the importer adds no normals): smooth normals and tangents are made here so the lighting and the normal map work.
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var turn: Basis = Basis(Vector3.UP, PI)
		var pivot: Vector3 = joint[k]
		var tool: SurfaceTool = SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)

		for t in kept:
			for c in range(3):
				var src: int = indices[t * 3 + c]
				tool.set_uv(uvs[src])
				tool.add_vertex(turn * ((verts[src] - pivot) * scale))

		if kept.size() > 0:
			tool.index()
			tool.generate_normals()
			tool.generate_tangents()
			tool.set_material(_material)

		pieces.append(tool.commit())

	return pieces


# The middle of the vertices within `band` of height `y`.
func _centre_at(verts: PackedVector3Array, y: float, band: float) -> Vector3:
	var sum: Vector3 = Vector3.ZERO
	var n: int = 0

	for p in verts:
		if absf(p.y - y) < band:
			sum += p
			n += 1

	return sum / float(maxi(n, 1))
