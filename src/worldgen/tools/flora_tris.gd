extends SceneTree

# Triangles per flora model: builds every wanted species with tree_builder (near and far, variant 0) and counts triangles and surfaces,
# so a crown or leaf change can be reported as a cost before and after (+10 percent budget).
#   godot --headless --path . --script res://src/worldgen/tools/flora_tris.gd -- [--species=maple,oak,beech] [--kind=tree] [--out=FILE.json]
# The mesh is built at the species' reference height (mid of height_m) with plain materials; counts are triangles of all surfaces.

const TreeBuilderScript := preload("res://src/flora/tree_builder.gd")


func _init() -> void:
	var wanted: PackedStringArray = []
	var kind: String = "tree"
	var out: String = ""

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--species="):
			wanted = argument.trim_prefix("--species=").split(",")
		elif argument.begins_with("--kind="):
			kind = argument.trim_prefix("--kind=")
		elif argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")

	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/tables/flora.json"))
	var materials: Dictionary = {}

	for key in ["bark", "birch_bark", "smooth_bark", "chrome", "ember", "broad", "conifer", "palm", "grass", "twig", "oak", "willow", "rowan", "maple", "witness"]:
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		materials[key] = m

	var result: Dictionary = {}
	var total_near: int = 0

	for entry in table["entries"]:
		if entry.get("retired", false) or str(entry["kind"]) != kind:
			continue

		if not wanted.is_empty() and not (str(entry["name"]) in wanted):
			continue

		var height: Array = entry["height_m"]
		var h: float = 0.5 * (float(height[0]) + float(height[1]))
		var row: Dictionary = {}

		for far in [false, true]:
			var mesh: ArrayMesh = TreeBuilderScript.build(entry, h, 0, far, materials)
			var tris: int = 0

			if mesh != null:
				for s in range(mesh.get_surface_count()):
					var arrays: Array = mesh.surface_get_arrays(s)
					var idx = arrays[Mesh.ARRAY_INDEX]
					tris += (idx.size() if idx != null and idx.size() > 0 else arrays[Mesh.ARRAY_VERTEX].size()) / 3

			row["far" if far else "near"] = tris

		total_near += int(row["near"])
		result[str(entry["name"])] = row
		print("%-18s near %6d  far %5d" % [entry["name"], row["near"], row["far"]])

	print("total near %d" % total_near)

	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(JSON.stringify(result, "\t"))
		f.close()

	quit(0)
