extends SceneTree

# Firewood and wooden-block piles (Dave 2 Nov 2026): a stack of split-log pieces, not balls. Builds the mesh for several counts of each item and checks it exists and grows with the count.
#   godot --headless --path . --script res://src/worldgen/tools/test_pile_logs.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const PileLookScript := preload("res://src/client/pile_look.gd")
const BasicLook := preload("res://src/client/basic_look.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var table = ItemTableScript.load_default()

	for id in ["firewood", "wooden_block"]:
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

	# Sawn boards (Dave 21 Nov 2026: "they should look like 8ft long boards"): one board is 2.44 m long, two or more lie in a lumber stack of 12 triangles a board.
	for id in ["lumber", "hardwood_board"]:
		var entry: Dictionary = table.entry(id)
		check(str(BasicLook.entry(id).get("shape", "")) == "board" and absf(BasicLook.mesh_for(id).get_aabb().size.x - 2.44) < 0.02, "%s: one board is drawn 8 ft long (%s)" % [id, str(BasicLook.mesh_for(id).get_aabb().size)])
		check(entry.has("pile") and str(entry["pile"].get("shape", "")) == "boards" and not PileLookScript.is_pile(entry, 1) and PileLookScript.is_pile(entry, 2), "%s: two or more make a stack of boards" % id)

		for count in [2, 4, 5, 20, 41]:
			var mesh: Mesh = PileLookScript.mesh_for(id, entry, count, 7)
			var tris: int = floori(float((mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size()) / 3.0)
			var box: AABB = mesh.get_aabb()
			check(tris == 12 * count and box.size.x > 2.4 and box.size.x < 2.6 and box.position.y > -0.001, "%s: %d boards are %d triangles, 8 ft long, on the ground (%d, %s)" % [id, count, 12 * count, tris, str(box)])

		var four: AABB = PileLookScript.mesh_for(id, entry, 4, 7).get_aabb()
		var five: AABB = PileLookScript.mesh_for(id, entry, 5, 7).get_aabb()
		check(five.size.y > four.size.y * 1.5 and absf(five.size.z - four.size.z) < 0.05, "%s: four boards lie side by side, the fifth starts the next layer" % id)

	print("pile logs: %d failures" % failures)
	quit(1 if failures > 0 else 0)
