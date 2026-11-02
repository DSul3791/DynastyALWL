extends RefCounted

# Dave 2 Nov 2026: "The entire game stops ... no sounds no nothing" for about 2 s near a felled log. The frame probe's FREEZE line (frame_probe.gd) only
# prints after the main thread comes back, and it cannot tell a stuck script from the whole game being stopped. This watch runs on its own thread:
# - the main thread beats once a frame (beat()) and names each piece it finishes (frame_probe.stop calls note());
# - every 100 ms the watch looks: no beat for over STUCK_MS prints "FREEZE watch: main thread stuck N ms, last finished: <piece>" while it is still stuck,
#   and once more when it is free again with the whole length;
# - if the watch's own 100 ms sleep took over STALL_MS, the whole game was stopped (this thread too): the operating system, memory paging, the disk
#   or the graphics driver, not our scripts. That prints "FREEZE watch: the whole game stopped N ms".

const LOOK_MS := 100
const STUCK_MS := 700
const STALL_MS := 600

static var _mutex: Mutex = Mutex.new()
static var _beat_msec: int = 0
static var _last_piece: String = "start"
static var _frame: int = 0

var _thread: Thread
var _running: bool = false


static func beat() -> void:
	_mutex.lock()
	_beat_msec = Time.get_ticks_msec()
	_frame += 1
	_last_piece = "frame start"
	_mutex.unlock()


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

		if now - woke > STALL_MS:
			print("FREEZE watch: the whole game stopped %d ms (this watch thread too): the operating system, memory paging, the disk or the graphics driver, not our scripts" % (now - woke))

		woke = now
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
