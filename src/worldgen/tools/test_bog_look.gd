extends SceneTree

# Bog iron in the world (Dave 21 Nov 2026: "it shouldnt just be a big bullseye. it should be the actual color of the ground so change the grounds
# color and when I dig it the color goes away as I get the ore"): no stain sheet; a patch the server sends is rust in the ground shader
# (ground_material.gd set_bogs: centre, radius, share of ore left, its generated level, at most 16), plus a few small ore lumps that thin out as
# it is dug and are gone when it is empty; rebuilt only when that changes; gone with the row; terrain_client keeps the grass off it and hands
# the patches to the shader only when they change.
#   godot --headless --path . --script res://src/worldgen/tools/test_bog_look.gd

const PieceLook := preload("res://src/client/piece_look.gd")
const GroundMaterial := preload("res://src/client/ground_material.gd")

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
			n += floori(float((index as PackedInt32Array).size() if index != null and (index as PackedInt32Array).size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3.0)

	for child in node.get_children():
		n += _triangles(child)

	return n


func _row(id: int, left: int) -> Array:
	return [id, 0, left, Vector3(10.0, 2.0, 10.0), 229, {"key": "1,1", "total": 8, "r": 3.5}]


func _init() -> void:
	var lumps: Node3D = PieceLook.bog_iron_lumps(4)
	var tris: int = _triangles(lumps)
	check(lumps.get_child_count() == 4 and tris > 0 and tris <= 300, "four lumps, under the 300 triangle piece budget (%d)" % tris)
	lumps.free()
	check(FileAccess.get_file_as_string("res://src/client/piece_look.gd").find("static func bog_iron_patch") < 0 and FileAccess.get_file_as_string("res://src/client/look_table.gd").find("bog_iron_patch") < 0, "the old stain sheet is gone")

	var view = load("res://src/client/inventory_view.gd").new()
	var holder: Node3D = Node3D.new()
	view._root = holder
	var id: int = 2000000000
	var rev: int = view.bogs_rev
	view._note_bog(id, _row(id, 8))
	check(view.bogs.has(id) and view.bogs[id].get("node") is Node3D and int(view.bogs[id]["lumps"]) == 4 and holder.get_child_count() == 1, "a full patch in sight has four lumps")
	check(view.bogs_rev > rev and is_equal_approx(float(view.bogs[id]["r"]), 3.5), "and is handed on to the ground shader with its radius")
	var first: Node3D = view.bogs[id]["node"]
	rev = view.bogs_rev
	view._note_bog(id, _row(id, 8))
	check(view.bogs[id]["node"] == first and view.bogs_rev == rev, "the same row again changes nothing (no rebuild every sync)")
	view._note_bog(id, _row(id, 7))
	check(view.bogs[id]["node"] == first and view.bogs_rev > rev, "one ore taken: the same lumps, a paler rust")
	view._note_bog(id, _row(id, 3))
	check(int(view.bogs[id]["lumps"]) == 2 and view.bogs[id]["node"] != first, "most taken: fewer lumps")
	view._note_bog(id, _row(id, 0))
	check(int(view.bogs[id]["lumps"]) == 0 and not view.bogs[id].has("node"), "empty: no lumps")
	rev = view.bogs_rev
	view._forget(id)
	check(not view.bogs.has(id) and view.bogs_rev > rev, "out of sight: forgotten, and the shader told")

	# The shader's rust: nearest first, the share of ore left, the generated level; at most 16.
	var shader: Shader = Shader.new()
	shader.code = GroundMaterial.SHADER
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	var bogs: Dictionary = {}

	for k in range(20):
		bogs[k] = {"pos": Vector3(100.0 + 10.0 * float(k), 3.0, 0.0), "left": 4, "total": 8, "r": 3.0}

	GroundMaterial.set_bogs(mat, bogs, Vector3(100.0, 0.0, 0.0))
	var spots: Variant = mat.get_shader_parameter("bog_spot")
	var floors: Variant = mat.get_shader_parameter("bog_floor")
	check(int(mat.get_shader_parameter("bog_count")) == 16, "at most 16 patches go to the shader")
	check(spots is PackedVector4Array and (spots as PackedVector4Array).size() == 16 and (spots as PackedVector4Array)[0] == Vector4(100.0, 0.0, 3.0, 0.5), "nearest first: centre x, z, radius, half its ore left (%s)" % str(spots[0] if spots is PackedVector4Array and not (spots as PackedVector4Array).is_empty() else "-"))
	check(floors is PackedFloat32Array and is_equal_approx((floors as PackedFloat32Array)[0], 3.0), "with its generated level")
	GroundMaterial.set_bogs(mat, {}, Vector3.ZERO)
	check(int(mat.get_shader_parameter("bog_count")) == 0, "no patches: the rust is off")
	var code: String = GroundMaterial.SHADER
	check(code.find("uniform vec4 bog_spot[16]") >= 0 and code.find("bog_floor[b] - 0.45") >= 0, "the ground shader draws the rust and skips dug ground")

	var client_src: String = FileAccess.get_file_as_string("res://scenes/terrain_client/terrain_client.gd")
	check(client_src.find("for bog_id in items.bogs:") >= 0, "terrain_client clears the grass off every bog patch")
	check(client_src.find("GroundMaterialScript.set_bogs(") >= 0 and client_src.find("items.bogs_rev != _bogs_rev") >= 0, "terrain_client hands the patches to the shader only when they change")

	holder.free()
	view.free()
	print("test_bog_look: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)
