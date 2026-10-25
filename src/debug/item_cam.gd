extends RefCounted

# Camera placement for a picture of one item lying on the ground (shot runner --shot-item). Pure maths, no scene.
# yaw 0 faces -Z, 90 faces -X (the same convention as the runner); pitch in degrees, negative looks down.

const MIN_DIST := 0.2
const MAX_FIT_DIST := 3.0
const FIT_EXTENT := 0.9                  # every corner within 90 % of the half-frame: 10 % margin
const MIN_FILL := 1.0 / 3.0
const TOP_PITCH := -90.0


# Yaw (degrees) that faces from `from` to `to` on the ground plane.
static func yaw_to(from: Vector3, to: Vector3) -> float:
	var d: Vector3 = to - from
	return rad_to_deg(atan2(-d.x, -d.z))


# Pitch (degrees) that aims from `from` at `to`.
static func pitch_to(from: Vector3, to: Vector3) -> float:
	var d: Vector3 = to - from
	return rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length()))


# The four views of the item whose drawn box is `box`, on ground at `ground_y`: front, side, top, diag. Each looks at the box centre from the closest distance (MIN_DIST to
# MAX_FIT_DIST) at which the whole box sits inside the frame with FIT_MARGIN to spare, so a long tool backs off and a small one comes close. Each: name, dist, cam (world
# position), yaw, pitch, cam_x, cam_z, above (camera metres above the ground, for the runner's view setup), up (the camera's up vector, for the framing maths).
static func views(box: AABB, fov_deg: float, ground_y: float, aspect: float = 16.0 / 9.0) -> Array:
	var centre: Vector3 = box.get_center()
	var specs: Array = [["front", 0.0, 25.0], ["side", 90.0, 25.0], ["top", 0.0, 90.0], ["diag", 45.0, 35.0]]
	var out: Array = []

	for spec in specs:
		var bearing: float = deg_to_rad(float(spec[1]))
		var elevation: float = deg_to_rad(float(spec[2]))
		var dir: Vector3 = Vector3(sin(bearing) * cos(elevation), sin(elevation), cos(bearing) * cos(elevation))
		var up: Vector3 = Vector3.UP if float(spec[2]) < 89.0 else Vector3(0.0, 0.0, -1.0)
		var d: float = fit_distance(box, dir, up, fov_deg, aspect)
		var aim_from: Vector3 = centre + dir * d      # the orientation is the one of the unshifted camera; centre_in_frame only slides the camera
		var cam: Vector3 = centre_in_frame(box, aim_from, -dir, up, fov_deg, aspect)
		var top: bool = float(spec[2]) >= 89.0
		out.append({"name": spec[0], "dist": d, "cam": cam, "yaw": 0.0 if top else yaw_to(aim_from, centre), "pitch": TOP_PITCH if top else pitch_to(aim_from, centre),
			"cam_x": cam.x, "cam_z": cam.z, "above": cam.y - ground_y, "up": up})

	return out


# Perspective makes the projected box lean away from the projection of its centre point (the near corners spread wider), so aiming at the 3D centre leaves the picture
# of a close item off centre. The camera is slid sideways (orientation unchanged) until the middle of the projected box is the middle of the frame.
static func centre_in_frame(box: AABB, cam: Vector3, forward: Vector3, up: Vector3, fov_deg: float, aspect: float) -> Vector3:
	var right: Vector3 = forward.cross(up).normalized()
	var true_up: Vector3 = right.cross(forward).normalized()
	var t: float = tan(deg_to_rad(fov_deg) * 0.5)
	var depth: float = (box.get_center() - cam).dot(forward)

	for n in range(8):
		var b: Dictionary = frame_stats(box, cam, forward, up, fov_deg, aspect)

		if not b.has("centre"):
			return cam

		var c: Vector2 = b["centre"]

		if absf(c.x) < 0.002 and absf(c.y) < 0.002:
			break

		cam += right * c.x * t * aspect * depth + true_up * c.y * t * depth

	return cam


# The smallest distance along `dir` from the box centre (aiming back at it) at which every corner lies within FIT_MARGIN of the frame edges (bisection: the fit only
# improves with distance). Capped at MAX_FIT_DIST.
static func fit_distance(box: AABB, dir: Vector3, up: Vector3, fov_deg: float, aspect: float) -> float:
	var centre: Vector3 = box.get_center()
	var lo: float = MIN_DIST
	var hi: float = MAX_FIT_DIST

	if float(frame_stats(box, centre + dir * lo, -dir, up, fov_deg, aspect)["extent"]) <= FIT_EXTENT:
		return lo

	for n in range(24):
		var mid: float = (lo + hi) * 0.5

		if float(frame_stats(box, centre + dir * mid, -dir, up, fov_deg, aspect)["extent"]) <= FIT_EXTENT:
			hi = mid
		else:
			lo = mid

	return hi


# Where the corners of `box` land in the frame seen from `cam` looking along `forward`, `up` up (vertical field of view and aspect define the frame):
# {"fill": larger of the width and height fractions, "off": how far the box centre is from the frame centre as a fraction of the frame size (larger of x and y),
# "inside": every corner is in the frame, "extent": the farthest corner from the frame centre in half-frame units (1 = at the edge)}. fill 0 and inside false when any corner is behind the camera.
static func frame_stats(box: AABB, cam: Vector3, forward: Vector3, up: Vector3, fov_deg: float, aspect: float) -> Dictionary:
	var right: Vector3 = forward.cross(up).normalized()
	var true_up: Vector3 = right.cross(forward).normalized()
	var t: float = tan(deg_to_rad(fov_deg) * 0.5)
	var lo: Vector2 = Vector2(INF, INF)
	var hi: Vector2 = Vector2(-INF, -INF)

	for k in range(8):
		var corner: Vector3 = box.position + Vector3(box.size.x * float(k & 1), box.size.y * float((k >> 1) & 1), box.size.z * float((k >> 2) & 1))
		var rel: Vector3 = corner - cam
		var depth: float = rel.dot(forward)

		if depth <= 0.01:
			return {"fill": 0.0, "off": 1.0, "inside": false, "extent": 9.0}

		var screen: Vector2 = Vector2(rel.dot(right) / (depth * t * aspect), rel.dot(true_up) / (depth * t))     # -1..1 across the frame
		lo = Vector2(minf(lo.x, screen.x), minf(lo.y, screen.y))
		hi = Vector2(maxf(hi.x, screen.x), maxf(hi.y, screen.y))

	var centre: Vector2 = (lo + hi) * 0.5
	return {"fill": maxf(minf(hi.x - lo.x, 2.0) * 0.5, minf(hi.y - lo.y, 2.0) * 0.5), "off": maxf(absf(centre.x), absf(centre.y)) * 0.5, "centre": centre, "inside": lo.x >= -1.0 and lo.y >= -1.0 and hi.x <= 1.0 and hi.y <= 1.0, "extent": maxf(maxf(absf(lo.x), absf(hi.x)), maxf(absf(lo.y), absf(hi.y)))}


static func fill_fraction(box: AABB, cam: Vector3, forward: Vector3, up: Vector3, fov_deg: float, aspect: float) -> float:
	return float(frame_stats(box, cam, forward, up, fov_deg, aspect)["fill"])
