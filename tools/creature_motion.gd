extends SceneTree

# Creature motion strips (MikeW, 8 Nov 2026): the game's own animal view (src/client/animal_view.gd) driven by made-up server rows,
# so the client layers that only run in play show in pictures: tails, ears, breathing, head tracking, herd facing and looking up
# together, sleep, the wet look, eye shine and the hop arc. One picture per kind: N frames side by side, `--every` seconds apart.
# Needs a window (pictures): run without --headless.
#   godot --path . --script res://tools/creature_motion.gd -- --kinds=dog,deer --out=E:/Software/godotDev/creature_motion
#       [--state=0] [--speed=0] [--count=1] [--hour=12] [--season=summer] [--frames=6] [--every=0.25] [--cam=6]
#       [--approach]   the camera walks in from 30 m to 6 m over the frames (head tracking, herd glances, ears)
#       [--water=0.4]  water this deep over the ground everywhere (swim role, wet look)
#       [--torch]      a held torch at the camera, night sky (eye shine)
#       [--fx] [--tilt] [--prints] [--ik] turn on the footfall puffs and the slope pitch (FOOTFALL.md)
# A picture is saved per kind as <out>/motion_<kind>_<state>.png, and a line per frame says what the view did (sleep, look weight).

const AnimalView := preload("res://src/client/animal_view.gd")


func _init() -> void:
	var opts: Dictionary = {"kinds": "deer", "out": "user://creature_motion", "state": 0, "speed": 0.0, "count": 1, "hour": 12.0, "season": "summer", "frames": 6, "every": 0.25, "cam": 6.0, "approach": false, "water": -1.0, "torch": false, "fx": false, "tilt": false, "prints": false, "ik": false}

	for a in OS.get_cmdline_user_args():
		var key: String = a.trim_prefix("--").get_slice("=", 0)
		var val: String = a.get_slice("=", 1) if a.contains("=") else "true"

		if opts.has(key):
			opts[key] = val if opts[key] is String else (val == "true" if opts[key] is bool else (int(val) if opts[key] is int else float(val)))

	DirAccess.make_dir_recursive_absolute(str(opts["out"]))

	for kind in str(opts["kinds"]).split(",", false):
		await _strip(kind, opts)

	quit()


func _strip(kind: String, opts: Dictionary) -> void:
	var number: Variant = AnimalView.KIND_OF_SPECIES.find_key(kind)

	if number == null:
		print("creature_motion: no species ", kind)
		return

	var px: int = 480
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(px, px)
	vp.own_world_3d = true
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	var night: bool = bool(opts["torch"])
	env.background_color = Color(0.03, 0.04, 0.07) if night else Color(0.62, 0.78, 0.92)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.05, 0.05, 0.08) if night else Color(0.6, 0.62, 0.66)
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	if not night:
		var sun: DirectionalLight3D = DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-50, 30, 0)
		sun.shadow_enabled = true
		vp.add_child(sun)

	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(80, 80)
	var gm: StandardMaterial3D = StandardMaterial3D.new()
	gm.albedo_color = Color(0.34, 0.44, 0.24)
	plane.material = gm
	ground.mesh = plane
	vp.add_child(ground)
	var water_d: float = float(opts["water"])

	if water_d > 0.0:
		var sheet: MeshInstance3D = MeshInstance3D.new()
		var wp: PlaneMesh = PlaneMesh.new()
		wp.size = Vector2(80, 80)
		var wm: StandardMaterial3D = StandardMaterial3D.new()
		wm.albedo_color = Color(0.2, 0.35, 0.45, 0.6)
		wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wp.material = wm
		sheet.mesh = wp
		sheet.position.y = water_d
		vp.add_child(sheet)

	var view: Node3D = AnimalView.new()
	view.footfall_fx = bool(opts["fx"])
	view.slope_tilt = bool(opts["tilt"])
	view.prints_fx = bool(opts["prints"])
	view.foot_ik = bool(opts["ik"])
	view.ground_height = func(x: float, _z: float) -> float: return 0.15 if x > 0.3 else 0.0      # --ik: a 15 cm step under the right-hand feet
	view.conditions_now = func() -> Dictionary: return {"hour": float(opts["hour"]), "season": str(opts["season"])}

	if water_d > 0.0:
		view.water_level = func(_x: float, _z: float) -> float: return water_d

	var cam: Camera3D = Camera3D.new()
	cam.fov = 50.0
	vp.add_child(cam)
	vp.add_child(view)
	var torch: OmniLight3D = null

	if night:
		torch = OmniLight3D.new()
		torch.omni_range = 9.0
		torch.light_color = Color(1.0, 0.65, 0.3)
		torch.light_energy = 2.0
		vp.add_child(torch)
		view.torch_light = func() -> Array: return [torch.global_position, torch.omni_range]

	root.add_child(vp)
	var count: int = int(opts["count"])
	var speed: float = float(opts["speed"])
	var frames: Array = []
	var t: float = 0.0
	var step: float = 1.0 / 30.0
	var total: float = float(opts["frames"]) * float(opts["every"]) + 2.0      # 2 s to settle first
	var next_shot: float = 2.0

	while t <= total:
		var rows: Array = []

		for i in count:
			var at: Vector3 = Vector3(float(i % 3) * 2.5 - 2.5, max(water_d - 0.25, 0.0) if water_d > 0.0 else 0.0, float(int(i / 3.0)) * 2.5 + speed * t)
			rows.append([1000 + i, int(number), at, PI * 0.5, int(opts["state"])])      # heading pi/2: the animal walks toward +Z

		view.on_rows(rows)
		var dist: float = float(opts["cam"])

		if bool(opts["approach"]):
			dist = lerpf(30.0, 6.0, clampf((t - 2.0) / maxf(total - 2.0, 0.01), 0.0, 1.0))

		var focus: Vector3 = Vector3(0.0, 0.6, speed * t)
		cam.global_position = focus + Vector3(dist, 1.2, 0.0)
		cam.look_at(focus, Vector3.UP)

		if torch != null:
			torch.global_position = cam.global_position + Vector3(0.0, -0.3, 0.0)

		await process_frame
		t += step

		if t >= next_shot and frames.size() < int(opts["frames"]):
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			await process_frame
			frames.append(vp.get_texture().get_image())
			var b: Dictionary = view._bodies.get(1000, {})
			print("frame %d t %.2f: asleep %s, look_left %.1f, herd_bias %.2f, wet %.2f" % [frames.size(), t, str(b.get("asleep", false)), float(b.get("look_left", 0.0)), float(b.get("herd_bias", 0.0)), float(b.get("wet", 0.0))])
			next_shot += float(opts["every"])

	if not frames.is_empty():
		var sheet_img: Image = Image.create(px * frames.size(), px, false, (frames[0] as Image).get_format())

		for i in frames.size():
			sheet_img.blit_rect(frames[i], Rect2i(0, 0, px, px), Vector2i(i * px, 0))

		var path: String = "%s/motion_%s_%d.png" % [str(opts["out"]), kind, int(opts["state"])]
		sheet_img.save_png(path)
		print("creature_motion: saved ", path)

	vp.queue_free()
	await process_frame
