extends Node3D

# The Dynasty first-person arms (src/client/character/dynasty_arms.gd) for tools/shot_node.gd (Kathleen): the arms hanging from the middle of the shoulders at the origin, playing a clip, a stick in the right hand.
#   godot --path . --script res://tools/shot_node.gd -- --script=res://tools/dynasty_arms_view.gd --clip=swing_fp --at=0.5 --hold --out=C:/temp/arms.png --height=1.2 --pitch=-15
# --clip= idle swing_fp jab throw use; --at= seconds into it; --hold puts a 0.7 m stick in the right hand mount. A dummy box fixes the camera's centre (the skinned bounds are not meaningful).

const Arms := preload("res://src/client/character/dynasty_arms.gd")


func _init() -> void:
	var clip: String = "idle"
	var at: float = 0.0
	var hold: bool = false

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--clip="):
			clip = a.trim_prefix("--clip=")
		elif a.begins_with("--at="):
			at = float(a.trim_prefix("--at="))
		elif a == "--hold":
			hold = true

	var arms: Node3D = Arms.new()
	arms.position = Vector3(0.0, 0.7, 0.0)
	add_child(arms)
	arms.play(clip, 1.0, 0.0)
	arms.animation_player.seek(at, true)
	arms.animation_player.speed_scale = 0.0
	var marker: MeshInstance3D = MeshInstance3D.new()
	marker.mesh = BoxMesh.new()
	(marker.mesh as BoxMesh).size = Vector3(0.9, 0.9, 0.5)
	marker.position = Vector3(0.0, 0.45, 0.0)
	marker.visible = false
	add_child(marker)

	if hold:
		var stick: MeshInstance3D = MeshInstance3D.new()
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = 0.02
		cyl.bottom_radius = 0.025
		cyl.height = 0.7
		stick.mesh = cyl
		stick.rotation.x = PI * 0.5
		stick.position = Vector3(0.0, 0.0, -0.35)
		arms.hand_mount_r.add_child(stick)
