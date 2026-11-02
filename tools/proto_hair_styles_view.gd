extends SceneTree

# PROTOTYPE (Sonny, 30 Oct 2026): every hair style from the front, the side and the back (columns: the ten styles), at Hair Length 0 and +1. Needs a window.
#   godot --path . --resolution 1920x1080 --script res://tools/proto_hair_styles_view.gd -- --out=res://art/character_proto/hair_styles

const GeneratedBody := preload("res://src/client/character/generated_body.gd")
const Generator := preload("res://src/client/character/body_generator.gd")
const SHOT := Vector2i(200, 250)
const YAWS := [0.0, 90.0, 180.0]        # camera yaw: front, side, back

var _out: String = "res://art/character_proto/hair_styles"
var _viewport: SubViewport
var _cam: Camera3D


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)

	_run()


func _frames(count: int = 3) -> void:
	for _i in range(count):
		await process_frame

	await RenderingServer.frame_post_draw


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_viewport = SubViewport.new()
	_viewport.size = SHOT
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.24, 0.28)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.68)
	env.ambient_light_energy = 0.9
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
	_viewport.add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 24.0
	_viewport.add_child(_cam)

	for length in [0.0, 1.0]:
		var count: int = Generator.HAIR_STYLES.size()
		var sheet: Image = Image.create(SHOT.x * count, SHOT.y * YAWS.size(), false, Image.FORMAT_RGBA8)

		for style in range(count):
			var g: Dictionary = Generator.make_genome("average", Color(0.82, 0.62, 0.48), Color(0.35, 0.2, 0.1) if style % 2 == 0 else Color(0.72, 0.55, 0.25))
			g["hair_style"] = style
			g["hair_length"] = length
			var body: Node3D = GeneratedBody.new(g, 0.03, false)
			_viewport.add_child(body)
			await _frames(3)
			var head: Vector3 = Generator.rig(g)["global"][4]
			var target: Vector3 = head + Vector3(0.0, 0.1, 0.0)

			for row in range(YAWS.size()):
				var dir: Vector3 = Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, deg_to_rad(YAWS[row]))
				_cam.look_at_from_position(target + dir * 1.0, target)
				await _frames()
				var im: Image = _viewport.get_texture().get_image()
				im.convert(Image.FORMAT_RGBA8)
				sheet.blit_rect(im, Rect2i(0, 0, SHOT.x, SHOT.y), Vector2i(style * SHOT.x, row * SHOT.y))

			body.queue_free()
			await _frames(2)

		sheet.save_png(ProjectSettings.globalize_path("%s/styles_length_%s.png" % [_out, "plus1" if length > 0.5 else "0"]))

	quit(0)
