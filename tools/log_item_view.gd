extends Node3D

# The dropped-log item mesh of src/client/inventory_view.gd (_log_mesh) for tools/shot_node.gd (Kathleen): species logs and the plain log lying side by side.
#   godot --path . --script res://tools/shot_node.gd -- --script=res://tools/log_item_view.gd --out=C:/temp/logs.png --height=2.5 --pitch=-35

const InventoryView := preload("res://src/client/inventory_view.gd")


func _init() -> void:
	var iv: Node = InventoryView.new()
	add_child(iv)
	var ids: Array = ["log_oak", "log_birch", "log_beech", "log"]

	for k in ids.size():
		var m: MeshInstance3D = MeshInstance3D.new()
		m.mesh = iv._log_mesh(ids[k])
		m.position = Vector3(0.0, 0.3, (float(k) - 1.5) * 0.9)
		add_child(m)
