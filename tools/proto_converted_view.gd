extends SceneTree

# PROTOTYPE (Sonny, 2026-10-30), plan 8: the OLD rig clips (converted by clip_converter.gd) played on generated bodies through the drop-in GeneratedBody.
#   godot --path . --resolution 320x240 --script res://tools/proto_converted_view.gd -- --out=res://art/character_proto/converted
# Needs a window. Rows: lean and stocky; columns: idle, walk, jog, run, crouch, swing (middle), jab (middle), throw (middle).

const GeneratedBody := preload("res://src/client/character/generated_body.gd")
const Generator := preload("res://src/client/character/body_generator.gd")
const SHOT := Vector2i(200, 330)

var _out: String = "res://art/character_proto/converted"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)

	_run()


func _frames() -> void:
	await process_frame
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
	env.background_color = Color(0.62, 0.72, 0.8)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.66)
	env.ambient_light_energy = 0.8
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	viewport.add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
	viewport.add_child(sun)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 28.0
	viewport.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 1.0, 6.2), Vector3(0.0, 1.0, 0.0))
	var clips: Array = [["idle", 0.4], ["walk", 0.25], ["jog", 0.25], ["run", 0.2], ["crouch", 0.5], ["swing", 0.5], ["jab", 0.5], ["throw", 0.45]]
	var shots: Array = []

	for preset in ["lean", "stocky"]:
		var body: Node3D = GeneratedBody.new(Generator.make_genome(preset), 0.04)
		viewport.add_child(body)
		body.rotation_degrees.y = 55.0
		await _frames()

		for entry in clips:
			body.play(entry[0], 1.0, 0.0)
			var player: AnimationPlayer = body.animation_player
			player.seek(float(entry[1]) * player.current_animation_length, true)
			player.pause()
			await _frames()
			var im: Image = viewport.get_texture().get_image()
			im.convert(Image.FORMAT_RGBA8)
			shots.append(im)

		body.queue_free()
		await _frames()

	var sheet: Image = Image.create(SHOT.x * clips.size(), SHOT.y * 2, false, Image.FORMAT_RGBA8)

	for i in range(shots.size()):
		sheet.blit_rect(shots[i], Rect2i(0, 0, SHOT.x, SHOT.y), Vector2i((i % clips.size()) * SHOT.x, (i / clips.size()) * SHOT.y))

	sheet.save_png(_out + "/old_clips_on_generated.png")
	print("done")
	quit()
