extends SceneTree

# A standing tree's trunk collider is as wide as its model is drawn (world audit 23 Nov 2026: the collider was the species trunk_m scaled by height,
# up to 0.3 m of invisible wall round the slim young models and up to 0.4 m inside the bark of oaks, spruces and pines). The table the colliders read,
# data/look/tree_trunks.json, must match the models: after a change to a tree model run src/worldgen/tools/make_tree_trunks.gd.
#   godot --headless --path . --script res://src/worldgen/tools/test_tree_trunks.gd

const TreeBuilder := preload("res://src/flora/tree_builder.gd")
const TreeTrunks := preload("res://src/flora/tree_trunks.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")
const TABLE := "res://data/look/tree_trunks.json"

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var table: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string(TABLE)) as Dictionary)["trunks"]
	var measured: Dictionary = TreeTrunks.measure_all()
	check(measured.size() >= 40 and measured.keys().size() == table.keys().size(), "every tree species with a trunk collider is in the table (%d measured, %d in it)" % [measured.size(), table.size()])

	for species in measured:
		var now: Array = measured[species]
		var kept: Array = table.get(species, [])
		var same: bool = kept.size() == now.size()

		for v in range(mini(kept.size(), now.size())):
			same = same and absf(float(kept[v]) - float(now[v])) <= 0.015

		check(same, "%s: tree_trunks.json %s is the model's trunk %s (run make_tree_trunks.gd after a model change)" % [species, str(kept), str(now)])

	var flora: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/tables/flora.json"))
	var rows: Dictionary = {}

	for entry in flora["entries"]:
		rows[str(entry["name"])] = entry

	var oak: Dictionary = rows["oak"]
	var reference: float = 0.5 * (float(oak["height_m"][0]) + float(oak["height_m"][1]))
	var old: float = PlacerScript.collider_radius(PlacerScript.KIND_TREE, float(oak["trunk_m"]), 1.0, reference)
	var oak_r: float = TreeTrunks.standing_collider("oak", 5, reference, old)
	check(oak_r > old + 0.2 and absf(oak_r - float(table["oak"][TreeTrunks.drawn_variant(oak, 5, reference)])) < 0.001, "an oak at its reference height collides at its drawn trunk (%.2f m, trunk_m %.2f)" % [oak_r, old])
	check(absf(TreeTrunks.standing_collider("oak", 5, reference * 0.5, old * 0.5) - oak_r * 0.5) < 0.001, "a half-height oak is drawn, and collides, half as wide")
	check(TreeTrunks.standing_collider("oak", 5, 1.5, 0.0) == 0.0, "a sapling still has no collider")
	check(TreeTrunks.standing_collider("no_such_tree", 5, 10.0, 0.42) == 0.42, "a species not in the table keeps the old collider")
	var walnut: Dictionary = rows["walnut"]
	var young_id: int = -1

	for id in range(1, 200):
		if TreeTrunks.drawn_variant(walnut, id, 8.0) >= 2:
			young_id = id
			break

	var walnut_old: float = PlacerScript.collider_radius(PlacerScript.KIND_TREE, float(walnut["trunk_m"]), 8.0 / 13.5, 8.0)
	check(young_id > 0 and TreeTrunks.standing_collider("walnut", young_id, 8.0, walnut_old) < walnut_old * 0.6, "an 8 m walnut, drawn as a slim young pole, has a slim collider, no invisible wall round it")

	var snag: Dictionary = rows["dead_tree"]
	var snag_ref: float = 0.5 * (float(snag["height_m"][0]) + float(snag["height_m"][1]))
	var snag_r: float = TreeTrunks.standing_collider("dead_tree", 7, snag_ref, TreeTrunks.snag_fallback(snag_ref, snag_ref))
	check(TreeTrunks.is_snag(snag) and not TreeTrunks.is_snag(rows["fallen_log"]) and not TreeTrunks.is_snag(rows["old_stump"]), "the standing dead tree is a snag; fallen logs and old stumps are not")
	check(absf(snag_r - float(table["dead_tree"][0])) < 0.02 and snag_r > 0.15, "a standing dead tree blocks at its drawn trunk (%.2f m)" % snag_r)
	check(FileAccess.get_file_as_string("res://src/flora/flora_view.gd").contains("TreeTrunks.snag_fallback("), "flora_view gives the dead tree its trunk collider")

	var ever: Dictionary = rows["everember"]
	var ever_ref: float = 0.5 * (float(ever["height_m"][0]) + float(ever["height_m"][1]))
	var ever_old: float = PlacerScript.collider_radius(PlacerScript.KIND_TREE, float(ever["trunk_m"]), 1.0, ever_ref)
	var ever_r: float = TreeTrunks.standing_collider("everember", 5, ever_ref, ever_old)
	check(ever_r > 5.0 and absf(ever_r - float(table["everember"][TreeTrunks.drawn_variant(ever, 5, ever_ref)])) < 0.001, "the everember collides at its drawn trunk (%.2f m), not its old %.1f m" % [ever_r, ever_old])
	check(TreeTrunks.widest_m() >= ever_r * float(ever["height_m"][1]) / ever_ref - 0.001, "widest_m covers the widest trunk at its tallest (%.2f m)" % TreeTrunks.widest_m())
	var server: String = FileAccess.get_file_as_string("res://scenes/terrain_server/terrain_server.gd")
	check(server.contains("radius + float(tree[3])") and server.contains("> TreeTrunks.SEARCH_TRUNK_M") and server.contains("TreeTrunks.widest_m()"), "the server finds a trunk wider than its callers' margins by its own radius")


	# The server's trunk list (terrain_server _cached_trees): an everember is found by its own radius from an arrow's ordinary 2 m margin at its bark.
	var fake: FakeFlora = FakeFlora.new()
	var ever_id: int = int(ever["id"])
	var oak_id: int = int(oak["id"])
	fake.placer._by_id[ever_id] = {"kind": PlacerScript.KIND_TREE, "name": "everember", "trunk": float(ever["trunk_m"]), "height_min": float(ever["height_m"][0]), "height_max": float(ever["height_m"][1])}
	fake.placer._by_id[oak_id] = {"kind": PlacerScript.KIND_TREE, "name": "oak", "trunk": float(oak["trunk_m"]), "height_min": float(oak["height_m"][0]), "height_max": float(oak["height_m"][1])}
	var ever_at: Vector3 = Vector3(300.0, 10.0, 300.0)
	fake.items = {"ids": PackedInt32Array([(ever_id << 16) | 5, (oak_id << 16) | 1]), "positions": PackedVector3Array([ever_at, Vector3(330.0, 10.0, 300.0)]), "heights": PackedFloat32Array([ever_ref, reference])}
	var host = load("res://scenes/terrain_server/terrain_server.gd").new()
	host.flora = fake
	var bark: Vector3 = ever_at + Vector3(ever_r + 0.5, 0.0, 0.0)
	var near_bark: Array = host._cached_trees(bark, 2.0)
	check(near_bark.size() == 1 and str(near_bark[0][2]) == "everember" and absf(float(near_bark[0][3]) - ever_r) < 0.001, "2 m from an everember's bark the server finds it, at its drawn radius (%s)" % str(near_bark))
	check(host._cached_trees(ever_at + Vector3(ever_r + 3.0, 0.0, 0.0), 2.0).is_empty(), "and not 3 m out")
	var by_oak: Array = host._cached_trees(Vector3(331.5, 10.0, 300.0), 2.0)
	check(by_oak.size() == 1 and str(by_oak[0][2]) == "oak", "an ordinary trunk is found as before, by its root within the radius")
	host.free()

	var flora_view: String = FileAccess.get_file_as_string("res://src/flora/flora_view.gd")
	check(flora_view.contains("(ids[n] * 2654435761 >> 5) % int(info[\"near\"].size())") and flora_view.contains("variant % half + (half if float(items[\"heights\"][n]) < float(info[\"young_below\"]) else 0)"), "flora_view picks the drawn variant as drawn_variant does")
	check(FileAccess.get_file_as_string("res://src/stream/server_items.gd").contains("const ARROW_TRUNK_SEARCH_M := %.1f" % TreeTrunks.SEARCH_TRUNK_M), "the arrow trunk search margin is SEARCH_TRUNK_M, past which the server lists a trunk as wide")

	print("tree trunks: %d failures" % failures)
	quit(1 if failures > 0 else 0)


# A stand-in for the server's flora (server_flora.gd): one chunk with an everember and an oak, nothing removed.
class FakePlacer:
	var chunk_m: float = 256.0
	var _by_id: Dictionary = {}

	func normalize(chunk: Vector2i) -> Vector2i:
		return chunk


class FakeFlora:
	var placer: FakePlacer = FakePlacer.new()
	var items: Dictionary = {}

	func items_cached(chunk: Vector2i) -> Dictionary:
		return items if chunk == Vector2i(1, 1) else {}

	func removed_in(_chunk: Vector2i) -> Array:
		return []
