extends RefCounted

# Dave 2 Nov 2026: "The entire game stops ... no sounds no nothing" for about 2 s near a felled log. The frame probe's FREEZE line (frame_probe.gd) only
# prints after the main thread comes back, and it cannot tell a stuck script from the whole game being stopped. This watch runs on its own thread:
# - the main thread beats once a frame (beat()) and names each piece it finishes (frame_probe.stop calls note());
# - every 100 ms the watch looks: no beat for over STUCK_MS prints "FREEZE watch: main thread stuck N ms, last finished: <piece>" while it is still stuck,
#   and once more when it is free again with the whole length;
# - if the watch's own 100 ms sleep took over STALL_MS, this thread was starved (every core busy) or the whole game was stopped; a late look is
#   not used for the stuck reading (3 Nov: starved looks gave 0.7-0.9 s "stuck" lines while no frame was over 142 ms);
# - beat() itself prints "FREEZE gap: N ms between frames" from the main thread's own clock: the line to trust for a real stop.

const LOOK_MS := 100
const STUCK_MS := 700
const STALL_MS := 600
const GAP_MS := 500                     # a main-thread frame gap this long prints a FREEZE gap line (the one to trust)
const LATE_MS := 250                    # the watch woke this late: its stuck reading is not trusted (the thread was starved)
const DRAW_START := "draw start (every _process and deferred call done)"     # a stall after it is in the draw
const DRAWN := "drawn (the draw done; next the physics step, then frame start)"   # a stall after it: the window's present, or physics callbacks
const PHYSICS_STEP := "physics callbacks done (next the physics engine's step, the network poll, then frame start)"   # terrain_client _physics_process

const PrintQueueScript := preload("res://src/shared/print_queue.gd")
static var printer = PrintQueueScript.new()   # the client's diagnostic lines, printed on a worker (D-LAG-1): a print on the main thread flushed the log 0.4-1.6 s
static var _mutex: Mutex = Mutex.new()
static var _beat_msec: int = 0
static var _last_piece: String = "start"
static var _frame: int = 0
# Wall clock of the last frame's parts (main thread, usec), so a HITCH line can say where a slow frame went when its timed pieces are small
# (Lane A 25 Nov 2026: 100-145 ms frames whose named pieces added up to about 10 ms).
static var _beat_usec: int = 0
static var _pre_usec: int = 0
static var _post_usec: int = 0
static var _phys_usec: int = 0
static var _end_usec: int = 0             # the last _process of the frame (process_end_mark.gd): scripts before it, deferred calls and engine work after
static var wall_ms: float = 0.0           # the frame that just ended, beat to beat on the main thread's clock (0: no draw, use the engine's delta)
static var built_last: String = ""        # the renderer's pipeline builds in that frame (", pipelines built: ..." or "")
static var split: String = ""            # "process N, draw N, present N, physics step and poll N" for the frame that just ended (ms); "present" runs
                                          # from the draw's end to the last physics callback, "physics step and poll" from there to the next frame's
                                          # start (the physics engine's step, the network poll, any _process before the client's)

var _thread: Thread
var _running: bool = false


static func beat() -> void:
	var now: int = Time.get_ticks_msec()
	var now_usec: int = Time.get_ticks_usec()

	if _beat_usec > 0 and _pre_usec > _beat_usec and _post_usec >= _pre_usec:
		var after: int = (_phys_usec if _phys_usec > _post_usec else now_usec) - _post_usec
		var engine: int = now_usec - _phys_usec if _phys_usec > _post_usec else 0
		var process_part: String = "process %.0f" % (float(_pre_usec - _beat_usec) / 1000.0)

		if _end_usec > _beat_usec and _end_usec <= _pre_usec:
			process_part = "scripts %.0f, deferred and engine %.0f" % [float(_end_usec - _beat_usec) / 1000.0, float(_pre_usec - _end_usec) / 1000.0]

		split = "%s, draw %.0f, present %.0f, physics step and poll %.0f" % [process_part, float(_post_usec - _pre_usec) / 1000.0, float(after) / 1000.0, float(engine) / 1000.0]
		wall_ms = float(now_usec - _beat_usec) / 1000.0
	else:
		split = "no draw"   # no frame drawn since the last beat (minimised, headless): no split for it
		wall_ms = 0.0

	_beat_usec = now_usec
	_mutex.lock()
	var gap: int = now - _beat_msec
	var piece: String = _last_piece
	_beat_msec = now
	_frame += 1
	_last_piece = "frame start"
	var frame: int = _frame
	_mutex.unlock()

	# The real time between two frames, from the main thread itself (not the watch thread, which can be held up when every core is busy):
	# Dave's 3 Nov log had watch lines of 0.7-0.9 s while no frame was over 142 ms, so the watch alone is not proof of a stall.
	var built: String = _pipelines_built()
	built_last = built

	if gap > GAP_MS and frame > 30:
		printer.line("FREEZE gap: %d ms between frames %d and %d, last finished before it: \"%s\"%s; physics bodies active %d, pairs %d, video mem %d MB" % [gap, frame - 1, frame, piece, built,
			int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)), int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)),
			int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)])


# The renderer's pipeline builds since the last beat (Godot's PIPELINE_COMPILATIONS monitors, counted since start), as ", pipelines built:
# draw 3, surface 120" (only those not 0), or "" when none: tells a stall in the driver's pipeline building (draw: built while drawing)
# from Godot's own shader compiling, which these do not count (22 Nov 2026: the 8 s cold first-join freeze on Vulkan, after "held item").
const PIPELINE_MONITORS := [["draw", Performance.PIPELINE_COMPILATIONS_DRAW], ["surface", Performance.PIPELINE_COMPILATIONS_SURFACE],
	["mesh", Performance.PIPELINE_COMPILATIONS_MESH], ["specialization", Performance.PIPELINE_COMPILATIONS_SPECIALIZATION],
	["canvas", Performance.PIPELINE_COMPILATIONS_CANVAS]]
static var _pipelines_seen: PackedInt64Array = PackedInt64Array()


static func _pipelines_built() -> String:
	if _pipelines_seen.size() != PIPELINE_MONITORS.size():
		_pipelines_seen.resize(PIPELINE_MONITORS.size())

	var parts: PackedStringArray = PackedStringArray()

	for i in range(PIPELINE_MONITORS.size()):
		var total: int = int(Performance.get_monitor(PIPELINE_MONITORS[i][1]))

		if total > _pipelines_seen[i]:
			parts.append("%s %d" % [PIPELINE_MONITORS[i][0], total - _pipelines_seen[i]])

		_pipelines_seen[i] = total

	return "" if parts.is_empty() else ", pipelines built: " + ", ".join(parts)


static func note(piece: String) -> void:
	_mutex.lock()
	_last_piece = piece
	_mutex.unlock()


func start() -> void:
	if _thread != null:
		return

	# The draw's own ends, so a stall after the last probed piece is placed (Lane A, 23 Nov 2026: the join's 9 s frame was "stuck after held
	# item", the last _process piece, with no word whether the deferred calls, the draw or the next physics step held it).
	RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	RenderingServer.frame_post_draw.connect(_on_post_draw)
	beat()
	_running = true
	_thread = Thread.new()
	_thread.start(_watch)


func stop() -> void:
	if _thread == null:
		return

	if RenderingServer.frame_pre_draw.is_connected(_on_pre_draw):
		RenderingServer.frame_pre_draw.disconnect(_on_pre_draw)
		RenderingServer.frame_post_draw.disconnect(_on_post_draw)

	_running = false
	_thread.wait_to_finish()
	_thread = null


func _on_pre_draw() -> void:
	_pre_usec = Time.get_ticks_usec()
	note(DRAW_START)


func _on_post_draw() -> void:
	_post_usec = Time.get_ticks_usec()
	note(DRAWN)


# The last _process of the frame (src/debug/process_end_mark.gd, lowest process priority): what follows before the draw is the deferred calls and
# the engine's own end-of-process work.
static func process_end_mark() -> void:
	_end_usec = Time.get_ticks_usec()


# The last physics callback of the frame (terrain_client _physics_process): what follows is the physics engine's own step.
static func physics_mark() -> void:
	_phys_usec = Time.get_ticks_usec()
	note(PHYSICS_STEP)


func _watch() -> void:
	var woke: int = Time.get_ticks_msec()
	var stuck_frame: int = -1
	var stuck_since: int = 0
	var stuck_piece: String = ""

	while _running:
		OS.delay_msec(LOOK_MS)
		var now: int = Time.get_ticks_msec()

		var slept: int = now - woke
		woke = now

		if slept > STALL_MS:
			print("FREEZE watch: this watch thread slept %d ms instead of %d: every core busy (loader and mesh threads), or the whole game stopped by the operating system, paging, the disk or the driver" % [slept, LOOK_MS])

		if slept > LOOK_MS + LATE_MS:
			continue   # starved: a late look would blame the main thread for the watch's own wait

		_mutex.lock()
		var beat_at: int = _beat_msec
		var frame: int = _frame
		var piece: String = _last_piece
		_mutex.unlock()

		if stuck_frame >= 0 and frame != stuck_frame:
			print("FREEZE watch: main thread free again after %d ms; it was stuck after \"%s\"" % [beat_at - stuck_since, stuck_piece])
			stuck_frame = -1

		if stuck_frame < 0 and now - beat_at > STUCK_MS:
			stuck_frame = frame
			stuck_since = beat_at
			stuck_piece = piece
			print("FREEZE watch: main thread stuck %d ms so far (frame %d), last finished: \"%s\"" % [now - beat_at, frame, piece])
