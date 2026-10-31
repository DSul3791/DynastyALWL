extends Node3D

# A 3 x 3 sheet of the campfire look for tools/shot_node.gd (Kathleen): one row per state (laid and unlit, lit, burnt out), one column per fire tier (1 survival, 2 campfire,
# 3 bonfire), 1.6 m apart. Offline preview of the real meshes and vertex colours (not the game light).
#   godot --path . --script res://tools/shot_node.gd -- --script=res://tools/fire_grid.gd --out=C:/temp/fires.png --height=5

const BuildingLook := preload("res://src/client/building_look.gd")


func _init() -> void:
	var rows: Array = [[false, true], [true, false], [false, false]]   # [lit, loaded]

	for r in rows.size():
		for tier in range(1, 4):
			var fire: Node3D = BuildingLook.fire(bool(rows[r][0]), bool(rows[r][1]), tier)
			fire.position = Vector3((float(tier) - 2.0) * 1.6, 0.0, (float(r) - 1.0) * 1.6)
			add_child(fire)
