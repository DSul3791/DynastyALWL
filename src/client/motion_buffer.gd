extends RefCounted

# Where to draw a body the server moves (Dave 19 Nov 2026 play test: animals "teleporting when they move"). The server sends an animal's
# position about four times a second; the body chased each new point (lerp by delta), so it lunged after every send and slowed before the
# next, and its walk clip, played at the speed it covered, flicked between walk, run and stand. Now each body keeps its last few sent
# points with their arrival times and is drawn a little in the past (a send interval and a bit), on the straight line between the two
# points either side of that moment: steady speed, the standard entity interpolation of network games. A body that was not sent for a
# while (unchanged rows go out every 2 s) is taken to have stood still until the send before this one, so it walks off instead of
# sliding the whole gap. A late or lost send (the rows go unreliable) is bridged: past the newest point the body carries on at its last
# speed for up to one more interval (CARRY_S at most), then stands. A jump longer than SNAP_M (a rabbit out of its burrow) is drawn at once.

const KEEP := 4                 # points kept per body
const SNAP_M := 25.0            # farther than this between two sends: the body is put there, not slid there
const CARRY_S := 0.3            # the longest a body carries on past its newest point


# A sent point `pos` (heading radians) that arrived at `t` seconds, sends `gap` seconds apart lately.
static func push(samples: Array, pos: Vector3, heading: float, t: float, gap: float) -> void:
	if not samples.is_empty():
		var last: Array = samples[samples.size() - 1]

		if (last[0] as Vector3).distance_to(pos) > SNAP_M:
			samples.clear()
		elif t - float(last[2]) > gap * 3.0:   # not one lost send (the rows are unreliable), a real pause
			samples.append([last[0], last[1], t - gap])   # it stood still until the send before this one

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


# How far in the past bodies are drawn, from the recent gap between sends: one gap and a little (a late send is carried over, see at), so
# a drawn animal is no further behind the server's than the old chase was (the bow aims at what is drawn).
static func delay_s(gap: float) -> float:
	return clampf(gap + 0.03, 0.08, 0.6)
