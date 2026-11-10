extends SceneTree

# The look-at line for plants and trees (Dave and Jamie, 10 Nov 2026): a tree is named for its species, never for its harvest ("Tannin-rich bark"
# on an oak); a plant's hover name carries a property in brackets only when it warns (toxic, stings), not a remedy ("Olive (Cough remedy)").
#   godot --headless --path . --script res://src/worldgen/tools/test_look_labels.gd

const FloraView := preload("res://src/flora/flora_view.gd")
const Harvest := preload("res://src/client/harvest.gd")
const GatherRules := preload("res://src/shared/gather_rules.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	check(FloraView._label_for({"name": "olive", "display": "Olive", "properties": ["cough_remedy"]}) == "Olive", "a remedy is not on the hover line")
	check(FloraView._label_for({"name": "foxglove", "display": "Foxglove", "properties": ["heart_drug", "toxic"]}) == "Foxglove (Toxic)", "a warning is, wherever it is in the list")
	check(FloraView._label_for({"name": "nettle", "display": "Nettle", "properties": ["stings"]}) == "Nettle (Stings)", "stings warns")
	check(FloraView._label_for({"name": "oak", "display": "English oak", "properties": []}) == "English oak", "no properties: the display name")

	var flora: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/tables/flora.json"))
	var drops: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/drops.json"))
	var trees: int = 0

	for entry in flora.get("entries", []):
		var row: Dictionary = entry
		var harvested: bool = not GatherRules.harvest_row(drops, str(row.get("name", ""))).is_empty()

		if str(row.get("kind", "")) == "tree" and harvested:
			trees += 1
			check(not Harvest.named_for_product(row), "%s (a tree with a harvest) is named for itself, not its harvest" % str(row.get("name", "")))
		elif harvested:
			check(Harvest.named_for_product(row), "%s (a bush or herb) is named for what it gives" % str(row.get("name", "")))

	check(trees >= 5, "the oak and the fruit trees were read (%d)" % trees)
	print("test_look_labels: %d failures" % failures)
	quit(1 if failures > 0 else 0)
