extends SceneTree

# Exports every tree and shrub species' procedural models to glb for Blender (owner request, 2026-10-20:
# "build the meshes for all our trees and put them in a zip so I can work on them").
#   godot --headless --path . --script res://tools/export_tree_meshes.gd -- --out=/some/dir
# Writes <species>.glb (the four near variants side by side, named <species>_v0 to _v3), <species>_far.glb
# (the cheaper far models, 150 to 300 triangles) and <species>_winter.glb where the winter model differs,
# plus a triangle table (triangles.csv). Materials are plain StandardMaterial3D with the game's textures
# (the game draws them with its own shaders: wind sway, back-light, moss, see README.md in the zip).

const TreeBuilder := preload("res://src/flora/tree_builder.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")

var _materials: Dictionary = {}


func _initialize() -> void:
	var out: String = "/tmp/tree_meshes"

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)

	DirAccess.make_dir_recursive_absolute(out)
	_make_materials()
	var tables = TableSetScript.new()
	tables.load_directory()
	var rows: Array = ["species,kind,model_or_shape,variant,near_triangles,far_triangles,surfaces,height_m,crown_m"]
	var exported: int = 0

	for entry in tables.get_entries("flora"):
		if entry.get("retired", false) or str(entry["kind"]) == "plant":
			continue

		var name: String = str(entry["name"])
		var height: Array = entry["height_m"]
		var reference: float = 0.5 * (float(height[0]) + float(height[1]))
		var spread: float = maxf(float(entry["crown_m"]) * 1.4, 2.0)
		var near_root: Node3D = Node3D.new()
		near_root.name = name
		var far_root: Node3D = Node3D.new()
		far_root.name = name + "_far"
		var winter_root: Node3D = Node3D.new()
		winter_root.name = name + "_winter"
		var winter_differs: bool = false

		for v in range(TreeBuilder.VARIANTS):
			var near: ArrayMesh = TreeBuilder.build(entry, reference, v, false, _materials)
			var far: ArrayMesh = TreeBuilder.build(entry, reference, v, true, _materials)
			var winter: ArrayMesh = TreeBuilder.build(entry, reference, v, false, _materials, "winter")
			var near_tris: int = _triangles(near)
			var far_tris: int = _triangles(far)
			rows.append("%s,%s,%s,%d,%d,%d,%d,%.1f,%.1f" % [name, entry["kind"], entry.get("model", entry["shape"]), v, near_tris, far_tris, near.get_surface_count(), reference, float(entry["crown_m"])])
			_add(near_root, near, "%s_v%d" % [name, v], v, spread)
			_add(far_root, far, "%s_v%d_far" % [name, v], v, spread)

			if _triangles(winter) != near_tris:
				winter_differs = true

			_add(winter_root, winter, "%s_v%d_winter" % [name, v], v, spread)

		_write(near_root, out + "/" + name + ".glb")
		_write(far_root, out + "/" + name + "_far.glb")

		if winter_differs:
			_write(winter_root, out + "/" + name + "_winter.glb")

		exported += 1
		near_root.free()
		far_root.free()
		winter_root.free()

	var file: FileAccess = FileAccess.open(out + "/triangles.csv", FileAccess.WRITE)
	file.store_string("\n".join(rows) + "\n")
	file.close()
	print("exported %d species to %s" % [exported, out])
	quit()


func _add(root: Node3D, mesh: ArrayMesh, node_name: String, v: int, spread: float) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = Vector3(float(v) * spread, 0.0, 0.0)
	root.add_child(instance)
	instance.owner = root


func _write(root: Node3D, path: String) -> void:
	var document: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var error: int = document.append_from_scene(root, state)

	if error == OK:
		error = document.write_to_filesystem(state, path)

	if error != OK:
		push_error("could not write %s (%d)" % [path, error])


func _triangles(mesh: ArrayMesh) -> int:
	var total: int = 0

	for s in range(mesh.get_surface_count()):
		total += (mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3

	return total


# Plain materials with the game's painted textures (vertex colour is the tint the game multiplies in).
func _make_materials() -> void:
	var bark: Dictionary = {"bark": "bark.png", "birch_bark": "bark_birch.png", "smooth_bark": "bark_smooth.png", "ember": "bark.png", "chrome": "bark_smooth.png"}
	var leaf: Dictionary = {"broad": "leaf_broad.png", "conifer": "leaf_conifer.png", "palm": "leaf_palm.png", "twig": "twig_birch.png", "oak": "leaf_oak.png", "willow": "leaf_willow.png", "rowan": "leaf_rowan.png", "maple": "leaf_maple.png", "witness": "leaf_witness.png"}

	for key in bark:
		_materials[key] = _standard(key, "res://assets/trees/" + bark[key], false)

	for key in leaf:
		_materials[key] = _standard(key, "res://assets/trees/" + leaf[key], true)

	_materials["grass"] = _standard("grass", "res://assets/grass/grass_tall.png", true)


func _standard(key: String, path: String, cutout: bool) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.resource_name = key
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))

	if image != null:
		material.albedo_texture = ImageTexture.create_from_image(image)

	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	if cutout:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.5

	return material
