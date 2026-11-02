extends SceneTree

# PROTOTYPE (Sonny, 30 Oct 2026): the three body frames (feminine, masculine, neutral) from the front and the side, and the creator's About you section. Needs a window.
#   godot --path . --resolution 1920x1080 --script res://tools/proto_frames_view.gd -- --out=res://art/character_proto/frames

const GeneratedBody := preload("res://src/client/character/generated_body.gd")
const Logic := preload("res://src/client/character/creator_logic.gd")
const Creator := preload("res://scenes/creator_proto/creator_proto.tscn")
const SHOT := Vector2i(360, 600)

var _out: String = "res://art/character_proto/frames"


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
	cam.look_at_from_position(Vector3(0.0, 1.0, 5.4), Vector3(0.0, 0.92, 0.0))
	var shots: Array = []

	for frame in ["feminine", "masculine", "neutral"]:
		var logic: RefCounted = Logic.new({}, 1)
		logic.apply_frame(frame)
		var body: Node3D = GeneratedBody.new(logic.genome, 0.035, false)
		viewport.add_child(body)

		for yaw in [180.0, 90.0]:
			body.rotation_degrees.y = yaw
			await _frames()
			var im: Image = viewport.get_texture().get_image()
			im.convert(Image.FORMAT_RGBA8)
			shots.append(im)

		body.queue_free()
		await _frames(2)

	var sheet: Image = Image.create(SHOT.x * 2, SHOT.y * 3, false, Image.FORMAT_RGBA8)

	for i in range(shots.size()):
		sheet.blit_rect(shots[i], Rect2i(0, 0, SHOT.x, SHOT.y), Vector2i((i % 2) * SHOT.x, (i / 2) * SHOT.y))

	sheet.save_png(ProjectSettings.globalize_path(_out + "/frames_front_side.png"))
	viewport.queue_free()
	# The creator's About you section with a woman chosen.
	root.size = Vector2i(1920, 1080)
	var screen: Control = Creator.instantiate()
	root.add_child(screen)
	screen.turntable = false
	await _frames(10)
	screen.set_gender("woman")
	screen._name_field.text = "Wren Ash"
	screen._body.rotation_degrees.y = 180.0
	await _frames(40)
	var shot: Image = root.get_texture().get_image()
	shot.save_png(ProjectSettings.globalize_path(_out + "/creator_about_you.png"))
	print("done")
	quit(0)
