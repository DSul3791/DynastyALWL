extends SceneTree

# A gallery of animal models (Kathleen): every species standing on a ground plane in a grid, side view, name under each, one picture. Offline, the real meshes (src/client/animal_view.gd), a sun and a sky:
# brighter than the game, so metal and pale things read lighter than in play.
#   godot --path . --script res://tools/animal_gallery.gd -- --items=rabbit,fox,deer,boar,grouse --out=C:/temp/animals.png [--cols=4] [--pitch=-12] [--cell=2.4] [--px=400]

const AnimalView := preload("res://src/client/animal_view.gd")


func _init() -> void:
	var ids: PackedStringArray = PackedStringArray()
	var out: String = "user://item_sheet.png"
	var cols: int = 4
	var pitch: float = -12.0
	var cell: float = 2.4
	var px: int = 400

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--items="):
			ids = a.trim_prefix("--items=").split(",", false)
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--cols="):
			cols = int(a.trim_prefix("--cols="))
		elif a.begins_with("--pitch="):
			pitch = float(a.trim_prefix("--pitch="))
		elif a.begins_with("--cell="):
			cell = float(a.trim_prefix("--cell="))
		elif a.begins_with("--px="):
			px = int(a.trim_prefix("--px="))

	var rows: int = int(ceil(float(ids.size()) / float(cols)))
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(cols * px, rows * px)
	vp.own_world_3d = true
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.78, 0.92)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.66)
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	vp.add_child(sun)
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(float(cols) * cell + 2.0, float(rows) * cell + 2.0)
	var gm: StandardMaterial3D = StandardMaterial3D.new()
	gm.albedo_color = Color(0.34, 0.44, 0.24)
	plane.material = gm
	ground.mesh = plane
	vp.add_child(ground)
	var view: Node3D = AnimalView.new()

	for n in ids.size():
		var model: Node3D = null

		match ids[n]:
			"rabbit": model = view._make_rabbit()
			"wolf": model = view._make_wolf()
			"fox": model = view._make_fox()
			"deer": model = view._make_deer(0)
			"moose": model = view._make_moose(0)
			"horse": model = view._make_horse(0)
			"duck": model = view._make_flock(0)
			"boar": model = view._make_boar()
			"songbird": model = view._make_songbird()
			"frog": model = view._make_frog()
			"trout": model = view._make_fish()
			"grouse": model = view._make_grouse()
			"seal": model = view._make_seal()
			"gull": model = view._make_seabird()

		var cx: float = (float(n % cols) - float(cols - 1) * 0.5) * cell
		var cz: float = (float(n / cols) - float(rows - 1) * 0.5) * cell

		if model != null:
			model.position = Vector3(cx, 0.0, cz)
			model.rotation.y = -PI * 0.5      # the animal faces -Z: turned to face the left of the picture
			vp.add_child(model)

		var label: Label3D = Label3D.new()
		label.text = ids[n] if model != null else ids[n] + " (none)"
		label.font_size = 40
		label.pixel_size = cell / 700.0
		label.outline_size = 8
		label.modulate = Color(1, 1, 1)
		label.rotation_degrees = Vector3(-90, 0, 0)
		label.position = Vector3(cx, 0.01, cz + cell * 0.4)
		vp.add_child(label)

	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(float(rows) * cell * 1.05, float(cols) * cell * 0.5)
	cam.rotation_degrees = Vector3(pitch, 0.0, 0.0)      # looking along -Z from the south: the animals show their left side
	var tilt: float = deg_to_rad(absf(pitch))
	cam.position = Vector3(0.0, 0.7 + 14.0 * sin(tilt), 14.0 * cos(tilt))      # aimed at the middle of the grid, 0.7 m up
	vp.add_child(cam)
	root.add_child(vp)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await process_frame
	await process_frame
	await process_frame
	var image: Image = vp.get_texture().get_image()
	image.save_png(out)
	print("saved ", out, " ", ids.size(), " items")
	quit()
