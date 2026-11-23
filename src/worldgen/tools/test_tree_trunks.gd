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

	var ever: Dictionary = rows["everember"]
	var ever_ref: float = 0.5 * (float(ever["height_m"][0]) + float(ever["height_m"][1]))
	var ever_old: float = PlacerScript.collider_radius(PlacerScript.KIND_TREE, float(ever["trunk_m"]), 1.0, ever_ref)
	check(TreeTrunks.standing_collider("everember", 5, ever_ref, ever_old) <= maxf(ever_old, TreeTrunks.SEARCH_TRUNK_M) + 0.001, "a trunk drawn wider than the server's trunk searches reach never grows past its old collider")

	for species in table:
		var row: Dictionary = rows[species]
		var tallest: float = float(row["height_m"][1])
		var ref: float = 0.5 * (float(row["height_m"][0]) + tallest)
		var fallback: float = PlacerScript.collider_radius(PlacerScript.KIND_TREE, float(row["trunk_m"]), tallest / ref, tallest)

		for id in range(1, 9):
			var r: float = TreeTrunks.standing_collider(species, id, tallest, fallback)
			check(r <= maxf(fallback, TreeTrunks.SEARCH_TRUNK_M) + 0.001, "%s at its tallest: collider %.2f m within the server's trunk search (%.1f m) or its old size" % [species, r, TreeTrunks.SEARCH_TRUNK_M])

	var flora_view: String = FileAccess.get_file_as_string("res://src/flora/flora_view.gd")
	check(flora_view.contains("(ids[n] * 2654435761 >> 5) % int(info[\"near\"].size())") and flora_view.contains("variant % half + (half if float(items[\"heights\"][n]) < float(info[\"young_below\"]) else 0)"), "flora_view picks the drawn variant as drawn_variant does")
	check(FileAccess.get_file_as_string("res://src/stream/server_items.gd").contains("const ARROW_TRUNK_SEARCH_M := %.1f" % TreeTrunks.SEARCH_TRUNK_M), "the arrow trunk search reaches SEARCH_TRUNK_M")

	print("tree trunks: %d failures" % failures)
	quit(1 if failures > 0 else 0)
