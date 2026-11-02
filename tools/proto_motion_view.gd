extends SceneTree

# PROTOTYPE (Sonny, 2026-10-30), plan 5: renders strips of the prototype clips on generated bodies so a person can judge them.
#   godot --path . --resolution 320x240 --script res://tools/proto_motion_view.gd -- --out=res://art/character_proto/motion
# Needs a window. Rows: a walk (side view) and the stepped panic (three-quarter view) for a lean and a stocky body.

const Generator := preload("res://src/client/character/body_generator.gd")
const Motion := preload("res://src/client/character/motion_proto.gd")
const SHOT := Vector2i(220, 360)
const COLUMNS := 8

var _out: String = "res://art/character_proto/motion"


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
	var rows: Array = []
	var log_lines: PackedStringArray = PackedStringArray()

	for preset in ["lean", "stocky"]:
		var made: Dictionary = Generator.make_node(Generator.make_genome(preset), 0.04)
		var node: Node3D = made["node"]
		viewport.add_child(node)
		var skeleton: Skeleton3D = made["skeleton"]
		var parts: Dictionary = Motion.attach(node, skeleton)
		var tree: AnimationTree = parts["tree"]
		var head_y: float = float(((made["built"] as Dictionary)["rig"] as Dictionary)["dims"]["head_y"]) + 0.3
		cam.look_at_from_position(Vector3(0.0, head_y * 0.5, 6.0), Vector3(0.0, head_y * 0.5, 0.0))
		await _frames()
		# Walk: eight phases of one second, side view.
		tree["parameters/Loco/blend_position"] = 1.4
		node.rotation_degrees.y = 90.0
		var walk_row: Array = []

		for i in range(COLUMNS):
			tree.advance(1.0 / float(COLUMNS))
			await _frames()
			walk_row.append(_grab(viewport))

		rows.append(walk_row)
		# Panic over a standing idle: eight poses a twelfth of a second apart (the stepped clip), three-quarter view.
		tree["parameters/Loco/blend_position"] = 0.0
		node.rotation_degrees.y = -35.0
		tree.advance(0.5)
		tree["parameters/Shot/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
		var panic_row: Array = []

		for i in range(COLUMNS):
			tree.advance(1.0 / 12.0 * 1.5)
			await _frames()
			panic_row.append(_grab(viewport))

		rows.append(panic_row)
		log_lines.append("%s: walk and panic strips rendered" % preset)
		node.queue_free()
		await _frames()

	var sheet: Image = Image.create(SHOT.x * COLUMNS, SHOT.y * rows.size(), false, Image.FORMAT_RGBA8)

	for r in range(rows.size()):
		for c in range(COLUMNS):
			sheet.blit_rect(rows[r][c], Rect2i(0, 0, SHOT.x, SHOT.y), Vector2i(c * SHOT.x, r * SHOT.y))

	sheet.save_png(_out + "/strips.png")
	var file: FileAccess = FileAccess.open(_out + "/strips.txt", FileAccess.WRITE)
	file.store_string("rows: lean walk, lean panic, stocky walk, stocky panic\n" + "\n".join(log_lines) + "\n")
	file.close()
	print("done")
	quit()


func _grab(viewport: SubViewport) -> Image:
	var im: Image = viewport.get_texture().get_image()
	im.convert(Image.FORMAT_RGBA8)
	return im
