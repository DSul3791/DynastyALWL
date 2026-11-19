extends RefCounted

# The look of a crop on a tilled bed or garden plot, stage 0 (seedling) to 3 (ripe).
# The field crops and vegetables with no wild plant wear Dave's painted plants (19 Nov 2026: his picture of wheat, barley, oats and rye, and his row of carrot,
# potato, turnip, cabbage, onion, peas, beet, radish, lettuce and parsnip, cut out into assets/crops/<crop>.png by assets/crops/make_crop_cards.py): crossed
# picture cards, one clump every half metre. The pictures are the grown plant, so (PROVISIONAL CL-2) a grain's seedling and young stages are green blades (the
# grass card), its growing stage the picture a little shorter and greener; a vegetable is its own picture, smaller while young.
# A crop that grows wild too (flora.json has a plant of the same name: chamomile, yarrow, nettle ... 70 of the 84 crops) wears that wild plant's own model, as the
# wild ones draw it (FloraView.crop_model, passed in as `plant_model`), smaller while young (Dave play test 19 Nov 2026: the seedlings were green boxes though
# "they have a model in the game"). PLACEHOLDER ART while the flora models are still being built at the join: a small grid of plain boxes ("tufts"), scaled
# and coloured by stage, as FARMING_SPEC.md step 6 allows as the interim ("a green tuft scaled by stage").

const FloraView := preload("res://src/flora/flora_view.gd")
const HEIGHT_M := [0.08, 0.2, 0.38, 0.55]           # stage -> tuft height
const MODEL_SHARE := [0.35, 0.6, 0.85, 1.0]         # PROVISIONAL CL-1: stage -> share of the wild plant's usual height (a seedling a third, ripe full size)
const GRAINS := ["flax"]                            # placeholder tufts tall and thin, tan when ripe
const GRAIN_RIPE := Color(0.74, 0.66, 0.44)
const LEAF := Color(0.27, 0.52, 0.2)
const LEAF_RIPE := Color(0.2, 0.42, 0.16)           # roots and greens: a fuller, darker leaf
# PROVISIONAL CL-2: crop -> grown height in metres of the painted clump, near the real plant's
const PICTURE_HEIGHT_M := {"wheat": 1.0, "barley": 0.9, "oats": 1.0, "rye": 1.3, "carrot": 0.35, "potato": 0.6, "turnip": 0.4, "cabbage": 0.4, "onion": 0.45,
		"peas": 0.9, "beet": 0.4, "radish": 0.3, "lettuce": 0.3, "parsnip": 0.5}
const BLADES_YOUNG := ["wheat", "barley", "oats", "rye"]    # the grains: green blades before the ears show
const PICTURE_PATH := "res://assets/crops/%s.png"
const BLADES_PATH := "res://assets/grass/grass_tall.png"    # kept light: the material tints it LEAF
const GRAIN_SHARE := [0.12, 0.35, 0.85, 1.0]        # PROVISIONAL CL-2: a grain's stage -> share of its grown height (vegetables: MODEL_SHARE)
const GRAIN_GROWING_TINT := Color(0.78, 1.0, 0.62)  # a grain's growing stage: the ears still green

static var _materials: Dictionary = {}              # "crop:stage" -> StandardMaterial3D
static var _meshes: Dictionary = {}                 # "grain:stage" or "leaf:stage" -> the one BoxMesh every tuft of that look shares; "card:crop:stage" -> crossed cards
static var _textures: Dictionary = {}               # path -> Texture2D


# `side_m`: the bed's footprint (1 for a tilled bed, 2 for a garden plot); a plant every half metre. `plant_model`: (crop id, share of height, spots) -> Node3D,
# or null for none (FloraView.crop_model); unset (tests, no flora) gives the placeholder. The root's meta "placeholder" says which it got.
static func build(crop_id: String, stage: int, side_m: float, plant_model: Callable = Callable()) -> Node3D:
	var root: Node3D = Node3D.new()
	var s: int = clampi(stage, 0, HEIGHT_M.size() - 1)
	var per_side: int = maxi(int(round(side_m * 2.0)), 1)
	var spots: Array = []

	for ix in range(per_side):
		for iz in range(per_side):
			spots.append(Vector3((float(ix) + 0.5) / float(per_side) * side_m - side_m * 0.5, 0.0, (float(iz) + 0.5) / float(per_side) * side_m - side_m * 0.5))

	if PICTURE_HEIGHT_M.has(crop_id):
		for n in spots.size():
			var card: MeshInstance3D = MeshInstance3D.new()
			card.mesh = _card_mesh(crop_id, s)
			card.material_override = _card_material(crop_id, s)
			card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # as the wild plants
			card.visibility_range_end = FloraView.CROP_VIEW_M
			card.position = spots[n]
			card.rotation.y = float(n) * 2.4                                     # each clump turned its own way, as FloraView.crop_model
			root.add_child(card)

		root.set_meta("placeholder", false)
		return root

	var model: Variant = plant_model.call(crop_id, float(MODEL_SHARE[s]), spots) if plant_model.is_valid() else null

	if model is Node3D:
		root.add_child(model)
		root.set_meta("placeholder", false)
		return root

	var grain: bool = crop_id in GRAINS
	var high: float = _mesh(s, grain).size.y

	for spot in spots:
		var tuft: MeshInstance3D = MeshInstance3D.new()
		tuft.mesh = _mesh(s, grain)
		tuft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # placeholder tufts: no shadow cost per bed
		tuft.material_override = _material(crop_id, s, grain)
		tuft.position = spot + Vector3(0.0, high * 0.5, 0.0)
		root.add_child(tuft)

	root.set_meta("placeholder", true)
	return root


static func _mesh(stage: int, grain: bool) -> BoxMesh:
	var key: String = "%s:%d" % ["grain" if grain else "leaf", stage]

	if not _meshes.has(key):
		var shape: BoxMesh = BoxMesh.new()
		var high: float = float(HEIGHT_M[stage]) * (1.0 if grain else 0.7)
		shape.size = Vector3(0.1, high, 0.1) if grain else Vector3(0.22, high, 0.22)
		_meshes[key] = shape

	return _meshes[key]


static func _material(crop_id: String, stage: int, grain: bool) -> StandardMaterial3D:
	var key: String = "%s:%d" % [crop_id, stage]

	if not _materials.has(key):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		var colour: Color = LEAF

		if stage >= 3:
			colour = GRAIN_RIPE if grain else LEAF_RIPE
		elif grain:
			colour = LEAF.lerp(GRAIN_RIPE, 0.25 * float(stage) / 2.0)   # the green yellows a little as the grain fills

		m.albedo_color = colour
		m.roughness = 0.9
		_materials[key] = m

	return _materials[key]


# Two upright cards crossed at right angles, standing on the soil at the origin, sized to the picture's own shape.
static func _card_mesh(crop_id: String, stage: int) -> ArrayMesh:
	var key: String = "card:%s:%d" % [crop_id, stage]

	if not _meshes.has(key):
		var picture: Texture2D = _texture(_card_path(crop_id, stage))
		var high: float = float(PICTURE_HEIGHT_M[crop_id]) * float((GRAIN_SHARE if crop_id in BLADES_YOUNG else MODEL_SHARE)[stage])
		var half: float = high * float(picture.get_width()) / float(maxi(picture.get_height(), 1)) * 0.5
		var cards: SurfaceTool = SurfaceTool.new()
		cards.begin(Mesh.PRIMITIVE_TRIANGLES)

		for across in [Vector3(half, 0.0, 0.0), Vector3(0.0, 0.0, half)]:
			var corners: Array = [-across, across, across + Vector3(0.0, high, 0.0), -across + Vector3(0.0, high, 0.0)]
			var uvs: Array = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]

			for k in [0, 1, 2, 0, 2, 3]:
				cards.set_normal(Vector3.UP)   # lit from above on both faces, as a clump is, not dark from behind
				cards.set_uv(uvs[k])
				cards.add_vertex(corners[k])

		_meshes[key] = cards.commit()

	return _meshes[key]


static func _card_material(crop_id: String, stage: int) -> StandardMaterial3D:
	var key: String = "card:%s:%d" % [crop_id, stage]

	if not _materials.has(key):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_texture = _texture(_card_path(crop_id, stage))
		m.albedo_color = Color.WHITE

		if _card_path(crop_id, stage) == BLADES_PATH:
			m.albedo_color = LEAF.lightened(0.35)
		elif crop_id in BLADES_YOUNG and stage == 2:
			m.albedo_color = GRAIN_GROWING_TINT

		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.9
		_materials[key] = m

	return _materials[key]


static func _card_path(crop_id: String, stage: int) -> String:
	return BLADES_PATH if stage < 2 and crop_id in BLADES_YOUNG else PICTURE_PATH % crop_id


static func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = FloraView._load_texture(path)

	return _textures[path]
