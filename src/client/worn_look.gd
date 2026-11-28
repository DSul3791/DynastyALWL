extends RefCounted

# Worn clothing (Kathleen, goal 1f). `attach(rig, item_ids, far)` hangs one mesh set per item on the named bones of a RagdollBody (hips, chest, head, hand_*, thigh_*, shin_*, foot_*),
# replacing whatever was attached before, so Steve's sync code calls it once with the ids the server sends. Items come from data/items/worn.json (builder, colour, layer).
# Parts are simple spheres, boxes and cylinders in the bone's own space (limbs run down -Y, the front of the body is -Z, right is +X). Meshes and materials are shared and cached.
# A layer stands LAYER_M further out (1.5 cm) so a cloak over leggings does not z-fight. Far bodies (beyond about 30 m) skip the detail parts (mittens' thumbs, straps, fringe).
# On a body that is one skinned mesh (rig meta "worn_shell", Dave's body) a sleeved body garment also hangs a fitted layer that bends with the skin (worn_shell.gd).

const WornShell := preload("res://src/client/worn_shell.gd")
const Shapes := preload("res://src/client/character/dynasty_shapes.gd")

const WORN_PATH := "res://data/items/worn.json"
const LAYER_M := 0.015
# Builders whose pieces stand off the body (headwear, a cloak, a pack, a belt, sandal straps): the skin under them is not tucked in (attach, BugsList 187).
# Builders worn on the torso, under a pack's straps (attach `under`).
const TORSO_BUILDERS := ["tunic", "padded", "mailshirt", "jerkin", "cuirass"]
const NO_COVER := ["cloak", "hood", "cap", "furhat", "sandals", "pack", "helm", "belt"]
const BUILDERS := ["cloak", "hood", "cap", "furhat", "boots", "leggings", "mittens", "skirt", "sandals", "pack", "tunic", "trousers", "gloves", "helm", "jerkin", "mailshirt", "cuirass", "padded", "belt"]
const HUMANOID_NAMES := {
	"hips": "Hips", "chest": "Chest", "head": "Head",
	"hand_r": "RightHand", "hand_l": "LeftHand", "forearm_r": "RightLowerArm", "forearm_l": "LeftLowerArm", "arm_r": "RightUpperArm", "arm_l": "LeftUpperArm",
	"thigh_r": "RightUpperLeg", "thigh_l": "LeftUpperLeg", "shin_r": "RightLowerLeg", "shin_l": "LeftLowerLeg", "foot_r": "RightFoot", "foot_l": "LeftFoot",
}

# Builders that replace the placeholder one a worn.json row still names (Kathleen, Sal's request for a sleeved shirt, sewn trousers and fingered gloves):
# item id -> builder. Applied only while the row uses the old placeholder builder, so a later worn.json edit wins.
const BUILDER_OVERRIDES := {"hide_tunic": ["cloak", "tunic"], "hide_trousers": ["leggings", "trousers"], "hide_gloves": ["mittens", "gloves"]}

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

		for item_id in BUILDER_OVERRIDES:
			if _table.has(item_id) and str(_table[item_id].get("builder", "")) == str(BUILDER_OVERRIDES[item_id][0]):
				_table[item_id]["builder"] = BUILDER_OVERRIDES[item_id][1]

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
	var frames: Dictionary = rig.get_meta("worn_frames", {}) if rig.has_meta("worn_frames") else {}
	var covered: Array = []      # the bone groups (dynasty_shapes.gd COVERS) a worn piece sits on, whose skin a body that can tucks in under it
	var under: float = 0.0      # how far out the torso garments worn here stand (their layer and one more): the pack's straps lie on them

	for item_id in item_ids:
		var torso_row: Dictionary = table().get(str(item_id), {})

		if str(torso_row.get("builder", "")) in TORSO_BUILDERS:
			under = maxf(under, float(int(torso_row.get("layer", 1)) + 1) * LAYER_M)

	var layer_chest: bool = false      # a near garment's fitted layer is the chest on this body (worn_shell.gd LAYER_IS_CHEST): the shirt under it keeps no chest pieces

	for item_id in item_ids:
		var chest_row: Dictionary = table().get(str(item_id), {})
		layer_chest = layer_chest or (not far and rig.has_meta("worn_shell") and str(chest_row.get("builder", "")) in WornShell.LAYER_IS_CHEST)

	for item_id in item_ids:
		var row: Dictionary = table().get(str(item_id), {})

		if row.is_empty():
			continue

		# A body can list builders it already draws itself (the generated body has its tunic and trousers in its mesh): those items add no separate pieces.
		if str(row.get("builder", "")) in (rig.get_meta("worn_skip_builders", []) as Array):
			continue

		var out: float = float(int(row.get("layer", 1))) * LAYER_M

		var parts: Array = parts_of(str(row["builder"]), out, bool(row.get("fringe", false)), under)

		if rig.has_meta("worn_shell"):
			parts = WornShell.fit_parts(str(row["builder"]), parts, not far)      # fitted to Dave's body, over the layer (worn_shell.gd CHEST_TURN)

		if layer_chest and str(row["builder"]) in WornShell.UNDER_CHEST:
			parts = parts.filter(func(part: Dictionary) -> bool: return str(part["bone"]) != "chest")

		for part in parts:
			if far and bool(part.get("detail", false)):
				continue

			var bone: String = str(part["bone"])
			var group: String = bone.trim_suffix("_r").trim_suffix("_l")

			if not bool(part.get("detail", false)) and not str(row["builder"]) in NO_COVER and group in Shapes.COVERS and not group in covered:
				covered.append(group)

			# The generated body (src/client/character/body_generator.gd) has humanoid bone names; the parts below are written for the old names, so they are mapped
			# when the skeleton has no bone of the old name. The old body is untouched by this.
			if frames.has(bone):
				# A body in other bone frames (Dave's body, dynasty_body.gd _worn_frames) gives each old bone its own bone and a frame under it in the old axes.
				var key: String = "frame_" + bone

				if not anchors.has(key):
					var frame_row: Array = frames[bone]
					var holder: BoneAttachment3D = BoneAttachment3D.new()
					holder.name = "Worn_" + bone
					skeleton.add_child(holder)
					holder.bone_name = str(frame_row[0])
					var frame: Node3D = Node3D.new()
					frame.name = "Frame"
					frame.transform = frame_row[1]
					holder.add_child(frame)
					anchors[key] = frame

				bone = key
			elif skeleton.find_bone(bone) < 0 and HUMANOID_NAMES.has(bone):
				bone = str(HUMANOID_NAMES[bone])

			if not anchors.has(bone):
				var anchor: BoneAttachment3D = BoneAttachment3D.new()
				anchor.name = "Worn_" + bone
				skeleton.add_child(anchor)
				anchor.bone_name = bone
				anchors[bone] = anchor

			var node: MeshInstance3D = MeshInstance3D.new()
			node.mesh = _mesh(str(part["shape"]))
			node.material_override = _material(Color.html(str(row["color"])).darkened(float(part.get("dark", 0.0))), stuff_of(str(item_id)))
			# A generated body carries a per-bone fit (widths and lengths of its own proportions); the old body has none, so nothing changes for it.
			# A part with "fitted": true was already built from the body's own measures (rig meta "worn_measures"), so it is not scaled again.
			var fit: Vector3 = Vector3.ONE if bool(part.get("fitted", false)) else (rig.get_meta("worn_fit", {}) as Dictionary).get(bone, Vector3.ONE)
			# A part with its own "basis" (a strap turned along its length, _strap) is sized in its own axes; Basis.scaled sizes along the bone's axes, which skews a turned box.
			var shape_basis: Basis = Basis.from_scale(fit) * (part["basis"] as Basis) if part.has("basis") else Basis.from_euler(part.get("rot", Vector3.ZERO)).scaled((part["size"] as Vector3) * fit)
			node.transform = Transform3D(shape_basis, (part["at"] as Vector3) * fit)
			anchors[bone].add_child(node)
			count += 1

		# A sleeved body garment on a body that is one skinned mesh (Dave's) also gets its fitted layer, which bends with the skin (worn_shell.gd, QA #15). Far bodies skip it:
		# beyond about 30 m a gap between the pieces is a few pixels.
		if not far and rig.has_meta("worn_shell") and WornShell.covers(str(row["builder"])):
			if WornShell.hang(rig, skeleton, str(row["builder"]), _material(Color.html(str(row["color"])), stuff_of(str(item_id)), true)) != null:
				count += 1

	if rig.has_method("cover"):
		rig.call("cover", covered)      # Dave's body tucks its skin in under the pieces (dynasty_body.gd cover); the old bodies have no such shapes

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
		elif shape == "cyls" or shape == "frus":
			# Smooth versions for headwear (Dave 5 Nov 2026: "what is on her head", the six-sided hood read as a brown block): 16 sides; "frus" narrows to the top (a hood's drape).
			var round_cyl: CylinderMesh = CylinderMesh.new()
			round_cyl.top_radius = 0.3 if shape == "frus" else 0.5
			round_cyl.bottom_radius = 0.5
			round_cyl.height = 1.0
			round_cyl.radial_segments = 16
			round_cyl.rings = 1
			round_cyl.cap_top = false
			round_cyl.cap_bottom = false
			mesh = round_cyl
		elif shape == "tor":
			var ring: TorusMesh = TorusMesh.new()      # in the XZ plane, outer radius 0.5, tube 0.07
			ring.inner_radius = 0.36
			ring.outer_radius = 0.5
			ring.rings = 20
			ring.ring_segments = 8
			mesh = ring
		elif shape == "hemi":
			mesh = _dome()
		elif shape == "sphs":
			var round_sph: SphereMesh = SphereMesh.new()
			round_sph.radius = 0.5
			round_sph.height = 1.0
			round_sph.radial_segments = 16
			round_sph.rings = 8
			mesh = round_sph
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


# A dome: the top half of a sphere of radius 0.5, its open rim at y 0 and its crown at y 0.5, 16 sides and 6 rings (a cap's crown). Built here so the shape does not depend
# on how SphereMesh draws a hemisphere.
static func _dome() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides: int = 16
	var rings: int = 6

	for r in range(rings):
		for k in range(sides):
			var quad: Array = []

			for corner in [[r, k], [r, k + 1], [r + 1, k + 1], [r + 1, k]]:
				var up: float = PI * 0.5 * float(corner[0]) / float(rings)
				var round_a: float = TAU * float(corner[1]) / float(sides)
				quad.append(Vector3(cos(up) * cos(round_a), sin(up), cos(up) * sin(round_a)))

			for index in [0, 2, 1, 0, 3, 2]:
				st.set_normal(quad[index])
				st.add_vertex((quad[index] as Vector3) * 0.5)

	return st.commit()

# What each worn item is made of, from its id: hide and leather show a soft grain and a little sheen, wool and padded cloth a woven nap, linen a fine weave, fur strands,
# grass and fibre plaited stems, bronze and steel are shiny metal, iron and mail a drab matt grey. The look follows Art_Direction.md: real stuff, no plastic (Kathreen, 3 Nov 2026).
const STUFF_PREFIXES := [["hide", "hide"], ["leather", "hide"], ["quiver", "hide"], ["simple_backpack", "hide"], ["improved_backpack", "hide"], ["quality_backpack", "hide"],
	["advanced_backpack", "hide"], ["wool", "wool"], ["gambeson", "quilted"], ["linen", "linen"],
	["fur", "fur"], ["grass", "fibre"], ["fibre", "fibre"], ["bronze", "metal"], ["iron", "iron"], ["steel", "metal"], ["mail", "iron"], ["plate", "metal"]]
# stuff -> [weave scale (per metre), weave strength, roughness, specular, metallic, woven share, quilting channel width in metres (0 none)]
const STUFF_LOOKS := {
	"hide": [60.0, 0.16, 0.78, 0.3, 0.0, 0.1], "wool": [260.0, 0.22, 0.98, 0.1, 0.0, 0.7],
	# The gambeson (Dave, 28 Nov 2026: get it a shape of its own): wool with quilted channels 5 cm apart, each puffed between dark stitched seams, drawn on the cloth.
	"quilted": [260.0, 0.2, 0.98, 0.1, 0.0, 0.7, 0.05], "linen": [420.0, 0.12, 0.9, 0.18, 0.0, 0.9],
	"fur": [380.0, 0.3, 0.95, 0.12, 0.0, 0.3], "fibre": [140.0, 0.34, 0.9, 0.2, 0.0, 0.9], "metal": [30.0, 0.1, 0.38, 0.5, 0.85, 0.0],
	# Iron and mail (Dave, 27 Nov 2026: "it should be a drab gray. steel will be shiny"; R-ITEM-IRON-LOOK; BugsList 189): a dull, matt dark grey with a faint sheen, as
	# forge-blackened iron. As "metal" (85% metallic) it drew flat black wherever nothing bright was there to reflect.
	"iron": [30.0, 0.14, 0.8, 0.35, 0.2, 0.0],
}
const CLOTH_SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform vec3 tint : source_color = vec3(0.45, 0.32, 0.2);
uniform float weave = 260.0;
uniform float depth = 0.2;
uniform float rough = 0.95;
uniform float spec = 0.15;
uniform float metal = 0.0;
uniform float woven = 0.7;      // 1 all threads, 0 all grain (hide, metal)
uniform float quilt = 0.0;     // quilting channel width in metres (0 none): channels across x, puffed in the middle and dark at the stitched seams
uniform bool rest_custom = false;   // a fitted layer (worn_shell.gd): the weave from the skin's rest place in CUSTOM0, so it stays on the cloth as the body bends

varying vec3 lp;

float h3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1.0, 0.0, 0.0)), f.x), mix(h3(i + vec3(0.0, 1.0, 0.0)), h3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(h3(i + vec3(0.0, 0.0, 1.0)), h3(i + vec3(1.0, 0.0, 1.0)), f.x), mix(h3(i + vec3(0.0, 1.0, 1.0)), h3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

void vertex() {
	vec3 s = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	lp = rest_custom ? CUSTOM0.rgb : VERTEX * s;          // metres, so a glove and a cloak share one weave size
}

void fragment() {
	vec3 q = lp * weave;
	float threads = 0.5 + 0.5 * sin(q.x + 2.0 * vnoise(q * 0.2)) * sin(q.y + 2.0 * vnoise(q.yzx * 0.2));   // warp and weft (stems, for fibre)
	float blotch = vnoise(lp * 9.0 + 3.0);                                                                  // wear, grease and sun fade
	float grain = vnoise(q * 0.35);
	float v = mix(1.0, 0.82 + 0.36 * mix(grain, threads, woven), depth) * (0.9 + 0.2 * blotch);

	if (quilt > 0.0) {
		float c = fract(lp.x / quilt);
		float stitch = step(0.5, fract(lp.y / 0.012));                                     // running stitches down each seam
		v *= mix(0.62 + 0.12 * stitch, 1.0, pow(sin(c * 3.14159), 0.45));
	}
	ALBEDO = tint * v;
	ROUGHNESS = clamp(rough - 0.12 * blotch, 0.05, 1.0);
	SPECULAR = spec;
	METALLIC = metal;
}
"""
static var _cloth_shader: Shader


static func stuff_of(item_id: String) -> String:
	for pair in STUFF_PREFIXES:
		if item_id.begins_with(str(pair[0])):
			return str(pair[1])

	return "wool"


static func _material(color: Color, stuff: String = "wool", fitted: bool = false) -> Material:
	var key: String = color.to_html() + stuff + ("|fitted" if fitted else "")

	if not _materials.has(key):
		if _cloth_shader == null:
			_cloth_shader = Shader.new()
			_cloth_shader.code = CLOTH_SHADER

		var look: Array = STUFF_LOOKS.get(stuff, STUFF_LOOKS["wool"])
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = _cloth_shader
		m.set_shader_parameter("tint", color)
		m.set_shader_parameter("weave", float(look[0]))
		m.set_shader_parameter("depth", float(look[1]))
		m.set_shader_parameter("rough", float(look[2]))
		m.set_shader_parameter("spec", float(look[3]))
		m.set_shader_parameter("metal", float(look[4]))
		m.set_shader_parameter("woven", float(look[5]))
		m.set_shader_parameter("quilt", float(look[6]) if look.size() > 6 else 0.0)
		m.set_shader_parameter("rest_custom", fitted)
		_materials[key] = m

	return _materials[key]


static func _p(bone: String, shape: String, at: Vector3, size: Vector3, rot: Vector3 = Vector3.ZERO, detail: bool = false, dark: float = 0.0) -> Dictionary:
	return {"bone": bone, "shape": shape, "at": at, "size": size, "rot": rot, "detail": detail, "dark": dark}


# The parts of one builder, in bone space; `o` is the outward offset of the layer. Sizes are full extents (the shared meshes have radius/edge 0.5).
# `under`: how far out the torso garments worn with it stand (attach: 0 on a bare chest), for the pack's straps to lie on them; below 0, the builder's own `o`.
static func parts_of(builder: String, o: float, fringe: bool = false, under: float = -1.0) -> Array:
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
		# Headwear (Dave 5 Nov 2026, "what is on her head": the old hood was a six-sided ball 0.33 m across over the whole head, with a band, and read as a brown block; the
		# caps and the fur hat used it too). Head frame: y 0 about the chin, the crown at 0.24, the face at z -0.1 (front -Z). Refs: medieval hoods with a shoulder cape
		# and a short back point (Herjolfsnes, Bocksten), round skull caps with a rim, a fur hat with a rolled fur brim.
		"hood":
			# A hood: a smooth shell set back so the face shows (its front edge 2.5 cm behind the face), a collar over the neck and shoulder tops, and a short point
			# at the back. PC shots 5 Nov (4f58f71d): the first try was 0.31 m deep with a ring and a 0.42 m cape, and read as a box hiding the face.
			out.append(_p("head", "sphs", Vector3(0.0, 0.15, 0.05), Vector3(0.2 + o, 0.26 + o, 0.22 + o)))
			out.append(_p("head", "frus", Vector3(0.0, -0.045, 0.035), Vector3(0.28 + o, 0.1, 0.24 + o)))
			out.append(_p("head", "cone", Vector3(0.0, 0.21, 0.16 + o * 0.5), Vector3(0.06, 0.1, 0.1), Vector3(2.2, 0.0, 0.0), true, 0.05))
		"cap":
			# A round skull cap (leather or knitted wool): a dome over the crown, its darker rim on the brow above the eyes (the eye line is about 0.13 in this frame:
			# PC shot 5 Nov, a rim at 0.15 sat over the eyes), a small knot on the crown.
			out.append(_p("head", "hemi", Vector3(0.0, 0.17, 0.015), Vector3(0.2 + o, 0.2 + o, 0.225 + o)))
			out.append(_p("head", "cyls", Vector3(0.0, 0.182, 0.015), Vector3(0.205 + o, 0.025, 0.23 + o), Vector3.ZERO, false, 0.15))
			out.append(_p("head", "sphs", Vector3(0.0, 0.27 + o * 0.5, 0.015), Vector3(0.025, 0.018, 0.025), Vector3.ZERO, true, 0.2))
		"furhat":
			# A fur hat: a taller dome and a thick rolled fur brim on the brow, above the eyes, a shade lighter where the fur turns over.
			out.append(_p("head", "hemi", Vector3(0.0, 0.18, 0.015), Vector3(0.205 + o, 0.24 + o, 0.235 + o)))
			out.append(_p("head", "tor", Vector3(0.0, 0.19, 0.015), Vector3(0.24 + o, 0.22, 0.27 + o), Vector3.ZERO, false, -0.12))
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
		"tunic":
			# A hide tunic: a sleeved shirt of sewn hide over the chest and hips, loose sleeves to the wrist, a rope belt, a round neck with a short lace opening at the front.
			out.append(_p("chest", "cyl", Vector3(0.0, -0.04, 0.0), Vector3(0.38 + o * 2.0, 0.5, 0.27 + o * 2.0)))
			out.append(_p("hips", "cyl", Vector3(0.0, -0.07, 0.0), Vector3(0.42 + o * 2.0, 0.28, 0.3 + o * 2.0), Vector3.ZERO, false, 0.04))
			out.append(_p("hips", "cyl", Vector3(0.0, 0.04, 0.0), Vector3(0.4 + o * 2.0, 0.045, 0.285 + o * 2.0), Vector3.ZERO, false, 0.4))

			for side in ["r", "l"]:
				out.append(_p("arm_" + side, "cyl", Vector3(0.0, -0.15, 0.0), Vector3(0.125 + o * 2.0, 0.32, 0.125 + o * 2.0)))
				out.append(_p("forearm_" + side, "cyl", Vector3(0.0, -0.12, 0.0), Vector3(0.105 + o * 2.0, 0.25, 0.105 + o * 2.0), Vector3.ZERO, false, 0.04))
				out.append(_p("forearm_" + side, "cyl", Vector3(0.0, -0.245, 0.0), Vector3(0.11 + o * 2.0, 0.025, 0.11 + o * 2.0), Vector3.ZERO, true, 0.3))

			out.append(_p("chest", "cyl", Vector3(0.0, 0.25, 0.0), Vector3(0.17 + o * 2.0, 0.05, 0.17 + o * 2.0), Vector3.ZERO, true, 0.25))
			out.append(_p("chest", "box", Vector3(0.0, 0.2, -0.135 - o), Vector3(0.025, 0.1, 0.012), Vector3.ZERO, true, 0.4))
		"helm":
			# A helmet (refs: Bronze Age and Viking spectacle-free round helms, medieval kettle caps): a skull dome, a rolled rim round the brow, a nasal bar down the face and a small crest ridge.
			out.append(_p("head", "sph", Vector3(0.0, 0.13, 0.04), Vector3(0.29 + o * 2.0, 0.27 + o * 2.0, 0.3 + o * 2.0)))
			out.append(_p("head", "cyl", Vector3(0.0, 0.05, 0.035), Vector3(0.31 + o * 2.0, 0.035, 0.32 + o * 2.0), Vector3.ZERO, true, 0.25))
			out.append(_p("head", "box", Vector3(0.0, 0.07, -0.125 - o), Vector3(0.025, 0.1, 0.012), Vector3.ZERO, true, 0.2))
			out.append(_p("head", "box", Vector3(0.0, 0.26, 0.04), Vector3(0.02, 0.04, 0.26), Vector3.ZERO, true, 0.2))
		"jerkin":
			# A sleeveless leather jerkin (refs: boiled-leather jerkins): a torso tube with a lower skirt flare, shoulder straps, a laced front seam and a belt.
			out.append(_p("chest", "cyl", Vector3(0.0, -0.04, 0.0), Vector3(0.39 + o * 2.0, 0.5, 0.28 + o * 2.0)))
			out.append(_p("hips", "cyl", Vector3(0.0, -0.06, 0.0), Vector3(0.44 + o * 2.0, 0.26, 0.32 + o * 2.0), Vector3.ZERO, false, 0.06))
			out.append(_p("hips", "cyl", Vector3(0.0, 0.04, 0.0), Vector3(0.41 + o * 2.0, 0.04, 0.29 + o * 2.0), Vector3.ZERO, true, 0.4))
			out.append(_p("chest", "box", Vector3(0.0, 0.0, -0.145 - o), Vector3(0.025, 0.42, 0.012), Vector3.ZERO, true, 0.4))

			for side in [-1.0, 1.0]:
				out.append(_p("chest", "box", Vector3(0.13 * side, 0.26, 0.0), Vector3(0.07, 0.05, 0.3 + o * 2.0), Vector3.ZERO, true, 0.15))
		"mailshirt":
			# A mail shirt (refs: Norman and Viking byrnies): a torso tube and short sleeves to the elbow, a skirt to mid-thigh, and rows of ring bands that catch the light.
			out.append(_p("chest", "cyl", Vector3(0.0, -0.04, 0.0), Vector3(0.4 + o * 2.0, 0.5, 0.29 + o * 2.0)))
			out.append(_p("hips", "cyl", Vector3(0.0, -0.1, 0.0), Vector3(0.45 + o * 2.0, 0.34, 0.33 + o * 2.0), Vector3.ZERO, false, 0.05))

			for k in range(5):
				out.append(_p("chest", "cyl", Vector3(0.0, 0.18 - 0.1 * float(k), 0.0), Vector3(0.405 + o * 2.0, 0.012, 0.295 + o * 2.0), Vector3.ZERO, true, 0.3))

			for side in ["r", "l"]:
				out.append(_p("arm_" + side, "cyl", Vector3(0.0, -0.1, 0.0), Vector3(0.13 + o * 2.0, 0.22, 0.13 + o * 2.0)))
				out.append(_p("arm_" + side, "cyl", Vector3(0.0, -0.2, 0.0), Vector3(0.135 + o * 2.0, 0.015, 0.135 + o * 2.0), Vector3.ZERO, true, 0.3))

			out.append(_p("hips", "cyl", Vector3(0.0, -0.27, 0.0), Vector3(0.455 + o * 2.0, 0.02, 0.335 + o * 2.0), Vector3.ZERO, true, 0.3))
		"cuirass":
			# A plate cuirass (refs: 15th century breastplates): a rounded breast and back plate with a ridge down the middle, shoulder plates, an overlapping waist band and short tassets over the hips.
			out.append(_p("chest", "sph", Vector3(0.0, 0.03, -0.01), Vector3(0.4 + o * 2.0, 0.46, 0.3 + o * 2.0)))
			out.append(_p("chest", "box", Vector3(0.0, 0.03, -0.155 - o), Vector3(0.03, 0.4, 0.02), Vector3.ZERO, true, 0.2))
			out.append(_p("hips", "cyl", Vector3(0.0, 0.03, 0.0), Vector3(0.4 + o * 2.0, 0.09, 0.285 + o * 2.0), Vector3.ZERO, true, 0.15))
			out.append(_p("hips", "cyl", Vector3(0.0, -0.08, 0.0), Vector3(0.43 + o * 2.0, 0.1, 0.31 + o * 2.0), Vector3.ZERO, false, 0.05))
			out.append(_p("hips", "cyl", Vector3(0.0, -0.17, 0.0), Vector3(0.45 + o * 2.0, 0.09, 0.325 + o * 2.0), Vector3.ZERO, true, 0.1))

			for side in [-1.0, 1.0]:
				out.append(_p("chest", "sphl", Vector3(0.22 * side, 0.22, 0.0), Vector3(0.16, 0.1, 0.2 + o * 2.0), Vector3(0.0, 0.0, 0.3 * side), false, 0.03))
		"padded":
			# A quilted gambeson (refs: arming doublets): a thick sleeved torso, a high collar, and long sleeves to the wrist; its quilting is in its cloth ("quilted").
			# On Dave's body its fitted layer is its chest instead of the tube (worn_shell.gd LAYER_IS_CHEST).
			out.append(_p("chest", "cyl", Vector3(0.0, -0.04, 0.0), Vector3(0.41 + o * 2.0, 0.5, 0.3 + o * 2.0)))
			out.append(_p("hips", "cyl", Vector3(0.0, -0.08, 0.0), Vector3(0.45 + o * 2.0, 0.3, 0.33 + o * 2.0), Vector3.ZERO, false, 0.03))
			out.append(_p("chest", "cyl", Vector3(0.0, 0.26, 0.0), Vector3(0.2 + o * 2.0, 0.08, 0.2 + o * 2.0), Vector3.ZERO, true, 0.12))

			for side in ["r", "l"]:
				out.append(_p("arm_" + side, "cyl", Vector3(0.0, -0.15, 0.0), Vector3(0.14 + o * 2.0, 0.32, 0.14 + o * 2.0)))
				out.append(_p("forearm_" + side, "cyl", Vector3(0.0, -0.12, 0.0), Vector3(0.115 + o * 2.0, 0.25, 0.115 + o * 2.0), Vector3.ZERO, false, 0.03))
		"trousers":
			# Sewn hide trousers: a waistband with a cord, a seat and two full legs, a darker seam down the outside of each leg and a turned cuff at each ankle.
			out.append(_p("hips", "cyl", Vector3(0.0, 0.03, 0.0), Vector3(0.38 + o * 2.0, 0.07, 0.27 + o * 2.0), Vector3.ZERO, false, 0.3))
			out.append(_p("hips", "sphl", Vector3(0.0, -0.06, 0.0), Vector3(0.36 + o * 2.0, 0.22, 0.27 + o * 2.0)))

			for side in ["r", "l"]:
				var sx: float = 1.0 if side == "r" else -1.0
				out.append(_p("thigh_" + side, "cyl", Vector3(0.0, -0.22, 0.0), Vector3(0.195 + o * 2.0, 0.46, 0.195 + o * 2.0)))
				out.append(_p("shin_" + side, "cyl", Vector3(0.0, -0.2, 0.0), Vector3(0.155 + o * 2.0, 0.4, 0.155 + o * 2.0), Vector3.ZERO, false, 0.04))
				out.append(_p("shin_" + side, "sphl", Vector3.ZERO, Vector3(0.165 + o * 2.0, 0.16, 0.165 + o * 2.0)))
				out.append(_p("thigh_" + side, "box", Vector3(sx * (0.095 + o), -0.22, 0.0), Vector3(0.01, 0.44, 0.02), Vector3.ZERO, true, 0.3))
				out.append(_p("shin_" + side, "cyl", Vector3(0.0, -0.385, 0.0), Vector3(0.17 + o * 2.0, 0.04, 0.17 + o * 2.0), Vector3.ZERO, true, 0.25))
		"gloves":
			# Hide gloves: a palm and back of the hand, four separate fingers and a thumb standing out at an angle, and a short cuff over the wrist.
			for side in ["r", "l"]:
				out.append(_p("hand_" + side, "sphl", Vector3(0.0, -0.05, 0.0), Vector3(0.095 + o * 2.0, 0.11 + o * 2.0, 0.05 + o * 2.0)))

				for k in range(4):
					var fx: float = -0.034 + 0.0227 * float(k)
					var flen: float = 0.085 - 0.012 * absf(float(k) - 1.5) * 0.7
					out.append(_p("hand_" + side, "cyl", Vector3(fx, -0.1 - flen * 0.5, 0.0), Vector3(0.021 + o * 2.0, flen, 0.024 + o * 2.0), Vector3.ZERO, true))

				out.append(_p("hand_" + side, "cyl", Vector3(0.0, -0.075, -0.04), Vector3(0.024 + o * 2.0, 0.07, 0.024 + o * 2.0), Vector3(0.9, 0.0, 0.0), true))
				out.append(_p("forearm_" + side, "cyl", Vector3(0.0, -0.215, 0.0), Vector3(0.11 + o * 2.0, 0.09, 0.11 + o * 2.0), Vector3.ZERO, false, 0.2))
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
		"belt":
			# A leather belt (waist slot, item system #950 slots): a strap round the hips over whatever is worn under it, a bone toggle at the front
			# (-Z) and the strap's end hanging down beside it.
			out.append(_p("hips", "cyl", Vector3(0.0, 0.03, 0.0), Vector3(0.42 + o * 2.0, 0.05, 0.3 + o * 2.0), Vector3.ZERO, false, 0.1))
			out.append(_p("hips", "cyl", Vector3(0.0, 0.03, -0.155 - o), Vector3(0.022, 0.07, 0.022), Vector3(0.0, 0.0, PI * 0.5), true, -0.45))
			out.append(_p("hips", "box", Vector3(0.05, -0.03, -0.155 - o), Vector3(0.03, 0.1, 0.01), Vector3.ZERO, true, 0.2))
		"pack":
			out.append(_p("chest", "box", Vector3(0.0, 0.02, 0.19 + o), Vector3(0.34, 0.46, 0.17)))
			out.append(_p("chest", "box", Vector3(0.0, 0.26, 0.19 + o), Vector3(0.3, 0.1, 0.17), Vector3.ZERO, false, 0.12))
			out.append(_p("chest", "box", Vector3(0.0, -0.02, 0.29 + o), Vector3(0.2, 0.2, 0.05), Vector3.ZERO, true, 0.2))

			# Two thin shoulder straps (Dave, 27 Nov 2026: "they dont have straps they have big blocky things pretending to be straps"; BugsList 188): each a flat band
			# 4 cm wide from the pack's front face up over the top of the shoulder, sloping down onto the chest, and down the front of the chest. They were 26 cm deep
			# slabs through the body. The front lies on what is worn under it (`under`): on the bare chest, or on a shirt or armour (laptop pictures 27 Nov: a strap
			# sized for a shirt stood several cm off the bare chest).
			var front_z: float = -0.105 - (o if under < 0.0 else under)

			for side in [-1.0, 1.0]:
				var x: float = 0.1 * side
				out.append(_strap(Vector3(x, 0.27, 0.13), Vector3(x, 0.3, 0.0)))
				out.append(_strap(Vector3(x, 0.3, 0.0), Vector3(x, 0.26, front_z)))
				out.append(_p("chest", "box", Vector3(x, 0.11, front_z), Vector3(0.04, 0.32, 0.012), Vector3.ZERO, true, 0.25))

	return out + joint_caps(out)


# A flat strap 4 cm wide on the chest bone from `a` to `b` (both with the same x): a box along its own z, turned about x to run between them, 1 cm longer each
# way so the pieces of one strap overlap. Its "basis" sizes it in its own axes (attach); laptop pictures 27 Nov: sized after the turn, it stood out as a wing.
static func _strap(a: Vector3, b: Vector3) -> Dictionary:
	var d: Vector3 = b - a
	var size: Vector3 = Vector3(0.04, 0.012, d.length() + 0.02)
	var part: Dictionary = _p("chest", "box", (a + b) * 0.5, size, Vector3.ZERO, true, 0.25)
	part["basis"] = Basis(Vector3.RIGHT, atan2(-d.y, d.z)) * Basis.from_scale(size)
	return part


# The joints a garment bends at: [parent bone, child bone, the joint's height on the parent bone (ragdoll_body.gd BONES), the cap's size over the child piece's width].
# Shoulders get a larger ball, to close the corner between the body tube and the sleeve (a tunic's shoulder ball is 21 cm across).
const JOINTS := [
	["chest", "arm_r", 0.2, 1.15], ["chest", "arm_l", 0.2, 1.15], ["arm_r", "forearm_r", -0.29, 1.05], ["arm_l", "forearm_l", -0.29, 1.05],
	["forearm_r", "hand_r", -0.26, 1.05], ["forearm_l", "hand_l", -0.26, 1.05], ["hips", "thigh_r", -0.05, 1.05], ["hips", "thigh_l", -0.05, 1.05],
	["thigh_r", "shin_r", -0.45, 1.05], ["thigh_l", "shin_l", -0.45, 1.05], ["shin_r", "foot_r", -0.4, 1.05], ["shin_l", "foot_l", -0.4, 1.05],
]
const JOINT_REACH_M := 0.06      # a piece whose end comes this near a joint covers it


# QA #15 (25 Nov 2026, a tester: "log chopping animation limbs not attached"; Lane A stills of the chop: the sleeve and body pieces are rigid per bone, so at a bent elbow the
# upper and lower sleeve parted with skin between, and at a raised arm the sleeve left the body with the shoulder and armpit bare). Wherever one garment covers both sides of a
# joint, a ball of its colour sits on the joint, on the child bone, as wide as the child's piece there: it turns with the limb and fills the gap in every pose. A garment that
# covers only one side (a mail shirt's short sleeve, a cuff) gets none, and a joint that already has a ball (the leggings' knee) gets no second one.
static func joint_caps(parts: Array) -> Array:
	var caps: Array = []

	for joint in JOINTS:
		var parent_covered: bool = false
		var width: float = 0.0
		var has_ball: bool = false

		for part in parts:
			if bool(part["detail"]):
				continue

			var at: Vector3 = part["at"]
			var size: Vector3 = part["size"]

			if str(part["bone"]) == str(joint[0]) and at.y - size.y * 0.5 <= float(joint[2]) + JOINT_REACH_M and at.y + size.y * 0.5 >= float(joint[2]) - JOINT_REACH_M:
				parent_covered = true
			elif str(part["bone"]) == str(joint[1]) and at.y + size.y * 0.5 >= -JOINT_REACH_M and at.y - size.y * 0.5 <= JOINT_REACH_M:
				width = maxf(width, maxf(size.x, size.z))
				has_ball = has_ball or (str(part["shape"]).begins_with("sph") and at.length() < 0.03)

		if parent_covered and width > 0.0 and not has_ball:
			var d: float = width * float(joint[3])
			caps.append(_p(str(joint[1]), "sph", Vector3.ZERO, Vector3(d, d, d)))

	return caps
