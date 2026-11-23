extends RefCounted

# The trunk collider of a standing tree: as wide as its model is drawn where a player meets it (data/tables/tree_trunks.json, made from the
# models by src/worldgen/tools/make_tree_trunks.gd), for the model variant flora_view draws that tree with (fell_pose.gd drawn_variant). The client's
# trunk cylinder (flora_view) and the server's trunks (terrain_server: arrows, carts, digging, bandit camps) both use it.

const TreeBuilder := preload("res://src/flora/tree_builder.gd")
const FellPose := preload("res://src/flora/fell_pose.gd")

const MEASURE_Y_M := 1.0        # the height on the model the trunk is measured at: a walking player's hips
const TABLE_PATH := "res://data/tables/tree_trunks.json"
const FLORA_PATH := "res://data/tables/flora.json"

static var _rows: Dictionary = {}   # species name -> [radii per variant at the reference height, reference height m, flora.json row]


# The collider radius for the tree `id` of species `species` and `height` m. `fallback`: the radius without the table (flora_placer.collider_radius,
# the species trunk scaled by height); 0 stays 0 (a sapling has no collider).
static func standing_collider(species: String, id: int, height: float, fallback: float) -> float:
	if fallback <= 0.0:
		return 0.0

	var row: Variant = _table().get(species)

	if row == null or float(row[1]) <= 0.0:
		return fallback

	var radii: Array = row[0]
	return float(radii[FellPose.drawn_variant(row[2], id, height) % radii.size()]) * height / float(row[1])


static func _table() -> Dictionary:
	if not _rows.is_empty():
		return _rows

	var rows: Dictionary = {}
	var trunks: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH)) if FileAccess.file_exists(TABLE_PATH) else null
	var flora: Variant = JSON.parse_string(FileAccess.get_file_as_string(FLORA_PATH))

	if trunks is Dictionary and flora is Dictionary:
		for entry in flora["entries"]:
			var radii: Variant = (trunks["trunks"] as Dictionary).get(str(entry["name"]))

			if radii is Array and not (radii as Array).is_empty():
				rows[str(entry["name"])] = [radii, _reference(entry), entry]

	_rows = rows   # one assignment: a worker thread reading it meanwhile sees the empty table and reads the files itself
	return _rows


static func _reference(entry: Dictionary) -> float:
	var span: Array = entry.get("height_m", [])
	return 0.5 * (float(span[0]) + float(span[1])) if span.size() >= 2 else 0.0


# Every tree species' drawn trunk radius per variant (make_tree_trunks.gd, test_tree_trunks.gd).
static func measure_all() -> Dictionary:
	var flora: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FLORA_PATH))
	var out: Dictionary = {}

	for entry in flora["entries"]:
		if str(entry.get("kind", "")) == "tree" and float(entry.get("trunk_m", 0.0)) >= 0.1:
			out[str(entry["name"])] = measure(entry)

	return out


# The drawn trunk radius of each variant of `entry`'s model at its reference height, MEASURE_Y_M above the foot: the lower quartile of the distances
# from the trunk's axis at which its bark surfaces cross that height, so root fins, low boughs and a leaning stem's far side do not widen it (a
# collider a little inside the bark is felt less than an invisible wall). Rounded to the centimetre.
static func measure(entry: Dictionary) -> Array:
	var materials: Dictionary = {}

	for key in ["bark", "birch_bark", "smooth_bark", "fruit", "chrome", "ember", "greens", "fungus", "berry", "petal", "twig", "broad", "conifer", "palm", "fern", "herb", "grass", str(entry.get("leaf", "broad"))]:
		materials[key] = StandardMaterial3D.new()

	var barks: Array = [materials["bark"], materials["birch_bark"], materials["smooth_bark"], materials["chrome"], materials["ember"]]
	var trunk: float = float(entry["trunk_m"])
	var radii: Array = []

	for v in range(TreeBuilder.VARIANTS):
		var found: Array = []

		for surface in TreeBuilder.build_surfaces(entry, _reference(entry), v, false, materials):
			if not barks.has(surface[1]):
				continue

			var points: PackedVector3Array = surface[0][Mesh.ARRAY_VERTEX]
			var index: PackedInt32Array = surface[0][Mesh.ARRAY_INDEX]

			for k in range(0, index.size(), 3):
				for q in 3:
					var a: Vector3 = points[index[k + q]]
					var b: Vector3 = points[index[k + (q + 1) % 3]]

					if (a.y - MEASURE_Y_M) * (b.y - MEASURE_Y_M) < 0.0:
						var at: Vector3 = a.lerp(b, (MEASURE_Y_M - a.y) / (b.y - a.y))
						var r: float = Vector2(at.x, at.z).length()

						if r < maxf(2.0, trunk * 3.0):
							found.append(r)

		found.sort()
		radii.append(snappedf(float(found[found.size() / 4]), 0.01) if not found.is_empty() else snappedf(TreeBuilder.trunk_radius(entry, _reference(entry), v), 0.01))

	return radii
