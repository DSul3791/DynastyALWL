extends SceneTree

# PROTOTYPE (Sonny, 31 Oct 2026): a frame strip of the third-person chop (axe) or pick_overhead clip on the generated body with a stand-in axe in the right hand, from the body's left
# side and from the front-left, at the phases of the swing; the impact frame is marked. Needs a window.
#   godot --path . --resolution 1920x1080 --script res://tools/proto_chop_view.gd -- --out=res://art/character_proto/chop --clip=chop

const GeneratedBody := preload("res://src/client/character/generated_body.gd")
const Generator := preload("res://src/client/character/body_generator.gd")
const Extra := preload("res://src/client/character/motion_extra.gd")
const SHOT := Vector2i(230, 330)

var _out: String = "res://art/character_proto/chop"
var _clip: String = "chop"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--clip="):
			_clip = arg.substr(7)

	_run()


func _frames(count: int = 3) -> void:
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
	env.background_color = Color(0.45, 0.5, 0.45)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.68)
	env.ambient_light_energy = 0.9
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	viewport.add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, -35.0, 0.0)
	viewport.add_child(sun)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 38.0
	viewport.add_child(cam)
	var body: Node3D = GeneratedBody.new(Generator.make_genome("average"), 0.035, false)
	viewport.add_child(body)
	_axe(body)
	var impact: float = Extra.CHOP_IMPACT_S if _clip == "chop" else Extra.PICK_IMPACT_S
	var length: float = Extra.CHOP_LENGTH if _clip == "chop" else Extra.PICK_LENGTH
	var times: Array = [0.0, 0.15, 0.30, 0.38, 0.45, impact, impact + 0.1, 0.75, 0.9]
	var views: Array = [Vector3(-3.0, 1.1, 0.0), Vector3(-2.2, 1.2, -2.2)]
	var sheet: Image = Image.create(SHOT.x * times.size(), SHOT.y * views.size(), false, Image.FORMAT_RGBA8)
	body.animation_player.play(_clip)
	body.animation_player.pause()

	for c in range(times.size()):
		body.animation_player.seek(minf(float(times[c]), length - 0.001), true)

		for r in range(views.size()):
			cam.look_at_from_position(views[r], Vector3(0.0, 0.95, 0.0))
			await _frames()
			var im: Image = viewport.get_texture().get_image()
			im.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(im, Rect2i(0, 0, SHOT.x, SHOT.y), Vector2i(c * SHOT.x, r * SHOT.y))

	sheet.save_png(ProjectSettings.globalize_path("%s/%s_strip.png" % [_out, _clip]))
	print("saved ", _clip, " impact at ", impact, " of ", length)
	quit(0)


# A stand-in axe (haft and head) in the right hand mount.
func _axe(body: Node3D) -> void:
	var haft: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.018
	cyl.bottom_radius = 0.022
	cyl.height = 0.8
	haft.mesh = cyl
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.38, 0.2)
	haft.material_override = wood
	haft.position = Vector3(0.0, 0.0, -0.3)
	haft.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	body.hand_mount_r.add_child(haft)
	var head: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.03, 0.14, 0.2)
	head.mesh = box
	var steel: StandardMaterial3D = StandardMaterial3D.new()
	steel.albedo_color = Color(0.6, 0.62, 0.66)
	head.material_override = steel
	head.position = Vector3(0.0, 0.0, -0.68)
	body.hand_mount_r.add_child(head)
