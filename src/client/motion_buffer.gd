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

const KEEP := 4                 # points kept per body
const SNAP_M := 25.0            # farther than this between two sends: the body is put there, not slid there
const CARRY_S := 0.3            # the longest a body carries on past its newest point
const LEAD_S := 0.15            # how far behind the rows' newest moment bodies are drawn, beyond one gap between rows (delay_s)
const REANCHOR_S := 10.0        # a clock offset this much above the smallest is a new server clock (a reconnect to another): start again
const CREEP_S := 0.0005         # the smallest offset rises this much a batch, so one freak fast delivery does not hold it low for ever


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
# drawn moment fell before the oldest one: it froze, then jumped (gate review of PR #1433, 21 Nov 2026).
static func push_row(body: Dictionary, pos: Vector3, heading: float, row_ms: int, off: float, gap: float) -> void:
	if int(body.get("row_ms", -1)) == row_ms:
		return

	body["row_ms"] = row_ms
	push(body["samples"], pos, heading, float(row_ms) / 1000.0 + off, gap)


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
# up to that leg's time (CARRY_S at most), then held.
static func at(samples: Array, t: float) -> Array:
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
	var on: float = minf(t - float(newest[2]), minf(leg, CARRY_S))
	return [(newest[0] as Vector3) + ((newest[0] as Vector3) - (before[0] as Vector3)) * (on / leg), newest[1]]


# How far in the past bodies are drawn, from the recent gap between rows: a point reaches this computer up to one gap after the server
# made it, plus the animal's own step and some lateness (LEAD_S); a later one is carried over (see at). About as far behind the server as
# the arrival-time drawing was (the bow aims at what is drawn).
static func delay_s(gap: float) -> float:
	return clampf(gap + LEAD_S, 0.1, 0.7)
