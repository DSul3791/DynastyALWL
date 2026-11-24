extends SceneTree

# A steady measure of how an animal drawn at the present follows the server (docs/design/ANIMAL_NETCODE.md "Plans", step 4). The robot runs
# over the lossy link vary a lot run to run (the same head gave a 95th two-robot gap of 1.0 m and 2.4 m: the deer go where they go), so this
# replays one fixed track through one fixed link, with the client's own drawing (MotionBuffer at_plan, follow, smooth: the present path of
# animal_view _process_body), twice: with the drain the merged code had and with the current one. Same seed, same track: any difference is
# the code. The track: a deer that grazes, bolts at 12 m/s, zig-zags (a turn every 1.5 s), stops dead, grazes again; four times.
# The server steps it at 10 Hz and sends a batch every 0.25 s; the link holds each 120 ms plus 0 to 60 ms and loses 3%.
# Measured per frame at 60 fps: the correction left to drain (sm_err), the drawn place against the server's at the drawn moment, the
# drawn speed (never over the deer's top speed with some slack), and how fast a body that overshot a stop is pulled back.
#   godot --headless --path . --script res://src/worldgen/tools/test_animal_draw_replay.gd

const MotionBuffer := preload("res://src/client/motion_buffer.gd")
const AnimalView := preload("res://src/client/animal_view.gd")

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


# The server's steps: [ms, position, moving, plan or null].
func track() -> Array:
	var steps: Array = []
	var pos: Vector3 = Vector3.ZERO
	var ms: int = 0
	var heading: float = 0.0

	for _bout in 4:
		for k in 30:   # graze 3 s: small steps now and then
			if k % 10 == 0:
				pos += Vector3(0.3, 0.0, 0.0).rotated(Vector3.UP, heading)
			steps.append([ms, pos, k % 10 == 0, null])
			ms += STEP_MS

		for leg in 5:   # bolt: five 1.5 s legs, turning 50 degrees each way
			heading += deg_to_rad(50.0) * (1.0 if leg % 2 == 0 else -1.0)
			var dir: Vector3 = Vector3(cos(heading), 0.0, sin(heading))
			var goal: Vector3 = pos + dir * RUN_MPS * 1.5

			for _k in 15:
				pos += dir * RUN_MPS * float(STEP_MS) / 1000.0
				steps.append([ms, pos, true, Vector2(goal.x, goal.z)])
				ms += STEP_MS

		for _k in 20:   # stopped dead: standing 2 s
			steps.append([ms, pos, false, null])
			ms += STEP_MS

	return steps


# The client's drawing of the track through the link: returns {err: [], off: [], fastest, back}.
func replay(steps: Array, new_drain: bool) -> Dictionary:
	var rng: Array = [7]
	var arrivals: Array = []   # [local s, send ms, row ms, position, plan]
	var row_pos: Vector3 = Vector3.INF
	var row_ms: int = -1
	var moved_ms: int = -1
	var end_ms: int = int(steps.back()[0])

	for send_ms in range(SEND_MS, end_ms, SEND_MS):
		var st: Array = steps[mini(int(float(send_ms) / STEP_MS), steps.size() - 1)]

		for k in range(maxi(int(float(send_ms) / STEP_MS) - 3, 0), mini(int(float(send_ms) / STEP_MS) + 1, steps.size())):
			if bool(steps[k][2]):
				moved_ms = int(steps[k][0])

		if row_pos != st[1]:
			row_pos = st[1]
			row_ms = moved_ms if moved_ms > row_ms else send_ms
		elif not bool(st[2]):
			row_ms = send_ms   # a standing row carries the send time (protocol 154)

		var lost: float = _lcg(rng)
		var jitter: float = _lcg(rng)

		if lost >= LOSS:
			arrivals.append([100.0 + float(send_ms + LAG_MS) / 1000.0 + float(JITTER_MS) / 1000.0 * jitter, send_ms, row_ms, st[1], st[3]])

	arrivals.sort_custom(func(l, r): return float(l[0]) < float(r[0]))
	var body: Dictionary = {"samples": []}
	var c: Dictionary = MotionBuffer.clock_new()
	var i: int = 0
	var errs: Array = []
	var offs: Array = []
	var fastest: float = 0.0
	var prev: Variant = null
	var top: float = AnimalView.top_mps("deer")

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
		var p: Vector3 = MotionBuffer.smooth(body, spot, MotionBuffer.speed_at(body["samples"], present), FRAME, 1.05, MotionBuffer.CATCH_X, MotionBuffer.CATCH_MIN_MPS,
				top if new_drain else 0.0, MotionBuffer.way_of(body["samples"]) if new_drain else Vector3.ZERO)

		if now > 101.0:
			errs.append((body.get("sm_err", Vector3.ZERO) as Vector3).length())
			var server_ms: int = int(round((present - float(c["off"])) * 1000.0))   # the server moment drawn
			var truth: Vector3 = steps[clampi(int(float(server_ms) / STEP_MS), 0, steps.size() - 1)][1]
			offs.append(Vector2(p.x - truth.x, p.z - truth.z).length())

			if prev != null:
				fastest = maxf(fastest, Vector2(p.x - (prev as Vector3).x, p.z - (prev as Vector3).z).length() / FRAME)

		prev = p

	return {"err": errs, "off": offs, "fastest": fastest}


func pct(xs: Array, q: float) -> float:
	var s: Array = xs.duplicate()
	s.sort()
	return float(s[mini(int(q * float(s.size())), s.size() - 1)])


func line(name: String, r: Dictionary) -> String:
	return "%s: correction left median %.2f m, 95th %.2f m, over 1 m %d of %d frames; drawn against the server median %.2f m, 95th %.2f m; fastest %.1f m/s" % [
		name, pct(r["err"], 0.5), pct(r["err"], 0.95), (r["err"] as Array).filter(func(x): return float(x) > 1.0).size(), (r["err"] as Array).size(),
		pct(r["off"], 0.5), pct(r["off"], 0.95), float(r["fastest"])]


func _init() -> void:
	var steps: Array = track()
	var old: Dictionary = replay(steps, false)
	var now: Dictionary = replay(steps, true)
	print("REPLAY " + line("old drain (1.3 times the leg)", old))
	print("REPLAY " + line("new drain (to the kind's top speed, trailing only)", now))
	check(pct(now["err"], 0.95) < pct(old["err"], 0.95), "the new drain leaves less correction at the 95th (%.2f against %.2f m)" % [pct(now["err"], 0.95), pct(old["err"], 0.95)])
	check(pct(now["off"], 0.95) <= pct(old["off"], 0.95) + 0.05, "and draws it no farther from the server (95th %.2f against %.2f m)" % [pct(now["off"], 0.95), pct(old["off"], 0.95)])
	check(float(now["fastest"]) <= AnimalView.top_mps("deer") * 1.3, "never drawn faster than 1.3 times the deer's top speed (%.1f m/s)" % float(now["fastest"]))
	print("test_animal_draw_replay: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)
