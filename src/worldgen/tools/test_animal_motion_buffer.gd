extends SceneTree

# Animals are drawn between the points the server sent, a send behind (src/client/motion_buffer.gd; Dave 19 Nov 2026 play test: "they are
# teleporting when they move"): steady speed between sends, a late send carried over, a long-still animal walks off instead of sliding the whole gap, a far jump is shown at once.
#   godot --headless --path . --script res://src/worldgen/tools/test_animal_motion_buffer.gd

const MotionBuffer := preload("res://src/client/motion_buffer.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	failures += 0 if ok else 1


func _init() -> void:
	var s: Array = []
	MotionBuffer.push(s, Vector3(0, 0, 0), 0.0, 10.0, 0.25)
	check((MotionBuffer.at(s, 10.5)[0] as Vector3).is_equal_approx(Vector3.ZERO), "one point: drawn there")
	MotionBuffer.push(s, Vector3(1, 0, 0), 0.0, 10.25, 0.25)
	MotionBuffer.push(s, Vector3(2, 0, 0), 0.0, 10.5, 0.25)

	# Drawn a send behind, the body moves the same distance every frame (no lunge after a send).
	var steps: Array = []
	var was: Vector3 = MotionBuffer.at(s, 10.2)[0]

	for i in range(1, 6):
		var now: Vector3 = MotionBuffer.at(s, 10.2 + 0.05 * i)[0]
		steps.append(now.distance_to(was))
		was = now

	var even: bool = true

	for d in steps:
		even = even and absf(float(d) - 0.2) < 0.001

	check(even, "between sends the body covers 0.2 m every 0.05 s (4 m/s steady): %s" % str(steps))
	check(absf((MotionBuffer.at(s, 10.6)[0] as Vector3).x - 2.4) < 0.001, "a late send: past the newest point it carries on at 4 m/s")
	check((MotionBuffer.at(s, 11.0)[0] as Vector3).is_equal_approx(Vector3(3, 0, 0)), "for one more leg's time, then stands")
	check(absf(float(MotionBuffer.at([[Vector3.ZERO, 3.0, 0.0], [Vector3.ONE, -3.0, 1.0]], 0.5)[1]) - PI) < 0.05, "the heading turns the short way round")

	# Two seconds still (the unchanged rows went out every 2 s), then a step: it walks off from the send before, not over the whole 2 s.
	var still: Array = []
	MotionBuffer.push(still, Vector3(0, 0, 0), 0.0, 20.0, 0.25)
	MotionBuffer.push(still, Vector3(1, 0, 0), 0.0, 22.0, 0.25)
	check((MotionBuffer.at(still, 21.7)[0] as Vector3).is_equal_approx(Vector3.ZERO), "still until the send before (21.75)")
	check(absf((MotionBuffer.at(still, 21.875)[0] as Vector3).x - 0.5) < 0.001, "then half way in half a send")

	# Out of a burrow 40 m off: shown at once.
	MotionBuffer.push(still, Vector3(41, 0, 0), 0.0, 22.25, 0.25)
	check(still.size() == 1 and (MotionBuffer.at(still, 22.0)[0] as Vector3).is_equal_approx(Vector3(41, 0, 0)), "a 40 m jump is drawn there at once")

	# At most KEEP points, and the delay follows the gap between sends.
	for i in range(10):
		MotionBuffer.push(still, Vector3(41 + i, 0, 0), 0.0, 22.5 + 0.25 * i, 0.25)

	check(still.size() == MotionBuffer.KEEP, "only the last %d points kept" % MotionBuffer.KEEP)
	check(absf(MotionBuffer.delay_s(0.25) - 0.28) < 0.001 and MotionBuffer.delay_s(5.0) == 0.6 and MotionBuffer.delay_s(0.0) == 0.08, "delay: a send and a bit, 0.08 to 0.6 s")

	# One lost send (a 0.5 s gap) is not taken for a pause: the body keeps sliding from the point before.
	var lost: Array = []
	MotionBuffer.push(lost, Vector3(0, 0, 0), 0.0, 30.0, 0.25)
	MotionBuffer.push(lost, Vector3(2, 0, 0), 0.0, 30.5, 0.25)
	check(lost.size() == 2 and absf((MotionBuffer.at(lost, 30.25)[0] as Vector3).x - 1.0) < 0.001, "a lost send: no stand-still point, half way at half time")

	print("test_animal_motion_buffer: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)
