extends Node3D

# One loose-item model (src/client/basic_look.gd) for tools/shot_node.gd: four views of a single item, or a row of several, offline with the real mesh and vertex colours.
# Kathleen's item-art loop uses it for the iterative critique rounds (art/CRITIQUES/<item>_<date>/round1.png ...).
#   godot --path . --script res://tools/shot_node.gd -- --script=res://tools/look_view.gd --look-item=bedding --out=C:/temp/bedding_round1.png --height=0.5 --pitch=-30
#   --look-item=a,b,c   items from looks.json (and ART_OVERRIDES), laid out in a row 0.5 m apart

const BasicLook := preload("res://src/client/basic_look.gd")


func _init() -> void:
	var ids: PackedStringArray = PackedStringArray()

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--look-item="):
			ids = a.trim_prefix("--look-item=").split(",", false)

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0

	for n in ids.size():
		var mesh: Mesh = BasicLook.mesh_for(ids[n])

		if mesh == null:
			push_warning("look_view: no look for " + ids[n])
			continue

		var node: MeshInstance3D = MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = material
		node.position = Vector3((float(n) - float(ids.size() - 1) * 0.5) * 0.5, 0.06, 0.0)   # items are modelled to lie 0.06 m below their origin: lift them clear of the preview ground
		add_child(node)
