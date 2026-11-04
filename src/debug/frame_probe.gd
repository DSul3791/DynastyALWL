extends RefCounted

const FreezeWatch := preload("res://src/debug/freeze_watch.gd")

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
static var _win_process_ms: float = 0.0   # engine monitors summed per frame since window_reset (the GPU probe's engine rows)
static var _win_physics_ms: float = 0.0
const FREEZE_MS := 500.0
const HITCH_MS := 100.0                  # a frame this long prints a HITCH line at once (rate-limited)
static var _hitch_next_msec: int = 0
static var context: Callable = Callable()   # returns a short text about the game's state (set by the client), printed with every freeze line
static var _freeze_prints: int = 0


static func start() -> int:
	return Time.get_ticks_usec()


static func stop(name: String, started: int) -> void:
	var used: int = Time.get_ticks_usec() - started
	FreezeWatch.note(name)   # the last piece finished, for the freeze watch thread

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
	_win_process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_win_physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var ms: float = delta * 1000.0

	# Dave 2 Nov 2026: 4-10 s freezes when trees and grass spawn in. A freeze prints at once (not only in the exit report) with what this frame
	# timed, the engine's script and physics times, draw calls and video memory, and the game's own state: "nothing measured" with a small
	# script time means the wait was in the engine or the graphics driver, not in our scripts.
	if ms > FREEZE_MS and _frames > 30 and _freeze_prints < 40:
		_freeze_prints += 1
		var named: PackedStringArray = PackedStringArray()

		for name in _this_frame:
			if int(_this_frame[name]) > 1000:
				named.append("%s %.0f" % [name, float(_this_frame[name]) / 1000.0])

		print("FREEZE %.0f ms (frame %d): script %.0f ms, physics %.0f ms, draw calls %d, video mem %d MB, objects %d; timed: %s; %s" % [
			ms, _frames,
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0),
			int(Performance.get_monitor(Performance.OBJECT_COUNT)), ", ".join(named) if not named.is_empty() else "nothing",
			str(context.call()) if context.is_valid() else ""
		])

	if ms > SLOW_MS and _frames > 30:
		_slow_count += 1
		var parts: Dictionary = {}

		for name in _this_frame:
			parts[name] = float(_this_frame[name]) / 1000.0

		# Performance monitors are for the frame that just ended: script work, physics step.
		parts["~script process"] = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		parts["~physics step"] = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		parts["~at frame"] = float(_frames)

		# Dave 3 Nov 2026: "every two steps or three it pauses for half a second". The slow-frame breakdown was only in the exit report; a hitch
		# of 100 ms or more now prints at once with its biggest timed pieces (at most one line every 2 s), so a normal play log names it.
		var now_msec: int = Time.get_ticks_msec()

		if ms >= HITCH_MS and now_msec >= _hitch_next_msec:
			_hitch_next_msec = now_msec + 2000
			var named: Array = []

			for name in _this_frame:
				named.append([name, float(_this_frame[name]) / 1000.0])

			named.sort_custom(func(a, b): return a[1] > b[1])
			var text: PackedStringArray = PackedStringArray()

			for k in range(mini(named.size(), 5)):
				text.append("%s %.0f" % [named[k][0], named[k][1]])

			print("HITCH %.0f ms: %s; script %.0f ms, physics %.0f ms, draw calls %d" % [ms, ", ".join(text) if not text.is_empty() else "nothing timed",
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
				int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
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
	_win_process_ms = 0.0
	_win_physics_ms = 0.0


# The pieces that cost most per frame since window_reset, as "name ms" strings (average over the frames in the window).
static func window_top(count: int) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var names: Array = _win.keys()
	names.sort_custom(func(a, b): return _win[a] > _win[b])

	for name in names.slice(0, count):
		out.append("%s %.1f" % [name, float(_win[name]) / 1000.0 / maxf(float(_win_frames), 1.0)])

	return out


# Per frame since window_reset: [engine idle step ms (scripts and engine nodes), physics ms, ms of the pieces the code times].
static func window_engine() -> Array:
	var frames: float = maxf(float(_win_frames), 1.0)
	var named: float = 0.0

	for name in _win:
		named += float(_win[name]) / 1000.0

	return [_win_process_ms / frames, _win_physics_ms / frames, named / frames]
