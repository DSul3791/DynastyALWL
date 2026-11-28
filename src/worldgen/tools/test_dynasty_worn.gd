extends SceneTree

# Worn clothing on Dave's body (dynasty_body.gd _worn_frames, worn_look.gd "worn_frames"): the pieces hang, each where it belongs on a 1.7 m body standing at the origin and
# facing -Z (boots at the feet, the hood on the head, the tunic on the chest, sleeves on the arms, gloves at the hands), in metres, right on the right; a second attach
# replaces the first. Run: godot --headless --path . --script res://src/worldgen/tools/test_dynasty_worn.gd
const Body := preload("res://src/client/character/dynasty_body.gd")
const WornLook := preload("res://src/client/worn_look.gd")
const Ragdoll := preload("res://src/client/ragdoll_body.gd")
const WornShell := preload("res://src/client/worn_shell.gd")
const Shapes := preload("res://src/client/character/dynasty_shapes.gd")
const Generator := preload("res://src/client/character/body_generator.gd")

var _fails: int = 0


# The balls on `bone` centred on its joint (worn_look.gd joint_caps, or a builder's own).
func _caps(parts: Array, bone: String) -> int:
	var n: int = 0

	for part in parts:
		if str(part["bone"]) == bone and str(part["shape"]).begins_with("sph") and (part["at"] as Vector3).length() < 0.03:
			n += 1

	return n


# The fitted layers (worn_shell.gd) on `s`, by garment.
func _shells(s: Skeleton3D) -> Dictionary:
	var out: Dictionary = {}

	for child in s.get_children():
		if child is MeshInstance3D and child.has_meta("shell_builder"):
			out[str(child.get_meta("shell_builder"))] = child

	return out


# Skin the body and its fitted layer on the CPU at the skeleton's current pose, as the renderer does (each vertex by its bones' pose times the skin's bind pose, weighted),
# and count the body's skin vertices the garment covers that its cloth does not: [covered vertices with no cloth vertex, cloth vertices not out in front of their skin
# point along the skin's normal by at least a third of the layer's distance in world metres, covered vertices]. A third, not all: where two bones turn far apart (the
# shoulder with the arm overhead) the blended normal shortens, and the layer comes nearer the skin there while still outside it.
func _bare(body_mesh: MeshInstance3D, shell: MeshInstance3D, s: Skeleton3D, region: Array, out_m: float) -> Array:
	var skin: Skin = body_mesh.skin
	var mats: Array = []

	for i in range(skin.get_bind_count()):
		var bone: int = skin.get_bind_bone(i)

		if bone < 0:
			bone = s.find_bone(skin.get_bind_name(i))

		mats.append(s.get_bone_global_pose(bone) * skin.get_bind_pose(i) if bone >= 0 else Transform3D.IDENTITY)

	var src: Array = (body_mesh.mesh as ArrayMesh).surface_get_arrays(0)
	var lay: Array = (shell.mesh as ArrayMesh).surface_get_arrays(0)
	var under: PackedInt32Array = ((shell.mesh.get_meta("source_vertices") as Array)[0] as Dictionary)["vertices"]
	var verts: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
	var bones: PackedInt32Array = src[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = src[Mesh.ARRAY_WEIGHTS]
	var cloth: PackedVector3Array = lay[Mesh.ARRAY_VERTEX]
	var c_bones: PackedInt32Array = lay[Mesh.ARRAY_BONES]
	var c_weights: PackedFloat32Array = lay[Mesh.ARRAY_WEIGHTS]
	var per: int = int(float(bones.size()) / float(verts.size()))
	var has_cloth: Dictionary = {}
	var thin: int = 0
	var to_world: float = s.global_transform.basis.x.length()

	for i in range(under.size()):
		var v: int = under[i]
		has_cloth[v] = true
		var p: Vector3 = Vector3.ZERO
		var q: Vector3 = Vector3.ZERO
		var n: Vector3 = Vector3.ZERO

		for k in range(per):
			var m: Transform3D = mats[bones[v * per + k]]
			p += (m * verts[v]) * weights[v * per + k]
			n += (m.basis * normals[v]) * weights[v * per + k]
			q += ((mats[c_bones[i * per + k]] as Transform3D) * cloth[i]) * c_weights[i * per + k]

		# Skeleton space to world metres (the skeleton is in centimetres under the model's 0.01): measured in the world, so a wrong unit anywhere shows as a layer too near.
		if (q - p).dot(n.normalized()) * to_world < out_m / 3.0:
			thin += 1

	var covered: int = 0
	var no_cloth: int = 0

	for v in range(verts.size()):
		var best: int = -1
		var best_w: float = 0.0

		for k in range(per):
			if weights[v * per + k] > best_w:
				best_w = weights[v * per + k]
				best = bones[v * per + k]

		var bone_name: String = String(skin.get_bind_name(best)) if best >= 0 else ""

		if bone_name == "" and best >= 0 and skin.get_bind_bone(best) >= 0:
			bone_name = s.get_bone_name(skin.get_bind_bone(best))

		if WornShell.short_name(bone_name) in region:
			covered += 1
			no_cloth += 0 if has_cloth.has(v) else 1

	return [no_cloth, thin, covered]


# Whether `p` (world) is inside a worn piece, by the shared mesh it draws (worn_look.gd _mesh; Godot's CylinderMesh puts a corner of the six-sided tube at +Z).
func _inside(node: MeshInstance3D, p: Vector3) -> bool:
	var q: Vector3 = node.global_transform.affine_inverse() * p

	if node.mesh == WornLook._mesh("box"):
		return absf(q.x) <= 0.5 and absf(q.y) <= 0.5 and absf(q.z) <= 0.5

	if node.mesh == WornLook._mesh("sphs"):
		return q.length() <= 0.5

	if node.mesh == WornLook._mesh("sph") or node.mesh == WornLook._mesh("sphl"):
		return q.length() <= 0.45      # the low spheres' faces dip under the radius

	for shape in [["cyl", 6], ["cyls", 16], ["frus", 16]]:
		if node.mesh == WornLook._mesh(str(shape[0])):
			var seg: float = TAU / float(shape[1])
			var ang: float = fposmod(atan2(q.x, q.z), seg) - seg * 0.5
			return absf(q.y) <= 0.5 and Vector2(q.x, q.z).length() <= 0.5 * cos(seg * 0.5) / cos(ang)

	return false


# The fitted layer's torso points (over the strongest bones in WornShell.TORSO) that stand outside every piece of the garment at the current pose: where the layer, not the
# garment's shape, is what shows (Lane A qa15e, 26 Nov 2026: Dave's back muscles showed through as cloth-coloured lumps). [outside, torso points, outside over the
# shoulder blades: behind the chest frame's middle, 5 to 20 cm up it].
func _showing(body_mesh: MeshInstance3D, shell: MeshInstance3D, s: Skeleton3D) -> Array:
	var skin: Skin = body_mesh.skin
	var mats: Array = []

	for i in range(skin.get_bind_count()):
		var bone: int = skin.get_bind_bone(i)

		if bone < 0:
			bone = s.find_bone(skin.get_bind_name(i))

		mats.append(s.get_bone_global_pose(bone) * skin.get_bind_pose(i) if bone >= 0 else Transform3D.IDENTITY)

	var pieces: Array = []

	for holder in s.get_children():
		if str(holder.name).begins_with("Worn_") and not holder.has_meta("shell_builder"):
			pieces.append_array(holder.find_children("*", "MeshInstance3D", true, false))

	var lay: Array = (shell.mesh as ArrayMesh).surface_get_arrays(0)
	var under: PackedInt32Array = ((shell.mesh.get_meta("source_vertices") as Array)[0] as Dictionary)["vertices"]
	var src: Array = (body_mesh.mesh as ArrayMesh).surface_get_arrays(0)
	var bones: PackedInt32Array = src[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = src[Mesh.ARRAY_WEIGHTS]
	var cloth: PackedVector3Array = lay[Mesh.ARRAY_VERTEX]
	var c_bones: PackedInt32Array = lay[Mesh.ARRAY_BONES]
	var c_weights: PackedFloat32Array = lay[Mesh.ARRAY_WEIGHTS]
	var per: int = int(float(c_bones.size()) / float(cloth.size()))
	var outside: int = 0
	var torso: int = 0
	var blades: int = 0
	var chest: Node3D = s.get_node_or_null("Worn_chest/Frame") as Node3D
	var to_chest: Transform3D = chest.global_transform.affine_inverse() if chest != null else Transform3D.IDENTITY

	for i in range(cloth.size()):
		var v: int = under[i]
		var best: int = -1
		var best_w: float = 0.0

		for k in range(per):
			if weights[v * per + k] > best_w:
				best_w = weights[v * per + k]
				best = bones[v * per + k]

		if best < 0 or not (WornShell.short_name(String(skin.get_bind_name(best))) in WornShell.TORSO):
			continue

		torso += 1
		var q: Vector3 = Vector3.ZERO

		for k in range(per):
			q += ((mats[c_bones[i * per + k]] as Transform3D) * cloth[i]) * c_weights[i * per + k]

		var p: Vector3 = s.global_transform * q
		var hidden: bool = false

		for node in pieces:
			if _inside(node as MeshInstance3D, p):
				hidden = true
				break

		if not hidden:
			outside += 1
			var c: Vector3 = to_chest * p
			blades += 1 if chest != null and c.z > 0.0 and c.y > 0.05 and c.y < 0.2 else 0

	return [outside, torso, blades]


# Points on a piece's surface in its own unit space (WornLook._mesh shapes), for _standoff.
func _surface(node: MeshInstance3D) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()

	if node.mesh == WornLook._mesh("box"):
		for a in range(5):
			for b in range(5):
				for c in [-0.5, 0.5]:
					var u: float = -0.5 + 0.25 * float(a)
					var v: float = -0.5 + 0.25 * float(b)
					out.append(Vector3(u, v, c))
					out.append(Vector3(u, c, v))
					out.append(Vector3(c, u, v))
		return out

	for shape in [["cyl", 6], ["cyls", 16], ["frus", 16]]:
		if node.mesh == WornLook._mesh(str(shape[0])):
			for ring in range(9):
				for k in range(int(shape[1])):
					var a0: float = TAU * float(k) / float(shape[1])
					var a1: float = TAU * float(k + 1) / float(shape[1])
					for t in range(5):
						var e: Vector2 = Vector2(sin(a0), cos(a0)).lerp(Vector2(sin(a1), cos(a1)), float(t) / 4.0) * 0.5     # CylinderMesh: x = sin, z = cos
						out.append(Vector3(e.x, -0.5 + 0.125 * float(ring), e.y))
			return out

	var r: float = 0.5 if node.mesh == WornLook._mesh("sphs") else 0.45
	for i in range(13):
		for j in range(24):
			var th: float = PI * float(i) / 12.0
			var ph: float = TAU * float(j) / 24.0
			out.append(Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph)) * r)
	return out


# How far the garment's chest pieces stand off Dave's body at the current pose, in the chest frame (+Z the back): by 5 cm of height, the garment's furthest back point
# past the body's (within 12 cm of the middle), and its furthest side point past the body's; the most of each [back, side] (Lane A qa15f, 26 Nov 2026: a round
# shoulder mantle read as a hump from the back and the side; an offline count of uncovered points did not see it).
func _standoff(body_mesh: MeshInstance3D, s: Skeleton3D) -> Array:
	var chest: Node3D = s.get_node_or_null("Worn_chest/Frame") as Node3D

	if chest == null:
		return [INF, INF]

	var to_chest: Transform3D = chest.global_transform.affine_inverse()
	var skin: Skin = body_mesh.skin
	var mats: Array = []

	for i in range(skin.get_bind_count()):
		var bone: int = skin.get_bind_bone(i)

		if bone < 0:
			bone = s.find_bone(skin.get_bind_name(i))

		mats.append(s.get_bone_global_pose(bone) * skin.get_bind_pose(i) if bone >= 0 else Transform3D.IDENTITY)

	var src: Array = (body_mesh.mesh as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = src[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = src[Mesh.ARRAY_WEIGHTS]
	var per: int = int(float(bones.size()) / float(verts.size()))
	var body: Dictionary = {}      # band -> [back, side, middle back seen]
	var cloth: Dictionary = {}

	for v in range(verts.size()):
		var best: int = -1
		var best_w: float = 0.0
		var q: Vector3 = Vector3.ZERO

		for k in range(per):
			var w: float = weights[v * per + k]
			q += ((mats[bones[v * per + k]] as Transform3D) * verts[v]) * w

			if w > best_w:
				best_w = w
				best = bones[v * per + k]

		if best < 0 or not (WornShell.short_name(String(skin.get_bind_name(best))) in WornShell.TORSO + ["Neck"]):
			continue

		_band(body, to_chest * (s.global_transform * q))

	for node in chest.get_children():
		if node is MeshInstance3D:
			var m: Transform3D = to_chest * (node as MeshInstance3D).global_transform
			for p in _surface(node as MeshInstance3D):
				_band(cloth, m * p)

	var back: float = -INF
	var side: float = -INF

	for band in cloth.keys():
		if not body.has(band):
			continue

		var g: Array = cloth[band]
		var b: Array = body[band]
		side = maxf(side, float(g[1]) - float(b[1]))

		if float(g[0]) > -INF and float(b[0]) > -INF:
			back = maxf(back, float(g[0]) - float(b[0]))

	return [back, side]


# A point into its 5 cm height band: [furthest back within 12 cm of the middle, furthest out to either side].
func _band(bands: Dictionary, c: Vector3) -> void:
	if c.y < -0.3 or c.y >= 0.35:
		return

	var band: int = floori(c.y / 0.05)
	var row: Array = bands.get(band, [-INF, -INF])

	if absf(c.x) < 0.12:
		row[0] = maxf(float(row[0]), c.z)

	row[1] = maxf(float(row[1]), absf(c.x))
	bands[band] = row


# The chest's flat front details lie on it (Lane A qa15f and qa15g, 26 Nov 2026: the gambeson's quilting stood out in front of it, the shirt's lacing stood proud above it):
# each one's back face, at its top, middle and foot, is inside the chest tube. [details, details with their back face inside].
func _quilting(s: Skeleton3D) -> Array:
	var chest: Node3D = s.get_node_or_null("Worn_chest/Frame") as Node3D
	var tube: MeshInstance3D = null
	var strips: Array = []

	if chest == null:
		return [0, 0]

	for node in chest.get_children():
		if not (node is MeshInstance3D):
			continue

		var mi: MeshInstance3D = node as MeshInstance3D
		var scale: Vector3 = mi.transform.basis.get_scale()

		if mi.mesh == WornLook._mesh("cyl") and tube == null and scale.y > 0.3:
			tube = mi
		elif mi.mesh == WornLook._mesh("box") and scale.x < 0.03:
			strips.append(mi)

	var lying: int = 0

	for strip in strips:
		var ok: bool = tube != null

		for y in [-0.45, 0.0, 0.45]:
			ok = ok and _inside(tube, (strip as MeshInstance3D).global_transform * Vector3(0.0, y, 0.5))

		lying += 1 if ok else 0

	return [strips.size(), lying]


# The layer's points over the Neck bone (by their body vertex's strongest bone), in the mesh's rest: [count, the highest one's height, the neck joint's height].
func _neck_band(body_mesh: MeshInstance3D, shell: MeshInstance3D) -> Array:
	var skin: Skin = body_mesh.skin
	var neck_y: float = INF

	for i in range(skin.get_bind_count()):
		if WornShell.short_name(String(skin.get_bind_name(i))) == "Neck":
			neck_y = skin.get_bind_pose(i).affine_inverse().origin.y

	var src: Array = (body_mesh.mesh as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = src[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = src[Mesh.ARRAY_WEIGHTS]
	var per: int = int(float(bones.size()) / float(verts.size()))
	var under: PackedInt32Array = ((shell.mesh.get_meta("source_vertices") as Array)[0] as Dictionary)["vertices"]
	var count: int = 0
	var top: float = -INF

	for v in under:
		var best: int = -1
		var best_w: float = 0.0

		for k in range(per):
			if weights[v * per + k] > best_w:
				best_w = weights[v * per + k]
				best = bones[v * per + k]

		if best >= 0 and WornShell.short_name(String(skin.get_bind_name(best))) == "Neck":
			count += 1
			top = maxf(top, verts[v].y)

	return [count, top, neck_y]


func _check(ok: bool, what: String) -> void:
	print(("pass " if ok else "FAIL ") + what)
	_fails += 0 if ok else 1


# Every worn piece's world position, by the old bone it was written for.
# The rigid chest tubes hung on the chest (the long cylinders, not the collar rings).
func _chest_tubes(s: Skeleton3D) -> int:
	var chest: Node3D = s.get_node_or_null("Worn_chest/Frame") as Node3D
	var n: int = 0

	if chest == null:
		return 0

	for node in chest.get_children():
		if node is MeshInstance3D and (node as MeshInstance3D).mesh == WornLook._mesh("cyl") and (node as MeshInstance3D).transform.basis.get_scale().y > 0.3:
			n += 1

	return n


func _pieces(skeleton: Skeleton3D) -> Dictionary:
	var out: Dictionary = {}

	for holder in skeleton.get_children():
		if not str(holder.name).begins_with("Worn_"):
			continue

		var old: String = str(holder.name).trim_prefix("Worn_")

		for node in holder.find_children("*", "MeshInstance3D", true, false):
			if not out.has(old):
				out[old] = []

			out[old].append(node)

	return out


func _init() -> void:
	if not Body.available():
		print("dynasty worn tests: Dave's body is not imported, nothing to test")
		quit()
		return

	var body: Node3D = Body.new()
	root.add_child(body)
	body.play("idle", 1.0, 0.0)
	body.animation_player.seek(0.0, true)
	# Held on the first frame: under a loaded gate the two frames below can be long and the idle would play on, so the pose (and every height checked) would
	# depend on the machine's speed (PC gate 5 Nov: the hood's cape read 1.30 m in the gate and passed alone).
	body.animation_player.speed_scale = 0.0
	var s: Skeleton3D = body.skeleton
	Shapes.wait()      # the body's shapes made first, so the skin's tuck-in below is set at once and checked (dynasty_shapes.gd COVERS)
	var hung: int = WornLook.attach(body, ["hide_boots", "hide_tunic", "hide_hood", "hide_trousers", "hide_gloves"], false)
	await process_frame
	await process_frame
	_check(hung > 10, "the outfit hangs pieces (%d)" % hung)
	# BugsList 187: the skin under the outfit tucks in (dynasty_shapes.gd COVERS); the hood leaves the head and neck as they are.
	var covered: Array = body.get("_covered")

	for group in ["foot", "shin", "thigh", "hips", "chest", "arm", "forearm", "hand"]:
		_check(group in covered, "skin tucked in under the outfit on " + group)

	var cover_i: int = body.body_mesh.find_blend_shape_by_name("cover_shin")
	_check(cover_i >= 0 and absf(body.body_mesh.get_blend_shape_value(cover_i) - 1.0) < 0.001, "cover_shin weight 1 under boots")
	var pieces: Dictionary = _pieces(s)

	for old in ["foot_r", "foot_l", "shin_r", "thigh_r", "hips", "chest", "head", "arm_r", "forearm_l", "hand_r", "hand_l"]:
		_check(pieces.has(old), "pieces on " + old)

	for node in pieces.get("foot_r", []) + pieces.get("foot_l", []):
		var at: Vector3 = (node as Node3D).global_position
		_check(at.y > -0.02 and at.y < 0.16, "boot foot at the ground (y %.2f)" % at.y)

	for node in pieces.get("foot_r", []):
		_check((node as Node3D).global_position.x > 0.05, "right boot on the right (+X)")

	# The hood's crown (its big shell) sits on his head; its shoulder cape hangs round the neck down to the tops of the shoulders (his neck joint is at about
	# 1.40 m, the cape's middle about 7 cm under the hood frame's chin line), so pieces sit between the shoulders and the crown.
	var crown_y: float = -1.0

	for node in pieces.get("head", []):
		var at: Vector3 = (node as Node3D).global_position
		crown_y = maxf(crown_y, at.y)
		_check(at.y > 1.25 and at.y < 1.8, "hood piece at the head, neck or shoulders (y %.2f)" % at.y)

	_check(crown_y > 1.45, "hood crown on the head (y %.2f)" % crown_y)

	for node in pieces.get("chest", []):
		var at: Vector3 = (node as Node3D).global_position
		_check(at.y > 0.85 and at.y < 1.6 and absf(at.x) < 0.12, "tunic on the chest (%.2f, %.2f)" % [at.x, at.y])

	for node in pieces.get("arm_r", []):
		var at: Vector3 = (node as Node3D).global_position
		_check(at.x > 0.12 and at.y > 1.0 and at.y < 1.5, "right sleeve on the right upper arm (%.2f, %.2f)" % [at.x, at.y])   # up to 1.5: the shoulder's joint ball (QA #15) sits on the joint

	for side in ["r", "l"]:
		var hand: Vector3 = (s.global_transform * s.get_bone_global_pose(s.find_bone("mixamorig_" + ("RightHand" if side == "r" else "LeftHand")))).origin

		for node in pieces.get("hand_" + side, []):
			_check((node as Node3D).global_position.distance_to(hand) < 0.25, "glove at the %s hand" % side)

	# Metres: a boot's shin cylinder is 0.14 m wide plus a 3 cm layer, whatever the skeleton's centimetre scale.
	var widest: float = 0.0

	for node in pieces.get("shin_r", []):
		widest = maxf(widest, (node as Node3D).global_transform.basis.get_scale().x)

	_check(widest > 0.12 and widest < 0.3, "pieces are metre-sized (shin %.3f)" % widest)
	# QA #15 (25 Nov 2026, "limbs not attached"): a garment that covers both sides of a joint puts a ball of its colour on it (worn_look.gd joint_caps), on the child
	# bone at the joint, so a bent elbow or a raised arm never opens a gap between rigid pieces.
	var tunic: Array = WornLook.parts_of("tunic", 0.03)
	_check(_caps(tunic, "arm_r") == 1 and _caps(tunic, "forearm_r") == 1 and _caps(tunic, "arm_l") == 1 and _caps(tunic, "forearm_l") == 1, "a sleeved tunic has a ball at each shoulder and elbow")
	_check(_caps(WornLook.parts_of("padded", 0.03), "forearm_l") == 1 and _caps(WornLook.parts_of("trousers", 0.0), "thigh_r") == 1 and _caps(WornLook.parts_of("gloves", 0.0), "hand_r") == 1, "the gambeson's elbow, the trousers' hip and the gloves' wrist are joined")
	var mail: Array = WornLook.parts_of("mailshirt", 0.03)
	_check(_caps(mail, "arm_r") == 1 and _caps(mail, "forearm_r") == 0, "a short mail sleeve joins at the shoulder only (it does not reach the elbow)")
	_check(_caps(WornLook.parts_of("leggings", 0.0), "shin_r") == 1, "the leggings' own knee ball is not doubled")
	_check(WornLook.joint_caps(WornLook.parts_of("hood", 0.0)).is_empty() and WornLook.joint_caps(WornLook.parts_of("cloak", 0.0)).is_empty(), "no balls where a garment bends at no joint")
	# BugsList 188: a pack's chest straps lie on the bare chest, and further out over a shirt (attach `under`).
	var bare_strap: Vector3 = (WornLook.parts_of("pack", 0.045, false, 0.0).back() as Dictionary)["at"]
	var shirt_strap: Vector3 = (WornLook.parts_of("pack", 0.045, false, 0.045).back() as Dictionary)["at"]
	_check(bare_strap.z > -0.12 and shirt_strap.z < bare_strap.z - 0.03, "the pack's chest strap lies on the bare chest (z %.3f) and over a shirt (z %.3f)" % [bare_strap.z, shirt_strap.z])

	# The joint heights are ragdoll_body.gd's bone offsets, and on Dave's body the ball sits on his own joint.
	var bones: Dictionary = {}

	for row in Ragdoll.BONES:
		bones[str(row[0])] = row

	var heights_match: bool = true

	for joint in WornLook.JOINTS:
		heights_match = heights_match and str(bones[joint[1]][1]) == str(joint[0]) and is_equal_approx((bones[joint[1]][2] as Vector3).y, float(joint[2]))

	_check(heights_match, "the worn joints are the rig's joints (ragdoll_body.gd BONES)")

	for bone_pair in [["arm_r", "mixamorig_RightArm"], ["forearm_l", "mixamorig_LeftForeArm"]]:
		var joint_at: Vector3 = (s.global_transform * s.get_bone_global_pose(s.find_bone(str(bone_pair[1])))).origin
		var nearest: float = INF

		for node in pieces.get(str(bone_pair[0]), []):
			nearest = minf(nearest, (node as Node3D).global_position.distance_to(joint_at))

		_check(nearest < 0.03, "a ball on the %s joint of Dave's body (%.3f m off)" % [str(bone_pair[0]), nearest])

	for part in tunic:
		if str(part["bone"]) == "arm_r" and str(part["shape"]) == "sph":
			_check(float((part["size"] as Vector3).x) >= 0.15, "the shoulder ball is wider than the sleeve (%.3f m)" % float((part["size"] as Vector3).x))

	# QA #15 (26 Nov 2026, Lane A stills: skin through the back of the gambeson at the shoulder blades at idle; with the arm raised in the chop, bare neck, upper chest and
	# armpit between the vest and the sleeve): a sleeved garment on Dave's body also hangs a fitted layer, skinned like the body (worn_shell.gd), so no skin it covers shows
	# from any side in any pose. Counted at idle and at the chop frames the stills show (t 0.1, 0.3, 0.5, 0.7), for the shirt, the gambeson and the mail shirt. The layers are
	# made on a worker (below); here each one is waited for (WornShell.wait) and put on (refresh) before it is measured.
	WornShell.wait()
	WornShell.refresh(body)
	_check(_shells(s).keys() == ["tunic"], "the tunic hangs one fitted layer on Dave's body (%s)" % str(_shells(s).keys()))
	var tunic_shell: MeshInstance3D = _shells(s).get("tunic", null)
	_check(tunic_shell != null and tunic_shell.skin == body.body_mesh.skin and tunic_shell.get_node_or_null(tunic_shell.skeleton) == s, "the layer is skinned to Dave's skeleton with his body's skin")

	for garment in [["gambeson", "padded"], ["linen_shirt", "tunic"], ["mail_shirt", "mailshirt"]]:
		WornLook.attach(body, [str(garment[0])], false)
		WornShell.wait()
		WornShell.refresh(body)
		body.play("idle", 1.0, 0.0)
		body.animation_player.seek(0.0, true)
		await process_frame
		var shell: MeshInstance3D = _shells(s).get(str(garment[1]), null)
		_check(shell != null, "%s hangs its fitted layer" % str(garment[0]))

		if shell == null:
			continue

		# At idle the garment's own shape shows over his shoulder blades, not the layer under it (the blades stood out through it before the chest pieces were fitted to
		# Dave's body, worn_shell.gd CHEST_TURN; offline: 245 gambeson and 308 shirt of about 3600 torso points, fitted 40 and 75). The tops of the shoulders above the
		# chest tube are the layer's: the garment's own shoulders.
		# The gambeson's layer is its chest on his body (worn_shell.gd LAYER_IS_CHEST), so only the shirt is counted.
		if str(garment[1]) == "tunic":
			var showing: Array = _showing(body.body_mesh, shell, s)
			_check(int(showing[1]) > 2000 and int(showing[2]) * 100 <= int(showing[1]) * 3,
				"%s at idle: the layer shows over the shoulder blades at %d of %d torso points (at most 3%%; outside the pieces anywhere %d)" % [str(garment[0]), int(showing[2]), int(showing[1]), int(showing[0])])

		# The garment does not stand off his body: no hump at the back or side (offline at idle: at most 7.5 cm off the back and 8 cm past the sides; the mantle stood 10.6).
		var standoff: Array = _standoff(body.body_mesh, s)
		_check(float(standoff[0]) <= 0.085 and float(standoff[1]) <= 0.085,
			"%s at idle stands off the body at most %.3f m at the back and %.3f m at the sides (at most 0.085)" % [str(garment[0]), float(standoff[0]), float(standoff[1])])

		var details: Array = _quilting(s)
		var want: int = {"tunic": 1}.get(str(garment[1]), 0)      # the gambeson's quilting is in its cloth (worn_look.gd "quilted")
		_check(int(details[0]) == want and int(details[1]) == want, "%s's %d flat chest details (of %d) lie on its chest: %d" % [str(garment[0]), int(details[0]), want, int(details[1])])

		# Each garment's layer stops at the neck (a 9 cm band up the gambeson's neck read as a neck brace and left the throat bare with the arm raised, Lane A qa15g).
		var neck_band: Array = _neck_band(body.body_mesh, shell)
		_check(int(neck_band[0]) == 0, "%s's layer leaves the neck bare (%d neck points)" % [str(garment[0]), int(neck_band[0])])

		for pose in [["idle", 0.0], ["chop", 0.1], ["chop", 0.3], ["chop", 0.5], ["chop", 0.7]]:
			body.play(str(pose[0]), 1.0, 0.0)
			body.animation_player.seek(float(pose[1]), true)
			await process_frame
			var bare: Array = _bare(body.body_mesh, shell, s, WornShell.REGIONS[str(garment[1])], float(WornShell.OUT_M[str(garment[1])]))
			_check(int(bare[2]) > 3000 and int(bare[0]) * 100 <= int(bare[2]) and int(bare[1]) * 1000 <= int(bare[2]),
				"%s at %s t%.1f: skin covered %d, with no cloth %d (the region's ragged edge, at most 1%%), cloth too near the skin %d (at most 0.1%%)" % [str(garment[0]), str(pose[0]), float(pose[1]), int(bare[2]), int(bare[0]), int(bare[1])])

	# Made on a worker (Lane A 26 Nov 2026: on the main thread it held the frame 36 to 49 ms the first time a garment was worn): over a body mesh it has not seen, the layer
	# hangs at once without a mesh while its worker runs, and the body fills it in a later frame (dynasty_body.gd _process).
	var plain: Mesh = body.body_mesh.mesh
	body.body_mesh.mesh = plain.duplicate()
	var t_hang: int = Time.get_ticks_msec()
	WornLook.attach(body, ["gambeson"], false)
	var hang_ms: int = Time.get_ticks_msec() - t_hang
	var late: MeshInstance3D = _shells(s).get("padded", null)
	var was_waiting: bool = late != null and late.mesh == null
	var frames_waited: int = 0

	while late != null and late.mesh == null and frames_waited < 600:
		await process_frame
		frames_waited += 1

	_check(was_waiting and late.mesh != null and late.mesh.get_blend_shape_count() == body.body_mesh.mesh.get_blend_shape_count(),
		"a new mesh's layer is made on a worker (the attach did not wait: %s, %d ms) and put on by the body %d frames later" % ["yes" if was_waiting else "NO", hang_ms, frames_waited])
	body.body_mesh.mesh = plain
	# The width sliders (dynasty_shapes.gd): a shaped body's layer is made from the shaped mesh, carries the same shapes and takes the body's weights.
	var g: Dictionary = Generator.make_genome()
	g["build"] = 0.6
	g["bust"] = 0.5
	Shapes.prewarm(body.body_mesh.mesh, body.body_mesh.skin, s)
	Shapes.wait()
	body.set_proportions(g)
	WornLook.attach(body, ["gambeson"], false)
	WornShell.wait()
	WornShell.refresh(body)
	await process_frame
	var wide: MeshInstance3D = _shells(s).get("padded", null)
	var build_at: int = wide.find_blend_shape_by_name("build") if wide != null else -1
	var body_build: int = body.body_mesh.find_blend_shape_by_name("build")
	_check(wide != null and wide.mesh.get_blend_shape_count() == body.body_mesh.mesh.get_blend_shape_count() and wide.mesh.get_blend_shape_count() > 0,
		"a shaped body's layer has the body's width shapes (%d of %d)" % [wide.mesh.get_blend_shape_count() if wide != null else -1, body.body_mesh.mesh.get_blend_shape_count()])
	_check(build_at >= 0 and body_build >= 0 and is_equal_approx(wide.get_blend_shape_value(build_at), body.body_mesh.get_blend_shape_value(body_build)) and body.body_mesh.get_blend_shape_value(body_build) > 0.5,
		"the layer takes the body's build weight (%.2f)" % (wide.get_blend_shape_value(build_at) if build_at >= 0 else -1.0))
	g["build"] = -0.4
	body.set_proportions(g)
	_check(build_at >= 0 and is_equal_approx(wide.get_blend_shape_value(build_at), -0.4), "a slider move reaches the layer (%.2f)" % (wide.get_blend_shape_value(build_at) if build_at >= 0 else -1.0))
	var shaped_bare: Array = _bare(body.body_mesh, wide, s, WornShell.REGIONS["padded"], float(WornShell.OUT_M["padded"])) if wide != null else [0, 0, 0]
	_check(int(shaped_bare[2]) > 3000 and int(shaped_bare[1]) * 1000 <= int(shaped_bare[2]), "the shaped layer stands out from the skin (too near %d of %d)" % [int(shaped_bare[1]), int(shaped_bare[2])])
	WornLook.attach(body, ["gambeson"], true)
	await process_frame
	_check(_shells(s).is_empty(), "a far body hangs no fitted layer")
	_check(_chest_tubes(s) == 1, "a far gambeson keeps its chest tube (%d)" % _chest_tubes(s))
	# The gambeson's own shape (Dave, 28 Nov 2026; BugsList 158: its chest tube read as a squared block from the side): near, on Dave's body, its fitted layer is its chest
	# and no rigid chest tube is hung; a shirt worn under it hangs no chest pieces through it, and the mail shirt over it keeps its own.
	WornLook.attach(body, ["linen_shirt", "gambeson", "mail_shirt"], false)
	await process_frame
	_check(_chest_tubes(s) == 1 and _shells(s).has("padded") and _shells(s).has("tunic") and _shells(s).has("mailshirt"),
		"shirt, gambeson and mail on Dave's body: one chest tube (the mail's: %d) and all three layers (%s)" % [_chest_tubes(s), str(_shells(s).keys())])
	_check(float(WornShell.OUT_M["tunic"]) < float(WornShell.OUT_M["padded"]) and float(WornShell.OUT_M["padded"]) < float(WornShell.OUT_M["mailshirt"]), "the shirt under the gambeson under the mail")
	WornLook.attach(body, ["gambeson"], false)
	await process_frame
	_check(_chest_tubes(s) == 0, "a near gambeson on Dave's body hangs no chest tube (%d)" % _chest_tubes(s))
	var old_body: Node3D = Ragdoll.new()
	root.add_child(old_body)
	WornLook.attach(old_body, ["gambeson"], false)
	_check(_shells(old_body.get("skeleton") as Skeleton3D).is_empty(), "the old ragdoll body (not one skinned mesh) hangs no fitted layer")
	old_body.queue_free()
	body.play("idle", 1.0, 0.0)
	body.animation_player.seek(0.0, true)
	WornLook.attach(body, ["hide_hood"], false)
	await process_frame
	var after: Dictionary = _pieces(s)
	_check(after.keys() == ["head"], "a second attach replaces the first (%s)" % str(after.keys()))
	print("dynasty worn tests: %d failures" % _fails)
	quit(1 if _fails > 0 else 0)
