extends RefCounted

# Saved settled water for one tile: the wet cells and their depths. The server owns
# and saves this; clients never read it (they get drawn levels over the network).
# File: "DWAT", u16 version, u16 side, u32 count, then Zstandard of count x (u32 cell, u16 depth in cm).

const MAGIC := "DWAT"
const VERSION := 1


static func save(path: String, side: int, depth: PackedFloat32Array) -> int:
	var raw: StreamPeerBuffer = StreamPeerBuffer.new()
	var count: int = 0

	for k in range(depth.size()):
		if depth[k] > 0.004:
			raw.put_u32(k)
			raw.put_u16(clampi(int(round(depth[k] * 100.0)), 0, 65535))
			count += 1

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)

	if file == null:
		return -1

	var packed: PackedByteArray = raw.data_array.compress(FileAccess.COMPRESSION_ZSTD)
	file.store_buffer(MAGIC.to_ascii_buffer())
	file.store_16(VERSION)
	file.store_16(side)
	file.store_32(count)
	file.store_32(raw.data_array.size())
	file.store_buffer(packed)
	file.close()
	return count


# Depth per cell, or an empty array when the file is missing or not valid.
static func load_depth(path: String, side: int) -> PackedFloat32Array:
	if not FileAccess.file_exists(path):
		return PackedFloat32Array()

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)

	if file == null or file.get_buffer(4).get_string_from_ascii() != MAGIC:
		return PackedFloat32Array()

	if file.get_16() != VERSION or file.get_16() != side:
		return PackedFloat32Array()

	var count: int = file.get_32()
	var raw_size: int = file.get_32()

	if count == 0 or raw_size == 0:
		var none: PackedFloat32Array = PackedFloat32Array()
		none.resize(side * side)
		return none

	var raw: PackedByteArray = file.get_buffer(file.get_length() - file.get_position()).decompress(raw_size, FileAccess.COMPRESSION_ZSTD)
	var buffer: StreamPeerBuffer = StreamPeerBuffer.new()
	buffer.data_array = raw
	var depth: PackedFloat32Array = PackedFloat32Array()
	depth.resize(side * side)

	for n in range(count):
		var k: int = buffer.get_u32()
		depth[k] = float(buffer.get_u16()) / 100.0

	return depth
