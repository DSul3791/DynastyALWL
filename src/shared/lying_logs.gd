extends RefCounted

# Where a log lies, as the segment the grass and flora pressing uses: [ax, az, bx, bz, radius at a, radius at b] (x, z in metres).
# Client look only. Dave 2 Nov 2026: grass came up through felled and loose logs, so loose logs, stumps and boulders press it. A felled tree is
# its loose logs at once (16 Nov 2026), so there is no whole trunk to press.

const MIN_LOOSE_R := 0.08    # never thinner than this, so a small log still presses its blades


# A loose log item (a drawn cylinder lying along its local x, centred on `at`): `axis` is that x axis in world space with its length
# scale (the node's basis x), `length` the log's own length, r_a and r_b the radii at the +x and -x ends.
static func loose_segment(at: Vector3, axis: Vector3, length: float, r_a: float, r_b: float) -> Array:
	var half: Vector2 = Vector2(axis.x, axis.z) * (length * 0.5)
	return [snappedf(at.x + half.x, 0.01), snappedf(at.z + half.y, 0.01), snappedf(at.x - half.x, 0.01), snappedf(at.z - half.y, 0.01), maxf(r_a, MIN_LOOSE_R), maxf(r_b, MIN_LOOSE_R)]


# A stump or a boulder: a round footprint, pressed the same way (a segment of no length).
static func round_segment(at: Vector3, radius: float) -> Array:
	var r: float = maxf(radius, MIN_LOOSE_R)
	return [snappedf(at.x, 0.01), snappedf(at.z, 0.01), snappedf(at.x, 0.01), snappedf(at.z, 0.01), r, r]


# --- A loose log's pose (server_items.gd rolling logs, inventory_view.gd drawing; TREE_WOOD_TOOLS_DESIGN.md s5 "Rolling") ---
# A loose log's record keeps `pos`, the point under its middle (its centre less LOG_R * girth: the loose-item convention), `rot_y` its turn about
# the vertical (0 = lying along x), `pitch` the rise of its long axis and `spin` its roll about that axis. Its basis is turn(y) * pitch(z) * spin(x),
# so the long axis is the basis x, as the drawn log mesh lies (inventory_view._log_mesh).
const LOG_R := 0.25          # a drawn log's middle radius (0.28 at the butt, 0.22 at the top); girth scales it
const LOG_HALF_M := 1.5      # half of every log's 3 m (drops.json trunk.log_length_m)


static func basis_of(rot_y: float, pitch: float, spin: float) -> Basis:
	return Basis(Vector3.UP, rot_y) * Basis(Vector3(0.0, 0.0, 1.0), pitch) * Basis(Vector3(1.0, 0.0, 0.0), spin)


# [rot_y, pitch, spin] of a basis (rot_y in 0 .. TAU).
static func angles_of(b: Basis) -> Vector3:
	var o: Basis = b.orthonormalized()
	var axis: Vector3 = o.x
	var rot_y: float = atan2(-axis.z, axis.x)
	var pitch: float = asin(clampf(axis.y, -1.0, 1.0))
	var rest: Basis = (Basis(Vector3.UP, rot_y) * Basis(Vector3(0.0, 0.0, 1.0), pitch)).inverse() * o   # what is left is a turn about x
	return Vector3(fposmod(rot_y, TAU), pitch, atan2(rest.y.z, rest.y.y))


# A walker against a lying log (Dave 16 Nov 2026: "If I walk into a log I should collide and at the same time I should push the log. the log will
# stop me"). The walker is an upright capsule standing on `feet` (radius p_r, height p_h); the log a capsule round its centre along the unit
# `axis`, `half` from the centre to each rounded end, radius r. {} when they are apart or the walker is on top of it (feet above its middle);
# else {"out": the level move that puts the walker clear, "at": the touching point on the log, "n": the level unit direction from the log to the walker}.
static func walker_touch(feet: Vector3, p_r: float, p_h: float, centre: Vector3, axis: Vector3, half: float, r: float) -> Dictionary:
	if feet.y >= centre.y + r * 0.6:
		return {}

	var core: float = maxf(half - r, 0.0)
	var pair: Array = closest_on_segments(feet + Vector3(0.0, p_r, 0.0), feet + Vector3(0.0, maxf(p_h - p_r, p_r), 0.0), centre - axis * core, centre + axis * core)
	var d: Vector3 = (pair[0] as Vector3) - (pair[1] as Vector3)
	var gap: float = d.length()

	if gap >= p_r + r:
		return {}

	var level: Vector3 = Vector3(d.x, 0.0, d.z)

	if level.length() < 0.001:
		level = Vector3(feet.x - centre.x, 0.0, feet.z - centre.z)

	if level.length() < 0.001:
		level = Vector3(-axis.z, 0.0, axis.x)   # dead on its middle: out across it

	var n: Vector3 = level.normalized()
	var at: Vector3 = (pair[1] as Vector3) + (d / gap if gap > 0.0001 else n) * r
	return {"out": n * (p_r + r - gap), "at": at, "n": n}


# ACT_PUSH_LOG's b and count (protocol 125) for a walker meeting a log `square` (0 to 1: how straight into it they walk) along the level `into`:
# [1000 when sprinting + square in hundredths, the heading in degrees (atan2 of z over x)]. server_items._push_log reads them back.
static func push_args(sprint: bool, square: float, into: Vector3) -> Array:
	return [(1000 if sprint else 0) + int(round(clampf(square, 0.0, 1.0) * 100.0)), int(round(rad_to_deg(atan2(into.z, into.x))))]


# The nearest points of segments p0-p1 and q0-q1: [on p, on q].
static func closest_on_segments(p0: Vector3, p1: Vector3, q0: Vector3, q1: Vector3) -> Array:
	var u: Vector3 = p1 - p0
	var v: Vector3 = q1 - q0
	var w: Vector3 = p0 - q0
	var a: float = u.dot(u)
	var b: float = u.dot(v)
	var c: float = v.dot(v)
	var d: float = u.dot(w)
	var e: float = v.dot(w)
	var den: float = a * c - b * b
	var s: float = 0.0
	var t: float = 0.0

	if a < 1e-9 and c < 1e-9:
		return [p0, q0]

	if a < 1e-9:
		t = clampf(e / c, 0.0, 1.0)
	elif c < 1e-9:
		s = clampf(-d / a, 0.0, 1.0)
	else:
		s = clampf((b * e - c * d) / den, 0.0, 1.0) if den > 1e-9 else 0.0
		t = (b * s + e) / c

		if t < 0.0:
			t = 0.0
			s = clampf(-d / a, 0.0, 1.0)
		elif t > 1.0:
			t = 1.0
			s = clampf((b - d) / a, 0.0, 1.0)

	return [p0 + u * s, q0 + v * t]
