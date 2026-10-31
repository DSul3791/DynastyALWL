extends SceneTree

# PROTOTYPE (Sonny, 30 Oct 2026): close pictures of the arm, wrist and hand from the front, three-quarter, side and back at several Arms, Hands, Muscle and Shoulders values,
# plus the clips idle, walk and carry. Needs a window.
#   godot --path . --resolution 1920x1080 --script res://tools/proto_arm_view.gd -- --out=res://art/character_proto/arms --tag=before

const GeneratedBody := preload("res://src/client/character/generated_body.gd")
const Generator := preload("res://src/client/character/body_generator.gd")
const SHOT := Vector2i(300, 420)
const YAWS := [0.0, 35.0, 90.0, 180.0]        # camera yaw around the arm: front, three-quarter, side (from outside), back

var _out: String = "res://art/character_proto/arms"
var _tag: String = "before"
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


func _shot(_body: Node3D, yaw: float, target: Vector3, dist: float) -> Image:
	var dir: Vector3 = Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, deg_to_rad(yaw))       # the body faces -z, so the front view is from -z
	_cam.look_at_from_position(target + dir * dist, target)
	await _frames()
	var im: Image = _viewport.get_texture().get_image()
	im.convert(Image.FORMAT_RGBA8)
	return im


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
	var variants: Array = [
		["default", {}], ["arms-1", {"arms": -1.0}], ["arms+1", {"arms": 1.0}], ["hands-1", {"hands": -1.0}], ["hands+1", {"hands": 1.0}],
		["muscle-1", {"muscle": -1.0}], ["muscle+1", {"muscle": 1.0}], ["shoulders+1", {"shoulders": 1.0}], ["shoulders-1", {"shoulders": -1.0}],
	]
	var rows: Array = []

	for v in variants:
		var g: Dictionary = Generator.make_genome("average")

		for key in v[1]:
			g[key] = v[1][key]

		var body: Node3D = GeneratedBody.new(g, 0.03, true)
		_viewport.add_child(body)
		await _frames(3)
		var rg: Dictionary = Generator.rig(g)
		var hand: Vector3 = rg["global"][8]
		var elbow: Vector3 = rg["global"][7]
		var shoulder: Vector3 = rg["global"][6]
		var centre: Vector3 = (elbow + hand) * 0.5 + Vector3(0.0, -0.05, 0.0)       # the left forearm and hand (the body's left is -x)
		var row: Array = []

		for yaw in YAWS:
			row.append(await _shot(body, yaw if shoulder.x < 0.0 else -yaw, centre, 1.15))

		rows.append(row)
		body.queue_free()
		await _frames(2)

	var sheet: Image = Image.create(SHOT.x * YAWS.size(), SHOT.y * rows.size(), false, Image.FORMAT_RGBA8)

	for r in range(rows.size()):
		for c in range(YAWS.size()):
			sheet.blit_rect(rows[r][c], Rect2i(0, 0, SHOT.x, SHOT.y), Vector2i(c * SHOT.x, r * SHOT.y))

	sheet.save_png(ProjectSettings.globalize_path("%s/%s_arms.png" % [_out, _tag]))
	quit(0)
