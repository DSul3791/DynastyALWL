extends RefCounted

# Where to draw a body the server moves (Dave 19 Nov 2026 play test: animals "teleporting when they move"). The server sends an animal's
# position about four times a second; the body chased each new point (lerp by delta), so it lunged after every send and slowed before the
# next, and its walk clip, played at the speed it covered, flicked between walk, run and stand. Now each body keeps its last few sent
# points with their times and is drawn a little in the past, on the straight line between the two points either side of that moment:
# steady speed, the standard entity interpolation of network games. A body that has not moved for a while is taken to have stood still
# until just before its next point, so it walks off instead of sliding the whole gap. A late or lost send (the rows go unreliable) is
# bridged: past the newest point the body carries on at its last speed for up to one more interval (CARRY_S at most), then stands. A jump
# longer than SNAP_M (a rabbit out of its burrow) is drawn at once.
#
# The times (protocol 147; Dave 21 Nov 2026: "animals are still teleporting and not actually running"): a point's time is when the server
# moved the animal there, put on this computer's clock (clock_off), not when the rows came. An animal steps 3 to 10 times a second, on its
# own beat, while the rows go out four times a second, and a frame hitch here holds rows back and hands over two at once: on arrival times
# a running animal covered two steps in one interval and none in the next, so it jumped, stood and jumped.

const KEEP := 6                 # points kept per body: enough for the deepest row-clock delay (MAX_DELAY_S) at four rows a second
const SNAP_M := 25.0            # farther than this between two sends: the body is put there, not slid there
const CARRY_S := 0.3            # the longest a body carries on past its newest point
const LEAD_S := 0.15            # how far behind the rows' newest moment bodies are drawn, beyond one gap between rows (delay_s)
const REANCHOR_S := 10.0        # a clock offset this much above the smallest is a new server clock (a reconnect to another): start again
const CREEP_S := 0.0005         # the smallest offset rises this much a batch, so one freak fast delivery does not hold it low for ever
const MIN_DELAY_S := 0.1        # the row clock's delay (clock_delay) stays within these
const MAX_DELAY_S := 0.8
const SMOOTH_HALF_S := 0.1      # a correction (smooth) is blended away with this half-life...
const CATCH_X := 0.3            # ...catching up at most this share of the body's own speed faster than it moves (CATCH_MIN_MPS at least),
const CATCH_MIN_MPS := 0.9      # so a drawn body never goes over 1.3 times its leg's speed (robots under lag, 23 Nov 2026: deer and a fox at 2x)
const CATCH_DRAIN_S := 0.5      # ...unless it is given its kind's top speed (smooth top_mps): a body drawn at the present that trails its point by metres drains
                                # them at about this time constant, never faster than the kind can run (robots 24 Nov 2026: a deer trailing 5 to 9 m for seconds)
const AHEAD_CARRY_S := 0.8      # a body drawn at the present (a committed charge, animal_view AHEAD_STATES) carries on this long past its newest point
const CARRY_MPS := 15.0         # and no faster than this (the fastest charge is 12 m/s); smooth() eases a body at most this fast (a 16-18 m/s
                                # flush or pronghorn flight is drawn at 15 and settles a few tenths of a metre behind its point; any excess is eased in, not jumped)
const LUNGE_MPS := 12.0         # a charge's lunge shorter than a row gap reaches the client already done (the charge row stood where the warning
                                # stood, the recover row at its end): its body is eased onto it at the fastest charge's pace, not walked there at
                                # CATCH_MIN_MPS (robots 23 Nov 2026, boar: a 3.6 m lunge drawn over 2.5 s, the first blow of each fight drawn 2.7 to
                                # 4 m from where the server had it). animal_view LUNGE_STATES


# Local seconds minus server seconds (`off` so far, INF for none): the smallest seen, the batch that came fastest, so a point's time plus
# it is never later than its arrival. Rises by CREEP_S a batch. Starts again when the server clock went backwards (`last_ms`, the batch
# before: a restarted server) or the offset is REANCHOR_S high (another server); a frame hitch here only makes batches late, which never
# re-anchors it.
static func clock_off(off: float, now_s: float, server_ms: int, last_ms: int = -1) -> float:
	var seen: float = now_s - float(server_ms) / 1000.0

	if off == INF or seen < off or server_ms < last_ms - 2000 or seen - off > REANCHOR_S:   # 2 s back: a restart, not a batch out of order
		return seen

	return off + CREEP_S


# One body's row (protocol 147): `row_ms` the server ms it reached `pos`, `off` the clock offset now (clock_off). The same row_ms as the
# body's last one is the same point sent again and is skipped: the offset creeps between batches, so on this clock the repeat would land a
# little later than the point and be kept twice. That stopped a body dead on a late send and pushed real points out of the KEEP, so the
# drawn moment fell before the oldest one: it froze, then jumped (gate review of PR #1433, 21 Nov 2026). A repeat still turns the newest
# point: an animal standing still turns (one warning watches the player), and its row_ms follows its position only. An older row_ms (a
# batch out of order) is dropped and not remembered, unless the server clock went back over 2 s (a restart).
static func push_row(body: Dictionary, pos: Vector3, heading: float, row_ms: int, off: float, gap: float) -> void:
	var last_ms: int = int(body.get("row_ms", -1))
	var samples: Array = body["samples"]

	if row_ms == last_ms:
		if not samples.is_empty():
			(samples[samples.size() - 1] as Array)[1] = heading

		return

	if row_ms < last_ms and row_ms >= last_ms - 2000:
		return

	body["row_ms"] = row_ms
	push(samples, pos, heading, float(row_ms) / 1000.0 + off, gap)


# A sent point `pos` (heading radians) the server reached at `t` seconds (this computer's clock), rows `gap` seconds apart lately. A point no
# later than the newest is the same one sent again (rows repeat unchanged; unreliable ones can come out of order) and is dropped.
static func push(samples: Array, pos: Vector3, heading: float, t: float, gap: float) -> void:
	if not samples.is_empty():
		var last: Array = samples[samples.size() - 1]

		if t <= float(last[2]):
			return

		if (last[0] as Vector3).distance_to(pos) > SNAP_M:
			samples.clear()
		elif t - float(last[2]) > gap * 3.0:   # not one lost send (the rows are unreliable), a real pause
			samples.append([last[0], last[1], t - gap])   # it stood still until a gap before this point

	samples.append([pos, heading, t])

	while samples.size() > KEEP:
		samples.pop_front()


# [position, heading] to draw at time `t`: between the two sent points either side of it; past the newest one, on along the last leg for
# up to that leg's time (CARRY_S at most), or for `carry_s` when given (a body drawn at the present: AHEAD_CARRY_S; at most two legs' time and
# at CARRY_MPS at most), then held.
static func at(samples: Array, t: float, carry_s: float = -1.0) -> Array:
	var first: Array = samples[0]

	if samples.size() == 1 or t <= float(first[2]):
		return [first[0], first[1]]

	for i in range(samples.size() - 1):
		var a: Array = samples[i]
		var b: Array = samples[i + 1]

		if t < float(b[2]):
			var f: float = (t - float(a[2])) / maxf(float(b[2]) - float(a[2]), 0.001)
			return [(a[0] as Vector3).lerp(b[0], f), lerp_angle(float(a[1]), float(b[1]), f)]

	var newest: Array = samples[samples.size() - 1]
	var before: Array = samples[samples.size() - 2]
	var leg: float = maxf(float(newest[2]) - float(before[2]), 0.001)
	var on: float = minf(t - float(newest[2]), minf(leg, CARRY_S) if carry_s < 0.0 else minf(carry_s, leg * 2.0))
	var step: Vector3 = (newest[0] as Vector3) - (before[0] as Vector3)

	if carry_s >= 0.0:
		step = step.limit_length(CARRY_MPS * leg)   # a short leg (a charge out of a stand stamped at the send time) is not a launch

	return [(newest[0] as Vector3) + step * (on / leg), newest[1]]


# at() for a body drawn at the present (animal_view, protocol 168): past its newest point it carries on along its last leg for up to
# `carry_s` (two legs' time and CARRY_MPS at most), but never past `plan` (Vector2 x, z: where its row says it is walking to), so a body
# whose stop row is late stops where the server stops it instead of running on and being pulled back. A plan behind it (it is turning)
# holds it at its newest point. No plan: as at() with no carry_s (its last leg's time, CARRY_S at most).
static func at_plan(samples: Array, t: float, carry_s: float, plan: Variant) -> Array:
	if not plan is Vector2:
		return at(samples, t)

	var r: Array = at(samples, t, carry_s)

	if samples.size() < 2 or t <= float(samples[samples.size() - 1][2]):
		return r

	var newest: Vector3 = samples[samples.size() - 1][0]
	var on: Vector2 = Vector2((r[0] as Vector3).x - newest.x, (r[0] as Vector3).z - newest.z)

	if on.length() < 0.001:
		return r

	var goal: Vector2 = plan
	var ahead: float = Vector2(goal.x - newest.x, goal.y - newest.z).dot(on / on.length())   # how far along this leg its goal lies

	if ahead <= 0.0:
		return [newest, r[1]]

	if on.length() > ahead:
		return [newest + ((r[0] as Vector3) - newest) * (ahead / on.length()), r[1]]

	return r


# How far in the past bodies are drawn, from the recent gap between rows: a point reaches this computer up to one gap after the server
# made it, plus the animal's own step and some lateness (LEAD_S); a later one is carried over (see at). About as far behind the server as
# the arrival-time drawing was (the bow aims at what is drawn).
static func delay_s(gap: float) -> float:
	return clampf(gap + LEAD_S, 0.1, 0.7)


# The row clock of one stream of timed rows (the animals, protocol 154; Dave 23 Nov 2026, first game on the real server over the internet:
# "animals were still teleporting and jumping right through us"). On a real connection rows come late by a varying amount and some never
# come (ENet drops unreliable packets on purpose when the ping wobbles: data/network.json packet_throttle). The draw delay was one row gap
# plus a fixed 0.15 s, measured from arrival gaps, so a lost or late batch ran the body past its newest point and it stood, then jumped.
# Now the clock keeps, from the server times of the batches that came: `interval` the server seconds between batches (a hole, one
# missing, is not counted in it), `hole` the recent share of holes, and `late` how late the recent latest batch came beyond the fastest
# one (fast up, slow down). The delay (clock_delay) is one interval, one more as holes grow, plus that lateness: a jitter buffer as deep
# as the connection needs, no deeper. See docs/design/ANIMAL_NETCODE.md.
static func clock_new() -> Dictionary:
	return {"off": INF, "server_ms": -1, "interval": 0.25, "late": 0.05, "hole": 0.0}


# own_stall: this computer's own frame stalled (a hitch, a long load) just before the rows were read. They came late because nobody read them,
# not because the line is slow, so the lateness is left as it was (robots 23 Nov 2026: one 2 s hitch left a client's lateness over 1 s for
# the rest of the fight, its delay at the 0.8 s cap and its charges drawn a second behind).
static func clock_note(c: Dictionary, now_s: float, server_ms: int, own_stall: bool = false) -> void:
	var last: int = int(c["server_ms"])

	if last >= 0 and server_ms > last:
		var span: float = float(server_ms - last) / 1000.0
		var hole: bool = span >= float(c["interval"]) * 1.5

		if not hole:
			c["interval"] = lerpf(float(c["interval"]), clampf(span, 0.05, 0.5), 0.1)

		c["hole"] = lerpf(float(c["hole"]), 1.0 if hole else 0.0, 0.05)

	c["off"] = clock_off(float(c["off"]), now_s, server_ms, last)
	c["server_ms"] = server_ms if server_ms > last or server_ms < last - 2000 else last
	if own_stall:
		return

	var late: float = maxf(now_s - (float(server_ms) / 1000.0 + float(c["off"])), 0.0)
	c["late"] = late if late > float(c["late"]) else lerpf(float(c["late"]), late, 0.02)


# How far behind the rows' clock bodies are drawn (see clock_new).
static func clock_delay(c: Dictionary) -> float:
	return clampf(float(c["interval"]) * (1.0 + minf(float(c["hole"]) * 4.0, 1.0)) + float(c["late"]) + 0.05, MIN_DELAY_S, MAX_DELAY_S)


# Where to draw a body this frame: `p` where its points put it now (at), `speed` its recent ground speed. A frame's move of the target
# beyond a normal one (its speed, at least 2 m/s, at most CARRY_MPS) is not shown at once: it goes into the body's correction (sm_err), which
# is then blended away (SMOOTH_HALF_S, at most CATCH_X of its speed faster, CATCH_MIN_MPS at least: so about 1.3 times its leg speed, plus
# up to about 1.5 m/s for a slow walker while a correction drains). Remote players (player_view) share it. A late batch, a hole bridged too far, a step past a player held
# back: the body never jumps. A move longer than SNAP_M (out of a burrow, a reconnect) is shown at once.
# room_x, catch_x and catch_min: the animals' (1.3 times their speed at most) unless given; other players pass their own (player_view.gd).
static func smooth(body: Dictionary, p: Vector3, speed: float, delta: float, room_x: float = 1.05, catch_x: float = CATCH_X, catch_min: float = CATCH_MIN_MPS, top_mps: float = 0.0) -> Vector3:
	var v: float = clampf(speed, 2.0, CARRY_MPS)   # a leg between two near-simultaneous rows reads absurdly fast: no animal outruns CARRY_MPS (Lane B probe, 23 Nov 2026: 1 to 4 m frame jumps under loss)
	var err: Vector3 = body.get("sm_err", Vector3.ZERO)

	if body.has("sm_p"):
		var jump: Vector3 = p - (body["sm_p"] as Vector3)
		var room: float = v * delta * room_x + 0.002   # the leg's own speed (a slack in proportion, so it holds at any frame rate): anything faster is eased in below

		if jump.length() > SNAP_M:
			err = Vector3.ZERO
		elif jump.length() > room:
			err -= jump - jump.normalized() * room

		var size: float = err.length()

		if size > 0.0:
			var drain: float = maxf(v * catch_x, catch_min)

			if top_mps > v:
				drain = maxf(drain, minf(top_mps - v, size / CATCH_DRAIN_S))   # a big backlog drains at up to the kind's own top speed, not 1.3 times this leg's

			err -= err / size * minf(minf(size * (1.0 - pow(0.5, delta / SMOOTH_HALF_S)), drain * delta), size)

	body["sm_p"] = p
	body["sm_err"] = err
	return p + err


# The ground speed (m/s) of the leg the drawn moment `t` is on, for smooth: past the newest point the last leg's, before the first none.
# Not the newest leg's: the body is drawn a delay behind, so when a run's stop row has come it is still running on the legs before it
# (gate review of PR #1631: the newest leg's speed of 0 slowed every runner to a crawl short of its stop).
static func speed_at(samples: Array, t: float) -> float:
	if samples.size() < 2 or t <= float(samples[0][2]):
		return 0.0

	var i: int = 1

	while i < samples.size() - 1 and t >= float(samples[i][2]):
		i += 1

	var a: Array = samples[i - 1]
	var b: Array = samples[i]
	var da: Vector3 = (b[0] as Vector3) - (a[0] as Vector3)
	return Vector2(da.x, da.z).length() / maxf(float(b[2]) - float(a[2]), 0.05)


# The body's own feet (Dave 23 Nov 2026: animals "like really bad animatronics", "they might need more freedom client side";
# docs/design/ANIMAL_NETCODE.md, PR 2). The server keeps where an animal is and what it does, and turns and starts it at once; the drawn
# body follows that point as a body would: a critically damped spring (the SmoothDamp form, steady at any frame rate) on the point
# FOLLOW_S ahead along its own way, so it keeps up with a steady run, eases into a start or a stop over about FOLLOW_S, and draws a sharp
# corner as a short curve. It stays within about FOLLOW_S of its speed of the point (0.25 m at 6 m/s); over SNAP_M it is put there.
const FOLLOW_S := 0.15

static func follow(body: Dictionary, p: Vector3, delta: float) -> Vector3:
	if not body.has("fw_p") or (body["fw_p"] as Vector3).distance_to(p) > SNAP_M or delta <= 0.0:
		body["fw_p"] = p
		body["fw_v"] = Vector3.ZERO
		body["fw_pv"] = Vector3.ZERO
		body["fw_last"] = p
		return p

	var q: Vector3 = body["fw_p"]
	var v: Vector3 = body["fw_v"]
	var pv: Vector3 = (p - (body["fw_last"] as Vector3)) / delta   # the point's own velocity this frame...
	pv = Vector3(pv.x, 0.0, pv.z).limit_length(CARRY_MPS)   # ...as fast as an animal runs: a jump of the point itself (a late batch) is not run at 9x
	body["fw_pv"] = pv
	var goal: Vector3 = p + pv * FOLLOW_S
	var omega: float = 2.0 / FOLLOW_S
	var x: float = omega * delta
	var damp: float = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change: Vector3 = Vector3(q.x - goal.x, 0.0, q.z - goal.z)
	var pull: Vector3 = (v + change * omega) * delta
	v = (v - pull * omega) * damp
	var drawn: Vector3 = Vector3(goal.x, p.y, goal.z) + (change + pull) * damp   # height is the ground's, from the point
	body["fw_p"] = drawn
	body["fw_v"] = v
	body["fw_last"] = p
	return drawn


# This computer's own frame stalled: the body is drawn where its points put it, with no correction to ease away and its feet starting from
# there. Every body on the screen jumped with the stall anyway; eased, it would drain a jump of the stall's length (13 m for a moose at
# 6 m/s after a 2 s hitch) at 1.3 times its speed, drawn 10 to 15 m off where the other players and the server have it for 10 s and more
# (robots 23 Nov 2026, the kinds sweep: the two clients 16 m apart on one moose).
# The end of the settle window after this computer's own stall: a gap since the bodies were last drawn (frame_s, -1 before the first) or this
# frame's own step over stall_s opens it for stall_s more; otherwise `until` as it was. Bodies are settled, and rows leave the lateness, while
# now_s <= the result: it covers the frame after the stall too, whichever of the two the rows and the drawing land in.
static func stall_until(now_s: float, frame_s: float, until: float, step_s: float, stall_s: float) -> float:
	if (frame_s >= 0.0 and now_s - frame_s > stall_s) or step_s > stall_s:
		return now_s + stall_s

	return until


static func settle(body: Dictionary) -> void:
	body.erase("sm_p")
	body.erase("sm_err")
	body.erase("fw_p")


# A body drawn without its feet this frame (a charge, animal_view AHEAD_STATES) at `p`: follow starts again from there, at the speed it had.
static func follow_hold(body: Dictionary, p: Vector3, delta: float) -> void:
	var v: Vector3 = (p - (body["fw_p"] as Vector3)) / maxf(delta, 0.001) if body.has("fw_p") else Vector3.ZERO
	v.y = 0.0
	body["fw_v"] = v.limit_length(CARRY_MPS)
	body["fw_pv"] = body["fw_v"]
	body["fw_p"] = p
	body["fw_last"] = p


# The heading a body is drawn with: the way the point it follows goes when it moves (not the spring's own velocity, which swings back past a
# stop), the sent heading when it stands; turned at most
# `turn_rad_s` a second (a standing body turns on the spot, a running one in an arc), never snapped. `yaw` is the node's rotation.y now.
static func face(body: Dictionary, yaw: float, sent_heading: float, turn_rad_s: float, delta: float) -> float:
	var v: Vector3 = body.get("fw_pv", Vector3.ZERO)
	var want: float = -sent_heading - PI * 0.5

	if Vector2(v.x, v.z).length() > 0.4:
		want = atan2(-v.x, -v.z)   # a node faces -Z

	var turn: float = angle_difference(yaw, want)
	return yaw + clampf(turn, -turn_rad_s * delta, turn_rad_s * delta)
