extends SceneTree

# PROTOTYPE (Sonny, 2026-10-30), plan 6: close-ups of the simplified hands (open, fist, point, clutch) and of the eyes and brows (normal, blink, wide, low brows).
#   godot --path . --resolution 320x240 --script res://tools/proto_hands.gd -- --out=res://art/character_proto/hands
# Needs a window.

const Generator := preload("res://src/client/character/body_generator.gd")
const SHOT := Vector2i(300, 300)

var _out: String = "res://art/character_proto/hands"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)

	_run()


func _frames() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw


func _curl(sk: Skeleton3D, prefix: String, finger: String, prox: float, dist: float) -> void:
	sk.set_bone_pose_rotation(sk.find_bone(prefix + finger + "Proximal"), Quaternion.from_euler(Vector3(prox, 0.0, 0.0)))
	sk.set_bone_pose_rotation(sk.find_bone(prefix + finger + "Distal"), Quaternion.from_euler(Vector3(dist, 0.0, 0.0)))


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var viewport: SubViewport = SubViewport.new()
	viewport.size = SHOT
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.72, 0.8)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.68)
	env.ambient_light_energy = 0.9
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	viewport.add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30.0, -25.0, 0.0)
	viewport.add_child(sun)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 22.0
	viewport.add_child(cam)
	var made: Dictionary = Generator.make_node(Generator.make_genome("broad"), 0.035)
	var node: Node3D = made["node"]
	viewport.add_child(node)
	var sk: Skeleton3D = made["skeleton"]
	await _frames()
	var shots: Array = []
	var hand: Vector3 = sk.get_bone_global_rest(sk.find_bone("RightHand")).origin + Vector3(0.0, -0.06, 0.0)
	# Hand poses: the arm is raised a little and turned so the palm faces the camera.
	sk.set_bone_pose_rotation(sk.find_bone("RightUpperArm"), Quaternion.from_euler(Vector3(1.2, 0.0, 0.3)))
	sk.set_bone_pose_rotation(sk.find_bone("RightLowerArm"), Quaternion.from_euler(Vector3(0.9, 0.0, 0.0)))
	await _frames()
	var palm: Vector3 = sk.get_bone_global_pose(sk.find_bone("RightHand")).origin
	cam.fov = 14.0
	var poses: Array = [
		["open", [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]],
		["fist", [0.7, 0.5, 1.5, 1.3, 1.5, 1.3, 1.5, 1.3]],
		["point", [0.7, 0.5, 0.0, 0.0, 1.5, 1.3, 1.5, 1.3]],
		["claw", [0.3, 0.3, 0.9, 0.7, 0.9, 0.7, 0.9, 0.7]],
	]

	for pose in poses:
		var v: Array = pose[1]
		_curl(sk, "Right", "Thumb", v[0], v[1])
		_curl(sk, "Right", "Index", v[2], v[3])
		_curl(sk, "Right", "Middle", v[4], v[5])
		_curl(sk, "Right", "Little", v[6], v[7])
		var aim: Vector3 = palm + Vector3(0.0, 0.05, -0.09)
		cam.look_at_from_position(aim + Vector3(0.75, 0.0, 0.0), aim)
		await _frames()
		shots.append(_grab(viewport))

	# Faces: eyes and brows.
	for tag in ["Left", "Right"]:
		sk.set_bone_pose_rotation(sk.find_bone(tag + "UpperArm"), Quaternion.IDENTITY)
		sk.set_bone_pose_rotation(sk.find_bone(tag + "LowerArm"), Quaternion.IDENTITY)

	cam.fov = 22.0
	var head: Vector3 = sk.get_bone_global_rest(sk.find_bone("Head")).origin + Vector3(0.0, 0.14, 0.0)
	cam.look_at_from_position(head + Vector3(0.0, 0.0, -0.9), head)
	var face: Node3D = node.get_meta("face")

	for expr in [[1.0, 0.0], [0.08, 0.0], [1.35, 1.0], [0.55, -1.0]]:
		Generator.set_expression(face, expr[0], expr[1])
		await _frames()
		shots.append(_grab(viewport))

	var sheet: Image = Image.create(SHOT.x * 4, SHOT.y * 2, false, Image.FORMAT_RGBA8)

	for i in range(shots.size()):
		sheet.blit_rect(shots[i], Rect2i(0, 0, SHOT.x, SHOT.y), Vector2i((i % 4) * SHOT.x, (i / 4) * SHOT.y))

	sheet.save_png(_out + "/hands_and_faces.png")
	print("done")
	quit()


func _grab(viewport: SubViewport) -> Image:
	var im: Image = viewport.get_texture().get_image()
	im.convert(Image.FORMAT_RGBA8)
	return im
