extends SceneTree

# Firewood and wooden-block piles (Dave 2 Nov 2026): a stack of split-log pieces, not balls. Builds the mesh for several counts of each item and checks it exists and grows with the count.
#   godot --headless --path . --script res://src/worldgen/tools/test_pile_logs.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const PileLookScript := preload("res://src/client/pile_look.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var table = ItemTableScript.load_default()

	for id in ["firewood", "firewood_soft", "wooden_block", "wooden_block_soft"]:
		var entry: Dictionary = table.entry(id)
		check(entry.has("pile") and str(entry["pile"].get("shape", "")) == "logs", "%s has a logs pile row" % id)
		var least: int = 2 if id.begins_with("firewood") else 6      # firewood shows from 2 pieces, so each split beside the block adds a piece (bug 3)
		check(not PileLookScript.is_pile(entry, least - 1) and PileLookScript.is_pile(entry, least), "%s: %d or more make a pile" % [id, least])
		var last: int = 0

		for count in ([2, 3, 4, 5, 6, 21, 60, 400] if least == 2 else [6, 21, 60, 400]):
			var mesh: Mesh = PileLookScript.mesh_for(id, entry, count, 7)
			var verts: int = (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			check(verts > last, "%s: a pile of %d has more vertices (%d) than the one before (%d)" % [id, count, verts, last])
			last = verts

	print("pile logs: %d failures" % failures)
	quit(1 if failures > 0 else 0)
