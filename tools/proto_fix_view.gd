extends SceneTree

# PROTOTYPE (Sonny, 30 Oct 2026): close pictures of the default body's head, boots and sleeve cuffs from the front, three-quarter, side and back, and the head with other hair colours,
# lengths and body types. Needs a window.
#   godot --path . --resolution 1920x1080 --script res://tools/proto_fix_view.gd -- --out=res://art/character_proto/fixes --tag=before

const GeneratedBody := preload("res://src/client/character/generated_body.gd")
const Generator := preload("res://src/client/character/body_generator.gd")
const SHOT := Vector2i(380, 380)
const YAWS := [180.0, 150.0, 90.0, 0.0]        # front, three-quarter, side, back

var _out: String = "res://art/character_proto/fixes"
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


func _shot(body: Node3D, yaw: float, target: Vector3, dist: float) -> Image:
	body.rotation_degrees.y = yaw
	_cam.look_at_from_position(target + Vector3(0.0, 0.0, dist), target)
	await _frames()
	var im: Image = _viewport.get_texture().get_image()
	im.convert(Image.FORMAT_RGBA8)
	return im


func _sheet(rows: Array, name: String) -> void:
	var sheet: Image = Image.create(SHOT.x * YAWS.size(), SHOT.y * rows.size(), false, Image.FORMAT_RGBA8)

	for r in range(rows.size()):
		for c in range(YAWS.size()):
			sheet.blit_rect(rows[r][c], Rect2i(0, 0, SHOT.x, SHOT.y), Vector2i(c * SHOT.x, r * SHOT.y))

	sheet.save_png(ProjectSettings.globalize_path("%s/%s_%s.png" % [_out, _tag, name]))


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
	_cam.fov = 30.0
	_viewport.add_child(_cam)
	var body: Node3D = GeneratedBody.new(Generator.make_genome("average"), 0.035, true)
	_viewport.add_child(body)
	await _frames(3)
	var head_y: float = 1.62
	var rows: Array = []

	for spec in [[Vector3(0.0, head_y, 0.0), 1.0], [Vector3(0.0, 0.1, 0.0), 1.1], [Vector3(0.0, 1.3, 0.0), 1.7]]:
		var row: Array = []

		for yaw in YAWS:
			row.append(await _shot(body, yaw, spec[0], spec[1]))

		rows.append(row)

	_sheet(rows, "head_boots_cuffs")
	body.queue_free()
	await _frames(2)
	# The head with other hair colours, lengths and body types (three-quarter and top-front views).
	var variants: Array = []

	for preset in ["average", "broad", "lean", "stocky"]:
		for length in [-1.0, 0.0, 1.0]:
			variants.append([preset, length, Color(0.08, 0.06, 0.05) if length < 0.0 else (Color(0.7, 0.55, 0.25) if length > 0.0 else Color(0.25, 0.16, 0.09))])

	var vrows: Array = []

	for v in variants:
		var g: Dictionary = Generator.make_genome(v[0], Color(0.82, 0.62, 0.48), v[2])
		g["hair_length"] = v[1]
		var b: Node3D = GeneratedBody.new(g, 0.035, false)
		_viewport.add_child(b)
		await _frames(2)
		var row: Array = []

		for yaw in YAWS:
			row.append(await _shot(b, yaw, Vector3(0.0, head_y + (0.05 if v[0] == "lean" else (-0.1 if v[0] == "stocky" else 0.0)), 0.0), 1.0))

		vrows.append(row)
		b.queue_free()
		await _frames(2)

	_sheet(vrows.slice(0, 6), "hair_a")
	_sheet(vrows.slice(6, 12), "hair_b")
	quit(0)
