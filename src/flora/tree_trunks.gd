extends RefCounted

# The trunk collider of a standing tree: as wide as its model is drawn where a player meets it (data/look/tree_trunks.json, made from the
# models by src/worldgen/tools/make_tree_trunks.gd), for the model variant flora_view draws that tree with (drawn_variant below). The client's
# trunk cylinder (flora_view) and the server's trunks (terrain_server: arrows, carts, digging, bandit camps) both use it.

const TreeBuilder := preload("res://src/flora/tree_builder.gd")

const MEASURE_Y_M := 1.0        # the height on the model the trunk is measured at: a walking player's hips
const TABLE_PATH := "res://data/look/tree_trunks.json"
const FLORA_PATH := "res://data/tables/flora.json"

const SEARCH_TRUNK_M := 2.0     # the widest trunk the server's trunk searches reach (server_items ARROW_TRUNK_SEARCH_M, carts, digging): a drawn trunk wider than this keeps its old collider

static var _rows: Dictionary = {}   # species name -> [radii per variant at the reference height, reference height m, flora.json row]
static var _loaded: bool = false


# The collider radius for the tree `id` of species `species` and `height` m. `fallback`: the radius without the table (flora_placer.collider_radius,
# the species trunk scaled by height); 0 stays 0 (a sapling has no collider).
static func standing_collider(species: String, id: int, height: float, fallback: float) -> float:
	if fallback <= 0.0:
		return 0.0

	var row: Variant = _table().get(species)

	if row == null or float(row[1]) <= 0.0:
		return fallback

	var radii: Array = row[0]
	var drawn: float = float(radii[drawn_variant(row[2], id, height) % radii.size()]) * height / float(row[1])
	# Never past what the server's trunk searches reach, or the old size: the everember (drawn 6.7 m at 1 m up) keeps its 3.2 m until those searches widen.
	return minf(drawn, maxf(fallback, SEARCH_TRUNK_M))


# Reads the table now (the main thread at start: flora_view and terrain_server), so no worker or tree listing parses the files.
static func warm() -> void:
	_table()


# The model variant flora_view.gd draws for the tree `id` (its own hash; with young_below_m in the species row, trees shorter than it take the young
# half). Mirrors flora_view exactly, including its negative remainders, which index the variant list from the end. fell_pose.gd (the server's
# felled trunk) uses it too; it lives here because the client pack has this script and not fell_pose.
static func drawn_variant(entry: Dictionary, id: int, height: float) -> int:
	var count: int = TreeBuilder.VARIANTS
	var variant: int = (id * 2654435761 >> 5) % count

	if entry.has("young_below_m"):
		@warning_ignore("integer_division")
		var half: int = count / 2
		variant = variant % half + (half if height < float(entry["young_below_m"]) else 0)

	return posmod(variant, count)


static func _table() -> Dictionary:
	if _loaded:
		return _rows

	var rows: Dictionary = {}
	var trunks: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH)) if FileAccess.file_exists(TABLE_PATH) else null
	var flora: Variant = JSON.parse_string(FileAccess.get_file_as_string(FLORA_PATH))

	if trunks is Dictionary and flora is Dictionary:
		for entry in flora["entries"]:
			var radii: Variant = (trunks["trunks"] as Dictionary).get(str(entry["name"]))

			if radii is Array and not (radii as Array).is_empty():
				rows[str(entry["name"])] = [radii, _reference(entry), entry]

	_rows = rows   # warm() reads it on the main thread first; a late reader on a worker would only parse the files again
	_loaded = true   # also when empty (no table): read once, then every collider keeps its fallback
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
		@warning_ignore("integer_division")
		radii.append(snappedf(float(found[found.size() / 4]), 0.01) if not found.is_empty() else snappedf(TreeBuilder.trunk_radius(entry, _reference(entry), v), 0.01))

	return radii
