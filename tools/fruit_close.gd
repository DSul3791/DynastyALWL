extends Node3D

# A few round apples close up for tools/shot_node.gd (Kathleen): the real TreeBuilder._round_fruit, vertex colours, a leaf-green backdrop card.
#   godot --path . --script res://tools/shot_node.gd -- --script=res://tools/fruit_close.gd --out=C:/temp/apples.png --height=0.5 --pitch=-10

const TreeBuilderScript := preload("res://src/flora/tree_builder.gd")


func _init() -> void:
	var acc: RefCounted = TreeBuilderScript.Acc.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5

	for k in 5:
		var c: Color = TreeBuilderScript.APPLE_TINT * rng.randf_range(0.92, 1.1)
		c.a = 0.0
		TreeBuilderScript._round_fruit(acc, Vector3(-0.2 + 0.1 * float(k), 0.1, 0.03 * float(k % 2)), 0.07, c, rng)

	var mesh: ArrayMesh = ArrayMesh.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	acc.commit(mesh, material)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	add_child(node)
