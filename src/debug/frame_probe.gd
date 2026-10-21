extends RefCounted

# Owner (2026-10-19): find what makes the game pause, as a regular routine while coding.
# Times named pieces of main-thread work. Wrap a piece with
#   var t: int = FrameProbe.start()  ...  FrameProbe.stop("flora", t)
# and call FrameProbe.frame(delta) once per frame. Keeps, per name, the count, total and
# worst time, and for every slow frame (over SLOW_MS) which pieces it spent its time on.
# report() returns a short text: the pieces by total time, then the slowest frames.

const SLOW_MS := 50.0
const KEEP_SLOW := 12

static var _totals: Dictionary = {}       # name -> [count, total_us, worst_us]
static var _this_frame: Dictionary = {}   # name -> us spent this frame
static var _slow: Array = []              # [frame_ms, {name: ms}]
static var _frames: int = 0
static var _slow_count: int = 0
static var _win: Dictionary = {}          # name -> us since window_reset (the GPU probe's script-cost lines)
static var _win_frames: int = 0


static func start() -> int:
	return Time.get_ticks_usec()


static func stop(name: String, started: int) -> void:
	var used: int = Time.get_ticks_usec() - started

	if used > 2500 and OS.has_environment("SPIKES"):
		print("SPIKE %s %.1f ms at %d" % [name, float(used) / 1000.0, Time.get_ticks_msec()])

	var entry: Array = _totals.get(name, [0, 0, 0])
	entry[0] += 1
	entry[1] += used
	entry[2] = maxi(entry[2], used)
	_totals[name] = entry
	_this_frame[name] = int(_this_frame.get(name, 0)) + used
	_win[name] = int(_win.get(name, 0)) + used


# Call at the start of each frame with the previous frame's length (seconds).
static func frame(delta: float) -> void:
	_frames += 1
	_win_frames += 1
	var ms: float = delta * 1000.0

	if ms > SLOW_MS and _frames > 30:
		_slow_count += 1
		var parts: Dictionary = {}

		for name in _this_frame:
			parts[name] = float(_this_frame[name]) / 1000.0

		# Performance monitors are for the frame that just ended: script work, physics step.
		parts["~script process"] = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		parts["~physics step"] = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		parts["~at frame"] = float(_frames)
		_slow.append([ms, parts])
		_slow.sort_custom(func(a, b): return a[0] > b[0])

		if _slow.size() > KEEP_SLOW:
			_slow.resize(KEEP_SLOW)

	_this_frame = {}


static func reset() -> void:
	_totals = {}
	_this_frame = {}
	_slow = []
	_frames = 0
	_slow_count = 0


static func report() -> String:
	var lines: PackedStringArray = PackedStringArray()
	var names: Array = _totals.keys()
	names.sort_custom(func(a, b): return _totals[a][1] > _totals[b][1])
	lines.append("frame probe: %d frames, %d slower than %.0f ms" % [_frames, _slow_count, SLOW_MS])

	for name in names:
		var entry: Array = _totals[name]
		lines.append("  %-18s %6d calls  total %8.1f ms  avg %6.2f ms  worst %7.1f ms" % [
			name, entry[0], float(entry[1]) / 1000.0, float(entry[1]) / 1000.0 / maxf(float(entry[0]), 1.0), float(entry[2]) / 1000.0
		])

	for slow in _slow:
		var parts: Dictionary = slow[1]
		var text: PackedStringArray = PackedStringArray()
		var keys: Array = parts.keys()
		keys.sort_custom(func(a, b): return parts[a] > parts[b])

		for name in keys:
			text.append("%s %.1f" % [name, parts[name]] if name != "~at frame" else "frame no. %d" % int(parts[name]))

		lines.append("  slow frame %.0f ms: %s" % [slow[0], ", ".join(text) if not text.is_empty() else "(nothing measured: engine work)"])

	return "\n".join(lines)


static func window_reset() -> void:
	_win = {}
	_win_frames = 0


# The pieces that cost most per frame since window_reset, as "name ms" strings (average over the frames in the window).
static func window_top(count: int) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var names: Array = _win.keys()
	names.sort_custom(func(a, b): return _win[a] > _win[b])

	for name in names.slice(0, count):
		out.append("%s %.1f" % [name, float(_win[name]) / 1000.0 / maxf(float(_win_frames), 1.0)])

	return out
