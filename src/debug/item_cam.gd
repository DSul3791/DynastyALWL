extends RefCounted

# Camera placement for a picture of one item lying on the ground (shot runner --shot-item). Pure maths, no scene.
# yaw 0 faces -Z, 90 faces -X (the same convention as the runner); pitch in degrees, negative looks down.

const MIN_DIST := 0.2
const MAX_FIT_DIST := 3.0
const FIT_EXTENT := 0.9                  # every corner within 90 % of the half-frame: 10 % margin
const TOP_PITCH := -90.0


# The height a piece stands on: the physics hit (what the game's own placement ghost uses, the smooth drawn surface) when there is one, otherwise the voxel
# raycast on the SDF channel, which lies 0.3 to 0.4 m below that surface and sank low pieces out of sight. NAN when neither found ground.
static func pick_ground(physics_y: float, voxel_y: float) -> float:
	return voxel_y if is_nan(physics_y) else physics_y


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
static func views(box: AABB, fov_deg: float, ground_y: float, aspect: float = 16.0 / 9.0, blade_dir: Vector2 = Vector2.ZERO, plate_normal: Vector3 = Vector3.ZERO, max_fit: float = MAX_FIT_DIST, low_piece: bool = false) -> Array:
	var centre: Vector3 = box.get_center()
	var specs: Array = [["front", 0.0, 25.0], ["side", 90.0, 25.0], ["top", 0.0, 90.0], ["diag", 45.0, 35.0]]

	# A low building piece (bed, floor, hearth, snare; the piece shot job): the orbit stands higher so the top of it shows.
	if low_piece:
		specs = [["front", 0.0, 40.0], ["side", 90.0, 40.0], ["top", 0.0, 90.0], ["diag", 45.0, 50.0]]

	# A long tool with a heavy end (spade, hoe, axe): the diag view looks down at 45 degrees from beyond that end, so the blade is the near, large thing.
	if blade_dir.length() > 0.5:
		specs[3] = ["diag", rad_to_deg(atan2(blade_dir.x, blade_dir.y)), 45.0]

	# The item's flat face (the normal of its largest surfaces) decides where the diag camera stands, so a blade that came to rest on its side is still seen face-on.
	var diag_dir: Vector3 = Vector3.ZERO

	if plate_normal.length() > 0.5:
		var n: Vector3 = plate_normal.normalized()

		if absf(n.y) > 0.8:
			var h: Vector2 = blade_dir if blade_dir.length() > 0.5 else Vector2(0.0, 1.0)
			diag_dir = (n + Vector3(h.x, 0.0, h.y) * 0.9).normalized()      # lying flat: from above and a little toward the blade end (about 48 degrees up)
		else:
			diag_dir = Vector3(n.x, 0.35, n.z).normalized()               # resting on its side: from the side the face points to, a little above
	var out: Array = []

	for spec in specs:
		var bearing: float = deg_to_rad(float(spec[1]))
		var elevation: float = deg_to_rad(float(spec[2]))
		var dir: Vector3 = Vector3(sin(bearing) * cos(elevation), sin(elevation), cos(bearing) * cos(elevation))

		if spec[0] == "diag" and diag_dir != Vector3.ZERO:
			dir = diag_dir

		var up: Vector3 = Vector3.UP if float(spec[2]) < 89.0 else Vector3(0.0, 0.0, -1.0)
		var d: float = fit_distance(box, dir, up, fov_deg, aspect, max_fit)
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
	var step: float = maxf(box.size.length() * 0.02, 0.005)
	var best: Vector3 = cam
	var best_err: float = INF

	# Newton on the two sideways slides with a measured 2x2 slope: a long thin item aimed along a diagonal has corners at very different depths, so a plain
	# "slide by the offset" step overshoots or crawls (iron hoe diag stuck at 8 to 11 percent). Keeps the best camera seen.
	for n in range(24):
		var b: Dictionary = frame_stats(box, cam, forward, up, fov_deg, aspect)

		if not b.has("centre"):
			return best

		var c: Vector2 = b["centre"]
		var err: float = maxf(absf(c.x), absf(c.y))

		if err < best_err:
			best_err = err
			best = cam

		if err < 0.002:
			break

		var bx: Dictionary = frame_stats(box, cam + right * step, forward, up, fov_deg, aspect)
		var by: Dictionary = frame_stats(box, cam + true_up * step, forward, up, fov_deg, aspect)

		if not bx.has("centre") or not by.has("centre"):
			return best

		var cx: Vector2 = (bx["centre"] as Vector2 - c) / step      # d(centre)/d(slide right)
		var cy: Vector2 = (by["centre"] as Vector2 - c) / step      # d(centre)/d(slide up)
		var det: float = cx.x * cy.y - cy.x * cx.y

		if absf(det) < 1.0e-9:
			break

		var dx: float = -(c.x * cy.y - c.y * cy.x) / det
		var dy: float = -(cx.x * c.y - cx.y * c.x) / det
		cam += right * dx + true_up * dy

	var last: Dictionary = frame_stats(box, cam, forward, up, fov_deg, aspect)

	if last.has("centre") and maxf(absf((last["centre"] as Vector2).x), absf((last["centre"] as Vector2).y)) < best_err:
		best = cam

	return best


# The normal of the item's largest flat surfaces: the dominant direction of the area-weighted triangle normals (power iteration on sum(area x n nT)), pointing up (or,
# for a face that stands upright, toward +x/+z). Zero when there are no faces.
static func face_normal(faces: PackedVector3Array) -> Vector3:
	var xx: float = 0.0
	var xy: float = 0.0
	var xz: float = 0.0
	var yy: float = 0.0
	var yz: float = 0.0
	var zz: float = 0.0

	for k in range(0, faces.size() - 2, 3):
		var cross: Vector3 = (faces[k + 1] - faces[k]).cross(faces[k + 2] - faces[k])
		var area: float = cross.length() * 0.5

		if area <= 0.0:
			continue

		var n: Vector3 = cross.normalized()
		xx += area * n.x * n.x
		xy += area * n.x * n.y
		xz += area * n.x * n.z
		yy += area * n.y * n.y
		yz += area * n.y * n.z
		zz += area * n.z * n.z

	if xx + yy + zz <= 0.0:
		return Vector3.ZERO

	var v: Vector3 = Vector3(0.3, 1.0, 0.2).normalized()

	for _step in range(40):
		v = Vector3(xx * v.x + xy * v.y + xz * v.z, xy * v.x + yy * v.y + yz * v.z, xz * v.x + yz * v.y + zz * v.z).normalized()

	if v.y < -0.05 or (absf(v.y) <= 0.05 and v.x + v.z < 0.0):
		v = -v

	return v


# Which end of a long tool is the heavy one (blade, head): the area-weighted centroid of its triangles against the middle of its box, along the box's longer horizontal side.
# Returns the unit horizontal direction from the middle to that end (x, z), or zero when the item is not long (under 2 : 1) or the two ends weigh the same.
static func heavy_end(faces: PackedVector3Array, box: AABB) -> Vector2:
	var long_x: bool = box.size.x >= box.size.z
	var longest: float = maxf(box.size.x, box.size.z)
	var shortest: float = maxf(minf(box.size.x, box.size.z), 0.001)

	if longest / shortest < 2.0 or faces.size() < 3:
		return Vector2.ZERO

	var centre: Vector3 = box.get_center()
	var weight: float = 0.0
	var moment: float = 0.0

	for k in range(0, faces.size() - 2, 3):
		var area: float = (faces[k + 1] - faces[k]).cross(faces[k + 2] - faces[k]).length() * 0.5
		var mid: Vector3 = (faces[k] + faces[k + 1] + faces[k + 2]) / 3.0
		weight += area
		moment += area * ((mid.x - centre.x) if long_x else (mid.z - centre.z))

	if weight <= 0.0:
		return Vector2.ZERO

	var offset: float = moment / weight

	if absf(offset) < longest * 0.03:
		return Vector2.ZERO

	return Vector2(signf(offset), 0.0) if long_x else Vector2(0.0, signf(offset))


# The smallest distance along `dir` from the box centre (aiming back at it) at which every corner lies within FIT_MARGIN of the frame edges (bisection: the fit only
# improves with distance). Capped at MAX_FIT_DIST.
static func fit_distance(box: AABB, dir: Vector3, up: Vector3, fov_deg: float, aspect: float, max_fit: float = MAX_FIT_DIST) -> float:
	var centre: Vector3 = box.get_center()
	var lo: float = MIN_DIST
	var hi: float = maxf(max_fit, box.size.length() * 1.5)      # a long tool needs more room than 3 m (a 2.5 m spade seen end-on)

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
