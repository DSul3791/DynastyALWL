extends RefCounted

# Pipes laid from the hand (docs/design/PLUMBING_DESIGN.md s9, Dave 19 Nov 2026): a laid run is one straight pipe between two points, at any angle and
# through anything. Its structure row keeps its middle (pos), turn (yaw, degrees about up), tilt (pitch, degrees up from level along its own +X) and
# length; its ends follow from those. Shared by the server (checks, the water network's ports) and the client (the ghost line, the blue pipes, the
# sliding dot), so both work the ends out the same way.

const MAX_RUN_M := 30.0     # PV-3: the longest run one click lays
const MIN_RUN_M := 0.3      # shorter than this is a mis-click (and two ends this close are one joint)
const SNAP_M := 0.3         # an aimed point this near a connection point or a laid pipe takes it (the water network joins ends within 0.3 m)


# The run's two ends: [middle - half its length along its axis, middle + half].
static func ends(pos: Vector3, yaw_deg: float, pitch_deg: float, length: float) -> Array:
	var axis: Vector3 = axis_of(yaw_deg, pitch_deg)
	return [pos - axis * length * 0.5, pos + axis * length * 0.5]


# The unit direction of a run's +X end: level +X tilted up by pitch, then turned by yaw about up (as water_piece turns every port).
static func axis_of(yaw_deg: float, pitch_deg: float) -> Vector3:
	var p: float = deg_to_rad(pitch_deg)
	return Vector3(cos(p), sin(p), 0.0).rotated(Vector3.UP, deg_to_rad(yaw_deg))


# The row a run from `a` to `b` is saved as: {"pos", "yaw", "pitch", "len"} (ends() gives a and b back).
static func pose(a: Vector3, b: Vector3) -> Dictionary:
	var d: Vector3 = b - a
	var length: float = d.length()

	if length < 0.0001:
		return {"pos": a, "yaw": 0.0, "pitch": 0.0, "len": 0.0}

	var flat: float = Vector2(d.x, d.z).length()
	var yaw: float = rad_to_deg(atan2(-d.z, d.x)) if flat > 0.0001 else 0.0
	return {"pos": (a + b) * 0.5, "yaw": fposmod(yaw, 360.0), "pitch": rad_to_deg(atan2(d.y, flat)), "len": length}


# How many pack pieces a run of `length` metres takes, each covering `piece_m` (a 7 m copper run: 3 pieces of 3 m).
static func pieces_for(length: float, piece_m: float) -> int:
	return maxi(1, ceili(length / maxf(piece_m, 0.1) - 0.001))


# The point on the segment a-b nearest `p`.
static func closest_on(a: Vector3, b: Vector3, p: Vector3) -> Vector3:
	var d: Vector3 = b - a
	var len2: float = d.length_squared()

	if len2 < 1.0e-8:
		return a

	return a + d * clampf((p - a).dot(d) / len2, 0.0, 1.0)


# Where a ray (from `origin` along unit `dir`) passes nearest the segment a-b: [the point on the segment, its distance from the ray, the distance along
# the ray]. The client's blue pipes are picked this way (they need no collision, so a pipe never blocks a walker or the aim).
static func ray_nearest(origin: Vector3, dir: Vector3, a: Vector3, b: Vector3) -> Array:
	var u: Vector3 = b - a
	var w: Vector3 = a - origin
	var uu: float = u.dot(u)
	var ud: float = u.dot(dir)
	var uw: float = u.dot(w)
	var dw: float = dir.dot(w)
	var den: float = uu - ud * ud   # dir is unit length
	var s: float = clampf((ud * dw - uw) / den, 0.0, 1.0) if den > 1.0e-8 else 0.0
	var on: Vector3 = a + u * s
	var t: float = maxf((on - origin).dot(dir), 0.0)
	return [on, (origin + dir * t).distance_to(on), t]
