class_name IslandShape
extends RefCounted

# Planning geometry for islands inside a tile.
#
# At planning time an island is an ellipse (a rough footprint, not the
# final coastline). Positions are meters from the tile center, x east
# and z south. The tile bake later grows a ragged coast inside this
# footprint.

const SAMPLE_COUNT := 48


# Semi-axes (a is the long one) for a target land area. The fill factor
# is the share of the ellipse that ends up as land once the coast is ragged.
static func semi_axes(area_km2: float, aspect: float, fill: float) -> Vector2:
	var ab: float = area_km2 * 1000000.0 / (PI * fill)
	return Vector2(sqrt(ab * aspect), sqrt(ab / aspect))


# Boundary points of an ellipse centered at (cx, cz), rotated by rot_deg.
static func boundary(
	cx: float, cz: float, a: float, b: float, rot_deg: float
) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var rot: float = deg_to_rad(rot_deg)
	var cos_r: float = cos(rot)
	var sin_r: float = sin(rot)

	for index in range(SAMPLE_COUNT):
		var angle: float = TAU * float(index) / float(SAMPLE_COUNT)
		var ex: float = a * cos(angle)
		var ez: float = b * sin(angle)
		points.append(Vector2(
			cx + ex * cos_r - ez * sin_r,
			cz + ex * sin_r + ez * cos_r
		))

	return points


# Distance from the ellipse center to its boundary in a world direction.
static func radius_at(
	a: float, b: float, rot_deg: float, direction_rad: float
) -> float:
	var psi: float = direction_rad - deg_to_rad(rot_deg)
	var bc: float = b * cos(psi)
	var as_: float = a * sin(psi)
	return (a * b) / sqrt(bc * bc + as_ * as_)


static func contains(island: Dictionary, point: Vector2) -> bool:
	var rot: float = deg_to_rad(float(island["rot"]))
	var dx: float = point.x - float(island["cx"])
	var dz: float = point.y - float(island["cz"])
	var local_x: float = dx * cos(rot) + dz * sin(rot)
	var local_z: float = -dx * sin(rot) + dz * cos(rot)
	var a: float = float(island["a"])
	var b: float = float(island["b"])
	return (local_x * local_x) / (a * a) + (local_z * local_z) / (b * b) <= 1.0


# Largest distance from the tile center along each axis.
static func extents(points: PackedVector2Array) -> Vector2:
	var max_x: float = 0.0
	var max_z: float = 0.0

	for point in points:
		max_x = maxf(max_x, absf(point.x))
		max_z = maxf(max_z, absf(point.y))

	return Vector2(max_x, max_z)


static func fits_inside(points: PackedVector2Array, limit: float) -> bool:
	for point in points:
		if absf(point.x) > limit or absf(point.y) > limit:
			return false

	return true


# Smallest distance between two islands' footprints. Returns 0 when they
# overlap. Islands are dictionaries with cx, cz, a, b, rot and pts.
static func gap_between(first: Dictionary, second: Dictionary) -> float:
	var center_a: Vector2 = Vector2(float(first["cx"]), float(first["cz"]))
	var center_b: Vector2 = Vector2(float(second["cx"]), float(second["cz"]))
	var center_distance: float = center_a.distance_to(center_b)

	# Cheap bounds: far apart islands need no detailed test.
	var reach: float = float(first["a"]) + float(second["a"])

	if center_distance > reach + 6000.0:
		return center_distance - reach

	var points_a: PackedVector2Array = first["pts"]
	var points_b: PackedVector2Array = second["pts"]

	for point in points_a:
		if contains(second, point):
			return 0.0

	for point in points_b:
		if contains(first, point):
			return 0.0

	if contains(first, center_b) or contains(second, center_a):
		return 0.0

	var best: float = INF

	for point in points_a:
		best = minf(best, _distance_to_polygon(point, points_b))

	for point in points_b:
		best = minf(best, _distance_to_polygon(point, points_a))

	return best


static func _distance_to_polygon(
	point: Vector2, polygon: PackedVector2Array
) -> float:
	var best: float = INF
	var count: int = polygon.size()

	for index in range(count):
		var start: Vector2 = polygon[index]
		var end: Vector2 = polygon[(index + 1) % count]
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(
			point, start, end
		)
		best = minf(best, point.distance_to(closest))

	return best
