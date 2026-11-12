extends SceneTree

# TEST-007 (Dave's playtest 12 Nov 2026): seen from underneath, the middle and upper canopy of the trees had large gaps. The limb-built hardwood crowns
# (maple, beech, oak, sweet chestnut, walnut) hung every leaf clump on the limb tips at the crown's shell, so the upper middle over the trunk was empty.
# tree_builder.gd _crown_core now fills it. This builds each one's near model the way flora_view.gd does and looks straight up from beside the trunk:
# the share of the sky within CONE_DEG of overhead that leaf cards cover (the card shapes, not the see-through gaps painted in the leaf texture).
# Run: godot --headless --path . -s src/worldgen/tools/test_canopy_cover.gd

const TreeBuilder := preload("res://src/flora/tree_builder.gd")
const SPECIES := ["maple", "beech", "oak", "sweet_chestnut", "walnut"]
const EYE := Vector3(1.0, 1.7, 0.0)   # a player standing a metre from the trunk
const CONE_DEG := 20.0
const CELLS := 40                     # across the cone, on a flat plane one metre above the eye
const MIN_COVER := 0.85                # before the core: oak about 0.33, maple 0.68 to 0.9, beech 0.77 to 0.95 (a port of the builder, 12 Nov 2026)

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1

	print("%s %s" % ["ok  " if ok else "FAIL", what])


# The share of the cells inside the cone that a leaf triangle covers, the triangles seen from `eye` and projected onto the plane y = eye.y + 1.
static func sky_cover(arrays: Array, eye: Vector3) -> float:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var t: float = tan(deg_to_rad(CONE_DEG))
	var cell: float = 2.0 * t / float(CELLS)
	var hit: PackedByteArray = PackedByteArray()
	hit.resize(CELLS * CELLS)
	hit.fill(0)

	for k in range(0, index.size(), 3):
		var g: Array = []

		for j in range(3):
			var p: Vector3 = verts[index[k + j]] - eye

			if p.y < 0.1:
				break

			g.append(Vector2(p.x / p.y, p.z / p.y))

		if g.size() < 3:
			continue

		var lo: Vector2 = (g[0] as Vector2).min(g[1]).min(g[2])
		var hi: Vector2 = (g[0] as Vector2).max(g[1]).max(g[2])

		for cz in range(maxi(int(floor((lo.y + t) / cell)), 0), mini(int(floor((hi.y + t) / cell)) + 1, CELLS)):
			for cx in range(maxi(int(floor((lo.x + t) / cell)), 0), mini(int(floor((hi.x + t) / cell)) + 1, CELLS)):
				var c: Vector2 = Vector2((float(cx) + 0.5) * cell - t, (float(cz) + 0.5) * cell - t)

				if Geometry2D.point_is_inside_triangle(c, g[0], g[1], g[2]):
					hit[cz * CELLS + cx] = 1

	var inside: int = 0
	var covered: int = 0

	for cz in range(CELLS):
		for cx in range(CELLS):
			if Vector2((float(cx) + 0.5) * cell - t, (float(cz) + 0.5) * cell - t).length() <= t:
				inside += 1
				covered += hit[cz * CELLS + cx]

	return float(covered) / float(maxi(inside, 1))


# tree_builder.gd _crown_variety: about one crown in eight is dying (a wedge of its upper crown bare) and one in twenty mostly dead, on purpose
# (moderator 2026-10-31). Its own random stream, drawn in the same order: the ninth draw is the roll. 0 healthy.
static func variety_state(species: String, variant: int) -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([species, variant, "variety"])

	for k in range(8):
		rng.randf()

	var roll: float = rng.randf()
	return 2 if roll < 0.05 else (1 if roll < 0.17 else 0)


func _init() -> void:
	var leaf: StandardMaterial3D = StandardMaterial3D.new()
	var materials: Dictionary = {}

	for key in ["bark", "birch_bark", "smooth_bark", "chrome", "ember", "greens", "twig", "fungus", "berry", "fruit", "petal"]:
		materials[key] = StandardMaterial3D.new()

	for key in ["broad", "conifer", "palm", "grass", "oak", "willow", "rowan", "maple", "witness", "fern", "herb"]:
		materials[key] = leaf

	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/tables/flora.json"))
	var rows: Dictionary = {}

	for entry in table["entries"]:
		if str(entry.get("name", "")) in SPECIES and not bool(entry.get("retired", false)):
			rows[str(entry["name"])] = entry

	_check(rows.size() == SPECIES.size(), "all %d hardwoods are in flora.json" % SPECIES.size())

	for species in SPECIES:
		if not rows.has(species):
			continue

		var entry: Dictionary = rows[species]
		# flora_view.gd builds every model at the middle of the height range and scales each tree to its own height; variants 0 and 1 are the mature
		# crowns (2 and 3 the young ones, a pole with a leafy top of its own).
		var h: float = 0.5 * (float(entry["height_m"][0]) + float(entry["height_m"][1]))

		for variant in [0, 1]:
			if variety_state(species, variant) != 0:
				print("skip %s variant %d: a dying crown by design" % [species, variant])
				continue

			var mesh: ArrayMesh = TreeBuilder.build(entry, h, variant, false, materials)
			var cover: float = -1.0

			for s in range(mesh.get_surface_count()):
				if mesh.surface_get_material(s) == leaf:
					cover = sky_cover(mesh.surface_get_arrays(s), EYE)

			_check(cover >= MIN_COVER, "%s variant %d, %.0f m: leaves cover %.0f%% of the sky within %.0f degrees of overhead (at least %.0f%%)" % [species, variant, h, cover * 100.0, CONE_DEG, MIN_COVER * 100.0])

	# The core is small and near-only: 12 vertices a clump (three cards), none on the far model.
	var near: TreeBuilder.Acc = TreeBuilder.Acc.new()
	TreeBuilder._crown_core(near, Vector3(0.0, 12.0, 0.0), 8.0, 20.0, 10, 0.6, false)
	_check(near.v.size() == 10 * 12, "ten core clumps are 120 vertices (%d)" % near.v.size())
	var far: TreeBuilder.Acc = TreeBuilder.Acc.new()
	TreeBuilder._crown_core(far, Vector3(0.0, 12.0, 0.0), 8.0, 20.0, 10, 0.6, true)
	_check(far.v.is_empty(), "and none on the far model")
	var top: float = 0.0

	for p in near.v:
		top = maxf(top, p.y)

	_check(top <= 20.0 + 8.0 * 0.36, "the core stays inside the crown's top (highest card corner %.1f m)" % top)

	print("canopy cover: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(1 if _fails > 0 else 0)
