extends SceneTree

# Playthrough animal sheet: every live animal as the client draws it (animal_view.gd's own builders), on a plain ground, name under each,
# from the side and from three quarters in front.  godot --path . --script res://art/playthrough/animal_sheet.gd -- --out=art/playthrough/animals

const AnimalView := preload("res://src/client/animal_view.gd")
const W := 1800
const H := 800

var vp: SubViewport
var cam: Camera3D
var stage: Node3D


func _init() -> void:
	var out_dir: String = "art/playthrough/animals"

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://") + out_dir)
	vp = SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.78, 0.92)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.75)
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 40, 0)
	sun.shadow_enabled = true
	vp.add_child(sun)
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(80, 80)
	var gm: StandardMaterial3D = StandardMaterial3D.new()
	gm.albedo_color = Color(0.36, 0.46, 0.26)
	plane.material = gm
	ground.mesh = plane
	vp.add_child(ground)
	stage = Node3D.new()
	vp.add_child(stage)
	cam = Camera3D.new()
	cam.fov = 35.0
	vp.add_child(cam)
	root.add_child(vp)
	await process_frame
	var view = AnimalView.new()
	vp.add_child(view)
	var list: Array = [["rabbit", view._make_rabbit()], ["fox", view._make_fox()], ["deer", view._make_deer(0)], ["deer (id 1)", view._make_deer(1)], ["moose", view._make_moose(1)], ["horse", view._make_horse(1)], ["wolf", view._make_wolf()], ["duck flock", view._make_flock(1)]]
	var gap: float = 3.4
	var report: Array = []

	for n in range(list.size()):
		var node: Node3D = list[n][1]
		node.position = Vector3((float(n) - float(list.size() - 1) * 0.5) * gap, 0.0, 0.0)
		stage.add_child(node)
		var l: Label3D = Label3D.new()
		l.text = str(list[n][0])
		l.font_size = 40
		l.pixel_size = 0.005
		l.no_depth_test = true
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.outline_size = 12
		l.position = Vector3(node.position.x, -0.15, 1.4)
		stage.add_child(l)
		report.append(str(list[n][0]))

	await create_timer(0.5).timeout

	for view_name in ["side", "front34"]:
		var yaw: float = 0.0 if view_name == "side" else 40.0
		cam.rotation_degrees = Vector3(-14.0, yaw, 0.0)
		cam.position = Vector3(0.0, 1.4, 0.0) + cam.transform.basis.z * 20.0
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await process_frame
		await process_frame
		await process_frame
		var img: Image = vp.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://") + out_dir + "/animals_" + view_name + ".png")

	print("animals: sheet saved ", report)
	quit()
