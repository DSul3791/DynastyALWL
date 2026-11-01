extends Node3D

# Dynasty body (src/client/character/dynasty_body.gd) for tools/shot_node.gd (Kathleen): the body playing one of the game's clips, optionally holding an axe-sized stick.
#   godot --path . --script res://tools/shot_node.gd -- --script=res://tools/dynasty_body_view.gd --clip=walk --at=0.4 --hold --out=C:/temp/dyn.png --height=1.9
# --clip= any game name (idle walk jog run crouch sit lie swing jab throw use chop) or one of Dave's; --at= seconds into it; --hold puts a 0.7 m stick in the right hand mount.

const Body := preload("res://src/client/character/dynasty_body.gd")


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

	var body: Node3D = Body.new()
	body.name = "DynastyBody"
	add_child(body)
	body.play(clip, 1.0, 0.0)
	body.animation_player.seek(at, true)
	body.animation_player.speed_scale = 0.0

	if hold:
		var stick: MeshInstance3D = MeshInstance3D.new()
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = 0.02
		cyl.bottom_radius = 0.025
		cyl.height = 0.7
		stick.mesh = cyl
		stick.rotation.x = PI * 0.5
		stick.position = Vector3(0.0, 0.0, -0.35)
		body.hand_mount_r.add_child(stick)
