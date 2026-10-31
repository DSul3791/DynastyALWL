extends SceneTree

# PROTOTYPE (Sonny, 30 Oct 2026): the feet from above and from the side (two Feet values and the default), then the whole body from above. Needs a window.
#   godot --path . --resolution 1920x1080 --script res://tools/proto_feet_view.gd -- --out=res://art/character_proto/feet --tag=after

const GeneratedBody := preload("res://src/client/character/generated_body.gd")
const Generator := preload("res://src/client/character/body_generator.gd")
const SHOT := Vector2i(360, 360)

var _out: String = "res://art/character_proto/feet"
var _tag: String = "after"
var _viewport: SubViewport
var _cam: Camera3D


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--tag="):
			_tag = arg.substr(6)

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
	env.background_color = Color(0.45, 0.4, 0.3)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.68)
	env.ambient_light_energy = 0.9
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	_viewport.add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 30.0
	_viewport.add_child(_cam)
	var rows: Array = []

	for feet in [-1.0, 0.0, 1.0]:
		var g: Dictionary = Generator.make_genome("average")
		g["feet"] = feet
		var body: Node3D = GeneratedBody.new(g, 0.03, true)
		_viewport.add_child(body)
		body.set_clothed(true)
		await _frames(3)
		var row: Array = []
		# From above (a little in front, like the game's top-down view), from the side, from the front.
		_cam.look_at_from_position(Vector3(0.0, 1.4, -0.35), Vector3(0.0, 0.0, -0.1), Vector3.UP)
		_cam.far = 20.0
		await _frames()
		row.append(_viewport.get_texture().get_image())
		_cam.look_at_from_position(Vector3(1.3, 0.2, 0.0), Vector3(0.0, 0.1, -0.05))
		await _frames()
		row.append(_viewport.get_texture().get_image())
		_cam.look_at_from_position(Vector3(0.0, 0.5, -1.3), Vector3(0.0, 0.1, 0.0))
		await _frames()
		row.append(_viewport.get_texture().get_image())
		rows.append(row)
		body.queue_free()
		await _frames(2)

	var sheet: Image = Image.create(SHOT.x * 3, SHOT.y * rows.size(), false, Image.FORMAT_RGBA8)

	for r in range(rows.size()):
		for c in range(3):
			var im: Image = rows[r][c]
			im.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(im, Rect2i(0, 0, SHOT.x, SHOT.y), Vector2i(c * SHOT.x, r * SHOT.y))

	sheet.save_png(ProjectSettings.globalize_path("%s/%s_feet.png" % [_out, _tag]))
	quit(0)
