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

const PrintQueueScript := preload("res://src/shared/print_queue.gd")
static var printer = PrintQueueScript.new()   # the client's diagnostic lines, printed on a worker (D-LAG-1): a print on the main thread flushed the log 0.4-1.6 s
static var _mutex: Mutex = Mutex.new()
static var _beat_msec: int = 0
static var _last_piece: String = "start"
static var _frame: int = 0

var _thread: Thread
var _running: bool = false


static func beat() -> void:
	var now: int = Time.get_ticks_msec()
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

	if gap > GAP_MS and frame > 30:
		printer.line("FREEZE gap: %d ms between frames %d and %d, last finished before it: \"%s\"%s" % [gap, frame - 1, frame, piece, built])


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

	beat()
	_running = true
	_thread = Thread.new()
	_thread.start(_watch)


func stop() -> void:
	if _thread == null:
		return

	_running = false
	_thread.wait_to_finish()
	_thread = null


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
