extends SceneTree

# Animals on uneven frames (BugsList 174): animal_view draws each animal on the ticks clock, so its feet, easing, drawn speed and gait must step
# by that clock's own step, not the engine's delta, which differs from it when frames come unevenly (Lane A saw up to 132 ms on Dave's PC).
# One deer walks east at 3 m/s with a row about every 200 ms, stamped when it is handed over (never late); the view is stepped by hand with a
# 0.05 s delta (under STALL_S) on real frames of 2 to 30 ms, so the old delta-stepped draw reads the walk at a third of its pace on any lane.
# The drawn deer must walk about 3 m/s, its legs must read that speed (b["spd"]), no frame may jump, and a model's footsteps must follow it.
#   godot --headless --path . --script res://src/worldgen/tools/test_animal_frame_clock.gd

const AnimalView := preload("res://src/client/animal_view.gd")
const DEER := 2
const WALK := 1
const ID := 7
const DELTA := 0.05   # the engine delta handed to every frame: not the real frame time, and under STALL_S (0.25 s)

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _initialize() -> void:
	var view = AnimalView.new()
	view.files_ready = func(_species: int) -> bool: return true
	root.add_child(view)
	view.set_process(false)   # stepped by hand below, with a delta that is not the real frame time
	var camera: Camera3D = Camera3D.new()
	root.add_child(camera)
	var at: Vector3 = Vector3(3000.0, 30.0, 3000.0)
	camera.position = at + Vector3(0.0, 2.0, 8.0)
	camera.make_current()
	await process_frame
	var steps: Array = [0]
	view.stepped.connect(func(_kind: String, _at: Vector3) -> void: steps[0] = int(steps[0]) + 1)
	# The body is made first, standing, before the timed walk: a slow first model load (a loaded lane) is spent standing still on the same clock the rows use,
	# so it reads as neither a late row nor a jump.
	var start_ms: int = Time.get_ticks_msec()
	view.on_rows([[ID, DEER, at, -PI * 0.5, WALK, 40000]], 40000)
	view._process_body(DELTA)
	check(view._bodies.has(ID), "a body is made for the deer")
	var walk_from: int = Time.get_ticks_msec() - start_ms
	var frames_ms: Array = [2, 2, 30, 8, 2, 16]   # uneven real frames; each is handed DELTA as its delta
	var next_row: int = walk_from
	var frame: int = 0
	var first_x: float = NAN
	var last_x: float = NAN
	var worst_frame: float = 0.0
	var spd_low: float = INF
	var spd_high: float = 0.0
	var was_x: float = NAN
	var was_us: int = 0

	while Time.get_ticks_msec() - start_ms < walk_from + 3000:
		var now: int = Time.get_ticks_msec() - start_ms

		if now >= next_row:   # a 3 m/s walk east, a row about every 200 ms, stamped by when it is handed over, so the draw clock never sees it late
			view.on_rows([[ID, DEER, at + Vector3(3.0 * float(now - walk_from) / 1000.0, 0.0, 0.0), -PI * 0.5, WALK, 40000 + now]], 40000 + now)
			next_row = now + 200

		var wait_ms: int = int(frames_ms[frame % frames_ms.size()])
		frame += 1
		OS.delay_usec(wait_ms * 1000)
		view._process_body(DELTA)
		var now_us: int = Time.get_ticks_usec()
		var real_s: float = float(now_us - was_us) / 1.0e6
		was_us = now_us
		var b: Dictionary = view._bodies.get(ID, {})

		if b.is_empty() or now - walk_from <= 1200:
			continue

		var x: float = (b["node"] as Node3D).position.x
		first_x = x if is_nan(first_x) else first_x

		if not is_nan(was_x):
			worst_frame = maxf(worst_frame, absf(x - was_x) / maxf(real_s, 0.001))   # this frame's own move over its real time, in m/s

		was_x = x
		last_x = x
		spd_low = minf(spd_low, float(b["spd"]))
		spd_high = maxf(spd_high, float(b["spd"]))

	var body: Dictionary = view._bodies.get(ID, {})
	check(not body.is_empty(), "a body is drawn for the deer")

	if not body.is_empty():
		var walked: float = last_x - first_x
		print("deer (%s): walked %.2f m in the last 1.8 s, legs read %.2f-%.2f m/s, fastest frame %.1f m/s, %d footsteps" % ["model" if bool(body["model"]) else "code body", walked, spd_low, spd_high, worst_frame, int(steps[0])])
		check(walked > 4.0 and walked < 7.0, "the drawn deer walked %.2f m in the last 1.8 s (5.4 m at 3 m/s), not standing or rushing" % walked)
		check(spd_low > 2.0 and spd_high < 4.0, "its legs read the walk, %.2f-%.2f m/s (3 m/s), on frames handed a %.2f s delta" % [spd_low, spd_high, DELTA])
		check(worst_frame < 6.0, "no frame jumps: the fastest frame moved %.1f m/s (3 m/s walk)" % worst_frame)

		if bool(body["model"]) or bool(body["quad"]):
			check(int(steps[0]) >= 2, "its footsteps follow the metres walked (%d over the walk)" % int(steps[0]))

	view.queue_free()
	camera.queue_free()
	print("test_animal_frame_clock: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
