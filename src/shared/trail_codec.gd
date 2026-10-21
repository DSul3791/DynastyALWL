extends RefCounted

# Game trail blocks on the wire (protocol 65) and in trails.json: a block is a list of worn cells, each {index in the block, strength
# 0..1}. Packed as [count u16][index u16, strength u8] x count, then deflated with the raw size in front (u32), so the client reads it
# with decode(). Index = local_x + local_z * block_cells (local 0 to block_cells - 1, from the block's south-west corner).


static func encode(cells: Dictionary) -> PackedByteArray:
	var raw: PackedByteArray = PackedByteArray()
	raw.resize(2 + cells.size() * 3)
	raw.encode_u16(0, cells.size())
	var at: int = 2

	for idx in cells:
		raw.encode_u16(at, int(idx))
		raw.encode_u8(at + 2, clampi(int(round(float(cells[idx]) * 255.0)), 0, 255))
		at += 3

	var out: PackedByteArray = PackedByteArray()
	out.resize(4)
	out.encode_u32(0, raw.size())
	out.append_array(raw.compress(FileAccess.COMPRESSION_DEFLATE))
	return out


# Returns {cell index: strength 0..1}; an empty dictionary for a damaged block.
static func decode(bytes: PackedByteArray) -> Dictionary:
	var cells: Dictionary = {}

	if bytes.size() < 6:
		return cells

	var size: int = bytes.decode_u32(0)

	if size < 2 or size > 1000000:
		return cells

	var raw: PackedByteArray = bytes.slice(4).decompress(size, FileAccess.COMPRESSION_DEFLATE)

	if raw.size() < 2:
		return cells

	var count: int = raw.decode_u16(0)

	for k in count:
		var at: int = 2 + k * 3

		if at + 3 > raw.size():
			break

		cells[raw.decode_u16(at)] = float(raw.decode_u8(at + 2)) / 255.0

	return cells
