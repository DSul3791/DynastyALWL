extends SceneTree

# Photographs any generated model with the real renderer (your GPU, a window flashes up): builds `load(script).new()` (or an instance of a .tscn),
# stands it on a ground plane under sun and sky light, and saves four views (front, 3/4, side, back) in one PNG. Not the game lighting or tint,
# but the real mesh, vertex colours and skinning at rest pose; use tools/look_rig.sh for the true in-game look.
#
#   godot --path . --script res://tools/shot_node.gd -- --script=res://src/client/ragdoll_body.gd --out=C:/temp/body.png
#   godot --path . --script res://tools/shot_node.gd -- --scene=res://path/model.tscn --out=C:/temp/model.png
#   options: --play=walk   (ragdoll-style bodies: call node.play(name) and wait --wait=0.4 s, default 0.3)
#            --height=1.9  (frame this many metres, default: the model's AABB height)
#            --arg=true    (pass one constructor argument to the script, e.g. the first-person flag)
# Written by Kathleen (art) for Sonny's body prototype; the output size is 4 x 400 px wide.

const TILE := 400


func _init() -> void:
	var script_path: String = ""
	var scene_path: String = ""
	var out: String = "user://shot_node.png"
	var play: String = ""
	var wait_s: float = 0.3
	var height: float = 0.0
	var ctor_arg: String = ""

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--script="):
			script_path = a.trim_prefix("--script=")
		elif a.begins_with("--scene="):
			scene_path = a.trim_prefix("--scene=")
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--play="):
			play = a.trim_prefix("--play=")
		elif a.begins_with("--wait="):
			wait_s = float(a.trim_prefix("--wait="))
		elif a.begins_with("--height="):
			height = float(a.trim_prefix("--height="))
		elif a.begins_with("--arg="):
			ctor_arg = a.trim_prefix("--arg=")

	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(TILE, TILE)
	vp.own_world_3d = true
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.78, 0.92)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.68)
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.shadow_enabled = true
	vp.add_child(sun)
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(30, 30)
	var gm: StandardMaterial3D = StandardMaterial3D.new()
	gm.albedo_color = Color(0.32, 0.42, 0.22)
	plane.material = gm
	ground.mesh = plane
	vp.add_child(ground)
	root.add_child(vp)

	var model: Node = null

	if script_path != "":
		var script: GDScript = load(script_path)
		model = script.new(ctor_arg == "true") if ctor_arg != "" else script.new()
	elif scene_path != "":
		model = (load(scene_path) as PackedScene).instantiate()

	if model == null:
		push_error("shot_node: nothing to build (--script= or --scene=)")
		quit(1)
		return

	vp.add_child(model)

	if play != "" and model.has_method("play"):
		model.call("play", play)

	await create_timer(wait_s).timeout
	var box: AABB = _aabb(model)
	var frame: float = height if height > 0.0 else maxf(box.size.y, 0.3)
	var centre: Vector3 = box.get_center() if box.size != Vector3.ZERO else Vector3(0, frame * 0.5, 0)
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = frame * 1.25
	vp.add_child(cam)
	var image: Image = Image.create(TILE * 4, TILE, false, Image.FORMAT_RGB8)
	var yaws: Array = [0.0, 40.0, 90.0, 180.0]   # the model faces -Z, so yaw 0 looks at its front from +Z

	for v in range(4):
		cam.rotation_degrees = Vector3(-8, yaws[v], 0)
		cam.position = centre + cam.transform.basis.z * 5.0
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await process_frame
		await process_frame
		var shot: Image = vp.get_texture().get_image()
		shot.convert(Image.FORMAT_RGB8)
		image.blit_rect(shot, Rect2i(0, 0, TILE, TILE), Vector2i(v * TILE, 0))

	image.save_png(out)
	print("saved ", out, " size ", box.size)
	quit()


func _aabb(node: Node) -> AABB:
	var result: AABB = AABB()
	var first: bool = true

	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = child
		var b: AABB = mi.global_transform * mi.get_aabb()
		result = b if first else result.merge(b)
		first = false

	return result
