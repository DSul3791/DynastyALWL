extends SceneTree

# Animals are drawn between the points the server sent, a send behind (src/client/motion_buffer.gd; Dave 19 Nov 2026 play test: "they are
# teleporting when they move"; 21 Nov "still teleporting"): steady speed between sends, on the server's step times (protocol 147), a late send carried over, a long-still animal walks off instead of sliding the whole gap, a far jump is shown at once.
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
	check(absf(MotionBuffer.delay_s(0.25) - 0.4) < 0.001 and MotionBuffer.delay_s(5.0) == 0.7 and absf(MotionBuffer.delay_s(0.0) - 0.15) < 0.001, "delay: a send and LEAD_S, 0.1 to 0.7 s")

	# One lost send (a 0.5 s gap) is not taken for a pause: the body keeps sliding from the point before.
	var lost: Array = []
	MotionBuffer.push(lost, Vector3(0, 0, 0), 0.0, 30.0, 0.25)
	MotionBuffer.push(lost, Vector3(2, 0, 0), 0.0, 30.5, 0.25)
	check(lost.size() == 2 and absf((MotionBuffer.at(lost, 30.25)[0] as Vector3).x - 1.0) < 0.001, "a lost send: no stand-still point, half way at half time")

	# The same point sent again (unchanged rows repeat) or an older one out of order is dropped.
	var again: Array = []
	MotionBuffer.push(again, Vector3(0, 0, 0), 0.0, 40.0, 0.25)
	MotionBuffer.push(again, Vector3(1, 0, 0), 0.0, 40.25, 0.25)
	MotionBuffer.push(again, Vector3(1, 0, 0), 0.0, 40.25, 0.25)
	MotionBuffer.push(again, Vector3(0.5, 0, 0), 0.0, 40.1, 0.25)
	check(again.size() == 2, "a repeat and an out-of-order point are dropped (%d kept)" % again.size())

	# The clock offset (protocol 147): the smallest seen, creeping up, starting again after a big jump.
	var off: float = MotionBuffer.clock_off(INF, 100.0, 5000)
	check(absf(off - 95.0) < 0.0001, "first offset: local minus server (%.4f)" % off)
	off = MotionBuffer.clock_off(off, 100.35, 5250)   # this batch came 0.1 s slower
	check(absf(off - (95.0 + MotionBuffer.CREEP_S)) < 0.0001, "a slower batch: the offset only creeps (%.4f)" % off)
	off = MotionBuffer.clock_off(off, 100.45, 5500)   # a faster one
	check(absf(off - 94.95) < 0.0001, "a faster batch: the offset drops to it (%.4f)" % off)
	off = MotionBuffer.clock_off(off, 101.0, 10)   # the server restarted: its clock is back near zero
	check(absf(off - 100.99) < 0.0001, "a server clock that jumped: started again (%.4f)" % off)

	# Dave 21 Nov 2026 ("animals are still teleporting and not actually running"): an elephant running at 10 m/s, stepped every 0.1 s on the
	# server, its rows sent every 0.25 s, and two batches handed over together after a 150 ms frame hitch. Drawn on the server's step times
	# it covers the same ground every frame; on arrival times (the old way) it jumped and stood.
	var run: Array = []
	var arrive: Array = []   # [local arrival s, server ms of the send, server ms of the newest step]
	var off2: float = INF

	for k in range(1, 13):
		var send_ms: int = 250 * k
		var step_ms: int = int(floor(float(send_ms) / 100.0)) * 100   # the newest step at or before the send
		var at_s: float = 50.0 + float(send_ms) / 1000.0 + 0.04 + (0.15 if k == 6 else 0.0)   # the hitch holds batch 6 back to batch 7
		arrive.append([at_s, send_ms, step_ms])

	var widest: float = 0.0
	var narrowest: float = INF

	for frame in range(0, 80):
		var now_s: float = 50.3 + 0.033 * frame

		for r in arrive.duplicate():
			if float(r[0]) <= now_s:
				off2 = MotionBuffer.clock_off(off2, float(r[0]), int(r[1]))
				MotionBuffer.push(run, Vector3(10.0 * float(r[2]) / 1000.0, 0, 0), 0.0, float(r[2]) / 1000.0 + off2, 0.25)
				arrive.erase(r)

		if now_s >= 50.8 and run.size() >= 2 and now_s < 52.6:   # once the drawn moment is past the first point, until the rows run out
			var a0: float = (MotionBuffer.at(run, now_s - 0.033 - MotionBuffer.delay_s(0.25))[0] as Vector3).x
			var a1: float = (MotionBuffer.at(run, now_s - MotionBuffer.delay_s(0.25))[0] as Vector3).x
			var speed: float = (a1 - a0) / 0.033
			widest = maxf(widest, speed)
			narrowest = minf(narrowest, speed)

	check(narrowest > 8.5 and widest < 11.5, "an elephant running at 10 m/s is drawn at 8.5 to 11.5 m/s every frame through a hitch (%.1f to %.1f)" % [narrowest, widest])

	print("test_animal_motion_buffer: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)
