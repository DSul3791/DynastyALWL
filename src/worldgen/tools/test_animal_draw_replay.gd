extends SceneTree

# A steady measure of how an animal drawn at the present follows the server (docs/design/ANIMAL_NETCODE.md "Plans", step 4). The robot runs
# over the lossy link vary a lot run to run (the same head gave a 95th two-robot gap of 1.0 m and 2.4 m: the deer go where they go), so this
# replays one fixed track through one fixed link, with the client's own drawing (MotionBuffer at_plan, follow, smooth: the present path of
# animal_view _process_body), twice: with the rows' plans as they were before 24 Nov 2026 (only a moving animal's) and with the server's
# own row_plan (server_animals: also "it stops here" for STOP_PLAN_MS after its step stopped it). Same seed, same track: any difference is
# the code. The track: a deer that grazes, bolts at 12 m/s, zig-zags (a turn every 1.5 s), stops dead, grazes again; four times. The
# server steps it at 10 Hz and sends a batch every 0.25 s; the link holds each 120 ms plus 0 to 60 ms and loses 3%. The send times fall
# differently against the steps from one moment to the next, so it is replayed at ten send phases (0 to 225 ms), all counted together.
# Measured per frame at 60 fps: the correction left to drain (sm_err), the drawn place against the server's at the drawn moment, and the
# drawn speed. Without the stop plan a stop that falls badly against a send was carried on past and pulled back; at other phases the
# row with the stop went out while it still moved, with its plan. What is left is mostly starts and turns: the row with the new way
# arrives 0.1 to 0.35 s after the moment drawn, and nothing is drawn ahead of the server (docs/design/ANIMAL_NETCODE.md "Plans", step 4).
#   godot --headless --path . --script res://src/worldgen/tools/test_animal_draw_replay.gd

const MotionBuffer := preload("res://src/client/motion_buffer.gd")
const AnimalView := preload("res://src/client/animal_view.gd")
const AnimalsScript := preload("res://src/stream/server_animals.gd")

const STEP_MS := 100
const SEND_MS := 250
const LAG_MS := 120
const JITTER_MS := 60
const LOSS := 0.03
const FRAME := 1.0 / 60.0
const RUN_MPS := 12.0

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	failures += 0 if ok else 1


func _lcg(state: Array) -> float:
	state[0] = (int(state[0]) * 1103515245 + 12345) % 2147483648
	return float(state[0]) / 2147483648.0


# The server's steps: [ms, position, moving, plan or null, standing after a bolt].
func track() -> Array:
	var steps: Array = []
	var pos: Vector3 = Vector3.ZERO
	var ms: int = 0
	var heading: float = 0.0

	for _bout in 4:
		for k in 30:   # graze 3 s: small steps now and then
			if k % 10 == 0:
				pos += Vector3(0.3, 0.0, 0.0).rotated(Vector3.UP, heading)
			steps.append([ms, pos, k % 10 == 0, null, false])
			ms += STEP_MS

		for leg in 5:   # bolt: five 1.5 s legs, turning 50 degrees each way
			heading += deg_to_rad(50.0) * (1.0 if leg % 2 == 0 else -1.0)
			var dir: Vector3 = Vector3(cos(heading), 0.0, sin(heading))
			var goal: Vector3 = pos + dir * RUN_MPS * 1.5

			for _k in 15:
				pos += dir * RUN_MPS * float(STEP_MS) / 1000.0
				steps.append([ms, pos, true, Vector2(goal.x, goal.z), false])
				ms += STEP_MS

		for _k in 20:   # stopped dead: standing 2 s
			steps.append([ms, pos, false, null, true])
			ms += STEP_MS

	return steps


# The client's drawing of the track through the link, sends `phase_ms` after the steps' own times: returns {err: [], off: [], fastest,
# over_rule, stand_bad (frames with over 1 m of correction while the server has it standing after a bolt)}.
func replay(steps: Array, stop_plan: bool, phase_ms: int) -> Dictionary:
	var rng: Array = [7]
	var arrivals: Array = []   # [local s, send ms, row ms, position, plan]
	var row_pos: Vector3 = Vector3.INF
	var row_ms: int = -1
	var moved_ms: int = -1
	var end_ms: int = int(steps.back()[0])

	for send_ms in range(SEND_MS + phase_ms, end_ms, SEND_MS):
		var st: Array = steps[mini(int(float(send_ms) / STEP_MS), steps.size() - 1)]

		for k in range(maxi(int(float(send_ms) / STEP_MS) - 3, 0), mini(int(float(send_ms) / STEP_MS) + 1, steps.size())):
			if bool(steps[k][2]):
				moved_ms = int(steps[k][0])

		if row_pos != st[1]:   # as rows_near
			row_pos = st[1]
			row_ms = moved_ms if moved_ms > row_ms else send_ms
		elif not bool(st[2]):
			row_ms = send_ms   # a standing row carries the send time (protocol 154)

		var goal: Variant = st[3]
		var a: Dictionary = {"pos": st[1], "moving": st[2], "plan_ms": send_ms}

		if goal is Vector2:
			a["plan_to"] = Vector3((goal as Vector2).x, 0.0, (goal as Vector2).y)

		for k in range(mini(int(float(send_ms) / STEP_MS), steps.size() - 1), 0, -1):   # the tick's stopped_ms: the step that stopped it
			if stop_plan and bool(steps[k - 1][2]) and not bool(steps[k][2]):
				a["stopped_ms"] = int(steps[k][0])
				break

		var plan: Variant = AnimalsScript.row_plan(a, send_ms)

		var lost: float = _lcg(rng)
		var jitter: float = _lcg(rng)

		if lost >= LOSS:
			arrivals.append([100.0 + float(send_ms + LAG_MS) / 1000.0 + float(JITTER_MS) / 1000.0 * jitter, send_ms, row_ms, st[1], plan])

	arrivals.sort_custom(func(l, r): return float(l[0]) < float(r[0]))
	var body: Dictionary = {"samples": []}
	var c: Dictionary = MotionBuffer.clock_new()
	var i: int = 0
	var errs: Array = []
	var offs: Array = []
	var fastest: float = 0.0
	var over_rule: int = 0
	var stand_bad: int = 0
	var prev: Variant = null

	for f in int(float(end_ms) / 1000.0 * 60.0):
		var now: float = 100.0 + float(f) * FRAME

		while i < arrivals.size() and float(arrivals[i][0]) <= now:
			var a: Array = arrivals[i]
			i += 1
			MotionBuffer.clock_note(c, float(a[0]), int(a[1]))
			MotionBuffer.push_row(body, a[3], 0.0, int(a[2]), float(c["off"]), INF)

			if int(body.get("row_ms", -1)) == int(a[2]):
				body["plan"] = a[4]   # as animal_view on_rows: only from a row the buffer took

		if (body["samples"] as Array).is_empty():
			continue

		var present: float = now - float(c["late"])
		var drawn: Array = MotionBuffer.at_plan(body["samples"], present, AnimalView.PLAN_CARRY_S, body.get("plan", null))
		var spot: Vector3 = MotionBuffer.follow(body, drawn[0], FRAME)
		var leg: float = MotionBuffer.speed_at(body["samples"], present)
		var p: Vector3 = MotionBuffer.smooth(body, spot, leg, FRAME)

		if now > 101.0:
			errs.append((body.get("sm_err", Vector3.ZERO) as Vector3).length())
			var server_ms: int = int(round((present - float(c["off"])) * 1000.0))   # the server moment drawn
			var at_step: Array = steps[clampi(int(float(server_ms) / STEP_MS), 0, steps.size() - 1)]
			var truth: Vector3 = at_step[1]
			stand_bad += 1 if bool(at_step[4]) and (body.get("sm_err", Vector3.ZERO) as Vector3).length() > 1.0 else 0
			offs.append(Vector2(p.x - truth.x, p.z - truth.z).length())

			if prev != null:
				var speed: float = Vector2(p.x - (prev as Vector3).x, p.z - (prev as Vector3).z).length() / FRAME
				fastest = maxf(fastest, speed)
				# smooth's own rule: a frame moves at most its room (1.05 times the leg's speed, clamped to 2..CARRY_MPS, plus 2 mm) and the
				# correction's drain (CATCH_X of that speed, CATCH_MIN_MPS at least). So a body catching up runs up to 1.35 times its leg.
				var v: float = clampf(leg, 2.0, MotionBuffer.CARRY_MPS)
				over_rule += 1 if speed > v * 1.05 + 0.002 / FRAME + maxf(v * MotionBuffer.CATCH_X, MotionBuffer.CATCH_MIN_MPS) + 0.01 else 0

		prev = p

	return {"err": errs, "off": offs, "fastest": fastest, "over_rule": over_rule, "stand_bad": stand_bad}


func pct(xs: Array, q: float) -> float:
	var s: Array = xs.duplicate()
	s.sort()
	return float(s[mini(int(q * float(s.size())), s.size() - 1)])


# The replays at every send phase, counted together.
func replay_all(steps: Array, stop_plan: bool) -> Dictionary:
	var total: Dictionary = {"err": [], "off": [], "fastest": 0.0, "over_rule": 0, "stand_bad": 0, "worse": 0}

	for phase in range(0, SEND_MS, 25):
		var r: Dictionary = replay(steps, stop_plan, phase)
		(total["err"] as Array).append_array(r["err"])
		(total["off"] as Array).append_array(r["off"])
		total["fastest"] = maxf(float(total["fastest"]), float(r["fastest"]))
		total["over_rule"] = int(total["over_rule"]) + int(r["over_rule"])
		total["stand_bad"] = int(total["stand_bad"]) + int(r["stand_bad"])

		if stop_plan and pct(r["err"], 0.95) > pct(replay(steps, false, phase)["err"], 0.95) + 0.01:
			total["worse"] = int(total["worse"]) + 1

	return total


func line(name: String, r: Dictionary) -> String:
	return "%s: correction left median %.2f m, 95th %.2f m, over 1 m %d of %d frames; drawn against the server median %.2f m, 95th %.2f m; fastest %.1f m/s" % [
		name, pct(r["err"], 0.5), pct(r["err"], 0.95), (r["err"] as Array).filter(func(x): return float(x) > 1.0).size(), (r["err"] as Array).size(),
		pct(r["off"], 0.5), pct(r["off"], 0.95), float(r["fastest"])]


func _init() -> void:
	var steps: Array = track()
	var before: Dictionary = replay_all(steps, false)
	var now: Dictionary = replay_all(steps, true)
	print("REPLAY " + line("plans as before (moving only)", before) + "; over 1 m standing after a bolt %d" % int(before["stand_bad"]))
	print("REPLAY " + line("with the stop plan (row_plan)", now) + "; over 1 m standing after a bolt %d" % int(now["stand_bad"]))
	check(int(now["stand_bad"]) == 0 and int(before["stand_bad"]) > 0, "a deer standing after its bolt is never left over 1 m from where it stopped (%d frames, before %d)" % [int(now["stand_bad"]), int(before["stand_bad"])])
	check(int(now["worse"]) == 0 and pct(now["err"], 0.95) < pct(before["err"], 0.95), "the correction left is no worse at any send phase, and less at the 95th over all (%.2f, before %.2f m)" % [pct(now["err"], 0.95), pct(before["err"], 0.95)])
	check(pct(now["off"], 0.5) < pct(before["off"], 0.5) and pct(now["off"], 0.95) <= pct(before["off"], 0.95), "drawn nearer the server (median %.2f, before %.2f m; 95th %.2f, before %.2f m)" % [pct(now["off"], 0.5), pct(before["off"], 0.5), pct(now["off"], 0.95), pct(before["off"], 0.95)])
	check(int(now["over_rule"]) == 0, "no frame faster than smooth's own rule allows its leg (1.35 times it: fastest %.1f m/s, %.2f times the deer's 12)" % [float(now["fastest"]), float(now["fastest"]) / RUN_MPS])
	print("test_animal_draw_replay: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)
