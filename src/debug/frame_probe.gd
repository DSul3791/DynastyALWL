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
# Where a slow frame's time went (Dave 21 Nov 2026, "lags or pauses a lot when I am running"): the HITCH lines named pieces adding up to a few ms
# of a 140 ms frame, and the frame length came from delta, which the engine caps near 8 physics steps (about 133 ms). The split below takes
# the real time between frames and divides it into the last draw (frame_pre_draw to frame_post_draw, where pipeline builds and GPU waits
# land), the engine's process step (scripts and engine nodes), the physics steps run, the voxel terrain's own main-thread work, and the rest.
static var terrain: Object = null         # the client's VoxelLodTerrain (its get_statistics() main-thread times), set by the client
static var last_split: Dictionary = {}    # the split of the frame frame() just closed (the shot runner's run-in-a-line totals read it)
static var _wall_usec: int = 0
static var _pre_draw_usec: int = 0
static var _draw_usec: int = 0
static var _physics_seen: int = 0
static var _pipelines_seen: int = 0


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
	var now_usec: int = Time.get_ticks_usec()
	var ms: float = float(now_usec - _wall_usec) / 1000.0 if _wall_usec > 0 else delta * 1000.0
	_wall_usec = now_usec
	last_split = _split(ms)

	# Dave 2 Nov 2026: 4-10 s freezes when trees and grass spawn in. A freeze prints at once (not only in the exit report) with what this frame
	# timed, the engine's script and physics times, draw calls and video memory, and the game's own state: "nothing measured" with a small
	# script time means the wait was in the engine or the graphics driver, not in our scripts.
	if ms > FREEZE_MS and _frames > 30 and _freeze_prints < 40:
		_freeze_prints += 1
		var named: PackedStringArray = PackedStringArray()

		for name in _this_frame:
			if int(_this_frame[name]) > 1000:
				named.append("%s %.0f" % [name, float(_this_frame[name]) / 1000.0])

		print("FREEZE %.0f ms (frame %d): script %.0f ms, physics %.0f ms, draw calls %d, video mem %d MB, objects %d; %s; timed: %s; %s" % [
			ms, _frames,
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0),
			int(Performance.get_monitor(Performance.OBJECT_COUNT)), split_text(last_split), ", ".join(named) if not named.is_empty() else "nothing",
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

			print("HITCH %.0f ms: %s; script %.0f ms, physics %.0f ms, draw calls %d; %s" % [ms, ", ".join(text) if not text.is_empty() else "nothing timed",
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
				int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), split_text(last_split)])
		_slow.append([ms, parts])
		_slow.sort_custom(func(a, b): return a[0] > b[0])

		if _slow.size() > KEEP_SLOW:
			_slow.resize(KEEP_SLOW)

	_this_frame = {}


# The client calls these from RenderingServer.frame_pre_draw and frame_post_draw: the draw's CPU time, pipeline builds and GPU waits included.
static func pre_draw() -> void:
	_pre_draw_usec = Time.get_ticks_usec()


static func post_draw() -> void:
	if _pre_draw_usec > 0:
		_draw_usec = Time.get_ticks_usec() - _pre_draw_usec


# The frame just closed, in ms: wall (real time since the frame before), draw, process (the engine's process step: our scripts and engine
# nodes), timed (the pieces this probe names, part of process), physics (see below), voxel (the
# terrain's own main-thread times, read on slow frames only), other (what is left: input, the engine's own frame work); pipelines = pipeline
# compilations since. Physics is the steps run times the engine's physics monitor (its longest step), so it is an upper bound.
static func _split(wall_ms: float) -> Dictionary:
	var physics_now: int = Engine.get_physics_frames()
	var steps: int = physics_now - _physics_seen if _physics_seen > 0 else 1
	_physics_seen = physics_now
	var pipelines_now: int = _pipelines_total()
	var built: int = pipelines_now - _pipelines_seen if _pipelines_seen > 0 else 0
	_pipelines_seen = pipelines_now
	var timed: float = 0.0

	for name in _this_frame:
		timed += float(_this_frame[name]) / 1000.0

	var voxel: float = 0.0

	if wall_ms > SLOW_MS and terrain != null and is_instance_valid(terrain):   # only for a slow frame: the statistics build a Dictionary
		var stats: Dictionary = terrain.call("get_statistics")

		for key in stats:
			if str(key).begins_with("time_"):
				voxel += float(stats[key]) / 1000.0

	var process: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0 * float(steps)
	var draw: float = float(_draw_usec) / 1000.0
	return {"wall": wall_ms, "draw": draw, "process": process, "timed": timed, "physics": physics, "steps": steps, "voxel": voxel,
		"other": maxf(wall_ms - draw - process - physics, 0.0), "pipelines": built, "n": _frames, "usec": Time.get_ticks_usec()}


static func split_text(split: Dictionary) -> String:
	if split.is_empty():
		return "no split"

	return "split: draw %.0f, process %.0f (timed %.0f, voxel %.0f), physics %.0f in %d steps, other %.0f; %d pipelines built; %s" % [
		float(split["draw"]), float(split["process"]), float(split["timed"]), float(split["voxel"]), float(split["physics"]), int(split["steps"]),
		float(split["other"]), int(split["pipelines"]), pipelines_text()]


static func _pipelines_total() -> int:
	return int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)) + int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)) \
		+ int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)) + int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)) \
		+ int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS))


# The renderer's pipeline compilations since the game started, by what asked for them (Godot's monitors). "draw" ones were built while a
# frame waited for them; a freeze whose draw count jumps was the graphics driver building shaders (first join on a cold machine, 20 Nov 2026).
static func pipelines_text() -> String:
	return "pipelines so far: draw %d, specialization %d, mesh %d, surface %d, canvas %d" % [
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)), int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)),
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)), int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)),
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS))]


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
