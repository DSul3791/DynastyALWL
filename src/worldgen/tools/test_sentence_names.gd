extends SceneTree

# Item names in sentences (coordinator ruling 10 Nov 2026): a "Tier - Item" name reads "tier item" in lower case inside a sentence
# ("You hone the stone knife."); UI labels keep "Stone - Knife" (ItemTable.name_of). ItemTable.sentence_name / in_sentence.
#   godot --headless --path . --script res://src/worldgen/tools/test_sentence_names.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var table = ItemTableScript.load_default()
	check(table.in_sentence("Stone - Knife") == "stone knife", "Stone - Knife reads stone knife")
	check(table.in_sentence("Wooden - Bench") == "wooden bench" and table.in_sentence("Plank") == "plank", "a plain name is only lower-cased")
	check(table.in_sentence("Hide trousers") == "hide trousers", "a name with no dash keeps its words")

	var dashed: int = 0

	for id in table.ids():
		var label: String = table.name_of(table.number_of(id))
		var said: String = table.sentence_name(table.number_of(id))

		if label.contains(" - "):
			dashed += 1

		check(not said.contains(" - ") and said == said.to_lower(), "%s reads %s in a sentence" % [label, said])

	check(dashed > 0, "the table has Tier - Item names to test (%d)" % dashed)

	if failures == 0:
		print("sentence names: all checks passed")

	quit(1 if failures > 0 else 0)
