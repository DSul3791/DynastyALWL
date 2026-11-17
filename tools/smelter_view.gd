extends Node3D

# The three smelters as the game draws a placed one (inventory_view._model_for_state, with _smelter_fire), for tools/shot_node.gd: back row
# cold (row lit false), front row lit (row lit true, its fire light switched on as the nearest-lights list does in game), and at the right
# the Primitive smelter's blueprint ghost (inventory_view.ghost_model). Left to right: Primitive, Improved, Advanced. Dave 17 Nov 2026: "it
# needs to show no fire when its not lit".
#   godot --path . --script res://tools/shot_node.gd -- --script=res://tools/smelter_view.gd --out=C:/temp/smelters.png --height=5 --pitch=-25
# Not the game lighting or the blue blueprint tint; tools/look_rig.sh at a placed smelter shows that.

const ViewScript := preload("res://src/client/inventory_view.gd")


func _init() -> void:
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(16.0, 12.0)
	var soil: StandardMaterial3D = StandardMaterial3D.new()
	soil.albedo_color = Color(0.42, 0.38, 0.3)
	plane.material = soil
	ground.mesh = plane
	add_child(ground)
	var view = ViewScript.new()
	var structures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/structures.json"))["structures"]
	var x: float = -4.5

	for kind in ["smelter", "improved_smelter", "large_forge"]:
		var state: int = int(structures[kind]["state"])

		for lit in [false, true]:
			var model: Node3D = view._model_for_state(state, {"lit": lit})
			model.position = Vector3(x, 0.0, 2.0 if lit else -2.5)
			var light: Node3D = model.get_node_or_null("Light") as Node3D

			if light != null:
				light.visible = lit

			add_child(model)

		x += 3.5

	var ghost: Node3D = view.ghost_model(int(structures["smelter"]["state"]))
	ghost.position = Vector3(6.0, 0.0, 0.0)
	add_child(ghost)
	view.free()
