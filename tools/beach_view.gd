extends Node3D

# Beach scenery meshes of src/client/grass_view.gd for tools/shot_node.gd (Kathleen): shells, seaweed wrack and pebbles on sand, at the sizes and colours _put_shore uses.
#   godot --path . --script res://tools/shot_node.gd -- --script=res://tools/beach_view.gd --out=C:/temp/beach.png --height=0.8 --pitch=-60

const GrassView := preload("res://src/client/grass_view.gd")


func _init() -> void:
	var sand: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(3.0, 3.0)
	sand.position.y = -0.02
	var sand_mat: StandardMaterial3D = StandardMaterial3D.new()
	sand_mat.albedo_color = Color(0.82, 0.74, 0.55)
	plane.material = sand_mat
	sand.mesh = plane
	add_child(sand)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var shell: ArrayMesh = GrassView._make_shell()
	var wrack: ArrayMesh = GrassView._make_wrack()
	var pebble: ArrayMesh = GrassView._make_pebble()

	for k in 40:
		var kind: int = k % 4
		var m: MeshInstance3D = MeshInstance3D.new()
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		var size: float
		var shade: float = rng.randf_range(0.8, 1.1)

		if kind == 0 or kind == 1:
			m.mesh = shell
			size = rng.randf_range(0.04, 0.09) * 3.0
			var hue: float = rng.randf()
			mat.albedo_color = Color(0.85 if hue < 0.5 else 0.78, 0.8 if hue < 0.5 else 0.7, 0.68) * shade
		elif kind == 2:
			m.mesh = wrack
			size = rng.randf_range(0.2, 0.45)
			mat.albedo_color = Color(0.24, 0.22, 0.1) * shade
		else:
			m.mesh = pebble
			size = rng.randf_range(0.07, 0.22)
			mat.albedo_color = Color(0.5, 0.48, 0.42) * shade

		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.material_override = mat
		m.scale = Vector3(size, size, size)
		m.rotation.y = rng.randf() * TAU
		m.position = Vector3(rng.randf_range(-1.2, 1.2), 0.0, rng.randf_range(-1.2, 1.2))
		add_child(m)
