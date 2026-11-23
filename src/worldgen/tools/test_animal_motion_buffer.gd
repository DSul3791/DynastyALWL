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
	off = MotionBuffer.clock_off(off, 101.0, 10, 5500)   # the server restarted: its clock is back near zero
	check(absf(off - 100.99) < 0.0001, "a server clock that went back: started again (%.4f)" % off)
	var held: float = MotionBuffer.clock_off(off, 103.5, 1010, 10)   # a 1.5 s frame hitch held this batch back
	check(absf(held - (off + MotionBuffer.CREEP_S)) < 0.0001, "a late batch after a long hitch does not move the offset (%.4f)" % held)

	# A runner that stops: the server sends its first still moment, so the last leg has no length and it is not carried past its stop.
	var stop: Array = []
	MotionBuffer.push(stop, Vector3(0, 0, 0), 0.0, 60.0, 0.25)
	MotionBuffer.push(stop, Vector3(2.5, 0, 0), 0.0, 60.25, 0.25)
	MotionBuffer.push(stop, Vector3(2.5, 0, 0), 0.0, 60.45, 0.25)   # a standing row: the send time (protocol 154)
	check(absf((MotionBuffer.at(stop, 60.75)[0] as Vector3).x - 2.5) < 0.001, "a stopped runner stays where it stopped (%.2f)" % (MotionBuffer.at(stop, 60.75)[0] as Vector3).x)

	# Repeated rows the way the client gets them (gate review of PR #1433): the offset creeps between batches, so the same server ms lands a
	# little later each time. It is kept once; a repeat with a new heading turns the point in place; an older batch out of order is dropped.
	var body: Dictionary = {"samples": []}
	MotionBuffer.push_row(body, Vector3(1, 0, 0), 0.0, 1000, 70.0, 0.25)
	MotionBuffer.push_row(body, Vector3(1, 0, 0), 0.0, 1000, 70.0005, 0.25)
	check((body["samples"] as Array).size() == 1, "the same server ms a creep later is kept once (%d points)" % (body["samples"] as Array).size())
	MotionBuffer.push_row(body, Vector3(1, 0, 0), 1.5, 1000, 70.001, 0.25)
	check((body["samples"] as Array).size() == 1 and absf(float(MotionBuffer.at(body["samples"], 72.0)[1]) - 1.5) < 0.001, "a repeat with a new heading turns the standing body")
	MotionBuffer.push_row(body, Vector3(2, 0, 0), 1.5, 1300, 70.001, 0.25)
	MotionBuffer.push_row(body, Vector3(1.5, 0, 0), 1.5, 1150, 70.001, 0.25)
	MotionBuffer.push_row(body, Vector3(2, 0, 0), 1.5, 1300, 70.0015, 0.25)
	check((body["samples"] as Array).size() == 2 and int(body["row_ms"]) == 1300, "an older batch out of order is dropped, and the newest is not taken again after it")
	var restarted: Dictionary = {"samples": [], "row_ms": 900000}
	MotionBuffer.push_row(restarted, Vector3(0, 0, 0), 0.0, 40, 100.0, 0.25)
	check((restarted["samples"] as Array).size() == 1, "a server clock back over 2 s (a restart) is taken")

	# The same through 24 batches with a jittery delivery (so the offset really creeps) and an animal stepped every 0.333 s: one point per step.
	var run3: Dictionary = {"samples": []}
	var off3: float = INF
	var last3: int = -1
	var steps3: Dictionary = {}
	var kept3: int = 0

	for k in range(1, 25):
		var send3: int = 250 * k
		var step3: int = int(floor(float(send3) / 333.0)) * 333
		var at3: float = 70.0 + float(send3) / 1000.0 + 0.03 + 0.01 * float(k % 3)
		off3 = MotionBuffer.clock_off(off3, at3, send3, last3)
		last3 = send3
		var before3: float = float((run3["samples"] as Array).back()[2]) if not (run3["samples"] as Array).is_empty() else -1.0
		MotionBuffer.push_row(run3, Vector3(10.0 * float(step3) / 1000.0, 0, 0), 0.0, step3, off3, 0.25)
		steps3[step3] = true

		if float((run3["samples"] as Array).back()[2]) != before3:
			kept3 += 1

	check(kept3 == steps3.size(), "with a creeping offset each step is kept once (%d kept, %d steps)" % [kept3, steps3.size()])

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

	# Over a real connection (Dave 23 Nov 2026, the real server: animals "teleporting and jumping right through us"; docs/design/ANIMAL_NETCODE.md).
	# The row clock: the interval between batches leaves out holes, a hole raises the delay, lateness raises it fast and lowers it slowly.
	var clock: Dictionary = MotionBuffer.clock_new()
	MotionBuffer.clock_note(clock, 10.0, 1000)
	MotionBuffer.clock_note(clock, 10.25, 1250)
	check(absf(MotionBuffer.clock_delay(clock) - (float(clock["interval"]) + float(clock["late"]) + 0.05)) < 0.0001, "a steady feed: one interval, the lateness and 0.05 s (%.3f)" % MotionBuffer.clock_delay(clock))
	var steady: float = MotionBuffer.clock_delay(clock)
	MotionBuffer.clock_note(clock, 11.0, 2000)   # two batches lost
	check(absf(float(clock["interval"]) - 0.25) < 0.001 and float(clock["hole"]) > 0.0 and MotionBuffer.clock_delay(clock) > steady, "a hole is not taken for the interval, and it deepens the buffer (%.3f > %.3f)" % [MotionBuffer.clock_delay(clock), steady])
	MotionBuffer.clock_note(clock, 11.55, 2250)   # this one 0.3 s late
	check(float(clock["late"]) > 0.29, "a late batch raises the lateness at once (%.3f)" % float(clock["late"]))
	var late_then: float = float(clock["late"])
	MotionBuffer.clock_note(clock, 11.5, 2500)
	check(float(clock["late"]) < late_then and float(clock["late"]) > late_then * 0.9, "and an on-time one lowers it only slowly (%.3f)" % float(clock["late"]))
	# Rows read after this computer's own stall came late because nobody read them: the lateness stays (robots 23 Nov 2026: one 2 s hitch
	# held a client's lateness over 1 s for the rest of a fight). The offset still follows them.
	var own: Dictionary = MotionBuffer.clock_new()
	MotionBuffer.clock_note(own, 10.0, 1000)
	MotionBuffer.clock_note(own, 10.25, 1250)
	var own_late: float = float(own["late"])
	MotionBuffer.clock_note(own, 12.4, 1500, true)
	check(float(own["late"]) == own_late and int(own["server_ms"]) == 1500, "rows read after this computer's own stall leave the lateness as it was (%.3f)" % float(own["late"]))
	# And the bodies are drawn where their points are: no correction left to ease away, the feet start from there.
	var settled: Dictionary = {"sm_p": Vector3.ZERO, "sm_err": Vector3(-13.0, 0.0, 0.0), "fw_p": Vector3.ZERO}
	MotionBuffer.settle(settled)
	check(MotionBuffer.smooth(settled, Vector3(13, 0, 0), 6.0, 1.0 / 60.0).is_equal_approx(Vector3(13, 0, 0)) and MotionBuffer.follow(settled, Vector3(13, 0, 0), 1.0 / 60.0).is_equal_approx(Vector3(13, 0, 0)), "after a stall a body is drawn at its point, not eased 13 m behind it")
	check(MotionBuffer.clock_delay({"interval": 5.0, "hole": 1.0, "late": 5.0}) == MotionBuffer.MAX_DELAY_S and MotionBuffer.clock_delay({"interval": 0.0, "hole": 0.0, "late": 0.0}) == MotionBuffer.MIN_DELAY_S, "the delay stays within %.1f to %.1f s" % [MotionBuffer.MIN_DELAY_S, MotionBuffer.MAX_DELAY_S])

	# smooth: a target that jumps 3 m in a frame is not drawn there at once; a standing body walks the rest at 0.9 m/s (CATCH_MIN_MPS, the
	# floor), so it is caught up within 4 s; a 40 m jump is shown at once.
	var sm: Dictionary = {}
	MotionBuffer.smooth(sm, Vector3.ZERO, 0.0, 1.0 / 60.0)
	var first: Vector3 = MotionBuffer.smooth(sm, Vector3(3, 0, 0), 0.0, 1.0 / 60.0)
	var later: Vector3 = first

	for f in 240:
		later = MotionBuffer.smooth(sm, Vector3(3, 0, 0), 0.0, 1.0 / 60.0)

	check(first.x < 0.1 and absf(later.x - 3.0) < 0.05, "a 3 m jump of the target: drawn %.2f m on in that frame, %.2f m 4 s later" % [first.x, later.x])
	check(MotionBuffer.smooth(sm, Vector3(45, 0, 0), 0.0, 1.0 / 60.0).is_equal_approx(Vector3(45, 0, 0)), "a 40 m jump is shown at once")
	# A leg between two rows stamped nearly together reads as hundreds of m/s: the drawn body still never moves more than 0.35 m a frame
	# (at the 15 m/s cap: 1.05 frames of the leg's speed plus 0.3 of it in catch-up, 0.34 m: never over 1.3 times its speed, robots 23 Nov 2026).
	var fast: Dictionary = {}
	MotionBuffer.smooth(fast, Vector3.ZERO, 0.0, 1.0 / 60.0)
	var fast_worst: float = 0.0
	var fast_was: Vector3 = Vector3.ZERO

	for i in 120:
		var fp: Vector3 = MotionBuffer.smooth(fast, Vector3(4, 0, 0), 400.0, 1.0 / 60.0)
		fast_worst = maxf(fast_worst, fp.distance_to(fast_was))
		fast_was = fp

	check(fast_worst < 0.35 and fast_was.distance_to(Vector3(4, 0, 0)) < 0.05, "a 4 m correction with an absurd leg speed is eased in, never over 0.35 m a frame (worst %.2f m)" % fast_worst)

	# A run that stops (gate review of PR #1631): the stop row is the newest point while the body, drawn 0.35 s behind, is still on the run's
	# legs. smooth takes the speed of the leg being drawn, so the body keeps its 10 m/s to the stop instead of slowing to a crawl short of it.
	var halt: Dictionary = {"samples": []}
	var halt_rows: Array = []

	for k in 11:
		halt_rows.append([k * 100, Vector3(float(k), 0.0, 0.0)])

	halt_rows.append([1250, Vector3(10.0, 0.0, 0.0)])   # standing: the send time (protocol 154)
	var slowest: float = INF
	var halt_was: Vector3 = Vector3.INF
	var halt_end: Vector3 = Vector3.ZERO

	for f in 100:
		var now_h: float = 0.4 + float(f) / 60.0

		while not halt_rows.is_empty() and float(halt_rows[0][0]) / 1000.0 <= now_h:
			var hr: Array = halt_rows.pop_front()
			MotionBuffer.push_row(halt, hr[1], 0.0, int(hr[0]), 0.0, INF)

		var t_h: float = now_h - 0.35
		var p_h: Vector3 = MotionBuffer.smooth(halt, MotionBuffer.at(halt["samples"], t_h)[0], MotionBuffer.speed_at(halt["samples"], t_h), 1.0 / 60.0)

		if halt_was != Vector3.INF and p_h.x < 9.0 and t_h > 0.1:
			slowest = minf(slowest, (p_h.x - halt_was.x) * 60.0)

		halt_was = p_h
		halt_end = p_h

	check(slowest > 7.0 and absf(halt_end.x - 10.0) < 0.05, "a 10 m/s run drawn to its stop: never under 7 m/s before it (%.1f), ends at the stop (%.2f)" % [slowest, halt_end.x])

	# The whole path, as the client gets it from a real server: an animal stepped ten times a second runs 3 s at 10 m/s (turning 40 degrees
	# either way every 1.2 s), stands 2 s, again; rows every 0.25 s; 40 to 70 ms on the way; a share of the batches lost. The old way (a stand
	# guessed from arrival gaps, a delay of one arrival gap plus 0.15 s, no smoothing, stood_ms once) jumped over half a metre in a frame
	# 3 times in 30 s at 10% loss and 9 at 30%; now none, also at 50% (scratch model, same numbers: gdmirror.py). The old way here is a model
	# of the code before protocol 154 written into this test (_connection_jumps), not that code itself.
	print("baseline: the old way (a model of it) at 30%% loss: %d frames over 0.5 m in 30 s" % _connection_jumps(false, 0.3))   # printed, not checked (gate review)

	for loss in [0.0, 0.1, 0.3, 0.5]:
		check(_connection_jumps(true, loss) == 0, "now at %d%% loss: no frame jumps over half a metre in 30 s (%d)" % [int(loss * 100.0), _connection_jumps(true, loss)])

	# PR 2, the body's own feet (Dave 23 Nov 2026: "really bad animatronics", "more freedom client side"): a point running 6 m/s east that
	# turns sharply north, then stops, is drawn on a curve: its speed never changes by more than 4 m/s in a frame (the point's changes by 6),
	# it is never more than 0.5 m from the point (a model gives 0.25), and ends on it; the facing turns at most its rate a frame.
	var fb: Dictionary = {}
	var fpt: Vector3 = Vector3.ZERO
	var f_worst_gap: float = 0.0
	var f_worst_dv: float = 0.0
	var f_was_v: Vector3 = Vector3.ZERO
	var f_drawn: Vector3 = MotionBuffer.follow(fb, fpt, 1.0 / 60.0)
	var yaw: float = 0.0
	var f_worst_turn: float = 0.0
	var rate: float = 5.0
	var yaw_east: float = 0.0
	var yaw_north: float = 0.0

	for i in 240:
		fpt += (Vector3(6.0, 0, 0) if i < 90 else (Vector3(0, 0, -6.0) if i < 180 else Vector3.ZERO)) / 60.0
		var q: Vector3 = MotionBuffer.follow(fb, fpt, 1.0 / 60.0)
		var v_now: Vector3 = (q - f_drawn) * 60.0
		f_worst_dv = maxf(f_worst_dv, (v_now - f_was_v).length() * 60.0) if i > 0 else 0.0
		f_was_v = v_now
		f_drawn = q
		f_worst_gap = maxf(f_worst_gap, Vector2(q.x - fpt.x, q.z - fpt.z).length())
		var y2: float = MotionBuffer.face(fb, yaw, 0.0, rate, 1.0 / 60.0)
		f_worst_turn = maxf(f_worst_turn, absf(angle_difference(yaw, y2)))
		yaw = y2

		if i == 89:
			yaw_east = yaw
		elif i == 179:
			yaw_north = yaw

	check(f_worst_gap <= 0.5 and f_drawn.distance_to(fpt) < 0.05, "a run that turns a sharp corner and stops is drawn within 0.5 m of the server's point and ends on it (worst %.2f m)" % f_worst_gap)
	check(f_worst_dv / 60.0 < 4.0, "its drawn speed eases: never 4 m/s more or less in one frame (worst %.2f m/s)" % (f_worst_dv / 60.0))
	check(f_worst_turn <= rate / 60.0 + 0.0001, "its facing turns at most its turn rate a frame (worst %.3f rad)" % f_worst_turn)
	check(absf(angle_difference(yaw_east, -PI * 0.5)) < 0.01 and absf(angle_difference(yaw_north, 0.0)) < 0.01, "it faces the way it runs: east -PI/2 (%.2f), north (-Z) 0 (%.2f)" % [yaw_east, yaw_north])
	# A late batch: the point itself jumps 3 m back in one frame. The body is not flung (the point's speed is taken at most CARRY_MPS).
	var lb: Dictionary = {}
	var lp: Vector3 = Vector3.ZERO
	MotionBuffer.follow(lb, lp, 1.0 / 60.0)

	for i in 60:
		lp += Vector3(6.0, 0, 0) / 60.0
		MotionBuffer.follow(lb, lp, 1.0 / 60.0)

	lp -= Vector3(3.0, 0, 0)
	var lb_worst: float = 0.0
	var lb_move: float = 0.0
	var lb_was: Vector3 = lb["fw_p"]

	for i in 120:
		lp += Vector3(6.0, 0, 0) / 60.0
		var lq: Vector3 = MotionBuffer.follow(lb, lp, 1.0 / 60.0)
		lb_worst = maxf(lb_worst, Vector2(lq.x - lp.x, lq.z - lp.z).length())
		lb_move = maxf(lb_move, lq.distance_to(lb_was))
		lb_was = lq

	check(lb_move < 0.5, "and it never moves more than 0.5 m in a frame doing so (worst %.2f m; a model gives 0.17)" % lb_move)
	check(lb_worst < 3.05, "a 3 m jump back of the point is followed, never farther from it than the jump (worst %.2f m; a model gives 2.92)" % lb_worst)
	var fs: Dictionary = {}
	MotionBuffer.follow(fs, Vector3.ZERO, 1.0 / 60.0)
	check(MotionBuffer.follow(fs, Vector3(40, 0, 0), 1.0 / 60.0).is_equal_approx(Vector3(40, 0, 0)), "a move farther than SNAP_M is put there at once")
	var standing: Dictionary = {}
	var yaw_still: float = MotionBuffer.face(standing, 0.0, 0.0, 100.0, 1.0)
	check(is_equal_approx(yaw_still, -PI * 0.5), "a standing body turns to its sent heading (heading 0, east, is rotation -PI/2)")

	print("test_animal_motion_buffer: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)


# A small fixed random sequence (the same numbers on every machine).
func _lcg(state: Array) -> float:
	state[0] = (int(state[0]) * 1103515245 + 12345) % 2147483648
	return float(state[0]) / 2147483648.0


# Frames (60 a second, over 29 s) in which the drawn body moved more than 0.5 m, for the path above: `fixed` the protocol 154 path (standing
# rows stamped every send, the row clock, smooth), otherwise the old one; `loss` the share of batches lost.
func _connection_jumps(fixed: bool, loss: float, seconds: float = 30.0) -> int:
	var rng: Array = [7]
	var steps: Array = []   # [ms, position, moving, moved_ms, stood_ms]
	var pos: Vector3 = Vector3.ZERO
	var moving: bool = false
	var moved_ms: int = -1
	var stood_ms: int = -1

	for k in int(seconds * 10.0) + 1:
		var t: float = float(k) * 0.1
		var was: Vector3 = pos

		if k > 0 and fmod(t, 5.0) < 3.0:
			var hd: float = 0.7 if int(t / 1.2) % 2 == 0 else -0.7
			pos += Vector3(cos(hd), 0.0, sin(hd))

		if pos != was:
			moved_ms = k * 100
			moving = true
		elif moving:
			moving = false
			stood_ms = k * 100

		steps.append([k * 100, pos, moving, moved_ms, stood_ms])

	var arrivals: Array = []   # [local s, send ms, row ms, position]
	var row_pos: Vector3 = Vector3.INF
	var row_ms: int = -1

	for j in int(seconds * 4.0):
		var send_ms: int = 250 * j + 50
		var st: Array = steps[mini(int(floor(float(send_ms) / 100.0)), steps.size() - 1)]

		if row_pos != st[1]:
			row_pos = st[1]
			row_ms = int(st[3]) if int(st[3]) > row_ms else send_ms
		elif fixed and not bool(st[2]):
			row_ms = send_ms
		elif not fixed and int(st[4]) > row_ms:
			row_ms = int(st[4])

		var lost: float = _lcg(rng)
		var jitter: float = _lcg(rng)

		if lost >= loss:
			arrivals.append([500.0 + float(send_ms) / 1000.0 + 0.04 + 0.03 * jitter * jitter, send_ms, row_ms, st[1]])

	arrivals.sort_custom(func(l, r): return float(l[0]) < float(r[0]))
	var body: Dictionary = {"samples": []}
	var c: Dictionary = MotionBuffer.clock_new()
	var gap: float = 0.25
	var rows_at: float = -1.0
	var off: float = INF
	var last_ms: int = -1
	var i: int = 0
	var prev: Variant = null
	var jumps: int = 0
	var frame: float = 1.0 / 60.0

	for f in int((seconds - 1.0) * 60.0):
		var now: float = 500.5 + float(f) * frame

		while i < arrivals.size() and float(arrivals[i][0]) <= now:
			var a: Array = arrivals[i]
			i += 1

			if fixed:
				MotionBuffer.clock_note(c, float(a[0]), int(a[1]))
				MotionBuffer.push_row(body, a[3], 0.0, int(a[2]), float(c["off"]), INF)
			else:
				if rows_at >= 0.0:
					gap = lerpf(gap, clampf(float(a[0]) - rows_at, 0.05, 0.5), 0.2)

				rows_at = float(a[0])
				off = MotionBuffer.clock_off(off, float(a[0]), int(a[1]), last_ms)
				last_ms = int(a[1])
				MotionBuffer.push_row(body, a[3], 0.0, int(a[2]), off, gap)

		if (body["samples"] as Array).is_empty():
			continue

		var d: Vector3

		if fixed:
			d = MotionBuffer.smooth(body, MotionBuffer.at(body["samples"], now - MotionBuffer.clock_delay(c))[0], MotionBuffer.speed_at(body["samples"], now - MotionBuffer.clock_delay(c)), frame)
		else:
			d = MotionBuffer.at(body["samples"], now - MotionBuffer.delay_s(gap))[0]

		if prev != null and now > 501.5 and d.distance_to(prev) > 0.5:
			jumps += 1

		prev = d

	return jumps

