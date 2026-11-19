extends SceneTree

# Bog iron deposit stains drawn in the world (Dave 19 Nov 2026: "make sure they are obvious and visible for characters to find"): a row the
# server sends becomes one ground stain, rebuilt only when its state (dry, wet, dug) changes, gone with the row; the stain is cheap and its ochre
# stands out from peat; terrain_client keeps the grass off it.
#   godot --headless --path . --script res://src/worldgen/tools/test_bog_look.gd

const PieceLook := preload("res://src/client/piece_look.gd")
const PEAT := Color(0.14, 0.1, 0.07)

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _triangles(node: Node) -> int:
	var n: int = 0

	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh: Mesh = (node as MeshInstance3D).mesh

		for s in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(s)
			var index: Variant = arrays[Mesh.ARRAY_INDEX]
			n += ((index as PackedInt32Array).size() if index != null and (index as PackedInt32Array).size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3

	for child in node.get_children():
		n += _triangles(child)

	return n


func _brightest(node: Node) -> float:
	var best: float = 0.0

	if node is MeshInstance3D and (node as MeshInstance3D).material_override is StandardMaterial3D:
		best = ((node as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.get_luminance()

	for child in node.get_children():
		best = maxf(best, _brightest(child))

	return best


func _init() -> void:
	for state in ["dry", "wet", "dug"]:
		var patch: Node3D = PieceLook.bog_iron_patch(state)
		var tris: int = _triangles(patch)
		check(tris > 0 and tris < 800, "a %s stain is cheap: %d triangles" % [state, tris])
		check(_brightest(patch) > PEAT.get_luminance() * 3.0, "a %s stain's ochre is at least three times as bright as peat (%.2f)" % [state, _brightest(patch)])
		patch.free()

	var view = load("res://src/client/inventory_view.gd").new()
	var root: Node3D = Node3D.new()
	view._root = root
	var id: int = 2000000000
	var row: Array = [id, 0, 8, Vector3(10.0, 2.0, 10.0), 229, {"key": "1,1", "total": 8, "wet": false}]
	view._note_bog(id, row)
	check(view.bogs.has(id) and view.bogs[id].get("node") is Node3D and str(view.bogs[id]["state"]) == "dry" and root.get_child_count() == 1, "a full deposit in sight is drawn dry")
	var first: Node3D = view.bogs[id]["node"]
	view._note_bog(id, row)
	check(view.bogs[id]["node"] == first, "the same row again keeps the same stain (no rebuild every sync)")
	view._note_bog(id, [id, 0, 6, Vector3(10.0, 2.0, 10.0), 229, {"key": "1,1", "total": 8, "wet": false}])
	check(str(view.bogs[id]["state"]) == "dug" and view.bogs[id]["node"] != first, "ore taken: it is drawn dug")
	view._note_bog(id, [id, 0, 6, Vector3(10.0, 2.0, 10.0), 229, {"key": "1,1", "total": 8, "wet": true}])
	check(str(view.bogs[id]["state"]) == "wet", "under standing water: wet")
	view._forget(id)
	check(not view.bogs.has(id), "out of sight: forgotten")

	var client_src: String = FileAccess.get_file_as_string("res://scenes/terrain_client/terrain_client.gd")
	check(client_src.find("for bog_id in items.bogs:") >= 0, "terrain_client clears the grass off every bog stain")

	root.free()
	view.free()
	print("test_bog_look: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)
