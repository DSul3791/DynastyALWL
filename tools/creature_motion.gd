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
#       [--fx] [--tilt] [--prints] [--ik] [--stalk] [--coats] [--dust] [--ruffle] [--young=2 --age=3 --follow] [--wlife (with --water=1.2 to swim) --bank (water ahead: drinking)] [--wind=0.8] turn on the footfall puffs and the slope pitch (FOOTFALL.md)
# A picture is saved per kind as <out>/motion_<kind>_<state>.png, and a line per frame says what the view did (sleep, look weight).

const AnimalView := preload("res://src/client/animal_view.gd")


func _init() -> void:
	var opts: Dictionary = {"kinds": "deer", "out": "user://creature_motion", "state": 0, "speed": 0.0, "count": 1, "hour": 12.0, "season": "summer", "frames": 6, "every": 0.25, "cam": 6.0, "approach": false, "water": -1.0, "torch": false, "fx": false, "tilt": false, "prints": false, "ik": false, "stalk": false, "coats": false, "dust": false, "ruffle": false, "young": 0, "age": -1.0, "follow": false, "wlife": false, "bank": false, "idles": false, "turn": 0.0, "roll": false, "storm": false, "foe": false, "shine": false, "moon": false, "sign": "", "wx": "", "hit": "", "kill": false, "windlooks": false, "fog": 0.0, "cave": "", "drink": false, "ice": false, "thunder": 0.0, "cover": false, "birdrig": false, "posed": false, "swimrig": false, "wind": 0.0}

	for a in OS.get_cmdline_user_args():
		var key: String = a.trim_prefix("--").get_slice("=", 0)
		var val: String = a.get_slice("=", 1) if a.contains("=") else "true"

		if opts.has(key):
			if opts[key] is String:
				opts[key] = val
			elif opts[key] is bool:
				opts[key] = val == "true"
			elif opts[key] is int:
				opts[key] = int(val)
			else:
				opts[key] = float(val)

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
	view.stalk_fx = bool(opts["stalk"])
	view.season_coats = bool(opts["coats"])
	view.coat_dust = bool(opts["dust"])
	view.coat_ruffle = bool(opts["ruffle"])
	view.young_gait = int(opts["young"]) > 0
	view.young_age_days = float(opts["age"])
	view.young_follow = bool(opts["follow"])
	view.water_life = bool(opts["wlife"]) or bool(opts["bank"])
	view.idle_variety = bool(opts["idles"])
	view.flight_bank = float(opts["turn"]) != 0.0 or bool(opts["roll"])
	view.look_at_foe = bool(opts["foe"])
	view.idle_first_s = 1.0 if bool(opts["idles"]) or bool(opts["follow"]) else -1.0
	view.wind_now = func() -> float: return float(opts["wind"])
	view.ground_height = func(x: float, _z: float) -> float: return 0.15 if x > 0.3 else 0.0      # --ik: a 15 cm step under the right-hand feet
	view.conditions_now = func() -> Dictionary: return {"hour": float(opts["hour"]), "season": str(opts["season"]), "storm_ahead": 1.0 if bool(opts["storm"]) else 0.0, "ground_snow": 1.0 if str(opts["sign"]) == "snow" else 0.0, "ice_cover": 1.0 if bool(opts["ice"]) else 0.0}
	view.animal_sign = str(opts["sign"]) != ""
	view.weather_looks = str(opts["wx"]) != "" and not bool(opts["windlooks"])
	view.wind_looks = bool(opts["windlooks"])
	view.fog_looks = float(opts["fog"]) > 0.0
	view.cave_air = str(opts["cave"]) != ""
	view.drink_looks = bool(opts["drink"])
	view.ice_looks = bool(opts["ice"])
	view.storm_looks = float(opts["thunder"]) > 0.0
	var claps: Array = [0]
	view.thunder_count = func() -> int: return claps[0]

	if str(opts["cave"]) != "":
		view.cave_c_at = func(_p: Vector3) -> float: return float(opts["cave"])

	if float(opts["fog"]) > 0.0:
		env.fog_enabled = true
		env.fog_density = 3.0 / float(opts["fog"])
		env.fog_light_color = Color(0.75, 0.78, 0.8)
		view.fog_now = func() -> Dictionary: return {"visibility_m": float(opts["fog"]), "mist": 0.8}
	view.cover_still = bool(opts["cover"])
	view.bird_rig = bool(opts["birdrig"])
	view.swim_rig = bool(opts["swimrig"])
	view.posed_flight_all = bool(opts["posed"])
	var wx_start: int = Time.get_ticks_msec()
	view.weather_now = func() -> Dictionary:      # --wx: gale from +X, cold -12 C, rain that stops after 2 s, snow falling
		var w: String = str(opts["wx"])
		return {"wind": 0.9 if w == "gale" else (0.5 if w == "windrain" else (0.3 if w == "breeze" else 0.1)), "wind_dir": 0.0, "temp_c": -12.0 if w == "cold" or w == "snowbed" else 10.0,
			"rain": (0.8 if Time.get_ticks_msec() - wx_start < 2000 else 0.0) if w == "stoprain" else (0.6 if w == "windrain" else 0.0), "snow": 0.8 if w == "snowbed" else 0.0}
	view.soil_at = func(_p: Vector3) -> String: return str(opts["sign"]) if str(opts["sign"]) != "snow" else "grass"

	if water_d > 0.0:
		view.water_level = func(_x: float, _z: float) -> float: return water_d

	if bool(opts["bank"]):      # --bank: water starts 0.6 m ahead of the animal (it faces +Z), 5 cm deep: it drinks
		view.water_level = func(_x: float, z: float) -> float: return 0.05 if z > 0.6 else NAN

	var cam: Camera3D = Camera3D.new()
	cam.fov = 50.0
	vp.add_child(cam)
	view.eye_shine = bool(opts["shine"])

	if bool(opts["shine"]):
		view.night_light = func() -> Dictionary: return {"night": 1.0, "moon": 1.0 if bool(opts["moon"]) else 0.0, "moon_to": (cam.global_position - Vector3(0.0, 0.6, 0.0)).normalized()}
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
			var at: Vector3 = Vector3(float(i % 3) * 2.5 - 2.5, max(water_d - 0.25, 0.0) if water_d > 0.0 and not bool(opts["wlife"]) else 0.0, float(int(i / 3.0)) * 2.5 + speed * t)
			rows.append([1000 + i, int(number), at, PI * 0.5 + float(opts["turn"]) * t, int(opts["state"])])

			if bool(opts["foe"]):      # --foe: the server's foe position, 4 m to the animal's left (a dog it warns)
				rows[-1].append(at + Vector3(4.0, 0.0, 1.0))      # heading pi/2: the animal walks toward +Z (--turn: turning)

		for i in int(opts["young"]):      # --young: young ones (species + 100) 1.5 m behind and beside the first animal
			var at: Vector3 = Vector3(-2.5 + (1.2 if i % 2 == 0 else -1.2), 0.0, speed * t - 1.5 - float(i / 2.0))
			rows.append([2000 + i, int(number) + AnimalView.YOUNG_NUM, at, PI * 0.5, int(opts["state"])])

		if str(opts["hit"]) != "" and t >= 2.0 and t < 2.0 + step:      # --hit: one hit on the first animal at that zone, damage 60% of a deer
			view.hunt_feedback = true
			var hz: Dictionary = {"head": Vector3(0.0, 0.9, 0.9), "chest": Vector3(0.0, 0.7, 0.3), "hip": Vector3(0.0, 0.7, -0.8), "leg": Vector3(0.0, 0.15, 0.0)}      # the animal faces +Z
			view.note_hit(rows[0][2] + hz.get(str(opts["hit"]), Vector3(0.0, 0.7, 0.0)), 12)

		if bool(opts["kill"]) and t >= 3.0:      # --kill: the hit animal leaves the rows, so it falls
			rows.remove_at(0)

		if float(opts["thunder"]) > 0.0 and t >= float(opts["thunder"]) and t < float(opts["thunder"]) + step:      # --thunder: one clap heard then
			claps[0] += 1

		view.on_rows(rows)

		if bool(opts["roll"]) and fposmod(t, 2.0) < step:      # --roll: the server's raven roll event every 2 s (half, then full)
			view.play_roll(1000, 0.5 if fposmod(t, 4.0) < 2.0 else 1.0)
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
