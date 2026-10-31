extends Node3D

# One flora model built by src/flora/tree_builder.gd for tools/shot_node.gd (Kathleen): an offline four-view picture of a species or a new model name before it has a flora.json row. The entry is
# copied from a real row (--like, default tall_grass) and given the model, name and size you pass; the real build function and vertex colours are used, plain materials (no leaf textures).
#   godot --path . --script res://tools/shot_node.gd -- --script=res://tools/flora_model_view.gd --species=fallen_log --model=fallen_log --h=4 --crown=0.5 --trunk=0.2 --out=C:/temp/log.png --height=2
#   --species=NAME --model=MODEL --h=METRES --crown=M --trunk=M [--like=ROWNAME] [--far=1] [--season=summer]

const TreeBuilderScript := preload("res://src/flora/tree_builder.gd")


func _init() -> void:
	var species: String = "tall_grass"
	var model: String = ""
	var h: float = 1.0
	var crown: float = 0.5
	var trunk: float = 0.0
	var like: String = "tall_grass"
	var far: bool = false
	var season: String = ""

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--species="):
			species = a.trim_prefix("--species=")
		elif a.begins_with("--model="):
			model = a.trim_prefix("--model=")
		elif a.begins_with("--h="):
			h = float(a.trim_prefix("--h="))
		elif a.begins_with("--crown="):
			crown = float(a.trim_prefix("--crown="))
		elif a.begins_with("--trunk="):
			trunk = float(a.trim_prefix("--trunk="))
		elif a.begins_with("--like="):
			like = a.trim_prefix("--like=")
		elif a.begins_with("--season="):
			season = a.trim_prefix("--season=")
		elif a.begins_with("--far="):
			far = a.trim_prefix("--far=") == "1"

	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/tables/flora.json"))
	var entry: Dictionary = {}

	for e in table["entries"]:
		if str(e["name"]) == like:
			entry = (e as Dictionary).duplicate(true)

	if entry.is_empty():
		push_error("flora_model_view: no flora row named " + like)
		return

	entry["name"] = species
	entry["model"] = model if model != "" else species
	entry["crown_m"] = crown
	entry["trunk_m"] = trunk
	entry["height_m"] = [h, h]
	var materials: Dictionary = {}

	for key in ["bark", "birch_bark", "smooth_bark", "chrome", "ember", "broad", "conifer", "palm", "grass", "twig", "oak", "willow", "rowan", "maple", "witness"]:
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 1.0
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		materials[key] = m

	var mesh: ArrayMesh = TreeBuilderScript.build(entry, h, 0, far, materials, season)

	if mesh == null:
		push_error("flora_model_view: the builder made no mesh for " + species)
		return

	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	add_child(node)
