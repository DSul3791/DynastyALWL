extends RefCounted

# Rivers, lakes and marsh pools for drawing (starter-town playtest work).
#
# For one flora chunk, the tile's water surface on its 8 m grid: one level
# per grid point (NAN where there is no inland water). The sea is not
# included; clients draw it as one plane at 0 m.
#
# Static helpers only; thread safe.


# Water levels for the chunk with corner `origin` (wrapped coordinates):
# {"count": points per side, "spacing": m, "levels": PackedFloat32Array}.
static func chunk_levels(generator, origin: Vector2, chunk_m: float) -> Dictionary:
	var data = generator.get_tile(generator.tile_of(origin.x + 1.0, origin.y + 1.0))
	var spacing: float = 8.0 if data.placeholder else data.spacing_m
	var count: int = int(round(chunk_m / spacing)) + 1
	var levels: PackedFloat32Array = PackedFloat32Array()
	levels.resize(count * count)
	levels.fill(NAN)
	var wet: int = 0

	if data.placeholder:
		return {"count": count, "spacing": spacing, "levels": levels, "wet": 0}

	for j in range(count):
		for i in range(count):
			var level: float = _level_at(generator, data, origin.x + float(i) * spacing, origin.y + float(j) * spacing, spacing)

			if not is_nan(level):
				levels[j * count + i] = level
				wet += 1

	if wet == 0:
		return {"count": count, "spacing": spacing, "levels": levels, "wet": 0}

	var closed: PackedFloat32Array = levels.duplicate()

	for j in range(count):
		for i in range(count):
			if is_nan(levels[j * count + i]):
				var level: float = _gap_level(generator, data, origin.x + float(i) * spacing, origin.y + float(j) * spacing, spacing)

				if not is_nan(level):
					closed[j * count + i] = level
					wet += 1

	levels = closed

	return {"count": count, "spacing": spacing, "levels": levels, "wet": wet}


# The inland water level at one point (NAN when dry).
static func _level_at(generator, data, x: float, z: float, spacing: float) -> float:
	# The last row and column may sit on the next tile.
	var source = data if (x < data.x0 + float(data.samples - 1) * spacing and z < data.z0 + float(data.samples - 1) * spacing) else generator.get_tile(generator.tile_of(x, z))

	if source.placeholder:
		return NAN

	var k: int = source.nearest(x, z)
	var level: float = source.water_surface[k]
	return level if source.water_class[k] > 1 and not is_nan(level) else NAN


# How far (in grid steps) a hole in a river may be closed. Steep falls leave long holes.
const GAP_STEPS := 6


# Rivers are one or two samples wide and the baked map leaves holes along
# them, mostly where the line steps sideways. A dry point with water on
# both sides of it (up to three steps away, up and down or left and right,
# allowing one step across) takes the mean of the two, closing the hole.
static func _gap_level(generator, data, x: float, z: float, spacing: float) -> float:
	for axis in [Vector2(0, 1), Vector2(1, 0)]:
		var across: Vector2 = Vector2(axis.y, axis.x)
		var a: float = NAN
		var da: int = 0

		for before in range(1, GAP_STEPS + 1):
			for side_a in [0, -1, 1]:
				a = _level_at(generator, data, x + (across.x * side_a - axis.x * before) * spacing, z + (across.y * side_a - axis.y * before) * spacing, spacing)

				if not is_nan(a):
					break

			if not is_nan(a):
				da = before
				break

		if is_nan(a):
			continue

		for after in range(1, GAP_STEPS + 1):
			for side_b in [0, -1, 1]:
				var b: float = _level_at(generator, data, x + (across.x * side_b + axis.x * after) * spacing, z + (across.y * side_b + axis.y * after) * spacing, spacing)

				if not is_nan(b):
					# A long hole is only a waterfall when the two ends differ in height;
					# level water far apart is separate water with land between.
					if da + after > 4 and absf(a - b) < 1.5:
						break

					# Nearer end counts more, so a long drop slopes instead of stepping.
					return lerpf(a, b, float(da) / float(da + after))

	return NAN


# Packs levels for sending: empty when the chunk holds no inland water,
# else a wet mask and the wet levels in cm, Zstandard-compressed.
static func encode(grid: Dictionary) -> PackedByteArray:
	if int(grid.get("wet", 0)) == 0:
		return PackedByteArray()

	var buffer: StreamPeerBuffer = StreamPeerBuffer.new()
	var levels: PackedFloat32Array = grid["levels"]
	buffer.put_u16(int(grid["count"]))
	buffer.put_float(float(grid["spacing"]))

	for n in range(levels.size()):
		var wet: bool = not is_nan(levels[n])
		buffer.put_u8(1 if wet else 0)

		if wet:
			buffer.put_32(int(round(levels[n] * 100.0)))

	var raw: PackedByteArray = buffer.data_array
	var packed: PackedByteArray = PackedByteArray()
	packed.resize(4)
	packed.encode_u32(0, raw.size())
	packed.append_array(raw.compress(FileAccess.COMPRESSION_ZSTD))
	return packed


static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 4:
		return {"count": 0, "spacing": 8.0, "levels": PackedFloat32Array(), "wet": 0}

	var buffer: StreamPeerBuffer = StreamPeerBuffer.new()
	buffer.data_array = bytes.slice(4).decompress(bytes.decode_u32(0), FileAccess.COMPRESSION_ZSTD)
	var count: int = buffer.get_u16()
	var spacing: float = buffer.get_float()
	var levels: PackedFloat32Array = PackedFloat32Array()
	levels.resize(count * count)
	var wet: int = 0

	for n in range(count * count):
		if buffer.get_u8() == 1:
			levels[n] = float(buffer.get_32()) / 100.0
			wet += 1
		else:
			levels[n] = NAN

	return {"count": count, "spacing": spacing, "levels": levels, "wet": wet}


# A water mesh for a chunk: one smooth surface over the grid. Wet points
# sit at their own level; dry points beside water are pulled under the bank
# (SHORE_DROP m lower) and fade out, so the surface slides under the ground
# without hard edges or overlapping panels. Only cells with at least one
# wet corner are drawn. Vertex positions are relative to the chunk corner;
# vertex alpha carries the fade (use vertex colors as albedo).
const SHORE_DROP := 1.5


static func build_mesh(grid: Dictionary, material: Material) -> ArrayMesh:
	var count: int = int(grid["count"])
	var spacing: float = float(grid["spacing"])
	var levels: PackedFloat32Array = grid["levels"]
	var height: PackedFloat32Array = PackedFloat32Array()
	height.resize(count * count)
	height.fill(NAN)

	for j in range(count):
		for i in range(count):
			var n: int = j * count + i

			if not is_nan(levels[n]):
				height[n] = levels[n]
				continue

			var total: float = 0.0
			var wet: int = 0

			for dj in range(-1, 2):
				for di in range(-1, 2):
					var jj: int = j + dj
					var ii: int = i + di

					if jj < 0 or jj >= count or ii < 0 or ii >= count:
						continue

					var other: float = levels[jj * count + ii]

					if not is_nan(other):
						total += other
						wet += 1

			if wet > 0:
				height[n] = total / float(wet) - SHORE_DROP

	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	var slot: PackedInt32Array = PackedInt32Array()
	slot.resize(count * count)
	slot.fill(-1)

	for j in range(count - 1):
		for i in range(count - 1):
			var corners: Array = [j * count + i, j * count + i + 1, (j + 1) * count + i + 1, (j + 1) * count + i]
			var any_wet: bool = false

			for c in corners:
				if not is_nan(levels[c]):
					any_wet = true

			if not any_wet:
				continue

			var ids: Array = []

			for c in corners:
				if slot[c] < 0:
					slot[c] = vertices.size()
					var level: float = height[c]

					if is_nan(level):
						# A dry corner with no wet neighbor in this chunk: sit with the cell's wet ones.
						level = 0.0
						var wet_total: float = 0.0
						var wet_count: int = 0

						for d in corners:
							if not is_nan(levels[d]):
								wet_total += levels[d]
								wet_count += 1

						level = wet_total / float(wet_count) - SHORE_DROP

					vertices.append(Vector3(float(c % count) * spacing, level, float(c / count) * spacing))
					normals.append(Vector3.UP)
					colors.append(Color(1.0, 1.0, 1.0, 1.0 if not is_nan(levels[c]) else 0.0))

				ids.append(slot[c])

			indices.append_array(PackedInt32Array([ids[0], ids[1], ids[2], ids[0], ids[2], ids[3]]))

	var mesh: ArrayMesh = ArrayMesh.new()

	if vertices.is_empty():
		return mesh

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh
