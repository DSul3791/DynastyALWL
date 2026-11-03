extends SceneTree

# Lag while walking (Dave 3 Nov 2026: a pause every two or three steps, client frames of 50-145 ms): the real flora view on the starter tile, fed
# the real chunks, walked 300 m at a jog. Every frame times flora update (each 500 ms, as the client) and apply_built, and the whole frame (deferred
# frees included). Then a new trunk, a stump and a hoe patch land beside the player (a fell, a split, a hoe click) and the frames after are timed.
#   godot --headless --path . --script res://src/worldgen/tools/test_flora_walk_cost.gd
# Prints "walk:" lines with the worst pieces; fails when one frame's flora work passes the bars below.

const FloraView := preload("res://src/flora/flora_view.gd")
const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")

const APPLY_BAR_MS := 30.0     # one apply_built call
const UPDATE_BAR_MS := 30.0    # one flora update
const FRAME_BAR_MS := 60.0     # one whole frame of flora work plus the frees after it
const JOG_M_S := 4.5
const FRAME_S := 1.0 / 60.0

var failures: int = 0
var worst: Dictionary = {"apply": 0.0, "update": 0.0, "frame": 0.0}
var over: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	_run.call_deferred()


func _frame(view, pos: Vector3, do_update: bool, label: String) -> void:
	var t0: int = Time.get_ticks_usec()
	var update_ms: float = 0.0

	if do_update:
		view.update(pos)
		update_ms = float(Time.get_ticks_usec() - t0) / 1000.0

	var t1: int = Time.get_ticks_usec()
	view.apply_built()
	var apply_ms: float = float(Time.get_ticks_usec() - t1) / 1000.0
	await process_frame          # deferred frees of this frame run before the next
	var frame_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0

	worst["apply"] = maxf(worst["apply"], apply_ms)
	worst["update"] = maxf(worst["update"], update_ms)
	worst["frame"] = maxf(worst["frame"], frame_ms)

	if frame_ms > FRAME_BAR_MS:
		over += 1
		print("walk: %s slow frame %.1f ms (update %.1f, apply %.1f) at %s; %s" % [label, frame_ms, update_ms, apply_ms, str(pos.round()), view.load_state()])


func _run() -> void:
	var world_dir: String = "res://worlds/base_world"
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world_dir + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world_dir + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())

	if settings == null or rules.is_empty() or not errors.is_empty():
		print("FAIL world data does not load: ", errors)
		quit(1)
		return

	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world_dir + "/tiles")
	var placer = PlacerScript.new()
	placer.setup(generator, tables, rules)
	var view = FloraView.new()
	root.add_child(view)
	view.setup(tables, rules)

	# The species models are built by a worker: wait for the set-up (apply_built steps it).
	var waited: int = 0

	while not view._setup_done and waited < 3000:
		view.apply_built()
		await process_frame
		OS.delay_msec(10)
		waited += 1

	check(view._setup_done, "the flora view set itself up (%d frames)" % waited)

	# Dave's walk in the log: from x 53256 z 68470 (the starter tile), east.
	var pos: Vector3 = Vector3(53256.0, 30.0, 68470.0)
	var home: Vector2i = placer.chunk_of(pos.x, pos.z)
	var t_items: int = Time.get_ticks_usec()

	for dz in range(-2, 3):
		for dx in range(-2, 4):
			var chunk: Vector2i = home + Vector2i(dx, dz)
			view.set_chunk(chunk, placer.chunk_items(placer.normalize(chunk)), pos)

	print("walk: %d chunks made and set in %.0f ms (worker-side in the game)" % [view._chunks.size(), float(Time.get_ticks_usec() - t_items) / 1000.0])

	# Let the first drawing finish (loading, not walking: not timed against the bars).
	waited = 0

	while (not view._jobs.is_empty() or not view._tasks.is_empty() or not view._plan_wait.is_empty() or waited < 30) and waited < 6000:
		view.apply_built()
		await process_frame
		waited += 1

	print("walk: first drawing done after %d frames; %s" % [waited, view.load_state()])
	worst = {"apply": 0.0, "update": 0.0, "frame": 0.0}
	over = 0

	# Walk 300 m east at a jog; flora update every 500 ms as the client does.
	var frames: int = int(300.0 / JOG_M_S / FRAME_S)
	var since_update: float = 0.0

	for f in range(frames):
		pos.x += JOG_M_S * FRAME_S
		since_update += FRAME_S
		var do_update: bool = since_update >= 0.5

		if do_update:
			since_update = 0.0

		await _frame(view, pos, do_update, "walking")

	print("walk: 300 m, %d frames: worst apply %.1f ms, worst update %.1f ms, worst frame %.1f ms, %d frames over %.0f ms" % [frames, worst["apply"], worst["update"], worst["frame"], over, FRAME_BAR_MS])
	check(worst["apply"] < APPLY_BAR_MS, "walking: no apply_built over %.0f ms (worst %.1f)" % [APPLY_BAR_MS, worst["apply"]])
	check(worst["update"] < UPDATE_BAR_MS, "walking: no flora update over %.0f ms (worst %.1f)" % [UPDATE_BAR_MS, worst["update"]])
	check(over == 0, "walking: no frame of flora work over %.0f ms (%d were)" % [FRAME_BAR_MS, over])

	# A fell, a split and a hoe click beside the player: a new trunk, a stump and a hoe patch, each its own _sync_cleared change.
	worst = {"apply": 0.0, "update": 0.0, "frame": 0.0}
	over = 0
	var lying: Array = []
	var events: Array = [
		[pos.x + 3.0, pos.z, pos.x + 11.0, pos.z + 1.0, 0.3, 0.2],   # the felled trunk
		[pos.x + 3.0, pos.z, pos.x + 3.0, pos.z, 0.28, 0.28],         # its stump
		[pos.x - 2.0, pos.z + 2.0, pos.x - 2.0, pos.z + 2.0, 0.6, 0.6],   # a hoe path patch
	]

	for event in events:
		lying.append(event)
		var t0: int = Time.get_ticks_usec()
		view.set_trunks(lying.duplicate(), 0.3)
		var set_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
		worst["frame"] = maxf(worst["frame"], set_ms)

		for f in range(90):     # 1.5 s of frames: the filter, the replan and the redraw
			await _frame(view, pos, f % 30 == 0, "after an edit")

	print("walk: fell, split and hoe: worst apply %.1f ms, worst frame %.1f ms, %d frames over %.0f ms" % [worst["apply"], worst["frame"], over, FRAME_BAR_MS])
	check(worst["apply"] < APPLY_BAR_MS, "after a fell, a split or a hoe click: no apply_built over %.0f ms (worst %.1f)" % [APPLY_BAR_MS, worst["apply"]])
	check(over == 0, "after a fell, a split or a hoe click: no frame over %.0f ms (%d were)" % [FRAME_BAR_MS, over])
	view.finish_tasks()
	view.queue_free()
	await process_frame
	print("test_flora_walk_cost: %d failures" % failures)
	quit(1 if failures > 0 else 0)
