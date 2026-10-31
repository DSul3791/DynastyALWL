extends Node3D

# The tide-line gather props of src/client/shore_props.gd for tools/shot_node.gd (Kathleen): kelp, mussels, crabs and a nest on sand, in a row.
#   godot --path . --script res://tools/shot_node.gd -- --script=res://tools/shore_props_view.gd --out=C:/temp/shore.png --height=1.4 --pitch=-45

const ShoreProps := preload("res://src/client/shore_props.gd")


func _init() -> void:
	var sand: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(6.0, 3.0)
	var sand_mat: StandardMaterial3D = StandardMaterial3D.new()
	sand_mat.albedo_color = Color(0.82, 0.74, 0.55)
	plane.material = sand_mat
	sand.mesh = plane
	sand.position.y = 0.004
	add_child(sand)
	var props: Node3D = ShoreProps.new()
	add_child(props)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	var kinds: Array = ["kelp", "mussels", "crabs", "nest"]

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--kinds="):
			kinds = a.trim_prefix("--kinds=").split(",", false)

	for k in kinds.size():
		var prop: Node3D = props._make_prop(kinds[k], Vector3((float(k) - float(kinds.size() - 1) * 0.5) * 0.9, 0.0, 0.0), rng)
		prop.rotation.y = 0.3
		props.add_child(prop)
