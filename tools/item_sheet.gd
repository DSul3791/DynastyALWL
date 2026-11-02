extends SceneTree

# A contact sheet of loose-item looks (Kathleen): every item lying on a ground plane in a grid, name under each, one picture. Offline, the real meshes (src/client/basic_look.gd), a sun and a sky:
# brighter than the game, so metal and pale things read lighter than in play.
#   godot --path . --script res://tools/item_sheet.gd -- --items=wheat,barley,carrot --out=C:/temp/sheet.png [--cols=6] [--pitch=-50] [--cell=0.5] [--px=300]
#   --items=all-overrides   every item in the ART_OVERRIDES table of basic_look.gd (the items drawn by hand)

const BasicLook := preload("res://src/client/basic_look.gd")


func _init() -> void:
	var ids: PackedStringArray = PackedStringArray()
	var out: String = "user://item_sheet.png"
	var cols: int = 6
	var pitch: float = -50.0
	var cell: float = 0.5
	var px: int = 300

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

	if ids.size() == 1 and ids[0] == "all-overrides":
		var src: String = FileAccess.get_file_as_string("res://src/client/basic_look.gd")
		var start: int = src.find("const ART_OVERRIDES")
		var finish: int = src.find("static func entry")
		var regex: RegEx = RegEx.new()
		regex.compile("\\t\"([a-z_0-9]+)\": \\{\"shape\"")
		ids = PackedStringArray()

		for m in regex.search_all(src.substr(start, finish - start)):
			ids.append(m.get_string(1))

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
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0

	for n in ids.size():
		var mesh: Mesh = BasicLook.mesh_for(ids[n])
		var cx: float = (float(n % cols) - float(cols - 1) * 0.5) * cell
		var cz: float = (float(n / cols) - float(rows - 1) * 0.5) * cell

		if mesh != null:
			var node: MeshInstance3D = MeshInstance3D.new()
			node.mesh = mesh
			node.material_override = material
			node.position = Vector3(cx, 0.06, cz)
			vp.add_child(node)

		var label: Label3D = Label3D.new()
		label.text = ids[n] if mesh != null else ids[n] + " (none)"
		label.font_size = 40
		label.pixel_size = cell / 600.0
		label.outline_size = 8
		label.modulate = Color(1, 1, 1)
		label.rotation_degrees = Vector3(-90, 0, 0)
		label.position = Vector3(cx, 0.01, cz + cell * 0.42)
		vp.add_child(label)

	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = float(rows) * cell / cos(deg_to_rad(absf(pitch) - 90.0)) if false else float(rows) * cell * 1.0
	cam.rotation_degrees = Vector3(-90.0, 0, 0)    # straight down: a flat contact sheet, each item seen from above
	cam.position = Vector3(0, 6, 0)
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
