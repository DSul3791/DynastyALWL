extends SceneTree

# PROTOTYPE (Sonny, 2026-10-30), plan 12: the worn clothing pieces (src/client/worn_look.gd) on generated bodies. Needs a window.
#   godot --path . --resolution 320x240 --script res://tools/proto_worn_view.gd -- --out=res://art/character_proto/worn
# Columns: nothing, cloak + hood + boots, pack + leggings + mittens, grass skirt + sandals + quiver. Rows: lean (seen from the front-left) and stocky (seen from the back-left).

const GeneratedBody := preload("res://src/client/character/generated_body.gd")
const Generator := preload("res://src/client/character/body_generator.gd")
const WornLook := preload("res://src/client/worn_look.gd")
const SHOT := Vector2i(220, 360)

var _out: String = "res://art/character_proto/worn"


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
	env.ambient_light_color = Color(0.62, 0.64, 0.68)
	env.ambient_light_energy = 0.9
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
	var sets: Array = [[], ["hide_cloak", "hide_hood", "hide_boots"], ["backpack", "hide_leggings", "hide_mittens"], ["grass_skirt", "fibre_sandals", "quiver"]]
	var shots: Array = []

	for r in range(2):
		var body: Node3D = GeneratedBody.new(Generator.make_genome("lean" if r == 0 else "stocky"), 0.04)
		viewport.add_child(body)
		body.rotation_degrees.y = 35.0 if r == 0 else 145.0
		await _frames()

		for set in sets:
			WornLook.attach(body, set, false)
			await _frames()
			var im: Image = viewport.get_texture().get_image()
			im.convert(Image.FORMAT_RGBA8)
			shots.append(im)

		body.queue_free()
		await _frames()

	var sheet: Image = Image.create(SHOT.x * sets.size(), SHOT.y * 2, false, Image.FORMAT_RGBA8)

	for i in range(shots.size()):
		sheet.blit_rect(shots[i], Rect2i(0, 0, SHOT.x, SHOT.y), Vector2i((i % sets.size()) * SHOT.x, (i / sets.size()) * SHOT.y))

	sheet.save_png(_out + "/worn_on_generated_fitted.png")
	print("done")
	quit()
