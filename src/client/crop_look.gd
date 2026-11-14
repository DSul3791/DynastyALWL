extends RefCounted

# The look of a crop on a tilled bed or garden plot, stage 0 (seedling) to 3 (ripe).
# PLACEHOLDER ART (GOALS-REPAIR WP-R1B): a small grid of plain boxes ("tufts"), scaled and coloured by stage and crop group, as FARMING_SPEC.md step 6 allows as the interim
# ("a green tuft scaled by stage"). It is not Kathleen's crop models (4 stages x each crop) and has not been looked at in the game; replace `build` when they land.

const HEIGHT_M := [0.08, 0.2, 0.38, 0.55]           # stage -> tuft height
const GRAINS := ["wheat", "barley", "oats", "rye", "flax"]   # tall and golden (flax tan) when ripe
const RIPE_COLOUR := {"flax": Color(0.74, 0.66, 0.44)}
const GRAIN_RIPE := Color(0.82, 0.68, 0.25)
const LEAF := Color(0.27, 0.52, 0.2)
const LEAF_RIPE := Color(0.2, 0.42, 0.16)           # roots and greens: a fuller, darker leaf

static var _materials: Dictionary = {}              # "crop:stage" -> StandardMaterial3D
static var _meshes: Dictionary = {}                 # "grain:stage" or "leaf:stage" -> the one BoxMesh every tuft of that look shares


# `side_m`: the bed's footprint (1 for a tilled bed, 2 for a garden plot); a tuft every half metre.
static func build(crop_id: String, stage: int, side_m: float) -> Node3D:
	var root: Node3D = Node3D.new()
	var s: int = clampi(stage, 0, HEIGHT_M.size() - 1)
	var grain: bool = crop_id in GRAINS
	var high: float = _mesh(s, grain).size.y
	var per_side: int = maxi(int(round(side_m * 2.0)), 1)

	for ix in range(per_side):
		for iz in range(per_side):
			var tuft: MeshInstance3D = MeshInstance3D.new()
			tuft.mesh = _mesh(s, grain)
			tuft.material_override = _material(crop_id, s, grain)
			tuft.position = Vector3((float(ix) + 0.5) / float(per_side) * side_m - side_m * 0.5, high * 0.5, (float(iz) + 0.5) / float(per_side) * side_m - side_m * 0.5)
			root.add_child(tuft)

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
			colour = RIPE_COLOUR.get(crop_id, GRAIN_RIPE) if grain else LEAF_RIPE
		elif grain:
			colour = LEAF.lerp(GRAIN_RIPE, 0.25 * float(stage) / 2.0)   # the green yellows a little as the grain fills

		m.albedo_color = colour
		m.roughness = 0.9
		_materials[key] = m

	return _materials[key]
