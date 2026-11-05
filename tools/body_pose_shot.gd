extends SceneTree

# A still of the Dynasty body holding one clip, offline (no world, no server): for checking poses like the ground sit (BUG-020) without the PC.
# Needs a real renderer: in the cloud, Xvfb plus software Vulkan (project memory "cloud-rendering").
#   godot --path . --rendering-driver vulkan --script res://tools/body_pose_shot.gd -- --clip=sit --out=/tmp/sit.png [--yaw=90] [--t=0.5]
# yaw 180 looks at his front, 0 at his back, 90 at his side. Grid lines on the ground are 0.5 m apart.

const DynastyBodyScript := preload("res://src/client/character/dynasty_body.gd")

var clip: String = "sit"
var out: String = "user://pose.png"
var yaw_deg: float = 90.0
var at_s: float = 0.5
var frames: int = 0
var dist: float = 1.8
var body: Node3D


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--clip="):
			clip = a.trim_prefix("--clip=")
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--yaw="):
			yaw_deg = float(a.trim_prefix("--yaw="))
		elif a.begins_with("--t="):
			at_s = float(a.trim_prefix("--t="))

	root.size = Vector2i(900, 900)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.74, 0.86)
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(4, 4)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.45, 0.28)
	ground.material_override = mat
	root.add_child(ground)

	for k in range(-4, 5):   # 0.5 m grid lines, to read heights and positions
		for along in [true, false]:
			var line := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(4.0, 0.004, 0.01) if along else Vector3(0.01, 0.004, 4.0)
			line.mesh = box
			line.position = Vector3(0.0, 0.002, k * 0.5) if along else Vector3(k * 0.5, 0.002, 0.0)
			root.add_child(line)

	body = DynastyBodyScript.new()
	root.add_child(body)
	var cam := Camera3D.new()
	var yaw: float = deg_to_rad(yaw_deg)
	root.add_child(cam)
	cam.look_at_from_position(Vector3(sin(yaw) * dist, 0.7, cos(yaw) * dist), Vector3(0.0, 0.4, 0.0))
	cam.current = true


func _process(_delta: float) -> bool:
	frames += 1

	if frames == 3:
		body.play(clip, 1.0, 0.0)
		body.animation_player.seek(at_s, true)
		body.animation_player.pause()

	if frames == 12:
		root.get_texture().get_image().save_png(out)
		print("saved ", out)
		return true

	return false
