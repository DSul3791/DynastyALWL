extends SceneTree

# PROTOTYPE (Sonny, 30 Oct 2026): the Shoulders slider at -1, 0 and +1 from the front (the rest of the body at its neutral values). Needs a window.
#   godot --path . --resolution 1920x1080 --script res://tools/proto_shoulders_view.gd -- --out=res://art/character_proto/shoulders

const GeneratedBody := preload("res://src/client/character/generated_body.gd")
const Generator := preload("res://src/client/character/body_generator.gd")
const SHOT := Vector2i(420, 560)

var _out: String = "res://art/character_proto/shoulders"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)

	_run()


func _frames(count: int = 4) -> void:
	for _i in range(count):
		await process_frame

	await RenderingServer.frame_post_draw


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var viewport: SubViewport = SubViewport.new()
	viewport.size = SHOT
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.24, 0.28)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.68)
	env.ambient_light_energy = 0.9
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	viewport.add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
	viewport.add_child(sun)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 30.0
	viewport.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 1.2, 3.6), Vector3(0.0, 1.2, 0.0))
	var sheet: Image = Image.create(SHOT.x * 3, SHOT.y, false, Image.FORMAT_RGBA8)
	var col: int = 0

	for s in [-1.0, 0.0, 1.0]:
		var g: Dictionary = Generator.make_genome("average")
		g["shoulders"] = s
		var body: Node3D = GeneratedBody.new(g, 0.035, false)
		body.rotation_degrees.y = 180.0
		viewport.add_child(body)
		await _frames()
		var im: Image = viewport.get_texture().get_image()
		im.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(im, Rect2i(0, 0, SHOT.x, SHOT.y), Vector2i(col * SHOT.x, 0))
		col += 1
		body.queue_free()
		await _frames(2)

	sheet.save_png(ProjectSettings.globalize_path(_out + "/shoulders_minus1_0_plus1.png"))
	quit(0)
