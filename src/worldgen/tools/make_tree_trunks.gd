extends SceneTree

# Measures every tree model's drawn trunk where a player meets it and writes data/tables/tree_trunks.json, which the trunk colliders read
# (fell_pose.gd standing_collider; world audit 23 Nov 2026: the colliders were the species trunk_m scaled by height, a third too wide on the
# slim young models and up to half too thin on oaks, spruces and pines). Run it again after a tree model changes; test_tree_trunks fails until then.
#   godot --headless --path . --script res://src/worldgen/tools/make_tree_trunks.gd

const TrunkTable := preload("res://src/flora/tree_trunks.gd")


func _init() -> void:
	var table: Dictionary = TrunkTable.measure_all()
	var note: String = "Made by src/worldgen/tools/make_tree_trunks.gd from the tree models (tree_builder.gd): per tree species, the drawn trunk radius in metres of each model variant, %.1f m above its foot, at the species reference height (the middle of height_m). A tree of another height scales it by height / reference, as it is drawn." % TrunkTable.MEASURE_Y_M
	var lines: PackedStringArray = []
	var names: Array = table.keys()
	names.sort()

	for species in names:
		lines.append("\t\t%s: %s" % [JSON.stringify(species), JSON.stringify(table[species])])

	var file: FileAccess = FileAccess.open(TrunkTable.TABLE_PATH, FileAccess.WRITE)
	file.store_string("{\n\t\"table\": \"tree_trunks\",\n\t\"note\": %s,\n\t\"trunks\": {\n%s\n\t}\n}\n" % [JSON.stringify(note), ",\n".join(lines)])
	file.close()
	print("tree_trunks.json: %d species" % table.size())
	quit()
