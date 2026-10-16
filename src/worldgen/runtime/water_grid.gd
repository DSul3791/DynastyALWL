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
			var x: float = origin.x + float(i) * spacing
			var z: float = origin.y + float(j) * spacing
			# The last row and column may sit on the next tile.
			var source = data if (x < data.x0 + float(data.samples - 1) * spacing and z < data.z0 + float(data.samples - 1) * spacing) else generator.get_tile(generator.tile_of(x, z))

			if source.placeholder:
				continue

			var k: int = source.nearest(x, z)
			var level: float = source.water_surface[k]

			if source.water_class[k] > 1 and not is_nan(level):
				levels[j * count + i] = level
				wet += 1

	return {"count": count, "spacing": spacing, "levels": levels, "wet": wet}


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


# A water mesh for a chunk: one quad per grid cell with any wet corner, at
# the mean level of its wet corners (the ground hides the parts that lie
# under the banks). Vertex positions are relative to the chunk corner.
static func build_mesh(grid: Dictionary, material: Material) -> ArrayMesh:
	var count: int = int(grid["count"])
	var spacing: float = float(grid["spacing"])
	var levels: PackedFloat32Array = grid["levels"]
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()

	for j in range(count - 1):
		for i in range(count - 1):
			var total: float = 0.0
			var wet: int = 0

			for corner in [j * count + i, j * count + i + 1, (j + 1) * count + i, (j + 1) * count + i + 1]:
				if not is_nan(levels[corner]):
					total += levels[corner]
					wet += 1

			if wet == 0:
				continue

			var y: float = total / float(wet)
			var x0: float = float(i) * spacing
			var z0: float = float(j) * spacing
			# Slightly larger than the cell so neighbors at different levels overlap.
			var a: Vector3 = Vector3(x0 - 0.3, y, z0 - 0.3)
			var b: Vector3 = Vector3(x0 + spacing + 0.3, y, z0 - 0.3)
			var c: Vector3 = Vector3(x0 + spacing + 0.3, y, z0 + spacing + 0.3)
			var d: Vector3 = Vector3(x0 - 0.3, y, z0 + spacing + 0.3)
			vertices.append_array(PackedVector3Array([a, b, c, a, c, d]))

			for n in range(6):
				normals.append(Vector3.UP)

	var mesh: ArrayMesh = ArrayMesh.new()

	if vertices.is_empty():
		return mesh

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh
