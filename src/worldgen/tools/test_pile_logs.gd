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
		check(not PileLookScript.is_pile(entry, 5) and PileLookScript.is_pile(entry, 6), "%s: 6 or more make a pile" % id)
		var last: int = 0

		for count in [6, 21, 60, 400]:
			var mesh: Mesh = PileLookScript.mesh_for(id, entry, count, 7)
			var verts: int = (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			check(verts > last, "%s: a pile of %d has more vertices (%d) than the one before (%d)" % [id, count, verts, last])
			last = verts

	print("pile logs: %d failures" % failures)
	quit(1 if failures > 0 else 0)
