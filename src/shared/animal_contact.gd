extends RefCounted

# How near an animal comes to a player (data/animals/contact.json; Dave 23 Nov 2026, first game on the real server: animals were "jumping
# right through us"). The server keeps every animal's position out of each player's body (server_animals keep_off_players, a charge in
# server_big_game stops there), and the client never draws a body inside the local player (animal_view). Shared, so the two agree.

const PATH := "res://data/animals/contact.json"

static var _rows: Dictionary = {}


static func rows() -> Dictionary:
	if _rows.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_rows = parsed if typeof(parsed) == TYPE_DICTIONARY else {"player_m": 0.35, "default_m": 0.4, "body_m": {}}

	return _rows


# Centre to centre on the ground, the nearest species `sp` comes to a player.
static func contact_m(sp: String) -> float:
	return body_m(sp) + float(rows().get("player_m", 0.35))


# The species' reach from its middle to its nose or tusks (body_m), in metres.
static func body_m(sp: String) -> float:
	var r: Dictionary = rows()
	return float((r.get("body_m", {}) as Dictionary).get(sp, r.get("default_m", 0.4)))


# `pos` moved out of the body of a player standing at `at` (feet): unchanged when it is `m` or more away on the ground or more than 2 m
# above or below; otherwise put on the circle `m` round the player, on its own side (straight back along `from` when it is on the spot).
static func keep_off(pos: Vector3, at: Vector3, m: float, from: Vector3 = Vector3.INF) -> Vector3:
	if at == Vector3.INF or absf(pos.y - at.y) > 2.0:
		return pos

	var off: Vector2 = Vector2(pos.x - at.x, pos.z - at.z)

	if off.length_squared() >= m * m:
		return pos

	if off.length_squared() < 0.0001:
		off = Vector2(from.x - at.x, from.z - at.z) if from != Vector3.INF else Vector2.RIGHT

		if off.length_squared() < 0.0001:
			off = Vector2.RIGHT

	off = off.normalized() * m
	return Vector3(at.x + off.x, pos.y, at.z + off.y)


# Where a charge from a0 to a1 stops when it reaches a player at `p`: the first point of the stretch `m` (the species' contact distance)
# from them on the ground, so it stands against the player, not inside or past them (Dave 23 Nov 2026, the real server: animals were
# "jumping right through us"). The start when it was already that close (a player under it); a1 when the stretch never comes that close.
static func stop_at(p: Vector3, a0: Vector3, a1: Vector3, m: float) -> Vector3:
	var seg: Vector2 = Vector2(a1.x - a0.x, a1.z - a0.z)
	var rel: Vector2 = Vector2(p.x - a0.x, p.z - a0.z)

	if rel.length_squared() <= m * m:
		return a0

	var len_sq: float = seg.length_squared()

	if len_sq < 0.000001:
		return a1

	var f: float = rel.dot(seg) / len_sq
	var miss_sq: float = (rel - seg * f).length_squared()

	if miss_sq >= m * m:
		return a1

	var half: float = sqrt(m * m - miss_sq) / sqrt(len_sq)

	if f - half > 1.0 or f + half < 0.0:
		return a1   # the stretch ends before the circle, or goes away from it

	return a0.lerp(a1, f - half)


# The client's form (animal_view: a charge drawn at the present, carried on past its newest point): the body drawn last frame at `a0` goes
# toward `a1`, the local player at `p`. It stops where it would enter them (stop_at), on the side it came from, never sliding through to the far
# side; already that near (the player walked into it), it steps out to the edge on its own side. When the animal itself is already past them (a1 outside
# the circle, on the far side: it ran by, or the server's player stood elsewhere), the body goes ROUND the player toward it (round_toward)
# instead of waiting at the edge: held there, it stood in the player while the animal ran on, then jumped 42 m when let go (robot run ClZm,
# 23 Nov 2026: a bear inside the capsule, then gone in one frame).
static func stop_toward(p: Vector3, a0: Vector3, a1: Vector3, m: float, reach: float = INF, go_round: bool = true) -> Vector3:
	if absf(a1.y - p.y) > 2.0:
		return a1

	var d0: float = Vector2(a0.x - p.x, a0.z - p.z).length()
	var to: Vector2 = Vector2(a1.x - p.x, a1.z - p.z)

	if to.length() < m:
		# The animal is at the player itself (a charge's carry ending in them, or the player walked into it): it waits at the edge, and one
		# drawn inside steps out to the edge on its own side (never across: gate review of PR #1631). Held where it was, a player walking
		# into a standing bear stood inside it (robot run TLcL, 23 Nov 2026: 0.24 m from the player's middle).
		if d0 < m:
			var from: Vector2 = Vector2(a0.x - p.x, a0.z - p.z)

			if from.length() < 0.01:
				from = to if to.length() >= 0.01 else Vector2.RIGHT

			var edge: Vector2 = from.normalized() * m
			return Vector3(p.x + edge.x, a0.y, p.z + edge.y)

		return stop_at(p, a0, a1, m)

	if _nearest(p, a0, a1) >= minf(d0, m) - 0.01:
		return a1      # a straight way there that comes no nearer the player

	if d0 > m + 0.05 or not go_round:
		return stop_at(p, a0, a1, m)      # still coming to the edge; or a committed charge carried past them, held on its own side until its next row

	return round_toward(p, a0, a1, m, reach)


# How near the stretch a0 -> a1 comes to p (across the ground).
static func _nearest(p: Vector3, a0: Vector3, a1: Vector3) -> float:
	var seg: Vector2 = Vector2(a1.x - a0.x, a1.z - a0.z)
	var rel: Vector2 = Vector2(p.x - a0.x, p.z - a0.z)
	var f: float = clampf(rel.dot(seg) / seg.length_squared(), 0.0, 1.0) if seg.length_squared() > 0.000001 else 0.0
	return (rel - seg * f).length()


const ROUND_RAD := 0.2      # the most a body goes round the player in one frame (its chord then dips about 1 cm inside the circle at 2 m)


# One frame of going round the player at `p` (circle `m`) from `a0` toward `a1`: along the circle, at most `reach` metres a frame (the caller
# passes the drawn body's own room, so the drawing (MotionBuffer.smooth) keeps up with the turn instead of cutting across it) and at most
# ROUND_RAD of turn; out to the circle if the player had walked into it. Once round, it goes on in a straight line.
static func round_toward(p: Vector3, a0: Vector3, a1: Vector3, m: float, reach: float = INF) -> Vector3:
	var from: Vector2 = Vector2(a0.x - p.x, a0.z - p.z)
	var to: Vector2 = Vector2(a1.x - p.x, a1.z - p.z)

	if from.length() < 0.01:
		from = to.normalized() * 0.01      # drawn on the player's middle: out on the animal's side

	var step: float = minf(Vector2(a1.x - a0.x, a1.z - a0.z).length(), reach)
	var r: float = maxf(move_toward(from.length(), m, step), from.length())
	var gap: float = wrapf(to.angle() - from.angle(), -PI, PI)
	var turn: float = signf(gap) * minf(absf(gap), minf(step / maxf(r, 0.1), ROUND_RAD))
	var out: Vector2 = Vector2.from_angle(from.angle() + turn) * r
	return Vector3(p.x + out.x, lerpf(a0.y, a1.y, 0.5), p.z + out.y)


# How fast the client turns a drawn body of species `sp` (MotionBuffer.face; not big game's defend turn_rad_s, the charge's own steering), radians a second: a full turn in half a second plus its body
# size, so a wolf (0.6 m) turns about 5.7 rad/s and an elephant (2.2 m) about 2.3 (Dave 23 Nov 2026: "really bad animatronics").
static func draw_turn_rad_s(sp: String) -> float:
	var r: Dictionary = rows()
	return TAU / (0.5 + float((r.get("body_m", {}) as Dictionary).get(sp, r.get("default_m", 0.4))))
