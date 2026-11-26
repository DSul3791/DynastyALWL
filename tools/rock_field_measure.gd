extends SceneTree

# Rocky ground measure (boulders plan stage 2, thread "Place rocks and boulders on mountains", 26 Nov 2026): how many rocks the client draws
# smoothly and what they cost the server, before the rock_fields numbers (data/items/boulders.json) are set for good. Low must hold (the
# slowest tester: quad core, 8 GB, GTX 1050). A measurement, not a pass or fail.
#
# Client: a flat 400 m ground, a camera at eye height turning a full circle, and 0 to 4,000 boulders drawn by the game's own boulder code
# (inventory_view.gd _show_boulder: mesh, rock material, hull collider) in a 100 m disc round it (the server sends rocks within 100 m).
# For each count: frame time mean, 95th and 99th percentile and worst, draw calls and objects drawn, at Low and at Medium, and the cost of
# adding one rock (what walking into a new rocky cell costs). Also 1,000 worked rocks (the crack overlay on every rock, as every rock had
# before this change) to show what the second pass costs.
# Server: 32 players 300 m apart on rocky ground above the treeline (the worst case: every cell rocky), at rock_fields density_scale 0, 1
# and 2: the rows laid, the slowest scatter tick while the cells are laid out, then the steady scatter tick (its walk of every loose row
# against every player) and the world sync.
#
# Run on Lane A only, from the lane clone, with a real renderer (not --headless), Dave's Godot and game closed:
#   C:\DynastyLane\godot\godot_lane_a.exe --path . --resolution 1920x1080 --script res://tools/rock_field_measure.gd -- --out=C:/DynastyLane/logs/rock_measure
# Options after --: --out=<folder> (rock_measure.txt there; default user://rock_measure), --part=client or --part=server (default both),
# --limit=<seconds> (default 600: the run stops itself, exit 2). Prints rock_measure: lines; exit 0 when it ran to the end.

const InventoryViewScript := preload("res://src/client/inventory_view.gd")
const LookSettings := preload("res://src/client/look_settings.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")

const COUNTS := [0, 250, 500, 1000, 2000, 4000]
const QUALITIES := [0, 1]                  # Low, Medium
const SHADOW_M := [0.0, 45.0]              # terrain_client QUALITY_SHADOW_M for those qualities
const FRAMES := 360                        # one full turn of the camera, a degree a frame
const WARM_FRAMES := 30
const DISC_M := 100.0
const WORKED_COUNT := 1000
const PLAYERS := 32
const PLAYER_GAP_M := 300.0
const DENSITIES := [0.0, 1.0, 2.0]
const STEADY_CALLS := 20

var lines: PackedStringArray = PackedStringArray()
var out_dir: String = "user://rock_measure"
var part: String = "both"
var limit_s: float = 600.0
var started_msec: int = 0


func say(text: String) -> void:
	print("rock_measure: " + text)
	lines.append(text)


func over_time() -> bool:
	return float(Time.get_ticks_msec() - started_msec) / 1000.0 > limit_s


func _initialize() -> void:
	started_msec = Time.get_ticks_msec()

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--part="):
			part = arg.trim_prefix("--part=")
		elif arg.begins_with("--limit="):
			limit_s = float(arg.trim_prefix("--limit="))

	say("start: Godot %s, renderer %s, GPU %s, CPU %s (%d threads), part %s" % [Engine.get_version_info()["string"], RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_name(), OS.get_processor_name(), OS.get_processor_count(), part])
	var ok: bool = true

	if part != "server":
		ok = await measure_client()

	if ok and part != "client":
		ok = measure_server()

	DirAccess.make_dir_recursive_absolute(out_dir)
	var file: FileAccess = FileAccess.open(out_dir.path_join("rock_measure.txt"), FileAccess.WRITE)

	if file != null:
		file.store_string("\n".join(lines) + "\n")
		file.close()

	say("done" if ok else "STOPPED: past the time limit of %.0f s" % limit_s)
	quit(0 if ok else 2)


# The client's draw cost of rocks, by count and quality.
func measure_client() -> bool:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = ProceduralSkyMaterial.new()
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = environment
	world.add_child(world_env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	world.add_child(sun)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(400.0, 400.0)
	floor_mesh.mesh = plane
	var floor_material: StandardMaterial3D = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.32, 0.36, 0.22)
	floor_mesh.material_override = floor_material
	world.add_child(floor_mesh)
	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(0.0, 1.7, 0.0)
	camera.far = 1000.0
	world.add_child(camera)
	camera.make_current()
	var holder: Node3D = Node3D.new()
	world.add_child(holder)
	var view = InventoryViewScript.new()
	view._root = holder
	view._queue_rock_hulls()

	while not view._hull_queue.is_empty():
		view._hull_step()

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 26112026
	var rows: Array = []

	for n in range(COUNTS[COUNTS.size() - 1]):
		var radius: float = lerpf(0.3, 1.5, pow(rng.randf(), 2.0))
		var at: Vector2 = Vector2(sqrt(rng.randf()) * DISC_M, 0.0).rotated(rng.randf() * TAU)

		if at.length() < 3.0:
			at = at.normalized() * 3.0 if at.length() > 0.01 else Vector2(3.0, 0.0)   # none on the camera

		var total: int = maxi(int(4.0 / 3.0 * PI * pow(radius, 3.0) * 0.85 * 2600.0 * 0.094), 1)
		rows.append([n + 1, 0, total, Vector3(at.x, 0.0, at.y), view.BOULDER_STATE, {"radius": radius, "yaw": rng.randf() * 360.0, "total": total, "ang": rng.randf()}])

	for quality in QUALITIES:
		LookSettings.apply(environment, sun, root, quality)
		sun.shadow_enabled = float(SHADOW_M[quality]) > 0.0
		sun.directional_shadow_max_distance = maxf(float(SHADOW_M[quality]), 1.0)
		var shown: int = 0

		for count in COUNTS:
			var add_usec: int = Time.get_ticks_usec()

			while shown < int(count):
				view._show_boulder(int(rows[shown][0]), rows[shown])
				shown += 1

			var add_ms: float = float(Time.get_ticks_usec() - add_usec) / 1000.0
			var frames: Array = await turn(camera)

			if frames.is_empty():
				return false

			say("client %s: %4d rocks: %s%s" % ["Low" if quality == 0 else "Medium", int(count), frame_text(frames), "" if quality != QUALITIES[0] or int(count) == 0 else "; added in %.1f ms" % add_ms])

		# The old look: every rock worked (the crack overlay on each), at WORKED_COUNT.
		while shown > WORKED_COUNT:
			shown -= 1
			drop_rock(view, int(rows[shown][0]))

		for n in range(shown):
			var worked: Array = rows[n].duplicate()
			worked[2] = int(rows[n][2]) - 1
			view._show_boulder(int(worked[0]), worked)

		var worked_frames: Array = await turn(camera)

		if worked_frames.is_empty():
			return false

		say("client %s: %4d rocks all worked (the crack overlay on each): %s" % ["Low" if quality == 0 else "Medium", WORKED_COUNT, frame_text(worked_frames)])

		while shown > 0:
			shown -= 1
			drop_rock(view, int(rows[shown][0]))

	# What adding one rock costs on its own (walking into new ground): 200 rocks, one at a time.
	var each: PackedFloat64Array = PackedFloat64Array()

	for n in range(200):
		var usec: int = Time.get_ticks_usec()
		view._show_boulder(int(rows[n][0]), rows[n])
		each.append(float(Time.get_ticks_usec() - usec) / 1000.0)

	each.sort()
	say("client: one rock added in %.3f ms on average, %.3f ms at the 99th percentile, %.3f ms at worst" % [mean(each), each[int(each.size() * 0.99) - 1], each[each.size() - 1]])
	world.queue_free()
	view.free()
	await process_frame
	return true


func drop_rock(view, id: int) -> void:
	if view._boulders.has(id):
		(view._boulders[id]["node"] as Node).queue_free()
		view._boulders.erase(id)


# Frame times in ms over a full turn of the camera, after a few warm-up frames; [] past the time limit.
func turn(camera: Camera3D) -> Array:
	for n in range(WARM_FRAMES):
		await process_frame

	var times: Array = []
	var draws: float = 0.0
	var objects: float = 0.0
	var last: int = Time.get_ticks_usec()

	for n in range(FRAMES):
		camera.rotation_degrees.y = float(n) * 360.0 / float(FRAMES)
		await process_frame
		var now: int = Time.get_ticks_usec()
		times.append(float(now - last) / 1000.0)
		last = now
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)

		if over_time():
			return []

	return [times, draws / float(FRAMES), objects / float(FRAMES)]


func frame_text(frames: Array) -> String:
	var times: Array = (frames[0] as Array).duplicate()
	times.sort()
	var sum: float = 0.0

	for t in times:
		sum += float(t)

	return "frame %.2f ms mean, %.2f p95, %.2f p99, %.2f worst; %.0f draw calls, %.0f objects" % [sum / float(times.size()), float(times[int(times.size() * 0.95) - 1]),
		float(times[int(times.size() * 0.99) - 1]), float(times[times.size() - 1]), float(frames[1]), float(frames[2])]


func mean(values: PackedFloat64Array) -> float:
	var sum: float = 0.0

	for v in values:
		sum += v

	return sum / float(maxi(values.size(), 1))


# The server's cost of rocky ground: PLAYERS players apart on ground above the treeline, at each density.
func measure_server() -> bool:
	for density in DENSITIES:
		var dir: String = "user://rock_measure_server"
		DirAccess.make_dir_recursive_absolute(dir)

		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + "/" + file)

		var items = ItemsScript.new()
		items.send_full = func(_p, _b): pass
		items.send_slots = func(_p, _b): pass
		items.send_world_items = func(_p, _a, _r): pass
		items.send_notice = func(_p, _t): pass
		items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
		items.setup(ItemTableScript.load_default(), dir)
		items.ground_height = func(x: float, z: float) -> float: return 700.0 + 3.0 * sin(x * 0.05) * cos(z * 0.04)
		items._boulder_cfg["rock_fields"]["density_scale"] = density

		for p in range(PLAYERS):
			var key: String = "rockmeasure%02d" % p
			items.peer_connected_hello(p + 1, key)
			items.report_position(p + 1, Vector3(float(p % 8) * PLAYER_GAP_M, 700.0, floorf(float(p) / 8.0) * PLAYER_GAP_M))

		var worst_ms: float = 0.0
		var ticks: int = 0
		var cells_before: int = -1

		while items._cells_done.size() != cells_before:
			cells_before = items._cells_done.size()
			var usec: int = Time.get_ticks_usec()
			items._scatter_around_players()
			worst_ms = maxf(worst_ms, float(Time.get_ticks_usec() - usec) / 1000.0)
			items._sync_world_items()   # as the server does after each scatter (its grid is what a cell's keep-clear lookup reads)
			ticks += 1

			if over_time():
				return false

		var rocks: int = 0
		var stones: int = 0

		for id in items._items:
			var it: Dictionary = items._items[id]

			if it.has("scatter") and (int(it["scatter"]) & items.FIELD_KEY) != 0:
				rocks += 1 if it.has("boulder") else 0
				stones += 0 if it.has("boulder") else 1

		var scatter_usec: int = Time.get_ticks_usec()

		for n in range(STEADY_CALLS):
			items._scatter_around_players()

		var scatter_ms: float = float(Time.get_ticks_usec() - scatter_usec) / 1000.0 / float(STEADY_CALLS)
		var sync_usec: int = Time.get_ticks_usec()

		for n in range(STEADY_CALLS):
			items._sync_world_items()

		var sync_ms: float = float(Time.get_ticks_usec() - sync_usec) / 1000.0 / float(STEADY_CALLS)
		say("server density %.1f: %d players, %d cells, %d records (%d rocky-ground rocks, %d of its loose stones, %.0f rocks a player); laying out: %d ticks, slowest %.1f ms; then a scatter tick %.2f ms, a world sync %.2f ms" % [
			density, PLAYERS, items._cells_done.size(), items._items.size(), rocks, stones, float(rocks) / float(PLAYERS), ticks, worst_ms, scatter_ms, sync_ms])

	return true
