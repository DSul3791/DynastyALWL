extends RefCounted

# Camera placement for a picture of one item lying on the ground (shot runner --shot-item). Pure maths, no scene.
# yaw 0 faces -Z, 90 faces -X (the same convention as the runner); pitch in degrees, negative looks down.

const MIN_DIST := 0.2
const MAX_DIST := 1.5
const MIN_FILL := 1.0 / 3.0
const TOP_PITCH := -89.0


# Distance at which the longest side (lying across the picture) fills `fill` of the frame width, clamped to what a ground picture can use. fov is the vertical field of view.
static func distance_for(longest_m: float, fov_deg: float, aspect: float, fill: float = MIN_FILL) -> float:
	var span: float = 2.0 * tan(deg_to_rad(fov_deg) * 0.5) * aspect
	return clampf(longest_m / (maxf(fill, 0.05) * span), MIN_DIST, MAX_DIST)


# Yaw (degrees) that faces from `from` to `to` on the ground plane.
static func yaw_to(from: Vector3, to: Vector3) -> float:
	var d: Vector3 = to - from
	return rad_to_deg(atan2(-d.x, -d.z))


# Pitch (degrees) that aims from `from` at `to`.
static func pitch_to(from: Vector3, to: Vector3) -> float:
	var d: Vector3 = to - from
	return rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length()))


# The four views of an item centred at `centre` whose ground is `ground_y`: front, side, top, diag. Each: name, dist, cam (world position), yaw, pitch,
# cam_x, cam_z, above (camera metres above the ground at the item, for the runner's view setup).
static func views(centre: Vector3, longest_m: float, fov_deg: float, ground_y: float, aspect: float = 16.0 / 9.0) -> Array:
	var d: float = distance_for(longest_m, fov_deg, aspect)
	var out: Array = []
	var bearings: Dictionary = {"front": 0.0, "side": 90.0, "diag": 45.0}

	for view_name in ["front", "side"]:
		out.append(_view(view_name, centre, d, float(bearings[view_name]), 0.5, ground_y))

	out.append(_top(centre, d, ground_y))
	out.append(_view("diag", centre, d, 45.0, 0.8, ground_y))
	return out


# A camera `d` away on a bearing (0 = south of the item looking north, 90 = east looking west), `rise` m above the item centre.
static func _view(view_name: String, centre: Vector3, d: float, bearing_deg: float, rise: float, ground_y: float) -> Dictionary:
	var b: float = deg_to_rad(bearing_deg)
	rise = minf(rise, d * 0.6)
	var horizontal: float = sqrt(maxf(d * d - rise * rise, 0.01))
	var cam: Vector3 = Vector3(centre.x + sin(b) * horizontal, centre.y + rise, centre.z + cos(b) * horizontal)
	return {"name": view_name, "dist": d, "cam": cam, "yaw": yaw_to(cam, centre), "pitch": pitch_to(cam, centre), "cam_x": cam.x, "cam_z": cam.z, "above": cam.y - ground_y}


static func _top(centre: Vector3, d: float, ground_y: float) -> Dictionary:
	var cam: Vector3 = Vector3(centre.x, centre.y + d, centre.z + 0.001)
	return {"name": "top", "dist": d, "cam": cam, "yaw": 0.0, "pitch": TOP_PITCH, "cam_x": cam.x, "cam_z": cam.z, "above": cam.y - ground_y}


# The fraction of the frame (the larger of width and height) the corners of `box` cover seen from `cam` looking along `forward`, `up` up; the vertical field of view and
# aspect define the frame. 0 when the box is behind the camera.
static func fill_fraction(box: AABB, cam: Vector3, forward: Vector3, up: Vector3, fov_deg: float, aspect: float) -> float:
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
			return 0.0

		var screen: Vector2 = Vector2(rel.dot(right) / (depth * t * aspect), rel.dot(true_up) / (depth * t))     # -1..1 across the frame
		lo = Vector2(minf(lo.x, screen.x), minf(lo.y, screen.y))
		hi = Vector2(maxf(hi.x, screen.x), maxf(hi.y, screen.y))

	return maxf(minf(hi.x - lo.x, 2.0) * 0.5, minf(hi.y - lo.y, 2.0) * 0.5)
