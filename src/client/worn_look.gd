extends RefCounted

# Worn clothing (Kathleen, goal 1f). `attach(rig, item_ids, far)` hangs one mesh set per item on the named bones of a RagdollBody (hips, chest, head, hand_*, thigh_*, shin_*, foot_*),
# replacing whatever was attached before, so Steve's sync code calls it once with the ids the server sends. Items come from data/items/worn.json (builder, colour, layer).
# Parts are low-poly spheres, boxes and cylinders in the bone's own space (limbs run down -Y, the front of the body is -Z, right is +X). Meshes and materials are shared and cached.
# A layer stands LAYER_M further out (1.5 cm) so a cloak over leggings does not z-fight. Far bodies (beyond about 30 m) skip the detail parts (mittens' thumbs, straps, fringe).

const WORN_PATH := "res://data/items/worn.json"
const LAYER_M := 0.015
const BUILDERS := ["cloak", "hood", "boots", "leggings", "mittens", "skirt", "sandals", "pack"]
const HUMANOID_NAMES := {
	"hips": "Hips", "chest": "Chest", "head": "Head",
	"hand_r": "RightHand", "hand_l": "LeftHand", "forearm_r": "RightLowerArm", "forearm_l": "LeftLowerArm", "arm_r": "RightUpperArm", "arm_l": "LeftUpperArm",
	"thigh_r": "RightUpperLeg", "thigh_l": "LeftUpperLeg", "shin_r": "RightLowerLeg", "shin_l": "LeftLowerLeg", "foot_r": "RightFoot", "foot_l": "LeftFoot",
}

static var _table: Dictionary = {}
static var _loaded: bool = false
static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}


static func table() -> Dictionary:
	if not _loaded:
		_loaded = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(WORN_PATH))

		if parsed is Dictionary:
			_table = parsed.get("items", {})

	return _table


static func has_worn(item_id: String) -> bool:
	return table().has(item_id)


# Replace the worn meshes on `rig` (a RagdollBody) with those of `item_ids`. Returns the number of parts hung.
static func attach(rig: Node, item_ids: Array, far: bool = false) -> int:
	var skeleton: Skeleton3D = rig.get("skeleton") as Skeleton3D

	if skeleton == null:
		return 0

	for child in skeleton.get_children():
		if str(child.name).begins_with("Worn_"):
			skeleton.remove_child(child)
			child.queue_free()

	var anchors: Dictionary = {}
	var count: int = 0

	for item_id in item_ids:
		var row: Dictionary = table().get(str(item_id), {})

		if row.is_empty():
			continue

		var out: float = float(int(row.get("layer", 1))) * LAYER_M

		for part in parts_of(str(row["builder"]), out, bool(row.get("fringe", false))):
			if far and bool(part.get("detail", false)):
				continue

			var bone: String = str(part["bone"])

			# The generated body (src/client/character/body_generator.gd) has humanoid bone names; the parts below are written for the old names, so they are mapped
			# when the skeleton has no bone of the old name. The old body is untouched by this.
			if skeleton.find_bone(bone) < 0 and HUMANOID_NAMES.has(bone):
				bone = str(HUMANOID_NAMES[bone])

			if not anchors.has(bone):
				var anchor: BoneAttachment3D = BoneAttachment3D.new()
				anchor.name = "Worn_" + bone
				skeleton.add_child(anchor)
				anchor.bone_name = bone
				anchors[bone] = anchor

			var node: MeshInstance3D = MeshInstance3D.new()
			node.mesh = _mesh(str(part["shape"]))
			node.material_override = _material(Color.html(str(row["color"])).darkened(float(part.get("dark", 0.0))))
			node.transform = Transform3D(Basis.from_euler(part.get("rot", Vector3.ZERO)).scaled(part["size"]), part["at"])
			anchors[bone].add_child(node)
			count += 1

	return count


static func _mesh(shape: String) -> Mesh:
	if not _meshes.has(shape):
		var mesh: Mesh
		if shape == "box":
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3.ONE
			mesh = box
		elif shape == "cyl":
			var cyl: CylinderMesh = CylinderMesh.new()
			cyl.top_radius = 0.5
			cyl.bottom_radius = 0.5
			cyl.height = 1.0
			cyl.radial_segments = 6
			cyl.rings = 1
			cyl.cap_top = false
			cyl.cap_bottom = false
			mesh = cyl
		elif shape == "cone":
			var cone: CylinderMesh = CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.5
			cone.height = 1.0
			cone.radial_segments = 5
			cone.rings = 1
			cone.cap_bottom = false
			mesh = cone
		else:
			var sph: SphereMesh = SphereMesh.new()
			sph.radius = 0.5
			sph.height = 1.0
			sph.radial_segments = 5 if shape == "sphl" else 6
			sph.rings = 2 if shape == "sphl" else 3
			mesh = sph
		_meshes[shape] = mesh

	return _meshes[shape]


static func _material(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html()

	if not _materials.has(key):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 1.0
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[key] = m

	return _materials[key]


static func _p(bone: String, shape: String, at: Vector3, size: Vector3, rot: Vector3 = Vector3.ZERO, detail: bool = false, dark: float = 0.0) -> Dictionary:
	return {"bone": bone, "shape": shape, "at": at, "size": size, "rot": rot, "detail": detail, "dark": dark}


# The parts of one builder, in bone space; `o` is the outward offset of the layer. Sizes are full extents (the shared meshes have radius/edge 0.5).
static func parts_of(builder: String, o: float, fringe: bool = false) -> Array:
	var out: Array = []

	match builder:
		"cloak":
			# Shoulder cape, a back panel in three flaring steps down to the knees, and a clasp at the throat.
			out.append(_p("chest", "sphl", Vector3(0.0, 0.26, 0.01), Vector3(0.5 + o * 2.0, 0.16, 0.34 + o * 2.0)))
			out.append(_p("chest", "box", Vector3(0.0, 0.1, 0.15 + o), Vector3(0.46, 0.34, 0.03)))
			out.append(_p("chest", "box", Vector3(0.0, -0.24, 0.17 + o), Vector3(0.56, 0.36, 0.03), Vector3(0.1, 0.0, 0.0), false, 0.05))
			out.append(_p("chest", "box", Vector3(0.0, -0.58, 0.2 + o), Vector3(0.68, 0.36, 0.03), Vector3(0.14, 0.0, 0.0), false, 0.1))
			out.append(_p("chest", "sphl", Vector3(0.0, 0.27, -0.12 - o), Vector3(0.05, 0.05, 0.03), Vector3.ZERO, true, -0.4))

			if fringe:
				for k in range(7):
					out.append(_p("chest", "cone", Vector3(-0.3 + 0.1 * float(k), -0.82, 0.22 + o), Vector3(0.07, 0.2, 0.02), Vector3(PI, 0.0, 0.0), true, 0.1))
		"hood":
			out.append(_p("head", "sph", Vector3(0.0, 0.12, 0.045), Vector3(0.27 + o * 2.0, 0.28 + o * 2.0, 0.28 + o * 2.0)))
			out.append(_p("head", "cyl", Vector3(0.0, 0.04, 0.0), Vector3(0.3 + o * 2.0, 0.1, 0.3 + o * 2.0), Vector3.ZERO, false, 0.05))
		"boots":
			for side in ["r", "l"]:
				out.append(_p("shin_" + side, "cyl", Vector3(0.0, -0.18, 0.0), Vector3(0.14 + o * 2.0, 0.26, 0.14 + o * 2.0)))
				out.append(_p("foot_" + side, "sphl", Vector3(0.0, -0.035, -0.06), Vector3(0.125 + o * 2.0, 0.095 + o * 2.0, 0.29 + o * 2.0)))
				out.append(_p("shin_" + side, "cyl", Vector3(0.0, -0.05, 0.0), Vector3(0.16 + o * 2.0, 0.04, 0.16 + o * 2.0), Vector3.ZERO, true, 0.15))
		"leggings":
			for side in ["r", "l"]:
				out.append(_p("thigh_" + side, "cyl", Vector3(0.0, -0.22, 0.0), Vector3(0.18 + o * 2.0, 0.46, 0.18 + o * 2.0)))
				out.append(_p("shin_" + side, "cyl", Vector3(0.0, -0.2, 0.0), Vector3(0.135 + o * 2.0, 0.4, 0.135 + o * 2.0)))
				out.append(_p("shin_" + side, "sphl", Vector3.ZERO, Vector3(0.15 + o * 2.0, 0.15, 0.15 + o * 2.0)))
		"mittens":
			for side in ["r", "l"]:
				out.append(_p("hand_" + side, "sphl", Vector3(0.0, -0.07, 0.0), Vector3(0.1 + o * 2.0, 0.17 + o * 2.0, 0.075 + o * 2.0)))
				out.append(_p("hand_" + side, "sphl", Vector3(0.0, -0.17, 0.0), Vector3(0.095 + o * 2.0, 0.07, 0.07), Vector3.ZERO, true))
				out.append(_p("forearm_" + side, "cyl", Vector3(0.0, -0.22, 0.0), Vector3(0.1 + o * 2.0, 0.07, 0.1 + o * 2.0), Vector3.ZERO, true, 0.15))
		"skirt":
			# A ring of hanging blades (cones point down when flipped) in two rows round the waist.
			out.append(_p("hips", "cyl", Vector3(0.0, 0.05, 0.0), Vector3(0.4 + o * 2.0, 0.06, 0.28 + o * 2.0), Vector3.ZERO, false, 0.2))

			for k in range(8):
				var a: float = TAU * float(k) / 8.0
				var row: float = 1.0 if k % 2 == 0 else 0.8
				out.append(_p("hips", "cone", Vector3(cos(a) * (0.2 + o), -0.13 * row - 0.02, sin(a) * (0.14 + o)), Vector3(0.1, 0.3 * row, 0.04), Vector3(PI, -a, 0.0), k % 2 == 1, 0.1 * float(k % 3)))
		"sandals":
			for side in ["r", "l"]:
				out.append(_p("foot_" + side, "box", Vector3(0.0, -0.065, -0.06), Vector3(0.11, 0.016, 0.27)))
				out.append(_p("foot_" + side, "box", Vector3(0.0, -0.035, -0.04), Vector3(0.12 + o * 2.0, 0.012, 0.025), Vector3.ZERO, true, 0.2))
				out.append(_p("foot_" + side, "box", Vector3(0.0, -0.035, -0.11), Vector3(0.12 + o * 2.0, 0.012, 0.025), Vector3.ZERO, true, 0.2))
		"pack":
			out.append(_p("chest", "box", Vector3(0.0, 0.02, 0.19 + o), Vector3(0.34, 0.46, 0.17)))
			out.append(_p("chest", "box", Vector3(0.0, 0.26, 0.19 + o), Vector3(0.3, 0.1, 0.17), Vector3.ZERO, false, 0.12))
			out.append(_p("chest", "box", Vector3(0.0, -0.02, 0.29 + o), Vector3(0.2, 0.2, 0.05), Vector3.ZERO, true, 0.2))

			for side in [-1.0, 1.0]:
				out.append(_p("chest", "box", Vector3(0.12 * side, 0.12, 0.0), Vector3(0.05, 0.4, 0.26 + o * 2.0), Vector3.ZERO, true, 0.25))

	return out
