class_name RiverNetwork
extends RefCounted

# The world's rivers, worked out once for the whole world on the 160 m
# elevation map (spec Section 4b). Every tile reads the rivers that pass
# through its frame, so a river that leaves one tile enters the next at
# the same place with the same size.
#
# How it works
#   1. Priority flood from the sea over the wrapped world: every land cell
#      learns the neighbor it drains into (its receiver). Basins are filled,
#      so every river reaches the sea.
#   2. Drainage area: each cell collects the area of every cell that drains
#      through it.
#   3. Cells whose area reaches the river threshold are river cells. They
#      are joined into chains: each chain starts at a source, follows the
#      receivers downhill and ends at the sea or where it joins a bigger
#      river. A chain remembers the area at every cell.
#   4. A tile asks for the chains that cross its frame. Each chain is drawn
#      as a smooth Catmull-Rom curve through its cell centers, sampled every
#      few meters, with the area interpolated along it.
#
# Chains use unwrapped coordinates (they may run past the world edge); the
# lookup tries the world shifted by one period in each direction.

var size_x: int = 0
var size_z: int = 0
var cell_m: float = 160.0
var origin_x: float = 0.0
var origin_z: float = 0.0
var river_cells: int = 0
var chains: Array = []             # {"points": PackedVector2Array, "areas": PackedFloat32Array (km2), "bounds": Rect2}

var _receiver: PackedInt32Array = PackedInt32Array()
var _area_cells: PackedFloat32Array = PackedFloat32Array()


func build(elevation, river_start_km2: float) -> void:
	size_x = elevation.size_x
	size_z = elevation.size_z
	cell_m = elevation.cell_m
	origin_x = elevation.origin_x
	origin_z = elevation.origin_z
	var total: int = size_x * size_z
	var heights: PackedFloat32Array = elevation.heights

	# Priority flood from the sea. Heights are binned in tenths of a meter.
	var low: int = 0
	var high: int = 0

	for value in heights:
		high = maxi(high, int(value * 10.0))

	high += 2
	var head: PackedInt32Array = PackedInt32Array()
	head.resize(high - low + 2)
	head.fill(-1)
	var next: PackedInt32Array = PackedInt32Array()
	next.resize(total)
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(total)
	var level: PackedInt32Array = PackedInt32Array()
	level.resize(total)
	_receiver = PackedInt32Array()
	_receiver.resize(total)
	_receiver.fill(-1)

	for index in range(total):
		if heights[index] <= 0.0:
			seen[index] = 1

	# Land next to the sea starts the flood.
	for index in range(total):
		if seen[index] == 1:
			continue

		var row: int = index / size_x
		var column: int = index % size_x
		var touches_sea: bool = false
		var sea_cell: int = -1

		for dz in range(-1, 2):
			var nr: int = posmod(row + dz, size_z)

			for dx in range(-1, 2):
				if dx == 0 and dz == 0:
					continue

				var neighbor: int = nr * size_x + posmod(column + dx, size_x)

				if heights[neighbor] <= 0.0:
					touches_sea = true
					sea_cell = neighbor
					break

			if touches_sea:
				break

		if touches_sea:
			seen[index] = 2
			_receiver[index] = sea_cell
			var key: int = maxi(int(heights[index] * 10.0), 1)
			level[index] = key
			next[index] = head[key - low]
			head[key - low] = index

	var order: PackedInt32Array = PackedInt32Array()

	for slot in range(head.size()):
		while head[slot] != -1:
			var index: int = head[slot]
			head[slot] = next[index]
			order.append(index)
			var row: int = index / size_x
			var column: int = index % size_x
			var here: int = level[index]

			for dz in range(-1, 2):
				var nr: int = posmod(row + dz, size_z)

				for dx in range(-1, 2):
					if dx == 0 and dz == 0:
						continue

					var neighbor: int = nr * size_x + posmod(column + dx, size_x)

					if seen[neighbor] != 0:
						continue

					seen[neighbor] = 2
					_receiver[neighbor] = index
					var filled: int = maxi(int(heights[neighbor] * 10.0), here)
					level[neighbor] = filled
					next[neighbor] = head[filled - low]
					head[filled - low] = neighbor

	# Drainage area, upstream cells last in the order.
	_area_cells = PackedFloat32Array()
	_area_cells.resize(total)

	for index in order:
		_area_cells[index] = 1.0

	for k in range(order.size() - 1, -1, -1):
		var index: int = order[k]
		var down: int = _receiver[index]

		if down >= 0 and seen[down] == 2:
			_area_cells[down] += _area_cells[index]

	_build_chains(order, seen, river_start_km2)


func _build_chains(order: PackedInt32Array, seen: PackedByteArray, river_start_km2: float) -> void:
	var total: int = size_x * size_z
	var cell_km2: float = cell_m * cell_m / 1.0e6
	var threshold: float = river_start_km2 / cell_km2

	# The biggest upstream neighbor of each cell is the one its chain continues from.
	var main_up: PackedInt32Array = PackedInt32Array()
	main_up.resize(total)
	main_up.fill(-1)

	for index in order:
		var down: int = _receiver[index]

		if down >= 0 and seen[down] == 2 and (main_up[down] < 0 or _area_cells[index] > _area_cells[main_up[down]]):
			main_up[down] = index

	chains = []
	river_cells = 0

	for index in order:
		if _area_cells[index] < threshold:
			continue

		river_cells += 1
		var up: int = main_up[index]

		if up >= 0 and _area_cells[up] >= threshold:
			continue

		# A source: walk downhill until the sea or a bigger river.
		var points: PackedVector2Array = PackedVector2Array()
		var areas: PackedFloat32Array = PackedFloat32Array()
		var walker: int = index
		var previous: Vector2 = Vector2.ZERO
		var steps: int = 0

		while walker >= 0 and steps < 20000:
			steps += 1
			var center: Vector2 = _unwrapped_center(walker, previous, points.size() > 0)
			points.append(center)
			areas.append(_area_cells[walker] * cell_km2)
			previous = center

			if seen[walker] != 2:
				break

			var down: int = _receiver[walker]

			if down < 0:
				break

			if seen[down] != 2:
				# Reached the sea: one more point at the shore cell.
				points.append(_unwrapped_center(down, previous, true))
				areas.append(areas[areas.size() - 1])
				break

			if main_up[down] != walker:
				# Joins a bigger river: end exactly on its cell center.
				points.append(_unwrapped_center(down, previous, true))
				areas.append(areas[areas.size() - 1])
				break

			walker = down

		if points.size() < 2:
			continue

		var bounds: Rect2 = Rect2(points[0], Vector2.ZERO)

		for point in points:
			bounds = bounds.expand(point)

		chains.append({"points": points, "areas": areas, "bounds": bounds.grow(cell_m)})


# The center of a cell, moved by whole world widths so that it stays within
# half a world of the previous point of its chain.
func _unwrapped_center(index: int, previous: Vector2, has_previous: bool) -> Vector2:
	var center: Vector2 = Vector2(
		origin_x + (float(index % size_x) + 0.5) * cell_m,
		origin_z + (float(index / size_x) + 0.5) * cell_m
	)

	if has_previous:
		var width: float = float(size_x) * cell_m
		var height: float = float(size_z) * cell_m

		while center.x - previous.x > width * 0.5:
			center.x -= width

		while previous.x - center.x > width * 0.5:
			center.x += width

		while center.y - previous.y > height * 0.5:
			center.y -= height

		while previous.y - center.y > height * 0.5:
			center.y += height

	return center


# Rivers crossing a rectangle (world meters), each as a smooth polyline of
# points about `step_m` apart with the drainage area (km2) at every point.
# Points can lie a little outside the rectangle; a river that leaves and
# comes back is returned as separate pieces.
func guides_in(rect: Rect2, step_m: float) -> Array:
	var out: Array = []
	var world_w: float = float(size_x) * cell_m
	var world_h: float = float(size_z) * cell_m
	var wanted: Rect2 = rect.grow(cell_m)

	for chain in chains:
		var bounds: Rect2 = chain["bounds"]

		for kx in range(-1, 2):
			for kz in range(-1, 2):
				var shift: Vector2 = Vector2(float(kx) * world_w, float(kz) * world_h)

				# The chain, moved by `shift`, against the rectangle.
				if not Rect2(bounds.position + shift, bounds.size).intersects(wanted):
					continue

				_sample_chain(chain, shift, wanted, step_m, out)

	return out


func _sample_chain(chain: Dictionary, shift: Vector2, wanted: Rect2, step_m: float, out: Array) -> void:
	var points: PackedVector2Array = chain["points"]
	var areas: PackedFloat32Array = chain["areas"]
	var count: int = points.size()
	var piece_points: PackedVector2Array = PackedVector2Array()
	var piece_areas: PackedFloat32Array = PackedFloat32Array()

	for i in range(count - 1):
		var a: Vector2 = points[i] + shift
		var b: Vector2 = points[i + 1] + shift

		# Skip segments that cannot touch the rectangle.
		var segment_box: Rect2 = Rect2(a, Vector2.ZERO).expand(b).grow(cell_m)

		if not segment_box.intersects(wanted):
			if piece_points.size() > 1:
				out.append({"points": piece_points, "areas": piece_areas})

			piece_points = PackedVector2Array()
			piece_areas = PackedFloat32Array()
			continue

		var p0: Vector2 = points[i - 1] + shift if i > 0 else 2.0 * a - b
		var p3: Vector2 = points[i + 2] + shift if i + 2 < count else 2.0 * b - a
		var pieces: int = maxi(int(ceil(a.distance_to(b) / step_m)), 1)

		for s in range(pieces):
			var t: float = float(s) / float(pieces)
			piece_points.append(_catmull_rom(p0, a, b, p3, t))
			piece_areas.append(lerpf(areas[i], areas[i + 1], t))

		if i == count - 2:
			piece_points.append(b)
			piece_areas.append(areas[i + 1])

	if piece_points.size() > 1:
		out.append({"points": piece_points, "areas": piece_areas})


static func _catmull_rom(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * (
		2.0 * p1 + (p2 - p0) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3
	)
