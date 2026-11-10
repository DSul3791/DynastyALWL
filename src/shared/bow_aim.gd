extends RefCounted

# The bow's aim (Dave 10 Nov 2026, data/items/bow.json "aim"): how steady the drawn bow is, how it sways after, how much a vital zone draws the
# reticle, how far the server turns a shot at random and the damage, all by the bow skill. Pure, shared: the client draws the aim with it, the
# server (server_items._shoot) takes the spread and the damage from it. A curve is [[skill level 0..100, value], ...], straight lines between.

const PATH := "res://data/items/bow.json"


static func load_config() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


# A curve at `x`: the first point's value below it, the last one's above it.
static func curve(points: Array, x: float) -> float:
	if points.is_empty():
		return 0.0

	if x <= float(points[0][0]):
		return float(points[0][1])

	for n in range(1, points.size()):
		var a: Array = points[n - 1]
		var b: Array = points[n]

		if x <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (x - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001))

	return float(points[points.size() - 1][1])


static func _aim(cfg: Dictionary) -> Dictionary:
	return cfg.get("aim", {})


static func steady_s(cfg: Dictionary, level: float) -> float:
	return curve(_aim(cfg).get("steady_s", [[0, 2.0]]), level)


static func damage_mult(cfg: Dictionary, level: float) -> float:
	return curve(_aim(cfg).get("damage_mult", [[0, 1.0]]), level)


static func spread_deg(cfg: Dictionary, level: float) -> float:
	return curve(_aim(cfg).get("spread_deg", [[0, 0.0]]), level)


static func pull(cfg: Dictionary, level: float) -> float:
	return clampf(curve(_aim(cfg).get("pull", [[0, 0.0]]), level), 0.0, 1.0)


# How far the aim sways (degrees) after `drawn_s` seconds at full draw: still for steady_s, then growing by wobble_deg_per_s a second up to wobble_max_deg.
static func wobble_deg(cfg: Dictionary, level: float, drawn_s: float) -> float:
	var over: float = maxf(drawn_s - steady_s(cfg, level), 0.0)
	return minf(over * curve(_aim(cfg).get("wobble_deg_per_s", [[0, 1.0]]), level), float(_aim(cfg).get("wobble_max_deg", 4.0)))


# The sway at time `t` (seconds) for an amplitude in degrees: a slow figure of two sines, x yaw and y pitch, never a jump.
static func wobble_offset(amplitude_deg: float, t: float, hz: float) -> Vector2:
	return Vector2(sin(TAU * hz * t), sin(TAU * hz * 1.37 * t + 1.1)) * amplitude_deg


# An aim direction turned by a sway (degrees: x to the right, y up) about the camera's own right and up.
static func turned(forward: Vector3, right: Vector3, up: Vector3, offset_deg: Vector2) -> Vector3:
	var d: Vector3 = forward.normalized()
	d = d.rotated(up.normalized(), -deg_to_rad(offset_deg.x))
	d = d.rotated(right.normalized(), deg_to_rad(offset_deg.y))
	return d.normalized()


# The turn (degrees: x to the right, y up) that takes `forward` to `aim`, about the view's own `right` and `up`: the inverse of turned() for the
# small angles of a sway (the client turns the whole view by it).
static func turn_of(aim: Vector3, forward: Vector3, right: Vector3, up: Vector3) -> Vector2:
	var a: Vector3 = aim.normalized()
	return Vector2(rad_to_deg(atan2(a.dot(right), a.dot(forward))), rad_to_deg(asin(clampf(a.dot(up), -1.0, 1.0))))


# Where a flight segment `from` -> `to` first meets a standing trunk: a vertical cylinder of `radius` round `root`, from just under the root up
# `height` (Dave 10 Nov 2026: an arrow shot at a tree must stick in it). The share 0..1 along the segment, or -1 when it misses.
static func segment_trunk(from: Vector3, to: Vector3, root: Vector3, radius: float, height: float) -> float:
	var d: Vector2 = Vector2(to.x - from.x, to.z - from.z)
	var f: Vector2 = Vector2(from.x - root.x, from.z - root.z)
	var c: float = f.dot(f) - radius * radius
	var t: float = 0.0

	if c > 0.0:   # outside the trunk at the start: the first crossing of its circle
		var a: float = d.dot(d)

		if a < 0.000001:
			return -1.0

		var b: float = 2.0 * f.dot(d)
		var disc: float = b * b - 4.0 * a * c

		if disc < 0.0:
			return -1.0

		t = (-b - sqrt(disc)) / (2.0 * a)

		if t < 0.0 or t > 1.0:
			return -1.0

	var y: float = lerpf(from.y, to.y, t)
	return t if y >= root.y - 0.2 and y <= root.y + height else -1.0


# The vital zones of an animal standing at `pos` facing `heading` (radians, the server's: forward is Vector2.from_angle(heading) on x, z).
static func zone_points(cfg: Dictionary, pos: Vector3, heading: float) -> Array:
	var fwd: Vector2 = Vector2.from_angle(heading)
	var out: Array = []

	for zone in _aim(cfg).get("zones", []):
		out.append(pos + Vector3(fwd.x, 0.0, fwd.y) * float(zone.get("fwd_m", 0.0)) + Vector3(0.0, float(zone.get("up_m", 0.5)), 0.0))

	return out


# Aim assist: the vital zone (of `points`, seen from `eye`) nearest the aim within pull_cone_deg draws the aim toward it by the skill's pull share.
# No skill (pull 0) or nothing near the aim: `aim` as it was.
static func assist(cfg: Dictionary, level: float, eye: Vector3, aim: Vector3, points: Array) -> Vector3:
	var share: float = pull(cfg, level)

	if share <= 0.0 or points.is_empty():
		return aim

	var cone: float = deg_to_rad(float(_aim(cfg).get("pull_cone_deg", 4.0)))
	var best: Vector3 = Vector3.ZERO
	var best_angle: float = cone

	for p in points:
		var to: Vector3 = (p as Vector3) - eye

		if to.length() < 0.5:
			continue

		var angle: float = aim.angle_to(to)

		if angle <= best_angle:
			best_angle = angle
			best = to.normalized()

	if best == Vector3.ZERO:
		return aim

	return aim.normalized().slerp(best, share).normalized()


# A shot turned at random by up to `max_deg` (the server's spread): `u_radius` 0..1 how far out (luck lowers it), `u_round` 0..1 which way.
static func spread(direction: Vector3, max_deg: float, u_radius: float, u_round: float) -> Vector3:
	var d: Vector3 = direction.normalized()

	if max_deg <= 0.0:
		return d

	var side: Vector3 = d.cross(Vector3.UP)

	if side.length() < 0.01:
		side = d.cross(Vector3.RIGHT)

	side = side.normalized()
	var angle: float = deg_to_rad(max_deg) * sqrt(clampf(u_radius, 0.0, 1.0))
	var tilt: Vector3 = d.rotated(side, angle)
	return tilt.rotated(d, TAU * u_round).normalized()
