extends SceneTree

# Writes the procedural tree models of some species as JSON (positions,
# normals, uvs, colors and triangles per surface), so tools/render_trees.py can draw a
# preview picture without a graphics card.
#
#   godot --headless --path . --script res://src/worldgen/tools/tree_mesh_dump.gd -- --species=balsam_fir,spruce [--far] [--scales=0.4,1,1.4] [--season=winter] [--out=PATH]
#
# Default output: worlds/base_world/plan/tree_meshes.json. Each species gives
# its TreeBuilder variants at its reference height (middle of height_m), or
# with --scales each variant scaled as the game scales a shorter or taller tree.

const TreeBuilder := preload("res://src/flora/tree_builder.gd")


func _init() -> void:
	var names: PackedStringArray = PackedStringArray(["balsam_fir"])
	var far: bool = false
	var season: String = ""
	var scales: PackedFloat64Array = PackedFloat64Array([1.0])
	var out_path: String = "res://worlds/base_world/plan/tree_meshes.json"

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--species="):
			names = argument.trim_prefix("--species=").split(",")
		elif argument.begins_with("--scales="):
			scales = PackedFloat64Array()
			for part in argument.trim_prefix("--scales=").split(","):
				scales.append(float(part))
		elif argument.begins_with("--season="):
			season = argument.trim_prefix("--season=")
		elif argument == "--far":
			far = true
		elif argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")

	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/tables/flora.json"))
	var materials: Dictionary = {}

	for key in ["bark", "broad", "conifer", "palm", "grass", "birch_bark", "twig", "oak", "smooth_bark"]:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.resource_name = key
		materials[key] = material

	var result: Array = []

	for entry in table["entries"]:
		if not names.has(str(entry["name"])):
			continue

		var height: Array = entry["height_m"]
		var reference: float = 0.5 * (float(height[0]) + float(height[1]))

		for index in range(TreeBuilder.VARIANTS * scales.size()):
			var v: int = index % TreeBuilder.VARIANTS
			var scale: float = scales[index / TreeBuilder.VARIANTS]
			var mesh: ArrayMesh = TreeBuilder.build(entry, reference, v, far, materials, season)
			var surfaces: Array = []

			for s in range(mesh.get_surface_count()):
				var arrays: Array = mesh.surface_get_arrays(s)
				var flat_v: Array = []
				var flat_uv: Array = []
				var flat_c: Array = []
				var flat_n: Array = []

				for q in arrays[Mesh.ARRAY_NORMAL]:
					flat_n.append_array([q.x, q.y, q.z])

				for p in arrays[Mesh.ARRAY_VERTEX]:
					flat_v.append_array([p.x * scale, p.y * scale, p.z * scale])

				for t in arrays[Mesh.ARRAY_TEX_UV]:
					flat_uv.append_array([t.x, t.y])

				for c in arrays[Mesh.ARRAY_COLOR]:
					flat_c.append_array([c.r, c.g, c.b, c.a])

				surfaces.append({
					"material": mesh.surface_get_material(s).resource_name,
					"v": flat_v, "n": flat_n, "uv": flat_uv, "c": flat_c,
					"i": Array(arrays[Mesh.ARRAY_INDEX]),
				})

			result.append({"name": str(entry["name"]), "variant": v, "height": reference * scale, "color": entry["color"],
				"young_color": entry.get("young_color", entry["color"]), "young_m": entry.get("young_m", [0.0, 0.1]),
				"autumn_colors": entry.get("autumn_colors", []), "surfaces": surfaces})
			print("%s variant %d: %d triangles" % [entry["name"], v, _triangles(mesh)])

	var file: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(result))
	file.close()
	print("wrote ", out_path)
	quit()


static func _triangles(mesh: ArrayMesh) -> int:
	var n: int = 0

	for s in range(mesh.get_surface_count()):
		n += mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX].size() / 3

	return n
