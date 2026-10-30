extends SceneTree

# PROTOTYPE (Sonny, 2026-10-30): builds the generated bodies of src/client/character/body_generator.gd, times them and saves pictures.
#   godot --path . --script res://tools/proto_body.gd -- --out=res://art/character_proto
# Needs a window (it renders); it is not a headless test. Writes contact sheets and bench.txt. Not used by the game.

const Generator := preload("res://src/client/character/body_generator.gd")
const SHOT := Vector2i(300, 520)

var _out: String = "res://art/character_proto"
var _voxel: float = 0.03


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--voxel="):
			_voxel = float(arg.substr(8))

	_run()


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
	env.ambient_light_color = Color(0.55, 0.58, 0.62)
	env.ambient_light_energy = 0.8
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	viewport.add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
	sun.light_energy = 1.1
	viewport.add_child(sun)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 28.0
	viewport.add_child(cam)
	var bench: PackedStringArray = PackedStringArray()
	var sheets: Dictionary = {"rest": [], "bent": []}
	var presets: Array = ["average", "broad", "lean", "stocky"]
	var skins: Array = [Color(0.85, 0.66, 0.52), Color(0.62, 0.43, 0.3), Color(0.42, 0.28, 0.2), Color(0.93, 0.78, 0.66)]
	var hairs: Array = [Color(0.25, 0.16, 0.09), Color(0.08, 0.06, 0.05), Color(0.7, 0.55, 0.25), Color(0.55, 0.2, 0.1)]

	for i in range(presets.size()):
		var g: Dictionary = Generator.make_genome(presets[i], skins[i], hairs[i])
		var result: Dictionary = Generator.make_node(g, _voxel)
		var node: Node3D = result["node"]
		var built: Dictionary = result["built"]
		var ms: Dictionary = built["ms"]
		bench.append("%s: %d vertices, %d triangles, grid cells %s, ms rig+primitives %.1f field %.1f surface %.1f weights %.1f total %.1f" % [presets[i], built["vertex_count"], built["triangle_count"], str((built["grid"] as Vector3i).x), ms["rig_prims"], ms["field"], ms["surface"], ms["weights"], ms["total"]])
		print(bench[bench.size() - 1])
		if i == 0:
			_save_reload_test(node, bench)

		viewport.add_child(node)
		var height: float = float((built["rig"] as Dictionary)["dims"]["head_y"]) + 0.3
		cam.look_at_from_position(Vector3(0.0, height * 0.5, 6.2), Vector3(0.0, height * 0.5, 0.0))
		await _frames()
		(sheets["rest"] as Array).append(await _grab(viewport, node, 0.0))
		(sheets["rest"] as Array).append(await _grab(viewport, node, 90.0))
		_bend(result["skeleton"])
		await _frames()
		(sheets["bent"] as Array).append(await _grab(viewport, node, 0.0))
		(sheets["bent"] as Array).append(await _grab(viewport, node, 90.0))
		node.queue_free()
		await _frames()

	for key in sheets:
		var imgs: Array = sheets[key]
		# 8 pictures (4 bodies x front and side) in two rows of 4 pictures keep the sheet readable.
		var rows: Image = Image.create(SHOT.x * 4, SHOT.y * 2, false, Image.FORMAT_RGBA8)

		for k in range(imgs.size()):
			rows.blit_rect(imgs[k], Rect2i(0, 0, SHOT.x, SHOT.y), Vector2i((k % 4) * SHOT.x, (k / 4) * SHOT.y))

		rows.save_png("%s/proto_%s.png" % [_out, key])

	var file: FileAccess = FileAccess.open(_out + "/bench.txt", FileAccess.WRITE)
	file.store_string("\n".join(bench) + "\n")
	file.close()
	print("done")
	quit()


func _frames() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw


func _grab(viewport: SubViewport, node: Node3D, yaw_deg: float) -> Image:
	node.rotation_degrees.y = yaw_deg
	await _frames()
	var im: Image = viewport.get_texture().get_image()
	im.convert(Image.FORMAT_RGBA8)
	return im


# A test pose to see how the skin bends: arms up and elbows bent, knees bent, a head turn.
func _bend(skeleton: Skeleton3D) -> void:
	_pose(skeleton, "LeftUpperArm", Vector3(1.2, 0.0, -0.2))
	_pose(skeleton, "LeftLowerArm", Vector3(1.5, 0.0, 0.0))
	_pose(skeleton, "RightUpperArm", Vector3(0.6, 0.0, 0.9))
	_pose(skeleton, "RightLowerArm", Vector3(1.0, 0.0, 0.0))
	_pose(skeleton, "LeftUpperLeg", Vector3(0.9, 0.0, 0.0))
	_pose(skeleton, "LeftLowerLeg", Vector3(-1.3, 0.0, 0.0))
	_pose(skeleton, "RightUpperLeg", Vector3(-0.3, 0.0, 0.0))
	_pose(skeleton, "RightLowerLeg", Vector3(-0.5, 0.0, 0.0))
	_pose(skeleton, "Spine", Vector3(0.2, 0.0, 0.0))
	_pose(skeleton, "Head", Vector3(0.0, 0.5, 0.0))


func _pose(skeleton: Skeleton3D, bone: String, euler: Vector3) -> void:
	var idx: int = skeleton.find_bone(bone)
	skeleton.set_bone_pose_rotation(idx, Quaternion.from_euler(euler))


# Saves the generated body mesh and skin as a binary resource, loads it back and times both (plan 5.7.9: bake once, cache by genome).
func _save_reload_test(node: Node3D, bench: PackedStringArray) -> void:
	var body: MeshInstance3D = node.get_node("Skeleton3D/Body")
	var path: String = "user://proto_body_average.res"
	var t0: int = Time.get_ticks_usec()
	var err: int = ResourceSaver.save(body.mesh, path, ResourceSaver.FLAG_COMPRESS)
	var t1: int = Time.get_ticks_usec()
	var loaded: Mesh = load(path) as Mesh
	var t2: int = Time.get_ticks_usec()
	var same: bool = loaded != null and (loaded.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() == (body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var size: int = FileAccess.get_file_as_bytes(path).size() if FileAccess.file_exists(path) else -1
	bench.append("save/reload mesh: save err %d, %.1f ms, file %d bytes, load %.1f ms, same vertex count %s, skin bind count after reload not tested" % [err, float(t1 - t0) / 1000.0, size, float(t2 - t1) / 1000.0, str(same)])
	print(bench[bench.size() - 1])
