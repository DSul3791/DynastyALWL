class_name ErosionDelta
extends RefCounted

# The whole-island erosion pre-carve (tools/erosion_precarve: stream power over a million years on one shared
# 32 m grid). The file holds the height change per coarse cell; every frame samples it by WORLD position, so
# neighbouring frames get the same change along their shared edge. Format "ERD1" (little endian):
#   char[4] "ERD1", int32 width, int32 height, float32 cell_m, float32 origin_x_m, float32 origin_z_m,
#   float32 reserved, int32 seed, int32 params_hash, then width * height float32 (row-major, z down).
# Outside the grid the change is 0. The file is committed once with the final bake; the tool never runs at bake time.

var width: int = 0
var height: int = 0
var cell_m: float = 32.0
var origin_x: float = 0.0
var origin_z: float = 0.0
var file_seed: int = 0
var params_hash: int = 0
var data: PackedFloat32Array = PackedFloat32Array()


# True when the file was read.
func load_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false

	var file := FileAccess.open(path, FileAccess.READ)

	if file == null or file.get_buffer(4).get_string_from_ascii() != "ERD1":
		return false

	width = file.get_32()
	height = file.get_32()
	cell_m = file.get_float()
	origin_x = file.get_float()
	origin_z = file.get_float()
	file.get_float()
	file_seed = file.get_32()
	params_hash = file.get_32()
	data = file.get_buffer(width * height * 4).to_float32_array()
	return data.size() == width * height


# Change in metres at a world position: bicubic (Catmull-Rom) on the 32 m grid, so there are no slope kinks at the
# cell lines for the 8 m water routing to find. 0 outside the grid.
func sample(x_m: float, z_m: float) -> float:
	var u: float = (x_m - origin_x) / cell_m
	var v: float = (z_m - origin_z) / cell_m

	if u < 0.0 or v < 0.0 or u > float(width - 1) or v > float(height - 1):
		return 0.0

	var c0: int = mini(int(u), width - 2)
	var r0: int = mini(int(v), height - 2)
	var tu: float = u - float(c0)
	var tv: float = v - float(r0)
	var rows: PackedFloat32Array = PackedFloat32Array()

	for dr in range(-1, 3):
		var row: int = clampi(r0 + dr, 0, height - 1) * width
		rows.append(_cubic(data[row + clampi(c0 - 1, 0, width - 1)], data[row + c0], data[row + c0 + 1], data[row + clampi(c0 + 2, 0, width - 1)], tu))

	return _cubic(rows[0], rows[1], rows[2], rows[3], tv)


static func _cubic(p0: float, p1: float, p2: float, p3: float, t: float) -> float:
	return p1 + 0.5 * t * (p2 - p0 + t * (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3 + t * (3.0 * (p1 - p2) + p3 - p0)))


# The frame (n by n samples, origin in sample units) with the change added. Sea (<= 0) is never changed
# and land never drops below `min_land_m` (or its own height if that is lower).
func apply(heights: PackedFloat32Array, n: int, spacing_m: float, origin_sx: int, origin_sz: int, min_land_m: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = heights.duplicate()

	for j in range(n):
		var z: float = float(origin_sz + j) * spacing_m

		for i in range(n):
			var index: int = j * n + i
			var original: float = heights[index]

			if original <= 0.0:
				continue

			out[index] = maxf(original + sample(float(origin_sx + i) * spacing_m, z), minf(original, min_land_m))

	return out


# The change at every land cell of the frame, computed once so two height maps over the same frame (the ground and its
# pre-erosion copy) share it: the same sample() at the same positions, so the result is identical to apply().
# NAN where the cell is sea (<= 0) in `heights`.
func delta_field(heights: PackedFloat32Array, n: int, spacing_m: float, origin_sx: int, origin_sz: int) -> PackedFloat64Array:
	var field: PackedFloat64Array = PackedFloat64Array()
	field.resize(n * n)
	field.fill(NAN)

	for j in range(n):
		var z: float = float(origin_sz + j) * spacing_m

		for i in range(n):
			var index: int = j * n + i

			if heights[index] > 0.0:
				field[index] = sample(float(origin_sx + i) * spacing_m, z)

	return field


# apply() with the change taken from a delta_field() of the same frame (a cell the field left NAN is sampled here).
func apply_field(heights: PackedFloat32Array, field: PackedFloat64Array, n: int, spacing_m: float, origin_sx: int, origin_sz: int, min_land_m: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = heights.duplicate()

	for j in range(n):
		var z: float = float(origin_sz + j) * spacing_m

		for i in range(n):
			var index: int = j * n + i
			var original: float = heights[index]

			if original <= 0.0:
				continue

			var change: float = field[index]

			if is_nan(change):
				change = sample(float(origin_sx + i) * spacing_m, z)

			out[index] = maxf(original + change, minf(original, min_land_m))

	return out
