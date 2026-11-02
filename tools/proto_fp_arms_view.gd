extends SceneTree

# PICTURE TOOL (Kathreen, 2 Nov 2026), bug 4 (first-person arms alignment). Shows what the first-person arms look like with no game running: Dave's arms (dynasty_arms.gd) placed under a camera
# exactly as held_item.gd places them (ArmsView.arms_transform with held_item.gd's constants), at rest and raised (arm_up 0 and 1), looking level and looking down 35 degrees, plus the old tube arms
# for comparison. Needs a window (not --headless).
#   godot --path . --resolution 1280x720 --script res://tools/proto_fp_arms_view.gd -- --out=res://art/CRITIQUES/arms_2026-11-02
# Saves <out>/<arms>_<pose>_<look>.png and prints one line per picture.

const ArmsView := preload("res://src/client/character/arms_view.gd")
const DynastyArms := preload("res://src/client/character/dynasty_arms.gd")
const Ragdoll := preload("res://src/client/ragdoll_body.gd")
# held_item.gd constants (keep in step with it)
const ARMS_POS := Vector3(0.0, -0.1, -0.15)
const ARMS_PITCH_DEG := 50.0
const REST_DOWN_M := 0.3
const REST_BACK_M := 0.05
const REST_PITCH_DEG := 50.0
const ARMS_SCALE := 0.85

var _out: String = "res://art/CRITIQUES/arms_2026-11-02"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)

	_run()


func _frames(count: int = 4) -> void:
	for _i in range(count):
		await process_frame

	await RenderingServer.frame_post_draw


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	root.size = Vector2i(1280, 720)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.6, 0.45)         # meadow green, so the arms are judged against grass
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.75)
	env.ambient_light_energy = 0.9
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	root.add_child(sun)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 75.0
	cam.current = true
	root.add_child(cam)

	for kind in ["dynasty", "old"]:
		var arms: Node3D = DynastyArms.new() if kind == "dynasty" else Ragdoll.new(true)
		cam.add_child(arms)          # arms_transform returns a transform local to the camera, as held_item.gd uses it
		arms.play("idle")

		for pose in [["rest", 0.0], ["raised", 1.0]]:
			for look in [["level", 0.0], ["down35", -35.0]]:
				cam.global_transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(float(look[1]))), Vector3(0.0, 1.6, 0.0))
				arms.transform = ArmsView.arms_transform(cam.global_transform, cam.global_rotation.y, float(pose[1]), REST_PITCH_DEG, REST_DOWN_M, REST_BACK_M, ARMS_POS, ARMS_PITCH_DEG, ARMS_SCALE)
				await _frames()
				var im: Image = root.get_texture().get_image()
				im.convert(Image.FORMAT_RGBA8)
				var file: String = "%s_%s_%s" % [kind, pose[0], look[0]]
				im.save_png("%s/%s.png" % [_out, file])
				print("saved ", file)

		arms.queue_free()

	quit(0)
